extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas de los rangos de plano por ciclo (spec doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md),
## solo desarrollo, sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn


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


func test_enemy_stats_match_the_current_curve() -> void:
	var skel := EnemyScaling.enemy_stats(1, EnemyArchetypes.get_data(&"skeleton"), false)
	check(skel.max_hp == 40 and is_equal_approx(skel.dmg, 11.75),
		"esqueleto de la sala 1: 40 de vida y 11,75 de daño (%d, %.2f)" % [skel.max_hp, skel.dmg])
	var boss10 := EnemyScaling.enemy_stats(10, EnemyArchetypes.get_data(&"boss"), true)
	check(boss10.max_hp == 214, "jefe de la sala 10: 214 de vida (%d)" % boss10.max_hp)
	check(absf(boss10.dmg - 69.5) < 0.1, "jefe de la sala 10: 69,5 de daño (%.2f)" % boss10.dmg)


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
