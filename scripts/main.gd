extends Node2D

## Script bootstrap de Main.tscn
## Estructura: HUDLayer (HUD_Main con todo el layout) + FadeLayer
## HUDMain.gd gestiona: Corridor, minijuegos, requests, blueprints, equipment.
## Este script solo: registra nodos en UIManager, inicia GameManager, fade-in y debug.

@onready var hud_layer: CanvasLayer = $HUDLayer
@onready var hud_main: Control = $HUDLayer/HUD_Main
@onready var fade_layer: CanvasLayer = $FadeLayer
@onready var fade_overlay: ColorRect = $FadeLayer/FadeOverlay

func _ready() -> void:
	# Iniciar con pantalla en negro
	fade_overlay.modulate.a = 1.0
	fade_layer.visible = true
	
	# Obtener corridor desde HUDMain (vive dentro de un SubViewport)
	var corridor: Node = null
	if hud_main and hud_main.has_method("get_corridor"):
		corridor = hud_main.get_corridor()
	
	# Registrar nodos en UIManager
	var ui_mgr = get_node_or_null("/root/UIManager")
	if ui_mgr:
		ui_mgr.register_nodes({
			"corridor": corridor,
			"hud_forge": hud_main,
			"fade_layer": fade_layer,
			"fade_overlay": fade_overlay,
		})
		ui_mgr.show_forge()
	
	# Registrar héroe y arrancar combate
	_register_game_manager(corridor)
	
	# Instanciar DebugPanel
	_setup_debug_panel()
	
	# Reproducir ambiente de forja
	_play_forge_ambient()
	
	# Fade in
	await get_tree().create_timer(0.2).timeout
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): fade_layer.visible = false)

func _register_game_manager(corridor: Node) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("Main: GameManager not found")
		return
	
	# Registrar héroe desde corridor
	if corridor:
		var hero = corridor.get_node_or_null("Hero")
		if hero:
			gm.register_hero(hero)
	
	# Arrancar el combate si no está corriendo
	if not gm.is_run_active():
		gm.start_run()

func _setup_debug_panel() -> void:
	var debug_panel_scene = load("res://scenes/UI/DebugPanel.tscn")
	if debug_panel_scene:
		var debug_layer = CanvasLayer.new()
		debug_layer.name = "DebugLayer"
		debug_layer.layer = 100
		add_child(debug_layer)
		debug_layer.add_child(debug_panel_scene.instantiate())

func _play_forge_ambient() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am == null:
		return
	var forge_ambient: AudioStream = load("res://art/sounds/sfx/minigames/forge/amb_forge_market_base.wav")
	if forge_ambient:
		am.play_music(forge_ambient, true, -12.0)

func _input(event: InputEvent) -> void:
	# Atajo debug: F5 abre comparador de animaciones
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		get_tree().change_scene_to_file("res://scenes/sandboxes/AnimationTestComparison.tscn")
