extends Control

@export var material_name: String = "iron"

func _draw():
	var icon_size = size
	if material_name == "iron":
		draw_rect(Rect2(2, 2, icon_size.x-4, icon_size.y-4), Color.GRAY)
	elif material_name == "leather":
		draw_circle(icon_size/2, icon_size.x/2 - 2, Color.SADDLE_BROWN)
	elif material_name == "cloth":
		draw_rect(Rect2(2, 2, icon_size.x-4, icon_size.y-4), Color.LIGHT_BLUE)
	elif material_name == "water":
		draw_circle(icon_size/2, icon_size.x/2 - 2, Color.BLUE)
	elif material_name == "catalyst_fire":
		draw_circle(icon_size/2, icon_size.x/2 - 2, Color.RED)
	else:
		draw_rect(Rect2(2, 2, icon_size.x-4, icon_size.y-4), Color.WHITE)