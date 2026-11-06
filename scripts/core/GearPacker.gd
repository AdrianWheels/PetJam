class_name GearPacker
extends RefCounted

## Colocación automática (spec del inventario en rejilla, apartados 6 y 10). En el juego no se coloca
## nada solo: esto lo usan la migración de partidas antiguas, BalanceSim y el botón «A la mochila» de la
## ficha completa (lo pide el jugador y aquí se busca el sitio). Determinista: prueba los giros 0 a 3 y
## las casillas de arriba abajo y de izquierda a derecha, primero las que tocan la zona de la pieza y
## después cualquiera.

## Primer sitio libre para `item`: {"cell": Vector2i, "rot": int}, o {} si no cabe en ninguno.
static func find_spot(grid: GearGrid, item: CraftedItem, prefer_zone: bool = true) -> Dictionary:
	var passes := [true, false] if prefer_zone else [false]
	for zone_only in passes:
		for rot in 4:
			for y in grid.size.y:
				for x in grid.size.x:
					var cell := Vector2i(x, y)
					if not grid.fits(item, cell, rot, [item]):
						continue
					if zone_only and not _touches_zone(grid, item, cell, rot):
						continue
					return {"cell": cell, "rot": rot}
	return {}


static func _touches_zone(grid: GearGrid, item: CraftedItem, cell: Vector2i, rot: int) -> bool:
	var zone: StringName = GearAuras.ZONES.get(item.get_equipment_slot(), &"")
	for c in grid.cells_at(item, cell, rot).clean:
		if GearAuras.cell_in_zone(c, zone, grid.size):
			return true
	return false


## Coloca las piezas en el orden dado donde quepan, sin mover las que ya hay. Devuelve las que no caben.
static func pack(grid: GearGrid, items: Array, prefer_zone: bool = true) -> Array:
	var left := []
	for item in items:
		var spot := find_spot(grid, item, prefer_zone)
		if spot.is_empty() or not grid.place(item, spot.cell, spot.rot):
			left.append(item)
	return left
