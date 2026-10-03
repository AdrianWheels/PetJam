extends Control

## Franja de nombres y vida del duelo, debajo de los pies de los combatientes. Empieza donde apoyan
## (Corridor.FLOOR_Y en píxeles de la franja): así no tapa a los enemigos bajos (limo, murciélago).
## Una línea por lado con el nombre a la izquierda y la vida a la derecha, y la barra debajo.

const SIDE_X := [40.0, 580.0]
const SIDE_W := 460.0
const NAME_SIZE := 28
const HP_SIZE := 26
const BAR_H := 12.0

var corridor: Node
var show_vs := true
var _hero_name: Label
var _enemy_name: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in 2:
		var label := Label.new()
		label.size = Vector2(SIDE_W - 150.0, 34)
		label.add_theme_font_override("font", ThemeDB.fallback_font)
		label.add_theme_font_size_override("font_size", NAME_SIZE)
		label.add_theme_color_override("font_color", Color("fff4df"))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		if side == 0:
			_hero_name = label
		else:
			_enemy_name = label

## Borde de arriba de la franja: el suelo del duelo, en píxeles de la franja (1080x480).
func band_top() -> float:
	return float(corridor.FLOOR_Y) * PixelView.SCALE if corridor else 430.0

func _process(_delta: float) -> void:
	if corridor:
		var top := band_top()
		_hero_name.position = Vector2(SIDE_X[0], top + 1.0)
		_enemy_name.position = Vector2(SIDE_X[1], top + 1.0)
		_hero_name.text = "Tico"
		_enemy_name.text = tr(corridor.enemy.display_name) + " · " + str(corridor.enemy.level)
	queue_redraw()

func _draw() -> void:
	if not corridor:
		return
	var top := band_top()
	draw_rect(Rect2(0, top, size.x if size.x > 0.0 else 1080.0, 480.0 - top), Color(0.035, 0.025, 0.02, 0.8))
	var fighters := [corridor.hero, corridor.enemy]
	for side in 2:
		var unit: Node = fighters[side]
		var x: float = SIDE_X[side]
		draw_string_outline(ThemeDB.fallback_font, Vector2(x, top + 27.0), "%d / %d" % [maxi(0, unit.hp), unit.max_hp], HORIZONTAL_ALIGNMENT_RIGHT, SIDE_W, HP_SIZE, 4, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(x, top + 27.0), "%d / %d" % [maxi(0, unit.hp), unit.max_hp], HORIZONTAL_ALIGNMENT_RIGHT, SIDE_W, HP_SIZE, Color("fff4df"))
		var at := Vector2(x, top + 34.0)
		draw_rect(Rect2(at, Vector2(SIDE_W, BAR_H)), Color(0.22, 0.16, 0.13))
		var ratio := clampf(float(unit.hp) / maxf(1.0, unit.max_hp), 0, 1)
		draw_rect(Rect2(at, Vector2(SIDE_W * ratio, BAR_H)), Color("6ddb80") if side == 0 else Color("f07861"))
	# «VS» a media pierna, entre los dos: la columna de arriba es del selector, los avisos y las pociones
	if show_vs:
		draw_string_outline(ThemeDB.fallback_font, Vector2(490, top - 90.0), "VS", HORIZONTAL_ALIGNMENT_CENTER, 100, 48, 6, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(490, top - 90.0), "VS", HORIZONTAL_ALIGNMENT_CENTER, 100, 48, Color("ffe3a5"))
