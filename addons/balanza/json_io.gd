extends RefCounted
## Lectura y escritura de JSON del arnés de Balanza. Las rutas pueden ser res:// o absolutas.


## JSON de un texto; tolera el BOM que deja el Bloc de notas. Devuelve null si no es válido.
static func parse(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text.trim_prefix(char(0xFEFF))) != OK:
		push_error("JSON no válido: %s (línea %d)" % [json.get_error_message(), json.get_error_line()])
		return null
	return json.data


static func read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return parse(FileAccess.get_file_as_string(path))


## Devuelve false si no puede abrir el fichero (carpeta imposible, fichero bloqueado).
static func write(path: String, data: Variant) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  ", false, true) + "\n")
	return true
