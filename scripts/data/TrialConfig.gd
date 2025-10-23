extends Resource

## Generic configuration payload for a single trial/minigame run.
class_name TrialConfig

@export var minigame_id: StringName = &""
@export var trial_id: StringName = &""
@export var blueprint_id: StringName = &""
@export var minigame_scene: PackedScene
@export var max_score: float = 100.0
@export var parameters: Dictionary = {}

func get_parameter(key: StringName, default_value: Variant = null) -> Variant:
    return parameters.get(key, default_value)

func duplicate_config() -> TrialConfig:
    var dup: TrialConfig = duplicate(true)
    dup.parameters = parameters.duplicate(true)
    return dup
