extends SubViewportContainer

## MinigameContainer - Contenedor con recorte visual REAL para minijuegos
## Usa SubViewport para recortar canvas drawing (_draw calls)

@onready var _viewport: SubViewport = $SubViewport

func _ready() -> void:
	# SubViewportContainer con stretch=true recorta automáticamente
	stretch = true
	# 🖱️ CAMBIO: PASS en lugar de IGNORE para permitir clicks en minijuegos
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Conectar cuando se añade un hijo AL VIEWPORT (no al container)
	if _viewport:
		_viewport.child_entered_tree.connect(_on_minigame_added)
		print("[MinigameContainer] Ready - Viewport Size: %s, Stretch: true, Mouse: PASS" % [_viewport.size])
	else:
		push_error("[MinigameContainer] SubViewport not found!")

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
