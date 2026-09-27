extends Node2D

## Escenario procedural de la mazmorra: parallax por capas + biomas + atmósfera.
## Todo se dibuja con vectores (sin texturas grandes) y cada capa se cachea hasta que cambia la paleta.
## El Corridor llama a set_room(sala) y a follow_camera(pos) cada frame.

signal biome_changed(biome_index: int, display_name: String)

const SK := preload("res://scripts/gameplay/visual/ShapeKit.gd")
const LayerScript := preload("res://scripts/gameplay/visual/BackdropLayer.gd")
const TorchScript := preload("res://scripts/gameplay/visual/TorchFlame.gd")

const VIEW_SIZE := PixelView.VIEW_SIZE
const FLOOR_Y := PixelView.FLOOR_Y
const TILE := PixelView.VIEW_W
const TRANSITION_TIME := 1.4

## kind, scroll_scale, z_index, ancho de baldosa, semilla.
## Fase 1 del spec de pixel art: una capa lisa. La fase 4 vuelve a las 5 capas con teselas pixel.
const LAYERS := [
	["plain", 1.0, -60, TILE, 41],
]

var biome_index := -1
var palette: Dictionary = {}

var _layers: Array = []  # BackdropLayer (nodos de dibujo)
var _front_layer: Node2D
var _front_tween: Tween
var _torches: Array = []
var _sky: Node2D
var _screen: CanvasLayer
var _vignette: Sprite2D
var _flash_rect: ColorRect
var _tint_rect: ColorRect
var _dust: CPUParticles2D
var _dust_decor := ""  # decor con el que se configuró el polvo (cambiarlo reinicia las partículas)
var _transition_tween: Tween
var _from_palette: Dictionary = {}
var _to_palette: Dictionary = {}


func _ready() -> void:
	_build_sky()
	_build_layers()
	_build_screen_fx()
	_build_dust()
	set_biome(0, false)


# ─── Construcción ──────────────────────────────────────────────────────

func _build_sky() -> void:
	# El cielo va en pantalla (no se mueve con la cámara)
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	_sky = Node2D.new()
	_sky.set_script(LayerScript)
	sky_layer.add_child(_sky)
	_sky.setup("sky", VIEW_SIZE.x, VIEW_SIZE.y, FLOOR_Y, 7)


func _build_layers() -> void:
	for spec in LAYERS:
		var par := Parallax2D.new()
		par.scroll_scale = Vector2(spec[1], 1.0)
		par.repeat_size = Vector2(spec[3], 0.0)
		par.repeat_times = 3
		par.z_index = spec[2]
		add_child(par)
		var layer := Node2D.new()
		layer.set_script(LayerScript)
		par.add_child(layer)
		layer.setup(spec[0], spec[3], VIEW_SIZE.y, FLOOR_Y, spec[4])
		if spec[0] == "front":
			layer.modulate = Color(1, 1, 1, 0.85)
			_front_layer = layer
		if spec[0] == "pillars":
			# Antorchas sobre los soportes (una por columna)
			for i in 2:
				var torch := Node2D.new()
				torch.set_script(TorchScript)
				torch.position = Vector2(spec[3] * float(i) / 2.0, 199.0)
				par.add_child(torch)
				_torches.append(torch)
		_layers.append(layer)


func _build_screen_fx() -> void:
	_screen = CanvasLayer.new()
	_screen.layer = 5
	add_child(_screen)
	# Viñeta: centro transparente, bordes oscuros
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.72))
	grad.add_point(0.55, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.45)
	tex.fill_to = Vector2(1.05, 0.45)
	tex.width = 256
	tex.height = 128
	_vignette = Sprite2D.new()
	_vignette.texture = tex
	_vignette.centered = false
	_vignette.scale = VIEW_SIZE / Vector2(256, 128)
	_screen.add_child(_vignette)
	# Tinte (pulso rojo del jefe, etc.)
	_tint_rect = ColorRect.new()
	_tint_rect.size = VIEW_SIZE
	_tint_rect.color = Color(1, 0, 0, 0)
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint_rect.visible = false  # un rect transparente también se pinta: oculto mientras no se usa
	_screen.add_child(_tint_rect)
	# Destello a pantalla completa (críticos, muertes)
	_flash_rect = ColorRect.new()
	_flash_rect.size = VIEW_SIZE
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.visible = false
	_screen.add_child(_flash_rect)


func _build_dust() -> void:
	_dust = CPUParticles2D.new()
	_dust.amount = 36
	_dust.lifetime = 7.0
	_dust.preprocess = 7.0
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(VIEW_SIZE.x * 0.75, VIEW_SIZE.y * 0.45)
	_dust.texture = SK.glow_texture()
	_dust.material = SK.additive_material()
	_dust.scale_amount_min = 0.008  # 1-2 píxeles del arte
	_dust.scale_amount_max = 0.016
	_dust.z_index = 40
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	_dust.color_ramp = ramp
	add_child(_dust)


# ─── API ───────────────────────────────────────────────────────────────

## Sitúa el emisor de polvo con la cámara (las partículas viven en el mundo).
func follow_camera(cam_center: Vector2) -> void:
	if _dust:
		_dust.position = Vector2(cam_center.x, VIEW_SIZE.y * 0.5)


## Actualiza el bioma según la sala. Devuelve true si ha cambiado.
func set_room(room: int, animated: bool = true) -> bool:
	var idx := Biomes.biome_index_for_room(room)
	if idx == biome_index:
		return false
	set_biome(idx, animated)
	return true


func set_biome(index: int, animated: bool = true) -> void:
	var target: Dictionary = Biomes.get_biome(index)
	var changed := index != biome_index
	biome_index = index
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	if not animated or palette.is_empty():
		_apply_palette(target)
	else:
		_from_palette = palette.duplicate()
		_to_palette = target
		_transition_tween = create_tween()
		_transition_tween.tween_method(_transition_step, 0.0, 1.0, TRANSITION_TIME).set_trans(Tween.TRANS_SINE)
	if changed:
		biome_changed.emit(index, Biomes.display_name(index))


func _transition_step(t: float) -> void:
	_apply_palette(Biomes.lerp_palette(_from_palette, _to_palette, t))


func _apply_palette(p: Dictionary) -> void:
	palette = p
	_sky.set_palette(p)
	for layer in _layers:
		layer.set_palette(p)
	for torch in _torches:
		torch.set_palette(p)
	_configure_dust(p)


func _configure_dust(p: Dictionary) -> void:
	if _dust == null:
		return
	var c: Color = p.get("particle", Color.WHITE)
	_dust.color = Color(c.r, c.g, c.b, 0.55)
	# CPUParticles2D.set_amount desactiva todas las partículas: reconfigurar solo al cambiar de tipo
	var decor := String(p.get("decor", ""))
	if decor == _dust_decor:
		return
	_dust_decor = decor
	match decor:
		"lava":  # brasas que suben
			_dust.direction = Vector2(0.2, -1)
			_dust.spread = 25.0
			_dust.gravity = Vector2(0, -3.6)
			_dust.initial_velocity_min = 2.4
			_dust.initial_velocity_max = 6.0
			_dust.amount = 48
		"crystals":  # nieve que cae
			_dust.direction = Vector2(-0.3, 1)
			_dust.spread = 20.0
			_dust.gravity = Vector2(0, 2)
			_dust.initial_velocity_min = 2.0
			_dust.initial_velocity_max = 4.8
			_dust.amount = 56
		_:  # polvo/esporas flotando
			_dust.direction = Vector2(0.1, -1)
			_dust.spread = 60.0
			_dust.gravity = Vector2(0, -0.6)
			_dust.initial_velocity_min = 0.6
			_dust.initial_velocity_max = 2.4
			_dust.amount = 36
	_dust.restart()  # vuelve a ejecutar el preprocess: el aire se llena al instante


## Rellena de nuevo el polvo alrededor de la cámara (tras un salto de cámara, p. ej. al reaparecer).
func reset_dust() -> void:
	if _dust:
		_dust.restart()


## Atenúa el primer plano durante el combate para que nunca tape la pelea.
func set_foreground_dim(dim: bool) -> void:
	if _front_layer == null:
		return
	if _front_tween and _front_tween.is_valid():
		_front_tween.kill()
	_front_tween = create_tween()
	_front_tween.tween_property(_front_layer, "modulate:a", 0.22 if dim else 0.85, 0.45).set_trans(Tween.TRANS_SINE)


## Destello breve a pantalla completa (solo la franja del héroe).
func flash(color: Color = Color(1, 1, 1), strength: float = 0.35, duration: float = 0.18) -> void:
	if _flash_rect == null:
		return
	_flash_rect.color = Color(color.r, color.g, color.b, strength)
	_flash_rect.visible = true
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _flash_rect.visible = false)


## Pulso de tinte (p. ej. rojo al aparecer un jefe).
func pulse_tint(color: Color, pulses: int = 2, strength: float = 0.22, period: float = 0.5) -> void:
	if _tint_rect == null:
		return
	_tint_rect.color = Color(color.r, color.g, color.b, 0.0)
	_tint_rect.visible = true
	var tw := create_tween()
	for i in pulses:
		tw.tween_property(_tint_rect, "color:a", strength, period * 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_tint_rect, "color:a", 0.0, period * 0.65).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _tint_rect.visible = false)


func get_palette() -> Dictionary:
	return palette
