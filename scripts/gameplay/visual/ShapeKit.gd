class_name ShapeKit
extends RefCounted

## Utilidades de dibujo vectorial para el estilo "geometría iluminada".
## Todas las funciones reciben el CanvasItem sobre el que dibujar (se llaman desde _draw()).

const OUTLINE := Color(0.05, 0.035, 0.06, 1.0)

static var _glow_tex: Texture2D = null
static var _add_material: CanvasItemMaterial = null
static var _lit_cache: Dictionary = {}
const LIT_CACHE_MAX := 512


## Textura de halo radial (blanco → transparente) generada una sola vez y compartida.
static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		grad.add_point(0.35, Color(1, 1, 1, 0.45))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		_glow_tex = tex
	return _glow_tex


## Material aditivo compartido (halos de luz, chispas).
static func additive_material() -> CanvasItemMaterial:
	if _add_material == null:
		_add_material = CanvasItemMaterial.new()
		_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_material


## Sprite de halo aditivo listo para añadir como hijo.
static func make_glow(color: Color, radius: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_texture()
	s.material = additive_material()
	s.modulate = color
	s.scale = Vector2.ONE * (radius * 2.0 / 128.0)
	return s


## Polígono relleno con contorno antialiasado.
static func outlined_poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline: Color = OUTLINE, width: float = 3.0) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, fill)
	if width > 0.0 and outline.a > 0.0:
		ci.draw_polyline(closed(pts), outline, width, true)


## Polígono a dos tonos: base en sombra y la parte iluminada desplazada hacia la luz.
## Da volumen barato sin texturas (el borde inferior/derecho queda en sombra).
static func shaded_poly(ci: CanvasItem, pts: PackedVector2Array, lit: Color, shade: Color, light_offset: Vector2 = Vector2(-4, -5), outline: Color = OUTLINE, width: float = 3.0) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, shade)
	# La intersección de una forma simple con su copia desplazada no tiene agujeros.
	# Se cachea: casi todas las piezas son constantes en espacio local (el movimiento va en draw_set_transform)
	var key := hash(pts) ^ hash(light_offset)
	var parts: Array = _lit_cache.get(key, [])
	if parts.is_empty():
		parts = Geometry2D.intersect_polygons(pts, offset_pts(pts, light_offset))
		if _lit_cache.size() >= LIT_CACHE_MAX:
			_lit_cache.clear()  # las piezas animadas (capa, hoja) generan claves nuevas: poda simple
		_lit_cache[key] = parts
	for part in parts:
		if part.size() >= 3:
			ci.draw_colored_polygon(part, lit)
	if width > 0.0 and outline.a > 0.0:
		ci.draw_polyline(closed(pts), outline, width, true)


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if pts.size() > 0:
		out.append(pts[0])
	return out


static func offset_pts(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + off
	return out


static func xform_pts(pts: PackedVector2Array, xf: Transform2D) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = xf * pts[i]
	return out


## Escala respecto a un pivote (útil para squash & stretch por pieza).
static func scale_pts(pts: PackedVector2Array, pivot: Vector2, s: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pivot + (pts[i] - pivot) * s
	return out


static func regular_poly(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := rotation + TAU * float(i) / float(sides)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


static func ellipse_pts(center: Vector2, rx: float, ry: float, segments: int = 20, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rot := Transform2D(rotation, Vector2.ZERO)
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + rot * Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func rounded_rect_pts(rect: Rect2, radius: float, corner_segments: int = 4) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI * 0.5],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5],
		[rect.position + Vector2(r, r), PI],
	]
	for c in corners:
		var center: Vector2 = c[0]
		var start: float = c[1]
		for i in corner_segments + 1:
			var a := start + (PI * 0.5) * float(i) / float(corner_segments)
			pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Arco de puerta: rectángulo con remate semicircular (coordenadas: base en y=bottom).
static func arch_pts(center_x: float, bottom: float, width: float, height: float, segments: int = 14) -> PackedVector2Array:
	var hw := width * 0.5
	var spring := bottom - height + hw  # altura donde arranca el semicírculo
	var pts := PackedVector2Array()
	pts.append(Vector2(center_x - hw, bottom))
	pts.append(Vector2(center_x - hw, spring))
	for i in range(1, segments):
		var a := PI + PI * float(i) / float(segments)
		pts.append(Vector2(center_x, spring) + Vector2(cos(a), sin(a)) * hw)
	pts.append(Vector2(center_x + hw, spring))
	pts.append(Vector2(center_x + hw, bottom))
	return pts


## Media luna (arco de corte): entre dos radios y dos ángulos.
static func crescent_pts(center: Vector2, r_outer: float, r_inner: float, a0: float, a1: float, segments: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := lerpf(a0, a1, float(i) / float(segments))
		pts.append(center + Vector2(cos(a), sin(a)) * r_outer)
	# Borde interior: el grosor máximo está en el centro y se afila en los extremos
	for i in range(segments - 1, 0, -1):
		var t := float(i) / float(segments)
		var a := lerpf(a0, a1, t)
		var r := lerpf(r_outer, r_inner, sin(t * PI))
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Ojo con esclerótica, pupila que mira a `look` (vector normalizado) y parpadeo (0 abierto, 1 cerrado).
static func eye(ci: CanvasItem, center: Vector2, radius: float, look: Vector2, blink: float = 0.0, sclera: Color = Color(1, 1, 1), pupil: Color = OUTLINE, glow: bool = false) -> void:
	var open := clampf(1.0 - blink, 0.08, 1.0)
	if glow:
		ci.draw_circle(center, radius * 1.9, Color(sclera.r, sclera.g, sclera.b, 0.18 * open))
	ci.draw_colored_polygon(ellipse_pts(center, radius, radius * open, 14), sclera)
	if open > 0.3 and pupil.a > 0.0:
		var p := center + look.limit_length(1.0) * radius * 0.38
		ci.draw_colored_polygon(ellipse_pts(p, radius * 0.5, radius * 0.5 * open, 10), pupil)


## Rombo (diamante) centrado.
static func diamond_pts(center: Vector2, half_w: float, half_h: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -half_h),
		center + Vector2(half_w, 0),
		center + Vector2(0, half_h),
		center + Vector2(-half_w, 0),
	])


## Estrella de n puntas (chispas de crítico, destellos).
static func star_pts(center: Vector2, r_outer: float, r_inner: float, points: int = 4, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := r_outer if i % 2 == 0 else r_inner
		var a := rotation + PI * float(i) / float(points)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Degradado vertical en un rectángulo (colores por vértice).
static func v_gradient(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	])
	ci.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


## Polígono con degradado vertical (color por vértice según su altura).
static func v_gradient_poly(ci: CanvasItem, pts: PackedVector2Array, top_y: float, bottom_y: float, top: Color, bottom: Color) -> void:
	if pts.size() < 3:
		return
	var cols := PackedColorArray()
	cols.resize(pts.size())
	var span := maxf(1.0, bottom_y - top_y)
	for i in pts.size():
		cols[i] = top.lerp(bottom, clampf((pts[i].y - top_y) / span, 0.0, 1.0))
	ci.draw_polygon(pts, cols)


## Color con alfa multiplicado.
static func fade(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)
