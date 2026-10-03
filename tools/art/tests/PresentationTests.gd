extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	for i in 8:
		await process_frame
	var im := load("res://scripts/autoload/InventoryManager.gd").new() as Node
	root.add_child(im)
	var equipped := CraftedItem.new(load("res://data/items/helmet_basic.tres"), 0.95)
	equipped.aristas.clear()
	equipped.place = &"hero"
	equipped.cell = Vector2i.ZERO
	var stored := CraftedItem.new(load("res://data/items/sword_advanced.tres"), 0.8)
	stored.place = &"bag"
	stored.rot = 1
	var legacy := {"hero_grid": [6, 6], "materials": {"gold": 237}, "crafted_items": [equipped.to_dict(), stored.to_dict()]}
	im.load_save_data(legacy)
	expect(im.get_bag_items().is_empty(), "la mochila antigua se vacía al cargar")
	expect(im.get_loot_count() == 1, "la pieza antigua pasa al botín")
	expect(im.get_hero_items().size() == 1, "el equipo colocado se conserva")
	expect(im.get_crafted_items().size() == 2 and im.get_quantity(&"gold") == 237, "se conservan piezas y oro")
	if not im.get_loot().is_empty():
		var migrated: CraftedItem = im.get_loot()[0]
		expect(migrated.rot == 1 and is_equal_approx(migrated.quality, stored.quality), "se conservan giro y calidad")
	var saved: Dictionary = im.to_save_data()
	im.load_save_data(saved)
	expect(im.get_crafted_items().size() == 2 and im.get_loot_count() == 1, "la migración es idempotente al guardar y cargar")
	var helmet: CraftedItem = im.get_hero_items()[0]
	var outside: Dictionary = im.drop_result(helmet, &"hero", Vector2i(-1, 0), 0)
	expect(not outside.ok and outside.reason == "outside", "un rechazo identifica el borde de la rejilla")
	expect(not im.move_item(helmet, &"bag"), "la mochila retirada no admite piezas nuevas")
	var panel: Control = load("res://scenes/UI/EquipmentPanel.tscn").instantiate()
	root.add_child(panel)
	panel._im = im
	panel.open()
	var position: Vector2 = panel._hero_view.global_position + Vector2(55, 55)
	panel._on_press(position)
	panel._on_release(position)
	expect(panel._selected == helmet and helmet.rot == 0, "principal selecciona sin girar")
	panel._secondary_at(position)
	expect(helmet.rot == 1, "secundario gira la pieza colocada")
	panel._on_press(position)
	panel._on_motion(position + Vector2(20, 0))
	expect(panel._dragging, "principal inicia el arrastre")
	var before: int = panel._drag_rot
	var secondary := InputEventMouseButton.new()
	secondary.button_index = MOUSE_BUTTON_RIGHT
	secondary.pressed = true
	secondary.position = position
	panel._input(secondary)
	expect(panel._drag_rot == (before + 1) % 4, "secundario gira durante el arrastre")
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	var touch_rot: int = panel._drag_rot
	panel._input(touch)
	# Gesto provisional del móvil (sin botón secundario, rueda ni R): un segundo dedo gira mientras el primero arrastra
	expect(panel._drag_rot == (touch_rot + 1) % 4, "un segundo dedo gira durante el arrastre")
	panel.close()
	panel.queue_free()
	print("PRESENTATION_TESTS: %d comprobaciones, %d fallos" % [checks, failures])
	im.queue_free()
	quit(1 if failures else 0)
