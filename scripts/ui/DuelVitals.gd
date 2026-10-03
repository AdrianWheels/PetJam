extends Control

var corridor: Node
var show_vs := true
var _hero_name: Label
var _enemy_name: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in 2:
		var label := Label.new()
		label.position = Vector2(45 if side == 0 else 635, 364)
		label.size = Vector2(400, 54)
		label.add_theme_font_override("font", ThemeDB.fallback_font)
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color("fff4df"))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		if side == 0:
			_hero_name = label
		else:
			_enemy_name = label

func _process(_delta: float) -> void:
	if corridor:
		_hero_name.text = "Tico"
		_enemy_name.text = tr(corridor.enemy.display_name) + " · " + str(corridor.enemy.level)
	queue_redraw()

func _draw() -> void:
	if not corridor:
		return
	draw_rect(Rect2(0, 360, 1080, 120), Color(0.035, 0.025, 0.02, 0.75))
	var fighters := [corridor.hero, corridor.enemy]
	for side in 2:
		var unit: Node = fighters[side]
		var at := Vector2(60 if side == 0 else 650, 426)
		draw_rect(Rect2(at, Vector2(370, 16)), Color(0.22, 0.16, 0.13))
		var ratio := clampf(float(unit.hp) / maxf(1.0, unit.max_hp), 0, 1)
		draw_rect(Rect2(at, Vector2(370 * ratio, 16)), Color("6ddb80") if side == 0 else Color("f07861"))
		draw_string(ThemeDB.fallback_font, at + Vector2(0, 42), "%d / %d" % [maxi(0, unit.hp), unit.max_hp], HORIZONTAL_ALIGNMENT_CENTER, 370, 28, Color("fff4df"))
	if show_vs:
		draw_string(ThemeDB.fallback_font, Vector2(490, 245), "VS", HORIZONTAL_ALIGNMENT_CENTER, 100, 44, Color("ffe3a5"))
