# res://scripts/ui/EquipmentPanel.gd
extends ColorRect

## Panel modal para visualizar y gestionar el equipamiento del héroe
## Muestra: 5 slots de equipo + inventario (solo items no equipados)
## Equipar = click en inventario. Desequipar = click en slot equipado.

signal item_equipped(slot_type: StringName, item)
signal panel_closed

# Referencias a nodos
@onready var close_btn: Button = $PanelContainer/MainVBox/TitleBar/CloseBtn
@onready var wow_layout: HBoxContainer = $PanelContainer/MainVBox/ContentHBox/EquipmentBG/WoWStyleLayout
@onready var inventory_grid: GridContainer = $PanelContainer/MainVBox/ContentHBox/InventoryBG/InventorySection/InventoryScroll/InventoryGrid

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

const EQUIPMENT_SLOT_TYPES := ["head", "main_hand", "off_hand", "body", "feet"]

# Colores de estado
const COLOR_SLOT_EMPTY := Color(0.25, 0.25, 0.3, 1.0)
const COLOR_SLOT_HOVER := Color(0.4, 0.4, 0.5, 1.0)

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

func close() -> void:
	visible = false
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
	
	for slot_type in EQUIPMENT_SLOT_TYPES:
		var slot_node = _equipment_slots.get(slot_type)
		if slot_node == null:
			continue
		
		var icon_name = slot_icon_names.get(slot_type, "")
		var icon_rect = slot_node.get_node_or_null(icon_name)
		var equipped_item: CraftedItem = _inventory_manager.get_equipped_item(slot_type)
		
		if icon_rect and icon_rect is ColorRect:
			if equipped_item != null:
				icon_rect.color = equipped_item.get_quality_color()
				# Tooltip: nombre del item en el slot
				slot_node.tooltip_text = equipped_item.get_display_name()
			else:
				icon_rect.color = COLOR_SLOT_EMPTY
				slot_node.tooltip_text = slot_type.capitalize()

func _refresh_inventory() -> void:
	# Limpiar grid
	for child in inventory_grid.get_children():
		child.queue_free()
	
	if not _inventory_manager:
		return
	
	# Solo mostrar items NO equipados
	var unequipped: Array[CraftedItem] = _inventory_manager.get_unequipped_items()
	
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
		hp_label.text = "HP: %d/%d" % [hero.hp, hero.max_hp]
	if dmg_label:
		dmg_label.text = "DMG: %.0f" % hero.dmg
	if armor_label:
		armor_label.text = "ARMOR: %d" % hero.armor
	if crit_label:
		crit_label.text = "CRIT: %.1f%%" % (hero.crit_p * 100.0)

func _refresh_stats_from_equipment() -> void:
	## Fallback: calcular stats solo de equipamiento sin referencia al héroe
	if not _inventory_manager:
		return
	var stats: Dictionary = _inventory_manager.calculate_total_stats()
	if hp_label:
		hp_label.text = "HP: +%d" % int(stats.get("hp", 0))
	if dmg_label:
		dmg_label.text = "DMG: +%d" % int(stats.get("damage", 0))
	if armor_label:
		armor_label.text = "ARMOR: +%d" % int(stats.get("armor", 0))
	if crit_label:
		crit_label.text = "CRIT: +%.1f%%" % (float(stats.get("crit", 0.0)) * 100.0)

# ═══════════════════════════════════════════════════════════════════
#  ITEM SLOTS (inventario)
# ═══════════════════════════════════════════════════════════════════

func _create_item_slot(item: CraftedItem) -> Control:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(90, 90)
	
	# Borde de color según calidad
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 1.0)
	style.border_color = item.get_quality_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	slot.add_theme_stylebox_override("panel", style)
	
	# VBox para nombre + calidad
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vbox)
	
	# Nombre del item (compacto)
	var name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if item.item_resource:
		name_label.text = item.item_resource.display_name
	else:
		name_label.text = "???"
	vbox.add_child(name_label)
	
	# Calidad label
	var quality_label = Label.new()
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_font_size_override("font_size", 10)
	quality_label.add_theme_color_override("font_color", item.get_quality_color())
	quality_label.text = "%d%% %s" % [item.get_quality_percent(), item.get_quality_label()]
	vbox.add_child(quality_label)
	
	# Slot type (indicador)
	var slot_label = Label.new()
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.add_theme_font_size_override("font_size", 9)
	slot_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	slot_label.text = item.get_equipment_slot().capitalize()
	vbox.add_child(slot_label)
	
	# Click para equipar
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
	else:
		DebugManager.log_msg(&"ui", "EquipmentPanel: Failed to equip %s" % item.get_display_name())

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
