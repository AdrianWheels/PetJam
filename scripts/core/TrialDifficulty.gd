class_name TrialDifficulty
extends RefCounted

## Dificultad de los minijuegos por rango (spec de rangos, apartado 5). Ajusta la copia de la
## configuración de una prueba según las claves que lleva (los ids de minijuego no son uniformes).
## Topes jugables en móvil; si el valor ya pasaba el tope, se respeta.

const FORGE_SPEED_STEP := 1.1
const FORGE_SPEED_CAP := 2.0
const FORGE_PRECISION_STEP := 0.06
const HAMMER_SPEED_STEP := 1.08
const HAMMER_SPEED_CAP := 160
const HAMMER_PRECISION_STEP := 0.05
const PRECISION_CAP := 0.85
const SEW_SPEED_STEP := 1.08
const SEW_SPEED_CAP := 1.6
const SEW_PRECISION_STEP := 0.05  # en coser se resta: menos precisión = ventanas menores
const QUENCH_SPEED_STEP := 1.08
const QUENCH_SPEED_CAP := 2.0
const QUENCH_WINDOW_STEP := 0.92
const QUENCH_WINDOW_MIN := 0.12


static func apply(config: TrialConfig, rank: int) -> void:
	var k := maxi(1, rank) - 1
	if config == null or k == 0:
		return
	var p := config.parameters
	if p.has("forge_speed"):
		p["forge_speed"] = _up(float(p.forge_speed), pow(FORGE_SPEED_STEP, k), FORGE_SPEED_CAP)
		if p.has("precision"):
			p["precision"] = _add_up(float(p.precision), FORGE_PRECISION_STEP * k, PRECISION_CAP)
	elif p.has("hammer_speed"):
		var bpm := roundi(_up(float(p.hammer_speed), pow(HAMMER_SPEED_STEP, k), HAMMER_SPEED_CAP))
		p["hammer_speed"] = bpm
		if p.has("tempo_bpm"):
			p["tempo_bpm"] = bpm
		if p.has("precision"):
			p["precision"] = _add_up(float(p.precision), HAMMER_PRECISION_STEP * k, PRECISION_CAP)
	elif p.has("stitch_speed"):
		p["stitch_speed"] = _up(float(p.stitch_speed), pow(SEW_SPEED_STEP, k), SEW_SPEED_CAP)
		if p.has("precision"):
			p["precision"] = maxf(0.0, float(p.precision) - SEW_PRECISION_STEP * k)
	elif p.has("quench_speed"):
		p["quench_speed"] = _up(float(p.quench_speed), pow(QUENCH_SPEED_STEP, k), QUENCH_SPEED_CAP)
		if p.has("time_window"):
			var w := float(p.time_window)
			p["time_window"] = w if w <= QUENCH_WINDOW_MIN else maxf(QUENCH_WINDOW_MIN, w * pow(QUENCH_WINDOW_STEP, k))


## Multiplica sin pasar del tope (si ya lo pasaba, lo deja).
static func _up(value: float, factor: float, cap: float) -> float:
	return value if value >= cap else minf(cap, value * factor)


static func _add_up(value: float, delta: float, cap: float) -> float:
	return value if value >= cap else minf(cap, value + delta)
