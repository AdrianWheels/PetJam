extends Node

signal data_ready

var blueprints: Dictionary = {}
var unlocked_ranks: Dictionary = {}  # blueprint_id -> rango máximo desbloqueado (0 = bloqueado)
var _tiers: Dictionary = {}  # blueprint_id -> Ranks.TIER_* (desde la rareza de su objeto)

const BLUEPRINT_LIBRARY_PATH := "res://data/blueprints/BlueprintLibrary.tres"

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
		# Todo empieza bloqueado: los básicos I los dan los hitos del récord al cargar la partida o al empezar
		# (GameManager.apply_record_milestones)
		unlocked_ranks[key] = 0
		var item := get_item_resource(blueprint.result_item)
		_tiers[key] = Ranks.tier_from_rarity(item.rarity if item else "basic")

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

func get_unlocked_rank(bp_id: StringName) -> int:
	return int(unlocked_ranks.get(bp_id, 0))


func is_blueprint_unlocked(bp_id: StringName) -> bool:
	return get_unlocked_rank(bp_id) >= 1


## Sube el rango desbloqueado de un plano. true si ha subido (nunca baja).
func unlock_rank(bp_id: StringName, rank: int) -> bool:
	if bp_id not in blueprints:
		push_warning("DataManager: Cannot unlock unknown blueprint '%s'" % bp_id)
		return false
	if rank <= get_unlocked_rank(bp_id):
		return false
	unlocked_ranks[bp_id] = rank
	return true


## Compatibilidad: desbloquear sin rango es desbloquear el rango I.
func unlock_blueprint(bp_id: StringName) -> bool:
	return unlock_rank(bp_id, 1)


func get_unlocked_blueprints() -> Array:
	var result := []
	for bp_id in unlocked_ranks:
		if unlocked_ranks[bp_id] >= 1:
			result.append(bp_id)
	return result


func get_locked_blueprints() -> Array:
	var result := []
	for bp_id in unlocked_ranks:
		if unlocked_ranks[bp_id] <= 0:
			result.append(bp_id)
	return result


func blueprint_tier(bp_id: StringName) -> StringName:
	return _tiers.get(bp_id, Ranks.TIER_BASIC)


func get_blueprint_ids_for_tier(tier: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for bp_id in blueprints:
		if blueprint_tier(bp_id) == tier:
			out.append(bp_id)
	return out


## Aplica hitos ({"rank", "tier"}) sin emitir señales. Devuelve los desbloqueos nuevos: [{"id", "rank"}].
func apply_milestones(milestones: Array) -> Array:
	var newly := []
	for ms in milestones:
		for bp_id in get_blueprint_ids_for_tier(ms.tier):
			if unlock_rank(bp_id, int(ms.rank)):
				newly.append({"id": bp_id, "rank": int(ms.rank)})
	return newly

# ═══════════════════════════════════════════════════════════════════
#  PERSISTENCIA
# ═══════════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	var ranks := {}
	for bp_id in unlocked_ranks:
		ranks[String(bp_id)] = unlocked_ranks[bp_id]
	return {"unlocked_ranks": ranks}


## Compatible con las versiones 1 y 2 (planos desbloqueados como bool). Cargar una partida la sustituye entera: primero todo
## bloqueado y después lo suyo; los hitos de su récord los aplica SaveManager.load_game() después.
func load_save_data(data: Dictionary) -> void:
	for bp_id in unlocked_ranks:
		unlocked_ranks[bp_id] = 0
	if data.has("unlocked_ranks"):
		var saved: Dictionary = data.get("unlocked_ranks", {})
		for bp_id_str in saved:
			var bp_id := StringName(bp_id_str)
			if bp_id in unlocked_ranks:
				unlocked_ranks[bp_id] = maxi(0, int(saved[bp_id_str]))
	else:
		# Versiones 1 y 2: planos desbloqueados como bool → rango I
		var old: Dictionary = data.get("unlocked_blueprints", {})
		for bp_id_str in old:
			var bp_id := StringName(bp_id_str)
			if bp_id in unlocked_ranks and bool(old[bp_id_str]):
				unlocked_ranks[bp_id] = 1
	print("DataManager: Loaded %d unlocked blueprints from save" % get_unlocked_blueprints().size())


## Obtiene un ItemResource por ID desde el blueprint
func get_item_resource(item_id: StringName) -> ItemResource:
	# Buscar en todos los blueprints el que tenga este result_item
	for bp_id in blueprints:
		var bp: BlueprintResource = blueprints[bp_id]
		if bp and bp.result_item == item_id:
			# Intentar cargar desde icon_path
			if bp.icon_path != "":
				var loaded = ResourceLoader.load(bp.icon_path)
				if loaded and loaded is ItemResource:
					return loaded as ItemResource
			# Fallback: crear ItemResource básico desde blueprint
			var fallback = ItemResource.new()
			fallback.item_id = item_id
			fallback.display_name = bp.display_name
			fallback.description = bp.description
			fallback.icon = bp.icon if bp.icon else null
			
			# Determinar tipo y slot basado en el id del item
			var id_str = String(item_id).to_lower()
			if id_str.contains("sword") or id_str.contains("weapon"):
				fallback.item_type = "weapon"
				fallback.equipment_slot = "main_hand"
			elif id_str.contains("shield"):
				fallback.item_type = "shield"
				fallback.equipment_slot = "off_hand"
			elif id_str.contains("helmet") or id_str.contains("helm"):
				fallback.item_type = "helmet"
				fallback.equipment_slot = "head"
			elif id_str.contains("armor") or id_str.contains("chest"):
				fallback.item_type = "armor"
				fallback.equipment_slot = "body"
			elif id_str.contains("boots") or id_str.contains("shoes"):
				fallback.item_type = "boots"
				fallback.equipment_slot = "feet"
			else:
				fallback.item_type = "accessory"
				fallback.equipment_slot = "main_hand"
			
			# Stats base por defecto
			fallback.base_damage_min = 5
			fallback.base_damage_max = 15
			fallback.base_armor_min = 2
			fallback.base_armor_max = 8
			
			print("DataManager: Created fallback ItemResource for '%s' (type: %s, slot: %s)" % [item_id, fallback.item_type, fallback.equipment_slot])
			return fallback
	
	push_warning("DataManager: ItemResource '%s' not found" % item_id)
	return null


