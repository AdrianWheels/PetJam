extends AnimatedSprite2D
class_name AnimatedSteelBarBackground

## Background animado de barra de acero usando frames individuales (solo 21 frames)
## Método eficiente con pocos frames para un loop suave

const FRAMES_PATH := "res://art/placeholders/steel_bar_bg_frames/"
const FRAME_COUNT := 21  # Solo 21 frames a 4 FPS
const FPS := 4.0

var _sprite_frames: SpriteFrames

func _ready() -> void:
	_load_animation_frames()
	play("steel_bar_loop")

func _load_animation_frames() -> void:
	_sprite_frames = SpriteFrames.new()
	_sprite_frames.add_animation("steel_bar_loop")
	_sprite_frames.set_animation_loop("steel_bar_loop", true)
	_sprite_frames.set_animation_speed("steel_bar_loop", FPS)
	
	var loaded_count := 0
	
	# Cargar todos los frames (solo 21, muy manejable)
	for i in range(1, FRAME_COUNT + 1):
		var frame_path := FRAMES_PATH + "frame_%04d.png" % i
		var texture := load(frame_path) as Texture2D
		if texture:
			_sprite_frames.add_frame("steel_bar_loop", texture)
			loaded_count += 1
		else:
			push_error("AnimatedSteelBarBackground: No se pudo cargar frame: %s" % frame_path)
	
	sprite_frames = _sprite_frames
	print("AnimatedSteelBarBackground: Cargados %d frames @ %.1f FPS" % [loaded_count, FPS])
