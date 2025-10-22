extends Node2D

@onready var hero: Node = $Hero
@onready var enemy: Node = $Enemy
@onready var combat_controller: Node = $CombatController
@onready var particle_manager: Node = $ParticleManager

const HERO_SPEED = 120
const SPAWN_DISTANCE = 520
const GROUND_Y = 460

enum State { RUN, FIGHT, DEAD }

var state = State.RUN
var level = 1
var dist_ref = 0

func _ready():
	reset_run()

func _process(delta: float):
	match state:
		State.RUN:
			update_run(delta)
		State.FIGHT:
			update_fight(delta)
		State.DEAD:
			update_dead(delta)
	particle_manager.update_particles(delta)
	queue_redraw()

func update_run(delta: float):
	hero.position.x += HERO_SPEED * delta
	if check_overlap(hero.position, hero.size, enemy.position, enemy.size):
		state = State.FIGHT
		combat_controller.start_combat()

func update_fight(_delta: float):
	pass  # Combat handled by CombatController

func update_dead(_delta: float):
	pass  # Combat handled by CombatController

func check_overlap(pos1: Vector2, size1: Vector2, pos2: Vector2, size2: Vector2) -> bool:
	var rect1 = Rect2(pos1 - size1 / 2, size1)
	var rect2 = Rect2(pos2 - size2 / 2, size2)
	return rect1.intersects(rect2)

func advance_enemy():
	level = min(8, level + 1)
	spawn_enemy(level, 2620)
	hero.position.x = 2100  # Reset hero position
	state = State.RUN
	dist_ref = enemy.position.x - hero.position.x

func spawn_enemy(lv: int, x: float):
	enemy.level = lv
	enemy.reset_stats()
	enemy.position = Vector2(x, GROUND_Y)

func reset_run():
	hero.respawn()
	level = 1
	spawn_enemy(level, 2620)
	state = State.RUN
	dist_ref = enemy.position.x - hero.position.x

func _draw():
	# Draw static background
	var center_x = 2000  # Dungeon center
	draw_rect(Rect2(center_x - 480, 0, 960, 540), Color(0x0b / 255.0, 0x0f / 255.0, 0x17 / 255.0))
	# Draw ground
	draw_rect(Rect2(center_x - 480, GROUND_Y, 960, 540 - GROUND_Y), Color(0x11 / 255.0, 0x18 / 255.0, 0x27 / 255.0))
	# Draw entities
	draw_hero()
	draw_enemy()
	particle_manager.draw_particles(self, 2000)

func draw_hero():
	var pos = hero.position
	var size = hero.size
	draw_rect(Rect2(pos - size / 2, size), Color(0x38 / 255.0, 0xbf / 255.0, 0xf8 / 255.0))
	var stripe_size = size - Vector2(16, 16)
	draw_rect(Rect2(pos - stripe_size / 2, stripe_size), Color(0x0e / 255.0, 0xa5 / 255.0, 0xe9 / 255.0))

func draw_enemy():
	var pos = enemy.position
	var size = enemy.size
	var color = Color.from_hsv((enemy.level - 1) / 7.0, 1, 1)
	if enemy.shape == "rect":
		draw_rect(Rect2(pos - size / 2, size), color)
	else:
		draw_circle(pos, size.x / 2, color)