extends Node
class_name InventoryManager

signal inventory_changed(current_inventory)

var inventory: Dictionary = {}

func _ready() -> void:
	"""Inicializar inventario con materiales básicos para evitar softlocks"""
	# Dar materiales generosos al inicio para poder craftear los primeros pedidos gratis
	var starting_materials := {
		"wood": 40,
		"iron": 40,
		"leather": 40,
		"fiber": 40,
		"herb": 30,
		"gold": 20,
		"bottle": 20
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
	emit_signal("inventory_changed", inventory.duplicate())
