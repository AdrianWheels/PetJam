@tool
extends EditorScript

## 🔧 Script de Editor: Actualiza ForgeTrialConfig en todos los blueprints
## Añade trials, forge_speed y ajusta max_score

func _run():
	print("🔧 Iniciando actualización de ForgeTrialConfig...")
	
	var updated := 0
	var skipped := 0
	
	# Mapeo de dificultad por blueprint (tier aproximado)
	var difficulty_map := {
		# Tier 1 (fácil) - 3 trials, speed 0.7-0.8
		"sword_basic": {"trials": 3, "speed": 0.8, "precision": 0.4},
		"dagger_basic": {"trials": 3, "speed": 0.7, "precision": 0.3},
		"shield_wooden": {"trials": 3, "speed": 0.7, "precision": 0.35},
		
		# Tier 2 (medio-bajo) - 4 trials, speed 0.9-1.0
		"spear_wood": {"trials": 4, "speed": 0.9, "precision": 0.45},
		"mace_stone": {"trials": 4, "speed": 1.0, "precision": 0.5},
		
		# Tier 3 (medio) - 4 trials, speed 1.0-1.2
		"axe_iron": {"trials": 4, "speed": 1.1, "precision": 0.55},
		"armor_iron": {"trials": 4, "speed": 1.0, "precision": 0.5},
		
		# Tier 4 (medio-alto) - 5 trials, speed 1.3-1.5
		"amulet_silver": {"trials": 5, "speed": 1.3, "precision": 0.6},
		"ring_gold": {"trials": 5, "speed": 1.4, "precision": 0.65},
		
		# Especiales
		"potion_heal": {"trials": 3, "speed": 0.9, "precision": 0.4},
	}
	
	# Buscar todos los blueprints
	var dir := DirAccess.open("res://data/blueprints/")
	if not dir:
		print("❌ Error: No se pudo abrir directorio de blueprints")
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "BlueprintLibrary.tres":
			var path := "res://data/blueprints/" + file_name
			var blueprint: BlueprintResource = load(path)
			
			if blueprint:
				var changed := false
				var bp_id := blueprint.blueprint_id
				
				# Revisar cada trial
				for trial: TrialResource in blueprint.trial_sequence:
					if trial.config and trial.config is ForgeTrialConfig:
						var forge_config: ForgeTrialConfig = trial.config
						
						# Obtener configuración de dificultad (o usar default)
						var diff := difficulty_map.get(bp_id, {"trials": 4, "speed": 1.0, "precision": 0.5})
						
						print("  📝 Actualizando: %s - Trial: %s" % [file_name, trial.display_name])
						
						# Actualizar valores
						forge_config.trials = diff.trials
						forge_config.forge_speed = diff.speed
						forge_config.precision = diff.precision
						forge_config.hardness = 0.3  # Valor legacy, mantener para compatibilidad
						
						# Ajustar max_score basado en número de trials (300 pts por trial)
						trial.config.max_score = float(diff.trials * 300)
						
						forge_config.prepare()
						changed = true
						
						print("    • trials=%d, speed=%.1f, precision=%.1f, max_score=%.0f" % 
							[diff.trials, diff.speed, diff.precision, trial.config.max_score])
				
				if changed:
					var err := ResourceSaver.save(blueprint, path)
					if err == OK:
						updated += 1
						print("  ✅ Guardado: %s" % file_name)
					else:
						print("  ❌ Error al guardar: %s (error %d)" % [file_name, err])
				else:
					skipped += 1
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("\n🎉 Actualización completada:")
	print("  ✅ Actualizados: %d blueprints" % updated)
	print("  ⏭️  Sin cambios: %d blueprints" % skipped)
	print("\n⚠️  IMPORTANTE: Reinicia el editor para que los cambios surtan efecto.")
	print("\n📊 Dificultades aplicadas:")
	print("  🟢 Tier 1 (fácil): 3 trials, speed 0.7-0.8")
	print("  🟡 Tier 2-3 (medio): 4 trials, speed 0.9-1.2")
	print("  🔴 Tier 4 (difícil): 5 trials, speed 1.3-1.5")
