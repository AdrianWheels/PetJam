extends Control

signal continue_pressed

@export var title: String = "TITLE"
@export var instructions: String = "INSTRUCTIONS"

@onready var title_label = $TitleLabel
@onready var instructions_label = $InstructionsLabel
@onready var continue_label = $ContinueLabel

var accepted = false

func _ready():
	title_label.text = title
	instructions_label.text = instructions
	title_label.add_theme_font_override("font", ThemeDB.get_default_theme().get_font("font", "Label"))
	title_label.add_theme_font_size_override("font_size", 48)
	instructions_label.add_theme_font_override("font", ThemeDB.get_default_theme().get_font("font", "Label"))
	instructions_label.add_theme_font_size_override("font_size", 24)
	continue_label.add_theme_font_override("font", ThemeDB.get_default_theme().get_font("font", "Label"))
	continue_label.add_theme_font_size_override("font_size", 24)
	set_process_input(true)
	focus_mode = Control.FOCUS_ALL
	grab_focus()

func _input(event):
	if not accepted and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		accepted = true
		print("TitleScreen: Continue pressed")
		continue_pressed.emit()
		set_process_input(false)
		accept_event()