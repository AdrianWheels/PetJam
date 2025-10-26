extends Node
class_name InventoryManager

signal inventory_changed(current_inventory)
signal crafted_items_changed(items_array)

# Diccionario de materiales (StringName -> int)
var inventory: Dictionary = {}

# Array de items crafteados (Array[CraftedItem])
var crafted_items: Array[CraftedItem] = []

# Items equipados por slot (String -> CraftedItem)
var equipped_items: Dictionary = {}

func _ready() -> void:
	"""Inicializar inventario con materiales básicos para evitar softlocks"""
	# Dar materiales generosos al inicio para poder craftear los primeros pedidos gratis
	var starting_materials := {
		"wood": 40,
		"iron": 40,
		"leather": 40,
		"cloth": 40,
		"herb": 30,
		"fire": 20,
		"water": 20
	}
	
	for mat_id in starting_materials:
		add_item(StringName(mat_id), starting_materials[mat_id])
	
	print("InventoryManager: Inicializado con materiales de inicio")

func add_item(item_id: StringName, quantity: int) -> void:
		if quantity <= 0:
				return
		if item_id == StringName():
				return
		var key := item_id
		inventory[key] = inventory.get(key, 0) + quantity
		emit_signal("inventory_changed", inventory.duplicate())

func add_drops(drops: Array) -> void:
		for drop in drops:
				if drop == null or typeof(drop) != TYPE_DICTIONARY:
						continue
				var item_id: StringName = drop.get("item_id", StringName(""))
				var quantity: int = int(drop.get("quantity", 0))
				add_item(item_id, quantity)

func get_quantity(item_id: StringName) -> int:
		return inventory.get(item_id, 0)

func get_materials() -> Dictionary:
	return inventory.duplicate()

func has_materials(required_materials: Dictionary) -> bool:
	"""Verifica si el jugador tiene todos los materiales requeridos"""
	for mat_id in required_materials.keys():
		var required_qty: int = int(required_materials[mat_id])
		var current_qty: int = get_quantity(mat_id)
		if current_qty < required_qty:
			return false
	return true

func consume_materials(required_materials: Dictionary) -> bool:
	"""Consume materiales del inventario. Retorna true si tuvo éxito."""
	# Primero verificar que tenemos suficiente
	if not has_materials(required_materials):
		return false
	
	# Consumir
	for mat_id in required_materials.keys():
		var qty: int = int(required_materials[mat_id])
		var key: StringName = mat_id if mat_id is StringName else StringName(str(mat_id))
		inventory[key] = inventory.get(key, 0) - qty
		if inventory[key] <= 0:
			inventory.erase(key)
	
	emit_signal("inventory_changed", inventory.duplicate())
	return true

func clear() -> void:
	inventory.clear()
	crafted_items.clear()
	equipped_items.clear()
	emit_signal("inventory_changed", inventory.duplicate())
	emit_signal("crafted_items_changed", crafted_items)

# ═══════════════════════════════════════════════════════════════════
#  SISTEMA DE ITEMS CRAFTEADOS
# ═══════════════════════════════════════════════════════════════════

## Añade un item crafteado al inventario
func add_crafted_item(item: CraftedItem) -> void:
	if item == null:
		push_warning("InventoryManager: Intentando añadir item null")
		return
	
	crafted_items.append(item)
	emit_signal("crafted_items_changed", crafted_items)
	print("InventoryManager: Item crafteado añadido: %s (calidad: %d%%)" % [item.get_display_name(), item.get_quality_percent()])

## Retorna todos los items crafteados
func get_crafted_items() -> Array[CraftedItem]:
	return crafted_items

## Retorna items crafteados no equipados
func get_unequipped_items() -> Array[CraftedItem]:
	var result: Array[CraftedItem] = []
	for item in crafted_items:
		if not item.is_equipped:
			result.append(item)
	return result

## Retorna items equipados
func get_equipped_items() -> Array[CraftedItem]:
	var result: Array[CraftedItem] = []
	for item in crafted_items:
		if item.is_equipped:
			result.append(item)
	return result

## Equipa un item en el slot correspondiente
func equip_item(item: CraftedItem) -> bool:
	if item == null or item not in crafted_items:
		return false
	
	var slot = item.get_equipment_slot()
	if slot == "":
		push_warning("InventoryManager: Item sin slot de equipamiento")
		return false
	
	# Desequipar item previo si existe
	if slot in equipped_items:
		var prev_item = equipped_items[slot]
		prev_item.is_equipped = false
	
	# Equipar nuevo item
	equipped_items[slot] = item
	item.is_equipped = true
	
	emit_signal("crafted_items_changed", crafted_items)
	print("InventoryManager: Equipado %s en slot %s" % [item.get_display_name(), slot])
	return true

## Desequipa un item del slot
func unequip_item(slot: String) -> bool:
	if slot not in equipped_items:
		return false
	
	var item = equipped_items[slot]
	item.is_equipped = false
	equipped_items.erase(slot)
	
	emit_signal("crafted_items_changed", crafted_items)
	print("InventoryManager: Desequipado item del slot %s" % slot)
	return true

## Retorna el item equipado en un slot específico
func get_equipped_item(slot: String) -> CraftedItem:
	return equipped_items.get(slot, null)

## Calcula estadísticas totales del héroe con items equipados
func calculate_total_stats() -> Dictionary:
	var total_stats = {
		"damage": 0,
		"str": 0,
		"agi": 0,
		"int": 0,
		"hp": 0,
		"armor": 0,
		"crit": 0.0,
		"aps": 0.0
	}
	
	for item in equipped_items.values():
		for stat in item.calculated_stats:
			if stat in total_stats:
				total_stats[stat] += item.calculated_stats[stat]
	
	return total_stats

## Remove un item crafteado del inventario (ej: al venderlo)
func remove_crafted_item(item: CraftedItem) -> bool:
	if item not in crafted_items:
		return false
	
	# Desequipar si estaba equipado
	if item.is_equipped:
		for slot in equipped_items.keys():
			if equipped_items[slot] == item:
				unequip_item(slot)
				break
	
	crafted_items.erase(item)
	emit_signal("crafted_items_changed", crafted_items)
	return true

