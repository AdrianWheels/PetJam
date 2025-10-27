extends "res://scripts/core/MinigameBase.gd"

## 🔨 HAMMER - Minijuego de timing rítmico (refactorizado a nodos)
## Sistema: Notas que se acercan, golpear en momento preciso a tempo BPM

# 🎨 Sistemas de feedback
const MinigameFX = preload("res://scripts/ui/MinigameFX.gd")
const MinigameAudio = preload("res://scripts/ui/MinigameAudio.gd")

# Referencias a nodos
@onready var _background: ColorRect = %Background
@onready var _gameplay_container: Control = %GameplayContainer
@onready var _track_line: Panel = %TrackLine
@onready var _impact_zone: Panel = %ImpactZone
@onready var _impact_marker: ColorRect = %ImpactMarker
@onready var _note_container: Control = %NoteContainer
@onready var _hammer_note: Panel = %HammerNote
@onready var _hammer_sprite: TextureRect = %HammerSprite
@onready var _score_label: Label = %ScoreLabel
@onready var _progress_label: Label = %ProgressLabel

# Constantes (ahora NO usamos valores hardcodeados, solo progress 0.0 a 1.0)
const APPROACH_TIME := 1.2  # segundos que tarda nota en llegar
const DEFAULT_BPM := 90
const TOTAL_HITS := 5

# Estado del juego
var _running := false
var _bpm := DEFAULT_BPM
var _precision := 0.5
var _hit_index := 0
var _score := 0
var _combo := 0
var _max_combo := 0
var _quality_counts := {"Perfect": 0, "Good": 0, "Regular": 0, "Miss": 0}
var _windows := {"perfect": 40.0, "good": 90.0, "regular": 140.0}  # ms
var _next_hit_time := 0.0
var _note_spawn_time := 0.0
var _can_hit := false

# Config
var _max_score := 650.0

func _ready():
	# 🎶 Configurar SoundSet específico para Hammer
	var hammer_soundset := MinigameSoundSet.new()
	hammer_soundset.sound_perfect = load("res://art/sounds/sfx/minigames/hammer/hammer_perfect.wav")
	hammer_soundset.sound_good = load("res://art/sounds/sfx/minigames/hammer/hammer_good.wav")
	hammer_soundset.sound_regular = load("res://art/sounds/sfx/minigames/hammer/hammer_good.wav")
	hammer_soundset.sound_miss = load("res://art/sounds/sfx/minigames/hammer/hammer_miss.wav")
	MinigameAudio.set_sound_set(hammer_soundset)
	
	# Ocultar elementos del juego
	_gameplay_container.visible = false
	_score_label.visible = false
	_progress_label.visible = false
	
	# Crear pantalla de título
	setup_title_screen(
		"🔨 HAMMER - Timing",
		"Golpea al ritmo con precisión",
		"Pulsa ESPACIO o CLIC cuando la nota llegue"
	)

func _exit_tree():
	"""Detener background audio al salir"""
	MinigameAudio.stop_background()

func start_trial(config: TrialConfig) -> void:
	super.start_trial(config)
	
	# Leer hammer_speed directamente (es BPM, no multiplicador)
	var hammer_speed: int = int(config.get_parameter(&"hammer_speed", DEFAULT_BPM))
	_bpm = clamp(hammer_speed, 50, 150)  # Limitar BPM entre 50 y 150
	
	_precision = clamp(float(config.get_parameter(&"precision", 0.5)), 0.0, 1.0)
	_max_score = config.max_score if config.max_score > 0 else 650.0
	
	# Calcular ventanas de timing
	_compute_windows()

func start_game():
	"""Inicia el minijuego. Override de MinigameBase."""
	super.start_game()
	
	# Mostrar elementos del juego
	_gameplay_container.visible = true
	_score_label.visible = true
	_progress_label.visible = true
	
	_running = true
	_hit_index = 0
	_score = 0
	_combo = 0
	_max_combo = 0
	_quality_counts = {"Perfect": 0, "Good": 0, "Regular": 0, "Miss": 0}
	
	_update_ui()
	_spawn_next_note()

func _compute_windows() -> void:
	# Ventanas más estrechas = más difícil
	var scl: float = lerp(1.2, 0.7, _precision)
	_windows = {
		"perfect": 40.0,
		"good": max(90.0 * scl, 30.0),
		"regular": max(140.0 * scl, 30.0)
	}

func _spawn_next_note() -> void:
	if _hit_index >= TOTAL_HITS:
		return
	
	# Mostrar la nota en el inicio (anchor_left = 0.0 = izquierda del contenedor)
	_hammer_note.visible = true
	_hammer_note.anchor_left = 0.0
	_hammer_note.anchor_right = 0.0
	_hammer_note.offset_left = 0.0
	_hammer_note.offset_right = 50.0
	
	# Obtener el fondo de la nota para cambiar color
	var note_bg := _hammer_note.get_node_or_null("NoteBG") as ColorRect
	if note_bg:
		note_bg.color = Color(0.2, 0.8, 1.0, 0.9)  # Color inicial cyan
	
	_note_spawn_time = Time.get_ticks_msec() / 1000.0
	_can_hit = false
	
	# Calcular cuándo debería golpearse (en segundos desde ahora)
	var _beat_interval := 60.0 / _bpm
	_next_hit_time = _note_spawn_time + APPROACH_TIME

func _process(_delta):
	if not _running or not _hammer_note.visible:
		return
	
	var current_time := Time.get_ticks_msec() / 1000.0
	var elapsed := current_time - _note_spawn_time
	var progress := elapsed / APPROACH_TIME
	
	# Mover nota usando anchor_left (0.0 = izquierda, 1.0 = derecha)
	# Vamos de 0.0 a 0.92 (cerca del final pero sin llegar al borde)
	var target_anchor := 0.92
	_hammer_note.anchor_left = lerp(0.0, target_anchor, progress)
	_hammer_note.anchor_right = _hammer_note.anchor_left
	_hammer_note.offset_left = 0.0
	_hammer_note.offset_right = 50.0
	
	# Cambiar color según proximidad (acceder al fondo de la nota)
	var time_to_hit: float = _next_hit_time - current_time
	var time_to_hit_ms: float = time_to_hit * 1000.0
	
	var note_bg := _hammer_note.get_node_or_null("NoteBG") as ColorRect
	if note_bg:
		if abs(time_to_hit_ms) <= _windows.perfect:
			note_bg.color = MinigameFX.COLORS["Perfect"]
			_can_hit = true
		elif abs(time_to_hit_ms) <= _windows.good:
			note_bg.color = MinigameFX.COLORS["Success"]
			_can_hit = true
		elif abs(time_to_hit_ms) <= _windows.regular:
			note_bg.color = MinigameFX.COLORS["Warning"]
			_can_hit = true
		else:
			note_bg.color = Color(0.2, 0.8, 1.0, 0.9)
			_can_hit = true  # Siempre permitir golpear
	
	# Auto-miss si pasa la zona
	if progress > 1.15:
		_judge_hit(9999.0)  # Miss automático

func _input(event):
	if not _running or not _hammer_note.visible:
		return
	
	if (event is InputEventMouseButton and event.pressed) or \
	   (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		var current_time: float = Time.get_ticks_msec() / 1000.0
		var time_diff_ms: float = abs(_next_hit_time - current_time) * 1000.0
		_judge_hit(time_diff_ms)
		accept_event()

func _judge_hit(time_diff_ms: float) -> void:
	if not _hammer_note.visible:
		return
	
	# 🎯 Determinar calidad
	var quality := "Miss"
	var points := 0
	
	if time_diff_ms <= _windows.perfect:
		quality = "Perfect"
		points = 100
		_combo += 1
	elif time_diff_ms <= _windows.good:
		quality = "Good"
		points = 70
		_combo += 1
	elif time_diff_ms <= _windows.regular:
		quality = "Regular"
		points = 40
		_combo += 1
	else:
		quality = "Miss"
		points = 0
		_combo = 0
	
	_quality_counts[quality] += 1
	_score += points + (_combo * 2)  # Bonus por combo
	_max_combo = max(_max_combo, _combo)
	
	# 🎨 Efectos
	var feedback_pos := _impact_zone.global_position + _impact_zone.size / 2
	MinigameFX.full_feedback(feedback_pos, quality, self)
	MinigameFX.create_floating_label(feedback_pos, quality, quality, self)
	MinigameAudio.play_feedback(quality)
	
	# 🔨 Efecto de martillazo en la posición del HammerNote
	_play_hammer_strike(quality)
	
	# Ocultar nota después del golpe
	_hammer_note.visible = false
	
	# Avanzar
	_hit_index += 1
	_update_ui()
	
	if _hit_index >= TOTAL_HITS:
		await get_tree().create_timer(0.6).timeout
		_end_game()
	else:
		# Esperar hasta siguiente beat
		var beat_interval := 60.0 / _bpm
		await get_tree().create_timer(beat_interval * 0.3).timeout
		_spawn_next_note()

func _update_ui() -> void:
	_score_label.text = "Puntos: %d" % _score
	_progress_label.text = "Progreso: %d/%d" % [_hit_index, TOTAL_HITS]

func _end_game() -> void:
	_running = false
	
	# Ocultar elementos de juego
	_gameplay_container.visible = false
	_score_label.visible = false
	_progress_label.visible = false
	
	# Calcular éxito
	var perfect_count: int = _quality_counts["Perfect"]
	var good_count: int = _quality_counts["Good"]
	var hits: int = perfect_count + good_count + _quality_counts["Regular"]
	var success: bool = hits >= int(ceil(TOTAL_HITS * 0.6))
	
	# Crear resultado
	var result := TrialResult.new()
	result.score = _score
	result.max_score = _max_score
	result.success = success
	result.duration_ms = Time.get_ticks_msec()
	result.details = {
		"perfect": perfect_count,
		"Good": good_count,
		"regular": _quality_counts["Regular"],
		"miss": _quality_counts["Miss"],
		"max_combo": _max_combo
	}
	complete_trial(result)
	
	# ✅ Auto-cerrar después de un breve delay (sin pantalla de puntuación legacy)
	await get_tree().create_timer(0.5).timeout
	_fade_out_and_close()

## 🔨 Efecto visual del martillazo
func _play_hammer_strike(quality: String) -> void:
	if not _hammer_sprite or not _hammer_note:
		return
	
	# Posicionar martillo usando el mismo anchor que HammerNote
	_hammer_sprite.anchor_left = _hammer_note.anchor_left
	_hammer_sprite.anchor_right = _hammer_note.anchor_right
	_hammer_sprite.offset_left = _hammer_note.offset_left
	_hammer_sprite.offset_right = _hammer_sprite.offset_left + 200.0
	
	_hammer_sprite.visible = true
	_hammer_sprite.modulate = Color.WHITE
	_hammer_sprite.rotation = 0.0
	_hammer_sprite.scale = Vector2.ONE
	
	# Tween para el martillazo (ahora +50% más grande: de 1.3 a 1.95)
	var tween := create_tween()
	tween.set_parallel(true)
	
	# Animación de rotación (golpe hacia abajo)
	tween.tween_property(_hammer_sprite, "rotation", -0.4, 0.08).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_hammer_sprite, "rotation", 0.15, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC).set_delay(0.08)
	
	# Escala (impacto +50% más grande: de 1.3 a 1.95)
	tween.tween_property(_hammer_sprite, "scale", Vector2(1.95, 1.95), 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hammer_sprite, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_IN_OUT).set_delay(0.06)
	
	# Fade out
	tween.tween_property(_hammer_sprite, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN).set_delay(0.6)
	
	# Screen shake según calidad
	var shake_strength := 0.0
	match quality:
		"Perfect":
			shake_strength = 20.0
		"Good":
			shake_strength = 12.0
		"Regular":
			shake_strength = 6.0
		_:
			shake_strength = 3.0
	
	_screen_shake(shake_strength, 0.2)
	
	# Ocultar después de la animación
	await tween.finished
	_hammer_sprite.visible = false

## 📳 Screen shake breve
func _screen_shake(strength: float, duration: float) -> void:
	if not _gameplay_container:
		return
	
	var original_pos := _gameplay_container.position
	var shake_tween := create_tween()
	
	# Sacudir varias veces
	var steps := int(duration / 0.03)
	for i in range(steps):
		var offset := Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		shake_tween.tween_property(_gameplay_container, "position", original_pos + offset, 0.03)
	
	# Volver a la posición original
	shake_tween.tween_property(_gameplay_container, "position", original_pos, 0.05).set_ease(Tween.EASE_OUT)
