class_name GridExpansions
extends RefCounted

## Recetas de ampliación de la rejilla de Tico (spec doc/specs/2026-09-27-inventario-en-rejilla.md,
## apartado 7): una por jefe de las salas 10, 20, 30 y 40 del ciclo I. Cada receta forjada lleva la
## rejilla al tamaño siguiente de SIZES, sea cual sea la receta. Solo cuentan los jefes del ciclo I.

const START_SIZE := Vector2i(4, 4)
## Tamaño tras 1, 2, 3 y 4 ampliaciones: columna a la derecha, fila abajo, alternando.
const SIZES: Array[Vector2i] = [Vector2i(5, 4), Vector2i(5, 5), Vector2i(6, 5), Vector2i(6, 6)]
const MAX_SIZE := Vector2i(6, 6)
## Receta → jefe que la desbloquea (sala del ciclo I) y nombre (texto base, con tr()), en el orden de
## los jefes. Materiales y pruebas del plano: blueprint() (tarea 12).
const RECIPES := {
	&"grid_bone_straps": {"room": 10, "name": "Correas de hueso"},
	&"grid_moss_pouches": {"room": 20, "name": "Bolsas de musgo"},
	&"grid_obsidian_buckles": {"room": 30, "name": "Hebillas de obsidiana"},
	&"grid_frost_harness": {"room": 40, "name": "Arnés de escarcha"},
}


static func size_after(count: int) -> Vector2i:
	if count <= 0:
		return START_SIZE
	return SIZES[mini(count, SIZES.size()) - 1]


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in RECIPES:
		out.append(id)
	return out


static func is_expansion(id: StringName) -> bool:
	return RECIPES.has(id)


## Receta que desbloquea vencer al jefe de `room`, o &"" (solo las salas 10 a 40 del ciclo I).
static func recipe_for_boss_room(room: int) -> StringName:
	for id in RECIPES:
		if int(RECIPES[id].room) == room:
			return id
	return &""


## Recetas desbloqueadas con un récord: las de los jefes que ya ha vencido (récord mayor que su sala).
static func unlocked_for_record(record: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in RECIPES:
		if record > int(RECIPES[id].room):
			out.append(id)
	return out
