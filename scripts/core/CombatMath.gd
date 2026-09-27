class_name CombatMath
extends RefCounted

## Fórmulas del combate sin nodos. Las usan Hero, Enemy y la simulación de balance (BalanceSim),
## así que un cambio aquí cambia el juego y la simulación a la vez.

const HERO_BASE_HP := 60
const HERO_BASE_DMG := 6.0
const HERO_BASE_APS := 1.0
const HERO_BASE_STR := 10
const HERO_BASE_AGI := 10
const HERO_BASE_INT := 8
const PULSE_INTERVAL := 2.5
const ARMOR_K := 40.0
const MAX_MITIGATION := 0.6


## Estadísticas de Tico a partir de los totales del equipo (InventoryManager.calculate_total_stats()).
## `aps` es el ritmo sin efectos temporales (la Poción de Velocidad la aplica Hero encima).
static func hero_stats(equipment: Dictionary) -> Dictionary:
	var str_v := HERO_BASE_STR + int(equipment.get("str", 0))
	var agi := HERO_BASE_AGI + int(equipment.get("agi", 0))
	var intel := HERO_BASE_INT + int(equipment.get("int", 0))
	return {
		"STR": str_v, "AGI": agi, "INT": intel,
		"max_hp": HERO_BASE_HP + str_v * 10 + int(equipment.get("hp", 0)),
		"dmg": HERO_BASE_DMG + str_v * 1.5 + float(equipment.get("damage", 0)),
		"aps": clampf(HERO_BASE_APS + agi * 0.02 + float(equipment.get("aps", 0.0)), 0.3, 5.0),
		"crit_p": clampf(agi * 0.005 + float(equipment.get("crit", 0.0)), 0.0, 0.75),
		"crit_m": clampf(1.5 + intel * 0.01, 1.0, 3.0),
		"armor": int(equipment.get("armor", 0)),
	}


## Fracción de daño físico que absorbe la armadura (0..MAX_MITIGATION).
static func armor_mitigation(armor: int) -> float:
	if armor <= 0:
		return 0.0
	return minf(MAX_MITIGATION, float(armor) / (float(armor) + ARMOR_K))


## Daño por segundo esperado: golpes con el crítico medio, reducidos por la armadura del objetivo,
## más el pulso mágico (INT × 3 cada PULSE_INTERVAL), que la ignora.
static func expected_dps(stats: Dictionary, target_mitigation: float = 0.0) -> float:
	var hit: float = float(stats.dmg) * (1.0 + float(stats.crit_p) * (float(stats.crit_m) - 1.0))
	var pulse: float = float(stats.INT) * 3.0 / PULSE_INTERVAL
	return float(stats.aps) * hit * (1.0 - target_mitigation) + pulse
