extends CanvasLayer

func _ready():
	var btn_forge = get_node_or_null("BtnForge")
	if btn_forge:
		btn_forge.pressed.connect(_on_btn_forge)
		print("HUD: Forge button connected")
	else:
		print("HUD: Forge button not found")
	var btn_hammer = get_node_or_null("BtnHammer")
	if btn_hammer:
		btn_hammer.pressed.connect(_on_btn_hammer)
		print("HUD: Hammer button connected")
	else:
		print("HUD: Hammer button not found")
	var btn_sew = get_node_or_null("BtnSewOSU")
	if btn_sew:
		btn_sew.pressed.connect(_on_btn_sew_osu)
		print("HUD: Sew button connected")
	else:
		print("HUD: Sew button not found")
	var btn_quench = get_node_or_null("BtnQuench")
	if btn_quench:
		btn_quench.pressed.connect(_on_btn_quench)
		print("HUD: Quench button connected")
	else:
		print("HUD: Quench button not found")
	var btn_temp = get_node_or_null("BtnTemp")
	if btn_temp:
		btn_temp.pressed.connect(_on_btn_temp)
		print("HUD: Temp button connected")
	else:
		print("HUD: Temp button not found")

	# Connect to CraftingManager
	var cm = get_node("/root/CraftingManager")
	if cm:
		cm.connect("craft_enqueued", Callable(self, "_on_craft_enqueued"))
		print("HUD: Connected to CraftingManager")
	else:
		print("HUD: CraftingManager not found")

	update_queue_display()

func _on_craft_enqueued(_slot_idx, _recipe_id):
	update_queue_display()

func update_queue_display():
	var cm = get_node("/root/CraftingManager")
	var dm = get_node("/root/DataManager")
	if not cm or not dm:
		return
	var queue = cm.queue
	
	# Clear existing slots
	var grid = get_node("BlueprintQueuePanel/BluePrint Grid")
	for child in grid.get_children():
		child.queue_free()
	
	for i in range(queue.size()):
		var slot_scene = preload("res://scenes/UI/BlueprintQueueSlot.tscn")
		var slot_panel = slot_scene.instantiate()
		slot_panel.name = "Slot%d" % (i+1)
		grid.add_child(slot_panel)
		
		var name_label = slot_panel.get_node("VBoxContainer/NameLabel")
		var _mats_container = slot_panel.get_node("VBoxContainer/MaterialsContainer")
		if queue[i] != null:
			var recipe_id = queue[i].recipe_id
			var blueprints = dm.get_blueprints()
			if blueprints.has(recipe_id):
				var bp = blueprints[recipe_id]
				name_label.text = bp.name
				# Set materials
				var materials = bp.materials
				slot_panel.set_materials(materials)
			else:
				name_label.text = "Unknown"
				slot_panel.set_materials([])
		else:
			name_label.text = "Empty"
			slot_panel.set_materials([])

func _on_btn_forge():
	_toggle_minigame("res://scenes/Minigames/ForgeTemp.tscn", "ForgeTemp")

func _on_btn_hammer():
	print("HUD: Hammer button pressed")
	_toggle_minigame("res://scenes/HammerMinigame.tscn", "HammerMinigame")

func _on_btn_sew_osu():
	_toggle_minigame("res://scenes/Minigames/SewOSU.tscn", "SewOSU")

func _on_btn_quench():
	_toggle_minigame("res://scenes/Minigames/QuenchWater.tscn", "QuenchWater")

func _on_btn_temp():
	_toggle_minigame("res://scenes/Minigames/TempMinigame.tscn", "TempMinigame")

func _toggle_minigame(scene_path, node_name):
	var existing = get_node_or_null(node_name)
	if existing:
		print("HUD: Removing existing minigame " + node_name)
		get_parent().remove_child(existing)
		existing.queue_free()
		_set_forge_panels_visible(true)
	else:
		print("HUD: Loading minigame " + scene_path + " as " + node_name)
		_remove_minigames()
		_set_forge_panels_visible(false)
		var minigame_scene = load(scene_path).instantiate()
		print("HUD: Instantiated minigame, adding to ", get_parent().name)
		minigame_scene.name = node_name
		get_parent().add_child(minigame_scene)
		if minigame_scene is CanvasLayer:
			minigame_scene.offset = Vector2(0, 0)
		else:
			minigame_scene.position = Vector2(0, 0)
		print("HUD: Minigame " + node_name + " added at position " + str(minigame_scene.position if not minigame_scene is CanvasLayer else minigame_scene.offset) + ", size: " + str(minigame_scene.size if minigame_scene is Control else "N/A"))

func _remove_minigames():
	var main = get_parent()
	print("HUD: Removing minigames from " + main.name)
	for child in main.get_children():
		if child is Control and child.name in ["ForgeTemp", "HammerMinigame", "SewOSU", "QuenchWater", "TempMinigame"]:
			print("HUD: Removing " + child.name)
			main.remove_child(child)
			child.queue_free()


# Lógica para ocultar minijuegos si se cambia de área
func hide_minigames():
	_remove_minigames()
	_set_forge_panels_visible(false)

func show_forge_panels():
	_set_forge_panels_visible(true)

func _set_forge_panels_visible(panel_visible: bool):
	var panels = ["CraftPanel", "InventoryPanel", "DeliveryButton", "BtnForge", "BtnHammer", "BtnSewOSU", "BtnQuench", "BtnTemp", "CraftLabel", "InventoryLabel", "BlueprintQueuePanel"]
	for panel_name in panels:
		if has_node(panel_name):
			get_node(panel_name).visible = panel_visible
