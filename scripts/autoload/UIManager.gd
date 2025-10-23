extends Node
class_name UIManager

signal area_changed(new_area)
signal delivery_opened(item_id)
signal delivery_closed

var forge_ui: CanvasLayer
var dungeon_ui: CanvasLayer
var corridor: Node
var hud_forge: Node
var hud_hero: Node
var delivery_panel: Control
var item_info_panel: Control  # Panel de info centrado (solo visual)
var dungeon_status: Node
var result_panel: Control
var fade_layer: CanvasLayer
var fade_overlay: ColorRect
var camera: Camera2D
var forge_position: Vector2 = Vector2.ZERO
var dungeon_position: Vector2 = Vector2.ZERO
var forge_zoom: Vector2 = Vector2.ONE
var dungeon_zoom: Vector2 = Vector2.ONE
var _current_area: StringName = &"forge"
var _camera_tween: Tween
var _current_item_data: Dictionary = {}  # Guarda datos del ítem completado

var _game_manager: Node
var _data_manager: Node

func _ready() -> void:
		_game_manager = get_node_or_null("/root/GameManager")
		_data_manager = get_node_or_null("/root/DataManager")
		if _game_manager:
				if not _game_manager.is_connected("enemy_spawned", Callable(self, "_on_enemy_spawned")):
						_game_manager.enemy_spawned.connect(_on_enemy_spawned)
				if not _game_manager.is_connected("hero_died", Callable(self, "_on_hero_died")):
						_game_manager.hero_died.connect(_on_hero_died)
				if not _game_manager.is_connected("hero_respawned", Callable(self, "_on_hero_respawned")):
						_game_manager.hero_respawned.connect(_on_hero_respawned)
				if not _game_manager.is_connected("boss_defeated", Callable(self, "_on_boss_defeated")):
						_game_manager.boss_defeated.connect(_on_boss_defeated)
				if not _game_manager.is_connected("game_over", Callable(self, "_on_game_over")):
						_game_manager.game_over.connect(_on_game_over)
				if not _game_manager.is_connected("dungeon_state_changed", Callable(self, "_on_dungeon_state_changed")):
						_game_manager.dungeon_state_changed.connect(_on_dungeon_state_changed)
				if not _game_manager.is_connected("hero_loadout_changed", Callable(self, "_on_hero_loadout_changed")):
						_game_manager.hero_loadout_changed.connect(_on_hero_loadout_changed)

func register_nodes(config: Dictionary) -> void:
	forge_ui = config.get("forge_ui", forge_ui)
	dungeon_ui = config.get("dungeon_ui", dungeon_ui)
	corridor = config.get("corridor", corridor)
	hud_forge = config.get("hud_forge", hud_forge)
	hud_hero = config.get("hud_hero", hud_hero)
	delivery_panel = config.get("delivery_panel", delivery_panel)
	item_info_panel = config.get("item_info_panel", item_info_panel)
	dungeon_status = config.get("dungeon_status", dungeon_status)
	result_panel = config.get("result_panel", result_panel)
	fade_layer = config.get("fade_layer", fade_layer)
	fade_overlay = config.get("fade_overlay", fade_overlay)
	camera = config.get("camera", camera)
	forge_position = config.get("forge_position", forge_position)
	dungeon_position = config.get("dungeon_position", dungeon_position)
	forge_zoom = config.get("forge_zoom", forge_zoom)
	dungeon_zoom = config.get("dungeon_zoom", dungeon_zoom)

	# Conectar botones de delivery manualmente (DeliveryPanel es ColorRect sin script)
	if delivery_panel:
		var btn_client = delivery_panel.get_node_or_null("DeliveryVBox/DeliverHBox/Client")
		var btn_hero = delivery_panel.get_node_or_null("DeliveryVBox/DeliverHBox/Hero")
		if btn_client and not btn_client.is_connected("pressed", Callable(self, "_on_delivery_btn_client")):
			btn_client.pressed.connect(_on_delivery_btn_client)
			print("UIManager: Client button connected")
		if btn_hero and not btn_hero.is_connected("pressed", Callable(self, "_on_delivery_btn_hero")):
			btn_hero.pressed.connect(_on_delivery_btn_hero)
			print("UIManager: Hero button connected")
	
	if corridor:
		# Corridor SIEMPRE procesa para auto-farm en background
		corridor.process_mode = Node.PROCESS_MODE_INHERIT
		var hero := corridor.get_node_or_null("Hero")
		if hero and _game_manager and _game_manager.has_method("register_hero"):
			_game_manager.register_hero(hero)

	if dungeon_status:
		if _game_manager:
			#dungeon_status.call_deferred("set_total_rooms", _game_manager.total_rooms)
			dungeon_status.call_deferred("set_max_deaths", GameManager.MAX_DEATHS)
			dungeon_status.call_deferred("update_room", _game_manager.current_enemy_level)
			dungeon_status.call_deferred("update_deaths", _game_manager.death_count)
			dungeon_status.call_deferred("update_state", _dungeon_state_name(_game_manager.dungeon_state))
	if delivery_panel:
		delivery_panel.visible = false

func show_forge() -> void:
		_current_area = &"forge"
		if forge_ui:
				forge_ui.visible = true
		if dungeon_ui:
				dungeon_ui.visible = false
		if hud_forge:
				hud_forge.visible = true
		if hud_hero:
				hud_hero.visible = false
		if corridor:
				# Corridor sigue procesando en background (auto-farm)
				corridor.process_mode = Node.PROCESS_MODE_INHERIT
				corridor.visible = false
		_apply_camera_target(forge_position, forge_zoom)
		emit_signal("area_changed", _current_area)

func show_dungeon() -> void:
		_current_area = &"dungeon"
		if forge_ui:
				forge_ui.visible = false
		if dungeon_ui:
				dungeon_ui.visible = true
		if hud_forge:
				hud_forge.visible = false
		if hud_hero:
				hud_hero.visible = true
		if corridor:
				corridor.visible = true
				corridor.process_mode = Node.PROCESS_MODE_INHERIT
		_apply_camera_target(dungeon_position, dungeon_zoom)
		emit_signal("area_changed", _current_area)

func get_current_area() -> StringName:
		return _current_area

func can_toggle_area() -> bool:
		if delivery_panel and delivery_panel.visible:
				return false
		return true

func deliver_item_to_hero(item_id: StringName, slot: StringName = StringName()) -> void:
		if item_id == StringName():
				return
		if _game_manager == null:
				push_warning("UIManager: GameManager unavailable when delivering item")
				return
		_game_manager.deliver_item_to_hero(item_id, slot)

func present_delivery(result: Dictionary) -> void:
	print("UIManager: present_delivery() called with result = %s" % result)
	if delivery_panel == null:
		print("UIManager: ERROR - delivery_panel is NULL!")
		return
	var item_id: StringName = result.get("result_item", StringName())
	var blueprint_id: StringName = result.get("blueprint_id", StringName())
	var grade := String(result.get("grade", ""))
	var score := float(result.get("score", 0.0))
	var max_score := float(result.get("max_score", 0.0))
	var blueprint: BlueprintResource = null
	print("UIManager: item_id=%s, blueprint_id=%s, grade=%s" % [item_id, blueprint_id, grade])
	if _data_manager:
		blueprint = _data_manager.get_blueprint(blueprint_id)
	var payload := {
		"item_id": item_id,
		"blueprint": blueprint,
		"grade": grade,
		"score": score,
		"max_score": max_score,
		"result_item": item_id,
	}
	
	print("UIManager: Showing delivery panel...")
	# Mostrar panel de info centrado (solo visual)
	if item_info_panel:
		item_info_panel.call("show_item_info", payload)
	
	# Guardar datos del ítem para las funciones de entrega
	_current_item_data = payload.duplicate(true)
	
	# Mostrar panel de delivery (ColorRect simple, sin script)
	if delivery_panel:
		delivery_panel.visible = true
		print("UIManager: DeliveryPanel visible = true")
	
	show_forge()
	emit_signal("delivery_opened", item_id)
func is_delivery_open() -> bool:
		return delivery_panel != null and delivery_panel.visible

func register_camera(camera_node: Camera2D, forge_pos: Vector2, dungeon_pos: Vector2, forge_zoom_value: Vector2 = Vector2.ONE, dungeon_zoom_value: Vector2 = Vector2.ONE) -> void:
		camera = camera_node
		forge_position = forge_pos
		dungeon_position = dungeon_pos
		forge_zoom = forge_zoom_value
		dungeon_zoom = dungeon_zoom_value

func _apply_camera_target(target_position: Vector2, target_zoom: Vector2) -> void:
		if camera == null:
				return
		if _camera_tween and _camera_tween.is_running():
				_camera_tween.stop()
		_camera_tween = camera.get_tree().create_tween()
		_camera_tween.tween_property(camera, "position", target_position, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_camera_tween.parallel().tween_property(camera, "zoom", target_zoom, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_enemy_spawned(enemy_level: int) -> void:
		print("UIManager: Enemy level %d spawned" % enemy_level)
		if dungeon_status:
				dungeon_status.call("update_room", enemy_level)

func _on_hero_died(death_count: int) -> void:
		if dungeon_status:
				dungeon_status.call("update_deaths", death_count)
				dungeon_status.call("show_result", "¡Héroe derrotado!", Color(1, 0.45, 0.35))

func _on_hero_respawned(death_count: int) -> void:
		if dungeon_status:
				dungeon_status.call("update_deaths", death_count)
				dungeon_status.call("clear_result")

func _on_boss_defeated() -> void:
		if dungeon_status:
				dungeon_status.call("show_result", "¡Jefe derrotado!", Color(0.45, 0.95, 0.55))

func _on_game_over() -> void:
		if dungeon_status:
				dungeon_status.call("show_result", "Fin de la expedición", Color(1, 0.85, 0.35))

func _on_dungeon_state_changed(new_state: int) -> void:
		if dungeon_status:
				dungeon_status.call("update_state", _dungeon_state_name(new_state))

func _on_hero_loadout_changed(_loadout: Dictionary) -> void:
		# Ya no necesitamos esto - DeliveryPanel no tiene slot selector
		pass

func _on_delivered_to_client(item_data: Dictionary) -> void:
	# Vender ítem al cliente por oro
	var grade = item_data.get("grade", "bronze")
	var base_price = 50
	var gold_reward = base_price
	
	match grade:
		"gold":
			gold_reward = base_price * 3  # 150 oro
		"silver":
			gold_reward = base_price * 2  # 100 oro
		"bronze":
			gold_reward = base_price      # 50 oro
		_:
			gold_reward = int(base_price / 2.0)  # 25 oro
	
	var im = get_node_or_null("/root/InventoryManager")
	if im and im.has_method("add_item"):
		im.add_item("gold", gold_reward)
		print("UIManager: +%d oro recibido por grado %s" % [gold_reward, grade])
	
	# Cerrar ambos paneles
	if item_info_panel:
		item_info_panel.call("hide_info")
	if delivery_panel:
		delivery_panel.visible = false
		print("UIManager: DeliveryPanel hidden")
	
	emit_signal("delivery_closed")
	print("UIManager: Delivery completed (client), returning to IDLE state")
	
	# Volver a mostrar paneles del HUD forge (IDLE state)
	print("UIManager: hud_forge = %s" % hud_forge)
	if hud_forge:
		print("UIManager: hud_forge found, restoring panels visibility...")
		# Acceder directamente a los nodos y hacerlos visibles
		var panels = ["MinigamesPanel", "BlueprintQueuePanel", "InventoryPanel"]
		for panel_name in panels:
			var panel = hud_forge.get_node_or_null(panel_name)
			print("UIManager: Looking for %s... %s" % [panel_name, "found" if panel else "NOT FOUND"])
			if panel:
				panel.visible = true
				print("UIManager: %s.visible = true" % panel_name)
	else:
		print("UIManager: ERROR - hud_forge is NULL, cannot restore panels!")

func _on_delivered_to_hero(item_data: Dictionary) -> void:
	# Agregar ítem al inventario del héroe
	var item_id = item_data.get("result_item", "unknown_item")
	var grade = item_data.get("grade", "bronze")
	
	var im = get_node_or_null("/root/InventoryManager")
	if im and im.has_method("add_item"):
		im.add_item(item_id, 1)
		print("UIManager: Ítem '%s' (grado %s) agregado al inventario del héroe" % [item_id, grade])
	
	# Cerrar ambos paneles
	if item_info_panel:
		item_info_panel.call("hide_info")
	if delivery_panel:
		delivery_panel.visible = false
		print("UIManager: DeliveryPanel hidden")
	
	emit_signal("delivery_closed")
	print("UIManager: Delivery completed (hero), returning to IDLE state")
	
	# Volver a mostrar paneles del HUD forge (IDLE state)
	print("UIManager: hud_forge = %s" % hud_forge)
	if hud_forge:
		print("UIManager: hud_forge found, restoring panels visibility...")
		# Acceder directamente a los nodos y hacerlos visibles
		var panels = ["MinigamesPanel", "BlueprintQueuePanel", "InventoryPanel"]
		for panel_name in panels:
			var panel = hud_forge.get_node_or_null(panel_name)
			print("UIManager: Looking for %s... %s" % [panel_name, "found" if panel else "NOT FOUND"])
			if panel:
				panel.visible = true
				print("UIManager: %s.visible = true" % panel_name)
	else:
		print("UIManager: ERROR - hud_forge is NULL, cannot restore panels!")

func _on_delivery_cancelled() -> void:
	# Cerrar ambos paneles
	if item_info_panel:
		item_info_panel.call("hide_info")
	if delivery_panel:
		delivery_panel.visible = false
	
	emit_signal("delivery_closed")

## Manejadores de botones del DeliveryPanel (ColorRect sin script)
func _on_delivery_btn_client() -> void:
	print("UIManager: Client button clicked")
	_on_delivered_to_client(_current_item_data)

func _on_delivery_btn_hero() -> void:
	print("UIManager: Hero button clicked")
	_on_delivered_to_hero(_current_item_data)

func _dungeon_state_name(state: int) -> String:
		if _game_manager == null:
				return "Desconocido"
		var keys := GameManager.DungeonState.keys()
		if state >= 0 and state < keys.size():
				return String(keys[state]).capitalize()
		return "Desconocido"

func _open_blueprint_library() -> void:
		# Abrir panel de PEDIDOS (requests), no biblioteca de blueprints
		var requests_panel: Control = null
		
		# Buscar RequestsPanel en hud_forge
		if hud_forge:
				requests_panel = hud_forge.get_node_or_null("RequestsPanel")
		
		# Buscar en forge_ui como fallback
		if not requests_panel and forge_ui:
				requests_panel = forge_ui.get_node_or_null("RequestsPanel")
		
		if requests_panel and requests_panel.has_method("open"):
				requests_panel.call_deferred("open")
				print("UIManager: Abriendo panel de pedidos para elegir siguiente trabajo")
		else:
				print("UIManager: RequestsPanel no encontrado, usando fallback")
				# Fallback: abrir BlueprintLibraryPanel si existe
				var library_panel: Control = null
				if hud_forge:
						library_panel = hud_forge.get_node_or_null("BlueprintLibraryPanel")
				if not library_panel and forge_ui:
						library_panel = forge_ui.get_node_or_null("BlueprintLibraryPanel")
				if library_panel and library_panel.has_method("open"):
						library_panel.call_deferred("open")
