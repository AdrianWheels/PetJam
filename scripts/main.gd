extends Node2D

const HUD_FORGE_SCENE := preload("res://scenes/UI/HUD_Forge.tscn")
const HUD_HERO_SCENE := preload("res://scenes/UI/HUD_Hero.tscn")
const CORRIDOR_SCENE := preload("res://scenes/Corridor.tscn")
const DUNGEON_STATUS_SCENE := preload("res://scenes/HUD/DungeonStatus.tscn")
const ITEM_INFO_PANEL_SCENE := preload("res://scenes/ForgeUI/ItemInfoPanel.tscn")

@onready var camera: Camera2D = $Camera2D
@onready var forge_ui: CanvasLayer = $ForgeUI
@onready var dungeon_ui: CanvasLayer = $DungeonUI
@onready var fade_overlay: ColorRect = $FadeLayer/FadeOverlay
@onready var fade_layer: CanvasLayer = $FadeLayer

var hud_forge: CanvasLayer
var hud_hero: CanvasLayer
var corridor: Node2D
var dungeon_status: Control
var delivery_panel: Control  # DeliveryPanel dentro de HUD_Forge
var item_info_panel: Control

var current_area: StringName = &"forge"
var forge_camera_pos := Vector2(640, 360)  # Centro de viewport 1280x720
var dungeon_camera_pos := Vector2(640, 3360)  # 3000px abajo + centro
var forge_zoom := Vector2(1.0, 1.0)  # Zoom 1:1 para ver la pantalla completa
var dungeon_zoom := Vector2(1.0, 1.0)

func _ready() -> void:
	print("Main: Scene ready")
	
	# Instanciar HUD de Forja
	hud_forge = HUD_FORGE_SCENE.instantiate()
	forge_ui.add_child(hud_forge)
	
	# Instanciar HUD de Héroe
	hud_hero = HUD_HERO_SCENE.instantiate()
	dungeon_ui.add_child(hud_hero)

	corridor = CORRIDOR_SCENE.instantiate()
	corridor.visible = false
	corridor.position = Vector2(0, 3000)  # Posicionar en área de dungeon
	add_child(corridor)

	dungeon_status = DUNGEON_STATUS_SCENE.instantiate()
	dungeon_ui.add_child(dungeon_status)
	
	# Obtener referencia al DeliveryPanel que YA EXISTE dentro de HUD_Forge
	delivery_panel = hud_forge.get_node_or_null("DeliveryPanel")
	if delivery_panel:
		print("Main: DeliveryPanel found in HUD_Forge")
		delivery_panel.visible = false
	else:
		print("Main: ERROR - DeliveryPanel NOT found in HUD_Forge!")
	
	# Instanciar ItemInfoPanel
	item_info_panel = ITEM_INFO_PANEL_SCENE.instantiate()
	forge_ui.add_child(item_info_panel)
	item_info_panel.visible = false
	print("Main: ItemInfoPanel instantiated")

	fade_overlay.size = get_viewport_rect().size
	fade_layer.visible = false
	corridor.visible = false
	
	# Inicialmente mostrar solo Forge UI
	forge_ui.visible = true
	dungeon_ui.visible = false
	hud_forge.visible = true
	hud_hero.visible = false

	if has_node("/root/UIManager"):
		var ui_mgr = get_node("/root/UIManager")
		ui_mgr.register_camera(camera, forge_camera_pos, dungeon_camera_pos, forge_zoom, dungeon_zoom)
		ui_mgr.register_nodes({
				"forge_ui": forge_ui,
				"dungeon_ui": dungeon_ui,
				"corridor": corridor,
				"hud_forge": hud_forge,
				"hud_hero": hud_hero,
				"dungeon_status": dungeon_status,
				"delivery_panel": delivery_panel,
				"item_info_panel": item_info_panel,
				"fade_layer": fade_layer,
				"fade_overlay": fade_overlay,
				"camera": camera,
				"forge_position": forge_camera_pos,
				"dungeon_position": dungeon_camera_pos,
				"forge_zoom": forge_zoom,
				"dungeon_zoom": dungeon_zoom,
		})
		print("Main: UIManager nodes registered (including delivery_panel and item_info_panel)")
		if not ui_mgr.is_connected("area_changed", Callable(self, "_on_area_changed")):
				ui_mgr.area_changed.connect(_on_area_changed)
		ui_mgr.show_forge()
	else:
		_apply_area_locally(&"forge")

	_register_game_manager()
	print("Main: Scene ready. Área actual: Forja")

func _register_game_manager() -> void:
	if not has_node("/root/GameManager"):
		push_error("Main: GameManager not found")
		return
	var gm = get_node("/root/GameManager")
	if not gm.is_connected("enemy_spawned", Callable(self, "_on_enemy_spawned")):
		gm.enemy_spawned.connect(_on_enemy_spawned)
	if not gm.is_connected("game_over", Callable(self, "_on_game_over")):
		gm.game_over.connect(_on_game_over)
	if not gm.is_connected("hero_died", Callable(self, "_on_hero_died")):
		gm.hero_died.connect(_on_hero_died)
	if not gm.is_connected("hero_respawned", Callable(self, "_on_hero_respawned")):
		gm.hero_respawned.connect(_on_hero_respawned)
	if not gm.is_connected("boss_defeated", Callable(self, "_on_boss_defeated")):
		gm.boss_defeated.connect(_on_boss_defeated)
	var hero := corridor.get_node_or_null("Hero")
	if hero:
		gm.register_hero(hero)
		# Conectar héroe al HUD de Héroe
		if hud_hero and hud_hero.has_method("set_hero"):
			hud_hero.set_hero(hero)
	gm.start_run()

func change_area(area: StringName) -> void:
		var ui_mgr = get_node_or_null("/root/UIManager")
		if ui_mgr and ui_mgr.get_current_area() == area:
				return
		if not ui_mgr and current_area == area:
				return
		_fade_out_in(func():
				var umgr = get_node_or_null("/root/UIManager")
				if umgr:
						if area == &"forge":
								umgr.show_forge()
						else:
								umgr.show_dungeon()
				else:
						_apply_area_locally(area)
		)

func _apply_area_locally(area: StringName) -> void:
	current_area = area
	var is_dungeon := area == &"dungeon"
	
	# Controlar visibilidad de CanvasLayers
	forge_ui.visible = not is_dungeon
	dungeon_ui.visible = is_dungeon
	
	# Controlar visibilidad de HUDs específicos
	if hud_forge:
		hud_forge.visible = not is_dungeon
	if hud_hero:
		hud_hero.visible = is_dungeon
	
	if corridor:
		corridor.visible = is_dungeon
		corridor.process_mode = Node.PROCESS_MODE_INHERIT if is_dungeon else Node.PROCESS_MODE_DISABLED
	
	camera.position = dungeon_camera_pos if is_dungeon else forge_camera_pos
	camera.zoom = dungeon_zoom if is_dungeon else forge_zoom
	
	# Update area indicator
	var area_name := "DUNGEON" if is_dungeon else "FORJA"
	_update_hud_label("%s (Clic derecho para cambiar)" % area_name)

func _fade_out_in(callback: Callable) -> void:
		fade_overlay.modulate.a = 0
		fade_layer.visible = true
		var tween := get_tree().create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 1.0, 1.0)
		tween.tween_interval(0.5)
		tween.tween_callback(callback)
		tween.tween_property(fade_overlay, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func(): fade_layer.visible = false)

func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				var ui_mgr = get_node_or_null("/root/UIManager")
				if ui_mgr and not ui_mgr.can_toggle_area():
						return
				var target_area := &"dungeon" if _get_current_area() == &"forge" else &"forge"
				change_area(target_area)

func _process(_delta: float) -> void:
		if _get_current_area() != &"dungeon" or corridor == null or dungeon_status == null:
				return
		var hero := corridor.get_node_or_null("Hero")
		var enemy := corridor.get_node_or_null("Enemy")
		if hero and enemy:
				dungeon_status.call("update_combat_info", hero, enemy, _corridor_state_name())

func _on_enemy_spawned(enemy_level: int) -> void:
		# NO cambiar de área automáticamente - el usuario decide con el botón
		print("Main: Enemy level %d spawned (staying in current area)" % enemy_level)
		_update_hud_label("Enemy Level: %d" % enemy_level)

func _on_game_over() -> void:
		print("Main: Cambiando a Forja")
		change_area(&"forge")
		_update_hud_label("GAME OVER")

func _on_hero_died(death_count: int) -> void:
		print("Main: Hero died (%d)" % death_count)
		_update_hud_label("Hero died! (%d)" % death_count)

func _on_hero_respawned(death_count: int) -> void:
		print("Main: Hero respawned after %d deaths" % death_count)
		_update_hud_label("Hero ready (deaths %d)" % death_count)

func _on_boss_defeated() -> void:
		print("Main: Boss defeated")
		_update_hud_label("Boss defeated!")

func _on_area_changed(new_area: StringName) -> void:
	current_area = new_area
	var is_dungeon := new_area == &"dungeon"
	var area_name := "DUNGEON" if is_dungeon else "FORJA"
	_update_hud_label("%s (Clic derecho para cambiar)" % area_name)
	
	# Si cambiamos a dungeon, actualizar stats del héroe
	if is_dungeon and hud_hero and hud_hero.has_method("update_stats"):
		hud_hero.update_stats()

func _update_hud_label(text: String) -> void:
	# Actualizar label del HUD activo según el área
	var active_hud := hud_forge if current_area == &"forge" else hud_hero
	if active_hud:
		var label: Label = active_hud.get_node_or_null("RoomLabel")
		if not label:
			label = active_hud.get_node_or_null("Label")
		if label:
			label.text = text

func _get_current_area() -> StringName:
		var ui_mgr = get_node_or_null("/root/UIManager")
		if ui_mgr:
				return ui_mgr.get_current_area()
		return current_area

func _corridor_state_name() -> String:
		if corridor == null:
				return "IDLE"
		if not "state" in corridor:
				return "UNKNOWN"
		var state_value: int = corridor.state
		match state_value:
				0: # RUN
						return "RUN"
				1: # FIGHT
						return "FIGHT"
				2: # DEAD
						return "DEAD"
				3: # COMPLETE
						return "COMPLETE"
				_:
						return "UNKNOWN"
