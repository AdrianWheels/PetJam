extends Node2D

## Corredor endless: el héroe avanza sala a sala y lucha contra un enemigo por sala.
## El estado de juego vive en GameManager; aquí va la presentación del combate:
## cámara (héroe al tercio izquierdo), escenario por biomas, puertas numeradas, despertar de enemigos,
## hit-stop local (nunca congela los minijuegos), botín visible y transiciones de muerte/reaparición.

signal room_entered(room: int, is_boss: bool)
signal biome_entered(biome_index: int, display_name: String)
signal boss_appeared(room: int, boss_name: String)
signal boss_slain(room: int, boss_name: String)
signal loot_dropped(kind: StringName, world_pos: Vector2, payload: Dictionary)
signal hero_fell(room: int)
signal hero_returned

@onready var hero: Node = $Hero
@onready var enemy: Node = $Enemy
@onready var combat_controller: Node = $CombatController
@onready var camera: Camera2D = $Camera2D
@onready var backdrop: Node2D = $Backdrop
@onready var fx: Node2D = $CombatFX
@onready var _gates: Array = [$GateA, $GateB]

# Medidas en píxeles del arte (216x96): las de 1080x480 divididas entre 5
const HERO_SPEED := 38.0
const FLOOR_Y := PixelView.FLOOR_Y
const VIEW_W := PixelView.VIEW_W
const VIEW_H := PixelView.VIEW_H
const HERO_SCREEN_X := PixelView.HERO_SCREEN_X  # posición del héroe en pantalla (fracción del ancho)
const SPAWN_AHEAD := 160.0  # el enemigo aparece justo fuera de pantalla por la derecha
const BOSS_EXTRA_DISTANCE := 52.0  # el jefe entra en pantalla andando, no de golpe
const GATE_BEFORE_ENEMY := 66.0
const ENGAGE_GAP := 3.0
const HERO_START := PixelView.HERO_START
const BOSS_INTERVAL := 10  # Boss cada 10 niveles (coincide con Biomes.ROOMS_PER_BIOME)
const RESPAWN_DELAY := 1.5
const POST_KILL_PAUSE := 0.45
const FIRST_STEP_PAUSE := 0.35

enum State { RUN, FIGHT, DEAD, COMPLETE }

var state := State.RUN
var level := 1
var ground_offset := 0.0  # Distancia recorrida desde la última reaparición
var dist_ref := 0.0

var _respawn_timer: Timer
var _game_manager: Node
var _hitstop := 0.0
var _frozen := false
var _pause := 0.0
var _gate_index := 0
var _next_gate_x := INF
var _next_gate_room := 1
var _next_gate: Node = null
var _material_cache: Dictionary = {}


func _ready():
	_game_manager = get_node_or_null("/root/GameManager")

	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.wait_time = RESPAWN_DELAY
	add_child(_respawn_timer)
	_respawn_timer.timeout.connect(_on_respawn_timeout)

	hero.fx = fx
	enemy.fx = fx
	if hero.has_signal("died"):
		hero.died.connect(_on_local_hero_died)
	if enemy.has_signal("stats_reset"):
		enemy.stats_reset.connect(_on_enemy_stats_reset)
	# Se conecta después que CombatController: cuando llega aquí el enemigo ya se ha recolocado,
	# por eso Enemy guarda death_info antes de emitir.
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died_fx)
	if backdrop.has_signal("biome_changed"):
		backdrop.biome_changed.connect(func(idx: int, biome_name: String): biome_entered.emit(idx, biome_name))

	if _game_manager:
		_game_manager.hero_died.connect(_on_game_manager_hero_died)
		_game_manager.hero_respawned.connect(_on_game_manager_hero_respawned)
		_game_manager.enemy_level_changed.connect(_on_enemy_level_changed)
		if _game_manager.has_signal("blueprint_unlocked"):
			_game_manager.blueprint_unlocked.connect(_on_blueprint_unlocked)

	camera.position = Vector2(0, VIEW_H * 0.5)
	reset_combat(true)


func _process(delta: float):
	# Hit-stop: congela héroe, enemigo y combate; cámara y efectos siguen vivos
	if _hitstop > 0.0:
		_hitstop -= delta
		if _hitstop <= 0.0:
			_set_frozen(false)
		_update_camera()
		return
	match state:
		State.RUN:
			update_run(delta)
		State.FIGHT:
			update_fight(delta)
		State.DEAD:
			update_dead(delta)
		State.COMPLETE:
			update_complete(delta)
	_update_camera()
	_update_enemy_wake()
	if enemy.alive:
		hero.look_target = enemy.position + Vector2(0, -12)
	else:
		hero.look_target = hero.position + Vector2(60, -12)


func update_run(delta: float):
	if _pause > 0.0:
		_pause -= delta
		hero.walking = false
		return
	if hero.alive:
		hero.position.x += HERO_SPEED * delta
		hero.walking = true
		hero.walk_speed = HERO_SPEED
		ground_offset += HERO_SPEED * delta
		# Cruzar la puerta = entrar en la sala (y en el bioma nuevo si toca)
		if hero.position.x >= _next_gate_x:
			_next_gate_x = INF
			_enter_room(_next_gate_room)
	if hero.alive and enemy.alive and _in_engage_range():
		_begin_fight()


func update_fight(_delta: float):
	hero.walking = false


func update_dead(_delta: float):
	hero.walking = false


func update_complete(_delta: float):
	pass


## true mientras el héroe avanza (no pelea ni está caído).
func is_advancing() -> bool:
	return state == State.RUN


func _in_engage_range() -> bool:
	return enemy.position.x - hero.position.x <= hero.reach + enemy.half_width + ENGAGE_GAP


func _begin_fight() -> void:
	state = State.FIGHT
	hero.walking = false
	backdrop.set_foreground_dim(true)
	if _next_gate_x != INF:
		# Por si el enemigo estaba antes que la puerta (no debería), entra ya en la sala
		_next_gate_x = INF
		_enter_room(_next_gate_room)
	enemy.wake()
	enemy.alert()
	if combat_controller and combat_controller.has_method("start_combat"):
		combat_controller.start_combat()


func _enter_room(room: int) -> void:
	backdrop.set_room(room, true)
	room_entered.emit(room, Biomes.is_boss_room(room))


func _update_camera() -> void:
	if hero == null or camera == null:
		return
	camera.set_target_x(hero.position.x + VIEW_W * (0.5 - HERO_SCREEN_X))
	backdrop.follow_camera(camera.position)


func _update_enemy_wake() -> void:
	if not enemy.alive or enemy.is_awake():
		return
	# Deja terminar la celebración de la muerte anterior antes de presentar al siguiente
	if _pause > 0.0 and state == State.RUN:
		return
	var right_edge := camera.position.x + VIEW_W * 0.5
	if enemy.position.x - enemy.half_width * 0.6 < right_edge:
		enemy.wake()
		if enemy.is_boss:
			_boss_intro()


func _boss_intro() -> void:
	backdrop.pulse_tint(Color(1, 0.1, 0.05), 3, 0.24, 0.55)
	camera.add_trauma(0.45)
	boss_appeared.emit(enemy.level, enemy.display_name)
	Sfx.play(&"boss_appear")


func advance_enemy():
	# Endless: siempre avanza al siguiente nivel
	if _game_manager and _game_manager.has_method("advance_enemy_level"):
		_game_manager.advance_enemy_level()
	else:
		level += 1
		spawn_enemy(level, hero.position.x + SPAWN_AHEAD)
		state = State.RUN
		dist_ref = enemy.position.x - hero.position.x


func spawn_enemy(lv: int, x: float):
	if enemy == null:
		return
	backdrop.set_foreground_dim(false)
	var boss := lv % BOSS_INTERVAL == 0 and lv > 0  # Boss cada N niveles
	if enemy.has_method("configure_for_level"):
		enemy.configure_for_level(lv, boss)
	else:
		enemy.level = lv
		enemy.is_boss = boss
		enemy.reset_stats()
	if boss:
		x += BOSS_EXTRA_DISTANCE
	enemy.position = Vector2(x, FLOOR_Y)
	enemy.velocity = Vector2.ZERO
	if combat_controller and combat_controller.has_method("stop_combat"):
		combat_controller.stop_combat()
	_place_gate(lv, x - GATE_BEFORE_ENEMY)


func _place_gate(room: int, x: float) -> void:
	# Si la puerta anterior aún no se ha cruzado, ya no vale (la sala se ha recolocado)
	if _next_gate and _next_gate_x != INF:
		_next_gate.visible = false
	var gate = _gates[_gate_index]
	_gate_index = (_gate_index + 1) % _gates.size()
	gate.setup(room, x, Biomes.biome_for_room(room))
	_next_gate = gate
	_next_gate_x = x
	_next_gate_room = room


func reset_combat(full_reset: bool):
	var start := HERO_START
	if hero:
		hero.respawn(start)
		hero.walking = false
	if _game_manager and "current_enemy_level" in _game_manager:
		level = maxi(1, _game_manager.current_enemy_level)
	elif full_reset:
		level = 1
	state = State.RUN
	_pause = FIRST_STEP_PAUSE
	for g in _gates:
		g.visible = false
	_next_gate = null
	_next_gate_x = INF
	camera.snap_to(start.x + VIEW_W * (0.5 - HERO_SCREEN_X), VIEW_H * 0.5)
	backdrop.set_room(level, false)
	# Las partículas viven en el mundo: tras el salto de cámara hay que rellenarlas donde está ahora
	backdrop.follow_camera(camera.position)
	backdrop.reset_dust()
	if fx:
		fx.clear()
	spawn_enemy(level, start.x + SPAWN_AHEAD)
	room_entered.emit(level, Biomes.is_boss_room(level))
	ground_offset = 0.0
	dist_ref = enemy.position.x - hero.position.x if hero and enemy else 0.0


# ─── Hit-stop ───────────────────────────────────────────────────────────

## Congela un instante el combate (solo esta escena; los minijuegos siguen).
func hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	_hitstop = maxf(_hitstop, duration)
	_set_frozen(true)


func _set_frozen(frozen: bool) -> void:
	if _frozen == frozen:
		return
	_frozen = frozen
	var mode := Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
	hero.process_mode = mode
	enemy.process_mode = mode
	combat_controller.process_mode = mode


# ─── Muerte / reaparición ─────────────────────────────────────────────

func _start_respawn_timer():
	if _respawn_timer.is_stopped():
		_respawn_timer.start()


func _on_local_hero_died():
	state = State.DEAD
	hero.walking = false
	if combat_controller and combat_controller.has_method("stop_combat"):
		combat_controller.stop_combat()
	camera.add_trauma(0.75)
	camera.punch(0.05)
	backdrop.flash(Color(1, 0.2, 0.15), 0.4, 0.35)
	hitstop(0.16)
	Sfx.play(&"hero_fall")
	hero_fell.emit(level)
	if _game_manager == null:
		_start_respawn_timer()


func _on_game_manager_hero_died(_death_count):
	# Endless: siempre iniciar respawn
	_start_respawn_timer()


func _on_respawn_timeout():
	if _game_manager and _game_manager.has_method("request_respawn"):
		if _game_manager.request_respawn():
			return
	_perform_respawn()


func _on_game_manager_hero_respawned(_death_count):
	_perform_respawn()


func _perform_respawn():
	_set_frozen(false)
	_hitstop = 0.0
	reset_combat(false)
	fx.beam(hero.position, Color(0.65, 0.85, 1.0), 94.0, 0.75, 16.0)
	fx.ring(hero.position + Vector2(0, -1), Color(0.7, 0.9, 1.0, 0.9), 2.0, 18.0, 0.5, 1.0)
	Sfx.play(&"hero_respawn", 2.0)
	hero_returned.emit()


func _on_enemy_stats_reset():
	dist_ref = enemy.position.x - hero.position.x if hero and enemy else 0.0


func _on_enemy_level_changed(new_level: int):
	# Ya estamos en esa sala con su enemigo vivo (p. ej. señal repetida tras reaparecer)
	if new_level == level and enemy.alive and enemy.level == new_level and state != State.DEAD:
		return
	level = new_level
	if state == State.RUN or state == State.FIGHT:
		spawn_enemy(level, hero.position.x + SPAWN_AHEAD)
		state = State.RUN
		_pause = POST_KILL_PAUSE


# ─── Botín y celebración al matar ──────────────────────────────────────

func _on_enemy_died_fx(_drops) -> void:
	var info: Dictionary = enemy.death_info
	var pos: Vector2 = info.get("pos", enemy.position)
	var was_boss: bool = info.get("boss", false)
	camera.add_trauma(0.8 if was_boss else 0.32)
	camera.punch(0.06 if was_boss else 0.025)
	hitstop(0.22 if was_boss else 0.08)
	Sfx.play(&"enemy_shatter", 1.0 if was_boss else 0.0, 0.8 if was_boss else 1.0)
	if was_boss:
		Sfx.play(&"boss_defeated", 2.0)
		backdrop.flash(Color(1, 0.85, 0.4), 0.5, 0.6)
		fx.float_text(pos + Vector2(0, -30), "¡JEFE DERROTADO!", Color("ffd54a"), true, 1.8, 6.0, 0.25)
		boss_slain.emit(int(info.get("level", level)), String(info.get("name", "")))
	var md: Dictionary = info.get("material", {})
	if not md.is_empty():
		var mat := _material_info(StringName(md.get("item_id", "")))
		fx.loot_pop(pos + Vector2(2, -4), mat.get("icon"), "+%d %s" % [int(md.get("quantity", 0)), mat.get("name", "")], Color(1, 0.93, 0.7), 0.3 if was_boss else 0.12, FLOOR_Y)
		loot_dropped.emit(&"material", pos, {"id": md.get("item_id", ""), "quantity": md.get("quantity", 0)})
		# Tintineo cuando sale el botín (va con el mismo retardo que su icono)
		get_tree().create_timer(0.3 if was_boss else 0.12).timeout.connect(func(): Sfx.play(&"loot_coins"))


func _on_blueprint_unlocked(bp_id: StringName) -> void:
	var pos: Vector2 = enemy.death_info.get("pos", hero.position + Vector2(24, 0))
	var dm := get_node_or_null("/root/DataManager")
	var bp = dm.blueprints.get(bp_id) if dm and "blueprints" in dm else null
	var bp_name := String(bp_id)
	var icon: Texture2D = null
	if bp:
		bp_name = bp.display_name
		icon = bp.get_blueprint_icon()  # el arte del plano; bp.icon no llega a cargarse
	fx.star(pos + Vector2(0, -16), Color("ffe08a"), 14.0, 0.4)
	fx.float_text(pos + Vector2(0, -26), "¡Nuevo plano!", Color("ffe08a"), true, 1.6, 8.0)
	Sfx.play(&"blueprint_found", 1.0)
	loot_dropped.emit(&"blueprint", pos + Vector2(0, -16), {"id": bp_id, "name": bp_name, "icon": icon})


func _material_info(mat_id: StringName) -> Dictionary:
	if _material_cache.has(mat_id):
		return _material_cache[mat_id]
	var info := {"name": String(mat_id).capitalize(), "icon": null}
	var path := "res://data/materials/%s.tres" % String(mat_id)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res:
			info.name = res.display_name if res.display_name != "" else info.name
			info.icon = res.icon
	_material_cache[mat_id] = info
	return info
