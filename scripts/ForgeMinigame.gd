extends "res://scripts/core/MinigameBase.gd"

var closing = false

func _ready():
	size = get_viewport_rect().size
	position = Vector2(0,0)
	setup_title_screen("FORGE TIME")

func start_game():
	start({})
	# Simulate minigame: wait 5 seconds then end
	await get_tree().create_timer(5.0).timeout
	show_end_screen()

func start(_blueprint):
	pass

func show_end_screen():
	setup_end_screen("Prueba Completada", "Presiona cualquier tecla o clic para cerrar")

func _draw():
	draw_rect(Rect2(0, 0, size.x, size.y), Color("#0b0f14"))
	draw_string(ThemeDB.get_default_theme().get_font("font", "Label"), Vector2(100, 100), "Forging in progress...", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)