extends Node
class_name InventoryManager

## Materiales y piezas forjadas. Cada pieza está siempre en uno de tres sitios (spec
## doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 3):
##  - la rejilla de Tico (hero_grid): lo único que cuenta para sus estadísticas;
##  - la mochila (bag_grid, 6×4 fija): guarda sin contar;
##  - el botín (loot): lista sin límite con lo más nuevo delante. Aquí llega todo lo forjado.
## Nada se coloca solo, salvo en la migración de partidas antiguas. Las reglas viven en PieceShape,
## GearGrid, GearAuras, LegendaryPowers, GearPacker y GridExpansions.

const _SaveManager = preload("res://scripts/core/SaveManager.gd")

signal inventory_changed(current_inventory)
signal crafted_items_changed(items_array)
signal equipment_changed(equipment_stats: Dictionary)  ## ha cambiado la rejilla de Tico
signal loot_changed(count: int)
signal grid_resized(size: Vector2i)

const PLACE_HERO := &"hero"
const PLACE_BAG := &"bag"
const PLACE_LOOT := &"loot"
const BAG_SIZE := Vector2i(6, 4)
const LEVEL_ORDER := {"basic": 0, "advanced": 1, "master": 2}

# Diccionario de materiales (StringName -> int)
var inventory: Dictionary = {}
## Todas las piezas forjadas, estén donde estén
var crafted_items: Array[CraftedItem] = []
var hero_grid: GearGrid = GearGrid.new(GridExpansions.START_SIZE)
var bag_grid: GearGrid = GearGrid.new(BAG_SIZE)
var loot: Array[CraftedItem] = []
## Recetas de ampliación ya forjadas: la rejilla de Tico mide GridExpansions.size_after(expansions.size())
var expansions: Array[StringName] = []

func _ready() -> void:
	"""Inicializa inventario. Si hay save, se cargará luego via load_save_data().
	Si no hay save, da materiales de inicio."""
	if not _SaveManager.has_save():
		_give_starting_materials()
	else:
		print("InventoryManager: Save detectado, esperando load_save_data()")

## Materiales generosos al inicio para evitar softlocks. Solo materiales que pide algún plano.
const STARTING_MATERIALS := {
	"wood": 40,
	"iron": 40,
	"leather": 40,
	"cloth": 40,
	"fire": 20,
	"water": 20,
}

func _give_starting_materials() -> void:
	for mat_id in STARTING_MATERIALS:
		add_item(StringName(mat_id), STARTING_MATERIALS[mat_id])
	print("InventoryManager: Inicializado con materiales de inicio")

func add_item(item_id: StringName, quantity: int) -> void:
		if quantity <= 0:
				return
		if item_id == StringName():
				return
		var key := item_id
		inventory[key] = inventory.get(key, 0) + quantity
		emit_signal("inventory_changed", inventory.duplicate())

func add_drops(drops: Array) -> void:
		for drop in drops:
				if drop == null or typeof(drop) != TYPE_DICTIONARY:
						continue
				var item_id: StringName = drop.get("item_id", StringName(""))
				var quantity: int = int(drop.get("quantity", 0))
				add_item(item_id, quantity)

func get_quantity(item_id: StringName) -> int:
		return inventory.get(item_id, 0)

func get_materials() -> Dictionary:
	return inventory.duplicate()

func has_materials(required_materials: Dictionary) -> bool:
	"""Verifica si el jugador tiene todos los materiales requeridos"""
	for mat_id in required_materials.keys():
		var required_qty: int = int(required_materials[mat_id])
		var current_qty: int = get_quantity(mat_id)
		if current_qty < required_qty:
			return false
	return true

func consume_materials(required_materials: Dictionary) -> bool:
	"""Consume materiales del inventario. Retorna true si tuvo éxito."""
	# Primero verificar que tenemos suficiente
	if not has_materials(required_materials):
		return false
	
	# Consumir
	for mat_id in required_materials.keys():
		var qty: int = int(required_materials[mat_id])
		var key: StringName = mat_id if mat_id is StringName else StringName(str(mat_id))
		inventory[key] = inventory.get(key, 0) - qty
		if inventory[key] <= 0:
			inventory.erase(key)
	
	emit_signal("inventory_changed", inventory.duplicate())
	return true

func clear() -> void:
	inventory.clear()
	crafted_items.clear()
	loot.clear()
	expansions.clear()
	hero_grid = GearGrid.new(GridExpansions.START_SIZE)
	bag_grid = GearGrid.new(BAG_SIZE)
	emit_signal("inventory_changed", inventory.duplicate())
	grid_resized.emit(hero_grid.size)
	_changed(true)

# ═══════════════════════════════════════════════════════════════════
#  PIEZAS
# ═══════════════════════════════════════════════════════════════════

## Lo recién forjado llega al botín, delante. Nada se coloca solo.
func add_crafted_item(item: CraftedItem) -> void:
	if item == null:
		push_warning("InventoryManager: Intentando añadir item null")
		return
	crafted_items.append(item)
	_put_in_loot(item, 0)
	_changed(false)
	print("InventoryManager: Pieza al botín: %s (calidad: %d%%)" % [item.get_display_name(), item.get_quality_percent()])


func get_crafted_items() -> Array[CraftedItem]:
	return crafted_items


func get_loot() -> Array[CraftedItem]:
	return loot


func get_loot_count() -> int:
	return loot.size()


func get_hero_items() -> Array[CraftedItem]:
	return hero_grid.items


func get_bag_items() -> Array[CraftedItem]:
	return bag_grid.items


## Lo que no lleva Tico (botín y mochila): lo que la tienda deja vender.
func get_unequipped_items() -> Array[CraftedItem]:
	var out: Array[CraftedItem] = []
	out.append_array(loot)
	out.append_array(bag_grid.items)
	return out


func grid_for(place: StringName) -> GearGrid:
	if place == PLACE_HERO:
		return hero_grid
	if place == PLACE_BAG:
		return bag_grid
	return null


func hero_grid_size() -> Vector2i:
	return hero_grid.size


## Qué pasaría al soltar `item` en `place` con esa casilla y giro: {"ok": bool, "swap": pieza o null}.
## En el botín siempre cabe. En una rejilla, en casillas libres, o encima de una sola pieza si cabe al
## quitarla (intercambio).
func drop_result(item: CraftedItem, place: StringName, cell: Vector2i = Vector2i.ZERO, rot: int = 0) -> Dictionary:
	if place == PLACE_LOOT:
		return {"ok": true, "swap": null}
	var grid := grid_for(place)
	if grid == null or item == null:
		return {"ok": false, "swap": null}
	var others := grid.overlapping(item, cell, rot)
	if others.is_empty():
		return {"ok": grid.fits(item, cell, rot, [item]), "swap": null}
	if others.size() == 1 and grid.fits(item, cell, rot, [item, others[0]]):
		return {"ok": true, "swap": others[0]}
	return {"ok": false, "swap": null}


## Mueve una pieza. Encima de una sola pieza se intercambian: la otra va al sitio de donde salió la
## primera (con su propio giro) si cabe allí; si no, al botín. true si se ha movido.
func move_item(item: CraftedItem, place: StringName, cell: Vector2i = Vector2i.ZERO, rot: int = 0) -> bool:
	if item == null or not (item in crafted_items):
		return false
	var res := drop_result(item, place, cell, rot)
	if not res.ok:
		return false
	var from_place := item.place
	var from_cell := item.cell
	var from_loot := loot.find(item)
	var other: CraftedItem = res.swap
	var hero_changed := from_place == PLACE_HERO or place == PLACE_HERO
	_take_out(item)
	if other:
		_take_out(other)
	_put(item, place, cell, rot)
	if other:
		if from_place == PLACE_LOOT or not _try_put(other, from_place, from_cell, other.rot):
			_put_in_loot(other, maxi(0, from_loot))
	_changed(hero_changed)
	return true


## Toque sobre una pieza de una rejilla: gira 90° sobre su centro, o sobre su esquina si así cabe.
## false si girada no cabe (el panel la hace temblar).
func rotate_in_place(item: CraftedItem) -> bool:
	var grid := grid_for(item.place)
	if grid == null:
		return false
	var new_rot := (item.rot + 1) % 4
	var old_size: Vector2i = PieceShape.of_item(item).size
	var new_size: Vector2i = PieceShape.of_item(item, new_rot).size
	@warning_ignore("integer_division")
	var centered := item.cell + Vector2i((old_size.x - new_size.x) / 2, (old_size.y - new_size.y) / 2)
	for cell in [centered, item.cell]:
		if grid.fits(item, cell, new_rot, [item]):
			grid.place(item, cell, new_rot)
			item.cell = cell
			item.rot = new_rot
			_changed(item.place == PLACE_HERO)
			return true
	return false


## Vende una pieza (esté donde esté) y suma su oro. Devuelve el oro (0 si no se vendió).
func sell_item(item: CraftedItem) -> int:
	if item == null or not (item in crafted_items):
		return 0
	var price := item.get_sell_price()
	remove_crafted_item(item)
	add_item(&"gold", price)
	return price


## Lo que vende "Vender todo": el botín salvo las Épicas y las Legendarias.
func sellable_loot() -> Array[CraftedItem]:
	var out: Array[CraftedItem] = []
	for item in loot:
		if not (item.get_quality_tier() in ["epic", "legendary"]):
			out.append(item)
	return out


## "Vender todo": vende sellable_loot() y devuelve el oro ganado.
func sell_all_loot() -> int:
	var gold := 0
	for item in sellable_loot():
		gold += item.get_sell_price()
		_take_out(item)
		crafted_items.erase(item)
	if gold > 0:
		add_item(&"gold", gold)
		_changed(false)
	return gold


## Quita una pieza del inventario (venta en la tienda, pruebas).
func remove_crafted_item(item: CraftedItem) -> bool:
	if item == null or not (item in crafted_items):
		return false
	var was_hero := item.place == PLACE_HERO
	_take_out(item)
	crafted_items.erase(item)
	_changed(was_hero)
	return true

# ═══════════════════════════════════════════════════════════════════
#  ESTADÍSTICAS DE TICO
# ═══════════════════════════════════════════════════════════════════

## Totales del equipo para Tico: las piezas de su rejilla con auras, zonas y tope (GearAuras).
func calculate_total_stats() -> Dictionary:
	return GearAuras.totals(hero_grid)


## Aumentos de cada pieza de Tico (pieza → {estadística: fracción}): ficha y brillos del panel.
func hero_bonuses() -> Dictionary:
	return GearAuras.bonuses(hero_grid)


## Habilidades legendarias que cuentan: las de las piezas legendarias de la rejilla de Tico.
func active_legendary_powers() -> Array[StringName]:
	return LegendaryPowers.active(hero_grid.items)


## La rejilla de Tico como quedaría tras soltar `item` ahí. Es una copia: no mueve nada.
func simulate_hero_grid(item: CraftedItem, place: StringName, cell: Vector2i, rot: int) -> GearGrid:
	var g := hero_grid.duplicate_grid()
	var res := drop_result(item, place, cell, rot)
	if not res.ok:
		return g
	var other: CraftedItem = res.swap
	g.remove(item)
	if place == PLACE_HERO:
		if other:
			g.remove(other)
		g.place(item, cell, rot)
	if other and item.place == PLACE_HERO:
		g.place(other, item.cell, other.rot)  # la otra vuelve al sitio de la primera, si cabe
	return g


## Estadísticas del equipo si `item` se soltara ahí (sin mover nada): vista previa del arrastre.
func preview_stats(item: CraftedItem, place: StringName, cell: Vector2i, rot: int) -> Dictionary:
	return GearAuras.totals(simulate_hero_grid(item, place, cell, rot))


## La mejor pieza de un tipo ("main_hand", "off_hand", "head" o "feet") en la rejilla de Tico: primero
## el rango, después el nivel y después la calidad. Es la que dibuja su sprite.
func best_hero_item(slot: String) -> CraftedItem:
	var best: CraftedItem = null
	for item in hero_grid.items:
		if item.get_equipment_slot() != slot:
			continue
		if best == null or gear_score(item) > gear_score(best):
			best = item
	return best


static func gear_score(item: CraftedItem) -> float:
	var level: int = LEVEL_ORDER.get(String(item.item_resource.rarity) if item.item_resource else "basic", 0)
	return float(item.rank) * 1000.0 + float(level) * 10.0 + item.quality


## Rango del equipo (spec de rangos, apartado 6, "Base de Tico"; spec del inventario, apartado 6): el
## menor rango entre las mejores piezas de cada tipo de la rejilla de Tico. Añadir una pieza de un tipo
## que ya lleva nunca lo baja. Sin piezas, rango I.
func equipment_rank() -> int:
	var rank := 0
	for slot in ["main_hand", "off_hand", "head", "feet"]:
		var best := best_hero_item(slot)
		if best:
			rank = best.rank if rank == 0 else mini(rank, best.rank)
	return maxi(1, rank)

# ═══════════════════════════════════════════════════════════════════
#  SITIOS (privado)
# ═══════════════════════════════════════════════════════════════════

## Saca una pieza de donde esté, sin avisar.
func _take_out(item: CraftedItem) -> void:
	hero_grid.remove(item)
	bag_grid.remove(item)
	loot.erase(item)


## Pone una pieza (ya fuera de todo sitio) en `place`. Si no cabe en la rejilla, al botín.
func _put(item: CraftedItem, place: StringName, cell: Vector2i, rot: int) -> void:
	if place == PLACE_LOOT or not _try_put(item, place, cell, rot):
		_put_in_loot(item, 0)


func _try_put(item: CraftedItem, place: StringName, cell: Vector2i, rot: int) -> bool:
	var grid := grid_for(place)
	if grid == null or not grid.place(item, cell, rot):
		return false
	item.place = place
	item.cell = cell
	item.rot = posmod(rot, 4)
	return true


func _put_in_loot(item: CraftedItem, index: int) -> void:
	loot.insert(clampi(index, 0, loot.size()), item)
	item.place = PLACE_LOOT


## Avisa de un cambio de piezas; si ha cambiado la rejilla de Tico, también de su equipo.
func _changed(hero_changed: bool) -> void:
	emit_signal("crafted_items_changed", crafted_items)
	loot_changed.emit(loot.size())
	if hero_changed:
		emit_signal("equipment_changed", calculate_total_stats())

# ═══════════════════════════════════════════════════════════════════
#  COMPATIBILIDAD PROVISIONAL (la quita la tarea 10, con el panel nuevo)
# ═══════════════════════════════════════════════════════════════════

## Equipa como el panel viejo: la pieza entra en el primer sitio libre de la rejilla de Tico.
func equip_item(item: CraftedItem) -> bool:
	if item == null or not (item in crafted_items) or item.place == PLACE_HERO:
		return false
	var spot := GearPacker.find_spot(hero_grid, item)
	return not spot.is_empty() and move_item(item, PLACE_HERO, spot.cell, spot.rot)


## Quita de Tico la mejor pieza de ese hueco antiguo y la manda al botín.
func unequip_item(slot: String) -> bool:
	var item := best_hero_item(slot)
	return item != null and move_item(item, PLACE_LOOT)


func get_equipped_item(slot: String) -> CraftedItem:
	return best_hero_item(slot)

# ═══════════════════════════════════════════════════════════════════
#  PERSISTENCIA
# ═══════════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	var mats := {}
	for mat_id in inventory:
		mats[String(mat_id)] = inventory[mat_id]
	# El botín primero y en su orden (lo más nuevo delante); después la rejilla de Tico y la mochila
	var ordered: Array[CraftedItem] = []
	ordered.append_array(loot)
	ordered.append_array(hero_grid.items)
	ordered.append_array(bag_grid.items)
	var items_arr: Array = []
	for item in ordered:
		items_arr.append(item.to_dict())
	return {
		"materials": mats,
		"crafted_items": items_arr,
		"hero_grid": [hero_grid.size.x, hero_grid.size.y],
		"expansions": expansions.map(func(id): return String(id)),
	}


## Carga el inventario. `record` es la sala máxima alcanzada de la misma partida
## (GameManager.best_enemy_level). En una partida anterior a la rejilla (sin "hero_grid"), la migra:
## da forjadas las ampliaciones de los jefes vencidos, sortea las aristas de cada pieza con una semilla
## fija, coloca lo que estaba equipado con GearPacker (las mejores primero) y manda el resto al botín.
## Nunca se pierde una pieza: una posición guardada imposible también acaba en el botín.
func load_save_data(data: Dictionary, record: int = 1) -> void:
	inventory.clear()
	crafted_items.clear()
	loot.clear()
	expansions.clear()
	var mats: Dictionary = data.get("materials", {})
	for mat_id_str in mats:
		inventory[StringName(mat_id_str)] = int(mats[mat_id_str])
	var migrating := not data.has("hero_grid")
	if migrating:
		expansions.assign(GridExpansions.unlocked_for_record(record))
	else:
		for id in data.get("expansions", []):
			if GridExpansions.is_expansion(StringName(id)) and not (StringName(id) in expansions):
				expansions.append(StringName(id))
	hero_grid = GearGrid.new(GridExpansions.size_after(expansions.size()))
	bag_grid = GearGrid.new(BAG_SIZE)
	var was_equipped := {}  # posiciones de la lista equipadas en las versiones 1 y 2
	var slots: Dictionary = data.get("equipped_slots", {})
	for slot in slots:
		was_equipped[int(slots[slot])] = true
	var to_pack: Array = []
	var to_loot: Array = []
	var dm := get_node_or_null("/root/DataManager")
	var items_arr: Array = data.get("crafted_items", [])
	for i in items_arr.size():
		var item_data = items_arr[i]
		if not item_data is Dictionary:
			continue
		var item_id := StringName(item_data.get("item_id", ""))
		var item_res: ItemResource = null
		if item_id != StringName() and dm and dm.has_method("get_item_resource"):
			item_res = dm.get_item_resource(item_id)
		if item_res == null:
			push_warning("InventoryManager: No se pudo resolver ItemResource '%s' — pieza omitida" % item_id)
			continue
		var crafted := CraftedItem.from_dict(item_data, item_res)
		crafted_items.append(crafted)
		if migrating:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([int(item_data.get("timestamp", 0)), i])
			crafted.aristas = PieceShape.roll_aristas(item_res, crafted.get_quality_tier(), rng)
			if was_equipped.has(i) or bool(item_data.get("equipped", false)):
				to_pack.append(crafted)
			else:
				to_loot.append(crafted)
		elif crafted.place == PLACE_LOOT or not _try_put(crafted, crafted.place, crafted.cell, crafted.rot):
			_put_in_loot(crafted, loot.size())
	if migrating:
		to_pack.sort_custom(func(a, b): return gear_score(a) > gear_score(b))
		for item in to_pack:
			var spot := GearPacker.find_spot(hero_grid, item)
			if spot.is_empty() or not _try_put(item, PLACE_HERO, spot.cell, spot.rot):
				to_loot.append(item)
		to_loot.sort_custom(func(a, b): return gear_score(a) > gear_score(b))
		for item in to_loot:
			_put_in_loot(item, loot.size())
	print("InventoryManager: %d materiales, %d piezas (Tico %d, mochila %d, botín %d)%s" % [inventory.size(), crafted_items.size(), hero_grid.items.size(), bag_grid.items.size(), loot.size(), " — partida migrada" if migrating else ""])
	emit_signal("inventory_changed", inventory.duplicate())
	grid_resized.emit(hero_grid.size)
	_changed(true)
