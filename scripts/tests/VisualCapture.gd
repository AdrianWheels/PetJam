extends Node
## 🎥 Arnés de captura visual (solo desarrollo).
## Instancia Main.tscn y ejecuta un "plan" de acciones para poder grabar el juego con
## --write-movie sin interacción humana. No afecta al juego normal.
##
## Uso:
##   godot --path . --write-movie out/f.png --fixed-fps 10 --quit-after 200 res://scenes/tests/VisualCapture.tscn -- --plan=craft
## Planes:
##   main   → solo arranca Main y deja al héroe luchar
##   craft  → acepta el primer pedido y va tocando la pantalla para jugar los minijuegos
##   boss   → salta al nivel 9 para ver la llegada del jefe
##   death  → quita vida al héroe para ver muerte + respawn
##   potions → compra Velocidad, Suerte y Vida en la tienda, fuerza el botín doble y adelanta el
##             final de la Velocidad para ver su parpadeo y cómo desaparece (sala 2, combate normal)

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _plan := "main"
var _main: Node
var _tap_timer: Timer

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plan="):
			_plan = arg.trim_prefix("--plan=")
	print("[VisualCapture] plan=%s" % _plan)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	match _plan:
		"craft":
			_run_craft_plan()
		"boss":
			_run_boss_plan()
		"death":
			_run_death_plan()
		"unlock":
			_run_unlock_plan()
		"biome":
			_run_biome_plan()
		"panels":
			_run_panels_plan()
		"result":
			_run_result_plan()
		"tour":
			_run_tour_plan()
		"title":
			_run_title_plan()
		"potions":
			_run_potions_plan()


func _hud() -> Node:
	return _main.get_node_or_null("HUDLayer/HUD_Main")


func _run_craft_plan() -> void:
	await get_tree().create_timer(3.0).timeout
	var inv := get_node_or_null("/root/InventoryManager")
	if inv:
		for mat in ["wood", "iron", "leather", "cloth", "herb", "fire", "water", "ice", "poison"]:
			inv.add_item(StringName(mat), 50)
	var hud := _hud()
	if hud and hud.has_method("_on_request_slot_clicked"):
		hud._on_request_slot_clicked(0)
	_tap_timer = Timer.new()
	_tap_timer.wait_time = 0.55
	_tap_timer.timeout.connect(_tap_center)
	add_child(_tap_timer)
	await get_tree().create_timer(1.5).timeout
	_tap_timer.start()


func _tap_center() -> void:
	# Coordenadas de ventana (el stretch canvas_items las transforma al viewport 1080x1920)
	var pos := Vector2(DisplayServer.window_get_size()) * 0.5
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	await get_tree().create_timer(0.12).timeout
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)


func _run_boss_plan() -> void:
	await get_tree().create_timer(2.0).timeout
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.current_enemy_level = 8
		gm.advance_enemy_level()


func _run_death_plan() -> void:
	await get_tree().create_timer(3.0).timeout
	var gm := get_node_or_null("/root/GameManager")
	var hero: Node = gm.get_hero() if gm else null
	if hero and hero.has_method("take_damage"):
		hero.take_damage(hero.hp * 10, true)


func _run_unlock_plan() -> void:
	# Bloquea un plano y olvida las victorias para que la próxima muerte lo desbloquee
	await get_tree().create_timer(1.0).timeout
	var dm := get_node_or_null("/root/DataManager")
	var gm := get_node_or_null("/root/GameManager")
	if dm:
		dm.unlocked_blueprints[&"helmet_master"] = false
		dm.unlocked_blueprints[&"boots_master"] = false
	if gm:
		gm.enemies_defeated.clear()


func _run_biome_plan() -> void:
	# Salta al final del primer bioma para ver jefe → cambio de bioma
	await get_tree().create_timer(1.5).timeout
	var gm := get_node_or_null("/root/GameManager")
	var hero: Node = gm.get_hero() if gm else null
	if hero:
		hero.set_invincible(true)
	if gm:
		gm.current_enemy_level = 9
		gm.advance_enemy_level()


func _run_panels_plan() -> void:
	# Abre cada panel unos segundos: tienda → equipo → planos (para revisar su aspecto)
	var hud := _hud()
	if hud == null:
		return
	await get_tree().create_timer(1.5).timeout
	hud._on_shop_pressed()
	await get_tree().create_timer(2.5).timeout
	if hud.shop_panel and hud.shop_panel.has_method("close"):
		hud.shop_panel.close()
	else:
		hud.shop_panel.visible = false
	await get_tree().create_timer(0.5).timeout
	hud._on_delivery_pressed()
	await get_tree().create_timer(2.5).timeout
	if hud.equipment_panel and hud.equipment_panel.has_method("close"):
		hud.equipment_panel.close()
	else:
		hud.equipment_panel.visible = false
	await get_tree().create_timer(0.5).timeout
	hud._on_blueprints_pressed()


func _run_result_plan() -> void:
	# Muestra directamente la pantalla de resultado con una pieza de alta calidad
	await get_tree().create_timer(1.0).timeout
	var hud := _hud()
	var dm := get_node_or_null("/root/DataManager")
	if hud == null or dm == null:
		return
	var quality := 0.93
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			quality = float(arg.trim_prefix("--quality="))
	var item_res: ItemResource = dm.get_item_resource(&"sword_masterwork")
	var item := CraftedItem.new(item_res, quality)
	hud._show_craft_result({
		"quality": quality, "grade": "gold" if quality >= 0.9 else "silver",
		"blueprint_id": &"sword_masterwork", "crafted_item": item,
		"forjamagia": 7, "forjamagia_bonus": 0.1,
	})


func _run_tour_plan() -> void:
	# Recorre los biomas: héroe invencible y saltos de sala cada pocos segundos
	await get_tree().create_timer(1.0).timeout
	var gm := get_node_or_null("/root/GameManager")
	var hero: Node = gm.get_hero() if gm else null
	if hero:
		hero.set_invincible(true)
	for room in [3, 20, 22, 30, 33, 42, 50]:
		if gm:
			gm.current_enemy_level = room - 1
			gm.advance_enemy_level()
		await get_tree().create_timer(5.0).timeout


func _run_potions_plan() -> void:
	# Pociones compradas por la tienda de verdad (cobro, efecto e indicador del HUD) con la tirada de
	# Suerte siempre a favor para ver el botín doble en cada muerte
	await get_tree().create_timer(1.5).timeout
	var gm := get_node_or_null("/root/GameManager")
	var inv := get_node_or_null("/root/InventoryManager")
	var hud := _hud()
	if gm == null or inv == null or hud == null:
		return
	gm.current_enemy_level = 1
	gm.advance_enemy_level()  # sala 2: combates cortos
	var corridor: Node = hud.get_corridor()
	corridor.enemy.luck_roll = func() -> float: return 0.0
	inv.add_item(&"gold", 1000)
	var shop: Node = hud.shop_panel
	for pot_id in [&"potion_speed", &"potion_luck"]:
		shop._on_buy_potion(pot_id, int(ShopPanel.POTION_CATALOG[pot_id].price))
	# Poción de Vida con Tico herido, mientras camina hacia el primer enemigo: +N verde sobre él
	await get_tree().create_timer(1.5).timeout
	var hero: Node = gm.get_hero()
	if hero and hero.alive:
		hero.take_damage(int(hero.max_hp * 0.4), true)
		shop._on_buy_potion(&"potion_heal", int(ShopPanel.POTION_CATALOG[&"potion_heal"].price))
	# Adelanta el reloj: a la Velocidad le quedan 4 s (parpadea y luego desaparece)
	await get_tree().create_timer(7.5).timeout
	gm.tick_buffs(gm.buff_remaining(&"speed") - 4.0)


func _run_title_plan() -> void:
	# Acepta un pedido y no toca: se ve el título del minijuego desvanecerse solo
	await get_tree().create_timer(2.0).timeout
	var inv := get_node_or_null("/root/InventoryManager")
	if inv:
		for mat in ["wood", "iron", "leather", "cloth", "herb", "fire", "water", "ice", "poison"]:
			inv.add_item(StringName(mat), 50)
	var hud := _hud()
	if hud and hud.has_method("_on_request_slot_clicked"):
		hud._on_request_slot_clicked(0)
