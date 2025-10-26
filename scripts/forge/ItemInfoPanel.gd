extends Control
class_name ItemInfoPanel

const QualityUtils = preload("res://scripts/core/QualityHelper.gd")

@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name_label: Label = %ItemName
@onready var grade_label: Label = %GradeLabel
@onready var score_label: Label = %ScoreLabel

func _ready() -> void:
	visible = false

func show_item_info(payload: Dictionary) -> void:
	var blueprint: BlueprintResource = payload.get("blueprint", null) as BlueprintResource
	var score: float = float(payload.get("score", 0.0))
	var max_score: float = float(payload.get("max_score", 100.0))
	
	# Calcular quality normalizada
	var quality: float = clamp(score / max_score if max_score > 0.0 else 0.0, 0.0, 1.0)
	
	# 🔊 Reproducir SFX según calidad
	var quality_label_text = QualityUtils.get_quality_label(quality).to_lower()
	var craft_sfx: AudioStream
	
	match quality_label_text:
		"legendary", "gold":
			craft_sfx = load("res://art/sounds/sfx/craft/craft_gold.wav")
		"silver", "good":
			craft_sfx = load("res://art/sounds/sfx/craft/craft_silver.wav")
		_:
			craft_sfx = load("res://art/sounds/sfx/craft/craft_bronze.wav")
	
	if craft_sfx and has_node("/root/AudioManager"):
		var AudioManager = get_node("/root/AudioManager")
		if AudioManager.has_method("play_sfx"):
			# Acceder al enum AudioContext correctamente
			var forge_context = AudioManager.AudioContext.FORGE if "AudioContext" in AudioManager else 0
			AudioManager.play_sfx(craft_sfx, 0.0, forge_context)
			print("ItemInfoPanel: Playing craft SFX for quality '%s'" % quality_label_text)
	
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
	
	# Mostrar grado con color de calidad
	if grade_label:
		# Reutilizar quality_label_text calculado arriba
		grade_label.text = "Quality: " + quality_label_text.capitalize()
		grade_label.modulate = QualityUtils.get_quality_color(quality)
	
	# Mostrar puntuación con porcentaje
	if score_label:
		var percent = QualityUtils.get_quality_percent(quality)
		score_label.text = "Puntaje: %d%%" % percent
	
	# Aplicar borde de calidad al panel
	if has_node("%ItemPanel"):
		var panel = get_node("%ItemPanel")
		if panel is PanelContainer:
			var style = QualityUtils.create_quality_border_style(quality)
			panel.add_theme_stylebox_override("panel", style)
	
	visible = true
	print("ItemInfoPanel: Showing item info - Quality: %d%% (%s)" % [QualityUtils.get_quality_percent(quality), QualityUtils.get_quality_label(quality)])

func hide_info() -> void:
	visible = false
	print("ItemInfoPanel: Hidden")
