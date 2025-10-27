extends "res://scripts/core/MinigameBase.gd"

## 💧 QUENCH - Minijuego de temple con ventana óptima (responsive)
## Sistema: Barra de metal baja al agua, soltar en ventana óptima
## Usa proporciones (0.0-1.0) en lugar de píxeles hardcodeados

# 🎨 Sistemas de feedback
const MinigameFX = preload("res://scripts/ui/MinigameFX.gd")
const MinigameAudio = preload("res://scripts/ui/MinigameAudio.gd")

# Referencias a nodos
@onready var _background: ColorRect = %Background
@onready var _video_background: VideoStreamPlayer = get_node_or_null("%VideoBackground")  # Opcional
@onready var _water_bucket_back: ColorRect = get_node_or_null("%WaterBucketBack")  # Opcional
@onready var _water_bucket_front: Control = get_node_or_null("%WaterBucketFront")  # Opcional (ahora Control con clip)
@onready var _temperature_bar: Panel = %TemperatureBar
@onready var _optimal_zone: ColorRect = %OptimalZone
@onready var _current_temp: ColorRect = %CurrentTemp
@onready var _temp_label: Label = %TempLabel
@onready var _instruction_hint: Label = %InstructionHint
@onready var _steel_bar: TextureRect = %SteelBar
@onready var _water_bubbles: CPUParticles2D = get_node_or_null("%WaterBubbles")  # Sistema de burbujas

# Constantes de temperatura
const MAX_TEMP := 900.0
const MIN_TEMP := 200.0
const OPTIMAL_CENTER := 400.0
const BASE_WINDOW := 80.0

# Constantes de progreso (0.0 a 1.0, responsive)
const STEEL_START_PROGRESS := 0.0  # Arriba del todo
const WATER_SURFACE_Y := 350.0  # Posición donde empieza el agua (WaterBucketFront offset_top)
const STEEL_END_PROGRESS := 1.0    # Abajo del todo (sumergido)
const TEMP_BAR_MARGIN := 0.05      # 5% margen superior e inferior

# Estado
var _running := false
var _holding := false
var _current_temperature := MAX_TEMP
var _steel_progress := 0.0  # 0.0 = arriba, 1.0 = abajo
var _optimal_min := 350.0
var _optimal_max := 450.0
var _catalyst_bonus := false
var _result_quality := ""
var _immersion_played := false  # Flag para reproducir sonido solo una vez

# Config (parámetros del blueprint)
var _max_score := 100.0
var _quench_speed := 1.0  # Multiplicador de velocidad
var _time_window := 0.3   # Ventana de tiempo (segundos)

func _ready():
	# 🎶 Configurar SoundSet específico para Quench (feedback de calidad)
	var quench_soundset := MinigameSoundSet.new()
	quench_soundset.sound_perfect = load("res://art/sounds/perfect.mp3")
	quench_soundset.sound_good = load("res://art/sounds/good.mp3")
	quench_soundset.sound_regular = load("res://art/sounds/regular.mp3")
	quench_soundset.sound_miss = load("res://art/sounds/miss.mp3")
	MinigameAudio.set_sound_set(quench_soundset)
	
	# 🎵 Reproducir background audio
	MinigameAudio.play_background("res://art/sounds/sfx/minigames/quench/quench_background.wav", self, -8.0)
	
	# Ocultar elementos del juego
	_temperature_bar.visible = false
	_temp_label.visible = false
	_instruction_hint.visible = false
	_steel_bar.visible = false
	
	# Ocultar elementos opcionales si existen
	if _video_background:
		_video_background.visible = false
	if _water_bucket_back:
		_water_bucket_back.visible = false
	if _water_bucket_front:
		_water_bucket_front.visible = false
	
	# Crear pantalla de título
	setup_title_screen(
		"💧 QUENCH - Temple",
	"Release at optimal moment for tempering",
	"Hold and release in green zone"
	)

func _exit_tree():
	"""Detener background audio al salir"""
	MinigameAudio.stop_background()

func start_trial(config: TrialConfig) -> void:
	super.start_trial(config)
	
	# Leer parámetros del blueprint
	_quench_speed = clamp(float(config.get_parameter(&"quench_speed", 1.0)), 0.3, 2.5)
	_time_window = clamp(float(config.get_parameter(&"time_window", 0.3)), 0.1, 1.0)
	_catalyst_bonus = bool(config.get_parameter(&"catalyst_bonus", false))
	_max_score = config.max_score if config.max_score > 0 else 100.0
	
	# Calcular ventana óptima de temperatura
	var window_size: float = BASE_WINDOW * (_time_window / 0.3)  # Normalizado a 0.3 base
	if _catalyst_bonus:
		window_size *= 1.2  # +20% más grande con catalizador
	
	_optimal_min = OPTIMAL_CENTER - window_size / 2
	_optimal_max = OPTIMAL_CENTER + window_size / 2
	
	_update_optimal_zone_position()

func start_game():
	"""Inicia el minijuego. Override de MinigameBase."""
	super.start_game()
	
	# Mostrar elementos del juego
	_temperature_bar.visible = true
	_temp_label.visible = true
	_instruction_hint.visible = true
	_steel_bar.visible = true
	
	# Mostrar elementos opcionales si existen
	if _video_background:
		_video_background.visible = true
		_video_background.play()
	if _water_bucket_back:
		_water_bucket_back.visible = true
	if _water_bucket_front:
		_water_bucket_front.visible = true
	
	_running = true
	_holding = false
	_current_temperature = MAX_TEMP
	_steel_progress = STEEL_START_PROGRESS
	_result_quality = ""
	_immersion_played = false  # Resetear flag de sonido
	
	# Posicionar barra de metal en posición inicial (arriba)
	_update_steel_bar_position()
	_update_temp_display()

func _update_optimal_zone_position() -> void:
	# Posicionar zona verde según temperatura óptima (proporciones en barra vertical)
	if not _temperature_bar:
		return
	
	var temp_range := MAX_TEMP - MIN_TEMP
	
	# Calcular proporciones (0.0 = arriba/caliente, 1.0 = abajo/frío)
	var min_progress := (MAX_TEMP - _optimal_max) / temp_range  # Invertido
	var max_progress := (MAX_TEMP - _optimal_min) / temp_range
	
	# Aplicar con margen
	var usable_range := 1.0 - (TEMP_BAR_MARGIN * 2)
	min_progress = TEMP_BAR_MARGIN + (min_progress * usable_range)
	max_progress = TEMP_BAR_MARGIN + (max_progress * usable_range)
	
	# Posicionar zona óptima usando anchor_top
	_optimal_zone.anchor_top = min_progress
	_optimal_zone.anchor_bottom = max_progress
	_optimal_zone.offset_top = 0.0
	_optimal_zone.offset_bottom = 0.0

func _process(delta):
	if not _running:
		return
	
	# Descender y enfriar cuando se mantiene pulsado
	if _holding:
		# 🎵 Reproducir sonido de inmersión cuando empieza a descender (solo una vez)
		if not _immersion_played and _steel_progress > 0.01:
			_immersion_played = true
			print("[Quench] 🎵 Reproduciendo sonido de inmersión (barra descendiendo)")
			if Engine.get_main_loop().root.has_node("/root/AudioManager"):
				var am: Node = Engine.get_main_loop().root.get_node("/root/AudioManager")
				var immersion_sound: AudioStream = load("res://art/sounds/sfx/minigames/quench/quench_immersion.wav")
				if immersion_sound:
					am.play_sfx(immersion_sound, 0.0, am.AudioContext.FORGE)
					print("[Quench] ✅ Sonido de inmersión reproducido")
				else:
					print("[Quench] ❌ No se pudo cargar el sonido de inmersión")
		
		# Calcular velocidad de descenso (progreso por segundo)
		var progress_speed := 0.4 * _quench_speed  # Base: 2.5 segundos para descender todo
		_steel_progress += progress_speed * delta
		_steel_progress = clamp(_steel_progress, STEEL_START_PROGRESS, STEEL_END_PROGRESS)
		
		# Enfriar temperatura proporcionalmente al progreso
		var temp_range := MAX_TEMP - MIN_TEMP
		_current_temperature = MAX_TEMP - (_steel_progress * temp_range)
		_current_temperature = clamp(_current_temperature, MIN_TEMP, MAX_TEMP)
		
		# Actualizar visuales
		_update_steel_bar_position()
		_update_temp_display()
		
		# Auto-finish si llega al final
		if _steel_progress >= STEEL_END_PROGRESS:
			_judge_release()

func _update_steel_bar_position() -> void:
	"""Actualiza la posición de la barra de metal basado en progreso (0.0-1.0)"""
	if not _steel_bar:
		return
	
	# Obtener el GameArea (padre de SteelBar)
	var game_area := _steel_bar.get_parent() as Control
	if not game_area:
		return
	
	# Usar el tamaño del GameArea en lugar del viewport
	var container_height := game_area.size.y
	var bar_height := _steel_bar.size.y
	
	# Rango de movimiento: desde arriba (fuera) hasta dentro del agua
	# La barra empieza más arriba para que no se sumerja completamente
	# y termina en una posición donde queda parcialmente visible
	var start_y: float = -container_height * 0.64  # Más arriba (-448px para 700px)
	var end_y: float = container_height * 0.25     # Menos profundo (175px para 700px)
	
	var current_y: float = lerp(start_y, end_y, _steel_progress)
	
	# Actualizar offset_top manteniendo el tamaño de la barra
	_steel_bar.offset_top = current_y
	_steel_bar.offset_bottom = current_y + bar_height
	
	# Activar burbujas cuando la barra toca el agua
	if _water_bubbles:
		# steel_bottom_y es relativo al GameArea (que va de -350 a +350)
		# WATER_SURFACE_Y es absoluto dentro del GameArea (350 desde el top)
		# Necesitamos convertir: el centro del GameArea está en 0, el top en -350
		# Entonces WATER_SURFACE_Y=350 desde top = 350-350 = 0 desde centro
		var water_surface_from_center := WATER_SURFACE_Y - (game_area.size.y / 2)
		var steel_bottom_y := current_y + bar_height  # Parte inferior de la barra (relativo a centro)
		
		if steel_bottom_y >= water_surface_from_center:
			# La barra está tocando el agua - emitir continuamente
			_water_bubbles.emitting = true
			
			# Posicionar burbujas en coordenadas globales
			# GameArea está centrado en el viewport (anchors 0.5, 0.5)
			var game_area_global_pos := game_area.global_position
			var water_surface_global_y := game_area_global_pos.y + WATER_SURFACE_Y
			
			# Posición X relativa al centro del GameArea (donde está la barra)
			# GameArea tiene offset_left=-450, offset_right=450, size.x=900
			# El centro horizontal del GameArea es game_area_global_pos.x + (game_area.size.x / 2)
			var steel_center_global_x := game_area_global_pos.x + (game_area.size.x / 2)
			
			_water_bubbles.position = Vector2(steel_center_global_x, water_surface_global_y)
		else:
			# La barra aún no toca el agua
			_water_bubbles.emitting = false

func _input(event):
	if not _running:
		return
	
	# Detectar presionar (iniciar descenso)
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
	   (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed):
		if not _holding:
			_holding = true
		_instruction_hint.text = "Cooling... Release in green zone!"
		print("[Quench] ⏬ Button pressed - starting descent")
		accept_event()
	
	# Detectar soltar
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or \
		 (event is InputEventKey and event.keycode == KEY_SPACE and not event.pressed):
		if _holding:
			_judge_release()
		accept_event()

func _update_temp_display() -> void:
	_temp_label.text = "%d°C" % int(_current_temperature)
	
	# Mover indicador visual usando proporciones (0.0 = arriba/caliente, 1.0 = abajo/frío)
	var temp_range := MAX_TEMP - MIN_TEMP
	var temp_progress := (MAX_TEMP - _current_temperature) / temp_range
	
	# Aplicar con margen
	var usable_range := 1.0 - (TEMP_BAR_MARGIN * 2)
	temp_progress = TEMP_BAR_MARGIN + (temp_progress * usable_range)
	
	# Posicionar indicador usando anchor_top
	_current_temp.anchor_top = temp_progress
	_current_temp.offset_top = 0.0
	
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
	
	# Detener burbujas
	if _water_bubbles:
		_water_bubbles.emitting = false
	
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
			quality = "Good"
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
	
	# 🎨 Efectos de vibración en la barra (temple)
	if success:
		_play_quench_vibration()
	
	# 🎨 Efectos de feedback
	var feedback_pos := _steel_bar.global_position + Vector2(_steel_bar.size.x / 2, _steel_bar.size.y / 2)
	MinigameFX.full_feedback(feedback_pos, quality, self)
	MinigameFX.create_floating_label(feedback_pos, "%d°C" % int(_current_temperature), quality, self)
	MinigameAudio.play_feedback(quality)
	
	await get_tree().create_timer(1.5).timeout
	_finish_minigame(quality, score, success)

func _finish_minigame(quality: String, score: float, success: bool) -> void:
	# Ocultar elementos del juego
	_temperature_bar.visible = false
	_temp_label.visible = false
	_instruction_hint.visible = false
	_steel_bar.visible = false
	
	# Detener burbujas
	if _water_bubbles:
		_water_bubbles.emitting = false
	
	# Ocultar elementos opcionales si existen
	if _video_background:
		_video_background.visible = false
		_video_background.stop()
	if _water_bucket_back:
		_water_bucket_back.visible = false
	if _water_bucket_front:
		_water_bucket_front.visible = false
	
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
	
	# ✅ Auto-cerrar después de un breve delay (sin pantalla de puntuación legacy)
	await get_tree().create_timer(0.5).timeout
	_fade_out_and_close()

## 💧 Efecto de vibración al templar (simula el shock térmico)
func _play_quench_vibration() -> void:
	if not _steel_bar:
		return
	
	var original_rotation := _steel_bar.rotation
	var vibration_tween := create_tween()
	vibration_tween.set_parallel(false)
	
	# Vibración rápida (simula el cambio de calor a frío)
	for i in range(8):
		var angle := randf_range(-0.08, 0.08)
		vibration_tween.tween_property(_steel_bar, "rotation", angle, 0.03)
	
	# Volver a posición original
	vibration_tween.tween_property(_steel_bar, "rotation", original_rotation, 0.1).set_ease(Tween.EASE_OUT)
