extends Node

signal craft_enqueued(slot_idx, recipe_id)
signal task_started(task_id, config)
signal task_updated(task_id, payload)
signal task_completed(slot_idx: int, crafted_item: Dictionary)

const MAX_SLOTS := 3
const STATUS_QUEUED := &"queued"
const STATUS_IN_PROGRESS := &"in_progress"
const STATUS_COMPLETED := &"completed"

const GRADE_THRESHOLDS := {
	"gold": 0.9,
	"silver": 0.7,
	"bronze": 0.4,
}

# FASE 1: Pesos por defecto para fusión de minijuegos
const DEFAULT_MINIGAME_WEIGHTS := {
	&"temp": 1.0,
	&"hammer": 1.0,
	&"sew": 1.0,
	&"quench": 1.0
}

class CraftingTask:
	var id: int
	var blueprint: BlueprintResource
	var status: StringName = STATUS_QUEUED
	var slot_index: int = -1
	var current_trial_index: int = 0
	var current_trial_id: StringName = &""
	var current_trial_config: TrialConfig
	var score_accumulated: float = 0.0
	var max_score_accumulated: float = 0.0
	var trial_results: Array = []
	var grade: String = ""

	func _init(task_id: int, blueprint_res: BlueprintResource, slot: int) -> void:
		id = task_id
		blueprint = blueprint_res
		slot_index = slot

var queue: Array = []
var heat := 0
var forjamagia := 0

var _next_task_id: int = 1

func _ready():
	for i in range(MAX_SLOTS):
		queue.append(null)

	# Wait for DataManager to load blueprints before enqueuing defaults
	if has_node("/root/DataManager"):
		var dm = get_node("/root/DataManager")
		if dm.has_signal("data_ready"):
			dm.connect("data_ready", Callable(self, "_on_data_ready"))
		else:
			_enqueue_defaults()
	else:
		_enqueue_defaults()

	print("CraftingManager: Ready with %d slots" % MAX_SLOTS)

func _on_data_ready() -> void:
	_enqueue_defaults()

func _enqueue_defaults() -> void:
	var default_blueprints = ["sword_basic", "armor_leather", "shield_wooden"]
	for recipe_id in default_blueprints:
		enqueue(recipe_id)
	print("CraftingManager: Default blueprints enqueued")

func enqueue(recipe_id) -> bool:
	var blueprint := _resolve_blueprint(StringName(str(recipe_id)))
	if blueprint == null:
		push_warning("CraftingManager: Cannot enqueue recipe '%s' without blueprint" % recipe_id)
		return false

	for i in range(MAX_SLOTS):
		if queue[i] == null:
			var task := CraftingTask.new(_generate_task_id(), blueprint, i)
			queue[i] = task
			task.status = STATUS_QUEUED  # Wait for player click
			emit_signal("craft_enqueued", i, recipe_id)
			print("CraftingManager: Enqueued recipe '%s' in slot %d (waiting for player)" % [recipe_id, i])
			_emit_task_update(task)
			# Do NOT auto-start trials - wait for player to click blueprint
			return true

	print("CraftingManager: No free slots for recipe '%s'" % recipe_id)
	return false


## Encola un blueprint aleatorio de los desbloqueados
func enqueue_random() -> bool:
	var dm = get_node_or_null("/root/DataManager")
	if dm == null or not dm.has_method("get_unlocked_blueprints"):
		# Fallback: usar defaults si DataManager no está disponible
		var defaults = ["sword_basic", "armor_leather", "shield_wooden"]
		var fallback_bp = defaults[randi() % defaults.size()]
		return enqueue(fallback_bp)
	
	var unlocked = dm.get_unlocked_blueprints()
	if unlocked.is_empty():
		print("CraftingManager: No unlocked blueprints available")
		return false
	
	var random_bp = unlocked[randi() % unlocked.size()]
	print("CraftingManager: Auto-enqueuing random unlocked blueprint: %s" % random_bp)
	return enqueue(random_bp)

func start_task(slot_idx: int) -> bool:
	"""Manually start a queued task when player clicks on blueprint"""
	if slot_idx < 0 or slot_idx >= MAX_SLOTS:
		return false
	
	var task: CraftingTask = queue[slot_idx]
	if task == null:
		return false
	
	if task.status != STATUS_QUEUED:
		print("CraftingManager: Task %d already started (status: %s)" % [task.id, task.status])
		return false
	
	if task.blueprint.has_trials():
		print("CraftingManager: Player starting task %d (slot %d)" % [task.id, slot_idx])
		_start_next_trial(task)
		return true
	else:
		_finalize_task(task)
		return true

func cancel(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= MAX_SLOTS:
		push_warning("CraftingManager: Invalid slot %d for cancel" % slot_idx)
		return {}

	var task: CraftingTask = queue[slot_idx]
	if task == null:
		print("CraftingManager: Cannot cancel empty slot %d" % slot_idx)
		return {}

	queue[slot_idx] = null
	print("CraftingManager: Cancelled recipe in slot %d" % slot_idx)
	_emit_slot_cleared(slot_idx)
	_compress_queue()
	# Return 80% of materials (stub)
	return {"refund_pct": 0.8}

func promote(slot_idx: int) -> bool:
	if slot_idx <= 0 or slot_idx >= MAX_SLOTS:
		print("CraftingManager: Invalid slot %d for promotion" % slot_idx)
		return false

	var task: CraftingTask = queue[slot_idx]
	if task == null:
		print("CraftingManager: Cannot promote empty slot %d" % slot_idx)
		return false

	queue.remove_at(slot_idx)
	queue.insert(0, task)
	_update_slot_indices()
	heat = clamp(heat + 10, 0, 100)
	print("CraftingManager: Promoted slot %d to front, heat now %d" % [slot_idx, heat])
	return true

func report_trial_result(task_id: int, result: TrialResult) -> Dictionary:
	var task := _find_task(task_id)
	if task == null:
		push_warning("CraftingManager: Unknown task_id %d in report_trial_result" % task_id)
		return {}

	if result == null:
		push_warning("CraftingManager: Null result for task %d" % task_id)
		return {}

	var trial_id := result.trial_id
	if task.current_trial_id != StringName(trial_id):
		push_warning("CraftingManager: Trial mismatch for task %d (expected %s, got %s)" % [task_id, String(task.current_trial_id), String(trial_id)])

	task.score_accumulated += result.score
	task.max_score_accumulated += result.max_score
	task.trial_results.append(result)
	_emit_task_update(task)

	task.current_trial_index += 1
	task.current_trial_id = StringName()
	task.current_trial_config = null

	if task.blueprint != null and task.current_trial_index < task.blueprint.trial_sequence.size():
		_start_next_trial(task)
		return {"status": STATUS_IN_PROGRESS}

	return _finalize_task(task)

func get_queue_snapshot() -> Array:
	var snapshot: Array = []
	for i in range(MAX_SLOTS):
		var task: CraftingTask = queue[i]
		if task == null:
			snapshot.append({
				"slot_index": i,
				"status": "empty",
			})
			continue

		var total_trials := task.blueprint.trial_sequence.size() if task.blueprint else 0
		var display_name := ""
		var blueprint_id := StringName()
		var materials := {}
		if task.blueprint:
			blueprint_id = task.blueprint.blueprint_id
			display_name = task.blueprint.display_name if task.blueprint.display_name != "" else String(task.blueprint.blueprint_id)
			materials = task.blueprint.materials
		snapshot.append({
			"slot_index": i,
			"task_id": task.id,
			"status": String(task.status),
			"blueprint": task.blueprint,
			"blueprint_id": blueprint_id,
			"display_name": display_name,
			"current_trial_index": task.current_trial_index,
			"total_trials": total_trials,
			"score": task.score_accumulated,
			"max_score": task.max_score_accumulated,
			"grade": task.grade,
			"materials": materials,
		})
	return snapshot

func _generate_task_id() -> int:
	var id := _next_task_id
	_next_task_id += 1
	return id

func _resolve_blueprint(recipe_id: StringName) -> BlueprintResource:
	if not has_node('/root/DataManager'):
		push_warning("CraftingManager: DataManager unavailable when resolving blueprint %s" % String(recipe_id))
		return null
	return get_node('/root/DataManager').get_blueprint(recipe_id)

func _start_next_trial(task: CraftingTask) -> void:
	if task == null or task.blueprint == null:
		return

	if task.current_trial_index >= task.blueprint.trial_sequence.size():
		_finalize_task(task)
		return

	var trial: TrialResource = task.blueprint.trial_sequence[task.current_trial_index]
	if trial == null:
		push_warning("CraftingManager: Blueprint %s trial %d is null" % [String(task.blueprint.blueprint_id), task.current_trial_index])
		task.current_trial_index += 1
		_start_next_trial(task)
		return

	task.status = STATUS_IN_PROGRESS
	task.current_trial_id = trial.trial_id
	var config := _resolve_trial_config(trial, task.blueprint)
	print("CraftingManager: Starting trial %s for task %d" % [String(trial.trial_id), task.id])
	_emit_task_update(task)
	task.current_trial_config = config
	# Emitir señal deferred para evitar race condition con limpieza de minijuego anterior
	call_deferred("emit_signal", "task_started", task.id, config.duplicate_config())

func _resolve_trial_config(trial: TrialResource, blueprint: BlueprintResource) -> TrialConfig:
	if trial == null:
		return null
	var config: TrialConfig = null
	if trial.config != null:
		config = trial.config.duplicate_config()
	else:
		config = TrialConfig.new()
	if config.minigame_id == StringName():
		config.minigame_id = trial.get_effective_minigame()
	if config.trial_id == StringName():
		config.trial_id = trial.trial_id
	if config.blueprint_id == StringName() and blueprint != null:
		config.blueprint_id = blueprint.blueprint_id
	if config.minigame_scene == null:
		config.minigame_scene = trial.minigame_scene
	if config.parameters == null:
		config.parameters = {}
	if config.max_score <= 0.0:
		config.max_score = 100.0
	return config

func _finalize_task(task: CraftingTask) -> Dictionary:
	if task == null:
		return {}

	task.status = STATUS_COMPLETED
	var ratio := 1.0 if task.max_score_accumulated <= 0.0 else task.score_accumulated / task.max_score_accumulated
	var grade := _determine_grade(ratio)
	task.grade = grade
	_emit_task_update(task)

	var result := {
		"status": STATUS_COMPLETED,
		"task_id": task.id,
		"grade": grade,
		"score": task.score_accumulated,
		"max_score": task.max_score_accumulated,
		"blueprint_id": task.blueprint.blueprint_id if task.blueprint else StringName(),
		"result_item": task.blueprint.result_item if task.blueprint else StringName(),
		"materials": task.blueprint.materials if task.blueprint else {},
	}

	var slot := task.slot_index
	
	# Emitir señal antes de limpiar el slot para que HUD sepa qué ítem mostrar
	emit_signal("task_completed", slot, result)
	
	print("CraftingManager: Task %d completed in slot %d, clearing slot..." % [task.id, slot])
	queue[slot] = null
	_emit_slot_cleared(slot)
	_compress_queue()
	
	# AUTO-RELLENAR: Encolar un nuevo pedido aleatorio para mantener 3 slots llenos
	print("CraftingManager: Auto-refilling slot after completion...")
	enqueue_random()
	
	return result

func _determine_grade(ratio: float) -> String:
	for grade in ["gold", "silver", "bronze"]:
		if ratio >= GRADE_THRESHOLDS[grade]:
			return grade
	return "fail"

func _find_task(task_id: int) -> CraftingTask:
	for task in queue:
		if task is CraftingTask and task.id == task_id:
			return task
	return null

func _compress_queue() -> void:
	var new_queue: Array = []
	for task in queue:
		if task != null:
			new_queue.append(task)
	while new_queue.size() < MAX_SLOTS:
		new_queue.append(null)
	queue = new_queue
	_update_slot_indices()

func _update_slot_indices() -> void:
	for i in range(queue.size()):
		var task: CraftingTask = queue[i]
		if task:
			task.slot_index = i
			_emit_task_update(task)

func _emit_task_update(task: CraftingTask) -> void:
	if task == null:
		return
	var payload := {
		"slot_index": task.slot_index,
		"status": String(task.status),
		"blueprint_id": task.blueprint.blueprint_id if task.blueprint else StringName(),
		"display_name": task.blueprint.display_name if task.blueprint and task.blueprint.display_name != "" else String(task.blueprint.blueprint_id) if task.blueprint else "",
		"current_trial_index": task.current_trial_index,
		"total_trials": task.blueprint.trial_sequence.size() if task.blueprint else 0,
		"score": task.score_accumulated,
		"max_score": task.max_score_accumulated,
		"grade": task.grade,
		"current_trial_id": String(task.current_trial_id)
	}
	emit_signal("task_updated", task.id, payload)

## FASE 1: Fusión robusta de resultados de minijuegos
## Usa media geométrica ponderada para evitar "hard carry" de un solo minijuego perfecto
func fuse_trial_results(results: Array, weights: Dictionary = {}) -> float:
	if results.is_empty():
		return 0.0
	
	var normalized_scores := []
	var total_weight := 0.0
	var active_weights := weights if not weights.is_empty() else DEFAULT_MINIGAME_WEIGHTS
	
	for result in results:
		if not (result is TrialResult):
			continue
		
		# Normalizar a 0-100
		var max_score = max(result.max_score, 1.0)  # Evitar división por 0
		var norm_score = (result.score / max_score) * 100.0
		norm_score = clamp(norm_score, 0.0, 100.0)
		
		var weight = active_weights.get(result.trial_id, 1.0)
		normalized_scores.append({"score": norm_score, "weight": weight})
		total_weight += weight
	
	if normalized_scores.is_empty() or total_weight <= 0:
		return 0.0
	
	# Media geométrica ponderada: product(score^(weight/total))
	var product := 1.0
	for item in normalized_scores:
		var normalized_weight = item.weight / total_weight
		var base = item.score / 100.0  # Normalizar a 0-1 para pow
		product *= pow(max(base, 0.01), normalized_weight)  # Evitar pow(0)
	
	return product * 100.0  # Escalar de vuelta a 0-100

func _emit_slot_cleared(slot_idx: int) -> void:
	emit_signal("task_updated", -1, {"slot_index": slot_idx, "status": "empty"})
