class_name LootStripView
extends Control

## El botín en una tira con desplazamiento lateral (spec del inventario en rejilla, apartado 9.1): las
## piezas a tamaño real, tumbadas (con el giro que las deja más bajas) y lo más nuevo a la izquierda.
## Mide 3 casillas de alto: ninguna pieza tumbada, aristas incluidas, pasa de 3. El dedo lo lleva el panel.

const CELL := GearGridView.CELL
const PAD := 20.0
const COLOR_BG := Color(0.12, 0.08, 0.07, 0.85)

var items: Array[CraftedItem] = []
var scroll := 0.0
var hidden_item: CraftedItem = null  ## la pieza que se arrastra no se dibuja
var sprite_for: Callable = Callable()
var _slots: Array = []  # [{"item", "rot", "rect"}], rect en coordenadas sin desplazar


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # el panel lleva el dedo
	clip_contents = true  # una pieza a medio desplazar no se sale de la tira


func set_items(list: Array) -> void:
	items.assign(list)
	_layout()
	queue_redraw()


## Giro con el que se enseña una pieza en la tira: el que la deja más baja (el primero si empatan).
static func flat_rot(item: CraftedItem) -> int:
	var best := 0
	var best_h := 999
	for r in 4:
		var h: int = PieceShape.of_item(item, r).size.y
		if h < best_h:
			best_h = h
			best = r
	return best


func _layout() -> void:
	_slots.clear()
	var x := PAD
	for item in items:
		var rot := flat_rot(item)
		var box: Vector2 = Vector2(PieceShape.of_item(item, rot).size) * CELL
		_slots.append({"item": item, "rot": rot, "rect": Rect2(Vector2(x, (size.y - box.y) * 0.5), box)})
		x += box.x + PAD
	scroll = clampf(scroll, 0.0, max_scroll())


func content_width() -> float:
	if _slots.is_empty():
		return 0.0
	var last: Rect2 = _slots.back().rect
	return last.end.x + PAD


func max_scroll() -> float:
	return maxf(0.0, content_width() - size.x)


## Pieza bajo un punto (coordenadas locales): {"item", "rot", "rect"}, o {} si no hay.
func slot_at_local(local: Vector2) -> Dictionary:
	var p := local + Vector2(scroll, 0.0)
	for s in _slots:
		if s.rect.has_point(p):
			return s
	return {}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	for s in _slots:
		if s.item == hidden_item:
			continue
		var top_left: Vector2 = s.rect.position - Vector2(scroll, 0.0)
		if top_left.x > size.x or top_left.x + s.rect.size.x < 0.0:
			continue
		GearGridView.draw_piece_at(self, s.item, top_left, s.rot, CELL, 1.0, sprite_for)
