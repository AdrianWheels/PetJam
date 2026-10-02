# res://scripts/ui/EquipmentPanel.gd
extends ColorRect

## Panel de Equipo a pantalla completa (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 9).
## De arriba abajo: estadísticas de Tico, ficha de la última pieza tocada, rejilla de Tico delante de su
## sprite (con los consumibles al lado), botín, mochila y zona de venta.
## El dedo lo lleva este panel, en _input:
##  - tocar una pieza de una rejilla la gira (si girada no cabe, tiembla); en el botín solo la enseña;
##  - mantener pulsado abre su ficha completa, con los botones A la mochila, Al botín, Vender y Cerrar;
##  - arrastrar la mueve: la pieza va una casilla por encima del dedo y un segundo dedo la gira;
##  - soltarla en la zona de venta la vende (las Épicas y Legendarias piden confirmación);
##  - en el botín, de lado se desplaza la tira; hacia arriba o abajo se coge la pieza;
##  - en un hueco de consumibles, tocar enseña la poción en la ficha y mantener pulsado ofrece venderla (la pulsación larga
##    termina la pulsación, como la de una pieza).
## En el ordenador el ratón hace lo mismo, y la rueda o la tecla R giran la pieza que se arrastra.
## Atrás (Android) llega como NOTIFICATION_WM_GO_BACK_REQUEST, no como tecla, y el árbol cierra el juego si
## quit_on_go_back es true: mientras el panel está abierto lo apaga. Atrás y Escape cierran lo de más arriba: la
## confirmación, si no la ficha y, si no, el panel (ver _back).

signal panel_closed

const HERO_SCENE := preload("res://scenes/Hero.tscn")
const CELL := GearGridView.CELL
const HERO_GRID_POS := Vector2(60, 262)
const BAG_POS := Vector2(60, 1350)
const LOOT_RECT := Rect2(60, 970, 960, 330)
const STATS_RECT := Rect2(60, 100, 960, 70)
const FICHA_RECT := Rect2(60, 174, 960, 84)
const NEXT_RECT := Rect2(760, 620, 260, 280)
## Los dos huecos de consumibles, a la derecha de la rejilla de Tico (que llega a x = 720 con 6 columnas)
const POTION_SLOT_RECTS := [Rect2(780, 300, 220, 120), Rect2(780, 440, 220, 120)]
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
var _potion_slots: Array[Label] = []
var _ghost_layer: Control
var _puppet: Node2D
var _selected: CraftedItem = null
## Ficha completa (pulsación larga) y confirmación: capas oscuras a pantalla completa con un panel en el centro.
## La confirmación guarda lo que hará si se dice que sí.
var _card: ColorRect
var _card_text: RichTextLabel
var _card_sell_btn: Button
var _card_item: CraftedItem = null
var _confirm_box: ColorRect
var _confirm_text: Label
var _confirm_action: Callable = Callable()

## Pulsación en curso: {"item", "from", "rot", "origin", "pos", "time"}; {} si no hay.
## "origin" es la esquina de la caja de la pieza en la pantalla al pulsar. "item" es null si se pulsa el
## botín vacío (solo para desplazarlo). La pulsación larga la termina (abre la ficha).
## En un hueco de consumibles: {"slot", "item": null, "from": &"slot", "pos", "time"}.
var _press := {}
var _dragging := false
var _scrolling := false
var _scroll_start := 0.0
var _drag_rot := 0
var _drag_pos := Vector2.ZERO
## Destino del arrastre: {"place", "cell", "ok", "swap", "view"}; {} si no hay ninguno.
var _target := {}
## Atrás en Android: el quit_on_go_back de antes de abrir el panel, si el panel lo tiene apagado ahora y si aún
## no ha devuelto lo que cambió (la devolución se hace en diferido).
var _go_back_saved := true
var _go_back_held := false
var _go_back_owed := false


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
		_im.consumables_changed.connect(func(_s): _refresh_if_open())


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
	for r in POTION_SLOT_RECTS:
		var slot := Label.new()
		slot.position = r.position
		slot.size = r.size
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 28)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.11, 0.09, 0.9)
		style.border_color = Color(0.55, 0.41, 0.24)
		style.set_border_width_all(3)
		style.set_corner_radius_all(12)
		slot.add_theme_stylebox_override("normal", style)
		add_child(slot)
		_potion_slots.append(slot)
	_ghost_layer = Control.new()
	_ghost_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_layer.draw.connect(_draw_ghost)
	add_child(_ghost_layer)  # encima de rejillas y botín; la ficha y la confirmación, creadas después, van sobre él (con ellas no se arrastra)
	_build_card()
	_build_confirm()
	sell_all_btn.pressed.connect(_on_sell_all)


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
	if is_node_ready():
		# Por si algo ocultó el panel sin pasar por close(): ni arrastre, ni ficha, ni confirmación de la vez anterior
		_cancel_press()
		_close_card()
		_close_confirm()
	visible = true
	_hold_go_back()
	_refresh()
	if _puppet:
		_puppet.process_mode = Node.PROCESS_MODE_INHERIT
		_puppet.respawn(_puppet.position)


func close() -> void:
	_cancel_press()
	_close_card()
	_close_confirm()
	visible = false
	_release_go_back()
	if _puppet:
		_puppet.process_mode = Node.PROCESS_MODE_DISABLED
	emit_signal("panel_closed")

# ═══════════════════════════════════════════════════════════════════
#  ATRÁS (ANDROID)
# ═══════════════════════════════════════════════════════════════════

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_visible_in_tree():
			_back()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		# También si algo oculta el panel sin pasar por close(), o lo oculta un ancestro suyo
		if is_visible_in_tree():
			_hold_go_back()
		else:
			_release_go_back()


## Atrás (Android) y Escape: cierran lo que esté más arriba. Primero la confirmación (y su acción se olvida), si no la
## ficha y, si no hay ninguna, el panel.
func _back() -> void:
	if _confirm_box.visible:
		_close_confirm()
	elif _card.visible:
		_close_card()
	else:
		close()


func _exit_tree() -> void:
	# Si el panel sale del árbol abierto, Atrás se devuelve ya: en diferido llegaría tarde para quien abra otro
	if _go_back_owed:
		_go_back_owed = false
		_go_back_held = false
		get_tree().quit_on_go_back = _go_back_saved


## Con el panel abierto, Atrás lo cierra a él y no al juego (spec, apartado 9.1).
func _hold_go_back() -> void:
	if _go_back_held or not is_inside_tree():
		return
	_go_back_held = true
	if not _go_back_owed:  # si queda una devolución sin hacer, lo guardado sigue siendo lo de antes del panel
		_go_back_saved = get_tree().quit_on_go_back
		_go_back_owed = true
	get_tree().quit_on_go_back = false


## Devuelve lo de antes en diferido: el aviso de Atrás que cierra el panel aún tiene que pasar por el árbol, que
## mira quit_on_go_back cuando los nodos ya han terminado, y cerraría el juego.
func _release_go_back() -> void:
	if _go_back_held:
		_go_back_held = false
		call_deferred("_give_back_go_back")


func _give_back_go_back() -> void:
	if _go_back_owed and not _go_back_held:  # si se ha abierto otra vez mientras tanto, no
		_go_back_owed = false
		get_tree().quit_on_go_back = _go_back_saved

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
	if _dragging:
		# Llegó una pieza, creció la rejilla...: el destino, sus casillas y la vista previa se calculan de nuevo
		_target = {"refreshed": true}  # distinto de cualquier destino: fuerza a enseñarlo otra vez
		_update_target()
	else:
		_refresh_stats({})
	_refresh_ficha()
	_refresh_next()
	_refresh_potions()
	if _puppet and _puppet.has_method("refresh_gear"):
		_puppet.refresh_gear()


## Estadísticas de Tico. `preview` ({"totals", "powers", "rank"}, del arrastre) añade el cambio en verde o rojo.
func _refresh_stats(preview: Dictionary) -> void:
	var now := CombatMath.hero_stats_with_powers(_im.calculate_total_stats(), _im.active_legendary_powers(), _im.equipment_rank())
	var after: Dictionary = now if preview.is_empty() else CombatMath.hero_stats_with_powers(preview.totals, preview.powers, int(preview.get("rank", 1)))
	# La reducción depende del enemigo: se enseña la de la sala actual
	var room: int = int(_gm.current_enemy_level) if _gm and "current_enemy_level" in _gm else 1
	var mitigation := roundi(CombatMath.armor_mitigation(int(now.armor), room) * 100.0)
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


## Los huecos de consumibles: qué poción llevan y cuántas, o que están libres.
func _refresh_potions() -> void:
	for i in _potion_slots.size():
		var s: Dictionary = _im.consumables[i]
		_potion_slots[i].text = "%s ×%d" % [tr(Potions.CATALOG[s.id].short), int(s.count)] if int(s.count) > 0 else tr("Hueco libre")

# ═══════════════════════════════════════════════════════════════════
#  EL DEDO
# ═══════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		_back()
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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and _dragging:
		_rotate_drag()
		get_viewport().set_input_as_handled()


func _on_press(pos: Vector2) -> void:
	if _card.visible or _confirm_box.visible:
		return  # con la ficha o la confirmación abiertas, el dedo es de sus botones
	var potion := _potion_slot_at(pos)
	if potion >= 0:
		_press = {"slot": potion, "item": null, "from": &"slot", "pos": pos, "time": Time.get_ticks_msec()}
		get_viewport().set_input_as_handled()
		return
	var hit := _piece_at(pos)
	if hit.is_empty():
		return  # botones y fondo: sigue su camino
	_press = hit
	_press.pos = pos
	_press.time = Time.get_ticks_msec()
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


## Hueco de consumibles con pociones bajo un punto de la pantalla, o -1 (un hueco libre no se pulsa).
func _potion_slot_at(pos: Vector2) -> int:
	for i in POTION_SLOT_RECTS.size():
		if POTION_SLOT_RECTS[i].has_point(pos) and int(_im.consumables[i].count) > 0:
			return i
	return -1


func _on_motion(pos: Vector2) -> void:
	if _press.is_empty():
		return
	if _press.has("slot"):
		return  # un hueco solo se toca o se mantiene: el dedo no lo arrastra
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
	if _press.has("slot"):
		_show_potion(_press.slot)  # solo llega aquí un toque: la pulsación larga ya terminó la pulsación
		_cancel_press()
		return
	var item: CraftedItem = _press.item
	if _dragging:
		_drop(item)
	elif not _scrolling and item:
		_tap(item)
	_cancel_press()


## Pulsación larga: abre la ficha completa de la pieza o, en un hueco de consumibles, ofrece vender sus pociones. Las dos
## terminan la pulsación, para que mover el dedo después no arrastre la pieza por debajo de la ficha ni soltarlo la gire.
func _process(_delta: float) -> void:
	if _press.is_empty() or _dragging or _scrolling:
		return
	if Time.get_ticks_msec() - int(_press.time) < LONG_PRESS_MS:
		return
	if _press.has("slot"):
		var index: int = _press.slot
		_cancel_press()
		_ask_sell_potions(index)
	elif _press.item:  # el botín vacío no tiene ficha: solo se desplaza
		var item: CraftedItem = _press.item
		_selected = item
		_refresh_ficha()
		_open_card(item)
		_cancel_press()


func _cancel_press() -> void:
	_press = {}
	_dragging = false
	_scrolling = false
	_target = {}
	_set_hidden(null)
	_clear_highlights()
	sell_label.text = tr("Suelta aquí para vender")
	sell_zone.modulate = Color.WHITE
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


## Toque en un hueco de consumibles: enseña la poción (nombre y qué hace) en la ficha breve.
func _show_potion(index: int) -> void:
	var s: Dictionary = _im.consumables[index]
	if int(s.count) <= 0:
		return  # se ha bebido mientras el dedo estaba en el hueco
	var info: Dictionary = Potions.CATALOG[s.id]
	_ficha_label.text = "%s\n%s" % [tr(info.display_name), tr(info.description)]


func _rotate_drag() -> void:
	_drag_rot = (_drag_rot + 1) % 4
	_target = {"rotated": true}  # distinto de cualquier destino: fuerza a volver a enseñarlo
	_update_target()


## Esquina de la caja de la pieza que se arrastra: donde la cogió el dedo, una casilla más arriba para
## que el dedo no tape el destino.
func _ghost_origin() -> Vector2:
	var grab: Vector2 = _press.origin - _press.pos
	return _drag_pos + grab + Vector2(0.0, -CELL)


## Busca el destino y lo enseña. Primero la zona de venta, por el dedo: con el dedo en ella, la parte cogida ya está fuera
## de la mochila, pero una pieza ancha puede tener aún su primera casilla encima de ella y saldría un rojo. Después las
## rejillas, por la casilla que hay bajo la pieza (el centro de la primera casilla de su caja; solo cuentan las que ya
## existen, no las punteadas, que sobre una rejilla pequeña taparían el botín). Si no hay ninguna, el botín, por el dedo.
func _update_target() -> void:
	var item: CraftedItem = _press.item
	var t := {}
	if sell_zone.get_global_rect().has_point(_drag_pos):
		t = {"place": &"sell", "ok": true}
	if t.is_empty():
		var anchor := _ghost_origin() + Vector2(CELL, CELL) * 0.5
		for view in [_hero_view, _bag_view]:
			var local: Vector2 = anchor - view.global_position
			if not Rect2(Vector2.ZERO, view.size).has_point(local):
				continue
			var cell: Vector2i = view.cell_at(local)
			if not view.grid.in_bounds(cell):
				continue
			var place: StringName = InventoryManager.PLACE_HERO if view == _hero_view else InventoryManager.PLACE_BAG
			var res: Dictionary = _im.drop_result(item, place, cell, _drag_rot)
			t = {"place": place, "cell": cell, "ok": res.ok, "swap": res.swap, "view": view}
			break
	if t.is_empty() and _loot_view.get_global_rect().has_point(_drag_pos):
		t = {"place": InventoryManager.PLACE_LOOT, "ok": true}
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
			preview = {"totals": GearAuras.totals(sim), "powers": LegendaryPowers.active(sim.items), "rank": InventoryManager.grid_rank(sim)}
			_hero_view.glow = _aura_changes(_im.hero_bonuses(), GearAuras.bonuses(sim))
	elif not _target.is_empty() and item.place == InventoryManager.PLACE_HERO:
		# Sacarla de Tico (al botín o a la venta): la vista previa es sin ella
		var sim2: GearGrid = _im.simulate_hero_grid(item, InventoryManager.PLACE_LOOT, Vector2i.ZERO, 0)
		preview = {"totals": GearAuras.totals(sim2), "powers": LegendaryPowers.active(sim2.items), "rank": InventoryManager.grid_rank(sim2)}
		_hero_view.glow = _aura_changes(_im.hero_bonuses(), GearAuras.bonuses(sim2))
	# La zona de venta enseña lo que daría la pieza mientras está encima
	var selling: bool = _target.get("place", &"") == &"sell"
	sell_label.text = tr("Vender por %d de oro") % item.get_sell_price() if selling else tr("Suelta aquí para vender")
	sell_zone.modulate = Color(1.4, 1.25, 0.8) if selling else Color.WHITE
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
	if _target.place == &"sell":
		_sell(item)
		return
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

# ═══════════════════════════════════════════════════════════════════
#  FICHA COMPLETA, CONFIRMACIÓN Y VENTA
# ═══════════════════════════════════════════════════════════════════

## Capa oscura a pantalla completa con un panel centrado; la usan la ficha y la confirmación.
## Devuelve [la capa, la caja vertical del panel].
func _overlay(top: float) -> Array:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.visible = false
	add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(90, top)
	panel.custom_minimum_size = Vector2(900, 0)
	shade.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	return [shade, box]


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 96)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b


func _build_card() -> void:
	var parts := _overlay(560)
	_card = parts[0]
	_card_text = RichTextLabel.new()
	_card_text.bbcode_enabled = true
	_card_text.fit_content = true
	_card_text.custom_minimum_size = Vector2(860, 0)
	_card_text.add_theme_font_size_override("normal_font_size", 28)
	parts[1].add_child(_card_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	parts[1].add_child(row)
	row.add_child(_button(tr("A la mochila"), _card_to_bag))
	row.add_child(_button(tr("Al botín"), _card_to_loot))
	_card_sell_btn = _button(tr("Vender"), _card_sell)
	row.add_child(_card_sell_btn)
	row.add_child(_button(tr("Cerrar"), _close_card))


func _build_confirm() -> void:
	var parts := _overlay(760)
	_confirm_box = parts[0]
	_confirm_text = Label.new()
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size = Vector2(860, 0)
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.add_theme_font_size_override("font_size", 30)
	parts[1].add_child(_confirm_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	parts[1].add_child(row)
	row.add_child(_button(tr("Sí"), _on_confirm_yes))
	row.add_child(_button(tr("No"), _close_confirm))


## Ficha completa de una pieza (pulsación larga): su ficha breve y qué se puede hacer con ella.
func _open_card(item: CraftedItem) -> void:
	_card_item = item
	var aristas := tr("Sin aristas") if item.aristas.is_empty() else tr("Aristas: %d") % item.aristas.size()
	_card_text.text = "%s\n[color=#a89a86]%s[/color]" % [_ficha_text(item), aristas]
	_card_sell_btn.text = tr("Vender por %d") % item.get_sell_price()
	_card.visible = true


func _close_card() -> void:
	_card.visible = false
	_card_item = null


func _card_to_bag() -> void:
	var item := _card_item
	_close_card()
	if item == null or item.place == InventoryManager.PLACE_BAG:
		return
	var spot := GearPacker.find_spot(_im.bag_grid, item, false)
	if spot.is_empty() or not _im.move_item(item, InventoryManager.PLACE_BAG, spot.cell, spot.rot):
		Sfx.play(&"ui_tap", 0.0, 0.55)  # la mochila está llena
		# Y se dice en la ficha breve, que si no parece que el botón no ha hecho nada. Se va con el siguiente refresco
		_ficha_label.text = "[color=#%s]%s[/color]" % [COLOR_DOWN, tr("La mochila está llena")]


func _card_to_loot() -> void:
	var item := _card_item
	_close_card()
	if item:
		_im.move_item(item, InventoryManager.PLACE_LOOT)


func _card_sell() -> void:
	var item := _card_item
	_close_card()
	if item:
		_sell(item)


## Pregunta antes de hacer algo que no se deshace.
func _confirm(text: String, action: Callable) -> void:
	_confirm_text.text = text
	_confirm_action = action
	_confirm_box.visible = true


## Cierra la confirmación sin hacer nada y se olvida de su acción (No, Atrás y cerrar el panel).
func _close_confirm() -> void:
	_confirm_box.visible = false
	_confirm_action = Callable()


func _on_confirm_yes() -> void:
	var action := _confirm_action
	_close_confirm()  # antes de actuar: si la acción pregunta otra cosa, esa pregunta se queda
	if action.is_valid():
		action.call()


## Venta desde la zona de venta o la ficha: las Épicas y las Legendarias piden confirmación.
func _sell(item: CraftedItem) -> void:
	if item.get_quality_tier() in ["epic", "legendary"]:
		_confirm(tr("¿Vender %s por %d de oro?") % [item.get_name_with_rank(), item.get_sell_price()], func(): _do_sell(item))
	else:
		_do_sell(item)


func _do_sell(item: CraftedItem) -> void:
	if _im.sell_item(item) > 0:
		Sfx.play(&"loot_coins")
	_refresh()


## "Vender todo": el botín salvo las Épicas y las Legendarias, tras confirmar con el total.
func _on_sell_all() -> void:
	var items: Array = _im.sellable_loot()
	if items.is_empty():
		Sfx.play(&"ui_tap", 0.0, 0.55)
		return
	var total := 0
	for item in items:
		total += item.get_sell_price()
	_confirm(tr("¿Vender %d piezas del botín por %d de oro? Las Épicas y Legendarias se quedan.") % [items.size(), total], func():
		if _im.sell_all_loot() > 0:
			Sfx.play(&"loot_coins")
		_refresh()
	)


## Pulsación larga en un hueco: vender sus pociones a mitad de precio (la única forma de cambiar de tipo).
func _ask_sell_potions(index: int) -> void:
	var s: Dictionary = _im.consumables[index]
	if int(s.count) <= 0:
		return  # se ha bebido mientras el dedo estaba en el hueco
	var info: Dictionary = Potions.CATALOG[s.id]
	var gold := roundi(int(s.count) * int(info.price) * 0.5)
	_confirm(tr("¿Vender %d %s por %d de oro?") % [int(s.count), tr(info.short), gold], func():
		if _im.sell_potion_slot(index) > 0:
			Sfx.play(&"loot_coins")
		_refresh()
	)
