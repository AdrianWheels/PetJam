class_name GearGrid
extends RefCounted

## Una rejilla de equipo (la de Tico o la mochila) con sus piezas colocadas (spec del inventario en
## rejilla, apartado 3). Guarda la casilla y el giro de cada pieza por su cuenta, sin escribir en la
## pieza: InventoryManager se los copia al confirmar un movimiento, y las copias (duplicate_grid)
## sirven para la vista previa sin tocar nada de verdad.

var size: Vector2i
var items: Array[CraftedItem] = []
var _pos: Dictionary = {}  # CraftedItem → {"cell": Vector2i, "rot": int}
var _occ: Dictionary = {}  # Vector2i → CraftedItem (todas sus casillas, aristas incluidas)
var _clean_occ: Dictionary = {}  # Vector2i → CraftedItem (solo las casillas limpias)


func _init(grid_size: Vector2i) -> void:
	size = grid_size


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


## Casillas absolutas de `item` si su caja empezara en `cell` con el giro `rot`. Un giro negativo vale su equivalente
## en 0-3: PieceShape.of_item toma el giro de la pieza ante cualquier negativo.
func cells_at(item: CraftedItem, cell: Vector2i, rot: int) -> Dictionary:
	var fp := PieceShape.of_item(item, posmod(rot, 4))
	return {"clean": PieceShape.shift(fp.clean, cell), "aristas": PieceShape.shift(fp.aristas, cell)}


## Piezas (sin contar `item`) que pisaría `item` en esa casilla y giro.
func overlapping(item: CraftedItem, cell: Vector2i, rot: int) -> Array[CraftedItem]:
	var out: Array[CraftedItem] = []
	var cs := cells_at(item, cell, rot)
	for c in cs.clean + cs.aristas:
		var other: CraftedItem = _occ.get(c)
		if other != null and other != item and not (other in out):
			out.append(other)
	return out


## true si `item` cabe en esa casilla y giro: todo dentro y sin pisar piezas que no estén en `ignore`.
func fits(item: CraftedItem, cell: Vector2i, rot: int, ignore: Array = []) -> bool:
	var cs := cells_at(item, cell, rot)
	for c in cs.clean + cs.aristas:
		if not in_bounds(c):
			return false
		var other: CraftedItem = _occ.get(c)
		if other != null and other != item and not (other in ignore):
			return false
	return true


## Coloca `item` (si ya estaba, lo mueve). false si no cabe.
func place(item: CraftedItem, cell: Vector2i, rot: int) -> bool:
	if not fits(item, cell, rot, [item]):
		return false
	remove(item)
	var cs := cells_at(item, cell, rot)
	for c in cs.clean:
		_occ[c] = item
		_clean_occ[c] = item
	for c in cs.aristas:
		_occ[c] = item
	_pos[item] = {"cell": cell, "rot": posmod(rot, 4)}
	items.append(item)
	return true


func remove(item: CraftedItem) -> void:
	if not _pos.has(item):
		return
	for key in _occ.keys():
		if _occ[key] == item:
			_occ.erase(key)
	for key in _clean_occ.keys():
		if _clean_occ[key] == item:
			_clean_occ.erase(key)
	_pos.erase(item)
	items.erase(item)


func has(item: CraftedItem) -> bool:
	return _pos.has(item)


func cell_of(item: CraftedItem) -> Vector2i:
	return _pos[item].cell if _pos.has(item) else Vector2i(-1, -1)


func rot_of(item: CraftedItem) -> int:
	return int(_pos[item].rot) if _pos.has(item) else 0


func item_at(c: Vector2i) -> CraftedItem:
	return _occ.get(c)


func placed_clean_cells(item: CraftedItem) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _pos.has(item):
		out = cells_at(item, cell_of(item), rot_of(item)).clean
	return out


## Piezas que tocan por un lado alguna casilla limpia de `item` con una casilla limpia suya. Cada una,
## una vez.
func neighbors(item: CraftedItem) -> Array[CraftedItem]:
	var out: Array[CraftedItem] = []
	for c in placed_clean_cells(item):
		for d in PieceShape.SIDES:
			var other: CraftedItem = _clean_occ.get(c + d)
			if other != null and other != item and not (other in out):
				out.append(other)
	return out


## Hace crecer la rejilla (nunca encoge). Las piezas no se mueven.
func resize(new_size: Vector2i) -> void:
	size = Vector2i(maxi(size.x, new_size.x), maxi(size.y, new_size.y))


## Copia con las mismas piezas en los mismos sitios (para simular sin tocar esta).
func duplicate_grid() -> GearGrid:
	var g := GearGrid.new(size)
	for item in items:
		g.place(item, cell_of(item), rot_of(item))
	return g
