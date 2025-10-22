extends CharacterBody2D

var max_hp := 100
var hp := 100

func _ready():
	hp = max_hp

func take_damage(amount:int):
	hp -= amount
	if hp <= 0:
		hp = 0
		get_node_or_null("/root/GameManager").respawn_hero()
