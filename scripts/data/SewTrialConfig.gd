extends TrialConfig

## Configuración específica para minijuego de Coser (OSU-like).
class_name SewTrialConfig

## Número de eventos/círculos a coser.
@export_range(4, 12, 1) var events: int = 8

## Velocidad de colapso del círculo (multiplicador). Más alto = más rápido.
@export_range(0.3, 2.5, 0.1) var stitch_speed: float = 1.0

## Precisión requerida (0.0-1.0). Más alto = ventana más estrecha.
@export_range(0.0, 1.0, 0.05) var precision: float = 0.5

## Umbral para otorgar bonus de Evasión (0.0-1.0).
@export_range(0.0, 1.0, 0.05) var evasion_threshold: float = 0.7

## Índices de spawn points personalizados (0-19). Si vacío → random.
## Ejemplo: [0, 5, 10, 15, 3, 8, 12, 18] para patrón específico.
@export var spawn_indices: Array[int] = []

## Etiqueta visible en UI.
@export var label: String = "Coser"

func _ready() -> void:
	_sync_to_parameters()

func _sync_to_parameters() -> void:
	parameters = {
		"events": events,
		"stitch_speed": stitch_speed,
		"precision": precision,
		"evasion_threshold": evasion_threshold,
		"spawn_indices": spawn_indices,
		"label": label
	} as Dictionary

## Llamar antes de pasar el config al minijuego para asegurar sincronización.
func prepare() -> void:
	_sync_to_parameters()
