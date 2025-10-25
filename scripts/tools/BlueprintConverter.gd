extends Control

## Herramienta visual para convertir blueprints al nuevo sistema de configs.
## CÓMO USAR:
## 1. Abre esta escena en Godot
## 2. Presiona F6 (Run Current Scene) o el botón ▶
## 3. Haz clic en "Convertir Blueprints"

@onready var convert_button: Button = %ConvertButton
@onready var update_button: Button = %UpdateButton
@onready var log_output: TextEdit = %LogOutput
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel

const BLUEPRINT_DIR := "res://data/blueprints/"

func _ready() -> void:
	convert_button.pressed.connect(_on_convert_pressed)
	update_button.pressed.connect(_on_update_pressed)
	_log("Listo para convertir blueprints.")
	_log("Directorio: %s" % BLUEPRINT_DIR)
	status_label.text = "Esperando..."

func _on_convert_pressed() -> void:
	convert_button.disabled = true
	status_label.text = "Convirtiendo..."
	log_output.text = ""
	progress_bar.value = 0
	
	await get_tree().process_frame
	_convert_all_blueprints()
	
	convert_button.disabled = false

func _convert_all_blueprints() -> void:
	_log("=== Iniciando conversión de blueprints ===")
	
	var dir: DirAccess = DirAccess.open(BLUEPRINT_DIR)
	if dir == null:
		_log_error("No se pudo abrir directorio: %s" % BLUEPRINT_DIR)
		status_label.text = "Error al abrir directorio"
		return
	
	# Contar archivos primero
	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "BlueprintLibrary.tres":
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if files.is_empty():
		_log("No se encontraron blueprints para convertir.")
		status_label.text = "Sin archivos"
		return
	
	progress_bar.max_value = files.size()
	var converted_count: int = 0
	var failed_count: int = 0
	
	for i in files.size():
		var fname: String = files[i]
		var path: String = BLUEPRINT_DIR.path_join(fname)
		_log("\n[%d/%d] Procesando: %s" % [i + 1, files.size(), fname])
		
		if _convert_blueprint(path):
			converted_count += 1
		else:
			failed_count += 1
		
		progress_bar.value = i + 1
		await get_tree().process_frame
	
	_log("\n=== Conversión finalizada ===")
	_log("✓ Convertidos: %d" % converted_count)
	if failed_count > 0:
		_log_error("✗ Fallidos: %d" % failed_count)
	status_label.text = "Completado: %d/%d" % [converted_count, files.size()]

func _convert_blueprint(path: String) -> bool:
	var blueprint: BlueprintResource = load(path)
	if blueprint == null:
		_log_error("  ✗ No se pudo cargar blueprint: %s" % path)
		return false
	
	var modified: bool = false
	
	for trial: TrialResource in blueprint.trial_sequence:
		if trial is TrialResource and trial.config != null:
			var old_config: TrialConfig = trial.config
			
			# Si ya es un config específico, saltar
			if _is_specific_config(old_config):
				_log("  → Ya convertido: %s (%s)" % [trial.trial_id, old_config.get_script().get_global_name()])
				continue
			
			var new_config: TrialConfig = null
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
					_log_error("  ✗ Tipo de minijuego desconocido: %s" % minigame_id)
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
				_log("  ✓ Convertido: %s → %s" % [trial.trial_id, new_config.get_script().get_global_name()])
	
	if modified:
		var err: Error = ResourceSaver.save(blueprint, path)
		if err == OK:
			_log("  ✓ Blueprint guardado: %s" % path.get_file())
			return true
		else:
			_log_error("  ✗ Error al guardar (código %d)" % err)
			return false
	else:
		_log("  → Sin cambios necesarios")
		return false

func _is_specific_config(config: TrialConfig) -> bool:
	var script_name: String = ""
	if config.get_script():
		script_name = config.get_script().get_global_name()
	
	return script_name in ["ForgeTrialConfig", "HammerTrialConfig", "SewTrialConfig", "QuenchTrialConfig"]

func _create_forge_config(old: TrialConfig) -> ForgeTrialConfig:
	var config := ForgeTrialConfig.new()
	config.temp_window_base = old.get_parameter("temp_window_base", 90.0)
	config.hardness = old.get_parameter("hardness", 0.3)
	config.precision = old.get_parameter("precision", 0.5)
	config.label = old.get_parameter("label", "Forja")
	return config

func _create_hammer_config(old: TrialConfig) -> HammerTrialConfig:
	var config := HammerTrialConfig.new()
	config.notes = old.get_parameter("notes", 5)
	config.tempo_bpm = old.get_parameter("tempo_bpm", 85)
	config.precision = old.get_parameter("precision", 0.4)
	config.weight = old.get_parameter("weight", 0.5)
	config.label = old.get_parameter("label", "Martillo")
	return config

func _create_sew_config(old: TrialConfig) -> SewTrialConfig:
	var config := SewTrialConfig.new()
	config.events = old.get_parameter("events", 8)
	config.speed = old.get_parameter("speed", 0.5)
	config.precision = old.get_parameter("precision", 0.5)
	config.evasion_threshold = old.get_parameter("evasion_threshold", 0.7)
	config.label = old.get_parameter("label", "Coser")
	return config

func _create_quench_config(old: TrialConfig) -> QuenchTrialConfig:
	var config := QuenchTrialConfig.new()
	config.optimal_time = old.get_parameter("optimal_time", 1.5)
	config.time_window = old.get_parameter("time_window", 0.3)
	config.catalyst_bonus = old.get_parameter("catalyst_bonus", 1.2)
	config.label = old.get_parameter("label", "Temple")
	config.element = old.get_parameter("element", "")
	return config

func _log(message: String) -> void:
	log_output.text += message + "\n"
	log_output.scroll_vertical = INF
	print(message)

func _log_error(message: String) -> void:
	_log("[ERROR] " + message)
	push_error(message)

func _repeat_char(ch: String, count: int) -> String:
	var result: String = ""
	for i in count:
		result += ch
	return result

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🆕 ACTUALIZACIÓN COMPLETA DE CONFIGS (NUEVO)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_update_pressed() -> void:
	update_button.disabled = true
	convert_button.disabled = true
	status_label.text = "Actualizando configs..."
	log_output.text = ""
	progress_bar.value = 0
	
	await get_tree().process_frame
	_update_all_configs()
	
	update_button.disabled = false
	convert_button.disabled = false

func _update_all_configs() -> void:
	_log("🔧 Iniciando actualización COMPLETA de todos los TrialConfigs...")
	_log(_repeat_char("━", 60))
	
	# Mapeo de dificultad por blueprint (tier aproximado)
	var difficulty_map: Dictionary = {
		# Tier 1 (fácil)
		"sword_basic": {"tier": 1, "speed_mult": 0.8},
		"dagger_basic": {"tier": 1, "speed_mult": 0.7},
		"shield_wooden": {"tier": 1, "speed_mult": 0.7},
		"armor_leather": {"tier": 1, "speed_mult": 0.8},
		
		# Tier 2 (medio-bajo)
		"spear_wood": {"tier": 2, "speed_mult": 0.9},
		"mace_stone": {"tier": 2, "speed_mult": 1.0},
		"bow_simple": {"tier": 2, "speed_mult": 0.9},
		
		# Tier 3 (medio)
		"axe_iron": {"tier": 3, "speed_mult": 1.1},
		"armor_iron": {"tier": 3, "speed_mult": 1.0},
		
		# Tier 4 (medio-alto)
		"amulet_silver": {"tier": 4, "speed_mult": 1.3},
		"ring_gold": {"tier": 4, "speed_mult": 1.4},
		
		# Especiales
		"potion_heal": {"tier": 1, "speed_mult": 0.9},
	}
	
	var dir: DirAccess = DirAccess.open(BLUEPRINT_DIR)
	if dir == null:
		_log_error("No se pudo abrir directorio: %s" % BLUEPRINT_DIR)
		status_label.text = "Error al abrir directorio"
		return
	
	# Recopilar archivos
	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "BlueprintLibrary.tres":
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if files.is_empty():
		_log("No se encontraron blueprints.")
		status_label.text = "Sin archivos"
		return
	
	progress_bar.max_value = files.size()
	var updated: int = 0
	var skipped: int = 0
	
	for i in files.size():
		var fname: String = files[i]
		var path: String = BLUEPRINT_DIR.path_join(fname)
		var blueprint: BlueprintResource = load(path)
		
		if not blueprint:
			_log_error("No se pudo cargar: %s" % fname)
			skipped += 1
			continue
		
		var bp_id := String(blueprint.blueprint_id)
		var diff: Dictionary = difficulty_map.get(bp_id, {"tier": 2, "speed_mult": 1.0})
		
		_log("\n📦 [%d/%d] %s (Tier %d)" % [i + 1, files.size(), fname, int(diff.tier)])
		
		var changed: bool = false
		
		for trial: TrialResource in blueprint.trial_sequence:
			if not trial.config:
				continue
			
			var config: TrialConfig = trial.config
			
			# 🔥 FORGE
			if config is ForgeTrialConfig:
				_log("  🔥 [Forge] %s" % trial.display_name)
				var forge: ForgeTrialConfig = config
				
				var tier := int(diff.tier)
				var trials_count := 3 if tier <= 1 else (4 if tier <= 3 else 5)
				forge.trials = trials_count
				forge.forge_speed = float(diff.speed_mult)
				forge.precision = 0.3 + (tier * 0.1)
				forge.hardness = 0.3
				config.max_score = float(trials_count * 300)
				
				_log("    • trials=%d, speed=%.1f, precision=%.1f" % [trials_count, forge.forge_speed, forge.precision])
				changed = true
			
			# 🔨 HAMMER
			elif config is HammerTrialConfig:
				_log("  🔨 [Hammer] %s" % trial.display_name)
				var hammer: HammerTrialConfig = config
				
				var tier := int(diff.tier)
				# hammer_speed es int (BPM), rango 60-180
				var base_bpm := 85
				hammer.hammer_speed = int(base_bpm * diff.speed_mult)
				hammer.precision = 0.3 + (tier * 0.1)
				config.max_score = 650.0
				
				_log("    • speed=%d BPM, precision=%.1f" % [hammer.hammer_speed, hammer.precision])
				changed = true
			
			# 🧵 SEW
			elif config is SewTrialConfig:
				_log("  🧵 [Sew] %s" % trial.display_name)
				var sew: SewTrialConfig = config
				
				var tier := int(diff.tier)
				sew.stitch_speed = float(diff.speed_mult)
				sew.precision = 0.35 + (tier * 0.1)
				sew.events = 8
				sew.evasion_threshold = 0.7
				config.max_score = 2400.0
				
				_log("    • speed=%.1f, precision=%.1f, events=%d" % [sew.stitch_speed, sew.precision, sew.events])
				changed = true
			
			# 💧 QUENCH
			elif config is QuenchTrialConfig:
				_log("  💧 [Quench] %s" % trial.display_name)
				var quench: QuenchTrialConfig = config
				
				var tier := int(diff.tier)
				quench.quench_speed = float(diff.speed_mult)
				# time_window: ventana de tolerancia (± segundos), rango 0.1-1.0
				quench.time_window = max(0.15, 0.4 - (tier * 0.05))
				# optimal_time: tiempo óptimo de inmersión
				quench.optimal_time = 1.5
				# catalyst_bonus: multiplicador (1.0-2.0), sin catalizador = 1.0
				quench.catalyst_bonus = 1.0
				config.max_score = 100.0
				
				_log("    • speed=%.1f, time_window=%.2f s" % [quench.quench_speed, quench.time_window])
				changed = true
			
			# Preparar config
			if config.has_method("prepare"):
				config.prepare()
		
		if changed:
			var err: Error = ResourceSaver.save(blueprint, path)
			if err == OK:
				updated += 1
				_log("  ✅ Guardado")
			else:
				_log_error("  ❌ Error al guardar (código %d)" % err)
		else:
			skipped += 1
			_log("  ⏭️  Sin cambios")
		
		progress_bar.value = i + 1
		await get_tree().process_frame
	
	_log("\n" + _repeat_char("━", 60))
	_log("🎉 Actualización completada:")
	_log("  ✅ Actualizados: %d blueprints" % updated)
	_log("  ⏭️  Sin cambios: %d blueprints" % skipped)
	_log("\n⚠️  IMPORTANTE: Reinicia Godot para que los cambios surtan efecto.")
	_log("\n📊 Sistema de dificultad aplicado:")
	_log("  🟢 Tier 1: speed 0.7-0.8, precision 0.3-0.4")
	_log("  🟡 Tier 2-3: speed 0.9-1.1, precision 0.4-0.5")
	_log("  🔴 Tier 4: speed 1.3-1.4, precision 0.6-0.7")
	_log(_repeat_char("━", 60))
	
	status_label.text = "Completado: %d actualizados, %d sin cambios" % [updated, skipped]
