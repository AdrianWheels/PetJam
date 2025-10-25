extends "res://scripts/core/MinigameBase.gd"

## 🧵 SEW - Minijuego OSU-like (refactorizado a nodos de escena)
## Sistema: Anillo fijo + círculo colapsando, click en momento preciso

# 🎨 Sistemas de feedback
const MinigameFX = preload("res://scripts/ui/MinigameFX.gd")
const MinigameAudio = preload("res://scripts/ui/MinigameAudio.gd")

# Referencias a nodos de la escena
@onready var _background: ColorRect = %Background
@onready var _target_ring: Control = %TargetRing
@onready var _collapsing_circle: Control = %CollapsingCircle
@onready var _score_label: Label = %ScoreLabel
@onready var _combo_label: Label = %ComboLabel

# Constantes de juego
const RING_R := 42.0
const START_R := 140.0
const BASE_SPEED := 120.0
const TOTAL_NOTES := 8

# 🎯 Sistema de puntos distribuidos
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(0.25, 0.25), Vector2(0.5, 0.25), Vector2(0.75, 0.25),
	Vector2(0.2, 0.4), Vector2(0.5, 0.4), Vector2(0.8, 0.4),
	Vector2(0.25, 0.5), Vector2(0.75, 0.5),
	Vector2(0.15, 0.6), Vector2(0.5, 0.6), Vector2(0.85, 0.6),
	Vector2(0.25, 0.75), Vector2(0.5, 0.75), Vector2(0.75, 0.75),
	Vector2(0.3, 0.85), Vector2(0.7, 0.85),
	Vector2(0.1, 0.5), Vector2(0.9, 0.5),
	Vector2(0.35, 0.35), Vector2(0.65, 0.65)
]
const MARGIN_SIZE := 80.0  # Margen desde los bordes (adaptable)
var _current_spawn_pos := Vector2.ZERO
var _margin := Vector2(MARGIN_SIZE, MARGIN_SIZE)

# Estado del juego
var _running := false
var _current_radius := START_R
var _speed := BASE_SPEED
var _note_index := 0
var _combo := 0
var _max_combo := 0
var _quality_counts := {"Perfect": 0, "Bien": 0, "Regular": 0, "Miss": 0}
var _windows := {"perfect": 3.0, "bien": 8.0, "regular": 14.0}
var _note_active := false
var _note_judged := false
var _feedback_timer := 0.0
var _last_quality := ""

# Config
var _max_score := 2400.0
var _precision := 0.4
var _stitch_speed := 1.0
var _spawn_indices: Array[int] = []  # Índices personalizados (vacío = random)

func _ready():
	# Ocultar elementos del juego hasta que inicie
	_target_ring.visible = false
	_collapsing_circle.visible = false
	_score_label.visible = false
	_combo_label.visible = false
	
	# Crear pantalla de título
	setup_title_screen(
		"🧵 SEW - Precisión rítmica",
		"Haz clic cuando los círculos coincidan",
		"Pulsa ESPACIO o CLIC en el momento justo"
	)

func start_trial(config: TrialConfig) -> void:
	super.start_trial(config)
	_stitch_speed = clamp(float(config.get_parameter(&"stitch_speed", 1.0)), 0.3, 1.8)
	_precision = clamp(float(config.get_parameter(&"precision", 0.4)), 0.0, 1.0)
	_max_score = max(config.max_score, float(TOTAL_NOTES * 300))
	
	# Leer spawn_indices personalizados (si existen)
	var custom_indices = config.get_parameter(&"spawn_indices", [])
	if custom_indices is Array and not custom_indices.is_empty():
		# Convertir Array genérico a Array[int]
		_spawn_indices.clear()
		for idx in custom_indices:
			if idx is int:
				_spawn_indices.append(int(idx))
	else:
		_spawn_indices = []
	
	# Calcular ventanas de timing según precisión
	_compute_windows()

func start_game():
	"""Inicia el minijuego. Override de MinigameBase."""
	super.start_game()
	
	# Mostrar elementos del juego
	_target_ring.visible = true
	_collapsing_circle.visible = true
	_score_label.visible = true
	_combo_label.visible = true
	
	# 🎯 IMPORTANTE: Configurar pivot_offset para que el círculo escale desde su centro
	_collapsing_circle.pivot_offset = _collapsing_circle.size / 2.0
	_target_ring.pivot_offset = _target_ring.size / 2.0
	
	_running = true
	_current_radius = START_R
	_note_index = 0
	_combo = 0
	_max_combo = 0
	_quality_counts = {"Perfect": 0, "Bien": 0, "Regular": 0, "Miss": 0}
	_note_active = true
	_note_judged = false
	_speed = BASE_SPEED * max(0.4, _stitch_speed)
	
	# 🎯 Posicionar en primer punto aleatorio
	_position_at_random_spawn()
	
	# 🔍 DEBUG: Info inicial
	print("\n🧵 [SEW] Game started!")
	print("  📊 Config: events=%d, speed=%.1f, precision=%.1f" % [TOTAL_NOTES, _stitch_speed, _precision])
	print("  📐 Background size: %v" % _background.size)
	print("  🎯 Target ring: pos=%v, size=%v" % [_target_ring.position, _target_ring.size])
	print("  ⭕ Collapsing circle: pos=%v, size=%v" % [_collapsing_circle.position, _collapsing_circle.size])
	
	_update_ui()
	_update_circles()

func _compute_windows() -> void:
	# Ventanas más grandes = más fácil
	var p: float = clamp(_precision, 0.0, 1.0)
	_windows = {
		"perfect": max(3.0 * (1.0 + 0.5 * p), 2.0),
		"bien": max(8.0 * (1.0 + 0.35 * p), 2.0),
		"regular": max(14.0 * (1.0 + 0.20 * p), 2.0)
	}

func _process(delta):
	if not _running:
		return
	
	# Colapsar círculo hacia el anillo central
	if _note_active and not _note_judged:
		_current_radius -= delta * _speed
		
		# Auto-miss si pasa el anillo
		if _current_radius < RING_R - _windows.regular:
			_judge_hit(abs(_current_radius - RING_R), true)
		
		_update_circles()
	
	# Timer de feedback
	if _feedback_timer > 0:
		_feedback_timer -= delta

func _input(event):
	if not _running or not _note_active or _note_judged:
		return
	
	var is_click := false
	var mouse_pos := Vector2.ZERO
	
	# Detectar click/espacio
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_click = true
		mouse_pos = event.position
		print("🖱️ [SEW] Mouse click detected at: %v" % mouse_pos)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		is_click = true
		mouse_pos = get_viewport().get_mouse_position()
		print("⌨️  [SEW] Space pressed, mouse at: %v" % mouse_pos)
	
	if is_click:
		# 🎯 Calcular centro del círculo en coordenadas locales del viewport
		# CRÍTICO: No usar global_position dentro de SubViewport, usar position local
		var circle_center := _collapsing_circle.position + _collapsing_circle.size / 2.0
		var distance_to_center := mouse_pos.distance_to(circle_center)
		var current_circle_radius := (_current_radius / START_R) * (_collapsing_circle.size.x / 2.0)
		
		# 🔍 DEBUG: Información detallada
		print("  📍 Circle center (local): %v" % circle_center)
		print("  📍 Mouse pos (viewport): %v" % mouse_pos)
		print("  📏 Distance to center: %.1f px" % distance_to_center)
		print("  ⭕ Current circle radius: %.1f px" % current_circle_radius)
		print("  ✅ Inside circle: %s" % (distance_to_center <= current_circle_radius))
		
		# Solo juzgar si el click está dentro del círculo actual
		if distance_to_center <= current_circle_radius:
			var diff: float = abs(_current_radius - RING_R)
			var late: bool = _current_radius < RING_R
			print("  🎯 HIT REGISTERED! Diff: %.1f" % diff)
			_judge_hit(diff, late)
			accept_event()
		else:
			print("  ❌ Click outside circle, ignored")

func _judge_hit(diff: float, late: bool) -> void:
	if _note_judged:
		return
	
	_note_judged = true
	
	# 🎯 Determinar calidad
	var quality := "Miss"
	var score_value := 0
	
	if diff <= _windows.perfect:
		quality = "Perfect"
		score_value = 300
		_combo += 1
	elif diff <= _windows.bien:
		quality = "Bien"
		score_value = 200
		_combo += 1
	elif diff <= _windows.regular:
		quality = "Regular"
		score_value = 100
		_combo += 1
	else:
		quality = "Miss"
		score_value = 0
		_combo = 0
	
	_quality_counts[quality] += 1
	_max_combo = max(_max_combo, _combo)
	_last_quality = quality
	_feedback_timer = 0.6
	
	# 🎨 Efectos visuales y sonoros
	var feedback_pos := _target_ring.global_position + _target_ring.size / 2
	MinigameFX.full_feedback(feedback_pos, quality, self)
	MinigameFX.create_floating_label(feedback_pos, quality, quality, self)
	MinigameAudio.play_feedback(quality)
	
	# Avanzar a siguiente nota
	_note_index += 1
	
	if _note_index >= TOTAL_NOTES:
		_finish_minigame()
	else:
		# Preparar siguiente nota en nueva posición
		await get_tree().create_timer(0.3).timeout
		_current_radius = START_R
		_note_active = true
		_note_judged = false
		_position_at_random_spawn()
	
	_update_ui()

func _update_ui() -> void:
	_score_label.text = "%d/%d" % [_note_index, TOTAL_NOTES]
	_combo_label.text = "Combo: %d" % _combo

func _update_circles() -> void:
	# Actualizar tamaño del círculo colapsando
	var scale_val: float = _current_radius / START_R
	_collapsing_circle.scale = Vector2(scale_val, scale_val)
	
	# Cambiar color según proximidad
	var diff: float = abs(_current_radius - RING_R)
	var color: Color = Color.WHITE
	
	if diff <= _windows.perfect:
		color = MinigameFX.COLORS["Perfect"]
	elif diff <= _windows.bien:
		color = MinigameFX.COLORS["Success"]
	elif diff <= _windows.regular:
		color = MinigameFX.COLORS["Warning"]
	else:
		color = MinigameFX.COLORS["Miss"]
	
	# Aplicar color al Control (necesitarás un ColorRect hijo o modulate)
	_collapsing_circle.modulate = color

func _finish_minigame() -> void:
	_running = false
	
	# Calcular puntuación final
	var perfect_count: int = _quality_counts["Perfect"]
	var bien_count: int = _quality_counts["Bien"]
	var regular_count: int = _quality_counts["Regular"]
	var miss_count: int = _quality_counts["Miss"]
	
	var total_score: float = perfect_count * 300 + bien_count * 200 + regular_count * 100
	var success: bool = perfect_count + bien_count >= TOTAL_NOTES * 0.5
	
	var avg_quality := "Miss"
	if perfect_count >= TOTAL_NOTES * 0.75:
		avg_quality = "Perfect"
	elif perfect_count + bien_count >= TOTAL_NOTES * 0.625:
		avg_quality = "Bien"
	elif perfect_count + bien_count >= TOTAL_NOTES * 0.375:
		avg_quality = "Regular"
	
	# Ocultar elementos del juego
	_target_ring.visible = false
	_collapsing_circle.visible = false
	_score_label.visible = false
	_combo_label.visible = false
	
	# Crear resultado
	var result := TrialResult.new()
	result.score = total_score
	result.max_score = _max_score
	result.success = success
	result.duration_ms = Time.get_ticks_msec()
	result.details = {
		"perfect": perfect_count,
		"bien": bien_count,
		"regular": regular_count,
		"miss": miss_count,
		"max_combo": _max_combo,
		"quality": avg_quality
	}
	complete_trial(result)
	
	# Pantalla final
	var outcome := "🎉 ÉXITO" if success else "❌ FALLO"
	var stats := "Perfect: %d | Bien: %d | Regular: %d | Miss: %d\nMáx Combo: %d" % \
		[perfect_count, bien_count, regular_count, miss_count, _max_combo]
	
	setup_end_screen(outcome, stats + "\n\nPulsa para cerrar")

func _position_at_random_spawn() -> void:
	"""Posiciona el target ring en un punto del panel (custom o aleatorio)."""
	
	# 🎯 Si hay spawn_indices definidos y válidos → usar el patrón custom
	var spawn_idx: int
	if not _spawn_indices.is_empty() and _note_index < _spawn_indices.size():
		spawn_idx = clampi(_spawn_indices[_note_index], 0, SPAWN_POINTS.size() - 1)
		print("  🎨 [SEW] Usando spawn_index CUSTOM #%d: %d" % [_note_index, spawn_idx])
	else:
		# Random por defecto
		spawn_idx = randi() % SPAWN_POINTS.size()
	
	var spawn_point := SPAWN_POINTS[spawn_idx]
	
	# 📱 Ajustar márgenes dinámicamente según tamaño del panel (responsive)
	var panel_size := _background.size
	var adaptive_margin := Vector2(
		min(MARGIN_SIZE, panel_size.x * 0.1),  # Máx 10% del ancho
		min(MARGIN_SIZE, panel_size.y * 0.1)   # Máx 10% del alto
	)
	
	# Calcular posición en píxeles considerando márgenes
	var safe_area := panel_size - adaptive_margin * 2
	_current_spawn_pos = adaptive_margin + Vector2(
		spawn_point.x * safe_area.x,
		spawn_point.y * safe_area.y
	)
	
	# Posicionar ambos controles (centrados en la posición)
	var half_size := _target_ring.size / 2.0
	_target_ring.position = _current_spawn_pos - half_size
	_collapsing_circle.position = _current_spawn_pos - _collapsing_circle.size / 2.0
	
	# 🔍 DEBUG: Info de posicionamiento
	print("  📍 [SEW] Trial %d spawned at point #%d (%.2f, %.2f)" % [_note_index + 1, spawn_idx + 1, spawn_point.x, spawn_point.y])
	print("    • Spawn position (px): %v" % _current_spawn_pos)
	print("    • Target ring pos: %v" % _target_ring.position)
	print("    • Collapsing circle pos: %v" % _collapsing_circle.position)
