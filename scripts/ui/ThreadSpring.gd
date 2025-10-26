extends Node2D

## 🧵 Sistema de cuerda con física spring
## Simula un hilo que cuelga desde el cursor con física realista

# 🎯 Parámetros físicos
@export var spring_k: float = 120.0			# Rigidez del muelle
@export var damping_c: float = 14.0			# Amortiguación
@export var mass_m: float = 1.0				# Masa de la bolita
@export var min_distance: float = 180.0		# Distancia mínima cursor-bolita (aumentada para hilo más largo)
@export var gravity: float = 800.0			# Gravedad en px/s² (aumentada para caída más rápida)
@export var sag_factor: float = 0.18			# Factor de caída de la cuerda (0-1)
@export var max_sag: float = 140.0			# Máxima panza de la cuerda

# 🎨 Visual
@export var thread_color: Color = Color(0.886, 0.78, 0.58, 0.95)	# Cáñamo
@export var thread_thickness: float = 1.5	# Grosor del hilo (reducido para más fino)
@export var ball_radius: float = 12.0
@export var show_debug: bool = false

# 🎯 Offset del cursor (para ajustar punto de anclaje visual)
@export var cursor_offset: Vector2 = Vector2.ZERO

# Estado físico
var _pos: Vector2 = Vector2.ZERO			# Posición actual bolita
var _vel: Vector2 = Vector2.ZERO			# Velocidad bolita
var _target: Vector2 = Vector2.ZERO		# Posición del cursor
var _enabled: bool = false

func _ready() -> void:
	set_process(false)

func _on_gui_input(event: InputEvent) -> void:
	"""Manejo de input para la escena de prueba."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _enabled:
			disable()
		else:
			enable(get_viewport().get_mouse_position())

func enable(initial_pos: Vector2) -> void:
	"""Activa el sistema en una posición inicial."""
	_pos = initial_pos
	_target = initial_pos
	_vel = Vector2.ZERO
	_enabled = true
	set_process(true)
	queue_redraw()

func set_cursor_offset_from_size(cursor_size: Vector2, scale_factor: float = 5.0) -> void:
	"""Configura el offset del cursor basado en su tamaño y escala.
	Para un cursor de 1024x1024 reducido a 1/5, el offset será (0, ~204.8)
	para anclar en la esquina inferior izquierda."""
	var scaled_height := cursor_size.y / scale_factor
	cursor_offset = Vector2(0, scaled_height)
	print("🧵 [ThreadSpring] Cursor offset configurado: %v" % cursor_offset)

func disable() -> void:
	"""Desactiva el sistema."""
	_enabled = false
	set_process(false)
	queue_redraw()

func update_target(cursor_pos: Vector2) -> void:
	"""Actualiza la posición objetivo (cursor)."""
	_target = cursor_pos

func _process(delta: float) -> void:
	if not _enabled:
		return
	
	# Actualizar target con posición del mouse
	_target = get_viewport().get_mouse_position()
	
	# Limitar delta para estabilidad
	var dt: float = clampf(delta, 0.001, 0.032)
	
	# 🎯 Calcular target con distancia mínima respetada
	var target_pos := _target
	var dir_to_ball := _pos - _target
	var dist := dir_to_ball.length()
	
	if dist < min_distance:
		# Empujar la bolita para mantener distancia mínima
		if dist > 1e-5:
			dir_to_ball = dir_to_ball.normalized()
		else:
			# Caso degenerado: usar velocidad o eje X
			if _vel.length() > 1e-3:
				dir_to_ball = _vel.normalized()
			else:
				dir_to_ball = Vector2.RIGHT
		
		target_pos = _target + dir_to_ball * min_distance
	
	# 🧮 Física de Hooke: F = -k*(x - target) - c*v
	var spring_force := -spring_k * (_pos - target_pos) - damping_c * _vel
	var accel := spring_force / mass_m
	accel.y += gravity  # Gravedad hacia abajo
	
	# Integración de Euler
	_vel += accel * dt
	_pos += _vel * dt
	
	# 🔒 Corrección dura: no permitir menos de min_distance
	dist = (_pos - _target).length()
	if dist < min_distance:
		var dir := (_pos - _target).normalized()
		_pos = _target + dir * min_distance
		# Remover componente radial de velocidad
		var v_radial := _vel.dot(dir)
		_vel -= dir * v_radial
	
	queue_redraw()

func _draw() -> void:
	if not _enabled:
		return
	
	# 🎨 Aplicar offset al punto de inicio (cursor)
	var start := _target + cursor_offset
	var end := _pos
	var dist := start.distance_to(end)
	var sag := minf(max_sag, dist * sag_factor)
	var mid := (start + end) * 0.5
	mid.y += sag  # Caída hacia abajo
	
	# Sombra de la cuerda
	draw_bezier_curve(
		start + Vector2(0, 2),
		mid + Vector2(0, 2),
		end + Vector2(0, 2),
		thread_color * Color(0.0, 0.0, 0.0, 0.35),
		thread_thickness + 2.0
	)
	
	# Cuerda base
	draw_bezier_curve(
		start,
		mid,
		end,
		thread_color,
		thread_thickness
	)
	
	# Brillo lateral
	draw_bezier_curve(
		start,
		mid - Vector2(0, 2),
		end - Vector2(0, 2),
		Color.WHITE * Color(1, 1, 1, 0.35),
		thread_thickness * 0.5
	)
	
	#  Debug: círculo de distancia mínima y offset (solo si show_debug = true)
	if show_debug:
		draw_arc(_target, min_distance, 0, TAU, 64, Color.YELLOW * Color(1, 1, 1, 0.3), 1.0, true)
		# Indicador del offset del cursor
		draw_line(_target, start, Color.CYAN * Color(1, 1, 1, 0.5), 2.0, true)
		draw_circle(start, 4.0, Color.CYAN)
		# Bolita en el extremo (debug)
		draw_circle(_pos, ball_radius, Color(1, 1, 1, 0.06))
		draw_arc(_pos, ball_radius, 0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)

func draw_bezier_curve(start: Vector2, control: Vector2, end: Vector2, color: Color, width: float) -> void:
	"""Dibuja una curva cuadrática (aproximada con líneas)."""
	const SEGMENTS := 16
	var prev := start
	for i in range(1, SEGMENTS + 1):
		var t := float(i) / float(SEGMENTS)
		var t_inv := 1.0 - t
		# Curva cuadrática: (1-t)²*P0 + 2*(1-t)*t*P1 + t²*P2
		var point := t_inv * t_inv * start + 2.0 * t_inv * t * control + t * t * end
		draw_line(prev, point, color, width, true)
		prev = point
