extends HBoxContainer

# MaterialRow - Muestra icono + nombre + cantidad de un material

@onready var icon: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var quantity_label: Label = $QuantityLabel

# Mapeo de material_id a nombres legibles en español
const MATERIAL_NAMES := {
	"iron": "Hierro",
	"wood": "Madera",
	"leather": "Cuero",
	"fiber": "Fibra",
	"herb": "Hierba",
	"water": "Agua",
	"gold": "Oro"
}

func set_material_data(material_id: String, quantity: int) -> void:
	# Cargar icono del material
	var icon_path = "res://art/placeholders/forge/material_%s.png" % material_id
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		# Fallback a icono genérico
		if ResourceLoader.exists("res://icon.svg"):
			icon.texture = load("res://icon.svg")
	
	# Nombre legible
	var display_name = MATERIAL_NAMES.get(material_id, material_id.capitalize())
	name_label.text = display_name
	
	# Cantidad con color
	quantity_label.text = "x%d" % quantity
	
	# Color según cantidad
	if quantity == 0:
		quantity_label.modulate = Color(0.5, 0.5, 0.5)  # Gris si no hay
	elif quantity < 5:
		quantity_label.modulate = Color(1.0, 0.7, 0.3)  # Naranja si poco
	else:
		quantity_label.modulate = Color(0.3, 1.0, 0.3)  # Verde si suficiente
