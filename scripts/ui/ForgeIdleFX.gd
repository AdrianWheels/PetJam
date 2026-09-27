extends Control

## Vida para el fondo de la forja cuando no hay minijuego: halo del fuego que parpadea
## y brasas que suben. Va como hijo de ForgeBackground, así que se oculta con él.

const SK := preload("res://scripts/gameplay/visual/ShapeKit.gd")

## Posición del fuego dentro del fondo (viewport de minijuegos de 1080x960)
@export var fire_center := Vector2(404, 470)

var _t := 0.0
var _glow: Sprite2D
var _core: Sprite2D
var _embers: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow = SK.make_glow(Color(1.0, 0.55, 0.2, 0.3), 300.0)
	_glow.position = fire_center
	add_child(_glow)
	_core = SK.make_glow(Color(1.0, 0.8, 0.45, 0.35), 120.0)
	_core.position = fire_center + Vector2(0, 50)
	add_child(_core)
	_embers = CPUParticles2D.new()
	_embers.amount = 26
	_embers.lifetime = 2.6
	_embers.preprocess = 2.6
	_embers.position = fire_center + Vector2(0, 80)
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(110, 18)
	_embers.direction = Vector2(0, -1)
	_embers.spread = 18.0
	_embers.gravity = Vector2(0, -30)
	_embers.initial_velocity_min = 40.0
	_embers.initial_velocity_max = 110.0
	_embers.angular_velocity_min = -90.0
	_embers.angular_velocity_max = 90.0
	_embers.scale_amount_min = 0.03
	_embers.scale_amount_max = 0.08
	_embers.texture = SK.glow_texture()
	_embers.material = SK.additive_material()
	_embers.color = Color(1.0, 0.65, 0.3, 0.9)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 0.7, 0.5, 0.7), Color(1, 0.4, 0.2, 0)])
	_embers.color_ramp = ramp
	add_child(_embers)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	# Parpadeo irregular del fuego (senos incommensurables = ruido barato)
	var flick := 0.8 + 0.12 * sin(_t * 7.3) + 0.08 * sin(_t * 17.9 + 1.3)
	_glow.modulate.a = 0.26 * flick
	_glow.scale = Vector2.ONE * (600.0 / 128.0) * (0.95 + 0.05 * flick)
	_core.modulate.a = 0.32 * flick
