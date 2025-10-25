extends "res://scripts/core/MinigameBase.gd"

## 💧 QUENCH - Minijuego de temple con ventana óptima (refactorizado)
## Sistema: Temperatura baja, soltar en ventana óptima

# 🎨 Sistemas de feedback
const MinigameFX = preload("res://scripts/ui/MinigameFX.gd")
const MinigameAudio = preload("res://scripts/ui/MinigameAudio.gd")

# Referencias a nodos
@onready var _background: ColorRect = %Background
@onready var _temperature_bar: Panel = %TemperatureBar
@onready var _optimal_zone: ColorRect = %OptimalZone
@onready var _current_temp: ColorRect = %CurrentTemp
@onready var _temp_label: Label = %TempLabel
@onready var _instruction_hint: Label = %InstructionHint

# Constantes
const MAX_TEMP := 900.0
const MIN_TEMP := 200.0
const COOLING_SPEED := 120.0  # °C por segundo
const OPTIMAL_CENTER := 400.0
const BASE_WINDOW := 80.0

# Estado
var _running := false
var _holding := false
var _current_temperature := MAX_TEMP
var _optimal_min := 350.0
var _optimal_max := 450.0
var _catalyst_bonus := false
var _result_quality := ""

# Config
var _max_score := 100.0
var _quench_speed := 1.0

func _ready():
	# Ocultar elementos del juego
	_temperature_bar.visible = false
	_temp_label.visible = false
	_instruction_hint.visible = false
	
	# Crear pantalla de título
	setup_title_screen(
		"💧 QUENCH - Temple",
		"Suelta en el momento óptimo para el temple",
		"Mantén pulsado ESPACIO o CLIC, suelta en la zona verde"
	)

func start_trial(config: TrialConfig) -> void:
	super.start_trial(config)
	_quench_speed = clamp(float(config.get_parameter(&"quench_speed", 1.0)), 0.5, 2.0)
	var window_size: float = clamp(float(config.get_parameter(&"window", 1.0)), 0.5, 2.0)
	_catalyst_bonus = bool(config.get_parameter(&"catalyst", false))
	_max_score = config.max_score if config.max_score > 0 else 100.0
	
	# Calcular ventana óptima
	var window: float = BASE_WINDOW * window_size
	if _catalyst_bonus:
		window *= 1.2  # +20% más grande con catalizador
	
	_optimal_min = OPTIMAL_CENTER - window / 2
	_optimal_max = OPTIMAL_CENTER + window / 2
	
	_update_optimal_zone_position()

func start_game():
	"""Inicia el minijuego. Override de MinigameBase."""
	super.start_game()
	
	# Mostrar elementos del juego
	_temperature_bar.visible = true
	_temp_label.visible = true
	_instruction_hint.visible = true
	
	_running = true
	_holding = false
	_current_temperature = MAX_TEMP
	_result_quality = ""
	
	_update_temp_display()

func _update_optimal_zone_position() -> void:
	# Posicionar zona verde según temperatura óptima
	var bar_width := _temperature_bar.size.x - 20.0
	var temp_range := MAX_TEMP - MIN_TEMP
	
	var min_pos := (_optimal_min - MIN_TEMP) / temp_range * bar_width + 10.0
	var max_pos := (_optimal_max - MIN_TEMP) / temp_range * bar_width + 10.0
	
	_optimal_zone.position.x = min_pos
	_optimal_zone.size.x = max_pos - min_pos

func _process(delta):
	if not _running:
		return
	
	# Enfriar gradualmente cuando se mantiene pulsado (aplicar quench_speed)
	if _holding:
		_current_temperature -= COOLING_SPEED * _quench_speed * delta
		_current_temperature -= COOLING_SPEED * _quench_speed * delta
		_current_temperature = max(_current_temperature, MIN_TEMP)
		_update_temp_display()
		
		# Auto-finish si llega al mínimo
		if _current_temperature <= MIN_TEMP:
			_judge_release()

func _input(event):
	if not _running:
		return
	
	# Detectar presionar
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
	   (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed):
		if not _holding:
			_holding = true
			_instruction_hint.text = "Enfriando... Suelta en la zona verde!"
		accept_event()
	
	# Detectar soltar
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or \
	     (event is InputEventKey and event.keycode == KEY_SPACE and not event.pressed):
		if _holding:
			_judge_release()
		accept_event()

func _update_temp_display() -> void:
	_temp_label.text = "%d°C" % int(_current_temperature)
	
	# Mover indicador visual
	var bar_width := _temperature_bar.size.x - 20.0
	var temp_range := MAX_TEMP - MIN_TEMP
	var pos_x := (_current_temperature - MIN_TEMP) / temp_range * bar_width + 10.0
	_current_temp.position.x = pos_x
	
	# Cambiar color según proximidad a ventana óptima
	if _current_temperature >= _optimal_min and _current_temperature <= _optimal_max:
		_current_temp.color = MinigameFX.COLORS["Perfect"]
	elif _current_temperature >= _optimal_min - 30.0 and _current_temperature <= _optimal_max + 30.0:
		_current_temp.color = MinigameFX.COLORS["Success"]
	else:
		_current_temp.color = Color(1, 0.5, 0, 1)

func _judge_release() -> void:
	if not _running:
		return
	
	_running = false
	_holding = false
	
	# 🎯 Evaluar calidad del temple
	var quality := "Miss"
	var score := 0.0
	var success := false
	
	var dist_from_center: float = abs(_current_temperature - OPTIMAL_CENTER)
	var window_half: float = (_optimal_max - _optimal_min) / 2.0
	
	if _current_temperature >= _optimal_min and _current_temperature <= _optimal_max:
		# Dentro de la ventana óptima
		var precision_ratio: float = 1.0 - (dist_from_center / window_half)
		
		if precision_ratio >= 0.85:
			quality = "Perfect"
			score = _max_score
		elif precision_ratio >= 0.6:
			quality = "Bien"
			score = _max_score * 0.8
		else:
			quality = "Regular"
			score = _max_score * 0.5
		
		success = true
	else:
		# Fuera de la ventana
		if dist_from_center < window_half * 1.5:
			quality = "Regular"
			score = _max_score * 0.3
			success = false
		else:
			quality = "Miss"
			score = 0
			success = false
	
	_result_quality = quality
	
	# 🎨 Efectos
	var feedback_pos := _current_temp.global_position + Vector2(_current_temp.size.x / 2, 0)
	MinigameFX.full_feedback(feedback_pos, quality, self)
	MinigameFX.create_floating_label(feedback_pos, "%d°C" % int(_current_temperature), quality, self)
	MinigameAudio.play_feedback(quality)
	
	await get_tree().create_timer(1.0).timeout
	_finish_minigame(quality, score, success)

func _finish_minigame(quality: String, score: float, success: bool) -> void:
	# Ocultar elementos del juego
	_temperature_bar.visible = false
	_temp_label.visible = false
	_instruction_hint.visible = false
	
	# Crear resultado
	var result := TrialResult.new()
	result.score = score
	result.max_score = _max_score
	result.success = success
	result.duration_ms = Time.get_ticks_msec()
	result.details = {
		"temperature": int(_current_temperature),
		"optimal_min": int(_optimal_min),
		"optimal_max": int(_optimal_max),
		"quality": quality,
		"catalyst": _catalyst_bonus
	}
	complete_trial(result)
	
	# Pantalla final
	var outcome := "🎉 ÉXITO" if success else "❌ FALLO"
	var temp_text := "Temperatura: %d°C\nÓptimo: %d-%d°C\nCalidad: %s" % \
		[int(_current_temperature), int(_optimal_min), int(_optimal_max), quality]
	
	if _catalyst_bonus:
		temp_text += "\n✨ Catalizador activo (+20% ventana)"
	
	setup_end_screen(outcome, temp_text + "\n\nPulsa para cerrar")
