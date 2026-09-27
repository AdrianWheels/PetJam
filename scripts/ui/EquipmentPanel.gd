# res://scripts/ui/EquipmentPanel.gd
extends ColorRect

## Panel modal para ver y gestionar el equipo del héroe.
## Muestra al héroe EN VIVO (el mismo dibujo que en la mazmorra) con lo que lleva puesto:
## al equipar algo se ve al instante. Huecos con el icono del objeto y marco del color de su calidad.
## Equipar = tocar un objeto de la mochila. Desequipar = tocar un hueco ocupado.

signal item_equipped(slot_type: StringName, item)
signal panel_closed

const HERO_SCENE := preload("res://scenes/Hero.tscn")

# Referencias a nodos
@onready var close_btn: Button = $PanelContainer/MainVBox/TitleBar/CloseBtn
@onready var wow_layout: HBoxContainer = $PanelContainer/MainVBox/ContentHBox/EquipmentBG/WoWStyleLayout
@onready var inventory_grid: GridContainer = $PanelContainer/MainVBox/ContentHBox/InventoryBG/InventorySection/InventoryScroll/InventoryGrid
@onready var hero_center: CenterContainer = $PanelContainer/MainVBox/ContentHBox/EquipmentBG/WoWStyleLayout/HeroCenter

# Stats labels
@onready var hp_label: Label = $PanelContainer/MainVBox/StatsBG/HeroStatsSection/StatsGrid/HPLabel
@onready var dmg_label: Label = $PanelContainer/MainVBox/StatsBG/HeroStatsSection/StatsGrid/DMGLabel
@onready var armor_label: Label = $PanelContainer/MainVBox/StatsBG/HeroStatsSection/StatsGrid/ARMORLabel
@onready var crit_label: Label = $PanelContainer/MainVBox/StatsBG/HeroStatsSection/StatsGrid/CRITLabel

# Slots de equipo (referencias)
var _equipment_slots: Dictionary = {}

# Managers
var _inventory_manager: Node
var _game_manager: Node

# Héroe de muestra (solo dibujo; no combate)
var _puppet: Node2D

const EQUIPMENT_SLOT_TYPES := ["head", "main_hand", "off_hand", "body", "feet"]
const SLOT_NAMES := {"head": "Casco", "main_hand": "Arma", "off_hand": "Escudo", "body": "Pecho", "feet": "Botas"}
const TIER_NAMES := {"legendary": "Legendario", "epic": "Épico", "rare": "Raro", "uncommon": "Bueno", "common": "Básico"}
const RARITY_RANK := {"basic": 0, "advanced": 1, "master": 2}

# Colores de estado
const COLOR_SLOT_EMPTY := Color(0.11, 0.075, 0.065, 1.0)
const COLOR_SLOT_HOVER := Color(0.4, 0.4, 0.5, 1.0)
const COLOR_FRAME_EMPTY := Color(0.32, 0.24, 0.16, 1.0)

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	close_btn.pressed.connect(_on_close_pressed)

	_inventory_manager = get_node_or_null("/root/InventoryManager")
	_game_manager = get_node_or_null("/root/GameManager")

	# Conectar señal de equipamiento para auto-refresh
	if _inventory_manager and _inventory_manager.has_signal("equipment_changed"):
		_inventory_manager.equipment_changed.connect(_on_equipment_changed)

	# Mapear slots de equipo
	_map_equipment_slots()
	_connect_equipment_slot_clicks()
	_create_puppet()

func _map_equipment_slots() -> void:
	_equipment_slots = {
		"head": wow_layout.get_node_or_null("LeftColumn/HelmetSlot"),
		"body": wow_layout.get_node_or_null("LeftColumn/ArmorSlot"),
		"main_hand": wow_layout.get_node_or_null("RightColumn/WeaponSlot"),
		"off_hand": wow_layout.get_node_or_null("RightColumn/ShieldSlot"),
		"feet": wow_layout.get_node_or_null("RightColumn/BootsSlot"),
	}

func _connect_equipment_slot_clicks() -> void:
	## Conectar click en cada slot equipado para desequipar
	for slot_type in _equipment_slots:
		var slot_node = _equipment_slots[slot_type]
		if slot_node == null:
			continue
		# Captura por valor
		var _slot_type = slot_type
		slot_node.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_equipment_slot_clicked(_slot_type)
		)
		slot_node.mouse_filter = Control.MOUSE_FILTER_STOP

## Crea el héroe de muestra dentro del hueco central (mismo dibujo que en la mazmorra).
func _create_puppet() -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(320, 520)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_center.add_child(holder)
	_puppet = HERO_SCENE.instantiate()
	# Que no lo confundan con el héroe real (DebugPanel busca el grupo "hero")
	_puppet.remove_from_group("hero")
	_puppet.set("show_hud", false)
	_puppet.position = Vector2(160, 440)
	_puppet.scale = Vector2(8, 8)  # pixel art a escala entera (fase 2: mini-lienzo propio)
	_puppet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(_puppet)
	_puppet.look_target = _puppet.position + Vector2(300, -80)
	_puppet.process_mode = Node.PROCESS_MODE_DISABLED  # solo se anima con el panel abierto
	# Peana
	var pedestal := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.14, 0.1, 1)
	style.border_color = Color(0.55, 0.41, 0.24, 1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(40)
	pedestal.add_theme_stylebox_override("panel", style)
	pedestal.size = Vector2(250, 44)
	pedestal.position = Vector2(35, 430)
	pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedestal.show_behind_parent = false
	holder.add_child(pedestal)
	holder.move_child(pedestal, 0)

func _gui_input(event: InputEvent) -> void:
	# Cerrar al hacer click en el fondo oscuro
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel_container = get_node_or_null("PanelContainer")
		if panel_container:
			var local_pos = panel_container.get_local_mouse_position()
			var panel_rect = Rect2(Vector2.ZERO, panel_container.size)
			if not panel_rect.has_point(local_pos):
				close()
				accept_event()

func open() -> void:
	visible = true
	_refresh_all()
	# Aparición del panel
	var panel: Control = $PanelContainer
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	if _puppet:
		_puppet.process_mode = Node.PROCESS_MODE_INHERIT
		_puppet.respawn(_puppet.position)

func close() -> void:
	visible = false
	if _puppet:
		_puppet.process_mode = Node.PROCESS_MODE_DISABLED
	emit_signal("panel_closed")

func _on_equipment_changed(_stats: Dictionary) -> void:
	## Auto-refresh cuando cambia el equipamiento (señal de InventoryManager)
	if visible:
		_refresh_all()

# ═══════════════════════════════════════════════════════════════════
#  REFRESH
# ═══════════════════════════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_equipment()
	_refresh_inventory()
	_refresh_stats()
	if _puppet and _puppet.has_method("refresh_gear"):
		_puppet.refresh_gear()

func _refresh_equipment() -> void:
	if not _inventory_manager:
		return

	var slot_icon_names := {
		"head": "HelmetIcon",
		"main_hand": "WeaponIcon",
		"off_hand": "ShieldIcon",
		"body": "ArmorIcon",
		"feet": "BootsIcon"
	}
	var slot_label_names := {
		"head": "HelmetLabel",
		"main_hand": "WeaponLabel",
		"off_hand": "ShieldLabel",
		"body": "ArmorLabel",
		"feet": "BootsLabel"
	}

	for slot_type in EQUIPMENT_SLOT_TYPES:
		var slot_node = _equipment_slots.get(slot_type)
		if slot_node == null:
			continue

		var icon_rect = slot_node.get_node_or_null(slot_icon_names.get(slot_type, ""))
		var label: Label = slot_node.get_node_or_null(slot_label_names.get(slot_type, ""))
		var equipped_item: CraftedItem = _inventory_manager.get_equipped_item(slot_type)
		if icon_rect == null:
			continue
		var frame := _ensure_slot_frame(icon_rect)
		var tex_rect := _ensure_slot_icon(icon_rect)
		if equipped_item != null:
			tex_rect.texture = equipped_item.get_icon()
			tex_rect.modulate = Color.WHITE
			_set_frame_color(frame, equipped_item.get_quality_color(), 4)
			slot_node.tooltip_text = equipped_item.get_display_name()
			if label:
				label.text = "%d%% %s" % [equipped_item.get_quality_percent(), TIER_NAMES.get(equipped_item.get_quality_tier(), "")]
				label.add_theme_color_override("font_color", equipped_item.get_quality_color())
		else:
			tex_rect.texture = null
			_set_frame_color(frame, COLOR_FRAME_EMPTY, 3)
			slot_node.tooltip_text = SLOT_NAMES.get(slot_type, slot_type.capitalize())
			if label:
				label.text = SLOT_NAMES.get(slot_type, slot_type.capitalize())
				label.add_theme_color_override("font_color", Color(0.6, 0.52, 0.42))
		if icon_rect is ColorRect:
			icon_rect.color = COLOR_SLOT_EMPTY

func _ensure_slot_frame(icon_rect: Control) -> Panel:
	var frame: Panel = icon_rect.get_node_or_null("Frame")
	if frame == null:
		frame = Panel.new()
		frame.name = "Frame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.add_child(frame)
	return frame

func _ensure_slot_icon(icon_rect: Control) -> TextureRect:
	var tex: TextureRect = icon_rect.get_node_or_null("ItemIcon")
	if tex == null:
		tex = TextureRect.new()
		tex.name = "ItemIcon"
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.offset_left = 10
		tex.offset_top = 10
		tex.offset_right = -10
		tex.offset_bottom = -10
		icon_rect.add_child(tex)
	return tex

func _set_frame_color(frame: Panel, color: Color, width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", style)

func _refresh_inventory() -> void:
	# Limpiar grid
	for child in inventory_grid.get_children():
		child.queue_free()

	if not _inventory_manager:
		return

	# Solo mostrar items NO equipados (los mejores primero)
	var unequipped: Array[CraftedItem] = _inventory_manager.get_unequipped_items()
	unequipped.sort_custom(func(a: CraftedItem, b: CraftedItem): return _item_score(a) > _item_score(b))

	for item in unequipped:
		var item_slot = _create_item_slot(item)
		inventory_grid.add_child(item_slot)

func _refresh_stats() -> void:
	# Obtener héroe via GameManager.get_hero()
	var hero: Node = null
	if _game_manager and _game_manager.has_method("get_hero"):
		hero = _game_manager.get_hero()

	if hero == null:
		# Fallback: sin héroe registrado, mostrar stats de equipamiento
		_refresh_stats_from_equipment()
		return

	if hp_label:
		hp_label.text = "Vida %d" % hero.max_hp
	if dmg_label:
		dmg_label.text = "Daño %.0f" % hero.dmg
	if armor_label:
		var mitigation: float = hero.armor_mitigation() if hero.has_method("armor_mitigation") else 0.0
		armor_label.text = "Armadura %d (-%d%%)" % [hero.armor, int(round(mitigation * 100.0))]
	if crit_label:
		crit_label.text = "Crítico %.0f%%" % (hero.crit_p * 100.0)

func _refresh_stats_from_equipment() -> void:
	## Fallback: calcular stats solo de equipamiento sin referencia al héroe
	if not _inventory_manager:
		return
	var stats: Dictionary = _inventory_manager.calculate_total_stats()
	if hp_label:
		hp_label.text = "Vida +%d" % int(stats.get("hp", 0))
	if dmg_label:
		dmg_label.text = "Daño +%d" % int(stats.get("damage", 0))
	if armor_label:
		armor_label.text = "Armadura +%d" % int(stats.get("armor", 0))
	if crit_label:
		crit_label.text = "Crítico +%.0f%%" % (float(stats.get("crit", 0.0)) * 100.0)

# ═══════════════════════════════════════════════════════════════════
#  ITEM SLOTS (inventario)
# ═══════════════════════════════════════════════════════════════════

## Puntuación simple para ordenar y marcar mejoras: rareza del plano y luego calidad.
func _item_score(item: CraftedItem) -> float:
	var rarity := "basic"
	if item.item_resource:
		rarity = String(item.item_resource.rarity)
	return float(RARITY_RANK.get(rarity, 0)) * 100.0 + item.quality * 100.0

func _is_upgrade(item: CraftedItem) -> bool:
	if _inventory_manager == null:
		return false
	var current: CraftedItem = _inventory_manager.get_equipped_item(item.get_equipment_slot())
	return current == null or _item_score(item) > _item_score(current)

## Texto corto con las stats más relevantes del objeto.
func _stat_line(item: CraftedItem) -> String:
	var parts: Array[String] = []
	var st: Dictionary = item.calculated_stats
	if int(st.get("damage", 0)) > 0:
		parts.append("+%d Daño" % int(st.damage))
	if int(st.get("hp", 0)) > 0:
		parts.append("+%d Vida" % int(st.hp))
	if int(st.get("armor", 0)) > 0:
		parts.append("+%d Arm" % int(st.armor))
	if float(st.get("crit", 0.0)) > 0.005:
		parts.append("+%d%% Crít" % int(round(float(st.crit) * 100.0)))
	if float(st.get("aps", 0.0)) > 0.01:
		parts.append("+%.1f Vel" % float(st.aps))
	return "  ".join(parts.slice(0, 2))

func _create_item_slot(item: CraftedItem) -> Control:
	var tier_color := item.get_quality_color()
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(218, 250)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.105, 0.085, 1.0)
	style.border_color = tier_color
	style.set_border_width_all(3)
	style.border_width_bottom = 6
	style.set_corner_radius_all(14)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	slot.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vbox)

	var icon := TextureRect.new()
	icon.texture = item.get_icon()
	icon.custom_minimum_size = Vector2(0, 104)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.text = item.item_resource.display_name if item.item_resource else "???"
	vbox.add_child(name_label)

	var quality_label := Label.new()
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_font_size_override("font_size", 20)
	quality_label.add_theme_color_override("font_color", tier_color)
	quality_label.add_theme_constant_override("outline_size", 4)
	quality_label.text = "%d%% · %s" % [item.get_quality_percent(), TIER_NAMES.get(item.get_quality_tier(), "")]
	vbox.add_child(quality_label)

	var stat_label := Label.new()
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.add_theme_font_size_override("font_size", 18)
	stat_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
	stat_label.text = _stat_line(item)
	vbox.add_child(stat_label)

	if _is_upgrade(item):
		var up := Label.new()
		up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		up.add_theme_font_size_override("font_size", 20)
		up.add_theme_color_override("font_color", Color(0.45, 0.95, 0.5))
		up.add_theme_constant_override("outline_size", 4)
		up.text = "▲ Mejora"
		vbox.add_child(up)

	# Toque para equipar
	slot.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_item_clicked(item)
	)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	return slot

# ═══════════════════════════════════════════════════════════════════
#  ACCIONES
# ═══════════════════════════════════════════════════════════════════

func _on_item_clicked(item: CraftedItem) -> void:
	if not _inventory_manager:
		return

	var success = _inventory_manager.equip_item(item)
	if success:
		emit_signal("item_equipped", item.get_equipment_slot(), item)
		DebugManager.log_msg(&"ui", "EquipmentPanel: Equipped %s" % item.get_display_name())
		_equip_feedback(item.get_equipment_slot())
	else:
		DebugManager.log_msg(&"ui", "EquipmentPanel: Failed to equip %s" % item.get_display_name())

## Brillo en el hueco equipado, el héroe de muestra se "re-materializa" y suena un clinc metálico.
func _equip_feedback(slot_type: String) -> void:
	var slot_node: Control = _equipment_slots.get(slot_type)
	if slot_node:
		slot_node.pivot_offset = slot_node.size * 0.5
		var tw := create_tween()
		tw.tween_property(slot_node, "scale", Vector2(1.18, 1.18), 0.08)
		tw.tween_property(slot_node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slot_node.modulate = Color(1.8, 1.7, 1.3)
		create_tween().tween_property(slot_node, "modulate", Color.WHITE, 0.4)
	if _puppet:
		_puppet.set("_materialize", 0.55)
	Sfx.play(&"equip_clink")

func _on_equipment_slot_clicked(slot_type: String) -> void:
	## Desequipa el item del slot al hacer click
	if not _inventory_manager:
		return

	var equipped_item: CraftedItem = _inventory_manager.get_equipped_item(slot_type)
	if equipped_item == null:
		return  # Slot vacío, nada que hacer

	var success = _inventory_manager.unequip_item(slot_type)
	if success:
		DebugManager.log_msg(&"ui", "EquipmentPanel: Unequipped from %s" % slot_type)

func _on_close_pressed() -> void:
	close()
