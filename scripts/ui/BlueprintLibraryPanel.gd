# res://scripts/ui/BlueprintLibraryPanel.gd
extends ColorRect

## Modal que muestra todos los blueprints disponibles (desbloqueados y bloqueados)
## SOLO PARA CONSULTA, no se encola desde aquí

@onready var blueprint_list: GridContainer = $PanelContainer/VBox/ScrollContainer/BlueprintList
@onready var close_btn: Button = $PanelContainer/VBox/TitleBar/CloseBtn

const BLUEPRINT_CARD_SCENE := preload("res://scenes/UI/BlueprintCard.tscn")

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP  # Capturar clicks en el fondo

func _gui_input(event: InputEvent) -> void:
	# Cerrar al hacer click en el fondo oscuro
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Verificar si el click fue en el fondo y no en el panel
		var panel_container = get_node_or_null("PanelContainer")
		if panel_container:
			var local_pos = panel_container.get_local_mouse_position()
			var panel_rect = Rect2(Vector2.ZERO, panel_container.size)
			if not panel_rect.has_point(local_pos):
				close()
				accept_event()

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
		
		# Crear tarjeta para el blueprint
		var card = BLUEPRINT_CARD_SCENE.instantiate()
		blueprint_list.add_child(card)
		
		if card.has_method("set_blueprint_data"):
			card.set_blueprint_data(bp_id, blueprint, is_unlocked)

func _on_close_pressed() -> void:
	close()
