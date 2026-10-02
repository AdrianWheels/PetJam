extends RefCounted
## Generador mulberry32: la misma secuencia que adapters/ts/rng.ts para la misma semilla.
## Las multiplicaciones van por mitades de 16 bits para no desbordar los enteros de 64 bits.

var _state := 0


func _init(seed_value: int) -> void:
	_state = seed_value & 0xFFFFFFFF


## Multiplicación de 32 bits como Math.imul: los 32 bits bajos del producto.
static func imul(a: int, b: int) -> int:
	var ah := (a >> 16) & 0xFFFF
	var al := a & 0xFFFF
	var bh := (b >> 16) & 0xFFFF
	var bl := b & 0xFFFF
	return (al * bl + (((ah * bl + al * bh) & 0xFFFF) << 16)) & 0xFFFFFFFF


func next() -> float:
	_state = (_state + 0x6D2B79F5) & 0xFFFFFFFF
	var t := imul(_state ^ (_state >> 15), _state | 1)
	t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
