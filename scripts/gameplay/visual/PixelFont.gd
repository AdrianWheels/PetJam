class_name PixelFont
extends RefCounted

## Fuentes pixel de la franja (BMFont que genera tools/pixel_art/fonts.py en art/font/pixel/).
## Solo tienen mayúsculas: el texto se convierte al pintarlo. El contorno oscuro va dentro del glifo,
## así que sirven con cualquier color de texto. Se dibujan a su tamaño o a múltiplos enteros.

const SMALL_PATH := "res://art/font/pixel/pixel_small.fnt"
const BIG_PATH := "res://art/font/pixel/pixel_big.fnt"
const SMALL_SIZE := 9  ## alto de línea de la pequeña (contorno + 2 filas de tilde + 5 + contorno)
const BIG_SIZE := 11  ## alto de línea de la grande (contorno + 2 + 7 + contorno)

static var _small: FontFile
static var _big: FontFile


static func small() -> FontFile:
	if _small == null:
		_small = _load(SMALL_PATH)
	return _small


static func big() -> FontFile:
	if _big == null:
		_big = _load(BIG_PATH)
	return _big


static func _load(path: String) -> FontFile:
	var f := load(path) as FontFile
	if f == null:
		push_error("PixelFont: falta %s (ejecuta python tools/pixel_art/export.py)" % path)
		return null
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	if "modulate_color_glyphs" in f:
		f.modulate_color_glyphs = true  # el trazo blanco toma el color del texto
	return f


static func font(is_big: bool) -> FontFile:
	return big() if is_big else small()


static func line_size(is_big: bool) -> int:
	return BIG_SIZE if is_big else SMALL_SIZE


## Ancho en píxeles del arte a escala 1.
static func width(text: String, is_big: bool = false) -> int:
	return int(font(is_big).get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, line_size(is_big)).x)


## Pinta el texto con su esquina superior izquierda en `pos` (redondeada a píxel entero).
static func draw(ci: CanvasItem, pos: Vector2, text: String, color: Color, alpha: float = 1.0, is_big: bool = false, scale: int = 1) -> void:
	var f := font(is_big)
	var size := line_size(is_big) * scale
	var c := Color(color.r, color.g, color.b, color.a * alpha)
	ci.draw_string(f, pos.round() + Vector2(0, f.get_ascent(size)), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## Como draw(), centrado en x sobre `top_center`.
static func draw_centered(ci: CanvasItem, top_center: Vector2, text: String, color: Color, alpha: float = 1.0, is_big: bool = false, scale: int = 1) -> void:
	var w := width(text, is_big) * scale
	draw(ci, Vector2(roundf(top_center.x - w * 0.5), top_center.y), text, color, alpha, is_big, scale)
