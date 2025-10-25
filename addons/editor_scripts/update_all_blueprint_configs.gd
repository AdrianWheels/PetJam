@tool
extends EditorScript

## 🔧 Script de Editor: Actualiza TODOS los TrialConfig en blueprints
## Añade parámetros de velocidad, trials, y precision según el tipo de minijuego

func _run():
	print("🔧 Iniciando actualización COMPLETA de todos los TrialConfigs...")
	
	var updated := 0
	var skipped := 0
	
	# Mapeo de dificultad por blueprint (tier aproximado)
	var difficulty_map := {
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
				
				# Obtener configuración de dificultad (o usar default)
				var diff := difficulty_map.get(bp_id, {"tier": 2, "speed_mult": 1.0})
				
				print("\n📦 Procesando: %s (Tier %d)" % [file_name, diff.tier])
				
				# Revisar cada trial
				for trial: TrialResource in blueprint.trial_sequence:
					if not trial.config:
						continue
					
					var config := trial.config
					var config_type := config.get_class()
					
					# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
					# 🔥 FORGE
					# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
					if config is ForgeTrialConfig:
						print("  🔥 [Forge] %s" % trial.display_name)
						var forge: ForgeTrialConfig = config
						
						# Trials según tier
						var trials_count := 3 if diff.tier <= 1 else (4 if diff.tier <= 3 else 5)
						forge.trials = trials_count
						forge.forge_speed = diff.speed_mult
						forge.precision = 0.3 + (diff.tier * 0.1)  # 0.3→0.4→0.5→0.6
						forge.hardness = 0.3
						config.max_score = float(trials_count * 300)
						
						print("    • trials=%d, speed=%.1f, precision=%.1f" % [trials_count, forge.forge_speed, forge.precision])
						changed = true
					
					# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
					# 🔨 HAMMER
					# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
					elif config is HammerTrialConfig:
						print("  🔨 [Hammer] %s" % trial.display_name)
						var hammer: HammerTrialConfig = config
						
						hammer.hammer_speed = diff.speed_mult
						hammer.precision = 0.3 + (diff.tier * 0.1)
						config.max_score = 650.0
						
						print("    • speed=%.1f, precision=%.1f" % [hammer.hammer_speed, hammer.precision])
						changed = true
					
					# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
					# 🧵 SEW
					# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
					elif config is SewTrialConfig:
						print("  🧵 [Sew] %s" % trial.display_name)
						var sew: SewTrialConfig = config
						
						sew.stitch_speed = diff.speed_mult
						sew.precision = 0.35 + (diff.tier * 0.1)
						sew.events = 8  # Siempre 8 eventos por ahora
						sew.evasion_threshold = 0.7
						config.max_score = 2400.0
						
						print("    • speed=%.1f, precision=%.1f, events=%d" % [sew.stitch_speed, sew.precision, sew.events])
						changed = true
					
					# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
					# 💧 QUENCH
					# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
					elif config is QuenchTrialConfig:
						print("  💧 [Quench] %s" % trial.display_name)
						var quench: QuenchTrialConfig = config
						
						quench.quench_speed = diff.speed_mult
						quench.window = 1.0 - (diff.tier * 0.1)  # Ventana más pequeña = más difícil
						quench.catalyst = false
						config.max_score = 100.0
						
						print("    • speed=%.1f, window=%.1f" % [quench.quench_speed, quench.window])
						changed = true
					
					# Preparar config
					if config.has_method("prepare"):
						config.prepare()
				
				if changed:
					var err := ResourceSaver.save(blueprint, path)
					if err == OK:
						updated += 1
						print("  ✅ Guardado: %s" % file_name)
					else:
						print("  ❌ Error al guardar: %s (error %d)" % [file_name, err])
				else:
					skipped += 1
					print("  ⏭️  Sin cambios")
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("\n" + "━" * 60)
	print("🎉 Actualización completada:")
	print("  ✅ Actualizados: %d blueprints" % updated)
	print("  ⏭️  Sin cambios: %d blueprints" % skipped)
	print("\n⚠️  IMPORTANTE: Reinicia Godot para que los cambios surtan efecto.")
	print("\n📊 Sistema de dificultad aplicado:")
	print("  🟢 Tier 1: speed 0.7-0.8, precision 0.3-0.4")
	print("  🟡 Tier 2-3: speed 0.9-1.1, precision 0.4-0.5")
	print("  🔴 Tier 4: speed 1.3-1.4, precision 0.6-0.7")
	print("━" * 60)
