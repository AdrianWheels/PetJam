extends Node

class_name CraftingManager

const TrialResult = preload("res://scripts/data/TrialResult.gd")
const TrialConfig = preload("res://scripts/data/TrialConfig.gd")

signal craft_enqueued(slot_idx, recipe_id)
signal task_started(task_id, config)
signal task_updated(task_id, payload)

const MAX_SLOTS := 3
const STATUS_QUEUED := &"queued"
const STATUS_IN_PROGRESS := &"in_progress"
const STATUS_COMPLETED := &"completed"

const GRADE_THRESHOLDS := {
    "gold": 0.9,
    "silver": 0.7,
    "bronze": 0.4,
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

    # Enqueue default blueprints
    var default_blueprints = ["sword_basic", "armor_leather", "shield_wooden"]
    for recipe_id in default_blueprints:
        enqueue(recipe_id)

    print("CraftingManager: Ready with %d slots and default blueprints enqueued" % MAX_SLOTS)

func enqueue(recipe_id) -> bool:
    var blueprint := _resolve_blueprint(StringName(str(recipe_id)))
    if blueprint == null:
        push_warning("CraftingManager: Cannot enqueue recipe '%s' without blueprint" % recipe_id)
        return false

    for i in range(MAX_SLOTS):
        if queue[i] == null:
            var task := CraftingTask.new(_generate_task_id(), blueprint, i)
            queue[i] = task
            emit_signal("craft_enqueued", i, recipe_id)
            print("CraftingManager: Enqueued recipe '%s' in slot %d" % [recipe_id, i])
            if has_node('/root/Logger'):
                get_node('/root/Logger').info("CraftingManager: Enqueued", {"slot": i, "recipe": recipe_id, "task_id": task.id})
            _emit_task_update(task)
            if task.blueprint.has_trials():
                _start_next_trial(task)
            else:
                _finalize_task(task)
            return true

    print("CraftingManager: No free slots for recipe '%s'" % recipe_id)
    return false

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
    if has_node('/root/Logger'):
        get_node('/root/Logger').info("CraftingManager: Cancelled", {"slot": slot_idx, "task_id": task.id})
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
    if has_node('/root/Logger'):
        get_node('/root/Logger').info("CraftingManager: Task started", {"task_id": task.id, "trial_id": trial.trial_id, "slot": task.slot_index})
    _emit_task_update(task)
    task.current_trial_config = config
    emit_signal("task_started", task.id, config.duplicate_config())

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
    queue[slot] = null
    _emit_slot_cleared(slot)
    _compress_queue()
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
        "materials": task.blueprint.materials if task.blueprint else {},
    }
    emit_signal("task_updated", task.id, payload)

func _emit_slot_cleared(slot_idx: int) -> void:
    emit_signal("task_updated", -1, {"slot_index": slot_idx, "status": "empty"})
