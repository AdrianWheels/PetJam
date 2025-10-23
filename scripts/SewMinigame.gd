extends "res://scripts/core/MinigameBase.gd"

# Port of coser.html OSU-like minigame

var CANVAS_W = 640
var CANVAS_H = 360
var RING_R = 42
var START_R = 140
const BASE_SPEED = 120
const INTER_NOTE_MS = 420
const TOTAL_NOTES = 8

var state = null
var font = ThemeDB.get_default_theme().get_font("font", "Label")
var scale_factor = 1.0
var closing = false

var cx = CANVAS_W / 2.0
var cy = CANVAS_H / 2.0
var ring_r = RING_R
var r = START_R
var speed = BASE_SPEED
var note_active = false
var note_judged = false
var idx = 0
var combo = 0
var max_combo = 0
var score = 0
var quality_counts = {"Perfect": 0, "Bien": 0, "Regular": 0, "Miss": 0}
var ords = []
var windows = {"perfect": 3, "bien": 8, "regular": 14}
var cooldown_until = 0
var feedback_timer = 0
var last_label = ""
var started_at = 0
var ended_at = 0
var running = false
var paused = false
var finished = false
var bp = {"name": "Coser-Default", "stitchSpeed": 1, "agility": 0.15, "precision": 0.2}
var _pending_blueprint := bp.duplicate(true)
var _max_score := 2400.0

func _ready():
        print("SewMinigame: Ready")
        var viewport_size = get_viewport_rect().size
        size = viewport_size
        position = Vector2(0,0)
	scale_factor = viewport_size.x / CANVAS_W
	CANVAS_W = int(CANVAS_W * scale_factor)
	CANVAS_H = int(CANVAS_H * scale_factor)
	RING_R = int(RING_R * scale_factor)
	START_R = int(START_R * scale_factor)
	cx = CANVAS_W / 2.0
	cy = CANVAS_H / 2.0
	ring_r = RING_R
	r = START_R
        setup_title_screen("SEW TIME")
        queue_redraw()

func start_trial(config: TrialConfig) -> void:
        super.start_trial(config)
        var stitch_speed := clamp(float(config.get_parameter(&"stitch_speed", 1.0)), 0.3, 2.0)
        var agility := clamp(float(config.get_parameter(&"agility", 0.2)), 0.0, 1.0)
        var precision := clamp(float(config.get_parameter(&"precision", 0.4)), 0.0, 1.0)
        var label := String(config.get_parameter(&"label", "Coser"))
        _pending_blueprint = {
                "name": label,
                "stitchSpeed": stitch_speed,
                "agility": agility,
                "precision": precision
        }
        _max_score = max(config.max_score, float(TOTAL_NOTES * 300))
        queue_redraw()

func start_game():
        start(_pending_blueprint)
        queue_redraw()

func start(blueprint):
	reset()
	bp = blueprint if blueprint else bp
	running = true
	paused = false
	started_at = Time.get_ticks_msec()
	note_active = true
	windows = compute_windows(bp.precision)
	speed = BASE_SPEED * max(0.4, bp.stitchSpeed)

func reset():
	running = false
	paused = false
	finished = false
	idx = 0
	combo = 0
	max_combo = 0
	score = 0
	quality_counts = {"Perfect": 0, "Bien": 0, "Regular": 0, "Miss": 0}
	ords = []
	note_active = false
	note_judged = false
	r = START_R
	cooldown_until = 0
	feedback_timer = 0
	last_label = ""

func compute_windows(precision):
	var p = clamp(precision, 0, 1)
	return {
		"perfect": 3 * (1 + 0.5 * p),
		"bien": 8 * (1 + 0.35 * p),
		"regular": 14 * (1 + 0.20 * p)
	}

func _input(event):
	if event is InputEventMouseButton or event is InputEventKey:
		if event.pressed:
			_on_hit()

func _on_hit():
	if not running or paused or finished or not note_active or note_judged:
		return
	var diff = abs(r - ring_r)
	var late = r < ring_r
	var result = judge(diff, late, windows, bp.agility)
	_apply_judgement(result.label, result.ord, result.score)

func judge(diff, late, win_dict, agility):
	var label = "Miss"
	if diff <= win_dict.perfect:
		label = "Perfect"
	elif diff <= win_dict.bien:
		label = "Bien"
	elif diff <= win_dict.regular:
		label = "Regular"
	else:
		var forgive = win_dict.regular + 6 * clamp(agility, 0, 1)
		if late and diff <= forgive:
			label = "Regular"
	var quality_ord = {"Perfect": 3, "Bien": 2, "Regular": 1, "Miss": 0}[label]
	var points = {"Perfect": 300, "Bien": 200, "Regular": 100, "Miss": 0}[label]
	return {"label": label, "ord": quality_ord, "score": points}

func _apply_judgement(label, quality_ord, points):
	note_judged = true
	last_label = label
	feedback_timer = Time.get_ticks_msec() + 420
	ords.append(quality_ord)
	self.score += points
	quality_counts[label] += 1
	if label == "Miss":
		max_combo = max(max_combo, combo)
		combo = 0
	else:
		combo += 1
		max_combo = max(max_combo, combo)
	_schedule_next_note()

func _schedule_next_note():
	cooldown_until = Time.get_ticks_msec() + INTER_NOTE_MS

func _process(delta):
	if running and not paused and not finished:
		if note_active and not note_judged:
			r -= speed * delta
			if r < 0:
				r = 0
			if r == 0:
				_apply_judgement("Miss", 0, 0)
		var now = Time.get_ticks_msec()
		if note_judged and now >= cooldown_until:
			idx += 1
			if idx >= TOTAL_NOTES:
				_finish()
				return
			note_judged = false
			note_active = true
			r = START_R
	queue_redraw()

func _finish():
        finished = true
        running = false
        ended_at = Time.get_ticks_msec()
        var avg_quality = ords.reduce(func(a, b): return a + b, 0) / float(TOTAL_NOTES)
        var non_miss = quality_counts["Perfect"] + quality_counts["Bien"] + quality_counts["Regular"]
        var success = non_miss >= 5
        var bonus_evasion = avg_quality >= 2.0
        var qualities = ["Perfect", "Bien", "Regular", "Miss"]
        for i in range(ords.size()):
                print("Trial %d = %s" % [i+1, qualities[ords[i]]])
        var trial_result := TrialResult.new()
        trial_result.score = score
        trial_result.max_score = _max_score
        trial_result.success = success
        trial_result.duration_ms = ended_at - started_at
        trial_result.details = {
                "quality_counts": quality_counts.duplicate(),
                "avg_quality": avg_quality,
                "bonus_evasion": bonus_evasion,
                "combo_max": max_combo
        }
        complete_trial(trial_result)
        var summary := "Puntuación: %d\nPromedio: %.2f" % [score, avg_quality]
        setup_end_screen(success and "Éxito" or "Fallo", summary + "\nPulsa para cerrar")

func show_end_screen():
	setup_end_screen("Prueba Completada", "Presiona cualquier tecla o clic para cerrar")

func _draw():
	if not running and not finished:
		return
	var now = Time.get_ticks_msec()
	# Background
	draw_rect(Rect2(0, 0, size.x, size.y), Color("#0b0f14"))
	# Grid
	for x in range(0, int(size.x), 20):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("#121520"), 1)
	for y in range(0, int(size.y), 20):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("#121520"), 1)
	
	# Ring
	draw_arc(Vector2(cx, cy), ring_r, 0, TAU, 32, Color("#8bd3dd"), 3)
	
	# Collapsing circle
	if not finished:
		draw_arc(Vector2(cx, cy), r, 0, TAU, 32, Color("#7c3aed"), 6)
	
	# Feedback
	if feedback_timer > now:
		var color = {"Perfect": Color("#22c55e"), "Bien": Color("#38bdf8"), "Regular": Color("#f59e0b"), "Miss": Color("#ef4444")}.get(last_label, Color.WHITE)
		draw_string(font, Vector2(cx - 50, cy - 90), last_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 28, color)
	
	# HUD
	var avg = ords.reduce(func(a, b): return a + b, 0) / float(max(ords.size(), 1))
	draw_string(font, Vector2(16, 22), "Nota %d/%d" % [min(idx + 1, TOTAL_NOTES), TOTAL_NOTES])
	draw_string(font, Vector2(16, 42), "Combo %d" % combo)
	draw_string(font, Vector2(16, 62), "AVG %.2f / 3" % avg)
	
	# Bars
	var bar_x = 180
	var bar_y = 12
	var bar_w = 440
	var bar_h = 10
	var total = TOTAL_NOTES
	var p_w = (quality_counts["Perfect"] / float(total)) * bar_w
	var b_w = (quality_counts["Bien"] / float(total)) * bar_w
	var r_w = (quality_counts["Regular"] / float(total)) * bar_w
	var m_w = (quality_counts["Miss"] / float(total)) * bar_w
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("#1f2937"))
	draw_rect(Rect2(bar_x, bar_y, p_w, bar_h), Color("#22c55e"))
	draw_rect(Rect2(bar_x + p_w, bar_y, b_w, bar_h), Color("#38bdf8"))
	draw_rect(Rect2(bar_x + p_w + b_w, bar_y, r_w, bar_h), Color("#f59e0b"))
	draw_rect(Rect2(bar_x + p_w + b_w + r_w, bar_y, m_w, bar_h), Color("#ef4444"))
	
	draw_string(font, Vector2(bar_x, bar_y + bar_h + 14), "P:%d B:%d R:%d M:%d" % [quality_counts["Perfect"], quality_counts["Bien"], quality_counts["Regular"], quality_counts["Miss"]])
	
	if finished:
		var avg_q = ords.reduce(func(a, b): return a + b, 0) / float(TOTAL_NOTES)
		var non_miss = quality_counts["Perfect"] + quality_counts["Bien"] + quality_counts["Regular"]
		var success = non_miss >= 5
		var bonus = avg_q >= 2.0
		# Overlay
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(cx, cy - 70), "RESULTADO", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
		draw_string(font, Vector2(cx, cy - 40), "Score %d | AVG %.2f | Combo Max %d" % [score, avg_q, max_combo], HORIZONTAL_ALIGNMENT_CENTER)
		draw_string(font, Vector2(cx, cy - 16), "P %d B %d R %d M %d" % [quality_counts["Perfect"], quality_counts["Bien"], quality_counts["Regular"], quality_counts["Miss"]], HORIZONTAL_ALIGNMENT_CENTER)
		var success_color = Color("#22c55e") if success else Color("#ef4444")
		draw_string(font, Vector2(cx, cy + 12), "Éxito" if success else "Fallo", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, success_color)
		var bonus_color = Color("#38bdf8") if bonus else Color("#94a3b8")
		draw_string(font, Vector2(cx, cy + 36), "Evasión: %s" % ("BONUS" if bonus else "—"), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, bonus_color)