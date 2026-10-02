extends Node
## 🎥 Arnés de captura visual (solo desarrollo).
## Instancia Main.tscn y ejecuta un "plan" de acciones para poder grabar el juego con
## --write-movie sin interacción humana. No afecta al juego normal.
##
## Uso:
##   godot --path . --write-movie out/f.png --fixed-fps 10 --quit-after 200 res://scenes/tests/VisualCapture.tscn -- --plan=craft
## Opciones:
##   --locale=xx → idioma de la captura (es, en…): se pone antes de instanciar Main, como haría el móvil.
##                 Sin él se usa el del sistema.
## Planes:
##   start  → solo la pantalla de inicio (StartScreen), sin Main
##   main   → solo arranca Main y deja al héroe luchar
##   craft  → acepta el primer pedido y va tocando la pantalla para jugar los minijuegos
##   boss   → salta al nivel 9 para ver la llegada del jefe
##   death  → quita vida al héroe para ver muerte + respawn (sin habilidades: Segunda oportunidad lo dejaría en pie)
##   potions → compra Velocidad y Suerte (a los huecos), las bebe al aparecer un jefe y bebe la Vida al bajar del 30 %;
##             fuerza el botín doble y adelanta el final de la Velocidad para ver su parpadeo y cómo desaparece
##             (sala 2, combate normal)
##   unlock → hito de rango en el jefe de la sala 20: cartel «¡Planos avanzados!», 4 pergaminos escalonados y, detrás, «¡La rejilla crece!»
##   shop   → abre la tienda y enseña sus pestañas una a una (materiales, pociones y venta)
##   wall   → muro y farmeo: cae en la sala 14, farmea la 13 con «Muro: sala 14» y el selector lo lleva a la 4
##   inventory → rejilla de 6×6 con piezas (una legendaria, la maestra de rango II, y una con aristas), mochila, botín y 2 pociones de Vida; arrastra
##               una pieza del botín hasta Tico con intercambio y abre la ficha de la legendaria
##   ranks  → pedidos con numeral y materiales de bioma, biblioteca con el selector de rango y, en el Santuario del Vacío
##            (sala 45), botín con fragmento de vacío y el cartel «¡Planos avanzados II!»

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const START_SCENE := preload("res://scenes/UI/StartScreen.tscn")

var _plan := "main"
var _main: Node
var _tap_timer: Timer

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plan="):
			_plan = arg.trim_prefix("--plan=")
		elif arg.begins_with("--locale="):
			TranslationServer.set_locale(arg.trim_prefix("--locale="))
	print("[VisualCapture] plan=%s locale=%s" % [_plan, TranslationServer.get_locale()])
	if _plan == "start":
		add_child(START_SCENE.instantiate())
		return
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
		"shop":
			_run_shop_plan()
		"wall":
			_run_wall_plan()
		"inventory":
			_run_inventory_plan()
		"ranks":
			_run_ranks_plan()


func _hud() -> Node:
	return _main.get_node_or_null("HUDLayer/HUD_Main")


## Tumba a Tico de un golpe mortal. Con una Segunda oportunidad legendaria en su rejilla se quedaría en pie
## («¡OTRA VEZ!») y la captura no enseñaría la caída: se le quitan las habilidades hasta que reaparece (reset_stats las
## vuelve a leer), sin tocar su equipo ni su aspecto ni la partida.
func _knock_down(hero: Node) -> void:
	hero.power = LegendaryPowers.effects([])
	hero._second_chance_ready = false
	hero.take_damage(hero.hp * 10, true)


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
		_knock_down(hero)


func _run_unlock_plan() -> void:
	# Hito de rangos (spec de rangos, apartado 3): bloquea los avanzados, vacía la rejilla de Tico (sin ampliaciones) y
	# lleva a Tico (invencible) al jefe de la sala 20 con el récord en ella. Su muerte da el cartel del hito y, en cola
	# detrás de él, el aviso «¡La rejilla crece!» de la ampliación provisional.
	await get_tree().create_timer(1.0).timeout
	var dm := get_node_or_null("/root/DataManager")
	var gm := get_node_or_null("/root/GameManager")
	var im := get_node_or_null("/root/InventoryManager")
	if dm == null or gm == null or im == null:
		return
	for id in dm.get_blueprint_ids_for_tier(Ranks.TIER_ADVANCED):
		dm.unlocked_ranks[id] = 0
	im.clear()
	var hero: Node = gm.get_hero()
	if hero:
		hero.set_invincible(true)
	gm.wall_room = 0
	gm.room_locked = false
	gm.best_enemy_level = 19
	gm.current_enemy_level = 19
	gm.advance_enemy_level()  # sala 20, récord 20: su jefe aún no ha caído


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


func _run_shop_plan() -> void:
	# Tienda pestaña a pestaña: materiales, pociones (descripciones) y venta (tarjetas con estadísticas)
	var hud := _hud()
	if hud == null:
		return
	await get_tree().create_timer(1.0).timeout
	hud._on_shop_pressed()
	var tabs: TabContainer = hud.shop_panel._tab_container
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		await get_tree().create_timer(2.5).timeout


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
	# Pociones compradas por la tienda de verdad (cobro y huecos) y bebidas solas (efecto e indicadores del HUD) con la
	# tirada de Suerte siempre a favor para ver el botín doble en cada muerte. No depende de la copia de la partida: los
	# huecos se vacían antes, se quita el muro y Tico llega con la vida llena al pulso
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
	inv.consumables = inv._empty_slots()
	var shop: Node = hud.shop_panel
	# Dos de Velocidad: la segunda se queda en el hueco y sale en la línea de pociones que quedan, bajo los efectos
	for pot_id in [&"potion_speed", &"potion_speed", &"potion_luck"]:
		shop._on_buy_potion(pot_id, int(ShopPanel.POTION_CATALOG[pot_id].price))
	await get_tree().create_timer(1.0).timeout  # comprar no aplica nada: solo se ven las pociones en la franja
	# Aparece un "jefe": se beben Velocidad y Suerte solas (indicadores con su tiempo). Delante de un muro sin candado no
	# se beben, y la copia de la partida puede tener uno: se quita
	gm._set_wall(0)
	gm.on_boss_appeared()
	# Pociones de Vida con Tico herido: se bebe sola al bajar del 30 % (+N verde sobre él) y queda otra en el hueco
	await get_tree().create_timer(1.5).timeout
	for i in 2:
		shop._on_buy_potion(&"potion_heal", int(ShopPanel.POTION_CATALOG[&"potion_heal"].price))
	await get_tree().create_timer(1.5).timeout
	var hero: Node = gm.get_hero()
	if hero and hero.alive:
		hero.hp = hero.max_hp  # a mitad de un combate, el pulso podría matarlo: con la vida llena se queda en el 25 %
		hero.take_damage(int(hero.max_hp * 0.75), true)
	# Adelanta el reloj: a la Velocidad le quedan 4 s (parpadea y luego desaparece)
	await get_tree().create_timer(4.5).timeout
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


func _run_wall_plan() -> void:
	# Muro y farmeo (spec de rangos, apartado 7): Tico cae en la sala 14 y farmea la 13 con el candado
	# abierto; después el selector lo lleva a la 4, con el candado cerrado
	await get_tree().create_timer(1.5).timeout
	var gm := get_node_or_null("/root/GameManager")
	var hero: Node = gm.get_hero() if gm else null
	if gm == null or hero == null:
		return
	gm.best_enemy_level = maxi(gm.best_enemy_level, 14)
	gm.travel_to_room(14)
	await get_tree().create_timer(2.5).timeout
	_knock_down(hero)
	await get_tree().create_timer(3.5).timeout
	gm.set_room_locked(false)
	await get_tree().create_timer(4.0).timeout
	gm.travel_to_room(4)


func _run_inventory_plan() -> void:
	await get_tree().create_timer(1.0).timeout
	var hud := _hud()
	var im := get_node_or_null("/root/InventoryManager")
	if hud == null or im == null:
		return
	im.clear()
	for id in GridExpansions.ids():
		im.apply_grid_expansion(id)
	im.consumables[0] = {"id": &"potion_heal", "count": 2}  # un hueco con dibujo y el otro libre
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Pieza nueva con sus aristas. En una rejilla va a `cell` si cabe allí y, si no, al primer sitio libre
	var add := func(id: StringName, quality: float, place: StringName, cell: Vector2i) -> CraftedItem:
		var res: ItemResource = load("res://data/items/%s.tres" % id)
		var item := CraftedItem.new(res, quality)
		item.aristas = PieceShape.roll_aristas(res, item.get_quality_tier(), rng)
		im.add_crafted_item(item)
		var grid: GearGrid = im.grid_for(place)
		if grid:
			var spot: Dictionary = {"cell": cell, "rot": 0} if grid.fits(item, cell, 0) else GearPacker.find_spot(grid, item)
			if not spot.is_empty():
				im.move_item(item, place, spot.cell, spot.rot)
		return item
	var legend: CraftedItem = add.call(&"sword_masterwork", 1.0, InventoryManager.PLACE_HERO, Vector2i(5, 0))  # legendaria (Filo ígneo), de pie en la columna derecha
	legend.rank = 2  # rango II: la ficha enseña «… II» (solo el nombre: la captura no mira sus números)
	add.call(&"shield_master", 0.95, InventoryManager.PLACE_HERO, Vector2i(0, 2))
	add.call(&"helmet_master", 0.8, InventoryManager.PLACE_HERO, Vector2i(1, 0))  # rara: 1 arista
	add.call(&"boots_master", 0.95, InventoryManager.PLACE_HERO, Vector2i(2, 3))
	add.call(&"shield_basic", 0.6, InventoryManager.PLACE_BAG, Vector2i(0, 0))
	add.call(&"boots_basic", 0.3, InventoryManager.PLACE_LOOT, Vector2i.ZERO)
	add.call(&"helmet_advanced", 1.0, InventoryManager.PLACE_LOOT, Vector2i.ZERO)
	var fresh: CraftedItem = add.call(&"sword_advanced", 0.93, InventoryManager.PLACE_LOOT, Vector2i.ZERO)  # épica, sin aristas
	hud._on_delivery_pressed()
	await get_tree().create_timer(2.5).timeout  # las tres del botín caen en la caja, una tras otra
	var panel: Node = hud.equipment_panel
	var box: LootBoxView = panel._loot_box
	# Arrastre: la espada nueva, de la caja a la columna derecha de Tico. Al cogerla se endereza; con la R se pone de pie
	# y cae encima de la maestra: se intercambian y la maestra vuelve al botín, cayendo desde arriba.
	var start: Vector2 = box.piece_global_point(fresh)
	panel._on_press(start)
	var turns := (4 - int(panel._press.rot)) % 4  # giros de R hasta dejarla de pie: la espada avanzada (1×3) lo está en el giro 0
	var grab: Vector2 = panel._press.origin - panel._press.pos
	var finish: Vector2 = panel._hero_view.global_position + Vector2(5, 0) * GearGridView.CELL - grab + Vector2(0.0, GearGridView.CELL)
	for i in 12:
		panel._on_motion(start.lerp(finish, float(i + 1) / 12.0))
		if i in [4, 6, 8] and turns > 0:
			panel._rotate_drag()
			turns -= 1
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(1.0).timeout  # destino en verde, intercambio y cambio de estadísticas
	panel._on_release(finish)
	await get_tree().create_timer(2.0).timeout  # la maestra cae en la caja
	# Ficha completa de la maestra legendaria, ya en la caja. La pulsación larga mide tiempo real (Time.get_ticks_msec) y
	# la grabación va más deprisa que el reloj: se adelanta la hora de la pulsación en vez de esperarla
	var legend_point: Vector2 = box.piece_global_point(legend)
	panel._on_press(legend_point)
	panel._press.time = Time.get_ticks_msec() - 1000
	await get_tree().create_timer(0.6).timeout
	panel._on_release(legend_point)


func _run_ranks_plan() -> void:
	# Rangos (spec de rangos): pedidos con numeral y materiales de bioma, biblioteca con el selector de
	# rango y, en el Santuario del Vacío, botín con fragmento de vacío y el cartel de un hito
	await get_tree().create_timer(1.0).timeout
	var dm := get_node_or_null("/root/DataManager")
	var gm := get_node_or_null("/root/GameManager")
	var rm := get_node_or_null("/root/RequestsManager")
	var inv := get_node_or_null("/root/InventoryManager")
	var hud := _hud()
	if dm == null or gm == null or rm == null or inv == null or hud == null:
		return
	for id in dm.get_blueprint_ids_for_tier(Ranks.TIER_BASIC):
		dm.unlock_rank(id, 2)
	dm.unlock_rank(&"sword_advanced", 2)
	var mats: Array = ["wood", "iron", "leather", "cloth", "fire", "water", "ice", "poison"]
	for mat_id in Ranks.BIOME_MATERIALS:
		mats.append(String(mat_id))
	for mat in mats:
		inv.add_item(StringName(mat), 60)
	rm.refresh_all_requests()
	await get_tree().create_timer(2.0).timeout
	hud._on_blueprints_pressed()
	await get_tree().create_timer(3.0).timeout
	if hud.blueprint_library and hud.blueprint_library.has_method("close"):
		hud.blueprint_library.close()
	var hero: Node = gm.get_hero()
	if hero:
		hero.set_invincible(true)
	hud.get_corridor().enemy.biome_drop_chance = 1.0
	gm.wall_room = 0
	gm.room_locked = false
	gm.current_enemy_level = 44
	gm.advance_enemy_level()  # sala 45, Santuario del Vacío
	await get_tree().create_timer(2.0).timeout
	gm.blueprints_milestone.emit(2, Ranks.TIER_ADVANCED, [])
