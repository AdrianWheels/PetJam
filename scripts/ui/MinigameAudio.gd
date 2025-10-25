extends Node
class_name MinigameAudio

## Sistema centralizado de audio para minijuegos
## Maneja feedback sonoro consistente: Perfect, Bien, Regular, Miss
## Integrado con AudioManager contexto FORGE
## Usa MinigameSoundSet (Resource) para compartir sonidos entre minijuegos

# 🔊 SoundSet por defecto (cargar desde .tres)
static var _sound_set: MinigameSoundSet = null

# Paths de sonidos esperados (DEPRECATED - usar SoundSet)
const SOUND_PATHS := {
	"Perfect": "res://art/sounds/minigame_perfect.wav",
	"Bien": "res://art/sounds/minigame_good.wav",
	"Regular": "res://art/sounds/minigame_ok.wav",
	"Miss": "res://art/sounds/minigame_miss.wav",
	"Hit": "res://art/sounds/minigame_hit.wav",
	"Start": "res://art/sounds/minigame_start.wav",
	"Finish": "res://art/sounds/minigame_finish.wav",
}

const COOLDOWN_MS = 120

## Establece el SoundSet a usar (llamar desde autoload o main)
static func set_sound_set(sound_set: MinigameSoundSet) -> void:
	_sound_set = sound_set
	print("[MinigameAudio] SoundSet configured")

## Obtiene el SoundSet actual (carga default si no hay)
static func get_sound_set() -> MinigameSoundSet:
	if _sound_set == null:
		_sound_set = load("res://data/minigame_sounds_default.tres")
		if _sound_set:
			print("[MinigameAudio] Loaded default SoundSet")
	return _sound_set

# Variación de pitch por calidad
const PITCH_VARIATION := {
	"Perfect": {"base": 1.2, "variance": 0.05},
	"Bien": {"base": 1.0, "variance": 0.03},
	"Regular": {"base": 0.85, "variance": 0.04},
	"Miss": {"base": 0.6, "variance": 0.02},
}

# Volumen por calidad (dB)
const VOLUME_DB := {
	"Perfect": 3.0,
	"Bien": 0.0,
	"Regular": -3.0,
	"Miss": -6.0,
}

## Reproduce feedback de audio por calidad de intento
## @param quality: "Perfect", "Bien", "Regular", "Miss"
## @param position: (Opcional) Posición 2D para audio espacial en el futuro
static func play_feedback(quality: String, position: Vector2 = Vector2.ZERO) -> void:
	# Acceder al AudioManager singleton
	if not Engine.get_main_loop().root.has_node("/root/AudioManager"):
		return
	
	var am: Node = Engine.get_main_loop().root.get_node("/root/AudioManager")
	
	# Intentar obtener sonido del SoundSet
	var sound_set: MinigameSoundSet = get_sound_set()
	var sound: AudioStream = null
	
	if sound_set:
		sound = sound_set.get_feedback_sound(quality)
	
	# Fallback a placeholder si no hay sound en SoundSet
	if not sound:
		sound = load_placeholder_sound(quality)
	
	if sound:
		var volume: float = VOLUME_DB.get(quality, 0.0)
		am.play_sfx(sound, volume, am.AudioContext.FORGE)
		print("[MinigameAudio] Played feedback: %s" % quality)
	else:
		print("[MinigameAudio] No sound loaded for: %s" % quality)

## Reproduce sonido de golpe/hit genérico
static func play_hit() -> void:
	if not Engine.get_main_loop().root.has_node("/root/AudioManager"):
		return
	
	var am = Engine.get_main_loop().root.get_node("/root/AudioManager")
	var hit_sound := load("res://art/sounds/atk_sword_flesh_hit_01.wav")
	
	if hit_sound:
		am.play_sfx(hit_sound, -3.0, am.AudioContext.FORGE)

## Reproduce sonido de inicio de minijuego
static func play_start() -> void:
	if not Engine.get_main_loop().root.has_node("/root/AudioManager"):
		return
	
	# TODO: Cargar sonido de start cuando exista
	print("[MinigameAudio] Start sound (pending asset)")

## Reproduce sonido de finalización de minijuego
static func play_finish(success: bool) -> void:
	if not Engine.get_main_loop().root.has_node("/root/AudioManager"):
		return
	
	# TODO: Cargar sonidos de victoria/derrota cuando existan
	var quality := "Perfect" if success else "Miss"
	print("[MinigameAudio] Finish sound: %s (pending asset)" % quality)

## Reproduce combo sound (para racha de aciertos)
static func play_combo(combo_count: int) -> void:
	if not Engine.get_main_loop().root.has_node("/root/AudioManager"):
		return
	
	if combo_count < 3:
		return  # Solo reproducir en combos significativos
	
	var am: Node = Engine.get_main_loop().root.get_node("/root/AudioManager")
	# TODO: Cargar sonido de combo cuando exista
	# Por ahora usar hit con pitch modificado según combo
	var hit_sound: AudioStream = load("res://art/sounds/atk_sword_flesh_hit_01.wav")
	if hit_sound:
		var volume: float = min(3.0, combo_count * 0.5)
		am.play_sfx(hit_sound, volume, am.AudioContext.FORGE)

## Reproduce ticking/countdown sound
static func play_tick() -> void:
	if not Engine.get_main_loop().root.has_node("/root/AudioManager"):
		return
	
	# TODO: Sonido de tick/reloj
	pass

## Carga placeholder sound según calidad
## @param quality: "Perfect", "Bien", "Regular", "Miss"
## @return AudioStream o null
static func load_placeholder_sound(quality: String) -> AudioStream:
	# Por ahora, usar el sonido existente de hit como placeholder
	# Cuando haya assets específicos, cargar desde SOUND_PATHS
	var hit_sound := load("res://art/sounds/atk_sword_flesh_hit_01.wav")
	return hit_sound

## Versión avanzada: play_feedback con pitch control
## @param quality: Calidad del intento
## @param custom_pitch: Pitch personalizado (opcional)
## @param custom_volume: Volumen personalizado en dB (opcional)
static func play_feedback_advanced(quality: String, custom_pitch: float = 1.0, custom_volume: float = 0.0) -> void:
	# TODO: Implementar cuando se tenga control de pitch en AudioStreamPlayer
	# O crear un sistema con AudioStreamPlayer2D + AudioEffects
	play_feedback(quality)

## Precarga todos los sonidos de minijuegos (llamar al inicio)
static func preload_sounds() -> void:
	print("[MinigameAudio] Preloading sounds...")
	
	for quality in SOUND_PATHS.keys():
		var path: String = SOUND_PATHS[quality]
		if ResourceLoader.exists(path):
			var sound := load(path)
			if sound:
				print("[MinigameAudio] Loaded: %s" % quality)
		else:
			print("[MinigameAudio] Missing asset: %s -> %s" % [quality, path])
	
	print("[MinigameAudio] Preload complete")

## Crea un AudioStreamPlayer temporal para efectos oneshot
## @param stream: AudioStream a reproducir
## @param volume_db: Volumen en decibelios
## @param parent: Nodo padre donde añadir el player
static func create_oneshot_player(stream: AudioStream, volume_db: float, parent: Node) -> void:
	if not stream or not parent:
		return
	
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "SFX"
	parent.add_child(player)
	player.play()
	
	# Auto-destruir cuando termine
	player.finished.connect(func(): player.queue_free())
