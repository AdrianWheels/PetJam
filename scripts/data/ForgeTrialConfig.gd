extends TrialConfig

## Configuración específica para minijuego de Forja (temperatura).
class_name ForgeTrialConfig

## Número de soplidos al fuelle (trials).
@export_range(3, 8, 1) var trials: int = 3

## Velocidad del cursor (multiplicador). Más alto = más rápido.
@export_range(0.3, 2.5, 0.1) var forge_speed: float = 1.0

## Ventana de temperatura óptima (0.0-1.0). Más bajo = más difícil.
@export_range(0.0, 1.0, 0.05) var precision: float = 0.5

## Dureza del material (deprecated, usar precision).
@export_range(0.0, 1.0, 0.05) var hardness: float = 0.3

## Etiqueta visible en UI.
@export var label: String = "Forja"

func _ready() -> void:
	_sync_to_parameters()

func _sync_to_parameters() -> void:
	parameters = {
		"trials": trials,
		"forge_speed": forge_speed,
		"precision": precision,
		"hardness": hardness,
		"label": label
	} as Dictionary

## Llamar antes de pasar el config al minijuego para asegurar sincronización.
func prepare() -> void:
	_sync_to_parameters()
