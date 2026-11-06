extends Node
## 🧪 Flujo real de arranque (solo desarrollo): StartScreen → pulsar JUGAR → Main.
## Comprueba que la partida cargada (sala, muertes, récord) sobrevive a start_run().

func _ready() -> void:
	var start: Node = load("res://scenes/UI/StartScreen.tscn").instantiate()
	add_child(start)
	await get_tree().create_timer(1.5).timeout
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		print("[StartFlow] antes de JUGAR: sala=%d muertes=%d récord=%d" % [gm.current_enemy_level, gm.death_count, gm.best_enemy_level])
	start._on_start_button_pressed()
	await get_tree().create_timer(2.5).timeout
	if gm:
		print("[StartFlow] en Main: sala=%d muertes=%d récord=%d" % [gm.current_enemy_level, gm.death_count, gm.best_enemy_level])
