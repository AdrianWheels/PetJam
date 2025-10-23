extends Control

const MATERIAL_TEXTURES := {
    "iron": preload("res://art/placeholders/forge/material_iron.png"),
    "leather": preload("res://art/placeholders/forge/material_leather.png"),
    "cloth": preload("res://art/placeholders/forge/material_cloth.png"),
    "water": preload("res://art/placeholders/forge/material_water.png"),
    "catalyst_fire": preload("res://art/placeholders/forge/material_catalyst_fire.png"),
    "default": preload("res://art/placeholders/forge/material_default.png"),
}

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
    var texture: Texture2D = MATERIAL_TEXTURES.get(material_name, null)
    if texture == null:
        var candidate_path: String = "res://art/placeholders/forge/material_%s.png" % material_name
        if ResourceLoader.exists(candidate_path, "Texture2D"):
            var loaded: Resource = ResourceLoader.load(candidate_path)
            if loaded is Texture2D:
                texture = loaded as Texture2D
    if texture == null:
        texture = MATERIAL_TEXTURES.get("default")
    _texture_rect.texture = texture
