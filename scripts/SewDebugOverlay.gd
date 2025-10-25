extends Control

## 🎨 Overlay de debug para visualizar los 20 puntos de spawn del minijuego Sew

const SPAWN_POINTS: Array[Vector2] = [
	Vector2(0.25, 0.25), Vector2(0.5, 0.25), Vector2(0.75, 0.25),
	Vector2(0.2, 0.4), Vector2(0.5, 0.4), Vector2(0.8, 0.4),
	Vector2(0.25, 0.5), Vector2(0.75, 0.5),
	Vector2(0.15, 0.6), Vector2(0.5, 0.6), Vector2(0.85, 0.6),
	Vector2(0.25, 0.75), Vector2(0.5, 0.75), Vector2(0.75, 0.75),
	Vector2(0.3, 0.85), Vector2(0.7, 0.85),
	Vector2(0.1, 0.5), Vector2(0.9, 0.5),
	Vector2(0.35, 0.35), Vector2(0.65, 0.65)
]

const MARGIN_SIZE := 80.0

func _draw():
	if not visible:
		return
	
	var panel_size := size
	
	# 🎯 Calcular márgenes adaptativos (igual que el minijuego)
	var adaptive_margin := Vector2(
		min(MARGIN_SIZE, panel_size.x * 0.1),
		min(MARGIN_SIZE, panel_size.y * 0.1)
	)
	var safe_area := panel_size - adaptive_margin * 2
	
	# Dibujar cada punto de spawn
	for i in range(SPAWN_POINTS.size()):
		var spawn_point := SPAWN_POINTS[i]
		var pos := adaptive_margin + Vector2(
			spawn_point.x * safe_area.x,
			spawn_point.y * safe_area.y
		)
		
		# Círculo del punto (más grande y semitransparente)
		draw_circle(pos, 12, Color(0.4, 1, 0.4, 0.5))
		
		# Borde del círculo
		draw_arc(pos, 12, 0, TAU, 24, Color.YELLOW_GREEN, 2)
		
		# Número del punto
		draw_string(
			ThemeDB.fallback_font,
			pos + Vector2(16, 6),
			str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18,
			Color.WHITE
		)
		
		# Radio de área del ring target (42px como RING_R) - más visible
		draw_arc(pos, 42, 0, TAU, 32, Color(1, 1, 0, 0.4), 2.5)

func _process(_delta):
	# Redibujar constantemente para mantener visibilidad
	if visible:
		queue_redraw()
