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
	var expected := CombatMath.hero_stats(inv.calculate_total_stats())
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
