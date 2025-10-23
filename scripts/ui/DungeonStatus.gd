extends Control
class_name DungeonStatus

@onready var room_label: Label = %RoomLabel
@onready var death_label: Label = %DeathLabel
@onready var state_label: Label = %StateLabel
@onready var result_label: Label = %ResultLabel
@onready var info_label: Label = %InfoLabel

var total_rooms: int = 0
var max_deaths: int = 0

func set_total_rooms(value: int) -> void:
        total_rooms = value
        if room_label:
                room_label.text = "Sala: 0 / %d" % max(1, total_rooms)

func set_max_deaths(value: int) -> void:
        max_deaths = value
        if death_label:
                death_label.text = "Muertes: 0 / %d" % max(1, max_deaths)

func update_room(room_idx: int) -> void:
        if room_label == null:
                return
        var total := total_rooms if total_rooms > 0 else room_idx
        room_label.text = "Sala: %d / %d" % [room_idx, max(1, total)]

func update_deaths(deaths: int) -> void:
        if death_label == null:
                return
        var limit := max_deaths if max_deaths > 0 else deaths
        death_label.text = "Muertes: %d / %d" % [deaths, max(1, limit)]

func update_state(state: String) -> void:
        if state_label:
                state_label.text = "Estado: %s" % state

func show_result(text: String, color: Color = Color.WHITE) -> void:
        if result_label:
                result_label.text = text
                result_label.modulate = color
                result_label.visible = text != ""

func clear_result() -> void:
        show_result("")

func update_combat_info(hero: Node, enemy: Node, state: String) -> void:
        if info_label == null:
                return
        if hero and enemy and hero.has_method("expected_dps") and enemy.has_method("expected_dps"):
                var hero_hp: int = hero.hp
                var hero_max_hp: int = hero.max_hp
                var enemy_hp: int = enemy.hp
                var enemy_max_hp: int = enemy.max_hp
                var enemy_level: int = enemy.level
                var text := "ENEMY L%d  |  HERO HP %d/%d (DPS %.1f)  |  ENEMY HP %d/%d (DPS %.1f)  |  STATE %s" % [
                        enemy_level,
                        hero_hp,
                        hero_max_hp,
                        hero.expected_dps(),
                        enemy_hp,
                        enemy_max_hp,
                        enemy.expected_dps(),
                        state,
                ]
                info_label.text = text
        else:
                info_label.text = "Estado: %s" % state
