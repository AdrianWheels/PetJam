class_name Ranks
extends RefCounted

## Rangos de plano por ciclo (spec doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md).
## Un ciclo son los 5 biomas (50 salas); el ciclo N da los planos de rango N. El rango I es el de siempre.
## Hitos: los básicos de rango N al entrar en su ciclo (el rango I al empezar; los demás al vencer al
## último jefe del ciclo anterior), los avanzados al vencer al jefe +20 y los maestros al jefe +40.

const ROOMS_PER_CYCLE := 50
const ADVANCED_BOSS_OFFSET := 20
const MASTER_BOSS_OFFSET := 40
const MID_CYCLE_OFFSET := 25

const TIER_BASIC := &"basic"
const TIER_ADVANCED := &"advanced"
const TIER_MASTER := &"master"
const TIERS := [&"basic", &"advanced", &"master"]

## Estadísticas del objeto que escalan con el rango. Agilidad, inteligencia, crítico y velocidad de ataque
## no escalan: tienen tope en Tico (CombatMath.hero_stats).
const SCALED_STATS := ["damage", "hp", "str", "armor"]

## Material de cada bioma, en el orden de Biomes.LIST
const BIOME_MATERIALS := [&"bone", &"moss", &"obsidian", &"frost", &"void_shard"]
## Materiales de bioma que pide cada nivel de pieza (además de los de su plano)
const TIER_BIOME_MATERIALS := {
	&"basic": [&"bone"],
	&"advanced": [&"moss", &"obsidian"],
	&"master": [&"frost", &"void_shard"],
}
const BIOME_MATERIAL_BASE_QTY := 2

## Crecimiento de recetas, botín y oro por rango (spec: 1,6^(N−1))
const MAT_GROWTH := 1.6
## Ajuste del poder por rango sobre la curva de enemigos (lo fija la calibración de la tarea 3)
const RANK_POWER_BONUS := 1.0

## Texto del aviso de cada hito; %s es el numeral con espacio delante (" II") o nada en el rango I
const MILESTONE_TEXTS := {
	&"basic": "¡Planos básicos%s!",
	&"advanced": "¡Planos avanzados%s!",
	&"master": "¡Planos maestros%s!",
}


static func cycle_for_room(room: int) -> int:
	return floori(float(maxi(1, room) - 1) / ROOMS_PER_CYCLE) + 1


static func first_room_of_cycle(cycle: int) -> int:
	return ROOMS_PER_CYCLE * (maxi(1, cycle) - 1) + 1


static func mat_mult(rank: int) -> float:
	return pow(MAT_GROWTH, maxi(1, rank) - 1)


static func gold_mult(rank: int) -> float:
	return mat_mult(rank)


## Cuánto más fuerte es un objeto de rango N que el de rango I. Sigue a la curva de enemigos medida a
## mitad de ciclo, para que el rango N pese contra el ciclo N lo mismo que el I contra el I.
static func stat_mult(rank: int) -> float:
	var r := maxi(1, rank)
	if r == 1:
		return 1.0
	var mid_n := ROOMS_PER_CYCLE * (r - 1) + MID_CYCLE_OFFSET
	return EnemyScaling.stat_scale(mid_n) / EnemyScaling.stat_scale(MID_CYCLE_OFFSET) * pow(RANK_POWER_BONUS, r - 1)


## Aplica el rango a las estadísticas de un objeto (las de ItemResource.calculate_stats).
static func scale_stats(stats: Dictionary, rank: int) -> Dictionary:
	var out := stats.duplicate()
	if rank <= 1:
		return out
	var m := stat_mult(rank)
	for key in SCALED_STATS:
		if out.has(key):
			out[key] = roundi(float(out[key]) * m)
	return out


## Receta de un plano en un rango: sus materiales × mat_mult (hacia arriba) más los de su bioma.
static func recipe(base_materials: Dictionary, tier: StringName, rank: int) -> Dictionary:
	var m := mat_mult(rank)
	var out := {}
	for mat_id in base_materials:
		out[StringName(str(mat_id))] = ceili(float(base_materials[mat_id]) * m - 0.0001)
	for mat_id in TIER_BIOME_MATERIALS.get(tier, []):
		out[mat_id] = ceili(BIOME_MATERIAL_BASE_QTY * m - 0.0001)
	return out


## Hito que desbloquea vencer al jefe de `room`: {"rank": N, "tier": …}, o {} si esa sala no es un hito.
static func milestone_for_boss_room(room: int) -> Dictionary:
	if room <= 0:
		return {}
	var offset := room % ROOMS_PER_CYCLE
	var cycle := cycle_for_room(room)
	if offset == ADVANCED_BOSS_OFFSET:
		return {"rank": cycle, "tier": TIER_ADVANCED}
	if offset == MASTER_BOSS_OFFSET:
		return {"rank": cycle, "tier": TIER_MASTER}
	if offset == 0:
		return {"rank": cycle + 1, "tier": TIER_BASIC}  # el último jefe del ciclo abre el siguiente
	return {}


## Hitos ya superados con un récord (sala más profunda alcanzada): los básicos I siempre y cada
## jefe-hito de una sala menor que el récord (llegar a la sala X+1 implica haber vencido al jefe X).
static func milestones_up_to_record(record: int) -> Array:
	var out: Array = [{"rank": 1, "tier": TIER_BASIC}]
	var boss_room := Biomes.ROOMS_PER_BIOME
	while boss_room < record:
		var ms := milestone_for_boss_room(boss_room)
		if not ms.is_empty():
			out.append(ms)
		boss_room += Biomes.ROOMS_PER_BIOME
	return out


## Nivel de pieza desde ItemResource.rarity ("basic", "advanced", "master").
static func tier_from_rarity(rarity: String) -> StringName:
	match rarity:
		"advanced":
			return TIER_ADVANCED
		"master":
			return TIER_MASTER
	return TIER_BASIC


static func biome_material_for_room(room: int) -> StringName:
	return BIOME_MATERIALS[posmod(Biomes.biome_index_for_room(room), BIOME_MATERIALS.size())]


## "" en el rango I (no se muestra), "II", "III"… a partir del II.
static func numeral(rank: int) -> String:
	return "" if rank <= 1 else Biomes.roman(rank)


## " II" para añadir a un nombre, o "" en el rango I.
static func suffix(rank: int) -> String:
	return "" if rank <= 1 else " " + numeral(rank)


## Aviso de un hito ya traducido: "¡Planos avanzados II!".
static func milestone_text(rank: int, tier: StringName) -> String:
	return String(TranslationServer.translate(MILESTONE_TEXTS.get(tier, MILESTONE_TEXTS[TIER_BASIC]))) % suffix(rank)
