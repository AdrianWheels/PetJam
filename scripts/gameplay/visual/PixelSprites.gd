class_name PixelSprites
extends RefCounted

## Sprites pixel del juego y sus medidas. Los genera tools/pixel_art/export.py en art/sprites/pixel/.
## Claves: "hero/tico_0", "enemies/slime", "bosses/boss_0"…

const ROOT := "res://art/sprites/pixel/"
const BOSS_COUNT := 5

static var _metrics: Dictionary = {}
static var _textures: Dictionary = {}


## Medidas de la tira (ver tools/pixel_art/game_assets.py). Diccionario vacío si la clave no existe.
static func metrics(key: String) -> Dictionary:
	if _metrics.is_empty():
		var res := load(ROOT + "metrics.json") as JSON
		if res == null:
			push_error("PixelSprites: falta %smetrics.json (ejecuta python tools/pixel_art/export.py)" % ROOT)
			return {}
		_metrics = res.data
	return _metrics.get(key, {})


static func texture(key: String) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = load(ROOT + key + ".png")
	return _textures[key]


## Clave del sprite de un enemigo: el jefe es el de su bioma (ciclan igual que los biomas).
static func enemy_key(archetype: StringName, level: int) -> String:
	if archetype == &"boss":
		return "bosses/boss_%d" % posmod(Biomes.biome_index_for_room(level), BOSS_COUNT)
	return "enemies/%s" % String(archetype)
