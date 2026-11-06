extends Control

## HUD de la franja del héroe (25 % superior).
## Arriba: oro (izquierda), muertes (centro, como se pidió) y sala/bioma/récord (derecha).
## Debajo del centro: 10 marcas hasta el siguiente jefe.
## Carteles animados: nuevo bioma, jefe, caída del héroe, récord y plano desbloqueado.
## También hace el fundido a negro que oculta el teletransporte al reaparecer.
## Pociones activas (GameManager): a la derecha del oro, una línea por efecto con su nombre en
## mayúsculas y los segundos que le quedan, redondeados hacia arriba ("VELOCIDAD 25 s"), cada una de
## su color. Parpadean los últimos 5 s y desaparecen al caducar. Solo letras y cifras: sin emoji.
## La de Suerte da un latido cuando sale un botín doble.
## Debajo de los efectos, una línea con las pociones que quedan en los huecos de consumibles ("VIDA ×2 · VELOCIDAD ×1").
## Todo lo que enseña pasa por tr() al ponerlo (locale/textos.csv): los nombres que llegan por señal
## (jefes, planos) vienen en español, que es el texto base.
## Selector de sala (spec de rangos, apartado 7), bajo la banda superior, a la derecha: flecha atrás,
## candado y flecha adelante, con tamaño de dedo. Toque corto: la sala de al lado; mantener pulsado
## LONG_PRESS: el principio del bioma anterior o del siguiente. Con muro, el récord dice "Muro: sala N".

const SK := preload("res://scripts/gameplay/visual/ShapeKit.gd")

const TOP_BAND := 96.0
const PIP_Y := 24.0
const PIP_SPACING := 20.0

## Efecto → [nombre (texto base), color]. El orden es el de las filas.
const BUFF_LABELS := {
	&"speed": ["VELOCIDAD", Color("a3e4ff")],
	&"luck": ["SUERTE", Color("a8ee84")],
}
## Efectos y pociones en la columna central, bajo el selector y el aviso (el «VS» va más abajo, a media pierna)
const BUFF_POS := Vector2(440, 180)
const BUFF_ROW := 36.0
const BUFF_FONT_SIZE := 28
const BUFF_BLINK_TIME := 5.0

## Tres botones de dedo (88 px como mínimo en el móvil) centrados bajo la fila de jefes
const SELECTOR_BUTTON := Vector2(88, 88)
const SELECTOR_POS := Vector2(540.0 - (SELECTOR_BUTTON.x * 3.0 + 4.0 * 2.0) * 0.5, 38)
const SELECTOR_GAP := 4.0
## Avisos (récord, jefe caído…) justo debajo del selector, sin pisar sus botones
const TOAST_Y := SELECTOR_POS.y + SELECTOR_BUTTON.y + 8.0
const LONG_PRESS := 0.45

var _corridor: Node
var _game_manager: Node
var _inventory: Node
var _font: Font
var _coin_icon: Texture2D = preload("res://art/stickers/sources/ui/coin.png")

var _gold_label: Label
var _death_label: Label
var _room_label: Label
var _biome_label: Label
var _record_label: Label
var _banner_title: Label
var _banner_sub: Label
var _toast: Label
var _vitals: Control
var _fade: ColorRect
var _buff_labels: Dictionary = {}  # efecto → Label
var _potion_label: Label  # las pociones que quedan en los huecos, debajo de los efectos

var _prev_button: Button
var _lock_button: Button
var _next_button: Button
var _held_dir := 0  # flecha que se mantiene pulsada (−1, 1 o 0)
var _held_time := 0.0
var _held_jumped := false  # ya saltó de bioma en esta pulsación

var _gold_shown := 0.0
var _gold_target := 0
var _gold_pop := 0.0
var _luck_pop := 0.0  # latido de la etiqueta de Suerte al salir un botín doble
var _death_pop := 0.0
var _room := 1
## Lo más que Tico le ha quitado a cada muro, en fracción de su vida (sala → 0..1). Solo en esta sesión: dice lo cerca
## que está del siguiente intento sin tocar el guardado.
var _wall_best := {}
var _record := 1
var _record_announced := false  # un solo aviso de récord por vida del héroe
var _t := 0.0
var _banner_tween: Tween
var _banner_until := 0.0  # mientras haya cartel, los avisos esperan en cola
var _toast_queue: Array = []
var _toast_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_game_manager = get_node_or_null("/root/GameManager")
	_inventory = get_node_or_null("/root/InventoryManager")
	_build()
	if _game_manager:
		_game_manager.hero_died.connect(_on_hero_died)
		_game_manager.hero_respawned.connect(_on_deaths_changed)
		if _game_manager.has_signal("record_changed"):
			_game_manager.record_changed.connect(_on_record_changed)
		if _game_manager.has_signal("progress_loaded"):
			_game_manager.progress_loaded.connect(_refresh_all)
		if _game_manager.has_signal("wall_changed"):
			_game_manager.wall_changed.connect(func(_w): _refresh_room())
			_game_manager.room_lock_changed.connect(func(_l): _refresh_room())
		if _game_manager.has_signal("grid_expanded"):
			_game_manager.grid_expanded.connect(func(_id): show_toast(tr("¡La rejilla crece!"), Color("9fe0ff")))
		if _game_manager.has_signal("blueprints_milestone"):
			_game_manager.blueprints_milestone.connect(_on_blueprints_milestone)
		_game_manager.enemy_level_changed.connect(func(_l): _refresh_selector())
	if _inventory and _inventory.has_signal("inventory_changed"):
		_inventory.inventory_changed.connect(func(_inv): _refresh_gold())
	_refresh_all()
	_gold_shown = _gold_target


## HUDMain la llama con el Corridor del viewport del héroe.
func bind_corridor(corridor: Node) -> void:
	var vitals := preload("res://scripts/ui/DuelVitals.gd").new()
	vitals.corridor = corridor
	_vitals = vitals
	add_child(vitals)
	_corridor = corridor
	if corridor == null:
		return
	corridor.room_entered.connect(_on_room_entered)
	corridor.biome_entered.connect(_on_biome_entered)
	corridor.boss_appeared.connect(_on_boss_appeared)
	corridor.boss_slain.connect(_on_boss_slain)
	corridor.hero_fell.connect(_on_hero_fell)
	corridor.hero_returned.connect(_on_hero_returned)
	corridor.loot_dropped.connect(_on_loot_dropped)
	corridor.room_traveled.connect(_on_room_traveled)
	_room = corridor.level
	_refresh_room()


# ─── Construcción ──────────────────────────────────────────────────────

func _make_label(size: int, color: Color, align: HorizontalAlignment, outline: int = 8) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = _font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color(0.04, 0.02, 0.04, 0.95)
	ls.shadow_size = 0
	l.label_settings = ls
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _build() -> void:
	_gold_label = _make_label(40, Color("ffd76a"), HORIZONTAL_ALIGNMENT_LEFT)
	_gold_label.position = Vector2(66, 12)
	_gold_label.size = Vector2(260, 52)
	_gold_label.pivot_offset = Vector2(0, 26)

	_death_label = _make_label(36, Color("f1e4cf"), HORIZONTAL_ALIGNMENT_LEFT)
	_death_label.position = Vector2(276, 12)
	_death_label.size = Vector2(160, 52)
	_death_label.pivot_offset = Vector2(20, 26)

	_room_label = _make_label(42, Color("f3d9a4"), HORIZONTAL_ALIGNMENT_RIGHT)
	_room_label.position = Vector2(700, 6)
	_room_label.size = Vector2(356, 52)

	_biome_label = _make_label(24, Color("c9b8a0"), HORIZONTAL_ALIGNMENT_RIGHT, 6)
	_biome_label.position = Vector2(640, 50)
	_biome_label.size = Vector2(416, 30)

	_record_label = _make_label(22, Color("ffd76a"), HORIZONTAL_ALIGNMENT_LEFT, 6)
	_record_label.position = Vector2(66, 58)
	_record_label.size = Vector2(300, 30)

	for id in BUFF_LABELS:
		var buff := _make_label(BUFF_FONT_SIZE, BUFF_LABELS[id][1], HORIZONTAL_ALIGNMENT_LEFT, 6)
		buff.position = BUFF_POS
		buff.size = Vector2(250, BUFF_ROW)
		buff.pivot_offset = Vector2(0, BUFF_ROW * 0.5)
		buff.visible = false
		_buff_labels[id] = buff

	_potion_label = _make_label(22, Color("ffe7b0"), HORIZONTAL_ALIGNMENT_LEFT)
	_potion_label.position = BUFF_POS
	_potion_label.size = Vector2(250, BUFF_ROW)
	_potion_label.visible = false

	_banner_title = _make_label(64, Color("ffe7b0"), HORIZONTAL_ALIGNMENT_CENTER, 12)
	_banner_title.position = Vector2(0, 132)
	_banner_title.size = Vector2(1080, 80)
	_banner_title.pivot_offset = Vector2(540, 40)
	_banner_title.modulate.a = 0.0
	_banner_sub = _make_label(30, Color("e8d6bf"), HORIZONTAL_ALIGNMENT_CENTER, 8)
	_banner_sub.position = Vector2(0, 204)
	_banner_sub.size = Vector2(1020, 100)
	_banner_sub.position.x = 30
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_sub.modulate.a = 0.0

	_toast = _make_label(30, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER, 8)
	_toast.position = Vector2(0, TOAST_Y)
	_toast.size = Vector2(1080, 40)
	_toast.modulate.a = 0.0

	_prev_button = _make_selector_button(0)
	_lock_button = _make_selector_button(1)
	_next_button = _make_selector_button(2)
	_prev_button.button_down.connect(_on_arrow_down.bind(-1))
	_prev_button.button_up.connect(_on_arrow_up.bind(-1))
	_next_button.button_down.connect(_on_arrow_down.bind(1))
	_next_button.button_up.connect(_on_arrow_up.bind(1))
	_lock_button.pressed.connect(_on_lock_pressed)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.visible = false  # solo visible mientras funde (un rect transparente también cuesta)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func _make_selector_button(index: int) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.position = SELECTOR_POS + Vector2((SELECTOR_BUTTON.x + SELECTOR_GAP) * index, 0)
	b.size = SELECTOR_BUTTON
	add_child(b)
	return b


# ─── Actualización ─────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	# Conteo animado del oro
	if absf(_gold_shown - _gold_target) > 0.5:
		_gold_shown = lerpf(_gold_shown, float(_gold_target), 1.0 - exp(-8.0 * delta))
	else:
		_gold_shown = _gold_target
	_gold_label.text = str(int(round(_gold_shown)))
	_gold_pop = maxf(0.0, _gold_pop - delta * 3.0)
	_gold_label.scale = Vector2.ONE * (1.0 + 0.25 * _gold_pop)
	_death_pop = maxf(0.0, _death_pop - delta * 2.5)
	_death_label.scale = Vector2.ONE * (1.0 + 0.35 * _death_pop)
	_luck_pop = maxf(0.0, _luck_pop - delta * 2.0)
	_refresh_buffs()
	if _vitals:
		_vitals.show_vs = _t >= _banner_until
	# Avisos en cola: de uno en uno y nunca encima de un cartel
	# (tampoco encima de la presentación «VS» de un duelo)
	var presenting: bool = _vitals != null and _vitals.is_presenting()
	if not _toast_queue.is_empty() and _t >= _banner_until and not presenting and not (_toast_tween and _toast_tween.is_valid() and _toast_tween.is_running()):
		var next: Array = _toast_queue.pop_front()
		_play_toast(next[0], next[1])
	# Selector: mantener pulsada una flecha salta de bioma, una sola vez por pulsación
	if _held_dir != 0 and not _held_jumped:
		_held_time += delta
		if _held_time >= LONG_PRESS:
			_held_jumped = true
			_travel_selector(_held_dir, true)
	queue_redraw()


func _refresh_all() -> void:
	_refresh_gold()
	if _game_manager:
		_death_label.text = str(_game_manager.death_count)
		_record = int(_game_manager.get("best_enemy_level")) if "best_enemy_level" in _game_manager else 1
	_refresh_room()


func _refresh_gold() -> void:
	if _inventory == null:
		return
	var gold: int = _inventory.get_quantity(&"gold")
	if gold > _gold_target:
		_gold_pop = 1.0
	_gold_target = gold


## Una fila por efecto activo, en el orden de BUFF_LABELS y sin huecos.
func _refresh_buffs() -> void:
	var row := 0
	for id in _buff_labels:
		var label: Label = _buff_labels[id]
		var left: float = _game_manager.buff_remaining(id) if _game_manager and _game_manager.has_method("buff_remaining") else 0.0
		label.visible = left > 0.0
		if not label.visible:
			continue
		label.position = BUFF_POS + Vector2(0, BUFF_ROW * row)
		row += 1
		label.text = "%s %d s" % [tr(BUFF_LABELS[id][0]), ceili(left)]
		label.modulate.a = 0.45 + 0.55 * absf(cos(_t * 5.0)) if left <= BUFF_BLINK_TIME else 1.0
	var luck: Label = _buff_labels[&"luck"]
	luck.scale = Vector2.ONE * (1.0 + 0.3 * _luck_pop)
	luck.modulate.r = 1.0 + 0.6 * _luck_pop  # destello (el modulate admite valores mayores que 1)
	luck.modulate.g = 1.0 + 0.6 * _luck_pop
	luck.modulate.b = 1.0 + 0.6 * _luck_pop
	# Pociones que quedan en los huecos (spec del inventario, apartado 8), debajo de los efectos activos
	var parts := []
	if _inventory and "consumables" in _inventory:
		for s in _inventory.consumables:
			if int(s.count) > 0:
				parts.append("%s ×%d" % [tr(Potions.CATALOG[s.id].short).to_upper(), int(s.count)])
	_potion_label.visible = not parts.is_empty()
	_potion_label.text = " · ".join(parts)
	_potion_label.position = BUFF_POS + Vector2(0, BUFF_ROW * row)


func _refresh_room() -> void:
	_room_label.text = tr("Sala %d") % _room
	var idx := Biomes.biome_index_for_room(_room)
	_biome_label.text = Biomes.display_name(idx)  # ya traducido
	_record = maxi(_record, _room)
	var wall: int = int(_game_manager.wall_room) if _game_manager and "wall_room" in _game_manager else 0
	if wall > 0 and _wall_best.has(wall):
		_record_label.text = tr("Muro: sala %d · %d %%") % [wall, floori(float(_wall_best[wall]) * 100.0)]
	else:
		_record_label.text = tr("Muro: sala %d") % wall if wall > 0 else tr("Récord: sala %d") % _record
	_refresh_selector()


## Flechas apagadas en los extremos (la sala 1 y el récord). El candado siempre se puede tocar.
func _refresh_selector() -> void:
	if _prev_button == null or _game_manager == null or not ("room_locked" in _game_manager):
		return
	var room: int = int(_game_manager.current_enemy_level)
	_prev_button.disabled = room <= 1
	_next_button.disabled = room >= int(_game_manager.best_enemy_level)


func _draw() -> void:
	# Banda oscura superior para que el HUD se lea sobre cualquier bioma
	SK.v_gradient(self, Rect2(0, 0, size.x, TOP_BAND + 20.0), Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.0))
	_draw_coin(Vector2(38, 38), 17.0)
	_draw_skull(Vector2(248, 38), 15.0, _death_pop)
	_draw_boss_pips()
	_draw_retry_pips()
	_draw_selector()
	# Franja oscura tras los carteles: se leen aunque pasen por encima de placas de nombre
	var ribbon_a := _banner_title.modulate.a
	if ribbon_a > 0.01:
		# Cubre el título y todas las líneas del subtítulo (el de la derrota ocupa dos): con fundido arriba y abajo
		var top_y := _banner_title.position.y - 6.0
		var bottom_y := _banner_title.position.y + _banner_title.size.y
		if _banner_sub.text != "":
			bottom_y = _banner_sub.position.y + float(_banner_sub.get_line_count() * _banner_sub.get_line_height()) + 12.0
		var dark := Color(0, 0, 0, 0.62 * ribbon_a)
		var fade := 28.0
		SK.v_gradient(self, Rect2(0, top_y - fade, size.x, fade), Color(0, 0, 0, 0.0), dark)
		draw_rect(Rect2(0, top_y, size.x, bottom_y - top_y), dark)
		SK.v_gradient(self, Rect2(0, bottom_y, size.x, fade), dark, Color(0, 0, 0, 0.0))


func _draw_coin(c: Vector2, r: float) -> void:
	if _coin_icon:
		draw_texture_rect(_coin_icon, Rect2(c - Vector2.ONE * r, Vector2.ONE * r * 2), false)
		return
	var spin := absf(cos(_t * 2.0)) * 0.3 + 0.7
	var pts := SK.ellipse_pts(c, r * spin, r, 20)
	SK.outlined_poly(self, pts, Color("f2b53a"), SK.OUTLINE, 3.0)
	draw_colored_polygon(SK.ellipse_pts(c, r * spin * 0.62, r * 0.62, 16), Color("ffd76a"))
	draw_line(c + Vector2(-r * 0.2 * spin, -r * 0.45), c + Vector2(-r * 0.2 * spin, r * 0.3), Color(1, 1, 1, 0.7), 3.0, true)


func _draw_skull(c: Vector2, r: float, pop: float) -> void:
	var col := Color("e9dfc7").lerp(Color("ff6a5a"), pop)
	var shake := Vector2(sin(_t * 60.0) * 3.0 * pop, 0)
	c += shake
	draw_colored_polygon(SK.ellipse_pts(c, r, r * 0.92, 16), col)
	draw_rect(Rect2(c + Vector2(-r * 0.55, r * 0.55), Vector2(r * 1.1, r * 0.55)), col)
	draw_colored_polygon(SK.ellipse_pts(c + Vector2(-r * 0.38, 0), r * 0.26, r * 0.3, 10), SK.OUTLINE)
	draw_colored_polygon(SK.ellipse_pts(c + Vector2(r * 0.38, 0), r * 0.26, r * 0.3, 10), SK.OUTLINE)
	draw_polyline(SK.closed(SK.ellipse_pts(c, r, r * 0.92, 16)), SK.OUTLINE, 2.5, true)


## Victorias hacia el siguiente intento contra el muro, a la derecha de «Muro: sala N», mientras Tico farmea la sala de
## antes: se van llenando y con la última vuelve al muro.
func _draw_retry_pips() -> void:
	if _game_manager == null or not _game_manager.has_method("is_farming_wall") or not _game_manager.is_farming_wall():
		return
	var ls := _record_label.label_settings
	var text_w := ls.font.get_string_size(_record_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ls.font_size).x
	var wins: int = _game_manager.wall_retry_wins()
	var total: int = _game_manager.wall_retry_goal()
	var y := _record_label.position.y + _record_label.size.y * 0.5
	for i in total:
		var c := Vector2(_record_label.position.x + text_w + 18.0 + 20.0 * float(i), y)
		var fill := Color("ffd76a") if i < wins else Color(0.42, 0.35, 0.33, 0.95)
		SK.outlined_poly(self, SK.diamond_pts(c, 6.5, 8.5), fill, SK.OUTLINE, 2.0)

func _draw_boss_pips() -> void:
	var in_biome := Biomes.room_in_biome(_room)
	var total := Biomes.ROOMS_PER_BIOME
	var start_x := size.x * 0.5 - PIP_SPACING * float(total - 1) * 0.5
	for i in total:
		var room_i := i + 1
		var c := Vector2(start_x + PIP_SPACING * float(i), PIP_Y)
		if room_i == total:
			# Marca del jefe: corona
			var lit := in_biome >= total
			var col := Color("ff5a3a") if lit else Color("7a3a30")
			if lit:
				col = col.lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 8.0))
			var crown := PackedVector2Array([c + Vector2(-11, 7), c + Vector2(-12, -8), c + Vector2(-5, -1), c + Vector2(0, -11), c + Vector2(5, -1), c + Vector2(12, -8), c + Vector2(11, 7)])
			SK.outlined_poly(self, crown, col, SK.OUTLINE, 2.5)
			continue
		var cleared := room_i < in_biome
		var current := room_i == in_biome
		var r := 7.0 + (2.0 * (0.5 + 0.5 * sin(_t * 6.0)) if current else 0.0)
		var fill := Color("ffd76a") if cleared else (Color("fff2c9") if current else Color(0.25, 0.2, 0.22, 0.9))
		SK.outlined_poly(self, SK.diamond_pts(c, r, r * 1.25), fill, SK.OUTLINE, 2.5)


func _draw_selector() -> void:
	_draw_arrow(_prev_button, -1)
	_draw_lock(_lock_button)
	_draw_arrow(_next_button, 1)


func _selector_color(button: Button, lit: bool) -> Color:
	if button.disabled:
		return Color(0.5, 0.45, 0.42, 0.45)
	return Color("fff2c9") if lit else Color("f3d9a4")


func _draw_arrow(button: Button, dir: int) -> void:
	var c := button.position + button.size * 0.5
	draw_colored_polygon(SK.ellipse_pts(c, 40.0, 40.0, 24), Color(0, 0, 0, 0.45))
	var s := 20.0 * float(dir)
	var tri := PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s * 0.7, 20), c + Vector2(-s * 0.7, -20)])
	if dir < 0:
		tri.reverse()  # el mismo sentido de giro en las dos flechas
	SK.outlined_poly(self, tri, _selector_color(button, _held_dir == dir), SK.OUTLINE, 3.0)


## Candado: cerrado y dorado con el candado puesto; abierto (el arco levantado a un lado) sin él.
func _draw_lock(button: Button) -> void:
	var c := button.position + button.size * 0.5
	draw_colored_polygon(SK.ellipse_pts(c, 40.0, 40.0, 24), Color(0, 0, 0, 0.45))
	var locked: bool = _game_manager != null and "room_locked" in _game_manager and bool(_game_manager.room_locked)
	var col := Color("ffd76a") if locked else Color("c9b8a0")
	var arc_c := c + (Vector2(0, -8) if locked else Vector2(-10, -14))
	draw_arc(arc_c, 11.0, PI, TAU, 16, SK.OUTLINE, 9.0, true)
	draw_arc(arc_c, 11.0, PI, TAU, 16, col, 5.0, true)
	var body := PackedVector2Array([c + Vector2(-16, -8), c + Vector2(16, -8), c + Vector2(16, 18), c + Vector2(-16, 18)])
	SK.outlined_poly(self, body, col, SK.OUTLINE, 3.0)


# ─── Carteles ──────────────────────────────────────────────────────────

func show_banner(title: String, subtitle: String, color: Color = Color("ffe7b0"), hold: float = 1.3) -> void:
	if _toast.modulate.a > 0.01:
		_toast_queue.push_front([_toast.text, _toast.label_settings.font_color])
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_title.text = title
	_banner_title.label_settings.font_color = color
	_banner_sub.text = subtitle
	_banner_title.modulate.a = 0.0
	_banner_sub.modulate.a = 0.0
	_banner_title.scale = Vector2(1.6, 1.6)
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner_title, "modulate:a", 1.0, 0.18)
	_banner_tween.tween_property(_banner_title, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner_sub, "modulate:a", 1.0, 0.3).set_delay(0.12)
	_banner_until = _t + hold + 0.7
	_banner_tween.chain().tween_interval(hold)
	_banner_tween.chain().set_parallel(true)
	_banner_tween.tween_property(_banner_title, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_property(_banner_sub, "modulate:a", 0.0, 0.4)


func show_toast(text: String, color: Color = Color("ffe08a")) -> void:
	if _toast_queue.size() < 4:
		_toast_queue.append([text, color])


func _play_toast(text: String, color: Color) -> void:
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = text
	_toast.label_settings.font_color = color
	_toast.position.y = TOAST_Y + 14.0
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_property(_toast, "position:y", TOAST_Y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(1.6)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.4)


func _fade_to(alpha: float, duration: float, delay: float = 0.0) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	if delay > 0.0:
		_fade_tween.tween_interval(delay)
	_fade_tween.tween_callback(func(): _fade.visible = true)
	_fade_tween.tween_property(_fade, "color:a", alpha, duration).set_trans(Tween.TRANS_SINE)
	if alpha <= 0.0:
		_fade_tween.tween_callback(func(): _fade.visible = false)


# ─── Señales ───────────────────────────────────────────────────────────

func _on_room_entered(room: int, _is_boss: bool) -> void:
	_room = room
	_refresh_room()


func _on_biome_entered(idx: int, biome_name: String) -> void:
	# El cartel solo al avanzar (no al volver a la sala 1 tras morir)
	if _corridor and _corridor.is_advancing() and idx > 0 and Biomes.room_in_biome(_corridor.level) == 1:
		show_banner(tr(biome_name), tr("Profundidad %d") % _corridor.level, Biomes.get_biome(idx).get("light", Color("ffe7b0")).lerp(Color.WHITE, 0.4))
		Sfx.play(&"biome_enter")


func _on_boss_appeared(room: int, boss_name: String) -> void:
	show_banner(tr("¡JEFE!"), tr("%s · Sala %d") % [tr(boss_name), room], Color("ff6a4a"), 1.1)


## Sin aviso propio: el «¡JEFE DERROTADO!» que sale del pecho del jefe (Corridor) ya lo dice. El aviso «X ha caído» salía
## a la vez en la misma franja, se montaba con él y con el botín, y como esperaba en cola seguía en pantalla en el duelo
## siguiente, sobre otro enemigo.
func _on_boss_slain(_room_num: int, _boss_name: String) -> void:
	pass


## Ficha del muro (idea de Dungeonbound): el cartel dice cuánta vida le quitó Tico al enemigo que lo ha tumbado, que es
## lo cerca que está de pasar, y la barra de arriba lo guarda junto al muro mientras farmea.
func _on_hero_fell(room: int) -> void:
	var dealt := 0.0
	var foe: Node = _corridor.enemy if _corridor and "enemy" in _corridor else null
	if foe and int(foe.max_hp) > 0:
		dealt = clampf(1.0 - float(maxi(0, foe.hp)) / float(foe.max_hp), 0.0, 1.0)
	# Hacia abajo al enseñarlo: un 99,6 % no puede decir «100 %» si Tico ha perdido
	_wall_best[room] = maxf(float(_wall_best.get(room, 0.0)), dealt)
	_refresh_room()
	var retry_wins: int = _game_manager.wall_retry_goal() if _game_manager and _game_manager.has_method("wall_retry_goal") else 3
	show_banner(tr("El héroe ha caído"), tr("Le quitaste el %d %% de su vida. Vuelves a la sala %d sin perder nada y lo reintentas cada %d victorias.") % [floori(dealt * 100.0), maxi(1, room - 1), retry_wins], Color("ff8a7a"), 1.1)
	_fade_to(0.85, 0.35, 0.95)


func _on_hero_returned() -> void:
	_fade_to(0.0, 0.45)


func _on_hero_died(death_count: int) -> void:
	_death_label.text = str(death_count)
	_death_pop = 1.0
	_record_announced = false


func _on_deaths_changed(death_count: int) -> void:
	_death_label.text = str(death_count)


func _on_record_changed(best: int) -> void:
	var was := _record
	_record = maxi(_record, best)
	_refresh_room()
	if best > was and best > 2 and not _record_announced:
		_record_announced = true
		show_toast(tr("¡Nuevo récord de profundidad!"), Color("ffd76a"))


## Hito de rangos (spec de rangos, apartado 3): cartel con el grupo desbloqueado. Llega al vencer a un
## jefe, antes que su aviso "X ha caído", que es un toast y espera en cola mientras dure el cartel.
func _on_blueprints_milestone(rank: int, tier: StringName, _ids: Array) -> void:
	show_banner(Ranks.milestone_text(rank, tier), tr("Nuevos planos en la biblioteca"), Color("ffe08a"), 1.6)


func _on_loot_dropped(kind: StringName, _world_pos: Vector2, payload: Dictionary) -> void:
	# Los pergaminos de un hito no avisan aquí: los anuncia el cartel del hito
	if kind == &"blueprint":
		return
	if payload.get("bonus", false):
		_luck_pop = 1.0  # botín doble de la Poción de Suerte


func _on_arrow_down(dir: int) -> void:
	_held_dir = dir
	_held_time = 0.0
	_held_jumped = false


func _on_arrow_up(dir: int) -> void:
	if _held_dir != dir:
		return
	_held_dir = 0
	if not _held_jumped:
		_travel_selector(dir, false)


func _travel_selector(dir: int, by_biome: bool) -> void:
	if _game_manager == null or not _game_manager.has_method("travel_to_room"):
		return
	_game_manager.travel_to_room(_game_manager.selector_target(_game_manager.current_enemy_level, dir, by_biome))


func _on_lock_pressed() -> void:
	if _game_manager and _game_manager.has_method("set_room_locked"):
		_game_manager.set_room_locked(not _game_manager.room_locked)


## Fundido desde negro: tapa el salto de sala del selector o del reintento del muro.
func _on_room_traveled(_room_num: int) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade.color.a = 0.9
	_fade.visible = true
	_fade_to(0.0, 0.3)
