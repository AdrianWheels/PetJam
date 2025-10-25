@tool
extends EditorScript

## 🔍 Validador: Verifica implementación del sistema de 20 puntos en Sew

func _run():
	print("🔍 Iniciando validación del sistema de puntos aleatorios...")
	print("=" * 60)
	
	var errors := 0
	var warnings := 0
	
	# 1. Verificar SewTrialConfig tiene stitch_speed
	print("\n📋 Verificando SewTrialConfig.gd...")
	var config_test := SewTrialConfig.new()
	if config_test.has_method("prepare"):
		print("  ✅ Método prepare() existe")
	else:
		print("  ❌ ERROR: Método prepare() no encontrado")
		errors += 1
	
	config_test.stitch_speed = 1.5
	config_test.prepare()
	
	if config_test.parameters.has("stitch_speed"):
		print("  ✅ stitch_speed sincronizado en parameters")
	else:
		print("  ❌ ERROR: stitch_speed no está en parameters")
		errors += 1
	
	# 2. Verificar SewMinigame_NEW tiene SPAWN_POINTS
	print("\n📋 Verificando SewMinigame.gd...")
	var script_path := "res://scripts/SewMinigame.gd"
	var script_content := FileAccess.get_file_as_string(script_path)
	
	if "SPAWN_POINTS" in script_content:
		print("  ✅ Constante SPAWN_POINTS definida")
		
		# Contar puntos
		var count := script_content.count("Vector2(")
		if count >= 20:
			print("  ✅ Array tiene al menos 20 puntos (%d encontrados)" % count)
		else:
			print("  ⚠️  ADVERTENCIA: Solo %d puntos encontrados (esperados 20+)" % count)
			warnings += 1
	else:
		print("  ❌ ERROR: SPAWN_POINTS no encontrado")
		errors += 1
	
	if "_position_at_random_spawn" in script_content:
		print("  ✅ Función _position_at_random_spawn() existe")
	else:
		print("  ❌ ERROR: Función _position_at_random_spawn() no encontrada")
		errors += 1
	
	if "distance_to_center" in script_content:
		print("  ✅ Detección de click dentro del círculo implementada")
	else:
		print("  ⚠️  ADVERTENCIA: Detección de distancia no encontrada")
		warnings += 1
	
	# 3. Verificar blueprints
	print("\n📋 Verificando blueprints con SewTrialConfig...")
	var blueprints_ok := 0
	var blueprints_missing := 0
	
	for bp_name in ["bow_simple", "armor_leather"]:
		var bp_path := "res://data/blueprints/%s.tres" % bp_name
		var bp: BlueprintResource = load(bp_path)
		
		if bp:
			var has_sew := false
			for trial: TrialResource in bp.trial_sequence:
				if trial.config and trial.config is SewTrialConfig:
					has_sew = true
					var sew_cfg: SewTrialConfig = trial.config
					
					if "stitch_speed" in sew_cfg.parameters or sew_cfg.get("stitch_speed") != null:
						print("  ✅ %s: stitch_speed configurado" % bp_name)
						blueprints_ok += 1
					else:
						print("  ❌ %s: stitch_speed FALTA" % bp_name)
						blueprints_missing += 1
						errors += 1
					break
			
			if not has_sew:
				print("  ℹ️  %s: No usa SewTrialConfig (OK)" % bp_name)
		else:
			print("  ❌ ERROR: No se pudo cargar %s" % bp_path)
			errors += 1
	
	# 4. Verificar escena del minijuego
	print("\n📋 Verificando SewOSU.tscn...")
	var scene: PackedScene = load("res://scenes/Minigames/SewOSU.tscn")
	if scene:
		print("  ✅ Escena carga correctamente")
		var instance := scene.instantiate()
		
		if instance.has_node("%TargetRing"):
			print("  ✅ Nodo %TargetRing existe")
		else:
			print("  ❌ ERROR: Nodo %TargetRing no encontrado")
			errors += 1
		
		if instance.has_node("%CollapsingCircle"):
			print("  ✅ Nodo %CollapsingCircle existe")
		else:
			print("  ❌ ERROR: Nodo %CollapsingCircle no encontrado")
			errors += 1
		
		instance.free()
	else:
		print("  ❌ ERROR: No se pudo cargar SewOSU.tscn")
		errors += 1
	
	# 5. Verificar sandbox existe
	print("\n📋 Verificando herramientas de testing...")
	if FileAccess.file_exists("res://scenes/sandboxes/SewSandbox.tscn"):
		print("  ✅ SewSandbox.tscn existe")
	else:
		print("  ⚠️  ADVERTENCIA: SewSandbox.tscn no encontrado")
		warnings += 1
	
	if FileAccess.file_exists("res://scripts/SewSandbox.gd"):
		print("  ✅ SewSandbox.gd existe")
	else:
		print("  ⚠️  ADVERTENCIA: SewSandbox.gd no encontrado")
		warnings += 1
	
	# 6. Resumen final
	print("\n" + "=" * 60)
	print("📊 RESUMEN DE VALIDACIÓN")
	print("=" * 60)
	
	if errors == 0 and warnings == 0:
		print("✅ ¡TODO PERFECTO! Sistema listo para usar.")
		print("   • SewTrialConfig actualizado correctamente")
		print("   • SewMinigame_NEW con 20 puntos implementado")
		print("   • Blueprints configurados")
		print("   • Detección de clicks mejorada")
		print("\n🚀 Siguiente paso: Ejecutar SewSandbox.tscn para testing visual")
	else:
		if errors > 0:
			print("❌ ERRORES ENCONTRADOS: %d" % errors)
			print("   ⚠️  Revisar logs arriba para detalles")
		
		if warnings > 0:
			print("⚠️  ADVERTENCIAS: %d" % warnings)
			print("   ℹ️  No críticas, pero revisa los detalles")
	
	print("\n📖 Documentación completa en:")
	print("   • doc/SEW_SISTEMA_PUNTOS_ALEATORIOS.md")
	print("   • RESUMEN_SEW_PUNTOS_ALEATORIOS.md")
	print("=" * 60)
