extends CanvasLayer
func _find_node_any(candidates: Array) -> Node:
	for p in candidates:
		var n = get_node_or_null(str(p))
		if n:
			return n
	return null

func _ready():
	var btn_forge = _find_node_any(["BtnForge", "MinigamesPanel/BtnForge", "MinigamesPanel/MinigamesHBox/BtnForge"])
	if btn_forge:
		btn_forge.pressed.connect(_on_btn_forge)
		print("HUD: Forge button connected")
	else:
		print("HUD: Forge button not found")

	var btn_hammer = _find_node_any(["BtnHammer", "MinigamesPanel/MinigamesHBox/BtnHammer", "MinigamesPanel/BtnHammer"])
	if btn_hammer:
		btn_hammer.pressed.connect(_on_btn_hammer)
		print("HUD: Hammer button connected")
	else:
		print("HUD: Hammer button not found")

	var btn_sew = _find_node_any(["BtnSewOSU", "MinigamesPanel/MinigamesHBox/BtnSewOSU", "MinigamesPanel/BtnSewOSU"])
	if btn_sew:
		btn_sew.pressed.connect(_on_btn_sew_osu)
		print("HUD: Sew button connected")
	else:
		print("HUD: Sew button not found")

	var btn_quench = _find_node_any(["BtnQuench", "MinigamesPanel/MinigamesHBox/BtnQuench", "MinigamesPanel/BtnQuench"])
	if btn_quench:
		btn_quench.pressed.connect(_on_btn_quench)
		print("HUD: Quench button connected")
	else:
		print("HUD: Quench button not found")

	var btn_temp = _find_node_any(["BtnTemp", "MinigamesPanel/MinigamesHBox/BtnTemp", "MinigamesPanel/BtnTemp"])
	if btn_temp:
		btn_temp.pressed.connect(_on_btn_temp)
		print("HUD: Temp button connected")
	else:
		print("HUD: Temp button not found")

	# Connect to CraftingManager
	var cm = get_node("/root/CraftingManager") if has_node("/root/CraftingManager") else null
	if cm:
		cm.connect("craft_enqueued", Callable(self, "_on_craft_enqueued"))
		print("HUD: Connected to CraftingManager")
	else:
		print("HUD: CraftingManager not found")

	# Connect to DataManager to update UI after data loads
	if has_node('/root/DataManager'):
		var dm = get_node('/root/DataManager')
		# If data is already loaded, call immediately; otherwise wait for signal
		if dm.blueprints.size() > 0:
			update_queue_display()
			populate_materials_list()
		else:
			dm.connect("data_ready", Callable(self, "update_queue_display"))
			dm.connect("data_ready", Callable(self, "populate_materials_list"))
			print("HUD: waiting for DataManager.data_ready to populate queue")
	else:
		print("HUD: DataManager not found; queue will not populate until available")


func _on_btn_forge() -> void:
	print("HUD: Forge pressed")
	# For debug, open forge minigame (if available)
	if has_node('/root/GameManager'):
		get_node('/root/GameManager').start_minigame("Forge")


func _on_btn_hammer() -> void:
	print("HUD: Hammer pressed")
	if has_node('/root/GameManager'):
		get_node('/root/GameManager').start_minigame("Hammer")


func _on_btn_sew_osu() -> void:
	print("HUD: Sew OSU pressed")
	if has_node('/root/GameManager'):
		get_node('/root/GameManager').start_minigame("Sew")


func _on_btn_quench() -> void:
	print("HUD: Quench pressed")
	if has_node('/root/GameManager'):
		get_node('/root/GameManager').start_minigame("Quench")


func _on_btn_temp() -> void:
	print("HUD: Temp pressed")
	if has_node('/root/GameManager'):
		get_node('/root/GameManager').start_minigame("Temp")


func _on_craft_enqueued(slot_idx:int, recipe_id:String) -> void:
	print("HUD: Craft enqueued slot %d -> %s" % [slot_idx, recipe_id])
	if has_node('/root/Logger'):
		get_node('/root/Logger').info("HUD: craft_enqueued", {"slot": slot_idx, "recipe": recipe_id})
	update_queue_display()
	append_print("Craft enqueued: %s (slot %d)" % [recipe_id, slot_idx])


func update_queue_display() -> void:
	# Populate the QueueContainer with current crafting queue
	var queue_container = get_node_or_null("BlueprintQueuePanel/QueueContainer")
	if not queue_container:
		# fallback to top-level QueueContainer
		queue_container = get_node_or_null("QueueContainer")
	if not queue_container:
		print("HUD: QueueContainer not found; cannot update display")
		return

	# Clear existing children
	for child in queue_container.get_children():
		child.queue_free()

	# Acquire crafting queue from CraftingManager
	var cm = get_node("/root/CraftingManager") if has_node("/root/CraftingManager") else null
	if cm == null:
		print("HUD: CraftingManager not available for queue display")
		return

	for i in range(cm.queue.size()):
		var slot = cm.queue[i]
		var slot_scene = preload("res://scenes/UI/BlueprintQueueSlot.tscn")
		var slot_node = slot_scene.instantiate()

		# IMPORTANT: add to container first so the slot_node's onready variables are initialized
		queue_container.add_child(slot_node)

		if slot == null:
			# empty slot
			slot_node.set_blueprint_name("(vacío)")
			continue

		var recipe_id = slot.get("recipe_id") if typeof(slot) == TYPE_DICTIONARY else null
		if recipe_id == null:
			slot_node.set_blueprint_name("(desconocido)")
			continue

		# Lookup blueprint in DataManager
		var bp = null
		if has_node('/root/DataManager'):
			bp = get_node('/root/DataManager').get_blueprint(str(recipe_id))
		if bp == null:
			slot_node.set_blueprint_name(str(recipe_id))
			continue

		# Set display name
		var display_name = bp.get("name", str(recipe_id)) if typeof(bp) == TYPE_DICTIONARY else str(recipe_id)
		slot_node.set_blueprint_name(display_name)

		# Set materials (accepts Dictionary or Array)
		var materials = bp.get("materials", {}) if typeof(bp) == TYPE_DICTIONARY else {}
		slot_node.set_materials(materials)

		# Persistent trace for debugging
		if has_node('/root/Logger'):
			get_node('/root/Logger').info("HUD: queue_slot_populated", {"slot": i, "recipe_id": recipe_id, "display_name": display_name, "materials": materials})
		append_print("Slot %d: %s" % [i, display_name])


func append_print(msg: String) -> void:
	var ta = get_node_or_null("BlueprintQueuePanel/QueueVBox/PrintsArea")
	if not ta:
		ta = get_node_or_null("PrintsArea")
	if ta:
		ta.append_bbcode(str(msg) + "\n")


func populate_materials_list() -> void:
	var ml = get_node_or_null("InventoryPanel/InventoryVBox/MaterialsList")
	if not ml:
		ml = get_node_or_null("MaterialsList")
	if not ml:
		print("HUD: MaterialsList node not found")
		return

	# Clear existing
	for child in ml.get_children():
		child.queue_free()

	if not has_node('/root/DataManager'):
		return
	var dm = get_node('/root/DataManager')
	for key in dm.materials.keys():
		var entry = dm.materials[key]
		var label = Label.new()
		label.text = "%s: %s" % [str(key), str(entry.get("stack", "?"))]
		ml.add_child(label)
