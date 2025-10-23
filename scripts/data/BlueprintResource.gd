extends Resource

## High level crafting recipe definition consumed by the UI and DataManager.
class_name BlueprintResource

@export var blueprint_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_file("*.png", "*.svg", "*.webp", "*.tres") var icon_path: String = ""
@export var icon: Texture2D
@export var result_item: StringName = &""
@export var min_score: float = 0.0
@export var materials: Dictionary = {}
@export var trial_sequence: Array = []
@export var tags: PackedStringArray = []

var _icon_cache: Texture2D

func get_material_quantity(material_id: StringName) -> int:
    return int(materials.get(material_id, 0))

func has_trials() -> bool:
    return not trial_sequence.is_empty()

func get_icon() -> Texture2D:
    if icon:
        return icon
    if _icon_cache:
        return _icon_cache
    if icon_path == "":
        return null
    if ResourceLoader.exists(icon_path, "Texture2D"):
        var loaded_icon = ResourceLoader.load(icon_path)
        if loaded_icon is Texture2D:
            _icon_cache = loaded_icon
            return _icon_cache
        push_warning("BlueprintResource %s icon at %s is not a Texture2D" % [blueprint_id, icon_path])
    else:
        push_warning("BlueprintResource %s icon path missing: %s" % [blueprint_id, icon_path])
    return null
