extends AnimatedSprite2D
class_name AnimatedForgeBackground

## Script para animar el fondo de forja desde secuencia de frames PNG
## Carga automáticamente los frames de art/placeholders/forge_bg_frames/

const FRAMES_PATH := "res://art/placeholders/forge_bg_frames/"
const FRAME_COUNT := 121
const FPS := 24.0

## Cada cuántos frames cargar (1 = todos, 2 = mitad, 3 = un tercio, etc.)
@export_range(1, 10, 1) var frame_skip: int = 2

var _sprite_frames: SpriteFrames

func _ready() -> void:
	_load_animation_frames()
	play("forge_loop")

func _load_animation_frames() -> void:
	_sprite_frames = SpriteFrames.new()
	_sprite_frames.add_animation("forge_loop")
	_sprite_frames.set_animation_loop("forge_loop", true)
	
	# Ajustar FPS proporcionalmente al skip
	var adjusted_fps := FPS / float(frame_skip)
	_sprite_frames.set_animation_speed("forge_loop", adjusted_fps)
	
	var loaded_count := 0
	
	# Cargar frames saltando según frame_skip
	for i in range(1, FRAME_COUNT + 1, frame_skip):
		var frame_path := FRAMES_PATH + "frame_%03d.png" % i
		var texture := load(frame_path) as Texture2D
		if texture:
			_sprite_frames.add_frame("forge_loop", texture)
			loaded_count += 1
		else:
			push_error("No se pudo cargar frame: %s" % frame_path)
	
	sprite_frames = _sprite_frames
	print("AnimatedForgeBackground: Cargados %d/%d frames (skip=%d) a %.1f FPS" % [loaded_count, FRAME_COUNT, frame_skip, adjusted_fps])
