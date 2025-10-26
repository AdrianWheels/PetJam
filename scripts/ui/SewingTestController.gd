extends Node

## 🧵 Controlador de prueba para sistemas de costura

# 🖱️ Cursor custom
const CUSTOM_CURSOR_PATH := "res://art/assets/Imagenes/Cursor/staff_with_cloth_sin_fondo.png"
var _custom_cursor: Texture2D = null

@onready var _thread_spring: Node2D = get_parent().get_node("ThreadSpring")
@onready var _stitch_visual: Node2D = get_parent().get_node("StitchVisual")
@onready var _parent: Control = get_parent()

func _ready() -> void:
	# Cargar y activar cursor custom (ya configura el offset internamente)
	_load_custom_cursor()
	
	# Activar stitch visual inmediatamente
	_stitch_visual.enable()
	print("✅ Sistema de costura listo")
	print("  • Click izquierdo: añadir punto")
	print("  • Click derecho: toggle hilo spring")
	print("  • Z: deshacer punto")
	print("  • C: limpiar")

func _load_custom_cursor() -> void:
	"""Carga, escala y activa el cursor custom."""
	if ResourceLoader.exists(CUSTOM_CURSOR_PATH):
		var original_texture := load(CUSTOM_CURSOR_PATH) as Texture2D
		if original_texture:
			# El cursor es 1024x1024, lo escalamos a ~205x205 (1024/5)
			var original_size := original_texture.get_size()
			var scale_factor := 5.0
			var new_size := Vector2i(
				int(original_size.x / scale_factor),
				int(original_size.y / scale_factor)
			)
			
			# Crear imagen escalada
			var original_image := original_texture.get_image()
			original_image.resize(new_size.x, new_size.y, Image.INTERPOLATE_LANCZOS)
			
			# 🎨 Añadir sombra sutil para dar sensación de profundidad
			var shadow_image := _create_cursor_with_shadow(original_image)
			
			# Convertir a texture
			_custom_cursor = ImageTexture.create_from_image(shadow_image)
			
			# Hotspot en esquina INFERIOR IZQUIERDA (la punta, punto de click)
			var hotspot := Vector2(0, new_size.y)
			
			Input.set_custom_mouse_cursor(_custom_cursor, Input.CURSOR_ARROW, hotspot)
			print("✅ Cursor custom activado y escalado")
			print("   • Tamaño original: %v" % original_size)
			print("   • Tamaño nuevo: %v" % new_size)
			print("   • Factor de escala: 1/%d" % scale_factor)
			print("   • Hotspot: %v (esquina inferior izquierda = punta)" % hotspot)
			
			# Configurar offset del hilo: desde la punta hacia el ojo de la aguja (sup. derecha)
			# Offset: ancho completo hacia la derecha, altura completa hacia arriba, -15px ajuste
			var thread_offset := Vector2(new_size.x - 15, -new_size.y)
			_thread_spring.cursor_offset = thread_offset
			print("   • Offset del hilo: %v (ojo de la aguja)" % thread_offset)
		else:
			push_warning("⚠️ No se pudo cargar el cursor: %s" % CUSTOM_CURSOR_PATH)
	else:
		push_warning("⚠️ Cursor no encontrado: %s" % CUSTOM_CURSOR_PATH)

func _process(_delta: float) -> void:
	# Actualizar posición del hilo con el mouse
	if _thread_spring and _thread_spring.get("_enabled"):
		_thread_spring.update_target(get_viewport().get_mouse_position())

func _input(event: InputEvent) -> void:
	# Click izquierdo: añadir punto de costura
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		_stitch_visual.add_point(pos)
		print("➕ Punto añadido en: %v (Total: %d)" % [pos, _stitch_visual.get_point_count()])
		_parent.accept_event()
	
	# Click derecho: toggle hilo spring
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _thread_spring.get("_enabled"):
			_thread_spring.disable()
			print("🧵 Hilo desactivado")
		else:
			_thread_spring.enable(event.position)
			print("🧵 Hilo activado")
		_parent.accept_event()
	
	# Z: deshacer
	elif event is InputEventKey and event.pressed and event.keycode == KEY_Z:
		_stitch_visual.remove_last_point()
		print("↩️ Punto eliminado (Total: %d)" % _stitch_visual.get_point_count())
		_parent.accept_event()
	
	# C: limpiar
	elif event is InputEventKey and event.pressed and event.keycode == KEY_C:
		_stitch_visual.clear_points()
		print("🧹 Puntos limpiados")
		_parent.accept_event()

func _create_cursor_with_shadow(base_image: Image) -> Image:
	"""Añade una sombra sutil al cursor para dar sensación de profundidad."""
	var size := base_image.get_size()
	var shadow_offset := Vector2i(3, 3)  # Offset de la sombra (abajo-derecha)
	
	# Crear imagen con espacio para la sombra
	var result := Image.create(size.x + shadow_offset.x, size.y + shadow_offset.y, false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))  # Transparente
	
	# Dibujar sombra (versión semi-transparente oscura)
	for y in range(size.y):
		for x in range(size.x):
			var pixel := base_image.get_pixel(x, y)
			if pixel.a > 0.1:  # Si el pixel no es transparente
				var shadow_color := Color(0, 0, 0, pixel.a * 0.3)  # Sombra negra al 30% de opacidad
				result.set_pixel(x + shadow_offset.x, y + shadow_offset.y, shadow_color)
	
	# Dibujar imagen original encima
	for y in range(size.y):
		for x in range(size.x):
			var pixel := base_image.get_pixel(x, y)
			if pixel.a > 0.0:
				result.set_pixel(x, y, pixel)
	
	return result
