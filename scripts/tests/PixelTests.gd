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
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(SAVE_PATH)


func _restore_save() -> void:
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

func test_hero_strip_renders_at_216x96() -> void:
	var hud: Node = load("res://scenes/UI/HUD_Main.tscn").instantiate()
	var panel: SubViewportContainer = hud.get_node("HeroViewPanel")
	var vp: SubViewport = hud.get_node("HeroViewPanel/HeroViewport")
	check(panel.stretch and panel.stretch_shrink == PixelView.SCALE, "el contenedor pinta a 1/5 (%d)" % panel.stretch_shrink)
	check(panel.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "el contenedor amplía con filtro lineal (lo pide el sombreador)")
	var mat := panel.material as ShaderMaterial
	check(mat != null and mat.shader.resource_path == "res://shaders/pixel_upscale.gdshader", "el contenedor usa pixel_upscale")
	check(vp.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "dentro del viewport no se suaviza")
	check(vp.snap_2d_transforms_to_pixel and vp.snap_2d_vertices_to_pixel, "el viewport ajusta a píxel entero")
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
	check(cam.rotation == 0.0 and cam.zoom == Vector2.ONE, "sin giro ni zoom")
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
	check(c.x == hero.position.x and c.y < hero.position.y - 8.0 and c.y > hero.position.y - 20.0, "centro del cuerpo a media altura (%s)" % c)
	hero.queue_free()


func test_hero_sprite_stands_on_the_floor() -> void:
	var hero := _new_hero()
	hero._update_sprite()
	var spr: Sprite2D = hero._sprite
	check(spr.position == Vector2(-16, -29), "en reposo el fotograma apoya los pies en el origen (%s)" % spr.position)
	check(spr.hframes == 2, "tira de reposo de 2 fotogramas")
	check((spr.material as ShaderMaterial).shader.resource_path == "res://shaders/pixel_sprite.gdshader", "usa pixel_sprite")
	hero._strike = 1.0
	hero._update_sprite()
	check(spr.position.x > -16.0, "la estocada lo adelanta hacia el enemigo (%s)" % spr.position)
	hero.queue_free()


func test_hero_sprite_follows_the_sword() -> void:
	var hero := _new_hero()
	var cases := [
		[{}, "tico_0"],
		[{"main_hand": {"tier": "rare", "rarity": "advanced"}}, "tico_1"],
		[{"main_hand": {"tier": "legendary", "rarity": "master"}}, "tico_2"],
	]
	for c in cases:
		hero.gear = c[0]
		hero._apply_sprite()
		check(hero._sprite.texture.resource_path.ends_with("hero/%s.png" % c[1]), "espada %s → %s" % [c[0], c[1]])
	hero.queue_free()


func test_dead_hero_stays_hidden_after_equipping() -> void:
	var hero := _new_hero()
	hero.alive = false
	hero.gear = {"main_hand": {"tier": "common", "rarity": "basic"}}
	hero._apply_sprite()
	hero._update_sprite()
	check(not hero._sprite.visible, "equipar durante la caída no hace reaparecer el sprite")
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
	check(e._sprite.texture.resource_path.ends_with("enemies/slime.png"), "tira del Limo")
	check(e.body_center().y < e.position.y and e.cast_origin().x < e.position.x, "centro sobre los pies y orbe hacia el héroe")
	e.queue_free()


func test_each_biome_has_its_boss_sprite() -> void:
	var e := _new_enemy()
	for i in 5:
		e.configure_for_level((i + 1) * 10, true)
		check(e._sprite.texture.resource_path.ends_with("bosses/boss_%d.png" % i), "jefe de la sala %d" % ((i + 1) * 10))
		check(e.display_name == EnemyArchetypes.BOSS_NAMES[i], "nombre del jefe %d" % i)
	e.queue_free()


func test_enemy_sprite_faces_the_hero_and_stands_on_floor() -> void:
	var e := _new_enemy()
	e.configure_for_level(1, false)
	e.wake()
	e._intro = 1.0
	e._update_sprite()
	check(e._sprite.visible, "despierto y vivo se ve")
	check(e._sprite.position == Vector2(-16, -29), "en reposo apoya los pies en el origen (%s)" % e._sprite.position)
	e._strike = 1.0
	e._update_sprite()
	check(e._sprite.position.x < -16.0, "el golpe lo acerca al héroe (%s)" % e._sprite.position)
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

func test_backdrop_is_plain_and_pixel_sized() -> void:
	var bd := Node2D.new()
	bd.set_script(load("res://scripts/gameplay/visual/DungeonBackdrop.gd"))
	add_child(bd)
	check(bd._layers.size() == 1 and bd._layers[0].kind == "plain", "fase 1: una sola capa lisa")
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


func test_corridor_engages_at_pixel_distance() -> void:
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	var hero: Node2D = corridor.get_node("Hero")
	var enemy: Node2D = corridor.get_node("Enemy")
	check(hero.position == PixelView.HERO_START, "el héroe arranca en HERO_START (%s)" % hero.position)
	check(enemy.position.y == PixelView.FLOOR_Y, "el enemigo pisa el suelo")
	var gap: float = enemy.position.x - hero.position.x
	check(gap >= 150.0, "el enemigo aparece fuera de pantalla por la derecha (a %d px)" % int(gap))
	var t := 0.0
	while t < 8.0 and corridor.state != corridor.State.FIGHT:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(corridor.state == corridor.State.FIGHT, "el héroe llega al enemigo y empieza el combate")
	var dist: float = enemy.position.x - hero.position.x
	check(dist <= hero.reach + enemy.half_width + corridor.ENGAGE_GAP + 1.0, "se engancha a distancia de píxeles (%.1f)" % dist)
	check(dist >= 8.0, "no se solapan (%.1f)" % dist)
	corridor.queue_free()
	await get_tree().process_frame


# ─── Revisión final ────────────────────────────────────────────────────

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
