extends Control
class_name ShopPanel

## Panel de tienda para comprar materiales y pociones con oro
## Se abre desde el botón ShopBtn en el BottomRightPanel

signal shop_closed
signal item_purchased(item_id: StringName, quantity: int, cost: int)
signal item_sold(item: CraftedItem, gold_earned: int)

## Precio base de venta por tier de calidad
const SELL_PRICE_BY_TIER := {
	"legendary": 500,
	"epic": 250,
	"rare": 120,
	"uncommon": 60,
	"common": 25,
}

# ═══════════════════════════════════════════════════════════════════
#  CATÁLOGO DE LA TIENDA
# ═══════════════════════════════════════════════════════════════════

## Materiales disponibles para compra: id → {display_name, price, icon_path}
const MATERIAL_CATALOG := {
	&"wood": {"display_name": "Madera", "price": 15, "quantity": 5},
	&"iron": {"display_name": "Hierro", "price": 25, "quantity": 5},
	&"leather": {"display_name": "Cuero", "price": 20, "quantity": 5},
	&"cloth": {"display_name": "Tela", "price": 15, "quantity": 5},
	&"herb": {"display_name": "Hierba", "price": 30, "quantity": 3},
	&"fire": {"display_name": "Fuego", "price": 40, "quantity": 3},
	&"water": {"display_name": "Agua", "price": 40, "quantity": 3},
	&"ice": {"display_name": "Hielo", "price": 50, "quantity": 2},
	&"poison": {"display_name": "Veneno", "price": 50, "quantity": 2},
}

## Pociones: efecto temporal o mejora permanente (futuro)
const POTION_CATALOG := {
	&"potion_heal": {"display_name": "Poción de Vida", "price": 100, "description": "Cura al héroe al máximo"},
	&"potion_speed": {"display_name": "Poción de Velocidad", "price": 150, "description": "Héroe ataca 50% más rápido (30s)"},
	&"potion_luck": {"display_name": "Poción de Suerte", "price": 200, "description": "+20% probabilidad de drops (60s)"},
}

# ═══════════════════════════════════════════════════════════════════
#  NODOS INTERNOS (creados en _build_ui)
# ═══════════════════════════════════════════════════════════════════

var _bg: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _gold_label: Label
var _tab_container: TabContainer
var _materials_grid: GridContainer
var _potions_grid: GridContainer
var _inventory_grid: VBoxContainer
var _inventory_empty_label: Label
var _close_btn: Button
var _toast_label: Label
var _toast_tween: Tween

var _inventory_manager: Node


func _ready() -> void:
	_inventory_manager = get_node_or_null("/root/InventoryManager")
	_build_ui()
	_populate_materials()
	_populate_potions()
	_populate_sell_items()
	_update_gold_display()
	
	# Conectar señal de inventario para actualizar oro y cantidades
	if _inventory_manager and _inventory_manager.has_signal("inventory_changed"):
		_inventory_manager.inventory_changed.connect(_on_inventory_changed)
	if _inventory_manager and _inventory_manager.has_signal("crafted_items_changed"):
		_inventory_manager.crafted_items_changed.connect(_on_crafted_items_changed)


func _build_ui() -> void:
	# Fondo semitransparente — solo cubre la zona del minijuego (25%-75% vertical)
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.7)
	_bg.anchor_left = 0.0
	_bg.anchor_top = 0.25
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 0.75
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)
	
	# Panel central — misma zona que el MinigamePanel
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.25
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 0.75
	_panel.offset_left = 20
	_panel.offset_top = 10
	_panel.offset_right = -20
	_panel.offset_bottom = -10
	add_child(_panel)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(main_vbox)
	
	# ── Header: Título + Oro + Cerrar ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header)
	
	_title_label = Label.new()
	_title_label.text = "🏪 TIENDA"
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	
	_gold_label = Label.new()
	_gold_label.text = "💰 0"
	_gold_label.add_theme_font_size_override("font_size", 34)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_gold_label)
	
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(90, 90)
	_close_btn.add_theme_font_size_override("font_size", 38)
	_close_btn.pressed.connect(_on_close_pressed)
	header.add_child(_close_btn)
	
	# ── Separador ──
	var sep := HSeparator.new()
	main_vbox.add_child(sep)
	
	# ── Tabs: Materiales / Pociones ──
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_tab_container)
	
	# Tab Materiales
	var materials_scroll := ScrollContainer.new()
	materials_scroll.name = "Materiales"
	materials_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	materials_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(materials_scroll)
	
	_materials_grid = GridContainer.new()
	_materials_grid.columns = 2
	_materials_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_materials_grid.add_theme_constant_override("h_separation", 12)
	_materials_grid.add_theme_constant_override("v_separation", 12)
	materials_scroll.add_child(_materials_grid)
	
	# Tab Pociones
	var potions_scroll := ScrollContainer.new()
	potions_scroll.name = "Pociones"
	potions_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	potions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(potions_scroll)
	
	_potions_grid = GridContainer.new()
	_potions_grid.columns = 1
	_potions_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_potions_grid.add_theme_constant_override("h_separation", 12)
	_potions_grid.add_theme_constant_override("v_separation", 12)
	potions_scroll.add_child(_potions_grid)
	
	# Tab Vender
	var sell_scroll := ScrollContainer.new()
	sell_scroll.name = "Vender"
	sell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(sell_scroll)
	
	_inventory_grid = VBoxContainer.new()
	_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_grid.add_theme_constant_override("separation", 12)
	sell_scroll.add_child(_inventory_grid)
	
	# Label vacío para cuando no hay items
	_inventory_empty_label = Label.new()
	_inventory_empty_label.text = "No tienes items para vender.\nCraftea equipo y véndelo aquí."
	_inventory_empty_label.add_theme_font_size_override("font_size", 26)
	_inventory_empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_inventory_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_grid.add_child(_inventory_empty_label)
	
	# ── Toast de feedback ──
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 26)
	_toast_label.modulate.a = 0.0
	main_vbox.add_child(_toast_label)


func _populate_materials() -> void:
	for mat_id in MATERIAL_CATALOG:
		var info: Dictionary = MATERIAL_CATALOG[mat_id]
		var card := _create_material_card(mat_id, info)
		_materials_grid.add_child(card)


func _populate_potions() -> void:
	for pot_id in POTION_CATALOG:
		var info: Dictionary = POTION_CATALOG[pot_id]
		var card := _create_potion_card(pot_id, info)
		_potions_grid.add_child(card)


func _create_material_card(mat_id: StringName, info: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 140)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"  # _update_material_cards busca "VBoxContainer/Row/NameLabel"
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	
	# Icono del material + nombre + cantidad actual
	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var mat_res_path := "res://data/materials/%s.tres" % String(mat_id)
	if ResourceLoader.exists(mat_res_path):
		var mat_res = load(mat_res_path)
		if mat_res and "icon" in mat_res:
			icon.texture = mat_res.icon
	row.add_child(icon)
	var name_label := Label.new()
	name_label.name = "NameLabel"
	var owned: int = _inventory_manager.get_quantity(mat_id) if _inventory_manager else 0
	name_label.text = "%s (x%d)" % [info.display_name, owned]
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	
	# Botón comprar
	var buy_btn := Button.new()
	buy_btn.name = "BuyBtn"
	var qty: int = info.quantity
	var price: int = info.price
	buy_btn.text = "Comprar %dx — %d 💰" % [qty, price]
	buy_btn.custom_minimum_size = Vector2(0, 70)
	buy_btn.add_theme_font_size_override("font_size", 26)
	buy_btn.pressed.connect(_on_buy_material.bind(mat_id, qty, price))
	vbox.add_child(buy_btn)
	
	# Almacenar referencia para updates
	card.set_meta("mat_id", mat_id)
	
	return card


func _create_potion_card(pot_id: StringName, info: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	
	# Nombre
	var name_label := Label.new()
	name_label.text = "🧪 %s" % info.display_name
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Descripción
	var desc_label := Label.new()
	desc_label.text = info.description
	desc_label.add_theme_font_size_override("font_size", 24)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	# Botón comprar
	var buy_btn := Button.new()
	buy_btn.text = "Comprar — %d 💰" % info.price
	buy_btn.custom_minimum_size = Vector2(0, 70)
	buy_btn.add_theme_font_size_override("font_size", 26)
	buy_btn.pressed.connect(_on_buy_potion.bind(pot_id, info.price))
	vbox.add_child(buy_btn)
	
	card.set_meta("pot_id", pot_id)
	
	return card


# ═══════════════════════════════════════════════════════════════════
#  LÓGICA DE COMPRA
# ═══════════════════════════════════════════════════════════════════

func _on_buy_material(mat_id: StringName, quantity: int, price: int) -> void:
	if not _inventory_manager:
		return
	
	var gold: int = _inventory_manager.get_quantity(&"gold")
	if gold < price:
		_show_toast("❌ Oro insuficiente", Color(1.0, 0.3, 0.3))
		return
	
	# Consumir oro y añadir materiales
	_inventory_manager.consume_materials({&"gold": price})
	_inventory_manager.add_item(mat_id, quantity)
	
	var info: Dictionary = MATERIAL_CATALOG.get(mat_id, {})
	var display_name: String = info.get("display_name", String(mat_id))
	_show_toast("✅ +%d %s" % [quantity, display_name], Color(0.3, 1.0, 0.3))
	item_purchased.emit(mat_id, quantity, price)
	
	print("ShopPanel: Comprado %dx %s por %d oro" % [quantity, mat_id, price])


func _on_buy_potion(pot_id: StringName, price: int) -> void:
	if not _inventory_manager:
		return
	
	var gold: int = _inventory_manager.get_quantity(&"gold")
	if gold < price:
		_show_toast("❌ Oro insuficiente", Color(1.0, 0.3, 0.3))
		return
	
	# Consumir oro
	_inventory_manager.consume_materials({&"gold": price})
	
	# Aplicar efecto de poción
	_apply_potion_effect(pot_id)
	
	var info: Dictionary = POTION_CATALOG.get(pot_id, {})
	var display_name: String = info.get("display_name", String(pot_id))
	_show_toast("✅ %s aplicada" % display_name, Color(0.3, 1.0, 0.3))
	item_purchased.emit(pot_id, 1, price)
	
	print("ShopPanel: Comprado %s por %d oro" % [pot_id, price])


func _apply_potion_effect(pot_id: StringName) -> void:
	var gm = get_node_or_null("/root/GameManager")
	match pot_id:
		&"potion_heal":
			# Curar héroe al máximo
			if gm and gm.has_method("heal_hero"):
				gm.heal_hero()
			else:
				# Buscar héroe directamente
				var hero = _find_hero()
				if hero and "hp" in hero:
					hero.hp = hero.max_hp if "max_hp" in hero else 100
					print("ShopPanel: Héroe curado al máximo")
		&"potion_speed":
			# TODO: Implementar buff temporal de velocidad
			print("ShopPanel: Poción de velocidad — buff temporal (pendiente)")
		&"potion_luck":
			# TODO: Implementar buff temporal de suerte
			print("ShopPanel: Poción de suerte — buff temporal (pendiente)")


func _find_hero() -> Node:
	# Buscar héroe en el árbol de escena
	var tree := get_tree()
	if tree == null:
		return null
	var heroes := tree.get_nodes_in_group("hero")
	if not heroes.is_empty():
		return heroes[0]
	return null


# ═══════════════════════════════════════════════════════════════════
#  UI UPDATES
# ═══════════════════════════════════════════════════════════════════

func _update_gold_display() -> void:
	if _gold_label and _inventory_manager:
		var gold: int = _inventory_manager.get_quantity(&"gold")
		_gold_label.text = "💰 %d" % gold


func _update_material_cards() -> void:
	if not _materials_grid or not _inventory_manager:
		return
	
	for card in _materials_grid.get_children():
		if not card.has_meta("mat_id"):
			continue
		var mat_id: StringName = card.get_meta("mat_id")
		var info: Dictionary = MATERIAL_CATALOG.get(mat_id, {})
		var name_label = card.get_node_or_null("VBoxContainer/Row/NameLabel")
		if name_label:
			var owned: int = _inventory_manager.get_quantity(mat_id)
			name_label.text = "%s (x%d)" % [info.get("display_name", ""), owned]


func _on_inventory_changed(_inv: Dictionary) -> void:
	_update_gold_display()
	_update_material_cards()


func _on_crafted_items_changed(_items: Array) -> void:
	_populate_sell_items()


# ═══════════════════════════════════════════════════════════════════
#  TAB VENDER — Items crafteados
# ═══════════════════════════════════════════════════════════════════

func _get_sell_price(item: CraftedItem) -> int:
	var tier := item.get_quality_tier()
	return SELL_PRICE_BY_TIER.get(tier, 25)


func _populate_sell_items() -> void:
	if not _inventory_grid:
		return
	
	# Limpiar grid actual
	for child in _inventory_grid.get_children():
		child.queue_free()
	
	if not _inventory_manager:
		return
	
	# Obtener items no equipados
	var items: Array = []
	if _inventory_manager.has_method("get_unequipped_items"):
		items = _inventory_manager.get_unequipped_items()
	
	if items.is_empty():
		# Mostrar mensaje vacío
		_inventory_empty_label = Label.new()
		_inventory_empty_label.text = "No tienes items para vender.\nCraftea equipo y véndelo aquí."
		_inventory_empty_label.add_theme_font_size_override("font_size", 26)
		_inventory_empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_inventory_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_inventory_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_inventory_grid.add_child(_inventory_empty_label)
		return
	
	# Crear tarjeta de venta por cada item
	for item in items:
		if item is CraftedItem:
			var card := _create_sell_card(item)
			_inventory_grid.add_child(card)


func _create_sell_card(item: CraftedItem) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 130)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Borde de color según tier
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 1.0)
	style.border_color = item.get_quality_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)
	
	# Info del item (izquierda)
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)
	
	# Nombre con color de tier
	var name_label := Label.new()
	name_label.text = item.get_display_name()
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", item.get_quality_color())
	info_vbox.add_child(name_label)
	
	# Tier label
	var tier_label := Label.new()
	tier_label.text = item.get_quality_label()
	tier_label.add_theme_font_size_override("font_size", 20)
	tier_label.add_theme_color_override("font_color", item.get_quality_color().lerp(Color.WHITE, 0.3))
	info_vbox.add_child(tier_label)
	
	# Stats resumidos
	var stats_text := ""
	for stat_key in item.calculated_stats:
		var val = item.calculated_stats[stat_key]
		if typeof(val) == TYPE_FLOAT and val < 0.01:
			continue
		if typeof(val) == TYPE_INT and val == 0:
			continue
		if stats_text != "":
			stats_text += " · "
		stats_text += "%s: +%s" % [stat_key.to_upper(), str(snapped(val, 0.1) if typeof(val) == TYPE_FLOAT else val)]
	
	if stats_text != "":
		var stats_label := Label.new()
		stats_label.text = stats_text
		stats_label.add_theme_font_size_override("font_size", 18)
		stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(stats_label)
	
	# Botón vender (derecha)
	var sell_price := _get_sell_price(item)
	var sell_btn := Button.new()
	sell_btn.text = "💰 %d" % sell_price
	sell_btn.custom_minimum_size = Vector2(130, 70)
	sell_btn.add_theme_font_size_override("font_size", 26)
	sell_btn.pressed.connect(_on_sell_item.bind(item, sell_price))
	hbox.add_child(sell_btn)
	
	return card


func _on_sell_item(item: CraftedItem, price: int) -> void:
	if not _inventory_manager:
		return
	
	# Eliminar item del inventario
	if _inventory_manager.has_method("remove_crafted_item"):
		var success: bool = _inventory_manager.remove_crafted_item(item)
		if not success:
			_show_toast("❌ Error al vender", Color(1.0, 0.3, 0.3))
			return
	
	# Dar oro
	_inventory_manager.add_item(&"gold", price)
	
	var display_name := item.get_display_name()
	_show_toast("💰 +%d oro — %s vendido" % [price, display_name], Color(1.0, 0.85, 0.2))
	item_sold.emit(item, price)
	
	print("ShopPanel: Vendido '%s' por %d oro" % [display_name, price])
	
	# Refrescar lista de items vendibles
	_populate_sell_items()


func _show_toast(text: String, color: Color = Color.WHITE) -> void:
	if not _toast_label:
		return
	
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	
	if _toast_tween:
		_toast_tween.kill()
	
	_toast_tween = create_tween()
	_toast_label.modulate.a = 1.0
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


# ═══════════════════════════════════════════════════════════════════
#  APERTURA / CIERRE
# ═══════════════════════════════════════════════════════════════════

func open() -> void:
	visible = true
	_update_gold_display()
	_update_material_cards()
	_populate_sell_items()
	# Ocultar fondo de forja si existe (estamos sobre el MinigamePanel)
	var hud_main = get_parent()
	if hud_main and hud_main.has_method("get_minigame_viewport"):
		var vp: SubViewport = hud_main.get_minigame_viewport()
		if vp:
			var bg = vp.get_node_or_null("ForgeBackground")
			if bg:
				bg.visible = false
	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		visible = false
		# Restaurar fondo de forja
		var hud_main = get_parent()
		if hud_main and hud_main.has_method("get_minigame_viewport"):
			var vp: SubViewport = hud_main.get_minigame_viewport()
			if vp:
				var bg = vp.get_node_or_null("ForgeBackground")
				if bg:
					bg.visible = true
		shop_closed.emit()
	)


func _on_close_pressed() -> void:
	close()
