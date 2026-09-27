extends Control

## Título de minijuego: aparece, se sostiene un instante y se desvanece solo
## (un toque lo salta). Solo texto, como se pidió en E6 de "Preguntas del proyecto".

signal continue_pressed

@export var title: String = "TITLE"
@export var instructions: String = ""
@export var continue_text: String = ""
## Segundos que se muestra antes de empezar solo (0 = esperar a un toque)
@export var auto_time: float = 1.4

@onready var title_label = $TitleLabel
@onready var instructions_label = $InstructionsLabel
@onready var continue_label = $ContinueLabel

var accepted = false
var _t := 0.0


func _ready():
	var font: Font = load("res://art/font/PirataOne-Regular.ttf")
	title_label.text = title
	instructions_label.text = instructions
	continue_label.text = continue_text
	instructions_label.visible = instructions != ""
	continue_label.visible = continue_text != ""
	var title_settings := LabelSettings.new()
	title_settings.font = font
	title_settings.font_size = 92
	title_settings.font_color = Color("ffd98a")
	title_settings.outline_size = 16
	title_settings.outline_color = Color(0.08, 0.04, 0.03, 1)
	title_settings.shadow_size = 18
	title_settings.shadow_color = Color(1.0, 0.5, 0.15, 0.35)
	title_settings.shadow_offset = Vector2.ZERO
	title_label.label_settings = title_settings
	# El título ocupa todo el ancho para que quepan los textos largos
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.offset_left = 20.0
	title_label.offset_right = -20.0
	title_label.offset_top = 300.0
	title_label.offset_bottom = 430.0
	for lbl in [instructions_label, continue_label]:
		lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
		lbl.add_theme_constant_override("outline_size", 8)
		lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.03))
		lbl.anchor_left = 0.0
		lbl.anchor_right = 1.0
		lbl.offset_left = 30.0
		lbl.offset_right = -30.0
	instructions_label.offset_top = 440.0
	instructions_label.offset_bottom = 490.0
	continue_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	set_process_input(true)
	focus_mode = Control.FOCUS_ALL
	grab_focus()


func _process(delta: float) -> void:
	if accepted:
		return
	_t += delta
	# Latido suave del título mientras está en pantalla
	title_label.pivot_offset = title_label.size * 0.5
	title_label.scale = Vector2.ONE * (1.0 + 0.03 * sin(_t * 5.0))
	if auto_time > 0.0 and _t >= auto_time:
		_accept()


func _input(event):
	if not accepted and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_accept()
		accept_event()


func _accept() -> void:
	if accepted:
		return
	accepted = true
	print("TitleScreen: Continue")
	continue_pressed.emit()
	set_process_input(false)
