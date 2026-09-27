class_name EnemyArchetypes
extends RefCounted

## Arquetipos de enemigo. Los multiplicadores mantienen la amenaza (vida × daño × velocidad ≈ 1)
## para no romper la curva de dificultad: cambia el ritmo del combate, no lo duro que es.
## Las medidas (medio ancho, alto, vuelo) salen del sprite: art/sprites/pixel/metrics.json (PixelSprites).
## body/shade/accent son los colores de los efectos (fragmentos, chispas, orbe).
## "name" y BOSS_NAMES son el texto base en español: quien los enseña los pasa por tr()
## (locale/textos.csv; en inglés, Limo → Slime, Rey Osario → Bone King…).
##
## style: cómo ataca (anima la anticipación y el impacto)
##   hop   → se aplasta y salta hacia delante
##   swing → levanta el arma y golpea
##   dive  → sube y se lanza en picado
##   slam  → alza los puños y machaca el suelo (shake fuerte)
##   cast  → carga y lanza un orbe que llega justo al impactar

const DATA := {
	&"slime": {
		"name": "Limo", "hp": 1.25, "dmg": 0.85, "aps": 0.95,
		"body": Color("63c95b"), "shade": Color("3b8a3a"), "accent": Color("b6ff9e"),
		"windup": 0.24, "strike": 0.26, "style": "hop",
	},
	&"skeleton": {
		"name": "Esqueleto", "hp": 1.0, "dmg": 1.0, "aps": 1.0,
		"body": Color("e8ddc2"), "shade": Color("ab9c7c"), "accent": Color("ff4a3a"),
		"windup": 0.22, "strike": 0.22, "style": "swing",
	},
	&"bat": {
		"name": "Murciélago", "hp": 0.7, "dmg": 0.75, "aps": 1.9,
		"body": Color("7c4bb5"), "shade": Color("4f2d7a"), "accent": Color("ff5a5a"),
		"windup": 0.15, "strike": 0.2, "style": "dive",
	},
	&"golem": {
		"name": "Gólem", "hp": 1.25, "dmg": 1.6, "aps": 0.5,
		"body": Color("8b8f99"), "shade": Color("5b5e68"), "accent": Color("ffb347"),
		"windup": 0.38, "strike": 0.3, "style": "slam",
	},
	&"wraith": {
		"name": "Espectro", "hp": 0.8, "dmg": 1.25, "aps": 1.0,
		"body": Color("a6ece6"), "shade": Color("5fa6a8"), "accent": Color("c77dff"),
		"windup": 0.32, "strike": 0.2, "style": "cast",
	},
	&"boss": {
		"name": "Jefe", "hp": 1.0, "dmg": 1.0, "aps": 1.0,
		"body": Color("e2a82c"), "shade": Color("9a6a12"), "accent": Color("ff3b30"),
		"windup": 0.34, "strike": 0.3, "style": "slam",
	},
}

## Nombre del jefe de cada bioma (ciclan igual que los biomas).
const BOSS_NAMES := ["Rey Osario", "Madre del Musgo", "Señor del Magma", "Coloso de Escarcha", "Heraldo del Vacío"]

## Colores de efectos del jefe de cada bioma (su aspecto es el sprite de art/sprites/pixel/bosses/).
const BOSS_STYLES := [
	{"body": Color("e2a82c"), "shade": Color("9a6a12"), "accent": Color("ff3b30")},
	{"body": Color("73c24c"), "shade": Color("3d7a2a"), "accent": Color("e8ff7a")},
	{"body": Color("dd5a2c"), "shade": Color("8a2a12"), "accent": Color("ffd23f")},
	{"body": Color("93d6f2"), "shade": Color("4a88b0"), "accent": Color("ffffff")},
	{"body": Color("9d5cdb"), "shade": Color("56308a"), "accent": Color("ff6af0")},
]


static func boss_style_for_room(room: int) -> Dictionary:
	var idx := Biomes.biome_index_for_room(room)
	return BOSS_STYLES[posmod(idx, BOSS_STYLES.size())]


static func get_data(id: StringName) -> Dictionary:
	return DATA.get(id, DATA[&"skeleton"])


## Arquetipo determinista por sala: la misma sala siempre trae el mismo tipo de enemigo
## (tras morir el jugador reconoce "la sala 7 es un gólem").
static func pick_for_room(room: int) -> StringName:
	if Biomes.is_boss_room(room):
		return &"boss"
	var biome: Dictionary = Biomes.biome_for_room(room)
	var pool: Array = biome.get("enemies", ["skeleton"])
	# Salas 1-3 enseñan tres tipos distintos seguidos
	if room <= 3:
		return StringName(pool[(room - 1) % pool.size()])
	var h: int = absi(hash(room * 7919 + 13))
	return StringName(pool[h % pool.size()])


static func boss_name_for_room(room: int) -> String:
	var idx := Biomes.biome_index_for_room(room)
	return BOSS_NAMES[posmod(idx, BOSS_NAMES.size())]
