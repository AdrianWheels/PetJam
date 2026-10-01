extends RefCounted
## Enlace de PetJam con el arnés de Balanza (D:/Proyectos/Balanza; spec del kit, apartado 11.1).
## Escenario «duel» (spec de rangos, apartados 6 y 7): Tico entra con la vida llena en cada sala, de la 1 en adelante,
## contra el enemigo de esa sala, con el daño esperado por segundo de cada lado (CombatMath.expected_dps), la armadura
## y el tiempo hasta matar, sin azar. Métricas:
##   wall: la primera sala cuyo duelo pierde (para comprobar los objetivos);
##   progress: wall − 1 más la parte de la vida de ese enemigo que le quita (continua, para medir).
## Parámetros del conjunto: rank (rango de las piezas, que es también el rango del equipo) y quality.

## Hasta dónde se busca el muro: un equipo que no pierde antes tiene wall = MAX_ROOM + 1
const MAX_ROOM := 400
## Estadísticas que el juego guarda como enteros (ItemResource.calculate_stats las redondea con roundi)
const INT_STATS := ["damage", "str", "agi", "int", "hp", "armor"]


func scenarios() -> Array:
	return ["duel"]


func capabilities() -> Dictionary:
	return {"stochastic": false, "ablation": false}


func measure_metric(_scenario: String) -> String:
	return "progress"


## Palancas de la calibración (en sweep, game.<nombre>). Son static var del juego: un valor dura hasta que el arnés pone
## otro o termina la ejecución.
func set_param(name: String, value: float) -> void:
	match name:
		"exp":
			EnemyScaling.EXP = value
		"step":
			EnemyScaling.STEP = value
		"boss":
			EnemyScaling.BOSS_MULT = value
		"armor_k":
			CombatMath.ARMOR_K = value
		"rank_bonus":
			Ranks.RANK_POWER_BONUS = value
		_:
			push_error("palanca desconocida «%s»: usa exp, step, boss, armor_k o rank_bonus" % name)


func evaluate(build: Dictionary, _scenario: String, _seed_value: int) -> Dictionary:
	# Todas las piezas del conjunto son del rango del parámetro; el del equipo lo da la regla del juego
	var rank := int(build.params.get("rank", 1))
	var piece_ranks := []
	for item in build.items:
		if not item.get("virtual", false):
			piece_ranks.append(rank)
	return wall_of(CombatMath.hero_stats(gear_totals(build.items, rank), Ranks.team_rank(piece_ranks)))


## Totales del equipo, como InventoryManager.calculate_total_stats: cada objeto redondeado como
## ItemResource.calculate_stats y con su rango como Ranks.scale_stats. Los objetos virtuales que añade el arnés (+δ de
## una estadística al medir) se suman tal cual, sin redondeo ni rango.
static func gear_totals(items: Array, rank: int) -> Dictionary:
	var totals := {"damage": 0.0, "str": 0.0, "agi": 0.0, "int": 0.0, "hp": 0.0, "armor": 0.0, "crit": 0.0, "aps": 0.0}
	for item in items:
		var virtual: bool = item.get("virtual", false)
		var stats := {}
		for key in item.stats:
			stats[key] = float(item.stats[key])
			if not virtual and key in INT_STATS:
				stats[key] = roundi(float(item.stats[key]))
		if not virtual:
			stats = Ranks.scale_stats(stats, rank)
		for key in stats:
			if totals.has(key):
				totals[key] += float(stats[key])
	return totals


## Muro de un Tico: la primera sala cuyo duelo pierde, y el progreso continuo hasta él.
static func wall_of(hero: Dictionary) -> Dictionary:
	var hero_dps := CombatMath.expected_dps(hero)
	for room in range(1, MAX_ROOM + 1):
		var d := duel(hero, hero_dps, room)
		if not d.won:
			return {"wall": float(room), "progress": room - 1 + float(d.fraction)}
	return {"wall": float(MAX_ROOM + 1), "progress": float(MAX_ROOM)}


## Un duelo con la vida llena contra el enemigo de `room`: gana si lo mata antes de que su daño acabe con la vida de
## Tico (un empate lo pierde). `fraction` es la parte de la vida del enemigo que le quita (1 si gana).
static func duel(hero: Dictionary, hero_dps: float, room: int) -> Dictionary:
	var boss := Biomes.is_boss_room(room)
	var arch := EnemyArchetypes.get_data(&"boss" if boss else EnemyArchetypes.pick_for_room(room))
	var enemy := EnemyScaling.enemy_stats(room, arch, boss)
	var time_to_kill: float = float(enemy.max_hp) / maxf(hero_dps, 0.001)
	var incoming := CombatMath.expected_dps(enemy, CombatMath.armor_mitigation(int(hero.armor), room))
	var time_to_die: float = float(hero.max_hp) / maxf(incoming, 0.001)
	if time_to_kill < time_to_die:
		return {"won": true, "fraction": 1.0}
	return {"won": false, "fraction": time_to_die / time_to_kill}
