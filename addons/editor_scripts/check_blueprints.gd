@tool
extends EditorScript

## Verificador de integridad de blueprints.
## Comprueba que todos los blueprints tengan configs específicos.

const BLUEPRINT_DIR := "res://data/blueprints/"

func _run() -> void:
	print("\n=== Verificador de Blueprints ===\n")
	
	var dir := DirAccess.open(BLUEPRINT_DIR)
	if dir == null:
		push_error("No se pudo abrir directorio: %s" % BLUEPRINT_DIR)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var total := 0
	var ok_count := 0
	var need_conversion := 0
	var errors := 0
	
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "BlueprintLibrary.tres":
			total += 1
			var path := BLUEPRINT_DIR.path_join(file_name)
			var result := _check_blueprint(path)
			
			match result:
				"OK":
					ok_count += 1
					print("  ✓ %s — Convertido correctamente" % file_name)
				"NEEDS_CONVERSION":
					need_conversion += 1
					print("  ⚠ %s — Necesita conversión" % file_name)
				"ERROR":
					errors += 1
					print("  ✗ %s — Error al cargar" % file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("\n=== Resumen ===")
	print("Total blueprints: %d" % total)
	print("✓ Convertidos: %d" % ok_count)
	if need_conversion > 0:
		print("⚠ Necesitan conversión: %d" % need_conversion)
		print("\n👉 Ejecuta BlueprintConverter.tscn para convertirlos")
	if errors > 0:
		print("✗ Errores: %d" % errors)
	
	if need_conversion == 0 and errors == 0:
		print("\n🎉 Todos los blueprints están correctamente configurados!")

func _check_blueprint(path: String) -> String:
	var blueprint: BlueprintResource = load(path)
	if blueprint == null:
		return "ERROR"
	
	var needs_conversion := false
	
	for trial in blueprint.trial_sequence:
		if trial is TrialResource and trial.config != null:
			var config: TrialConfig = trial.config
			
			if not _is_specific_config(config):
				needs_conversion = true
				break
	
	return "NEEDS_CONVERSION" if needs_conversion else "OK"

func _is_specific_config(config: TrialConfig) -> bool:
	if config == null:
		return false
	
	var script_name := ""
	if config.get_script():
		script_name = config.get_script().get_global_name()
	
	return script_name in ["ForgeTrialConfig", "HammerTrialConfig", "SewTrialConfig", "QuenchTrialConfig"]
