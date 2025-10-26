@tool
extends EditorScript

## Script de editor para añadir blueprint_icon a todos los blueprints
## El icon existente ya representa el item resultante
## Ejecutar desde Editor > Run Script

const BLUEPRINT_FOLDER := "res://data/blueprints/"
const BLUEPRINT_IMAGES := "res://art/assets/Imagenes Raw/Blueprints/"

# Mapeo de blueprint_id a nombres de archivos de blueprint
const BLUEPRINT_MAPPING := {
	&"sword_basic": "sword_basic_bp_raw.png",
	&"sword_advanced": "sword_advanced_bp_raw.png",
	&"sword_masterwork": "sword_master_bp_raw.png",
	&"shield_basic": "shield_basic_bp_raw.png",
	&"shield_wooden": "shield_basic_bp_raw.png",  # Usa mismo blueprint
	&"shield_advanced": "shield_advanced_bp_raw.png",
	&"shield_master": "shield_master_bp_raw.png",
	&"helmet_basic": "helmet_basic_bp_raw.png",
	&"helmet_iron": "helmet_basic_bp_raw.png",  # Usa mismo blueprint
	&"helmet_advanced": "helmet_advanced_bp_raw.png",
	&"helmet_master": "helmet_master_bp_raw.png",
	&"boots_basic": "boots_basic_bp_raw.png",
	&"boots_leather": "boots_basic_bp_raw.png",  # Usa mismo blueprint
	&"boots_advanced": "boots_advanced_bp_raw.png",
	&"boots_master": "boots_master_bp_raw.png",
}

func _run() -> void:
	print("\n" + "=".repeat(60))
	print("ACTUALIZANDO BLUEPRINTS CON ICONOS DE BLUEPRINT")
	print("(icon ya representa el item resultante)")
	print("=".repeat(60))
	
	var dir := DirAccess.open(BLUEPRINT_FOLDER)
	if not dir:
		push_error("No se pudo abrir carpeta: " + BLUEPRINT_FOLDER)
		return
	
	var files := dir.get_files()
	var updated_count := 0
	var error_count := 0
	
	for file in files:
		if not file.ends_with(".tres"):
			continue
		if file == "BlueprintLibrary.tres":
			continue
		
		var full_path := BLUEPRINT_FOLDER + file
		var blueprint: BlueprintResource = load(full_path) as BlueprintResource
		
		if not blueprint:
			push_warning("No se pudo cargar blueprint: " + file)
			error_count += 1
			continue
		
		var blueprint_id := blueprint.blueprint_id
		if not BLUEPRINT_MAPPING.has(blueprint_id):
			push_warning("Blueprint %s no tiene mapeo de imagen" % blueprint_id)
			error_count += 1
			continue
		
		var bp_image_name: String = BLUEPRINT_MAPPING[blueprint_id]
		
		# Cargar blueprint_icon
		var bp_icon_path := BLUEPRINT_IMAGES + bp_image_name
		if ResourceLoader.exists(bp_icon_path):
			var bp_texture := load(bp_icon_path) as Texture2D
			if bp_texture:
				blueprint.blueprint_icon = bp_texture
				print("  ✓ Blueprint icon: %s -> %s" % [blueprint_id, bp_image_name])
			else:
				push_warning("  ✗ No se pudo cargar blueprint_icon: " + bp_icon_path)
				error_count += 1
		else:
			push_warning("  ✗ No existe: " + bp_icon_path)
			error_count += 1
		
		# Guardar blueprint
		var err := ResourceSaver.save(blueprint, full_path)
		if err == OK:
			updated_count += 1
			print("  💾 Guardado: %s\n" % file)
		else:
			push_error("  ✗ Error al guardar %s: %d" % [file, err])
			error_count += 1
	
	print("\n" + "=".repeat(60))
	print("RESUMEN:")
	print("  Blueprints actualizados: %d" % updated_count)
	print("  Errores: %d" % error_count)
	print("=".repeat(60) + "\n")
