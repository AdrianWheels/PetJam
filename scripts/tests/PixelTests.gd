extends Node
## 🧪 Pruebas de la franja de combate pixel (solo desarrollo), sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn
## Sale con código 0 si todo pasa y 1 si algo falla. Guarda y restaura user://save.json
## (las pruebas cargan los autoloads, que pueden autoguardar).

const SAVE_PATH := "user://save.json"

var _checks := 0
var _failures := 0
var _had_save := false
var _save_backup := PackedByteArray()
var _errors := ErrorCounter.new()


## Cuenta los errores (de script, de motor y de sombreador) que salen durante las pruebas.
## Un error corta la función de la prueba sin avisar al lanzador: así la prueba falla igualmente.
class ErrorCounter extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			count += 1


func _ready() -> void:
	await _wait_for_game_data()
	_backup_save()
	OS.add_logger(_errors)
	for m in get_method_list():
		var method_name: String = m.name
		if not method_name.begins_with("test_"):
			continue
		var before := _failures
		var checks_before := _checks
		var errors_before := _errors.count
		await call(method_name)
		if _errors.count > errors_before:
			check(false, "%s provocó %d errores (ver la salida)" % [method_name, _errors.count - errors_before])
		elif _checks == checks_before:
			check(false, "%s terminó sin ninguna comprobación" % method_name)
		print("%s %s" % ["ok   " if _failures == before else "FALLO", method_name])
	OS.remove_logger(_errors)
	# GameManager guarda en diferido (call_deferred): se deja que terminen esos guardados antes de
	# restaurar la partida, o escribirían encima de la copia restaurada
	for i in 3:
		await get_tree().process_frame
	_restore_save()
	print("[PixelTests] %d comprobaciones, %d fallos" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("  ✗ ", msg)


## GameManager carga la partida unos fotogramas después de arrancar (cuando DataManager tiene los planos)
## y guarda al cargarla. Se espera a que termine: así la copia de seguridad es la buena y la carga no
## llega en mitad de una prueba.
func _wait_for_game_data() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var waited := 0.0
	while gm and gm.has_method("is_save_loaded") and not gm.is_save_loaded() and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	for i in 5:
		await get_tree().process_frame  # deja pasar los guardados diferidos de la carga


func _backup_save() -> void:
	if OS.get_cmdline_user_args().has("--art-preview"):
		return
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(SAVE_PATH)


func _restore_save() -> void:
	if OS.get_cmdline_user_args().has("--art-preview"):
		return
	if _had_save:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(_save_backup)
		f.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ─── Tarea 3: ayudantes ────────────────────────────────────────────────

func test_pixel_view_scales_to_the_strip() -> void:
	check(PixelView.VIEW_SIZE * PixelView.SCALE == Vector2(1080, 480), "216x96 por 5 debe dar la franja de 1080x480")
	check(PixelView.HERO_START.y == PixelView.FLOOR_Y, "el héroe empieza sobre el suelo")


func test_pixel_sprites_load_with_metrics() -> void:
	var keys := ["hero/tico_0", "hero/tico_1", "hero/tico_2", "enemies/slime", "enemies/skeleton",
		"enemies/bat", "enemies/golem", "enemies/wraith", "bosses/boss_0", "bosses/boss_1",
		"bosses/boss_2", "bosses/boss_3", "bosses/boss_4"]
	for key in keys:
		var m := PixelSprites.metrics(key)
		var tex := PixelSprites.texture(key)
		check(not m.is_empty(), "medidas de " + key)
		check(tex != null and tex.get_width() == int(m.get("frame_w", 0)) * int(m.get("frames", 0)), "tira de " + key)
	check(PixelSprites.metrics("no/existe").is_empty(), "una clave desconocida devuelve medidas vacías")


func test_enemy_sprite_keys() -> void:
	check(PixelSprites.enemy_key(&"slime", 3) == "enemies/slime", "enemigo normal")
	check(PixelSprites.enemy_key(&"boss", 10) == "bosses/boss_0", "jefe de Catacumbas")
	check(PixelSprites.enemy_key(&"boss", 50) == "bosses/boss_4", "jefe del Santuario del Vacío")
	check(PixelSprites.enemy_key(&"boss", 60) == "bosses/boss_0", "los jefes ciclan con los biomas")


func test_pixel_fonts() -> void:
	check(PixelFont.small() != null and PixelFont.big() != null, "las dos fuentes cargan")
	check(PixelFont.width("AB") == 8, "A y B avanzan 4 px cada una (%d)" % PixelFont.width("AB"))
	check(PixelFont.width("ab") == PixelFont.width("AB"), "el texto se pasa a mayúsculas")
	check(PixelFont.width("MW") == 12, "M y W avanzan 6 px (%d)" % PixelFont.width("MW"))
	check(PixelFont.width("HERALDO DEL VACÍO NV 150") < int(PixelView.VIEW_W), "el nombre de jefe más largo cabe en la franja")
	check(int(PixelFont.small().get_height(PixelFont.SMALL_SIZE)) == PixelFont.SMALL_SIZE, "alto de línea de la pequeña")
	check(int(PixelFont.big().get_height(PixelFont.BIG_SIZE)) == PixelFont.BIG_SIZE, "alto de línea de la grande")


# ─── Tarea 4: viewport x5 ──────────────────────────────────────────────

func test_hero_strip_renders_illustrations_at_full_resolution() -> void:
	var hud: Node = load("res://scenes/UI/HUD_Main.tscn").instantiate()
	var panel: SubViewportContainer = hud.get_node("HeroViewPanel")
	var vp: SubViewport = hud.get_node("HeroViewPanel/HeroViewport")
	check(panel.stretch and panel.stretch_shrink == 1, "el contenedor pinta a resolución completa")
	check(panel.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "el contenedor amplía con filtro lineal (lo pide el sombreador)")
	check(panel.material == null, "las ilustraciones no pasan por pixel_upscale")
	check(vp.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR, "filtrado lineal para ilustración")
	check(vp.size == Vector2i(1080, 480), "viewport 1080×480")
	hud.free()


func test_sprite_shader_has_flash_and_dissolve() -> void:
	var shader := load("res://shaders/pixel_sprite.gdshader") as Shader
	var names := shader.get_shader_uniform_list().map(func(u): return u.name)
	check("flash" in names and "dissolve" in names, "pixel_sprite tiene flash y dissolve (%s)" % [names])


# ─── Tarea 5: cámara ───────────────────────────────────────────────────

func test_camera_moves_in_whole_pixels() -> void:
	var cam := Camera2D.new()
	cam.set_script(load("res://scripts/gameplay/visual/CorridorCamera.gd"))
	add_child(cam)
	cam.snap_to(10.4, 48.0)
	check(cam.position == Vector2(10, 48), "snap_to redondea a píxel entero (%s)" % cam.position)
	cam.set_target_x(57.3)
	for i in 5:
		cam._process(0.05)
		check(cam.position.x == roundf(cam.position.x), "la cámara sigue en píxeles enteros (%s)" % cam.position)
	cam.add_trauma(1.0)
	for i in 10:
		cam._process(0.016)
		check(absf(cam.offset.x) <= 3.0 and absf(cam.offset.y) <= 2.0, "el temblor no pasa de 3x2 (%s)" % cam.offset)
		check(cam.offset == cam.offset.round(), "el temblor es de píxeles enteros (%s)" % cam.offset)
	cam.punch(0.2)
	cam._process(0.016)
	var expected_zoom := cam.get_viewport_rect().size.x / float(PixelView.VIEW_W)
	check(cam.rotation == 0.0 and cam.zoom == Vector2.ONE * expected_zoom, "escala fija conserva el mundo lógico")
	cam.queue_free()


# ─── Tarea 6: Tico ─────────────────────────────────────────────────────

func _new_hero() -> Node2D:
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")  # que no lo confundan con el héroe de la partida
	add_child(hero)
	return hero


func test_hero_uses_pixel_units() -> void:
	var hero := _new_hero()
	check(hero.reach == 9.0 and hero.half_width == 6.0, "alcance y medio ancho en píxeles del arte")
	hero.respawn(PixelView.HERO_START)
	check(hero.position == PixelView.HERO_START, "reaparece en HERO_START")
	var c: Vector2 = hero.body_center()
	check(c.x == hero.position.x and c.y < hero.position.y - 8.0 and is_equal_approx(c.y, hero.position.y - 43.2), "centro del cuerpo a media altura (%s)" % c)
	hero.queue_free()


func test_hero_sprite_stands_on_the_floor() -> void:
	var hero := _new_hero()
	hero._update_sprite()
	var spr: Sprite2D = hero._sprite
	check(spr.position.is_equal_approx(spr.get_meta("sticker_origin")), "posición de la pegatina respecto a los pies (%s)" % spr.position)
	check(spr.hframes == 4 and spr.frame == 0, "cuatro poses con reposo fijo")
	check((spr.material as ShaderMaterial).shader.resource_path == "res://shaders/pixel_sprite.gdshader", "usa pixel_sprite")
	hero._strike = 1.0
	hero._update_sprite()
	check(spr.position.is_equal_approx(spr.get_meta("sticker_origin")) and spr.frame == 1, "el golpe cambia de pose y conserva la posición")
	hero.queue_free()


func test_hero_sprite_follows_the_sword() -> void:
	var hero := _new_hero()
	var cases := [
		[{}, "tico_none"],
		[{"main_hand": {"tier": "common", "rarity": "basic"}}, "tico_basic"],
		[{"main_hand": {"tier": "rare", "rarity": "advanced"}}, "tico_advanced"],
		[{"main_hand": {"tier": "legendary", "rarity": "master"}}, "tico_master"],
	]
	for c in cases:
		hero.gear = c[0]
		hero._apply_sprite()
		check(hero._sprite.get_meta("sticker_key", "") == c[1], "espada %s → %s" % [c[0], c[1]])
	hero.queue_free()


func test_dead_hero_keeps_defeat_pose_after_equipping() -> void:
	var hero := _new_hero()
	hero.alive = false
	hero.gear = {"main_hand": {"tier": "common", "rarity": "basic"}}
	hero._apply_sprite()
	hero._update_sprite()
	check(hero._sprite.visible and hero._sprite.frame == 3, "equipar durante la caída mantiene la pose derrotada")
	hero.queue_free()


# ─── Tarea 7: enemigos ─────────────────────────────────────────────────

func _new_enemy() -> Node2D:
	var e: Node2D = load("res://scenes/Enemy.tscn").instantiate()
	e.remove_from_group("enemy")
	add_child(e)
	return e


func test_enemy_takes_sprite_and_size_from_metrics() -> void:
	var e := _new_enemy()
	e.configure_for_level(1, false)  # sala 1 de Catacumbas: siempre un Limo
	check(e.archetype == &"slime", "la sala 1 trae un Limo")
	var m := PixelSprites.metrics("enemies/slime")
	check(e.half_width == float(m.half_width) and e.body_height == float(m.body_height), "medidas del sprite")
	check(e._sprite.get_meta("sticker_key", "") == "slime", "hoja de poses del Limo")
	check(e.body_center().y < e.position.y and e.cast_origin().x < e.position.x, "centro sobre los pies y orbe hacia el héroe")
	e.queue_free()


func test_each_biome_has_its_boss_sprite() -> void:
	var e := _new_enemy()
	for i in 5:
		e.configure_for_level((i + 1) * 10, true)
		check(e._sprite.get_meta("sticker_key", "") == "boss_%d" % i, "jefe de la sala %d" % ((i + 1) * 10))
		check(e.display_name == EnemyArchetypes.BOSS_NAMES[i], "nombre del jefe %d" % i)
	e.queue_free()


func test_enemy_sprite_faces_the_hero_and_stands_on_floor() -> void:
	var e := _new_enemy()
	e.configure_for_level(1, false)
	e.wake()
	e._intro = 1.0
	e._update_sprite()
	check(e._sprite.visible, "despierto y vivo se ve")
	check(e._sprite.position.is_equal_approx(e._sprite.get_meta("sticker_origin")), "posición de la pegatina del enemigo (%s)" % e._sprite.position)
	e._strike = 1.0
	e._update_sprite()
	check(e._sprite.position.is_equal_approx(e._sprite.get_meta("sticker_origin")) and e._sprite.frame == 1, "pose de golpe hacia el héroe (%s)" % e._sprite.position)
	e.queue_free()


func test_names_do_not_overlap_in_combat() -> void:
	var hero := _new_hero()
	var e := _new_enemy()
	var hero_x := PixelView.VIEW_W * PixelView.HERO_SCREEN_X
	for id in [&"slime", &"skeleton", &"bat", &"golem", &"wraith"]:
		e.level = 99
		e._apply_archetype(id)
		_check_labels(hero, e, hero_x)
	for room in [60, 70, 80, 90, 100]:
		e.configure_for_level(room, true)
		_check_labels(hero, e, hero_x)
	hero.queue_free()
	e.queue_free()


func _check_labels(hero: Node2D, e: Node2D, hero_x: float) -> void:
	var ex: float = hero_x + hero.reach + e.half_width + 3.0
	var hl: Rect2 = hero.hud_label_rect()
	hl.position += Vector2(hero_x, PixelView.FLOOR_Y)
	var el: Rect2 = e.hud_label_rect()
	el.position += Vector2(ex, PixelView.FLOOR_Y)
	check(not hl.intersects(el), "los nombres de Tico y %s no se pisan" % e.hud_label())
	check(el.end.x <= PixelView.VIEW_W, "%s cabe en la franja (acaba en %d)" % [e.hud_label(), int(el.end.x)])
	check(el.position.y >= 0.0, "%s no se sale por arriba" % e.hud_label())


# ─── Tarea 8: efectos ──────────────────────────────────────────────────

func _new_fx() -> Node2D:
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/gameplay/visual/CombatFX.gd"))
	add_child(fx)
	return fx


func test_fx_texts_use_pixel_fonts() -> void:
	var fx := _new_fx()
	fx.damage_number(Vector2(100, 40), 12, &"normal")
	fx.damage_number(Vector2(100, 40), 30, &"crit")
	fx.float_text(Vector2(100, 30), "¡Jefe derrotado!", Color.GOLD, true)
	var texts: Array = fx._parts.filter(func(p): return p.kind == fx.Kind.TEXT)
	check(texts.size() == 3, "tres textos en cola (%d)" % texts.size())
	check(not texts[0].big and texts[1].big and texts[2].big, "el crítico y el cartel usan la fuente grande")
	check(texts[1].text == "30!", "el crítico lleva exclamación")
	check(absf(texts[0].vel.y) < 25.0, "velocidades en píxeles del arte (%s)" % texts[0].vel)
	fx.queue_free()


func test_fx_shatter_bounces_on_pixel_floor() -> void:
	var fx := _new_fx()
	fx.shatter(Vector2(100, 60), [Color.RED], 4)
	check(fx._parts.size() == 4, "cuatro fragmentos")
	check(fx._parts[0].floor == PixelView.FLOOR_Y - 1.0, "rebotan en el suelo de la franja (%s)" % fx._parts[0].floor)
	fx.queue_free()


# ─── Tarea 9: pasillo ──────────────────────────────────────────────────

func test_backdrop_illustrations_cover_the_logical_strip() -> void:
	var bd := Node2D.new()
	bd.set_script(load("res://scripts/gameplay/visual/DungeonBackdrop.gd"))
	add_child(bd)
	for index in 5:
		bd.set_biome(index, false)
		check(bd._illustrated.texture.resource_path.ends_with("biome_%d.png" % index), "ilustración del bioma %d" % index)
		var coverage: Vector2 = bd._illustrated.texture.get_size() * bd._illustrated.scale
		check(coverage.is_equal_approx(PixelView.VIEW_SIZE), "el fondo cubre toda la franja sin huecos")
	check(not bd._layers[0].visible, "el fondo procedural queda como respaldo")
	check(bd._flash_rect.size == PixelView.VIEW_SIZE, "el destello cubre la franja de 216x96")
	check(bd._torches.is_empty(), "sin antorchas vectoriales")
	bd.queue_free()


func test_gate_plate_fits_the_room_number() -> void:
	var gate := Node2D.new()
	gate.set_script(load("res://scripts/gameplay/visual/RoomGate.gd"))
	add_child(gate)
	gate.setup(7, 100.0, Biomes.get_biome(0))
	var w1: float = gate.plate_rect().size.x
	gate.setup(120, 100.0, Biomes.get_biome(0))
	check(gate.plate_rect().size.x > w1, "la placa crece con las cifras")
	check(gate.plate_rect().size.x >= PixelFont.width("120") + 2, "el número cabe en la placa")
	gate.queue_free()


func test_corridor_duels_use_fixed_positions() -> void:
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	var hero: Node2D = corridor.hero
	var enemy: Node2D = corridor.enemy
	var hero_spot: Vector2 = hero.position
	var enemy_spot: Vector2 = enemy.position
	check(hero_spot == corridor.HERO_START and enemy_spot == corridor.ENEMY_SPOT, "frente a frente en las posiciones del duelo")
	var t := 0.0
	while t < 2.0 and corridor.state != corridor.State.FIGHT:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(corridor.state == corridor.State.FIGHT, "el duelo comienza sin desplazamiento")
	check(hero.position == hero_spot and enemy.position == enemy_spot, "el inicio conserva ambas posiciones")
	check(not hero.walking and not hero.show_hud and enemy.duel_presentation, "reposo fijo y HUD separado")
	for i in 20:
		await get_tree().process_frame
	check(hero.position == hero_spot and enemy.position == enemy_spot, "golpear no mueve a los combatientes")
	var atlas := StickerSprites.sheet("tico_none")
	var height: float = atlas.idle_rect.size.y * hero._sprite.scale.y
	check(is_equal_approx(height / PixelView.VIEW_H, 0.90), "Tico visible ocupa el 90 % de la altura")
	corridor.queue_free()
	await get_tree().process_frame


func test_next_enemy_stays_hidden_during_hitstop() -> void:
	var e := _new_enemy()
	e.configure_for_level(1, false)
	e.wake()
	e._intro = 1.0
	e._update_sprite()
	check(e._sprite.visible, "el enemigo despierto se ve")
	e.process_mode = Node.PROCESS_MODE_DISABLED  # hit-stop tras la muerte: el enemigo no procesa
	e.configure_for_level(2, false)  # el Corridor lo recoloca como el enemigo de la sala siguiente
	check(not e._sprite.visible, "el siguiente enemigo no asoma por el borde durante el hit-stop")
	e.queue_free()
