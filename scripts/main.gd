extends Node2D

@onready var hud_scene := preload("res://scenes/UI/HUD.tscn")
@onready var corridor_scene := preload("res://scenes/Corridor.tscn")


@onready var camera := $Camera2D
@onready var forge_area := $ForgeArea
@onready var dungeon_area := $DungeonArea
@onready var forge_ui := $ForgeUI
@onready var dungeon_ui := $DungeonUI

var hud: Node = null
var corridor: Node = null
var dungeon_hud: Node = null
@onready var fade_overlay := $FadeLayer/FadeOverlay
@onready var fade_layer := $FadeLayer

var current_area := "forge" # "forge" o "dungeon"
var forge_pos := Vector2.ZERO
var dungeon_pos := Vector2(2000, 270) # Separated more

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Main: Scene ready")
	# Instanciar HUD y Corridor
	hud = hud_scene.instantiate()
	forge_ui.add_child(hud)
	corridor = corridor_scene.instantiate()
	add_child(corridor)
	# Instanciar HUD dungeon (puedes crear una escena DungeonHUD.tscn si lo deseas)
	dungeon_hud = Control.new()
	dungeon_hud.size = Vector2(960, 60)
	dungeon_hud.position = Vector2(0, 0)
	
	var bg = ColorRect.new()
	bg.color = Color(0x11 / 255.0, 0x18 / 255.0, 0x27 / 255.0, 0.9)
	bg.size = Vector2(960, 40)
	dungeon_hud.add_child(bg)
	
	var label = Label.new()
	label.name = "InfoLabel"
	label.position = Vector2(10, 5)
	label.size = Vector2(940, 30)
	dungeon_hud.add_child(label)
	
	dungeon_ui.add_child(dungeon_hud)
	fade_overlay.size = get_viewport_rect().size
	fade_layer.visible = false
	corridor.visible = false  # Hide in forge
	forge_ui.visible = true
	dungeon_ui.visible = false

	# Conectar señales de GameManager autoload
	var gm = get_node("/root/GameManager")
	if gm:
		gm.connect("room_entered", Callable(self, "_on_room_entered"))
		gm.connect("game_over", Callable(self, "_on_game_over"))
		gm.connect("hero_died", Callable(self, "_on_hero_died"))
		gm.start_run()
	else:
		push_error("Main: GameManager not found")

	camera.position = forge_pos
	camera.zoom = Vector2(0.5, 0.5)
	print("Main: Scene ready. Área actual: Forja")

func change_area(area: String):
	_fade_out_in(func():
		if area == "forge":
			camera.position = forge_pos
			camera.zoom = Vector2(0.5, 0.5)
			current_area = "forge"
			if forge_ui:
				forge_ui.visible = true
				# Forzar visibilidad de todos los paneles y botones
				var hud_panels = ["CraftPanel", "InventoryPanel", "DeliveryButton", "BtnForge", "BtnHammer", "BtnSewOSU", "BtnQuench"]
				for panel_name in hud_panels:
					if hud.has_node(panel_name):
						hud.get_node(panel_name).visible = true
			if dungeon_ui:
				dungeon_ui.visible = false
			if corridor:
				corridor.visible = false
			if hud and hud.has_method("show_forge_panels"):
				hud.show_forge_panels()
		elif area == "dungeon":
			camera.position = dungeon_pos
			camera.zoom = Vector2(0.5, 0.5)
			current_area = "dungeon"
			if forge_ui:
				forge_ui.visible = false
				# Forzar ocultar todos los paneles y botones, incluyendo labels
				var hud_panels = ["CraftPanel", "InventoryPanel", "DeliveryButton", "BtnForge", "BtnHammer", "BtnSewOSU", "BtnQuench", "CraftLabel", "InventoryLabel"]
				for panel_name in hud_panels:
					if hud.has_node(panel_name):
						hud.get_node(panel_name).visible = false
			if dungeon_ui:
				dungeon_ui.visible = true
			if corridor:
				corridor.visible = true
			if hud and hud.has_method("hide_minigames"):
				hud.hide_minigames()
			if hud and hud.has_method("hide_forge_panels"):
				hud.hide_forge_panels()
		print("Main: Cambiando a %s" % area.capitalize())
	)

func _fade_out_in(callback):
	fade_overlay.modulate.a = 0
	fade_layer.visible = true
	var tween := get_tree().create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 1.0)
	tween.tween_interval(0.5)
	tween.tween_callback(callback)
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): fade_layer.visible = false)

func _input(event):
	if forge_ui.get_child_count() > 1:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if current_area == "forge":
				change_area("dungeon")
			else:
				change_area("forge")

func _toggle_area():
	if current_area == "forge":
		current_area = "dungeon"
		_move_camera_to(dungeon_pos)
		print("Main: Cambiando a Dungeon")
	else:
		current_area = "forge"
		_move_camera_to(forge_pos)
		print("Main: Cambiando a Forja")

func _move_camera_to(target_pos: Vector2):
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", target_pos, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_room_entered(room_idx: int):
	print("Main: Cambiando a Dungeon")
	change_area("dungeon")
	if hud and hud.has_node("Label"):
		hud.get_node("Label").text = "HUD - Room: %d" % room_idx

func _on_game_over():
	print("Main: Cambiando a Forja")
	change_area("forge")
	if hud and hud.has_node("Label"):
		hud.get_node("Label").text = "GAME OVER"

func _on_hero_died():
	print("Main: Hero died")
	if hud and hud.has_node("Label"):
		hud.get_node("Label").text = "Hero died!"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if current_area == "dungeon" and corridor and dungeon_hud:
		var hero = corridor.get_node("Hero")
		var enemy = corridor.get_node("Enemy")
		if hero and enemy:
			var state_str = "RUN" if corridor.state == 0 else "FIGHT" if corridor.state == 1 else "DEAD"
			var dps_h = hero.expected_dps()
			var dps_e = enemy.expected_dps()
			var label = dungeon_hud.get_node("InfoLabel")
			label.text = "ENEMY L%d  |  HERO HP %d/%d (DPS %.1f)  |  ENEMY HP %d/%d (DPS %.1f)  |  STATE %s" % [
				enemy.level, hero.hp, hero.max_hp, dps_h, enemy.hp, enemy.max_hp, dps_e, state_str
			]
