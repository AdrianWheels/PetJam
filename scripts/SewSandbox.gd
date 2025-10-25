extends Node2D

## 🧪 Sandbox para probar sistema de 20 puntos del minijuego Sew
## Visualiza los puntos de spawn y permite testar interactivamente

@onready var _sew_minigame := $SewOSU
@onready var _debug_overlay := $DebugOverlay

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

var _visualize_points := false

func _ready():
	print("🧪 Sandbox Sew - Presiona:")
	print("  V = Toggle visualización de puntos")
	print("  T = Test con config fácil")
	print("  Y = Test con config difícil")
	print("  ESPACIO = Iniciar trial actual")
	
	# Conectar señal de completado
	_sew_minigame.trial_completed.connect(_on_trial_completed)
	
	# Configurar overlay de debug
	_debug_overlay.visible = false

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_V:
				_visualize_points = !_visualize_points
				_debug_overlay.visible = _visualize_points
				_debug_overlay.queue_redraw()
				print("👁️  Visualización de puntos: %s" % ("ON" if _visualize_points else "OFF"))
			
			KEY_T:
				_test_easy_config()
			
			KEY_Y:
				_test_hard_config()

func _test_easy_config():
	print("\n🟢 Iniciando test FÁCIL...")
	var config := SewTrialConfig.new()
	config.events = 6
	config.stitch_speed = 0.7
	config.precision = 0.3
	config.max_score = 1800.0
	config.prepare()
	
	_sew_minigame.start_trial(config)

func _test_hard_config():
	print("\n🔴 Iniciando test DIFÍCIL...")
	var config := SewTrialConfig.new()
	config.events = 10
	config.stitch_speed = 1.8
	config.precision = 0.8
	config.max_score = 3000.0
	config.prepare()
	
	_sew_minigame.start_trial(config)

func _on_trial_completed(result: TrialResult):
	print("\n✅ Trial completado:")
	print("  Score: %.0f / %.0f" % [result.score, result.max_score])
	print("  Éxito: %s" % result.success)
	print("  Detalles: %s" % result.details)
	print("\n  Presiona T/Y para nuevo test")
