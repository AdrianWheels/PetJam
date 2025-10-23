extends CharacterBody2D

signal stats_reset
signal died(drops)

const BASE_HP := 40
const BASE_DMG := 5.0
const BASE_APS := 0.8
const PULSE_INTERVAL := 2.5
const BOSS_LEVEL_MULTIPLIER := 1.6

var level: int = 1
var STR: float = 0.0
var AGI: float = 0.0
var INT: float = 0.0

var max_hp: int = BASE_HP
var hp: int = BASE_HP
var dmg: float = BASE_DMG
var aps: float = BASE_APS
var crit_p: float = 0.0
var crit_m: float = 1.5
var atk_timer: float = 0.0
var pulse_timer: float = PULSE_INTERVAL
var alive: bool = true

var size: Vector2 = Vector2(40, 52)
var shape: String = "rect"

@export var is_boss: bool = false
@export var drop_table: DropTable

var _rng := RandomNumberGenerator.new()

const DEFAULT_DROP_TABLE := preload("res://data/drops/basic_enemy_drop.tres")

func _ready():
        if drop_table == null:
                drop_table = DEFAULT_DROP_TABLE
        _rng.randomize()
        reset_stats()

func configure_for_level(lv: int, boss: bool) -> void:
        level = lv
        is_boss = boss
        reset_stats()

func reset_stats():
        STR = 2.0 + level * 1.4
        AGI = 1.0 + level * 0.8
        INT = 1.0 + level * 0.6
        var multiplier := (BOSS_LEVEL_MULTIPLIER if is_boss else 1.0)
        var base_hp := BASE_HP * (1.0 + (level - 1) * 0.15) * multiplier
        max_hp = int(base_hp)
        hp = max_hp
        dmg = (BASE_DMG + STR * 1.5) * multiplier
        aps = clamp(BASE_APS + AGI * 0.02, 0.3, 5.0)
        crit_p = min(0.5, AGI * 0.005)
        crit_m = clamp(1.5 + INT * 0.01, 1.0, 2.0)
        atk_timer = 1.0 / aps
        pulse_timer = PULSE_INTERVAL
        alive = true
        size = Vector2(40 + min(20, level * 2), 52 + min(18, level * 2))
        shape = "rect" if level % 2 == 0 else "circle"
        emit_signal("stats_reset")

func expected_dps() -> float:
        var hit = dmg * (1.0 + crit_p * (crit_m - 1.0))
        var pulse_dmg = (INT * 3.0) / PULSE_INTERVAL
        return aps * hit + pulse_dmg

func take_damage(amount: int, _is_pulse: bool = false):
        if not alive:
                return
        hp = max(0, hp - amount)
        if hp == 0:
                _die()

func attack(target, particles: Array):
        if not alive or target == null or not target.alive:
                return
        atk_timer -= get_process_delta_time()
        while atk_timer <= 0.0 and target.alive:
                atk_timer += 1.0 / aps
                var damage := dmg
                var crit := randf() < crit_p
                if crit:
                        damage *= crit_m
                        for i in range(12):
                                particles.append(_create_spark_particle(target.position))
                target.take_damage(int(damage))

func pulse(target, particles: Array):
        if not alive or target == null or not target.alive:
                return
        pulse_timer -= get_process_delta_time()
        if pulse_timer <= 0.0:
                pulse_timer += PULSE_INTERVAL
                target.take_damage(int(INT * 3), true)
                particles.append(_create_pulse_particle(target.position))

func prepare_for_combat() -> void:
        atk_timer = 1.0 / aps
        pulse_timer = PULSE_INTERVAL

func generate_drops() -> Array[Dictionary]:
        if drop_table == null:
                return []
        return drop_table.roll_drops(_rng)

func _die() -> void:
        if not alive:
                return
        alive = false
        hp = 0
        emit_signal("died", generate_drops())

func _create_spark_particle(pos: Vector2) -> Dictionary:
        var angle := randf() * PI * 2.0
        var speed := 80.0 + randf() * 80.0
        return {
                "type": "spark",
                "position": pos,
                "velocity": Vector2(cos(angle), sin(angle)) * speed,
                "timer": 0.35
        }

func _create_pulse_particle(pos: Vector2) -> Dictionary:
        return {
                "type": "pulse",
                "position": pos,
                "timer": 0.35
        }
