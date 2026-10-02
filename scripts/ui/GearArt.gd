class_name GearArt
extends RefCounted

## Texturas de las piezas de la rejilla (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 9.5).
## Cada pieza con arte tiene `res://art/gear/<item_id>.png` en su giro 0, a 110 px por casilla
## (tools/gear_art/build_gear_art.py). Los otros 3 giros se sacan girando la imagen y se guardan.
## Es el `sprite_for` de GearGridView, LootBoxView y LootPiece: las piezas sin arte siguen con casillas de color.

const DIR := "res://art/gear/%s.png"

static var _cache := {}  # "<item_id>/<giro>" → Texture2D, o null si la pieza no tiene arte


static func texture_for(item: CraftedItem, rot: int) -> Texture2D:
	if item == null or item.item_resource == null:
		return null
	var id := String(item.item_resource.item_id)
	var r := posmod(rot, 4)
	var key := "%s/%d" % [id, r]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	var path := DIR % id
	if ResourceLoader.exists(path):
		var base: Texture2D = load(path)
		if r == 0:
			tex = base
		else:
			var img := base.get_image()
			if img.is_compressed():
				img.decompress()
			for i in r:
				img.rotate_90(CLOCKWISE)  # como PieceShape.rotate_raw: un cuarto de vuelta a la derecha
			tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
