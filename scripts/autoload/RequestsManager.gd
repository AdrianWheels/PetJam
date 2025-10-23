# res://scripts/autoload/RequestsManager.gd
extends Node

class_name RequestsManager

## Gestiona los pedidos activos del cliente (requests)
## A diferencia de BlueprintLibraryPanel que muestra TODO lo desbloqueado,
## este manager mantiene 3-5 pedidos aleatorios activos que el jugador puede aceptar

signal requests_refreshed(active_requests: Array)
signal request_accepted(blueprint_id: StringName)

const MAX_ACTIVE_REQUESTS := 5
const MIN_ACTIVE_REQUESTS := 3

var active_requests: Array[Dictionary] = []
var _data_manager: Node

func _ready() -> void:
	print("RequestsManager: Inicializando...")
	_data_manager = get_node_or_null("/root/DataManager")
	if _data_manager and _data_manager.has_signal("data_ready"):
		print("RequestsManager: Esperando data_ready de DataManager")
		_data_manager.data_ready.connect(_on_data_ready)
	else:
		print("RequestsManager: DataManager no disponible, generando pedidos de inmediato")
		call_deferred("_generate_initial_requests")

func _on_data_ready() -> void:
	print("RequestsManager: DataManager listo, generando pedidos iniciales")
	_generate_initial_requests()

func _generate_initial_requests() -> void:
	"""Genera pedidos iniciales aleatorios de blueprints desbloqueados"""
	active_requests.clear()
	
	if not _data_manager or not _data_manager.has_method("get_unlocked_blueprints"):
		print("RequestsManager: DataManager no disponible")
		return
	
	var unlocked: Array = _data_manager.get_unlocked_blueprints()
	if unlocked.is_empty():
		print("RequestsManager: No hay blueprints desbloqueados")
		return
	
	# Generar entre MIN y MAX pedidos aleatorios
	var num_requests := randi_range(MIN_ACTIVE_REQUESTS, MAX_ACTIVE_REQUESTS)
	num_requests = min(num_requests, unlocked.size())
	
	# Mezclar y tomar los primeros N
	unlocked.shuffle()
	
	for i in range(num_requests):
		var blueprint_id: StringName = unlocked[i]
		var blueprint: BlueprintResource = _data_manager.get_blueprint(blueprint_id)
		if blueprint:
			var reward := _calculate_reward(blueprint)
			active_requests.append({
				"blueprint_id": blueprint_id,
				"blueprint": blueprint,
				"gold_reward": reward,
				"client_name": _generate_client_name()
			})
	
	print("RequestsManager: Generados %d pedidos" % active_requests.size())
	for i in range(active_requests.size()):
		var req = active_requests[i]
		print("  [%d] %s - %d oro - Cliente: %s" % [i, req.blueprint.display_name, req.gold_reward, req.client_name])
	requests_refreshed.emit(active_requests)

func accept_request(index: int) -> bool:
	"""Acepta un pedido y lo encola en CraftingManager"""
	if index < 0 or index >= active_requests.size():
		return false
	
	var request: Dictionary = active_requests[index]
	var blueprint_id: StringName = request.get("blueprint_id", StringName())
	
	# Encolar en CraftingManager
	var cm := get_node_or_null("/root/CraftingManager")
	if cm and cm.has_method("enqueue"):
		var success: bool = cm.enqueue(blueprint_id)
		if success:
			# Remover pedido aceptado y generar uno nuevo
			active_requests.remove_at(index)
			_add_new_request()
			request_accepted.emit(blueprint_id)
			requests_refreshed.emit(active_requests)
			return true
	
	return false

func _add_new_request() -> void:
	"""Añade un nuevo pedido aleatorio para mantener el pool"""
	if not _data_manager:
		return
	
	var unlocked: Array = _data_manager.get_unlocked_blueprints()
	if unlocked.is_empty():
		return
	
	# Filtrar blueprints que ya están en active_requests
	var available: Array = []
	for bp_id in unlocked:
		var already_active := false
		for req in active_requests:
			if req.get("blueprint_id") == bp_id:
				already_active = true
				break
		if not already_active:
			available.append(bp_id)
	
	if available.is_empty():
		# Todos los blueprints ya están en requests, tomar uno random
		available = unlocked.duplicate()
	
	available.shuffle()
	var blueprint_id: StringName = available[0]
	var blueprint: BlueprintResource = _data_manager.get_blueprint(blueprint_id)
	
	if blueprint:
		var reward := _calculate_reward(blueprint)
		active_requests.append({
			"blueprint_id": blueprint_id,
			"blueprint": blueprint,
			"gold_reward": reward,
			"client_name": _generate_client_name()
		})

func refresh_all_requests() -> void:
	"""Regenera todos los pedidos (útil para botón de refresh)"""
	_generate_initial_requests()

func get_active_requests() -> Array[Dictionary]:
	return active_requests.duplicate()

func _calculate_reward(blueprint: BlueprintResource) -> int:
	"""Calcula recompensa base en oro según dificultad del blueprint"""
	var base_reward := 50
	
	# Aumentar según número de materiales
	var num_materials := blueprint.materials.size()
	base_reward += num_materials * 10
	
	# Aumentar según número de trials
	var num_trials := blueprint.trial_sequence.size() if blueprint.has_method("has_trials") and blueprint.has_trials() else 1
	base_reward += num_trials * 15
	
	return base_reward

func _generate_client_name() -> String:
	"""Genera nombre aleatorio de cliente para inmersión"""
	var first_names := ["Aldric", "Brenna", "Cedric", "Dara", "Eldon", "Fiona", "Gareth", "Hilda"]
	var titles := ["el Guerrero", "la Maga", "el Explorador", "la Cazadora", "el Herrero", "la Comerciante"]
	
	return first_names[randi() % first_names.size()] + " " + titles[randi() % titles.size()]
