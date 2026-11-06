extends Control

## Franja de nombres y vida del duelo, debajo de los pies de los combatientes. Empieza donde apoyan
## (Corridor.FLOOR_Y en píxeles de la franja): así no tapa a los enemigos bajos (limo, murciélago).
## Una línea por lado con el nombre a la izquierda y la vida a la derecha, y la barra debajo.
## Al empezar cada duelo (Corridor.duel_intro, mientras baja el humo) hace la presentación de juego de lucha: una cinta
## oscura entra por los dos lados con «TICO» y el rival, y un «VS» grande cae en medio y se asienta.

const SIDE_X := [40.0, 580.0]
const SIDE_W := 460.0
const NAME_SIZE := 28
const NAME_MIN := 22  ## un nombre largo baja hasta aquí antes de cortarse
const NAME_GAP := 18.0  ## aire entre el nombre y la vida de su lado
const HP_SIZE := 26
const BAR_H := 12.0
const TITLE_FONT := preload("res://art/font/PirataOne-Regular.ttf")
const INTRO_IN := 0.35  ## la cinta y los nombres entran en este tiempo
const INTRO_OUT := 0.3  ## y se van en este, al final de la presentación
const RIBBON_H := 132.0
const VS_GOLD := Color("ffd76a")

var corridor: Node
var show_vs := true
var _hero_name: Label
var _enemy_name: Label
var _intro_t := -1.0  ## segundos desde que empezó la presentación; -1 sin presentación
var _intro_len := 0.0
var _intro_enemy := ""

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
	if corridor and corridor.has_signal("duel_intro"):
		corridor.duel_intro.connect(_on_duel_intro)
		# El primer duelo de la partida se presenta antes de que exista esta franja: se retoma lo que quede
		var left: float = corridor.intro_time_left()
		if left > INTRO_OUT and not corridor.enemy.is_boss:
			_on_duel_intro(corridor.enemy.display_name, corridor.enemy.level, left)

## Borde de arriba de la franja: el suelo del duelo, en píxeles de la franja (1080x480).
func band_top() -> float:
	return float(corridor.FLOOR_Y) * PixelView.SCALE if corridor else 430.0

## true mientras dura la presentación de un duelo.
func is_presenting() -> bool:
	return _intro_t >= 0.0

func _on_duel_intro(enemy_name: String, enemy_level: int, length: float) -> void:
	_intro_t = 0.0
	_intro_len = maxf(length, INTRO_IN + INTRO_OUT)
	_intro_enemy = "%s · %d" % [tr(enemy_name), enemy_level]

func _process(delta: float) -> void:
	if _intro_t >= 0.0:
		_intro_t += delta
		if _intro_t > _intro_len:
			_intro_t = -1.0
	if corridor:
		var top := band_top()
		_hero_name.position = Vector2(SIDE_X[0], top + 1.0)
		_enemy_name.position = Vector2(SIDE_X[1], top + 1.0)
		_hero_name.text = "Tico"
		_enemy_name.text = tr(corridor.enemy.display_name) + " · " + str(corridor.enemy.level)
		_fit_name(_hero_name, corridor.hero)
		_fit_name(_enemy_name, corridor.enemy)
	queue_redraw()

## El nombre ocupa lo que deja libre la vida de su lado («Señor del Magma · 130» pisaba «18430 / 18430»): primero baja la
## letra hasta NAME_MIN y, si aun así no cabe, se corta con puntos suspensivos.
func _fit_name(label: Label, unit: Node) -> void:
	var font := ThemeDB.fallback_font
	var hp_w := font.get_string_size(_hp_text(unit), HORIZONTAL_ALIGNMENT_LEFT, -1, HP_SIZE).x
	var room := maxf(80.0, SIDE_W - hp_w - NAME_GAP)
	var font_size := NAME_SIZE
	while font_size > NAME_MIN and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 2
	label.add_theme_font_size_override("font_size", font_size)
	label.size.x = room

func _hp_text(unit: Node) -> String:
	return "%d / %d" % [maxi(0, unit.hp), unit.max_hp]

func _draw() -> void:
	if not corridor:
		return
	var top := band_top()
	var width := size.x if size.x > 0.0 else 1080.0
	draw_rect(Rect2(0, top, width, 480.0 - top), Color(0.035, 0.025, 0.02, 0.8))
	var fighters := [corridor.hero, corridor.enemy]
	for side in 2:
		var unit: Node = fighters[side]
		var x: float = SIDE_X[side]
		draw_string_outline(ThemeDB.fallback_font, Vector2(x, top + 27.0), _hp_text(unit), HORIZONTAL_ALIGNMENT_RIGHT, SIDE_W, HP_SIZE, 4, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(x, top + 27.0), _hp_text(unit), HORIZONTAL_ALIGNMENT_RIGHT, SIDE_W, HP_SIZE, Color("fff4df"))
		var at := Vector2(x, top + 34.0)
		draw_rect(Rect2(at, Vector2(SIDE_W, BAR_H)), Color(0.22, 0.16, 0.13))
		var ratio := clampf(float(unit.hp) / maxf(1.0, unit.max_hp), 0, 1)
		draw_rect(Rect2(at, Vector2(SIDE_W * ratio, BAR_H)), Color("6ddb80") if side == 0 else Color("f07861"))
	if not show_vs:
		return  # un cartel (bioma, jefe, derrota) ocupa la franja
	if is_presenting():
		_draw_intro(width, top)
		return
	if corridor.smoke_amount() > 0.05:
		return  # con el humo arriba el «VS» flotaría sobre el negro
	# «VS» a media pierna, entre los dos: la columna de arriba es del selector, los avisos y las pociones
	draw_string_outline(ThemeDB.fallback_font, Vector2(490, top - 90.0), "VS", HORIZONTAL_ALIGNMENT_CENTER, 100, 48, 6, Color.BLACK)
	draw_string(ThemeDB.fallback_font, Vector2(490, top - 90.0), "VS", HORIZONTAL_ALIGNMENT_CENTER, 100, 48, Color("ffe3a5"))

## Presentación: la cinta entra desde los dos bordes hacia el centro con los nombres, el «VS» cae grande y rebota hasta su
## tamaño, y al final todo se desvanece (el «VS» pequeño de siempre vuelve cuando acaba).
func _draw_intro(width: float, top: float) -> void:
	var enter := _ease_out_cubic(clampf(_intro_t / INTRO_IN, 0.0, 1.0))
	var leave := clampf((_intro_len - _intro_t) / INTRO_OUT, 0.0, 1.0)
	var alpha := leave
	var mid := top * 0.5
	var half := width * 0.5
	var ribbon := Color(0.02, 0.012, 0.01, 0.72 * alpha)
	# Dos mitades de cinta que llegan desde los bordes y se juntan en el centro, con un filo dorado
	var reach := half * enter
	draw_rect(Rect2(0, mid - RIBBON_H * 0.5, reach, RIBBON_H), ribbon)
	draw_rect(Rect2(width - reach, mid - RIBBON_H * 0.5, reach, RIBBON_H), ribbon)
	var edge := Color(VS_GOLD, 0.85 * alpha)
	for y in [mid - RIBBON_H * 0.5, mid + RIBBON_H * 0.5 - 4.0]:
		draw_rect(Rect2(0, y, reach, 4.0), edge)
		draw_rect(Rect2(width - reach, y, reach, 4.0), edge)
	# Nombres: entran deslizándose desde fuera hacia su lado
	var name_y := mid + 18.0
	var slide := (1.0 - enter) * 420.0
	_outlined(ThemeDB.fallback_font, Vector2(50.0 - slide, name_y), "TICO", HORIZONTAL_ALIGNMENT_LEFT, 400.0, 52, Color(Color("fff4df"), alpha))
	var enemy_text := _intro_enemy.to_upper()
	_outlined(ThemeDB.fallback_font, Vector2(width - 450.0 + slide, name_y), enemy_text, HORIZONTAL_ALIGNMENT_RIGHT, 400.0, _fit_size(enemy_text, 52, 400.0), Color(Color("ffb3a1"), alpha))
	# «VS»: cae grande con un pequeño rebote y se queda en el centro de la cinta
	var drop := clampf((_intro_t - INTRO_IN * 0.4) / 0.32, 0.0, 1.0)
	if drop <= 0.0:
		return
	var vs_scale := lerpf(2.6, 1.0, _ease_out_back(drop))
	var vs_size := int(round(96.0 * vs_scale))
	var vs_alpha := minf(1.0, drop * 2.5) * alpha
	_outlined(TITLE_FONT, Vector2(half - 200.0, mid + vs_size * 0.34), "VS", HORIZONTAL_ALIGNMENT_CENTER, 400.0, vs_size, Color(VS_GOLD, vs_alpha), 12)

func _outlined(font: Font, pos: Vector2, text: String, align: HorizontalAlignment, w: float, font_size: int, color: Color, outline: int = 8) -> void:
	draw_string_outline(font, pos, text, align, w, font_size, outline, Color(0, 0, 0, color.a))
	draw_string(font, pos, text, align, w, font_size, color)

## Tamaño de letra para que un nombre largo («MURCIÉLAGO · 23») quepa entero en su mitad de la cinta.
func _fit_size(text: String, wanted: int, max_w: float) -> int:
	var font_size := wanted
	while font_size > 28 and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w:
		font_size -= 2
	return font_size


func _ease_out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
