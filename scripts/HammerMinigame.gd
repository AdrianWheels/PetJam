extends "res://scripts/core/MinigameBase.gd"

## 🔨 HAMMER - Minijuego de timing rítmico (refactorizado a nodos)
## Sistema: Notas que se acercan, golpear en momento preciso a tempo BPM

# 🎨 Sistemas de feedback
const MinigameFX = preload("res://scripts/ui/MinigameFX.gd")
const MinigameAudio = preload("res://scripts/ui/MinigameAudio.gd")

# Referencias a nodos
@onready var _background: ColorRect = %Background
@onready var _track_line: ColorRect = %TrackLine
@onready var _impact_zone: ColorRect = %ImpactZone
@onready var _note_container: Control = %NoteContainer
@onready var _score_label: Label = %ScoreLabel
@onready var _progress_label: Label = %ProgressLabel

# Constantes
const TRACK_START_X := -280.0
const TRACK_END_X := 260.0
const IMPACT_X := 260.0
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
var _quality_counts := {"Perfect": 0, "Bien": 0, "Regular": 0, "Miss": 0}
var _windows := {"perfect": 40.0, "bien": 90.0, "regular": 140.0}  # ms
var _next_hit_time := 0.0
var _current_note: ColorRect = null
var _note_spawn_time := 0.0
var _can_hit := false

# Config
var _max_score := 650.0

func _ready():
	# Ocultar elementos del juego
	_track_line.visible = false
	_impact_zone.visible = false
	_note_container.visible = false
	_score_label.visible = false
	_progress_label.visible = false
	
	# Crear pantalla de título
	setup_title_screen(
		"🔨 HAMMER - Timing",
		"Golpea al ritmo con precisión",
		"Pulsa ESPACIO o CLIC cuando la nota llegue"
	)

func start_trial(config: TrialConfig) -> void:
	super.start_trial(config)
	
	# Leer hammer_speed (alias de tempo_bpm)
	var hammer_speed: float = clamp(float(config.get_parameter(&"hammer_speed", 1.0)), 0.3, 2.5)
	_bpm = DEFAULT_BPM * hammer_speed  # Aplicar multiplicador de velocidad
	
	_precision = clamp(float(config.get_parameter(&"precision", 0.5)), 0.0, 1.0)
	_max_score = config.max_score if config.max_score > 0 else 650.0
	
	# Calcular ventanas de timing
	_compute_windows()

func start_game():
	"""Inicia el minijuego. Override de MinigameBase."""
	super.start_game()
	
	# Mostrar elementos del juego
	_track_line.visible = true
	_impact_zone.visible = true
	_note_container.visible = true
	_score_label.visible = true
	_progress_label.visible = true
	
	_running = true
	_hit_index = 0
	_score = 0
	_combo = 0
	_max_combo = 0
	_quality_counts = {"Perfect": 0, "Bien": 0, "Regular": 0, "Miss": 0}
	
	_update_ui()
	_spawn_next_note()

func _compute_windows() -> void:
	# Ventanas más estrechas = más difícil
	var scl: float = lerp(1.2, 0.7, _precision)
	_windows = {
		"perfect": 40.0,
		"bien": max(90.0 * scl, 30.0),
		"regular": max(140.0 * scl, 30.0)
	}

func _spawn_next_note() -> void:
	if _hit_index >= TOTAL_HITS:
		return
	
	# Crear nota visual
	_current_note = ColorRect.new()
	_current_note.size = Vector2(30, 30)
	_current_note.position = Vector2(TRACK_START_X, -15)
	_current_note.color = Color.CYAN
	_note_container.add_child(_current_note)
	
	_note_spawn_time = Time.get_ticks_msec() / 1000.0
	_can_hit = false
	
	# Calcular cuándo debería golpearse (en segundos desde ahora)
	var beat_interval := 60.0 / _bpm
	_next_hit_time = _note_spawn_time + APPROACH_TIME

func _process(delta):
	if not _running or _current_note == null:
		return
	
	var current_time := Time.get_ticks_msec() / 1000.0
	var elapsed := current_time - _note_spawn_time
	var progress := elapsed / APPROACH_TIME
	
	# Mover nota hacia impact zone
	if _current_note:
		var x_pos: float = lerp(TRACK_START_X, IMPACT_X, progress)
		_current_note.position.x = x_pos
		
		# Cambiar color según proximidad
		var time_to_hit: float = _next_hit_time - current_time
		var time_to_hit_ms: float = time_to_hit * 1000.0
		
		if abs(time_to_hit_ms) <= _windows.perfect:
			_current_note.color = MinigameFX.COLORS["Perfect"]
			_can_hit = true
		elif abs(time_to_hit_ms) <= _windows.bien:
			_current_note.color = MinigameFX.COLORS["Success"]
			_can_hit = true
		elif abs(time_to_hit_ms) <= _windows.regular:
			_current_note.color = MinigameFX.COLORS["Warning"]
			_can_hit = true
		else:
			_current_note.color = Color.CYAN
			_can_hit = true  # Siempre permitir golpear
		
		# Auto-miss si pasa la zona
		if progress > 1.15:
			_judge_hit(9999.0)  # Miss automático

func _input(event):
	if not _running or _current_note == null:
		return
	
	if (event is InputEventMouseButton and event.pressed) or \
	   (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		var current_time: float = Time.get_ticks_msec() / 1000.0
		var time_diff_ms: float = abs(_next_hit_time - current_time) * 1000.0
		_judge_hit(time_diff_ms)
		accept_event()

func _judge_hit(time_diff_ms: float) -> void:
	if _current_note == null:
		return
	
	# 🎯 Determinar calidad
	var quality := "Miss"
	var points := 0
	
	if time_diff_ms <= _windows.perfect:
		quality = "Perfect"
		points = 100
		_combo += 1
	elif time_diff_ms <= _windows.bien:
		quality = "Bien"
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
	
	# Limpiar nota actual
	if _current_note:
		_current_note.queue_free()
		_current_note = null
	
	# Avanzar
	_hit_index += 1
	_update_ui()
	
	if _hit_index >= TOTAL_HITS:
		await get_tree().create_timer(0.6).timeout
		_finish_minigame()
	else:
		# Esperar hasta siguiente beat
		var beat_interval := 60.0 / _bpm
		await get_tree().create_timer(beat_interval * 0.3).timeout
		_spawn_next_note()

func _update_ui() -> void:
	_score_label.text = "Puntos: %d" % _score
	_progress_label.text = "Progreso: %d/%d" % [_hit_index, TOTAL_HITS]

func _finish_minigame() -> void:
	_running = false
	
	# Ocultar elementos del juego
	_track_line.visible = false
	_impact_zone.visible = false
	_note_container.visible = false
	_score_label.visible = false
	_progress_label.visible = false
	
	# Calcular éxito
	var perfect_count: int = _quality_counts["Perfect"]
	var bien_count: int = _quality_counts["Bien"]
	var hits: int = perfect_count + bien_count + _quality_counts["Regular"]
	var success: bool = hits >= int(ceil(TOTAL_HITS * 0.6))
	
	# Crear resultado
	var result := TrialResult.new()
	result.score = _score
	result.max_score = _max_score
	result.success = success
	result.duration_ms = Time.get_ticks_msec()
	result.details = {
		"perfect": perfect_count,
		"bien": bien_count,
		"regular": _quality_counts["Regular"],
		"miss": _quality_counts["Miss"],
		"max_combo": _max_combo
	}
	complete_trial(result)
	
	# Pantalla final
	var outcome := "🎉 ÉXITO" if success else "❌ FALLO"
	var stats := "Perfect: %d | Bien: %d | Regular: %d | Miss: %d\nMáx Combo: %d" % \
		[perfect_count, bien_count, _quality_counts["Regular"], _quality_counts["Miss"], _max_combo]
	
	setup_end_screen(outcome, stats + "\n\nPulsa para cerrar")
