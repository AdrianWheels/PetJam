# res://scripts/ui/BlueprintRow.gd
extends HBoxContainer

## Fila que muestra un blueprint en la biblioteca

@onready var icon: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var materials_label: Label = $MaterialsLabel
@onready var status_label: Label = $StatusLabel

func set_blueprint_data(bp_id: String, blueprint, is_unlocked: bool) -> void:
	# Nombre
	var display_name: String = ""
	if blueprint is BlueprintResource:
		display_name = blueprint.display_name if blueprint.display_name != "" else str(bp_id)
	else:
		display_name = str(bp_id)
	name_label.text = display_name
	
	# Materiales
	if blueprint is BlueprintResource and not blueprint.materials.is_empty():
		var mats = blueprint.materials
		var mat_text = ""
		for mat_id in mats:
			var qty = mats[mat_id]
			mat_text += "%s x%d, " % [mat_id, qty]
		materials_label.text = mat_text.trim_suffix(", ")
	else:
		materials_label.text = "---"
	
	# Estado
	if is_unlocked:
		status_label.text = "✓ Desbloqueado"
		status_label.modulate = Color.GREEN
		name_label.modulate = Color.WHITE
		materials_label.modulate = Color.WHITE
	else:
		status_label.text = "🔒 Bloqueado"
		status_label.modulate = Color.GRAY
		name_label.modulate = Color(0.5, 0.5, 0.5)
		materials_label.modulate = Color(0.5, 0.5, 0.5)
	
	# TODO: Cargar ícono del blueprint
	# var icon_path = "res://art/placeholders/blueprint_%s.png" % bp_id
	# if ResourceLoader.exists(icon_path):
	#     icon.texture = load(icon_path)
