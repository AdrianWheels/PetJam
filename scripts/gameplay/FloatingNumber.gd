extends Label
# Floating number que aparece sobre un personaje al recibir daño

var velocity := Vector2.ZERO
var lifetime := 0.0
const LIFETIME_MAX := 1.2

func _ready():
	# Configuración inicial del label
	modulate.a = 1.0
	
	# Randomizar dirección inicial (hacia arriba con ligero offset horizontal)
	var angle = randf_range(-PI/6, PI/6)  # ±30 grados
	velocity = Vector2(cos(angle), -1.0).normalized() * randf_range(80.0, 120.0)
	
	# Crear tween para animación
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Float up con ease out
	tween.tween_property(self, "position:y", position.y - 60, LIFETIME_MAX).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# Scale bounce
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	# Fade out en los últimos 0.4s
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(LIFETIME_MAX - 0.4)
	
	# Auto destruir
	await get_tree().create_timer(LIFETIME_MAX).timeout
	queue_free()

func _process(delta: float):
	# Aplicar velocidad (con gravedad simulada)
	position += velocity * delta
	velocity.y += 150.0 * delta  # Gravedad
	
	lifetime += delta
