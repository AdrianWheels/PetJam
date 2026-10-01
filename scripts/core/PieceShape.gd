class_name PieceShape
extends RefCounted

## Formas de las piezas en la rejilla de equipo (spec doc/specs/2026-09-27-inventario-en-rejilla.md,
## apartado 2). Casillas en (columna, fila), con la fila hacia abajo. Sin nodos: lo usan GearGrid,
## InventoryManager, las vistas y BalanceSim.

## Aristas que trae una pieza según su calidad (CraftedItem.get_quality_tier()).
const ARISTAS_BY_TIER := {"common": 2, "uncommon": 2, "rare": 1, "epic": 0, "legendary": 0}
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func aristas_for_tier(tier: String) -> int:
	return int(ARISTAS_BY_TIER.get(tier, 2))


## Gira unas casillas `rot` cuartos de vuelta en el sentido de las agujas del reloj: (x, y) → (−y, x).
## No las normaliza.
static func rotate_raw(cells: Array[Vector2i], rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		var p := c
		for i in posmod(rot, 4):
			p = Vector2i(-p.y, p.x)
		out.append(p)
	return out


static func shift(cells: Array[Vector2i], by: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(c + by)
	return out


## Casillas de la pieza girada, limpias y aristas por separado, relativas a su caja (esquina en 0,0):
## {"clean": Array[Vector2i], "aristas": Array[Vector2i], "size": Vector2i}.
static func footprint(clean: Array[Vector2i], aristas: Array[Vector2i], rot: int) -> Dictionary:
	var rc := rotate_raw(clean, rot)
	var ra := rotate_raw(aristas, rot)
	var all: Array[Vector2i] = []
	all.append_array(rc)
	all.append_array(ra)
	var lo := Vector2i(all[0].x, all[0].y)
	var hi := lo
	for c in all:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return {"clean": shift(rc, -lo), "aristas": shift(ra, -lo), "size": hi - lo + Vector2i.ONE}


## Caja de una pieza forjada con su giro, o con `rot` si se da.
static func of_item(item: CraftedItem, rot: int = -1) -> Dictionary:
	return footprint(item.item_resource.shape_cells, item.aristas, item.rot if rot < 0 else rot)


## Sortea sin repetir las aristas de una pieza de calidad `tier` entre sus sitios posibles.
static func roll_aristas(res: ItemResource, tier: String, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	spots.assign(res.arista_spots)
	var out: Array[Vector2i] = []
	for i in mini(aristas_for_tier(tier), spots.size()):
		var k := rng.randi_range(0, spots.size() - 1)
		out.append(spots[k])
		spots.remove_at(k)
	return out


## "" si la forma y los sitios de arista del recurso valen; si no, el motivo. Los sitios tienen que ser 3,
## distintos, fuera de la forma y pegados a ella por un lado.
static func check_resource(res: ItemResource) -> String:
	if res.shape_cells.is_empty():
		return "sin forma"
	if res.arista_spots.size() != 3:
		return "hacen falta 3 sitios de arista (%d)" % res.arista_spots.size()
	var seen := {}
	for s in res.arista_spots:
		if s in res.shape_cells:
			return "el sitio %s pisa la forma" % s
		if seen.has(s):
			return "el sitio %s está repetido" % s
		seen[s] = true
		var touches := false
		for d in SIDES:
			if (s + d) in res.shape_cells:
				touches = true
		if not touches:
			return "el sitio %s no toca la forma por un lado" % s
	return ""
