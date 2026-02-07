extends PanelContainer

# Request Slot Script
# Este script maneja la visualización e interacción de un pedido individual en la cola de pedidos

signal blueprint_clicked(slot_index: int)

const MATERIAL_ICON_SCENE := preload("res://scenes/UI/MaterialIcon.tscn")

var slot_index: int = -1

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconContainer/Icon
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var materials_container: HBoxContainer = $MarginContainer/HBoxContainer/VBoxContainer/MaterialsContainer

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if slot_index >= 0:
			emit_signal("blueprint_clicked", slot_index)
			print("RequestSlot: Clicked slot %d" % slot_index)

func set_blueprint(blueprint: BlueprintResource) -> void:
	if blueprint == null:
		set_blueprint_name("(unknown)")
		set_icon(null)
		set_materials({})
		return

	set_blueprint_name(blueprint.display_name if blueprint.display_name != "" else String(blueprint.blueprint_id))
	set_icon(blueprint.get_blueprint_icon())  # Usar icono del blueprint para cola de pedidos
	set_materials(blueprint.materials)

func set_blueprint_name(blueprint_name: String) -> void:
	name_label.text = blueprint_name

func set_icon(texture: Texture2D) -> void:
	icon_rect.texture = texture

func set_materials(materials) -> void:
	# Clear existing materials
	for child in materials_container.get_children():
		child.queue_free()

	# If materials is a Dictionary (map of id->qty), iterate keys
	if typeof(materials) == TYPE_DICTIONARY:
		for mat_id in materials.keys():
			var qty = materials[mat_id]
			_add_material_row(str(mat_id), qty)
		return

	# If materials is an Array, try to interpret entries as {"id":..., "qty":...}
	if typeof(materials) == TYPE_ARRAY:
		for entry in materials:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("id") and entry.has("qty"):
				_add_material_row(str(entry["id"]), entry["qty"])
		return

	# Otherwise ignore unknown types
	pass

func _add_material_row(material_name: String, quantity) -> void:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var icon_node = MATERIAL_ICON_SCENE.instantiate()
	icon_node.custom_minimum_size = Vector2(24, 24)
	icon_node.set("material_name", material_name)
	container.add_child(icon_node)

	var qty_label = Label.new()
	qty_label.text = "x%s" % str(quantity)
	qty_label.add_theme_font_size_override("font_size", 14)
	qty_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	container.add_child(qty_label)

	materials_container.add_child(container)
