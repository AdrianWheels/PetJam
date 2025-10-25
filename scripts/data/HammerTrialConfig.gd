extends TrialConfig

## Configuración específica para minijuego de Martillo (timing).
class_name HammerTrialConfig

## Número de golpes requeridos.
@export_range(3, 10, 1) var notes: int = 5

## Velocidad del martillo (BPM). Más alto = más rápido = más difícil.
@export_range(60, 180, 5) var hammer_speed: int = 85

## Tempo en BPM (alias de hammer_speed para compatibilidad).
@export_range(60, 180, 5) var tempo_bpm: int = 85:
	get: return hammer_speed
	set(value): hammer_speed = value

## Precisión requerida (0.0-1.0). Más alto = ventana más estrecha.
@export_range(0.0, 1.0, 0.05) var precision: float = 0.4

## Peso del martillo (0.0-1.0). Más alto = más lento.
@export_range(0.0, 1.0, 0.05) var weight: float = 0.5

## Etiqueta visible en UI.
@export var label: String = "Martillo"

func _ready() -> void:
	_sync_to_parameters()

func _sync_to_parameters() -> void:
	parameters = {
		"notes": notes,
		"hammer_speed": hammer_speed,
		"tempo_bpm": hammer_speed,  # Alias para compatibilidad
		"precision": precision,
		"weight": weight,
		"label": label
	} as Dictionary

## Llamar antes de pasar el config al minijuego para asegurar sincronización.
func prepare() -> void:
	_sync_to_parameters()
