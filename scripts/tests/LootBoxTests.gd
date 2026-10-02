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
	im.move_item(helmet, &"bag", Vector2i(0, 0), 0)
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
