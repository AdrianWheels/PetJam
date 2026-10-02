extends RefCounted
## Enlace de PetJam con el arnés de Balanza (D:/Proyectos/Balanza; spec del kit, apartado 11.1).
## Escenario «duel» (spec de rangos, apartados 6 y 7): Tico entra con la vida llena en cada sala, de la 1 en adelante,
## contra el enemigo de esa sala, con el daño esperado por segundo de cada lado (CombatMath.expected_dps), la armadura
## y el tiempo hasta matar, sin azar. Métricas:
##   wall: la primera sala cuyo duelo pierde (para comprobar los objetivos);
##   progress: para medir, la sala con decimales en la que deja de ganar a un esqueleto de la curva (progress_of).
##   Es continuo y no tiene los escalones de los jefes, en los que caían las medidas. El anterior, wall − 1 más la
##   parte de la vida del enemigo del muro, saltaba casi una sala cada vez que ganaba otra.
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


## Muro de un Tico (la primera sala cuyo duelo pierde) y su progreso (progress_of).
static func wall_of(hero: Dictionary) -> Dictionary:
	var hero_dps := CombatMath.expected_dps(hero)
	var wall := MAX_ROOM + 1
	for room in range(1, MAX_ROOM + 1):
		if not duel(hero, hero_dps, room).won:
			wall = room
			break
	return {"wall": float(wall), "progress": progress_of(hero, hero_dps)}


## Progreso para medir: la sala, con decimales, en la que Tico deja de ganar a un esqueleto de la curva (sin jefes ni
## otros arquetipos). Es continuo y sin escalones: con los jefes del muro, ganar a un jefe regala de golpe las salas
## siguientes, que son más fáciles, y una medida que cae en ese tramo da valores falsos. Hasta MAX_ROOM.
static func progress_of(hero: Dictionary, hero_dps: float) -> float:
	var skeleton := EnemyArchetypes.get_data(&"skeleton")
	# La sala ganada más justa (la de menor margen; con empate, la última): de ella parte el progreso
	var tight_room := 0
	var tight_margin := INF
	for room in range(1, MAX_ROOM + 1):
		var d := duel_against(hero, hero_dps, EnemyScaling.enemy_stats(room, skeleton, false), room)
		if not d.won:
			return progress_between(tight_room, tight_margin, room, d.margin)
		if d.margin <= tight_margin:
			tight_room = room
			tight_margin = d.margin
	return float(MAX_ROOM)


## Progreso continuo hasta la sala perdida `lost_room` (margen `lost_margin` ≤ 1) desde la sala ganada más justa,
## `tight_room` (margen `tight_margin` > 1; 0 si no ganó ninguna). Interpola con el logaritmo de los márgenes: vale
## `tight_room` justo al ganarla y llega a `lost_room` cuando ese duelo se empata, así que no salta al ganar una sala más.
## Sin salas ganadas, es el margen de la sala 1.
static func progress_between(tight_room: int, tight_margin: float, lost_room: int, lost_margin: float) -> float:
	if tight_room == 0:
		return lost_margin
	var won := log(tight_margin)
	var lost := log(maxf(lost_margin, 1e-12))
	return tight_room + (lost_room - tight_room) * won / (won - lost)


## Un duelo con la vida llena contra el enemigo de `room` (Biomes y EnemyArchetypes deciden cuál).
static func duel(hero: Dictionary, hero_dps: float, room: int) -> Dictionary:
	var boss := Biomes.is_boss_room(room)
	var arch := EnemyArchetypes.get_data(&"boss" if boss else EnemyArchetypes.pick_for_room(room))
	return duel_against(hero, hero_dps, EnemyScaling.enemy_stats(room, arch, boss), room)


## Un duelo con la vida llena contra `enemy` en la sala `room`: gana si lo mata antes de que su daño acabe con la vida
## de Tico (un empate lo pierde). `margin` es el tiempo hasta morir entre el tiempo hasta matar (gana si pasa de 1).
static func duel_against(hero: Dictionary, hero_dps: float, enemy: Dictionary, room: int) -> Dictionary:
	var time_to_kill: float = float(enemy.max_hp) / maxf(hero_dps, 0.001)
	var incoming := CombatMath.expected_dps(enemy, CombatMath.armor_mitigation(int(hero.armor), room))
	var time_to_die: float = float(hero.max_hp) / maxf(incoming, 0.001)
	return {"won": time_to_kill < time_to_die, "margin": time_to_die / time_to_kill}
