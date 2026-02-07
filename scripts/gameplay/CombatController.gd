extends Node

signal combat_started
signal combat_finished

@onready var hero: Node = $"../Hero"
@onready var enemy: Node = $"../Enemy"
@onready var particles: Node = $"../ParticleManager"

var combat_active := false
var _game_manager: Node
var _inventory_manager: Node
var _hero_hit_connected := false
var _enemy_hit_connected := false

func _ready():
	_game_manager = get_node_or_null("/root/GameManager")
	_inventory_manager = get_node_or_null("/root/InventoryManager")
	
	# Conectar señales de muerte
	if hero and hero.has_signal("died") and not hero.is_connected("died", Callable(self, "_on_hero_died")):
		hero.connect("died", Callable(self, "_on_hero_died"))
	if enemy and enemy.has_signal("died") and not enemy.is_connected("died", Callable(self, "_on_enemy_died")):
		enemy.connect("died", Callable(self, "_on_enemy_died"))
	
	# Conectar señales de hit frame (nuevo sistema)
	_connect_hit_frame_signals()

func _connect_hit_frame_signals():
	if hero and hero.has_signal("hit_frame_reached") and not _hero_hit_connected:
		if not hero.is_connected("hit_frame_reached", Callable(self, "_on_hero_hit_frame")):
			hero.connect("hit_frame_reached", Callable(self, "_on_hero_hit_frame"))
			_hero_hit_connected = true
	
	if enemy and enemy.has_signal("hit_frame_reached") and not _enemy_hit_connected:
		if not enemy.is_connected("hit_frame_reached", Callable(self, "_on_enemy_hit_frame")):
			enemy.connect("hit_frame_reached", Callable(self, "_on_enemy_hit_frame"))
			_enemy_hit_connected = true

func start_combat():
	if combat_active:
		return
	combat_active = true
	
	if hero and hero.has_method("prepare_for_combat"):
		hero.prepare_for_combat()
	if enemy and enemy.has_method("prepare_for_combat"):
		enemy.prepare_for_combat()
	_connect_hit_frame_signals()
	emit_signal("combat_started")

func stop_combat():
	if not combat_active:
		return
	combat_active = false
	if hero:
		hero.is_attacking = false
	if enemy:
		enemy.is_attacking = false
	emit_signal("combat_finished")

func _process(_delta: float):
	if not combat_active or hero == null or enemy == null:
		return
	if not hero.alive or not enemy.alive:
		stop_combat()
		return
	
	var particle_buffer: Array = particles.particles if particles else []
	hero.attack(enemy, particle_buffer)
	hero.pulse(enemy, particle_buffer)
	enemy.attack(hero, particle_buffer)
	enemy.pulse(hero, particle_buffer)
	
	if not hero.alive or not enemy.alive:
		stop_combat()

func _on_hero_hit_frame():
	"""Ejecuta el ataque del heroe cuando alcanza el hit frame de la animacion"""
	if not combat_active or hero == null or enemy == null:
		return
	if not hero.alive or not enemy.alive:
		return
	var particle_buffer: Array = particles.particles if particles else []
	_execute_hero_attack(particle_buffer)

func _on_enemy_hit_frame():
	"""Ejecuta el ataque del enemigo cuando alcanza el hit frame de la animacion"""
	if not combat_active or hero == null or enemy == null:
		return
	if not hero.alive or not enemy.alive:
		return
	var particle_buffer: Array = particles.particles if particles else []
	_execute_enemy_attack(particle_buffer)

func _execute_hero_attack(particle_buffer: Array):
	"""Ejecuta un ataque del heroe y aplica dano"""
	var damage: float = hero.dmg
	var crit: bool = randf() < hero.crit_p
	if crit:
		damage *= hero.crit_m
		for i in range(12):
			particle_buffer.append(hero._create_spark_particle(enemy.position))
	
	# Reproducir sonido de ataque
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		var hit_sfx = load("res://art/sounds/atk_sword_flesh_hit_01.wav")
		am.play_sfx(hit_sfx, -20.0)
	
	enemy.take_damage(int(damage))
	enemy._spawn_floating_number(int(damage), crit)

func _execute_enemy_attack(particle_buffer: Array):
	"""Ejecuta un ataque del enemigo y aplica dano"""
	var damage: float = enemy.dmg
	var crit: bool = randf() < enemy.crit_p
	if crit:
		damage *= enemy.crit_m
		for i in range(12):
			particle_buffer.append(enemy._create_spark_particle(hero.position))
	
	hero.take_damage(int(damage))
	hero._spawn_floating_number(int(damage), crit)

func _on_hero_died(_drops := []):
	stop_combat()
	if _game_manager and _game_manager.has_method("register_hero_death"):
		_game_manager.register_hero_death()

func _on_enemy_died(drops):
	stop_combat()
	if drops is Array and drops.size() > 0 and _inventory_manager and _inventory_manager.has_method("add_drops"):
		_inventory_manager.add_drops(drops)
	if _game_manager:
		if enemy and enemy.is_boss and _game_manager.has_method("register_boss_defeat"):
			_game_manager.register_boss_defeat()
		elif _game_manager.has_method("register_enemy_defeat"):
			_game_manager.register_enemy_defeat(enemy.level)
	if get_parent().has_method("advance_enemy"):
		get_parent().advance_enemy()
