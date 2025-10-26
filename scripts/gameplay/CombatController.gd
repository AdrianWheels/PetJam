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
	"""Conecta las señales de hit_frame_reached de Hero y Enemy"""
	if hero and hero.has_signal("hit_frame_reached") and not _hero_hit_connected:
		if not hero.is_connected("hit_frame_reached", Callable(self, "_on_hero_hit_frame")):
			hero.connect("hit_frame_reached", Callable(self, "_on_hero_hit_frame"))
			_hero_hit_connected = true
			print("CombatController: Connected hero hit_frame_reached signal")
	
	if enemy and enemy.has_signal("hit_frame_reached") and not _enemy_hit_connected:
		if not enemy.is_connected("hit_frame_reached", Callable(self, "_on_enemy_hit_frame")):
			enemy.connect("hit_frame_reached", Callable(self, "_on_enemy_hit_frame"))
			_enemy_hit_connected = true
			print("CombatController: Connected enemy hit_frame_reached signal")

func start_combat():
	if combat_active:
		print("CombatController: start_combat() called but combat already active")
		return
	print("CombatController: ===== STARTING COMBAT =====")
	combat_active = true
	
	if hero and hero.has_method("prepare_for_combat"):
		hero.prepare_for_combat()
		print("CombatController: Hero prepared for combat (atk_timer=%.2f, aps=%.2f)" % [hero.atk_timer, hero.aps])
	if enemy and enemy.has_method("prepare_for_combat"):
		enemy.prepare_for_combat()
		print("CombatController: Enemy prepared for combat (atk_timer=%.2f, aps=%.2f)" % [enemy.atk_timer, enemy.aps])
	
	# Reconectar señales de hit frame en cada combate (por si cambian hero/enemy)
	_connect_hit_frame_signals()
	
	emit_signal("combat_started")

func stop_combat():
	if not combat_active:
		print("CombatController: stop_combat() called but combat not active")
		return
	print("CombatController: ===== STOPPING COMBAT =====")
	combat_active = false
	
	# CRÍTICO: Resetear is_attacking cuando termina el combate
	if hero:
		hero.is_attacking = false
		print("CombatController: Reset hero.is_attacking = false")
	if enemy:
		enemy.is_attacking = false
		print("CombatController: Reset enemy.is_attacking = false")
	
	emit_signal("combat_finished")

func _process(_delta: float):
	if not combat_active or hero == null or enemy == null:
		return
	if not hero.alive or not enemy.alive:
		print("CombatController: Combat ending - hero.alive=%s, enemy.alive=%s" % [hero.alive, enemy.alive])
		stop_combat()
		return
	
	# Sistema HÍBRIDO: mantener attack() para timing, ejecutar daño en hit_frame
	var particle_buffer: Array = particles.particles if particles else []
	hero.attack(enemy, particle_buffer)
	hero.pulse(enemy, particle_buffer)
	enemy.attack(hero, particle_buffer)
	enemy.pulse(hero, particle_buffer)
	
	if not hero.alive or not enemy.alive:
		print("CombatController: Combat ending mid-frame - hero.alive=%s, enemy.alive=%s" % [hero.alive, enemy.alive])
		stop_combat()

func _on_hero_hit_frame():
	"""Ejecuta el ataque del héroe cuando alcanza el hit frame de la animación"""
	print("CombatController: 🎯 _on_hero_hit_frame() called!")
	if not combat_active or hero == null or enemy == null:
		print("CombatController: Ignoring hero hit frame - combat_active=%s, hero=%s, enemy=%s" % [combat_active, hero != null, enemy != null])
		return
	if not hero.alive or not enemy.alive:
		print("CombatController: Ignoring hero hit frame - hero.alive=%s, enemy.alive=%s" % [hero.alive, enemy.alive])
		return
	
	# SIMPLIFICADO: El timer ya fue validado en attack() antes de lanzar la animación
	# Aquí solo ejecutamos daño/FX cuando la señal se emite
	var particle_buffer: Array = particles.particles if particles else []
	_execute_hero_attack(particle_buffer)

func _on_enemy_hit_frame():
	"""Ejecuta el ataque del enemigo cuando alcanza el hit frame de la animación"""
	print("CombatController: 🎯 _on_enemy_hit_frame() called!")
	if not combat_active or hero == null or enemy == null:
		print("CombatController: Ignoring enemy hit frame - combat_active=%s, hero=%s, enemy=%s" % [combat_active, hero != null, enemy != null])
		return
	if not hero.alive or not enemy.alive:
		print("CombatController: Ignoring enemy hit frame - hero.alive=%s, enemy.alive=%s" % [hero.alive, enemy.alive])
		return
	
	# SIMPLIFICADO: El timer ya fue validado en attack() antes de lanzar la animación
	# Aquí solo ejecutamos daño/FX cuando la señal se emite
	var particle_buffer: Array = particles.particles if particles else []
	_execute_enemy_attack(particle_buffer)

func _execute_hero_attack(particle_buffer: Array):
	"""Ejecuta un ataque del héroe y aplica daño"""
	var damage: float = hero.dmg
	var crit: bool = randf() < hero.crit_p
	if crit:
		damage *= hero.crit_m
		for i in range(12):
			particle_buffer.append(hero._create_spark_particle(enemy.position))
	
	# Reproducir sonido de ataque
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("play_sfx"):
			var hit_sfx = load("res://art/sounds/atk_sword_flesh_hit_01.wav")
			am.play_sfx(hit_sfx, -20.0, am.AudioContext.DUNGEON)
	
	# Debug: mostrar cadencia de ataque
	print("Hero: HIT FRAME ATTACK at %.2f s, dmg=%.1f, crit=%s, aps=%.2f" % [Time.get_ticks_msec()/1000.0, damage, crit, hero.aps])
	
	# Aplicar daño y mostrar floating number
	enemy.take_damage(int(damage))
	enemy._spawn_floating_number(int(damage), crit)

func _execute_enemy_attack(particle_buffer: Array):
	"""Ejecuta un ataque del enemigo y aplica daño"""
	var damage: float = enemy.dmg
	var crit: bool = randf() < enemy.crit_p
	if crit:
		damage *= enemy.crit_m
		for i in range(12):
			particle_buffer.append(enemy._create_spark_particle(hero.position))
	
	# Debug: mostrar cadencia de ataque
	print("Enemy: HIT FRAME ATTACK at %.2f s, dmg=%.1f, crit=%s, aps=%.2f" % [Time.get_ticks_msec()/1000.0, damage, crit, enemy.aps])
	
	# Aplicar daño y mostrar floating number
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
