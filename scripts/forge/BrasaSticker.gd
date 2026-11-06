extends Node2D

## Brasa en el taller. Con rejilla animada: reposo en bucle, martillo o costura mientras dura la fabricación y la
## celebración al acabar. Sin ella, las cuatro poses fijas en el mismo orden.
const FPS := [8.0, 10.0, 8.0, 10.0]  # reposo, martillo, costura, celebración
var _sprite: Sprite2D
var _celebrate := 0.0
var _row := 0
var _t := 0.0

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
	_t += delta
	if _celebrate > 0:
		_celebrate -= delta
		if _celebrate <= 0:
			_show(0)
	if _sprite.get_meta("sticker_animated", false):
		_sprite.frame = _row * StickerSprites.ANIM_COLS + int(_t * FPS[_row]) % StickerSprites.ANIM_COLS

func _show(row: int) -> void:
	_row = row
	_t = 0.0
	if not _sprite.get_meta("sticker_animated", false):
		_sprite.frame = row

func _on_started(_task_id, config) -> void:
	_celebrate = 0
	_show(2 if "sew" in String(config.minigame_id).to_lower() else 1)

func _on_completed(_slot, _item) -> void:
	_show(3)
	_celebrate = 1.2
