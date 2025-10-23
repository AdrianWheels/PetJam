extends Panel

# Blueprint Queue Slot Script
# This script handles the display and interaction for a single blueprint slot in the queue

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var materials_container: VBoxContainer = $VBoxContainer/MaterialsContainer

func set_blueprint_name(blueprint_name: String):
	name_label.text = blueprint_name

func set_materials(materials) -> void:
	# Clear existing materials
	for child in materials_container.get_children():
		child.queue_free()

	# If materials is a Dictionary (map of id->qty), iterate keys
	if typeof(materials) == TYPE_DICTIONARY:
		for mat_id in materials.keys():
			var qty = materials[mat_id]
			var hbox = HBoxContainer.new()
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER

			# Use MaterialIcon scene for simple procedurally drawn icons
			var icon_scene = preload("res://scenes/UI/MaterialIcon.tscn")
			var icon_node = icon_scene.instantiate()
			icon_node.custom_minimum_size = Vector2(20, 20)
			icon_node.set("material_name", str(mat_id))
			hbox.add_child(icon_node)
			if has_node('/root/Logger'):
				get_node('/root/Logger').debug("BlueprintQueueSlot: created icon", {"material": mat_id})

			var qty_label = Label.new()
			qty_label.text = str(qty)
			hbox.add_child(qty_label)

			materials_container.add_child(hbox)
		return

	# If materials is an Array, try to interpret entries as {"id":..., "qty":...}
	if typeof(materials) == TYPE_ARRAY:
		for entry in materials:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("id") and entry.has("qty"):
				var hbox2 = HBoxContainer.new()
				hbox2.alignment = BoxContainer.ALIGNMENT_CENTER

				var icon_scene2 = preload("res://scenes/UI/MaterialIcon.tscn")
				var icon_node2 = icon_scene2.instantiate()
				icon_node2.custom_minimum_size = Vector2(20, 20)
				icon_node2.set("material_name", str(entry["id"]))
				hbox2.add_child(icon_node2)
				if has_node('/root/Logger'):
					get_node('/root/Logger').debug("BlueprintQueueSlot: created icon", {"material": entry["id"]})

				var qty_label2 = Label.new()
				qty_label2.text = str(entry["qty"])
				hbox2.add_child(qty_label2)

				materials_container.add_child(hbox2)
		return

	# Otherwise ignore unknown types
	return