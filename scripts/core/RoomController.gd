

extends Node

var current_room = 0
var total_rooms = 9 # 8 + jefe
var hero = null
var enemy = null
var state = "RUN" # RUN, FIGHT, DEAD
var death_timer = 0.0
var hero_speed = 120
var room_distance = 520
var ground_y = 180

var HeroScene = preload("res://scripts/core/Hero.gd")
var EnemyScene = preload("res://scripts/core/Enemy.gd")

func _ready():
	print("[RoomController] ready. Iniciando dungeon loop.")
	start_run()

func start_run():
	print("[RoomController] Start run. Room %d" % current_room)
	hero = HeroScene.new()
	hero.position = Vector2(100, ground_y)
	spawn_enemy(current_room)
	state = "RUN"
	death_timer = 0.0
	set_process(true)

func spawn_enemy(idx):
	if idx == total_rooms - 1:
		enemy = EnemyScene.new()
		enemy.hp = 240
		enemy.atk = 12
	else:
		enemy = EnemyScene.new()
	enemy.position = Vector2(hero.position.x + room_distance, ground_y)

func _process(delta):
	if state == "RUN":
		hero.position.x += hero_speed * delta
		if hero.position.x + hero.get_width() > enemy.position.x:
			print("[RoomController] Hero llegó al enemigo. Iniciando combate.")
			state = "FIGHT"
	elif state == "FIGHT":
		# Combate automático
		enemy.hp -= hero.atk * delta
		hero.hp -= enemy.atk * delta
		print("[RoomController] Combate: Hero HP %d, Enemy HP %d" % [hero.hp, enemy.hp])
		if hero.hp <= 0:
			hero.hp = 0
			print("[RoomController] Hero ha muerto. Respawn en 1s.")
			state = "DEAD"
			death_timer = 1.0
		elif enemy.hp <= 0:
			enemy.hp = 0
			print("[RoomController] Enemy derrotado. Avanzando a la siguiente sala.")
			advance_room()
	elif state == "DEAD":
		death_timer -= delta
		if death_timer <= 0:
			print("[RoomController] Respawn del héroe.")
			reset_to_first_room()

func reset_to_first_room():
	print("[RoomController] Reiniciando dungeon en sala 0.")
	current_room = 0
	get_node("/root/TelemetryManager").record_hero_death()
	start_run()

func advance_room():
	current_room += 1
	print("[RoomController] Nueva sala: %d" % current_room)
	get_node("/root/TelemetryManager").record_room_cleared()
	if current_room >= total_rooms:
		print("[RoomController] ¡Dungeon completada!")
		get_node("/root/GameManager").win()
		set_process(false)
	else:
		start_run()
