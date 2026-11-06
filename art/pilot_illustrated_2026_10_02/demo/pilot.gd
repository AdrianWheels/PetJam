extends Control
## Escena de revisión del lote ilustrado. No altera la partida ni el catálogo.

const INK := Color("e5d6bd")
const MUTED := Color("a89e90")
const GOLD := Color("caa26b")
const CELL := 110.0
const SHAPES := {
	"sword_basic": [Vector2i(0, 0), Vector2i(0, 1)],
	"hammer_fit": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
}

var _textures: Dictionary = {}
var _regions: Dictionary = {}
var _rot := 0
var _quality := 0
var _show_cells := true
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	for file in ["sword_basic", "hammer_fit", "tico", "skeleton", "catacombs", "forge"]:
		var path := ProjectSettings.globalize_path("res://../%s.png" % file)
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			push_error("No se puede cargar %s" % path)
			get_tree().quit(1)
			return
		_textures[file] = ImageTexture.create_from_image(image)
		_regions[file] = Rect2(image.get_used_rect())
	_button("Girar piezas", Vector2(54, 1770), _rotate)
	_button("Ver casillas", Vector2(378, 1770), _toggle_cells)
	_button("Cambiar calidad", Vector2(702, 1770), _cycle_quality)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rotation="):
			_rot = posmod(int(arg.trim_prefix("--rotation=")), 4)
	queue_redraw()
	for arg in OS.get_cmdline_user_args():
		if arg == "--verify":
			for r in 4:
				_rot = r
				queue_redraw()
				await get_tree().process_frame
			print("PILOT_OK: 6 assets cargados; 4 giros revisados")
			get_tree().quit()
		elif arg.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var path := arg.trim_prefix("--capture=")
			var err := get_viewport().get_texture().get_image().save_png(path)
			print("PILOT_CAPTURE: %s error=%s" % [path, err])
			get_tree().quit(0 if err == OK else 1)


func _button(title: String, pos: Vector2, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.position = pos
	button.size = Vector2(294, 76)
	button.add_theme_font_size_override("font_size", 25)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("352b28")
	style.border_color = Color("78604c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", INK)
	button.pressed.connect(action)
	add_child(button)


func _rotate() -> void:
	_rot = posmod(_rot + 1, 4)
	queue_redraw()


func _toggle_cells() -> void:
	_show_cells = not _show_cells
	queue_redraw()


func _cycle_quality() -> void:
	_quality = posmod(_quality + 1, 3)
	queue_redraw()


func _text(value: String, pos: Vector2, font_size: int = 28, color: Color = INK) -> void:
	draw_string(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _panel(rect: Rect2) -> void:
	draw_style_box(_panel_style(), rect)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("231e1d")
	style.border_color = Color("56473c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style


func _art(key: String, box: Rect2, tint: Color = Color.WHITE) -> void:
	var region: Rect2 = _regions[key]
	var ratio := minf(box.size.x / region.size.x, box.size.y / region.size.y)
	var size := region.size * ratio
	var dest := Rect2(box.position + (box.size - size) * 0.5, size)
	draw_texture_rect_region(_textures[key], dest, region, tint)


func _piece(key: String, origin: Vector2) -> void:
	var points: Array[Vector2i] = []
	for cell: Vector2i in SHAPES[key]:
		var rotated := cell
		for turn in _rot:
			rotated = Vector2i(-rotated.y, rotated.x)
		points.append(rotated)
	var low := points[0]
	var high := points[0]
	for point in points:
		low = low.min(point)
		high = high.max(point)
	var bounds := Vector2(high - low + Vector2i.ONE) * CELL
	var quality_color: Color = [Color("9d978c"), Color("9473af"), GOLD][_quality]
	if _show_cells:
		for point in points:
			var rect := Rect2(origin + Vector2(point - low) * CELL, Vector2.ONE * CELL)
			draw_rect(rect.grow(-4), Color("171515"))
			draw_rect(rect.grow(-4), quality_color, false, 3)
	# Rotate the whole source without cutting off any part to force its footprint.
	var base_region: Rect2 = _regions[key]
	var source_size := base_region.size
	if _rot % 2 == 1:
		source_size = Vector2(source_size.y, source_size.x)
	var scale_factor := minf((bounds.x - 16) / source_size.x, (bounds.y - 16) / source_size.y)
	draw_set_transform(origin + bounds * 0.5, _rot * PI * 0.5)
	draw_texture_rect_region(_textures[key], Rect2(-base_region.size * scale_factor * 0.5, base_region.size * scale_factor), base_region)
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	if _textures.is_empty():
		return
	draw_rect(Rect2(0, 0, 1080, 1920), Color("141313"))
	_text("PETJAM", Vector2(54, 91), 56)
	_text("MUESTRA DE ARTE · 01", Vector2(54, 137), 25, GOLD)
	_text("CATACUMBAS", Vector2(750, 130), 23, MUTED)
	draw_texture_rect(_textures["catacombs"], Rect2(0, 176, 1080, 430), false)
	_art("tico", Rect2(174, 242, 338, 338))
	_art("skeleton", Rect2(623, 256, 316, 316))
	_text("TICO", Vector2(252, 235), 22)
	_text("ESQUELETO", Vector2(704, 242), 22)
	draw_rect(Rect2(246, 245, 108, 7), Color("7a9f75"))
	draw_rect(Rect2(701, 252, 108, 7), Color("b26c62"))
	_panel(Rect2(42, 630, 996, 500))
	_text("EQUIPO", Vector2(68, 679), 32)
	_text("Forma y dibujo, a 110 px por casilla", Vector2(68, 719), 23, MUTED)
	_piece("sword_basic", Vector2(142, 754))
	_piece("hammer_fit", Vector2(451, 754))
	_text("Espada · 2 casillas", Vector2(85, 1110), 23)
	_text("Martillo · 4 casillas", Vector2(476, 1110), 23)
	_panel(Rect2(42, 1150, 996, 550))
	_text("TALLER", Vector2(68, 1201), 32)
	_text("Mismos materiales, misma dirección de arte", Vector2(68, 1239), 23, MUTED)
	draw_texture_rect(_textures["forge"], Rect2(62, 1266, 572, 382), false)
	# A quiet thumbnail of the result beside its workshop; it is not a gameplay QTE.
	_art("hammer_fit", Rect2(687, 1315, 283, 218))
	_text("Martillo de hierro", Vector2(687, 1576), 25)
	_text("Metal gastado", Vector2(687, 1615), 23, MUTED)
	_text("Cuero mate", Vector2(687, 1649), 23, MUTED)
	_text("Trazo dibujado · paleta apagada · siluetas claras", Vector2(54, 1742), 25, GOLD)
	_text("Escena de revisión · personajes en una pose", Vector2(54, 1889), 23, MUTED)
