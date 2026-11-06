extends Node2D

## Duelos endless en posiciones fijas. Cada sala cambia el rival y el escenario por bioma.
## GameManager conserva el avance, muro y reaparición; el estado RUN es la pausa entre duelos.
## Entre duelos: se ve la derrota y el botín, un humo tapa la franja hasta el negro, se pone el rival siguiente y el
## humo baja con la presentación «VS» (duel_intro). Cada duelo nuevo (arranque, reaparición, viaje) se descubre igual.
## El hit-stop afecta solo al combate; los minijuegos continúan funcionando.

signal room_entered(room: int, is_boss: bool)
signal biome_entered(biome_index: int, display_name: String)
signal boss_appeared(room: int, boss_name: String)
signal boss_slain(room: int, boss_name: String)
signal loot_dropped(kind: StringName, world_pos: Vector2, payload: Dictionary)
signal hero_fell(room: int)
signal hero_returned
signal room_traveled(room: int)  # viaje del selector o reintento del muro (el HUD funde desde negro)
signal duel_intro(enemy_name: String, enemy_level: int, length: float)  # presentación «VS» del duelo que empieza

@onready var hero: Node = $Hero
@onready var enemy: Node = $Enemy
@onready var combat_controller: Node = $CombatController
@onready var camera: Camera2D = $Camera2D
@onready var backdrop: Node2D = $Backdrop
@onready var fx: Node2D = $CombatFX
@onready var _gates: Array = [$GateA, $GateB]

# Medidas en píxeles del arte (216x96): las de 1080x480 divididas entre 5
const HERO_SPEED := 38.0
const UNLOCK_STAGGER := 0.15  # segundos entre los pergaminos de un mismo hito
var _unlock_burst := 0
## Suelo del duelo: los pies apoyan en el borde de arriba de la franja de nombres y vida (DuelVitals), que así no
## tapa a los enemigos bajos. Con Tico al 90 % del alto (86,4) la cabeza queda en el borde de arriba de la franja.
const FLOOR_Y := 86.0
const VIEW_W := PixelView.VIEW_W
const VIEW_H := PixelView.VIEW_H
const HERO_SCREEN_X := PixelView.HERO_SCREEN_X  # posición del héroe en pantalla (fracción del ancho)
const SPAWN_AHEAD := 160.0  # el enemigo aparece justo fuera de pantalla por la derecha
const BOSS_EXTRA_DISTANCE := 52.0  # el jefe entra en pantalla andando, no de golpe
const GATE_BEFORE_ENEMY := 66.0
const ENGAGE_GAP := 3.0
const HERO_START := Vector2(50.0, FLOOR_Y)
const ENEMY_SPOT := Vector2(166.0, FLOOR_Y)
const BOSS_INTERVAL := 10  # Boss cada 10 niveles (coincide con Biomes.ROOMS_PER_BIOME)
const RESPAWN_DELAY := 1.5
## Botín doble (Poción de Suerte): la segunda tanda sale a la vez que la primera, un icono más adelante,
## más rápida hacia delante y con la etiqueta una fila más arriba; su tintineo suena un poco después.
const BONUS_LOOT_AHEAD := 12.0
const BONUS_LOOT_SPEED := Vector2(22.0, 30.0)
const BONUS_LOOT_SOUND_LAG := 0.1
const SMOKE_SHADER := preload("res://shaders/duel_smoke.gdshader")
const DEATH_LINGER := 0.55  ## la derrota y el botín se ven antes de que suba el humo
const SMOKE_IN := 0.65
const SMOKE_OUT := 0.7
const VS_HOLD := 0.6  ## la presentación sigue un poco con la escena ya descubierta

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
var _smoke: ColorRect
var _transition: Tween
var _next_duel_shown := true  ## false entre la muerte del rival y el negro, cuando aún no está el siguiente
var _intro_ends := 0.0  ## hora (Time.get_ticks_msec) en que acaba la presentación del duelo en curso


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
		if _game_manager.has_signal("blueprints_milestone"):
			_game_manager.blueprints_milestone.connect(_on_blueprints_milestone)
		if _game_manager.has_signal("room_travel"):
			_game_manager.room_travel.connect(_on_room_travel)

	camera.position = Vector2(0, VIEW_H * 0.5)
	_build_smoke()
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
	hero.walking = false
	if _pause > 0.0:
		_pause -= delta
		return
	if hero.alive and enemy.alive:
		_begin_fight()  # la sala ya se anunció al aparecer su enemigo (_on_enemy_level_changed / reset_combat)


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
	return hero.alive and enemy.alive  # duelo fijo; no depende de distancia de corredor


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
	# Cada sala es un duelo: Tico entra con la vida llena (spec de rangos, apartado 7)
	if hero.alive:
		hero.heal(hero.max_hp - hero.hp)
	backdrop.set_room(room, true)
	room_entered.emit(room, Biomes.is_boss_room(room))


func _update_camera() -> void:
	if camera:
		camera.set_target_x(VIEW_W * 0.5)
		backdrop.follow_camera(Vector2(VIEW_W * 0.5, VIEW_H * 0.5))


func _update_enemy_wake() -> void:
	if state == State.FIGHT and enemy.alive and not enemy.is_awake():
		enemy.wake()


func _boss_intro() -> void:
	backdrop.pulse_tint(Color(1, 0.1, 0.05), 3, 0.24, 0.55)
	camera.add_trauma(0.45)
	boss_appeared.emit(enemy.level, enemy.display_name)
	Sfx.play(&"boss_appear")
	# Velocidad y Suerte se beben solas ante un jefe (GameManager decide si toca)
	if _game_manager and _game_manager.has_method("on_boss_appeared"):
		_game_manager.on_boss_appeared()


func advance_enemy():
	# La sala siguiente la decide GameManager: avanzar, repetir la sala o volver al muro
	if _game_manager and _game_manager.has_method("room_cleared"):
		_game_manager.room_cleared()
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
	enemy.position = ENEMY_SPOT
	hero.position = HERO_START
	hero.walking = false
	hero.show_hud = false
	enemy.duel_presentation = true
	enemy.velocity = Vector2.ZERO
	if combat_controller and combat_controller.has_method("stop_combat"):
		combat_controller.stop_combat()
	for gate in _gates:
		gate.hide()
	_next_gate_x = INF


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
	_kill_transition()
	for g in _gates:
		g.visible = false
	_next_gate = null
	_next_gate_x = INF
	camera.snap_to(VIEW_W * 0.5, VIEW_H * 0.5)
	backdrop.set_room(level, false)
	# Las partículas viven en el mundo: tras el salto de cámara hay que rellenarlas donde está ahora
	backdrop.follow_camera(camera.position)
	backdrop.reset_dust()
	if fx:
		fx.clear()
	spawn_enemy(level, start.x + SPAWN_AHEAD)
	room_entered.emit(level, Biomes.is_boss_room(level))
	# Arranque, reaparición o viaje: el duelo se descubre desde el negro, como tras una victoria
	_reveal_duel(true)
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


## Selector de sala o reintento del muro (GameManager.room_travel): viaje instantáneo. Un combate a medias
## se abandona sin premio ni castigo. Con Tico caído no hace nada: la reaparición ya usa la sala nueva.
func _on_room_travel(room: int) -> void:
	if state == State.DEAD:
		return
	_set_frozen(false)
	_hitstop = 0.0
	reset_combat(false)
	room_traveled.emit(room)


func _on_enemy_stats_reset():
	dist_ref = enemy.position.x - hero.position.x if hero and enemy else 0.0


func _on_enemy_level_changed(new_level: int):
	# Ya estamos en esa sala con su enemigo vivo (p. ej. señal repetida tras reaparecer)
	if new_level == level and enemy.alive and enemy.level == new_level and state != State.DEAD:
		return
	level = new_level
	if state == State.RUN or state == State.FIGHT:
		if combat_controller and combat_controller.has_method("stop_combat"):
			combat_controller.stop_combat()
		state = State.RUN
		_play_duel_transition()


# ─── Transición entre duelos ───────────────────────────────────────────

## Capa del humo, encima del escenario y su viñeta (capa 5). El HUD de la franja va fuera del viewport y sigue visible.
func _build_smoke() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_smoke = ColorRect.new()
	_smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_smoke.size = get_viewport_rect().size
	var mat := ShaderMaterial.new()
	mat.shader = SMOKE_SHADER
	mat.set_shader_parameter("aspect", _smoke.size.x / maxf(1.0, _smoke.size.y))
	_smoke.material = mat
	_smoke.visible = false
	layer.add_child(_smoke)


## Cuánto tapa el humo ahora (0 nada, 1 negro).
func smoke_amount() -> float:
	return float((_smoke.material as ShaderMaterial).get_shader_parameter("progress")) if _smoke and _smoke.visible else 0.0


func _set_smoke(amount: float) -> void:
	if _smoke == null:
		return
	_smoke.visible = amount > 0.001
	(_smoke.material as ShaderMaterial).set_shader_parameter("progress", amount)


## Tras una victoria: la derrota y el botín un momento, el humo sube hasta el negro, se pone el rival siguiente (con la sala
## del cartel y la vida llena de Tico) y el humo baja con la presentación. El combate empieza al terminar.
func _play_duel_transition() -> void:
	_kill_transition()
	_next_duel_shown = false
	_pause = INF
	_transition = create_tween()
	_transition.tween_interval(DEATH_LINGER)
	_transition.tween_method(_set_smoke, 0.0, 1.0, SMOKE_IN)  # lineal: el shader ya reparte el humo en el tiempo
	_transition.tween_callback(_show_next_duel)


func _show_next_duel() -> void:
	_next_duel_shown = true
	spawn_enemy(level, hero.position.x + SPAWN_AHEAD)
	if fx:
		fx.clear()  # el botín de la victoria anterior no sigue rebotando en el duelo nuevo
	_enter_room(level)
	_reveal_duel(false)


## El humo baja desde el negro y se presenta el duelo: un jefe con su cartel «¡JEFE!» (y las pociones que tocan), el resto
## con el «VS». El rival aparece mientras se descubre la escena; el combate empieza al terminar.
func _reveal_duel(from_reset: bool) -> void:
	if from_reset:
		_kill_transition()
	_set_smoke(1.0)
	_pause = INF
	_transition = create_tween()
	_transition.tween_method(_set_smoke, 1.0, 0.0, SMOKE_OUT)
	_transition.tween_interval(VS_HOLD)
	_transition.tween_callback(func(): _pause = 0.0)
	enemy.wake()
	if enemy.is_boss:
		_boss_intro()
	else:
		_intro_ends = Time.get_ticks_msec() + (SMOKE_OUT + VS_HOLD) * 1000.0
		duel_intro.emit(enemy.display_name, enemy.level, SMOKE_OUT + VS_HOLD)


## Segundos que le quedan a la presentación en curso (0 si no hay): la franja de nombres se conecta después de que el
## pasillo presente el primer duelo de la partida y la retoma con esto.
func intro_time_left() -> float:
	return maxf(0.0, (_intro_ends - Time.get_ticks_msec()) / 1000.0) if _transition and _transition.is_valid() else 0.0


func _kill_transition() -> void:
	if _transition and _transition.is_valid():
		_transition.kill()
	_transition = null
	_next_duel_shown = true
	_set_smoke(0.0)


## Termina ya la transición (las pruebas, que no esperan al humo): queda puesto el duelo siguiente y empieza en el
## próximo fotograma.
func skip_transition() -> void:
	var pending := not _next_duel_shown
	_kill_transition()
	if pending:
		_show_next_duel()
		_kill_transition()
	_pause = 0.0


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
		# Desde el pecho del jefe: más arriba subía hasta la fila de oro y sala y se cortaba en el borde
		fx.float_text(pos + Vector2(0, -6), tr("¡JEFE DERROTADO!"), Color("ffd54a"), true, 1.8, 6.0, 0.25)
		boss_slain.emit(int(info.get("level", level)), String(info.get("name", "")))
	var md: Dictionary = info.get("material", {})
	if not md.is_empty():
		var mat := _material_info(StringName(md.get("item_id", "")))
		fx.loot_pop(pos + Vector2(2, -4), mat.get("icon"), "+%d %s" % [int(md.get("quantity", 0)), tr(mat.get("name", ""))], Color(1, 0.93, 0.7), 0.3 if was_boss else 0.12, FLOOR_Y)
		loot_dropped.emit(&"material", pos, {"id": md.get("item_id", ""), "quantity": md.get("quantity", 0)})
		# Tintineo cuando sale el botín (va con el mismo retardo que su icono)
		get_tree().create_timer(0.3 if was_boss else 0.12).timeout.connect(func(): Sfx.play(&"loot_coins"))
	_show_bonus_loot(info)
	var bd: Dictionary = info.get("biome_material", {})
	if not bd.is_empty():
		var bmat := _material_info(StringName(bd.get("item_id", "")))
		var bdelay := (0.3 if was_boss else 0.12) + 0.18
		# Fila 2 de etiqueta: el de siempre usa la 0 y el doble de la Suerte la 1, así no se pisan
		fx.loot_pop(pos + Vector2(8, -8), bmat.get("icon"), "+%d %s" % [int(bd.get("quantity", 0)), tr(bmat.get("name", ""))], Color(0.8, 0.95, 1.0), bdelay, FLOOR_Y, NAN, 2)
		loot_dropped.emit(&"material", pos, {"id": bd.get("item_id", ""), "quantity": bd.get("quantity", 0), "biome": true})
		get_tree().create_timer(bdelay + 0.1).timeout.connect(func(): Sfx.play(&"loot_coins"))


## Segunda tanda de la Poción de Suerte, igual que la primera: icono con "+15 material" que sale del enemigo,
## aviso loot_dropped para el HUD ("bonus": true) y tintineo. El material ya está en el inventario (lo mete Enemy).
func _show_bonus_loot(info: Dictionary) -> void:
	var md: Dictionary = info.get("bonus_material", {})
	if md.is_empty():
		return
	var pos: Vector2 = info.get("pos", Vector2.ZERO)
	var delay: float = 0.3 if info.get("boss", false) else 0.12  # el mismo que el primer botín
	var mat := _material_info(StringName(md.get("item_id", "")))
	var vx := randf_range(BONUS_LOOT_SPEED.x, BONUS_LOOT_SPEED.y)
	fx.loot_pop(pos + Vector2(2.0 + BONUS_LOOT_AHEAD, -4), mat.get("icon"), "+%d %s" % [int(md.get("quantity", 0)), tr(mat.get("name", ""))], Color(1, 0.93, 0.7), delay, FLOOR_Y, vx, 1)
	loot_dropped.emit(&"material", pos, {"id": md.get("item_id", ""), "quantity": md.get("quantity", 0), "bonus": true})
	get_tree().create_timer(delay + BONUS_LOOT_SOUND_LAG).timeout.connect(func(): Sfx.play(&"loot_coins"))


## Hito de rangos: un solo destello y un sonido; el cartel lo pone HeroViewOverlay.
func _on_blueprints_milestone(_rank: int, _tier: StringName, _ids: Array) -> void:
	_unlock_burst = 0
	var pos: Vector2 = enemy.death_info.get("pos", hero.position + Vector2(24, 0))
	fx.star(pos + Vector2(0, -16), Color("ffe08a"), 14.0, 0.4)
	Sfx.play(&"blueprint_found", 1.0)


## Cada plano del hito vuela a su botón, escalonado para que no salgan apilados.
func _on_blueprint_unlocked(bp_id: StringName, rank: int = 1) -> void:
	var pos: Vector2 = enemy.death_info.get("pos", hero.position + Vector2(24, 0))
	var dm := get_node_or_null("/root/DataManager")
	var bp = dm.blueprints.get(bp_id) if dm and "blueprints" in dm else null
	var bp_name := String(bp_id)
	var icon: Texture2D = null
	if bp:
		bp_name = tr(bp.display_name) + Ranks.suffix(rank)
		icon = bp.get_blueprint_icon()  # el arte del plano; bp.icon no llega a cargarse
	var payload := {"id": bp_id, "name": bp_name, "icon": icon, "rank": rank}
	var delay := UNLOCK_STAGGER * _unlock_burst
	_unlock_burst += 1
	if delay <= 0.0:
		loot_dropped.emit(&"blueprint", pos + Vector2(0, -16), payload)
	else:
		get_tree().create_timer(delay).timeout.connect(func(): loot_dropped.emit(&"blueprint", pos + Vector2(0, -16), payload))


## Nombre e icono de un material (caché). El nombre es el texto base en español del .tres: quien lo
## enseña lo pasa por tr() al pintarlo, así la caché no guarda textos de un idioma viejo.
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
