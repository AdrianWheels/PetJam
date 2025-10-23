@tool
extends Panel

# Blueprint Queue Slot Script
# This script handles the display and interaction for a single blueprint slot in the queue
# El decorador @tool permite que este script se ejecute en el editor de Godot

signal blueprint_clicked(slot_index: int)

const MATERIAL_ICON_SCENE := preload("res://scenes/UI/MaterialIcon.tscn")

@export var preview_blueprint_id: String = "" : set = _set_preview_blueprint
@export var preview_materials: Dictionary = {} : set = _set_preview_materials
@export var preview_slot_index: int = 0 : set = _set_preview_slot_index

var slot_index: int = -1

@onready var icon_rect: TextureRect = $VBoxContainer/Icon
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var materials_container: VBoxContainer = $VBoxContainer/MaterialsContainer

func _ready() -> void:
	if not Engine.is_editor_hint():
		gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if slot_index >= 0:
			emit_signal("blueprint_clicked", slot_index)
			print("BlueprintQueueSlot: Clicked slot %d" % slot_index)

func set_blueprint(blueprint: BlueprintResource) -> void:
	if blueprint == null:
		set_blueprint_name("(desconocido)")
		set_icon(null)
		set_materials({})
		return

	set_blueprint_name(blueprint.display_name if blueprint.display_name != "" else String(blueprint.blueprint_id))
	set_icon(blueprint.get_icon())
	set_materials(blueprint.materials)

func set_blueprint_name(blueprint_name: String) -> void:
	if not is_inside_tree():
		await ready
	name_label.text = blueprint_name

func set_icon(texture: Texture2D) -> void:
	if not is_inside_tree():
		await ready
	icon_rect.texture = texture

func set_materials(materials) -> void:
	if not is_inside_tree():
		await ready
	
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
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_node = MATERIAL_ICON_SCENE.instantiate()
	icon_node.custom_minimum_size = Vector2(20, 20)
	icon_node.set("material_name", material_name)
	hbox.add_child(icon_node)

	var qty_label = Label.new()
	qty_label.text = str(quantity)
	hbox.add_child(qty_label)

	materials_container.add_child(hbox)

# ===== PREVIEW EN EDITOR =====
# Estas funciones permiten previsualizar el blueprint en el editor sin ejecutar el juego

func _set_preview_blueprint(value: String) -> void:
	preview_blueprint_id = value
	if Engine.is_editor_hint() and is_inside_tree():
		_update_preview()

func _set_preview_materials(value: Dictionary) -> void:
	preview_materials = value
	if Engine.is_editor_hint() and is_inside_tree():
		set_materials(value)

func _set_preview_slot_index(value: int) -> void:
	preview_slot_index = value
	slot_index = value

func _update_preview() -> void:
	if preview_blueprint_id == "":
		set_blueprint_name("(vacío)")
		set_icon(null)
		set_materials({})
		return
	
	# Intentar cargar el blueprint desde DataManager (solo si está disponible)
	if has_node("/root/DataManager"):
		var dm = get_node("/root/DataManager")
		if dm.has_method("get_blueprint"):
			var bp = dm.get_blueprint(preview_blueprint_id)
			if bp:
				set_blueprint(bp)
				return
	
	# Fallback: mostrar solo el ID
	set_blueprint_name(preview_blueprint_id)
	set_materials(preview_materials if preview_materials.size() > 0 else {"iron": 2, "wood": 1})
