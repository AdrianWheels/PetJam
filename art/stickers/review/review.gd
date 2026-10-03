extends Control

const CATEGORIES := ["characters", "gear", "materials", "potions", "backgrounds", "stations", "tools", "ui", "screens"]
var root_path: String
var records: Array
var category := 1
var page := 0
var _textures: Dictionary = {}
var _capture := ""

func _ready() -> void:
	root_path = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/").get_base_dir().get_base_dir().get_base_dir()
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root_path + "/doc/arte/inventario-produccion.json"))
	records = inventory.records
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--category="):
			category = CATEGORIES.find(arg.trim_prefix("--category="))
		elif arg.begins_with("--page="):
			page = int(arg.trim_prefix("--page="))
		elif arg.begins_with("--capture="):
			_capture = arg.trim_prefix("--capture=")
	category = maxi(category, 0)
	for i in 3:
		var button := Button.new()
		button.text = ["◀ Categoría", "Página siguiente", "Categoría ▶"][i]
		button.position = Vector2(30 + i * 350, 1790)
		button.size = Vector2(320, 90)
		button.add_theme_font_size_override("font_size", 25)
		button.pressed.connect(_navigate.bind(i))
		add_child(button)
	queue_redraw()
	if not _capture.is_empty():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(_capture)
		print("ART_CATALOG_CAPTURE: ", error, " ", _capture)
		get_tree().quit()

func _navigate(direction: int) -> void:
	if direction == 1:
		page += 1
	else:
		category = posmod(category + (-1 if direction == 0 else 1), CATEGORIES.size())
		page = 0
	queue_redraw()

func _texture(source: String) -> Texture2D:
	if not _textures.has(source):
		var image := Image.load_from_file(root_path + "/" + source)
		_textures[source] = ImageTexture.create_from_image(image) if image else null
	return _textures[source]

func _draw() -> void:
	if records.is_empty():
		return
	var font := ThemeDB.fallback_font
	var rows := records.filter(func(r): return r.category == CATEGORIES[category])
	var columns := 2 if category in [0, 4, 8] else 4
	var per_page := 6 if category in [0, 4] else (2 if category == 8 else 20)
	var pages := maxi(1, ceili(float(rows.size()) / per_page))
	page = posmod(page, pages)
	draw_string(font, Vector2(35, 55), "PETJAM / " + CATEGORIES[category].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("eedcc1"))
	draw_string(font, Vector2(35, 95), "%d recursos · página %d/%d · originales sin alterar" % [rows.size(), page + 1, pages], HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("bca88e"))
	var cell_size := Vector2(500, 510) if columns == 2 else Vector2(250, 310)
	if category == 8:
		cell_size.y = 1580
	for index in mini(per_page, rows.size() - page * per_page):
		var entry: Dictionary = rows[page * per_page + index]
		var position := Vector2(30, 135) + Vector2(index % columns, index / columns) * (cell_size + Vector2(10, 20))
		var image_rect := Rect2(position, cell_size - Vector2(0, 60))
		draw_style_box(_panel(), Rect2(position, cell_size))
		# Damero oscuro: permite comprobar halos y transparencia en cada recurso.
		for y in ceili(image_rect.size.y / 25.0):
			for x in ceili(image_rect.size.x / 25.0):
				var tile := Rect2(image_rect.position + Vector2(x, y) * 25, Vector2(25, 25)).intersection(image_rect)
				draw_rect(tile, Color("312b29") if (x + y) % 2 == 0 else Color("252322"))
		var tex := _texture(entry.source)
		if tex:
			var ratio := minf(image_rect.size.x / tex.get_width(), image_rect.size.y / tex.get_height())
			var size := tex.get_size() * ratio * 0.95
			draw_texture_rect(tex, Rect2(image_rect.get_center() - size * 0.5, size), false)
		var label: String = String(entry.id).get_file()
		draw_string(font, position + Vector2(12, cell_size.y - 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("eedcc1"))
		draw_string(font, position + Vector2(12, cell_size.y - 8), "activo" if entry.active else "arma futura", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("bca88e"))

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("181513")
	style.set_border_width_all(2)
	style.border_color = Color("806449")
	return style
