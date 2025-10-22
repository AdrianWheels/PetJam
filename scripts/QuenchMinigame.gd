extends "res://scripts/core/MinigameBase.gd"

# Port of agua.html tempering minigame

const CFG = {
	"dtMax": 1.0/60.0,
	"tSpan": 12.0,
	"margins": {"l":56.0,"r":16.0,"t":24.0,"b":64.0},
	"thresholds": {"Perfect":5.0, "Bien":12.0, "Regular":20.0},
	"btn":{"w":150.0,"h":36.0}
}

var bp = null
var t = 0.0
var running = false
var paused = false
var finished = false
var result = null

var last_mouse_pos = null

func _ready():
	size = get_viewport_rect().size
	position = Vector2(0,0)
	set_process_input(false)
	setup_title_screen("TEMPLE TIME")

func start_game():
	start({
		"name": "Temple A36",
		"Tini": 850, "Tamb": 25, "k": 0.30,
		"Tlow": 540, "Thigh": 600,
		"catalyst": false, "intelligence": 0.35
	})
	set_process_input(true)

func start(blueprint):
	bp = {
		"name": blueprint.get("name", "Acero medio"),
		"Tini": float(blueprint.get("Tini", 850)),
		"Tamb": float(blueprint.get("Tamb", 25)),
		"k": float(blueprint.get("k", 0.35)),
		"Tlow": float(blueprint.get("Tlow", 520)),
		"Thigh": float(blueprint.get("Thigh", 580)),
		"catalyst": bool(blueprint.get("catalyst", false)),
		"intelligence": clamp(float(blueprint.get("intelligence", 0)), 0, 1)
	}
	if bp.Thigh < bp.Tlow:
		var tmp = bp.Tlow
		bp.Tlow = bp.Thigh
		bp.Thigh = tmp
	# Reset state
	t = 0.0
	finished = false
	result = null
	running = true
	paused = false
	queue_redraw()

func _process(delta):
	if not running or paused or finished:
		return
	t += min(delta, CFG.dtMax)
	queue_redraw()

func _input(event):
	if event is InputEventMouseMotion:
		last_mouse_pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_drop()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		try_drop()

func try_drop():
	if not running or paused or finished:
		return
	var temp = Tof(t)
	result = eval_drop(temp, t)
	finished = true
	running = false
	print("Trial 1 = %s" % result.quality)
	show_end_screen()

func Tof(tt):
	return bp.Tamb + (bp.Tini - bp.Tamb) * exp(-bp.k * tt)

func effective_window():
	var center = (bp.Tlow + bp.Thigh) / 2.0
	var half = (bp.Thigh - bp.Tlow) / 2.0
	if bp.catalyst:
		half *= 1.2
	return {"center": center, "low": center - half, "high": center + half, "half": half}

func quality_from_delta(delta):
	if delta <= CFG.thresholds.Perfect:
		return "Perfect"
	elif delta <= CFG.thresholds.Bien:
		return "Bien"
	elif delta <= CFG.thresholds.Regular:
		return "Regular"
	else:
		return "Miss"

func eval_drop(temp, time_sec):
	var win = effective_window()
	var delta = abs(temp - win.center)
	if temp > win.high:
		var early = temp - win.high
		delta = max(0, delta - bp.intelligence * min(early, win.half))
	
	var qual = quality_from_delta(delta)
	var success = qual != "Miss"
	var score_map = {"Perfect":100, "Bien":85, "Regular":65, "Miss":0}
	var score = score_map[qual]
	var element_fixed = false
	if bp.catalyst and (qual == "Perfect" or qual == "Bien"):
		score = min(100, score + 5)
		element_fixed = true
	return {
		"finished": true,
		"success": success,
		"score": score,
		"quality": qual,
		"temp_at_drop": snapped(temp, 0.1),
		"element_fixed": element_fixed,
		"catalyst": bp.catalyst,
		"time_ms": round(time_sec * 1000),
		"blueprint_name": bp.name
	}

func y_for_temp(temp, t_min, t_max):
	var g_top = CFG.margins.t
	var g_bot = size.y - CFG.margins.b
	var ratio = (temp - t_min) / (t_max - t_min)
	return g_bot - ratio * (g_bot - g_top)

func x_for_time(tt):
	var span = min(CFG.tSpan, t)
	return CFG.margins.l + clamp(tt / span, 0, 1) * (size.x - CFG.margins.l - CFG.margins.r)

func _draw():
	if not bp:
		return
	
	var win = effective_window()
	var t_min = min(bp.Tamb, bp.Tlow, win.low) - 10
	var t_max = max(bp.Tini, bp.Thigh, win.high) + 10
	
	# Graph area
	draw_rect(Rect2(CFG.margins.l, CFG.margins.t, size.x - CFG.margins.l - CFG.margins.r, size.y - CFG.margins.t - CFG.margins.b), Color("#0d1219"))
	
	# Window band
	var y_high = y_for_temp(win.high, t_min, t_max)
	var y_low = y_for_temp(win.low, t_min, t_max)
	draw_rect(Rect2(CFG.margins.l, y_high, size.x - CFG.margins.l - CFG.margins.r, y_low - y_high), Color(0.062, 0.725, 0.506, 0.2))
	
	# Axes
	draw_line(Vector2(CFG.margins.l, size.y - CFG.margins.b), Vector2(size.x - CFG.margins.r, size.y - CFG.margins.b), Color("#374151"), 1)
	draw_line(Vector2(CFG.margins.l, CFG.margins.t), Vector2(CFG.margins.l, size.y - CFG.margins.b), Color("#374151"), 1)
	
	# Y ticks
	var font = ThemeDB.get_default_theme().get_font("font", "Label")
	for i in range(6):
		var u = i / 5.0
		var ty = lerp(size.y - CFG.margins.b, CFG.margins.t, u)
		draw_line(Vector2(CFG.margins.l, ty), Vector2(size.x - CFG.margins.r, ty), Color("#111827"), 1)
		var val = lerp(t_min, t_max, u)
		draw_string(font, Vector2(6, ty + 4), str(snapped(val, 1)) + "°C", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9ca3af"))
	
	# Labels
	draw_string(font, Vector2(size.x - CFG.margins.r - 62, size.y - CFG.margins.b + 38), "Tiempo (s)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9ca3af"))
	draw_string(font, Vector2(CFG.margins.l - 40, CFG.margins.t - 6), "T (°C)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9ca3af"))
	
	# Temperature curve
	var points = []
	var samples = 200
	for i in range(samples + 1):
		var tt = (i / float(samples)) * min(CFG.tSpan, t)
		var x = x_for_time(tt)
		var y = y_for_temp(Tof(tt), t_min, t_max)
		points.append(Vector2(x, y))
	draw_polyline(points, Color("#60a5fa"), 2)
	
	# Current marker
	var x_now = x_for_time(min(t, CFG.tSpan))
	var y_now = y_for_temp(Tof(t), t_min, t_max)
	draw_circle(Vector2(x_now, y_now), 4, Color("#fcd34d"))
	draw_string(font, Vector2(x_now + 8, y_now - 8), "T=%.1f°C  t=%.2fs" % [Tof(t), t], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e5e7eb"))
	
	# Window lines
	var dash = [5, 4]
	my_draw_dashed_line(Vector2(CFG.margins.l, y_high), Vector2(size.x - CFG.margins.r, y_high), Color("#10b981"), 1.5, dash)
	my_draw_dashed_line(Vector2(CFG.margins.l, y_low), Vector2(size.x - CFG.margins.r, y_low), Color("#10b981"), 1.5, dash)
	
	# Button
	var btn_rect = Rect2(size.x - CFG.margins.r - CFG.btn.w, size.y - CFG.margins.b / 2.0 - CFG.btn.h / 2.0, CFG.btn.w, CFG.btn.h)
	var hovering = last_mouse_pos and btn_rect.has_point(last_mouse_pos)
	var btn_color = Color("#334155") if finished else (Color("#1f8bff") if hovering else Color("#2563eb"))
	draw_rect(btn_rect, btn_color)
	draw_string(font, Vector2(btn_rect.position.x + btn_rect.size.x / 2, btn_rect.position.y + btn_rect.size.y / 2), "SOLTAR (Espacio)", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)
	
	# Footer
	draw_string(font, Vector2(CFG.margins.l, size.y - 28), "Plano: %s  |  Catalizador: %s  |  Ventana: [%.0f..%.0f]°C" % [bp.name, "Sí" if bp.catalyst else "No", win.low, win.high], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#94a3b8"))
	draw_string(font, Vector2(CFG.margins.l, size.y - 10), "Tip: suelta cerca del centro verde; con catalizador la ventana es +20%", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#94a3b8"))
	
	# Result overlay
	if finished and result:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.6))
		var box_w = 420
		var box_h = 180
		var bx = (size.x - box_w) / 2
		var by = (size.y - box_h) / 2
		draw_rect(Rect2(bx, by, box_w, box_h), Color("#0b1220"))
		draw_rect(Rect2(bx, by, box_w, box_h), Color("#1f6feb"), false, 2)
		draw_string(font, Vector2(bx + 16, by + 28), "Resultado del Temple", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e5e7eb"))
		var lines = [
			"Plano: %s" % result.blueprint_name,
			"Temperatura al soltar: %.1f°C" % result.temp_at_drop,
			"Tiempo: %d ms" % result.time_ms,
			"Calidad: %s%s" % [result.quality, " — Elemento fijado" if bp.catalyst and (result.quality == "Perfect" or result.quality == "Bien") else ""],
			"Catalizador: %s" % ("Sí" if result.catalyst else "No"),
			"Score: %d  |  %s" % [result.score, "Éxito" if result.success else "Fallido"]
		]
		var yy = by + 56
		for line in lines:
			draw_string(font, Vector2(bx + 16, yy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e5e7eb"))
			yy += 22
		draw_string(font, Vector2(bx + 16, by + box_h - 12), "Presiona cualquier tecla o clic para cerrar", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#94a3b8"))

func show_end_screen():
	setup_end_screen("Prueba Completada", "Presiona cualquier tecla o clic para cerrar")

func my_draw_dashed_line(from_pos: Vector2, to_pos: Vector2, color: Color, width: float, dash: Array):
	var length = (to_pos - from_pos).length()
	var dir = (to_pos - from_pos).normalized()
	var dash_length = dash[0] + dash[1]
	var num_dashes = ceil(length / dash_length)
	var current_pos = from_pos
	for i in range(num_dashes):
		var start_pos = current_pos
		var end_pos = start_pos + dir * dash[0]
		if (end_pos - from_pos).length() > length:
			end_pos = to_pos
		draw_line(start_pos, end_pos, color, width)
		current_pos = end_pos + dir * dash[1]
		if (current_pos - from_pos).length() >= length:
			break