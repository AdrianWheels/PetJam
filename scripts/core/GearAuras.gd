class_name GearAuras
extends RefCounted

## Auras, zonas y tope de la rejilla de Tico (spec doc/specs/2026-09-27-inventario-en-rejilla.md,
## apartado 4). Sin nodos: lo usan InventoryManager (estadísticas de Tico y vista previa), el panel de
## Equipo (ficha y brillos) y BalanceSim. Los valores son de partida: los fija la calibración (tarea 16).

## Fuerza del aura según la calidad de quien la emite.
const AURA_BY_TIER := {"common": 0.0, "uncommon": 0.05, "rare": 0.10, "epic": 0.15, "legendary": 0.20}
const ZONE_BONUS := 0.10
const CAP := 0.5
const STATS := ["damage", "str", "agi", "int", "hp", "armor", "crit", "aps"]
const INT_STATS := ["damage", "str", "agi", "int", "hp", "armor"]
## Aura de cada tipo de pieza (por equipment_slot): estadística que sube y a qué vecinas.
const AURAS := {
	"main_hand": {"stat": "damage", "to": &"weapon"},
	"off_hand": {"stat": "armor", "to": &"armor"},
	"head": {"stat": "hp", "to": &"any"},
	"feet": {"stat": "aps", "to": &"weapon"},
}
## Borde donde rinde más cada tipo: la rejilla está delante de Tico, que mira a la derecha.
const ZONES := {"head": &"top", "feet": &"bottom", "off_hand": &"left", "main_hand": &"right"}
## Textos (base en español, se enseñan con tr()): %d es la fuerza en tanto por ciento.
const AURA_TEXTS := {
	"main_hand": "+%d %% de daño a las armas vecinas",
	"off_hand": "+%d %% de armadura a las armaduras vecinas",
	"head": "+%d %% de vida a todas las piezas vecinas",
	"feet": "+%d %% de velocidad de ataque a las armas vecinas",
}
const ZONE_TEXTS := {
	"head": "Rinde más en la fila de arriba",
	"feet": "Rinde más en la fila de abajo",
	"off_hand": "Rinde más en la columna izquierda",
	"main_hand": "Rinde más en la columna derecha",
}


static func kind(item: CraftedItem) -> StringName:
	return &"weapon" if item.get_equipment_slot() == "main_hand" else &"armor"


static func aura_strength(item: CraftedItem) -> float:
	return float(AURA_BY_TIER.get(item.get_quality_tier(), 0.0))


static func cell_in_zone(c: Vector2i, zone: StringName, size: Vector2i) -> bool:
	match zone:
		&"top":
			return c.y == 0
		&"bottom":
			return c.y == size.y - 1
		&"left":
			return c.x == 0
		&"right":
			return c.x == size.x - 1
	return false


## true si alguna casilla limpia de la pieza está en su zona.
static func in_zone(grid: GearGrid, item: CraftedItem) -> bool:
	var zone: StringName = ZONES.get(item.get_equipment_slot(), &"")
	for c in grid.placed_clean_cells(item):
		if cell_in_zone(c, zone, grid.size):
			return true
	return false


## Aumento de cada estadística de cada pieza de la rejilla, con el tope ya aplicado:
## pieza → {estadística: fracción}. Solo aparecen las estadísticas que suben.
static func bonuses(grid: GearGrid) -> Dictionary:
	var out := {}
	for item in grid.items:
		var pct := {}
		if in_zone(grid, item):
			for s in STATS:
				pct[s] = ZONE_BONUS
		out[item] = pct
	for emitter in grid.items:
		var strength := aura_strength(emitter)
		var aura: Dictionary = AURAS.get(emitter.get_equipment_slot(), {})
		if strength <= 0.0 or aura.is_empty():
			continue
		for receiver in grid.neighbors(emitter):
			if aura.to != &"any" and kind(receiver) != aura.to:
				continue
			var pct: Dictionary = out[receiver]
			pct[aura.stat] = float(pct.get(aura.stat, 0.0)) + strength
	for item in out:
		var pct: Dictionary = out[item]
		for s in pct.keys():
			pct[s] = minf(CAP, float(pct[s]))
	return out


## Estadísticas de una pieza con sus aumentos, sin redondear.
static func boosted_stats(item: CraftedItem, pct: Dictionary) -> Dictionary:
	var out := {}
	for s in STATS:
		out[s] = float(item.calculated_stats.get(s, 0)) * (1.0 + float(pct.get(s, 0.0)))
	return out


## Totales de la rejilla para Tico, con las claves de InventoryManager.calculate_total_stats(): las
## enteras redondeadas al final y crítico y velocidad con decimales.
static func totals(grid: GearGrid) -> Dictionary:
	var sum := {}
	for s in STATS:
		sum[s] = 0.0
	var b := bonuses(grid)
	for item in grid.items:
		var st := boosted_stats(item, b[item])
		for s in STATS:
			sum[s] += st[s]
	var out := {}
	for s in STATS:
		out[s] = roundi(sum[s]) if s in INT_STATS else sum[s]
	return out
