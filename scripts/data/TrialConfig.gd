extends Resource

## Generic configuration payload for a single trial/minigame run.
class_name TrialConfig

@export var minigame_id: StringName = &""
@export var parameters: Dictionary = {}

func get_parameter(key: StringName, default_value := null) -> Variant:
    return parameters.get(key, default_value)
