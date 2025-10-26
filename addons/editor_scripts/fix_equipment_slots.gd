@tool
extends EditorScript

## Script de editor para añadir equipment_slot a todos los ItemResource

func _run() -> void:
	print("")
	print("============================================================")
	print("FIXING EQUIPMENT SLOTS IN ITEM RESOURCES")
	print("============================================================")
	print("")
	
	var fixes := {
		# Swords (main_hand)
		"res://data/items/sword_basic.tres": "main_hand",
		"res://data/items/sword_advanced.tres": "main_hand",
		"res://data/items/sword_masterwork.tres": "main_hand",
		
		# Shields (off_hand)
		"res://data/items/shield_basic.tres": "off_hand",
		"res://data/items/shield_advanced.tres": "off_hand",
		"res://data/items/shield_master.tres": "off_hand",
		
		# Helmets (head)
		"res://data/items/helmet_basic.tres": "head",
		"res://data/items/helmet_advanced.tres": "head",
		"res://data/items/helmet_master.tres": "head",
		
		# Boots (feet)
		"res://data/items/boots_basic.tres": "feet",
		"res://data/items/boots_advanced.tres": "feet",
		"res://data/items/boots_master.tres": "feet",
	}
	
	var fixed := 0
	var errors := 0
	
	for path in fixes.keys():
		var slot_type = fixes[path]
		if _fix_item_resource(path, slot_type):
			fixed += 1
		else:
			errors += 1
	
	print("")
	print("============================================================")
	print("RESULTS:")
	print("  ✅ Fixed: %d items" % fixed)
	if errors > 0:
		print("  ❌ Errors: %d items" % errors)
	print("============================================================")
	print("")

func _fix_item_resource(path: String, slot_type: String) -> bool:
	if not ResourceLoader.exists(path):
		print("❌ NOT FOUND: %s" % path)
		return false
	
	var resource = load(path) as ItemResource
	if not resource:
		print("❌ INVALID: %s (not ItemResource)" % path)
		return false
	
	# Verificar si ya tiene equipment_slot correcto
	if resource.equipment_slot == slot_type:
		print("⏭️  SKIP: %s (already has equipment_slot=%s)" % [path.get_file(), slot_type])
		return true
	
	# Actualizar
	resource.equipment_slot = slot_type
	var error = ResourceSaver.save(resource, path)
	
	if error == OK:
		print("✅ FIXED: %s → equipment_slot=%s" % [path.get_file(), slot_type])
		return true
	else:
		print("❌ ERROR: %s (save failed: %d)" % [path.get_file(), error])
		return false
