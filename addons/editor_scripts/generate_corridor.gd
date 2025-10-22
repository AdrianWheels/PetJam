@tool
extends EditorScript

func _run():
	var scene_path: String = "res://scenes/Corridor.tscn"
	var room_scene_res: Resource = ResourceLoader.load("res://scenes/Room.tscn")
	if room_scene_res == null:
		print("Room scene not found or failed to load")
		return

	var room_packed := room_scene_res as PackedScene
	if room_packed == null:
		print("Room.tscn is not a PackedScene")
		return

	# Create a temporary parent (Node) to assemble the corridor
	var corridor_parent: Node = Node.new()

	for i in range(9):
		var room_inst: Node = room_packed.instantiate()
		room_inst.name = "Room_%02d" % [i + 1]
		if i == 8:
			room_inst.set_meta("is_boss", true)
		corridor_parent.add_child(room_inst)

	# Save the assembled scene as a PackedScene
	var packed_scene: PackedScene = PackedScene.new()
	var ok := packed_scene.pack(corridor_parent)
	if ok != OK:
		print("Failed to pack corridor: ", ok)
		return

	var save_err := ResourceSaver.save(packed_scene, scene_path)
	if save_err != OK:
		print("Failed to save packed corridor: ", save_err)
	else:
		print("Generated 9 rooms in Corridor.tscn")
