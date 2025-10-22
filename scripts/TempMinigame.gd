extends "res://scripts/core/MinigameBase.gd"

# TempMinigame.gd - Port of temperatura.html minigame

const TUNE_BASE = {
	"BAR": { "x":40, "y":180, "w":560, "h":18, "radius":9 },
	"CURSOR": { "radius":9, "glow":8 },
	"BASE_FREQ_HZ": 0.45,
	"FREQ_STEP_HZ": 0.08,
	"FREQ_MAX_HZ": 1.6,
	"AMP": 0.96,
	"HITS_TO_WIN": 3,
	"FAILS_TO_LOSE": 5,
	"SCORE": { "Perfect":100, "Bien":70, "Regular":40, "Miss":-15 },
	"THRESH_PX": { "Perfect":6, "Bien":14, "Regular":24 },
	"HUD": { "font":"14px system-ui,Segoe UI,Roboto,Arial", "line":18 }
}

var TUNE = TUNE_BASE.duplicate(true)

var running = true
var finished = false
var success = false
var paused = false
var hits = 0
var fails = 0
var attempt = 0
var score = 0
var last_quality = "-"
var start_time = 0
var end_time = 0
var quality_counts = { "Perfect":0, "Bien":0, "Regular":0, "Miss":0 }

var freq_hz = TUNE.BASE_FREQ_HZ
var phase = 0.0

var blueprint = null
var zone_w = 80
var zone_center_x = TUNE.BAR.x + TUNE.BAR.w / 2.0

var ignore_input_timer = 0.0

func _ready():
	# Scale constants to fit viewport
	var viewport_size = get_viewport_rect().size
	self.size = viewport_size
	self.position = Vector2(0, 0)
	var scale_factor = min(viewport_size.x / 640.0, viewport_size.y / 360.0)
	TUNE.BAR.x = int(TUNE.BAR.x * scale_factor)
	TUNE.BAR.y = int(TUNE.BAR.y * scale_factor)
	TUNE.BAR.w = int(TUNE.BAR.w * scale_factor)
	TUNE.BAR.h = int(TUNE.BAR.h * scale_factor)
	TUNE.BAR.radius = int(TUNE.BAR.radius * scale_factor)
	TUNE.CURSOR.radius = int(TUNE.CURSOR.radius * scale_factor)
	TUNE.CURSOR.glow = int(TUNE.CURSOR.glow * scale_factor)
	TUNE.THRESH_PX.Perfect = int(TUNE.THRESH_PX.Perfect * scale_factor)
	TUNE.THRESH_PX.Bien = int(TUNE.THRESH_PX.Bien * scale_factor)
	TUNE.THRESH_PX.Regular = int(TUNE.THRESH_PX.Regular * scale_factor)
	TUNE.HUD.line = int(TUNE.HUD.line * scale_factor)
	
	setup_title_screen("FORJA · Temperatura", "Presiona ESPACIO o clic para empezar", "Presiona cualquier tecla o clic para continuar")
	
	# Apply default blueprint
	
	print("TempMinigame _ready, size: ", size, " viewport: ", get_viewport_rect().size, " parent: ", get_parent().name)
	queue_redraw()

func apply_blueprint(bp):
	blueprint = bp.duplicate()
	var hardness = blueprint.get("hardness", 0.5)
	var k = clamp(1 - 0.6 * clamp(hardness, 0, 1), 0.25, 1)
	var temp_window_base = blueprint.get("temp_window_base", 80)
	zone_w = clamp(temp_window_base * k, 20, TUNE.BAR.w * 0.9)
	zone_center_x = TUNE.BAR.x + TUNE.BAR.w / 2.0

func start(bp):
	apply_blueprint(bp)
	running = true
	finished = false
	success = false
	paused = false
	hits = 0
	fails = 0
	attempt = 0
	score = 0
	last_quality = "-"
	quality_counts = { "Perfect":0, "Bien":0, "Regular":0, "Miss":0 }
	freq_hz = TUNE.BASE_FREQ_HZ
	phase = 0.0
	start_time = Time.get_ticks_msec()
	end_time = 0

func px_at_cursor():
	var t = phase
	var a = TUNE.AMP * 0.5 * TUNE.BAR.w
	var cx = TUNE.BAR.x + TUNE.BAR.w / 2.0
	return cx + sin(t) * a

func eval_quality():
	if not blueprint:
		return "Miss"
	var x = px_at_cursor()
	var dist = abs(x - zone_center_x)
	var half = zone_w / 2
	
	var perfect_px = TUNE.THRESH_PX.Perfect * (1 + clamp(blueprint.get("precision", 0), 0, 1) * 0.7)
	var good_px = TUNE.THRESH_PX.Bien
	var reg_px = TUNE.THRESH_PX.Regular
	
	if dist > half:
		return "Miss"
	if dist <= perfect_px:
		return "Perfect"
	if dist <= good_px:
		return "Bien"
	if dist <= reg_px:
		return "Regular"
	return "Miss"

func lock_attempt():
	if not running or finished or paused:
		return
	var q = eval_quality()
	attempt += 1
	quality_counts[q] += 1
	last_quality = q
	print("Trial %d = %s" % [attempt, q])
	
	if q == "Miss":
		fails += 1
		score = max(0, score + TUNE.SCORE.Miss)
	else:
		hits += 1
		score += TUNE.SCORE[q]
		freq_hz = clamp(freq_hz + TUNE.FREQ_STEP_HZ, TUNE.BASE_FREQ_HZ, TUNE.FREQ_MAX_HZ)
	
	if hits >= TUNE.HITS_TO_WIN:
		finish(true)
	elif fails >= TUNE.FAILS_TO_LOSE:
		finish(false)

func finish(ok):
	finished = true
	success = ok
	running = false
	end_time = Time.get_ticks_msec()
	
	var res = get_result()
	var result_text = "Puntuación: %d  ·  Tiempo: %.2fs\nPerfect %d · Bien %d · Regular %d · Miss %d\nPresiona cualquier tecla o clic para cerrar" % [
		res.score, res.time_ms / 1000.0, res.quality_counts.Perfect, res.quality_counts.Bien, 
		res.quality_counts.Regular, res.quality_counts.Miss
	]
	setup_end_screen("Éxito" if success else "Fallo", result_text)

func _process(delta):
	if ignore_input_timer > 0:
		ignore_input_timer -= delta
		if ignore_input_timer <= 0:
			ignore_input_timer = 0
	if not running or paused:
		return
	var omega = 2 * PI * freq_hz
	phase += omega * delta
	queue_redraw()

func _draw():
	# Background
	var bg = Color(0.1, 0.12, 0.15)
	draw_rect(Rect2(0, 0, size.x, size.y), bg)
	
	if (title_screen and title_screen.visible) or (end_screen and end_screen.visible):
		return
	
	# Draw bar
	draw_bar()
	draw_hud()

func draw_bar():
	var bar = TUNE.BAR
	var cursor = TUNE.CURSOR
	
	# Bar background
	var bar_rect = Rect2(bar.x, bar.y - bar.h/2, bar.w, bar.h)
	draw_rect(bar_rect, Color(0.2, 0.25, 0.3), true)
	
	# Zone
	var zx = zone_center_x - zone_w / 2
	var zone_rect = Rect2(zx, bar.y - bar.h/2 - 8, zone_w, bar.h + 16)
	draw_rect(zone_rect, Color(0.35, 0.83, 0.51, 0.22))
	draw_rect(zone_rect, Color(0.35, 0.83, 0.51, 0.55), false, 2)
	
	# Quality marks
	var marks = [
		[TUNE.THRESH_PX.Regular, Color(1, 0.72, 0.3, 0.35)],
		[TUNE.THRESH_PX.Bien, Color(0.47, 0.75, 1, 0.45)],
		[TUNE.THRESH_PX.Perfect * (1 + (clamp(blueprint.get("precision", 0), 0, 1) if blueprint else 0) * 0.7), Color(0.5, 1, 0.79, 0.8)]
	]
	for m in marks:
		var px = m[0]
		var c = m[1]
		draw_line(Vector2(zone_center_x - px, bar.y - 18), Vector2(zone_center_x - px, bar.y + 18), c, 1 if m != marks[2] else 2)
		draw_line(Vector2(zone_center_x + px, bar.y - 18), Vector2(zone_center_x + px, bar.y + 18), c, 1 if m != marks[2] else 2)
	
	# Cursor
	var cx = px_at_cursor()
	var cursor_pos = Vector2(cx, bar.y)
	# Glow effect (simple circle)
	draw_circle(cursor_pos, cursor.radius + cursor.glow, Color(0.51, 0.87, 1, 0.3))
	draw_circle(cursor_pos, cursor.radius, Color(0.8, 0.95, 1))
	
	# Scale 0-100
	var font = ThemeDB.fallback_font
	var font_size = 12
	draw_string(font, Vector2(bar.x, bar.y + 34), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.58, 0.62, 0.67))
	draw_string(font, Vector2(bar.x + bar.w, bar.y + 34), "100", HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, Color(0.58, 0.62, 0.67))

func draw_hud():
	var line = TUNE.HUD.line
	var font = ThemeDB.fallback_font
	var font_size = 14
	var color = Color(0.81, 0.84, 0.87)
	var x = TUNE.BAR.x
	var y_start = TUNE.BAR.y + 70
	
	var rows = [
		"Blueprint: %s" % (blueprint.get("name", "-") if blueprint else "-"),
		"Aciertos: %d / %d" % [hits, TUNE.HITS_TO_WIN],
		"Fallos: %d / %d" % [fails, TUNE.FAILS_TO_LOSE],
		"Intento: %d" % (attempt + 1),
		"Último: %s" % last_quality,
		"Velocidad: %.2f Hz" % freq_hz,
		"Pausa: %s" % ("Sí" if paused else "No")
	]
	for i in range(rows.size()):
		draw_string(font, Vector2(x, y_start + i * line), rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	
	# Title
	var title_font_size = 18
	var title_color = Color(0.91, 0.94, 0.95)
	draw_string(font, Vector2(size.x / 2, 48), "FORJA · Temperatura", HORIZONTAL_ALIGNMENT_CENTER, -1, title_font_size, title_color)
	var instr_font_size = 12
	var instr_color = Color(0.58, 0.62, 0.67)
	draw_string(font, Vector2(size.x / 2, 66), "Click o ESPACIO para fijar. Pulsa P para pausar.", HORIZONTAL_ALIGNMENT_CENTER, -1, instr_font_size, instr_color)

func _input(event):
	if ignore_input_timer > 0 or (title_screen and title_screen.visible) or (end_screen and end_screen.visible):
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if not finished:
				lock_attempt()
				accept_event()
		elif event.keycode == KEY_P:
			if not finished:
				paused = not paused
				accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not finished:
			lock_attempt()
			accept_event()

func start_game():
	start({})
	ignore_input_timer = 0.2  # Ignore input for 0.2 seconds
	queue_redraw()

func _on_end_continue():
	# Emit end signal and remove self
	emit_signal("minigame_end", get_result())
	get_node("/root/Main/ForgeUI/HUD")._set_forge_panels_visible(true)
	queue_free()

func get_result():
	var t_end = end_time if finished else Time.get_ticks_msec()
	return {
		"finished": finished,
		"success": success,
		"score": score,
		"quality_counts": quality_counts.duplicate(),
		"hits": hits,
		"fails": fails,
		"time_ms": max(0, t_end - start_time),
		"blueprint_name": blueprint.name if blueprint else "-"
	}