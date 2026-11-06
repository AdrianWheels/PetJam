class_name Sfx
extends RefCounted

## Librería de SFX generados (doc/sfx/petjam_sfx_events.json → art/sounds/sfx/generated/).
## Uso: Sfx.play(&"enemy_shatter")  — elige variante al azar en los pools y varía un poco el tono.
## Los niveles relativos ya vienen horneados en los WAV (mix budget del catálogo); aquí solo se
## aplica una ganancia común a toda la librería y, si acaso, un ajuste fino por llamada.

const BASE_PATH := "res://art/sounds/sfx/generated/"
## Los WAV salen normalizados a -20 LUFS (menos su jerarquía); en el juego quedaban ~5 dB por
## debajo de los golpes de espada existentes. Esta ganancia los iguala sin acercar picos a 0 dBFS.
const GLOBAL_GAIN_DB := 4.0

## id → [carpeta, variantes (1 = one-shot), variación de tono]
const LIBRARY := {
	&"enemy_shatter": ["combat", 3, 0.08],
	&"boss_appear": ["combat", 1, 0.0],
	&"boss_defeated": ["feedback", 1, 0.0],
	&"hero_fall": ["combat", 1, 0.03],
	&"hero_respawn": ["feedback", 1, 0.02],
	&"loot_coins": ["feedback", 3, 0.06],
	&"blueprint_found": ["feedback", 1, 0.0],
	&"biome_enter": ["ambience", 1, 0.0],
	&"wraith_orb": ["combat", 3, 0.07],
	&"golem_slam": ["combat", 3, 0.06],
	&"equip_clink": ["ui", 1, 0.05],
	&"request_accept": ["ui", 1, 0.05],
	&"ui_tap": ["ui", 1, 0.08],
}

static var _cache: Dictionary = {}
static var _last_variant: Dictionary = {}


## Reproduce un evento de la librería. volume_db es un ajuste fino sobre el nivel horneado.
static func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _pick(id)
	if stream == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var am := tree.root.get_node_or_null("AudioManager")
	if am == null:
		return
	var variance: float = LIBRARY[id][2] if LIBRARY.has(id) else 0.0
	if am.has_method("play_sfx_pitched"):
		am.play_sfx_pitched(stream, volume_db + GLOBAL_GAIN_DB, pitch, variance)
	else:
		am.play_sfx(stream, volume_db + GLOBAL_GAIN_DB)


static func _pick(id: StringName) -> AudioStream:
	if not LIBRARY.has(id):
		return null
	var streams: Array = _load(id)
	if streams.is_empty():
		return null
	if streams.size() == 1:
		return streams[0]
	# Round-robin aleatorio sin repetir la última variante
	var last: int = _last_variant.get(id, -1)
	var idx := randi() % streams.size()
	if idx == last:
		idx = (idx + 1) % streams.size()
	_last_variant[id] = idx
	return streams[idx]


static func _load(id: StringName) -> Array:
	if _cache.has(id):
		return _cache[id]
	var info: Array = LIBRARY[id]
	var folder: String = info[0]
	var count: int = info[1]
	var out: Array = []
	if count <= 1:
		var path := "%s%s/%s.wav" % [BASE_PATH, folder, id]
		if ResourceLoader.exists(path):
			out.append(load(path))
	else:
		for i in count:
			var path := "%s%s/%s_%d.wav" % [BASE_PATH, folder, id, i + 1]
			if ResourceLoader.exists(path):
				out.append(load(path))
	_cache[id] = out
	return out
