extends Node

signal craft_enqueued(slot_idx, recipe_id)

const MAX_SLOTS = 3

var queue := []
var heat := 0
var forjamagia := 0

func _ready():
	for i in range(MAX_SLOTS):
		queue.append(null)
	
	# Enqueue default blueprints
	var default_blueprints = ["sword_basic", "armor_leather", "shield_wooden"]
	for recipe_id in default_blueprints:
		enqueue(recipe_id)
	
	print("CraftingManager: Ready with %d slots and default blueprints enqueued" % MAX_SLOTS)

func enqueue(recipe_id) -> bool:
	for i in range(MAX_SLOTS):
		if queue[i] == null:
			queue[i] = {"recipe_id": recipe_id, "progress": 0}
			print("CraftingManager: Enqueued recipe '%s' in slot %d" % [recipe_id, i])
			emit_signal("craft_enqueued", i, recipe_id)
			return true
	print("CraftingManager: No free slots for recipe '%s'" % recipe_id)
	return false

func cancel(slot_idx:int) -> Dictionary:
	var slot = queue[slot_idx]
	if slot == null:
		print("CraftingManager: Cannot cancel empty slot %d" % slot_idx)
		return {}
	queue[slot_idx] = null
	print("CraftingManager: Cancelled recipe in slot %d" % slot_idx)
	# Return 80% of materials (stub)
	return {"refund_pct": 0.8}

func promote(slot_idx:int) -> bool:
	if slot_idx <= 0 or slot_idx >= MAX_SLOTS:
		print("CraftingManager: Invalid slot %d for promotion" % slot_idx)
		return false
	var slot = queue[slot_idx]
	if slot == null:
		print("CraftingManager: Cannot promote empty slot %d" % slot_idx)
		return false
	# promote to front
	queue.remove_at(slot_idx)
	queue.insert(0, slot)
	heat = clamp(heat + 10, 0, 100)
	print("CraftingManager: Promoted slot %d to front, heat now %d" % [slot_idx, heat])
	return true
