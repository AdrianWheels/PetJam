extends SceneTree

## Empaquetado técnico: los originales generados se conservan intactos.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://doc/arte/inventario-produccion.json"))
	var total := 0
	for entry in manifest.records:
		if entry.category != "gear":
			continue
		var input_path: String = "res://" + entry.source
		if not FileAccess.file_exists(input_path):
			continue
		var image := Image.load_from_file(input_path)
		var extent := Vector2i.ONE
		for cell in entry.cells:
			extent.x = maxi(extent.x, int(cell[0]) + 1)
			extent.y = maxi(extent.y, int(cell[1]) + 1)
		image.resize(extent.x * 110, extent.y * 110, Image.INTERPOLATE_LANCZOS)
		var output: String = "res://art/stickers/gear/" + String(entry.id).get_file() + ".png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
		var error := image.save_png(output)
		if error != OK:
			printerr("ART_BUILD_FAIL: ", output)
			quit(1)
			return
		total += 1
	print("ART_BUILD_OK: ", total, " piezas a 110 px/casilla")
	quit()
