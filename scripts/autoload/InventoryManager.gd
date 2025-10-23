extends Node
class_name InventoryManager

signal inventory_changed(current_inventory)

var inventory: Dictionary = {}

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

func clear() -> void:
		inventory.clear()
		emit_signal("inventory_changed", inventory.duplicate())
