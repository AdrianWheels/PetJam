extends "res://scripts/core/MinigameBase.gd"

# Port of martillo.html rhythm game

var CANVAS_W = 640
var CANVAS_H = 360
var VIS_IMPACT_X = 520
var VIS_START_X = 60
var VIS_TRACK_Y = 210
const VIS_APPROACH_MS = 1200
const DEFAULT_BPM = 90
const DEFAULT_DRIFT_MS = 25
const WINDOWS_BASE = {"perfect": 40, "bien": 90, "regular": 140}
const SCORE = {"Perfect": 100, "Bien": 70, "Regular": 40, "Miss": 0}
const COOLDOWN_MS = 120

var state = null
var font = ThemeDB.get_default_theme().get_font("font", "Label")
var scale_factor = 1.0
var closing = false

func _ready():
	print("HammerMinigame: Ready")
	var viewport_size = get_viewport_rect().size
	self.size = viewport_size
	self.position = Vector2(0,0)
	scale_factor = viewport_size.x / CANVAS_W
	CANVAS_W = int(CANVAS_W * scale_factor)
	CANVAS_H = int(CANVAS_H * scale_factor)
	VIS_IMPACT_X = int(VIS_IMPACT_X * scale_factor)
	VIS_START_X = int(VIS_START_X * scale_factor)
	VIS_TRACK_Y = int(VIS_TRACK_Y * scale_factor)
	setup_title_screen("HAMMER TIME")
	queue_redraw()

func start_game():
	start({"name": "Martillo Básico", "tempoBPM": 60, "weight": 0.6, "precision": 0.5})
	queue_redraw()

func show_end_screen():
	setup_end_screen("Prueba Completada", "Presiona cualquier tecla o clic para cerrar")

func get_result():
	return {
		"finished": true,
		"success": state.quality_counts.Perfect + state.quality_counts.Bien + state.quality_counts.Regular >= 3,
		"score": state.score,
		"quality_counts": state.quality_counts.duplicate(),
		"combo_max": state.combo_max,
		"time_ms": max(0, round(Time.get_ticks_msec() - state.started_at - state.pause_accum)),
		"blueprint_name": state.blueprint.name if state.blueprint.has("name") else "Unknown"
	}

func start(blueprint):
	reset_with_blueprint(blueprint)

func reset_with_blueprint(bp):
	var blueprint = bp if bp else {"name": "Default", "tempoBPM": DEFAULT_BPM, "weight": 0.5, "precision": 0.5}
	var windows = make_windows(blueprint.precision)
	var weight = clamp(blueprint.weight if blueprint.has("weight") else 0.5, 0, 1)
	var ease_pow = lerp(1.0, 3.0, weight)
	var impact_kick = lerp(6, 18, weight)
	var t_start = Time.get_ticks_msec() + 800
	var notes = schedule_notes(t_start, blueprint.tempoBPM if blueprint.has("tempoBPM") else DEFAULT_BPM, DEFAULT_DRIFT_MS)
	state = {
		"blueprint": blueprint,
		"windows": windows,
		"ease_pow": ease_pow,
		"impact_kick": impact_kick,
		"notes": notes,
		"idx": 0,
		"playing": true,
		"finished": false,
		"accepting": true,
		"started_at": Time.get_ticks_msec(),
		"paused_at": 0,
		"pause_accum": 0,
		"last_input": -1e9,
		"last_feedback": null,
		"last_feedback_until": 0,
		"combo": 0,
		"combo_max": 0,
		"score": 0,
		"quality_counts": {"Perfect": 0, "Bien": 0, "Regular": 0, "Miss": 0},
		"impact_flash": 0
	}

func make_windows(precision):
	var scl = lerp(1.2, 0.7, clamp(precision if precision != null else 0.5, 0, 1))
	return {
		"perfect": WINDOWS_BASE.perfect,
		"bien": WINDOWS_BASE.bien * scl,
		"regular": WINDOWS_BASE.regular * scl,
		"miss": WINDOWS_BASE.regular
	}

func schedule_notes(t0, bpm, drift):
	var iv = 60000 / clamp(bpm, 30, 300)
	var notes = []
	for i in range(5):
		var t = t0 + i * iv + (randf() * 2 - 1) * drift
		notes.append({"time": t, "spawn": t - VIS_APPROACH_MS, "judged": false, "quality": null, "delta": null})
	return notes

func _input(event):
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		try_hit(Time.get_ticks_msec())

func try_hit(t_hit):
	if not state or not state.playing or not state.accepting or state.finished:
		return
	if t_hit - state.last_input < COOLDOWN_MS:
		return
	state.last_input = t_hit

	var i = state.idx
	if i >= state.notes.size():
		return

	var n = state.notes[i]
	var d = t_hit - n.time
	var q = judge_delta(d, state.windows)

	apply_judgement(n, q, d, true)

func judge_delta(d, W):
	var ad = abs(d)
	if ad <= W.perfect:
		return "Perfect"
	if ad <= W.bien:
		return "Bien"
	if ad <= W.regular:
		return "Regular"
	return "Miss"

func apply_judgement(n, q, d, _manual):
	if n.judged:
		return
	n.judged = true
	n.quality = q
	n.delta = d
	print("Trial %d = %s" % [state.idx + 1, q])

	if q == "Miss":
		state.combo = 0
	else:
		state.combo += 1
		state.combo_max = max(state.combo_max, state.combo)
	state.quality_counts[q] += 1
	state.score += SCORE[q] + (0 if q == "Miss" else floor(state.combo * 10))

	state.last_feedback = q + (" (" + str(round(abs(d))) + "ms)" if d != null else "")
	state.last_feedback_until = Time.get_ticks_msec() + 600
	state.impact_flash = 0.0 if q == "Miss" else 1.0

	state.idx += 1

	if state.idx >= state.notes.size():
		end_game()

func end_game():
	state.finished = true
	state.accepting = false
	state.playing = false
	var hits = state.quality_counts.Perfect + state.quality_counts.Bien + state.quality_counts.Regular
	var _result = {
		"finished": true,
		"success": hits >= 3,
		"score": state.score,
		"quality_counts": state.quality_counts.duplicate(),
		"combo_max": state.combo_max,
		"time_ms": max(0, round(Time.get_ticks_msec() - state.started_at - state.pause_accum)),
		"blueprint_name": state.blueprint.name if state.blueprint.has("name") else "Unknown"
	}
	# Show end screen
	show_end_screen()

func _process(_delta):
	if not state:
		return
	var t = Time.get_ticks_msec()

	if state.playing and not state.finished:
		auto_misses(t)

	queue_redraw()

func auto_misses(t_now):
	var i = state.idx
	if i >= state.notes.size():
		return
	var n = state.notes[i]
	if not n.judged and t_now > n.time + state.windows.miss:
		apply_judgement(n, "Miss", null, false)

func _draw():
	if not state:
		return
	var t = Time.get_ticks_msec()

	# Background
	draw_rect(Rect2(0, 0, size.x, size.y), Color("#0b0c10"))
	# Grid
	for x in range(0, int(size.x), 20):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("#121520"), 1)
	for y in range(0, int(size.y), 20):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("#121520"), 1)

	draw_track()
	draw_notes(t)
	draw_impact_flash()
	draw_hud(t)
	draw_finish_overlay()

func draw_track():
	# Track
	draw_line(Vector2(VIS_START_X, VIS_TRACK_Y), Vector2(VIS_IMPACT_X, VIS_TRACK_Y), Color("#2a3145"), 2)
	# Impact area
	draw_line(Vector2(VIS_IMPACT_X, VIS_TRACK_Y - 30), Vector2(VIS_IMPACT_X, VIS_TRACK_Y + 30), Color("#6b7280"), 4)

func draw_notes(t):
	for k in range(state.idx, state.notes.size()):
		var n = state.notes[k]
		var p = (t - n.spawn) / float(VIS_APPROACH_MS)
		if p <= 0:
			continue
		if p > 1.2:
			continue
		var pp = clamp(p, 0, 1)
		var eased = ease_out_pow(pp, state.ease_pow)
		var x = lerp(VIS_START_X, VIS_IMPACT_X, eased)
		var y = VIS_TRACK_Y

		var near = clamp(1 - abs(n.time - t) / 200.0, 0, 1)
		var r = 10 + 8 * near

		draw_circle(Vector2(x, y), r, Color.from_hsv(lerp(200.0/360, 160.0/360, pp), 0.7, lerp(0.4, 0.65, pp)))

func ease_out_pow(t, p):
	return 1 - pow(1 - t, p)

func draw_impact_flash():
	if state.impact_flash <= 0:
		return
	var a = state.impact_flash
	var y = VIS_TRACK_Y
	var x = VIS_IMPACT_X
	var r = 14 + state.impact_kick * a * 8
	var color = Color(1, 1, 1, 0.35 * a)
	draw_arc(Vector2(x, y), r, 0, TAU, 32, color, 3)

func draw_hud(t):
	# Combo
	draw_string(font, Vector2(16, 28), "Combo: " + str(state.combo), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a8b3cf"))
	draw_string(font, Vector2(16, 50), "Score: " + str(state.score), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a8b3cf"))

	# Feedback
	if t < state.last_feedback_until and state.last_feedback:
		var col = Color("#86efac")
		if state.last_feedback.begins_with("Bien"):
			col = Color("#fde047")
		elif state.last_feedback.begins_with("Regular"):
			col = Color("#f59e0b")
		elif state.last_feedback.begins_with("Miss"):
			col = Color("#f87171")
		draw_string(font, Vector2(VIS_IMPACT_X, VIS_TRACK_Y - 50), state.last_feedback, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, col)

	# Countdown
	var first = state.notes[0]
	if not state.finished and Time.get_ticks_msec() < first.spawn:
		var ms = max(0, first.spawn - Time.get_ticks_msec())
		var s = ceil(ms / 1000)
		draw_string(font, Vector2(16, CANVAS_H - 16), "Prepárate: " + str(s), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#94a3b8"))

func draw_finish_overlay():
	if not state.finished:
		return
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(10/255.0, 12/255.0, 18/255.0, 0.8))

	var hits = state.quality_counts.Perfect + state.quality_counts.Bien + state.quality_counts.Regular
	draw_string(font, Vector2(CANVAS_W / 2.0, 90), "Resultado", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color("#e5e7eb"))

	var text = str(hits) + "/5 aciertos  •  Score " + str(state.score) + "  •  Max Combo " + str(state.combo_max)
	draw_string(font, Vector2(CANVAS_W / 2.0, 120), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("#cbd5e1"))

	var y0 = 160
	draw_string(font, Vector2(CANVAS_W / 2.0, y0), "Perfect: " + str(state.quality_counts.Perfect), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("#cbd5e1"))
	draw_string(font, Vector2(CANVAS_W / 2.0, y0 + 24), "Bien: " + str(state.quality_counts.Bien), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("#cbd5e1"))
	draw_string(font, Vector2(CANVAS_W / 2.0, y0 + 48), "Regular: " + str(state.quality_counts.Regular), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("#cbd5e1"))
	draw_string(font, Vector2(CANVAS_W / 2.0, y0 + 72), "Miss: " + str(state.quality_counts.Miss), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("#cbd5e1"))