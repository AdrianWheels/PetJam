@tool
extends EditorScript

## Script de conversión para actualizar blueprints de TrialConfig genérico
## a configs específicos (ForgeTrialConfig, HammerTrialConfig, etc.)
##
## CÓMO USAR:
## 1. File → Run
## 2. Verifica la consola para ver resultados
## 3. Los blueprints se actualizan automáticamente

const BLUEPRINT_DIR := "res://data/blueprints/"

func _run() -> void:
	print("=== Iniciando conversión de blueprints ===")
	
	var dir := DirAccess.open(BLUEPRINT_DIR)
	if dir == null:
		push_error("No se pudo abrir directorio: %s" % BLUEPRINT_DIR)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var converted_count := 0
	
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "BlueprintLibrary.tres":
			var path := BLUEPRINT_DIR.path_join(file_name)
			if _convert_blueprint(path):
				converted_count += 1
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("=== Conversión finalizada: %d blueprints actualizados ===" % converted_count)

func _convert_blueprint(path: String) -> bool:
	var blueprint: BlueprintResource = load(path)
	if blueprint == null:
		push_warning("No se pudo cargar blueprint: %s" % path)
		return false
	
	var modified := false
	
	for trial in blueprint.trial_sequence:
		if trial is TrialResource and trial.config != null:
			var old_config: TrialConfig = trial.config
			var new_config: TrialConfig = null
			
			# Detectar tipo de minijuego y crear config específico
			var minigame_id: StringName = trial.get_effective_minigame()
			
			match minigame_id:
				"Forge", "forge":
					new_config = _create_forge_config(old_config)
				"hammer", "Hammer":
					new_config = _create_hammer_config(old_config)
				"sew", "Sew":
					new_config = _create_sew_config(old_config)
				"quench", "Quench", "water":
					new_config = _create_quench_config(old_config)
				_:
					push_warning("Tipo de minijuego desconocido: %s en %s" % [minigame_id, path])
					continue
			
			if new_config != null:
				# Copiar propiedades base
				new_config.minigame_id = old_config.minigame_id
				new_config.trial_id = old_config.trial_id
				new_config.blueprint_id = old_config.blueprint_id
				new_config.minigame_scene = old_config.minigame_scene
				new_config.max_score = old_config.max_score
				
				trial.config = new_config
				modified = true
				print("  ✓ Convertido trial %s a %s" % [trial.trial_id, new_config.get_script().get_global_name()])
	
	if modified:
		var err := ResourceSaver.save(blueprint, path)
		if err == OK:
			print("✓ Blueprint actualizado: %s" % path.get_file())
			return true
		else:
			push_error("Error al guardar blueprint %s: código %d" % [path, err])
	
	return false

func _create_forge_config(old: TrialConfig) -> TrialConfig:
	var config := ForgeTrialConfig.new()
	config.temp_window_base = old.get_parameter("temp_window_base", 90.0)
	config.hardness = old.get_parameter("hardness", 0.3)
	config.precision = old.get_parameter("precision", 0.5)
	config.label = old.get_parameter("label", "Forja")
	return config

func _create_hammer_config(old: TrialConfig) -> TrialConfig:
	var config := HammerTrialConfig.new()
	config.notes = old.get_parameter("notes", 5)
	config.tempo_bpm = old.get_parameter("tempo_bpm", 85)
	config.precision = old.get_parameter("precision", 0.4)
	config.weight = old.get_parameter("weight", 0.5)
	config.label = old.get_parameter("label", "Martillo")
	return config

func _create_sew_config(old: TrialConfig) -> TrialConfig:
	var config := SewTrialConfig.new()
	config.events = old.get_parameter("events", 8)
	config.speed = old.get_parameter("speed", 0.5)
	config.precision = old.get_parameter("precision", 0.5)
	config.evasion_threshold = old.get_parameter("evasion_threshold", 0.7)
	config.label = old.get_parameter("label", "Coser")
	return config

func _create_quench_config(old: TrialConfig) -> TrialConfig:
	var config := QuenchTrialConfig.new()
	config.optimal_time = old.get_parameter("optimal_time", 1.5)
	config.time_window = old.get_parameter("time_window", 0.3)
	config.catalyst_bonus = old.get_parameter("catalyst_bonus", 1.2)
	config.label = old.get_parameter("label", "Temple")
	config.element = old.get_parameter("element", "")
	return config
