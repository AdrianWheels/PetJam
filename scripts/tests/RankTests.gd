extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas de los rangos de plano por ciclo (spec doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md),
## solo desarrollo, sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn

const BalanzaBinding := preload("res://scripts/tests/BalanzaBinding.gd")
const BALANZA_TIERS := {
	&"basic": [&"sword_basic", &"shield_basic", &"helmet_basic", &"boots_basic"],
	&"advanced": [&"sword_advanced", &"shield_advanced", &"helmet_advanced", &"boots_advanced"],
	&"master": [&"sword_masterwork", &"shield_master", &"helmet_master", &"boots_master"],
}


func _new_hero() -> Node2D:
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")  # que no lo confundan con el héroe de la partida
	add_child(hero)
	return hero


func _new_enemy() -> Node2D:
	var e: Node2D = load("res://scenes/Enemy.tscn").instantiate()
	e.remove_from_group("enemy")
	add_child(e)
	return e


# ─── Tarea 1: fórmulas del combate ─────────────────────────────────────

func test_hero_stats_match_the_game_formulas() -> void:
	var bare := CombatMath.hero_stats({})
	check(bare.max_hp == 160, "Tico sin equipo: 160 de vida (60 + fuerza 10 × 10), no %d" % bare.max_hp)
	check(is_equal_approx(bare.dmg, 21.0), "sin equipo: 21 de daño (6 + 10 × 1,5), no %.2f" % bare.dmg)
	check(is_equal_approx(bare.aps, 1.2), "sin equipo: 1,2 ataques por segundo, no %.3f" % bare.aps)
	check(is_equal_approx(bare.crit_p, 0.05), "sin equipo: 5 % de crítico")
	check(is_equal_approx(bare.crit_m, 1.58), "sin equipo: crítico ×1,58")
	var geared := CombatMath.hero_stats({"damage": 27, "hp": 315, "armor": 33, "crit": 0.3375, "aps": 0.5425})
	check(geared.max_hp == 475 and is_equal_approx(geared.dmg, 48.0) and geared.armor == 33,
		"equipo maestro medio: 475 de vida, 48 de daño y 33 de armadura")
	check(is_equal_approx(geared.aps, 1.7425), "equipo maestro medio: 1,7425 ataques por segundo")


## La curva va en escalera (spec de rangos, apartado 6): poco por sala dentro del ciclo y un salto al empezar cada uno.
func test_enemy_curve_is_a_staircase() -> void:
	var skel := EnemyScaling.enemy_stats(1, EnemyArchetypes.get_data(&"skeleton"), false)
	check(skel.max_hp == 40 and is_equal_approx(skel.dmg, EnemyScaling.DMG_AT_ROOM_1), "la sala 1 no cambia (40 de vida, %.2f de daño)" % skel.dmg)
	check(is_equal_approx(EnemyScaling.stat_scale(50), pow(EnemyScaling.EXP, 49)), "dentro del ciclo, EXP por sala")
	check(is_equal_approx(EnemyScaling.stat_scale(51), EnemyScaling.STEP), "la sala 51 es STEP veces la 1")
	check(is_equal_approx(EnemyScaling.stat_scale(101), EnemyScaling.STEP * EnemyScaling.STEP), "la 101, STEP al cuadrado")
	check(EnemyScaling.stat_scale(51) > EnemyScaling.stat_scale(50), "la sala 51 es más dura que la 50 (STEP > EXP^49)")
	var a := EnemyScaling.enemy_stats(30, EnemyArchetypes.get_data(&"skeleton"), false)
	var b := EnemyScaling.enemy_stats(31, EnemyArchetypes.get_data(&"skeleton"), false)
	check(b.max_hp >= a.max_hp and b.dmg > a.dmg, "cada sala es al menos tan dura como la anterior")
	var boss := EnemyScaling.enemy_stats(60, EnemyArchetypes.get_data(&"boss"), true)
	check(is_equal_approx(boss.dmg, EnemyScaling.DMG_AT_ROOM_1 * EnemyScaling.stat_scale(60) * EnemyScaling.BOSS_MULT), "los jefes, ×BOSS_MULT")
	var far := EnemyScaling.enemy_stats(160, EnemyArchetypes.get_data(&"skeleton"), false)
	check(is_equal_approx(far.aps, skel.aps) and is_equal_approx(far.crit_p, skel.crit_p) and is_equal_approx(far.crit_m, skel.crit_m), "ritmo y crítico, los de la sala 1")
	check(is_equal_approx(float(far.INT), float(skel.INT) * EnemyScaling.stat_scale(160)), "el pulso crece con la escala")


## Base de Tico por rango (spec de rangos, apartado 6, «Base de Tico»): vida, daño y pulso × cycle_mult(rango).
func test_hero_base_scales_with_team_rank() -> void:
	var one := CombatMath.hero_stats({})
	var two := CombatMath.hero_stats({}, 2)
	var m := EnemyScaling.cycle_mult(2)
	check(two.max_hp == roundi(one.max_hp * m), "vida base × el salto (%d)" % two.max_hp)
	check(is_equal_approx(two.dmg, one.dmg * m), "daño base × el salto")
	check(two.INT == roundi(one.INT * m), "pulso base × el salto")
	check(is_equal_approx(two.crit_m, one.crit_m) and is_equal_approx(two.aps, one.aps), "crítico y ritmo no cambian con el rango")
	var geared := CombatMath.hero_stats({"hp": 50, "damage": 10}, 2)
	check(geared.max_hp == two.max_hp + 50 and is_equal_approx(geared.dmg, two.dmg + 10), "el equipo no se multiplica otra vez")


## El rango del equipo (spec de rangos, apartado 6): el menor entre las piezas equipadas; sin piezas, el I.
func test_team_rank_is_the_lowest_piece() -> void:
	check(Ranks.team_rank([3, 2, 4, 2]) == 2, "el menor rango de las piezas")
	check(Ranks.team_rank([]) == 1, "sin piezas, rango I")


## Las palancas de la calibración son static var: el enlace de Balanza las cambia con set_param.
func test_calibration_levers_are_static_vars() -> void:
	var saved := [EnemyScaling.EXP, EnemyScaling.STEP, EnemyScaling.BOSS_MULT, CombatMath.ARMOR_K, Ranks.RANK_POWER_BONUS]
	EnemyScaling.EXP = 1.05
	EnemyScaling.STEP = 3.0
	check(is_equal_approx(EnemyScaling.stat_scale(2), 1.05) and is_equal_approx(EnemyScaling.stat_scale(51), 3.0), "EXP y STEP mueven la curva")
	Ranks.RANK_POWER_BONUS = 2.0
	check(is_equal_approx(Ranks.stat_mult(2), 6.0), "stat_mult(2) es STEP por el bono")
	CombatMath.ARMOR_K = 10.0
	check(is_equal_approx(CombatMath.armor_mitigation(10, 1), 0.5), "ARMOR_K mueve la mitigación")
	EnemyScaling.EXP = saved[0]
	EnemyScaling.STEP = saved[1]
	EnemyScaling.BOSS_MULT = saved[2]
	CombatMath.ARMOR_K = saved[3]
	Ranks.RANK_POWER_BONUS = saved[4]


func test_hero_and_enemy_nodes_use_the_shared_formulas() -> void:
	var hero := _new_hero()
	await get_tree().process_frame
	var inv := get_node("/root/InventoryManager")
	var expected := CombatMath.hero_stats_with_powers(inv.calculate_total_stats(), inv.active_legendary_powers(), inv.equipment_rank())
	check(hero.max_hp == expected.max_hp and is_equal_approx(hero.dmg, expected.dmg),
		"Hero.reset_stats usa CombatMath.hero_stats (%d/%d, %.1f/%.1f)" % [hero.max_hp, expected.max_hp, hero.dmg, expected.dmg])
	check(is_equal_approx(hero.base_aps, expected.aps), "Hero.base_aps es el ritmo de CombatMath")
	hero.queue_free()
	var enemy := _new_enemy()
	await get_tree().process_frame
	enemy.configure_for_level(10, true)
	var e := EnemyScaling.enemy_stats(10, EnemyArchetypes.get_data(&"boss"), true)
	check(enemy.max_hp == e.max_hp and is_equal_approx(enemy.dmg, e.dmg), "Enemy.reset_stats usa EnemyScaling.enemy_stats")
	check(is_equal_approx(enemy.expected_dps(), CombatMath.expected_dps(e)), "Enemy.expected_dps usa CombatMath")
	enemy.queue_free()
	await get_tree().process_frame


# ─── Tarea 0: rango del equipo en la base de Tico ──────────────────────

func _im() -> Node:
	return get_node("/root/InventoryManager")


## Deja el inventario vacío (rejilla de 4×4) y devuelve lo que había para restaurarlo (como InventoryGridTests).
func _fresh_inventory() -> Dictionary:
	var saved: Dictionary = _im().to_save_data()
	_im().clear()
	return saved


func _restore_inventory(saved: Dictionary) -> void:
	_im().load_save_data(saved, int(get_node("/root/GameManager").best_enemy_level))
	await get_tree().process_frame  # deja pasar los guardados diferidos del cambio de equipo


## Pieza de rango `rank` en la casilla `cell` de la rejilla de Tico, sin girar. Calidad media: no es legendaria (sin
## habilidades) y no lleva aristas (CraftedItem.new no las sortea).
func _hero_piece(id: StringName, rank: int, cell: Vector2i) -> CraftedItem:
	var item := CraftedItem.new(load("res://data/items/%s.tres" % id), 0.5)
	item.rank = rank
	_im().add_crafted_item(item)
	_im().move_item(item, InventoryManager.PLACE_HERO, cell, 0)
	return item


## Base de Tico por el rango del equipo (spec de rangos, apartado 6, «Base de Tico»): Hero.reset_stats y el panel de
## Equipo pasan el rango de la rejilla de Tico a CombatMath, así que su vida base es × cycle_mult(rango).
func test_team_rank_reaches_tico_base() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var hero := _new_hero()
	await get_tree().process_frame
	check(im.equipment_rank() == 1 and hero.max_hp == CombatMath.hero_stats(im.calculate_total_stats()).max_hp, "rejilla vacía: rango I y la base de siempre (%d)" % hero.max_hp)
	var cells := {&"sword_basic": Vector2i(0, 0), &"shield_basic": Vector2i(1, 0), &"helmet_basic": Vector2i(2, 0), &"boots_basic": Vector2i(3, 0)}
	for id in cells:
		_hero_piece(id, 2, cells[id])
	check(im.get_hero_items().size() == 4 and im.equipment_rank() == 2, "4 piezas de rango II en Tico: rango II (%d piezas)" % im.get_hero_items().size())
	hero.reset_stats()  # el héroe de prueba no está en el grupo "hero": GameManager no lo recalcula solo
	var base_one: int = CombatMath.hero_stats({}).max_hp
	var gear_hp: int = CombatMath.hero_stats(im.calculate_total_stats()).max_hp - base_one  # lo que suman las piezas
	check(hero.max_hp == roundi(base_one * EnemyScaling.cycle_mult(2)) + gear_hp, "la vida base de Tico es × cycle_mult(2) (%d)" % hero.max_hp)
	check(hero.max_hp == CombatMath.hero_stats_with_powers(im.calculate_total_stats(), im.active_legendary_powers(), 2).max_hp, "Hero.reset_stats usa el rango del equipo")
	var panel: Control = load("res://scenes/UI/EquipmentPanel.tscn").instantiate()
	add_child(panel)
	panel.open()
	await get_tree().process_frame
	check((tr("Vida %d") % hero.max_hp) in panel._stats_label.text, "el panel de Equipo enseña la misma vida que Tico (%s)" % panel._stats_label.text)
	panel.queue_free()
	var base_two: int = hero.max_hp - gear_hp
	var extra := _hero_piece(&"sword_basic", 1, Vector2i(0, 2))
	check(extra.place == InventoryManager.PLACE_HERO and im.equipment_rank() == 2, "otra espada de rango I no baja el rango: cuenta la mejor espada")
	hero.reset_stats()
	var gear_hp_now: int = CombatMath.hero_stats(im.calculate_total_stats()).max_hp - base_one
	check(hero.max_hp - gear_hp_now == base_two, "y la base de Tico sigue siendo la del rango II (%d)" % (hero.max_hp - gear_hp_now))
	var helmet_one := CraftedItem.new(load("res://data/items/helmet_advanced.tres"), 0.5)
	im.add_crafted_item(helmet_one)
	var sim: GearGrid = im.simulate_hero_grid(im.best_hero_item("head"), InventoryManager.PLACE_LOOT, Vector2i.ZERO, 0)
	check(InventoryManager.grid_rank(sim) == 2, "sin casco en la vista previa: el tipo que falta no cuenta")
	sim = im.simulate_hero_grid(helmet_one, InventoryManager.PLACE_HERO, Vector2i(1, 2), 0)
	check(InventoryManager.grid_rank(sim) == 2, "un casco avanzado de rango I no baja el rango: el mejor casco sigue siendo el básico II")
	hero.queue_free()
	await _restore_inventory(saved)


# ─── Tarea 2: Ranks ────────────────────────────────────────────────────

func test_cycles_are_fifty_rooms() -> void:
	check(Ranks.ROOMS_PER_CYCLE == Biomes.ROOMS_PER_BIOME * Biomes.LIST.size(), "un ciclo son los 5 biomas")
	for pair in [[1, 1], [50, 1], [51, 2], [100, 2], [101, 3]]:
		check(Ranks.cycle_for_room(pair[0]) == pair[1], "la sala %d es del ciclo %d" % pair)
	check(Ranks.first_room_of_cycle(3) == 101, "el ciclo III empieza en la sala 101")


func test_milestones_are_boss_rooms() -> void:
	check(Ranks.milestone_for_boss_room(10).is_empty(), "el jefe de la sala 10 no es hito")
	check(Ranks.milestone_for_boss_room(25).is_empty(), "una sala normal no es hito")
	var cases := [
		[20, 1, Ranks.TIER_ADVANCED], [40, 1, Ranks.TIER_MASTER], [50, 2, Ranks.TIER_BASIC],
		[70, 2, Ranks.TIER_ADVANCED], [90, 2, Ranks.TIER_MASTER], [100, 3, Ranks.TIER_BASIC],
	]
	for c in cases:
		var ms := Ranks.milestone_for_boss_room(c[0])
		check(ms.get("rank") == c[1] and ms.get("tier") == c[2], "sala %d → rango %d %s (%s)" % [c[0], c[1], c[2], ms])


func test_milestones_up_to_record() -> void:
	check(Ranks.milestones_up_to_record(1) == [{"rank": 1, "tier": Ranks.TIER_BASIC}], "al empezar, solo los básicos I")
	check(Ranks.milestones_up_to_record(20).size() == 1, "con récord 20 el jefe de la sala 20 aún no está vencido")
	var at57 := Ranks.milestones_up_to_record(57)
	check(at57.size() == 4, "con récord 57: básicos I, avanzados I, maestros I y básicos II (%s)" % [at57])
	check(at57.has({"rank": 2, "tier": Ranks.TIER_BASIC}), "con récord 57 están los básicos II")


func test_multipliers_grow_with_the_rank() -> void:
	check(is_equal_approx(Ranks.mat_mult(1), 1.0) and is_equal_approx(Ranks.mat_mult(2), 1.6), "mat_mult: 1 y 1,6")
	check(is_equal_approx(Ranks.gold_mult(3), Ranks.mat_mult(3)), "el oro crece como los materiales")
	check(is_equal_approx(Ranks.stat_mult(1), 1.0), "el rango I no cambia las estadísticas")
	for r in range(1, 6):
		check(Ranks.stat_mult(r + 1) > Ranks.stat_mult(r), "stat_mult crece del rango %d al %d" % [r, r + 1])


func test_scale_stats_only_touches_additive_stats() -> void:
	var base := {"damage": 10, "hp": 20, "str": 0, "armor": 3, "agi": 5, "int": 2, "crit": 0.1, "aps": 0.2}
	var m := Ranks.stat_mult(2)
	var s := Ranks.scale_stats(base, 2)
	check(s.damage == roundi(10 * m) and s.hp == roundi(20 * m) and s.armor == roundi(3 * m), "daño, vida y armadura escalan")
	check(s.agi == 5 and s.int == 2 and is_equal_approx(s.crit, 0.1) and is_equal_approx(s.aps, 0.2), "agilidad, inteligencia, crítico y velocidad no")
	check(Ranks.scale_stats(base, 1) == base, "el rango I deja las estadísticas igual")


func test_recipe_adds_biome_materials_by_tier() -> void:
	var sword_master := {"fire": 2, "iron": 8}
	check(Ranks.recipe(sword_master, Ranks.TIER_MASTER, 1) == {&"fire": 2, &"iron": 8, &"frost": 2, &"void_shard": 2}, "maestro I: sus materiales + escarcha y vacío")
	check(Ranks.recipe(sword_master, Ranks.TIER_MASTER, 2) == {&"fire": 4, &"iron": 13, &"frost": 4, &"void_shard": 4}, "maestro II: todo × 1,6 redondeado hacia arriba")
	check(Ranks.recipe({"iron": 3}, Ranks.TIER_BASIC, 1) == {&"iron": 3, &"bone": 2}, "básico I: + hueso")
	check(Ranks.recipe({"iron": 5, "leather": 1}, Ranks.TIER_ADVANCED, 1) == {&"iron": 5, &"leather": 1, &"moss": 2, &"obsidian": 2}, "avanzado I: + musgo y obsidiana")


func test_rank_names() -> void:
	check(Ranks.numeral(1) == "" and Ranks.numeral(2) == "II" and Ranks.numeral(3) == "III", "numerales: nada, II, III")
	check(Ranks.tier_from_rarity("master") == Ranks.TIER_MASTER and Ranks.tier_from_rarity("basic") == Ranks.TIER_BASIC, "tier desde la rareza")
	check(Ranks.biome_material_for_room(5) == &"bone" and Ranks.biome_material_for_room(45) == &"void_shard" and Ranks.biome_material_for_room(55) == &"bone", "material de cada bioma")
	var t := Ranks.milestone_text(2, Ranks.TIER_ADVANCED)
	check(t.contains("II") and not t.is_empty(), "el texto del hito lleva el numeral (%s)" % t)


# ─── Piloto de Balanza: el enlace (spec del kit, apartado 11.1) ──────────

## Un conjunto como los que manda el arnés: las 4 piezas de un nivel a una calidad (estadísticas sin redondear y bandas).
static func _balanza_build(tier: StringName, quality: float, rank: int) -> Dictionary:
	var items := []
	for id in BALANZA_TIERS[tier]:
		var res: ItemResource = load("res://data/items/%s.tres" % id)
		var stats := {}
		var bands := {}
		for stat in ["damage", "hp", "armor", "crit", "aps"]:
			var lo := float(res.get("base_%s_min" % stat))
			var hi := float(res.get("base_%s_max" % stat))
			stats[stat] = lerpf(lo, hi, quality)
			bands[stat] = {"min": lo, "max": hi}
		items.append({"id": String(id), "slot": res.equipment_slot, "stats": stats, "bands": bands, "effects": []})
	return {"items": items, "params": {"rank": rank, "quality": quality}}


func test_balanza_gear_matches_the_game() -> void:
	var totals := BalanzaBinding.gear_totals(_balanza_build(&"advanced", 0.55, 2).items, 2)
	var expected := {}
	for id in BALANZA_TIERS[&"advanced"]:
		var res: ItemResource = load("res://data/items/%s.tres" % id)
		var stats := Ranks.scale_stats(res.calculate_stats(0.55), 2)
		for k in stats:
			expected[k] = expected.get(k, 0) + stats[k]
	for k in ["damage", "hp", "armor", "crit", "aps"]:
		check(is_equal_approx(float(totals[k]), float(expected[k])), "%s del avanzado II como en el juego (%s y %s)" % [k, totals[k], expected[k]])
	var delta := BalanzaBinding.gear_totals([{"id": "@delta:hp", "virtual": true, "stats": {"hp": 7.0}, "bands": {}, "effects": []}], 2)
	check(is_equal_approx(float(delta.hp), 7.0), "un objeto virtual del arnés se suma tal cual, sin rango")


func test_balanza_wall_is_the_first_lost_duel() -> void:
	var hero := CombatMath.hero_stats({})
	var dps := CombatMath.expected_dps(hero)
	var w: Dictionary = BalanzaBinding.wall_of(hero)
	var wall := int(w.wall)
	check(wall >= 2, "Tico sin equipo gana la sala 1 (muro en la %d)" % wall)
	check(not BalanzaBinding.duel(hero, dps, wall).won and BalanzaBinding.duel(hero, dps, wall - 1).won, "pierde en el muro y gana en la anterior")
	# El progreso se mide contra los esqueletos de la curva: va de la sala anterior a la primera que pierde contra ellos
	var skeleton := EnemyArchetypes.get_data(&"skeleton")
	var lost := 1
	while lost <= BalanzaBinding.MAX_ROOM and BalanzaBinding.duel_against(hero, dps, EnemyScaling.enemy_stats(lost, skeleton, false), lost).won:
		lost += 1
	check(w.progress >= lost - 1 and w.progress < lost, "el progreso va de la sala %d a la %d (%.2f)" % [lost - 1, lost, w.progress])


## El progreso no salta al ganar una sala más: vale la sala ganada más justa al ganarla y la perdida al empatarla.
func test_balanza_progress_is_continuous() -> void:
	check(absf(BalanzaBinding.progress_between(7, 1.0 + 1e-9, 9, 0.8) - 7.0) < 1e-6, "recién ganada la sala 7, el progreso es 7")
	check(absf(BalanzaBinding.progress_between(7, 1.3, 9, 1.0) - 9.0) < 1e-6, "con la sala 9 empatada, el progreso es 9")
	var mid := BalanzaBinding.progress_between(7, 1.3, 9, 0.8)
	check(mid > 7.0 and mid < 9.0, "entre las dos, en medio (%.2f)" % mid)
	check(is_equal_approx(BalanzaBinding.progress_between(0, INF, 1, 0.4), 0.4), "si pierde la sala 1, su margen")


func test_balanza_quality_and_rank_move_progress() -> void:
	var b = BalanzaBinding.new()
	var low: Dictionary = b.evaluate(_balanza_build(&"basic", 0.4, 1), "duel", 1)
	var high: Dictionary = b.evaluate(_balanza_build(&"basic", 1.0, 1), "duel", 1)
	check(high.progress > low.progress, "más calidad, más progreso (%.2f > %.2f)" % [high.progress, low.progress])
	var rank2: Dictionary = b.evaluate(_balanza_build(&"basic", 0.4, 2), "duel", 1)
	check(rank2.progress > low.progress, "más rango, más progreso (%.2f > %.2f)" % [rank2.progress, low.progress])


func test_balanza_set_param_reaches_the_levers() -> void:
	var b = BalanzaBinding.new()
	var saved := [EnemyScaling.EXP, EnemyScaling.STEP, EnemyScaling.BOSS_MULT, CombatMath.ARMOR_K, Ranks.RANK_POWER_BONUS]
	b.set_param("exp", 1.03)
	b.set_param("step", 5.0)
	b.set_param("boss", 2.0)
	b.set_param("armor_k", 33.0)
	b.set_param("rank_bonus", 1.5)
	check(is_equal_approx(EnemyScaling.EXP, 1.03) and is_equal_approx(EnemyScaling.STEP, 5.0) and is_equal_approx(EnemyScaling.BOSS_MULT, 2.0), "set_param llega a la curva")
	check(is_equal_approx(CombatMath.ARMOR_K, 33.0) and is_equal_approx(Ranks.RANK_POWER_BONUS, 1.5), "set_param llega a la armadura y al bono de rango")
	EnemyScaling.EXP = saved[0]
	EnemyScaling.STEP = saved[1]
	EnemyScaling.BOSS_MULT = saved[2]
	CombatMath.ARMOR_K = saved[3]
	Ranks.RANK_POWER_BONUS = saved[4]


## Review Focus 5: un equipo que nunca pierde llega al tope sin colgarse.
func test_balanza_wall_has_a_ceiling() -> void:
	var titan := CombatMath.hero_stats({"damage": 1e12, "hp": 1e15})
	var w: Dictionary = BalanzaBinding.wall_of(titan)
	check(int(w.wall) == BalanzaBinding.MAX_ROOM + 1 and is_equal_approx(w.progress, float(BalanzaBinding.MAX_ROOM)), "sin muro: wall = MAX_ROOM + 1 y progress = MAX_ROOM")


# ─── Tarea 4: materiales de bioma ──────────────────────────────────────

## Desde el arte de pegatinas (2026-10-02) los iconos de material son ilustraciones cuadradas, ya no pixel art de 12x12.
func test_biome_materials_exist_with_pixel_icons() -> void:
	for mat_id in Ranks.BIOME_MATERIALS:
		var path := "res://data/materials/%s.tres" % mat_id
		check(ResourceLoader.exists(path), "existe " + path)
		var res = load(path)
		var icon: Texture2D = res.icon if res else null
		check(icon != null and icon.get_width() == icon.get_height() and icon.get_width() >= 64, "%s tiene icono ilustrado cuadrado (%s)" % [mat_id, icon.get_size() if icon else "sin icono"])


func test_enemy_loot_grows_with_the_cycle_and_drops_its_biome_material() -> void:
	var inv := get_node("/root/InventoryManager")
	var e := _new_enemy()
	await get_tree().process_frame
	e.configure_for_level(5, false)  # Catacumbas, ciclo I
	e.biome_drop_chance = 1.0
	var bone_before: int = inv.get_quantity(&"bone")
	e.generate_drops()
	check(int(e.last_material_drop.get("quantity", 0)) == 15, "ciclo I: tanda de 15 (%s)" % [e.last_material_drop])
	check(e.last_biome_drop.get("item_id") == &"bone" and int(e.last_biome_drop.get("quantity", 0)) == 3, "Catacumbas suelta 3 de hueso (%s)" % [e.last_biome_drop])
	check(inv.get_quantity(&"bone") == bone_before + 3, "el hueso llega al inventario")
	e.configure_for_level(55, false)  # Catacumbas II, ciclo II
	e.generate_drops()
	check(int(e.last_material_drop.get("quantity", 0)) == ceili(15 * Ranks.mat_mult(2) - 0.0001), "ciclo II: la tanda crece con mat_mult")
	e.biome_drop_chance = 0.0
	e.configure_for_level(45, false)
	e.generate_drops()
	check(e.last_biome_drop.is_empty(), "sin la tirada no hay material de bioma")
	var gm := get_node("/root/GameManager")
	var best_before: int = gm.best_enemy_level
	gm.best_enemy_level = 40  # la primera vez: su muerte sube el récord
	e.configure_for_level(40, true)  # jefe del Glaciar: suelta el suyo aunque la probabilidad sea 0
	e.generate_drops()
	check(e.last_biome_drop.get("item_id") == &"frost" and int(e.last_biome_drop.get("quantity", 0)) == 10, "el jefe del Glaciar suelta 10 de escarcha (%s)" % [e.last_biome_drop])
	gm.best_enemy_level = 41  # ya vencido: al repetirlo, como un enemigo normal
	e.generate_drops()
	check(e.last_biome_drop.is_empty(), "repetir un jefe no da su tanda de bioma (%s)" % [e.last_biome_drop])
	gm.best_enemy_level = best_before
	e.queue_free()
	await get_tree().process_frame


# ─── Tarea 5: objeto forjado con rango ─────────────────────────────────

func test_crafted_item_has_rank_and_scaled_stats() -> void:
	var res: ItemResource = load("res://data/items/sword_masterwork.tres")
	var one := CraftedItem.new(res, 0.9)
	var three := CraftedItem.new(res, 0.9, 3)
	check(one.rank == 1 and three.rank == 3, "el rango se guarda en el objeto")
	check(three.calculated_stats.damage == roundi(one.calculated_stats.damage * Ranks.stat_mult(3)), "el daño escala con el rango")
	check(is_equal_approx(three.calculated_stats.crit, one.calculated_stats.crit), "el crítico no escala")
	check(three.get_name_with_rank().ends_with(" III") and not one.get_name_with_rank().ends_with(" I"), "numeral solo desde el II (%s / %s)" % [one.get_name_with_rank(), three.get_name_with_rank()])
	check(three.get_display_name().contains("III") and three.get_display_name().contains("90%"), "el nombre visible lleva numeral y calidad (%s)" % three.get_display_name())


func test_crafted_item_rank_survives_save() -> void:
	var res: ItemResource = load("res://data/items/helmet_master.tres")
	var item := CraftedItem.new(res, 0.7, 2)
	item.place = InventoryManager.PLACE_BAG
	item.cell = Vector2i(2, 1)
	item.rot = 3
	var ar: Array[Vector2i] = [Vector2i(3, 0)]
	item.aristas = ar
	var back := CraftedItem.from_dict(JSON.parse_string(JSON.stringify(item.to_dict())), res)  # como desde el fichero
	check(back.rank == 2 and back.calculated_stats.hp == item.calculated_stats.hp and back.calculated_stats.armor == item.calculated_stats.armor, "rango y estadísticas vuelven igual")
	check(back.place == item.place and back.cell == item.cell and back.rot == item.rot and back.aristas == item.aristas, "y su sitio, casilla, giro y aristas (%s %s %d %s)" % [back.place, back.cell, back.rot, back.aristas])
	var old := item.to_dict()
	old.erase("rank")
	check(CraftedItem.from_dict(old, res).rank == 1, "un objeto sin rango (versión 1) es de rango I")


# ─── Tarea 6: desbloqueo por rango y guardado v3 ───────────────────────

func _dm() -> Node:
	return get_node("/root/DataManager")


func test_blueprint_tiers() -> void:
	var dm := _dm()
	check(dm.blueprint_tier(&"sword_masterwork") == Ranks.TIER_MASTER and dm.blueprint_tier(&"boots_basic") == Ranks.TIER_BASIC, "nivel de pieza de cada plano")
	for tier in Ranks.TIERS:
		check(dm.get_blueprint_ids_for_tier(tier).size() == 4, "4 planos de nivel %s" % tier)


func test_unlock_rank_only_goes_up() -> void:
	var dm := _dm()
	var saved: Dictionary = dm.unlocked_ranks.duplicate()
	dm.unlocked_ranks[&"sword_basic"] = 0
	check(not dm.is_blueprint_unlocked(&"sword_basic"), "rango 0 = bloqueado")
	check(dm.unlock_rank(&"sword_basic", 2) and dm.get_unlocked_rank(&"sword_basic") == 2, "sube a II")
	check(not dm.unlock_rank(&"sword_basic", 1) and dm.get_unlocked_rank(&"sword_basic") == 2, "no baja")
	for id in dm.get_blueprint_ids_for_tier(Ranks.TIER_BASIC):
		if id != &"sword_basic":
			dm.unlocked_ranks[id] = 1
	var newly: Array = dm.apply_milestones([{"rank": 2, "tier": Ranks.TIER_BASIC}])
	check(newly.size() == 3, "los otros 3 básicos suben a II (%s)" % [newly])
	dm.unlocked_ranks = saved


## Copias de la partida antigua que había antes de una prueba (ruta → bytes, o null si no había). Las pruebas de
## migración las crean al cargar una partida vieja; al acabar se dejan como estaban (TestSuite lo repite al final).
func _snapshot_backups() -> Dictionary:
	var out := {}
	for path in OLD_SAVE_BACKUPS:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out


func _restore_backups(snap: Dictionary) -> void:
	for path in snap:
		if snap[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(snap[path])
			f.close()


## Escribe `bytes` como save.json y lo carga, sin copias de la partida antigua delante (para ver la que hace esta carga).
func _load_save_bytes(bytes: PackedByteArray) -> bool:
	for path in OLD_SAVE_BACKUPS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_buffer(bytes)
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


func test_v1_save_with_high_record_migrates() -> void:
	var dm := _dm()
	var inv := _im()
	var backups := _snapshot_backups()
	var original := FileAccess.get_file_as_bytes("res://scripts/tests/fixtures/save_v1.json")
	check(_load_save_bytes(original), "la partida v1 carga")
	check(dm.get_unlocked_rank(&"sword_advanced") >= 1 and dm.get_unlocked_rank(&"sword_masterwork") >= 1, "lo ya desbloqueado se conserva")
	check(dm.get_unlocked_rank(&"helmet_basic") == 2, "el récord 57 aplica los básicos II (casco básico: %d)" % dm.get_unlocked_rank(&"helmet_basic"))
	check(dm.get_unlocked_rank(&"helmet_master") == 1, "el récord 57 aplica los maestros I")
	var items: Array = inv.get_crafted_items()
	check(items.size() == 1 and items[0].rank == 1 and items[0].calculated_stats.damage == 34, "la espada pasa a rango I con sus estadísticas")
	check(items.size() == 1 and items[0].place == InventoryManager.PLACE_HERO and inv.best_hero_item("main_hand") == items[0], "y la que estaba equipada va a la rejilla de Tico")
	check(FileAccess.file_exists(V1_BACKUP_PATH) and FileAccess.get_file_as_bytes(V1_BACKUP_PATH) == original, "la copia save.v1.bak.json guarda la partida original")
	check(not FileAccess.file_exists(V2_BACKUP_PATH), "y no hace la de la versión 2")
	check(SaveManager.save_game(), "se guarda en la versión nueva")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(int(data.version) == 3 and data.data.has("unlocked_ranks") and not data.data.has("unlocked_blueprints"), "guardado versión 3 con unlocked_ranks")
	await _reload_user_save()
	_restore_backups(backups)


## Partida de la versión 2 (la rejilla, antes de los rangos), con la forma que escriben InventoryManager.to_save_data() y
## DataManager: récord 25, una ampliación (rejilla de 5×4), una espada con una arista en Tico y un casco en el botín.
func _v2_save() -> Dictionary:
	var sword := CraftedItem.new(load("res://data/items/sword_advanced.tres"), 0.8).to_dict()
	sword.merge({"place": "hero", "x": 2, "y": 1, "rot": 0, "aristas": [[1, 1]], "timestamp": 2001}, true)
	var helmet := CraftedItem.new(load("res://data/items/helmet_basic.tres"), 0.4).to_dict()
	helmet.merge({"place": "loot", "timestamp": 2002}, true)
	return {
		"version": 2,
		"timestamp": 1790000000.0,
		"game": {"current_enemy_level": 24, "best_enemy_level": 25, "wall_room": 0, "room_locked": false, "death_count": 1, "enemies_defeated": {}, "hero_loadout": {}},
		"data": {"unlocked_blueprints": {"sword_basic": true, "shield_basic": true, "boots_basic": true, "helmet_basic": false, "sword_advanced": true}},
		"inventory": {
			"materials": {"iron": 40, "gold": 120},
			"crafted_items": [helmet, sword],
			"hero_grid": [5, 4],
			"expansions": ["grid_bone_straps"],
			"consumables": [],
		},
		"requests": {"free_requests_remaining": 0},
	}


func test_v2_save_migrates_to_v3() -> void:
	var dm := _dm()
	var inv := _im()
	var backups := _snapshot_backups()
	var original := JSON.stringify(_v2_save()).to_utf8_buffer()
	check(_load_save_bytes(original), "la partida v2 carga")
	check(inv.hero_grid_size() == Vector2i(5, 4) and inv.get_crafted_items().size() == 2, "rejilla de 5×4 y las dos piezas (%s, %d)" % [inv.hero_grid_size(), inv.get_crafted_items().size()])
	var sword: CraftedItem = inv.best_hero_item("main_hand")
	check(sword != null and sword.cell == Vector2i(2, 1) and sword.rot == 0 and sword.aristas == [Vector2i(1, 1)], "la espada sigue en Tico, en su casilla, con su arista")
	check(inv.get_loot().size() == 1 and inv.get_loot()[0].item_resource.item_id == &"helmet_basic", "el casco sigue en el botín")
	check(inv.get_crafted_items().all(func(it): return it.rank == 1), "las piezas siguen en rango I")
	check(dm.get_unlocked_rank(&"sword_advanced") == 1 and dm.get_unlocked_rank(&"shield_basic") == 1, "los planos desbloqueados pasan a rango I")
	check(dm.get_unlocked_rank(&"helmet_basic") == 1, "los básicos I, siempre")
	check(dm.get_unlocked_rank(&"helmet_advanced") == 1 and dm.get_unlocked_rank(&"helmet_master") == 0, "récord 25: los avanzados I sí (jefe 20) y los maestros aún no (%d, %d)" % [dm.get_unlocked_rank(&"helmet_advanced"), dm.get_unlocked_rank(&"helmet_master")])
	check(FileAccess.file_exists(V2_BACKUP_PATH) and FileAccess.get_file_as_bytes(V2_BACKUP_PATH) == original, "la copia save.v2.bak.json guarda la partida original")
	check(not FileAccess.file_exists(V1_BACKUP_PATH), "y no hace la de la versión 1")
	check(SaveManager.save_game(), "se guarda")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(int(data.version) == 3 and data.data.has("unlocked_ranks") and data.inventory.has("hero_grid"), "versión 3, con unlocked_ranks y la rejilla")
	await _reload_user_save()
	_restore_backups(backups)


# ─── Tarea 7: hitos al vencer jefes ────────────────────────────────────

func test_boss_milestones_unlock_once_with_signals() -> void:
	var gm := get_node("/root/GameManager")
	var dm := _dm()
	var saved_ranks: Dictionary = dm.unlocked_ranks.duplicate()
	var saved_state: int = gm.dungeon_state
	var saved_best: int = gm.best_enemy_level
	var saved_defeated: Dictionary = gm.enemies_defeated.duplicate()
	for id in dm.unlocked_ranks:
		dm.unlocked_ranks[id] = 0
	dm.apply_milestones([{"rank": 1, "tier": Ranks.TIER_BASIC}])
	gm.dungeon_state = gm.DungeonState.RUNNING
	gm.best_enemy_level = 999  # récord ya pasado: los jefes 20 y 40 no amplían la rejilla de la partida (GridExpansions)
	var milestones := []
	var unlocked := []
	var on_ms := func(rank, tier, ids): milestones.append([rank, tier, ids.size()])
	var on_bp := func(id, rank): unlocked.append([id, rank, milestones.size()])
	gm.blueprints_milestone.connect(on_ms)
	gm.blueprint_unlocked.connect(on_bp)
	gm.register_enemy_defeat(19)
	check(milestones.is_empty() and unlocked.is_empty(), "una sala normal no desbloquea nada")
	gm.register_enemy_defeat(20)
	check(milestones == [[1, Ranks.TIER_ADVANCED, 4]], "el jefe 20 da los 4 avanzados I (%s)" % [milestones])
	check(unlocked.size() == 4 and unlocked.all(func(u): return u[2] == 1), "4 planos, anunciados después del hito")
	gm.register_enemy_defeat(20)
	check(milestones.size() == 1 and unlocked.size() == 4, "volver a vencerlo no repite nada")
	gm.register_enemy_defeat(50)
	check(milestones.back() == [2, Ranks.TIER_BASIC, 4] and dm.get_unlocked_rank(&"sword_basic") == 2, "el jefe 50 abre los básicos II")
	gm.blueprints_milestone.disconnect(on_ms)
	gm.blueprint_unlocked.disconnect(on_bp)
	gm.dungeon_state = saved_state
	gm.best_enemy_level = saved_best
	gm.enemies_defeated = saved_defeated
	dm.unlocked_ranks = saved_ranks


## La ampliación provisional de la rejilla sigue detrás de los hitos: el jefe 20 da a la vez su hito y, la primera vez,
## su ampliación.
func test_boss_20_gives_its_milestone_and_its_grid_expansion() -> void:
	var gm := get_node("/root/GameManager")
	var dm := _dm()
	var saved_inv := _fresh_inventory()
	var saved_ranks: Dictionary = dm.unlocked_ranks.duplicate()
	var saved_state: int = gm.dungeon_state
	var saved_best: int = gm.best_enemy_level
	var saved_defeated: Dictionary = gm.enemies_defeated.duplicate()
	for id in dm.get_blueprint_ids_for_tier(Ranks.TIER_ADVANCED):
		dm.unlocked_ranks[id] = 0
	gm.dungeon_state = gm.DungeonState.RUNNING
	gm.best_enemy_level = 20  # la primera vez que cae el jefe 20
	var events := []
	var on_ms := func(_rank, _tier, _ids): events.append(&"milestone")
	var on_grid := func(_id): events.append(&"grid")
	gm.blueprints_milestone.connect(on_ms)
	gm.grid_expanded.connect(on_grid)
	gm.register_enemy_defeat(20)
	check(events == [&"milestone", &"grid"], "el jefe 20 da el hito y después la ampliación (%s)" % [events])
	check(_im().hero_grid_size() == GridExpansions.size_after(1), "la rejilla crece (%s)" % _im().hero_grid_size())
	gm.blueprints_milestone.disconnect(on_ms)
	gm.grid_expanded.disconnect(on_grid)
	gm.dungeon_state = saved_state
	gm.best_enemy_level = saved_best
	gm.enemies_defeated = saved_defeated
	dm.unlocked_ranks = saved_ranks
	await _restore_inventory(saved_inv)


func test_milestone_shows_one_notice_and_staggers_scrolls() -> void:
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	await get_tree().process_frame
	var scrolls := []
	corridor.loot_dropped.connect(func(kind, _pos, _payload): if kind == &"blueprint": scrolls.append(Time.get_ticks_msec()))
	var fx: Node = corridor.fx
	var count_texts := func() -> int: return fx._parts.filter(func(p): return p.kind == fx.Kind.TEXT).size()
	var texts_before: int = count_texts.call()
	corridor._on_blueprints_milestone(2, Ranks.TIER_ADVANCED, [&"sword_advanced", &"shield_advanced", &"helmet_advanced", &"boots_advanced"])
	for id in [&"sword_advanced", &"shield_advanced", &"helmet_advanced", &"boots_advanced"]:
		corridor._on_blueprint_unlocked(id, 2)
	check(count_texts.call() == texts_before, "sin un texto flotante por plano (el aviso es el cartel del HUD)")
	await get_tree().create_timer(0.8).timeout
	check(scrolls.size() == 4, "salen los 4 pergaminos (%d)" % scrolls.size())
	check(scrolls.size() == 4 and scrolls[3] - scrolls[0] >= 250, "escalonados, no a la vez (%s ms)" % (scrolls[3] - scrolls[0] if scrolls.size() == 4 else -1))
	corridor.queue_free()
	await get_tree().process_frame


# ─── Tarea 8: pedidos y crafteo por rango ──────────────────────────────

func test_request_rank_is_mostly_the_highest() -> void:
	var rm := get_node("/root/RequestsManager")
	var dm := _dm()
	var saved: Dictionary = dm.unlocked_ranks.duplicate()
	dm.unlocked_ranks[&"sword_basic"] = 3
	rm.rng.seed = 12345
	var counts := {1: 0, 2: 0, 3: 0}
	for i in 1000:
		counts[rm.make_request(&"sword_basic").rank] += 1
	check(counts[3] > 750 and counts[3] < 850 and counts[2] > 150 and counts[1] == 0, "80 %% rango III, 20 %% rango II (%s)" % [counts])
	dm.unlocked_ranks[&"sword_basic"] = 1
	check(rm.make_request(&"sword_basic").rank == 1, "con solo el rango I, siempre I")
	dm.unlocked_ranks = saved


func test_request_carries_recipe_and_gold_of_its_rank() -> void:
	var rm := get_node("/root/RequestsManager")
	var dm := _dm()
	var saved: Dictionary = dm.unlocked_ranks.duplicate()
	dm.unlocked_ranks[&"sword_masterwork"] = 2
	rm.rng.seed = 1
	var req: Dictionary = rm.make_request(&"sword_masterwork")
	while req.rank != 2:
		req = rm.make_request(&"sword_masterwork")
	var bp: BlueprintResource = dm.get_blueprint(&"sword_masterwork")
	check(req.materials == Ranks.recipe(bp.materials, Ranks.TIER_MASTER, 2), "el pedido lleva la receta de su rango")
	dm.unlocked_ranks[&"sword_masterwork"] = 1
	var req1: Dictionary = rm.make_request(&"sword_masterwork")
	check(req.gold_reward == roundi(req1.gold_reward * Ranks.gold_mult(2)), "el oro crece con el rango (%d y %d)" % [req1.gold_reward, req.gold_reward])
	dm.unlocked_ranks = saved


func test_visible_request_keeps_its_rank() -> void:
	var rm := get_node("/root/RequestsManager")
	var dm := _dm()
	var saved: Dictionary = dm.unlocked_ranks.duplicate()
	dm.unlocked_ranks[&"shield_basic"] = 1
	var req: Dictionary = rm.make_request(&"shield_basic")
	var before := req.duplicate()
	dm.unlock_rank(&"shield_basic", 2)
	check(req.rank == before.rank and req.materials == before.materials and req.gold_reward == before.gold_reward, "un pedido ya creado no cambia al subir de rango")
	dm.unlocked_ranks = saved


func test_crafting_a_rank_makes_an_item_of_that_rank() -> void:
	var cm := get_node("/root/CraftingManager")
	var inv := get_node("/root/InventoryManager")
	var items_before: int = inv.get_crafted_items().size()
	var queue_before: Array = cm.queue.duplicate()  # _finalize_task vacía su hueco y compacta la cola
	for i in cm.MAX_SLOTS:
		cm.queue[i] = null
	check(cm.enqueue(&"helmet_basic", 100, 3), "se encola el casco básico III")
	var task = null
	for t in cm.queue:
		if t != null and t.blueprint.blueprint_id == &"helmet_basic" and t.rank == 3:
			task = t
	check(task != null, "la tarea guarda el rango")
	if task:
		var gold_before: int = inv.get_quantity(&"gold")
		var result: Dictionary = cm._finalize_task(task)
		var item: CraftedItem = result.crafted_item
		var paid: int = inv.get_quantity(&"gold") - gold_before
		check(paid == int(result.gold_reward), "el cliente paga el oro del pedido al terminarlo (%d de %d)" % [paid, int(result.gold_reward)])
		inv.consume_materials({&"gold": paid})  # devuelve el oro de prueba
		check(result.rank == 3 and item.rank == 3, "el objeto sale de rango III")
		var base: Dictionary = item.item_resource.calculate_stats(item.quality)
		check(item.calculated_stats == Ranks.scale_stats(base, 3), "con las estadísticas del rango III (%s)" % [item.calculated_stats])
		check(item.place == InventoryManager.PLACE_LOOT and inv.get_loot()[0] == item, "y llega al botín, delante, como todo lo forjado")
		check(item.aristas.size() == PieceShape.aristas_for_tier(item.get_quality_tier()), "con sus aristas sorteadas (%d)" % item.aristas.size())
		check(result.gold_reward > 0 and not result.own_order, "un pedido sí da oro")
		check(inv.remove_crafted_item(item) and not (item in inv.get_loot()), "remove_crafted_item lo saca también del botín")
	check(inv.get_crafted_items().size() == items_before, "la prueba deja el inventario como estaba")
	cm.queue = queue_before


## La venta ya va por rango (CraftedItem.get_sell_price, que usan la tienda y el panel de Equipo). Esta prueba lo guarda.
func test_sell_price_grows_with_the_rank() -> void:
	var res: ItemResource = load("res://data/items/shield_basic.tres")
	var one := CraftedItem.new(res, 0.75)
	var two := CraftedItem.new(res, 0.75, 2)
	check(two.get_sell_price() == roundi(one.get_sell_price() * Ranks.gold_mult(2)) and two.get_sell_price() > one.get_sell_price(), "el precio de venta crece con el rango (%d y %d)" % [one.get_sell_price(), two.get_sell_price()])


# ─── Tarea 9: claves de dificultad ─────────────────────────────────────

## Claves que cada minijuego lee de verdad
const MINIGAME_KEYS := {
	"ForgeTemp.tscn": ["forge_speed", "precision"],
	"HammerMinigame.tscn": ["hammer_speed", "precision"],
	"SewOSU.tscn": ["stitch_speed", "precision"],
	"QuenchWater.tscn": ["quench_speed", "time_window"],
}


func test_every_trial_passes_the_keys_its_minigame_reads() -> void:
	var dm := _dm()
	var cm := get_node("/root/CraftingManager")
	for bp_id in dm.get_all_blueprints():
		var bp: BlueprintResource = dm.get_blueprint(bp_id)
		for trial in bp.trial_sequence:
			var config: TrialConfig = cm._resolve_trial_config(trial, bp)
			var scene_file: String = config.minigame_scene.resource_path.get_file() if config.minigame_scene else ""
			check(MINIGAME_KEYS.has(scene_file), "%s: minijuego conocido (%s)" % [bp_id, scene_file])
			for key in MINIGAME_KEYS.get(scene_file, []):
				check(config.parameters.has(key), "%s / %s: %s lee «%s» y el plano no lo pasa" % [bp_id, trial.trial_id, scene_file, key])


func test_boots_sewing_gets_harder_with_the_tier() -> void:
	var dm := _dm()
	var cm := get_node("/root/CraftingManager")
	var p := {}
	for id in [&"boots_basic", &"boots_advanced", &"boots_master"]:
		var bp: BlueprintResource = dm.get_blueprint(id)
		for trial in bp.trial_sequence:
			var config: TrialConfig = cm._resolve_trial_config(trial, bp)
			if config.minigame_scene and config.minigame_scene.resource_path.ends_with("SewOSU.tscn"):
				p[id] = config.parameters
	check(p.size() == 3, "las tres botas se cosen")
	if p.size() == 3:
		check(p[&"boots_basic"].stitch_speed < p[&"boots_advanced"].stitch_speed and p[&"boots_advanced"].stitch_speed < p[&"boots_master"].stitch_speed, "la aguja va más rápida del básico al maestro")
		check(p[&"boots_basic"].precision > p[&"boots_advanced"].precision and p[&"boots_advanced"].precision > p[&"boots_master"].precision, "las ventanas se estrechan del básico al maestro")


func test_forge_reads_precision() -> void:
	var forge = load("res://scenes/Minigames/ForgeTemp.tscn").instantiate()
	add_child(forge)
	await get_tree().process_frame
	var config := TrialConfig.new()
	config.parameters = {"forge_speed": 1.0, "precision": 0.7, "trials": 3}
	forge.start_trial(config)
	check(is_equal_approx(forge._tolerance, lerpf(0.25, 0.08, 0.7)), "la forja estrecha su ventana con la precisión del plano (%.3f)" % forge._tolerance)
	forge.queue_free()
	await get_tree().process_frame


# ─── Tarea 10: dificultad por rango ────────────────────────────────────

func _config(params: Dictionary) -> TrialConfig:
	var c := TrialConfig.new()
	c.parameters = params.duplicate()
	return c


func test_rank_one_leaves_trials_unchanged() -> void:
	var c := _config({"forge_speed": 1.0, "precision": 0.4})
	TrialDifficulty.apply(c, 1)
	check(c.parameters == {"forge_speed": 1.0, "precision": 0.4}, "el rango I no cambia nada")


func test_difficulty_grows_with_rank_and_respects_caps() -> void:
	var forge := _config({"forge_speed": 1.0, "precision": 0.4})
	TrialDifficulty.apply(forge, 3)
	check(is_equal_approx(forge.parameters.forge_speed, 1.21) and is_equal_approx(forge.parameters.precision, 0.52), "forja III: ×1,21 y +0,12 (%s)" % [forge.parameters])
	var hammer := _config({"hammer_speed": 110, "tempo_bpm": 110, "precision": 0.7})
	TrialDifficulty.apply(hammer, 20)
	check(hammer.parameters.hammer_speed == 160 and hammer.parameters.tempo_bpm == 160 and is_equal_approx(hammer.parameters.precision, 0.85), "martillo XX: topes 160 y 0,85")
	var sew := _config({"stitch_speed": 1.2, "precision": 0.3})
	TrialDifficulty.apply(sew, 4)
	check(sew.parameters.stitch_speed > 1.2 and is_equal_approx(sew.parameters.precision, 0.15), "coser IV: más rápido y ventanas menores (precisión 0,15)")
	TrialDifficulty.apply(sew, 20)
	check(sew.parameters.stitch_speed <= 1.6 and sew.parameters.precision >= 0.0, "coser: topes 1,6 y 0,0")
	var quench := _config({"quench_speed": 1.0, "time_window": 0.3})
	TrialDifficulty.apply(quench, 30)
	check(is_equal_approx(quench.parameters.time_window, 0.12) and quench.parameters.quench_speed <= 2.0, "temple: ventana mínima 0,12 y velocidad máxima 2")


func test_crafting_uses_the_task_rank() -> void:
	var dm := _dm()
	var cm := get_node("/root/CraftingManager")
	var bp: BlueprintResource = dm.get_blueprint(&"sword_basic")
	var c1: TrialConfig = cm._resolve_trial_config(bp.trial_sequence[0], bp, 1)
	var c3: TrialConfig = cm._resolve_trial_config(bp.trial_sequence[0], bp, 3)
	check(c3.parameters.forge_speed > c1.parameters.forge_speed, "la espada básica III se forja más rápido que la I")


# ─── Tarea 11: encargo propio ──────────────────────────────────────────

func test_own_order_never_charges_when_refused() -> void:
	var cm := get_node("/root/CraftingManager")
	var inv := get_node("/root/InventoryManager")
	var dm := _dm()
	var saved_ranks: Dictionary = dm.unlocked_ranks.duplicate()
	var saved_inv: Dictionary = inv.inventory.duplicate()
	var saved_queue: Array = cm.queue.duplicate()
	dm.unlocked_ranks[&"sword_basic"] = 1
	check(cm.place_own_order(&"sword_basic", 2) == &"locked" and inv.inventory == saved_inv, "un rango bloqueado no se encarga ni cobra")
	inv.inventory = {}
	check(cm.place_own_order(&"sword_basic", 1) == &"no_materials" and inv.inventory.is_empty(), "sin materiales no se encarga")
	var bp: BlueprintResource = dm.get_blueprint(&"sword_basic")
	var recipe := Ranks.recipe(bp.materials, Ranks.TIER_BASIC, 1)
	for mat_id in recipe:
		inv.add_item(mat_id, recipe[mat_id] * 10)
	var Task = cm.get_script().CraftingTask  # clase interna del autoload (no tiene class_name)
	for i in cm.MAX_SLOTS:
		cm.queue[i] = Task.new(9000 + i, bp, i)
	var before: Dictionary = inv.inventory.duplicate()
	check(cm.place_own_order(&"sword_basic", 1) == &"queue_full" and inv.inventory == before, "con la cola llena no cobra")
	cm.queue = saved_queue
	inv.inventory = saved_inv
	dm.unlocked_ranks = saved_ranks


func test_own_order_charges_recipe_and_gives_no_gold() -> void:
	var cm := get_node("/root/CraftingManager")
	var inv := get_node("/root/InventoryManager")
	var dm := _dm()
	var saved_ranks: Dictionary = dm.unlocked_ranks.duplicate()
	var saved_inv: Dictionary = inv.inventory.duplicate()
	var saved_queue: Array = cm.queue.duplicate()
	for i in cm.MAX_SLOTS:
		cm.queue[i] = null
	dm.unlocked_ranks[&"helmet_basic"] = 2
	var bp: BlueprintResource = dm.get_blueprint(&"helmet_basic")
	var recipe := Ranks.recipe(bp.materials, Ranks.TIER_BASIC, 2)
	inv.inventory = {}
	for mat_id in recipe:
		inv.add_item(mat_id, recipe[mat_id])
	check(cm.place_own_order(&"helmet_basic", 2) == &"", "se encarga el casco básico II")
	check(inv.inventory.is_empty(), "cobra exactamente la receta del rango II")
	var task = cm.queue[0]
	check(task != null and task.own_order and task.rank == 2, "la tarea es un encargo propio de rango II")
	if task:
		var result: Dictionary = cm._finalize_task(task)
		check(result.gold_reward == 0 and result.crafted_item.rank == 2, "no da oro y el objeto es de rango II")
		check(inv.get_quantity(&"gold") == 0, "y no entra oro en el inventario (%d)" % inv.get_quantity(&"gold"))
		inv.remove_crafted_item(result.crafted_item)
	cm.queue = saved_queue
	inv.inventory = saved_inv
	dm.unlocked_ranks = saved_ranks


func test_library_reject_twice_restores_the_name() -> void:
	var panel = load("res://scenes/UI/BlueprintLibraryPanel.tscn").instantiate()
	add_child(panel)
	panel.open()
	await get_tree().process_frame
	var card = panel._cards.get(&"sword_basic")
	check(card != null, "la biblioteca tiene la tarjeta de la espada básica")
	if card == null:
		panel.queue_free()
		return
	var name_before: String = card.name_label.text
	var x_before: float = card.position.x
	panel.reject(&"sword_basic", &"no_materials")
	await get_tree().create_timer(0.5).timeout
	panel.reject(&"sword_basic", &"queue_full")
	check(card.name_label.text != name_before, "el motivo se ve mientras dura el rechazo")
	await get_tree().create_timer(panel.REJECT_SECONDS + 0.4).timeout
	check(card.name_label.text == name_before, "tras pulsar dos veces, el nombre real vuelve")
	check(absf(card.position.x - x_before) < 0.01, "la tarjeta vuelve a su x de reposo")
	panel.queue_free()


func test_library_card_shows_the_selected_rank_cost() -> void:
	var dm := _dm()
	var saved_ranks: Dictionary = dm.unlocked_ranks.duplicate()
	dm.unlocked_ranks[&"helmet_basic"] = 3
	var bp: BlueprintResource = dm.get_blueprint(&"helmet_basic")
	var card = load("res://scenes/UI/BlueprintCard.tscn").instantiate()
	add_child(card)
	card.set_blueprint_data(&"helmet_basic", bp, true, 3)
	await get_tree().process_frame
	var tier: StringName = dm.blueprint_tier(&"helmet_basic")
	var first: Dictionary = Ranks.recipe(bp.materials, tier, 1)
	var third: Dictionary = Ranks.recipe(bp.materials, tier, 3)
	check(card.shown_recipe == third and card._cost_box.get_child_count() == third.size(), "la tarjeta abre en el rango más alto y enseña su receta")
	card.selected_rank = 1
	card._refresh_rank()
	await get_tree().process_frame
	check(card.shown_recipe == first and card.shown_recipe != third, "al bajar el rango cambia la receta que enseña la tarjeta")
	card.selected_rank = 3
	card._refresh_rank()
	await get_tree().process_frame
	check(card.shown_recipe == third and card.shown_recipe != first, "al volver al rango III vuelve su receta")
	var labels_ok: bool = card._cost_box.get_child_count() == third.size()
	var idx := 0
	for mat_id in third:
		if idx < card._cost_box.get_child_count():
			labels_ok = labels_ok and card._cost_box.get_child(idx).get_node("Qty").text == "x%d" % third[mat_id]
		idx += 1
	check(labels_ok, "las cantidades de la línea de coste son las de Ranks.recipe del rango III")
	check(card.tooltip_text.contains("x%d" % third[third.keys()[0]]), "el tooltip usa la receta del rango elegido")
	card.queue_free()
	var locked = load("res://scenes/UI/BlueprintCard.tscn").instantiate()
	add_child(locked)
	locked.set_blueprint_data(&"helmet_basic", bp, false, 0)
	await get_tree().process_frame
	check(locked._cost_box == null and locked.shown_recipe.is_empty(), "la tarjeta bloqueada no muestra coste")
	locked.queue_free()
	dm.unlocked_ranks = saved_ranks
