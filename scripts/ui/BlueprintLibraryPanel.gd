# res://scripts/ui/BlueprintLibraryPanel.gd
extends ColorRect

## Modal que muestra todos los blueprints disponibles (desbloqueados y bloqueados)
## SOLO PARA CONSULTA, no se encola desde aquí

@onready var blueprint_list: VBoxContainer = $PanelContainer/VBox/ScrollContainer/BlueprintList
@onready var close_btn: Button = $PanelContainer/VBox/TitleBar/CloseBtn

const BLUEPRINT_ROW_SCENE := preload("res://scenes/UI/BlueprintRow.tscn")

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	visible = false

func open() -> void:
	visible = true
	populate_blueprints()

func close() -> void:
	visible = false

func populate_blueprints() -> void:
	# Limpiar lista
	for child in blueprint_list.get_children():
		child.queue_free()
	
	# Obtener todos los blueprints del DataManager
	var dm = get_node("/root/DataManager") if has_node("/root/DataManager") else null
	if not dm or not dm.has_method("get_all_blueprints"):
		print("BlueprintLibrary: DataManager no disponible")
		return
	
	var all_blueprints = dm.get_all_blueprints()
	
	for bp_id in all_blueprints:
		var blueprint = all_blueprints[bp_id]
		var is_unlocked = dm.is_blueprint_unlocked(bp_id) if dm.has_method("is_blueprint_unlocked") else true
		
		# Crear fila para el blueprint (muestra TODOS, bloqueados y desbloqueados)
		var row = BLUEPRINT_ROW_SCENE.instantiate() if BLUEPRINT_ROW_SCENE else _create_fallback_row()
		blueprint_list.add_child(row)
		
		if row.has_method("set_blueprint_data"):
			row.set_blueprint_data(bp_id, blueprint, is_unlocked)
		else:
			# Fallback manual
			_setup_fallback_row(row, bp_id, blueprint, is_unlocked)

func _create_fallback_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.name = "Icon"
	row.add_child(icon)
	
	var name_label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.name = "NameLabel"
	row.add_child(name_label)
	
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	row.add_child(status_label)
	
	return row

func _setup_fallback_row(row: HBoxContainer, bp_id: String, blueprint, is_unlocked: bool) -> void:
	var name_label = row.get_node_or_null("NameLabel")
	var status_label = row.get_node_or_null("StatusLabel")
	var icon = row.get_node_or_null("Icon")
	
	if name_label:
		var display_name = blueprint.display_name if blueprint.has("display_name") else str(bp_id)
		name_label.text = display_name
		name_label.modulate = Color.WHITE if is_unlocked else Color(0.5, 0.5, 0.5)
	
	if status_label:
		status_label.text = "✓ Desbloqueado" if is_unlocked else "🔒 Bloqueado"
		status_label.modulate = Color.GREEN if is_unlocked else Color.GRAY
	
	if icon:
		# TODO: Cargar ícono del blueprint
		pass

func _on_close_pressed() -> void:
	close()
