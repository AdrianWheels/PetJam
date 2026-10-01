extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas del inventario en rejilla (spec doc/specs/2026-09-27-inventario-en-rejilla.md), solo
## desarrollo, sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/InventoryGridTests.tscn

const ITEM_IDS := [&"sword_basic", &"sword_advanced", &"sword_masterwork", &"shield_basic",
	&"shield_advanced", &"shield_master", &"helmet_basic", &"helmet_advanced", &"helmet_master",
	&"boots_basic", &"boots_advanced", &"boots_master"]

## Casillas limpias de cada pieza (spec, apartado 2.2), sin girar.
const SHAPES := {
	&"sword_basic": [Vector2i(0, 0), Vector2i(0, 1)],
	&"sword_advanced": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	&"sword_masterwork": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
	&"shield_basic": [Vector2i(0, 0), Vector2i(0, 1)],
	&"shield_advanced": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	&"shield_master": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
	&"helmet_basic": [Vector2i(0, 0)],
	&"helmet_advanced": [Vector2i(0, 0), Vector2i(1, 0)],
	&"helmet_master": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	&"boots_basic": [Vector2i(0, 0)],
	&"boots_advanced": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	&"boots_master": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
}


func _res(id: StringName) -> ItemResource:
	return load("res://data/items/%s.tres" % id)


## Pieza de prueba con calidad y aristas fijas (sin sorteo).
func _piece(id: StringName, quality: float = 0.95, aristas: Array[Vector2i] = []) -> CraftedItem:
	var item := CraftedItem.new(_res(id), quality)
	item.aristas = aristas
	return item


## Casillas ordenadas por fila y columna, para comparar sin depender del orden.
func _sorted(cells: Array) -> Array:
	var out := cells.duplicate()
	out.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


# ─── Tarea 1: formas, giros y aristas ──────────────────────────────────

func test_every_piece_has_the_spec_shape() -> void:
	for id in ITEM_IDS:
		var res := _res(id)
		check(_sorted(res.shape_cells) == _sorted(SHAPES[id]), "%s: forma %s" % [id, res.shape_cells])
		check(PieceShape.check_resource(res) == "", "%s: %s" % [id, PieceShape.check_resource(res)])
	var areas := {}
	for id in ITEM_IDS:
		var tier := String(_res(id).rarity)
		areas[tier] = int(areas.get(tier, 0)) + SHAPES[id].size()
	check(areas == {"basic": 6, "advanced": 12, "master": 18}, "un juego completo ocupa 6, 12 y 18 casillas (%s)" % areas)


func test_rotation_is_clockwise_and_normalized() -> void:
	var none: Array[Vector2i] = []
	var sword: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var fp := PieceShape.footprint(sword, none, 1)
	check(_sorted(fp.clean) == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] and fp.size == Vector2i(3, 1), "la espada tumbada ocupa 3×1 (%s)" % [fp.clean])
	var boots: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var fp2 := PieceShape.footprint(boots, none, 1)
	check(_sorted(fp2.clean) == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)], "la bota en L gira a la derecha: la puntera pasa a apuntar abajo (%s)" % [fp2.clean])
	check(PieceShape.footprint(boots, none, 4).clean == PieceShape.footprint(boots, none, 0).clean, "4 giros vuelven al principio")


func test_aristas_rotate_with_the_piece() -> void:
	var sword: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
	var aristas: Array[Vector2i] = [Vector2i(-1, 2)]
	var fp := PieceShape.footprint(sword, aristas, 0)
	check(fp.size == Vector2i(2, 4) and fp.aristas == [Vector2i(0, 2)] and fp.clean[0] == Vector2i(1, 0), "una arista a la izquierda amplía la caja y desplaza la hoja (%s / %s)" % [fp.clean, fp.aristas])
	var fp1 := PieceShape.footprint(sword, aristas, 1)
	check(fp1.size == Vector2i(4, 2) and fp1.aristas == [Vector2i(1, 0)], "girada, la arista queda encima de la hoja (%s)" % [fp1.aristas])


func test_aristas_count_by_quality() -> void:
	var expected := {0.2: 2, 0.55: 2, 0.8: 1, 0.95: 0, 1.0: 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for q in expected:
		var item := CraftedItem.new(_res(&"sword_masterwork"), q)
		var rolled := PieceShape.roll_aristas(item.item_resource, item.get_quality_tier(), rng)
		check(rolled.size() == expected[q], "calidad %.2f: %d aristas (%d)" % [q, expected[q], rolled.size()])
		var unique := {}
		for a in rolled:
			check(a in item.item_resource.arista_spots, "cada arista sale de un sitio permitido (%s)" % a)
			unique[a] = true
		check(unique.size() == rolled.size(), "sin repetir sitio")


func test_arista_roll_is_repeatable_with_a_seed() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 12345
	b.seed = 12345
	var res := _res(&"shield_master")
	check(PieceShape.roll_aristas(res, "common", a) == PieceShape.roll_aristas(res, "common", b), "misma semilla, mismas aristas")


func test_crafted_item_saves_its_place() -> void:
	var rough: Array[Vector2i] = [Vector2i(1, 2)]
	var item := _piece(&"helmet_master", 0.6, rough)
	item.place = &"hero"
	item.cell = Vector2i(2, 3)
	item.rot = 3
	item.rank = 2
	var data := item.to_dict()
	var back := CraftedItem.from_dict(data, item.item_resource)
	check(back.place == &"hero" and back.cell == Vector2i(2, 3) and back.rot == 3, "sitio, casilla y giro vuelven igual")
	check(back.aristas == [Vector2i(1, 2)], "las aristas vuelven igual (%s)" % [back.aristas])
	check(back.rank == 2 and back.get_name_with_rank().ends_with(" II"), "el rango vuelve igual y sale en el nombre (%s)" % back.get_name_with_rank())
	check(not data.has("equipped"), "ya no se guarda equipped")
	var old := data.duplicate()
	for k in ["rank", "place", "x", "y", "rot", "aristas"]:
		old.erase(k)
	var before := CraftedItem.from_dict(old, item.item_resource)
	check(before.place == &"loot" and before.aristas.is_empty() and before.rank == 1, "una pieza de una partida anterior empieza en el botín, sin aristas y en el rango I")
	check(not before.get_name_with_rank().ends_with(" I"), "sin numeral en el rango I (%s)" % before.get_name_with_rank())


# ─── Tarea 2: la rejilla ───────────────────────────────────────────────

func test_grid_fits_and_places() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var sword := _piece(&"sword_masterwork")  # 1×4
	check(g.fits(sword, Vector2i(0, 0), 0), "la espada de 1×4 cabe de pie en 4×4")
	check(not g.fits(sword, Vector2i(0, 1), 0), "una casilla más abajo se sale")
	check(g.fits(sword, Vector2i(0, 3), 1), "tumbada en la última fila cabe")
	check(g.place(sword, Vector2i(3, 0), 0) and g.cell_of(sword) == Vector2i(3, 0) and g.rot_of(sword) == 0, "se coloca en la columna derecha")
	var shield := _piece(&"shield_advanced")  # 2×2
	check(not g.fits(shield, Vector2i(2, 0), 0), "no puede pisar la espada")
	check(g.overlapping(shield, Vector2i(2, 0), 0) == [sword], "sabe a quién pisaría")
	check(g.fits(shield, Vector2i(2, 0), 0, [sword]), "si se ignora la espada, cabe (para intercambiar)")
	check(g.item_at(Vector2i(3, 2)) == sword and g.item_at(Vector2i(0, 0)) == null, "casillas ocupadas y libres")
	g.remove(sword)
	check(not g.has(sword) and g.item_at(Vector2i(3, 2)) == null, "al quitarla deja libres sus casillas")


func test_aristas_take_room_but_are_not_neighbors() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var rough: Array[Vector2i] = [Vector2i(1, 0)]  # rebaba a la derecha de la punta
	var sword := _piece(&"sword_basic", 0.5, rough)
	check(g.place(sword, Vector2i(0, 0), 0), "la espada con arista ocupa 2 de ancho")
	var helmet := _piece(&"helmet_basic")
	check(not g.fits(helmet, Vector2i(1, 0), 0), "la arista ocupa su casilla")
	check(g.place(helmet, Vector2i(2, 0), 0), "el casco al lado de la arista")
	check(g.neighbors(helmet).is_empty() and g.neighbors(sword).is_empty(), "tocar solo la arista no es ser vecinas")
	var boots := _piece(&"boots_basic")
	check(g.place(boots, Vector2i(1, 1), 0), "las botas junto a la empuñadura")
	check(g.neighbors(sword) == [boots] and g.neighbors(boots) == [sword], "vecinas por un lado limpio")
	var diag := _piece(&"helmet_basic")
	check(g.place(diag, Vector2i(2, 2), 0) and not (diag in g.neighbors(boots)), "en diagonal no son vecinas")


func test_neighbors_count_each_piece_once() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var a := _piece(&"sword_advanced")  # 1×3
	var b := _piece(&"sword_advanced")
	g.place(a, Vector2i(0, 0), 0)
	g.place(b, Vector2i(1, 0), 0)
	check(g.neighbors(a) == [b], "dos espadas pegadas por 3 casillas son vecinas una vez")


func test_grid_copy_does_not_touch_pieces() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var s := _piece(&"shield_basic")
	g.place(s, Vector2i(0, 0), 0)
	var copy := g.duplicate_grid()
	copy.remove(s)
	copy.place(s, Vector2i(2, 2), 1)
	check(g.cell_of(s) == Vector2i(0, 0) and g.rot_of(s) == 0 and s.cell == Vector2i.ZERO, "mover en la copia no cambia la rejilla ni la pieza")
	g.resize(Vector2i(5, 4))
	check(g.size == Vector2i(5, 4) and g.cell_of(s) == Vector2i(0, 0), "crecer no mueve las piezas")
	g.resize(Vector2i(3, 3))
	check(g.size == Vector2i(5, 4), "nunca encoge")


# ─── Tarea 3: auras, zonas y tope ──────────────────────────────────────

func test_shield_aura_reaches_armor_neighbors_only() -> void:
	var g := GearGrid.new(Vector2i(5, 5))
	var shield := _piece(&"shield_advanced", 0.8)  # Raro: aura del 10 %
	var helmet := _piece(&"helmet_advanced", 0.2)  # Básico: sin aura propia
	var sword := _piece(&"sword_advanced", 0.2)
	g.place(shield, Vector2i(1, 1), 0)  # 2×2, lejos de los bordes
	g.place(helmet, Vector2i(1, 0), 0)  # 2×1 encima, en la fila de arriba (su zona)
	g.place(sword, Vector2i(3, 1), 0)   # 1×3 a la derecha del escudo, fuera de su zona (columna 4)
	var b := GearAuras.bonuses(g)
	check(is_equal_approx(b[helmet].get("armor", 0.0), 0.10 + GearAuras.ZONE_BONUS), "el casco recibe el 10 %% de armadura del escudo más su zona (%s)" % b[helmet])
	check(b[sword].get("armor", 0.0) == 0.0, "la espada no es armadura: no recibe el aura del escudo (%s)" % b[sword])
	check(b[shield].is_empty(), "el escudo no se potencia a sí mismo ni está en su zona (%s)" % b[shield])


func test_sword_and_boots_auras_go_to_weapons() -> void:
	var g := GearGrid.new(Vector2i(5, 5))
	var legendary_sword := _piece(&"sword_basic", 1.0)  # Legendario: 20 %
	var other_sword := _piece(&"sword_basic", 0.2)
	var boots := _piece(&"boots_basic", 0.95)  # Épico: 15 %
	g.place(legendary_sword, Vector2i(1, 1), 0)
	g.place(other_sword, Vector2i(2, 1), 0)
	g.place(boots, Vector2i(2, 3), 0)  # debajo de la segunda espada
	var b := GearAuras.bonuses(g)
	check(is_equal_approx(b[other_sword].get("damage", 0.0), 0.20), "+20 %% de daño de la espada legendaria vecina (%s)" % b[other_sword])
	check(is_equal_approx(b[other_sword].get("aps", 0.0), 0.15), "+15 %% de velocidad de las botas épicas (%s)" % b[other_sword])
	check(b[legendary_sword].get("damage", 0.0) == 0.0, "una espada de calidad Básico no da aura (%s)" % b[legendary_sword])


func test_bonus_is_capped() -> void:
	var g := GearGrid.new(Vector2i(3, 3))
	var center := _piece(&"helmet_basic", 0.2)
	g.place(center, Vector2i(1, 1), 0)
	for c in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		g.place(_piece(&"helmet_basic", 1.0), c, 0)
	var b := GearAuras.bonuses(g)
	check(is_equal_approx(b[center].hp, GearAuras.CAP), "cuatro cascos legendarios dan +80 %%, pero el tope lo deja en +50 %% (%s)" % b[center])


func test_a_bonus_on_a_stat_the_piece_lacks_does_nothing() -> void:
	# Spec 4.1: "el casco no da vida a una espada". La espada solo tiene daño, crítico y velocidad.
	var g := GearGrid.new(Vector2i(5, 5))
	var helmet := _piece(&"helmet_basic", 0.8)  # Raro: +10 % de vida a las vecinas
	var sword := _piece(&"sword_basic", 0.2)
	g.place(helmet, Vector2i(2, 1), 0)  # fuera de la fila de arriba: sin zona
	g.place(sword, Vector2i(3, 1), 0)  # pegada al casco y fuera de su zona (columna 4)
	var b := GearAuras.bonuses(g)
	check(not b[sword].has("hp"), "el casco no da vida a una espada, que no tiene (%s)" % b[sword])
	check(b[sword].is_empty(), "y fuera de su zona la espada no sube nada (%s)" % b[sword])
	g.place(sword, Vector2i(4, 1), 0)  # ahora en su zona (columna derecha), con el casco pegado
	g.place(helmet, Vector2i(3, 1), 0)
	b = GearAuras.bonuses(g)
	check(not b[sword].has("hp") and not b[sword].has("armor"), "en su zona tampoco sube la vida ni la armadura que no tiene (%s)" % b[sword])
	check(is_equal_approx(b[sword].get("damage", 0.0), GearAuras.ZONE_BONUS) and is_equal_approx(b[sword].get("aps", 0.0), GearAuras.ZONE_BONUS), "pero sí el daño y la velocidad que tiene (%s)" % b[sword])


func test_zone_follows_the_grid_edge() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var sword := _piece(&"sword_basic", 0.2)
	g.place(sword, Vector2i(3, 0), 0)
	check(GearAuras.in_zone(g, sword), "la espada en la columna derecha está en su zona")
	g.resize(Vector2i(5, 4))
	check(not GearAuras.in_zone(g, sword), "al crecer la rejilla, la columna derecha es la nueva")


func test_totals_match_a_hand_count() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var shield := _piece(&"shield_basic", 0.8)  # Raro
	var helmet := _piece(&"helmet_basic", 0.8)  # Raro
	g.place(shield, Vector2i(0, 1), 0)  # columna izquierda: su zona
	g.place(helmet, Vector2i(1, 1), 0)  # vecino del escudo, fuera de la fila de arriba
	var t := GearAuras.totals(g)
	var s: Dictionary = shield.calculated_stats
	var h: Dictionary = helmet.calculated_stats
	# Escudo: zona +10 % en todo y +10 % de vida del casco. Casco: +10 % de armadura del escudo.
	var hp := float(s.hp) * (1.0 + 0.10 + 0.10) + float(h.hp)
	var armor := float(s.armor) * 1.10 + float(h.armor) * 1.10
	check(t.hp == roundi(hp) and t.armor == roundi(armor), "vida %d (espera %d) y armadura %d (espera %d)" % [t.hp, roundi(hp), t.armor, roundi(armor)])
	check(t.keys() == ["damage", "str", "agi", "int", "hp", "armor", "crit", "aps"], "las claves de InventoryManager.calculate_total_stats() (%s)" % [t.keys()])


# ─── Tarea 4: habilidades legendarias (datos y multiplicadores) ────────

func test_every_piece_has_one_power() -> void:
	for id in ITEM_IDS:
		check(LegendaryPowers.POWERS.has(id), "%s tiene habilidad legendaria" % id)
	var priced := LegendaryPowers.POWERS.keys().filter(func(id): return LegendaryPowers.POWERS[id].price != "")
	check(priced.size() == 4 and priced.all(func(id): return String(_res(id).rarity) == "master"), "las 4 con precio son las maestras (%s)" % [priced])


func test_only_legendaries_count_and_only_once() -> void:
	var a := _piece(&"sword_basic", 1.0)
	var b := _piece(&"sword_basic", 1.0)
	var epic := _piece(&"shield_advanced", 0.95)
	check(LegendaryPowers.active([a, b, epic]) == [&"sword_basic"], "dos iguales cuentan como una y la épica no tiene habilidad")


func test_multipliers_apply_after_hero_stats_with_caps() -> void:
	var equip := {"damage": 20, "hp": 100, "armor": 10, "crit": 0.6, "aps": 1.0}
	var base := CombatMath.hero_stats(equip)
	var with := CombatMath.hero_stats_with_powers(equip, [&"sword_basic", &"helmet_basic", &"boots_master"])
	check(is_equal_approx(with.dmg, base.dmg * 1.25), "Filo perfecto: daño ×1,25 (%.2f)" % with.dmg)
	check(is_equal_approx(with.crit_p, 0.75), "Ojo de halcón multiplica el crítico, con el tope del 75 %% (%.3f)" % with.crit_p)
	check(with.armor == roundi(base.armor * 0.8), "Ímpetu cuesta un 20 %% de armadura (%d)" % with.armor)
	check(with.max_hp == base.max_hp, "la vida no cambia")
	var fx := LegendaryPowers.effects([&"boots_master", &"shield_advanced"])
	check(fx.first_strike == 3.0 and fx.block == 0.15 and fx.dodge == 0.0, "efectos de combate juntos (%s)" % fx)


# ─── Tarea 5: colocación automática (migración y simulación) ───────────

func test_packer_prefers_each_piece_zone() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var pieces := [_piece(&"sword_advanced"), _piece(&"helmet_advanced"), _piece(&"boots_basic"), _piece(&"shield_basic")]
	check(GearPacker.pack(g, pieces).is_empty(), "las cuatro caben en 4×4")
	for item in pieces:
		check(GearAuras.in_zone(g, item), "%s queda en su zona" % item.item_resource.item_id)


func test_packer_returns_what_does_not_fit() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var towers := []
	for i in 4:
		towers.append(_piece(&"shield_master"))  # 2×3 cada uno
	var left := GearPacker.pack(g, towers)
	check(left.size() == 2 and g.items.size() == 2, "en 4×4 caben 2 escudos torre; los otros 2 se devuelven (%d)" % left.size())
	check(GearPacker.find_spot(g, left[0]).is_empty(), "no queda sitio")


# ─── Tarea 6: los tres sitios del inventario ───────────────────────────

func _im() -> Node:
	return get_node("/root/InventoryManager")


## Deja el inventario vacío (rejilla de 4×4) y devuelve lo que había para restaurarlo.
func _fresh_inventory() -> Dictionary:
	var saved: Dictionary = _im().to_save_data()
	_im().clear()
	return saved


func _restore_inventory(saved: Dictionary) -> void:
	_im().load_save_data(saved, int(get_node("/root/GameManager").best_enemy_level))
	await get_tree().process_frame  # deja pasar los guardados diferidos del cambio de equipo


var _events := {"equipment": 0, "crafted": 0, "loot": 0}  # avisos contados desde la última vez


func _count_equipment(_stats: Dictionary) -> void:
	_events.equipment += 1


func _count_crafted(_items) -> void:
	_events.crafted += 1


func _count_loot(_count: int) -> void:
	_events.loot += 1


## Empieza a contar los avisos del inventario (equipo de Tico, piezas y botín). Se acaba con _stop_listening().
func _listen_to_inventory() -> void:
	_take_events()
	_im().equipment_changed.connect(_count_equipment)
	_im().crafted_items_changed.connect(_count_crafted)
	_im().loot_changed.connect(_count_loot)


func _stop_listening() -> void:
	_im().equipment_changed.disconnect(_count_equipment)
	_im().crafted_items_changed.disconnect(_count_crafted)
	_im().loot_changed.disconnect(_count_loot)


## Los avisos contados desde la última vez, y vuelta a cero.
func _take_events() -> Dictionary:
	var taken := _events
	_events = {"equipment": 0, "crafted": 0, "loot": 0}
	return taken


func test_grid_expansion_sizes_and_bosses() -> void:
	check(GridExpansions.size_after(0) == Vector2i(4, 4) and GridExpansions.size_after(1) == Vector2i(5, 4), "de 4×4 a 5×4")
	check(GridExpansions.size_after(4) == Vector2i(6, 6) and GridExpansions.size_after(9) == Vector2i(6, 6), "el máximo es 6×6")
	check(GridExpansions.recipe_for_boss_room(10) == &"grid_bone_straps" and GridExpansions.recipe_for_boss_room(50) == &"", "jefes 10-40 del ciclo I")
	check(GridExpansions.unlocked_for_record(10).is_empty() and GridExpansions.unlocked_for_record(11) == [&"grid_bone_straps"], "récord mayor que la sala del jefe")


func test_new_pieces_arrive_at_the_front_of_the_loot() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var a := _piece(&"sword_basic")
	var b := _piece(&"shield_basic")
	im.add_crafted_item(a)
	im.add_crafted_item(b)
	check(im.get_loot() == [b, a] and a.place == &"loot", "lo más nuevo delante (%s)" % [im.get_loot()])
	check(im.hero_grid_size() == Vector2i(4, 4) and im.get_hero_items().is_empty(), "rejilla de 4×4 vacía: nada se coloca solo")
	check(im.get_unequipped_items().size() == 2, "botín y mochila se pueden vender")
	await _restore_inventory(saved)


func test_move_place_swap_and_back_to_loot() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var old_sword := _piece(&"sword_basic", 0.5)
	var new_sword := _piece(&"sword_advanced", 0.95)
	im.add_crafted_item(old_sword)
	im.add_crafted_item(new_sword)
	check(im.move_item(old_sword, &"hero", Vector2i(3, 0), 0), "la espada vieja a la columna derecha")
	check(old_sword.place == &"hero" and old_sword.cell == Vector2i(3, 0), "la pieza guarda su sitio")
	check(not im.move_item(new_sword, &"hero", Vector2i(3, 2), 0), "la nueva no cabe si se sale por abajo")
	var res: Dictionary = im.drop_result(new_sword, &"hero", Vector2i(3, 0), 0)
	check(res.ok and res.swap == old_sword, "encima de la vieja: intercambio")
	check(im.move_item(new_sword, &"hero", Vector2i(3, 0), 0), "se intercambian")
	check(new_sword.place == &"hero" and old_sword.place == &"loot", "la vieja va al botín, de donde salió la nueva")
	check(im.get_loot()[0] == old_sword, "en el sitio del botín que tenía la nueva")
	check(im.move_item(new_sword, &"loot"), "de vuelta al botín")
	check(im.get_hero_items().is_empty(), "la rejilla queda vacía")
	await _restore_inventory(saved)


func test_swap_sends_the_other_to_loot_if_it_does_not_fit_back() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var tower := _piece(&"shield_master")  # 2×3
	var small := _piece(&"helmet_basic")   # 1×1
	im.add_crafted_item(tower)
	im.add_crafted_item(small)
	check(im.move_item(small, &"bag", Vector2i(5, 3), 0), "el casco en la esquina de la mochila")
	check(im.move_item(tower, &"hero", Vector2i(0, 0), 0), "el escudo torre en Tico")
	check(im.move_item(small, &"hero", Vector2i(0, 0), 0), "el casco encima del escudo: intercambio")
	check(small.place == &"hero" and tower.place == &"loot", "el escudo no cabe en la esquina de la mochila: va al botín y no se pierde")
	await _restore_inventory(saved)


func test_rotate_in_place_needs_room() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_masterwork")  # 1×4
	im.add_crafted_item(sword)
	check(im.move_item(sword, &"hero", Vector2i(1, 0), 0), "de pie en la columna 1")
	check(im.rotate_in_place(sword) and sword.rot == 1 and sword.cell == Vector2i(0, 1), "gira sobre su centro: tumbada en la fila 1 (%s)" % sword.cell)
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	check(im.move_item(helmet, &"hero", Vector2i(1, 3), 0), "un casco debajo")
	check(not im.rotate_in_place(sword) and sword.rot == 1, "de pie ya no cabe: no gira")
	await _restore_inventory(saved)


func test_dropping_a_piece_where_it_already_is_changes_nothing() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_basic")  # 1×2
	var helmet := _piece(&"helmet_basic")
	var loot_a := _piece(&"boots_basic")
	var loot_b := _piece(&"boots_advanced")
	var loot_c := _piece(&"shield_basic")
	for p in [loot_a, loot_b, loot_c, sword, helmet]:
		im.add_crafted_item(p)
	check(im.move_item(sword, &"hero", Vector2i(1, 1), 1), "la espada tumbada en Tico")
	check(im.move_item(helmet, &"bag", Vector2i(2, 2), 0), "el casco en la mochila")
	var order: Array = im.get_loot().duplicate()
	check(order == [loot_c, loot_b, loot_a], "el botín, lo más nuevo delante (%s)" % [order])
	_listen_to_inventory()
	check(im.move_item(sword, &"hero", Vector2i(1, 1), 1), "soltar la espada en su casilla y con su giro vale")
	check(im.move_item(sword, &"hero", Vector2i(1, 1), 5) and im.move_item(sword, &"hero", Vector2i(1, 1), -3), "con más vueltas, el mismo giro")
	check(im.move_item(helmet, &"bag", Vector2i(2, 2), 0), "lo mismo con el casco en la mochila")
	check(im.move_item(loot_b, &"loot") and im.move_item(loot_c, &"loot") and im.move_item(loot_a, &"loot"), "y con las del botín, en el botín")
	var ev := _take_events()
	check(ev.equipment == 0 and ev.crafted == 0 and ev.loot == 0, "ningún aviso (%s)" % [ev])
	check(im.get_loot() == order, "el botín conserva su orden (%s)" % [im.get_loot()])
	check(sword.place == &"hero" and sword.cell == Vector2i(1, 1) and sword.rot == 1 and helmet.place == &"bag" and helmet.cell == Vector2i(2, 2), "y las piezas siguen donde estaban")
	check(im.move_item(sword, &"hero", Vector2i(1, 2), 1), "mover la espada a otra casilla sí la mueve")
	ev = _take_events()
	check(ev.equipment == 1 and ev.crafted == 1, "y esa sí avisa (%s)" % [ev])
	_stop_listening()
	await _restore_inventory(saved)


## Spec, apartado 3.2: colocar, quitar, girar o intercambiar una pieza de la rejilla de Tico cuenta como
## cambiarle el equipo (el muro vuelve a probarse con ese aviso). Nada más lo cuenta.
func test_equipment_changed_only_when_tico_grid_changes() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_basic")  # 1×2
	var shield := _piece(&"shield_basic")  # 1×2
	var helmet := _piece(&"helmet_basic")  # 1×1
	var boots := _piece(&"boots_basic")  # 1×1
	var big := _piece(&"shield_advanced")  # 2×2
	var long_sword := _piece(&"sword_masterwork")  # 1×4
	var stranger := _piece(&"sword_basic")  # no entra en el inventario
	for p in [sword, shield, helmet, boots, big, long_sword]:
		im.add_crafted_item(p)
	_listen_to_inventory()
	# Avisa una vez: colocar, girar, intercambiar, quitar y vender en la rejilla de Tico
	check(im.move_item(sword, &"hero", Vector2i(1, 1), 0), "la espada de pie en Tico")
	check(_take_events().equipment == 1, "colocar en Tico avisa una vez")
	check(im.rotate_in_place(sword) and sword.rot == 1, "la espada se tumba")
	check(_take_events().equipment == 1, "girar en Tico avisa una vez")
	im.move_item(helmet, &"hero", Vector2i(0, 0), 0)
	im.move_item(boots, &"hero", Vector2i(1, 2), 0)
	_take_events()
	# No avisa: lo rechazado no toca nada
	check(not im.move_item(big, &"hero", Vector2i(0, 0), 0), "el escudo de 2×2 no cabe encima de dos piezas")
	check(not im.move_item(long_sword, &"hero", Vector2i(3, 1), 0), "la espada de 1×4 se sale por abajo")
	check(not im.move_item(stranger, &"hero", Vector2i(3, 0), 0), "una pieza ajena no se mueve")
	check(not im.rotate_in_place(long_sword), "una pieza del botín no gira")
	check(not im.rotate_in_place(sword) and sword.rot == 1, "la espada tumbada no cabe de pie sobre las botas: no gira")
	check(_take_events().equipment == 0, "lo rechazado no avisa")
	# Avisa una vez
	check(im.move_item(helmet, &"hero", Vector2i(1, 2), 0) and boots.cell == Vector2i(0, 0) and boots.place == &"hero", "el casco encima de las botas: se intercambian y las botas ocupan el sitio del casco")
	check(_take_events().equipment == 1, "intercambiar en Tico avisa una vez")
	check(im.move_item(helmet, &"loot"), "el casco al botín")
	check(_take_events().equipment == 1, "quitar de Tico avisa una vez")
	check(im.sell_item(boots) > 0, "vender las botas de Tico")
	check(_take_events().equipment == 1, "vender de Tico avisa una vez")
	# No avisa: el botín y la mochila no son de Tico
	check(im.move_item(shield, &"bag", Vector2i(0, 0), 0) and im.rotate_in_place(shield) and im.move_item(shield, &"loot"), "el escudo del botín a la mochila, girado allí y de vuelta al botín")
	check(_take_events().equipment == 0, "botín, mochila y giros en la mochila no avisan del equipo")
	# Avisa una vez: el intercambio entre la mochila y Tico
	im.move_item(shield, &"bag", Vector2i(0, 0), 0)
	_take_events()
	check(im.move_item(shield, &"hero", Vector2i(1, 1), 0) and sword.place == &"bag", "el escudo de la mochila encima de la espada de Tico: la espada pasa a la mochila")
	check(_take_events().equipment == 1, "intercambiar con la mochila avisa una vez")
	_stop_listening()
	await _restore_inventory(saved)


func test_sell_and_sell_all_keep_the_best() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var common := _piece(&"boots_basic", 0.2)
	var epic := _piece(&"boots_basic", 0.95)
	var legend := _piece(&"boots_basic", 1.0)
	var kept := _piece(&"helmet_basic", 0.5)
	for p in [common, epic, legend, kept]:
		im.add_crafted_item(p)
	check(im.move_item(kept, &"bag", Vector2i(0, 0), 0), "una pieza en la mochila")
	var gold: int = im.sell_all_loot()
	check(gold == common.get_sell_price(), "Vender todo solo vende lo que no es Épico ni Legendario (%d)" % gold)
	check(im.get_loot().size() == 2 and epic in im.get_loot() and legend in im.get_loot(), "la épica y la legendaria siguen en el botín")
	check(kept.place == &"bag", "la mochila no se toca")
	check(im.sell_item(legend) == legend.get_sell_price() and not (legend in im.get_crafted_items()), "vender una suelta")
	check(im.get_quantity(&"gold") == gold + legend.get_sell_price(), "el oro sube lo vendido")
	await _restore_inventory(saved)


func test_totals_and_preview_use_the_hero_grid_only() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var shield := _piece(&"shield_basic", 0.8)
	var helmet := _piece(&"helmet_basic", 0.8)
	im.add_crafted_item(shield)
	im.add_crafted_item(helmet)
	im.move_item(shield, &"hero", Vector2i(0, 1), 0)
	im.move_item(helmet, &"bag", Vector2i(0, 0), 0)
	check(im.calculate_total_stats() == GearAuras.totals(im.hero_grid), "las estadísticas de Tico son las de su rejilla")
	var before: Dictionary = im.calculate_total_stats()
	var preview: Dictionary = im.preview_stats(helmet, &"hero", Vector2i(1, 1), 0)
	check(preview.hp > before.hp, "la vista previa suma el casco con su aura (%d → %d)" % [before.hp, preview.hp])
	check(im.calculate_total_stats() == before and helmet.place == &"bag", "la vista previa no mueve nada")
	await _restore_inventory(saved)


func test_hero_sprite_shows_the_best_piece_of_each_kind() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var weak := _piece(&"sword_masterwork", 0.3)
	var strong := _piece(&"sword_advanced", 0.9)
	strong.rank = 2
	for p in [weak, strong]:
		im.add_crafted_item(p)
	im.move_item(weak, &"hero", Vector2i(0, 0), 0)
	im.move_item(strong, &"hero", Vector2i(1, 0), 0)
	check(im.best_hero_item("main_hand") == strong, "el rango manda sobre el nivel")
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")
	add_child(hero)
	await get_tree().process_frame
	hero.refresh_gear()
	check(hero.gear.get("main_hand", {}).get("rarity", "") == "advanced", "Tico dibuja la espada de rango II (%s)" % hero.gear)
	hero.queue_free()
	await _restore_inventory(saved)


func test_equipment_rank_is_the_weakest_best_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	check(im.equipment_rank() == 1, "sin piezas, rango I")
	var sword3 := _piece(&"sword_basic")
	sword3.rank = 3
	var sword1 := _piece(&"sword_basic")
	var helmet2 := _piece(&"helmet_basic")
	helmet2.rank = 2
	for p in [sword3, sword1, helmet2]:
		im.add_crafted_item(p)
	im.move_item(sword3, &"hero", Vector2i(3, 0), 0)
	check(im.equipment_rank() == 3, "una espada de rango III: rango III")
	im.move_item(sword1, &"hero", Vector2i(2, 0), 0)
	check(im.equipment_rank() == 3, "otra espada de rango I no lo baja: cuenta la mejor espada")
	im.move_item(helmet2, &"hero", Vector2i(0, 0), 0)
	check(im.equipment_rank() == 2, "un casco de rango II sí: el menor entre los tipos")
	await _restore_inventory(saved)


func test_hero_stats_include_legendary_multipliers() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var shield := _piece(&"shield_basic", 1.0)  # Aguante: vida máxima ×1,2
	im.add_crafted_item(shield)
	im.move_item(shield, &"hero", Vector2i(0, 0), 0)
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")
	add_child(hero)
	await get_tree().process_frame
	var expected := CombatMath.hero_stats_with_powers(im.calculate_total_stats(), [&"shield_basic"])
	check(hero.max_hp == expected.max_hp and hero.max_hp > CombatMath.hero_stats(im.calculate_total_stats()).max_hp, "Aguante sube la vida de Tico (%d)" % hero.max_hp)
	hero.queue_free()
	await _restore_inventory(saved)


func test_forging_rolls_aristas_by_quality() -> void:
	var saved := _fresh_inventory()
	var cm := get_node("/root/CraftingManager")
	var im := _im()
	var Task = cm.get_script().CraftingTask  # clase interna del autoload (no tiene class_name)
	var bp: BlueprintResource = get_node("/root/DataManager").get_blueprint(&"sword_masterwork")
	var task = Task.new(9100, bp, 0)
	task.score_accumulated = 50.0
	task.max_score_accumulated = 100.0
	var fm_before: int = cm.forjamagia
	var queue_before: Array = cm.queue.duplicate()  # _finalize_task vacía su hueco y compacta la cola
	cm.forjamagia = 0  # sin bonus de Forjamagia: calidad 0,5 (Bueno)
	cm.rng.seed = 99
	var result: Dictionary = cm._finalize_task(task)
	var item: CraftedItem = result.crafted_item
	check(item != null and item.get_quality_tier() == "uncommon" and item.aristas.size() == 2, "una espada al 50 %% sale con 2 aristas (%s)" % (str(item.aristas) if item else "sin pieza"))
	check(item != null and item.place == &"loot" and im.get_loot()[0] == item, "y llega al botín, delante")
	cm.queue = queue_before
	cm.forjamagia = fm_before
	cm.rng.randomize()  # el sorteo vuelve a ser libre tras sembrarlo
	await _restore_inventory(saved)


# ─── Tarea 7: guardado versión 2 y migración ───────────────────────────

## Partida de la versión 1 (antes de la rejilla): 4 piezas equipadas y 40 sueltas, con récord 35.
func _v1_save() -> Dictionary:
	var items := []
	var equipped := {"main_hand": 0, "off_hand": 1, "head": 2, "feet": 3}
	var gear := [[&"sword_masterwork", 0.93], [&"shield_master", 0.5], [&"helmet_advanced", 0.6], [&"boots_master", 0.3]]
	for i in 44:
		var id: StringName = gear[i][0] if i < 4 else ITEM_IDS[i % ITEM_IDS.size()]
		var q: float = gear[i][1] if i < 4 else 0.2 + 0.018 * i
		var d := CraftedItem.new(_res(id), q).to_dict()
		for k in ["rank", "place", "x", "y", "rot", "aristas"]:
			d.erase(k)
		d["equipped"] = i < 4
		d["timestamp"] = 1000 + i
		items.append(d)
	return {
		"version": 1,
		"timestamp": 1790000000.0,
		"game": {"current_enemy_level": 7, "best_enemy_level": 35, "death_count": 2, "enemies_defeated": {}, "hero_loadout": {}},
		"data": {"unlocked_blueprints": {}},
		"inventory": {"materials": {"iron": 50, "gold": 300}, "crafted_items": items, "equipped_slots": equipped},
		"requests": {"free_requests_remaining": 0},
	}


func _load_save_dict(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	return SaveManager.load_game()


## Vuelve a cargar la partida de antes de la prueba (TestSuite solo restaura el fichero al terminar).
func _reload_user_save() -> void:
	if _had_save:
		var back := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		back.store_buffer(_save_backup)
		back.close()
		SaveManager.load_game()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	await get_tree().process_frame


## Una propiedad de cada pieza por marca de tiempo (única en la partida de prueba). El fichero de la versión 2
## guarda el botín primero, así que al cargarlo cambia el orden de la lista de piezas.
func _by_timestamp(im: Node, read: Callable) -> Dictionary:
	var out := {}
	for it in im.get_crafted_items():
		out[int(it.crafted_timestamp)] = read.call(it)
	return out


func test_v1_save_migrates_without_losing_pieces() -> void:
	var im := _im()
	check(_load_save_dict(_v1_save()), "la partida de la versión 1 carga")
	check(im.get_crafted_items().size() == 44, "ninguna pieza perdida (%d de 44)" % im.get_crafted_items().size())
	check(im.hero_grid_size() == Vector2i(6, 5) and im.expansions.size() == 3, "récord 35: jefes 10, 20 y 30 vencidos, 3 ampliaciones y rejilla de 6×5 (%s)" % im.hero_grid_size())
	check(im.get_hero_items().size() == 4, "con la rejilla de 6×5 caben las cuatro piezas equipadas (%d)" % im.get_hero_items().size())
	var hero_stamps: Array = im.get_hero_items().map(func(it): return int(it.crafted_timestamp))
	hero_stamps.sort()
	check(hero_stamps == [1000, 1001, 1002, 1003], "y son las que estaban equipadas en la partida antigua (%s)" % [hero_stamps])
	check(im.get_hero_items().size() + im.get_loot().size() == 44 and im.get_bag_items().is_empty(), "lo demás, al botín")
	var first: CraftedItem = im.get_loot()[0]
	check(im.get_loot().all(func(it): return InventoryManager.gear_score(it) <= InventoryManager.gear_score(first)), "el botín empieza por la mejor pieza")
	var aristas_a: Array = im.get_crafted_items().map(func(it): return it.aristas)
	check(aristas_a.any(func(a): return not a.is_empty()), "la migración sortea aristas: no salen todas vacías")
	check(_load_save_dict(_v1_save()), "se vuelve a cargar la misma partida")
	var aristas_b: Array = im.get_crafted_items().map(func(it): return it.aristas)
	check(aristas_a == aristas_b, "las aristas migradas salen siempre iguales")
	var migrated_aristas := _by_timestamp(im, func(it): return it.aristas.duplicate())
	var migrated_places := _by_timestamp(im, func(it): return [it.place, it.cell, it.rot])
	check(SaveManager.save_game(), "se guarda en la versión nueva")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(int(data.version) == SaveManager.SAVE_VERSION and data.inventory.has("hero_grid") and not data.inventory.has("equipped_slots"), "guardado versión 2, sin huecos fijos")
	# El fichero de la versión 2 también se carga: x, y y giro vuelven de JSON como decimales y las aristas como pares
	check(SaveManager.load_game(), "se carga el fichero de la versión 2")
	check(im.get_crafted_items().size() == 44, "ninguna pieza perdida al recargarlo (%d de 44)" % im.get_crafted_items().size())
	check(im.hero_grid_size() == Vector2i(6, 5) and im.expansions.size() == 3, "la rejilla de 6×5 y las 3 ampliaciones vuelven (%s)" % im.hero_grid_size())
	check(_by_timestamp(im, func(it): return it.aristas.duplicate()) == migrated_aristas, "las aristas vuelven iguales del fichero")
	check(_by_timestamp(im, func(it): return [it.place, it.cell, it.rot]) == migrated_places, "cada pieza vuelve a su sitio, casilla y giro")
	await _reload_user_save()


func test_v2_save_round_trip() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var a := _piece(&"shield_master", 0.5, [Vector2i(2, 1)])
	var b := _piece(&"boots_advanced", 0.7)
	var c := _piece(&"sword_basic", 0.3)
	for p in [a, b, c]:
		im.add_crafted_item(p)
	im.move_item(a, &"hero", Vector2i(0, 0), 0)
	im.move_item(b, &"bag", Vector2i(2, 1), 3)
	var data: Dictionary = im.to_save_data()
	im.load_save_data(data, 1)
	var by_id := {}
	for it in im.get_crafted_items():
		by_id[it.item_resource.item_id] = it
	check(by_id[&"shield_master"].place == &"hero" and by_id[&"shield_master"].aristas == [Vector2i(2, 1)], "el escudo vuelve a Tico con su arista")
	check(by_id[&"boots_advanced"].place == &"bag" and by_id[&"boots_advanced"].cell == Vector2i(2, 1) and by_id[&"boots_advanced"].rot == 3, "las botas vuelven a su casilla y giro de la mochila")
	check(by_id[&"sword_basic"].place == &"loot", "la espada sigue en el botín")
	await _restore_inventory(saved)


func test_impossible_saved_position_goes_to_loot() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var a := _piece(&"shield_master")
	var b := _piece(&"helmet_basic")
	im.add_crafted_item(a)
	im.add_crafted_item(b)
	im.move_item(a, &"hero", Vector2i(0, 0), 0)
	im.move_item(b, &"bag", Vector2i(5, 3), 0)
	var data: Dictionary = im.to_save_data()
	for d in data.crafted_items:
		if d.item_id == "shield_master":
			d.x = 3  # un escudo de 2×3 desde la columna 3 de una rejilla de 4×4 se sale
	im.load_save_data(data, 1)
	var by_id := {}
	for it in im.get_crafted_items():
		by_id[it.item_resource.item_id] = it
	check(by_id.size() == 2, "las dos piezas siguen ahí")
	check(by_id[&"shield_master"].place == &"loot", "el escudo con una posición imposible pasa al botín")
	check(by_id[&"helmet_basic"].place == &"bag" and by_id[&"helmet_basic"].cell == Vector2i(5, 3), "el casco sigue en su sitio de la mochila")
	await _restore_inventory(saved)


## Recoge lo que se escribe en el registro mientras está puesto: los avisos (push_warning) se cuentan y los
## mensajes (print) se guardan.
class LogCapture extends Logger:
	var warnings := 0
	var messages: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			warnings += 1

	func _log_message(message: String, _error: bool) -> void:
		messages.append(message)


## Una partida más antigua es una migración prevista (spec, apartado 10): se avisa con un mensaje normal, no con
## un aviso. Solo una más nueva que el juego avisa. El mensaje hace de control: sin él, un registro que no
## recibiera nada también daría cero avisos.
func test_older_save_migrates_without_a_warning() -> void:
	var captured := LogCapture.new()
	OS.add_logger(captured)
	check(_load_save_dict(_v1_save()), "carga una partida de la versión 1")
	OS.remove_logger(captured)
	check(captured.messages.any(func(m): return "versión 1" in m and "se migra" in m), "el registro dice que la migra (%d mensajes)" % captured.messages.size())
	check(captured.warnings == 0, "y no avisa (%d avisos)" % captured.warnings)
	await _reload_user_save()


# ─── Tarea 8: vistas de rejilla y botín ────────────────────────────────

func test_grid_view_maps_points_to_cells_and_pieces() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var sword := _piece(&"sword_advanced")
	g.place(sword, Vector2i(2, 1), 0)
	var view := GearGridView.new()
	add_child(view)
	view.setup(g, Vector2i(6, 6))
	check(view.size == Vector2(660, 660), "la rejilla dibuja 6×6 casillas de 110 px (%s)" % view.size)
	check(view.cell_at(Vector2(230, 120)) == Vector2i(2, 1), "un punto cae en su casilla")
	check(view.item_at_local(Vector2(240, 350)) == sword and view.item_at_local(Vector2(10, 10)) == null, "encuentra la pieza bajo el dedo")
	check(view.item_origin(sword) == Vector2(220, 110), "esquina de la pieza en píxeles")
	view.queue_free()


func test_loot_strip_lays_pieces_flat_and_scrolls() -> void:
	var tall := _piece(&"sword_masterwork")  # 1×4: tumbada ocupa 4×1
	var strip := LootStripView.new()
	strip.size = Vector2(960, 330)
	add_child(strip)
	var list := [tall]
	for i in 5:
		list.append(_piece(&"shield_master"))
	strip.set_items(list)
	check(LootStripView.flat_rot(tall) == 1, "la espada se enseña tumbada")
	var first: Dictionary = strip.slot_at_local(Vector2(40, 165))
	check(first.get("item") == tall and first.get("rot") == 1, "la primera pieza, a la izquierda")
	check(strip.max_scroll() > 0.0, "si no cabe todo, se desplaza (%.0f)" % strip.max_scroll())
	strip.scroll = strip.max_scroll()
	check(strip.slot_at_local(Vector2(900, 165)).get("item") == list.back(), "desplazada, la última queda a la derecha")
	strip.queue_free()


# ─── Tarea 9: panel de Equipo: tocar, arrastrar y soltar ───────────────

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


func _cell_center(view: Control, cell: Vector2i) -> Vector2:
	return view.global_position + (Vector2(cell) + Vector2(0.5, 0.5)) * GearGridView.CELL


## Dónde poner el dedo para que la pieza cogida caiga con su caja en `cell` de `view` (va una casilla
## por encima del dedo).
func _finger_for(panel: Control, view: Control, cell: Vector2i) -> Vector2:
	var grab: Vector2 = panel._press.origin - panel._press.pos
	return view.global_position + Vector2(cell) * GearGridView.CELL - grab + Vector2(0, GearGridView.CELL)


## Calla las voces de AudioManager y deja que el hilo de audio las suelte: el clinc de colocar una pieza en
## Tico sigue sonando al acabar la suite y Godot avisaría de recursos «still in use at exit» (como en
## GameplayTests._silence_loot_sounds).
func _silence_sounds() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		for voice in am.get_children():
			if voice is AudioStreamPlayer:
				voice.stop()
	await get_tree().create_timer(0.1).timeout


func test_tap_rotates_a_piece_in_the_grid() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")
	im.add_crafted_item(sword)
	im.move_item(sword, &"hero", Vector2i(1, 0), 0)
	var panel := _new_panel()
	var p := _cell_center(panel._hero_view, Vector2i(1, 1))
	_mouse(panel, p, true)
	_mouse(panel, p, false)
	check(sword.rot == 1, "un toque la gira (%d)" % sword.rot)
	check(panel._selected == sword, "y la enseña en la ficha")
	panel.queue_free()
	await _restore_inventory(saved)


func test_drag_from_loot_places_and_swaps() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var old_sword := _piece(&"sword_basic", 0.5)
	var new_sword := _piece(&"sword_basic", 0.95)
	im.add_crafted_item(old_sword)
	im.move_item(old_sword, &"hero", Vector2i(3, 0), 0)  # de pie en (3,0)-(3,1)
	im.add_crafted_item(new_sword)
	var panel := _new_panel()
	var start: Vector2 = panel._loot_view.global_position + Vector2(40, 165)
	_mouse(panel, start, true)
	check(panel._press.get("item") == new_sword and panel._press.get("rot") == 1, "se coge la espada nueva, tumbada como en el botín")
	_move(panel, start + Vector2(0, -30))  # hacia arriba: se coge (de lado se desplazaría el botín)
	check(panel._dragging, "empieza el arrastre")
	var finger := _finger_for(panel, panel._hero_view, Vector2i(2, 0))  # tumbada: (2,0)-(3,0), encima de la vieja
	_move(panel, finger)
	check(panel._target.get("ok", false) and panel._target.get("swap") == old_sword, "encima de la vieja: intercambio (%s)" % [panel._target])
	_mouse(panel, finger, false)
	check(new_sword.place == &"hero" and new_sword.cell == Vector2i(2, 0) and old_sword.place == &"loot", "la nueva en Tico y la vieja al botín")
	check(not panel._dragging and panel._press.is_empty(), "el arrastre termina")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


func test_second_finger_rotates_while_dragging() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")
	im.add_crafted_item(sword)
	im.move_item(sword, &"bag", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var start := _cell_center(panel._bag_view, Vector2i(0, 1))
	_mouse(panel, start, true)
	_move(panel, start + Vector2(40, 40))
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(900, 1500)
	panel._input(touch)
	check(panel._drag_rot == 1, "un segundo dedo gira la pieza que se arrastra (%d)" % panel._drag_rot)
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	panel._input(key)
	check(panel._drag_rot == 2, "en el ordenador, la tecla R también (%d)" % panel._drag_rot)
	_move(panel, Vector2(540, 60))  # arriba del todo, fuera de las rejillas y del botín
	_mouse(panel, Vector2(540, 60), false)  # soltada ahí vuelve a su sitio
	check(sword.place == &"bag" and sword.cell == Vector2i(0, 0) and sword.rot == 0, "soltada fuera, vuelve a su sitio sin girar")
	panel.queue_free()
	await _restore_inventory(saved)


func test_new_loot_while_dragging_is_not_lost() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var dragged := _piece(&"helmet_basic")
	im.add_crafted_item(dragged)
	var panel := _new_panel()
	var start: Vector2 = panel._loot_view.global_position + Vector2(60, 165)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	check(panel._dragging, "se arrastra el casco")
	var fresh := _piece(&"boots_basic")
	im.add_crafted_item(fresh)  # llega una pieza de la forja a mitad del arrastre
	check(panel._dragging and panel._press.get("item") == dragged, "el arrastre sigue con el casco")
	var finger := _finger_for(panel, panel._hero_view, Vector2i(0, 0))
	_move(panel, finger)
	_mouse(panel, finger, false)
	check(dragged.place == &"hero" and fresh.place == &"loot", "el casco en Tico y las botas nuevas en el botín")
	check(im.get_crafted_items().size() == 2, "no se pierde ninguna")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


func test_loot_strip_scrolls_sideways() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	for i in 6:
		im.add_crafted_item(_piece(&"shield_master"))
	var panel := _new_panel()
	var start: Vector2 = panel._loot_view.global_position + Vector2(600, 165)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(-300, 5))
	check(not panel._dragging and panel._loot_view.scroll > 250.0, "de lado se desplaza la tira, no se coge la pieza (%.0f)" % panel._loot_view.scroll)
	_mouse(panel, start + Vector2(-300, 5), false)
	panel.queue_free()
	await _restore_inventory(saved)


## Soltar una pieza donde ya estaba vale, pero no mueve nada: ni suena el clinc ni Tico se materializa de nuevo.
## Soltar cualquier pieza deja su ficha en pantalla, se mueva o no.
func test_dropping_a_piece_on_its_own_place_does_not_rematerialize_tico() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")  # 1×3
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(sword)
	im.add_crafted_item(helmet)
	im.move_item(sword, &"hero", Vector2i(1, 0), 0)
	var panel := _new_panel()
	var puppet: Node = panel._puppet
	puppet.set("_materialize", 1.0)  # Tico ya está entero
	var tap: Vector2 = panel._loot_view.global_position + Vector2(40, 165)
	_mouse(panel, tap, true)
	_mouse(panel, tap, false)
	check(panel._selected == helmet and "Casco básico" in panel._ficha_label.text, "un toque en el casco del botín lo enseña en la ficha")
	var start := _cell_center(panel._hero_view, Vector2i(1, 1))
	_mouse(panel, start, true)
	_move(panel, start + Vector2(30, 0))
	check(panel._dragging, "se coge la espada de Tico")
	var finger := _finger_for(panel, panel._hero_view, Vector2i(1, 0))  # su casilla y su giro
	_move(panel, finger)
	check(panel._target.get("ok", false) and panel._target.get("swap") == null and panel._target.get("cell") == Vector2i(1, 0), "el destino es su propio sitio (%s)" % [panel._target])
	_mouse(panel, finger, false)
	check(sword.place == &"hero" and sword.cell == Vector2i(1, 0) and sword.rot == 0, "la espada sigue donde estaba")
	check(is_equal_approx(puppet.get("_materialize"), 1.0), "soltarla ahí no vuelve a materializar a Tico (%s)" % puppet.get("_materialize"))
	check(panel._selected == sword and "Espada avanzada" in panel._ficha_label.text, "pero la ficha pasa a la espada soltada (%s)" % panel._ficha_label.text)
	_mouse(panel, tap, true)  # otra vez el casco, y luego la espada a otra casilla de verdad
	_mouse(panel, tap, false)
	check(panel._selected == helmet and "Casco básico" in panel._ficha_label.text, "la ficha vuelve al casco")
	_mouse(panel, start, true)
	_move(panel, start + Vector2(30, 0))
	finger = _finger_for(panel, panel._hero_view, Vector2i(2, 0))
	_move(panel, finger)
	_mouse(panel, finger, false)
	check(sword.cell == Vector2i(2, 0), "la espada se mueve a otra casilla (%s)" % sword.cell)
	check(is_equal_approx(puppet.get("_materialize"), 0.55), "y ahí sí se materializa de nuevo (%s)" % puppet.get("_materialize"))
	check(panel._selected == sword and "Espada avanzada" in panel._ficha_label.text, "y la ficha enseña la espada, no el casco (%s)" % panel._ficha_label.text)
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


# ─── Tarea 9, revisión: Atrás, destino bajo la pieza y detalles del arrastre ───

## Atrás en Android llega como NOTIFICATION_WM_GO_BACK_REQUEST, no como tecla, y el árbol cierra el juego si
## quit_on_go_back es true: mientras el panel está abierto, Atrás lo cierra a él y solo a él.
func test_android_back_closes_the_panel_and_not_the_game() -> void:
	var tree := get_tree()
	var before := tree.quit_on_go_back
	check(before, "antes de abrir el panel, Atrás cierra el juego, como siempre (ningún panel de otra prueba lo dejó retenido)")
	var closed := {"count": 0}
	var panel := _new_panel()
	panel.panel_closed.connect(func(): closed.count += 1)
	check(not tree.quit_on_go_back, "con el panel abierto, Atrás no cierra el juego")
	panel.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not panel.visible and closed.count == 1, "Atrás cierra el panel (avisos: %d)" % closed.count)
	check(not tree.quit_on_go_back, "y en ese mismo Atrás el juego sigue abierto: lo de antes se devuelve después")
	await get_tree().process_frame
	check(tree.quit_on_go_back == before, "un fotograma después, Atrás vuelve a ser lo de antes (%s)" % tree.quit_on_go_back)
	panel.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(closed.count == 1 and tree.quit_on_go_back == before, "con el panel cerrado, Atrás no hace nada del panel")
	panel.open()
	check(not tree.quit_on_go_back, "abierto otra vez, vuelve a retener Atrás")
	panel.open()  # abrirlo dos veces no pierde lo guardado
	panel.close()
	await get_tree().process_frame
	check(tree.quit_on_go_back == before, "y al cerrarlo lo devuelve, aunque se abriera dos veces (%s)" % tree.quit_on_go_back)
	panel.queue_free()


## Si el panel se oculta sin pasar por close(), o desaparece abierto, Atrás se devuelve igualmente.
func test_back_is_given_back_if_the_panel_goes_away_open() -> void:
	var tree := get_tree()
	var before := tree.quit_on_go_back
	var hidden := _new_panel()
	hidden.visible = false  # algo lo oculta sin pasar por close()
	await get_tree().process_frame
	check(tree.quit_on_go_back == before, "oculto sin close(), Atrás se devuelve (%s)" % tree.quit_on_go_back)
	hidden.queue_free()
	var freed := _new_panel()
	check(not tree.quit_on_go_back, "otro panel abierto vuelve a retener Atrás")
	freed.queue_free()
	await get_tree().process_frame
	check(tree.quit_on_go_back == before, "y si desaparece abierto, lo devuelve (%s)" % tree.quit_on_go_back)


## Manda la pieza, no el dedo: con la rejilla de 6×6, una pieza sobre su última fila, con el dedo ya dentro de la
## tira del botín, cae en la rejilla.
func test_dropping_on_the_last_row_of_a_full_grid_places_the_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var data: Dictionary = im.to_save_data()
	data["expansions"] = GridExpansions.ids().map(func(id): return String(id))
	im.load_save_data(data, 1)  # las cuatro ampliaciones forjadas: 6×6
	check(im.hero_grid_size() == Vector2i(6, 6), "Tico tiene la rejilla de 6×6 (%s)" % im.hero_grid_size())
	var helmet := _piece(&"helmet_basic")  # 1×1
	im.add_crafted_item(helmet)
	var panel := _new_panel()
	var start: Vector2 = panel._loot_view.global_position + Vector2(60, 165)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(2, 5))
	check(panel._loot_view.get_global_rect().has_point(finger), "el dedo ya está dentro de la tira del botín (%s)" % finger)
	_move(panel, finger)
	check(panel._target.get("place") == &"hero" and panel._target.get("cell") == Vector2i(2, 5) and panel._target.get("ok", false), "el destino es la casilla de Tico bajo la pieza (%s)" % [panel._target])
	_mouse(panel, finger, false)
	check(helmet.place == &"hero" and helmet.cell == Vector2i(2, 5), "y al soltar la pieza queda ahí")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## En una rejilla pequeña, las filas punteadas (aún sin abrir) no se llevan lo que se suelta sobre el botín.
func test_dashed_rows_do_not_steal_a_drop_meant_for_the_loot() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")  # 1×1
	im.add_crafted_item(helmet)
	im.move_item(helmet, &"hero", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var start := _cell_center(panel._hero_view, Vector2i(0, 0))
	_mouse(panel, start, true)
	_move(panel, start + Vector2(30, 30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(2, 5))  # la pieza sobre la fila 5, que en 4×4 aún no existe
	check(panel._loot_view.get_global_rect().has_point(finger), "el dedo está dentro de la tira del botín (%s)" % finger)
	_move(panel, finger)
	check(panel._target.get("place") == &"loot", "sobre una casilla que no existe manda el botín (%s)" % [panel._target])
	_mouse(panel, finger, false)
	check(helmet.place == &"loot", "y la pieza sale de Tico al botín")
	panel.queue_free()
	await _restore_inventory(saved)


## Mantener R pulsada repite la tecla (echo): la pieza gira una sola vez.
func test_holding_r_rotates_only_once() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")
	im.add_crafted_item(sword)
	im.move_item(sword, &"bag", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var start := _cell_center(panel._bag_view, Vector2i(0, 1))
	_mouse(panel, start, true)
	_move(panel, start + Vector2(40, 40))
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	panel._input(key)
	check(panel._drag_rot == 1, "R gira una vez (%d)" % panel._drag_rot)
	var repeat := InputEventKey.new()
	repeat.keycode = KEY_R
	repeat.pressed = true
	repeat.echo = true
	panel._input(repeat)
	panel._input(repeat)
	check(panel._drag_rot == 1, "las repeticiones de la tecla mantenida no la giran más (%d)" % panel._drag_rot)
	_move(panel, Vector2(540, 60))
	_mouse(panel, Vector2(540, 60), false)
	panel.queue_free()
	await _restore_inventory(saved)


## Si llega una pieza a mitad de un arrastre, la vista previa del cambio no se pierde.
func test_new_loot_while_dragging_keeps_the_stats_preview() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")
	im.add_crafted_item(sword)
	var panel := _new_panel()
	var start: Vector2 = panel._loot_view.global_position + Vector2(60, 165)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(0, 0))
	_move(panel, finger)
	check(panel._target.get("ok", false) and "[color=" in panel._stats_label.text, "sobre Tico vacío, la barra enseña el cambio (%s)" % panel._stats_label.text)
	im.add_crafted_item(_piece(&"boots_basic"))  # llega una pieza de la forja a mitad del arrastre
	check(panel._dragging and panel._target.get("ok", false) and "[color=" in panel._stats_label.text, "y la barra sigue enseñándolo (%s)" % panel._stats_label.text)
	_move(panel, Vector2(540, 60))
	_mouse(panel, Vector2(540, 60), false)
	panel.queue_free()
	await _restore_inventory(saved)


## Si crece la rejilla a mitad de un arrastre, el destino y sus casillas se calculan de nuevo.
func test_grid_growing_while_dragging_recalculates_the_target() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var shield := _piece(&"shield_advanced")  # 2×2
	im.add_crafted_item(shield)
	var panel := _new_panel()
	var start: Vector2 = panel._loot_view.global_position + Vector2(60, 165)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(3, 0))  # en 4×4 se sale por la derecha
	_move(panel, finger)
	check(not panel._target.get("ok", true) and panel._hero_view.drop_cells.size() == 2 and panel._hero_view.drop_cells.values().all(func(c): return c == GearGridView.COLOR_BAD), "en 4×4 no cabe: dos casillas en rojo (%s)" % [panel._hero_view.drop_cells])
	im.hero_grid.resize(Vector2i(5, 4))
	im.grid_resized.emit(Vector2i(5, 4))  # la ampliación llega a mitad del arrastre
	check(panel._target.get("ok", false), "con la columna nueva ya cabe (%s)" % [panel._target])
	check(panel._hero_view.drop_cells.size() == 4 and panel._hero_view.drop_cells.values().all(func(c): return c == GearGridView.COLOR_OK), "y las cuatro casillas pasan a verde (%s)" % [panel._hero_view.drop_cells])
	_move(panel, Vector2(540, 60))
	_mouse(panel, Vector2(540, 60), false)
	panel.queue_free()
	await _restore_inventory(saved)


## Si algo oculta el panel sin pasar por close() en mitad de un arrastre, al abrirlo otra vez no queda nada a medias.
func test_open_cancels_a_drag_left_over() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	var panel := _new_panel()
	var start: Vector2 = panel._loot_view.global_position + Vector2(60, 165)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	check(panel._dragging and panel._loot_view.hidden_item == helmet, "se arrastra el casco y la tira deja de dibujarlo")
	panel.visible = false  # algo lo oculta sin pasar por close()
	panel.open()
	check(not panel._dragging and panel._press.is_empty() and panel._loot_view.hidden_item == null, "al abrirlo otra vez el arrastre queda cancelado y el casco vuelve a verse")
	panel.queue_free()
	await _restore_inventory(saved)


## Con un ancestro oculto el panel no se ve aunque su visible sea true: no tiene que leer el dedo.
func test_a_hidden_ancestor_stops_the_panel_reading_the_finger() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")
	im.add_crafted_item(sword)
	im.move_item(sword, &"hero", Vector2i(1, 0), 0)
	var holder := Control.new()
	add_child(holder)
	var panel: Control = load("res://scenes/UI/EquipmentPanel.tscn").instantiate()
	holder.add_child(panel)
	panel.open()
	var p := _cell_center(panel._hero_view, Vector2i(1, 1))
	holder.visible = false
	check(panel.visible and not panel.is_visible_in_tree(), "el panel sigue abierto pero no se ve")
	_mouse(panel, p, true)
	check(panel._press.is_empty(), "y no lee el dedo")
	holder.visible = true
	_mouse(panel, p, true)
	check(not panel._press.is_empty(), "al volver a verse, sí")
	_mouse(panel, p, false)
	holder.queue_free()
	await _restore_inventory(saved)


# ─── Tarea 10: ficha, venta e insignia ─────────────────────────────────

func _long_press(panel: Control, pos: Vector2) -> void:
	_mouse(panel, pos, true)
	panel._press.time = Time.get_ticks_msec() - 1000  # como si llevara 1 s pulsada
	panel._process(0.0)


func test_long_press_opens_the_card() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_advanced", 1.0)
	im.add_crafted_item(helmet)
	im.move_item(helmet, &"hero", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var p := _cell_center(panel._hero_view, Vector2i(0, 0))
	_long_press(panel, p)
	check(panel._card.visible and panel._card_item == helmet, "mantener pulsado abre la ficha completa")
	check(panel._card_text.text.contains(tr("Regeneración")), "la ficha enseña la habilidad legendaria (%s)" % panel._card_text.text)
	_mouse(panel, p, false)
	check(helmet.rot == 0, "soltar tras la pulsación larga no gira")
	panel._card_to_bag()
	check(helmet.place == &"bag" and not panel._card.visible, "A la mochila la manda al primer hueco libre y cierra")
	panel.queue_free()
	await _restore_inventory(saved)


func test_sell_zone_sells_and_asks_for_the_best() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var plain := _piece(&"boots_basic", 0.3)
	var epic := _piece(&"boots_basic", 0.95)
	for p in [plain, epic]:
		im.add_crafted_item(p)
	im.move_item(plain, &"bag", Vector2i(0, 0), 0)
	im.move_item(epic, &"bag", Vector2i(2, 0), 0)
	var panel := _new_panel()
	var sell_point: Vector2 = panel.sell_zone.get_global_rect().get_center()
	for item in [plain, epic]:
		var start := _cell_center(panel._bag_view, item.cell)
		_mouse(panel, start, true)
		_move(panel, start + Vector2(0, -40))
		_move(panel, sell_point)
		check(panel._target.get("place") == &"sell", "sobre la zona de venta")
		check(panel.sell_label.text.contains(str(item.get_sell_price())), "la zona enseña el precio (%s)" % panel.sell_label.text)
		_mouse(panel, sell_point, false)
	check(not (plain in im.get_crafted_items()), "la pieza normal se vende al soltarla")
	check(epic in im.get_crafted_items() and panel._confirm_box.visible, "la épica pide confirmación antes")
	var gold: int = im.get_quantity(&"gold")
	panel._on_confirm_yes()
	check(not (epic in im.get_crafted_items()) and im.get_quantity(&"gold") == gold + epic.get_sell_price(), "al confirmar, se vende")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


func test_sell_all_asks_and_keeps_the_best() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var a := _piece(&"sword_basic", 0.2)
	var b := _piece(&"sword_basic", 0.5)
	var legend := _piece(&"sword_basic", 1.0)
	for p in [a, b, legend]:
		im.add_crafted_item(p)
	var panel := _new_panel()
	panel._on_sell_all()
	check(panel._confirm_box.visible and panel._confirm_text.text.contains(str(a.get_sell_price() + b.get_sell_price())), "pide confirmación con el total (%s)" % panel._confirm_text.text)
	check(im.get_loot().size() == 3, "sin confirmar no vende nada")
	panel._on_confirm_yes()
	check(im.get_loot() == [legend], "vende todo salvo la legendaria")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## Con solo lo mejor en el botín, Vender todo no tiene nada que vender y no pregunta.
func test_sell_all_does_not_ask_when_only_the_best_is_left() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	im.add_crafted_item(_piece(&"sword_basic", 0.95))
	var panel := _new_panel()
	panel._on_sell_all()
	check(not panel._confirm_box.visible, "con solo una épica en el botín no se pregunta")
	check(im.get_loot().size() == 1, "y el botín queda como estaba")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## La pulsación larga termina la pulsación: si el dedo se mueve después, no arrastra la pieza por debajo de la ficha.
func test_long_press_ends_the_press() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")  # 1×3
	im.add_crafted_item(sword)
	im.move_item(sword, &"hero", Vector2i(1, 0), 0)
	var panel := _new_panel()
	var p := _cell_center(panel._hero_view, Vector2i(1, 1))
	_long_press(panel, p)
	check(panel._card.visible and panel._card_item == sword, "la pulsación larga abre la ficha")
	check(panel._press.is_empty() and panel._selected == sword, "y termina la pulsación, con la pieza elegida en la ficha breve")
	_move(panel, p + Vector2(60, -60))
	check(not panel._dragging and panel._hero_view.hidden_item == null, "mover el dedo después no arrastra nada")
	_mouse(panel, p + Vector2(60, -60), false)
	check(sword.cell == Vector2i(1, 0) and sword.rot == 0 and panel._card.visible, "soltar no mueve ni gira la pieza, y la ficha sigue abierta")
	panel.queue_free()
	await _restore_inventory(saved)


## Vender una pieza de Tico arrastrándola a la zona de venta. La venta ocurre dentro de _drop, con el arrastre aún en
## marcha: el refresco que provoca recalcula el destino con la pieza ya vendida (sin errores).
func test_dragging_a_piece_of_tico_to_the_sell_zone_sells_it() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_basic", 0.3)  # normal: se vende sin preguntar
	im.add_crafted_item(sword)
	im.move_item(sword, &"hero", Vector2i(1, 0), 0)
	var panel := _new_panel()
	var price := sword.get_sell_price()
	var gold: int = im.get_quantity(&"gold")
	var start := _cell_center(panel._hero_view, Vector2i(1, 0))
	_mouse(panel, start, true)
	_move(panel, start + Vector2(30, 0))
	check(panel._dragging, "se coge la espada de Tico")
	var sell_point: Vector2 = panel.sell_zone.get_global_rect().get_center()
	_move(panel, sell_point)
	check(panel._target.get("place") == &"sell" and panel._target.get("ok", false), "sobre la zona de venta (%s)" % [panel._target])
	check("[color=" in panel._stats_label.text, "la barra enseña lo que perdería Tico (%s)" % panel._stats_label.text)
	_mouse(panel, sell_point, false)
	check(not (sword in im.get_crafted_items()) and not (sword in im.hero_grid.items) and im.get_hero_items().is_empty(), "la espada sale de Tico y del inventario")
	check(im.get_quantity(&"gold") == gold + price, "el oro sube lo que valía (%d)" % im.get_quantity(&"gold"))
	check(not panel._confirm_box.visible and not panel._dragging and panel._press.is_empty() and panel._target.is_empty(), "no queda nada a medias")
	check(panel._hero_view.hidden_item == null and not ("[color=" in panel._stats_label.text), "la rejilla se ve entera y la barra, sin cambios")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## La zona de venta se mira primero y por el dedo: con el dedo en ella, una pieza ancha cogida por la derecha puede estar
## aún sobre la mochila, y no por eso el destino es la mochila.
func test_sell_zone_wins_over_the_bag_under_the_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_master", 0.95)  # caja de 3×2
	im.add_crafted_item(helmet)
	im.move_item(helmet, &"bag", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var start := _cell_center(panel._bag_view, Vector2i(2, 1))  # su casilla de abajo a la derecha
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -30))
	check(panel._dragging, "se coge el casco maestro por su extremo derecho")
	_move(panel, panel.sell_zone.get_global_rect().position + Vector2(20, 250))  # en la zona, cerca de su borde izquierdo
	var anchor: Vector2 = panel._ghost_origin() + Vector2(GearGridView.CELL, GearGridView.CELL) * 0.5
	var under: Vector2i = panel._bag_view.cell_at(anchor - panel._bag_view.global_position)
	check(panel._bag_view.grid.in_bounds(under), "la pieza sigue sobre una casilla de la mochila (%s)" % under)
	check(panel._target.get("place") == &"sell", "pero el destino es la zona de venta (%s)" % [panel._target])
	_move(panel, Vector2(540, 60))  # fuera de todo: se cancela
	_mouse(panel, Vector2(540, 60), false)
	check(helmet.place == &"bag" and helmet.cell == Vector2i(0, 0), "soltada fuera, la pieza vuelve a su sitio")
	panel.queue_free()
	await _restore_inventory(saved)


## La zona de venta enseña el precio y se ilumina solo mientras la pieza está sobre ella.
func test_sell_zone_lights_up_only_while_the_piece_is_over_it() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var epic := _piece(&"helmet_basic", 0.95)  # épica: soltarla en la zona pregunta antes de vender
	im.add_crafted_item(epic)
	im.move_item(epic, &"bag", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var idle: String = panel.sell_label.text
	var inside: Vector2 = panel.sell_zone.get_global_rect().get_center()
	var start := _cell_center(panel._bag_view, Vector2i(0, 0))
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	check(panel.sell_label.text == idle and panel.sell_zone.modulate == Color.WHITE, "arrastrando fuera de la zona, ni precio ni brillo")
	_move(panel, inside)
	check(panel.sell_label.text.contains(str(epic.get_sell_price())) and panel.sell_zone.modulate != Color.WHITE, "sobre la zona, el precio y el brillo")
	_move(panel, start + Vector2(0, -40))
	check(panel.sell_label.text == idle and panel.sell_zone.modulate == Color.WHITE, "al salir de la zona vuelve a ser la de siempre")
	_move(panel, inside)
	_mouse(panel, inside, false)
	check(panel._confirm_box.visible and panel.sell_label.text == idle and panel.sell_zone.modulate == Color.WHITE, "al soltar vuelve a ser la de siempre, aunque se pida confirmar")
	panel.queue_free()
	await _restore_inventory(saved)


## Los botones de la ficha completa: Al botín, A la mochila (con y sin sitio) y Vender (con y sin confirmación).
func test_card_buttons_send_and_sell() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_basic", 0.3)
	var epic := _piece(&"helmet_basic", 0.95)
	im.add_crafted_item(sword)
	im.add_crafted_item(epic)
	im.move_item(sword, &"hero", Vector2i(0, 0), 0)
	var panel := _new_panel()
	panel._open_card(sword)
	check(panel._card_sell_btn.text.contains(str(sword.get_sell_price())), "el botón Vender enseña el precio (%s)" % panel._card_sell_btn.text)
	check(panel._card_text.text.contains(tr("Sin aristas")), "la ficha dice cuántas aristas trae (%s)" % panel._card_text.text)
	panel._card_to_loot()
	check(sword.place == &"loot" and not panel._card.visible, "Al botín la saca de Tico y cierra la ficha")
	panel._open_card(epic)
	panel._card_sell()
	check(not panel._card.visible and panel._confirm_box.visible and epic in im.get_crafted_items(), "vender una épica desde la ficha la cierra y pide confirmar")
	panel._close_confirm()
	var price := sword.get_sell_price()
	var gold: int = im.get_quantity(&"gold")
	panel._open_card(sword)
	panel._card_sell()
	check(not (sword in im.get_crafted_items()) and im.get_quantity(&"gold") == gold + price and not panel._confirm_box.visible, "vender una normal desde la ficha la vende sin preguntar")
	for y in 4:
		for x in 6:
			var filler := _piece(&"helmet_basic", 0.5)
			im.add_crafted_item(filler)
			im.move_item(filler, &"bag", Vector2i(x, y), 0)
	panel._open_card(epic)
	panel._card_to_bag()
	check(epic.place == &"loot" and not panel._card.visible, "con la mochila llena, A la mochila no mueve la pieza")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## Con la ficha o la confirmación abiertas el dedo es de sus botones: el panel no coge ni gira las piezas de debajo.
func test_overlays_take_the_finger() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")  # 1×3
	im.add_crafted_item(sword)
	im.move_item(sword, &"hero", Vector2i(1, 0), 0)
	var panel := _new_panel()
	var p := _cell_center(panel._hero_view, Vector2i(1, 1))
	panel._open_card(sword)
	_mouse(panel, p, true)
	_mouse(panel, p, false)
	check(panel._press.is_empty() and sword.rot == 0, "con la ficha abierta, un toque sobre la pieza de debajo no hace nada")
	panel._close_card()
	panel._confirm("¿Seguro?", func(): pass)
	_mouse(panel, p, true)
	_mouse(panel, p, false)
	check(panel._press.is_empty() and sword.rot == 0, "con la confirmación abierta, tampoco")
	panel._close_confirm()
	_mouse(panel, p, true)
	_mouse(panel, p, false)
	check(sword.rot == 1, "y con las dos cerradas el toque vuelve a girarla (%d)" % sword.rot)
	panel.queue_free()
	await _restore_inventory(saved)


## Atrás (Android) y Escape cierran lo que esté más arriba: la confirmación, si no la ficha y, si no, el panel.
func test_back_closes_the_topmost_overlay_first() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var epic := _piece(&"helmet_basic", 0.95)
	var plain := _piece(&"boots_basic", 0.3)
	im.add_crafted_item(epic)
	im.add_crafted_item(plain)
	var panel := _new_panel()
	var closed := {"count": 0}
	panel.panel_closed.connect(func(): closed.count += 1)
	var gold: int = im.get_quantity(&"gold")
	panel._open_card(epic)
	panel.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not panel._card.visible and panel._card_item == null and panel.visible and closed.count == 0, "Atrás con la ficha abierta cierra solo la ficha")
	check(not get_tree().quit_on_go_back, "y el panel sigue reteniendo Atrás: el juego no se cierra")
	panel._sell(epic)
	check(panel._confirm_box.visible, "vender una épica pide confirmación")
	panel.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not panel._confirm_box.visible and panel.visible and closed.count == 0, "Atrás con la confirmación abierta cierra solo la confirmación")
	check(epic in im.get_crafted_items() and im.get_quantity(&"gold") == gold, "y su acción no se ejecuta")
	check(not panel._confirm_action.is_valid(), "la confirmación se olvida de ella")
	panel._on_confirm_yes()
	check(epic in im.get_crafted_items() and im.get_quantity(&"gold") == gold, "un Sí que llegue después no vende lo que se canceló")
	# Con las dos a la vez (la confirmación va encima), Escape las cierra una a una y, a la tercera, el panel
	panel._open_card(plain)
	panel._on_sell_all()
	check(panel._card.visible and panel._confirm_box.visible, "la ficha y la confirmación, abiertas a la vez")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	panel._input(esc)
	check(not panel._confirm_box.visible and panel._card.visible and panel.visible, "Escape cierra primero la confirmación")
	panel._input(esc)
	check(not panel._card.visible and panel.visible and closed.count == 0, "después, la ficha")
	panel._input(esc)
	check(not panel.visible and closed.count == 1, "y por último el panel")
	await get_tree().process_frame  # Atrás se devuelve en diferido
	panel.queue_free()
	await _restore_inventory(saved)


## close() y open() dejan cerradas la ficha y la confirmación y olvidan la acción pendiente: al abrir el panel otra vez
## no sale la ficha ni la pregunta de la vez anterior.
func test_close_and_open_leave_both_overlays_closed() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var epic := _piece(&"helmet_basic", 0.95)
	im.add_crafted_item(epic)
	var panel := _new_panel()
	var gold: int = im.get_quantity(&"gold")
	panel._open_card(epic)
	panel._sell(epic)  # la épica pide confirmación
	check(panel._card.visible and panel._confirm_box.visible, "la ficha y la confirmación, abiertas")
	panel.close()
	check(not panel._card.visible and not panel._confirm_box.visible, "close() las cierra")
	panel.open()
	check(not panel._card.visible and not panel._confirm_box.visible, "y al abrir otra vez no hay ni ficha ni confirmación")
	panel._on_confirm_yes()
	check(epic in im.get_crafted_items() and im.get_quantity(&"gold") == gold, "la acción pendiente se olvidó al cerrar: un Sí no vende nada")
	# Si algo oculta el panel sin pasar por close(), open() las deja cerradas igualmente
	panel._open_card(epic)
	panel._sell(epic)
	panel.visible = false
	panel.open()
	check(not panel._card.visible and not panel._confirm_box.visible and not panel._confirm_action.is_valid(), "open() las cierra aunque el panel se ocultara sin close()")
	panel.queue_free()
	await _restore_inventory(saved)
