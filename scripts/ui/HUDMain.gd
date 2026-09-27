extends Control
class_name HUDMain

## Script principal del nuevo layout unificado
## Layout: Héroe arriba (25%), Minijuegos centro (50%), Controles abajo (25%)

signal minigame_requested(minigame_type: StringName)
signal blueprints_requested
signal delivery_requested
signal shop_requested
signal request_clicked(index: int)

const REQUEST_SLOT_SCENE := preload("res://scenes/UI/RequestSlot.tscn")

# Referencias a nodos
@onready var hero_viewport: SubViewport = $HeroViewPanel/HeroViewport
@onready var minigame_viewport: SubViewport = $MinigamePanel/MinigameViewport
@onready var hero_overlay: Control = $HeroViewPanel/HeroOverlay  # HUD de la franja del héroe (oro, muertes, sala…)
@onready var queue_container: HBoxContainer = $BottomLeftPanel/VBoxContainer/QueueContainer
@onready var blueprint_library: Control = $BlueprintLibraryPanel
@onready var equipment_panel: Control = $EquipmentPanel
@onready var shop_panel: Control = $ShopPanel
@onready var forjamagia_meter: Control = $ForgeMagiaMeter
@onready var forge_background: TextureRect = $MinigamePanel/MinigameViewport/ForgeBackground

# Paneles que se ocultan durante el delivery
@onready var minigames_panel: Panel = $BottomLeftPanel
@onready var bottom_right_panel: Panel = $BottomRightPanel

# Botones de minijuegos
@onready var forge_btn: Button = $BottomLeftPanel/VBoxContainer/TouchButtonsRow/ForgeBtn
@onready var hammer_btn: Button = $BottomLeftPanel/VBoxContainer/TouchButtonsRow/HammerBtn
@onready var sew_btn: Button = $BottomLeftPanel/VBoxContainer/TouchButtonsRow/SewBtn
@onready var quench_btn: Button = $BottomLeftPanel/VBoxContainer/TouchButtonsRow/QuenchBtn

# Botones del panel derecho
@onready var blueprints_btn: Button = $BottomRightPanel/VBoxContainer/BlueprintsBtn
@onready var delivery_btn: Button = $BottomRightPanel/VBoxContainer/DeliveryBtn
@onready var shop_btn: Button = $BottomRightPanel/VBoxContainer/ShopBtn

# Fila de minijuegos sueltos (solo pruebas: visible con el debug de minijuegos, Shift+P)
@onready var touch_buttons_label: Label = $BottomLeftPanel/VBoxContainer/TouchButtonsLabel
@onready var touch_buttons_row: HBoxContainer = $BottomLeftPanel/VBoxContainer/TouchButtonsRow

# Referencias externas
var _game_manager: Node
var _requests_manager: Node
var _crafting_manager: Node
var _inventory_manager: Node
var _corridor: Node

# Slots de requests activos
var _request_slots: Array[Node] = []

# Insignias de "nuevo" en los botones (Equipo: objetos forjados sin mirar; Planos: planos nuevos)
var _equip_badge: Label
var _blueprint_badge: Label
var _new_items := 0
var _new_blueprints := 0
var _known_item_count := -1
var _minigame_debug_shown := false
var _shown_request_keys: Array = []  # pedidos ya visibles (para no re-animar sus tarjetas)

func _ready() -> void:
	print("HUDMain: Ready")
	
	# Obtener managers
	_game_manager = get_node_or_null("/root/GameManager")
	_requests_manager = get_node_or_null("/root/RequestsManager")
	_crafting_manager = get_node_or_null("/root/CraftingManager")
	_inventory_manager = get_node_or_null("/root/InventoryManager")
	
	# Conectar botones de minijuegos
	if forge_btn:
		forge_btn.pressed.connect(_on_forge_pressed)
	if hammer_btn:
		hammer_btn.pressed.connect(_on_hammer_pressed)
	if sew_btn:
		sew_btn.pressed.connect(_on_sew_pressed)
	if quench_btn:
		quench_btn.pressed.connect(_on_quench_pressed)
	
	# Conectar botones del panel derecho
	if blueprints_btn:
		blueprints_btn.pressed.connect(_on_blueprints_pressed)
	if delivery_btn:
		delivery_btn.pressed.connect(_on_delivery_pressed)
	if shop_btn:
		shop_btn.pressed.connect(_on_shop_pressed)
	
	# Conectar señales del RequestsManager
	if _requests_manager:
		if _requests_manager.has_signal("requests_refreshed"):
			_requests_manager.requests_refreshed.connect(_on_requests_refreshed)
		print("HUDMain: RequestsManager connected")
	else:
		print("HUDMain: WARNING - RequestsManager not found!")
	
	# Conectar señales del CraftingManager para lanzar minijuegos
	if _crafting_manager:
		if _crafting_manager.has_signal("task_started"):
			_crafting_manager.task_started.connect(_on_task_started)
		if _crafting_manager.has_signal("task_completed"):
			_crafting_manager.task_completed.connect(_on_task_completed)
		if _crafting_manager.has_signal("forjamagia_changed"):
			_crafting_manager.forjamagia_changed.connect(_on_forjamagia_changed)
		print("HUDMain: CraftingManager connected")
	else:
		print("HUDMain: WARNING - CraftingManager not found!")
	
	# Obtener referencia al Corridor dentro del viewport
	_corridor = hero_viewport.get_node_or_null("Corridor")
	if _corridor:
		print("HUDMain: Corridor found in HeroViewport")
		# El HUD del héroe (oro, muertes, sala, carteles) escucha al corredor
		if hero_overlay and hero_overlay.has_method("bind_corridor"):
			hero_overlay.bind_corridor(_corridor)
		if _corridor.has_signal("loot_dropped"):
			_corridor.loot_dropped.connect(_on_corridor_loot)
	else:
		print("HUDMain: WARNING - Corridor not found!")
	
	# Insignias sobre los botones del panel derecho
	_equip_badge = _make_badge(delivery_btn)
	_blueprint_badge = _make_badge(blueprints_btn)
	if _inventory_manager and _inventory_manager.has_signal("crafted_items_changed"):
		_inventory_manager.crafted_items_changed.connect(_on_crafted_items_changed)
		_known_item_count = _inventory_manager.get_crafted_items().size()
	# Al cargar partida, los objetos que llegan no son "nuevos"
	if _game_manager and _game_manager.has_signal("progress_loaded"):
		_game_manager.progress_loaded.connect(_on_progress_loaded)
	_add_hero_view_frame()

	# Limpiar slots placeholder y cargar requests iniciales
	_clear_placeholder_slots()
	
	# Cargar requests después de un frame para dar tiempo al RequestsManager
	call_deferred("_load_initial_requests")

func _clear_placeholder_slots() -> void:
	# Eliminar los ColorRect placeholder del QueueContainer
	for child in queue_container.get_children():
		child.queue_free()

func _load_initial_requests() -> void:
	if _requests_manager and _requests_manager.has_method("get_active_requests"):
		var requests = _requests_manager.get_active_requests()
		_on_requests_refreshed(requests)

# ========================
# COLA DE PEDIDOS
# ========================

func _on_requests_refreshed(requests: Array) -> void:
	print("HUDMain: Requests refreshed, count: %d" % requests.size())
	
	# Limpiar slots actuales
	for slot in _request_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	_request_slots.clear()
	
	# Crear nuevos slots para cada request
	var keys: Array = []
	for i in range(min(requests.size(), 3)):  # Máximo 3 visibles
		var request = requests[i]
		var key := "%s|%s|%s" % [request.get("blueprint_id", ""), request.get("client_name", ""), request.get("gold_reward", 0)]
		keys.append(key)
		var slot = REQUEST_SLOT_SCENE.instantiate()
		slot.animate_in = not _shown_request_keys.has(key)
		queue_container.add_child(slot)
		
		# Configurar el slot (icono, materiales, recompensa, cliente, "GRATIS")
		slot.slot_index = i
		if slot.has_method("set_request"):
			slot.set_request(request)
		elif slot.has_method("set_blueprint"):
			slot.set_blueprint(request.get("blueprint"))
		
		# Conectar señal de click
		if slot.has_signal("blueprint_clicked"):
			slot.blueprint_clicked.connect(_on_request_slot_clicked)
		
		_request_slots.append(slot)
	_shown_request_keys = keys

func _on_request_slot_clicked(index: int) -> void:
	# Defensa: una tarjeta ya descartada (cola reconstruida en este frame) no acepta nada
	if index >= _request_slots.size() or not is_instance_valid(_request_slots[index]) or _request_slots[index].is_queued_for_deletion():
		return
	print("HUDMain: Request slot %d clicked" % index)
	emit_signal("request_clicked", index)
	
	# Datos de la tarjeta antes de que se reconstruya la cola
	var clicked_slot: Node = _request_slots[index] if index < _request_slots.size() else null
	var ghost_texture: Texture2D = null
	var ghost_rect := Rect2()
	if clicked_slot and is_instance_valid(clicked_slot) and "icon_rect" in clicked_slot and clicked_slot.icon_rect:
		ghost_texture = clicked_slot.icon_rect.texture
		ghost_rect = Rect2(clicked_slot.icon_rect.global_position, clicked_slot.icon_rect.size)

	# Intentar aceptar el request
	if _requests_manager and _requests_manager.has_method("accept_request"):
		var success = _requests_manager.accept_request(index)
		if success:
			_fly_request_to_forge(ghost_texture, ghost_rect)
			print("HUDMain: ✅ Request accepted! Starting crafting task...")
			# Después de encolar, iniciar el task para lanzar los minijuegos
			# El request se encola en slot 0 (el primer slot libre)
			if _crafting_manager and _crafting_manager.has_method("start_task"):
				# Buscar el slot que tiene el task recién encolado
				var queue = _crafting_manager.get_queue_snapshot() if _crafting_manager.has_method("get_queue_snapshot") else []
				for slot_info in queue:
					if slot_info.get("status") == "queued":
						var slot_idx = slot_info.get("slot_index", 0)
						print("HUDMain: Starting task in slot %d" % slot_idx)
						_crafting_manager.start_task(slot_idx)
						break
		else:
			print("HUDMain: ❌ Request rejected (no materials?)")
			if clicked_slot and is_instance_valid(clicked_slot) and clicked_slot.has_method("reject_feedback"):
				clicked_slot.reject_feedback()
			Sfx.play(&"ui_tap", 0.0, 0.55)  # "tunc" grave: no se puede

# ========================
# CALLBACKS DEL CRAFTING SYSTEM
# ========================

func _on_task_started(task_id: int, config) -> void:
	print("HUDMain: Task %d started, launching minigame..." % task_id)
	
	# Mostrar medidor de forjamagia durante trials
	if forjamagia_meter:
		forjamagia_meter.visible = true
		# Sync meter with current forjamagia
		if forjamagia_meter.has_method("set_value") and _crafting_manager:
			forjamagia_meter.set_value(_crafting_manager.forjamagia)
	
	# El config tiene la escena del minijuego o el minigame_id
	var minigame_scene: PackedScene = null
	
	if config and "minigame_scene" in config and config.minigame_scene != null:
		minigame_scene = config.minigame_scene
		print("HUDMain: Using minigame_scene from config")
	elif config and "minigame_id" in config:
		# Cargar escena según minigame_id
		var minigame_id = str(config.minigame_id)
		print("HUDMain: Loading minigame for id: %s" % minigame_id)
		match minigame_id:
			"temp", "forge":
				minigame_scene = load("res://scenes/Minigames/ForgeTemp.tscn")
			"hammer":
				minigame_scene = load("res://scenes/Minigames/HammerMinigame.tscn")
			"sew":
				minigame_scene = load("res://scenes/Minigames/SewOSU.tscn")
			"quench":
				minigame_scene = load("res://scenes/Minigames/QuenchWater.tscn")
			_:
				push_error("HUDMain: Unknown minigame_id: %s" % minigame_id)
				return
	if minigame_scene == null:
		push_error("HUDMain: Could not load minigame scene for task %d" % task_id)
		return
	
	# Ocultar fondo de forja cuando hay minijuego
	if forge_background:
		forge_background.visible = false
	
	# Limpiar viewport de minijuegos anteriores (excepto el fondo)
	for child in minigame_viewport.get_children():
		if child != forge_background:
			child.queue_free()
	
	var minigame_instance = minigame_scene.instantiate()
	
	# Hacer que el minijuego ocupe todo el espacio
	if minigame_instance is Control:
		minigame_instance.anchors_preset = Control.PRESET_FULL_RECT
		minigame_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Pasar configuración al minijuego
	if config and minigame_instance.has_method("start_trial"):
		# Usar el método estándar de MinigameBase
		minigame_instance.call_deferred("start_trial", config)
	elif config and minigame_instance.has_method("configure"):
		minigame_instance.configure(config)
	
	# ✅ CRÍTICO: Conectar señal trial_completed para reportar al CraftingManager
	if minigame_instance.has_signal("trial_completed"):
		minigame_instance.trial_completed.connect(
			func(result: TrialResult):
				_on_minigame_trial_completed(task_id, result)
		)
		print("HUDMain: Connected trial_completed signal for task %d" % task_id)
	
	# ⚡ Conectar hit_scored para actualizar forjamagia en CADA golpe
	if minigame_instance.has_signal("hit_scored"):
		minigame_instance.hit_scored.connect(_on_minigame_hit_scored)
		print("HUDMain: Connected hit_scored signal")
	
	minigame_viewport.add_child(minigame_instance)
	print("HUDMain: ✅ Minigame launched for task %d" % task_id)

func _on_minigame_trial_completed(task_id: int, result: TrialResult) -> void:
	print("HUDMain: Minigame trial completed for task %d" % task_id)
	print("  Score: %.0f / %.0f" % [result.score, result.max_score])
	
	# Reportar resultado al CraftingManager
	# NOTA: No añadir forjamagia aquí — ya se añadió por hit
	if _crafting_manager and _crafting_manager.has_method("report_trial_result"):
		var outcome = _crafting_manager.report_trial_result(task_id, result)
		print("HUDMain: Reported to CraftingManager, outcome: %s" % str(outcome))


## ⚡ Actualiza forjamagia en CADA golpe individual del minijuego
func _on_minigame_hit_scored(quality: String, _points: int) -> void:
	if not _crafting_manager:
		return
	var delta := 0
	match quality:
		"Perfect": delta = 3
		"Good": delta = 1
		"Regular": delta = 0
		"Miss": delta = -1
	if delta != 0:
		_crafting_manager.add_forjamagia(delta)

func _on_task_completed(slot_idx: int, result: Dictionary) -> void:
	print("HUDMain: Task in slot %d completed!" % slot_idx)
	
	# ── Transición: fade out minijuego + barra → resultado ──
	var minigame_node: Node = null
	for child in minigame_viewport.get_children():
		if child != forge_background:
			minigame_node = child
			break
	
	var transition_tween := create_tween()
	transition_tween.set_ease(Tween.EASE_OUT)
	transition_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Paso 1: Fade out del minijuego Y de la barra en paralelo (0.5s)
	if minigame_node and minigame_node is CanvasItem:
		transition_tween.tween_property(
			minigame_node, "modulate:a", 0.0, 0.5
		)
	if forjamagia_meter and forjamagia_meter.visible:
		transition_tween.parallel().tween_property(
			forjamagia_meter, "modulate:a", 0.0, 0.5
		)
	
	# Paso 2: Pequeña pausa tras el fade (0.3s)
	transition_tween.tween_interval(0.3)
	
	# Paso 3: Ocultar barra y mostrar resultado
	transition_tween.tween_callback(func():
		if forjamagia_meter:
			forjamagia_meter.visible = false
			forjamagia_meter.modulate.a = 1.0
		_show_craft_result(result)
	)


## Muestra la pantalla de resultado (llamada tras la transición post-trial)
func _show_craft_result(result: Dictionary) -> void:
	# Limpiar el viewport del minijuego (excepto el fondo)
	for child in minigame_viewport.get_children():
		if child != forge_background:
			child.queue_free()
	
	# NO mostrar fondo durante la pantalla de resultado
	if forge_background:
		forge_background.visible = false
	
	# Mostrar pantalla de resultado con barra de calidad animada
	var result_screen := CraftResultScreen.new()
	result_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minigame_viewport.add_child(result_screen)
	
	# Conectar señal de continuar → animar partículas + volver a idle
	result_screen.result_dismissed.connect(func(_craft_result: Dictionary):
		if forge_background:
			forge_background.visible = true
		# Animar partículas volando hacia el botón de equipamiento (esquina inferior derecha)
		_spawn_item_to_inventory_particles()
		get_tree().create_timer(0.7).timeout.connect(_update_badges)
		_on_delivery_finished()
	)
	
	# Iniciar animación del resultado
	result_screen.show_result(result)


## Limpieza post-crafteo (volver a estado idle)
func _on_delivery_finished() -> void:
	print("HUDMain: Delivery finished, returning to idle state")
	# Refrescar la lista de requests
	if _requests_manager and _requests_manager.has_method("get_active_requests"):
		var requests = _requests_manager.get_active_requests()
		_on_requests_refreshed(requests)


# ========================
# CALLBACKS DE MINIJUEGOS
# ========================

func _on_forge_pressed() -> void:
	print("HUDMain: Forge minigame requested")
	emit_signal("minigame_requested", &"forge")
	_launch_minigame("forge")

func _on_hammer_pressed() -> void:
	print("HUDMain: Hammer minigame requested")
	emit_signal("minigame_requested", &"hammer")
	_launch_minigame("hammer")

func _on_sew_pressed() -> void:
	print("HUDMain: Sew minigame requested")
	emit_signal("minigame_requested", &"sew")
	_launch_minigame("sew")

func _on_quench_pressed() -> void:
	print("HUDMain: Quench minigame requested")
	emit_signal("minigame_requested", &"quench")
	_launch_minigame("quench")

func _launch_minigame(type: String) -> void:
	# Cargar y lanzar minijuego en el viewport central
	var minigame_scene: PackedScene
	match type:
		"forge":
			minigame_scene = load("res://scenes/Minigames/ForgeTemp.tscn")
		"hammer":
			minigame_scene = load("res://scenes/Minigames/HammerMinigame.tscn")
		"sew":
			minigame_scene = load("res://scenes/Minigames/SewOSU.tscn")
		"quench":
			minigame_scene = load("res://scenes/Minigames/QuenchWater.tscn")
	
	if minigame_scene == null:
		push_error("HUDMain: Could not load minigame scene for type: " + type)
		return
	
	# Limpiar viewport y agregar nuevo minijuego
	for child in minigame_viewport.get_children():
		child.queue_free()
	
	var minigame_instance = minigame_scene.instantiate()
	minigame_viewport.add_child(minigame_instance)
	print("HUDMain: Launched minigame: " + type)

# ========================
# CALLBACKS PANEL DERECHO
# ========================

func _on_blueprints_pressed() -> void:
	print("HUDMain: Blueprints library requested")
	Sfx.play(&"ui_tap")
	_new_blueprints = 0
	_update_badges()
	emit_signal("blueprints_requested")
	if blueprint_library:
		if blueprint_library.has_method("open"):
			blueprint_library.open()
		else:
			blueprint_library.visible = true

func _on_delivery_pressed() -> void:
	print("HUDMain: Equipment panel requested")
	Sfx.play(&"ui_tap")
	_new_items = 0
	_update_badges()
	emit_signal("delivery_requested")
	if equipment_panel:
		if equipment_panel.has_method("open"):
			equipment_panel.open()
		else:
			equipment_panel.visible = true

func _on_shop_pressed() -> void:
	print("HUDMain: Shop panel requested")
	Sfx.play(&"ui_tap")
	emit_signal("shop_requested")
	if shop_panel:
		if shop_panel.has_method("open"):
			shop_panel.open()
		else:
			shop_panel.visible = true

# ========================
# ACTUALIZACIONES DE UI
# ========================
# Oro, muertes y sala los muestra HeroViewOverlay (scripts/ui/HeroViewOverlay.gd).

func _on_forjamagia_changed(value: int, _max_value: int) -> void:
	if forjamagia_meter and forjamagia_meter.has_method("set_value"):
		forjamagia_meter.set_value(value)


## Botín del corredor: los planos desbloqueados vuelan desde la mazmorra hasta el botón de Planos.
func _on_corridor_loot(kind: StringName, world_pos: Vector2, payload: Dictionary) -> void:
	if kind != &"blueprint" or blueprints_btn == null:
		return
	_new_blueprints += 1
	get_tree().create_timer(1.3).timeout.connect(_update_badges)
	# Mundo del corredor → píxeles del SubViewport → coordenadas del HUD
	var local := hero_viewport.get_canvas_transform() * world_pos
	var panel: Control = $HeroViewPanel
	var start := panel.global_position + local * (panel.size / Vector2(hero_viewport.size))
	var end := blueprints_btn.global_position + blueprints_btn.size * 0.5
	var icon := TextureRect.new()
	icon.texture = payload.get("icon") if payload.get("icon") is Texture2D else blueprints_btn.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(96, 96)
	icon.pivot_offset = icon.size * 0.5
	icon.position = start - icon.size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 100
	add_child(icon)
	var ctrl := (start + end) * 0.5 + Vector2(-220, -120)
	var tw := create_tween()
	# Salto en el sitio, pausa para que se vea y vuelo en arco hasta el botón
	tw.tween_property(icon, "scale", Vector2(1.35, 1.35), 0.18).from(Vector2(0.2, 0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_method(_make_particle_mover_ctrl(icon, start, ctrl, end), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(icon, "scale", Vector2(0.45, 0.45), 0.7)
	tw.parallel().tween_property(icon, "rotation", TAU, 0.7)
	tw.tween_callback(icon.queue_free)
	tw.tween_property(blueprints_btn, "modulate", Color(2.2, 2.0, 1.4), 0.1)
	tw.tween_property(blueprints_btn, "modulate", Color.WHITE, 0.35)
	blueprints_btn.pivot_offset = blueprints_btn.size * 0.5
	var bounce := create_tween()
	bounce.tween_interval(1.33)
	bounce.tween_property(blueprints_btn, "scale", Vector2(1.18, 1.18), 0.1)
	bounce.tween_property(blueprints_btn, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_particle_mover_ctrl(node: Control, from: Vector2, ctrl: Vector2, to: Vector2) -> Callable:
	return func(t: float) -> void:
		if is_instance_valid(node):
			node.position = _bezier_point(from, ctrl, to, t) - node.size * 0.5

# ========================
# API PÚBLICA
# ========================

## Obtiene el Corridor desde el viewport del héroe
func get_corridor() -> Node:
	return _corridor

## Obtiene el Viewport del héroe para manipulación externa
func get_hero_viewport() -> SubViewport:
	return hero_viewport

## Obtiene el Viewport de minijuegos
func get_minigame_viewport() -> SubViewport:
	return minigame_viewport

## Fuerza actualización de la cola de pedidos
func refresh_requests() -> void:
	if _requests_manager and _requests_manager.has_method("get_active_requests"):
		var requests = _requests_manager.get_active_requests()
		_on_requests_refreshed(requests)

# ========================
# ANIMACIÓN DE PARTÍCULAS
# ========================

## Genera partículas que vuelan desde el centro del MinigamePanel al botón de inventario/equipo
func _spawn_item_to_inventory_particles() -> void:
	# Origen: centro-inferior del MinigamePanel
	var mg_panel: Control = $MinigamePanel
	if not mg_panel:
		return
	var start_pos := Vector2(
		mg_panel.global_position.x + mg_panel.size.x * 0.5,
		mg_panel.global_position.y + mg_panel.size.y * 0.75
	)
	
	# Destino: centro del DeliveryBtn (botón de héroe/equipamiento)
	var end_pos := Vector2(size.x - 80, size.y - 120)  # Fallback esquina inf-derecha
	if delivery_btn:
		end_pos = delivery_btn.global_position + delivery_btn.size * 0.5
	
	# Generar 8-12 partículas con dispersión
	var particle_count := randi_range(8, 12)
	var tier_color := Color(0.4, 0.8, 1.0)  # Azul claro por defecto
	
	for i in range(particle_count):
		var particle := ColorRect.new()
		var p_size := randf_range(8.0, 18.0)
		particle.size = Vector2(p_size, p_size)
		particle.color = tier_color.lerp(Color.WHITE, randf_range(0.0, 0.4))
		particle.color.a = 1.0
		particle.position = start_pos - particle.size * 0.5
		particle.pivot_offset = particle.size * 0.5
		particle.z_index = 100
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(particle)
		
		# Delay escalonado para efecto de ráfaga
		var delay := randf_range(0.0, 0.15)
		var duration := randf_range(0.5, 0.8)
		
		# Punto de control para curva Bézier (arco hacia la derecha)
		var control_offset := Vector2(
			randf_range(-60.0, 120.0),
			randf_range(-180.0, -60.0)
		)
		var control_point := (start_pos + end_pos) * 0.5 + control_offset
		
		# Tween con movimiento curvo
		var tween := create_tween()
		tween.set_parallel(true)
		
		# Movimiento en arco usando método auxiliar
		var move_cb := _make_particle_mover(particle, start_pos, control_point, end_pos)
		tween.tween_method(move_cb, 0.0, 1.0, duration).set_delay(delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		
		# Escala: crece un poco, luego se encoge
		tween.tween_property(particle, "scale", Vector2(1.3, 1.3), duration * 0.3).set_delay(delay)
		tween.chain().tween_property(particle, "scale", Vector2(0.2, 0.2), duration * 0.7)
		
		# Fade out al final
		tween.tween_property(particle, "color:a", 0.0, duration * 0.3).set_delay(delay + duration * 0.7)
		
		# Rotación
		tween.tween_property(particle, "rotation", randf_range(TAU, TAU * 2.0), duration).set_delay(delay)
		
		# Limpiar partícula al terminar
		tween.chain().tween_callback(particle.queue_free)
	
	# Flash en el botón destino al llegar las partículas
	if delivery_btn:
		var flash_tween := create_tween()
		flash_tween.tween_interval(0.6)  # Esperar a que lleguen
		flash_tween.tween_property(delivery_btn, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.15)
		flash_tween.tween_property(delivery_btn, "modulate", Color.WHITE, 0.3)
	
	print("HUDMain: 📦 Partículas de item → inventario lanzadas")


## Calcula un punto en una curva Bézier cuadrática
func _bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	return q0.lerp(q1, t)


## Crea un Callable para mover una partícula en curva Bézier
func _make_particle_mover(particle: ColorRect, from: Vector2, ctrl: Vector2, to: Vector2) -> Callable:
	return func(t: float) -> void:
		if is_instance_valid(particle):
			var p := _bezier_point(from, ctrl, to, t)
			particle.position = p - particle.size * 0.5


# ========================
# INSIGNIAS Y FEEDBACK DE PEDIDOS
# ========================

func _process(_delta: float) -> void:
	# Fila de minijuegos de prueba: solo con el debug de minijuegos activo (Shift+P)
	var dm := get_node_or_null("/root/DebugManager")
	var show_debug: bool = dm != null and dm.show_minigame_debug
	if show_debug != _minigame_debug_shown:
		_minigame_debug_shown = show_debug
		if touch_buttons_label:
			touch_buttons_label.visible = show_debug
		if touch_buttons_row:
			touch_buttons_row.visible = show_debug


func _make_badge(button: Control) -> Label:
	if button == null:
		return null
	var badge := Label.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d9412f")
	style.border_color = Color("ffe1a8")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 0
	style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("normal", style)
	badge.add_theme_font_size_override("font_size", 24)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_constant_override("outline_size", 4)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(38, 36)
	badge.position = Vector2(button.size.x - 44, -10)
	badge.visible = false
	button.add_child(badge)
	button.resized.connect(func(): badge.position = Vector2(button.size.x - 44, -10))
	return badge


func _update_badges() -> void:
	_set_badge(_equip_badge, _new_items)
	_set_badge(_blueprint_badge, _new_blueprints)


func _set_badge(badge: Label, count: int) -> void:
	if badge == null:
		return
	var was_visible := badge.visible
	var old_text := badge.text
	badge.visible = count > 0
	badge.text = str(count) if count < 10 else "9+"
	if badge.visible and (not was_visible or old_text != badge.text):
		badge.pivot_offset = badge.size * 0.5
		var tw := create_tween()
		tw.tween_property(badge, "scale", Vector2(1.5, 1.5), 0.1).from(Vector2(0.3, 0.3))
		tw.tween_property(badge, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_crafted_items_changed(items) -> void:
	var count: int = items.size() if items is Array else 0
	if _known_item_count >= 0 and count > _known_item_count:
		# Se cuenta ya, pero la insignia se enciende al cerrar el resultado, cuando las
		# partículas del objeto llegan al botón (ver _show_craft_result)
		_new_items += count - _known_item_count
	_known_item_count = count


## Al aceptar un pedido, su icono sube desde la tarjeta hasta la forja y se funde.
func _fly_request_to_forge(texture: Texture2D, from_rect: Rect2) -> void:
	Sfx.play(&"request_accept", -1.0)
	if texture == null or from_rect.size == Vector2.ZERO:
		return
	var ghost := TextureRect.new()
	ghost.texture = texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.size = from_rect.size
	ghost.position = from_rect.position
	ghost.pivot_offset = from_rect.size * 0.5
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 90
	add_child(ghost)
	var mg_panel: Control = $MinigamePanel
	var target := mg_panel.global_position + mg_panel.size * Vector2(0.5, 0.45) - from_rect.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ghost, "position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(2.2, 2.2), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.3).set_delay(0.3)
	tw.chain().tween_callback(ghost.queue_free)


func _on_progress_loaded() -> void:
	if _inventory_manager:
		_known_item_count = _inventory_manager.get_crafted_items().size()
	_new_items = 0
	_update_badges()


## Marco entre la franja del héroe y la forja: listón de bronce y sombra sobre la forja.
func _add_hero_view_frame() -> void:
	var mg_panel: Control = $MinigamePanel
	var hero_panel: Control = $HeroViewPanel
	var edge: float = hero_panel.offset_bottom if hero_panel.offset_bottom > 0.0 else 480.0
	var shadow := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.7))
	grad.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	shadow.texture = tex
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shadow.offset_top = edge
	shadow.offset_bottom = edge + 46.0
	add_child(shadow)
	move_child(shadow, mg_panel.get_index() + 1)
	var trim := ColorRect.new()
	trim.color = Color(0.55, 0.41, 0.24, 1)
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trim.set_anchors_preset(Control.PRESET_TOP_WIDE)
	trim.offset_top = edge - 2.0
	trim.offset_bottom = edge + 3.0
	add_child(trim)
	move_child(trim, shadow.get_index() + 1)
