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
