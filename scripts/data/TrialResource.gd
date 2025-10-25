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
@export var background: Texture2D

func get_effective_minigame() -> StringName:
    if config and config.minigame_id != StringName():
        return config.minigame_id
    return minigame_id

## Prepara el config sincronizando parámetros si es necesario.
func get_prepared_config() -> TrialConfig:
    if config and config.has_method("prepare"):
        config.prepare()
    return config
