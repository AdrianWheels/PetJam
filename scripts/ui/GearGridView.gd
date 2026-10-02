class_name GearGridView
extends Control

## Una rejilla de equipo dibujada por sí misma (spec doc/specs/2026-09-27-inventario-en-rejilla.md,
## apartado 9): la de Tico o la mochila. Solo dibuja la GearGrid que le da el panel de Equipo; el dedo
## lo lleva el panel. Las casillas que aún no existen (ampliaciones pendientes) se dibujan punteadas.

const CELL := 110.0  ## 22 píxeles de arte a ×5, el tamaño de píxel de la franja
const COLOR_CELL := Color(0.16, 0.11, 0.09, 0.45)
const COLOR_LINE := Color(0.45, 0.33, 0.21, 0.9)
const COLOR_LOCKED := Color(0.6, 0.5, 0.38, 0.55)
const COLOR_WEAPON := Color("d85a30")
const COLOR_ARMOR := Color("1d9e75")
const COLOR_ARISTA := Color(0.62, 0.6, 0.58, 0.9)
const COLOR_ART_BACK := Color(0.1, 0.07, 0.06, 0.55)  ## fondo de las casillas de una pieza con arte
const COLOR_OK := Color(0.45, 0.95, 0.5, 0.45)
const COLOR_BAD := Color(1.0, 0.35, 0.3, 0.45)
const COLOR_SWAP := Color("ffd76a")
const COLOR_GAIN := Color(0.45, 0.95, 0.5, 0.9)
const COLOR_LOSS := Color(1.0, 0.4, 0.35, 0.9)
const COLOR_ZONE := Color(1.0, 0.84, 0.42, 0.22)
const ZONE_BAND := 10.0  ## ancho de la franja que marca una zona, en píxeles de pantalla

var grid: GearGrid
var show_zones := false  ## la rejilla de Tico marca las zonas de GearAuras.ZONES; la mochila, no
var max_size := Vector2i(6, 6)  ## casillas que se dibujan; las que aún no existen, punteadas
var hidden_item: CraftedItem = null  ## la pieza que se arrastra no se dibuja en su sitio
var drop_cells: Dictionary = {}  ## casilla → color del destino del arrastre
var swap_item: CraftedItem = null  ## pieza con la que se intercambiaría (contorno amarillo)
var glow: Dictionary = {}  ## pieza → color: gana (verde) o pierde (rojo) aumento con el arrastre
var sprite_for: Callable = Callable(GearArt, "texture_for")  ## (pieza, giro) → Texture2D; sin textura, casillas de color
var _shake_item: CraftedItem = null
var _shake := 0.0


func setup(g: GearGrid, max_cells: Vector2i) -> void:
	grid = g
	max_size = max_cells
	custom_minimum_size = Vector2(max_cells) * CELL
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # el panel lleva el dedo
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # el arte de las piezas es ilustrado, no pixel art
	queue_redraw()


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		queue_redraw()


func cell_at(local: Vector2) -> Vector2i:
	return Vector2i(floori(local.x / CELL), floori(local.y / CELL))


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c) * CELL, Vector2(CELL, CELL))


## Pieza bajo un punto (coordenadas locales), por sus casillas limpias o sus aristas; null si no hay.
func item_at_local(local: Vector2) -> CraftedItem:
	if grid == null:
		return null
	return grid.item_at(cell_at(local))


## Esquina de la caja de una pieza colocada, en coordenadas locales.
func item_origin(item: CraftedItem) -> Vector2:
	return Vector2(grid.cell_of(item)) * CELL


## La pieza tiembla un momento (no cabe girada).
func start_shake(item: CraftedItem) -> void:
	_shake_item = item
	_shake = 0.3


func _draw() -> void:
	if grid == null:
		return
	for y in max_size.y:
		for x in max_size.x:
			var c := Vector2i(x, y)
			var r := cell_rect(c).grow(-1.0)
			if grid.in_bounds(c):
				draw_rect(r, COLOR_CELL)
				draw_rect(r, COLOR_LINE, false, 2.0)
			else:
				_draw_dashed(r.grow(-6.0), COLOR_LOCKED)
	if show_zones:
		for slot in GearAuras.ZONES:
			_draw_zone(slot, GearAuras.ZONES[slot])
	for item in grid.items:
		if item == hidden_item:
			continue
		var offset := Vector2.ZERO
		if item == _shake_item and _shake > 0.0:
			offset.x = sin(_shake * 60.0) * 6.0
		draw_piece_at(self, item, item_origin(item) + offset, grid.rot_of(item), CELL, 1.0, sprite_for)
		if glow.has(item):
			_outline(item, glow[item])
	if swap_item and grid.has(swap_item):
		_outline(swap_item, COLOR_SWAP)
	for c in drop_cells:
		draw_rect(cell_rect(c).grow(-3.0), drop_cells[c])


## Dibuja una pieza con la esquina de su caja en `top_left` y casillas de `cell_px`. Lo usan la rejilla,
## el botín y la pieza que se arrastra. Si `sprite_fn` da una textura (GearArt), la pinta; si no, casillas de color.
static func draw_piece_at(canvas: CanvasItem, item: CraftedItem, top_left: Vector2, rot: int, cell_px: float, alpha: float, sprite_fn: Callable = Callable()) -> void:
	var fp := PieceShape.of_item(item, rot)
	var base := COLOR_WEAPON if GearAuras.kind(item) == &"weapon" else COLOR_ARMOR
	var edge := item.get_quality_color()
	var tex: Texture2D = sprite_fn.call(item, rot) if sprite_fn.is_valid() else null
	if tex:
		# Con arte: cada casilla limpia lleva un fondo oscuro del color de su tipo y el borde de la calidad, y la
		# textura va encima, estirada sobre la caja de las casillas limpias. Las aristas, en gris, como sin arte
		var lo := Vector2i(999, 999)
		var hi := Vector2i(-999, -999)
		for c in fp.clean:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
			var r := Rect2(top_left + Vector2(c) * cell_px, Vector2(cell_px, cell_px)).grow(-4.0)
			canvas.draw_rect(r, Color(base.darkened(0.7), alpha * 0.75))
			canvas.draw_rect(r, Color(edge, alpha), false, 3.0)
		for c in fp.aristas:
			var r := Rect2(top_left + Vector2(c) * cell_px, Vector2(cell_px, cell_px)).grow(-cell_px * 0.18)
			canvas.draw_rect(r, Color(COLOR_ARISTA, alpha * 0.85))
		var box := Rect2(top_left + Vector2(lo) * cell_px, Vector2(hi - lo + Vector2i.ONE) * cell_px)
		canvas.draw_texture_rect(tex, box, false, Color(1, 1, 1, alpha))
		return
	for c in fp.clean:
		var r := Rect2(top_left + Vector2(c) * cell_px, Vector2(cell_px, cell_px)).grow(-4.0)
		canvas.draw_rect(r, Color(base, alpha))
		canvas.draw_rect(r, Color(edge, alpha), false, 4.0)
	for c in fp.aristas:
		var r := Rect2(top_left + Vector2(c) * cell_px, Vector2(cell_px, cell_px)).grow(-cell_px * 0.18)
		canvas.draw_rect(r, Color(COLOR_ARISTA, alpha * 0.85))


## Zona de un tipo de pieza: una franja tenue por dentro de su borde de la rejilla (que sigue al borde al
## ampliarla). Las piezas se dibujan encima.
func _draw_zone(_slot: String, zone: StringName) -> void:
	var w := float(grid.size.x) * CELL
	var h := float(grid.size.y) * CELL
	var r: Rect2
	match zone:
		&"top":
			r = Rect2(0.0, 0.0, w, ZONE_BAND)
		&"bottom":
			r = Rect2(0.0, h - ZONE_BAND, w, ZONE_BAND)
		&"left":
			r = Rect2(0.0, 0.0, ZONE_BAND, h)
		&"right":
			r = Rect2(w - ZONE_BAND, 0.0, ZONE_BAND, h)
		_:
			return
	draw_rect(r, COLOR_ZONE)


func _outline(item: CraftedItem, color: Color) -> void:
	for c in grid.placed_clean_cells(item):
		draw_rect(cell_rect(c).grow(-2.0), color, false, 5.0)


func _draw_dashed(r: Rect2, color: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 8.0)
