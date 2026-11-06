extends Node2D

## Llama de antorcha animada con halo aditivo. Colores tomados de la paleta del bioma.

const SK := preload("res://scripts/gameplay/visual/ShapeKit.gd")

var core := Color("fff2c4")
var mid := Color("ffb347")
var outer := Color("ff5a1f")
var light := Color("ff9a45")

var _t := 0.0
var _phase := 0.0
var _glow: Sprite2D
var _glow_small: Sprite2D


func _ready() -> void:
	_phase = randf() * TAU
	_glow = SK.make_glow(Color(light.r, light.g, light.b, 0.55), 150.0)
	_glow.position = Vector2(0, -14)
	add_child(_glow)
	_glow_small = SK.make_glow(Color(core.r, core.g, core.b, 0.5), 40.0)
	_glow_small.position = Vector2(0, -12)
	add_child(_glow_small)


func set_palette(p: Dictionary) -> void:
	core = p.get("flame_core", core)
	mid = p.get("flame_mid", mid)
	outer = p.get("flame_outer", outer)
	light = p.get("light", light)
	if _glow:
		_glow.modulate = Color(light.r, light.g, light.b, 0.55)
		_glow_small.modulate = Color(core.r, core.g, core.b, 0.5)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	# Parpadeo del halo (dos senos desfasados = ruido barato)
	var flick := 0.85 + 0.1 * sin(_t * 9.0 + _phase) + 0.06 * sin(_t * 23.0 + _phase * 2.0)
	if _glow:
		_glow.scale = Vector2.ONE * (300.0 / 128.0) * flick
		_glow.modulate.a = 0.45 + 0.12 * flick
	queue_redraw()


func _draw() -> void:
	var sway := sin(_t * 6.0 + _phase) * 3.0
	var h := 1.0 + 0.12 * sin(_t * 11.0 + _phase) + 0.06 * sin(_t * 27.0)
	_flame(Vector2.ZERO, 13.0, 34.0 * h, sway * 1.3, outer)
	_flame(Vector2(0, -1), 9.0, 25.0 * h, sway, mid)
	_flame(Vector2(0, -2), 5.0, 14.0 * h, sway * 0.6, core)


func _flame(base: Vector2, half_w: float, height: float, sway: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 10
	# Lado derecho de abajo a arriba y lado izquierdo de arriba a abajo (forma de gota)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var w := half_w * sin((1.0 - t) * PI * 0.5 + 0.35) * (1.0 - t * 0.85)
		pts.append(base + Vector2(w + sway * t * t, -height * t))
	for i in range(steps - 1, -1, -1):
		var t := float(i) / float(steps)
		var w := half_w * sin((1.0 - t) * PI * 0.5 + 0.35) * (1.0 - t * 0.85)
		pts.append(base + Vector2(-w + sway * t * t, -height * t))
	draw_colored_polygon(pts, color)
