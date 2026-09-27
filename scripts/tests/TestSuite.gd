extends Node
## 🧪 Base de las suites de prueba sin ventana (solo desarrollo). Cada suite la extiende con
## `extends "res://scripts/tests/TestSuite.gd"`, declara funciones `test_*` (pueden usar await) y se
## lanza con su escena:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/<Suite>.tscn
## Sale con código 0 si todo pasa y 1 si algo falla. Guarda y restaura user://save.json
## (las pruebas cargan los autoloads, que pueden autoguardar).

const SAVE_PATH := "user://save.json"

var _checks := 0
var _failures := 0
var _had_save := false
var _save_backup := PackedByteArray()
var _errors := ErrorCounter.new()


## Cuenta los errores (de script, de motor y de sombreador) que salen durante las pruebas.
## Un error corta la función de la prueba sin avisar al lanzador: así la prueba falla igualmente.
class ErrorCounter extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			count += 1


func _ready() -> void:
	await _wait_for_game_data()
	_backup_save()
	OS.add_logger(_errors)
	for m in get_method_list():
		var method_name: String = m.name
		if not method_name.begins_with("test_"):
			continue
		var before := _failures
		var checks_before := _checks
		var errors_before := _errors.count
		await call(method_name)
		if _errors.count > errors_before:
			check(false, "%s provocó %d errores (ver la salida)" % [method_name, _errors.count - errors_before])
		elif _checks == checks_before:
			check(false, "%s terminó sin ninguna comprobación" % method_name)
		print("%s %s" % ["ok   " if _failures == before else "FALLO", method_name])
	OS.remove_logger(_errors)
	# GameManager guarda en diferido (call_deferred): se deja que terminen esos guardados antes de
	# restaurar la partida, o escribirían encima de la copia restaurada
	for i in 3:
		await get_tree().process_frame
	_restore_save()
	print("[%s] %d comprobaciones, %d fallos" % [get_script().resource_path.get_file().get_basename(), _checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("  ✗ ", msg)


## GameManager carga la partida unos fotogramas después de arrancar (cuando DataManager tiene los planos)
## y guarda al cargarla. Se espera a que termine: así la copia de seguridad es la buena y la carga no
## llega en mitad de una prueba.
func _wait_for_game_data() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var waited := 0.0
	while gm and gm.has_method("is_save_loaded") and not gm.is_save_loaded() and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	for i in 5:
		await get_tree().process_frame  # deja pasar los guardados diferidos de la carga


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(SAVE_PATH)


func _restore_save() -> void:
	if _had_save:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(_save_backup)
		f.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
