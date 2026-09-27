extends Camera2D

## Cámara del corredor pixel: sigue al héroe en X con suavizado, altura fija y shake por "trauma".
## Todo en píxeles enteros del arte (216x96): sin giro ni zoom, que deforman el pixel art.
## El trauma decae solo; el desplazamiento es trauma² para que los golpes pequeños apenas muevan.

const MAX_OFFSET := Vector2(3, 2)
const TRAUMA_DECAY := 1.6
const FOLLOW_SHARPNESS := 6.0

var trauma := 0.0
var _t := 0.0
var _target_x := 0.0
var _x := 0.0  # posición suavizada, sin redondear


func _ready() -> void:
	ignore_rotation = true
	_x = position.x


## Coloca la cámara al instante (respawn, arranque).
func snap_to(x: float, y: float) -> void:
	_target_x = x
	_x = x
	position = Vector2(roundf(x), roundf(y))
	reset_smoothing()


func set_target_x(x: float) -> void:
	_target_x = x


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Compatibilidad: el zoom de impacto deformaba el pixel art y se ha quitado. El temblor lo da add_trauma().
func punch(_amount: float = 0.04) -> void:
	pass


func _process(delta: float) -> void:
	_t += delta
	_x = lerpf(_x, _target_x, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
	position.x = roundf(_x)
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
	var shake := trauma * trauma
	offset = Vector2(
		roundf(MAX_OFFSET.x * shake * _noise(_t * 31.0, 0.0)),
		roundf(MAX_OFFSET.y * shake * _noise(_t * 29.0, 7.3))
	)


## Ruido suave barato en [-1, 1] (suma de senos incommensurables).
func _noise(x: float, seed_off: float) -> float:
	return (sin(x + seed_off) * 0.6 + sin(x * 1.73 + seed_off * 2.1) * 0.3 + sin(x * 3.11 + seed_off * 0.7) * 0.1)
