class_name StickerSprites
extends RefCounted

## Cuatro estados independientes: reposo, ataque, daño y derrota.
## Convierte las hojas 2×2 en una tira para Sprite2D, sin interpolar poses.
## Si existe art/stickers/poses/<clave>.png (tools/art/split_poses.py) se usa esa tira: allí cada pose va entera, aunque se
## salga de su cuarto en la hoja (la espada de Tico, el brazo del golem). Recortar por cuartos la cortaba y el trozo
## aparecía por el borde de la pose vecina. En la tira, el cuarto ocupa CELL_PX centrado en un fotograma con margen.
const ROOT := "res://art/stickers/sources/characters/"
const POSES := "res://art/stickers/poses/"
const CELL_PX := 320  ## lado mayor del cuarto en la tira (split_poses.py)
static var _cache: Dictionary = {}

static func pose_index(alive: bool, hurt: float, strike: float) -> int:
	if not alive:
		return 3
	if hurt > 0.0:
		return 2
	return 1 if strike > 0.0 else 0

static func sheet(key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var strip := _pose_strip(key)
	if not strip.is_empty():
		_cache[key] = strip
		return strip
	var path := ROOT + key + ".png"
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return {}
	var source: Image
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture:
			source = texture.get_image()
	else:
		source = Image.load_from_file(path)
	if source == null or source.is_empty():
		return {}
	var cell := Vector2i(source.get_width() / 2, source.get_height() / 2)
	# A resolución móvil una pose de 320 px conserva detalle y limita la memoria del atlas.
	var frame_px := mini(320, maxi(cell.x, cell.y))
	var atlas := Image.create(frame_px * 4, frame_px, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for pose in 4:
		var region := source.get_region(Rect2i(Vector2i(pose % 2, pose / 2) * cell, cell))
		region.resize(frame_px, frame_px, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(region, Rect2i(Vector2i.ZERO, Vector2i.ONE * frame_px), Vector2i(pose * frame_px, 0))
	var idle_rect := atlas.get_region(Rect2i(0, 0, frame_px, frame_px)).get_used_rect()
	var result := {"texture": ImageTexture.create_from_image(atlas), "frames": 4, "frame_px": frame_px, "cell_px": frame_px, "margin": 0.0, "idle_rect": idle_rect}
	_cache[key] = result
	return result


## La tira ya separada de art/stickers/poses, o {} si no está. El cuarto mide CELL_PX y va centrado: el margen de cada
## lado es (fotograma - CELL_PX) / 2.
static func _pose_strip(key: String) -> Dictionary:
	var path := POSES + key + ".png"
	if not ResourceLoader.exists(path):
		return {}
	var texture := load(path) as Texture2D
	if texture == null:
		return {}
	var frame_px := texture.get_width() / 4
	var image := texture.get_image()
	var idle_rect := image.get_region(Rect2i(0, 0, frame_px, frame_px)).get_used_rect() if image else Rect2i(0, 0, frame_px, frame_px)
	return {"texture": texture, "frames": 4, "frame_px": frame_px, "cell_px": CELL_PX, "margin": (frame_px - CELL_PX) * 0.5, "idle_rect": idle_rect}

static func apply(sprite: Sprite2D, key: String, logical_width: float = 36.0) -> bool:
	var data := sheet(key)
	if data.is_empty():
		return false
	sprite.texture = data.texture
	sprite.hframes = 4
	sprite.frame = 0
	# El ancho lógico es el del cuarto de la hoja, no el del fotograma con margen: el personaje mide lo mismo que antes. Sin
	# centrar, el margen se compensa para que el cuarto quede donde estaba
	sprite.scale = Vector2.ONE * logical_width / float(data.cell_px)
	sprite.offset = Vector2.ZERO if sprite.centered else -Vector2.ONE * float(data.margin)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.set_meta("sticker_key", key)
	return true

static func apply_height(sprite: Sprite2D, key: String, height: float) -> bool:
	if not apply(sprite, key):
		return false
	var data := sheet(key)
	var bounds: Rect2i = data.idle_rect
	var factor := height / maxf(1.0, bounds.size.y)
	sprite.scale = Vector2.ONE * factor
	sprite.offset = Vector2.ZERO  # la colocación la da sticker_origin, medido sobre el fotograma entero
	sprite.set_meta("sticker_origin", -Vector2(bounds.get_center().x, bounds.end.y) * factor)
	sprite.set_meta("sticker_height", height)
	return true

static func show_defeat(source: Sprite2D) -> void:
	var remains := Sprite2D.new()
	remains.centered = source.centered
	remains.offset = source.offset
	remains.texture = source.texture
	remains.hframes = 4
	remains.frame = 3
	remains.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	source.get_parent().get_parent().add_child(remains)
	remains.global_transform = source.global_transform
	remains.z_index = source.get_parent().z_index
	var tween := remains.create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(remains, "modulate:a", 0.0, 0.25)
	tween.tween_callback(remains.queue_free)
