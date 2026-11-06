extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)

func _run() -> void:
	var path := "res://scripts/gameplay/visual/StickerSprites.gd"
	if not FileAccess.file_exists(path):
		_fail("falta el selector de poses sticker")
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
			_fail("prioridad de pose %s" % str(example))
			return
	# anim_frame(vivo, reloj, desde_caída, desde_golpe, anticipación, golpe) → fila * 8 + columna
	var frames := [
		[[true, 0.0, 0.0, 99.0, 0.0, 0.0], 0, "reposo al empezar"],
		[[true, 0.5, 0.0, 99.0, 0.0, 0.0], 4, "el reposo avanza con el reloj"],
		[[true, 1.0, 0.0, 99.0, 0.0, 0.0], 0, "el reposo vuelve a empezar"],
		[[true, 0.0, 0.0, 99.0, 0.6, 0.0], 10, "la anticipación sigue al windup"],
		[[true, 0.0, 0.0, 99.0, 0.0, 1.0], 12, "el impacto cae cuando salta el golpe"],
		[[true, 0.0, 0.0, 99.0, 0.0, 0.1], 15, "la inercia acaba en la guardia"],
		[[true, 0.0, 0.0, 0.05, 0.0, 1.0], 16, "un golpe recibido manda sobre el ataque"],
		[[true, 0.0, 0.0, 0.3, 0.0, 0.0], 20, "la recuperación del daño sigue"],
		[[true, 0.0, 0.0, 0.3, 0.5, 0.0], 10, "atacar corta la recuperación"],
		[[false, 0.0, 0.0, 0.05, 0.0, 1.0], 24, "la derrota manda sobre todo"],
		[[false, 0.0, 5.0, 99.0, 0.0, 0.0], 31, "la derrota se queda en su última pose"],
	]
	for example in frames:
		var a: Array = example[0]
		var got: int = runtime.anim_frame(a[0], a[1], a[2], a[3], a[4], a[5])
		if got != example[1]:
			_fail("%s: %d en vez de %d" % [example[2], got, example[1]])
			return
	for key in ["tico_none", "tico_basic", "tico_advanced", "tico_master", "slime", "bat", "skeleton", "golem", "wraith",
			"boss_0", "boss_1", "boss_2", "boss_3", "boss_4", "brasa"]:
		var sheet: Dictionary = runtime.sheet(key)
		if sheet.is_empty() or not sheet.get("animated", false) or sheet.frames != 8 or sheet.rows != 4:
			_fail("%s no tiene rejilla animada de 8×4" % key)
			return
		if sheet.texture.get_width() != sheet.frame_size.x * 8 or sheet.texture.get_height() != sheet.frame_size.y * 4:
			_fail("%s: la rejilla no se divide en fotogramas iguales" % key)
			return
		var idle: Rect2i = sheet.idle_rect
		if idle.size.y < sheet.frame_size.y / 3 or idle.end.y > sheet.frame_size.y:
			_fail("%s: el reposo no ocupa su fotograma (%s)" % [key, idle])
			return
	if runtime.sheet("no_existe").size() != 0:
		_fail("recurso ausente debe permitir fallback")
		return
	print("STICKER_RUNTIME_OK: poses, rejillas animadas de los 15 personajes, prioridades y fallback")
	quit(0)
