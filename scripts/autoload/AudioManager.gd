extends Node

## Sistema de audio con contextos independientes para Forja y Dungeon
## Permite reproducir audio en paralelo en ambas áreas

enum AudioContext {
	GLOBAL,    ## Audio sin contexto específico (UI, menús)
	FORGE,     ## Audio de la forja (minijuegos, crafteo)
	DUNGEON    ## Audio del dungeon (combates, ambiente)
}

# Players globales (legacy, para compatibilidad)
@onready var _sfx_player := AudioStreamPlayer.new()
@onready var _music_player := AudioStreamPlayer.new()

# Players por contexto
var _contexts := {}

func _ready():
	# Setup legacy players
	add_child(_music_player)
	add_child(_sfx_player)
	_music_player.bus = "Master"
	_sfx_player.bus = "SFX"
	_music_player.name = "GlobalMusicPlayer"
	_sfx_player.name = "GlobalSFXPlayer"
	
	# Setup contextos independientes
	_setup_context(AudioContext.FORGE, "Forge")
	_setup_context(AudioContext.DUNGEON, "Dungeon")
	
	print("AudioManager ready with %d contexts" % _contexts.size())

func _setup_context(context: AudioContext, name_prefix: String) -> void:
	var music_player := AudioStreamPlayer.new()
	var sfx_player := AudioStreamPlayer.new()
	
	music_player.name = name_prefix + "MusicPlayer"
	sfx_player.name = name_prefix + "SFXPlayer"
	music_player.bus = "Master"
	sfx_player.bus = "SFX"
	
	add_child(music_player)
	add_child(sfx_player)
	
	_contexts[context] = {
		"music_player": music_player,
		"sfx_player": sfx_player,
		"enabled": false,  # Por defecto desactivado, se activa al entrar en su área
		"name": name_prefix
	}
	
	print("AudioManager: Context '%s' initialized (disabled by default)" % name_prefix)

## Reproduce SFX en el contexto especificado
func play_sfx(stream: AudioStream, volume_db: float = 0.0, context: AudioContext = AudioContext.GLOBAL):
	if stream == null:
		print("AudioManager: Cannot play null SFX stream")
		return
	
	var player: AudioStreamPlayer
	if context == AudioContext.GLOBAL:
		player = _sfx_player
	else:
		var ctx = _contexts.get(context)
		if ctx == null or not ctx.enabled:
			return  # Contexto desactivado, no reproducir
		player = ctx.sfx_player
	
	player.stream = stream
	player.volume_db = volume_db
	player.play()
	var ctx_name = _get_context_name(context)
	print("AudioManager: Playing SFX [%s]" % ctx_name)

## Reproduce música en el contexto especificado
func play_music(stream: AudioStream, loop: bool = true, volume_db: float = 0.0, context: AudioContext = AudioContext.GLOBAL):
	if stream == null:
		print("AudioManager: Cannot play null music stream")
		return
	
	var player: AudioStreamPlayer
	if context == AudioContext.GLOBAL:
		player = _music_player
	else:
		var ctx = _contexts.get(context)
		if ctx == null or not ctx.enabled:
			return  # Contexto desactivado, no reproducir
		player = ctx.music_player
	
	player.stream = stream
	player.loop = loop
	player.volume_db = volume_db
	player.play()
	var ctx_name = _get_context_name(context)
	print("AudioManager: Playing music [%s] (loop: %s)" % [ctx_name, str(loop)])

## Detiene música del contexto especificado (o global si no se especifica)
func stop_music(context: AudioContext = AudioContext.GLOBAL):
	var player: AudioStreamPlayer
	if context == AudioContext.GLOBAL:
		player = _music_player
	else:
		var ctx = _contexts.get(context)
		if ctx == null:
			return
		player = ctx.music_player
	
	player.stop()
	var ctx_name = _get_context_name(context)
	print("AudioManager: Stopped music [%s]" % ctx_name)

## Habilita/deshabilita un contexto de audio
func set_context_enabled(context: AudioContext, enabled: bool) -> void:
	if context == AudioContext.GLOBAL:
		push_warning("AudioManager: Cannot disable GLOBAL context")
		return
	
	var ctx = _contexts.get(context)
	if ctx == null:
		return
	
	ctx.enabled = enabled
	
	# Si se desactiva, detener audio actual
	if not enabled:
		ctx.music_player.stop()
		ctx.sfx_player.stop()
	
	print("AudioManager: Context '%s' %s" % [ctx.name, "enabled" if enabled else "disabled"])

## Verifica si un contexto está habilitado
func is_context_enabled(context: AudioContext) -> bool:
	if context == AudioContext.GLOBAL:
		return true
	var ctx = _contexts.get(context)
	return ctx != null and ctx.enabled

func _get_context_name(context: AudioContext) -> String:
	match context:
		AudioContext.GLOBAL:
			return "GLOBAL"
		AudioContext.FORGE:
			return "FORGE"
		AudioContext.DUNGEON:
			return "DUNGEON"
		_:
			return "UNKNOWN"

func duck_music(amount_db:float, time_sec:float=0.2):
	# simple immediate ducking (no tween dependency)
	_music_player.volume_db = _music_player.volume_db - amount_db
	print("AudioManager: Ducked music by %f dB for %f seconds" % [amount_db, time_sec])
	# schedule restore after time_sec
	var t = Timer.new()
	t.one_shot = true
	t.wait_time = time_sec
	t.connect("timeout", Callable(self, "_restore_music_volume").bind(amount_db))
	add_child(t)
	t.start()

func _restore_music_volume(amount_db:float):
	_music_player.volume_db = _music_player.volume_db + amount_db
	print("AudioManager: Restored music volume")
