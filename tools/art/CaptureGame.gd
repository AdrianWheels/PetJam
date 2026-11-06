extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := "res://doc/arte/juego-arte.png"
	var delay := 6.0
	var minigame := ""
	var placement := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--snapshot="):
			output = arg.trim_prefix("--snapshot=")
		elif arg.begins_with("--snapshot-time="):
			delay = float(arg.trim_prefix("--snapshot-time="))
		elif arg.begins_with("--minigame="):
			minigame = arg.trim_prefix("--minigame=")
		elif arg.begins_with("--inspect-placement="):
			placement = arg.trim_prefix("--inspect-placement=")
	var scene := load("res://scenes/tests/VisualCapture.tscn") as PackedScene
	var runner := scene.instantiate()
	root.add_child(runner)
	if not minigame.is_empty():
		await create_timer(0.5).timeout
		var names := {"forge": "ForgeTemp", "hammer": "HammerMinigame", "sew": "SewOSU", "quench": "QuenchWater"}
		var trial_scene := load("res://scenes/Minigames/%s.tscn" % names[minigame]) as PackedScene
		var trial := trial_scene.instantiate()
		var hud: Node = runner._hud()
		hud.set_workshop_trial(minigame)
		hud.minigame_viewport.add_child(trial)
		var config := TrialConfig.new()
		config.minigame_id = StringName(names[minigame])
		trial.start_trial(config)
		trial.title_screen.hide()
		trial.start_game()
	elif OS.get_cmdline_user_args().has("--plan=boss"):
		# El plan histórico llega a la sala 9; la ilustración del jefe se usa en la 10.
		await create_timer(2.2).timeout
		var gm := root.get_node("GameManager")
		gm.current_enemy_level = 9
		gm.advance_enemy_level()
	await create_timer(delay).timeout
	if not placement.is_empty():
		var panel: Control = runner._hud().equipment_panel
		var im := root.get_node("InventoryManager")
		var item: CraftedItem = im.get_loot()[0]
		var at: Vector2 = panel._loot_box.piece_global_point(item)
		panel._on_press(at)
		panel._on_motion(at + Vector2(20, 0))
		var spot := GearPacker.find_spot(im.hero_grid, item)
		if not spot.is_empty():
			panel._drag_rot = spot.rot
		var cell: Vector2i = spot.get("cell", Vector2i.ZERO) if placement == "valid" else Vector2i(5, 5)
		var grab: Vector2 = panel._press.origin - panel._press.pos
		panel._on_motion(panel._hero_view.global_position + Vector2(cell) * GearGridView.CELL - grab)
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output)
	print("ART_GAME_CAPTURE: ", error, " ", output)
	quit()
