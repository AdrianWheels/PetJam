# res://scripts/ui/BlueprintLibraryPanel.gd
extends ColorRect

## Modal que muestra todos los blueprints disponibles (desbloqueados y bloqueados)
## y deja encargar piezas propias (selector de rango y «Forjar» en cada tarjeta)

@onready var blueprint_list: GridContainer = $PanelContainer/VBox/ScrollContainer/BlueprintList
@onready var close_btn: Button = $PanelContainer/VBox/TitleBar/CloseBtn

const BLUEPRINT_CARD_SCENE := preload("res://scenes/UI/BlueprintCard.tscn")
const REJECT_TEXTS := {
	&"no_materials": "Faltan materiales",
	&"queue_full": "La forja está llena",
	&"locked": "Rango bloqueado",
}

const REJECT_SECONDS := 1.4

signal own_order_requested(bp_id: StringName, rank: int)

var _cards: Dictionary = {}  # bp_id -> tarjeta

func _ready() -> void:
	UIClarity.panel_title($PanelContainer/VBox/TitleBar/Title)
	UIClarity.close_button(close_btn)
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
	_cards.clear()
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
		
		var rank: int = dm.get_unlocked_rank(bp_id) if dm.has_method("get_unlocked_rank") else (1 if is_unlocked else 0)
		if card.has_method("set_blueprint_data"):
			card.set_blueprint_data(bp_id, blueprint, is_unlocked, rank)
		if card.has_signal("forge_requested"):
			card.forge_requested.connect(func(id, r): own_order_requested.emit(id, r))
		_cards[bp_id] = card

## El encargo no se ha podido hacer: la tarjeta tiembla y el motivo se ve en su nombre un momento.
func reject(bp_id: StringName, reason: StringName) -> void:
	var card = _cards.get(bp_id)
	if card == null or not is_instance_valid(card):
		return
	card.reject_feedback()
	var label: Label = card.name_label
	label.text = tr(REJECT_TEXTS.get(reason, "Faltan materiales"))
	label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	# Solo restaura el último rechazo: el nombre real lo vuelve a poner la propia tarjeta
	var token: int = int(card.get_meta(&"reject_token", 0)) + 1
	card.set_meta(&"reject_token", token)
	get_tree().create_timer(REJECT_SECONDS).timeout.connect(func():
		if is_instance_valid(card) and int(card.get_meta(&"reject_token", 0)) == token:
			card._refresh_rank()
			label.remove_theme_color_override("font_color"))


func _on_close_pressed() -> void:
	close()
