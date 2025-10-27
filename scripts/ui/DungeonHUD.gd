extends Control

const QualityUtils = preload("res://scripts/core/QualityHelper.gd")

# Referencias a elementos UI
@onready var run_label: Label = $MainPanel/MarginContainer/VBoxContainer/TopSection/ProgressSection/RunLabel
@onready var death_label: Label = $MainPanel/MarginContainer/VBoxContainer/TopSection/ProgressSection/DeathLabel
@onready var state_label: Label = $MainPanel/MarginContainer/VBoxContainer/TopSection/ProgressSection/StateLabel

@onready var hp_bar: ProgressBar = $MainPanel/MarginContainer/VBoxContainer/TopSection/StatsSection/HPBar
@onready var hp_label: Label = $MainPanel/MarginContainer/VBoxContainer/TopSection/StatsSection/HPBar/HPLabel
@onready var dmg_label: Label = $MainPanel/MarginContainer/VBoxContainer/TopSection/StatsSection/StatsGrid/DMGLabel
@onready var aps_label: Label = $MainPanel/MarginContainer/VBoxContainer/TopSection/StatsSection/StatsGrid/APSLabel
@onready var crit_label: Label = $MainPanel/MarginContainer/VBoxContainer/TopSection/StatsSection/StatsGrid/CRITLabel
@onready var armor_label: Label = $MainPanel/MarginContainer/VBoxContainer/TopSection/StatsSection/StatsGrid/ARMORLabel

@onready var helmet_name: Label = $MainPanel/MarginContainer/VBoxContainer/EquipHBoxContainer/EquipmentSection/EquipmentGrid/HelmetSlot/HelmetName
@onready var weapon_name: Label = $MainPanel/MarginContainer/VBoxContainer/EquipHBoxContainer/EquipmentSection/EquipmentGrid/WeaponSlot/WeaponName
@onready var shield_name: Label = $MainPanel/MarginContainer/VBoxContainer/EquipHBoxContainer/EquipmentSection/EquipmentGrid/ShieldSlot/ShieldName
@onready var boots_name: Label = $MainPanel/MarginContainer/VBoxContainer/EquipHBoxContainer/EquipmentSection/EquipmentGrid/BootsSlot/BootsName
@onready var armor_name: Label = $MainPanel/MarginContainer/VBoxContainer/EquipHBoxContainer/EquipmentSection/EquipmentGrid/ArmorSlot/ArmorName

@onready var inventory_grid: GridContainer = $MainPanel/MarginContainer/VBoxContainer/EquipHBoxContainer/InventorySection/InventoryScroll/InventoryGrid
@onready var back_button: TextureButton = $MainPanel/MarginContainer/VBoxContainer/BackButton

var hero_ref: Node = null
var game_manager: Node = null
var corridor: Node = null
var inventory_manager: Node = null

func _ready() -> void:
	# Buscar referencias
	await get_tree().process_frame
	_find_references()
	
	# Conectar botón de volver
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	# Conectar señales de GameManager
	if game_manager:
		if game_manager.has_signal("enemy_level_changed"):
			game_manager.connect("enemy_level_changed", Callable(self, "_on_enemy_level_changed"))
		if game_manager.has_signal("hero_died"):
			game_manager.connect("hero_died", Callable(self, "_on_hero_died"))
	
	# Conectar señales de InventoryManager
	if inventory_manager:
		if inventory_manager.has_signal("crafted_items_changed"):
			inventory_manager.connect("crafted_items_changed", Callable(self, "_on_items_changed"))
	
	# Update inicial
	_update_inventory()
	_update_equipment()
	
	# Configurar drop zones en slots de equipamiento
	_setup_equipment_drop_zones()

func _process(_delta: float) -> void:
	# Buscar héroe si no lo tenemos
	if not hero_ref or not is_instance_valid(hero_ref):
		_find_hero_if_needed()
	
	# Actualizar stats cada frame (solo si tenemos héroe)
	if hero_ref and is_instance_valid(hero_ref):
		_update_stats_silent()  # Versión sin prints para no saturar
	
	_update_run_info()

func _find_hero_if_needed() -> void:
	"""Busca el héroe si no está asignado"""
	if hero_ref and is_instance_valid(hero_ref):
		return
	
	# Usar grupo "hero" para búsqueda más robusta
	var heroes = get_tree().get_nodes_in_group("hero")
	if heroes.size() > 0:
		hero_ref = heroes[0]
		print("DungeonHUD: ✅ Héroe encontrado via grupo 'hero'")
		_update_stats()  # Primera actualización con debug
		return
	
	# Fallback: búsqueda por path
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var main = tree.root.get_node_or_null("Main")
	if main:
		var dungeon_area = main.get_node_or_null("DungeonArea")
		if dungeon_area:
			var corridor_node = dungeon_area.get_node_or_null("Corridor")
			if corridor_node:
				hero_ref = corridor_node.get_node_or_null("Hero")
				if hero_ref:
					print("DungeonHUD: ✅ Héroe encontrado via path")
					_update_stats()  # Primera actualización con debug

func _update_stats_silent() -> void:
	"""Versión de _update_stats sin prints (para _process)"""
	if not hero_ref or not is_instance_valid(hero_ref):
		return
	
	# HP actual
	if hp_bar:
		hp_bar.max_value = hero_ref.max_hp
		hp_bar.value = hero_ref.hp
	
	if hp_label:
		hp_label.text = "%d/%d" % [hero_ref.hp, hero_ref.max_hp]
	
	# Stats de combate
	if dmg_label:
		dmg_label.text = "DMG: %.1f" % hero_ref.dmg
	
	if aps_label:
		aps_label.text = "APS: %.2f" % hero_ref.aps
	
	if crit_label:
		crit_label.text = "CRIT: %.1f%%" % (hero_ref.crit_p * 100.0)
	
	if armor_label:
		armor_label.text = "ARMOR: %d" % hero_ref.armor
	
	# Estado visual del héroe basado en animación actual
	if state_label and "current_anim_state" in hero_ref:
		var state_text = ""
		var anim_state = hero_ref.current_anim_state
		match anim_state:
			0:  # IDLE
				state_text = "⏸️ Parado"
				state_label.modulate = Color.GRAY
			1:  # WALK
				state_text = "🏃 Avanzando"
				state_label.modulate = Color.WHITE
			2:  # ATTACK
				state_text = "⚔️ Atacando"
				state_label.modulate = Color.ORANGE
			3:  # DEATH
				state_text = "💀 Muriendo"
				state_label.modulate = Color.RED
			_:
				state_text = "❓ Estado: %d" % anim_state
				state_label.modulate = Color.YELLOW
		state_label.text = state_text

func _find_references() -> void:
	# Buscar GameManager
	if has_node("/root/GameManager"):
		game_manager = get_node("/root/GameManager")
	
	# Buscar InventoryManager
	if has_node("/root/InventoryManager"):
		inventory_manager = get_node("/root/InventoryManager")
	
	# Buscar Main y Corridor
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var main = tree.root.get_node_or_null("Main")
	if main:
		var dungeon_area = main.get_node_or_null("DungeonArea")
		if dungeon_area:
			corridor = dungeon_area.get_node_or_null("Corridor")
			if corridor:
				hero_ref = corridor.get_node_or_null("Hero")
				print("DungeonHUD: Found hero reference")

func _update_stats() -> void:
	"""Actualiza las estadísticas del héroe mostradas en el HUD"""
	if not hero_ref or not is_instance_valid(hero_ref):
		print("DungeonHUD: _update_stats() - Hero no válido")
		return
	
	print("DungeonHUD: Actualizando stats del héroe...")
	print("  Hero STR: %d (base %d)" % [hero_ref.STR, hero_ref.BASE_STR])
	print("  Hero DMG: %.1f" % hero_ref.dmg)
	print("  Hero HP: %d/%d" % [hero_ref.hp, hero_ref.max_hp])
	
	# HP actual / máximo
	if hp_label:
		hp_label.text = "HP: %d / %d" % [hero_ref.hp, hero_ref.max_hp]
		print("  ✓ HP label actualizado")
	else:
		print("  ❌ hp_label no encontrado")
	
	# DMG
	if dmg_label:
		dmg_label.text = "DMG: %.1f" % hero_ref.dmg
		print("  ✓ DMG: %.1f" % hero_ref.dmg)
	else:
		print("  ❌ dmg_label no encontrado")
	
	# APS
	if aps_label:
		aps_label.text = "APS: %.2f" % hero_ref.aps
		print("  ✓ APS: %.2f" % hero_ref.aps)
	else:
		print("  ❌ aps_label no encontrado")
	
	# CRIT
	if crit_label:
		crit_label.text = "CRIT: %.1f%%" % (hero_ref.crit_p * 100.0)
		print("  ✓ CRIT: %.1f%%" % (hero_ref.crit_p * 100.0))
	else:
		print("  ❌ crit_label no encontrado")
	
	# ARMOR
	if armor_label:
		var armor_value = hero_ref.get("armor") if hero_ref.has_method("get") else 0
		armor_label.text = "ARMOR: %d" % armor_value
		print("  ✓ ARMOR: %d" % armor_value)
	else:
		print("  ❌ armor_label no encontrado")


func _update_run_info() -> void:
	if not game_manager:
		return
	
	# Current room
	if run_label and "current_enemy_level" in game_manager:
		var level = game_manager.current_enemy_level
		run_label.text = "Room: %d / 8" % level
	
	# Deaths
	if death_label and "death_count" in game_manager:
		death_label.text = "Deaths: %d" % game_manager.death_count
	
	# State
	if state_label and corridor:
		var state_text = "Unknown"
		if "state" in corridor:
			match corridor.state:
				0: state_text = "Corriendo"
				1: state_text = "Combate"
				2: state_text = "Muerto"
				3: state_text = "Completo"
		state_label.text = "Estado: " + state_text

func _update_equipment() -> void:
	"""Actualiza los nombres y ICONOS de items equipados"""
	if not inventory_manager or not inventory_manager.has_method("get_equipped_item"):
		print("DungeonHUD: _update_equipment() - InventoryManager no disponible")
		return
	
	var equipment_grid_node = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/EquipHBoxContainer/EquipmentSection/EquipmentGrid")
	if not equipment_grid_node:
		print("DungeonHUD: _update_equipment() - EquipmentGrid no encontrado")
		return
	
	print("DungeonHUD: Actualizando equipment UI...")
	
	# Mapeo de slots UI a slots de inventario
	var slot_configs = {
		"head": {"label": helmet_name, "icon_path": "HelmetSlot/HelmetIcon"},
		"main_hand": {"label": weapon_name, "icon_path": "WeaponSlot/WeaponIcon"},
		"off_hand": {"label": shield_name, "icon_path": "ShieldSlot/ShieldIcon"},
		"feet": {"label": boots_name, "icon_path": "BootsSlot/BootsIcon"},
		"body": {"label": armor_name, "icon_path": "ArmorSlot/ArmorIcon"}
	}
	
	for slot_id in slot_configs:
		var config = slot_configs[slot_id]
		var label = config.label
		var icon_node = equipment_grid_node.get_node_or_null(config.icon_path)
		
		if not label:
			continue
		
		var item = inventory_manager.get_equipped_item(slot_id)
		if item:
			# Actualizar label con nombre y color
			label.text = item.item_resource.display_name if item.item_resource else "???"
			label.modulate = item.get_quality_color()
			print("  ✓ Slot '%s': %s (%d%%)" % [slot_id, label.text, QualityUtils.get_quality_percent(item.quality)])
			
			# Actualizar icono visual si existe
			if icon_node and icon_node is EquipmentDropSlot:
				_update_equipment_icon(icon_node, item)
		else:
			# Sin item equipado
			label.text = "---"
			label.modulate = Color.GRAY
			print("  - Slot '%s': vacío" % slot_id)
			
			# Limpiar icono
			if icon_node and icon_node is EquipmentDropSlot:
				_clear_equipment_icon(icon_node)

func _update_equipment_icon(slot: EquipmentDropSlot, item: CraftedItem) -> void:
	"""Actualiza el icono visual de un slot de equipamiento"""
	print("    → Actualizando icono en slot con item: %s" % item.get_display_name())
	
	# Buscar o crear TextureRect hijo para mostrar el icono
	var icon_rect: TextureRect = null
	for child in slot.get_children():
		if child is TextureRect:
			icon_rect = child
			break
	
	if not icon_rect:
		# Crear TextureRect si no existe
		icon_rect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# CRÍTICO: Usar anchors para que ocupe todo el slot con padding
		icon_rect.anchor_left = 0.0
		icon_rect.anchor_top = 0.0
		icon_rect.anchor_right = 1.0
		icon_rect.anchor_bottom = 1.0
		icon_rect.offset_left = 8
		icon_rect.offset_top = 8
		icon_rect.offset_right = -8
		icon_rect.offset_bottom = -8
		slot.add_child(icon_rect)
		print("      ✓ TextureRect creado con anchors full + padding 8px")
	
	# Configurar textura del item
	icon_rect.texture = item.get_icon()
	icon_rect.modulate = Color.WHITE
	icon_rect.visible = true
	print("      ✓ Icono configurado: %s" % icon_rect.texture)

func _clear_equipment_icon(slot: EquipmentDropSlot) -> void:
	"""Limpia el icono visual de un slot de equipamiento"""
	for child in slot.get_children():
		if child is TextureRect:
			child.visible = false
			child.texture = null
			print("    → Icono limpiado del slot")
			break

func _update_inventory() -> void:
	"""Muestra items crafteados NO EQUIPADOS con indicador de calidad"""
	# Limpiar grid actual
	for child in inventory_grid.get_children():
		child.queue_free()
	
	if not inventory_manager or not inventory_manager.has_method("get_crafted_items"):
		# Fallback: slots vacíos
		for i in range(12):
			var slot = ColorRect.new()
			slot.custom_minimum_size = Vector2(80, 80)
			slot.color = Color(0.2, 0.2, 0.25, 0.8)
			inventory_grid.add_child(slot)
		return
	
	var all_items = inventory_manager.get_crafted_items()
	
	# CRÍTICO: Filtrar items ya equipados
	var unequipped_items = []
	for item in all_items:
		var is_equipped = false
		# Verificar si el item está equipado en algún slot
		for slot_id in ["head", "main_hand", "off_hand", "feet", "body"]:
			var equipped_item = inventory_manager.get_equipped_item(slot_id)
			if equipped_item == item:
				is_equipped = true
				break
		
		if not is_equipped:
			unequipped_items.append(item)
	
	print("DungeonHUD: Inventario - %d items totales, %d no equipados" % [all_items.size(), unequipped_items.size()])
	
	if unequipped_items.is_empty():
		# Todos equipados - mostrar mensaje
		var empty_label = Label.new()
		empty_label.text = "Craft items to equip"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.modulate = Color.GRAY
		empty_label.custom_minimum_size = Vector2(480, 80)
		inventory_grid.add_child(empty_label)
		return
	
	# Mostrar solo items NO equipados
	for item in unequipped_items:
		var slot_container = _create_item_slot(item)
		inventory_grid.add_child(slot_container)

func _create_item_slot(item: CraftedItem) -> Control:
	"""Crea un slot visual CUADRADO para un item con color de calidad y drag & drop"""
	var container = DraggableItemSlot.new()
	container.custom_minimum_size = Vector2(100, 100)
	container.item = item
	
	# Panel con outline de calidad usando helper
	var style_box = QualityUtils.create_quality_border_style(item.quality)
	container.add_theme_stylebox_override("panel", style_box)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Para que el drag funcione
	container.add_child(vbox)
	
	# Icono del item CENTRADO
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(80, 80)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = item.get_icon()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_rect)
	
	# Label de calidad con color
	var quality_label = Label.new()
	quality_label.text = "%d%%" % QualityUtils.get_quality_percent(item.quality)
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_font_size_override("font_size", 14)
	quality_label.modulate = QualityUtils.get_quality_color(item.quality)
	quality_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(quality_label)
	
	return container

## Prepara los slots de equipamiento para recibir drops
func _setup_equipment_drop_zones() -> void:
	"""Hace los slots de equipamiento receptores de drag & drop"""
	var equipment_grid_node = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/EquipHBoxContainer/EquipmentSection/EquipmentGrid")
	if not equipment_grid_node:
		push_warning("DungeonHUD: EquipmentGrid no encontrado")
		return
	
	# Mapeo de slots a tipo de item permitido
	var slot_configs = {
		"HelmetSlot/HelmetIcon": {"type": "head", "label": helmet_name},
		"WeaponSlot/WeaponIcon": {"type": "main_hand", "label": weapon_name},
		"ShieldSlot/ShieldIcon": {"type": "off_hand", "label": shield_name},
		"BootsSlot/BootsIcon": {"type": "feet", "label": boots_name},
		"ArmorSlot/ArmorIcon": {"type": "body", "label": armor_name}
	}
	
	print("DungeonHUD: Configurando %d equipment drop zones..." % slot_configs.size())
	
	for slot_path in slot_configs.keys():
		var icon_node = equipment_grid_node.get_node_or_null(slot_path)
		if icon_node and icon_node is ColorRect:
			var config = slot_configs[slot_path]
			
			# Convertir a EquipmentDropSlot behavior
			icon_node.set_script(preload("res://scripts/ui/EquipmentDropSlot.gd"))
			icon_node.slot_type = config.type
			
			# Desconectar señales existentes si ya están conectadas (evitar duplicados)
			if icon_node.is_connected("item_equipped", Callable(self, "_on_item_equipped_in_slot")):
				icon_node.disconnect("item_equipped", Callable(self, "_on_item_equipped_in_slot"))
			if icon_node.is_connected("item_rejected", Callable(self, "_on_item_rejected_in_slot")):
				icon_node.disconnect("item_rejected", Callable(self, "_on_item_rejected_in_slot"))
			
			# Conectar señales de equip y rechazo
			icon_node.item_equipped.connect(_on_item_equipped_in_slot)
			icon_node.item_rejected.connect(_on_item_rejected_in_slot)
			
			print("  ✓ Slot '%s' configurado como tipo '%s'" % [slot_path, config.type])
	
	print("DungeonHUD: Equipment drop zones configurados OK")

## Handler cuando un item es equipado via drag & drop
func _on_item_equipped_in_slot(item: CraftedItem) -> void:
	"""Actualiza UI cuando item es equipado"""
	print("DungeonHUD: ✨ Item equipado via drag & drop: %s" % item.get_display_name())
	
	# CRÍTICO: Equipar el item en InventoryManager
	if inventory_manager and inventory_manager.has_method("equip_item"):
		var success = inventory_manager.equip_item(item)
		if success:
			print("DungeonHUD: ✅ Item equipado exitosamente en InventoryManager")
			
			# CRÍTICO: Forzar recálculo de stats del héroe
			if hero_ref and is_instance_valid(hero_ref) and hero_ref.has_method("reset_stats"):
				hero_ref.reset_stats()
				print("DungeonHUD: 🔄 Stats del héroe recalculados")
			
			_update_equipment()
			_update_inventory()  # Refrescar para mostrar estado equipado
			_update_stats()
		else:
			push_warning("DungeonHUD: ❌ Failed to equip item in InventoryManager")
	else:
		push_warning("DungeonHUD: ❌ InventoryManager no disponible")

## Handler cuando un item es rechazado (slot incompatible)
func _on_item_rejected_in_slot(item: CraftedItem) -> void:
	"""El item fue rechazado - buscar su slot en inventario y animarlo"""
	print("DungeonHUD: ❌ Item rechazado (slot incompatible): %s" % item.get_display_name())
	
	# Buscar el slot del item en el grid de inventario
	var inv_grid = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/EquipHBoxContainer/InventorySection/InventoryScrollContainer/InventoryGrid")
	if not inv_grid:
		return
	
	# Recorrer slots para encontrar el que contiene este item
	for slot in inv_grid.get_children():
		if slot is DraggableItemSlot and slot.item == item:
			_animate_item_return(slot)
			break

## Anima el slot del item para indicar que volvió al inventario
func _animate_item_return(slot: Control) -> void:
	"""Shake suave del slot para indicar que el item no se pudo equipar"""
	var original_pos = slot.position
	var tween = create_tween()
	
	# Shake horizontal suave
	tween.tween_property(slot, "position:x", original_pos.x + 6, 0.05)
	tween.tween_property(slot, "position:x", original_pos.x - 6, 0.05)
	tween.tween_property(slot, "position:x", original_pos.x + 4, 0.05)
	tween.tween_property(slot, "position:x", original_pos.x - 4, 0.05)
	tween.tween_property(slot, "position:x", original_pos.x, 0.05)
	
	# Flash rojo suave en el borde
	tween.set_parallel(true)
	var original_modulate = slot.modulate
	tween.tween_property(slot, "modulate", Color(1.0, 0.6, 0.6, 1.0), 0.1)
	tween.tween_property(slot, "modulate", original_modulate, 0.2).set_delay(0.1)
func _on_item_slot_clicked(event: InputEvent, item: CraftedItem) -> void:
	"""Maneja click en un slot de item para equiparlo"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if inventory_manager and inventory_manager.has_method("equip_item"):
			var success = inventory_manager.equip_item(item)
			if success:
				print("DungeonHUD: Equipado item: %s" % item.get_display_name())
				_update_equipment()
				_update_stats()
			else:
				push_warning("DungeonHUD: No se pudo equipar item")

func _on_items_changed(_items_array: Array) -> void:
	"""Callback cuando cambia el inventario de items"""
	_update_inventory()
	_update_equipment()
	_update_stats()

func _on_back_button_pressed() -> void:
	# Cambiar a forja
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var main = tree.root.get_node_or_null("Main")
	if main and main.has_method("change_area"):
		main.change_area(&"forge")

func _on_enemy_level_changed(level: int) -> void:
	if run_label:
		run_label.text = "Room: %d / 8" % level

func _on_hero_died(_death_count: int) -> void:
	if state_label:
		state_label.text = "State: Dead"
