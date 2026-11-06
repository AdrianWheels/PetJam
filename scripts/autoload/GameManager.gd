extends Node
class_name GameManager

const _SaveManager = preload("res://scripts/core/SaveManager.gd")

signal enemy_spawned(enemy_level)  # Cuando spawnea un nuevo nivel de enemigo
signal hero_died(death_count)
signal hero_respawned(death_count)
signal boss_defeated  # Milestone: boss derrotado (no termina el juego)
signal dungeon_state_changed(new_state)
signal hero_loadout_changed(loadout)
signal enemy_defeated_first_time(enemy_level)  # Para desbloquear blueprint
signal enemy_level_changed(new_level)  # Señal cuando cambia nivel de enemigo
signal blueprint_unlocked(blueprint_id, rank)  # Plano desbloqueado (o subido de rango) por un hito
signal blueprints_milestone(rank, tier, ids)  # Hito de rangos: se emite antes que los blueprint_unlocked
signal record_changed(best_level)  # Nueva sala máxima alcanzada (base del leaderboard)
signal progress_loaded  # La partida guardada ya está aplicada (para refrescar HUDs)
signal buffs_changed(active: Dictionary)  # Un efecto temporal empieza, se renueva o caduca (id → segundos)
signal room_travel(room: int)  # el selector o un reintento mandan a Tico a otra sala (viaje instantáneo)
signal wall_changed(wall_room: int)  # aparece o cae el muro (0 = sin muro)
signal room_lock_changed(locked: bool)  # candado del selector de sala
signal grid_expanded(recipe_id)  # la rejilla de Tico crece: primera victoria sobre el jefe 10, 20, 30 o 40
signal potion_drunk(potion_id)  # una poción de los huecos se ha bebido sola

enum DungeonState { IDLE, RUNNING, HERO_DEAD }

const ITEM_DEFAULT_SLOT := {
		&"sword_basic": &"weapon",
		&"dagger_basic": &"weapon",
		&"bow_simple": &"weapon",
		&"armor_leather": &"armor",
		&"helmet_iron": &"armor",
		&"shield_wooden": &"shield",
		&"potion_heal": &"trinket",
}

const ITEM_BONUSES := {
		&"sword_basic": {"STR": 4, "DMG": 2.0},
		&"dagger_basic": {"AGI": 5, "APS": 0.2},
		&"bow_simple": {"AGI": 3, "DMG": 1.5},
		&"armor_leather": {"STR": 2, "HP": 30},
		&"helmet_iron": {"INT": 3, "HP": 20},
		&"shield_wooden": {"HP": 40},
		&"potion_heal": {"HP": 25},
}

var current_enemy_level: int = 1  # Nivel del enemigo actual (infinito)
var best_enemy_level: int = 1  # Récord: la sala más profunda alcanzada que Tico aún no ha vencido

## Muro, farmeo y selector de sala (spec de rangos, apartado 7)
const WALL_RETRY_WINS := 3  # delante del muro, Tico lo reintenta cada 3 victorias
var wall_room: int = 0  # sala donde Tico perdió por última vez, hasta que la vence (0 = sin muro)
var room_locked: bool = false  # candado: Tico repite su sala y no reintenta el muro
var _wins_since_retry: int = 0
var _growing_grid := false  # la rejilla de Tico crece dentro de register_enemy_defeat: ampliar no manda a Tico al muro

var inventory := {}
var blueprints_unlocked := {}
var enemies_defeated := {}  # Track niveles de enemigo derrotados para desbloqueo de blueprints

var dungeon_state: int = DungeonState.IDLE:
		set(value):
				if dungeon_state == value:
						return
				dungeon_state = value
				emit_signal("dungeon_state_changed", dungeon_state)
		get:
				return dungeon_state

var death_count: int = 0
var boss_defeated_flag: bool = false
var hero_loadout := {
		&"weapon": StringName(),
		&"armor": StringName(),
		&"shield": StringName(),
		&"trinket": StringName(),
}
var _hero: Node = null

const AUTOSAVE_INTERVAL := 60.0  # Segundos entre auto-saves
var _save_loaded := false
## Se puede guardar al cerrar: los datos ya están listos y no hay un guardado en disco que no se haya podido leer
var _close_save_allowed := false
var _save_pending := false  # ya hay un guardado diferido en cola: los demás avisos del fotograma no piden otro
var _autosave_timer: Timer = null
## Quién escribe la partida en el guardado diferido; si no es válido, SaveManager. Las pruebas ponen uno que solo cuenta
## (sin tocar el disco), como Hero.power_roll en las tiradas.
var save_writer: Callable = Callable()

# ─── Efectos temporales (pociones de la tienda) ───────────────────────
## Poción de Velocidad: ataques por segundo del héroe x1,5 (Hero.refresh_attack_speed).
const BUFF_SPEED := &"speed"
## Poción de Suerte: cada enemigo derrotado puede soltar una segunda tanda de material (Enemy).
const BUFF_LUCK := &"luck"
const SPEED_ATTACK_MULTIPLIER := 1.5
const LUCK_DOUBLE_LOOT_CHANCE := 0.2
## id → segundos restantes. Cuenta tiempo real en _process: sigue durante el hit-stop (lo congela el
## Corridor, no este autoload) y con Tico caído (el efecto no se pierde al morir). Solo se para si se
## pausa el árbol entero. No se guarda en save.json: al cerrar el juego se pierde lo que quedara.
var _buffs: Dictionary = {}

func _ready():
	DebugManager.log_msg(&"game", "GameManager ready")
	# Conectar señal de equipamiento para actualizar stats del héroe
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager and inv_manager.has_signal("equipment_changed"):
		inv_manager.equipment_changed.connect(_on_equipment_changed)
		# Save al cambiar equipo
		inv_manager.equipment_changed.connect(_on_trigger_save)
	if inv_manager and inv_manager.has_signal("crafted_items_changed"):
		# Save al craft nuevo item
		inv_manager.crafted_items_changed.connect(_on_trigger_save)
	if inv_manager and inv_manager.has_signal("loot_poses_changed"):
		# Save cuando la pila del botín se queda quieta o se cierra el panel (spec del botín con física, apartado 8)
		inv_manager.loot_poses_changed.connect(_on_trigger_save)

	# Esperar data_ready para cargar partida guardada
	var dm = get_node_or_null("/root/DataManager")
	if dm and dm.has_signal("data_ready"):
		dm.data_ready.connect(_on_data_ready_load_save, CONNECT_ONE_SHOT)

	# Auto-save periódico
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)

	# Save al cambiar nivel de enemigo
	enemy_level_changed.connect(_on_trigger_save)
	hero_died.connect(_on_trigger_save)

func _process(delta: float) -> void:
	tick_buffs(delta)

# ═══════════════════════════════════════════════════════════════════
#  EFECTOS TEMPORALES
# ═══════════════════════════════════════════════════════════════════

## Activa un efecto durante `duration` segundos. Si ya estaba activo vuelve a la duración completa:
## no suma tiempo y el efecto no se acumula.
func apply_buff(id: StringName, duration: float) -> void:
	if duration <= 0.0:
		return
	_buffs[id] = duration
	buffs_changed.emit(get_active_buffs())
	retry_wall_now()  # una poción de efecto manda a Tico a probar el muro

## Segundos que le quedan a un efecto (0 si no está activo).
func buff_remaining(id: StringName) -> float:
	return float(_buffs.get(id, 0.0))

func has_buff(id: StringName) -> bool:
	return buff_remaining(id) > 0.0

## Copia de los efectos activos: id → segundos restantes.
func get_active_buffs() -> Dictionary:
	return _buffs.duplicate()

## Descuenta `delta` segundos a los efectos activos y quita los que caducan.
## _process la llama con el delta real; las pruebas, con el que quieran (sin esperas reales).
func tick_buffs(delta: float) -> void:
	if _buffs.is_empty() or delta <= 0.0:
		return
	var expired := false
	for id in _buffs.keys():
		var left: float = _buffs[id] - delta
		if left <= 0.0:
			_buffs.erase(id)
			expired = true
		else:
			_buffs[id] = left
	if expired:
		buffs_changed.emit(get_active_buffs())

func clear_buffs() -> void:
	if _buffs.is_empty():
		return
	_buffs.clear()
	buffs_changed.emit(get_active_buffs())

## Multiplicador del ritmo de ataque del héroe (Poción de Velocidad).
func attack_speed_multiplier() -> float:
	return SPEED_ATTACK_MULTIPLIER if has_buff(BUFF_SPEED) else 1.0

## Probabilidad de que un enemigo derrotado suelte botín doble (Poción de Suerte).
func double_loot_chance() -> float:
	return LUCK_DOUBLE_LOOT_CHANCE if has_buff(BUFF_LUCK) else 0.0

## Bebe una poción de los huecos si queda y aplica su efecto. true si se ha bebido.
func drink_potion(id: StringName) -> bool:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null or not inv.has_method("take_potion") or not inv.take_potion(id):
		return false
	var info: Dictionary = Potions.CATALOG.get(id, {})
	if info.has("buff"):
		apply_buff(info.buff, float(info.duration))
	elif id == &"potion_heal" and is_instance_valid(_hero) and _hero.has_method("heal"):
		_hero.heal(_hero.max_hp)
	emit_signal("potion_drunk", id)
	return true

## Tico ha recibido daño (también si lo esquivó o paró): vivo y por debajo del 30 %, bebe una de Vida si la lleva.
## hurt llega después de died en un golpe mortal, de ahí mirar si sigue vivo.
func _on_hero_hurt(_amount: int) -> void:
	if is_instance_valid(_hero) and _hero.alive and _hero.hp < _hero.max_hp * Potions.HEAL_BELOW:
		drink_potion(&"potion_heal")

## Aparece un jefe (lo llama el Corridor): Velocidad y Suerte, si las lleva y su efecto no está activo.
## Delante del muro y sin candado no se beben: una poción de efecto manda a Tico al muro (apply_buff llama
## a retry_wall_now) y dejaría este jefe a medias (spec del inventario, apartado 8).
func on_boss_appeared() -> void:
	if wall_room > 0 and not room_locked and current_enemy_level != wall_room:
		return
	for pair in [[&"potion_speed", BUFF_SPEED], [&"potion_luck", BUFF_LUCK]]:
		if not has_buff(pair[1]):
			drink_potion(pair[0])

func get_hero() -> Node:
	return _hero

func register_hero(hero_node: Node) -> void:
	# Solo se escucha al héroe registrado (Main y UIManager lo registran los dos): sin conexiones repetidas ni del anterior
	if is_instance_valid(_hero) and _hero.has_signal("hurt") and _hero.hurt.is_connected(_on_hero_hurt):
		_hero.hurt.disconnect(_on_hero_hurt)
	_hero = hero_node
	if is_instance_valid(_hero) and _hero.has_signal("hurt"):
		_hero.hurt.connect(_on_hero_hurt)
	# Aplicar stats de equipo actual al registrar héroe
	_refresh_hero_stats()

func _on_equipment_changed(_equipment_stats: Dictionary) -> void:
	"""Cuando cambia el equipamiento, recalcular stats del héroe y, delante de un muro, probarlo ya"""
	_refresh_hero_stats()
	if not _growing_grid:  # ampliar la rejilla en plena victoria sobre un jefe recalcula a Tico, pero no lo manda a otra sala
		retry_wall_now()

func _refresh_hero_stats() -> void:
	if is_instance_valid(_hero) and _hero.has_method("reset_stats"):
		_hero.reset_stats()
		DebugManager.log_msg(&"game", "Hero stats recalculated after equipment change")

func start_run():
	# Con partida cargada se continúa donde estaba (no hay "runs": es una sesión persistente)
	if not _save_loaded:
		current_enemy_level = 1
		death_count = 0
		enemies_defeated.clear()
		_set_wall(0)
		_set_room_locked(false)
	_wins_since_retry = 0
	boss_defeated_flag = false
	dungeon_state = DungeonState.RUNNING
	DebugManager.log_msg(&"game", "Starting endless run at enemy level %d" % current_enemy_level)
	emit_signal("enemy_spawned", current_enemy_level)
	emit_signal("enemy_level_changed", current_enemy_level)
	emit_signal("hero_respawned", death_count)
func advance_enemy_level():
	current_enemy_level += 1
	DebugManager.log_msg(&"game", "Advanced to enemy level %d" % current_enemy_level)
	if current_enemy_level > best_enemy_level:
		best_enemy_level = current_enemy_level
		emit_signal("record_changed", best_enemy_level)
	emit_signal("enemy_level_changed", current_enemy_level)
	# TODO: Boss cada X niveles (ej. cada 10)
	emit_signal("enemy_spawned", current_enemy_level)


## Tico ha vencido al enemigo de su sala: decide adónde va (spec de rangos, apartado 7).
## - Vencer la sala del récord lo sube, aunque Tico se quede (con el candado puesto).
## - Vencer el muro, o una sala más honda, lo quita.
## - Con candado repite la sala. En la sala anterior al muro la farmea y a las WALL_RETRY_WINS
##   victorias pasa al muro. Si no, avanza.
func room_cleared() -> void:
	var cleared := current_enemy_level
	if cleared >= best_enemy_level:
		best_enemy_level = cleared + 1
		emit_signal("record_changed", best_enemy_level)
	if wall_room > 0 and cleared >= wall_room:
		_set_wall(0)
	var repeat := room_locked
	if not repeat and wall_room > 0 and cleared + 1 == wall_room:
		_wins_since_retry += 1
		repeat = _wins_since_retry < WALL_RETRY_WINS
		if not repeat:
			_wins_since_retry = 0
	if repeat:
		# Otro enemigo de la misma sala: el pasillo lo pone por delante, como al avanzar
		emit_signal("enemy_level_changed", current_enemy_level)
		emit_signal("enemy_spawned", current_enemy_level)
	else:
		advance_enemy_level()


## Selector de sala: manda a Tico a una sala entre la 1 y el récord. Por debajo del récord pone el
## candado, salvo en el muro: elegir el muro o el récord es probarlo. Si ya está en esa sala, solo
## cambia el candado.
func travel_to_room(room: int) -> void:
	var target := clampi(room, 1, best_enemy_level)
	_set_room_locked(target < best_enemy_level and target != wall_room)
	if target != current_enemy_level:
		_travel(target)


## Candado del selector. Quitarlo lleva a Tico a la sala anterior al muro (o al récord si no hay muro).
func set_room_locked(locked: bool) -> void:
	if locked == room_locked:
		return
	_set_room_locked(locked)
	if locked:
		return
	var front := maxi(1, (wall_room if wall_room > 0 else best_enemy_level) - 1)
	if front != current_enemy_level:
		_travel(front)


## Con muro y sin candado, Tico lo prueba ya (equipo nuevo o poción de efecto). Solo con la partida en marcha.
## Para el HUD: Tico farmea la sala de antes del muro y lo reintentará al llegar a WALL_RETRY_WINS victorias.
func is_farming_wall() -> bool:
	return wall_room > 0 and not room_locked and current_enemy_level == wall_room - 1

## Victorias seguidas en la sala de antes del muro desde el último intento (0..WALL_RETRY_WINS-1).
func wall_retry_wins() -> int:
	return _wins_since_retry

## Cuántas victorias hacen falta para volver al muro (para el HUD y el cartel de derrota).
func wall_retry_goal() -> int:
	return WALL_RETRY_WINS

func retry_wall_now() -> void:
	if wall_room <= 0 or room_locked or dungeon_state != DungeonState.RUNNING:
		return
	if current_enemy_level != wall_room:
		_travel(wall_room)


## Sala a la que lleva el selector desde `from_room`: la de al lado (dir = −1 o 1) o, con by_biome, el
## principio del bioma anterior o del siguiente. Siempre entre la 1 y el récord.
func selector_target(from_room: int, dir: int, by_biome: bool) -> int:
	var target := from_room + dir
	if by_biome:
		var biome_start := from_room - Biomes.room_in_biome(from_room) + 1
		target = biome_start + Biomes.ROOMS_PER_BIOME * dir
	return clampi(target, 1, best_enemy_level)


## Viaje instantáneo. El pasillo (room_travel) abandona el combate a medias, sin premio ni castigo, y pone
## a Tico en la sala nueva con la vida llena; con Tico caído, la reaparición ya lo deja ahí. room_travel va
## antes que enemy_level_changed: el pasillo ya recolocado ignora la segunda.
func _travel(room: int) -> void:
	current_enemy_level = room
	_wins_since_retry = 0
	emit_signal("room_travel", room)
	emit_signal("enemy_level_changed", room)


func _set_wall(room: int) -> void:
	if wall_room == room:
		return
	wall_room = room
	emit_signal("wall_changed", wall_room)


func _set_room_locked(locked: bool) -> void:
	if room_locked == locked:
		return
	room_locked = locked
	emit_signal("room_lock_changed", room_locked)
	_on_trigger_save()


func register_enemy_defeat(level: int) -> void:
	if dungeon_state != DungeonState.RUNNING:
		return
	DebugManager.log_msg(&"game", "Enemy level %d defeated (current: %d)" % [level, current_enemy_level])
	
	if not enemies_defeated.has(level):
		enemies_defeated[level] = true
		emit_signal("enemy_defeated_first_time", level)
	# Hitos de rango: vencer a ciertos jefes desbloquea un nivel de pieza (spec de rangos, apartado 3)
	if Biomes.is_boss_room(level):
		var ms := Ranks.milestone_for_boss_room(level)
		var dm = get_node_or_null("/root/DataManager")
		if not ms.is_empty() and dm and dm.has_method("apply_milestones"):
			var newly: Array = dm.apply_milestones([ms])
			if not newly.is_empty():
				var ids := newly.map(func(n): return n.id)
				emit_signal("blueprints_milestone", int(ms.rank), ms.tier, ids)
				for n in newly:
					emit_signal("blueprint_unlocked", n.id, n.rank)
				_on_trigger_save()

	# Rejilla de Tico (spec del inventario en rejilla, apartado 7). Provisional hasta que lleguen las
	# recetas con los rangos: la primera vez que cae el jefe de la sala 10, 20, 30 o 40 del ciclo I, la
	# rejilla crece sola. El récord aún no ha pasado de esta sala (room_cleared va después). Ampliar avisa de
	# equipment_changed, que delante de un muro mandaría a Tico a otra sala en mitad de la victoria (el jefe
	# aún no ha acabado de caer y room_cleared() leería la sala del muro): mientras tanto, _growing_grid.
	var recipe := GridExpansions.recipe_for_boss_room(level)
	if recipe != &"" and best_enemy_level <= level:
		var inv = get_node_or_null("/root/InventoryManager")
		if inv and inv.has_method("apply_grid_expansion"):
			_growing_grid = true
			var grew = inv.apply_grid_expansion(recipe)
			_growing_grid = false
			if grew:
				emit_signal("grid_expanded", recipe)


func register_boss_defeat():
	# En endless cada jefe es un hito, no el final. El avance de sala lo hace el Corridor
	# (antes también se avanzaba aquí y el primer jefe se saltaba una sala).
	boss_defeated_flag = true
	DebugManager.log_msg(&"game", "Boss defeated! Continuing endless...")
	emit_signal("boss_defeated")

func register_hero_death():
	if dungeon_state != DungeonState.RUNNING:
		return
	death_count += 1
	dungeon_state = DungeonState.HERO_DEAD
	var fell_at := current_enemy_level
	DebugManager.log_msg(&"game", "Hero died (total: %d) at room %d - it becomes the wall" % [death_count, fell_at])
	emit_signal("hero_died", death_count)
	# La sala donde cae es el muro y reaparece en la anterior (spec de rangos, apartado 7). Con candado,
	# el candado baja con él: su sala es la actual.
	current_enemy_level = maxi(1, fell_at - 1)
	_wins_since_retry = 0
	_set_wall(fell_at)
func request_respawn() -> bool:
	if not can_respawn():
		return false
	dungeon_state = DungeonState.RUNNING
	DebugManager.log_msg(&"game", "Hero respawned at enemy level %d" % current_enemy_level)
	emit_signal("hero_respawned", death_count)
	emit_signal("enemy_spawned", current_enemy_level)
	emit_signal("enemy_level_changed", current_enemy_level)
	return true

func respawn_hero():
		return request_respawn()

func can_respawn() -> bool:
		return dungeon_state == DungeonState.HERO_DEAD

func is_run_active() -> bool:
		return dungeon_state == DungeonState.RUNNING

func deliver_item_to_hero(item_id: StringName, slot: StringName = StringName()) -> void:
		if item_id == StringName():
				return
		var resolved_slot := slot
		if resolved_slot == StringName() and ITEM_DEFAULT_SLOT.has(item_id):
				resolved_slot = ITEM_DEFAULT_SLOT[item_id]
		if resolved_slot == StringName():
				resolved_slot = &"trinket"
		hero_loadout[resolved_slot] = item_id
		_apply_hero_loadout()

func get_hero_loadout() -> Dictionary:
		return hero_loadout.duplicate(true)

func _apply_hero_loadout() -> void:
		if _hero and _hero.has_method("apply_loadout"):
				_hero.apply_loadout(_build_loadout_bonus())
		emit_signal("hero_loadout_changed", get_hero_loadout())

func _build_loadout_bonus() -> Dictionary:
		var totals := {}
		for slot in hero_loadout.keys():
				var item_id: StringName = hero_loadout[slot]
				if item_id == StringName():
						continue
				var bonus: Dictionary = ITEM_BONUSES.get(item_id, {})
				for key in bonus.keys():
						var accum: float = totals.get(key, 0.0)
						totals[key] = accum + bonus[key]
		return totals

# ═══════════════════════════════════════════════════════════════════
#  PERSISTENCIA
# ═══════════════════════════════════════════════════════════════════

func _on_data_ready_load_save() -> void:
	"""Llamado una vez que DataManager tiene los blueprints cargados."""
	if _SaveManager.has_save():
		_save_loaded = _SaveManager.load_game()
		DebugManager.log_msg(&"game", "Save loaded: %s" % str(_save_loaded))
	else:
		DebugManager.log_msg(&"game", "No save file found — fresh start")
	# Sin partida (o si no se pudo leer) no hay nada desbloqueado: los hitos del récord dan al menos los básicos I.
	# Con partida ya los ha aplicado SaveManager.load_game().
	if not _save_loaded:
		apply_record_milestones()
	_close_save_allowed = _save_loaded or not _SaveManager.has_save()


## Aplica en silencio los hitos que ya supera el récord (los básicos I siempre). Lo llama SaveManager.load_game() al
## cargar una partida (también al migrarla) y _on_data_ready_load_save() cuando no hay partida.
func apply_record_milestones() -> Array:
	var dm = get_node_or_null("/root/DataManager")
	if dm == null or not dm.has_method("apply_milestones"):
		return []
	return dm.apply_milestones(Ranks.milestones_up_to_record(best_enemy_level))

func is_save_loaded() -> bool:
	return _save_loaded

func _on_autosave_timeout() -> void:
	_SaveManager.save_game()

## Al cerrar la ventana, con el botón Atrás de Android (que cierra la app) o al mandar el juego al fondo en el móvil (donde el
## sistema puede cerrarlo sin avisar) se guarda ya: si no, se perdía lo hecho desde el último guardado (hasta un minuto de
## autoguardado). Nunca antes de cargar los datos, ni si había un guardado que no se pudo leer: no se pisa con el estado
## vacío del arranque.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_APPLICATION_PAUSED]:
		if _close_save_allowed:
			_SaveManager.save_game()

func _on_trigger_save(_value = null) -> void:
	# Defer para no guardar en medio de un frame de combate. Los guardados que se piden en un mismo fotograma son una sola
	# escritura: un cambio de la rejilla de Tico avisa de las piezas y del equipo, y cada aviso pedía la partida entera.
	if _save_pending:
		return
	_save_pending = true
	call_deferred("_deferred_save")

func _deferred_save() -> void:
	_save_pending = false  # antes de escribir: un cambio posterior pide otro guardado
	if save_writer.is_valid():
		save_writer.call()
	else:
		_SaveManager.save_game()

func to_save_data() -> Dictionary:
	var enemies_str := {}
	for k in enemies_defeated:
		enemies_str[str(k)] = enemies_defeated[k]

	var loadout_str := {}
	for slot in hero_loadout:
		loadout_str[String(slot)] = String(hero_loadout[slot])

	return {
		"current_enemy_level": current_enemy_level,
		"best_enemy_level": best_enemy_level,
		"wall_room": wall_room,
		"room_locked": room_locked,
		"death_count": death_count,
		"enemies_defeated": enemies_str,
		"hero_loadout": loadout_str,
	}

func load_save_data(data: Dictionary) -> void:
	current_enemy_level = int(data.get("current_enemy_level", 1))
	best_enemy_level = maxi(int(data.get("best_enemy_level", 1)), current_enemy_level)
	wall_room = clampi(int(data.get("wall_room", 0)), 0, best_enemy_level)
	room_locked = bool(data.get("room_locked", false))
	_wins_since_retry = 0
	death_count = int(data.get("death_count", 0))

	enemies_defeated.clear()
	var ed: Dictionary = data.get("enemies_defeated", {})
	for k in ed:
		enemies_defeated[int(k)] = ed[k]

	var ld: Dictionary = data.get("hero_loadout", {})
	for slot in ld:
		hero_loadout[StringName(slot)] = StringName(ld[slot])

	DebugManager.log_msg(&"game", "Loaded: enemy_lv=%d deaths=%d enemies_defeated=%d" % [current_enemy_level, death_count, enemies_defeated.size()])
	# Si la partida ya estaba en marcha (Main arrancado antes de cargar), resincronizar el corredor
	if dungeon_state == DungeonState.RUNNING:
		emit_signal("enemy_level_changed", current_enemy_level)
	emit_signal("progress_loaded")
