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
	check(im.move_item(small, &"hero", Vector2i(3, 3), 0), "el casco en la esquina de la rejilla de Tico")
	check(im.move_item(tower, &"hero", Vector2i(0, 0), 0), "el escudo torre en Tico")
	check(im.move_item(small, &"hero", Vector2i(0, 0), 0), "el casco encima del escudo: intercambio")
	check(small.place == &"hero" and tower.place == &"loot", "el escudo no cabe en la esquina de la rejilla de Tico: va al botín y no se pierde")
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
	check(im.move_item(helmet, &"hero", Vector2i(2, 2), 0), "el casco en la rejilla de Tico")
	var order: Array = im.get_loot().duplicate()
	check(order == [loot_c, loot_b, loot_a], "el botín, lo más nuevo delante (%s)" % [order])
	_listen_to_inventory()
	check(im.move_item(sword, &"hero", Vector2i(1, 1), 1), "soltar la espada en su casilla y con su giro vale")
	check(im.move_item(sword, &"hero", Vector2i(1, 1), 5) and im.move_item(sword, &"hero", Vector2i(1, 1), -3), "con más vueltas, el mismo giro")
	check(im.move_item(helmet, &"hero", Vector2i(2, 2), 0), "lo mismo con el casco en la rejilla de Tico")
	check(im.move_item(loot_b, &"loot") and im.move_item(loot_c, &"loot") and im.move_item(loot_a, &"loot"), "y con las del botín, en el botín")
	var ev := _take_events()
	check(ev.equipment == 0 and ev.crafted == 0 and ev.loot == 0, "ningún aviso (%s)" % [ev])
	check(im.get_loot() == order, "el botín conserva su orden (%s)" % [im.get_loot()])
	check(sword.place == &"hero" and sword.cell == Vector2i(1, 1) and sword.rot == 1 and helmet.place == &"hero" and helmet.cell == Vector2i(2, 2), "y las piezas siguen donde estaban")
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
	check(not im.move_item(shield, &"bag"), "la mochila retirada no acepta piezas")
	check(_take_events().equipment == 0, "rechazar no cambia equipo")
	check(im.move_item(shield, &"hero", Vector2i(1, 1), 0) and sword.place == &"loot", "intercambiar desde el botín devuelve la espada al botín")
	check(_take_events().equipment == 1, "intercambiar avisa una vez")
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
	check(im.move_item(kept, &"hero", Vector2i(0, 0), 0), "una pieza en la equipo de Tico")
	var gold: int = im.sell_all_loot()
	check(gold == common.get_sell_price(), "Vender todo solo vende lo que no es Épico ni Legendario (%d)" % gold)
	check(im.get_loot().size() == 2 and epic in im.get_loot() and legend in im.get_loot(), "la épica y la legendaria siguen en el botín")
	check(kept.place == &"hero", "la equipo de Tico no se toca")
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
	im.move_item(helmet, &"loot")
	check(im.calculate_total_stats() == GearAuras.totals(im.hero_grid), "las estadísticas de Tico son las de su rejilla")
	var before: Dictionary = im.calculate_total_stats()
	var preview: Dictionary = im.preview_stats(helmet, &"hero", Vector2i(1, 1), 0)
	check(preview.hp > before.hp, "la vista previa suma el casco con su aura (%d → %d)" % [before.hp, preview.hp])
	check(im.calculate_total_stats() == before and helmet.place == &"loot", "la vista previa no mueve nada")
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
	check(int(data.version) == SaveManager.SAVE_VERSION and data.inventory.has("hero_grid") and not data.inventory.has("equipped_slots"), "guardado en la versión actual, sin huecos fijos")
	# El fichero de la versión actual también se carga: x, y y giro vuelven de JSON como decimales y las aristas como pares
	check(SaveManager.load_game(), "se carga el fichero de la versión actual")
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
	b.rot = 3
	var data: Dictionary = im.to_save_data()
	im.load_save_data(data, 1)
	var by_id := {}
	for it in im.get_crafted_items():
		by_id[it.item_resource.item_id] = it
	check(by_id[&"shield_master"].place == &"hero" and by_id[&"shield_master"].aristas == [Vector2i(2, 1)], "el escudo vuelve a Tico con su arista")
	check(by_id[&"boots_advanced"].place == &"loot" and by_id[&"boots_advanced"].rot == 3, "las botas vuelven al botín con su giro")
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
	im.move_item(b, &"hero", Vector2i(3, 3), 0)
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
	check(by_id[&"helmet_basic"].place == &"hero" and by_id[&"helmet_basic"].cell == Vector2i(3, 3), "el casco sigue en su sitio de la rejilla de Tico")
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


# ─── Tarea 8: vista de la rejilla ────────────────────────────────

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
	return view.global_position + Vector2(cell) * GearGridView.CELL - grab + (Vector2(0, GearGridView.CELL) if DisplayServer.is_touchscreen_available() else Vector2.ZERO)


## Deja una pieza del botín apoyada en el suelo de la caja, en la x dada (px de la caja) y con ese ángulo: con pose, la
## caja la pone ahí al abrir el panel, sin esperar a que caiga desde arriba.
func _in_box(item: CraftedItem, x: float, angle: float = 0.0) -> void:
	var fp := PieceShape.of_item(item, posmod(roundi(angle / (PI / 2.0)), 4))
	var com := PieceShape.mass_center(fp, LootBoxView.BOX_CELL)
	item.loot_pose = {"pos": Vector2(x, LootBoxView.SIZE.y - float(fp.size.y) * LootBoxView.BOX_CELL + com.y - 1.0), "ang": angle}


## Dónde pulsar una pieza de la caja: el centro de su primera casilla limpia.
func _box_point(panel: Control, item: CraftedItem) -> Vector2:
	return panel._loot_box.piece_global_point(item)


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
	check(sword.rot == 0, "principal selecciona sin girar")
	panel._secondary_at(p)
	check(sword.rot == 1, "secundario gira la pieza")
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
	_in_box(new_sword, 300.0, PI / 2.0)  # tumbada en el suelo de la caja
	var panel := _new_panel()
	var start := _box_point(panel, new_sword)
	_mouse(panel, start, true)
	check(panel._press.get("item") == new_sword and panel._press.get("rot") == 1, "se coge la espada nueva, tumbada como está en la caja")
	_move(panel, start + Vector2(0, -30))
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
	im.move_item(sword, &"hero", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var start := _cell_center(panel._hero_view, Vector2i(0, 1))
	_mouse(panel, start, true)
	_move(panel, start + Vector2(40, 40))
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(900, 1500)
	panel._input(touch)
	check(panel._drag_rot == 1, "un segundo dedo gira la pieza que se arrastra (%d)" % panel._drag_rot)
	panel._secondary_at(start)
	check(panel._drag_rot == 2, "secundario gira durante el arrastre (%d)" % panel._drag_rot)
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	panel._input(key)
	check(panel._drag_rot == 3, "en el ordenador, la tecla R también (%d)" % panel._drag_rot)
	_move(panel, Vector2(540, 60))  # arriba del todo, fuera de las rejillas y del botín
	_mouse(panel, Vector2(540, 60), false)  # soltada ahí vuelve a su sitio
	check(sword.place == &"hero" and sword.cell == Vector2i(0, 0) and sword.rot == 0, "soltada fuera, vuelve a su sitio sin girar")
	panel.queue_free()
	await _restore_inventory(saved)


func test_new_loot_while_dragging_is_not_lost() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var dragged := _piece(&"helmet_basic")
	im.add_crafted_item(dragged)
	_in_box(dragged, 300.0)
	var panel := _new_panel()
	var start := _box_point(panel, dragged)
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


## En la caja no hay desplazamiento: arrastrar de lado también coge la pieza (spec del botín con física, apartado 6).
func test_dragging_sideways_in_the_box_takes_the_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var shield := _piece(&"shield_master")
	im.add_crafted_item(shield)
	_in_box(shield, 600.0)
	var panel := _new_panel()
	var start := _box_point(panel, shield)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(-300, 5))
	check(panel._dragging and panel._press.get("item") == shield, "de lado se coge la pieza")
	_mouse(panel, start + Vector2(-300, 5), false)
	check(shield.place == &"loot" and panel._loot_box.body_of(shield) != null, "soltada en la caja, sigue en el botín con su cuerpo")
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
	_in_box(helmet, 300.0)
	var panel := _new_panel()
	var puppet: Node = panel._puppet
	puppet.set("_materialize", 1.0)  # Tico ya está entero
	var tap := _box_point(panel, helmet)
	_mouse(panel, tap, true)
	_mouse(panel, tap, false)
	check(panel._selected == helmet and "Casco básico" in panel._ficha_label.text, "un toque en el casco de la caja lo enseña en la ficha")
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
	tap = _box_point(panel, helmet)
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
## caja del botín, cae en la rejilla.
func test_dropping_on_the_last_row_of_a_full_grid_places_the_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var data: Dictionary = im.to_save_data()
	data["expansions"] = GridExpansions.ids().map(func(id): return String(id))
	im.load_save_data(data, 1)  # las cuatro ampliaciones forjadas: 6×6
	check(im.hero_grid_size() == Vector2i(6, 6), "Tico tiene la rejilla de 6×6 (%s)" % im.hero_grid_size())
	var helmet := _piece(&"helmet_basic")  # 1×1
	im.add_crafted_item(helmet)
	_in_box(helmet, 300.0)
	var panel := _new_panel()
	var start := _box_point(panel, helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(2, 5))
	check(Rect2(panel._hero_view.global_position, panel._hero_view.size).has_point(finger), "en ordenador el cursor coincide con la casilla")
	_move(panel, finger)
	check(panel._target.get("place") == &"hero" and panel._target.get("cell") == Vector2i(2, 5) and panel._target.get("ok", false), "el destino es la casilla de Tico bajo la pieza (%s)" % [panel._target])
	_mouse(panel, finger, false)
	check(helmet.place == &"hero" and helmet.cell == Vector2i(2, 5), "y al soltar la pieza queda ahí")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## En una rejilla pequeña, las filas punteadas (aún sin abrir) no se llevan lo que se suelta sobre la caja del botín.
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
	check(not panel._loot_box.rect_global().has_point(finger), "las filas bloqueadas no se confunden con el botín")
	_move(panel, finger)
	check(not panel._target.get("ok", true) and panel._target.get("reason") == "outside", "la fila bloqueada explica el rechazo")
	_mouse(panel, finger, false)
	check(helmet.place == &"hero" and helmet.cell == Vector2i.ZERO, "un rechazo conserva la pieza en su lugar")
	panel.queue_free()
	await _restore_inventory(saved)


## Mantener R pulsada repite la tecla (echo): la pieza gira una sola vez.
func test_holding_r_rotates_only_once() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")
	im.add_crafted_item(sword)
	im.move_item(sword, &"hero", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var start := _cell_center(panel._hero_view, Vector2i(0, 1))
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
	_in_box(sword, 300.0)
	var panel := _new_panel()
	var start := _box_point(panel, sword)
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
	_in_box(shield, 300.0)
	var panel := _new_panel()
	var start := _box_point(panel, shield)
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
	_in_box(helmet, 300.0)
	var panel := _new_panel()
	var start := _box_point(panel, helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	check(panel._dragging and panel._loot_box.is_held(helmet) and panel._loot_box.body_of(helmet) == null, "se arrastra el casco y sale de la física de la caja")
	panel.visible = false  # algo lo oculta sin pasar por close()
	panel.open()
	check(not panel._dragging and panel._press.is_empty() and not panel._loot_box.is_held(helmet) and panel._loot_box.body_of(helmet) != null, "al abrirlo otra vez el arrastre queda cancelado y el casco vuelve a la caja")
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
	panel._card_to_loot()
	check(helmet.place == &"loot" and not panel._card.visible, "Al botín conserva la pieza y cierra")
	panel.queue_free()
	await _restore_inventory(saved)


func test_sell_zone_sells_and_asks_for_the_best() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var plain := _piece(&"boots_basic", 0.3)
	var epic := _piece(&"boots_basic", 0.95)
	for p in [plain, epic]:
		im.add_crafted_item(p)
	im.move_item(plain, &"hero", Vector2i(0, 0), 0)
	im.move_item(epic, &"hero", Vector2i(2, 0), 0)
	var panel := _new_panel()
	var sell_point: Vector2 = panel.sell_zone.get_global_rect().get_center()
	for item in [plain, epic]:
		var start := _cell_center(panel._hero_view, item.cell)
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
func test_sell_zone_lights_up_only_while_the_piece_is_over_it() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var epic := _piece(&"helmet_basic", 0.95)  # épica: soltarla en la zona pregunta antes de vender
	im.add_crafted_item(epic)
	im.move_item(epic, &"hero", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var idle: String = panel.sell_label.text
	var inside: Vector2 = panel.sell_zone.get_global_rect().get_center()
	var start := _cell_center(panel._hero_view, Vector2i(0, 0))
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


## Los botones de la ficha completa: Al botín, A la rejilla de Tico (con y sin sitio) y Vender (con y sin confirmación).
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
			im.move_item(filler, &"loot", Vector2i(x, y), 0)
	panel._open_card(epic)
	panel._card_to_loot()
	check(epic.place == &"loot" and not panel._card.visible, "con la mochila llena, Al botín no mueve la pieza")
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
	check(sword.rot == 0 and panel._selected == sword, "principal vuelve a seleccionar")
	panel._secondary_at(p)
	check(sword.rot == 1, "secundario vuelve a girar tras cerrar las capas")
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


# ─── Tarea 11: habilidades legendarias en combate ──────────────────────

## Pasillo de prueba con un enemigo de la sala 5 y Tico con las habilidades dadas, sin críticos y con toda
## tirada de habilidad a favor. Guarda el estado de GameManager para restaurarlo. Sin muro ni candado, sea cual
## sea la partida: al vencer, el pasillo pone el enemigo de la sala 6 (las pruebas del farmeo ponen el candado).
func _arena(powers: Array) -> Dictionary:
	var gm := get_node("/root/GameManager")
	var state := {"level": gm.current_enemy_level, "best": gm.best_enemy_level, "deaths": gm.death_count, "dungeon": gm.dungeon_state, "wall": gm.wall_room, "locked": gm.room_locked}
	gm.current_enemy_level = 5
	gm.wall_room = 0
	gm.room_locked = false
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	await get_tree().process_frame
	var hero: Node2D = corridor.get_node("Hero")
	hero.power = LegendaryPowers.effects(powers)
	hero._second_chance_ready = float(hero.power.second_chance) > 0.0  # cuentan las habilidades dadas, no la rejilla de la partida
	hero.crit_p = 0.0
	hero.power_roll = func() -> float: return 0.0
	return {"corridor": corridor, "hero": hero, "enemy": corridor.get_node("Enemy"), "cc": corridor.get_node("CombatController"), "state": state}


func _close_arena(a: Dictionary) -> void:
	a.corridor.queue_free()
	var gm := get_node("/root/GameManager")
	gm.current_enemy_level = a.state.level
	gm.best_enemy_level = a.state.best
	gm.death_count = a.state.deaths
	gm.dungeon_state = a.state.dungeon  # una caída de Tico en la prueba lo cambia
	gm.wall_room = a.state.wall  # y también deja un muro
	gm.room_locked = a.state.locked
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout  # deja que empiecen a sonar los golpes y el botín
	await _silence_sounds()


## Textos (números de daño incluidos) que hay ahora en la capa de efectos de la arena.
func _fx_parts(a: Dictionary) -> Array:
	var fx: Node2D = a.corridor.get_node("CombatFX")
	return fx._parts.filter(func(p): return p.kind == fx.Kind.TEXT)


func _fx_texts(a: Dictionary) -> Array:
	return _fx_parts(a).map(func(p): return p.text)


func test_double_hit_strikes_twice() -> void:
	var a := await _arena([&"sword_advanced"])
	var enemy: Node2D = a.enemy
	enemy.max_hp = 100000
	enemy.hp = 100000
	a.cc._execute_hero_attack()
	check(100000 - enemy.hp == int(a.hero.dmg) * 2, "con la tirada a favor golpea dos veces (%d de daño, golpe de %d)" % [100000 - enemy.hp, int(a.hero.dmg)])
	await _close_arena(a)


func test_double_hit_never_reaches_the_next_enemy() -> void:
	var a := await _arena([&"sword_advanced"])
	var enemy: Node2D = a.enemy
	var deaths := [0]
	enemy.died.connect(func(_drops): deaths[0] += 1)
	enemy.hp = 1
	var level_before: int = enemy.level
	a.cc._execute_hero_attack()
	check(deaths[0] == 1, "el primer golpe mata, una vez (%d)" % deaths[0])
	check(enemy.level == level_before or enemy.hp == enemy.max_hp, "si el nodo ya es el enemigo de la sala siguiente, está intacto (%d/%d)" % [enemy.hp, enemy.max_hp])
	await _close_arena(a)


func test_burn_deals_its_share_over_three_seconds() -> void:
	var a := await _arena([&"sword_masterwork"])
	var enemy: Node2D = a.enemy
	enemy.max_hp = 100000
	enemy.hp = 100000
	a.cc._execute_hero_attack()
	var hit := int(a.hero.dmg)
	var after_hit: int = enemy.hp
	check(enemy.is_burning(), "el golpe deja una quemadura")
	for i in 8:
		enemy._tick_burn(0.5)
	var burned: int = after_hit - enemy.hp
	check(absi(burned - roundi(hit * 0.4)) <= 1, "la quemadura hace el 40 %% del golpe en 3 s (%d de %d)" % [burned, hit])
	check(not enemy.is_burning(), "y se apaga")
	await _close_arena(a)


func test_burn_does_not_carry_over_to_the_next_enemy() -> void:
	var a := await _arena([])
	var enemy: Node2D = a.enemy
	enemy.apply_burn(50.0, 3.0)
	check(enemy.is_burning(), "quemándose")
	enemy.configure_for_level(6, false)  # el nodo pasa a la sala siguiente, como al morir
	check(not enemy.is_burning(), "el enemigo siguiente no empieza quemado")
	await _close_arena(a)


func test_thorns_kill_counts_once() -> void:
	var a := await _arena([&"shield_master"])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	hero.max_hp = 100000
	hero.hp = 100000
	enemy.dmg = 200.0
	enemy.crit_p = 0.0
	enemy.hp = 1
	var deaths := [0]
	enemy.died.connect(func(_drops): deaths[0] += 1)
	a.cc._execute_enemy_attack()
	check(deaths[0] == 1, "las Espinas matan al enemigo durante su propio ataque, una sola vez (%d)" % deaths[0])
	await _close_arena(a)


func test_dodge_and_block_avoid_whole_hits_but_not_pulses() -> void:
	var a := await _arena([&"boots_advanced"])
	var hero: Node2D = a.hero
	var hp: int = hero.hp
	check(hero.take_damage(50) == 0 and hero.last_avoid == &"dodge" and hero.hp == hp, "Esquiva: el golpe no hace nada")
	check(hero.take_damage(5, true) > 0 and hero.last_avoid == &"", "el pulso mágico no se esquiva")
	hero.power = LegendaryPowers.effects([&"shield_advanced"])
	hp = hero.hp
	check(hero.take_damage(50) == 0 and hero.last_avoid == &"block" and hero.hp == hp, "Parada: tampoco")
	hero.power_roll = func() -> float: return 0.99
	check(hero.take_damage(10) > 0, "con la tirada en contra, el golpe entra")
	await _close_arena(a)


func test_second_chance_once_per_duel() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_master", 1.0)
	im.add_crafted_item(helmet)
	im.move_item(helmet, &"hero", Vector2i(0, 0), 0)
	var a := await _arena([])
	var hero: Node2D = a.hero
	hero.respawn()  # vuelve a leer la rejilla (la arena le quitó las habilidades)
	hero.prepare_for_combat()  # empieza un duelo: Segunda oportunidad lista
	check(float(hero.power.second_chance) > 0.0, "el casco maestro legendario da Segunda oportunidad")
	hero.take_damage(hero.max_hp * 5, true)
	check(hero.alive and hero.hp == roundi(hero.max_hp * 0.4), "la primera caída del duelo se queda con el 40 %% (%d/%d)" % [hero.hp, hero.max_hp])
	hero.take_damage(hero.max_hp * 5, true)
	check(not hero.alive, "la segunda vez en el mismo duelo cae")
	hero.respawn()
	hero.prepare_for_combat()
	hero.take_damage(hero.max_hp * 5, true)
	check(hero.alive, "en el duelo siguiente vuelve a tenerla")
	await _close_arena(a)
	await _restore_inventory(saved)


func test_regeneration_heals_while_alive() -> void:
	var a := await _arena([&"helmet_advanced"])
	var hero: Node2D = a.hero
	hero.hp = roundi(hero.max_hp * 0.5)
	var before: int = hero.hp
	hero._process(1.0)
	check(hero.hp - before == int(hero.max_hp * 0.015), "recupera el 1,5 %% de la vida máxima en un segundo (%d)" % (hero.hp - before))
	await _close_arena(a)


func test_first_strike_triples_the_first_hit_on_each_enemy() -> void:
	var a := await _arena([&"boots_master"])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	enemy.max_hp = 100000
	enemy.hp = 100000
	hero.prepare_for_combat()
	var hit := int(hero.dmg)
	a.cc._execute_hero_attack()
	check(100000 - enemy.hp == int(hero.dmg * 3.0), "primer golpe ×3 (%d)" % (100000 - enemy.hp))
	var mid: int = enemy.hp
	a.cc._execute_hero_attack()
	check(mid - enemy.hp == hit, "el segundo, normal (%d)" % (mid - enemy.hp))
	await _close_arena(a)


# ─── Tarea 11: las habilidades en el pasillo (muro, Tico caído y franja) ───────

## Al farmear (con el candado puesto) el enemigo siguiente es de la misma sala: su nivel no lo distingue del que
## acaba de morir. Ni el segundo golpe ni la quemadura del golpe que mató al anterior pueden llegarle.
func test_a_kill_never_reaches_the_next_enemy_of_the_same_room() -> void:
	var a := await _arena([&"sword_advanced", &"sword_masterwork"])
	get_node("/root/GameManager").room_locked = true  # Tico repite la sala: el pasillo pone otro enemigo del mismo nivel
	var enemy: Node2D = a.enemy
	var deaths := [0]
	enemy.died.connect(func(_drops): deaths[0] += 1)
	enemy.hp = 1
	a.cc._execute_hero_attack()
	check(deaths[0] == 1, "el primer golpe mata, una vez (%d)" % deaths[0])
	check(enemy.alive and enemy.level == 5, "el pasillo ha puesto otro enemigo de la misma sala (nivel %d)" % enemy.level)
	check(enemy.hp == enemy.max_hp, "el segundo golpe no le llega (%d/%d)" % [enemy.hp, enemy.max_hp])
	check(not enemy.is_burning(), "y la quemadura del golpe que mató al anterior tampoco")
	await _close_arena(a)


## Si las Espinas matan al atacante en su propio ataque, lo que queda del fotograma no toca al enemigo de la sala
## siguiente: su pulso mágico conserva el cronómetro entero.
func test_thorns_kill_leaves_the_rest_of_the_frame_off_the_next_enemy() -> void:
	var a := await _arena([&"shield_master"])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	hero.max_hp = 100000
	hero.hp = 100000
	a.cc.start_combat()
	hero.atk_timer = 1000.0  # Tico ni golpea ni lanza su pulso en este fotograma
	hero.pulse_timer = 1000.0
	enemy.dmg = 200.0
	enemy.crit_p = 0.0
	enemy.hp = 1
	enemy.atk_timer = 0.0  # el atacante golpea ahora
	var deaths := [0]
	enemy.died.connect(func(_drops): deaths[0] += 1)
	a.cc._process(0.016)
	check(deaths[0] == 1, "las Espinas matan al atacante, una vez (%d)" % deaths[0])
	check(enemy.alive and enemy.level == 6 and enemy.hp == enemy.max_hp, "el nodo es ya el enemigo de la sala 6, entero (nivel %d, %d/%d)" % [enemy.level, enemy.hp, enemy.max_hp])
	check(enemy.pulse_timer == enemy.PULSE_INTERVAL, "y el resto del fotograma no toca su pulso mágico (%.4f)" % enemy.pulse_timer)
	await _close_arena(a)


## Un Tico que cae con el golpe no devuelve Espinas: el enemigo no muere con él (sería una victoria con Tico ya caído).
func test_thorns_need_tico_standing() -> void:
	var a := await _arena([&"shield_master"])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	hero.hp = 1
	enemy.dmg = 200.0
	enemy.crit_p = 0.0
	enemy.hp = 1
	var deaths := [0]
	enemy.died.connect(func(_drops): deaths[0] += 1)
	a.cc._execute_enemy_attack()
	check(not hero.alive, "el golpe tumba a Tico")
	check(deaths[0] == 0 and enemy.alive and enemy.hp == 1, "sin Tico en pie no hay Espinas (%d muertes, %d de vida)" % [deaths[0], enemy.hp])
	await _close_arena(a)


## Con Tico caído el duelo está perdido: la quemadura se apaga y no puede rematar al enemigo (sería una victoria
## que cuenta para el muro con Tico ya caído).
func test_burn_goes_out_when_tico_falls() -> void:
	var a := await _arena([&"sword_masterwork"])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	enemy.max_hp = 100000
	enemy.hp = 100000
	a.cc._execute_hero_attack()
	check(enemy.is_burning(), "el golpe deja una quemadura")
	hero.take_damage(hero.max_hp * 5, true)
	check(not hero.alive and not enemy.is_burning(), "al caer Tico, la quemadura se apaga")
	await _close_arena(a)


## Las quemaduras no se acumulan: se queda la que hace más daño por segundo y el tiempo vuelve a empezar (spec, apartado 5).
func test_burns_do_not_stack() -> void:
	var a := await _arena([])
	var enemy: Node2D = a.enemy
	enemy.max_hp = 100000
	enemy.hp = 100000
	enemy.apply_burn(10.0, 3.0)
	enemy._tick_burn(2.0)  # 20 de daño y queda 1 s
	enemy.apply_burn(4.0, 3.0)  # más floja: sigue la de 10 por segundo y el tiempo vuelve a 3 s
	for i in 6:
		enemy._tick_burn(0.5)
	check(100000 - enemy.hp == 20 + 30 and not enemy.is_burning(), "la floja no se suma: 20 + 3 s a 10 por segundo (%d)" % (100000 - enemy.hp))
	enemy.hp = 100000
	enemy.apply_burn(10.0, 3.0)
	enemy.apply_burn(20.0, 1.0)  # más fuerte: pasa a 20 por segundo
	for i in 2:
		enemy._tick_burn(0.5)
	check(100000 - enemy.hp == 20 and not enemy.is_burning(), "la fuerte manda: 1 s a 20 por segundo (%d)" % (100000 - enemy.hp))
	await _close_arena(a)


## Ímpetu vale solo para el primero de los dos golpes del golpe doble (spec, apartado 5), y el segundo se anuncia.
func test_first_strike_only_counts_for_the_first_of_a_double_hit() -> void:
	var a := await _arena([&"boots_master", &"sword_advanced"])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	enemy.max_hp = 100000
	enemy.hp = 100000
	hero.prepare_for_combat()
	var expected := int(hero.dmg * 3.0) + int(hero.dmg)
	a.corridor.get_node("CombatFX").clear()
	a.cc._execute_hero_attack()
	check(100000 - enemy.hp == expected, "el primero ×3 y el segundo normal (%d de %d)" % [100000 - enemy.hp, expected])
	check(not hero.first_strike_ready, "y el Ímpetu queda gastado")
	check("¡Doble!" in _fx_texts(a), "el segundo golpe sale con su «¡Doble!» (%s)" % [_fx_texts(a)])
	await _close_arena(a)


## `hurt` avisa tras cada golpe o pulso recibido, también si se esquiva (lo usarán las pociones automáticas), y sin
## tirada forzada las habilidades usan el azar de siempre.
func test_hurt_is_emitted_after_every_hit_even_an_avoided_one() -> void:
	var a := await _arena([&"boots_advanced"])
	var hero: Node2D = a.hero
	var seen := []
	hero.hurt.connect(func(amount: int): seen.append(amount))
	var dodged: int = hero.take_damage(50)
	var pulse: int = hero.take_damage(5, true)
	hero.power = LegendaryPowers.effects([])
	var hit: int = hero.take_damage(50)
	check(dodged == 0 and pulse > 0 and hit > 0 and seen == [dodged, pulse, hit], "un aviso por golpe o pulso, con el daño real (%s)" % [seen])
	hero.power_roll = Callable()
	var roll: float = hero.roll_power()
	check(roll >= 0.0 and roll < 1.0, "sin tirada forzada sale un azar de 0 a 1 (%.2f)" % roll)
	await _close_arena(a)


## La franja nombra lo que no hace daño: «¡Esquiva!» y «¡Parada!» en lugar del número, y «¡Otra vez!» al volver con
## Segunda oportunidad.
func test_the_strip_names_avoided_hits_and_the_second_chance() -> void:
	var a := await _arena([&"boots_advanced"])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	var fx: Node2D = a.corridor.get_node("CombatFX")
	enemy.crit_p = 0.0
	fx.clear()
	a.cc._execute_enemy_attack()
	var texts := _fx_texts(a)
	check("¡Esquiva!" in texts and not texts.any(func(t): return String(t).is_valid_int()), "esquivado: «¡Esquiva!» y ningún número de daño (%s)" % [texts])
	hero.power = LegendaryPowers.effects([&"shield_advanced"])
	fx.clear()
	a.cc._execute_enemy_attack()
	texts = _fx_texts(a)
	check("¡Parada!" in texts and not texts.any(func(t): return String(t).is_valid_int()), "parado: «¡Parada!» y ningún número de daño (%s)" % [texts])
	hero.power = LegendaryPowers.effects([&"helmet_master"])
	hero._second_chance_ready = true
	fx.clear()
	hero.take_damage(hero.max_hp * 5, true)
	check(hero.alive and "¡Otra vez!" in _fx_texts(a), "Segunda oportunidad: «¡Otra vez!» (%s)" % [_fx_texts(a)])
	await _close_arena(a)


## Los números de la quemadura y de las Espinas tienen su propio color.
func test_burn_and_thorns_numbers_have_their_own_colors() -> void:
	var a := await _arena([&"shield_master"])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	var fx: Node2D = a.corridor.get_node("CombatFX")
	hero.max_hp = 100000
	hero.hp = 100000
	enemy.max_hp = 100000
	enemy.hp = 100000
	enemy.crit_p = 0.0
	fx.clear()
	enemy.apply_burn(10.0, 1.0)
	enemy._tick_burn(0.5)
	var burn := _fx_parts(a)
	check(burn.size() == 1 and burn[0].text == "5" and burn[0].color == Color("ff8a3d"), "quemadura: el 5 de medio segundo, naranja (%s)" % [burn.map(func(p): return [p.text, p.color])])
	fx.clear()
	a.cc._execute_enemy_attack()
	var colors := _fx_parts(a).map(func(p): return p.color)
	check(Color("c9b37a") in colors, "Espinas: su número, del color de las Espinas")
	await _close_arena(a)


## La regeneración enseña un «+N» verde cada 2 s como mucho, con lo curado en medio, y se para con Tico caído.
func test_regeneration_shows_its_number_sparingly_and_stops_when_fallen() -> void:
	var a := await _arena([&"helmet_advanced"])
	var hero: Node2D = a.hero
	hero.max_hp = 1000
	hero.hp = 100
	a.corridor.get_node("CombatFX").clear()
	hero._process(1.0)
	check(_fx_texts(a).size() == 1, "el primer segundo ya enseña su número (%s)" % [_fx_texts(a)])
	hero._process(1.0)
	check(_fx_texts(a).size() == 1, "el siguiente espera: solo uno cada 2 s (%s)" % [_fx_texts(a)])
	hero._process(1.0)
	var texts := _fx_texts(a)
	var shown := 0
	for t in texts:
		shown += int(String(t).trim_prefix("+"))
	check(texts.size() == 2 and shown == hero.hp - 100, "y el segundo suma lo curado entre medias (%s, curado %d)" % [texts, hero.hp - 100])
	hero.take_damage(hero.max_hp * 5, true)
	hero._process(5.0)
	check(not hero.alive and hero.hp == 0, "con Tico caído no regenera ni resucita (%d)" % hero.hp)
	await _close_arena(a)


# ─── Tarea 11, revisión: Ímpetu tras un cambio de equipo y número de regeneración pendiente ───

## Si el equipo cambia entre que Tico engancha al enemigo y su primer golpe, el Ímpetu se va con las botas: el golpe
## pendiente hace su daño de siempre, no el de multiplicarlo por 0 (ni 0 de daño ni quemadura).
func test_first_strike_goes_with_the_boots_if_they_come_off_before_the_hit() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var boots := _piece(&"boots_master", 1.0)
	im.add_crafted_item(boots)
	im.move_item(boots, &"hero", Vector2i(0, 0), 0)
	var a := await _arena([])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	enemy.max_hp = 100000
	enemy.hp = 100000
	hero.respawn()  # vuelve a leer la rejilla (la arena le quitó las habilidades)
	hero.prepare_for_combat()  # el duelo empieza con el primer golpe por dar
	check(hero.first_strike_ready and float(hero.power.first_strike) > 0.0, "con las botas maestras legendarias, el Ímpetu está listo")
	hero.reset_stats()  # otro cambio de equipo que no toca las botas
	check(hero.first_strike_ready, "si las botas siguen puestas, sigue listo")
	im.move_item(boots, &"loot")  # el jugador se las quita antes del primer golpe
	hero.reset_stats()  # GameManager lo hace en cada cambio de equipo
	check(not hero.first_strike_ready, "sin las botas, ya no está listo")
	hero.crit_p = 0.0  # reset_stats recalcula el crítico
	a.cc._execute_hero_attack()
	check(100000 - enemy.hp == int(hero.dmg), "y el primer golpe hace su daño de siempre, no 0 (%d de %d)" % [100000 - enemy.hp, int(hero.dmg)])
	await _close_arena(a)
	await _restore_inventory(saved)


## Un "+N" de la regeneración que esperaba su turno se descarta cuando Tico cae y cuando reaparece (reaparecer es
## también viajar de sala): no sale flotando sobre un Tico caído ni sobre uno recién reaparecido.
func test_a_pending_regeneration_number_goes_with_the_fall_and_with_the_respawn() -> void:
	var a := await _arena([&"helmet_advanced"])
	var hero: Node2D = a.hero
	var fx: Node2D = a.corridor.get_node("CombatFX")
	hero.max_hp = 1000
	hero.hp = 100
	hero._process(1.0)  # cura y enseña su número: el siguiente tendrá que esperar 2 s
	hero._process(1.0)  # cura otra vez, y su número queda pendiente
	check(hero._regen_shown > 0, "queda un número pendiente (%d)" % hero._regen_shown)
	hero.take_damage(hero.max_hp * 5, true)
	check(not hero.alive and hero._regen_shown == 0, "al caer Tico, el número pendiente se descarta (%d)" % hero._regen_shown)
	fx.clear()
	hero._process(5.0)
	check(_fx_texts(a).is_empty(), "y no sale sobre Tico caído (%s)" % [_fx_texts(a)])
	hero.respawn()
	hero.power = LegendaryPowers.effects([&"helmet_advanced"])  # reaparecer vuelve a leer la rejilla
	hero.max_hp = 1000
	hero.hp = 100
	hero._regen_fx_cd = 0.0  # sin esperas de antes: este caso no depende del anterior
	hero._process(1.0)
	hero._process(1.0)
	check(hero._regen_shown > 0, "otra vez con un número pendiente (%d)" % hero._regen_shown)
	hero.respawn()
	check(hero._regen_shown == 0, "al reaparecer, el número pendiente se descarta (%d)" % hero._regen_shown)
	fx.clear()
	hero._process(3.0)
	check(_fx_texts(a).is_empty(), "y no sale sobre Tico recién reaparecido (%s)" % [_fx_texts(a)])
	await _close_arena(a)


# ─── Tarea 12: la rejilla crece al vencer a los jefes ──────────────────

func test_apply_grid_expansion_grows_once() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	check(im.apply_grid_expansion(&"grid_bone_straps") and im.hero_grid_size() == Vector2i(5, 4), "la primera ampliación lleva la rejilla a 5×4")
	check(not im.apply_grid_expansion(&"grid_bone_straps"), "la misma no amplía dos veces")
	check(im.apply_grid_expansion(&"grid_frost_harness") and im.hero_grid_size() == Vector2i(5, 5), "da igual cuál: la siguiente lleva a 5×5")
	check(not im.apply_grid_expansion(&"no_existe"), "algo que no es una ampliación no hace nada")
	await _restore_inventory(saved)


## Ampliar avisa de la rejilla nueva y del equipo de Tico, y lo hace con la rejilla ya crecida: las zonas de
## borde se mueven con ella (la espada de la columna derecha de 4×4 deja de estar en su zona al pasar a 5×4).
func test_the_expansion_announces_itself_and_moves_the_edge_zones() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_basic", 0.5)
	im.add_crafted_item(sword)
	check(im.move_item(sword, &"hero", Vector2i(3, 0), 0), "la espada, en la columna derecha de la rejilla de 4×4")
	check(not im.hero_bonuses()[sword].is_empty(), "y en su zona: rinde más (%s)" % [im.hero_bonuses()[sword]])
	var before: Dictionary = im.calculate_total_stats()
	var sizes := []
	var notices := []
	var on_resized := func(s): sizes.append(s)
	var on_equipment := func(totals): notices.append(totals)
	im.grid_resized.connect(on_resized)
	im.equipment_changed.connect(on_equipment)
	check(im.apply_grid_expansion(&"grid_bone_straps"), "la ampliación vale")
	im.grid_resized.disconnect(on_resized)
	im.equipment_changed.disconnect(on_equipment)
	check(sizes == [Vector2i(5, 4)], "avisa de la rejilla nueva, una vez (%s)" % [sizes])
	check(notices.size() == 1 and notices[0] != before and notices[0] == im.calculate_total_stats(), "y del equipo de Tico, ya con las zonas nuevas (%d avisos)" % notices.size())
	check(im.hero_bonuses()[sword].is_empty(), "la columna derecha es ahora la quinta: la espada deja de estar en su zona (%s)" % [im.hero_bonuses()[sword]])
	await _restore_inventory(saved)


func test_first_boss_kill_grows_the_grid() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var state := {"dungeon": gm.dungeon_state, "best": gm.best_enemy_level, "defeated": gm.enemies_defeated.duplicate(),
		"wall": gm.wall_room, "locked": gm.room_locked, "level": gm.current_enemy_level}
	# Sin muro, sea cual sea la partida: esta prueba mira la rejilla; el muro tiene la suya
	# (test_the_expansion_never_sends_tico_to_the_wall)
	gm.wall_room = 0
	var seen := []
	var on_grow := func(id): seen.append(id)
	gm.grid_expanded.connect(on_grow)
	gm.best_enemy_level = 10  # el récord deja pasar la ampliación: solo la parada de la partida puede impedirla
	for stopped in [gm.DungeonState.HERO_DEAD, gm.DungeonState.IDLE]:
		gm.dungeon_state = stopped
		gm.register_enemy_defeat(10)
		check(seen.is_empty() and im.hero_grid_size() == Vector2i(4, 4), "con la partida parada (estado %d) no cuenta la victoria: no amplía (%s)" % [stopped, seen])
	gm.dungeon_state = gm.DungeonState.RUNNING
	gm.best_enemy_level = 11
	gm.register_enemy_defeat(10)
	check(seen.is_empty() and im.hero_grid_size() == Vector2i(4, 4), "con el récord ya más hondo que su sala, no es la primera victoria: no amplía (%s)" % [seen])
	gm.best_enemy_level = 10
	gm.register_enemy_defeat(10)
	check(seen == [&"grid_bone_straps"] and im.hero_grid_size() == Vector2i(5, 4), "el jefe de la sala 10 amplía la rejilla (%s)" % [seen])
	gm.best_enemy_level = 11
	gm.register_enemy_defeat(10)
	check(seen.size() == 1 and im.hero_grid_size() == Vector2i(5, 4), "volver a vencerlo no amplía otra vez")
	gm.best_enemy_level = 60
	gm.register_enemy_defeat(60)
	check(seen.size() == 1, "los jefes del ciclo II no amplían")
	gm.grid_expanded.disconnect(on_grow)
	gm.dungeon_state = state.dungeon
	gm.best_enemy_level = state.best
	gm.enemies_defeated = state.defeated
	gm.wall_room = state.wall
	gm.room_locked = state.locked
	gm.current_enemy_level = state.level
	await _restore_inventory(saved)


## Los cuatro jefes del ciclo I, cada uno a su paso: 5×4, 5×5, 6×5 y 6×6. El de la sala 50 no es uno de ellos.
func test_each_boss_of_the_first_cycle_grows_the_grid_one_step() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var dm := get_node("/root/DataManager")
	var ranks_before: Dictionary = dm.unlocked_ranks.duplicate()  # los jefes desbloquean rangos de verdad: se restauran al final
	var state := {"dungeon": gm.dungeon_state, "best": gm.best_enemy_level, "defeated": gm.enemies_defeated.duplicate(),
		"wall": gm.wall_room, "locked": gm.room_locked, "level": gm.current_enemy_level}
	gm.wall_room = 0  # sin muro: ver test_first_boss_kill_grows_the_grid
	gm.dungeon_state = gm.DungeonState.RUNNING
	for step in [[10, Vector2i(5, 4)], [20, Vector2i(5, 5)], [30, Vector2i(6, 5)], [40, Vector2i(6, 6)], [50, Vector2i(6, 6)]]:
		gm.best_enemy_level = step[0]
		gm.register_enemy_defeat(step[0])
		check(im.hero_grid_size() == step[1], "tras el jefe de la sala %d, la rejilla es de %s (%s)" % [step[0], step[1], im.hero_grid_size()])
	check(im.expansions.size() == 4, "cuatro ampliaciones y no más (%d)" % im.expansions.size())
	dm.unlocked_ranks = ranks_before
	gm.dungeon_state = state.dungeon
	gm.best_enemy_level = state.best
	gm.enemies_defeated = state.defeated
	gm.wall_room = state.wall
	gm.room_locked = state.locked
	gm.current_enemy_level = state.level
	await _restore_inventory(saved)


## Tico de pega: cuenta las veces que GameManager le manda recalcular sus estadísticas.
class StatsCounter extends Node:
	var resets := 0

	func reset_stats() -> void:
		resets += 1


## Ampliar la rejilla no es cambiar de equipo: con un muro más abajo del jefe y sin candado, el aviso de equipo
## mandaría a Tico al muro en mitad de la victoria (CombatController aún sigue con el jefe y room_cleared() leería
## la sala del muro). Tico sí se recalcula (las zonas de borde se mueven), y un cambio de equipo normal justo
## después sí vuelve a probar el muro: la parada no se queda puesta.
func test_the_expansion_never_sends_tico_to_the_wall() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var dm := get_node("/root/DataManager")
	var ranks_before: Dictionary = dm.unlocked_ranks.duplicate()  # el jefe de la 20 desbloquea rangos de verdad: se restauran al final
	var state := {"dungeon": gm.dungeon_state, "best": gm.best_enemy_level, "defeated": gm.enemies_defeated.duplicate(),
		"wall": gm.wall_room, "locked": gm.room_locked, "level": gm.current_enemy_level, "wins": gm._wins_since_retry,
		"hero": gm.get("_hero")}
	var tico := StatsCounter.new()
	gm.set("_hero", tico)
	gm.wall_room = 19  # el muro, más abajo que el jefe (Tico cayó en la 19 y saltó con el selector a la 20)
	gm.room_locked = false
	gm.current_enemy_level = 20
	gm.best_enemy_level = 20
	gm.dungeon_state = gm.DungeonState.RUNNING
	var travels := []
	var on_travel := func(room): travels.append(room)
	gm.room_travel.connect(on_travel)
	gm.register_enemy_defeat(20)
	check(im.hero_grid_size() == Vector2i(5, 4), "el jefe de la sala 20 amplía la rejilla (%s)" % [im.hero_grid_size()])
	check(gm.current_enemy_level == 20 and gm.wall_room == 19 and travels.is_empty(), "y Tico sigue en la 20, sin viaje, con el muro en la 19 (sala %d, muro %d, viajes %s)" % [gm.current_enemy_level, gm.wall_room, travels])
	check(tico.resets == 1, "pero sus estadísticas se recalculan (%d veces)" % tico.resets)
	var sword := _piece(&"sword_basic", 0.5)
	im.add_crafted_item(sword)
	im.move_item(sword, &"hero", Vector2i(0, 0), 0)  # un cambio de equipo de verdad
	check(travels == [19] and gm.current_enemy_level == 19, "un cambio de equipo normal justo después sí prueba el muro (viajes %s, sala %d)" % [travels, gm.current_enemy_level])
	gm.room_travel.disconnect(on_travel)
	dm.unlocked_ranks = ranks_before
	gm.dungeon_state = state.dungeon
	gm.best_enemy_level = state.best
	gm.enemies_defeated = state.defeated
	gm.wall_room = state.wall
	gm.room_locked = state.locked
	gm.current_enemy_level = state.level
	gm._wins_since_retry = state.wins
	gm.set("_hero", state.hero if is_instance_valid(state.hero) else null)
	tico.free()
	await _restore_inventory(saved)


## Lo mismo por el camino de verdad: el jefe de la sala 10 cae de un golpe en el pasillo, con un muro en la 9 y sin
## candado. La victoria sigue su curso: el jefe cuenta como derrotado, el récord sube, el muro cae al vencer una
## sala más honda y Tico pasa a la 11. (Si la ampliación lo mandara al muro, el pasillo recolocaría al mismo enemigo
## en la 9: no habría hito del jefe, ni récord, y room_cleared() leería la 9.)
func test_a_boss_kill_with_a_lower_wall_keeps_the_room_accounting() -> void:
	var saved := _fresh_inventory()
	var a := await _arena([])
	var gm := get_node("/root/GameManager")
	var extra := {"defeated": gm.enemies_defeated.duplicate(), "boss": gm.boss_defeated_flag}
	gm.boss_defeated_flag = false
	gm.wall_room = 9
	gm.current_enemy_level = 10
	gm.best_enemy_level = 10
	gm.dungeon_state = gm.DungeonState.RUNNING
	a.corridor.reset_combat(false)  # el pasillo pone al jefe de la sala 10, como al viajar
	var enemy: Node2D = a.enemy
	check(enemy.level == 10 and enemy.is_boss, "el pasillo tiene al jefe de la sala 10 (nivel %d)" % enemy.level)
	var travels := []
	var on_travel := func(room): travels.append(room)
	gm.room_travel.connect(on_travel)
	enemy.hp = 1
	a.cc._execute_hero_attack()
	gm.room_travel.disconnect(on_travel)
	check(travels.is_empty(), "la victoria no manda a Tico a ninguna sala (viajes %s)" % [travels])
	check(_im().hero_grid_size() == Vector2i(5, 4) and gm.boss_defeated_flag, "el jefe cuenta como derrotado y la rejilla crece (%s)" % [_im().hero_grid_size()])
	check(gm.current_enemy_level == 11 and gm.best_enemy_level == 11 and gm.wall_room == 0, "el récord sube, el muro cae y Tico pasa a la 11 (sala %d, récord %d, muro %d)" % [gm.current_enemy_level, gm.best_enemy_level, gm.wall_room])
	gm.enemies_defeated = extra.defeated
	gm.boss_defeated_flag = extra.boss
	await _close_arena(a)  # devuelve el resto de GameManager (sala, récord, muro, candado, muertes y estado)
	await _restore_inventory(saved)


## La franja avisa con un cartelito cuando la rejilla crece.
func test_the_strip_announces_the_grid_growing() -> void:
	var gm := get_node("/root/GameManager")
	var overlay: Control = load("res://scripts/ui/HeroViewOverlay.gd").new()
	add_child(overlay)
	var queued: int = overlay._toast_queue.size()
	gm.grid_expanded.emit(&"grid_bone_straps")
	check(overlay._toast_queue.size() == queued + 1 and overlay._toast_queue.back()[0] == tr("¡La rejilla crece!"), "sale «¡La rejilla crece!» (%s)" % [overlay._toast_queue])
	overlay.free()


func test_result_screen_shows_aristas_and_the_legendary_power() -> void:
	var screen := CraftResultScreen.new()  # sin escena: el script construye la interfaz en _ready
	add_child(screen)
	await get_tree().process_frame
	var rough: Array[Vector2i] = [Vector2i(1, 1)]
	screen._populate_stats({"crafted_item": _piece(&"sword_basic", 0.5, rough)})
	var texts: Array = screen._stats_container.get_children().filter(func(c): return c is Label).map(func(l): return l.text)
	check(texts.has(tr("Aristas: %d") % 1), "dice cuántas aristas trae (%s)" % [texts])
	check(not texts.any(func(s): return s.begins_with(tr("Filo perfecto"))), "y una pieza que no es legendaria no enseña habilidad")
	screen._populate_stats({"crafted_item": _piece(&"sword_basic", 1.0)})
	texts = screen._stats_container.get_children().filter(func(c): return c is Label and not c.is_queued_for_deletion()).map(func(l): return l.text)
	check(texts.has(tr("Sin aristas")), "la legendaria sale sin aristas")
	check(texts.any(func(s): return s.begins_with(tr("Filo perfecto"))), "y con su habilidad (%s)" % [texts])
	screen.queue_free()
	await get_tree().process_frame


## La pantalla de resultado vive en la ventana del minijuego (la mitad de la pantalla: 1080×960 de base) y su
## contenido ya llenaba esa ventana. Con las líneas de aristas y de habilidad, una espada o una legendaria no
## caben a tamaño normal: la pantalla se reduce entera, y el botón de continuar queda dentro de la ventana.
## Lo que ya cabía (un escudo épico) sigue a tamaño normal.
func test_the_result_screen_fits_its_window_with_the_new_lines() -> void:
	var window := SubViewport.new()
	window.size = Vector2i(1080, 960)
	add_child(window)
	var rough: Array[Vector2i] = [Vector2i(-1, 0)]
	var cases := [
		[_piece(&"sword_masterwork", 1.0), true, "espada maestra legendaria (la habilidad ocupa dos líneas)"],
		[_piece(&"sword_basic", 0.8, rough), true, "espada rara con una arista"],
		[_piece(&"shield_basic", 0.95), false, "escudo épico"],
	]
	for c in cases:
		var screen: Control = CraftResultScreen.new()
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		window.add_child(screen)
		screen.show_result({"crafted_item": c[0], "blueprint_id": "sword_basic", "quality": c[0].quality, "grade": "perfect", "forjamagia": 3, "forjamagia_bonus": 0.1})
		for i in 4:
			await get_tree().process_frame
		var before_button: float = screen._margin.scale.x
		screen._continue_container.visible = true  # la revelación enseña el botón al final
		for i in 3:
			await get_tree().process_frame
		var button: Control = screen._continue_container
		var bottom: float = (button.get_global_transform() * Vector2(0.0, button.size.y)).y
		var center: float = (button.get_global_transform() * Vector2(button.size.x * 0.5, 0.0)).x
		check(bottom <= 960.5, "%s: el botón de continuar acaba dentro de la ventana (%.0f de 960)" % [c[2], bottom])
		check(screen._margin.scale.x < 1.0 if c[1] else is_equal_approx(screen._margin.scale.x, 1.0), "%s: %s (escala %.3f)" % [c[2], "se reduce" if c[1] else "sigue a tamaño normal", screen._margin.scale.x])
		check(is_equal_approx(screen._margin.scale.x, before_button), "%s: nada se recoloca al aparecer el botón (%.3f antes, %.3f después)" % [c[2], before_button, screen._margin.scale.x])
		check(absf(center - 540.0) < 1.0, "%s: reducida, sigue centrada (el botón, en x = %.1f)" % [c[2], center])
		screen.queue_free()
		await get_tree().process_frame
	window.queue_free()
	await get_tree().process_frame


# ─── Tarea 13: consumibles ─────────────────────────────────────────────

func test_potion_slots_hold_two_kinds_up_to_five() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	for i in 5:
		check(im.add_potion(&"potion_speed"), "la Velocidad %d entra en su hueco" % (i + 1))
	check(not im.add_potion(&"potion_speed"), "la sexta no cabe (5 como máximo)")
	check(im.add_potion(&"potion_luck"), "la Suerte va al otro hueco")
	check(not im.add_potion(&"potion_heal"), "la Vida no tiene hueco: los dos están ocupados")
	check(im.take_potion(&"potion_luck") and im.potion_count(&"potion_luck") == 0, "al beberse la última, el hueco queda libre")
	check(im.add_potion(&"potion_heal"), "y ya entra la Vida")
	var gold: int = im.sell_potion_slot(0)  # im es un Node: el tipo no se puede deducir
	check(gold == roundi(5 * Potions.CATALOG[&"potion_speed"].price * 0.5) and im.potion_count(&"potion_speed") == 0, "vender un hueco da la mitad de lo que costó (%d)" % gold)
	var data: Dictionary = im.to_save_data()
	im.load_save_data(data, 1)
	check(im.potion_count(&"potion_heal") == 1, "los huecos se guardan")
	await _restore_inventory(saved)


func test_boss_drinks_speed_and_luck_once() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var wall: int = gm.wall_room
	gm.wall_room = 0  # sin muro (la partida del usuario puede tener uno)
	gm.clear_buffs()
	im.add_potion(&"potion_speed")
	im.add_potion(&"potion_speed")
	im.add_potion(&"potion_luck")
	gm.on_boss_appeared()
	check(gm.has_buff(&"speed") and gm.has_buff(&"luck"), "al aparecer un jefe se beben Velocidad y Suerte")
	check(im.potion_count(&"potion_speed") == 1 and im.potion_count(&"potion_luck") == 0, "una de cada")
	gm.on_boss_appeared()
	check(im.potion_count(&"potion_speed") == 1, "con el efecto activo no se bebe otra")
	gm.clear_buffs()
	gm.wall_room = wall
	await _restore_inventory(saved)


func test_boss_potions_wait_in_front_of_the_wall() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var state := {"level": gm.current_enemy_level, "wall": gm.wall_room, "locked": gm.room_locked, "dungeon": gm.dungeon_state, "wins": gm._wins_since_retry}
	gm.clear_buffs()
	im.add_potion(&"potion_speed")
	gm.wall_room = 11
	gm.room_locked = false
	gm.current_enemy_level = 10  # farmea el jefe de la sala 10, delante del muro
	gm.dungeon_state = gm.DungeonState.RUNNING  # con la partida parada retry_wall_now() no hace nada, haya candado o no
	gm.on_boss_appeared()
	check(im.potion_count(&"potion_speed") == 1 and gm.current_enemy_level == 10, "delante del muro no se bebe: el jefe no se queda a medias")
	gm.room_locked = true
	gm.on_boss_appeared()
	check(im.potion_count(&"potion_speed") == 0 and gm.current_enemy_level == 10, "con candado sí se bebe, y Tico sigue en su sala")
	# Control: sin candado, la misma poción bebida con la partida en marcha sí manda a Tico al muro. Es lo que hace que la
	# mitad de arriba pueda fallar: sin esto, un Tico que se queda quieto podría deberse a cualquier otra cosa
	gm.room_locked = false
	gm.clear_buffs()
	im.add_potion(&"potion_speed")
	gm.drink_potion(&"potion_speed")
	check(gm.current_enemy_level == 11, "(control) sin candado la misma poción manda a Tico al muro, la sala 11 (sala %d)" % gm.current_enemy_level)
	gm.clear_buffs()
	gm.dungeon_state = state.dungeon
	gm.current_enemy_level = state.level
	gm.wall_room = state.wall
	gm.room_locked = state.locked
	gm._wins_since_retry = state.wins
	await _restore_inventory(saved)


func test_heal_potion_drinks_itself_below_30_percent() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")
	add_child(hero)
	await get_tree().process_frame
	var prev_hero: Node = gm.get_hero()
	gm.register_hero(hero)
	im.add_potion(&"potion_heal")
	hero.take_damage(roundi(hero.max_hp * 0.5), true)
	check(im.potion_count(&"potion_heal") == 1, "al 50 %% no se bebe")
	hero.take_damage(roundi(hero.max_hp * 0.3), true)
	check(hero.hp == hero.max_hp and im.potion_count(&"potion_heal") == 0, "por debajo del 30 %% se bebe sola y cura al máximo (%d/%d)" % [hero.hp, hero.max_hp])
	im.add_potion(&"potion_heal")
	hero.take_damage(hero.max_hp * 10, true)
	check(not hero.alive and im.potion_count(&"potion_heal") == 1, "con Tico caído no se bebe")
	gm.register_hero(prev_hero)
	hero.queue_free()
	await _restore_inventory(saved)


## Lo guardado se revisa al cargar: una pila de más de 5 se queda en 5, lo que no es una poción no ocupa hueco, no se
## inventan huecos y una partida sin consumibles (o con basura en su lugar) carga con los dos libres.
func test_saved_potion_slots_are_checked_on_load() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var data: Dictionary = im.to_save_data()
	data["consumables"] = [{"id": "potion_speed", "count": 99}, {"id": "potion_gold", "count": 3}, {"id": "potion_luck", "count": 2}]
	var from_disk: Dictionary = JSON.parse_string(JSON.stringify(data))  # como llega del disco: los números son decimales
	im.load_save_data(from_disk, 1)
	check(im.potion_count(&"potion_speed") == Potions.MAX_STACK, "una pila de más de 5 se queda en 5 (%d)" % im.potion_count(&"potion_speed"))
	check(im.consumables.size() == Potions.SLOTS and int(im.consumables[1].count) == 0, "lo que no es una poción no ocupa hueco (%s)" % [im.consumables])
	check(im.potion_count(&"potion_luck") == 0, "y no se inventa un tercer hueco")
	data.erase("consumables")
	im.load_save_data(data, 1)
	check(im.consumables.all(func(s): return int(s.count) == 0), "una partida sin consumibles carga con los huecos libres")
	data["consumables"] = [5, null]
	im.load_save_data(data, 1)
	check(im.consumables.size() == Potions.SLOTS and im.consumables.all(func(s): return int(s.count) == 0), "y las entradas que no son huecos se ignoran")
	await _restore_inventory(saved)


## El límite es el 30 % de verdad: con la vida justo en el 30 % (o algo más) no se bebe; un punto por debajo, sí.
func test_the_heal_potion_threshold_is_exactly_30_percent() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")
	add_child(hero)
	await get_tree().process_frame
	var prev_hero: Node = gm.get_hero()
	gm.register_hero(hero)
	var line := ceili(hero.max_hp * 0.3)  # la menor vida que no bebe (el 30 % escrito aquí, no el de Potions)
	im.add_potion(&"potion_heal")
	hero.hp = line + 1
	hero.take_damage(1, true)  # el pulso no mira la armadura: deja la vida en `line`
	check(hero.hp == line and im.potion_count(&"potion_heal") == 1, "con %d de %d de vida no se bebe" % [hero.hp, hero.max_hp])
	hero.take_damage(1, true)
	check(hero.hp == hero.max_hp and im.potion_count(&"potion_heal") == 0, "un punto por debajo sí (%d/%d)" % [hero.hp, hero.max_hp])
	gm.register_hero(prev_hero)
	hero.queue_free()
	await _restore_inventory(saved)


## Todo cambio de los huecos avisa con los que quedan; vaciar el inventario los deja libres, y cargar una partida avisa.
func test_consumables_changed_announces_every_change() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var seen := []
	var on_changed := func(slots): seen.append(slots.map(func(s): return int(s.count)))
	im.consumables_changed.connect(on_changed)
	im.add_potion(&"potion_speed")
	im.add_potion(&"potion_luck")
	im.take_potion(&"potion_speed")
	im.sell_potion_slot(1)
	check(seen == [[1, 0], [1, 1], [0, 1], [0, 0]], "añadir, beber y vender avisan con los huecos que quedan (%s)" % [seen])
	im.add_potion(&"potion_heal")
	seen.clear()
	im.clear()
	check(im.potion_count(&"potion_heal") == 0 and seen.size() == 1, "vaciar el inventario libera los huecos y avisa una vez (%s)" % [seen])
	im.load_save_data(im.to_save_data(), 1)
	check(seen.size() == 2, "cargar una partida también avisa (%s)" % [seen])
	im.consumables_changed.disconnect(on_changed)
	await _restore_inventory(saved)


## Beber avisa con la poción bebida; sin ninguna en los huecos no se bebe ni se avisa.
func test_drinking_announces_the_potion() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var seen := []
	var on_drunk := func(id): seen.append(id)
	gm.potion_drunk.connect(on_drunk)
	gm.clear_buffs()
	check(not gm.drink_potion(&"potion_speed") and seen.is_empty() and not gm.has_buff(&"speed"), "sin ninguna en el hueco no se bebe ni se avisa")
	im.add_potion(&"potion_speed")
	check(gm.drink_potion(&"potion_speed") and seen == [&"potion_speed"], "al beberla avisa de cuál (%s)" % [seen])
	check(gm.has_buff(&"speed") and is_equal_approx(gm.buff_remaining(&"speed"), 30.0) and im.potion_count(&"potion_speed") == 0, "su efecto dura 30 s y el hueco queda libre")
	gm.potion_drunk.disconnect(on_drunk)
	gm.clear_buffs()
	await _restore_inventory(saved)


## GameManager solo escucha a Tico, el héroe registrado: registrarlo dos veces (Main y UIManager lo hacen) no duplica la
## conexión, y al registrar otro héroe el anterior deja de beber.
func test_only_the_registered_hero_drinks_for_its_hurt() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var first: Node2D = load("res://scenes/Hero.tscn").instantiate()
	var second: Node2D = load("res://scenes/Hero.tscn").instantiate()
	for h in [first, second]:
		h.remove_from_group("hero")
		add_child(h)
	await get_tree().process_frame
	var prev_hero: Node = gm.get_hero()
	gm.register_hero(first)
	gm.register_hero(first)
	im.add_potion(&"potion_heal")
	im.add_potion(&"potion_heal")
	first.take_damage(roundi(first.max_hp * 0.8), true)
	check(im.potion_count(&"potion_heal") == 1 and first.hp == first.max_hp, "registrado dos veces, un golpe bebe una sola poción (%d)" % im.potion_count(&"potion_heal"))
	gm.register_hero(second)
	first.take_damage(roundi(first.max_hp * 0.8), true)
	check(im.potion_count(&"potion_heal") == 1 and first.hp < first.max_hp * 0.3, "el héroe anterior ya no bebe (%d)" % im.potion_count(&"potion_heal"))
	second.take_damage(roundi(second.max_hp * 0.8), true)
	check(im.potion_count(&"potion_heal") == 0 and second.hp == second.max_hp, "el registrado sí")
	gm.register_hero(prev_hero)
	first.queue_free()
	second.queue_free()
	await _restore_inventory(saved)


## El pasillo avisa a GameManager cuando aparece un jefe (y GameManager decide si beber): lo que se ha puesto en los
## huecos se bebe en la presentación del jefe.
func test_the_boss_intro_makes_the_potions_drink() -> void:
	var saved := _fresh_inventory()
	var a := await _arena([])  # sin muro ni candado
	var gm := get_node("/root/GameManager")
	gm.clear_buffs()
	_im().add_potion(&"potion_speed")
	_im().add_potion(&"potion_luck")
	a.corridor._boss_intro()
	check(gm.has_buff(&"speed") and gm.has_buff(&"luck"), "la presentación del jefe bebe Velocidad y Suerte")
	check(_im().potion_count(&"potion_speed") == 0 and _im().potion_count(&"potion_luck") == 0, "y se gastan del hueco")
	gm.clear_buffs()
	await _close_arena(a)
	await _restore_inventory(saved)


## Los huecos de consumibles en el panel de Equipo: cada uno dice qué lleva; tocarlo enseña la poción en la ficha y
## mantenerlo pulsado ofrece venderla a mitad de precio (como la pulsación larga de una pieza, termina la pulsación).
func test_potion_slots_in_the_panel() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	im.add_potion(&"potion_speed")
	im.add_potion(&"potion_speed")
	var panel := _new_panel()
	var slot0: Label = panel._potion_slots[0]
	var slot1: Label = panel._potion_slots[1]
	var p0: Vector2 = panel.POTION_SLOT_RECTS[0].get_center()
	var p1: Vector2 = panel.POTION_SLOT_RECTS[1].get_center()
	check(slot0.text == "Velocidad ×2" and slot1.text == tr("Hueco libre"), "cada hueco dice qué lleva o que está libre («%s», «%s»)" % [slot0.text, slot1.text])
	_mouse(panel, p1, true)
	check(panel._press.is_empty(), "un hueco libre no se pulsa")
	_mouse(panel, p1, false)
	im.add_potion(&"potion_luck")
	check(slot1.text == "Suerte ×1", "con el panel abierto, el hueco se actualiza al llegar una poción («%s»)" % slot1.text)
	_mouse(panel, p0, true)
	check(panel._press.has("slot") and panel._press.item == null, "pulsar un hueco con pociones empieza una pulsación de hueco")
	_mouse(panel, p0, false)
	check(panel._ficha_label.text.contains(tr(Potions.CATALOG[&"potion_speed"].description)) and panel._press.is_empty(), "tocarlo enseña la poción en la ficha (%s)" % panel._ficha_label.text)
	check(im.potion_count(&"potion_speed") == 2 and not panel._confirm_box.visible, "y no pregunta ni vende nada")
	var gold: int = im.get_quantity(&"gold")
	_long_press(panel, p0)
	check(panel._confirm_box.visible and panel._confirm_text.text.contains("150"), "mantenerlo pulsado pregunta si vender, con el oro (%s)" % panel._confirm_text.text)
	check(panel._press.is_empty(), "y termina la pulsación")
	_mouse(panel, p0, false)
	check(im.potion_count(&"potion_speed") == 2 and panel._confirm_box.visible, "soltar después no vende ni toca la pregunta")
	panel._close_confirm()  # No
	check(im.potion_count(&"potion_speed") == 2, "con No se queda todo")
	_long_press(panel, p0)
	panel._on_confirm_yes()
	check(im.potion_count(&"potion_speed") == 0 and im.get_quantity(&"gold") == gold + 150 and slot0.text == tr("Hueco libre"), "con Sí se venden a mitad de precio y el hueco queda libre (%d de oro)" % (im.get_quantity(&"gold") - gold))
	# Una poción que se bebe mientras el dedo sigue en el hueco: ni error al soltar ni pregunta por un hueco ya libre
	_mouse(panel, p1, true)
	im.take_potion(&"potion_luck")
	_mouse(panel, p1, false)
	check(not panel._confirm_box.visible and panel._press.is_empty(), "soltar sobre un hueco que se acaba de vaciar no hace nada")
	im.add_potion(&"potion_luck")  # entra en el primer hueco libre: el 0, que quedó libre al vender la Velocidad
	_mouse(panel, p0, true)
	check(panel._press.has("slot"), "(la Suerte ha entrado en el hueco 0 y su pulsación está en marcha)")
	im.take_potion(&"potion_luck")
	panel._press.time = Time.get_ticks_msec() - 1000
	panel._process(0.0)
	check(not panel._confirm_box.visible and panel._press.is_empty(), "y mantenerlo no ofrece vender lo que ya no está")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


# ─── Tarea 17: rendimiento del panel ───────────────────────────────────

## Spec, apartado 11: el panel se abre en menos de 50 ms. Aquí se mide en el ordenador, con la rejilla de 6×6 llena y
## el botín con piezas; el móvil se prueba con su tarjeta.
func test_panel_opens_fast_with_a_full_inventory() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	for id in GridExpansions.ids():
		im.apply_grid_expansion(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 40:
		var res: ItemResource = load("res://data/items/%s.tres" % ITEM_IDS[i % ITEM_IDS.size()])
		var item := CraftedItem.new(res, rng.randf())
		item.aristas = PieceShape.roll_aristas(res, item.get_quality_tier(), rng)
		im.add_crafted_item(item)
		var spot := GearPacker.find_spot(im.hero_grid, item)
		if not spot.is_empty():
			im.move_item(item, InventoryManager.PLACE_HERO, spot.cell, spot.rot)
	var filled := 0  # con otra rejilla u otro empaquetado, la prueba mediría un panel a medio llenar: así se ve
	for x in im.hero_grid.size.x:
		for y in im.hero_grid.size.y:
			if im.hero_grid.item_at(Vector2i(x, y)) != null:
				filled += 1
	check(filled >= 30 and im.get_loot_count() >= 10, "el inventario está lleno: %d de 36 casillas de Tico y %d piezas en el botín" % [filled, im.get_loot_count()])
	var panel: Control = load("res://scenes/UI/EquipmentPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame
	# Tres aperturas, cerrando entre medias, y se mira la más rápida: una sola medida puede caer en un tirón de un ordenador
	# ocupado y fallar sin que el panel haya empeorado
	var samples: Array[float] = []
	for i in 3:
		var t0 := Time.get_ticks_usec()
		panel.open()
		samples.append((Time.get_ticks_usec() - t0) / 1000.0)
		panel.close()
		await get_tree().process_frame
	var ms: float = samples.min()
	print("panel de Equipo: %.1f ms, la más rápida de 3 aperturas (%.1f / %.1f / %.1f; %d piezas en Tico, %d en el botín)" % [ms, samples[0], samples[1], samples[2], im.get_hero_items().size(), im.get_loot_count()])
	check(ms < 50.0, "se abre en menos de 50 ms (la más rápida de tres: %.1f)" % ms)
	panel.queue_free()
	await _restore_inventory(saved)


# ─── Revisión final: temporizadores de Tico, guardados, copia de la partida y detalles ───

## Cambiar la rejilla de Tico recalcula su equipo (GameManager llama a reset_stats en cada cambio) con el juego en marcha
## detrás del panel: el golpe y el pulso en curso no se reinician, mientras el enemigo conserva los suyos. La velocidad nueva
## solo cambia el ritmo al que se carga el golpe (conserva su avance, como refresh_attack_speed); empezar un duelo
## (prepare_for_combat) sí los llena.
func test_a_grid_change_mid_duel_keeps_the_attack_timers() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")
	add_child(hero)
	check(is_equal_approx(hero.atk_timer, 1.0 / hero.aps) and hero.pulse_timer == hero.PULSE_INTERVAL, "al aparecer, el primer cálculo deja los temporizadores llenos (golpe %.3f de %.3f, pulso %.1f)" % [hero.atk_timer, 1.0 / hero.aps, hero.pulse_timer])
	await get_tree().process_frame
	var prev_hero: Node = gm.get_hero()
	gm.register_hero(hero)
	hero.prepare_for_combat()
	hero.atk_timer = 0.3  # el golpe va por la mitad y el pulso, por el medio
	hero.pulse_timer = 1.2
	var sword := _piece(&"sword_basic", 0.5)
	im.add_crafted_item(sword)
	var aps_before: float = hero.aps
	im.move_item(sword, &"hero", Vector2i(0, 0), 0)  # cambia la rejilla de Tico: GameManager lo recalcula
	check(hero.aps > aps_before, "(la espada le sube la velocidad: %.2f → %.2f)" % [aps_before, hero.aps])
	check(is_equal_approx(hero.atk_timer, 0.3 * aps_before / hero.aps), "el golpe en curso conserva su avance con la velocidad nueva (%.4f, esperado %.4f)" % [hero.atk_timer, 0.3 * aps_before / hero.aps])
	check(hero.pulse_timer == 1.2, "el pulso ni se toca (%.2f)" % hero.pulse_timer)
	var kept: float = hero.atk_timer
	check(im.rotate_in_place(sword), "girar la espada en Tico vale")
	check(is_equal_approx(hero.atk_timer, kept) and hero.pulse_timer == 1.2, "girarla, con la misma velocidad, deja golpe y pulso donde iban (%.4f, %.2f)" % [hero.atk_timer, hero.pulse_timer])
	im.move_item(sword, &"loot")  # quitarla devuelve la velocidad de antes y, con ella, el avance de antes
	check(is_equal_approx(hero.aps, aps_before) and is_equal_approx(hero.atk_timer, 0.3), "quitarla devuelve el golpe a su avance de antes (%.4f)" % hero.atk_timer)
	hero.prepare_for_combat()
	check(is_equal_approx(hero.atk_timer, 1.0 / hero.aps) and hero.pulse_timer == hero.PULSE_INTERVAL, "un duelo nuevo sí empieza con los dos llenos (golpe %.3f, pulso %.1f)" % [hero.atk_timer, hero.pulse_timer])
	gm.register_hero(prev_hero)
	hero.queue_free()
	await _restore_inventory(saved)


var _save_writes := 0  # guardados que GameManager ha pedido escribir desde la última vez que se puso a cero


func _count_save_write() -> void:
	_save_writes += 1


## GameManager guarda en diferido cuando cambian las piezas (crafted_items_changed) y el equipo de Tico (equipment_changed):
## los guardados que se piden en un mismo fotograma son una sola escritura (antes, cada cambio de la rejilla de Tico escribía la
## partida entera dos veces). Se cambia el escritor por uno que solo cuenta, de principio a fin: la prueba no escribe
## ninguna partida.
func test_changes_in_the_same_frame_write_one_save() -> void:
	var gm := get_node("/root/GameManager")
	gm.save_writer = Callable(self, "_count_save_write")
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_basic", 0.5)
	var helmet := _piece(&"helmet_basic", 0.5)
	im.add_crafted_item(sword)
	im.add_crafted_item(helmet)
	for i in 2:
		await get_tree().process_frame  # deja pasar los guardados de antes de empezar a contar
	_save_writes = 0
	im.move_item(sword, &"hero", Vector2i(0, 0), 0)  # la rejilla de Tico: avisa de las piezas y del equipo
	for i in 2:
		await get_tree().process_frame
	check(_save_writes == 1, "un cambio de la rejilla de Tico escribe la partida una vez, no dos (%d)" % _save_writes)
	_save_writes = 0
	im.sell_item(helmet)  # fuera de Tico: solo avisa de las piezas
	for i in 2:
		await get_tree().process_frame
	check(_save_writes == 1, "un movimiento que no es de Tico también escribe una vez (%d)" % _save_writes)
	_save_writes = 0
	im.rotate_in_place(sword)  # tres cambios en el mismo fotograma, dos de ellos de Tico
	im.move_item(helmet, &"loot")
	im.move_item(sword, &"loot")
	for i in 2:
		await get_tree().process_frame
	check(_save_writes == 1, "varios cambios en un fotograma son una sola escritura (%d)" % _save_writes)
	for i in 2:
		await get_tree().process_frame
	check(_save_writes == 1, "y sin cambios no se escribe más (%d)" % _save_writes)
	im.move_item(sword, &"hero", Vector2i(0, 0), 0)
	for i in 2:
		await get_tree().process_frame
	check(_save_writes == 2, "un cambio de otro fotograma vuelve a escribir: la espera no se queda puesta (%d)" % _save_writes)
	await _restore_inventory(saved)  # también guarda en diferido: lo cuenta el escritor de pega
	gm.save_writer = Callable()


## Con la tienda oculta (como en HUD_Main hasta que open() la abre), un cambio de piezas no reconstruye su lista de venta, que
## cuesta unos 7 controles por pieza del botín y la mochila. open() la rehace al abrirla; visible, el cambio se ve al momento.
func test_a_hidden_shop_does_not_rebuild_its_sell_list() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var shop := ShopPanel.new()
	add_child(shop)
	await get_tree().process_frame
	shop.visible = false
	var list: Control = shop._inventory_grid
	var first_id := list.get_child(0).get_instance_id()
	var helmet := _piece(&"helmet_basic", 0.5)
	im.add_crafted_item(helmet)
	await get_tree().process_frame  # una reconstrucción libera los controles de antes al acabar el fotograma
	check(list.get_child_count() == 1 and list.get_child(0).get_instance_id() == first_id, "oculta, no reconstruye la lista: siguen los mismos controles (%d)" % list.get_child_count())
	shop.open()
	await get_tree().process_frame
	var card := list.get_child(0)
	var labels := card.find_children("*", "Label", true, false)
	check(list.get_child_count() == 1 and card is PanelContainer and not labels.is_empty() and labels[0].text == helmet.get_display_name(), "al abrirla enseña la lista de ahora: la pieza nueva (%d controles)" % list.get_child_count())
	var boots := _piece(&"boots_basic", 0.5)
	im.add_crafted_item(boots)
	await get_tree().process_frame
	check(list.get_child_count() == 2, "visible, un cambio de piezas se ve al momento (%d tarjetas)" % list.get_child_count())
	shop.free()
	await _restore_inventory(saved)


## La partida es una sola y la comparten todas las compilaciones del juego: antes de que el guardado de después de cargar una
## partida antigua la reescriba en la versión actual, SaveManager la copia en save.v1.bak.json con los mismos bytes, y solo la
## primera vez (una migración posterior no pisa la primera copia). Con la partida ya en la versión actual no hace copia.
func test_loading_an_old_save_keeps_a_backup_of_it() -> void:
	var had := FileAccess.file_exists(V1_BACKUP_PATH)
	var kept := FileAccess.get_file_as_bytes(V1_BACKUP_PATH) if had else PackedByteArray()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(V1_BACKUP_PATH))
	check(_load_save_dict(_v1_save()), "carga una partida de la versión 1")
	var original := FileAccess.get_file_as_bytes(SAVE_PATH)  # lo que había en el disco al cargar
	check(FileAccess.file_exists(V1_BACKUP_PATH) and FileAccess.get_file_as_bytes(V1_BACKUP_PATH) == original, "la carga deja una copia con los bytes de la partida original")
	await get_tree().process_frame  # el guardado de después de cargar reescribe save.json
	var rewritten: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(int(rewritten.version) == SaveManager.SAVE_VERSION, "save.json ya está en la versión %d (%s)" % [SaveManager.SAVE_VERSION, rewritten.version])
	check(FileAccess.file_exists(V1_BACKUP_PATH) and FileAccess.get_file_as_bytes(V1_BACKUP_PATH) == original, "y la copia sigue con los bytes de la versión 1")
	var later := _v1_save()
	later.game.current_enemy_level = 9
	check(_load_save_dict(later), "se carga otra partida antigua, distinta")
	check(FileAccess.file_exists(V1_BACKUP_PATH) and FileAccess.get_file_as_bytes(V1_BACKUP_PATH) == original, "una migración posterior no pisa la primera copia")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(V1_BACKUP_PATH))
	check(SaveManager.save_game() and SaveManager.load_game(), "se guarda y se carga una partida de la versión actual")
	check(not FileAccess.file_exists(V1_BACKUP_PATH), "una partida de la versión actual no hace copia")
	await _reload_user_save()
	# Se deja la copia como estaba antes de la prueba (la suite también la restaura al acabar)
	if had:
		var f := FileAccess.open(V1_BACKUP_PATH, FileAccess.WRITE)
		f.store_buffer(kept)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(V1_BACKUP_PATH))


## La migración toma el récord como GameManager.load_save_data: el mayor entre el récord guardado y la sala actual. Una
## partida más antigua aún no guardaba el récord: con el valor sin más, no daría ninguna de las ampliaciones que GameManager
## ya cuenta como ganadas.
func test_migration_takes_the_record_like_game_manager_does() -> void:
	var data := _v1_save()
	data.game.erase("best_enemy_level")
	data.game.current_enemy_level = 35
	check(_load_save_dict(data), "carga una partida de la versión 1 sin récord guardado")
	var gm := get_node("/root/GameManager")
	var im := _im()
	check(gm.best_enemy_level == 35, "GameManager toma la sala actual como récord (%d)" % gm.best_enemy_level)
	check(im.expansions.size() == 3 and im.hero_grid_size() == Vector2i(6, 5), "y la migración da las ampliaciones de ese mismo récord: 3 y rejilla de 6×5 (%d, %s)" % [im.expansions.size(), im.hero_grid_size()])
	await _reload_user_save()


## Un giro negativo vale lo mismo que su equivalente en 0-3: PieceShape.of_item toma el giro de la pieza ante cualquier
## negativo, y cells_at se lo pasaba tal cual (place guardaba el giro bueno pero ocupaba las casillas del otro). Las botas
## en L cambian de casillas con cada giro.
func test_cells_at_takes_a_negative_rotation_as_its_turn() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var boots := _piece(&"boots_advanced")  # giro propio 0
	for rot in [-1, -2, -3, -5]:
		var expected := g.cells_at(boots, Vector2i(1, 1), posmod(rot, 4))
		var got := g.cells_at(boots, Vector2i(1, 1), rot)
		check(got.clean == expected.clean and got.aristas == expected.aristas, "el giro %d es el %d (%s, esperado %s)" % [rot, posmod(rot, 4), got.clean, expected.clean])
	check(g.place(boots, Vector2i(1, 1), -1) and g.rot_of(boots) == 3, "colocada con el giro -1 guarda el 3")
	check(g.placed_clean_cells(boots).all(func(c): return g.item_at(c) == boots), "y ocupa las casillas del giro 3, las que dice ocupar (%s)" % [g.placed_clean_cells(boots)])


## «A la mochila» con la mochila llena no mueve nada: la ficha breve dice por qué (antes solo sonaba un toque grave). El aviso
## se va con el siguiente refresco, y con sitio la pieza pasa a la mochila sin decir nada.
