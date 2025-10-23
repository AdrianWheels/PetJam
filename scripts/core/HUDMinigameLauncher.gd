extends CanvasLayer

const FALLBACK_MINIGAMES := {
		&"Forge": preload("res://scenes/Minigames/ForgeTemp.tscn"),
		&"Hammer": preload("res://scenes/HammerMinigame.tscn"),
		&"Sew": preload("res://scenes/Minigames/SewOSU.tscn"),
		&"Quench": preload("res://scenes/Minigames/QuenchWater.tscn"),
		&"Temp": preload("res://scenes/Minigames/TempMinigame.tscn"),
}

var _active_minigame: Node = null
var _active_task_id: int = -1
var _active_config: TrialConfig

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

	# Los botones de entrega ya NO se conectan aquí
	# Ahora UIManager maneja todo el flujo de delivery con DeliveryPanel
	print("HUD: Delivery buttons managed by UIManager")
	
	# Conectar botón "Ver Blueprints"
	var btn_view_blueprints = get_node_or_null("BlueprintQueuePanel/QueueVBox/ViewBlueprintsBtn")
	if btn_view_blueprints:
		btn_view_blueprints.pressed.connect(_on_view_blueprints_pressed)
		print("HUD: View Blueprints button connected")
	
	# DeliverPanel con opacidad reducida cuando no hay ítem
	var deliver_panel = get_node_or_null("DeliverPanel")
	if deliver_panel:
		deliver_panel.modulate = Color(1, 1, 1, 0.5)

	var cm = get_node("/root/CraftingManager") if has_node("/root/CraftingManager") else null
	if cm:
		cm.connect("craft_enqueued", Callable(self, "_on_craft_enqueued"))
		if not cm.is_connected("task_started", Callable(self, "_on_task_started")):
			cm.connect("task_started", Callable(self, "_on_task_started"))
		if not cm.is_connected("task_updated", Callable(self, "_on_task_updated")):
			cm.connect("task_updated", Callable(self, "_on_task_updated"))
		if not cm.is_connected("task_completed", Callable(self, "_on_task_completed")):
			cm.connect("task_completed", Callable(self, "_on_task_completed"))
		print("HUD: Connected to CraftingManager")
	else:
		print("HUD: CraftingManager not found")

	if has_node('/root/DataManager'):
		var dm = get_node('/root/DataManager')
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
		if has_node('/root/GameManager'):
				get_node('/root/GameManager').start_minigame("Forge")

func _on_btn_hammer() -> void:
		print("HUD: Hammer pressed - botones de minijuego desactivados. Usa blueprints para iniciar trials.")
		# Estos botones eran para testing - ahora los minijuegos se inician desde blueprints

func _on_btn_sew_osu() -> void:
		print("HUD: Sew OSU pressed - botones de minijuego desactivados. Usa blueprints para iniciar trials.")

func _on_btn_quench() -> void:
		print("HUD: Quench pressed - botones de minijuego desactivados. Usa blueprints para iniciar trials.")

func _on_btn_temp() -> void:
		print("HUD: Temp pressed - botones de minijuego desactivados. Usa blueprints para iniciar trials.")

func _on_craft_enqueued(slot_idx:int, recipe_id:String) -> void:
		print("HUD: Craft enqueued slot %d -> %s" % [slot_idx, recipe_id])
		update_queue_display()
		append_print("Craft enqueued: %s (slot %d)" % [recipe_id, slot_idx])

func _on_task_started(task_id: int, config: TrialConfig) -> void:
		if config == null:
				return
		var runtime_config := config.duplicate_config() if config.has_method("duplicate_config") else config
		_launch_trial(task_id, runtime_config)

func _on_task_updated(task_id: int, payload: Dictionary) -> void:
		var status := String(payload.get("status", ""))
		if _active_task_id != -1 and task_id == _active_task_id and status == "completed":
				_active_task_id = -1

func _on_task_completed(slot_idx: int, crafted_item: Dictionary) -> void:
	print("HUD: Task completed! Slot %d, Grade: %s" % [slot_idx, crafted_item.get("grade", "unknown")])
	
	# UIManager.present_delivery() ya maneja todo el flujo de entrega
	# Solo actualizamos el display local
	update_queue_display()
	populate_materials_list()
	append_print("¡Ítem completado! Grado: %s" % crafted_item.get("grade", "?"))

func update_queue_display() -> void:
		var queue_container = get_node_or_null("BlueprintQueuePanel/QueueVBox/QueueContainer")
		if not queue_container:
				queue_container = get_node_or_null("BlueprintQueuePanel/QueueContainer")
		if not queue_container:
				queue_container = get_node_or_null("QueueContainer")
		if not queue_container:
				print("HUD: QueueContainer not found; cannot update display")
				return
		for child in queue_container.get_children():
				child.queue_free()

		var cm = get_node("/root/CraftingManager") if has_node("/root/CraftingManager") else null
		if cm == null:
				print("HUD: CraftingManager not available for queue display")
				return

		var snapshot: Array = cm.get_queue_snapshot() if cm.has_method("get_queue_snapshot") else []
		for entry in snapshot:
				if typeof(entry) != TYPE_DICTIONARY:
						continue
				var slot_idx: int = int(entry.get("slot_index", 0))
				var slot_scene = preload("res://scenes/UI/BlueprintQueueSlot.tscn")
				var slot_node = slot_scene.instantiate()
				queue_container.add_child(slot_node)
				
				# Pasar el índice del slot y conectar señal de clic
				slot_node.slot_index = slot_idx
				slot_node.blueprint_clicked.connect(_on_blueprint_clicked)

				if entry.get("status", "") == "empty":
						slot_node.set_blueprint_name("(vacío)")
						continue

				var blueprint: BlueprintResource = entry.get("blueprint", null)
				var recipe_id = entry.get("blueprint_id", "")
				if blueprint and blueprint is BlueprintResource:
						slot_node.set_blueprint(blueprint)
				else:
						var display_name: String = entry.get("display_name", str(recipe_id))
						slot_node.set_blueprint_name(display_name)
						slot_node.set_materials(entry.get("materials", {}))
				
				append_print("Slot %d: %s" % [slot_idx, entry.get("display_name", str(recipe_id))])

func append_print(msg: String) -> void:
	# PrintsArea movido a la raíz del HUD
	var ta = get_node_or_null("PrintsArea")
	if not ta:
		ta = get_node_or_null("BlueprintQueuePanel/QueueVBox/PrintsArea")
	if ta:
		ta.text += str(msg) + "\n"

func populate_materials_list() -> void:
		var ml = get_node_or_null("InventoryPanel/InventoryVBox/MaterialsList")
		if not ml:
				ml = get_node_or_null("MaterialsList")
		if not ml:
				print("HUD: MaterialsList node not found")
				return
		
		# Limpiar lista actual
		for child in ml.get_children():
				child.queue_free()
		
		if not has_node('/root/InventoryManager'):
				return
		
		var inv = get_node('/root/InventoryManager')
		if not inv.has_method("get_materials"):
				return
		
		var materials: Dictionary = inv.get_materials()
		
		# Orden prioritario: oro primero, luego materiales alfabéticamente
		var material_order = ["gold", "iron", "leather", "wood", "fiber", "herb", "water"]
		var material_row_scene = preload("res://scenes/UI/MaterialRow.tscn")
		
		for mat_id in material_order:
				if materials.has(mat_id):
						var row = material_row_scene.instantiate()
						ml.add_child(row)
						row.set_material_data(mat_id, materials[mat_id])
		
		# Agregar cualquier material adicional no listado
		for mat_id in materials.keys():
				if mat_id not in material_order:
						var row = material_row_scene.instantiate()
						ml.add_child(row)
						row.set_material_data(mat_id, materials[mat_id])

func _launch_trial(task_id: int, config: TrialConfig) -> void:
		if config == null:
				return
		if _active_minigame and is_instance_valid(_active_minigame):
				_active_minigame.queue_free()
		var scene: PackedScene = config.minigame_scene if config.minigame_scene else _fallback_scene_for(config.minigame_id)
		if scene == null:
				push_warning("HUD: No scene for minigame %s" % String(config.minigame_id))
				return
		var instance = scene.instantiate()
		_active_minigame = instance
		_active_task_id = task_id
		_active_config = config
		_set_forge_panels_visible(false)
		var parent_layer := get_parent()
		if parent_layer:
				parent_layer.add_child(instance)
		else:
				add_child(instance)
		if instance.has_signal("trial_completed"):
				instance.connect("trial_completed", Callable(self, "_on_trial_completed").bind(instance, task_id, config))
		if instance.has_method("start_trial"):
				instance.start_trial(config)
		elif instance.has_method("start_game"):
				instance.start_game()

func _on_trial_completed(result: TrialResult, instance: Node, task_id: int, config: TrialConfig) -> void:
		print("HUD: Trial completed, task_id=%d" % task_id)
		var outcome := {}
		if has_node("/root/CraftingManager"):
				outcome = get_node("/root/CraftingManager").report_trial_result(task_id, result)
				print("HUD: CraftingManager outcome = %s" % outcome)
		if has_node("/root/TelemetryManager"):
				get_node("/root/TelemetryManager").record_trial(config.blueprint_id, config.trial_id, result)
		if _active_minigame == instance:
				_active_task_id = -1
		if typeof(outcome) == TYPE_DICTIONARY:
				var status := String(outcome.get("status", ""))
				print("HUD: Outcome status = '%s'" % status)
				if status == "completed":
					print("HUD: All trials completed! Calling UIManager.present_delivery()")
					if has_node("/root/UIManager"):
						get_node("/root/UIManager").present_delivery(outcome)
					else:
						print("HUD: ERROR - UIManager not found!")
				else:
					print("HUD: More trials remain, status = %s" % status)

func _fallback_scene_for(minigame_id: StringName) -> PackedScene:
		var key := StringName(minigame_id)
		if FALLBACK_MINIGAMES.has(key):
				return FALLBACK_MINIGAMES[key]
		return null

func _set_forge_panels_visible(show_panels: bool) -> void:
		print("HUD: _set_forge_panels_visible(%s)" % show_panels)
		var nodes := [
				"MinigamesPanel",
				"BlueprintQueuePanel",
				"InventoryPanel",
                "Label"
		]
		for node_name in nodes:
				var node = get_node_or_null(node_name)
				if node:
						node.visible = show_panels
						print("  - %s.visible = %s" % [node_name, show_panels])

func _on_blueprint_clicked(slot_idx: int) -> void:
		print("HUD: Blueprint slot %d clicked, starting task..." % slot_idx)
		var cm = get_node("/root/CraftingManager") if has_node("/root/CraftingManager") else null
		if cm and cm.has_method("start_task"):
				var success: bool = cm.start_task(slot_idx)
				if success:
						print("HUD: Task %d started successfully" % slot_idx)
				else:
						print("HUD: Failed to start task %d" % slot_idx)
		else:
				print("HUD: CraftingManager.start_task() not available")

## ELIMINADAS: _on_deliver_to_client() y _on_deliver_to_hero()
## Ahora UIManager maneja toda la lógica de delivery a través de DeliveryPanel


## Abre el panel de biblioteca de blueprints (solo consulta)
func _on_view_blueprints_pressed() -> void:
	print("HUD: Opening Blueprint Library")
	var library_panel = get_node_or_null("BlueprintLibraryPanel")
	if library_panel and library_panel.has_method("open"):
		library_panel.open()
	else:
		print("HUD: BlueprintLibraryPanel no encontrado en la escena")

	# TODO: Implementar UI de equipamiento en dungeon
	# Cuando el jugador vaya a la dungeon, mostrar panel para equipar ítems