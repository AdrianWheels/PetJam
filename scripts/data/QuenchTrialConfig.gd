extends TrialConfig

## Configuración específica para minijuego de Agua (temple/quench).
class_name QuenchTrialConfig

## Velocidad de descenso del metal (multiplicador). Más alto = más rápido.
@export_range(0.3, 2.5, 0.1) var quench_speed: float = 1.0

## Tiempo óptimo de inmersión (segundos).
@export_range(0.5, 3.0, 0.1) var optimal_time: float = 1.5

## Ventana de tolerancia (± segundos).
@export_range(0.1, 1.0, 0.05) var time_window: float = 0.3

## Si hay catalizador, ampliación de ventana (multiplicador).
@export_range(1.0, 2.0, 0.1) var catalyst_bonus: float = 1.2

## Etiqueta visible en UI.
@export var label: String = "Temple"

## Elemento del catalizador (si aplica).
@export var element: String = ""

func _ready() -> void:
	_sync_to_parameters()

func _sync_to_parameters() -> void:
	parameters = {
		"quench_speed": quench_speed,
		"optimal_time": optimal_time,
		"time_window": time_window,
		"catalyst_bonus": catalyst_bonus,
		"label": label,
		"element": element
	} as Dictionary

## Llamar antes de pasar el config al minijuego para asegurar sincronización.
func prepare() -> void:
	_sync_to_parameters()
