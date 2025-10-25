extends Control
class_name UICircleRenderer

## Dibuja un círculo 2D que se escala desde su centro
## Útil para animaciones de contracción/expansión
## ⚠️ RENOMBRADO de CircleShape2D para evitar colisión con clase nativa de Godot

@export var radius: float = 50.0:
	set(value):
		radius = value
		queue_redraw()

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

@export var filled: bool = true:
	set(value):
		filled = value
		queue_redraw()

@export var border_width: float = 2.0:
	set(value):
		border_width = value
		queue_redraw()

@export var border_color: Color = Color.WHITE:
	set(value):
		border_color = value
		queue_redraw()

func _ready() -> void:
	# Asegurar que el tamaño mínimo permita ver el círculo
	custom_minimum_size = Vector2(radius * 2, radius * 2)
	queue_redraw()

func _draw() -> void:
	if radius <= 0:
		return
	
	# El centro del círculo está en el centro del Control
	var center := size / 2.0
	
	if filled:
		# Círculo relleno
		draw_circle(center, radius, color)
	
	# Borde (opcional)
	if border_width > 0:
		draw_arc(center, radius, 0, TAU, 32, border_color, border_width, true)

## Anima el radio con un tween
func animate_radius(target_radius: float, duration: float, trans_type: Tween.TransitionType = Tween.TRANS_LINEAR, ease_type: Tween.EaseType = Tween.EASE_OUT) -> Tween:
	var tween := create_tween()
	tween.set_trans(trans_type)
	tween.set_ease(ease_type)
	tween.tween_property(self, "radius", target_radius, duration)
	return tween

## Anima el color con un tween
func animate_color(target_color: Color, duration: float) -> Tween:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "color", target_color, duration)
	return tween
