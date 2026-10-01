class_name EnemyScaling
extends RefCounted

## Curva de dificultad de los enemigos (spec de rangos, apartado 6). Una sola fuente para Enemy y para el enlace de
## Balanza (scripts/tests/BalanzaBinding.gd). Va en escalera: escala(sala) = STEP^(ciclo − 1) · EXP^(sala del ciclo − 1).
## Vida, daño y pulso siguen la escala; la agilidad y la inteligencia se quedan en las de la sala 1, así que el ritmo y
## el crítico no cambian. Los jefes, ×BOSS_MULT. EXP, STEP y BOSS_MULT son static var porque son las palancas de la
## calibración (balance/ con Balanza); sus valores los fija esa calibración.

static var EXP := 1.006
static var STEP := 8.0
static var BOSS_MULT := 1.6
const CYCLE_ROOMS := 50  # igual que Ranks.ROOMS_PER_CYCLE (Ranks depende de esta clase, no al revés)
const BASE_HP := 40
const DMG_AT_ROOM_1 := 11.75  # daño de un esqueleto en la sala 1 con la fórmula anterior
const BASE_APS := 0.8
## Agilidad e inteligencia de un enemigo de la sala 1 con la fórmula anterior (1,5 + 0,8 y 1,5 + 0,6)
const AGI_AT_ROOM_1 := 2.3
const INT_AT_ROOM_1 := 2.1


static func cycle_of(level: int) -> int:
	return floori(float(maxi(1, level) - 1) / CYCLE_ROOMS) + 1


## Salto del ciclo: STEP^(ciclo − 1). Es también el multiplicador de la base de Tico por rango (CombatMath.hero_stats).
static func cycle_mult(cycle: int) -> float:
	return pow(STEP, maxi(1, cycle) - 1)


static func stat_scale(level: int) -> float:
	var lv := maxi(1, level)
	return cycle_mult(cycle_of(lv)) * pow(EXP, (lv - 1) % CYCLE_ROOMS)


static func boss_mult(_level: int) -> float:
	return BOSS_MULT


## Estadísticas de un enemigo de la sala `level` con los multiplicadores de su arquetipo (EnemyArchetypes.DATA).
static func enemy_stats(level: int, archetype: Dictionary, is_boss: bool) -> Dictionary:
	var lv := maxi(1, level)
	var scale := stat_scale(lv)
	var mult := boss_mult(lv) if is_boss else 1.0
	return {
		"STR": 4.5 * scale, "AGI": AGI_AT_ROOM_1, "INT": INT_AT_ROOM_1 * scale,
		"max_hp": maxi(1, int(BASE_HP * scale * mult * float(archetype.get("hp", 1.0)))),
		"dmg": DMG_AT_ROOM_1 * scale * mult * float(archetype.get("dmg", 1.0)),
		"aps": clampf(BASE_APS + AGI_AT_ROOM_1 * 0.02, 0.3, 4.0) * float(archetype.get("aps", 1.0)),
		"crit_p": minf(0.5, AGI_AT_ROOM_1 * 0.006),
		"crit_m": clampf(1.5 + INT_AT_ROOM_1 * 0.012, 1.0, 3.0),
	}
