extends Control
class_name DeliveryPanel

signal delivered_to_client(item_data)
signal delivered_to_hero(item_data)
signal cancelled

@onready var client_button: Button = %ClientButton
@onready var hero_button: Button = %HeroButton
@onready var cancel_button: Button = get_node_or_null("%CancelButton")

var _current_item_data: Dictionary = {}

func _ready() -> void:
	visible = false
	if client_button:
		client_button.pressed.connect(_on_client_pressed)
	if hero_button:
		hero_button.pressed.connect(_on_hero_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

func show_delivery_options(payload: Dictionary) -> void:
	_current_item_data = payload.duplicate(true)
	visible = true
	print("DeliveryPanel: Showing delivery options")

func hide_delivery() -> void:
	visible = false
	_current_item_data = {}
	print("DeliveryPanel: Hidden")

func _on_client_pressed() -> void:
	if _current_item_data.is_empty():
		return
	print("DeliveryPanel: Delivering to client")
	emit_signal("delivered_to_client", _current_item_data)
	hide_delivery()

func _on_hero_pressed() -> void:
	if _current_item_data.is_empty():
		return
	print("DeliveryPanel: Delivering to hero")
	emit_signal("delivered_to_hero", _current_item_data)
	hide_delivery()

func _on_cancel_pressed() -> void:
	print("DeliveryPanel: Cancelled delivery")
	cancelled.emit()
	hide_delivery()
