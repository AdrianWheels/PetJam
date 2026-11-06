class_name LegendaryPowers
extends RefCounted

## Habilidades de las piezas legendarias (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 5):
## una por pieza, cuenta si la pieza está en la rejilla de Tico y dos iguales cuentan como una. Las de las
## maestras tienen precio. Efectos:
##  - "mult": multiplica estadísticas finales de Tico (claves de CombatMath.hero_stats);
##  - "double_hit", "block" y "dodge": probabilidades;
##  - "burn": fracción del daño del golpe que quema en BURN_TIME s;
##  - "thorns": fracción del daño recibido que vuelve al atacante;
##  - "regen": fracción de la vida máxima que se recupera por segundo;
##  - "second_chance": fracción de vida con la que Tico sigue la primera vez que iba a caer en cada duelo;
##  - "first_strike": multiplicador del primer golpe contra cada enemigo.
## Los valores son de partida: los fija la calibración (tarea 16). Textos base en español, con tr().

const BURN_TIME := 3.0
const EFFECT_KEYS := ["double_hit", "burn", "block", "dodge", "thorns", "regen", "second_chance", "first_strike"]
const POWERS := {
	&"sword_basic": {"name": "Filo perfecto", "text": "Daño ×1,25", "price": "", "mult": {"dmg": 1.25}},
	&"sword_advanced": {"name": "Golpe doble", "text": "25 % de golpear dos veces", "price": "", "double_hit": 0.25},
	&"sword_masterwork": {"name": "Filo ígneo", "text": "Cada golpe quema: el 40 % de su daño en 3 s, sin contar la armadura", "price": "Probabilidad de crítico ×0,5", "burn": 0.4, "mult": {"crit_p": 0.5}},
	&"shield_basic": {"name": "Aguante", "text": "Vida máxima ×1,2", "price": "", "mult": {"max_hp": 1.2}},
	&"shield_advanced": {"name": "Parada", "text": "15 % de parar un golpe entero", "price": "", "block": 0.15},
	&"shield_master": {"name": "Espinas", "text": "Devuelve el 30 % del daño recibido", "price": "Velocidad de ataque ×0,85", "thorns": 0.3, "mult": {"aps": 0.85}},
	&"helmet_basic": {"name": "Ojo de halcón", "text": "Probabilidad de crítico ×1,5", "price": "", "mult": {"crit_p": 1.5}},
	&"helmet_advanced": {"name": "Regeneración", "text": "Recupera el 1,5 % de la vida máxima por segundo", "price": "", "regen": 0.015},
	&"helmet_master": {"name": "Segunda oportunidad", "text": "Una vez por duelo, al caer vuelve con el 40 % de la vida", "price": "Vida máxima ×0,85", "second_chance": 0.4, "mult": {"max_hp": 0.85}},
	&"boots_basic": {"name": "Paso ligero", "text": "Velocidad de ataque ×1,15", "price": "", "mult": {"aps": 1.15}},
	&"boots_advanced": {"name": "Esquiva", "text": "12 % de esquivar un golpe", "price": "", "dodge": 0.12},
	&"boots_master": {"name": "Ímpetu", "text": "El primer golpe contra cada enemigo hace ×3", "price": "Armadura ×0,8", "first_strike": 3.0, "mult": {"armor": 0.8}},
}


static func is_legendary(item: CraftedItem) -> bool:
	return item.get_quality_tier() == "legendary"


## Habilidades que dan unas piezas (las de la rejilla de Tico): una por pieza legendaria distinta.
static func active(items: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for item in items:
		if item == null or item.item_resource == null or not is_legendary(item):
			continue
		var id := StringName(item.item_resource.item_id)
		if POWERS.has(id) and not (id in out):
			out.append(id)
	return out


## Estadísticas de Tico (CombatMath.hero_stats) con los multiplicadores de las habilidades y los topes
## de siempre: crítico 75 %, velocidad de ataque entre 0,3 y 5.
static func apply_multipliers(stats: Dictionary, powers: Array) -> Dictionary:
	var out := stats.duplicate()
	for id in powers:
		var mult: Dictionary = POWERS[id].get("mult", {})
		for key in mult:
			out[key] = float(out[key]) * float(mult[key])
	out.max_hp = maxi(1, roundi(out.max_hp))
	out.armor = roundi(out.armor)
	out.aps = clampf(out.aps, 0.3, 5.0)
	out.crit_p = clampf(out.crit_p, 0.0, 0.75)
	return out


## Efectos de combate de unas habilidades: cada clave de EFFECT_KEYS → valor (0 si ninguna lo da).
static func effects(powers: Array) -> Dictionary:
	var out := {}
	for key in EFFECT_KEYS:
		out[key] = 0.0
	for id in powers:
		for key in EFFECT_KEYS:
			if POWERS[id].has(key):
				out[key] = float(POWERS[id][key])
	return out
