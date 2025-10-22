extends Node2D

@onready var hero: Node = $Hero
@onready var enemy: Node = $Enemy
@onready var combat_controller: Node = $CombatController
@onready var particle_manager: Node = $ParticleManager
@onready var camera: Camera2D = $Camera2D

const HERO_SPEED = 120
const SPAWN_DISTANCE = 520
const GROUND_Y = 460
const CAM_LERP = 0.12

enum State { RUN, FIGHT, DEAD }

var state = State.RUN
var level = 1
var cam_x = 0
var ground_offset = 0
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
	cam_follow(delta)
	particle_manager.update_particles(delta)
	queue_redraw()

func update_run(delta: float):
	hero.position.x += HERO_SPEED * delta
	if check_overlap(hero.position, hero.size, enemy.position, enemy.size):
		state = State.FIGHT
		combat_controller.start_combat()
	ground_offset += HERO_SPEED * delta

func update_fight(_delta: float):
	pass  # Combat handled by CombatController

func update_dead(_delta: float):
	pass  # Handled by CombatController

func cam_follow(delta: float):
	var target_x = hero.position.x - 960 * 0.33  # Assuming 960 width
	cam_x = lerp(cam_x, target_x, 1 - pow(1 - CAM_LERP, max(1, delta * 60)))
	if camera:
		camera.position.x = cam_x

func check_overlap(pos1: Vector2, size1: Vector2, pos2: Vector2, size2: Vector2) -> bool:
	var rect1 = Rect2(pos1 - size1 / 2, size1)
	var rect2 = Rect2(pos2 - size2 / 2, size2)
	return rect1.intersects(rect2)

func advance_enemy():
	level = min(8, level + 1)
	spawn_enemy(level, hero.position.x + SPAWN_DISTANCE)
	state = State.RUN
	dist_ref = enemy.position.x - hero.position.x

func spawn_enemy(lv: int, x: float):
	enemy.level = lv
	enemy.reset_stats()
	enemy.position = Vector2(x, GROUND_Y)

func reset_run():
	hero.respawn()
	level = 1
	spawn_enemy(level, hero.position.x + SPAWN_DISTANCE)
	state = State.RUN
	cam_x = 0
	ground_offset = 0
	dist_ref = enemy.position.x - hero.position.x

func _draw():
	# Draw background parallax
	draw_parallax(0.12, Color(0x0e / 255.0, 0x17 / 255.0, 0x26 / 255.0), 40, 0.6)
	draw_parallax(0.3, Color(0x0a / 255.0, 0x1a / 255.0, 0x2f / 255.0), 20, 0.8)
	# Draw ground
	draw_rect(Rect2(-1000, GROUND_Y, 2000, 540 - GROUND_Y), Color(0x11 / 255.0, 0x18 / 255.0, 0x27 / 255.0))
	draw_ground()
	# Draw entities
	draw_hero()
	draw_enemy()
	particle_manager.draw_particles(self, cam_x)

func draw_parallax(factor: float, color: Color, stripe: int, alpha: float):
	var w = 960
	var off = -int(fmod(cam_x * factor, float(stripe)))
	color.a = alpha
	for x in range(off - stripe, w + stripe, stripe):
		draw_rect(Rect2(x, 0, 2, GROUND_Y - 40), color)

func draw_ground():
	var w = 960
	var step = 32
	var off = -int(fmod(ground_offset * 0.8, float(step)))
	for x in range(off - step, w + step, step):
		var y = GROUND_Y + ((x * 0.15) as int & 7)
		draw_line(Vector2(x, y), Vector2(x + step, y), Color(0x1f / 255.0, 0x29 / 255.0, 0x37 / 255.0), 2)

func draw_hero():
	var pos = hero.position - Vector2(cam_x, 0)
	var size = hero.size
	draw_rect(Rect2(pos - size / 2, size), Color(0x38 / 255.0, 0xbf / 255.0, 0xf8 / 255.0))
	var stripe_size = size - Vector2(16, 16)
	draw_rect(Rect2(pos - stripe_size / 2, stripe_size), Color(0x0e / 255.0, 0xa5 / 255.0, 0xe9 / 255.0))

func draw_enemy():
	var pos = enemy.position - Vector2(cam_x, 0)
	var size = enemy.size
	var color = Color.from_hsv((enemy.level - 1) / 7.0, 1, 1)
	if enemy.shape == "rect":
		draw_rect(Rect2(pos - size / 2, size), color)
	else:
		draw_circle(pos, size.x / 2, color)