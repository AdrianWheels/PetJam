extends HBoxContainer

# MaterialRow - Muestra icono + nombre + cantidad de un material

@onready var icon: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var quantity_label: Label = $QuantityLabel

# Material ID to display name mapping (English)
const MATERIAL_NAMES := {
	"iron": "Iron",
	"wood": "Wood",
	"leather": "Leather",
	"cloth": "Cloth",
	"herb": "Herb",
	"water": "Water",
	"fire": "Fire",
	"ice": "Ice",
	"poison": "Poison"
}

func set_material_data(material_id: String, quantity: int) -> void:
	# Try loading from MaterialResource first
	var material_resource_path = "res://data/materials/%s.tres" % material_id
	if ResourceLoader.exists(material_resource_path):
		var material_res = load(material_resource_path)
		if material_res:
			# Use display_name from resource if available
			if "display_name" in material_res and material_res.display_name != "":
				name_label.text = material_res.display_name
			else:
				name_label.text = MATERIAL_NAMES.get(material_id, material_id.capitalize())
			
			# Use icon from resource if available
			if "icon" in material_res and material_res.icon:
				icon.texture = material_res.icon
			else:
				_try_fallback_icon(material_id)
		else:
			# Failed to load resource
			name_label.text = MATERIAL_NAMES.get(material_id, material_id.capitalize())
			_try_fallback_icon(material_id)
	else:
		# Resource doesn't exist, use fallback
		name_label.text = MATERIAL_NAMES.get(material_id, material_id.capitalize())
		_try_fallback_icon(material_id)
	
	# Cantidad con color
	quantity_label.text = "x%d" % quantity
	
	# Color según cantidad
	if quantity == 0:
		quantity_label.modulate = Color(0.5, 0.5, 0.5)  # Gris si no hay
	elif quantity < 5:
		quantity_label.modulate = Color(1.0, 0.7, 0.3)  # Naranja si poco
	else:
		quantity_label.modulate = Color(0.3, 1.0, 0.3)  # Verde si suficiente


func _try_fallback_icon(material_id: String) -> void:
	"""Try to load fallback icon for material"""
	var icon_path = "res://art/placeholders/forge/material_%s.png" % material_id
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		# Final fallback to generic icon
		if ResourceLoader.exists("res://icon.svg"):
			icon.texture = load("res://icon.svg")
