extends Resource
class_name MinigameSoundSet

## Resource que contiene todos los sonidos de minijuegos
## Permite reutilizar sonidos comunes entre diferentes minijuegos

@export_group("Feedback Sounds")
@export var sound_perfect: AudioStream
@export var sound_bien: AudioStream
@export var sound_regular: AudioStream
@export var sound_miss: AudioStream

@export_group("Event Sounds")
@export var sound_hit: AudioStream
@export var sound_start: AudioStream
@export var sound_finish_success: AudioStream
@export var sound_finish_fail: AudioStream
@export var sound_combo: AudioStream

@export_group("Ambient Sounds")
@export var sound_tick: AudioStream
@export var sound_whoosh: AudioStream

## Obtiene el sonido por nombre de calidad
func get_feedback_sound(quality: String) -> AudioStream:
	match quality:
		"Perfect":
			return sound_perfect
		"Bien":
			return sound_bien
		"Regular":
			return sound_regular
		"Miss":
			return sound_miss
		_:
			return sound_miss  # Fallback
