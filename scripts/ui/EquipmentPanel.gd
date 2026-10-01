# res://scripts/ui/EquipmentPanel.gd
extends ColorRect

## Panel de Equipo a pantalla completa (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 9).
## De arriba abajo: estadísticas de Tico, ficha de la última pieza tocada, rejilla de Tico delante de su
## sprite (con los consumibles al lado), botín, mochila y zona de venta.
## El dedo lo lleva este panel, en _input:
##  - tocar una pieza de una rejilla la gira (si girada no cabe, tiembla); en el botín solo la enseña;
##  - mantener pulsado enseña su ficha (la completa, con botones, llega en la tarea 10);
##  - arrastrar la mueve: la pieza va una casilla por encima del dedo y un segundo dedo la gira;
##  - en el botín, de lado se desplaza la tira; hacia arriba o abajo se coge la pieza.
## En el ordenador el ratón hace lo mismo, y la rueda o la tecla R giran la pieza que se arrastra.

signal panel_closed

const HERO_SCENE := preload("res://scenes/Hero.tscn")
const CELL := GearGridView.CELL
const HERO_GRID_POS := Vector2(60, 262)
const BAG_POS := Vector2(60, 1350)
const LOOT_RECT := Rect2(60, 970, 960, 330)
const STATS_RECT := Rect2(60, 100, 960, 70)
const FICHA_RECT := Rect2(60, 174, 960, 84)
const NEXT_RECT := Rect2(760, 620, 260, 280)
const DRAG_THRESHOLD := 10.0
const LONG_PRESS_MS := 400
const COLOR_UP := "7dff8a"
const COLOR_DOWN := "ff7a6e"

@onready var close_btn: Button = $CloseBtn
@onready var sell_all_btn: Button = $SellAllBtn
@onready var sell_zone: Control = $SellZone
@onready var sell_label: Label = $SellZone/SellLabel
@onready var loot_title: Label = $LootTitle

var _im: Node
var _gm: Node
var _hero_view: GearGridView
var _bag_view: GearGridView
var _loot_view: LootStripView
var _stats_label: RichTextLabel
var _ficha_label: RichTextLabel
var _next_label: Label
var _ghost_layer: Control
var _puppet: Node2D
var _selected: CraftedItem = null

## Pulsación en curso: {"item", "from", "rot", "origin", "pos", "time", "long_done"}; {} si no hay.
## "origin" es la esquina de la caja de la pieza en la pantalla al pulsar. "item" es null si se pulsa el
## botín vacío (solo para desplazarlo).
var _press := {}
var _dragging := false
var _scrolling := false
var _scroll_start := 0.0
var _drag_rot := 0
var _drag_pos := Vector2.ZERO
## Destino del arrastre: {"place", "cell", "ok", "swap", "view"}; {} si no hay ninguno.
var _target := {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_im = get_node_or_null("/root/InventoryManager")
	_gm = get_node_or_null("/root/GameManager")
	close_btn.pressed.connect(close)
	_build()
	if _im:
		_im.crafted_items_changed.connect(func(_items): _refresh_if_open())
		_im.equipment_changed.connect(func(_stats): _refresh_if_open())
		_im.grid_resized.connect(func(_size): _refresh_if_open())


func _build() -> void:
	_stats_label = _rich(STATS_RECT, 30)
	_ficha_label = _rich(FICHA_RECT, 22)
	_puppet_setup()
	_hero_view = _grid_view(HERO_GRID_POS)
	_hero_view.show_zones = true  # la mochila no tiene zonas
	_bag_view = _grid_view(BAG_POS)
	_loot_view = LootStripView.new()
	_loot_view.position = LOOT_RECT.position
	_loot_view.size = LOOT_RECT.size
	_loot_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loot_view)
	_next_label = Label.new()
	_next_label.position = NEXT_RECT.position
	_next_label.size = NEXT_RECT.size
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_label.add_theme_font_size_override("font_size", 24)
	_next_label.add_theme_color_override("font_color", Color(0.75, 0.66, 0.54))
	add_child(_next_label)
	_ghost_layer = Control.new()
	_ghost_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_layer.draw.connect(_draw_ghost)
	add_child(_ghost_layer)  # el último: se dibuja encima de todo


func _grid_view(pos: Vector2) -> GearGridView:
	var view := GearGridView.new()
	view.position = pos
	add_child(view)
	return view


func _rich(rect: Rect2, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.position = rect.position
	label.size = rect.size
	label.bbcode_enabled = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", font_size)
	add_child(label)
	return label


## Tico a gran tamaño y tenue detrás de su rejilla (el mismo dibujo que en la mazmorra; con la franja de
## pegatinas integrada, ver la nota después de este bloque).
func _puppet_setup() -> void:
	_puppet = HERO_SCENE.instantiate()
	_puppet.remove_from_group("hero")  # que no lo confundan con el héroe de la partida
	_puppet.set("show_hud", false)
	_puppet.scale = Vector2(18, 18)  # 32 px de arte a ×18: casi el alto de la rejilla
	_puppet.position = HERO_GRID_POS + Vector2(330, 640)  # pies al fondo de la rejilla, centrado
	_puppet.modulate = Color(1, 1, 1, 0.35)
	_puppet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_puppet.z_index = 0  # Hero.tscn lo pone en 10 (por delante de los enemigos); aquí va detrás de la rejilla y de la pieza que se arrastra
	add_child(_puppet)
	_puppet.process_mode = Node.PROCESS_MODE_DISABLED  # solo se anima con el panel abierto


func open() -> void:
	visible = true
	_refresh()
	if _puppet:
		_puppet.process_mode = Node.PROCESS_MODE_INHERIT
		_puppet.respawn(_puppet.position)


func close() -> void:
	_cancel_press()
	visible = false
	if _puppet:
		_puppet.process_mode = Node.PROCESS_MODE_DISABLED
	emit_signal("panel_closed")

# ═══════════════════════════════════════════════════════════════════
#  REFRESCO
# ═══════════════════════════════════════════════════════════════════

func _refresh_if_open() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	if _im == null or not is_node_ready():
		return
	_hero_view.setup(_im.hero_grid, GridExpansions.MAX_SIZE)
	_bag_view.setup(_im.bag_grid, InventoryManager.BAG_SIZE)
	_loot_view.set_items(_im.get_loot())
	loot_title.text = tr("Botín · %d") % _im.get_loot_count()
	if _selected and not (_selected in _im.get_crafted_items()):
		_selected = null
	_refresh_stats({})
	_refresh_ficha()
	_refresh_next()
	if _puppet and _puppet.has_method("refresh_gear"):
		_puppet.refresh_gear()


## Estadísticas de Tico. `preview` ({"totals", "powers"}, del arrastre) añade el cambio en verde o rojo.
func _refresh_stats(preview: Dictionary) -> void:
	var now := CombatMath.hero_stats_with_powers(_im.calculate_total_stats(), _im.active_legendary_powers())
	var after: Dictionary = now if preview.is_empty() else CombatMath.hero_stats_with_powers(preview.totals, preview.powers)
	var mitigation := roundi(CombatMath.armor_mitigation(int(now.armor)) * 100.0)
	var parts := [
		tr("Vida %d") % now.max_hp + _delta(after.max_hp - now.max_hp, "%+d"),
		tr("Daño %.0f") % now.dmg + _delta(after.dmg - now.dmg, "%+.0f"),
		tr("Armadura %d (-%d%%)") % [now.armor, mitigation] + _delta(after.armor - now.armor, "%+d"),
		tr("Crítico %.0f%%") % (now.crit_p * 100.0) + _delta((after.crit_p - now.crit_p) * 100.0, "%+.0f"),
		tr("Velocidad %.2f") % now.aps + _delta(after.aps - now.aps, "%+.2f"),
	]
	_stats_label.text = "   ".join(parts)


## Cambio de la vista previa: verde si sube, rojo si baja, nada si no cambia.
func _delta(d: float, fmt: String) -> String:
	if absf(d) < 0.005:
		return ""
	return " [color=#%s]%s[/color]" % [COLOR_UP if d > 0.0 else COLOR_DOWN, fmt % d]


func _refresh_ficha() -> void:
	if _selected:
		_ficha_label.text = _ficha_text(_selected)
	else:
		_ficha_label.text = "[color=#a89a86]%s[/color]" % tr("Toca una pieza para verla; arrástrala para colocarla")


## Ficha breve (spec, apartado 9.1): nombre y calidad, estadísticas con su aumento, aura, zona y, si es
## legendaria, su habilidad y su precio.
func _ficha_text(item: CraftedItem) -> String:
	var pct: Dictionary = _im.hero_bonuses().get(item, {}) if item.place == InventoryManager.PLACE_HERO else {}
	var head := "[color=#%s]%s · %s[/color]" % [item.get_quality_color().to_html(false), item.get_name_with_rank(), item.get_quality_label()]
	var stats := []
	for key in ["damage", "hp", "armor", "crit", "aps"]:
		var v := float(item.calculated_stats.get(key, 0))
		if v <= 0.0:
			continue
		var boost := float(pct.get(key, 0.0))
		var text := _stat_text(key, v * (1.0 + boost))
		if boost > 0.0:
			text += " [color=#%s](+%d %%)[/color]" % [COLOR_UP, roundi(boost * 100.0)]
		stats.append(text)
	var extras := []
	var slot := item.get_equipment_slot()
	var strength := GearAuras.aura_strength(item)
	if strength > 0.0 and GearAuras.AURA_TEXTS.has(slot):
		extras.append(tr(GearAuras.AURA_TEXTS[slot]) % roundi(strength * 100.0))
	if GearAuras.ZONE_TEXTS.has(slot):
		extras.append(tr(GearAuras.ZONE_TEXTS[slot]))
	var power: Dictionary = LegendaryPowers.POWERS.get(StringName(item.item_resource.item_id), {})
	if LegendaryPowers.is_legendary(item) and not power.is_empty():
		var p := "[color=#ffa629]%s: %s[/color]" % [tr(power.name), tr(power.text)]
		if String(power.price) != "":
			p += " [color=#%s](%s)[/color]" % [COLOR_DOWN, tr(power.price)]
		extras.append(p)
	return "%s   %s\n%s" % [head, "  ".join(stats), " · ".join(extras)]


func _stat_text(key: String, v: float) -> String:
	match key:
		"damage":
			return tr("+%d Daño") % roundi(v)
		"hp":
			return tr("+%d Vida") % roundi(v)
		"armor":
			return tr("+%d Arm") % roundi(v)
		"crit":
			return tr("+%d%% Crít") % roundi(v * 100.0)
		"aps":
			return tr("+%.1f Vel") % v
	return ""


## Siguiente ampliación: el primer jefe del ciclo I que aún no ha ampliado la rejilla (tarea 12; con los
## rangos llegarán las recetas).
func _refresh_next() -> void:
	_next_label.text = ""
	for id in GridExpansions.ids():
		if id in _im.expansions:
			continue
		_next_label.text = tr("La rejilla crece al vencer al jefe de la sala %d") % int(GridExpansions.RECIPES[id].room)
		return

# ═══════════════════════════════════════════════════════════════════
#  EL DEDO
# ═══════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_press(event.position)
			else:
				_on_release(event.position)
		elif event.pressed and _dragging and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_rotate_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_on_motion(event.position)
	elif event is InputEventScreenTouch and event.pressed and event.index >= 1 and _dragging:
		_rotate_drag()  # segundo dedo
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R and _dragging:
		_rotate_drag()
		get_viewport().set_input_as_handled()


func _on_press(pos: Vector2) -> void:
	var hit := _piece_at(pos)
	if hit.is_empty():
		return  # botones y fondo: sigue su camino
	_press = hit
	_press.pos = pos
	_press.time = Time.get_ticks_msec()
	_press.long_done = false
	_dragging = false
	_scrolling = false
	_scroll_start = _loot_view.scroll
	get_viewport().set_input_as_handled()


## Pieza bajo un punto de la pantalla: {"item", "from", "rot", "origin"}, o {} si no hay nada que coger.
## En el botín vacío devuelve {"item": null, "from": &"loot"} para poder desplazarlo.
func _piece_at(pos: Vector2) -> Dictionary:
	for view in [_hero_view, _bag_view]:
		var local: Vector2 = pos - view.global_position
		if Rect2(Vector2.ZERO, view.size).has_point(local):
			var item: CraftedItem = view.item_at_local(local)
			if item:
				return {"item": item, "from": item.place, "rot": item.rot, "origin": view.global_position + view.item_origin(item)}
	var lp: Vector2 = pos - _loot_view.global_position
	if Rect2(Vector2.ZERO, _loot_view.size).has_point(lp):
		var slot: Dictionary = _loot_view.slot_at_local(lp)
		if slot.is_empty():
			return {"item": null, "from": InventoryManager.PLACE_LOOT, "rot": 0, "origin": pos}
		var origin: Vector2 = _loot_view.global_position + slot.rect.position - Vector2(_loot_view.scroll, 0.0)
		return {"item": slot.item, "from": InventoryManager.PLACE_LOOT, "rot": slot.rot, "origin": origin}
	return {}


func _on_motion(pos: Vector2) -> void:
	if _press.is_empty():
		return
	get_viewport().set_input_as_handled()
	if _dragging:
		_drag_pos = pos
		_update_target()
		return
	if _scrolling:
		_loot_view.scroll = clampf(_scroll_start - (pos.x - _press.pos.x), 0.0, _loot_view.max_scroll())
		_loot_view.queue_redraw()
		return
	var moved: Vector2 = pos - _press.pos
	if moved.length() < DRAG_THRESHOLD:
		return
	var in_loot: bool = _press.from == InventoryManager.PLACE_LOOT
	if _press.item == null or (in_loot and absf(moved.x) > absf(moved.y)):
		_scrolling = true
		_on_motion(pos)
		return
	_dragging = true
	_drag_rot = int(_press.rot)
	_drag_pos = pos
	_set_hidden(_press.item)
	_update_target()


func _on_release(_pos: Vector2) -> void:
	if _press.is_empty():
		return
	get_viewport().set_input_as_handled()
	var item: CraftedItem = _press.item
	if _dragging:
		_drop(item)
	elif not _scrolling and item and not _press.long_done:
		_tap(item)
	_cancel_press()


## Pulsación larga: enseña la ficha de la pieza.
func _process(_delta: float) -> void:
	if _press.is_empty() or _dragging or _scrolling or _press.item == null or _press.long_done:
		return
	if Time.get_ticks_msec() - int(_press.time) >= LONG_PRESS_MS:
		_press.long_done = true
		_selected = _press.item
		_refresh_ficha()


func _cancel_press() -> void:
	_press = {}
	_dragging = false
	_scrolling = false
	_target = {}
	_set_hidden(null)
	_clear_highlights()
	if _im and is_node_ready():
		_refresh_stats({})
	_ghost_layer.queue_redraw()


func _set_hidden(item: CraftedItem) -> void:
	_hero_view.hidden_item = item
	_bag_view.hidden_item = item
	_loot_view.hidden_item = item
	_hero_view.queue_redraw()
	_bag_view.queue_redraw()
	_loot_view.queue_redraw()


func _clear_highlights() -> void:
	for view in [_hero_view, _bag_view]:
		view.drop_cells = {}
		view.swap_item = null
		view.glow = {}
		view.queue_redraw()


## Toque: en una rejilla gira la pieza (si no cabe girada, tiembla); en el botín solo la enseña.
func _tap(item: CraftedItem) -> void:
	_selected = item
	if item.place != InventoryManager.PLACE_LOOT and not _im.rotate_in_place(item):
		(_hero_view if item.place == InventoryManager.PLACE_HERO else _bag_view).start_shake(item)
		Sfx.play(&"ui_tap", 0.0, 0.55)
	_refresh()


func _rotate_drag() -> void:
	_drag_rot = (_drag_rot + 1) % 4
	_target = {"rotated": true}  # distinto de cualquier destino: fuerza a volver a enseñarlo
	_update_target()


## Esquina de la caja de la pieza que se arrastra: donde la cogió el dedo, una casilla más arriba para
## que el dedo no tape el destino.
func _ghost_origin() -> Vector2:
	var grab: Vector2 = _press.origin - _press.pos
	return _drag_pos + grab + Vector2(0.0, -CELL)


## Busca el destino bajo la pieza (el centro de la primera casilla de su caja) y lo enseña.
func _update_target() -> void:
	var item: CraftedItem = _press.item
	var t := {}
	if _loot_view.get_global_rect().has_point(_drag_pos):
		t = {"place": InventoryManager.PLACE_LOOT, "ok": true}
	else:
		var anchor := _ghost_origin() + Vector2(CELL, CELL) * 0.5
		for view in [_hero_view, _bag_view]:
			var local: Vector2 = anchor - view.global_position
			if not Rect2(Vector2.ZERO, view.size).has_point(local):
				continue
			var place: StringName = InventoryManager.PLACE_HERO if view == _hero_view else InventoryManager.PLACE_BAG
			var cell: Vector2i = view.cell_at(local)
			var res: Dictionary = _im.drop_result(item, place, cell, _drag_rot)
			t = {"place": place, "cell": cell, "ok": res.ok, "swap": res.swap, "view": view}
			break
	if t != _target:
		_target = t
		_show_target()
	_ghost_layer.queue_redraw()


func _show_target() -> void:
	_clear_highlights()
	var item: CraftedItem = _press.item
	var preview := {}
	if _target.has("view"):
		var view: GearGridView = _target.view
		var fp := PieceShape.of_item(item, _drag_rot)
		var color := GearGridView.COLOR_OK if _target.ok else GearGridView.COLOR_BAD
		for c in fp.clean + fp.aristas:
			var cell: Vector2i = _target.cell + c
			if view.grid.in_bounds(cell):
				view.drop_cells[cell] = color
		view.swap_item = _target.swap
		if _target.ok:
			var sim: GearGrid = _im.simulate_hero_grid(item, _target.place, _target.cell, _drag_rot)
			preview = {"totals": GearAuras.totals(sim), "powers": LegendaryPowers.active(sim.items)}
			_hero_view.glow = _aura_changes(_im.hero_bonuses(), GearAuras.bonuses(sim))
	elif not _target.is_empty() and item.place == InventoryManager.PLACE_HERO:
		# Sacarla de Tico (al botín o, en la tarea 10, a la venta): la vista previa es sin ella
		var sim2: GearGrid = _im.simulate_hero_grid(item, InventoryManager.PLACE_LOOT, Vector2i.ZERO, 0)
		preview = {"totals": GearAuras.totals(sim2), "powers": LegendaryPowers.active(sim2.items)}
		_hero_view.glow = _aura_changes(_im.hero_bonuses(), GearAuras.bonuses(sim2))
	_refresh_stats(preview)
	for view in [_hero_view, _bag_view]:
		view.queue_redraw()


## Piezas de Tico que ganarían (verde) o perderían (rojo) aumento con el arrastre.
func _aura_changes(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for item in after:
		if item == _press.item:
			continue
		var d := _sum(after[item]) - _sum(before.get(item, {}))
		if d > 0.001:
			out[item] = GearGridView.COLOR_GAIN
		elif d < -0.001:
			out[item] = GearGridView.COLOR_LOSS
	return out


func _sum(pct: Dictionary) -> float:
	var s := 0.0
	for k in pct:
		s += float(pct[k])
	return s


func _drop(item: CraftedItem) -> void:
	if _target.is_empty() or not _target.get("ok", false):
		return  # vuelve a su sitio
	var place: StringName = _target.place
	var from_place := item.place
	var from_cell := item.cell
	var from_rot := item.rot
	if _im.move_item(item, place, _target.get("cell", Vector2i.ZERO), _drag_rot):
		_selected = item
		_refresh_ficha()  # el aviso del movimiento llega antes de elegirla
		# Soltarla donde ya estaba vale, pero no mueve nada: ni clinc ni materialización
		var moved := item.place != from_place or item.cell != from_cell or item.rot != from_rot
		if moved and place == InventoryManager.PLACE_HERO:
			Sfx.play(&"equip_clink")
			if _puppet:
				_puppet.set("_materialize", 0.55)


func _draw_ghost() -> void:
	if not _dragging or _press.is_empty():
		return
	GearGridView.draw_piece_at(_ghost_layer, _press.item, _ghost_origin(), _drag_rot, CELL, 0.85, _hero_view.sprite_for)
