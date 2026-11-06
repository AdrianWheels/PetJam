class_name LootPiece
extends RigidBody2D

## Una pieza del botín con física (spec doc/specs/2026-10-02-botin-con-fisica.md, apartados 3 y 5): un cuerpo rígido con
## un rectángulo de colisión por casilla de su silueta (aristas incluidas), centrado en su centro de masa, y su dibujo de
## siempre (GearGridView.draw_piece_at), que gira con el cuerpo, todo a media escala (BOX_CELL, 55 px por casilla). Su
## forma es la del giro 0; el ángulo lo da el cuerpo.
## La caja (LootBoxView) la crea, la quita y decide cuándo pasa a modo fantasma: choca con la caja pero no con las demás
## piezas y se dibuja semitransparente.

## Escala de la caja (decisión del usuario, 2026-10-02): en el botín las piezas se dibujan y chocan a media escala, 55 px
## por casilla. Al cogerlas vuelven a 110 (el panel arrastra a tamaño completo) y al soltarlas en la caja vuelven a 55.
## Es la única constante de escala del botín: LootBoxView y las pruebas la leen de aquí.
const BOX_CELL := GearGridView.CELL * 0.5
## Capas propias del botín: el juego usa la 1 (Tico, enemigos, salas y el Tico del panel) y no debe tocar la caja
const LAYER_WALLS := 1 << 8
const LAYER_PIECES := 1 << 9
const LAYER_GHOSTS := 1 << 10
const FRICTION := 0.8
const BOUNCE := 0.05
const LINEAR_DAMP := 0.5
const ANGULAR_DAMP := 2.0
const GRAVITY_SCALE := 2.0
const MASS_PER_CELL := 1.0
const GHOST_ALPHA := 0.45

var item: CraftedItem
var is_ghost := false
var rects: Array[Rect2] = []  ## en coordenadas del cuerpo, de BOX_CELL (giro 0, centradas en su centro de masa); las limpias primero
var sprite_for: Callable = Callable(GearArt, "texture_for")  ## (pieza, giro) → Texture2D; sin textura, casillas de color
var _com := Vector2.ZERO  ## centro de masa desde la esquina de su caja, en el giro 0 y a BOX_CELL


## Rectángulos de colisión de una pieza en el giro 0, centrados en su centro de masa.
static func rects_for(it: CraftedItem) -> Array[Rect2]:
	return PieceShape.collision_rects(PieceShape.of_item(it, 0), BOX_CELL)


## Caja que ocupan unos rectángulos girados `angle` alrededor del centro de masa (el origen).
static func extent(list: Array[Rect2], angle: float) -> Rect2:
	var xf := Transform2D(angle, Vector2.ZERO)
	var out := Rect2(xf * list[0].position, Vector2.ZERO)
	for r in list:
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			out = out.expand(xf * corner)
	return out


## Formas, masa y material. Se llama antes de añadirla a la caja.
func setup(it: CraftedItem) -> void:
	item = it
	var fp := PieceShape.of_item(it, 0)
	_com = PieceShape.mass_center(fp, BOX_CELL)
	rects = PieceShape.collision_rects(fp, BOX_CELL)
	for r in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		add_child(cs)
	mass = MASS_PER_CELL * rects.size()
	var mat := PhysicsMaterial.new()
	mat.friction = FRICTION
	mat.bounce = BOUNCE
	physics_material_override = mat
	gravity_scale = GRAVITY_SCALE
	linear_damp = LINEAR_DAMP
	angular_damp = ANGULAR_DAMP
	can_sleep = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_ghost(false)


## Modo fantasma (spec, apartado 5): choca con el suelo, las paredes y el techo, pero no con las demás piezas, y se dibuja
## semitransparente. Al cambiar se despierta, para que vuelva a caer o a apoyarse.
func set_ghost(on: bool) -> void:
	is_ghost = on
	collision_layer = LAYER_GHOSTS if on else LAYER_PIECES
	collision_mask = LAYER_WALLS if on else LAYER_WALLS | LAYER_PIECES
	modulate.a = GHOST_ALPHA if on else 1.0
	sleeping = false
	queue_redraw()


## Caja que ocupa ahora, girada, en coordenadas del padre (la caja del botín).
func bounds() -> Rect2:
	var e := extent(rects, rotation)
	return Rect2(e.position + position, e.size)


## Su punto más alto, en coordenadas del padre.
func top_y() -> float:
	return bounds().position.y


## true si un punto (coordenadas del padre) cae en alguna de sus casillas, aristas incluidas.
func contains_point(p: Vector2) -> bool:
	var local := transform.affine_inverse() * p
	for r in rects:
		if r.has_point(local):
			return true
	return false


## Cuarto de vuelta más cercano a su ángulo (0-3, en el sentido de las agujas del reloj, como PieceShape.rotate_raw).
func straight_rot() -> int:
	return posmod(roundi(rotation / (PI / 2.0)), 4)


func _draw() -> void:
	GearGridView.draw_piece_at(self, item, -_com, 0, BOX_CELL, 1.0, sprite_for)
