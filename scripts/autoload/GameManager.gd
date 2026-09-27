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
signal blueprint_unlocked(blueprint_id)  # Plano desbloqueado al matar un enemigo por primera vez
signal record_changed(best_level)  # Nueva sala máxima alcanzada (base del leaderboard)
signal progress_loaded  # La partida guardada ya está aplicada (para refrescar HUDs)
signal buffs_changed(active: Dictionary)  # Un efecto temporal empieza, se renueva o caduca (id → segundos)

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
var best_enemy_level: int = 1  # Sala más profunda alcanzada nunca (récord / leaderboard)
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
var _autosave_timer: Timer = null

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

func get_hero() -> Node:
	return _hero

func register_hero(hero_node: Node) -> void:
	_hero = hero_node
	# Aplicar stats de equipo actual al registrar héroe
	_on_equipment_changed({})

func _on_equipment_changed(_equipment_stats: Dictionary) -> void:
	"""Cuando cambia el equipamiento, recalcular stats del héroe"""
	if _hero and _hero.has_method("reset_stats"):
		_hero.reset_stats()
		DebugManager.log_msg(&"game", "Hero stats recalculated after equipment change")

func start_run():
	# Con partida cargada se continúa donde estaba (no hay "runs": es una sesión persistente)
	if not _save_loaded:
		current_enemy_level = 1
		death_count = 0
		enemies_defeated.clear()
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
func register_enemy_defeat(level: int) -> void:
	if dungeon_state != DungeonState.RUNNING:
		return
	DebugManager.log_msg(&"game", "Enemy level %d defeated (current: %d)" % [level, current_enemy_level])
	
	# Si es la primera vez que se derrota este nivel, desbloquear blueprint
	if not enemies_defeated.has(level):
		enemies_defeated[level] = true
		DebugManager.log_msg(&"game", "Enemy level %d first kill - unlocking blueprint" % level)
		emit_signal("enemy_defeated_first_time", level)
		
		var dm = get_node_or_null("/root/DataManager")
		if dm and dm.has_method("get_locked_blueprints"):
			var locked = dm.get_locked_blueprints()
			if locked.size() > 0:
				var random_bp = locked[randi() % locked.size()]
				if dm.unlock_blueprint(random_bp):
					DebugManager.log_msg(&"game", "Unlocked blueprint '%s'" % random_bp)
					emit_signal("blueprint_unlocked", StringName(random_bp))
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
	DebugManager.log_msg(&"game", "Hero died (total: %d) - will respawn at enemy level 1" % death_count)
	emit_signal("hero_died", death_count)
	# Reset a nivel de enemigo 1 cuando muere (endless: sin límite)
	current_enemy_level = 1
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

func is_save_loaded() -> bool:
	return _save_loaded

func _on_autosave_timeout() -> void:
	_SaveManager.save_game()

func _on_trigger_save(_value = null) -> void:
	# Defer para no guardar en medio de un frame de combate
	call_deferred("_deferred_save")

func _deferred_save() -> void:
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
		"death_count": death_count,
		"enemies_defeated": enemies_str,
		"hero_loadout": loadout_str,
	}

func load_save_data(data: Dictionary) -> void:
	current_enemy_level = int(data.get("current_enemy_level", 1))
	best_enemy_level = maxi(int(data.get("best_enemy_level", 1)), current_enemy_level)
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
