extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://scripts/gameplay/visual/StickerSprites.gd"
	if not FileAccess.file_exists(path):
		printerr("FAIL: falta el selector de poses sticker")
		quit(1)
		return
	var runtime: GDScript = load(path)
	var cases := [
		[true, 0.0, 0.0, 0],
		[true, 0.0, 0.8, 1],
		[true, 0.1, 0.8, 2],
		[false, 0.1, 0.8, 3],
	]
	for example in cases:
		if runtime.pose_index(example[0], example[1], example[2]) != example[3]:
			printerr("FAIL: prioridad de pose %s" % str(example))
			quit(1)
			return
	var sheet: Dictionary = runtime.sheet("tico_basic")
	if sheet.is_empty() or sheet.frames != 4 or sheet.texture.get_width() != sheet.frame_px * 4:
		printerr("FAIL: las cuatro poses no son un atlas utilizable")
		quit(1)
		return
	if runtime.sheet("no_existe").size() != 0:
		printerr("FAIL: recurso ausente debe permitir fallback")
		quit(1)
		return
	print("STICKER_RUNTIME_OK: poses, prioridad daño/derrota, atlas y fallback")
	quit(0)
