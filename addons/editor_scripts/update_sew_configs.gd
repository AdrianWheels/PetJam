@tool
extends EditorScript

## 🔧 Script de Editor: Actualiza SewTrialConfig en blueprints existentes
## Añade stitch_speed con valor por defecto si falta

func _run():
	print("🔧 Iniciando actualización de SewTrialConfig...")
	
	var updated := 0
	var skipped := 0
	
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
				
				# Revisar cada trial
				for trial: TrialResource in blueprint.trial_sequence:
					if trial.config and trial.config is SewTrialConfig:
						var sew_config: SewTrialConfig = trial.config
						
						# Verificar si tiene stitch_speed, si no, asignar valor por defecto
						if not sew_config.parameters.has("stitch_speed"):
							print("  📝 Actualizando: %s - Trial: %s" % [file_name, trial.display_name])
							sew_config.stitch_speed = 1.0
							sew_config.prepare()
							changed = true
				
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
