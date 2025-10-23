extends Node

signal data_ready

var blueprints: Dictionary = {}
var unlocked_blueprints: Dictionary = {}  # blueprint_id -> bool

const BLUEPRINT_LIBRARY_PATH := "res://data/blueprints/BlueprintLibrary.tres"

# Blueprints desbloqueados por defecto al inicio
const DEFAULT_UNLOCKED := ["sword_basic", "armor_leather", "shield_wooden"]

func _ready() -> void:
	print("DataManager: Initializing...")
	call_deferred("_load_data")

func _load_data() -> void:
	print("DataManager: Loading blueprint library...")
	_load_blueprint_library()
	print("DataManager: Data loading complete.")
	emit_signal("data_ready")

func _load_blueprint_library() -> void:
	var res := ResourceLoader.load(BLUEPRINT_LIBRARY_PATH)
	if res == null:
		push_error("DataManager: Failed to load blueprint library at %s" % BLUEPRINT_LIBRARY_PATH)
		return

	if not res.has_method("get_blueprint_ids"):
		push_error("DataManager: Resource at %s is not a BlueprintLibrary" % BLUEPRINT_LIBRARY_PATH)
		return

	blueprints.clear()
	for blueprint in res.blueprints:
		if blueprint == null:
			continue
		if not blueprint is BlueprintResource:
			push_error("DataManager: Invalid blueprint entry (not BlueprintResource): %s" % str(blueprint))
			continue
		var key: StringName = blueprint.blueprint_id
		if key == StringName() and blueprint.resource_name != "":
			key = StringName(blueprint.resource_name)
		if key == StringName():
			push_error("DataManager: Blueprint without valid id: %s" % str(blueprint))
			continue
		blueprints[key] = blueprint
		
		# Inicializar estado de desbloqueo
		if key in DEFAULT_UNLOCKED:
			unlocked_blueprints[key] = true
		else:
			unlocked_blueprints[key] = false

	print("DataManager: Loaded %d blueprints" % blueprints.size())


func get_blueprint(id: StringName):
	var result = blueprints.get(id, null)
	if result == null:
		print("DataManager: Blueprint '%s' not found" % String(id))
	else:
		print("DataManager: Retrieved blueprint '%s'" % String(id))
	return result

func get_blueprints() -> Dictionary:
	return blueprints

func get_all_blueprints() -> Dictionary:
	return blueprints

func is_blueprint_unlocked(bp_id: StringName) -> bool:
	return unlocked_blueprints.get(bp_id, false)

func unlock_blueprint(bp_id: StringName) -> bool:
	if bp_id not in blueprints:
		push_warning("DataManager: Cannot unlock unknown blueprint '%s'" % bp_id)
		return false
	
	if unlocked_blueprints.get(bp_id, false):
		print("DataManager: Blueprint '%s' already unlocked" % bp_id)
		return false
	
	unlocked_blueprints[bp_id] = true
	print("DataManager: Blueprint '%s' unlocked!" % bp_id)
	return true

func get_unlocked_blueprints() -> Array:
	var result = []
	for bp_id in unlocked_blueprints:
		if unlocked_blueprints[bp_id]:
			result.append(bp_id)
	return result

func get_locked_blueprints() -> Array:
	var result = []
	for bp_id in unlocked_blueprints:
		if not unlocked_blueprints[bp_id]:
			result.append(bp_id)
	return result
