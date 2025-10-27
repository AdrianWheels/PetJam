extends Control

@export var material_name: String = "iron":
	set = set_material_name

@onready var _texture_rect: TextureRect = $TextureRect

func _ready() -> void:
	_update_texture()

func set_material_name(value: String) -> void:
	material_name = value
	if is_inside_tree():
		_update_texture()

func _update_texture() -> void:
	if _texture_rect == null:
		return
	
	# Try loading from MaterialResource first (primary method)
	var material_resource_path = "res://data/materials/%s.tres" % material_name
	if ResourceLoader.exists(material_resource_path):
		var material_res = load(material_resource_path)
		if material_res and "icon" in material_res and material_res.icon:
			_texture_rect.texture = material_res.icon
			return
	
	# Fallback to placeholder images
	var placeholder_path = "res://art/placeholders/forge/material_%s.png" % material_name
	if ResourceLoader.exists(placeholder_path):
		_texture_rect.texture = load(placeholder_path)
		return
	
	# Final fallback to default icon
	var default_path = "res://art/placeholders/forge/material_default.png"
	if ResourceLoader.exists(default_path):
		_texture_rect.texture = load(default_path)
	else:
		# Ultimate fallback to engine icon
		_texture_rect.texture = load("res://icon.svg")