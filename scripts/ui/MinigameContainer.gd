extends SubViewportContainer

## MinigameContainer - Contenedor con recorte visual REAL para minijuegos
## Usa SubViewport para recortar canvas drawing (_draw calls)
## AHORA CON MÁSCARA CIRCULAR

@onready var _viewport: SubViewport = $SubViewport

func _ready() -> void:
	# SubViewportContainer con stretch=true recorta automáticamente
	stretch = true
	# 🖱️ CAMBIO: PASS en lugar de IGNORE para permitir clicks en minijuegos
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Aplicar shader de máscara circular
	_apply_circular_mask()
	
	# Conectar cuando se añade un hijo AL VIEWPORT (no al container)
	if _viewport:
		_viewport.child_entered_tree.connect(_on_minigame_added)
		print("[MinigameContainer] Ready - Viewport Size: %s, Stretch: true, Mouse: PASS, Circular Mask: ACTIVE" % [_viewport.size])
	else:
		push_error("[MinigameContainer] SubViewport not found!")

func _apply_circular_mask() -> void:
	"""Aplica shader de máscara circular al SubViewportContainer"""
	var shader := load("res://shaders/circular_mask.gdshader") as Shader
	if not shader:
		push_error("[MinigameContainer] No se pudo cargar circular_mask.gdshader")
		return
	
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	
	# Por defecto usa máscara circular
	shader_material.set_shader_parameter("use_texture_mask", false)
	shader_material.set_shader_parameter("radius", 0.48)
	shader_material.set_shader_parameter("center", Vector2(0.5, 0.5))
	shader_material.set_shader_parameter("softness", 0.02)
	shader_material.set_shader_parameter("feather", 0.05)
	
	material = shader_material
	print("[MinigameContainer] Máscara circular aplicada")

func set_texture_mask(mask_texture: Texture2D, threshold: float = 0.5) -> void:
	"""Cambia a usar una textura como máscara"""
	if material and material is ShaderMaterial:
		material.set_shader_parameter("use_texture_mask", true)
		material.set_shader_parameter("mask_texture", mask_texture)
		material.set_shader_parameter("mask_threshold", threshold)
		print("[MinigameContainer] Máscara de textura aplicada")
	else:
		push_warning("[MinigameContainer] No se puede aplicar máscara de textura: material no es ShaderMaterial")

func set_circular_mask(radius: float = 0.48, center: Vector2 = Vector2(0.5, 0.5)) -> void:
	"""Cambia a usar máscara circular"""
	if material and material is ShaderMaterial:
		material.set_shader_parameter("use_texture_mask", false)
		material.set_shader_parameter("radius", radius)
		material.set_shader_parameter("center", center)
		print("[MinigameContainer] Máscara circular aplicada")
	else:
		push_warning("[MinigameContainer] No se puede aplicar máscara circular: material no es ShaderMaterial")


func _on_minigame_added(child: Node) -> void:
	if not (child is Control):
		return
	
	var minigame := child as Control
	
	# Forzar que el minijuego ocupe todo el viewport
	minigame.anchor_left = 0.0
	minigame.anchor_top = 0.0
	minigame.anchor_right = 1.0
	minigame.anchor_bottom = 1.0
	minigame.offset_left = 0.0
	minigame.offset_top = 0.0
	minigame.offset_right = 0.0
	minigame.offset_bottom = 0.0
	
	print("[MinigameContainer] Minigame '%s' added to viewport (800x560)" % child.name)
