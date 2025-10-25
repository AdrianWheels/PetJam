extends Node
class_name MinigameFX

## Sistema centralizado de efectos visuales para minijuegos
## Proporciona feedback multimodal consistente: colores, pulsos, partículas, screen shake

# 🎨 PALETA DE COLORES ESTÁNDAR
const COLORS := {
	"Perfect": Color("#22c55e"),     # Verde brillante
	"Bien": Color("#38bdf8"),        # Azul cielo
	"Regular": Color("#f59e0b"),     # Naranja
	"Miss": Color("#ef4444"),        # Rojo
	"Neutral": Color("#94a3b8"),     # Gris azulado
	"Background": Color("#0b0f14"),  # Fondo oscuro
	"Surface": Color("#111827"),     # Superficie
	"Border": Color("#1e293b"),      # Bordes
	"Accent": Color("#8b5cf6"),      # Púrpura acento
	"Warning": Color("#facc15"),     # Amarillo advertencia
	"Success": Color("#10b981"),     # Verde éxito
}

# 🎯 INTENSIDADES DE EFECTOS POR CALIDAD
const INTENSITY := {
	"Perfect": {"pulse_scale": 1.5, "particles": 24, "shake": 0.15, "flash": 0.6},
	"Bien": {"pulse_scale": 1.25, "particles": 12, "shake": 0.08, "flash": 0.35},
	"Regular": {"pulse_scale": 1.1, "particles": 6, "shake": 0.04, "flash": 0.15},
	"Miss": {"pulse_scale": 1.0, "particles": 3, "shake": 0.12, "flash": 0.25},
}

## Crea un efecto de pulso visual en una posición
## @param position: Posición en pantalla
## @param quality: "Perfect", "Bien", "Regular", "Miss"
## @param parent: Nodo padre donde añadir el efecto
static func create_pulse(position: Vector2, quality: String, parent: Node) -> void:
	var config: Dictionary = INTENSITY.get(quality, INTENSITY["Miss"])
	var color: Color = COLORS.get(quality, COLORS["Neutral"])
	
	var pulse := Control.new()
	pulse.position = position
	pulse.z_index = 100
	pulse.modulate = color
	parent.add_child(pulse)
	
	# Tween para escalar y desvanecer
	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(pulse, "scale", Vector2.ONE * config.pulse_scale, 0.4)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(pulse.queue_free)

## Crea partículas explosivas desde una posición
## @param position: Centro de la explosión
## @param quality: "Perfect", "Bien", "Regular", "Miss"
## @param parent: Nodo padre
static func create_particles(position: Vector2, quality: String, parent: Node) -> void:
	var config: Dictionary = INTENSITY.get(quality, INTENSITY["Miss"])
	var color: Color = COLORS.get(quality, COLORS["Neutral"])
	var count: int = int(config.particles)
	
	for i in range(count):
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.position = position - particle.size / 2
		particle.color = color
		particle.z_index = 99
		parent.add_child(particle)
		
		# Dirección aleatoria
		var angle := randf() * TAU
		var speed := randf_range(50, 150)
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		
		# Animación
		var tween := parent.create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		
		var duration := randf_range(0.3, 0.6)
		tween.tween_property(particle, "position", position + velocity * duration, duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.tween_property(particle, "scale", Vector2.ONE * 0.3, duration)
		tween.chain().tween_callback(particle.queue_free)

## Aplica screen shake a una cámara o nodo
## @param node: Nodo a sacudir (típicamente Camera2D o Control)
## @param quality: "Perfect", "Bien", "Regular", "Miss"
static func apply_shake(node: Node, quality: String) -> void:
	if node == null:
		return
	
	var config: Dictionary = INTENSITY.get(quality, INTENSITY["Miss"])
	var intensity: float = config.shake
	var original_pos := Vector2.ZERO
	
	if node is Camera2D:
		original_pos = node.offset
	elif node is Control or node is Node2D:
		original_pos = node.position
	else:
		return
	
	# 6 shakes rápidos
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	for i in range(6):
		var offset := Vector2(
			randf_range(-intensity, intensity) * 20,
			randf_range(-intensity, intensity) * 20
		)
		var target := original_pos + offset
		
		if node is Camera2D:
			tween.tween_property(node, "offset", target, 0.05)
		else:
			tween.tween_property(node, "position", target, 0.05)
	
	# Volver a posición original
	if node is Camera2D:
		tween.tween_property(node, "offset", original_pos, 0.1)
	else:
		tween.tween_property(node, "position", original_pos, 0.1)

## Crea un flash de pantalla completa
## @param quality: "Perfect", "Bien", "Regular", "Miss"
## @param parent: Nodo padre (típicamente el minijuego)
static func create_flash(quality: String, parent: Node) -> void:
	var config: Dictionary = INTENSITY.get(quality, INTENSITY["Miss"])
	var color: Color = COLORS.get(quality, COLORS["Neutral"])
	var alpha: float = config.flash
	
	var flash := ColorRect.new()
	flash.color = color
	flash.color.a = alpha
	flash.z_index = 98
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(flash)
	
	# Ajustar tamaño al viewport
	if parent is Control:
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		flash.size = parent.get_viewport_rect().size
	
	# Desvanecer
	var tween := parent.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

## Efecto completo de feedback (flash + partículas + pulso)
## @param position: Posición en pantalla
## @param quality: "Perfect", "Bien", "Regular", "Miss"
## @param parent: Nodo padre
static func full_feedback(position: Vector2, quality: String, parent: Node) -> void:
	create_flash(quality, parent)
	create_particles(position, quality, parent)
	create_pulse(position, quality, parent)

## Crea un label flotante con texto de feedback
## @param position: Posición inicial
## @param text: Texto a mostrar
## @param quality: "Perfect", "Bien", "Regular", "Miss"
## @param parent: Nodo padre
static func create_floating_label(position: Vector2, text: String, quality: String, parent: Node) -> void:
	var color: Color = COLORS.get(quality, COLORS["Neutral"])
	
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 101
	parent.add_child(label)
	
	# Flotar hacia arriba y desvanecer
	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(label, "position:y", position.y - 60, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.4)
	tween.chain().tween_callback(label.queue_free)

## Dibuja un trail/estela detrás de un objeto en movimiento
## @param from: Posición inicial
## @param to: Posición final
## @param color: Color del trail
## @param parent: Nodo padre
static func create_trail(from: Vector2, to: Vector2, color: Color, parent: Node) -> void:
	var trail := Line2D.new()
	trail.default_color = color
	trail.width = 3
	trail.add_point(from)
	trail.add_point(to)
	trail.z_index = 50
	parent.add_child(trail)
	
	# Desvanecer
	var tween := parent.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(trail, "modulate:a", 0.0, 0.3)
	tween.tween_callback(trail.queue_free)

## Crea un efecto de "glow" pulsante alrededor de un punto
## @param position: Centro del glow
## @param color: Color del efecto
## @param parent: Nodo padre
static func create_glow_pulse(position: Vector2, color: Color, parent: Node) -> void:
	var glow := Control.new()
	glow.position = position
	glow.z_index = 49
	glow.modulate = color
	parent.add_child(glow)
	
	var tween := parent.create_tween()
	tween.set_loops(3)
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	tween.tween_property(glow, "scale", Vector2.ONE * 1.3, 0.5)
	tween.tween_property(glow, "modulate:a", 0.2, 0.5)
	tween.chain().tween_callback(glow.queue_free)

## Helper: obtener color por calidad
static func get_quality_color(quality: String) -> Color:
	return COLORS.get(quality, COLORS["Neutral"])

## Helper: dibujar barra de progreso con estilo
static func draw_progress_bar(canvas: CanvasItem, rect: Rect2, progress: float, color: Color, bg_color: Color = COLORS["Surface"]) -> void:
	# Fondo
	canvas.draw_rect(rect, bg_color)
	
	# Progreso
	var filled_rect := Rect2(rect.position, Vector2(rect.size.x * clamp(progress, 0.0, 1.0), rect.size.y))
	canvas.draw_rect(filled_rect, color)
	
	# Borde
	canvas.draw_rect(rect, COLORS["Border"], false, 2)

## Helper: dibujar círculo con borde
static func draw_circle_outline(canvas: CanvasItem, position: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	canvas.draw_arc(position, radius, 0, TAU, 32, color, width, true)
