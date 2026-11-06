extends Control
class_name JuicyBar

## 🔥 JuicyBar — High-Energy Momentum Gauge
## Reusable "game juice" bar: ghost trail, elastic fill, impact punch,
## shake, leading-edge glow, threshold flash, and MAX idle loop.
## Works both horizontal and vertical via `is_horizontal`.

# ═══════════════════════════════════════════════════════════════════
#  SIGNALS
# ═══════════════════════════════════════════════════════════════════

signal threshold_crossed(threshold: float)  ## Emitted when 0.25, 0.50, 0.75, or 1.0 is first crossed
signal value_maxed                           ## Emitted when value reaches max

# ═══════════════════════════════════════════════════════════════════
#  EXPORTED — tune in inspector
# ═══════════════════════════════════════════════════════════════════

@export var is_horizontal := true            ## false = vertical (bottom→top)
@export var bar_color := Color(0.2, 0.85, 0.35, 1.0)
@export var ghost_color := Color(1.0, 0.95, 0.7, 0.45)
@export var bg_color := Color(0.15, 0.15, 0.2, 1.0)
@export var border_color := Color(0.3, 0.28, 0.4, 0.7)
@export var corner_radius := 6.0
@export var border_width := 2.0

## Juice toggles (disable individually for less intense bars)
@export_group("Juice Settings")
@export var enable_ghost := true
@export var enable_elastic := true
@export var enable_punch := true
@export var enable_shake := true
@export var enable_glow := true
@export var enable_flash := true
@export var enable_max_idle := true

## Timing
@export_group("Timing")
@export var elastic_duration := 0.18
@export var ghost_duration := 0.55
@export var punch_scale := 1.15
@export var punch_duration := 0.2
@export var shake_strength := 5.0
@export var shake_duration := 0.15

# ═══════════════════════════════════════════════════════════════════
#  INTERNAL STATE
# ═══════════════════════════════════════════════════════════════════

var _max_value := 1.0
var _current_value := 0.0
var _display_value := 0.0          ## Main bar (elastic)
var _ghost_value := 0.0            ## Ghost bar (slower follow)
var _glow_time := 0.0              ## Timer for glow/pulse
var _is_at_max := false
var _last_threshold_crossed := -1  ## Track which threshold was last crossed

## Tweens
var _fill_tween: Tween
var _ghost_tween: Tween
var _punch_tween: Tween
var _shake_tween: Tween
var _flash_alpha := 0.0
var _flash_tween: Tween

## Shake state
var _shake_offset := Vector2.ZERO
var _original_pos := Vector2.ZERO
var _pos_captured := false


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_glow_time += delta

	# Idle MAX pulsing
	if _is_at_max and enable_max_idle:
		pass  # drawn in _draw via sin(_glow_time)

	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	# ── Background ──
	draw_rect(rect, bg_color)

	# ── Ghost bar (behind main) ──
	if enable_ghost and _ghost_value > 0.001:
		var ghost_rect := _get_fill_rect(rect, _ghost_value / _max_value)
		draw_rect(ghost_rect, ghost_color)

	# ── Main fill ──
	var ratio := clampf(_display_value / _max_value, 0.0, 1.0)
	if ratio > 0.001:
		var fill_rect := _get_fill_rect(rect, ratio)
		draw_rect(fill_rect, bar_color)

		# ── Leading edge glow ──
		if enable_glow:
			_draw_leading_edge(fill_rect, rect)

	# ── Flash overlay ──
	if _flash_alpha > 0.01:
		draw_rect(rect, Color(1, 1, 1, _flash_alpha))

	# ── MAX idle glow ──
	if _is_at_max and enable_max_idle:
		var pulse := (sin(_glow_time * 4.0) * 0.5 + 0.5) * 0.18
		# Rainbow hue shift
		var hue := fmod(_glow_time * 0.15, 1.0)
		var max_color := Color.from_hsv(hue, 0.6, 1.0, pulse)
		draw_rect(rect, max_color)

	# ── Border ──
	draw_rect(rect, border_color, false, border_width)


# ═══════════════════════════════════════════════════════════════════
#  PUBLIC API
# ═══════════════════════════════════════════════════════════════════

## Set value with full juice animation
func set_value(new_val: float, max_val: float = -1.0, animate: bool = true) -> void:
	if max_val > 0.0:
		_max_value = max_val
	var clamped := clampf(new_val, 0.0, _max_value)
	var old_value := _current_value
	_current_value = clamped

	if not animate:
		_display_value = clamped
		_ghost_value = clamped
		_check_thresholds(old_value, clamped)
		_check_max(clamped)
		queue_redraw()
		return

	var increasing := clamped > old_value

	# ── Main fill tween (Elastic) ──
	if _fill_tween and _fill_tween.is_running():
		_fill_tween.kill()
	_fill_tween = create_tween()
	if enable_elastic and increasing:
		_fill_tween.set_ease(Tween.EASE_OUT)
		_fill_tween.set_trans(Tween.TRANS_ELASTIC)
		_fill_tween.tween_property(self, "_display_value", clamped, elastic_duration)
	else:
		_fill_tween.set_ease(Tween.EASE_OUT)
		_fill_tween.set_trans(Tween.TRANS_CUBIC)
		_fill_tween.tween_property(self, "_display_value", clamped, 0.3)

	# ── Ghost bar tween (slower follow) ──
	if enable_ghost:
		if _ghost_tween and _ghost_tween.is_running():
			_ghost_tween.kill()
		_ghost_tween = create_tween()
		_ghost_tween.set_ease(Tween.EASE_OUT)
		_ghost_tween.set_trans(Tween.TRANS_EXPO)
		_ghost_tween.tween_property(self, "_ghost_value", clamped, ghost_duration)

	# ── Impact punch ──
	if enable_punch and increasing:
		punch()

	# ── Shake ──
	if enable_shake and increasing and (clamped - old_value) / _max_value > 0.05:
		shake()

	# ── Threshold flash ──
	_check_thresholds(old_value, clamped)

	# ── Max check ──
	_check_max(clamped)


## Quick set without full juice (for ghost/secondary updates)
func set_value_silent(new_val: float, max_val: float = -1.0) -> void:
	set_value(new_val, max_val, false)


## Manual punch trigger
func punch() -> void:
	if _punch_tween and _punch_tween.is_running():
		_punch_tween.kill()
	_punch_tween = create_tween()
	_punch_tween.set_ease(Tween.EASE_OUT)
	_punch_tween.set_trans(Tween.TRANS_BACK)
	pivot_offset = size / 2.0
	_punch_tween.tween_property(self, "scale", Vector2.ONE * punch_scale, punch_duration * 0.3)
	_punch_tween.tween_property(self, "scale", Vector2.ONE, punch_duration * 0.7)


## Manual flash trigger
func flash() -> void:
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_flash_alpha = 0.7
	_flash_tween = create_tween()
	_flash_tween.set_ease(Tween.EASE_OUT)
	_flash_tween.set_trans(Tween.TRANS_CUBIC)
	_flash_tween.tween_property(self, "_flash_alpha", 0.0, 0.2)


## Manual shake trigger
func shake() -> void:
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
		position = _original_pos if _pos_captured else position

	if not _pos_captured:
		_original_pos = position
		_pos_captured = true

	_shake_tween = create_tween()
	var steps := int(shake_duration / 0.03)
	for i in range(steps):
		var offset := Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		_shake_tween.tween_property(self, "position", _original_pos + offset, 0.03)
	_shake_tween.tween_property(self, "position", _original_pos, 0.05).set_ease(Tween.EASE_OUT)


## Reset bar to zero
func reset(animate: bool = true) -> void:
	_is_at_max = false
	_last_threshold_crossed = -1
	set_value(0.0, -1.0, animate)


## Get current raw value
func get_current_value() -> float:
	return _current_value


## Check if bar is at maximum
func is_at_max() -> bool:
	return _is_at_max


# ═══════════════════════════════════════════════════════════════════
#  INTERNAL HELPERS
# ═══════════════════════════════════════════════════════════════════

func _get_fill_rect(container: Rect2, ratio: float) -> Rect2:
	ratio = clampf(ratio, 0.0, 1.0)
	if is_horizontal:
		return Rect2(container.position, Vector2(container.size.x * ratio, container.size.y))
	else:
		# Vertical: fill from bottom to top
		var fill_h := container.size.y * ratio
		return Rect2(
			Vector2(container.position.x, container.position.y + container.size.y - fill_h),
			Vector2(container.size.x, fill_h)
		)


func _draw_leading_edge(fill_rect: Rect2, container: Rect2) -> void:
	var glow_pulse := (sin(_glow_time * 5.0) * 0.5 + 0.5)
	var glow_alpha := 0.25 + glow_pulse * 0.35

	if is_horizontal:
		# Glow strip at right edge of fill
		var edge_w := minf(12.0, fill_rect.size.x * 0.15)
		var edge_rect := Rect2(
			Vector2(fill_rect.position.x + fill_rect.size.x - edge_w, fill_rect.position.y),
			Vector2(edge_w, fill_rect.size.y)
		)
		draw_rect(edge_rect, Color(1, 1, 1, glow_alpha))
	else:
		# Glow strip at top edge of fill (since we fill bottom→top)
		var edge_h := minf(12.0, fill_rect.size.y * 0.15)
		var edge_rect := Rect2(
			fill_rect.position,
			Vector2(fill_rect.size.x, edge_h)
		)
		draw_rect(edge_rect, Color(1, 1, 1, glow_alpha))


func _check_thresholds(old_val: float, new_val: float) -> void:
	if not enable_flash:
		return
	var thresholds: Array[float] = [0.25, 0.50, 0.75, 1.0]
	for i in range(thresholds.size()):
		var t: float = thresholds[i] * _max_value
		if old_val < t and new_val >= t and i > _last_threshold_crossed:
			_last_threshold_crossed = i
			flash()
			threshold_crossed.emit(thresholds[i])


func _check_max(val: float) -> void:
	var was_max := _is_at_max
	_is_at_max = val >= _max_value
	if _is_at_max and not was_max:
		_glow_time = 0.0
		value_maxed.emit()
