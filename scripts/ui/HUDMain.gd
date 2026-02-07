extends Control
class_name HUDMain

## Script principal del nuevo layout unificado
## Layout: Héroe arriba (25%), Minijuegos centro (50%), Controles abajo (25%)

signal minigame_requested(minigame_type: StringName)
signal blueprints_requested
signal delivery_requested
signal request_clicked(index: int)

const REQUEST_SLOT_SCENE := preload("res://scenes/UI/RequestSlot.tscn")

# Referencias a nodos
@onready var hero_viewport: SubViewport = $HeroViewPanel/HeroViewport
@onready var minigame_viewport: SubViewport = $MinigamePanel/MinigameViewport
@onready var room_label: Label = $HeroViewPanel/HeroOverlay/RoomLabel
@onready var death_label: Label = $HeroViewPanel/HeroOverlay/DeathLabel
@onready var queue_container: HBoxContainer = $BottomLeftPanel/VBoxContainer/QueueContainer
@onready var blueprint_library: Control = $BlueprintLibraryPanel
@onready var equipment_panel: Control = $EquipmentPanel
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
@onready var blueprints_btn: TextureButton = $BottomRightPanel/VBoxContainer/BlueprintsBtn
@onready var delivery_btn: TextureButton = $BottomRightPanel/VBoxContainer/DeliveryBtn

# Referencias externas
var _game_manager: Node
var _requests_manager: Node
var _crafting_manager: Node
var _corridor: Node

# Slots de requests activos
var _request_slots: Array[Node] = []

func _ready() -> void:
	print("HUDMain: Ready")
	
	# Obtener managers
	_game_manager = get_node_or_null("/root/GameManager")
	_requests_manager = get_node_or_null("/root/RequestsManager")
	_crafting_manager = get_node_or_null("/root/CraftingManager")
	
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
	
	# Conectar señales del GameManager
	if _game_manager:
		if _game_manager.has_signal("enemy_level_changed"):
			_game_manager.enemy_level_changed.connect(_on_enemy_level_changed)
		if _game_manager.has_signal("hero_died"):
			_game_manager.hero_died.connect(_on_hero_died)
		if _game_manager.has_signal("hero_respawned"):
			_game_manager.hero_respawned.connect(_on_hero_respawned)
	
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
		print("HUDMain: CraftingManager connected")
	else:
		print("HUDMain: WARNING - CraftingManager not found!")
	
	# Obtener referencia al Corridor dentro del viewport
	_corridor = hero_viewport.get_node_or_null("Corridor")
	if _corridor:
		print("HUDMain: Corridor found in HeroViewport")
	else:
		print("HUDMain: WARNING - Corridor not found!")
	
	# Inicializar UI
	_update_room_label(1)
	_update_death_label(0)
	
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

func _process(_delta: float) -> void:
	# Actualizar info del combate si hay corridor
	if _corridor and "level" in _corridor:
		_update_room_label(_corridor.level)

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
	for i in range(min(requests.size(), 3)):  # Máximo 3 visibles
		var request = requests[i]
		var slot = REQUEST_SLOT_SCENE.instantiate()
		queue_container.add_child(slot)
		
		# Configurar el slot
		slot.slot_index = i
		if slot.has_method("set_blueprint"):
			slot.set_blueprint(request.get("blueprint"))
		
		# Conectar señal de click
		if slot.has_signal("blueprint_clicked"):
			slot.blueprint_clicked.connect(_on_request_slot_clicked)
		
		_request_slots.append(slot)

func _on_request_slot_clicked(index: int) -> void:
	print("HUDMain: Request slot %d clicked" % index)
	emit_signal("request_clicked", index)
	
	# Intentar aceptar el request
	if _requests_manager and _requests_manager.has_method("accept_request"):
		var success = _requests_manager.accept_request(index)
		if success:
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

# ========================
# CALLBACKS DEL CRAFTING SYSTEM
# ========================

func _on_task_started(task_id: int, config) -> void:
	print("HUDMain: Task %d started, launching minigame..." % task_id)
	
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
	
	minigame_viewport.add_child(minigame_instance)
	print("HUDMain: ✅ Minigame launched for task %d" % task_id)

func _on_minigame_trial_completed(task_id: int, result: TrialResult) -> void:
	print("HUDMain: Minigame trial completed for task %d" % task_id)
	print("  Score: %.0f / %.0f" % [result.score, result.max_score])
	
	# Reportar resultado al CraftingManager
	if _crafting_manager and _crafting_manager.has_method("report_trial_result"):
		var outcome = _crafting_manager.report_trial_result(task_id, result)
		print("HUDMain: Reported to CraftingManager, outcome: %s" % str(outcome))

func _on_task_completed(slot_idx: int, result: Dictionary) -> void:
	print("HUDMain: Task in slot %d completed!" % slot_idx)
	
	# Limpiar el viewport del minijuego (excepto el fondo)
	for child in minigame_viewport.get_children():
		if child != forge_background:
			child.queue_free()
	
	# Mostrar el fondo de forja de nuevo
	if forge_background:
		forge_background.visible = true
	
	# Mostrar mensaje de completado brevemente
	var result_label = Label.new()
	result_label.anchors_preset = Control.PRESET_CENTER
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 28)
	if result.has("grade"):
		result_label.text = "✨ Completado!\nGrade: %s" % result.get("grade", "?").to_upper()
	else:
		result_label.text = "✨ Completado!"
	minigame_viewport.add_child(result_label)
	
	# Remover label después de 2 segundos
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(result_label):
			result_label.queue_free()
	)

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
	emit_signal("blueprints_requested")
	if blueprint_library:
		if blueprint_library.has_method("open"):
			blueprint_library.open()
		else:
			blueprint_library.visible = true

func _on_delivery_pressed() -> void:
	print("HUDMain: Equipment panel requested")
	emit_signal("delivery_requested")
	if equipment_panel:
		if equipment_panel.has_method("open"):
			equipment_panel.open()
		else:
			equipment_panel.visible = true

# ========================
# ACTUALIZACIONES DE UI
# ========================

func _update_room_label(room: int) -> void:
	if room_label:
		room_label.text = "Sala %d/8" % room

func _update_death_label(deaths: int) -> void:
	if death_label:
		death_label.text = "Muertes: %d" % deaths

func _on_enemy_level_changed(new_level: int) -> void:
	_update_room_label(new_level)

func _on_hero_died(death_count: int) -> void:
	_update_death_label(death_count)

func _on_hero_respawned(death_count: int) -> void:
	_update_death_label(death_count)

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
