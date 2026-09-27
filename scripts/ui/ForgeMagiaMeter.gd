extends Control
class_name ForgeMagiaMeter

## ⚡ Medidor de Forjamagia — barra vertical continua con GAME JUICE
## Se muestra durante el crafteo activo, superpuesta al MinigamePanel.
## Llena de abajo a arriba según el valor de forjamagia (0-10).
## Usa un shader de fuego para el fill principal.

signal overclock_triggered

# Colores
const COLOR_FILL_LOW := Color(0.25, 0.45, 0.75)
const COLOR_FILL_MID := Color(0.55, 0.30, 0.80)
const COLOR_FILL_HIGH := Color(0.85, 0.55, 0.15)
const COLOR_FILL_MAX := Color(1.0, 0.85, 0.2)
const COLOR_GHOST := Color(1.0, 0.95, 0.8, 0.35)
const COLOR_BG := Color(0.06, 0.05, 0.10, 0.55)
const COLOR_BORDER := Color(0.4, 0.35, 0.5, 0.35)
const COLOR_LABEL := Color(0.7, 0.7, 0.8)
const COLOR_LABEL_MAX := Color(1.0, 0.85, 0.2)
const BAR_MARGIN := 8.0
const FIRE_SHADER_PATH := "res://shaders/energy_bar_fill.gdshader"

# Estado
var _max_value := 10
var _current_value := 0
var _display_value := 0.0
var _ghost_value := 0.0
var _overclock_active := false
var _glow_timer := 0.0
var _glow_alpha := 0.0
var _flash_alpha := 0.0
var _edge_glow_time := 0.0

# Tweens
var _value_tween: Tween
var _ghost_tween: Tween
var _punch_tween: Tween
var _flash_tween: Tween

# Fire shader fill rect
var _fire_rect: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_setup_fire_fill()


func _setup_fire_fill() -> void:
	_fire_rect = ColorRect.new()
	_fire_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fire_rect.color = Color.WHITE  # Shader replaces this
	var shader := load(FIRE_SHADER_PATH) as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_fire_rect.material = mat
	add_child(_fire_rect)


func _process(delta: float) -> void:
	_edge_glow_time += delta
	if _overclock_active:
		_glow_timer += delta * 3.0
		_glow_alpha = (sin(_glow_timer) * 0.5 + 0.5) * 0.25
	else:
		_glow_alpha = maxf(0.0, _glow_alpha - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var bg_rect := Rect2(Vector2.ZERO, Vector2(w, h))
	draw_rect(bg_rect, COLOR_BG)

	var bar_x := BAR_MARGIN
	var bar_w := w - BAR_MARGIN * 2.0
	var bar_y := BAR_MARGIN
	var bar_h := h - BAR_MARGIN * 2.0 - 30.0
	if bar_h <= 0.0 or bar_w <= 0.0:
		return

	var max_f := float(_max_value)

	# ── Ghost bar ──
	var ghost_r := clampf(_ghost_value / max_f, 0.0, 1.0)
	if ghost_r > 0.001:
		var gh := bar_h * ghost_r
		draw_rect(
			Rect2(bar_x, bar_y + bar_h - gh, bar_w, gh),
			COLOR_GHOST
		)

	# ── Main fill (fire shader rect) ──
	var fill_r := clampf(_display_value / max_f, 0.0, 1.0)
	if _fire_rect:
		if fill_r > 0.001:
			_fire_rect.visible = true
			var fh := bar_h * fill_r
			_fire_rect.position = Vector2(bar_x, bar_y + bar_h - fh)
			_fire_rect.size = Vector2(bar_w, fh)
			# Adjust shader intensity based on overclock
			var mat := _fire_rect.material as ShaderMaterial
			if mat and _overclock_active:
				mat.set_shader_parameter("flame_intensity", 2.2)
				mat.set_shader_parameter("fire_speed", 3.0)
			elif mat:
				mat.set_shader_parameter("flame_intensity", 1.4)
				mat.set_shader_parameter("fire_speed", 1.8)
		else:
			_fire_rect.visible = false

	# ── Flash overlay ──
	if _flash_alpha > 0.01:
		draw_rect(
			Rect2(bar_x, bar_y, bar_w, bar_h),
			Color(1, 1, 1, _flash_alpha)
		)

	# ── Overclock glow ──
	if _glow_alpha > 0.01:
		draw_rect(
			Rect2(bar_x, bar_y, bar_w, bar_h),
			Color(COLOR_FILL_MAX.r, COLOR_FILL_MAX.g,
				COLOR_FILL_MAX.b, _glow_alpha)
		)

	# ── Border ──
	draw_rect(
		Rect2(bar_x, bar_y, bar_w, bar_h),
		COLOR_BORDER, false, 1.0
	)

	# ── Label ──
	var font := ThemeDB.fallback_font
	var fs := 18
	var lt := "⚡ %s" % tr("MÁX") if _overclock_active else "%d/%d" % [
		_current_value, _max_value
	]
	var ts := font.get_string_size(
		lt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs
	)
	var tp := Vector2((w - ts.x) / 2.0, h - BAR_MARGIN)
	var lc := COLOR_LABEL_MAX if _overclock_active else COLOR_LABEL
	draw_string(font, tp, lt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)


# ═══════════════════════════════════════════════════════════════════
#  API PÚBLICA
# ═══════════════════════════════════════════════════════════════════

## Establece el valor con juice completo
func set_value(new_value: int) -> void:
	var clamped := clampi(new_value, 0, _max_value)
	var old := _current_value
	_current_value = clamped

	# Siempre tween al valor (incluso si es el mismo — robustez)
	_tween_fill(float(clamped), clamped > old)
	_tween_ghost(float(clamped))

	# Juice solo en incrementos
	if clamped > old:
		_do_punch()
		_do_flash()

	# Overclock
	var was := _overclock_active
	_overclock_active = clamped >= _max_value
	if _overclock_active and not was:
		_glow_timer = 0.0
		_do_flash()
		overclock_triggered.emit()


## Reset al valor inicial (sin animación)
func reset() -> void:
	_current_value = 0
	_display_value = 0.0
	_ghost_value = 0.0
	_overclock_active = false
	_glow_timer = 0.0
	_glow_alpha = 0.0
	_flash_alpha = 0.0
	_kill_all_tweens()
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════
#  INTERNALS
# ═══════════════════════════════════════════════════════════════════

func _tween_fill(target: float, elastic: bool) -> void:
	if _value_tween and _value_tween.is_running():
		_value_tween.kill()
	_value_tween = create_tween()
	if elastic:
		_value_tween.set_ease(Tween.EASE_OUT)
		_value_tween.set_trans(Tween.TRANS_ELASTIC)
		_value_tween.tween_property(
			self, "_display_value", target, 0.3
		)
	else:
		_value_tween.set_ease(Tween.EASE_OUT)
		_value_tween.set_trans(Tween.TRANS_CUBIC)
		_value_tween.tween_property(
			self, "_display_value", target, 0.35
		)


func _tween_ghost(target: float) -> void:
	if _ghost_tween and _ghost_tween.is_running():
		_ghost_tween.kill()
	_ghost_tween = create_tween()
	_ghost_tween.set_ease(Tween.EASE_OUT)
	_ghost_tween.set_trans(Tween.TRANS_EXPO)
	_ghost_tween.tween_property(
		self, "_ghost_value", target, 0.55
	)


func _do_punch() -> void:
	if _punch_tween and _punch_tween.is_running():
		_punch_tween.kill()
	_punch_tween = create_tween()
	_punch_tween.set_ease(Tween.EASE_OUT)
	_punch_tween.set_trans(Tween.TRANS_BACK)
	pivot_offset = size / 2.0
	_punch_tween.tween_property(
		self, "scale", Vector2(1.12, 1.08), 0.06
	)
	_punch_tween.tween_property(
		self, "scale", Vector2.ONE, 0.14
	)


func _do_flash() -> void:
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_flash_alpha = 0.7
	_flash_tween = create_tween()
	_flash_tween.set_ease(Tween.EASE_OUT)
	_flash_tween.set_trans(Tween.TRANS_CUBIC)
	_flash_tween.tween_property(
		self, "_flash_alpha", 0.0, 0.2
	)


func _get_fill_color(ratio: float) -> Color:
	if ratio >= 0.91:
		return COLOR_FILL_MAX
	if ratio >= 0.61:
		return COLOR_FILL_HIGH.lerp(
			COLOR_FILL_MAX, (ratio - 0.61) / 0.3
		)
	if ratio >= 0.31:
		return COLOR_FILL_MID.lerp(
			COLOR_FILL_HIGH, (ratio - 0.31) / 0.3
		)
	return COLOR_FILL_LOW.lerp(COLOR_FILL_MID, ratio / 0.31)


func _kill_all_tweens() -> void:
	if _value_tween and _value_tween.is_running():
		_value_tween.kill()
	if _ghost_tween and _ghost_tween.is_running():
		_ghost_tween.kill()
	if _punch_tween and _punch_tween.is_running():
		_punch_tween.kill()
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
