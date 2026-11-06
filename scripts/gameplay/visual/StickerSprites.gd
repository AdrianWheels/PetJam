class_name StickerSprites
extends RefCounted

## Pegatinas de personaje. Si existe art/stickers/anim/<clave>.png se usa la rejilla animada: 8 fotogramas por fila y una
## fila por estado (reposo, ataque, daño y derrota; Brasa: reposo, martillo, costura y celebración), todos del mismo
## tamaño y con los pies en el mismo sitio (la genera Sprites-Lab/petjam/exportar_petjam.py). Si no, las cuatro poses
## fijas de siempre:
## Si existe art/stickers/poses/<clave>.png (tools/art/split_poses.py) se usa esa tira: allí cada pose va entera, aunque se
## salga de su cuarto en la hoja (la espada de Tico, el brazo del golem). Recortar por cuartos la cortaba y el trozo
## aparecía por el borde de la pose vecina. En la tira, el cuarto ocupa CELL_PX centrado en un fotograma con margen.
const ROOT := "res://art/stickers/sources/characters/"
const POSES := "res://art/stickers/poses/"
const ANIM := "res://art/stickers/anim/"
const CELL_PX := 320  ## lado mayor del cuarto en la tira (split_poses.py)
const ANIM_COLS := 8
const ANIM_ROWS := 4
enum Row { IDLE, ATTACK, HURT, DEFEAT }
const IDLE_FPS := 8.0
const HURT_FPS := 16.0
const DEFEAT_FPS := 10.0
## La animación de daño entera (8 fotogramas a HURT_FPS) y la parte del golpe que manda sobre un ataque en curso.
const HURT_ANIM_TIME := ANIM_COLS / HURT_FPS
const HURT_HOLD := 0.2
static var _cache: Dictionary = {}

static func pose_index(alive: bool, hurt: float, strike: float) -> int:
	if not alive:
		return 3
	if hurt > 0.0:
		return 2
	return 1 if strike > 0.0 else 0


## Fotograma de la rejilla animada. Derrota: avanza y se queda en la última pose. Daño: los primeros HURT_HOLD s mandan
## sobre el ataque (el golpe se nota); luego el ataque interrumpe la recuperación. Ataque: la anticipación (fotogramas
## 1-4) sigue a `windup` 0→1 y el impacto (5) cae justo cuando `strike` salta a 1, el momento del daño; la inercia
## (6-8) sigue a `strike` 1→0. Reposo: en bucle con `clock`.
static func anim_frame(alive: bool, clock: float, since_defeat: float, since_hurt: float, windup: float, strike: float) -> int:
	if not alive:
		return Row.DEFEAT * ANIM_COLS + mini(ANIM_COLS - 1, int(since_defeat * DEFEAT_FPS))
	if since_hurt < HURT_HOLD:
		return Row.HURT * ANIM_COLS + mini(ANIM_COLS - 1, int(since_hurt * HURT_FPS))
	if strike > 0.0:
		return Row.ATTACK * ANIM_COLS + 4 + mini(3, int((1.0 - strike) * 4.0))
	if windup > 0.0:
		return Row.ATTACK * ANIM_COLS + mini(3, int(windup * 4.0))
	if since_hurt < HURT_ANIM_TIME:
		return Row.HURT * ANIM_COLS + mini(ANIM_COLS - 1, int(since_hurt * HURT_FPS))
	return Row.IDLE * ANIM_COLS + int(clock * IDLE_FPS) % ANIM_COLS


## El fotograma que toca a una pegatina ya aplicada: rejilla animada si la tiene, pose fija si no.
static func frame_for(sprite: Sprite2D, alive: bool, clock: float, since_defeat: float, since_hurt: float, hurt: float, windup: float, strike: float) -> int:
	if sprite.get_meta("sticker_animated", false):
		return anim_frame(alive, clock, since_defeat, since_hurt, windup, strike)
	return pose_index(alive, hurt, strike)


static func sheet(key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var grid := _anim_grid(key)
	if not grid.is_empty():
		_cache[key] = grid
		return grid
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
	var result := {"texture": ImageTexture.create_from_image(atlas), "frames": 4, "rows": 1, "frame_px": frame_px, "frame_size": Vector2i(frame_px, frame_px), "cell_px": frame_px, "margin": 0.0, "idle_rect": idle_rect}
	_cache[key] = result
	return result


## La rejilla animada de art/stickers/anim, o {} si no está. idle_rect es lo que ocupa el primer fotograma del reposo: con
## él se mide y se coloca al personaje, y vale para todos porque comparten tamaño y ancla.
static func _anim_grid(key: String) -> Dictionary:
	var path := ANIM + key + ".png"
	if not ResourceLoader.exists(path):
		return {}
	var texture := load(path) as Texture2D
	if texture == null:
		return {}
	var size := Vector2i(texture.get_width() / ANIM_COLS, texture.get_height() / ANIM_ROWS)
	var image := texture.get_image()
	var idle_rect := image.get_region(Rect2i(Vector2i.ZERO, size)).get_used_rect() if image else Rect2i(Vector2i.ZERO, size)
	return {"texture": texture, "frames": ANIM_COLS, "rows": ANIM_ROWS, "frame_px": size.x, "frame_size": size, "cell_px": size.x, "margin": 0.0, "idle_rect": idle_rect, "animated": true}


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
	return {"texture": texture, "frames": 4, "rows": 1, "frame_px": frame_px, "frame_size": Vector2i(frame_px, frame_px), "cell_px": CELL_PX, "margin": (frame_px - CELL_PX) * 0.5, "idle_rect": idle_rect}

static func _bind(sprite: Sprite2D, key: String, data: Dictionary) -> void:
	sprite.texture = data.texture
	sprite.hframes = data.frames
	sprite.vframes = data.rows
	sprite.frame = 0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.set_meta("sticker_key", key)
	sprite.set_meta("sticker_animated", data.get("animated", false))

static func apply(sprite: Sprite2D, key: String, logical_width: float = 36.0) -> bool:
	var data := sheet(key)
	if data.is_empty():
		return false
	_bind(sprite, key, data)
	# La colocación se calcula con las poses de siempre (el ancho lógico es el del cuarto de la hoja, no el del fotograma
	# con margen) para que el personaje mida lo mismo y pise donde pisaba. Sin centrar, el margen se compensa para que el
	# cuarto quede donde estaba
	var fit: Dictionary = _pose_strip(key) if data.get("animated", false) else {}
	var refit := not fit.is_empty()
	if not refit:
		fit = data
	var fit_scale := logical_width / float(fit.cell_px)
	var fit_offset := Vector2.ZERO if sprite.centered else -Vector2.ONE * float(fit.margin)
	sprite.scale = Vector2.ONE * fit_scale
	sprite.offset = fit_offset
	if not refit:
		return true
	# Rejilla animada: misma altura en reposo y los mismos pies que la pose fija
	var old_rect: Rect2i = fit.idle_rect
	var new_rect: Rect2i = data.idle_rect
	var old_feet := fit_offset + _feet(old_rect) - (Vector2(fit.frame_size) * 0.5 if sprite.centered else Vector2.ZERO)
	var new_scale := old_rect.size.y * fit_scale / maxf(1.0, new_rect.size.y)
	sprite.scale = Vector2.ONE * new_scale
	sprite.offset = old_feet * fit_scale / new_scale - _feet(new_rect) + (Vector2(data.frame_size) * 0.5 if sprite.centered else Vector2.ZERO)
	return true

static func _feet(rect: Rect2i) -> Vector2:
	return Vector2(rect.get_center().x, rect.end.y)

static func apply_height(sprite: Sprite2D, key: String, height: float) -> bool:
	var data := sheet(key)
	if data.is_empty():
		return false
	_bind(sprite, key, data)
	var bounds: Rect2i = data.idle_rect
	var factor := height / maxf(1.0, bounds.size.y)
	sprite.scale = Vector2.ONE * factor
	sprite.offset = Vector2.ZERO  # la colocación la da sticker_origin, medido sobre el fotograma entero
	sprite.set_meta("sticker_origin", -_feet(bounds) * factor)
	sprite.set_meta("sticker_height", height)
	return true

## Lo que queda del enemigo al caer: con rejilla animada, la derrota entera y luego se desvanece; sin ella, la pose fija.
static func show_defeat(source: Sprite2D) -> void:
	var remains := Sprite2D.new()
	remains.centered = source.centered
	remains.offset = source.offset
	remains.texture = source.texture
	remains.hframes = source.hframes
	remains.vframes = source.vframes
	var animated: bool = source.get_meta("sticker_animated", false)
	remains.frame = Row.DEFEAT * ANIM_COLS if animated else 3
	remains.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	source.get_parent().get_parent().add_child(remains)
	remains.global_transform = source.global_transform
	remains.z_index = source.get_parent().z_index
	var tween := remains.create_tween()
	if animated:
		var first := Row.DEFEAT * ANIM_COLS
		tween.tween_method(func(f: float) -> void: remains.frame = first + mini(ANIM_COLS - 1, int(f)), 0.0, float(ANIM_COLS), ANIM_COLS / DEFEAT_FPS)
		tween.tween_interval(0.3)
	else:
		tween.tween_interval(0.35)
	tween.tween_property(remains, "modulate:a", 0.0, 0.25)
	tween.tween_callback(remains.queue_free)
