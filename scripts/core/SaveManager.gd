extends RefCounted

## Utilidad estática para persistencia a disco.
## Guarda/carga estado del juego en user://save.json
## NO es autoload — se usa como clase estática desde otros scripts.
class_name SaveManager

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Guarda el estado completo del juego a disco
static func save_game() -> bool:
	var save_data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
	}

	# Recopilar datos de cada autoload (los autoloads son nodos de /root, no singletons del motor)
	var gm := _get_autoload("GameManager")
	var dm := _get_autoload("DataManager")
	var im := _get_autoload("InventoryManager")
	var rm := _get_autoload("RequestsManager")

	if gm and gm.has_method("to_save_data"):
		save_data["game"] = gm.to_save_data()
	if dm and dm.has_method("to_save_data"):
		save_data["data"] = dm.to_save_data()
	if im and im.has_method("to_save_data"):
		save_data["inventory"] = im.to_save_data()
	if rm and rm.has_method("to_save_data"):
		save_data["requests"] = rm.to_save_data()

	# Escribir a disco
	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: No se pudo abrir %s para escritura (error: %s)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false

	file.store_string(json_string)
	file.close()
	print("SaveManager: ✅ Partida guardada en %s (%d bytes)" % [SAVE_PATH, json_string.length()])
	return true


## Carga el estado del juego desde disco y lo distribuye a los autoloads
static func load_game() -> bool:
	if not has_save():
		print("SaveManager: No hay partida guardada")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: No se pudo abrir %s para lectura" % SAVE_PATH)
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: Error parseando save (%s)" % json.get_error_message())
		return false

	var save_data: Dictionary = json.data
	if not save_data is Dictionary:
		push_error("SaveManager: Save data no es Dictionary")
		return false

	var version: int = save_data.get("version", 0)
	if version != SAVE_VERSION:
		push_warning("SaveManager: Versión de save %d != %d (actual). Intentando cargar igualmente." % [version, SAVE_VERSION])

	# Distribuir datos a cada autoload
	var dm := _get_autoload("DataManager")
	var gm := _get_autoload("GameManager")
	var im := _get_autoload("InventoryManager")
	var rm := _get_autoload("RequestsManager")

	# DataManager primero (blueprints desbloqueados necesarios para reconstruir items)
	if dm and dm.has_method("load_save_data") and save_data.has("data"):
		dm.load_save_data(save_data["data"])

	# InventoryManager (materiales + items crafteados + equipo)
	if im and im.has_method("load_save_data") and save_data.has("inventory"):
		im.load_save_data(save_data["inventory"])

	# GameManager (nivel enemigo, muertes, loadout)
	if gm and gm.has_method("load_save_data") and save_data.has("game"):
		gm.load_save_data(save_data["game"])

	# RequestsManager (pedidos gratis restantes)
	if rm and rm.has_method("load_save_data") and save_data.has("requests"):
		rm.load_save_data(save_data["requests"])

	var ts: float = save_data.get("timestamp", 0)
	var since := Time.get_unix_time_from_system() - ts
	print("SaveManager: ✅ Partida cargada (guardada hace %.0f segundos)" % since)
	return true


## Retorna true si existe un archivo de guardado
static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Borra el archivo de guardado
static func delete_save() -> bool:
	if not has_save():
		return false
	var err := DirAccess.remove_absolute(SAVE_PATH)
	if err != OK:
		push_error("SaveManager: Error borrando save (%d)" % err)
		return false
	print("SaveManager: 🗑️ Save borrado")
	return true


## Helper interno para obtener autoload por nombre
static func _get_autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/" + autoload_name)
