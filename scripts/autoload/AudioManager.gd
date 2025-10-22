extends Node

@onready var _sfx_player := AudioStreamPlayer.new()
@onready var _music_player := AudioStreamPlayer.new()

func _ready():
	# attach audio players as children so they persist and can play any AudioStream assigned
	add_child(_music_player)
	add_child(_sfx_player)
	_music_player.bus = "Master"
	_sfx_player.bus = "SFX"
	print("AudioManager ready")

func play_sfx(stream:AudioStream, volume_db:float=0.0):
	if stream == null:
		print("AudioManager: Cannot play null SFX stream")
		return
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db
	_sfx_player.play()
	print("AudioManager: Playing SFX")

func play_music(stream:AudioStream, loop:bool=true, volume_db:float=0.0):
	if stream == null:
		print("AudioManager: Cannot play null music stream")
		return
	_music_player.stream = stream
	_music_player.loop = loop
	_music_player.volume_db = volume_db
	_music_player.play()
	print("AudioManager: Playing music (loop: %s)" % str(loop))

func stop_music():
	_music_player.stop()
	print("AudioManager: Stopped music")

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
