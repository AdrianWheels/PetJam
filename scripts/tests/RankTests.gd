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
