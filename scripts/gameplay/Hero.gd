extends CharacterBody2D

signal stats_reset
signal died
signal respawned

const BASE_HP := 60
const BASE_DMG := 6.0
const BASE_APS := 1.0
const BASE_STR := 10
const BASE_AGI := 10
const BASE_INT := 8
const PULSE_INTERVAL := 2.5

var STR: int = BASE_STR
var AGI: int = BASE_AGI
var INT: int = BASE_INT

var max_hp: int = BASE_HP
var hp: int = BASE_HP
var dmg: float = BASE_DMG
var aps: float = BASE_APS
var crit_p: float = 0.0
var crit_m: float = 1.5
var atk_timer: float = 0.0
var pulse_timer: float = PULSE_INTERVAL
var alive: bool = true

var size: Vector2 = Vector2(42, 64)
var loadout_bonus: Dictionary = {}

@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null

func _ready():
		respawn()
		_update_health_bar()
		print("Hero: Ready at position %v, z_index=%d, visible=%s" % [position, z_index, visible])

func reset_stats():
		var bonus_str: int = int(loadout_bonus.get("STR", 0))
		var bonus_agi: int = int(loadout_bonus.get("AGI", 0))
		var bonus_int: int = int(loadout_bonus.get("INT", 0))
		STR = BASE_STR + bonus_str
		AGI = BASE_AGI + bonus_agi
		INT = BASE_INT + bonus_int

		var bonus_hp: int = int(loadout_bonus.get("HP", 0))
		var bonus_dmg: float = float(loadout_bonus.get("DMG", 0.0))
		var bonus_aps: float = float(loadout_bonus.get("APS", 0.0))
		var bonus_crit_p: float = float(loadout_bonus.get("CRIT_P", 0.0))
		var bonus_crit_m: float = float(loadout_bonus.get("CRIT_M", 0.0))

		max_hp = BASE_HP + STR * 10 + bonus_hp
		hp = max_hp
		dmg = BASE_DMG + STR * 1.5 + bonus_dmg
		aps = clamp(BASE_APS + AGI * 0.02 + bonus_aps, 0.3, 5.0)
		crit_p = clamp(AGI * 0.005 + bonus_crit_p, 0.0, 0.75)
		crit_m = clamp(1.5 + INT * 0.01 + bonus_crit_m, 1.0, 3.0)
		atk_timer = 1.0 / aps
		pulse_timer = PULSE_INTERVAL
		alive = true
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
				alive = false
				emit_signal("died")

func attack(target, particles: Array) -> void:
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
		
		# Reproducir sonido de ataque UNA SOLA VEZ por golpe (volumen reducido -20dB)
		if has_node("/root/AudioManager"):
			var am = get_node("/root/AudioManager")
			if am.has_method("play_sfx"):
				var hit_sfx = load("res://art/sounds/atk_sword_flesh_hit_01.wav")
				# Contexto DUNGEON: se silencia al desactivar "Dungeon Audio" en DebugPanel
				am.play_sfx(hit_sfx, -20.0, am.AudioContext.DUNGEON)
		
		# Debug: mostrar cadencia de ataque
		print("Hero: Attack at %.2f s, dmg=%.1f, crit=%s, aps=%.2f" % [Time.get_ticks_msec()/1000.0, damage, crit, aps])
		
		target.take_damage(int(damage))

func pulse(target, particles: Array) -> void:
		if not alive or target == null or not target.alive:
				return
		pulse_timer -= get_process_delta_time()
		if pulse_timer <= 0.0:
				pulse_timer += PULSE_INTERVAL
				target.take_damage(INT * 3, true)
				particles.append(_create_pulse_particle(target.position))

func prepare_for_combat() -> void:
		atk_timer = 1.0 / aps
		pulse_timer = PULSE_INTERVAL

func respawn(start_position: Vector2 = Vector2(2100, 460)) -> void:
		reset_stats()
		position = start_position
		velocity = Vector2.ZERO
		alive = true
		emit_signal("respawned")

func apply_loadout(loadout: Dictionary) -> void:
		loadout_bonus = loadout.duplicate(true)
		reset_stats()

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
		if health_bar:
				health_bar.max_value = max_hp
				health_bar.value = hp
				
				# Color según vida restante
				var hp_ratio = float(hp) / float(max_hp) if max_hp > 0 else 0.0
				if hp_ratio > 0.6:
						health_bar.modulate = Color(0.3, 1.0, 0.3)  # Verde
				elif hp_ratio > 0.3:
						health_bar.modulate = Color(1.0, 0.7, 0.3)  # Naranja
				else:
						health_bar.modulate = Color(1.0, 0.3, 0.3)  # Rojo
