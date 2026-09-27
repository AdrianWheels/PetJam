class_name Biomes
extends RefCounted

## Datos de los biomas de la mazmorra endless.
## Cada bioma dura ROOMS_PER_BIOME salas; la última sala de cada bioma es la del jefe.
## Al agotar la lista se vuelve a empezar añadiendo un numeral romano (Catacumbas II…).

const ROOMS_PER_BIOME := 10

const LIST := [
	{
		"name": "Catacumbas",
		"sky_top": Color("0d090f"), "sky_bottom": Color("2b1b1e"),
		"far": Color("201519"), "far_hi": Color("2e1f22"),
		"wall": Color("3b2b2d"), "wall_dark": Color("261b1e"), "wall_hi": Color("4b3837"),
		"pillar": Color("4a3834"), "pillar_dark": Color("2b1f21"), "pillar_hi": Color("5f4840"),
		"floor": Color("34272a"), "floor_dark": Color("1c1416"), "floor_hi": Color("4f3c37"),
		"fog": Color("5c3424"), "light": Color("ff9a45"),
		"flame_core": Color("fff2c4"), "flame_mid": Color("ffb347"), "flame_outer": Color("ff5a1f"),
		"particle": Color("ffb46b"), "accent": Color("7a1f2b"),
		"decor": "banners", "enemies": ["slime", "skeleton", "bat"],
	},
	{
		"name": "Cripta Musgosa",
		"sky_top": Color("060f0c"), "sky_bottom": Color("14281f"),
		"far": Color("0e1d17"), "far_hi": Color("16291f"),
		"wall": Color("22362c"), "wall_dark": Color("15241d"), "wall_hi": Color("2f4a3a"),
		"pillar": Color("2c4134"), "pillar_dark": Color("18281f"), "pillar_hi": Color("3d5946"),
		"floor": Color("1f2e26"), "floor_dark": Color("101a15"), "floor_hi": Color("2f4537"),
		"fog": Color("1d4a39"), "light": Color("7dffb2"),
		"flame_core": Color("eefff4"), "flame_mid": Color("86ffba"), "flame_outer": Color("1fa86b"),
		"particle": Color("a6ffcf"), "accent": Color("3f7a3a"),
		"decor": "vines", "enemies": ["slime", "skeleton", "wraith"],
	},
	{
		"name": "Caverna de Magma",
		"sky_top": Color("120404"), "sky_bottom": Color("3d1008"),
		"far": Color("250a07"), "far_hi": Color("361109"),
		"wall": Color("2f1b18"), "wall_dark": Color("1b0e0c"), "wall_hi": Color("402622"),
		"pillar": Color("35211c"), "pillar_dark": Color("1d100e"), "pillar_hi": Color("4d2d25"),
		"floor": Color("2a1916"), "floor_dark": Color("150a09"), "floor_hi": Color("3e2521"),
		"fog": Color("7d2b10"), "light": Color("ff6a26"),
		"flame_core": Color("fff0b0"), "flame_mid": Color("ff9a2e"), "flame_outer": Color("e8360f"),
		"particle": Color("ff9a3c"), "accent": Color("ff6a1c"),
		"decor": "lava", "enemies": ["golem", "bat", "skeleton"],
	},
	{
		"name": "Glaciar Olvidado",
		"sky_top": Color("050a13"), "sky_bottom": Color("15263b"),
		"far": Color("0f1c2c"), "far_hi": Color("172a40"),
		"wall": Color("22364c"), "wall_dark": Color("152536"), "wall_hi": Color("34506c"),
		"pillar": Color("2b4560"), "pillar_dark": Color("182a3c"), "pillar_hi": Color("4a6f91"),
		"floor": Color("243a50"), "floor_dark": Color("12202e"), "floor_hi": Color("3c5d7d"),
		"fog": Color("3a6a8e"), "light": Color("aee8ff"),
		"flame_core": Color("ffffff"), "flame_mid": Color("b8ecff"), "flame_outer": Color("4fb3ff"),
		"particle": Color("e2f7ff"), "accent": Color("7fd6ff"),
		"decor": "crystals", "enemies": ["golem", "wraith", "bat"],
	},
	{
		"name": "Santuario del Vacío",
		"sky_top": Color("090511"), "sky_bottom": Color("241439"),
		"far": Color("170e26"), "far_hi": Color("221436"),
		"wall": Color("2a1c3d"), "wall_dark": Color("1a1128"), "wall_hi": Color("3c2a57"),
		"pillar": Color("33234a"), "pillar_dark": Color("1d132c"), "pillar_hi": Color("4c366a"),
		"floor": Color("251a36"), "floor_dark": Color("130c1e"), "floor_hi": Color("3a2a52"),
		"fog": Color("4c2a7b"), "light": Color("c78bff"),
		"flame_core": Color("ffffff"), "flame_mid": Color("dcadff"), "flame_outer": Color("8a3cff"),
		"particle": Color("e3bcff"), "accent": Color("b46bff"),
		"decor": "runes", "enemies": ["wraith", "golem", "skeleton"],
	},
]

const _ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]


## Índice absoluto del bioma (0, 1, 2…) para una sala. Sala 1-10 → 0, 11-20 → 1…
static func biome_index_for_room(room: int) -> int:
	return floori(float(maxi(0, room - 1)) / ROOMS_PER_BIOME)


## Datos del bioma (se repiten cíclicamente).
static func get_biome(index: int) -> Dictionary:
	return LIST[posmod(index, LIST.size())]


static func biome_for_room(room: int) -> Dictionary:
	return get_biome(biome_index_for_room(room))


## Nombre visible: "Catacumbas", y a partir de la segunda vuelta "Catacumbas II".
static func display_name(index: int) -> String:
	var base: String = get_biome(index).get("name", "")
	var cycle := floori(float(index) / LIST.size())
	if cycle <= 0:
		return base
	return "%s %s" % [base, roman(cycle + 1)]


static func roman(n: int) -> String:
	if n >= 0 and n < _ROMAN.size():
		return _ROMAN[n]
	return str(n)


## Sala dentro del bioma (1..ROOMS_PER_BIOME). La ROOMS_PER_BIOME es la del jefe.
static func room_in_biome(room: int) -> int:
	return (maxi(1, room) - 1) % ROOMS_PER_BIOME + 1


static func is_boss_room(room: int) -> bool:
	return room > 0 and room % ROOMS_PER_BIOME == 0


## Mezcla dos paletas (para transiciones suaves entre biomas).
static func lerp_palette(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key in a.keys():
		var va = a[key]
		if va is Color and b.has(key):
			out[key] = (va as Color).lerp(b[key], t)
		else:
			out[key] = b.get(key, va) if t >= 0.5 else va
	return out
