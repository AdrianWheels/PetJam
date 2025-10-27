extends Control

@onready var death_count_label: Label = $VBoxContainer/DeathCountLabel
@onready var game_over_label: Label = $VBoxContainer/GameOverLabel

var float_time: float = 0.0
var is_victory: bool = false

func _ready() -> void:
	# Fade in al aparecer
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)
	
	# Mostrar el death count actual solo si es derrota
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if is_victory:
			game_over_label.text = "YOU WIN!"
			death_count_label.text = "Victory! Boss Defeated!"
		else:
			game_over_label.text = "YOU LOST"
			death_count_label.text = "Deaths: %d/%d" % [gm.death_count, gm.MAX_DEATHS]

func _process(delta: float) -> void:
	# Efecto flotante con intensidad 100 (equivalente a 10 unidades de amplitud)
	float_time += delta
	var float_offset = sin(float_time * 2.0) * 10.0
	game_over_label.position.y = float_offset

func _on_back_button_pressed() -> void:
	print("GameOverScreen: Back button pressed")
	# Fade out antes de cambiar de escena
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/UI/StartScreen.tscn")
	)

