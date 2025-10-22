extends Panel

# Blueprint Queue Slot Script
# This script handles the display and interaction for a single blueprint slot in the queue

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var materials_container: VBoxContainer = $VBoxContainer/MaterialsContainer

func set_blueprint_name(blueprint_name: String):
	name_label.text = blueprint_name

func set_materials(materials: Dictionary):
	# Clear existing materials
	for child in materials_container.get_children():
		child.queue_free()
	
	# Add new material icons and quantities
	for mat in materials:
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		# TODO: Set texture based on mat
		hbox.add_child(icon)
		
		var qty_label = Label.new()
		qty_label.text = str(materials[mat])
		hbox.add_child(qty_label)
		
		materials_container.add_child(hbox)