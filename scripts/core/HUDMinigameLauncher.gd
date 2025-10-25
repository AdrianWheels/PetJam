extends CanvasLayer

const FALLBACK_MINIGAMES := {
		&"Forge": preload("res://scenes/Minigames/ForgeTemp.tscn"),
		&"Hammer": preload("res://scenes/Minigames/HammerMinigame.tscn"),
		&"Sew": preload("res://scenes/Minigames/SewOSU.tscn"),
		&"Quench": preload("res://scenes/Minigames/QuenchWater.tscn"),
		# &"Temp" eliminado - usar "Forge" en su lugar
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
	
	# Conectar señal de UIManager para reactivar blueprints cuando se entrega el ítem
	var ui_mgr = get_node("/root/UIManager") if has_node("/root/UIManager") else null
	if ui_mgr:
		if ui_mgr.has_signal("delivery_closed") and not ui_mgr.is_connected("delivery_closed", Callable(self, "_on_delivery_closed")):
			ui_mgr.connect("delivery_closed", Callable(self, "_on_delivery_closed"))
			print("HUD: Connected to UIManager.delivery_closed")
	else:
		print("HUD: UIManager not found")
	
	# 📦 Conectar señal de InventoryManager para actualizar MaterialsList automáticamente
	var inv_mgr = get_node("/root/InventoryManager") if has_node("/root/InventoryManager") else null
	if inv_mgr:
		if inv_mgr.has_signal("inventory_changed") and not inv_mgr.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
			inv_mgr.connect("inventory_changed", Callable(self, "_on_inventory_changed"))
			print("HUD: Connected to InventoryManager.inventory_changed")
	
	# 📋 Conectar señal de RequestsManager para actualizar cola de pedidos
	var req_mgr = get_node("/root/RequestsManager") if has_node("/root/RequestsManager") else null
	if req_mgr:
		if req_mgr.has_signal("requests_refreshed") and not req_mgr.is_connected("requests_refreshed", Callable(self, "_on_requests_refreshed")):
			req_mgr.connect("requests_refreshed", Callable(self, "_on_requests_refreshed"))
			print("HUD: Connected to RequestsManager.requests_refreshed")
	else:
		print("HUD: RequestsManager not found")

	if has_node('/root/DataManager'):
		var dm = get_node('/root/DataManager')
		if dm.blueprints.size() > 0:
			# Ya NO llamar update_queue_display aquí - RequestsManager.requests_refreshed lo hará
			# update_queue_display()  # <-- QUITADO para evitar doble rendering
			populate_materials_list()
		else:
			# Si DataManager aún no está listo, esperar señal (raro en práctica)
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
		# Ya NO actualizar queue_display aquí - ahora muestra pedidos de RequestsManager
		append_print("Craft enqueued: %s (slot %d)" % [recipe_id, slot_idx])

func _on_task_started(task_id: int, config: TrialConfig) -> void:
		print("HUD: _on_task_started() called with task_id=%d, config=%s" % [task_id, config])
		if config == null:
				print("HUD: ERROR - config is NULL in _on_task_started!")
				return
		var runtime_config := config.duplicate_config() if config.has_method("duplicate_config") else config
		print("HUD: Launching trial for task %d..." % task_id)
		_launch_trial(task_id, runtime_config)

func _on_task_updated(task_id: int, payload: Dictionary) -> void:
		var status := String(payload.get("status", ""))
		if _active_task_id != -1 and task_id == _active_task_id and status == "completed":
				_active_task_id = -1

func _on_task_completed(slot_idx: int, crafted_item: Dictionary) -> void:
	print("HUD: Task completed! Slot %d, Grade: %s" % [slot_idx, crafted_item.get("grade", "unknown")])
	
	# Ya NO actualizar requests aquí - CraftingManager.task_completed es sobre crafteo,
	# no sobre la lista de pedidos disponibles. Los requests solo se actualizan desde
	# RequestsManager.requests_refreshed
	# update_queue_display()  # <-- QUITADO
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
		
		# Leer pedidos desde RequestsManager
		var rm = get_node("/root/RequestsManager") if has_node("/root/RequestsManager") else null
		if rm == null:
				print("HUD: RequestsManager not available for queue display")
				return

		var pending_requests: Array = rm.get_active_requests() if rm.has_method("get_active_requests") else []
		
		print("HUD: Updating queue display with %d requests" % pending_requests.size())
		
		# Actualizar contador de pedidos gratis
		_update_free_requests_label()
		
		# Detectar si hay slots nuevos (comparar tamaño antes/después)
		var old_count := queue_container.get_child_count()
		var new_count := pending_requests.size()
		var should_animate := new_count > old_count
		
		# LIMPIAR TODOS los slots existentes
		for child in queue_container.get_children():
				child.queue_free()
		
		# Esperar un frame para que queue_free() termine
		await get_tree().process_frame
		
		# NO INVERTIR - mantener orden original para que los índices coincidan
		# Los más viejos arriba, los más nuevos abajo (orden natural de llegada)
		
		# Crear slots para cada pedido
		for i in range(pending_requests.size()):
				var request: Dictionary = pending_requests[i]
				var blueprint: BlueprintResource = request.get("blueprint")
				
				if not blueprint:
						continue
				
				# Crear nuevo slot de pedido
				var slot_scene = preload("res://scenes/UI/RequestSlot.tscn")
				var slot_node = slot_scene.instantiate()
				slot_node.slot_index = i  # Usar índice actual, no el original
				slot_node.blueprint_clicked.connect(_on_blueprint_clicked)
				
				queue_container.add_child(slot_node)
				
				# Configurar contenido
				slot_node.set_blueprint(blueprint)
				
				# Animar entrada solo si es el último slot Y hay slots nuevos
				if should_animate and i == new_count - 1:
						_animate_slot_entry(slot_node)
				
				print("  RequestSlot %d: %s - %d oro - Cliente: %s" % [i, blueprint.display_name, request.get("gold_reward", 0), request.get("client_name", "???")])

func _update_free_requests_label() -> void:
	"""Actualiza el label 'Pedidos' con el contador de pedidos gratis"""
	var queue_label = get_node_or_null("BlueprintQueuePanel/QueueVBox/QueueLabel")
	if not queue_label:
		return
	
	var rm = get_node("/root/RequestsManager") if has_node("/root/RequestsManager") else null
	if not rm or not rm.has_method("get_free_requests_remaining"):
		queue_label.text = "Pedidos"
		return
	
	var free_count: int = rm.get_free_requests_remaining()
	if free_count > 0:
		queue_label.text = "Pedidos  %d 🎲" % free_count
	else:
		queue_label.text = "Pedidos"

func _animate_slot_entry(slot_node: Control) -> void:
	"""Anima la entrada de un nuevo slot desde abajo con efecto bounce"""
	if not slot_node:
		return
	
	# Esperar un frame para que el layout calcule el tamaño
	await get_tree().process_frame
	
	# Estado inicial: escala pequeña y transparente
	slot_node.modulate.a = 0.0
	slot_node.scale = Vector2(0.3, 0.3)
	slot_node.pivot_offset = slot_node.size / 2.0  # Centro del slot como pivot
	
	# Crear tween para la animación
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)  # Back = bounce effect
	
	# Fade in (rápido)
	tween.tween_property(slot_node, "modulate:a", 1.0, 0.3)
	
	# Scale bounce con overshoot
	tween.tween_property(slot_node, "scale", Vector2(1.0, 1.0), 0.6)

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
		
		# Limpiar minijuego anterior si existe
		if _active_minigame and is_instance_valid(_active_minigame):
				if _active_minigame.get_parent():
					_active_minigame.get_parent().remove_child(_active_minigame)
				_active_minigame.queue_free()
				_active_minigame = null
		
		# Buscar el SubViewport directamente por ruta
		var viewport: SubViewport = get_node_or_null("MinigameContainer/SubViewport")
		
		if not viewport:
				push_error("HUD: SubViewport not found at path 'MinigameContainer/SubViewport'!")
				print("HUD: Available nodes:")
				if has_node("MinigameContainer"):
					var container = get_node("MinigameContainer")
					print("  MinigameContainer found, children: %d" % container.get_child_count())
					for child in container.get_children():
						print("    - %s (%s)" % [child.name, child.get_class()])
				else:
					print("  MinigameContainer NOT FOUND")
				return
		
		# Limpiar hijos existentes del viewport
		for child in viewport.get_children():
				viewport.remove_child(child)
				child.queue_free()
		
		var scene: PackedScene = config.minigame_scene if config.minigame_scene else _fallback_scene_for(config.minigame_id)
		if scene == null:
				push_warning("HUD: No scene for minigame %s" % String(config.minigame_id))
				return
		
		var instance = scene.instantiate()
		_active_minigame = instance
		_active_task_id = task_id
		_active_config = config
		
		# Renderizar minijuego en el SubViewport (recorte visual REAL)
		viewport.add_child(instance)
		print("HUD: Minigame rendered in SubViewport (800x560, clipped)")
		
		# 🎨 FADE IN: Aparecer minijuego con efecto de desvanecimiento
		instance.modulate.a = 0.0
		var fade_tween := create_tween()
		fade_tween.set_ease(Tween.EASE_OUT)
		fade_tween.set_trans(Tween.TRANS_CUBIC)
		fade_tween.tween_property(instance, "modulate:a", 1.0, 0.3)		# Bloquear interacción con blueprints mientras minijuego activo
		_set_queue_interaction_enabled(false)
		
		if instance.has_signal("trial_completed"):
				instance.connect("trial_completed", Callable(self, "_on_trial_completed").bind(instance, task_id, config))
		if instance.has_method("start_trial"):
				instance.start_trial(config)
		elif instance.has_method("start_game"):
				instance.start_game()

func _on_trial_completed(result: TrialResult, instance: Node, task_id: int, config: TrialConfig) -> void:
		print("HUD: Trial completed, task_id=%d" % task_id)
		
		# 🎨 FADE OUT: Desvanecer minijuego antes de eliminarlo
		if instance and is_instance_valid(instance):
			var fade_tween := create_tween()
			fade_tween.set_ease(Tween.EASE_IN)
			fade_tween.set_trans(Tween.TRANS_CUBIC)
			fade_tween.tween_property(instance, "modulate:a", 0.0, 0.25)
			fade_tween.tween_callback(func():
				# Limpiar minijuego después del fade
				if instance and is_instance_valid(instance):
					if instance.get_parent():
						instance.get_parent().remove_child(instance)
					instance.queue_free()
				if _active_minigame == instance:
					_active_minigame = null
			)
		else:
			# Fallback sin animación
			if instance and is_instance_valid(instance):
				if instance.get_parent():
					instance.get_parent().remove_child(instance)
				instance.queue_free()
			if _active_minigame == instance:
				_active_minigame = null
			_active_task_id = -1
		
		# Reportar resultado a CraftingManager (esto puede disparar task_started sincrónicamente)
		var outcome := {}
		if has_node("/root/CraftingManager"):
				outcome = get_node("/root/CraftingManager").report_trial_result(task_id, result)
				print("HUD: CraftingManager outcome = %s" % outcome)
		if has_node("/root/TelemetryManager"):
				get_node("/root/TelemetryManager").record_trial(config.blueprint_id, config.trial_id, result)
		
		if typeof(outcome) == TYPE_DICTIONARY:
				var status := String(outcome.get("status", ""))
				print("HUD: Outcome status = '%s'" % status)
				if status == "completed":
					print("HUD: All trials completed! Calling UIManager.present_delivery()")
					# Ya NO actualizar queue aquí - solo se actualiza desde RequestsManager
					# ⚠️ NO desbloquear aquí - solo tras delivery_closed
					# _set_queue_interaction_enabled(true)  # <-- ELIMINAR
					if has_node("/root/UIManager"):
						get_node("/root/UIManager").present_delivery(outcome)
					else:
						print("HUD: ERROR - UIManager not found!")
				elif status == "in_progress":
					print("HUD: More trials remain, next trial will auto-start via task_started signal")
					# Ya NO actualizar queue aquí - solo se actualiza desde RequestsManager
					# NO desbloquear blueprints - el siguiente trial iniciará automáticamente
					# CraftingManager ya llamó _start_next_trial() que emitirá task_started
				else:
					print("HUD: Unexpected status '%s', re-enabling blueprint interaction" % status)
					_set_queue_interaction_enabled(true)

func _fallback_scene_for(minigame_id: StringName) -> PackedScene:
		var key := StringName(minigame_id)
		if FALLBACK_MINIGAMES.has(key):
				return FALLBACK_MINIGAMES[key]
		return null

func _set_queue_interaction_enabled(enabled: bool) -> void:
		"""Habilita/deshabilita la interacción con los blueprints de la cola"""
		print("HUD: _set_queue_interaction_enabled(%s)" % enabled)
		var queue_container = get_node_or_null("BlueprintQueuePanel/QueueVBox/QueueContainer")
		if not queue_container:
				queue_container = get_node_or_null("BlueprintQueuePanel/QueueContainer")
		if not queue_container:
				queue_container = get_node_or_null("QueueContainer")
		if queue_container:
				for slot in queue_container.get_children():
						if slot.has_method("set_interaction_enabled"):
								slot.set_interaction_enabled(enabled)
						elif slot is Control:
								slot.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
				print("  - Blueprint slots interaction = %s" % ("enabled" if enabled else "disabled"))
		else:
				print("  - WARNING: QueueContainer not found")

func _on_blueprint_clicked(slot_idx: int) -> void:
		# Prevenir clicks si hay un minijuego activo
		if _active_minigame != null and is_instance_valid(_active_minigame):
				print("HUD: Blueprint click ignored - minigame in progress")
				return
		
		print("HUD: Request slot %d clicked, accepting and starting crafteo..." % slot_idx)
		
		# Aceptar el pedido desde RequestsManager
		var rm = get_node("/root/RequestsManager") if has_node("/root/RequestsManager") else null
		if not rm or not rm.has_method("accept_request"):
				print("HUD: RequestsManager.accept_request() not available")
				return
		
		var accepted: bool = rm.accept_request(slot_idx)
		if not accepted:
				print("HUD: Failed to accept request in slot %d (materiales insuficientes?)" % slot_idx)
				return
		
		print("HUD: Request accepted, now starting crafteo in CraftingManager...")
		
		# El pedido ahora está en CraftingManager
		var cm = get_node("/root/CraftingManager") if has_node("/root/CraftingManager") else null
		if not cm:
				print("HUD: CraftingManager not found")
				return
		
		# Buscar el primer slot con estado "queued" (el que acabamos de añadir)
		var queue_snapshot = cm.get_queue_snapshot() if cm.has_method("get_queue_snapshot") else []
		var craft_slot_idx := -1
		for i in range(queue_snapshot.size()):
				if queue_snapshot[i].get("status", "") == "queued":
						craft_slot_idx = i
						break  # Tomar el primero que esté en cola
		
		if craft_slot_idx >= 0 and cm.has_method("start_task"):
				var success: bool = cm.start_task(craft_slot_idx)
				if success:
						print("HUD: Crafteo started successfully in slot %d" % craft_slot_idx)
				else:
						print("HUD: Failed to start crafteo in slot %d" % craft_slot_idx)
		
		# Ya NO actualizar queue aquí - RequestsManager.accept_request() emite requests_refreshed
		# que automáticamente actualiza la UI vía _on_requests_refreshed()

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

func _on_delivery_closed() -> void:
	"""Llamado cuando UIManager cierra el DeliveryPanel tras entregar al cliente o héroe"""
	print("HUD: Delivery closed, returning to IDLE state (re-enabling blueprint interaction)")
	# Ya no hay minijuego activo ni panel de entrega - volver a estado IDLE
	_active_minigame = null
	_active_task_id = -1
	_active_config = null
	# Permitir seleccionar otro blueprint
	_set_queue_interaction_enabled(true)
	update_queue_display()

func _on_inventory_changed(_current_inventory: Dictionary) -> void:
	"""Llamado cuando cambia el inventario (drops, consumo de materiales, etc)"""
	print("HUD: Inventory changed, refreshing MaterialsList")
	populate_materials_list()

func _on_requests_refreshed(_requests: Array) -> void:
	"""Llamado cuando RequestsManager actualiza sus pedidos (nuevos pedidos entrantes)"""
	print("HUD: Requests refreshed, updating queue display")
	update_queue_display()
