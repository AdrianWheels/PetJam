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

@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var level_label: Label = $LevelLabel if has_node("LevelLabel") else null
@onready var sprite: ColorRect = $Sprite if has_node("Sprite") else null

func _ready():
        if drop_table == null:
                drop_table = DEFAULT_DROP_TABLE
        _rng.randomize()
        reset_stats()
        _update_visuals()
        print("Enemy: Ready at position %v, z_index=%d, visible=%s, level=%d" % [position, z_index, visible, level])

func configure_for_level(lv: int, boss: bool) -> void:
        level = lv
        is_boss = boss
        reset_stats()
        _update_visuals()

func reset_stats():
        # Escala MUCHO más agresiva - necesitas crafteo para avanzar
        STR = 3.0 + level * 2.5  # Era 1.4, ahora 2.5
        AGI = 1.5 + level * 1.2  # Era 0.8, ahora 1.2
        INT = 1.5 + level * 0.9  # Era 0.6, ahora 0.9
        var multiplier := (BOSS_LEVEL_MULTIPLIER if is_boss else 1.0)
        # HP escala mucho más: nivel 1 = 40, nivel 2 = 72, nivel 3 = 112
        var base_hp := BASE_HP * (1.0 + (level - 1) * 0.8) * multiplier  # Era 0.15, ahora 0.8
        max_hp = int(base_hp)
        hp = max_hp
        dmg = (BASE_DMG + STR * 1.8) * multiplier  # Era 1.5, ahora 1.8
        aps = clamp(BASE_APS + AGI * 0.03, 0.3, 5.0)  # Era 0.02, ahora 0.03
        crit_p = min(0.5, AGI * 0.008)  # Era 0.005, ahora 0.008
        crit_m = clamp(1.5 + INT * 0.015, 1.0, 2.5)  # Era 0.01/2.0, ahora 0.015/2.5
        atk_timer = 1.0 / aps
        pulse_timer = PULSE_INTERVAL
        alive = true
        size = Vector2(40 + min(20, level * 2), 52 + min(18, level * 2))
        shape = "rect" if level % 2 == 0 else "circle"
        print("Enemy: Level %d stats: HP=%d, DMG=%.1f, APS=%.2f (STR=%.1f, AGI=%.1f, INT=%.1f)" % [level, max_hp, dmg, aps, STR, AGI, INT])
        emit_signal("stats_reset")

func expected_dps() -> float:
        var hit = dmg * (1.0 + crit_p * (crit_m - 1.0))
        var pulse_dmg = (INT * 3.0) / PULSE_INTERVAL
        return aps * hit + pulse_dmg

func take_damage(amount: int, _is_pulse: bool = false):
        if not alive:
                return
        hp = max(0, hp - amount)
        _update_health_bar()
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

func generate_drops() -> Array:
        if drop_table == null:
                return []
        
        # Drop de materiales aleatorios
        _drop_random_materials()
        
        return drop_table.roll_drops(_rng)

func _drop_random_materials() -> void:
        """Dropea 15 unidades de un material aleatorio de los disponibles en blueprints"""
        var dm := get_node_or_null("/root/DataManager")
        if not dm or not dm.has_method("get_all_blueprints"):
                return
        
        # Recopilar todos los materiales únicos de todos los blueprints
        var all_materials: Array[StringName] = []
        var all_blueprints: Dictionary = dm.get_all_blueprints()
        
        for bp_id in all_blueprints:
                var blueprint = all_blueprints[bp_id]
                if blueprint is BlueprintResource and not blueprint.materials.is_empty():
                        for mat_id in blueprint.materials.keys():
                                if not all_materials.has(mat_id):
                                        all_materials.append(StringName(mat_id))
        
        if all_materials.is_empty():
                print("Enemy: No materials found in blueprints")
                return
        
        # Elegir material aleatorio y dar 15 unidades (aumentado desde 5 para evitar softlocks)
        var random_material: StringName = all_materials[_rng.randi() % all_materials.size()]
        var drop_amount := 15
        
        var im := get_node_or_null("/root/InventoryManager")
        if im and im.has_method("add_item"):
                im.add_item(random_material, drop_amount)
                print("Enemy: Dropped %d x %s" % [drop_amount, random_material])
        else:
                print("Enemy: InventoryManager not found, cannot drop materials")

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

func _update_health_bar() -> void:
        if not health_bar:
                return
        health_bar.max_value = max_hp
        health_bar.value = hp
        
        # Color coding basado en % de HP
        var hp_percent := (hp / float(max_hp)) * 100.0
        if hp_percent > 60.0:
                health_bar.modulate = Color.GREEN
        elif hp_percent > 30.0:
                health_bar.modulate = Color.ORANGE
        else:
                health_bar.modulate = Color.RED

func _update_visuals() -> void:
        # Actualizar etiqueta de nivel
        if level_label:
                var text := "Lv %d" % level
                if is_boss:
                        text += " BOSS"
                level_label.text = text
        
        # Escalar sprite según nivel (crece con nivel)
        if sprite:
                var base_size := Vector2(40, 52)
                var scale_factor := 1.0 + (level - 1) * 0.15
                sprite.custom_minimum_size = base_size * scale_factor
                
                # Bosses tienen tinte dorado
                if is_boss:
                        sprite.color = Color(1.0, 0.85, 0.0)  # Amarillo/Oro
                else:
                        sprite.color = Color(0.9, 0.2, 0.2)  # Rojo normal
