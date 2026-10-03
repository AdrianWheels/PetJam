extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas del botín con física (spec doc/specs/2026-10-02-botin-con-fisica.md), solo desarrollo, sin ventana y con la
## física de verdad. Con --fixed-fps 60 cada paso de física es 1/60 s de juego y no se espera tiempo real:
##   D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn

const CELL := GearGridView.CELL
const ITEM_IDS := [&"sword_basic", &"sword_advanced", &"sword_masterwork", &"shield_basic",
	&"shield_advanced", &"shield_master", &"helmet_basic", &"helmet_advanced", &"helmet_master",
	&"boots_basic", &"boots_advanced", &"boots_master"]


func _res(id: StringName) -> ItemResource:
	return load("res://data/items/%s.tres" % id)


## Pieza de prueba con calidad y aristas fijas (sin sorteo). Con 0,95 es épica: sin aristas.
func _piece(id: StringName, quality: float = 0.95, aristas: Array[Vector2i] = []) -> CraftedItem:
	var item := CraftedItem.new(_res(id), quality)
	item.aristas = aristas
	return item


## true si dos listas de rectángulos son las mismas, en cualquier orden (con margen de redondeo).
func _same_rects(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var left := b.duplicate()
	for r in a:
		var found := -1
		for i in left.size():
			if r.is_equal_approx(left[i]):
				found = i
				break
		if found < 0:
			return false
		left.remove_at(found)
	return true


# ─── Tarea 1: rectángulos de colisión ──────────────────────────────────

func test_collision_rects_cover_the_cells_in_every_turn() -> void:
	for id in ITEM_IDS:
		var aristas: Array[Vector2i] = []
		aristas.assign(_res(id).arista_spots.slice(0, 2))  # una pieza básica: 2 aristas, que también chocan
		var item := _piece(id, 0.3, aristas)
		for rot in 4:
			var fp := PieceShape.of_item(item, rot)
			var com := PieceShape.mass_center(fp, CELL)
			var rects := PieceShape.collision_rects(fp, CELL)
			var want := []
			for c in fp.clean + fp.aristas:
				want.append(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)))
			var got := []
			var sum := Vector2.ZERO
			for r in rects:
				got.append(Rect2(r.position + com, r.size))
				sum += r.get_center()
			check(_same_rects(got, want), "%s giro %d: un rectángulo por casilla, aristas incluidas (%s)" % [id, rot, rects])
			check(sum.length() < 0.01, "%s giro %d: centrados en su centro de masa (%s)" % [id, rot, sum])
			check(rects[0].is_equal_approx(Rect2(Vector2(fp.clean[0]) * CELL - com, Vector2(CELL, CELL))), "%s giro %d: el primero es la primera casilla limpia" % [id, rot])


## Girar el cuerpo un cuarto de vuelta da la misma pieza que girarla en la rejilla: así, al cogerla de la caja enderezada,
## la vista previa cuadra con lo que se veía.
func test_turning_the_body_matches_the_turned_piece() -> void:
	var item := _piece(&"boots_master", 0.3, [Vector2i(1, 1)])
	var base := PieceShape.collision_rects(PieceShape.of_item(item, 0), CELL)
	for rot in 4:
		var turned := []
		for r in base:
			turned.append(Rect2(r.get_center().rotated(rot * PI / 2.0) - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)))
		check(_same_rects(turned, PieceShape.collision_rects(PieceShape.of_item(item, rot), CELL)), "girar %d cuartos el cuerpo da la pieza girada %d" % [rot, rot])


func test_mass_center_is_the_mean_of_the_cells() -> void:
	var sword := _piece(&"sword_basic")  # 1×2 de pie
	check(PieceShape.mass_center(PieceShape.of_item(sword, 0), CELL).is_equal_approx(Vector2(55, 110)), "espada básica: en medio de sus dos casillas")
	check(PieceShape.mass_center(PieceShape.of_item(sword, 1), CELL).is_equal_approx(Vector2(110, 55)), "tumbada, también")
	var boots := _piece(&"boots_master")  # (0,0) (0,1) (0,2) (1,2)
	check(PieceShape.mass_center(PieceShape.of_item(boots, 0), CELL).is_equal_approx(Vector2(0.75, 1.75) * CELL), "botas en L: la media de sus 4 casillas")


# ─── Tarea 2: la pose en la pieza y en el guardado ─────────────────────

func _im() -> Node:
	return get_node("/root/InventoryManager")


## Deja el inventario vacío y devuelve lo que había para restaurarlo.
func _fresh_inventory() -> Dictionary:
	var saved: Dictionary = _im().to_save_data()
	_im().clear()
	return saved


func _restore_inventory(saved: Dictionary) -> void:
	_im().load_save_data(saved, int(get_node("/root/GameManager").best_enemy_level))
	await get_tree().process_frame  # deja pasar los guardados diferidos del cambio


var _save_writes := 0


func _count_save_write() -> void:
	_save_writes += 1


func test_loot_pose_goes_in_the_save_only_in_the_loot() -> void:
	var item := _piece(&"boots_master")
	check(item.loot_pose.is_empty() and not item.to_dict().has("lx"), "una pieza nueva no tiene pose ni la escribe")
	item.loot_pose = {"pos": Vector2(412.5, -80.25), "ang": -1.25}
	var d := item.to_dict()
	check(is_equal_approx(float(d.lx), 412.5) and is_equal_approx(float(d.ly), -80.25) and is_equal_approx(float(d.ang), -1.25), "en el botín escribe lx, ly y ang (%s)" % [d])
	var back := CraftedItem.from_dict(JSON.parse_string(JSON.stringify(d)), item.item_resource)
	check(back.loot_pose.get("pos", Vector2.INF).is_equal_approx(Vector2(412.5, -80.25)) and is_equal_approx(float(back.loot_pose.get("ang", 0.0)), -1.25), "y vuelve igual del fichero (%s)" % [back.loot_pose])
	item.place = &"bag"
	check(not item.to_dict().has("lx") and not item.to_dict().has("ang"), "fuera del botín no se escribe")
	var plain := d.duplicate()
	for key in ["lx", "ly", "ang"]:
		plain.erase(key)
	check(CraftedItem.from_dict(plain, item.item_resource).loot_pose.is_empty(), "una partida sin los campos carga sin pose")
	for bad in [{"lx": "a", "ly": 1, "ang": 0}, {"lx": 1.0, "ly": 2.0}, {"lx": 1.0, "ly": null, "ang": 0.0}, {"lx": INF, "ly": 0.0, "ang": 0.0}]:
		var with_bad := plain.duplicate()
		with_bad.merge(bad, true)
		check(CraftedItem.from_dict(with_bad, item.item_resource).loot_pose.is_empty(), "valores que no son números se descartan (%s)" % [bad])
	check(CraftedItem.pose_from_dict({"lx": 3, "ly": 4, "ang": 0}) == {"pos": Vector2(3, 4), "ang": 0.0}, "los enteros valen")


func test_inventory_keeps_loot_poses_and_forgets_them_outside_the_loot() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var a := _piece(&"shield_master")
	var b := _piece(&"helmet_basic")
	im.add_crafted_item(a)
	im.add_crafted_item(b)
	a.loot_pose = {"pos": Vector2(300, 274), "ang": 0.5}
	b.loot_pose = {"pos": Vector2(700, 384), "ang": 0.0}
	var data: Dictionary = JSON.parse_string(JSON.stringify(im.to_save_data()))
	im.load_save_data(data, 1)
	var by_id := {}
	for it in im.get_crafted_items():
		by_id[it.item_resource.item_id] = it
	var shield: CraftedItem = by_id[&"shield_master"]
	var helmet: CraftedItem = by_id[&"helmet_basic"]
	check(shield.loot_pose.get("pos", Vector2.INF).is_equal_approx(Vector2(300, 274)) and is_equal_approx(float(shield.loot_pose.get("ang", 0.0)), 0.5), "la pose vuelve al cargar la partida (%s)" % [shield.loot_pose])
	im.move_item(helmet, &"hero", Vector2i(0, 0), 0)
	check(helmet.loot_pose.is_empty(), "al salir del botín la pieza pierde su pose")
	im.move_item(helmet, &"loot")
	check(helmet.loot_pose.is_empty() and helmet in im.get_loot(), "y vuelve al botín sin pose: caerá desde arriba")
	await _restore_inventory(saved)


## Las poses nuevas piden el guardado diferido de siempre: varios avisos en un fotograma son una sola escritura. Se cambia el
## escritor por uno que solo cuenta: la prueba no escribe ninguna partida.
func test_new_loot_poses_ask_for_one_deferred_save() -> void:
	var gm := get_node("/root/GameManager")
	gm.save_writer = Callable(self, "_count_save_write")
	for i in 2:
		await get_tree().process_frame
	_save_writes = 0
	_im().note_loot_poses()
	_im().note_loot_poses()
	for i in 2:
		await get_tree().process_frame
	check(_save_writes == 1, "dos avisos de poses en un fotograma, una escritura (%d)" % _save_writes)
	gm.save_writer = Callable()


# ─── Tarea 3: una pieza con física ─────────────────────────────────────

## Avanza la física paso a paso hasta que `done` dé true. Devuelve los pasos que hicieron falta, o -1 si pasan `limit`.
func _physics_until(done: Callable, limit: int) -> int:
	for i in limit:
		await get_tree().physics_frame
		if done.call():
			return i + 1
	return -1


func _physics_steps(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Soporte con un suelo de pega en y = 440 (coordenadas del soporte), en la capa de las paredes de la caja.
func _floor_holder() -> Node2D:
	var holder := Node2D.new()
	holder.position = Vector2(60, 970)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = LootPiece.LAYER_WALLS
	floor_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000, 400)
	cs.shape = shape
	cs.position = Vector2(480, 640)
	floor_body.add_child(cs)
	holder.add_child(floor_body)
	add_child(holder)
	return holder


func _loot_piece(id: StringName, pos: Vector2, angle: float = 0.0, aristas: Array[Vector2i] = []) -> LootPiece:
	var body := LootPiece.new()
	body.setup(_piece(id, 0.95, aristas))
	body.transform = Transform2D(angle, pos)
	return body


func test_loot_piece_has_one_shape_per_cell_and_its_mass() -> void:
	var holder := _floor_holder()
	var body := _loot_piece(&"shield_master", Vector2(300, 100), 0.0, [Vector2i(2, 1)])  # 6 casillas y 1 arista
	holder.add_child(body)
	var shapes := body.get_children().filter(func(n): return n is CollisionShape2D)
	check(shapes.size() == 7 and body.rects.size() == 7, "un rectángulo por casilla, la arista incluida (%d)" % shapes.size())
	check(is_equal_approx(body.mass, 7.0 * LootPiece.MASS_PER_CELL), "masa proporcional a las casillas (%.1f)" % body.mass)
	check(is_equal_approx(LootPiece.BOX_CELL, 55.0) and body.rects.all(func(r): return r.size == Vector2(55, 55)), "en la caja, cada casilla choca a media escala: 55 px")
	check(body.collision_layer == LootPiece.LAYER_PIECES and body.collision_mask == LootPiece.LAYER_WALLS | LootPiece.LAYER_PIECES, "choca con la caja y con las demás piezas")
	check(not body.is_ghost and is_equal_approx(body.modulate.a, 1.0), "empieza sin ser fantasma")
	holder.queue_free()
	await get_tree().physics_frame


func test_loot_piece_falls_and_sleeps_on_the_floor() -> void:
	var holder := _floor_holder()
	var body := _loot_piece(&"helmet_master", Vector2(300, 0), 0.4)
	holder.add_child(body)
	var frames: int = await _physics_until(func(): return body.sleeping, 900)
	check(frames > 0, "cae y se queda quieta en menos de 15 s (%d pasos)" % frames)
	check(absf(body.bounds().end.y - 440.0) < 4.0, "apoyada en el suelo (fondo en %.1f)" % body.bounds().end.y)
	holder.queue_free()
	await get_tree().physics_frame


func test_a_ghost_falls_through_pieces_but_not_the_floor() -> void:
	var holder := _floor_holder()
	var below := _loot_piece(&"shield_advanced", Vector2(300, 384))  # 2×2 a 55 px: centro a 55 px del suelo
	var ghost := _loot_piece(&"shield_advanced", Vector2(300, 0))
	holder.add_child(below)
	holder.add_child(ghost)
	ghost.set_ghost(true)
	check(ghost.is_ghost and ghost.collision_layer == LootPiece.LAYER_GHOSTS and ghost.collision_mask == LootPiece.LAYER_WALLS, "el fantasma solo choca con la caja")
	check(is_equal_approx(ghost.modulate.a, LootPiece.GHOST_ALPHA), "y se dibuja semitransparente")
	var frames: int = await _physics_until(func(): return ghost.sleeping and below.sleeping, 900)
	check(frames > 0, "los dos se quedan quietos (%d pasos)" % frames)
	check(ghost.position.distance_to(below.position) < 10.0, "el fantasma atraviesa la pieza y se queda solapado con ella (%s, %s)" % [ghost.position, below.position])
	check(ghost.bounds().end.y <= 444.0 and below.position.distance_to(Vector2(300, 384)) < 3.0, "sin atravesar el suelo ni empujar a la otra")
	ghost.set_ghost(false)
	check(not ghost.is_ghost and ghost.collision_layer == LootPiece.LAYER_PIECES and is_equal_approx(ghost.modulate.a, 1.0), "al salir del modo fantasma vuelve a chocar y a verse entera")
	holder.queue_free()
	await get_tree().physics_frame


func test_points_bounds_and_the_nearest_quarter_turn() -> void:
	var holder := _floor_holder()
	var sword := _loot_piece(&"sword_basic", Vector2(200, 200), PI / 2.0)  # tumbada a 55 px: 110 de ancho (145 a 255) y 55 de alto (172,5 a 227,5)
	holder.add_child(sword)
	check(sword.contains_point(Vector2(150, 200)) and sword.contains_point(Vector2(250, 200)), "tumbada, ocupa de lado")
	check(not sword.contains_point(Vector2(200, 150)) and not sword.contains_point(Vector2(100, 200)), "y no por arriba ni más allá de su media escala")
	check(sword.bounds().is_equal_approx(Rect2(145, 172.5, 110, 55)), "su caja girada, a media escala (%s)" % sword.bounds())
	check(is_equal_approx(sword.top_y(), 172.5), "su punto más alto")
	for pair in [[0.2, 0], [1.3, 1], [-0.1, 0], [3.0, 2], [-1.6, 3], [4.6, 3], [6.2, 0]]:
		sword.rotation = pair[0]
		check(sword.straight_rot() == pair[1], "ángulo %.1f → %d cuartos (%d)" % [pair[0], pair[1], sword.straight_rot()])
	check(LootPiece.extent(sword.rects, 0.0).is_equal_approx(Rect2(-27.5, -55, 55, 110)), "de pie, su caja alrededor del centro de masa (%s)" % LootPiece.extent(sword.rects, 0.0))
	holder.queue_free()
	await get_tree().physics_frame


# ─── Tarea 4: la caja ──────────────────────────────────────────────────

## Caja en su sitio del panel (60, 970), activa y con el azar fijo.
func _new_box() -> LootBoxView:
	var box := LootBoxView.new()
	box.position = Vector2(60, 970)
	box.rng.seed = 11
	add_child(box)
	box.set_active(true)
	return box


func _free_box(box: LootBoxView) -> void:
	box.queue_free()
	await get_tree().physics_frame


func _items(ids: Array) -> Array[CraftedItem]:
	var out: Array[CraftedItem] = []
	for id in ids:
		out.append(_piece(id))
	return out


## true si la pieza está dentro de la caja y por debajo del techo (con 2 px de margen).
func _inside(body: LootPiece) -> bool:
	var r := body.bounds()
	return r.position.x >= -2.0 and r.end.x <= LootBoxView.SIZE.x + 2.0 and r.position.y >= LootBoxView.CEIL_Y - 2.0 and r.end.y <= LootBoxView.SIZE.y + 2.0


## El punto más alto de la pila (el menor top_y).
func _highest_top(box: LootBoxView, list: Array) -> float:
	var top := INF
	for item in list:
		top = minf(top, box.body_of(item).top_y())
	return top


func test_pieces_without_a_pose_fall_one_after_another() -> void:
	var box := _new_box()
	var list := _items([&"helmet_basic", &"boots_basic", &"sword_basic"])
	box.sync(list)
	check(box._bodies.is_empty() and box._queue.size() == 3, "sin pose, esperan su turno para caer (%d en cola)" % box._queue.size())
	var frames: int = await _physics_until(func(): return box._bodies.size() == 1, 3 * LootBoxView.SPAWN_INTERVAL)
	check(frames >= LootBoxView.SPAWN_INTERVAL - 1 and box._queue.size() == 2, "la primera entra al cabo de %d pasos (%d)" % [LootBoxView.SPAWN_INTERVAL, frames])
	var first := box.body_of(list[0])
	check(first != null and first.position.y < 0.0, "y cae desde arriba de la caja (y %.0f)" % (first.position.y if first else INF))
	frames = await _physics_until(func(): return box._bodies.size() == 3, 6 * LootBoxView.SPAWN_INTERVAL)  # con margen por si la de arriba aún tapa un intento
	check(frames > 0 and box._queue.is_empty(), "las otras, una tras otra")
	await _free_box(box)


func test_pieces_fall_and_rest_inside_the_box() -> void:
	var box := _new_box()
	var list := _items([&"shield_master", &"sword_masterwork", &"helmet_master", &"boots_master", &"shield_advanced", &"boots_advanced", &"helmet_basic", &"sword_basic"])
	box.sync(list)
	var frames: int = await _physics_until(func(): return box.is_settled(), 1500)
	check(frames > 0, "8 piezas se quedan quietas en menos de 25 s (%d pasos)" % frames)
	check(list.all(func(it): return box.body_of(it) != null and _inside(box.body_of(it))), "todas dentro de la caja y por debajo del techo")
	await _free_box(box)


## Con la caja llena entran fantasmas; al vender las que chocan, los fantasmas vuelven a chocar y se recolocan.
func test_a_full_box_makes_ghosts_and_selling_brings_them_back() -> void:
	var box := _new_box()
	var list: Array[CraftedItem] = []
	for i in 40:
		list.append(_piece(&"shield_master"))  # 2×3 a 55 px: 240 casillas en una caja de unas 190 (con lo de encima del borde)
	box.sync(list)
	var frames: int = await _physics_until(func(): return box.is_settled(), 3000)
	check(frames > 0, "la caja llena se queda quieta (%d pasos)" % frames)
	var ghosts: Array = list.filter(func(it): return box.body_of(it).is_ghost)
	check(ghosts.size() > 0, "con la caja llena hay fantasmas (%d)" % ghosts.size())
	check(_highest_top(box, list) >= LootBoxView.CEIL_Y - 2.0, "nada pasa del techo (%.1f)" % _highest_top(box, list))
	check(ghosts.all(func(it): return is_equal_approx(box.body_of(it).modulate.a, LootPiece.GHOST_ALPHA)), "los fantasmas se ven semitransparentes")
	var keep: Array = ghosts.slice(0, 3)  # se vende todo lo que choca: con 3 escudos sobra sitio
	box.sync(keep)
	frames = await _physics_until(func(): return box.is_settled(), 3000)
	check(frames > 0, "después de vender, la pila vuelve a quedarse quieta (%d pasos)" % frames)
	check(keep.all(func(it): return not box.body_of(it).is_ghost), "los fantasmas vuelven a chocar")
	check(keep.all(func(it): return box.fits(box.body_of(it)) and _inside(box.body_of(it))), "y se recolocan sin solapes, dentro de la caja")
	await _free_box(box)


func test_the_sell_all_button_stays_reachable_under_a_full_pile() -> void:
	var saved := _fresh_inventory()
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var btn: Button = panel.sell_all_btn
	check(btn.get_index() > box.get_index() and panel.loot_title.get_index() > box.get_index(), "el título y «Vender todo» se dibujan sobre la pila")
	check(btn.get_index() < panel._next_label.get_index() and btn.get_index() < panel._ghost_layer.get_index(), "pero por debajo de lo que va encima (ficha, huecos, fantasma)")
	var center := btn.get_global_rect().get_center()
	for ghost in [false, true]:
		var item := _piece(&"shield_master")
		box._make_body(item, Transform2D(0.0, box.to_local(center)), ghost)
		check(box.piece_at(box.to_local(center)) != null, "hay un cuerpo bajo el botón (fantasma: %s)" % ghost)
		panel._press = {}
		_mouse(panel, center, true)
		check(panel._press.is_empty(), "pulsar el botón no coge la pieza de debajo (fantasma: %s)" % ghost)
		_mouse(panel, center, false)
	panel.queue_free()
	await _restore_inventory(saved)


func test_the_next_queued_piece_does_not_inherit_the_blocked_counter() -> void:
	var box := _new_box()
	var list := _items([&"helmet_basic", &"boots_basic", &"sword_basic"])
	box.sync(list)
	box._blocked = LootBoxView.SPAWN_PATIENCE - LootBoxView.SPAWN_INTERVAL
	box.sync(list.slice(1))  # se vende la cabeza de la cola
	check(box._queue[0] == list[1] and box._blocked == 0, "al cambiar la cabeza por sync, la nueva empieza sin espera acumulada (%d)" % box._blocked)
	box._blocked = LootBoxView.SPAWN_PATIENCE - LootBoxView.SPAWN_INTERVAL
	box.hold(list[1])  # la coge el dedo
	check(box._queue[0] == list[2] and box._blocked == 0, "y también al cogerla con el dedo (%d)" % box._blocked)
	box._blocked = 50
	box.sync(list.slice(1))  # la cabeza sigue siendo la misma: no se toca
	check(box._blocked == 50, "si la cabeza no cambia, el contador sigue (%d)" % box._blocked)
	await _free_box(box)


func test_poses_come_back_where_they_were() -> void:
	var box := _new_box()
	var list := _items([&"shield_master", &"helmet_master", &"boots_advanced", &"sword_masterwork"])
	box.sync(list)
	var frames: int = await _physics_until(func(): return box.is_settled(), 2000)
	check(frames > 0, "la pila se queda quieta (%d pasos)" % frames)
	box.collect_poses()
	check(list.all(func(it): return LootBoxView.pose_is_valid(it.loot_pose)), "cada pieza tiene su pose")
	var copies: Array[CraftedItem] = []
	for it in list:
		copies.append(CraftedItem.from_dict(JSON.parse_string(JSON.stringify(it.to_dict())), it.item_resource))
	await _free_box(box)
	var again := _new_box()
	again.sync(copies)
	check(again._queue.is_empty() and again._bodies.size() == 4, "con pose, todas entran a la vez, sin caer desde arriba")
	await _physics_steps(60)
	var worst := 0.0
	for it in copies:
		worst = maxf(worst, again.body_of(it).position.distance_to(it.loot_pose.pos))
	check(worst < 3.0, "y se quedan donde estaban (lo que más se ha movido: %.2f px)" % worst)
	await _free_box(again)


func test_impossible_poses_fall_from_the_top() -> void:
	var out := _piece(&"helmet_basic")
	out.loot_pose = {"pos": Vector2(5000, 100), "ang": 0.0}  # fuera de la caja
	var high := _piece(&"boots_basic")
	high.loot_pose = {"pos": Vector2(400, -400), "ang": 0.0}  # por encima del techo
	var good := _piece(&"sword_basic")
	good.loot_pose = {"pos": Vector2(200, 384), "ang": 0.0}  # de pie en el suelo (a 55 px: de y 329 a 439)
	check(not LootBoxView.pose_is_valid(out.loot_pose) and not LootBoxView.pose_is_valid(high.loot_pose), "fuera de la caja o por encima del techo no vale")
	check(not LootBoxView.pose_is_valid({}) and not LootBoxView.pose_is_valid({"pos": Vector2(NAN, 0), "ang": 0.0}) and not LootBoxView.pose_is_valid({"pos": Vector2(10, 10), "ang": "x"}), "vacía o sin números tampoco")
	check(LootBoxView.pose_is_valid(good.loot_pose), "dentro sí")
	var box := _new_box()
	box.sync([out, high, good])
	check(box.body_of(good) != null and box.body_of(out) == null and box.body_of(high) == null, "la buena entra en su pose; las imposibles, no")
	check(box._queue.size() == 2 and box._queue[0] == out and box._queue[1] == high, "las imposibles esperan para caer desde arriba")
	var frames: int = await _physics_until(func(): return box._queue.is_empty(), 200)
	check(frames > 0 and [out, high, good].all(func(it): return box.body_of(it) != null and _inside(box.body_of(it))), "y ninguna se pierde")
	await _free_box(box)


func test_overlapping_saved_poses_do_not_explode() -> void:
	var a := _piece(&"shield_advanced")
	var b := _piece(&"shield_advanced")
	for it in [a, b]:
		it.loot_pose = {"pos": Vector2(480, 384), "ang": 0.0}  # las dos en el mismo sitio
	var box := _new_box()
	box.sync([a, b])
	check(not box.body_of(a).is_ghost and box.body_of(b).is_ghost, "la segunda, encima de la primera, entra como fantasma")
	await _physics_steps(120)
	check(_inside(box.body_of(a)) and _inside(box.body_of(b)), "las dos siguen dentro de la caja")
	check(box.body_of(a).position.distance_to(Vector2(480, 384)) < 3.0, "y nadie sale despedido (%s)" % box.body_of(a).position)
	await _free_box(box)


func test_taking_out_a_support_lets_the_pile_fall() -> void:
	var below := _piece(&"shield_advanced")
	var above := _piece(&"helmet_basic")
	below.loot_pose = {"pos": Vector2(480, 384), "ang": 0.0}  # 2×2 en el suelo (a 55 px): de y 329 a 439
	above.loot_pose = {"pos": Vector2(480, 300), "ang": 0.0}  # 1×1 encima: de y 272,5 a 327,5
	var box := _new_box()
	box.sync([below, above])
	var frames: int = await _physics_until(func(): return box.is_settled(), 600)
	check(frames > 0, "la pila de dos se queda quieta (%d pasos)" % frames)
	box.sync([above])  # se vende la de abajo
	frames = await _physics_until(func(): return box.is_settled(), 900)
	check(frames > 0 and box.body_of(above).bounds().end.y > LootBoxView.SIZE.y - 4.0, "la de arriba cae al suelo (fondo en %.1f)" % box.body_of(above).bounds().end.y)
	await _free_box(box)


func test_a_piece_dropped_on_the_pile_rises_until_it_fits() -> void:
	var base := _piece(&"shield_advanced")
	base.loot_pose = {"pos": Vector2(480, 384), "ang": 0.0}
	var dropped := _piece(&"helmet_basic")
	var box := _new_box()
	box.sync([base, dropped])
	box.hold(dropped)
	check(box.is_held(dropped) and box.body_of(dropped) == null and box._queue.is_empty(), "cogida: sin cuerpo y fuera de la cola")
	box.drop_at(dropped, Vector2(480, 384), Vector2.ZERO, 0)  # justo encima del escudo: solaparía
	var body := box.body_of(dropped)
	check(body != null and not box.is_held(dropped), "soltada, vuelve a tener cuerpo")
	check(not body.is_ghost and not box._overlaps(body.rects, body.transform, [body.get_rid()]), "sube hasta no solapar")
	check(body.position.y < 320.0 and is_equal_approx(body.position.x, 480.0), "en la misma columna, encima del escudo (%s)" % body.position)
	await _free_box(box)


func test_a_throw_is_capped_and_keeps_its_turn() -> void:
	check(LootBoxView.cap_throw(Vector2(5000, 0)).is_equal_approx(Vector2(LootBoxView.MAX_THROW_SPEED, 0)), "un gesto rápido se queda en el tope")
	check(LootBoxView.cap_throw(Vector2(100, -50)) == Vector2(100, -50), "uno suave no se toca")
	var sword := _piece(&"sword_advanced")
	var box := _new_box()
	box.sync([sword])
	box.hold(sword)
	box.drop_at(sword, Vector2(480, 200), Vector2(0, -9000), 1)
	var body := box.body_of(sword)
	check(body != null and body.position.is_equal_approx(Vector2(480, 200)), "aparece donde se suelta")
	check(body.linear_velocity.length() <= LootBoxView.MAX_THROW_SPEED + 0.01 and body.linear_velocity.length() > LootBoxView.MAX_THROW_SPEED - 1.0, "con la velocidad del gesto, con tope (%.0f)" % body.linear_velocity.length())
	check(is_equal_approx(body.rotation, PI / 2.0), "y con el giro con que se soltó")
	await _free_box(box)


func test_a_closed_box_does_not_move() -> void:
	var helmet := _piece(&"helmet_basic")
	var box := _new_box()
	box.sync([helmet])
	box.hold(helmet)
	box.drop_at(helmet, Vector2(480, 0), Vector2.ZERO, 0)  # en el aire
	var body := box.body_of(helmet)
	box.set_active(false)
	var p0 := body.position
	await _physics_steps(60)
	check(body.position == p0, "con la caja cerrada no cae (%s → %s)" % [p0, body.position])
	box.set_active(true)
	await _physics_steps(60)
	check(body.position.y > p0.y + 50.0, "al abrirla sigue cayendo (%s)" % body.position)
	await _free_box(box)


func test_a_still_pile_reports_its_poses_at_most_once_a_second() -> void:
	var box := _new_box()
	var at: Array[int] = []
	box.poses_settled.connect(func(): at.append(Engine.get_physics_frames()))
	var list := _items([&"shield_advanced", &"helmet_basic"])
	box.sync(list)
	await _physics_until(func(): return at.size() == 1, 1200)
	check(at.size() == 1, "quieta tras el cambio, avisa una vez (%d)" % at.size())
	check(list.all(func(it): return it.loot_pose.get("pos", Vector2.INF).is_equal_approx(box.body_of(it).position)), "con las poses ya en las piezas")
	box.hold(list[1])
	box.drop_at(list[1], Vector2(700, 300), Vector2.ZERO, 0)
	await _physics_until(func(): return at.size() == 2, 1200)
	check(at.size() == 2 and at[1] - at[0] >= LootBoxView.SAVE_EVERY, "tras otro cambio avisa otra vez, como mucho una vez por segundo (%s)" % [at])
	await _physics_steps(120)
	check(at.size() == 2, "quieta y sin cambios, no avisa más")
	await _free_box(box)


func test_piece_under_a_point_and_its_place_on_screen() -> void:
	var sword := _piece(&"sword_basic")
	sword.loot_pose = {"pos": Vector2(200, 384), "ang": 0.0}  # de pie a 55 px: de x 172,5 a 227,5 y de y 329 a 439
	var box := _new_box()
	box.sync([sword])
	check(box.piece_at(Vector2(200, 400)) == box.body_of(sword) and box.piece_at(Vector2(600, 400)) == null and box.piece_at(Vector2(240, 400)) == null, "dice qué pieza hay bajo un punto, a media escala")
	check(box.rect_global() == Rect2(60, 970, 960, 440), "la caja en la pantalla (%s)" % box.rect_global())
	check(box.piece_global_point(sword).is_equal_approx(box.to_global(Vector2(200, 356.5))), "su primera casilla en la pantalla (%s)" % box.piece_global_point(sword))
	await _free_box(box)


# ─── Tarea 5: el panel de Equipo con la caja ───────────────────────────

func _new_panel() -> Control:
	var panel: Control = load("res://scenes/UI/EquipmentPanel.tscn").instantiate()
	add_child(panel)
	panel.open()
	return panel


## Eventos de ratón en coordenadas del lienzo (1080×1920), directos al panel.
func _mouse(panel: Control, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	panel._input(e)


func _move(panel: Control, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	panel._input(e)


## Dónde poner el dedo para que la pieza cogida caiga con su caja en `cell` de `view` (va una casilla por encima del dedo).
func _finger_for(panel: Control, view: Control, cell: Vector2i) -> Vector2:
	var grab: Vector2 = panel._press.origin - panel._press.pos
	return view.global_position + Vector2(cell) * CELL - grab + (Vector2(0, CELL) if DisplayServer.is_touchscreen_available() else Vector2.ZERO)


## Deja una pieza del botín apoyada en el suelo de la caja, en la x dada (px de la caja) y con ese ángulo: con pose, la
## caja la pone ahí al abrir el panel, sin esperar a que caiga desde arriba.
func _in_box(item: CraftedItem, x: float, angle: float = 0.0) -> void:
	var fp := PieceShape.of_item(item, posmod(roundi(angle / (PI / 2.0)), 4))
	var com := PieceShape.mass_center(fp, LootBoxView.BOX_CELL)
	item.loot_pose = {"pos": Vector2(x, LootBoxView.SIZE.y - float(fp.size.y) * LootBoxView.BOX_CELL + com.y - 1.0), "ang": angle}


func _long_press(panel: Control, pos: Vector2) -> void:
	_mouse(panel, pos, true)
	panel._press.time = Time.get_ticks_msec() - 1000  # como si llevara 1 s pulsada
	panel._process(0.0)


## Calla las voces de AudioManager: el clinc de colocar una pieza en Tico seguiría sonando al acabar la suite.
func _silence_sounds() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		for voice in am.get_children():
			if voice is AudioStreamPlayer:
				voice.stop()
	await get_tree().create_timer(0.1).timeout


func test_the_panel_makes_room_for_the_box() -> void:
	var panel := _new_panel()
	check(panel._loot_box.rect_global() == Rect2(60, 1070, 960, 440), "la caja mide 960×440 desde y = 970 (%s)" % panel._loot_box.rect_global())
	check(not ("_bag_view" in panel), "la mochila adicional está retirada")
	check(panel.sell_zone.get_global_rect() == Rect2(760, 1540, 260, 200), "y la zona de venta con ella (%s)" % panel.sell_zone.get_global_rect())
	check(not panel.has_node("BagIcon") and not panel.has_node("BagTitle"), "sin título ni icono de mochila")
	check(not ("_scrolling" in panel) and not ("_loot_view" in panel), "sin la tira ni su desplazamiento")
	panel.queue_free()
	await get_tree().process_frame


func test_grabbing_a_box_piece_straightens_it() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")  # 1×3
	im.add_crafted_item(sword)
	sword.loot_pose = {"pos": Vector2(480, 200), "ang": 1.3}  # torcida, casi tumbada
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	check(box.body_of(sword) != null and is_equal_approx(box.body_of(sword).rotation, 1.3), "la espada está en la caja con su ángulo")
	var start := box.piece_global_point(sword)
	_mouse(panel, start, true)
	check(panel._press.get("item") == sword and panel._press.get("rot") == 1, "al cogerla se endereza al cuarto de vuelta más cercano (%s)" % [panel._press.get("rot")])
	check(box.body_of(sword).rects.all(func(r): return r.size == Vector2(55, 55)), "en la caja choca a media escala: 55 px por casilla")
	var com := PieceShape.mass_center(PieceShape.of_item(sword, 1), panel.DRAG_CELL)
	check(is_equal_approx(panel.DRAG_CELL, 110.0) and (panel._press.origin + com).is_equal_approx(box.to_global(Vector2(480, 200))), "cogida, crece a 110 px por casilla alrededor de su centro de masa")
	_move(panel, start + Vector2(0, -40))
	check(panel._dragging and panel._drag_rot == 1 and box.is_held(sword) and box.body_of(sword) == null, "arrastrada, sale de la física y la lleva el dedo")
	var full: Vector2 = Vector2(PieceShape.of_item(sword, 1).size) * panel.DRAG_CELL
	check(full == Vector2(330, 110), "la pieza arrastrada mide lo que en la rejilla (%s)" % full)
	_move(panel, Vector2(540, 60))  # arriba del todo, fuera de las rejillas y de la caja
	_mouse(panel, Vector2(540, 60), false)
	var back := box.body_of(sword)
	check(sword.place == &"loot" and back != null and not box.is_held(sword), "soltada fuera de todo, vuelve a la caja")
	check(back.position.is_equal_approx(Vector2(480, LootBoxView.CEIL_Y + 27.5)) and is_equal_approx(back.rotation, PI / 2.0), "al punto de la caja más cercano al dedo, bajo el techo (%s)" % back.position)
	check(back.rects.all(func(r): return r.size == Vector2(55, 55)), "y vuelve a media escala")
	panel.queue_free()
	await _restore_inventory(saved)


func test_dropping_in_the_box_throws_with_the_gesture() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	_in_box(helmet, 200.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	var finger := box.to_global(Vector2(600, 300))
	_move(panel, finger)
	check(panel._target.get("place") == &"loot", "sobre la caja, el destino es el botín (%s)" % [panel._target])
	var center: Vector2 = panel._ghost_origin() + PieceShape.mass_center(PieceShape.of_item(helmet, 0), panel.DRAG_CELL)
	var now := Time.get_ticks_usec()
	panel._drag_trail = [[finger - Vector2(300, 0), now - 50000], [finger, now]]  # 6000 px/s hacia la derecha
	_mouse(panel, finger, false)
	var body := box.body_of(helmet)
	check(body != null and body.position.is_equal_approx(box.to_local(center)), "entra donde se veía la pieza, una casilla por encima del dedo")
	check(body.linear_velocity.x > 1000.0 and body.linear_velocity.length() <= LootBoxView.MAX_THROW_SPEED + 0.5, "con la inercia del gesto, con tope (%s)" % body.linear_velocity)
	panel.queue_free()
	await _restore_inventory(saved)


func test_a_piece_from_the_grid_lands_where_it_is_dropped() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	im.move_item(helmet, &"hero", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start: Vector2 = panel._hero_view.global_position + Vector2(55, 55)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(30, 30))
	var finger := box.to_global(Vector2(480, 300))
	_move(panel, finger)
	_mouse(panel, finger, false)
	var body := box.body_of(helmet)
	check(helmet.place == &"loot" and body != null and box._queue.is_empty(), "sale de Tico y entra en la caja sin caer desde arriba")
	check(body.position.is_equal_approx(Vector2(480, 190 if DisplayServer.is_touchscreen_available() else 300)), "donde se soltó: una casilla por encima del dedo (%s)" % body.position)
	panel.queue_free()
	await _restore_inventory(saved)


func test_a_swap_sends_the_other_piece_from_the_top() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var old_sword := _piece(&"sword_basic", 0.5)
	var new_sword := _piece(&"sword_basic", 0.95)
	im.add_crafted_item(old_sword)
	im.move_item(old_sword, &"hero", Vector2i(3, 0), 0)  # de pie en (3,0)-(3,1)
	im.add_crafted_item(new_sword)
	_in_box(new_sword, 300.0, PI / 2.0)  # tumbada en la caja
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(new_sword)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(2, 0))  # tumbada: (2,0)-(3,0), encima de la vieja
	_move(panel, finger)
	_mouse(panel, finger, false)
	check(new_sword.place == &"hero" and old_sword.place == &"loot", "se intercambian")
	check(box.body_of(old_sword) == null and box._queue.has(old_sword), "la vieja espera su turno para caer desde arriba")
	var frames: int = await _physics_until(func(): return box.body_of(old_sword) != null, 3 * LootBoxView.SPAWN_INTERVAL)
	check(frames > 0 and box.body_of(old_sword).position.y < 0.0, "y cae desde arriba de la caja")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


func test_tap_and_long_press_on_a_box_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_advanced", 1.0)
	im.add_crafted_item(helmet)
	_in_box(helmet, 400.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var p := box.piece_global_point(helmet)
	_mouse(panel, p, true)
	_mouse(panel, p, false)
	check(panel._selected == helmet and box.body_of(helmet) != null and not box.is_held(helmet), "tocarla la enseña en la ficha, sin sacarla de la caja")
	_long_press(panel, p)
	check(panel._card.visible and panel._card_item == helmet and box.body_of(helmet) != null, "mantenerla pulsada abre su ficha completa")
	_mouse(panel, p, false)
	panel.queue_free()
	await _restore_inventory(saved)


func test_closing_mid_drag_returns_the_piece_to_the_box() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	_in_box(helmet, 200.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	_move(panel, box.to_global(Vector2(700, 300)))
	check(box.is_held(helmet), "el casco va en el dedo")
	gm.save_writer = Callable(self, "_count_save_write")
	_save_writes = 0
	panel.close()  # Atrás con la pieza en el dedo
	var body := box.body_of(helmet)
	check(not box.active and not box.is_held(helmet) and body != null, "vuelve a la caja, que se congela")
	check(body.position.is_equal_approx(Vector2(700, 300)) and LootBoxView.pose_is_valid(helmet.loot_pose), "al punto más cercano al dedo, con su pose recogida (%s)" % body.position)
	var p0 := body.position
	await _physics_steps(30)
	check(body.position == p0, "con el panel cerrado no se mueve")
	for i in 2:
		await get_tree().process_frame
	check(_save_writes >= 1, "y la pose se guarda (%d)" % _save_writes)
	gm.save_writer = Callable()
	panel.queue_free()
	await _restore_inventory(saved)


func test_new_loot_while_holding_a_box_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	_in_box(helmet, 200.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	var fresh := _piece(&"boots_basic")
	im.add_crafted_item(fresh)  # llega de la forja a mitad del arrastre
	check(box.is_held(helmet) and box.body_of(helmet) == null, "la pieza cogida no reaparece en la caja")
	check(box._queue.has(fresh) and not box._queue.has(helmet), "la nueva espera para caer desde arriba")
	_move(panel, Vector2(540, 60))
	_mouse(panel, Vector2(540, 60), false)
	var frames: int = await _physics_until(func(): return box.body_of(fresh) != null, 6 * LootBoxView.SPAWN_INTERVAL)
	check(frames > 0 and box.body_of(helmet) != null and box._bodies.size() == 2, "al final, un cuerpo cada una")
	panel.queue_free()
	await _restore_inventory(saved)


func test_selling_an_epic_from_the_box_waits_in_the_box() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var epic := _piece(&"helmet_basic", 0.95)
	im.add_crafted_item(epic)
	_in_box(epic, 800.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(epic)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, 40))
	var sell_point: Vector2 = panel.sell_zone.get_global_rect().get_center()
	_move(panel, sell_point)
	_mouse(panel, sell_point, false)
	check(panel._confirm_box.visible and epic in im.get_crafted_items(), "la épica pide confirmación")
	check(box.body_of(epic) != null and not box.is_held(epic), "mientras, vuelve a la caja")
	panel._on_confirm_yes()
	check(not (epic in im.get_crafted_items()) and box.body_of(epic) == null, "al confirmar se vende y su cuerpo se va")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## Requisito A de la revisión de la tarea 4: la caja cerrada saca sus cuerpos de la física (PROCESS_MODE_DISABLED) y sus
## consultas de solape no verían nada. Las poses que se cargan con el panel cerrado entran al abrirlo, ya con la caja
## activa: las que se pisan acaban como fantasmas (o separadas) y nadie sale despedido.
func test_overlapping_poses_loaded_while_closed_do_not_explode_on_open() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var panel := _new_panel()
	panel.close()
	var box: LootBoxView = panel._loot_box
	check(not box.active, "con el panel cerrado la caja está parada")
	var a := _piece(&"shield_advanced")
	var b := _piece(&"shield_advanced")
	im.add_crafted_item(a)
	im.add_crafted_item(b)
	for it in [a, b]:
		it.loot_pose = {"pos": Vector2(480, 384), "ang": 0.0}  # las dos en el mismo sitio
	im.load_save_data(im.to_save_data(), 1)  # como al cargar la partida: piezas nuevas con su pose
	var loot: Array[CraftedItem] = im.get_loot()
	check(loot.size() == 2 and loot.all(func(it): return LootBoxView.pose_is_valid(it.loot_pose)), "se cargan con su pose")
	check(box._bodies.is_empty(), "con el panel cerrado aún no entran")
	panel.open()
	check(box.active and loot.all(func(it): return box.body_of(it) != null), "al abrir, las dos entran en su pose")
	var ghosts: Array = loot.filter(func(it): return box.body_of(it).is_ghost)
	check(ghosts.size() == 1, "la que pisa a la otra entra como fantasma (%d fantasmas)" % ghosts.size())
	await _physics_steps(120)
	check(loot.all(func(it): return _inside(box.body_of(it))), "las dos siguen dentro de la caja")
	var solid: Array = loot.filter(func(it): return not box.body_of(it).is_ghost)
	check(solid.size() >= 1 and box.body_of(solid[0]).position.distance_to(Vector2(480, 384)) < 3.0, "y nadie sale despedido (%s)" % box.body_of(loot[0]).position)
	panel.queue_free()
	await _restore_inventory(saved)


## Un cuerpo por pieza del botín, ni uno más ni uno menos: los cuerpos (y los hijos LootPiece de la caja) son las piezas
## del botín, salvo la que lleva el dedo.
func _one_body_each(box: LootBoxView, loot: Array) -> bool:
	var pieces := box.get_children().filter(func(n): return n is LootPiece)
	if pieces.size() != loot.size() or box._bodies.size() != loot.size():
		return false
	for item in loot:
		var body := box.body_of(item)
		if body == null or body.item != item or not (body in pieces):
			return false
	return true


## Requisito B: «Vender todo» y vender lo que queda (la caja se sincroniza con un botín vacío) dejan un cuerpo por pieza.
func test_sell_all_leaves_one_body_per_loot_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var basics := [_piece(&"helmet_basic", 0.3), _piece(&"boots_basic", 0.3), _piece(&"sword_basic", 0.3)]
	var epic := _piece(&"shield_advanced", 0.95)
	var xs := [120.0, 360.0, 600.0, 840.0]
	for i in 4:
		var it: CraftedItem = (basics + [epic])[i]
		im.add_crafted_item(it)
		_in_box(it, xs[i])
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	check(_one_body_each(box, im.get_loot()), "al abrir, un cuerpo por pieza (%d cuerpos, %d piezas)" % [box._bodies.size(), im.get_loot().size()])
	panel._on_sell_all()
	panel._on_confirm_yes()
	check(im.get_loot().size() == 1 and im.get_loot()[0] == epic, "«Vender todo» deja la épica")
	check(_one_body_each(box, im.get_loot()), "y solo su cuerpo en la caja (%d cuerpos)" % box._bodies.size())
	await _physics_steps(30)
	check(_one_body_each(box, im.get_loot()), "también unos pasos después")
	im.sell_item(epic)  # la caja se queda con el botín vacío
	check(_one_body_each(box, []) and box._queue.is_empty() and box._held == null, "con el botín vacío no queda ningún cuerpo")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## Requisito B: añadir, quitar y volver a añadir deprisa (en el mismo paso o con la pieza aún en la cola) no pierde ni
## duplica cuerpos.
func test_quick_add_remove_add_keeps_one_body_each() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var a := _piece(&"helmet_basic", 0.3)
	var b := _piece(&"boots_basic", 0.3)
	im.add_crafted_item(a)
	im.sell_item(a)
	im.add_crafted_item(a)  # la misma pieza vuelve antes de entrar
	im.add_crafted_item(b)
	check(box._queue.size() == 2 and box._queue.count(a) == 1, "en la cola, una vez cada una (%d)" % box._queue.size())
	var frames: int = await _physics_until(func(): return box._queue.is_empty(), 6 * LootBoxView.SPAWN_INTERVAL)
	check(frames > 0 and _one_body_each(box, im.get_loot()), "al entrar, un cuerpo cada una (%d cuerpos)" % box._bodies.size())
	# Con cuerpo: a Tico y de vuelta al botín en el mismo paso, y otra que llega y se vende a la vez
	im.move_item(a, &"hero", Vector2i(0, 0), 0)
	im.move_item(a, InventoryManager.PLACE_LOOT)
	var c := _piece(&"sword_basic", 0.3)
	im.add_crafted_item(c)
	im.remove_crafted_item(c)
	im.add_crafted_item(c)
	check(box.body_of(a) == null and box._queue.count(a) == 1 and box._queue.count(c) == 1, "la que volvió del todo cae otra vez desde arriba, sin cuerpo viejo")
	frames = await _physics_until(func(): return box._queue.is_empty(), 8 * LootBoxView.SPAWN_INTERVAL)
	check(frames > 0 and _one_body_each(box, im.get_loot()), "al final, un cuerpo por pieza del botín (%d cuerpos, %d piezas)" % [box._bodies.size(), im.get_loot().size()])
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## Revisión de la tarea 5: la velocidad del gesto es la del momento de soltar. Un gesto rápido seguido de una pausa para
## apuntar no lanza la pieza; uno reciente sí.
func test_a_throw_needs_a_fresh_gesture() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	_in_box(helmet, 200.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var now := Time.get_ticks_usec()
	panel._drag_trail = [[Vector2(0, 0), now - 300000], [Vector2(300, 0), now - 250000]]  # rápido, pero hace 0,25 s
	check(panel._throw_velocity() == Vector2.ZERO, "un gesto que acabó hace más de 0,1 s no lanza (%s)" % panel._throw_velocity())
	panel._drag_trail = [[Vector2(0, 0), now - 50000], [Vector2(300, 0), now]]
	check(panel._throw_velocity().x > 1000.0, "uno reciente sí (%s)" % panel._throw_velocity())
	var start := box.piece_global_point(helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	var finger := box.to_global(Vector2(600, 300))
	_move(panel, finger)
	now = Time.get_ticks_usec()
	panel._drag_trail = [[finger - Vector2(300, 0), now - 300000], [finger, now - 250000]]  # lanzó y luego se quedó quieto apuntando
	_mouse(panel, finger, false)
	var body := box.body_of(helmet)
	check(body != null and body.linear_velocity == Vector2.ZERO, "quieto al soltar, la pieza entra sin inercia (%s)" % (body.linear_velocity if body else Vector2.INF))
	panel.queue_free()
	await _restore_inventory(saved)


## Revisión de la tarea 5: se suelta donde se levanta el dedo, aunque no llegara un último movimiento hasta ahí.
func test_the_release_point_is_the_drop_point() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	_in_box(helmet, 200.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	_move(panel, box.to_global(Vector2(300, 300)))
	var finger := box.to_global(Vector2(700, 300))
	var center: Vector2 = finger + (panel._press.origin - panel._press.pos) + (Vector2(0, -panel.CELL) if DisplayServer.is_touchscreen_available() else Vector2.ZERO) + PieceShape.mass_center(PieceShape.of_item(helmet, 0), panel.DRAG_CELL)
	_mouse(panel, finger, false)  # sin movimiento previo hasta este punto
	var body := box.body_of(helmet)
	check(body != null and body.position.is_equal_approx(box.to_local(center)), "entra bajo el punto donde se soltó (%s)" % (body.position if body else Vector2.INF))
	panel.queue_free()
	await _restore_inventory(saved)


# ─── Tarea 6: rendimiento ──────────────────────────────────────────────

## Spec, apartado 10: 60 piezas se quedan quietas, sin pasar del techo, y abrir el panel con ellas (cada una vuelve a su pose:
## 60 cuerpos nuevos) cabe en 50 ms, el presupuesto del panel de siempre. Se mide en el ordenador; el móvil, con su tarjeta.
func test_sixty_pieces_settle_under_the_ceiling_and_the_panel_opens_fast() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 60:
		var res := _res(ITEM_IDS[i % ITEM_IDS.size()])
		var item := CraftedItem.new(res, rng.randf())
		item.aristas = PieceShape.roll_aristas(res, item.get_quality_tier(), rng)
		im.add_crafted_item(item)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var frames: int = await _physics_until(func(): return box.is_settled(), 4000)
	check(frames > 0, "las 60 piezas se quedan quietas (%d pasos, %.1f s de juego)" % [frames, frames / 60.0])
	check(box._bodies.size() == 60, "todas tienen cuerpo (%d)" % box._bodies.size())
	check(_highest_top(box, im.get_loot()) >= LootBoxView.CEIL_Y - 2.0, "ninguna pasa del techo (%.1f)" % _highest_top(box, im.get_loot()))
	check(im.get_loot().all(func(it): return _inside(box.body_of(it))), "todas dentro de la caja")
	var ghosts: int = im.get_loot().filter(func(it): return box.body_of(it).is_ghost).size()
	print("botín con física: 60 piezas quietas en %d pasos, %d fantasmas" % [frames, ghosts])
	check(60 - ghosts >= 20 and ghosts <= 40, "a media escala caben unas 25 que chocan; el resto, fantasmas (%d que chocan, %d fantasmas; medido: 25 y 35)" % [60 - ghosts, ghosts])
	panel.close()  # recoge las poses
	panel.queue_free()
	await get_tree().physics_frame
	# Tres paneles nuevos, cada uno crea los 60 cuerpos desde las poses; se mira la apertura más rápida
	var samples: Array[float] = []
	for i in 3:
		var fresh: Control = load("res://scenes/UI/EquipmentPanel.tscn").instantiate()
		add_child(fresh)
		await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		fresh.open()
		samples.append((Time.get_ticks_usec() - t0) / 1000.0)
		check(fresh._loot_box._bodies.size() == 60 and fresh._loot_box._queue.is_empty(), "al abrir, todas vuelven a su pose sin caer")
		fresh.close()
		fresh.queue_free()
		await get_tree().physics_frame
	var ms: float = samples.min()
	print("panel de Equipo con 60 piezas en la caja: %.1f ms, la más rápida de 3 (%.1f / %.1f / %.1f)" % [ms, samples[0], samples[1], samples[2]])
	check(ms < 50.0, "abrir el panel con 60 piezas cabe en 50 ms (%.1f)" % ms)
	await _restore_inventory(saved)
