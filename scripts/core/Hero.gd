extends Node

# Base stats from HTML
const BASE_HP = 60
const BASE_DMG = 6
const BASE_APS = 1.0
const BASE_STR = 10
const BASE_AGI = 10
const BASE_INT = 8

var STR: int = BASE_STR
var AGI: int = BASE_AGI
var INT: int = BASE_INT

var max_hp: int
var hp: int
var dmg: float
var aps: float
var crit_p: float
var crit_m: float
var atk_timer: float
var pulse_timer: float = 2.5
var alive: bool = true

var position: Vector2 = Vector2.ZERO
var size: Vector2 = Vector2(42, 64)

func _ready():
	reset_stats()

func reset_stats():
	max_hp = BASE_HP + STR * 10
	hp = max_hp
	dmg = BASE_DMG + STR * 1.5
	aps = clamp(BASE_APS + AGI * 0.02, 0.3, 5.0)
	crit_p = min(0.5, AGI * 0.005)
	crit_m = clamp(1.5 + INT * 0.01, 1.0, 2.0)
	atk_timer = 1.0 / aps
	alive = true

func expected_dps() -> float:
	var hit = dmg * (1 + crit_p * (crit_m - 1))
	var pulse_dmg = (INT * 3) / 2.5
	return aps * hit + pulse_dmg

func take_damage(amount: int, _is_pulse: bool = false):
	if not alive:
		return
	hp -= amount
	if hp <= 0:
		hp = 0
		alive = false

func attack(target, particles: Array):
	if not alive or not target.alive:
		return
	atk_timer -= get_process_delta_time()
	while atk_timer <= 0 and target.alive:
		atk_timer += 1.0 / aps
		var damage = dmg
		var crit = randf() < crit_p
		if crit:
			damage *= crit_m
			# Add critical particles
			for i in range(12):
				particles.append(create_spark_particle(target.position))
		target.take_damage(int(damage))

func pulse(target, particles: Array):
	if not alive or not target.alive:
		return
	pulse_timer -= get_process_delta_time()
	if pulse_timer <= 0:
		pulse_timer += 2.5
		target.take_damage(INT * 3, true)
		particles.append(create_pulse_particle(target.position))

func create_spark_particle(pos: Vector2) -> Dictionary:
	var angle = randf() * PI * 2
	var speed = 80 + randf() * 80
	return {
		"type": "spark",
		"position": pos,
		"velocity": Vector2(cos(angle), sin(angle)) * speed,
		"timer": 0.35
	}

func create_pulse_particle(pos: Vector2) -> Dictionary:
	return {
		"type": "pulse",
		"position": pos,
		"timer": 0.35
	}

func respawn():
	reset_stats()
	position = Vector2(100, 460)  # Assuming ground at 460
