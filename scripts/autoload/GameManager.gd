extends Node

signal room_entered(room_idx)
signal hero_died
signal game_over

var current_room: int = 1
var total_rooms: int = 9
var inventory := {}
var blueprints_unlocked := {}

func _ready():
	# Autoload singleton: Game state and run control
	print("GameManager: Ready")

func start_run():
	current_room = 1
	print("GameManager: Starting new run at room 1")
	emit_signal("room_entered", current_room)

func advance_room():
	current_room += 1
	print("GameManager: Advanced to room %d" % current_room)
	if current_room > total_rooms:
		print("GameManager: Game over - all rooms cleared")
		emit_signal("game_over")
	else:
		emit_signal("room_entered", current_room)

func respawn_hero():
	# The hero should be moved to room 1 by the scene logic; this just emits a signal
	print("GameManager: Hero died, respawning")
	emit_signal("hero_died")
