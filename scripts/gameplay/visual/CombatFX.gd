extends Node2D

## Capa de efectos del corredor, en espacio de mundo (se mueve con la cámara del viewport del héroe).
## Unidades: píxeles del arte (la franja mide 216x96). Un único nodo dibuja todas las partículas en un
## _draw() → barato en móvil. Los halos aditivos los dibuja un hijo con material ADD que lee la misma lista.
## Textos con las fuentes pixel (PixelFont). Provisional hasta la fase 5 del spec de pixel art, que
## sustituye estos dibujos por sprites manteniendo la API.

const SK := preload("res://scripts/gameplay/visual/ShapeKit.gd")
const MAX_PARTS := 360
const ICON_SIZE := 10.0

enum Kind { SPARK, SHARD, DOT, RING, SLASH, TEXT, STAR, BEAM, ORB, ICON, WAVE }

var _parts: Array = []
var _glow: Node2D
var _num_side := 1.0


class GlowDrawer extends Node2D:
	var fx: Node2D

	func _draw() -> void:
		if fx == null:
			return
		var tex: Texture2D = SK.glow_texture()
		for p in fx._parts:
			var g: float = p.get("glow", 0.0)
			if g <= 0.0 or p.get("delay", 0.0) > 0.0:
				continue
			var life_t: float = clampf(p.t / p.life, 0.0, 1.0)
			var a: float = (1.0 - life_t) * g
			var r: float = p.get("glow_r", 5.0)
			var c: Color = p.color
			draw_texture_rect(tex, Rect2(p.pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c.r, c.g, c.b, a))


func _ready() -> void:
	_glow = GlowDrawer.new()
	_glow.fx = self
	_glow.material = SK.additive_material()
	add_child(_glow)


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		# Retardo opcional (para escalonar textos y botín en las celebraciones)
		if p.get("delay", 0.0) > 0.0:
			p.delay -= delta
			continue
		p.t += delta
		if p.t >= p.life:
			_parts.remove_at(i)
			continue
		var grav: float = p.get("grav", 0.0)
		var drag: float = p.get("drag", 0.0)
		var vel: Vector2 = p.get("vel", Vector2.ZERO)
		vel.y += grav * delta
		if drag > 0.0:
			vel *= maxf(0.0, 1.0 - drag * delta)
		p.vel = vel
		p.pos += vel * delta
		if p.has("rot_vel"):
			p.rot += p.rot_vel * delta
		match p.kind:
			Kind.SHARD, Kind.ICON:
				# Rebote simple contra el suelo
				if p.pos.y > p.get("floor", 99999.0) and p.vel.y > 0.0:
					p.pos.y = p.floor
					p.vel = Vector2(p.vel.x * 0.5, -p.vel.y * 0.33)
					if p.has("rot_vel"):
						p.rot_vel *= 0.6
			Kind.WAVE:
				var life_w: float = clampf(p.t / p.life, 0.0, 1.0)
				p.pos = (p.from as Vector2).lerp(p.to, life_w)
			Kind.ORB:
				var life_o: float = clampf(p.t / p.life, 0.0, 1.0)
				var op: Vector2 = (p.from as Vector2).lerp(p.to, ease(life_o, 0.6))
				op.y -= sin(life_o * PI) * 5.0
				p.pos = op
	queue_redraw()
	_glow.queue_redraw()


func _add(p: Dictionary) -> void:
	if _parts.size() >= MAX_PARTS:
		_parts.remove_at(0)
	if not p.has("t"):
		p.t = 0.0
	_parts.append(p)
	queue_redraw()


# ─── Emisores ──────────────────────────────────────────────────────────

## Chispas direccionales (impactos).
func spark_burst(pos: Vector2, dir: Vector2, color: Color, count: int = 10, speed: Vector2 = Vector2(36, 84), spread: float = 0.9) -> void:
	var base_a := dir.angle() if dir != Vector2.ZERO else -PI * 0.5
	for i in count:
		var a := base_a + randf_range(-spread, spread)
		var sp := randf_range(speed.x, speed.y)
		_add({
			"kind": Kind.SPARK, "pos": pos, "vel": Vector2(cos(a), sin(a)) * sp,
			"life": randf_range(0.18, 0.34), "color": color, "grav": 104.0, "drag": 3.0,
			"len": randf_range(2.0, 4.5), "width": 1.0, "glow": 0.6, "glow_r": 3.0,
		})


## Fragmentos poligonales (muertes). La fase 3 los cambia por trozos del propio sprite.
func shatter(pos: Vector2, colors: Array, count: int = 10, size: Vector2 = Vector2(1, 3), floor_y: float = PixelView.FLOOR_Y, up_bias: float = 1.0) -> void:
	for i in count:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		var sp := randf_range(32.0, 84.0) * up_bias
		_add({
			"kind": Kind.SHARD, "pos": pos + Vector2(randf_range(-4, 4), randf_range(-6, 4)),
			"vel": Vector2(cos(a) * sp * 0.8, sin(a) * sp), "life": randf_range(0.7, 1.1),
			"color": colors[i % colors.size()], "grav": 180.0, "drag": 0.6,
			"size": randf_range(size.x, size.y), "rot": randf() * TAU, "rot_vel": randf_range(-12.0, 12.0),
			"floor": floor_y - 1.0, "shape": randi() % 3,
		})


## Anillo que se expande.
func ring(pos: Vector2, color: Color, r0: float = 2.0, r1: float = 12.0, duration: float = 0.3, width: float = 1.0) -> void:
	_add({"kind": Kind.RING, "pos": pos, "life": duration, "color": color, "r0": r0, "r1": r1, "width": width, "glow": 0.35, "glow_r": r1})


## Onda de pulso mágico que viaja de un punto a otro.
func pulse_wave(from: Vector2, to: Vector2, color: Color, duration: float = 0.28) -> void:
	_add({"kind": Kind.WAVE, "pos": from, "from": from, "to": to, "life": duration, "color": color, "glow": 0.5, "glow_r": 5.0})


## Arco de corte (media luna) delante del atacante.
func slash(center: Vector2, radius: float, a0: float, a1: float, color: Color, duration: float = 0.16, thickness: float = 3.0) -> void:
	_add({"kind": Kind.SLASH, "pos": center, "life": duration, "color": color, "r": radius, "a0": a0, "a1": a1, "thick": thickness})


## Destello en estrella (críticos, recoger botín).
func star(pos: Vector2, color: Color, size: float = 8.0, duration: float = 0.22) -> void:
	_add({"kind": Kind.STAR, "pos": pos, "life": duration, "color": color, "size": size, "rot": randf() * TAU, "glow": 0.7, "glow_r": size * 1.2})


## Columna de luz (reaparición del héroe).
func beam(pos: Vector2, color: Color, height: float = 92.0, duration: float = 0.7, width: float = 14.0) -> void:
	_add({"kind": Kind.BEAM, "pos": pos, "life": duration, "color": color, "height": height, "width": width, "glow": 0.5, "glow_r": width * 1.4})


## Orbe (proyectil del espectro) que viaja en la duración dada.
func orb(from: Vector2, to: Vector2, color: Color, duration: float) -> void:
	_add({"kind": Kind.ORB, "pos": from, "from": from, "to": to, "life": maxf(0.05, duration), "color": color, "glow": 0.9, "glow_r": 6.0})


## Polvo al pisar / aterrizar.
func dust_puff(pos: Vector2, color: Color, count: int = 5, strength: float = 1.0) -> void:
	for i in count:
		var dir := -1.0 if i % 2 == 0 else 1.0
		_add({
			"kind": Kind.DOT, "pos": pos + Vector2(randf_range(-2, 2), -1),
			"vel": Vector2(dir * randf_range(6.0, 18.0) * strength, randf_range(-10.0, -3.0) * strength),
			"life": randf_range(0.35, 0.6), "color": color, "grav": -2.0, "drag": 3.5,
			"size": randf_range(1.0, 2.0) * strength, "grow": 1.8,
		})


## Número de daño. style: "normal", "crit", "hero", "pulse", "enemy_pulse", "block"
func damage_number(pos: Vector2, amount: int, style: StringName = &"normal") -> void:
	var color := Color(1, 1, 1)
	var big := false
	var text := str(amount)
	match style:
		&"crit":
			color = Color("ffd23f")
			big = true
			text = "%d!" % amount
		&"hero":
			color = Color("ff5a4f")
		&"pulse":
			color = Color("6fe3ff")
		&"enemy_pulse":
			color = Color("c77dff")
		&"block":
			color = Color("b8c4d6")
	_num_side = -_num_side
	var start := pos + Vector2(_num_side * randf_range(1.0, 4.0), randf_range(-1.0, 1.0))
	_add({
		"kind": Kind.TEXT, "pos": start, "vel": Vector2(_num_side * randf_range(3.0, 7.0), -19.0),
		"life": 1.15 if big else 0.9, "color": color, "text": text, "big": big,
		"drag": 2.2, "grav": 8.0,
	})
	if style == &"crit":
		star(pos, Color("ffe08a"), 9.0, 0.2)


## Texto flotante genérico (botín, avisos, "Bloqueo"). big usa la fuente grande.
func float_text(pos: Vector2, text: String, color: Color, big: bool = false, duration: float = 1.1, rise: float = 14.0, delay: float = 0.0) -> void:
	_add({
		"kind": Kind.TEXT, "pos": pos, "vel": Vector2(0, -rise * 1.6), "life": duration,
		"color": color, "text": text, "big": big, "drag": 2.4, "grav": 0.0, "delay": delay,
	})


## Icono + texto que sube (botín de materiales). vx: velocidad hacia delante (NAN = al azar entre 8 y
## 18). text_row sube la etiqueta esas filas: dos botines que salen a la vez comparten la altura del
## salto (misma subida y gravedad), así que con filas distintas sus etiquetas no se pisan.
func loot_pop(pos: Vector2, icon: Texture2D, text: String, color: Color = Color(1, 0.93, 0.7), delay: float = 0.0, floor_y: float = NAN, vx: float = NAN, text_row: int = 0) -> void:
	if is_nan(vx):
		vx = randf_range(8.0, 18.0)  # hacia delante: se aleja del héroe y de su barra de vida
	# El icono se dibuja centrado: su "suelo" queda medio icono por encima de la línea del suelo
	var ground := (floor_y - ICON_SIZE * 0.5) if not is_nan(floor_y) else pos.y + 8.0
	_add({
		"kind": Kind.ICON, "pos": pos, "vel": Vector2(vx, -52.0), "life": 1.5, "color": color,
		"icon": icon, "text": text, "grav": 104.0, "drag": 0.5, "floor": ground,
		"glow": 0.5, "glow_r": 7.0, "delay": delay, "text_row": text_row,
	})


func clear() -> void:
	_parts.clear()
	queue_redraw()
	_glow.queue_redraw()


# ─── Dibujo ────────────────────────────────────────────────────────────

func _draw() -> void:
	for p in _parts:
		if p.get("delay", 0.0) > 0.0:
			continue
		var life_t: float = clampf(p.t / p.life, 0.0, 1.0)
		match p.kind:
			Kind.SPARK:
				var c: Color = p.color
				c.a = 1.0 - life_t
				var v: Vector2 = p.vel
				var tail: Vector2 = v.normalized() * p.len * (1.0 - life_t * 0.5)
				draw_line(p.pos - tail, p.pos, c, p.width, false)
			Kind.SHARD:
				_draw_shard(p, life_t)
			Kind.DOT:
				var c2: Color = p.color
				c2.a *= (1.0 - life_t) * 0.8
				var r: float = p.size * (1.0 + life_t * p.get("grow", 0.0))
				draw_circle(p.pos, r, c2)
			Kind.RING:
				var e := 1.0 - pow(1.0 - life_t, 3.0)
				var rr: float = lerpf(p.r0, p.r1, e)
				var c3: Color = p.color
				c3.a *= 1.0 - life_t
				draw_arc(p.pos, rr, 0.0, TAU, 24, c3, maxf(1.0, p.width * (1.0 - life_t * 0.6)), false)
			Kind.WAVE:
				var head: Vector2 = p.pos
				var dir_x := signf((p.to as Vector2).x - (p.from as Vector2).x)
				var a_start := -PI * 0.5 if dir_x >= 0.0 else PI * 0.5
				var c4: Color = p.color
				c4.a = 1.0 - life_t * 0.5
				draw_arc(head, 3.0 + 2.0 * life_t, a_start, a_start + PI, 12, c4, 1.0, false)
				draw_arc(head - Vector2(2.0 * dir_x, 0), 2.4 + 1.6 * life_t, a_start, a_start + PI, 10, SK.fade(c4, 0.5), 1.0, false)
			Kind.SLASH:
				_draw_slash(p, life_t)
			Kind.TEXT:
				_draw_text(p, life_t)
			Kind.STAR:
				var s: float = p.size * (0.6 + 0.8 * life_t)
				var c5: Color = p.color
				c5.a = 1.0 - life_t
				draw_colored_polygon(SK.star_pts(p.pos, s, s * 0.18, 4, p.rot), c5)
			Kind.BEAM:
				var a := sin(life_t * PI)
				var w: float = p.width * (1.0 - life_t * 0.6)
				var top: Vector2 = p.pos - Vector2(0, p.height)
				var cb: Color = p.color
				SK.v_gradient(self, Rect2(top.x - w * 0.5, top.y, w, p.height), Color(cb.r, cb.g, cb.b, 0.0), Color(cb.r, cb.g, cb.b, 0.75 * a))
				SK.v_gradient(self, Rect2(top.x - w * 0.18, top.y, w * 0.36, p.height), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8 * a))
			Kind.ORB:
				draw_circle(p.pos, 2.0, p.color)
				draw_circle(p.pos, 1.0, Color(1, 1, 1, 0.9))
			Kind.ICON:
				_draw_icon(p, life_t)


func _draw_shard(p: Dictionary, life_t: float) -> void:
	var c: Color = p.color
	c.a = 1.0 - maxf(0.0, (life_t - 0.6) / 0.4)
	var s: float = p.size
	var xf := Transform2D(p.rot, p.pos)
	var pts: PackedVector2Array
	match int(p.shape):
		0:
			pts = PackedVector2Array([Vector2(-s, -s * 0.6), Vector2(s, 0), Vector2(-s * 0.4, s * 0.8)])
		1:
			pts = PackedVector2Array([Vector2(-s * 0.7, -s * 0.5), Vector2(s * 0.6, -s * 0.7), Vector2(s * 0.7, s * 0.5), Vector2(-s * 0.5, s * 0.6)])
		_:
			pts = PackedVector2Array([Vector2(0, -s), Vector2(s * 0.5, 0), Vector2(0, s), Vector2(-s * 0.5, 0)])
	draw_colored_polygon(SK.xform_pts(pts, xf), c)


func _draw_slash(p: Dictionary, life_t: float) -> void:
	var grow := 1.0 - pow(1.0 - minf(1.0, life_t * 1.6), 2.0)
	var a0: float = p.a0
	var a1: float = lerpf(p.a0, p.a1, grow)
	if absf(a1 - a0) < 0.12:
		return  # Arco aún sin abrir: el polígono sería degenerado
	var r: float = p.r
	var c: Color = p.color
	c.a = 1.0 - life_t
	var pts := SK.crescent_pts(p.pos, r, r - p.thick, a0, a1, 16)
	if pts.size() >= 3:
		draw_colored_polygon(pts, c)
		var core := SK.crescent_pts(p.pos, r - 1.0, r - p.thick * 0.45, a0, a1, 16)
		if core.size() >= 3:
			draw_colored_polygon(core, Color(1, 1, 1, c.a * 0.9))


func _draw_text(p: Dictionary, life_t: float) -> void:
	var alpha := 1.0 - maxf(0.0, (life_t - 0.65) / 0.35)
	var big: bool = p.get("big", false)
	var lift := 1.0 if p.t < 0.1 else 0.0  # rebote de 1 px al aparecer (sin escalar)
	var top: Vector2 = p.pos - Vector2(0, PixelFont.line_size(big) * 0.5 + lift)
	PixelFont.draw_centered(self, top, p.text, p.color, alpha, big)


func _draw_icon(p: Dictionary, life_t: float) -> void:
	var alpha := 1.0 - maxf(0.0, (life_t - 0.7) / 0.3)
	var icon: Texture2D = p.icon
	if icon:
		var rect := Rect2((p.pos - Vector2(ICON_SIZE, ICON_SIZE) * 0.5).round(), Vector2(ICON_SIZE, ICON_SIZE))
		draw_texture_rect(icon, rect, false, Color(1, 1, 1, alpha))
	var text: String = p.text
	if text != "":
		var lift := float(p.get("text_row", 0)) * float(PixelFont.SMALL_SIZE + 1)
		PixelFont.draw_centered(self, p.pos + Vector2(0, -ICON_SIZE * 0.5 - PixelFont.SMALL_SIZE - lift), text, p.color, alpha)
