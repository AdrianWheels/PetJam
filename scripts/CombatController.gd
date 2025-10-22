extends Node

@onready var hero: Node = $"../Hero"
@onready var enemy: Node = $"../Enemy"
@onready var particles: Node = $"../ParticleManager"

var combat_active = false

func start_combat():
	combat_active = true

func _process(_delta: float):
	if combat_active and hero.alive and enemy.alive:
		hero.attack(enemy, particles.particles)
		hero.pulse(enemy, particles.particles)
		enemy.attack(hero, particles.particles)
		enemy.pulse(hero, particles.particles)
		if not hero.alive:
			combat_active = false
			get_tree().create_timer(1.0).connect("timeout", Callable(self, "_on_hero_died"))
		if not enemy.alive:
			combat_active = false
			get_parent().advance_enemy()

func _on_hero_died():
	if hero:
		hero.respawn()
		get_parent().reset_run()