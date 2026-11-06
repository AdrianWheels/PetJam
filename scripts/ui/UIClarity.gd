class_name UIClarity
extends RefCounted

const TITLE_FONT := preload("res://art/font/PirataOne-Regular.ttf")
const TITLE_GOLD := Color(0.91, 0.72, 0.29)

static func readable_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 30
	return theme

static func light_button(button: Button, icon_width: int = 120) -> void:
	button.add_theme_font_override("font", ThemeDB.fallback_font)
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color("fff2df"))
	button.add_theme_color_override("font_disabled_color", Color("cbbba7"))
	button.add_theme_constant_override("icon_max_width", icon_width)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 0.83, 0.55, 0.10 if state in ["hover", "pressed"] else 0.0)
		style.set_content_margin_all(8)
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state, style)

## Título de panel (Tienda, Equipo, Biblioteca de planos): la letra del juego en oro, como el logo y los carteles. Cada
## panel tenía el suyo (mayúsculas sin adorno, blanco grande, oro gótico) y no parecían del mismo juego.
static func panel_title(label: Label) -> void:
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", TITLE_GOLD)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.02))
	label.add_theme_constant_override("outline_size", 8)

## Botón de cerrar de los paneles: la misma «X» en todos, cuadrada y grande para el dedo (88 px).
static func close_button(button: Button) -> void:
	button.text = "X"
	button.custom_minimum_size = Vector2(88, 88)
	button.add_theme_font_override("font", ThemeDB.fallback_font)
	button.add_theme_font_size_override("font_size", 38)
	button.add_theme_color_override("font_color", Color("fff2df"))

static func compact_panel(panel: Control) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.075, 0.06, 0.9)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)

static func readable_labels(root: Node, minimum: int = 28) -> void:
	if root is Label:
		root.add_theme_font_override("font", ThemeDB.fallback_font)
		root.add_theme_font_size_override("font_size", maxi(minimum, root.get_theme_font_size("font_size")))
		root.add_theme_color_override("font_color", Color("fff3df"))
		root.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.01))
		root.add_theme_constant_override("outline_size", 3)
	for child in root.get_children():
		readable_labels(child, minimum)
