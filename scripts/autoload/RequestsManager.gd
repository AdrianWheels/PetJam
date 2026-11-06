# res://scripts/autoload/RequestsManager.gd
extends Node

class_name RequestsManager

## Gestiona los pedidos activos del cliente (requests)
## A diferencia de BlueprintLibraryPanel que muestra TODO lo desbloqueado,
## este manager mantiene 3-5 pedidos aleatorios activos que el jugador puede aceptar

signal requests_refreshed(active_requests: Array)
signal request_accepted(blueprint_id: StringName)
signal request_rejected_no_materials(blueprint_name: String, required_materials: Dictionary)

const MAX_ACTIVE_REQUESTS := 4
const MIN_ACTIVE_REQUESTS := 2
const REQUEST_DELAY_MIN := 3.0  # Segundos mínimos entre pedidos
const REQUEST_DELAY_MAX := 8.0  # Segundos máximos entre pedidos
const FREE_REQUESTS_COUNT := 2  # Primeros X pedidos son gratis

## Clientes: nombre → género ("m" o "f"). El título concuerda con él: "Aldric el Guerrero",
## "Brenna la Guerrera". Hombres: Aldric, Cedric, Eldon y Gareth; mujeres: Brenna, Dara, Fiona y Hilda.
const CLIENT_NAMES := {
	"Aldric": "m", "Brenna": "f", "Cedric": "m", "Dara": "f",
	"Eldon": "m", "Fiona": "f", "Gareth": "m", "Hilda": "f",
}
## Títulos por género, en español (texto base; locale/textos.csv los traduce: "la Guerrera" → "the Warrior").
const CLIENT_TITLES := [
	{"m": "el Guerrero", "f": "la Guerrera"},
	{"m": "el Mago", "f": "la Maga"},
	{"m": "el Explorador", "f": "la Exploradora"},
	{"m": "el Cazador", "f": "la Cazadora"},
	{"m": "el Herrero", "f": "la Herrera"},
	{"m": "el Mercader", "f": "la Mercader"},
]

const PREVIOUS_RANK_CHANCE := 0.2  # probabilidad de que un pedido sea del rango anterior al máximo
var rng := RandomNumberGenerator.new()
var active_requests: Array[Dictionary] = []
var free_requests_remaining: int = FREE_REQUESTS_COUNT
var _data_manager: Node
var _request_timer: Timer = null

func _ready() -> void:
	print("RequestsManager: Inicializando...")
	rng.randomize()
	_data_manager = get_node_or_null("/root/DataManager")
	
	# Crear timer para pedidos progresivos
	_request_timer = Timer.new()
	_request_timer.one_shot = true
	_request_timer.timeout.connect(_on_request_timer_timeout)
	add_child(_request_timer)
	
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
	"""Genera pedidos iniciales DE FORMA PROGRESIVA: empieza con 2 y van llegando"""
	active_requests.clear()
	
	if not _data_manager or not _data_manager.has_method("get_unlocked_blueprints"):
		print("RequestsManager: DataManager no disponible")
		return
	
	var unlocked: Array = _data_manager.get_unlocked_blueprints()
	if unlocked.is_empty():
		print("RequestsManager: No hay blueprints desbloqueados")
		return
	
	# 🎯 Empezar solo con 2 pedidos inmediatos
	unlocked.shuffle()
	var initial_count: int = min(2, unlocked.size())
	
	for i in range(initial_count):
		var blueprint_id: StringName = unlocked[i]
		if _data_manager.get_blueprint(blueprint_id):
			active_requests.append(make_request(blueprint_id))
	
	print("RequestsManager: Generados %d pedidos iniciales (2 inmediatos)" % active_requests.size())
	for i in range(active_requests.size()):
		var req = active_requests[i]
		print("  [%d] %s - %d gold - Client: %s" % [i, req.blueprint.display_name, req.gold_reward, req.client_name])
	requests_refreshed.emit(active_requests)
	
	# 🕐 Programar llegada del siguiente pedido (3-8 segundos después)
	_schedule_next_request()

## Crea un pedido de un plano desbloqueado con su rango, su receta y su oro (spec de rangos, apartado 5).
func make_request(blueprint_id: StringName) -> Dictionary:
	var blueprint: BlueprintResource = _data_manager.get_blueprint(blueprint_id)
	var rank := _pick_rank(blueprint_id)
	var tier: StringName = _data_manager.blueprint_tier(blueprint_id)
	return {
		"blueprint_id": blueprint_id,
		"blueprint": blueprint,
		"rank": rank,
		"materials": Ranks.recipe(blueprint.materials, tier, rank),
		"gold_reward": _calculate_reward(blueprint, rank),
	}.merged(_generate_client())  # client_name, client_first y client_title (la tarjeta lo traduce al enseñarlo)


func _pick_rank(blueprint_id: StringName) -> int:
	var top: int = maxi(1, _data_manager.get_unlocked_rank(blueprint_id))
	if top >= 2 and rng.randf() < PREVIOUS_RANK_CHANCE:
		return top - 1
	return top


func accept_request(index: int) -> bool:
	"""Acepta un pedido y lo encola en CraftingManager (solo si tienes materiales)"""
	if index < 0 or index >= active_requests.size():
		return false
	
	var request: Dictionary = active_requests[index]
	var blueprint_id: StringName = request.get("blueprint_id", StringName())
	var blueprint: BlueprintResource = request.get("blueprint")
	
	var is_free := free_requests_remaining > 0
	var materials: Dictionary = request.get("materials", blueprint.materials)
	
	# 🔍 DEBUG: Mostrar estado de materiales
	var inv := get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("get_materials"):
		var current_inv: Dictionary = inv.get_materials()
		print("RequestsManager: 📦 Inventario actual: %s" % str(current_inv))
		print("RequestsManager: 💎 Materiales requeridos para '%s': %s" % [blueprint.display_name, str(materials)])
	
	# 🎁 Si es gratis, no verificar materiales
	if not is_free:
		# 🛠️ Verificar que el jugador tiene los materiales necesarios
		if inv and inv.has_method("has_materials"):
			if not inv.has_materials(materials):
				print("RequestsManager: ❌ No tienes suficientes materiales para '%s'" % blueprint.display_name)
				# Emitir señal para que UI muestre error (panel rojo)
				emit_signal("request_rejected_no_materials", blueprint.display_name, materials)
				return false
		
		# 💰 Consumir materiales inmediatamente al aceptar
		if inv and inv.has_method("consume_materials"):
			if not inv.consume_materials(materials):
				print("RequestsManager: ❌ Error al consumir materiales")
				return false
			print("RequestsManager: ✅ Materiales consumidos para '%s'" % blueprint.display_name)
	else:
		print("RequestsManager: 🎁 Pedido GRATIS aceptado (%d gratis restantes)" % (free_requests_remaining - 1))
	
	# Encolar en CraftingManager
	var cm := get_node_or_null("/root/CraftingManager")
	if cm and cm.has_method("enqueue"):
		var gold_reward: int = request.get("gold_reward", 50)
		var success: bool = cm.enqueue(blueprint_id, gold_reward, int(request.get("rank", 1)))
		if success:
			# Decrementar contador de pedidos gratis
			if is_free:
				free_requests_remaining -= 1
			
			# Remover pedido aceptado
			active_requests.remove_at(index)
			request_accepted.emit(blueprint_id)
			requests_refreshed.emit(active_requests)
			
			print("RequestsManager: ✅ Pedido aceptado: '%s'" % blueprint.display_name)
			
			# 🕐 Programar llegada de nuevo pedido si no estamos al máximo
			if active_requests.size() < MAX_ACTIVE_REQUESTS:
				_schedule_next_request()
			
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
		var request := make_request(blueprint_id)
		active_requests.append(request)

		print("RequestsManager: ✨ New request added: %s - %d gold - Client: %s" % [blueprint.display_name, request.gold_reward, request.client_name])
		requests_refreshed.emit(active_requests)

func refresh_all_requests() -> void:
	"""Regenera todos los pedidos (útil para botón de refresh)"""
	_generate_initial_requests()

func get_active_requests() -> Array[Dictionary]:
	return active_requests.duplicate()

func get_free_requests_remaining() -> int:
	return free_requests_remaining

func _calculate_reward(blueprint: BlueprintResource, rank: int = 1) -> int:
	"""Recompensa base según el plano (materiales y pruebas), por el multiplicador de oro del rango"""
	var base_reward := 50
	
	# Increase based on number of materials
	var num_materials := blueprint.materials.size()
	base_reward += num_materials * 10
	
	# Increase based on number of trials
	var num_trials := blueprint.trial_sequence.size() if blueprint.has_trials() else 1
	base_reward += num_trials * 15
	
	return roundi(base_reward * Ranks.gold_mult(rank))

## Cliente al azar para el pedido. Se guardan el nombre y el título en español (texto base) y la tarjeta
## lo traduce al enseñarlo (client_display_name): así un cambio de idioma no deja clientes a medias.
## client_name es el nombre completo en español ("Brenna la Guerrera"), para los registros.
func _generate_client() -> Dictionary:
	var names: Array = CLIENT_NAMES.keys()
	var first: String = names[randi() % names.size()]
	var title: String = CLIENT_TITLES[randi() % CLIENT_TITLES.size()][CLIENT_NAMES[first]]
	return {"client_name": "%s %s" % [first, title], "client_first": first, "client_title": title}


## Nombre del cliente de un pedido en el idioma del jugador ("Brenna la Guerrera" / "Brenna the Warrior").
func client_display_name(request: Dictionary) -> String:
	var title := String(request.get("client_title", ""))
	if title == "":
		return String(request.get("client_name", ""))
	return "%s %s" % [request.get("client_first", ""), tr(title)]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🕐 SISTEMA DE DELAY PROGRESIVO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _schedule_next_request() -> void:
	"""Programa la llegada del siguiente pedido con delay aleatorio"""
	if active_requests.size() >= MAX_ACTIVE_REQUESTS:
		print("RequestsManager: Ya hay %d pedidos activos (máximo alcanzado)" % MAX_ACTIVE_REQUESTS)
		return
	
	if _request_timer and _request_timer.is_stopped():
		var delay := randf_range(REQUEST_DELAY_MIN, REQUEST_DELAY_MAX)
		_request_timer.start(delay)
		print("RequestsManager: Nuevo pedido llegará en %.1f segundos" % delay)

func _on_request_timer_timeout() -> void:
	"""Callback cuando llega un nuevo pedido"""
	_add_new_request()
	
	# Programar el siguiente pedido si no estamos al máximo
	if active_requests.size() < MAX_ACTIVE_REQUESTS:
		_schedule_next_request()
	else:
		print("RequestsManager: Pool completo (%d/%d pedidos)" % [active_requests.size(), MAX_ACTIVE_REQUESTS])

# ═══════════════════════════════════════════════════════════════════
#  PERSISTENCIA
# ═══════════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	return {
		"free_requests_remaining": free_requests_remaining,
	}

func load_save_data(data: Dictionary) -> void:
	free_requests_remaining = int(data.get("free_requests_remaining", FREE_REQUESTS_COUNT))
	print("RequestsManager: Loaded free_requests_remaining=%d" % free_requests_remaining)

