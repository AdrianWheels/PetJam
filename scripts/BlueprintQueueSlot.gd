extends Panel

# Blueprint Queue Slot Script
# This script handles the display and interaction for a single blueprint slot in the queue

const MATERIAL_ICON_SCENE := preload("res://scenes/UI/MaterialIcon.tscn")

@onready var icon_rect: TextureRect = $VBoxContainer/Icon
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var materials_container: VBoxContainer = $VBoxContainer/MaterialsContainer

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
    var hbox = HBoxContainer.new()
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER

    var icon_node = MATERIAL_ICON_SCENE.instantiate()
    icon_node.custom_minimum_size = Vector2(20, 20)
    icon_node.set("material_name", material_name)
    hbox.add_child(icon_node)
    if has_node('/root/Logger'):
        get_node('/root/Logger').debug("BlueprintQueueSlot: created icon", {"material": material_name})

    var qty_label = Label.new()
    qty_label.text = str(quantity)
    hbox.add_child(qty_label)

    materials_container.add_child(hbox)
