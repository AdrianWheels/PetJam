extends Node2D

## 🧵 Sistema de costura visual
## Dibuja costuras entre puntos con efecto de hilo trenzado

# 🎨 Parámetros visuales
@export var stitch_spacing: float = 28.0		# Espaciado entre puntadas
@export var seam_width: float = 12.0			# Ancho de la costura
@export var thread_thickness: float = 3.0	# Grosor del hilo
@export var thread_color: Color = Color(0.43, 0.91, 1.0, 1.0)  # Cyan (#6ee7ff)
@export var show_guides: bool = false		# Mostrar líneas guía
@export var show_holes: bool = true			# Mostrar ojetes

# Puntos de costura
var _points: Array[Vector2] = []
var _enabled: bool = false

func _ready() -> void:
	set_process(false)

func enable() -> void:
	"""Activa el sistema de costura."""
	_enabled = true
	queue_redraw()

func disable() -> void:
	"""Desactiva el sistema."""
	_enabled = false
	_points.clear()
	queue_redraw()

func add_point(point: Vector2) -> void:
	"""Añade un punto de costura."""
	_points.append(point)
	queue_redraw()

func remove_last_point() -> void:
	"""Elimina el último punto."""
	if not _points.is_empty():
		_points.pop_back()
		queue_redraw()

func clear_points() -> void:
	"""Limpia todos los puntos."""
	_points.clear()
	queue_redraw()

func get_point_count() -> int:
	"""Retorna el número de puntos."""
	return _points.size()

func _draw() -> void:
	if not _enabled or _points.is_empty():
		return
	
	# Dibujar costuras entre puntos consecutivos
	for i in range(_points.size() - 1):
		_draw_stitch(_points[i], _points[i + 1])
	
	# Dibujar puntos de referencia
	for point in _points:
		draw_circle(point, 3.0, Color(0.58, 0.64, 0.72, 1.0))

func _draw_stitch(point_a: Vector2, point_b: Vector2) -> void:
	"""Dibuja una costura entre dos puntos."""
	var dir := point_b - point_a
	var length := dir.length()
	
	if length < 1.0:
		return
	
	var unit := dir / length
	var normal := Vector2(-unit.y, unit.x)
	
	# 📐 Líneas guía (opcional)
	if show_guides:
		# Línea central
		draw_line(point_a, point_b, Color(1, 1, 1, 0.12), 1.0, true)
		
		# Rails laterales
		var rail_a1 := point_a + normal * seam_width
		var rail_b1 := point_b + normal * seam_width
		var rail_a2 := point_a - normal * seam_width
		var rail_b2 := point_b - normal * seam_width
		
		draw_line(rail_a1, rail_b1, Color(0.31, 0.47, 0.63, 0.25), 1.0, true)
		draw_line(rail_a2, rail_b2, Color(0.31, 0.47, 0.63, 0.25), 1.0, true)
	
	# 🕳️ Ojetes (eyelets)
	if show_holes:
		var hole_count := maxi(1, int(length / stitch_spacing))
		for i in range(hole_count + 1):
			var t := minf(float(i) * stitch_spacing, length)
			var pos := point_a + unit * t
			var hole1 := pos + normal * seam_width
			var hole2 := pos - normal * seam_width
			
			# Ojete con sombra
			draw_circle(hole1, 2.1, Color(0.04, 0.05, 0.07, 1.0))
			draw_arc(hole1, 2.1, 0, TAU, 12, Color(1, 1, 1, 0.35), 1.0)
			
			draw_circle(hole2, 2.1, Color(0.04, 0.05, 0.07, 1.0))
			draw_arc(hole2, 2.1, 0, TAU, 12, Color(1, 1, 1, 0.35), 1.0)
	
	# 🧵 Hilo cruzado (estilo cordones)
	var half_spacing := stitch_spacing * 0.5
	var steps := maxi(1, int(length / half_spacing))
	
	for k in range(steps):
		var s0 := minf(float(k) * half_spacing, length)
		var s1 := minf(float(k + 1) * half_spacing, length)
		var from_left := (k % 2 == 0)
		
		var pos_l0 := point_a + unit * s0 + normal * seam_width
		var pos_r0 := point_a + unit * s0 - normal * seam_width
		var pos_l1 := point_a + unit * s1 + normal * seam_width
		var pos_r1 := point_a + unit * s1 - normal * seam_width
		
		# Control point para curva (belly del hilo)
		var mid_s := (s0 + s1) * 0.5
		var mid_pos := point_a + unit * mid_s
		var ctrl_push := seam_width * 0.6
		var ctrl := mid_pos + normal * (ctrl_push if from_left else -ctrl_push)
		
		# Dibujar curva cuadrática
		var start := pos_l0 if from_left else pos_r0
		var end := pos_r1 if from_left else pos_l1
		
		_draw_bezier_thread(start, ctrl, end)
	
	# ✨ Brillo sutil en la costura
	var highlight_offset := normal * (seam_width * 0.2)
	var highlight_start := point_a + highlight_offset
	var highlight_end := point_b + highlight_offset
	
	# Usar dash para efecto sutil
	var dash_length := maxf(2.0, stitch_spacing - 4.0)
	_draw_dashed_line(highlight_start, highlight_end, Color.WHITE * Color(1, 1, 1, 0.25), maxf(1.0, thread_thickness - 1.0), 2.0, dash_length)

func _draw_bezier_thread(start: Vector2, control: Vector2, end: Vector2) -> void:
	"""Dibuja el hilo con curva cuadrática."""
	const SEGMENTS := 8
	var prev := start
	
	for i in range(1, SEGMENTS + 1):
		var t := float(i) / float(SEGMENTS)
		var t_inv := 1.0 - t
		var point := t_inv * t_inv * start + 2.0 * t_inv * t * control + t * t * end
		draw_line(prev, point, thread_color, thread_thickness, true)
		prev = point

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	"""Dibuja una línea discontinua."""
	var dir := to - from
	var length := dir.length()
	
	if length < 1.0:
		return
	
	var unit := dir / length
	var pos := 0.0
	var drawing := true
	
	while pos < length:
		var segment_length := dash if drawing else gap
		var next_pos := minf(pos + segment_length, length)
		
		if drawing:
			draw_line(from + unit * pos, from + unit * next_pos, color, width, true)
		
		pos = next_pos
		drawing = not drawing
