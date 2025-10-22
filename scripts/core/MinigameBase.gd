extends Control

var title_screen = null
var end_screen = null

func setup_title_screen(game_title: String, instructions: String = "", continue_text: String = ""):
	title_screen = preload("res://scenes/UI/TitleScreen.tscn").instantiate()
	title_screen.title = game_title
	if instructions != "":
		title_screen.get_node("InstructionsLabel").text = instructions
	if continue_text != "":
		title_screen.get_node("ContinueLabel").text = continue_text
	title_screen.connect("continue_pressed", Callable(self, "_on_title_continue"))
	add_child(title_screen)

func _on_title_continue():
	if title_screen:
		title_screen.visible = false
	start_game()

func start_game():
	# Override in subclasses
	pass

func setup_end_screen(title: String, result_text: String):
	end_screen = preload("res://scenes/UI/TitleScreen.tscn").instantiate()
	end_screen.title = title
	end_screen.get_node("ContinueLabel").text = result_text
	end_screen.connect("continue_pressed", Callable(self, "_on_end_continue"))
	add_child(end_screen)
	end_screen.visible = true

func _on_end_continue():
	emit_signal("minigame_end", get_result())
	get_parent().get_node("HUD")._set_forge_panels_visible(true)
	queue_free()

func get_result():
	# Override
	return {}

signal minigame_end(result)