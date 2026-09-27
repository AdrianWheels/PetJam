extends Node

## Sistema de audio unificado (contexto unico)
## Ya no hay dual-context FORGE/DUNGEON -- todo en una pantalla
## Los SFX usan un pool de voces: varios sonidos a la vez sin cortarse (golpes, minijuegos, UI).

## Enum mantenido por compatibilidad (ya no tiene efecto funcional)
enum AudioContext { GLOBAL, FORGE, DUNGEON }

const SFX_VOICES := 10

# Players globales
@onready var _music_player := AudioStreamPlayer.new()

var _sfx_voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _sfx_bus := "Master"
var _original_music_volume: float = 0.0
var _duck_tween: Tween

func _ready():
	add_child(_music_player)
	_music_player.bus = "Master"
	_music_player.name = "MusicPlayer"
	# El bus "SFX" solo se usa si existe en el layout de buses
	if AudioServer.get_bus_index("SFX") != -1:
		_sfx_bus = "SFX"
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "SFXVoice%d" % i
		p.bus = _sfx_bus
		add_child(p)
		_sfx_voices.append(p)
	DebugManager.log_msg(&"audio", "AudioManager ready (%d voces SFX)" % SFX_VOICES)

## Reproduce SFX
func play_sfx(stream: AudioStream, volume_db: float = 0.0, _context = null):
	play_sfx_pitched(stream, volume_db, 1.0, 0.0)

## Reproduce SFX con tono (y variación aleatoria ± variance) para que las repeticiones no suenen idénticas
func play_sfx_pitched(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0, variance: float = 0.0) -> void:
	if stream == null or _sfx_voices.is_empty():
		return
	var voice := _get_free_voice()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = maxf(0.05, pitch + randf_range(-variance, variance))
	voice.play()

func _get_free_voice() -> AudioStreamPlayer:
	for i in _sfx_voices.size():
		var idx := (_next_voice + i) % _sfx_voices.size()
		if not _sfx_voices[idx].playing:
			_next_voice = (idx + 1) % _sfx_voices.size()
			return _sfx_voices[idx]
	# Todas ocupadas: se reutiliza la más antigua (round-robin)
	var voice := _sfx_voices[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_voices.size()
	return voice

## Reproduce musica
func play_music(stream: AudioStream, loop: bool = true, volume_db: float = 0.0, _context = null):
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		stream.loop = loop
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_original_music_volume = volume_db
	_music_player.play()

## Detiene musica
func stop_music(_context = null):
	_music_player.stop()

## Ducking temporal de musica (sin leak de Timer)
func duck_music(amount_db: float, time_sec: float = 0.2):
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	var target_vol := _original_music_volume - amount_db
	_music_player.volume_db = target_vol
	_duck_tween = create_tween()
	_duck_tween.tween_interval(time_sec)
	_duck_tween.tween_property(_music_player, "volume_db", _original_music_volume, 0.15)

## Compatibilidad: set_context_enabled ahora es no-op
func set_context_enabled(_context, _enabled: bool) -> void:
	pass

## Compatibilidad: is_context_enabled siempre retorna true
func is_context_enabled(_context) -> bool:
	return true
