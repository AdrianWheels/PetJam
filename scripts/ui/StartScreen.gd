extends Control

func _on_start_button_pressed() -> void:
	print("StartScreen: Start button pressed - fading to Main scene")
	# Crear fade overlay
	var fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Hacer que cubra toda la pantalla
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
