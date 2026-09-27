extends Control

## Pantalla de inicio: arte a pantalla completa, título con brillo, brasas flotando,
## botón grande que late y el récord de profundidad si hay partida guardada.

const SK := preload("res://scripts/gameplay/visual/ShapeKit.gd")

@onready var background: TextureRect = $Background
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var start_button: Button = %StartButton
@onready var record_label: Label = %RecordLabel

var _t := 0.0
var _starting := false
var _bg_base := Vector2.ZERO


func _ready() -> void:
	_bg_base = background.position
	_add_shade()
	_add_embers()
	# Entrada: título cae y se asienta, luego subtítulo y botón
	title_label.pivot_offset = title_label.size * 0.5
	title_label.modulate.a = 0.0
	title_label.scale = Vector2(1.35, 1.35)
	subtitle_label.modulate.a = 0.0
	start_button.modulate.a = 0.0
	record_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(title_label, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(subtitle_label, "modulate:a", 1.0, 0.4)
	tw.tween_property(start_button, "modulate:a", 1.0, 0.35)
	tw.tween_property(record_label, "modulate:a", 1.0, 0.35)
	_refresh_record()
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("progress_loaded"):
		gm.progress_loaded.connect(_refresh_record)


func _process(delta: float) -> void:
	_t += delta
	# Brillo lento del título y latido del botón
	# self_modulate no obliga a re-maquetar el texto (cambiar label_settings sí)
	var glow := 0.5 + 0.5 * sin(_t * 1.8)
	title_label.self_modulate = Color(1, 1, 1).lerp(Color(1.18, 1.14, 1.05), glow)
	if not _starting:
		start_button.pivot_offset = start_button.size * 0.5
		start_button.scale = Vector2.ONE * (1.0 + 0.035 * sin(_t * 3.2))
	# Deriva lenta del fondo (sensación de vida)
	background.position = _bg_base + Vector2(sin(_t * 0.15) * 14.0, cos(_t * 0.11) * 8.0)


func _refresh_record() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var best := 1
	if gm and "best_enemy_level" in gm:
		best = int(gm.best_enemy_level)
	record_label.text = tr("Mejor profundidad: sala %d") % best if best > 1 else tr("El héroe te espera en la mazmorra")


func _add_shade() -> void:
	# Oscurece arriba y abajo para que el texto se lea sobre el arte
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.62, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.15), Color(0, 0, 0, 0.2), Color(0, 0, 0, 0.88)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	var shade := TextureRect.new()
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	move_child(shade, background.get_index() + 1)


func _add_embers() -> void:
	var embers := CPUParticles2D.new()
	embers.amount = 46
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.position = Vector2(540, 2000)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(620, 40)
	embers.direction = Vector2(0.15, -1)
	embers.spread = 20.0
	embers.gravity = Vector2(0, -12)
	embers.initial_velocity_min = 80.0
	embers.initial_velocity_max = 190.0
	embers.scale_amount_min = 0.06
	embers.scale_amount_max = 0.16
	embers.texture = SK.glow_texture()
	embers.material = SK.additive_material()
	embers.color = Color(1.0, 0.62, 0.25, 0.8)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 0.8, 0.6, 0.8), Color(1, 0.5, 0.3, 0)])
	embers.color_ramp = ramp
	add_child(embers)
	move_child(embers, background.get_index() + 2)


func _on_start_button_pressed() -> void:
	if _starting:
		return
	_starting = true
	Sfx.play(&"request_accept")
	print("StartScreen: Start button pressed - fading to Main scene")
	var press := create_tween()
	press.tween_property(start_button, "scale", Vector2(0.9, 0.9), 0.06)
	press.tween_property(start_button, "scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_BACK)
	# Crear fade overlay
	var fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hacer que cubra toda la pantalla
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	# Fade out
	var tween = create_tween()
	tween.tween_interval(0.15)
	tween.tween_property(fade, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
