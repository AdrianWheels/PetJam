extends Logger
## Cuenta los errores que salen mientras corre el arnés (Logger existe desde Godot 4.5). Un error de tiempo de
## ejecución de GDScript (una clave que no existe, una función que no existe) solo corta la función que lo tiene: el
## enlace sigue y devuelve un número cualquiera. run.gd mira este contador antes de escribir nada.

var count := 0
## El primero, para ponerlo en el mensaje: "código (fichero:línea)".
var first := ""


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	count += 1
	if first == "":
		var text := rationale if rationale != "" else code
		var where := file if file.begins_with("res://") or file.begins_with("user://") else ""
		if where == "" and not script_backtraces.is_empty():
			where = str(script_backtraces[0].format(0, 0)).strip_edges().get_slice("\n", 0)
		first = "%s%s" % [text, " (%s)" % where if where != "" else " (%s, línea %d)" % [function, line]]
