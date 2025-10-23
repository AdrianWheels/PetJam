extends "res://scripts/core/MinigameBase.gd"

var closing = false
var _progress := 0.0
var _running := false
var _target := 0.6
var _tolerance := 0.15
var _speed := 0.45
var _max_score := 100.0
var _start_time := 0

func _ready():
        size = get_viewport_rect().size
        position = Vector2(0,0)
        setup_title_screen("FORGE", "Detén el martillo en el punto justo", "Pulsa para empezar")

func start_trial(config: TrialConfig) -> void:
        super.start_trial(config)
        var difficulty := clamp(config.get_parameter(&"difficulty", 0.5), 0.0, 1.0)
        _target = clamp(config.get_parameter(&"target", 0.6), 0.2, 0.85)
        _tolerance = lerp(0.25, 0.08, difficulty)
        _speed = lerp(0.35, 1.2, difficulty)
        _max_score = config.max_score if config else 100.0
        queue_redraw()

func start_game():
        _progress = 0.0
        _running = true
        _start_time = Time.get_ticks_msec()
        queue_redraw()

func _process(delta):
        if not _running:
                return
        _progress += delta * _speed
        if _progress >= 1.0:
                _progress = 1.0
                _finish_attempt()
        queue_redraw()

func _input(event):
        if not _running:
                return
        if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
                _finish_attempt()
                accept_event()

func _finish_attempt():
        if not _running:
                return
        _running = false
        var elapsed := Time.get_ticks_msec() - _start_time
        var diff := abs(_progress - _target)
        var ratio := clamp(1.0 - diff / max(_tolerance, 0.001), 0.0, 1.0)
        var score := round(ratio * _max_score)
        var success := diff <= _tolerance
        var result := TrialResult.new()
        result.score = score
        result.max_score = _max_score
        result.success = success
        result.duration_ms = elapsed
        result.details = {
                "progress": _progress,
                "target": _target,
                "tolerance": _tolerance,
                "difficulty": trial_config.get_parameter(&"difficulty", 0.5) if trial_config else 0.5
        }
        complete_trial(result)
        var outcome := "Éxito" if success else "Fallo"
        var pct := int(round(ratio * 100))
        setup_end_screen(outcome, "Precisión: %d%%\nPulsa para cerrar" % pct)

func _draw():
        draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0f14"))
        var bar_rect := Rect2(80, size.y/2 - 20, size.x - 160, 40)
        draw_rect(bar_rect, Color("#111827"))
        var target_x := bar_rect.position.x + bar_rect.size.x * _target
        var tolerance_px := bar_rect.size.x * _tolerance
        var tol_rect := Rect2(target_x - tolerance_px, bar_rect.position.y, tolerance_px * 2, bar_rect.size.y)
        draw_rect(tol_rect, Color(0.16, 0.65, 0.42, 0.35))
        var progress_x := bar_rect.position.x + clamp(_progress, 0.0, 1.0) * bar_rect.size.x
        draw_rect(Rect2(progress_x - 4, bar_rect.position.y - 10, 8, bar_rect.size.y + 20), Color("#facc15"))
        var font := ThemeDB.get_default_theme().get_font("font", "Label")
        draw_string(font, Vector2(bar_rect.position.x, bar_rect.position.y - 30), "Progreso", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e5e7eb"))
        draw_string(font, Vector2(target_x - 30, bar_rect.position.y + bar_rect.size.y + 24), "Objetivo", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a855f7"))
        if _running:
                draw_string(font, Vector2(bar_rect.position.x, bar_rect.position.y - 8), "Pulsa espacio o clic para fijar", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#94a3b8"))
