# res://scripts/ui/RequestsPanel.gd
extends ColorRect

## Panel que muestra los pedidos activos del cliente
## El jugador elige un pedido para aceptarlo y craftéarlo

signal request_selected(request_index: int)

var requests_container: VBoxContainer
var close_btn: Button
var refresh_btn: Button

const REQUEST_ROW_SCENE: PackedScene = null  # Se usará fallback en _create_fallback_row

var _requests_manager: Node

func _ready() -> void:
	visible = false
	
	# Intentar encontrar nodos existentes primero
	requests_container = get_node_or_null("%RequestsContainer")
	close_btn = get_node_or_null("%CloseBtn")
	refresh_btn = get_node_or_null("%RefreshBtn")
	
	# Si no existen los nodos necesarios, crearlos automáticamente
	if not requests_container or not close_btn:
		_create_ui_structure()
	else:
		# Conectar botones existentes
		if close_btn:
			close_btn.pressed.connect(_on_close_pressed)
		if refresh_btn:
			refresh_btn.pressed.connect(_on_refresh_pressed)
	
	_requests_manager = get_node_or_null("/root/RequestsManager")
	if _requests_manager:
		if _requests_manager.has_signal("requests_refreshed"):
			_requests_manager.requests_refreshed.connect(_on_requests_refreshed)
	else:
		print("RequestsPanel: RequestsManager no encontrado como AutoLoad")

func _create_ui_structure() -> void:
	"""Crea la estructura UI si no existe"""
	print("RequestsPanel: Creando estructura UI automática")
	
	# Asegurarse de que este nodo tenga un nombre reconocible
	name = "RequestsPanel"
	
	# ColorRect ya existe (self), crear contenido
	color = Color(0.1, 0.1, 0.1, 0.95)
	
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)
	
	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	var title := Label.new()
	title.text = "PEDIDOS DISPONIBLES"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var close_button := Button.new()
	close_button.name = "CloseBtn"
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	close_btn = close_button
	
	# Scroll container
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(600, 400)
	vbox.add_child(scroll)
	
	var container := VBoxContainer.new()
	container.name = "RequestsContainer"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(container)
	requests_container = container
	
	# Footer con botón refresh
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(footer)
	
	var refresh_button := Button.new()
	refresh_button.name = "RefreshBtn"
	refresh_button.text = "🔄 Actualizar Pedidos"
	refresh_button.custom_minimum_size = Vector2(200, 40)
	refresh_button.pressed.connect(_on_refresh_pressed)
	footer.add_child(refresh_button)
	refresh_btn = refresh_button

func open() -> void:
	print("RequestsPanel: open() llamado, visible=%s" % visible)
	visible = true
	_populate_requests()
	print("RequestsPanel: Panel ahora visible")

func close() -> void:
	visible = false

func _populate_requests() -> void:
	if not requests_container:
		print("RequestsPanel: RequestsContainer no encontrado")
		return
	
	# Limpiar lista
	for child in requests_container.get_children():
		child.queue_free()
	
	if not _requests_manager or not _requests_manager.has_method("get_active_requests"):
		print("RequestsPanel: RequestsManager no disponible")
		return
	
	var requests: Array = _requests_manager.get_active_requests()
	
	if requests.is_empty():
		var label := Label.new()
		label.text = "No hay pedidos disponibles"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		requests_container.add_child(label)
		return
	
	for i in range(requests.size()):
		var request: Dictionary = requests[i]
		var row: Control
		
		if REQUEST_ROW_SCENE:
			row = REQUEST_ROW_SCENE.instantiate()
		else:
			row = _create_fallback_row()
		
		requests_container.add_child(row)
		
		if row.has_method("set_request_data"):
			row.set_request_data(request, i)
		else:
			_setup_fallback_row(row, request, i)
		
		# Conectar señal de clic
		if row.has_signal("request_clicked"):
			row.request_clicked.connect(_on_request_row_clicked)

func _create_fallback_row() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 80)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	
	var hbox := HBoxContainer.new()
	margin.add_child(hbox)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	var client_label := Label.new()
	client_label.name = "ClientLabel"
	client_label.add_theme_font_size_override("font_size", 12)
	client_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(client_label)
	
	var reward_label := Label.new()
	reward_label.name = "RewardLabel"
	reward_label.add_theme_font_size_override("font_size", 14)
	reward_label.modulate = Color(1, 0.85, 0.3)
	vbox.add_child(reward_label)
	
	var accept_btn := Button.new()
	accept_btn.name = "AcceptBtn"
	accept_btn.text = "Aceptar"
	accept_btn.custom_minimum_size = Vector2(100, 40)
	hbox.add_child(accept_btn)
	
	return panel

func _setup_fallback_row(row: Control, request: Dictionary, index: int) -> void:
	var blueprint: BlueprintResource = request.get("blueprint")
	var client_name: String = request.get("client_name", "Cliente Anónimo")
	var reward: int = request.get("gold_reward", 50)
	
	var name_label := row.find_child("NameLabel", true, false) as Label
	var client_label := row.find_child("ClientLabel", true, false) as Label
	var reward_label := row.find_child("RewardLabel", true, false) as Label
	var accept_btn := row.find_child("AcceptBtn", true, false) as Button
	
	if name_label and blueprint:
		name_label.text = blueprint.display_name if blueprint.display_name != "" else String(blueprint.blueprint_id)
	
	if client_label:
		client_label.text = "Cliente: " + client_name
	
	if reward_label:
		reward_label.text = "Recompensa: %d oro" % reward
	
	if accept_btn:
		accept_btn.pressed.connect(func(): _on_request_row_clicked(index))

func _on_request_row_clicked(index: int) -> void:
	print("RequestsPanel: Request %d selected" % index)
	if _requests_manager and _requests_manager.has_method("accept_request"):
		var success: bool = _requests_manager.accept_request(index)
		if success:
			print("RequestsPanel: Request accepted and enqueued")
			close()
		else:
			print("RequestsPanel: Failed to accept request (queue full?)")

func _on_requests_refreshed(_requests: Array) -> void:
	if visible:
		_populate_requests()

func _on_close_pressed() -> void:
	close()

func _on_refresh_pressed() -> void:
	if _requests_manager and _requests_manager.has_method("refresh_all_requests"):
		_requests_manager.refresh_all_requests()
		print("RequestsPanel: Requests refreshed")
