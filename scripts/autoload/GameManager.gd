extends Node
class_name GameManager

signal room_entered(room_idx)
signal hero_died(death_count)
signal hero_respawned(death_count)
signal boss_defeated
signal game_over
signal dungeon_state_changed(new_state)
signal hero_loadout_changed(loadout)

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

var current_room: int = 1
var total_rooms: int = 9
var inventory := {}
var blueprints_unlocked := {}

var dungeon_state: int = DungeonState.IDLE:
        set(value):
                if field == value:
                        return
                field = value
                emit_signal("dungeon_state_changed", field)
        get:
                return field

var death_count: int = 0
var boss_defeated: bool = false
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
        current_room = 1
        death_count = 0
        boss_defeated = false
        dungeon_state = DungeonState.RUNNING
        print("GameManager: Starting new run at room 1")
        emit_signal("room_entered", current_room)
        emit_signal("hero_respawned", death_count)

func advance_room():
        current_room += 1
        print("GameManager: Advanced to room %d" % current_room)
        if current_room > total_rooms:
                register_boss_defeat()
        else:
                emit_signal("room_entered", current_room)

func register_enemy_defeat(level: int) -> void:
        if dungeon_state != DungeonState.RUNNING:
                return
        print("GameManager: Enemy defeated at level %d" % level)

func register_boss_defeat():
        if boss_defeated:
                return
        boss_defeated = true
        dungeon_state = DungeonState.COMPLETED
        print("GameManager: Boss defeated! Run completed")
        emit_signal("boss_defeated")
        emit_signal("game_over")

func register_hero_death():
        if dungeon_state == DungeonState.FAILED or dungeon_state == DungeonState.COMPLETED:
                return
        death_count += 1
        dungeon_state = DungeonState.HERO_DEAD
        print("GameManager: Hero died (%d/%d)" % [death_count, MAX_DEATHS])
        emit_signal("hero_died", death_count)
        if death_count >= MAX_DEATHS:
                dungeon_state = DungeonState.FAILED
                print("GameManager: Run failed - maximum deaths reached")
                emit_signal("game_over")

func request_respawn() -> bool:
        if not can_respawn():
                return false
        dungeon_state = DungeonState.RUNNING
        print("GameManager: Hero respawned")
        emit_signal("hero_respawned", death_count)
        return true

func respawn_hero():
        return request_respawn()

func can_respawn() -> bool:
        if dungeon_state != DungeonState.HERO_DEAD:
                return false
        if boss_defeated:
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
                        var accum := totals.get(key, 0)
                        totals[key] = accum + bonus[key]
        return totals
