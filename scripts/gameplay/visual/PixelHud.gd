class_name PixelHud
extends RefCounted

## Piezas de HUD pixel que comparten Tico y los enemigos: barra de vida, sombra e icono de armadura.
## Todo en píxeles enteros del arte, sin antialiasing.

const OUTLINE := Color("241826")
const EMPTY := Color("3a2a30")
const GHOST := Color("fff3a8")


## Barra de vida con borde oscuro de 1 px, daño fantasma y brillo en la fila superior.
static func draw_bar(ci: CanvasItem, rect: Rect2, ratio: float, ghost: float, fill: Color, alpha: float = 1.0) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	ci.draw_rect(r.grow(1.0), _a(OUTLINE, alpha))
	ci.draw_rect(r, _a(EMPTY, alpha))
	var ghost_w := roundf(r.size.x * clampf(ghost, 0.0, 1.0))
	var fill_w := roundf(r.size.x * clampf(ratio, 0.0, 1.0))
	if ghost_w > fill_w:
		ci.draw_rect(Rect2(r.position, Vector2(ghost_w, r.size.y)), _a(GHOST, alpha))
	if fill_w > 0.0:
		ci.draw_rect(Rect2(r.position, Vector2(fill_w, r.size.y)), _a(fill, alpha))
		ci.draw_rect(Rect2(r.position, Vector2(fill_w, 1.0)), _a(fill.lightened(0.35), alpha))


## Sombra de dos filas sobre el suelo, centrada en los pies (`center`).
static func draw_shadow(ci: CanvasItem, center: Vector2, width: int, alpha: float = 1.0) -> void:
	var c := Color(0, 0, 0, 0.35 * alpha)
	var x := roundf(center.x - width * 0.5)
	ci.draw_rect(Rect2(x, center.y, width, 1.0), c)
	ci.draw_rect(Rect2(x + 2.0, center.y + 1.0, maxf(1.0, width - 4.0), 1.0), c)


## Escudo de 4x4 píxeles con su esquina superior izquierda en `pos`.
static func draw_armor_icon(ci: CanvasItem, pos: Vector2, alpha: float = 1.0, color: Color = Color("b3bdca")) -> void:
	var p := pos.round()
	ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(6, 6)), _a(OUTLINE, alpha))
	ci.draw_rect(Rect2(p, Vector2(4, 3)), _a(color, alpha))
	ci.draw_rect(Rect2(p + Vector2(1, 3), Vector2(2, 1)), _a(color, alpha))


static func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)
