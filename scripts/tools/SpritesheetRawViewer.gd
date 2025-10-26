extends Control

@onready var sprite: Sprite2D = $VBoxContainer/CenterContainer/Sprite2D
@onready var info_label: Label = $VBoxContainer/InfoLabel
@onready var prev_button: Button = $VBoxContainer/HBoxContainer/PrevButton
@onready var next_button: Button = $VBoxContainer/HBoxContainer/NextButton
@onready var play_button: Button = $VBoxContainer/HBoxContainer/PlayButton

var current_frame: int = 0
var total_frames: int = 63
var is_playing: bool = false
var animation_timer: float = 0.0
var fps: float = 12.0

func _ready() -> void:
	_update_info()
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	play_button.pressed.connect(_on_play_pressed)
	
	print("🎬 Spritesheet Raw Viewer")
	print("   LEFT/RIGHT: Navigate frames")
	print("   SPACE: Play/Pause")
	print("   Total frames: %d" % total_frames)

func _process(delta: float) -> void:
	if is_playing:
		animation_timer += delta
		var frame_duration = 1.0 / fps
		
		if animation_timer >= frame_duration:
			animation_timer -= frame_duration
			current_frame = (current_frame + 1) % total_frames
			sprite.frame = current_frame
			_update_info()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				_on_prev_pressed()
			KEY_RIGHT:
				_on_next_pressed()
			KEY_SPACE:
				_on_play_pressed()

func _on_prev_pressed() -> void:
	is_playing = false
	current_frame = (current_frame - 1 + total_frames) % total_frames
	sprite.frame = current_frame
	_update_info()
	_update_play_button()

func _on_next_pressed() -> void:
	is_playing = false
	current_frame = (current_frame + 1) % total_frames
	sprite.frame = current_frame
	_update_info()
	_update_play_button()

func _on_play_pressed() -> void:
	is_playing = !is_playing
	_update_play_button()

func _update_info() -> void:
	if info_label:
		info_label.text = "Frame: %d / %d" % [current_frame, total_frames - 1]

func _update_play_button() -> void:
	if play_button:
		play_button.text = "⏸ Pause (SPACE)" if is_playing else "▶ Play (SPACE)"
