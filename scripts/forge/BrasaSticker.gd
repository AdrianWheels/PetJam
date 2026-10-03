extends Node2D

var _sprite: Sprite2D
var _celebrate := 0.0

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	StickerSprites.apply(_sprite, "brasa", 580)
	_sprite.position = Vector2(-290, -540)
	var crafting := get_node_or_null("/root/CraftingManager")
	if crafting:
		crafting.task_started.connect(_on_started)
		crafting.task_completed.connect(_on_completed)

func _process(delta: float) -> void:
	if _celebrate > 0:
		_celebrate -= delta
		if _celebrate <= 0:
			_sprite.frame = 0

func _on_started(_task_id, config) -> void:
	_celebrate = 0
	_sprite.frame = 2 if "sew" in String(config.minigame_id).to_lower() else 1

func _on_completed(_slot, _item) -> void:
	_sprite.frame = 3
	_celebrate = 1.2
