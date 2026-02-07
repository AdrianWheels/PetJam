extends Node

## Sistema de audio unificado (contexto unico)
## Ya no hay dual-context FORGE/DUNGEON -- todo en una pantalla

## Enum mantenido por compatibilidad (ya no tiene efecto funcional)
enum AudioContext { GLOBAL, FORGE, DUNGEON }

# Players globales
@onready var _sfx_player := AudioStreamPlayer.new()
@onready var _music_player := AudioStreamPlayer.new()

var _original_music_volume: float = 0.0
var _duck_tween: Tween

func _ready():
	add_child(_music_player)
	add_child(_sfx_player)
	_music_player.bus = "Master"
	_sfx_player.bus = "SFX"
	_music_player.name = "MusicPlayer"
	_sfx_player.name = "SFXPlayer"
	DebugManager.log_msg(&"audio", "AudioManager ready")

## Reproduce SFX
func play_sfx(stream: AudioStream, volume_db: float = 0.0, _context = null):
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db
	_sfx_player.play()

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
