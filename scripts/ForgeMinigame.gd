extends "res://scripts/core/MinigameBase.gd"

# 🎨 Sistemas de feedback
const MinigameFX = preload("res://scripts/ui/MinigameFX.gd")
const MinigameAudio = preload("res://scripts/ui/MinigameAudio.gd")

# Referencias a nodos de la escena
@onready var _background: ColorRect = %Background
@onready var _progress_bar: Panel = %ProgressBar
@onready var _target_zone: ColorRect = %TargetZone
@onready var _cursor: ColorRect = %Cursor
@onready var _temperature_label: Label = %TemperatureLabel
@onready var _progress_label: Label = %ProgressLabel

# Constantes
const BASE_SPEED := 0.45
const TOTAL_TRIALS := 3  # Mínimo de trials por defecto

# Estado del juego
var closing = false
var _running := false
var _progress := 0.0
var _direction := 1  # 1 = derecha, -1 = izquierda
var _loops_completed := 0  # Contador de loops (ida-vuelta-ida = 3 loops)
var _target := 0.6
var _tolerance := 0.15
var _speed := BASE_SPEED
var _max_score := 900.0  # 3 trials * 300 pts cada uno
var _start_time := 0
var _last_quality := ""
var _feedback_timer := 0.0

# Sistema de múltiples trials
var _current_trial := 0
var _total_trials := TOTAL_TRIALS
var _trial_scores: Array[float] = []
var _trial_qualities: Array[String] = []
var _forge_speed := 1.0  # Velocidad del cursor (multiplicador)

func _ready():
	# Ocultar elementos del juego hasta que inicie
	_progress_bar.visible = false
	_temperature_label.visible = false
	_progress_label.visible = false
	
	# Crear pantalla de título (sistema original)
	setup_title_screen(
		"🔥 FORGE - Precisión",
		"Detén el martillo en el punto justo",
		"Pulsa ESPACIO o CLIC para empezar"
	)

func start_trial(config: TrialConfig) -> void:
	super.start_trial(config)
	
	# Leer configuración
	var difficulty: float = clamp(float(config.get_parameter(&"difficulty", 0.5)), 0.0, 1.0)
	_forge_speed = clamp(float(config.get_parameter(&"forge_speed", 1.0)), 0.3, 2.5)
	_total_trials = int(config.get_parameter(&"trials", TOTAL_TRIALS))
	_total_trials = max(_total_trials, 3)  # Mínimo 3 trials
	
	_target = clamp(float(config.get_parameter(&"target", 0.6)), 0.2, 0.85)
	_tolerance = lerp(0.25, 0.08, difficulty)
	_speed = BASE_SPEED * _forge_speed * 3.0  # ⚡ Velocidad x3 para el loop
	_max_score = config.max_score if config else float(_total_trials * 300)
	
	# Actualizar UI
	_update_target_zone_position()
	_progress_label.text = "Soplidos: 0/%d" % _total_trials

func start_game():
	"""Inicia el minijuego. Override de MinigameBase."""
	super.start_game()
	
	# Mostrar elementos del juego
	_progress_bar.visible = true
	_temperature_label.visible = true
	_progress_label.visible = true
	
	_running = true
	_current_trial = 0
	_trial_scores.clear()
	_trial_qualities.clear()
	_progress = 0.0
	_direction = 1
	_loops_completed = 0
	_start_time = Time.get_ticks_msec()
	_update_target_zone_position()
	
	print("\n🔥 [FORGE] Game started!")
	print("  📊 Config: trials=%d, speed=%.1f x3" % [_total_trials, _forge_speed])
	print("  🎯 Target: %.2f, Tolerance: %.2f" % [_target, _tolerance])

func _update_target_zone_position() -> void:
	# Posicionar la zona objetivo según _target
	var bar_width: float = _progress_bar.size.x
	var tolerance_px: float = bar_width * _tolerance
	var target_x: float = bar_width * _target
	
	_target_zone.position.x = target_x - tolerance_px
	_target_zone.size.x = tolerance_px * 2.0

func _process(delta):
	if not _running:
		return
	
	# 🔁 Sistema de loop: ida (0→1), vuelta (1→0), ida (0→1) = 3 loops total
	_progress += delta * _speed * _direction
	
	# Comprobar límites y cambiar dirección
	if _direction == 1 and _progress >= 1.0:
		_progress = 1.0
		_direction = -1
		_loops_completed += 1
		print("  🔄 [FORGE] Loop %d/3 completado (llegó a derecha)" % _loops_completed)
	elif _direction == -1 and _progress <= 0.0:
		_progress = 0.0
		_direction = 1
		_loops_completed += 1
		print("  🔄 [FORGE] Loop %d/3 completado (llegó a izquierda)" % _loops_completed)
	
	# Si completó 3 loops sin hacer clic → MISS automático
	if _loops_completed >= 3:
		print("  ❌ [FORGE] 3 loops completados sin clic → MISS")
		_finish_attempt()
		return
	
	# Actualizar posición del cursor visualmente
	var bar_width: float = _progress_bar.size.x
	_cursor.position.x = bar_width * clamp(_progress, 0.0, 1.0)
	
	# 🎨 Actualizar color del cursor según proximidad al objetivo + animación de pulso
	var dist_to_target: float = abs(_progress - _target)
	var target_color: Color
	if dist_to_target < _tolerance * 0.5:
		target_color = MinigameFX.COLORS["Success"]
		# Pulso suave cuando está en zona perfecta
		_cursor.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.15)
	elif dist_to_target < _tolerance:
		target_color = MinigameFX.COLORS["Warning"]
		_cursor.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08)
	else:
		target_color = MinigameFX.COLORS["Miss"]
		_cursor.scale = Vector2.ONE
	
	# Transición suave de color
	_cursor.color = _cursor.color.lerp(target_color, delta * 8.0)
	
	# Actualizar temperatura ficticia
	var temp: int = int(lerp(300.0, 900.0, _progress))
	_temperature_label.text = "%d°C" % temp
	
	# Timer de feedback
	if _feedback_timer > 0:
		_feedback_timer -= delta

func _input(event):
	if not _running:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_finish_attempt()
		accept_event()

func _finish_attempt():
	if not _running:
		return
	
	_running = false
	var diff: float = abs(_progress - _target)
	var ratio: float = clamp(1.0 - diff / max(_tolerance, 0.001), 0.0, 1.0)
	var score: float = ratio * 300.0  # 300 puntos por trial
	
	# 🎯 Determinar calidad del intento
	var quality := "Miss"
	if ratio >= 0.95:
		quality = "Perfect"
	elif ratio >= 0.75:
		quality = "Bien"
	elif ratio >= 0.5:
		quality = "Regular"
	
	_last_quality = quality
	_feedback_timer = 0.8
	_trial_scores.append(score)
	_trial_qualities.append(quality)
	_current_trial += 1
	
	# 🎨 Efectos visuales y sonoros
	var feedback_pos := _cursor.global_position + Vector2(_cursor.size.x / 2, 0)
	MinigameFX.full_feedback(feedback_pos, quality, self)
	MinigameFX.create_floating_label(feedback_pos, quality, quality, self)
	MinigameAudio.play_feedback(quality)
	
	# Actualizar progreso
	_progress_label.text = "Soplidos: %d/%d" % [_current_trial, _total_trials]
	
	print("  🔥 [FORGE] Trial %d: %.1f pts (%s)" % [_current_trial, score, quality])
	
	# ¿Terminamos todos los trials?
	if _current_trial >= _total_trials:
		await get_tree().create_timer(0.6).timeout
		_finish_minigame()
	else:
		# Preparar siguiente trial
		await get_tree().create_timer(0.5).timeout
		_progress = 0.0
		_direction = 1
		_loops_completed = 0
		_running = true
		_start_time = Time.get_ticks_msec()

func _finish_minigame() -> void:
	"""Finaliza el minijuego tras completar todos los trials."""
	_running = false
	
	# Calcular puntuación final
	var total_score := 0.0
	var perfect_count := 0
	var bien_count := 0
	var regular_count := 0
	var miss_count := 0
	
	for i in range(_trial_scores.size()):
		total_score += _trial_scores[i]
		match _trial_qualities[i]:
			"Perfect": perfect_count += 1
			"Bien": bien_count += 1
			"Regular": regular_count += 1
			"Miss": miss_count += 1
	
	var success: bool = perfect_count + bien_count >= _total_trials * 0.5
	var elapsed: int = Time.get_ticks_msec() - _start_time
	
	# Determinar calidad promedio
	var avg_quality := "Miss"
	if perfect_count >= _total_trials * 0.75:
		avg_quality = "Perfect"
	elif perfect_count + bien_count >= _total_trials * 0.625:
		avg_quality = "Bien"
	elif perfect_count + bien_count >= _total_trials * 0.375:
		avg_quality = "Regular"
	
	# Ocultar elementos del juego
	_progress_bar.visible = false
	_temperature_label.visible = false
	_progress_label.visible = false
	
	# Crear resultado
	var result := TrialResult.new()
	result.score = total_score
	result.max_score = _max_score
	result.success = success
	result.duration_ms = elapsed
	result.details = {
		"perfect": perfect_count,
		"bien": bien_count,
		"regular": regular_count,
		"miss": miss_count,
		"quality": avg_quality
	}
	complete_trial(result)
	
	# Pantalla final
	var outcome := "🎉 ÉXITO" if success else "❌ FALLO"
	var stats := "Perfect: %d | Bien: %d | Regular: %d | Miss: %d" % \
		[perfect_count, bien_count, regular_count, miss_count]
	
	setup_end_screen(outcome, stats + "\n\nPulsa para cerrar")
