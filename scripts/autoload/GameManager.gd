extends Node
class_name GameManager

signal enemy_spawned(enemy_level)  # Cuando spawnea un nuevo nivel de enemigo
signal hero_died(death_count)
signal hero_respawned(death_count)
signal boss_defeated
signal game_over
signal dungeon_state_changed(new_state)
signal hero_loadout_changed(loadout)
signal enemy_defeated_first_time(enemy_level)  # Nueva señal para desbloquear blueprint
signal enemy_level_changed(new_level)  # Señal cuando cambia nivel de enemigo

const MAX_DEATHS := 50

enum DungeonState { IDLE, RUNNING, HERO_DEAD, COMPLETED, FAILED }

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

var current_enemy_level: int = 1  # Nivel del enemigo actual (1-9)
var max_enemy_levels: int = 9  # Total de niveles antes del jefe (nivel 8+)
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

func _ready():
		print("GameManager: Ready")

func register_hero(hero_node: Node) -> void:
		_hero = hero_node
		_apply_hero_loadout()

func start_run():
	current_enemy_level = 1
	death_count = 0
	boss_defeated_flag = false
	enemies_defeated.clear()  # Reset enemigos derrotados al iniciar run
	dungeon_state = DungeonState.RUNNING
	print("GameManager: Starting new run at enemy level 1")
	emit_signal("enemy_spawned", current_enemy_level)
	emit_signal("enemy_level_changed", current_enemy_level)
	emit_signal("hero_respawned", death_count)
func advance_enemy_level():
	current_enemy_level += 1
	print("GameManager: Advanced to enemy level %d" % current_enemy_level)
	emit_signal("enemy_level_changed", current_enemy_level)
	if current_enemy_level > max_enemy_levels:
		register_boss_defeat()
	else:
		emit_signal("enemy_spawned", current_enemy_level)
func register_enemy_defeat(level: int) -> void:
	if dungeon_state != DungeonState.RUNNING:
		return
	print("GameManager: Enemy level %d defeated (current_enemy_level: %d)" % [level, current_enemy_level])
	
	# Si es la primera vez que se derrota este nivel de enemigo, desbloquear blueprint
	if not enemies_defeated.has(level):
		enemies_defeated[level] = true
		print("GameManager: Enemy level %d defeated for FIRST TIME - unlocking blueprint" % level)
		emit_signal("enemy_defeated_first_time", level)
		
		# Desbloquear un blueprint aleatorio
		var dm = get_node_or_null("/root/DataManager")
		if dm and dm.has_method("get_locked_blueprints"):
			var locked = dm.get_locked_blueprints()
			if locked.size() > 0:
				var random_bp = locked[randi() % locked.size()]
				if dm.unlock_blueprint(random_bp):
					print("GameManager: ✓ Unlocked blueprint '%s'" % random_bp)
					# TODO: Mostrar notificación "¡Nuevo blueprint descubierto: [Nombre]!"
			else:
				print("GameManager: No locked blueprints available to unlock")
func register_boss_defeat():
		if boss_defeated_flag:
				return
		boss_defeated_flag = true
		dungeon_state = DungeonState.COMPLETED
		print("GameManager: Boss defeated! Run completed")
		emit_signal("boss_defeated")
		emit_signal("game_over")

func register_hero_death():
	if dungeon_state == DungeonState.FAILED or dungeon_state == DungeonState.COMPLETED:
		return
	death_count += 1
	dungeon_state = DungeonState.HERO_DEAD
	print("GameManager: Hero died (%d/%d) - will respawn at enemy level 1" % [death_count, MAX_DEATHS])
	emit_signal("hero_died", death_count)
	
	# Reset a nivel de enemigo 1 cuando muere
	current_enemy_level = 1
	
	if death_count >= MAX_DEATHS:
		dungeon_state = DungeonState.FAILED
		print("GameManager: Run failed - maximum deaths reached")
		emit_signal("game_over")
func request_respawn() -> bool:
	if not can_respawn():
		return false
	dungeon_state = DungeonState.RUNNING
	print("GameManager: Hero respawned at enemy level %d" % current_enemy_level)
	emit_signal("hero_respawned", death_count)
	emit_signal("enemy_spawned", current_enemy_level)  # Spawnear enemigo del nivel actual
	emit_signal("enemy_level_changed", current_enemy_level)  # Actualizar nivel de enemigo en UI
	return true

func respawn_hero():
		return request_respawn()

func can_respawn() -> bool:
		if dungeon_state != DungeonState.HERO_DEAD:
				return false
		if boss_defeated_flag:
				return false
		if death_count >= MAX_DEATHS:
				return false
		return true

func is_run_failed() -> bool:
		return dungeon_state == DungeonState.FAILED

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
