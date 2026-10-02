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
