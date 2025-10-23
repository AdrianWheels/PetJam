extends Resource

## Defines a single trial within a blueprint's crafting flow.
class_name TrialResource

@export var trial_id: StringName = &""
@export var display_name: String = ""
@export var minigame_id: StringName = &""
@export var minigame_scene: PackedScene
@export var min_score: float = 0.0
@export var config: TrialConfig
@export var notes: String = ""

func get_effective_minigame() -> StringName:
    if config and config.minigame_id != StringName():
        return config.minigame_id
    return minigame_id
