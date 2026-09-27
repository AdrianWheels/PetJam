class_name EnemyScaling
extends RefCounted

## Curva de dificultad de los enemigos (spec de rangos, apartado 6). Una sola fuente para Enemy y BalanceSim.
## escala(sala) = (1 + LIN·(sala−1)) · EXP^(sala−1). Los jefes, ×BOSS_MULT.
## Las constantes las fija la calibración con BalanceSim (tarea 3); de momento son las de siempre.

const LIN := 0.15
const EXP := 1.04
const BOSS_MULT := 1.6
const BASE_HP := 40
const BASE_DMG := 5.0
const BASE_APS := 0.8


static func exp_factor(level: int) -> float:
	return pow(EXP, maxi(1, level) - 1)


static func stat_scale(level: int) -> float:
	return (1.0 + LIN * (maxi(1, level) - 1)) * exp_factor(level)


## Multiplicador de jefe de una sala.
static func boss_mult(_level: int) -> float:
	return BOSS_MULT


## Estadísticas de un enemigo de la sala `level` con los multiplicadores de su arquetipo (EnemyArchetypes.DATA).
static func enemy_stats(level: int, archetype: Dictionary, is_boss: bool) -> Dictionary:
	var lv := maxi(1, level)
	var ef := exp_factor(lv)
	var mult := boss_mult(lv) if is_boss else 1.0
	var str_v := (3.0 + lv * 1.5) * ef
	var agi := (1.5 + lv * 0.8) * sqrt(ef)
	var intel := (1.5 + lv * 0.6) * sqrt(ef)
	return {
		"STR": str_v, "AGI": agi, "INT": intel,
		"max_hp": maxi(1, int(BASE_HP * stat_scale(lv) * mult * float(archetype.get("hp", 1.0)))),
		"dmg": (BASE_DMG + str_v * 1.5) * mult * float(archetype.get("dmg", 1.0)),
		"aps": clampf(BASE_APS + agi * 0.02, 0.3, 4.0) * float(archetype.get("aps", 1.0)),
		"crit_p": minf(0.5, agi * 0.006),
		"crit_m": clampf(1.5 + intel * 0.012, 1.0, 3.0),
	}
