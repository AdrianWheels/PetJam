extends Control
class_name ItemInfoPanel

@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name_label: Label = %ItemName
@onready var grade_label: Label = %GradeLabel
@onready var score_label: Label = %ScoreLabel

func _ready() -> void:
	visible = false

func show_item_info(payload: Dictionary) -> void:
	var blueprint: BlueprintResource = payload.get("blueprint", null) as BlueprintResource
	var grade: String = String(payload.get("grade", ""))
	var score: float = float(payload.get("score", 0.0))
	var max_score: float = float(payload.get("max_score", 100.0))
	
	# Mostrar nombre del ítem
	if blueprint:
		if item_name_label:
			var display_name := blueprint.display_name if blueprint.display_name != "" else String(blueprint.blueprint_id)
			item_name_label.text = display_name
		if item_icon:
			item_icon.texture = blueprint.get_icon()
	else:
		var item_id = payload.get("item_id", "unknown")
		if item_name_label:
			item_name_label.text = String(item_id).capitalize()
		if item_icon:
			item_icon.texture = null
	
	# Mostrar grado
	if grade_label:
		var grade_text = "Calidad: " + (grade.capitalize() if grade != "" else "Sin calificar")
		grade_label.text = grade_text
	
	# Mostrar puntuación
	if score_label:
		if max_score > 0.0:
			var percent: float = clamp(score / max_score, 0.0, 1.0) * 100.0
			score_label.text = "Puntaje: %.0f%%" % percent
		else:
			score_label.text = "Puntaje: %.0f" % score
	
	visible = true
	print("ItemInfoPanel: Showing item info")

func hide_info() -> void:
	visible = false
	print("ItemInfoPanel: Hidden")
