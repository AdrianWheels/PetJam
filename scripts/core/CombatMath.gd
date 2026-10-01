class_name CombatMath
extends RefCounted

## Fórmulas del combate sin nodos. Las usan Hero, Enemy y la simulación de balance (el enlace de Balanza),
## así que un cambio aquí cambia el juego y la simulación a la vez.

const HERO_BASE_HP := 60
const HERO_BASE_DMG := 6.0
const HERO_BASE_APS := 1.0
const HERO_BASE_STR := 10
const HERO_BASE_AGI := 10
const HERO_BASE_INT := 8
const PULSE_INTERVAL := 2.5
## Palanca de la calibración (static var: la barre el enlace de Balanza).
static var ARMOR_K := 60.0
const MAX_MITIGATION := 0.6


## Estadísticas de Tico a partir de los totales del equipo (InventoryManager.calculate_total_stats()) y del rango de su
## equipo (spec de rangos, apartado 6, «Base de Tico»): su base de vida, daño y pulso se multiplica por
## EnemyScaling.cycle_mult(rango). La fuerza y la inteligencia del equipo no se multiplican otra vez (Ranks.scale_stats
## ya escala la fuerza), y el multiplicador de crítico sale de la inteligencia sin multiplicar.
## `aps` es el ritmo sin efectos temporales (la Poción de Velocidad la aplica Hero encima).
static func hero_stats(equipment: Dictionary, team_rank: int = 1) -> Dictionary:
	var m := EnemyScaling.cycle_mult(team_rank)
	var eq_str := int(equipment.get("str", 0))
	var eq_int := int(equipment.get("int", 0))
	var str_v := HERO_BASE_STR + eq_str
	var agi := HERO_BASE_AGI + int(equipment.get("agi", 0))
	var intel := HERO_BASE_INT + eq_int
	return {
		"STR": str_v, "AGI": agi, "INT": roundi(HERO_BASE_INT * m) + eq_int,
		"max_hp": roundi((HERO_BASE_HP + HERO_BASE_STR * 10) * m) + eq_str * 10 + int(equipment.get("hp", 0)),
		"dmg": (HERO_BASE_DMG + HERO_BASE_STR * 1.5) * m + eq_str * 1.5 + float(equipment.get("damage", 0)),
		"aps": clampf(HERO_BASE_APS + agi * 0.02 + float(equipment.get("aps", 0.0)), 0.3, 5.0),
		"crit_p": clampf(agi * 0.005 + float(equipment.get("crit", 0.0)), 0.0, 0.75),
		"crit_m": clampf(1.5 + intel * 0.01, 1.0, 3.0),
		"armor": int(equipment.get("armor", 0)),
	}


## Fracción de daño físico que absorbe la armadura frente a un enemigo de la sala `enemy_level`
## (0..MAX_MITIGATION). La armadura se compara con la escala del enemigo: así sigue contando en los
## rangos altos, donde el equipo multiplica la armadura. En la sala 1 es la fórmula de siempre.
static func armor_mitigation(armor: int, enemy_level: int = 1) -> float:
	if armor <= 0:
		return 0.0
	var k := ARMOR_K * EnemyScaling.stat_scale(enemy_level)
	return minf(MAX_MITIGATION, float(armor) / (float(armor) + k))


## Daño por segundo esperado: golpes con el crítico medio, reducidos por la armadura del objetivo,
## más el pulso mágico (INT × 3 cada PULSE_INTERVAL), que la ignora.
static func expected_dps(stats: Dictionary, target_mitigation: float = 0.0) -> float:
	var hit: float = float(stats.dmg) * (1.0 + float(stats.crit_p) * (float(stats.crit_m) - 1.0))
	var pulse: float = float(stats.INT) * 3.0 / PULSE_INTERVAL
	return float(stats.aps) * hit * (1.0 - target_mitigation) + pulse
