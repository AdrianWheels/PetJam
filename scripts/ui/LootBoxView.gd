class_name LootBoxView
extends Node2D

## El botín con física (spec doc/specs/2026-10-02-botin-con-fisica.md): una caja de 960×440 con suelo, paredes y un techo
## invisible 165 px por encima de su borde, y un cuerpo (LootPiece), a media escala (BOX_CELL, 55 px por casilla), por pieza de InventoryManager.loot, que sigue siendo la
## fuente de verdad: sync() crea y quita cuerpos según la lista. Coordenadas: las de este nodo (la esquina de arriba a la
## izquierda de la caja es 0,0; el techo está en y = CEIL_Y). El dedo lo lleva el panel de Equipo, que pasa sus puntos a
## estas coordenadas (to_local), pregunta qué pieza hay debajo (piece_at), la coge (hold) y la suelta (drop_at).
## Entrar en la caja:
##  - con pose guardada válida: aparece en ella, despierta (si la pose solapa a otra, como fantasma);
##  - soltada por el jugador: con su centro de masa en ese punto, con la velocidad del gesto (con tope) y subida lo justo
##    para no solapar;
##  - lo demás (forjado, «Al botín», intercambios, lo que llegó con el panel cerrado): cae desde arriba, una pieza tras otra,
##    tumbada, en una x al azar y con un pequeño giro.
## No cabe (apartado 5): una pieza que, ya quieta, solapa a otra o está apretada contra el techo, o que no encuentra sitio
## bajo el techo para caer, pasa a modo fantasma. Cada segundo, un fantasma que ya no solapa vuelve a chocar donde está; y
## cuando se libera sitio, los fantasmas vuelven a la cola para probar donde están o caer otra vez desde arriba.
## Cerrada (set_active(false)), la caja y sus cuerpos salen de la física: no se mueven ni cuestan nada.

signal poses_settled  ## la pila se ha quedado quieta tras un cambio y sus poses ya están en las piezas

const BOX_CELL := LootPiece.BOX_CELL  ## 55 px por casilla: la escala de las piezas en la caja
const SIZE := Vector2(960, 440)
const CEIL_Y := -165.0  ## techo invisible: 1,5 casillas por encima del borde de la caja
const WALL := 400.0  ## grosor del suelo, las paredes y el techo: que nada los atraviese
const COLOR_BG := Color(0.12, 0.08, 0.07, 0.85)  ## el fondo de la tira de antes; el techo no se dibuja
const MAX_THROW_SPEED := 1400.0  ## px/s: tope de la velocidad del gesto al soltar en la caja
const SPAWN_TILT := 0.3  ## rad: giro inicial máximo de lo que cae desde arriba
const SPAWN_SPIN := 1.5  ## rad/s: velocidad de giro máxima de lo que cae desde arriba
const SPAWN_INTERVAL := 9  ## pasos de física (0,15 s) entre un intento de caída desde arriba y el siguiente
const SPAWN_TRIES := 8  ## x al azar que se prueban en cada intento
const SPAWN_PATIENCE := 120  ## pasos (2 s) esperando sitio bajo el techo antes de entrar como fantasma
const SETTLE_CHECK := 180  ## pasos (3 s): si una pieza que ha entrado aún no se ha dormido, se mira igual si cabe
const CEIL_TOUCH := 3.0  ## px: una pieza quieta así de cerca del techo está apretada contra él
const OVERLAP_MARGIN := BOX_CELL * 0.08  ## px (4,4) que se encoge cada casilla al buscar solapes: el contacto normal no cuenta
const LIFT_STEP := BOX_CELL * 0.25  ## px (un cuarto de casilla de la caja) que sube una pieza soltada sobre otras hasta que no solapa
const GHOST_CHECK := 60  ## pasos (1 s) entre comprobaciones de los fantasmas
const SAVE_EVERY := 60  ## pasos (1 s) como mínimo entre dos avisos de poses
const SLEEP_LINEAR := 8.0  ## px/s: por debajo, una pieza puede dormirse
const SLEEP_ANGULAR := 0.21  ## rad/s (12°)
const SLEEP_TIME := 0.4  ## s quieta antes de dormirse

var active := false
var sprite_for: Callable = Callable(GearArt, "texture_for")
var rng := RandomNumberGenerator.new()
var _bodies: Dictionary = {}  # CraftedItem → LootPiece
var _held: CraftedItem = null  ## la pieza que lleva el dedo: está en el botín pero sin cuerpo
var _queue: Array[CraftedItem] = []  ## esperan para caer desde arriba (o, si ya tienen cuerpo fantasma, para volver a probar)
var _since_spawn := 0
var _blocked := 0  ## pasos que lleva la primera de la cola sin sitio bajo el techo
var _top_full := false  ## no hay sitio bajo el techo: lo que llega entra como fantasma sin esperar, hasta que se libere sitio
var _checks: Dictionary = {}  # LootPiece → pasos desde que entró: falta mirar si cabe
var _space_freed := false
var _ghost_clock := 0
var _dirty := false  ## ha cambiado algo desde el último aviso de poses
var _last_settled_frame := -1000000


func _ready() -> void:
	_build_walls()
	# Reposo: el juego no tiene más cuerpos rígidos, así que el umbral se pone en el espacio del mundo 2D
	var space := get_world_2d().space
	PhysicsServer2D.space_set_param(space, PhysicsServer2D.SPACE_PARAM_BODY_LINEAR_VELOCITY_SLEEP_THRESHOLD, SLEEP_LINEAR)
	PhysicsServer2D.space_set_param(space, PhysicsServer2D.SPACE_PARAM_BODY_ANGULAR_VELOCITY_SLEEP_THRESHOLD, SLEEP_ANGULAR)
	PhysicsServer2D.space_set_param(space, PhysicsServer2D.SPACE_PARAM_BODY_TIME_TO_SLEEP, SLEEP_TIME)
	set_active(active)


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = LootPiece.LAYER_WALLS
	walls.collision_mask = 0
	var tall := SIZE.y - CEIL_Y + 2.0 * WALL
	for r: Rect2 in [
		Rect2(-WALL, SIZE.y, SIZE.x + 2.0 * WALL, WALL),  # suelo
		Rect2(-WALL, CEIL_Y - WALL, WALL, tall),  # pared izquierda
		Rect2(SIZE.x, CEIL_Y - WALL, WALL, tall),  # pared derecha
		Rect2(-WALL, CEIL_Y - WALL, SIZE.x + 2.0 * WALL, WALL),  # techo invisible
	]:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		walls.add_child(cs)
	add_child(walls)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), COLOR_BG)

# ═══════════════════════════════════════════════════════════════════
#  LO QUE USA EL PANEL
# ═══════════════════════════════════════════════════════════════════

## Abierta, la caja simula; cerrada, la caja y sus cuerpos salen de la física (spec, apartado 7).
func set_active(on: bool) -> void:
	active = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Los cuerpos siguen a la lista del botín: quita los de las piezas que ya no están y da entrada a las nuevas (con pose
## válida, en ella; si no, a la cola para caer desde arriba). La pieza cogida no tiene cuerpo.
func sync(list: Array) -> void:
	var changed := false
	for item: CraftedItem in _bodies.keys():
		if not (item in list):
			_remove_body(item)
			changed = true
	if _held and not (_held in list):
		_held = null
		changed = true
	var old_head: CraftedItem = _queue[0] if not _queue.is_empty() else null
	var kept: Array[CraftedItem] = []
	for item in _queue:
		if item in list:
			kept.append(item)
	if kept.size() != _queue.size():
		changed = true
	_queue = kept
	if old_head != null and (kept.is_empty() or kept[0] != old_head):
		_blocked = 0  # la cabeza que esperaba sitio se fue: la siguiente empieza su paciencia de cero
	for item: CraftedItem in list:
		if item == _held or _bodies.has(item) or item in _queue:
			continue
		if pose_is_valid(item.loot_pose):
			_restore(item)
		else:
			_queue.append(item)
		changed = true
	if changed:
		_dirty = true


## La coge el dedo: sale de la física (spec, apartado 6). Sigue en el botín.
func hold(item: CraftedItem) -> void:
	if _bodies.has(item):
		_remove_body(item)
	if not _queue.is_empty() and _queue[0] == item:
		_blocked = 0
	_queue.erase(item)
	_held = item
	_dirty = true


func is_held(item: CraftedItem) -> bool:
	return item != null and item == _held


## Suelta una pieza del botín en la caja: su centro de masa en `local_pos` (coordenadas de la caja, o el punto de la caja
## más cercano), con el giro `rot` (cuartos de vuelta) y la velocidad del gesto, con tope. No hace nada si la pieza no está
## en el botín o ya tiene cuerpo.
func drop_at(item: CraftedItem, local_pos: Vector2, velocity: Vector2, rot: int) -> void:
	if item == _held:
		_held = null
	if item == null or item.place != InventoryManager.PLACE_LOOT or _bodies.has(item):
		return
	_queue.erase(item)
	_enter_at(item, local_pos, velocity, rot)
	_dirty = true


## Pieza bajo un punto (coordenadas de la caja): primero las que chocan (la de más arriba en el dibujo); si no, un fantasma.
func piece_at(local: Vector2) -> LootPiece:
	var ghost: LootPiece = null
	for i in range(get_child_count() - 1, -1, -1):
		var body := get_child(i) as LootPiece
		if body == null or not body.contains_point(local):
			continue
		if not body.is_ghost:
			return body
		if ghost == null:
			ghost = body
	return ghost


func body_of(item: CraftedItem) -> LootPiece:
	return _bodies.get(item)


## Centro de la primera casilla limpia de una pieza, en coordenadas globales (pruebas y capturas). Vector2.INF sin cuerpo.
func piece_global_point(item: CraftedItem) -> Vector2:
	var body := body_of(item)
	return body.to_global(body.rects[0].get_center()) if body else Vector2.INF


## La caja dibujada, en coordenadas globales: donde soltar una pieza la devuelve al botín.
func rect_global() -> Rect2:
	return Rect2(global_position, SIZE)


## true si la pieza cabe donde está (spec, apartado 5): no solapa a ninguna que choca y no está apretada contra el techo.
func fits(body: LootPiece) -> bool:
	var me: Array[RID] = [body.get_rid()]
	return body.top_y() > CEIL_Y + CEIL_TOUCH and not _overlaps(body.rects, body.transform, me)


## true si no queda nada por entrar ni por mirar y todas las piezas duermen.
func is_settled() -> bool:
	if not _queue.is_empty() or not _checks.is_empty():
		return false
	for body: LootPiece in _bodies.values():
		if not body.sleeping:
			return false
	return true


## Deja en cada pieza con cuerpo su pose de ahora (spec, apartado 8).
func collect_poses() -> void:
	for item: CraftedItem in _bodies:
		var body: LootPiece = _bodies[item]
		item.loot_pose = {"pos": body.position, "ang": wrapf(body.rotation, -PI, PI)}


## Una pose guardada vale si sus números son finitos y su centro está dentro de la caja, sin pasar del techo (spec,
## apartado 8). Si no, la pieza cae desde arriba.
static func pose_is_valid(pose: Dictionary) -> bool:
	if not (pose.get("pos") is Vector2) or not (pose.get("ang") is float):
		return false
	var p: Vector2 = pose.pos
	var a: float = pose.ang
	return p.is_finite() and is_finite(a) and p.x >= 0.0 and p.x <= SIZE.x and p.y >= CEIL_Y and p.y <= SIZE.y


## Velocidad del gesto con tope, para que la pieza no salga disparada (spec, apartado 4).
static func cap_throw(v: Vector2) -> Vector2:
	return v.limit_length(MAX_THROW_SPEED)

# ═══════════════════════════════════════════════════════════════════
#  CADA PASO DE FÍSICA
# ═══════════════════════════════════════════════════════════════════

func _physics_process(_delta: float) -> void:
	if _space_freed:
		# Se ha liberado sitio: los fantasmas vuelven a probar, por turno
		_space_freed = false
		for item: CraftedItem in _bodies:
			if _bodies[item].is_ghost and not (item in _queue):
				_queue.append(item)
	_feed_queue()
	_run_checks()
	_ghost_clock += 1
	if _ghost_clock >= GHOST_CHECK:
		_ghost_clock = 0
		for body: LootPiece in _bodies.values():
			if body.is_ghost and fits(body):
				_unghost(body)
	_report_if_settled()


## La primera de la cola entra, cada SPAWN_INTERVAL pasos: cae desde arriba si hay sitio bajo el techo. Un fantasma que
## vuelve a probar se queda donde está si ya cabe ahí. Sin sitio durante SPAWN_PATIENCE pasos (o con la caja ya llena), lo
## nuevo entra como fantasma y el fantasma que probaba sigue de fantasma.
func _feed_queue() -> void:
	_since_spawn += 1
	if _queue.is_empty() or _since_spawn < SPAWN_INTERVAL:
		return
	_since_spawn = 0
	var item: CraftedItem = _queue[0]
	var ghost: LootPiece = _bodies.get(item)
	if ghost and (not ghost.is_ghost or fits(ghost)):
		if ghost.is_ghost:
			_unghost(ghost)
		_next_in_queue()
		return
	var rects := LootPiece.rects_for(item)
	var spot := _find_top_spot(rects)
	if not spot.is_empty():
		if ghost:
			_free_body(item)
		var body := _make_body(item, spot.xform, false)
		body.angular_velocity = rng.randf_range(-SPAWN_SPIN, SPAWN_SPIN)
		_top_full = false
		_next_in_queue()
		return
	_blocked += SPAWN_INTERVAL
	if not _top_full and _blocked < SPAWN_PATIENCE:
		return
	_top_full = true
	if ghost == null:
		_make_body(item, _top_xform(rects, _flat_angle(rects)), true)
	_next_in_queue()


func _next_in_queue() -> void:
	_queue.pop_front()
	_blocked = 0
	_dirty = true


## Cada pieza que ha entrado, ya quieta (o a los SETTLE_CHECK pasos): si no cabe, pasa a modo fantasma.
func _run_checks() -> void:
	for body: LootPiece in _checks.keys():
		_checks[body] = int(_checks[body]) + 1
		if not body.sleeping and int(_checks[body]) < SETTLE_CHECK:
			continue
		_checks.erase(body)
		if not body.is_ghost and not fits(body):
			body.set_ghost(true)
			_dirty = true


func _unghost(body: LootPiece) -> void:
	body.set_ghost(false)
	_checks[body] = 0
	_dirty = true


## Quieta tras un cambio, y como mucho una vez cada SAVE_EVERY pasos: deja las poses en las piezas y avisa.
func _report_if_settled() -> void:
	if not _dirty or not is_settled():
		return
	var frame := Engine.get_physics_frames()
	if frame - _last_settled_frame < SAVE_EVERY:
		return
	_last_settled_frame = frame
	_dirty = false
	collect_poses()
	poses_settled.emit()

# ═══════════════════════════════════════════════════════════════════
#  CUERPOS (privado)
# ═══════════════════════════════════════════════════════════════════

func _make_body(item: CraftedItem, xform: Transform2D, ghost: bool) -> LootPiece:
	var body := LootPiece.new()
	body.setup(item)
	body.sprite_for = sprite_for
	body.transform = xform
	body.set_ghost(ghost)
	add_child(body)
	_bodies[item] = body
	_checks[body] = 0
	return body


## Quita el cuerpo ya: free() lo saca del espacio en el acto, y las consultas de solape de este mismo paso no lo ven.
func _free_body(item: CraftedItem) -> void:
	var body: LootPiece = _bodies[item]
	_bodies.erase(item)
	_checks.erase(body)
	remove_child(body)
	body.free()


## La pieza sale de la caja (vendida, sacada o cogida): queda sitio, y las que se apoyaban en ella se despiertan para caer.
func _remove_body(item: CraftedItem) -> void:
	_free_body(item)
	_space_freed = true
	_top_full = false
	for body: LootPiece in _bodies.values():
		body.sleeping = false


## Pose guardada: aparece en ella, despierta (si se guardó en el aire, cae). Si solapa a otra ya puesta, como fantasma.
func _restore(item: CraftedItem) -> void:
	var xform := Transform2D(float(item.loot_pose.ang), item.loot_pose.pos)
	_make_body(item, xform, _overlaps(LootPiece.rects_for(item), xform))


## Soltada por el jugador: dentro de la caja (el punto más cercano), subida a pasos de LIFT_STEP hasta no solapar. Si
## llega al techo y sigue solapando, entra como fantasma donde se soltó.
func _enter_at(item: CraftedItem, local_pos: Vector2, velocity: Vector2, rot: int) -> void:
	var rects := LootPiece.rects_for(item)
	var angle := float(posmod(rot, 4)) * PI / 2.0
	var ext := LootPiece.extent(rects, angle)
	var start := _clamp_inside(ext, local_pos)
	var top := CEIL_Y - ext.position.y
	var p := start
	while _overlaps(rects, Transform2D(angle, p)) and p.y - LIFT_STEP >= top:
		p.y -= LIFT_STEP
	var ghost := _overlaps(rects, Transform2D(angle, p))
	var body := _make_body(item, Transform2D(angle, start if ghost else p), ghost)
	body.linear_velocity = cap_throw(velocity)


## Centro de masa más cercano a `p` con el que la pieza (de caja girada `ext`) queda entera entre las paredes, el suelo y
## el techo.
func _clamp_inside(ext: Rect2, p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, -ext.position.x, SIZE.x - ext.end.x), clampf(p.y, CEIL_Y - ext.position.y, SIZE.y - ext.end.y))


## Sitio bajo el techo para caer: SPAWN_TRIES intentos, tumbada (_flat_angle) con un giro pequeño y una x al azar, con la
## pieza entera entre las paredes y pegada al techo. {"xform": Transform2D}, o {} si no hay.
func _find_top_spot(rects: Array[Rect2]) -> Dictionary:
	var flat := _flat_angle(rects)
	for i in SPAWN_TRIES:
		var xform := _top_xform(rects, flat + rng.randf_range(-SPAWN_TILT, SPAWN_TILT))
		if not _overlaps(rects, xform):
			return {"xform": xform}
	return {}


## Cuarto de vuelta (en radianes) con el que la pieza es más baja, como se tumbaba en la tira: así cae ocupando poca altura
## bajo el techo y cabe mientras la pila no llega arriba. El primero si empatan.
static func _flat_angle(rects: Array[Rect2]) -> float:
	var best := 0.0
	var best_h := INF
	for k in 4:
		var h := LootPiece.extent(rects, float(k) * PI / 2.0).size.y
		if h < best_h - 0.5:
			best_h = h
			best = float(k) * PI / 2.0
	return best


## Pose de caída desde arriba con giro `angle`: x al azar sin tocar las paredes y el punto más alto 1 px bajo el techo.
func _top_xform(rects: Array[Rect2], angle: float) -> Transform2D:
	var ext := LootPiece.extent(rects, angle)
	return Transform2D(angle, Vector2(rng.randf_range(-ext.position.x, SIZE.x - ext.end.x), CEIL_Y - ext.position.y + 1.0))


## true si unas casillas (rects de LootPiece) en `xform` (coordenadas de la caja) pisan alguna pieza que choca. Cada casilla
## se encoge OVERLAP_MARGIN por lado: tocarse no cuenta.
func _overlaps(rects: Array[Rect2], xform: Transform2D, exclude: Array[RID] = []) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(BOX_CELL, BOX_CELL) - Vector2.ONE * 2.0 * OVERLAP_MARGIN
	query.shape = shape
	query.collision_mask = LootPiece.LAYER_PIECES
	query.exclude = exclude
	for r in rects:
		query.transform = global_transform * xform * Transform2D(0.0, r.get_center())
		if not space.intersect_shape(query, 1).is_empty():
			return true
	return false
