extends Node

signal combat_started
signal combat_finished

@onready var hero: Node = $"../Hero"
@onready var enemy: Node = $"../Enemy"
@onready var particles: Node = $"../ParticleManager"

var combat_active := false
var _game_manager: Node
var _inventory_manager: Node

func _ready():
        _game_manager = get_node_or_null("/root/GameManager")
        _inventory_manager = get_node_or_null("/root/InventoryManager")
        if hero and hero.has_signal("died") and not hero.is_connected("died", Callable(self, "_on_hero_died")):
                hero.connect("died", Callable(self, "_on_hero_died"))
        if enemy and enemy.has_signal("died") and not enemy.is_connected("died", Callable(self, "_on_enemy_died")):
                enemy.connect("died", Callable(self, "_on_enemy_died"))

func start_combat():
        if combat_active:
                return
        combat_active = true
        if hero and hero.has_method("prepare_for_combat"):
                hero.prepare_for_combat()
        if enemy and enemy.has_method("prepare_for_combat"):
                enemy.prepare_for_combat()
        emit_signal("combat_started")

func stop_combat():
        if not combat_active:
                return
        combat_active = false
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
