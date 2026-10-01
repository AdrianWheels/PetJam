extends Node
## Lanzador del arnés de Balanza en Godot, sin ventana:
##   <godot> --headless --path <proyecto> res://addons/balanza/run.tscn -- <measure|check> [--dir <carpeta>] [--out <carpeta>]
##     measure [--challenge] [--stats] [--effects] [--items]   mide y escribe measured.json (sin opciones, lo que falte)
##     check                                                   comprueba los objetivos y escribe results.json
## --dir y --out admiten res:// o rutas absolutas (por defecto, res://balance).
## `--opción valor` y `--opción=valor` valen igual. Una opción desconocida, una sin su valor, un interruptor con valor, una
## repetida o un argumento suelto son errores (salida 2), como en la CLI de balanza y en el arnés de TypeScript.
## Sale con 0 si todo va bien, 1 si falla algún objetivo y 2 si hay un error.

const ErrorLogger := preload("res://addons/balanza/error_logger.gd")
const Harness := preload("res://addons/balanza/harness.gd")
const JsonIO := preload("res://addons/balanza/json_io.gd")
const SECTIONS := ["challenge", "stats", "effects", "items"]
## Las opciones de cada modo: interruptores (sin valor) y opciones con valor. `check --variants` se acepta por compatibilidad.
const OPTIONS := {
	"measure": {"flags": ["challenge", "stats", "effects", "items"], "values": ["dir", "out"]},
	"check": {"flags": ["variants"], "values": ["dir", "out"]},
}

var _logger
## El último mensaje de error (para las pruebas).
var last_error := ""


func _ready() -> void:
	get_tree().quit(run(OS.get_cmdline_user_args()))


## Sale con 2 si el enlace o el arnés dan un error de script, aunque el resto siga como si nada (ver error_logger.gd).
func run(args: PackedStringArray) -> int:
	_logger = ErrorLogger.new()
	OS.add_logger(_logger)
	var code := _run(args)
	OS.remove_logger(_logger)
	if code != 2 and _logger.count > 0:
		return _script_errors()
	return code


func _run(args: PackedStringArray) -> int:
	if args.is_empty() or not (args[0] in ["measure", "check"]):
		printerr("uso: -- <measure|check> [--dir <carpeta>] [--out <carpeta>] [--challenge] [--stats] [--effects] [--items]")
		return 2
	var mode := args[0]
	var parsed := _parse_options(mode, args.slice(1))
	if parsed.error != "":
		return _error(parsed.error)
	var dir := _clean(parsed.values.get("dir", "res://balance"))
	var out_dir := _clean(parsed.values.get("out", dir))
	var spec = JsonIO.read(dir.path_join("balance.json"))
	if not (spec is Dictionary):
		return _error("no se puede leer %s" % dir.path_join("balance.json"))
	var binding_path: String = spec.get("godot", {}).get("binding", "")
	if binding_path == "":
		return _error("falta godot.binding en balance.json")
	var script = load(binding_path)
	if script == null:
		return _error("no se puede cargar el enlace %s" % binding_path)
	if not (script is GDScript) or not script.can_instantiate():
		return _error("el enlace %s no compila (los errores están más arriba). Si usa un class_name del juego, importa el proyecto una vez: <godot> --headless --path <juego> --import" % binding_path)
	var binding = script.new()
	for method in ["scenarios", "evaluate", "measure_metric", "capabilities"]:
		if not binding.has_method(method):
			return _error("el enlace %s no tiene %s()" % [binding_path, method])
	var plan = JsonIO.read(dir.path_join("plan.json"))
	if not (plan is Dictionary):
		return _error("no existe plan.json en %s (ejecuta balanza plan o generate)" % dir)
	if float(plan.get("format", 0)) > Harness.PLAN_FORMAT_VERSION:
		return _error("plan.json tiene el formato %d y este adaptador lee hasta el %d: actualiza el adaptador con balanza install" % [int(float(plan.format)), Harness.PLAN_FORMAT_VERSION])
	var kind: String = plan.catalog.kind
	var file := "variants.json" if kind == "variants" else ("current.json" if kind == "current" else "catalog.json")
	var source = JsonIO.read(dir.path_join(file))
	if not (source is Dictionary):
		return _error("no existe %s en %s" % [file, dir])
	if source.get("inputsHash", "") != plan.catalog.hash:
		return _error("%s y plan.json no coinciden: vuelve a ejecutar balanza plan, generate o sweep" % file)
	var harness = Harness.new(plan, binding)
	if mode == "check":
		var results: Dictionary = harness.run_check(source if kind != "variants" else {}, source if kind == "variants" else {})
		# Los errores de script van primero: un enlace que falla a mitad de evaluate() suele acabar en «no devuelve la métrica»
		if _logger.count > 0:
			return _script_errors()
		if harness.error != "":
			return _error(harness.error)
		if not JsonIO.write(out_dir.path_join("results.json"), results):
			return _error("no se puede escribir %s (¿está abierto en otro programa?)" % out_dir.path_join("results.json"))
		return _print_results(results)
	if kind == "variants":
		return _error("para medir hace falta un catálogo, no un barrido: ejecuta balanza plan o generate")
	var requested := []
	for section in SECTIONS:
		if parsed.flags.has(section):
			requested.append(section)
	var measured_path := out_dir.path_join("measured.json")
	var previous = JsonIO.read(measured_path)
	# Un measured.json que existe pero no tiene forma de medidas: mejor un error que pisarlo en silencio
	if FileAccess.file_exists(measured_path) and not _has_measure_shape(previous):
		return _error("%s no es un objeto de medidas (bórralo o vuelve a medir con --stats --effects --items --challenge)" % measured_path)
	var previous_data: Dictionary = previous if previous is Dictionary else {}
	# Sin secciones pedidas y con todo medido para este plan, no hay nada que hacer: que no parezca una medida nueva
	if requested.is_empty() and not previous_data.is_empty() and previous_data.get("planId", "") == plan.planId and harness.missing_sections(previous_data).is_empty():
		print("nada que medir: measured.json ya tiene todo lo que pide el plan%s; si has cambiado el juego, vuelve a medir con --stats --effects --items --challenge" % _summarize(previous_data))
		return 0
	var measured: Dictionary = harness.run_measure(source, requested, previous_data)
	if _logger.count > 0:
		return _script_errors()
	if harness.error != "":
		return _error(harness.error)
	if not JsonIO.write(measured_path, measured):
		return _error("no se puede escribir %s (¿está abierto en otro programa?)" % measured_path)
	print("✔ medidas en %s (%d semillas)%s" % [measured_path, measured.seeds, _summarize(measured)])
	for w in measured.warnings:
		print("aviso: " + Harness.warning_text(w, measured))
	return 0


## ¿Tiene measured.json forma de medidas? Un objeto cuyas secciones, si están, son objetos.
static func _has_measure_shape(data) -> bool:
	if not (data is Dictionary):
		return false
	for key in ["stats", "effects", "items", "challenge"]:
		if data.has(key) and not (data[key] is Dictionary):
			return false
	return true


## Las barras invertidas de Windows de una ruta se pasan a barras normales.
func _clean(path: String) -> String:
	return path.replace("\\", "/")


## Opciones de un modo con las mismas reglas y mensajes que adapters/ts/run.ts. Devuelve {"error": "", "flags": [...],
## "values": {...}} o {"error": mensaje}.
func _parse_options(mode: String, rest: PackedStringArray) -> Dictionary:
	var spec: Dictionary = OPTIONS[mode]
	var flags := []
	var values := {}
	var i := 0
	while i < rest.size():
		var arg := rest[i]
		if not arg.begins_with("--"):
			return {"error": "sobra el argumento \"%s\" (%s solo lleva opciones)" % [arg, mode]}
		var eq := arg.find("=")
		var name := arg.substr(2) if eq < 0 else arg.substr(2, eq - 2)
		if name in spec.flags:
			if eq >= 0:
				return {"error": "--%s no lleva valor" % name}
			flags.append(name)
			i += 1
			continue
		if not (name in spec.values):
			var accepted := PackedStringArray()
			for known in spec.flags + spec.values:
				accepted.append("--" + known)
			return {"error": "opción desconocida \"--%s\" (%s acepta: %s)" % [name, mode, ", ".join(accepted)]}
		if values.has(name):
			return {"error": "--%s está repetida" % name}
		if eq >= 0:
			values[name] = arg.substr(eq + 1)
		elif i + 1 < rest.size() and not rest[i + 1].begins_with("--"):
			values[name] = rest[i + 1]
			i += 1
		else:
			return {"error": "--%s necesita un valor" % name}
		i += 1
	return {"error": "", "flags": flags, "values": values}


## Qué hay en measured.json: "estadísticas en 2 niveles, 1 efecto, 4 objetos, dificultad en 2 niveles".
func _summarize(measured: Dictionary) -> String:
	var parts := []
	var levels: int = measured.stats.size()
	var effects: int = measured.effects.size()
	var items: int = measured.items.size()
	var challenge: int = measured.challenge.size()
	if levels > 0:
		parts.append("estadísticas en %d %s" % [levels, "nivel" if levels == 1 else "niveles"])
	if effects > 0:
		parts.append("%d %s" % [effects, "efecto" if effects == 1 else "efectos"])
	if items > 0:
		parts.append("%d %s" % [items, "objeto" if items == 1 else "objetos"])
	if challenge > 0:
		parts.append("dificultad en %d %s" % [challenge, "nivel" if challenge == 1 else "niveles"])
	return ": " + ", ".join(PackedStringArray(parts)) if not parts.is_empty() else ""


func _error(message: String) -> int:
	last_error = message
	printerr("error: " + message)
	return 2


func _script_errors() -> int:
	return _error("el enlace o el arnés dieron %d errores de script (están más arriba; el primero: %s); no se ha escrito nada" % [_logger.count, _logger.first])


func _print_results(results: Dictionary) -> int:
	var any_passes := false
	for v in results.variants:
		var total: int = v.results.size()
		if v.failed == 0:
			any_passes = true
			print("✔ %s: %d de %d objetivos cumplidos" % [v.variant, total, total])
		else:
			print("✘ %s: %d de %d objetivos incumplidos" % [v.variant, v.failed, total])
			for r in v.results:
				if not r.pass:
					print("   %s: %s (margen %.3f)" % [r.id, " · ".join(PackedStringArray(r.values.map(func(x): return "%.3f" % x))), r.margin])
	return 0 if any_passes else 1
