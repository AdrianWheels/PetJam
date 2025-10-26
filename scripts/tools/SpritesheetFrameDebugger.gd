extends Control
# =====================================================
# Spritesheet Frame Debugger
# Herramienta para visualizar y seleccionar frames de spritesheets
# =====================================================

# UI References
@onready var texture_path_input: LineEdit = $VBoxContainer/PathContainer/TexturePathInput
@onready var load_button: Button = $VBoxContainer/PathContainer/LoadButton
@onready var hframes_input: SpinBox = $VBoxContainer/ConfigContainer/HFramesInput
@onready var fps_slider: HSlider = $VBoxContainer/ConfigContainer/FPSSlider
@onready var fps_label: Label = $VBoxContainer/ConfigContainer/FPSLabel
@onready var preview_sprite: Sprite2D = $VBoxContainer/PreviewContainer/PreviewPanel/PreviewSprite
@onready var frames_scroll: ScrollContainer = $VBoxContainer/FramesScroll
@onready var frames_grid: GridContainer = $VBoxContainer/FramesScroll/FramesGrid
@onready var export_button: Button = $VBoxContainer/ButtonsContainer/ExportButton
@onready var select_all_button: Button = $VBoxContainer/ButtonsContainer/SelectAllButton
@onready var deselect_all_button: Button = $VBoxContainer/ButtonsContainer/DeselectAllButton
@onready var info_label: Label = $VBoxContainer/InfoLabel

# State
var current_texture: Texture2D = null
var total_frames: int = 62
var animation_fps: float = 12.0
var animation_timer: float = 0.0
var current_frame: int = 0
var is_playing: bool = true
var selected_frames: Array[bool] = []  # true = incluir, false = excluir

# Frame buttons
var frame_buttons: Array[CheckButton] = []

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	print("🎬 Spritesheet Frame Debugger loaded")
	print("   SPACE: Pause/Play")
	print("   A: Select All | D: Deselect All | R: Reset")

func _setup_ui() -> void:
	"""Configurar UI inicial"""
	if fps_slider:
		fps_slider.min_value = 1.0
		fps_slider.max_value = 60.0
		fps_slider.value = animation_fps
		_update_fps_label()
	
	if hframes_input:
		hframes_input.min_value = 1
		hframes_input.max_value = 200
		hframes_input.value = total_frames
	
	if texture_path_input:
		texture_path_input.text = "res://art/assets/Spritesheets/Hero/hero_walk_01_12fps.png"
	
	if frames_grid:
		frames_grid.columns = 10  # 10 columnas para el grid

func _connect_signals() -> void:
	"""Conectar señales de UI"""
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	
	if fps_slider:
		fps_slider.value_changed.connect(_on_fps_changed)
	
	if hframes_input:
		hframes_input.value_changed.connect(_on_hframes_changed)
	
	if export_button:
		export_button.pressed.connect(_on_export_pressed)
	
	if select_all_button:
		select_all_button.pressed.connect(_on_select_all_pressed)
	
	if deselect_all_button:
		deselect_all_button.pressed.connect(_on_deselect_all_pressed)

func _process(delta: float) -> void:
	if not is_playing or not current_texture or not preview_sprite:
		return
	
	animation_timer += delta
	var frame_duration = 1.0 / animation_fps
	
	if animation_timer >= frame_duration:
		animation_timer -= frame_duration
		
		# Avanzar solo por frames seleccionados
		var next_frame = (current_frame + 1) % total_frames
		var iterations = 0
		
		while not selected_frames[next_frame] and iterations < total_frames:
			next_frame = (next_frame + 1) % total_frames
			iterations += 1
		
		# Si encontró un frame seleccionado, mostrarlo
		if iterations < total_frames:
			current_frame = next_frame
			preview_sprite.frame = current_frame

func _on_load_pressed() -> void:
	"""Cargar spritesheet desde la ruta especificada"""
	if not texture_path_input:
		return
	
	var path = texture_path_input.text.strip_edges()
	if not ResourceLoader.exists(path):
		_show_error("Texture not found: %s" % path)
		return
	
	var tex = load(path) as Texture2D
	if not tex:
		_show_error("Failed to load texture")
		return
	
	_load_spritesheet(tex)

func _on_hframes_changed(value: float) -> void:
	"""Cambiar número de frames horizontales"""
	total_frames = int(value)
	if current_texture:
		_load_spritesheet(current_texture)

func _load_spritesheet(tex: Texture2D) -> void:
	"""Cargar y analizar un spritesheet"""
	current_texture = tex
	
	# Inicializar frames seleccionados (todos activos por defecto)
	selected_frames.clear()
	selected_frames.resize(total_frames)
	selected_frames.fill(true)
	
	# Configurar preview sprite
	if preview_sprite:
		preview_sprite.texture = tex
		preview_sprite.hframes = total_frames
		preview_sprite.frame = 0
		# Escalar sprite para que se vea bien
		var frame_width = float(tex.get_width()) / float(total_frames)
		var target_size = 200.0  # Tamaño objetivo en pixeles
		preview_sprite.scale = Vector2.ONE * (target_size / frame_width)
	
	# Generar grid de frames
	_generate_frames_grid()
	
	_update_info_label()
	current_frame = 0
	
	print("✅ Loaded spritesheet: %d frames, %dx%d px total" % [total_frames, tex.get_width(), tex.get_height()])

func _generate_frames_grid() -> void:
	"""Generar grid de checkboxes para cada frame"""
	if not frames_grid:
		return
	
	# Limpiar grid existente
	for child in frames_grid.get_children():
		child.queue_free()
	frame_buttons.clear()
	
	# Crear checkbox para cada frame
	for i in range(total_frames):
		var check = CheckButton.new()
		check.text = "F%d" % i
		check.button_pressed = true
		check.tooltip_text = "Frame %d" % i
		check.toggled.connect(_on_frame_toggled.bind(i))
		frames_grid.add_child(check)
		frame_buttons.append(check)

func _on_frame_toggled(enabled: bool, frame_idx: int) -> void:
	"""Toggle frame selection"""
	if frame_idx < 0 or frame_idx >= total_frames:
		return
	
	selected_frames[frame_idx] = enabled
	_update_info_label()
	print("Frame %d: %s" % [frame_idx, "✅" if enabled else "❌"])

func _on_fps_changed(value: float) -> void:
	"""Cambiar FPS de reproducción"""
	animation_fps = value
	_update_fps_label()

func _update_fps_label() -> void:
	"""Actualizar etiqueta de FPS"""
	if fps_label:
		fps_label.text = "FPS: %.0f" % animation_fps

func _update_info_label() -> void:
	"""Actualizar información del spritesheet"""
	if not info_label:
		return
	
	var selected_count = selected_frames.count(true)
	var text = "📊 Total: %d | Selected: %d" % [total_frames, selected_count]
	
	if current_texture:
		text += " | Resolution: %dx%d" % [current_texture.get_width(), current_texture.get_height()]
	
	text += " | %s" % ("▶️ Playing" if is_playing else "⏸️ Paused")
	
	info_label.text = text

func _on_export_pressed() -> void:
	"""Exportar lista de frames seleccionados"""
	var selected_indices: Array[int] = []
	for i in range(total_frames):
		if selected_frames[i]:
			selected_indices.append(i)
	
	print("\n📋 SELECTED FRAMES EXPORT:")
	print("   Indices: ", selected_indices)
	print("   Total: %d frames" % selected_indices.size())
	print("   Percentage: %.1f%%" % (100.0 * selected_indices.size() / total_frames))
	
	# Copiar al clipboard
	var clipboard_text = "Selected frames (%d/%d): %s" % [selected_indices.size(), total_frames, str(selected_indices)]
	DisplayServer.clipboard_set(clipboard_text)
	print("✅ Copied to clipboard!\n")

func _on_select_all_pressed() -> void:
	"""Seleccionar todos los frames"""
	for i in range(total_frames):
		selected_frames[i] = true
		if i < frame_buttons.size():
			frame_buttons[i].button_pressed = true
	_update_info_label()
	print("✅ All %d frames selected" % total_frames)

func _on_deselect_all_pressed() -> void:
	"""Deseleccionar todos los frames"""
	for i in range(total_frames):
		selected_frames[i] = false
		if i < frame_buttons.size():
			frame_buttons[i].button_pressed = false
	_update_info_label()
	print("❌ All frames deselected")

func _show_error(message: String) -> void:
	"""Mostrar mensaje de error"""
	if info_label:
		info_label.text = "❌ ERROR: " + message
	printerr(message)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				is_playing = !is_playing
				_update_info_label()
				print("⏯️  %s" % ("Playing" if is_playing else "Paused"))
			
			KEY_A:
				_on_select_all_pressed()
			
			KEY_D:
				_on_deselect_all_pressed()
			
			KEY_R:
				# Reset to all selected
				_on_select_all_pressed()
				print("🔄 Reset to all frames selected")
