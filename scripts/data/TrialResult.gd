extends Resource

## Outcome for a single trial execution.
class_name TrialResult

@export var trial_id: StringName = &""
@export var blueprint_id: StringName = &""
@export var score: float = 0.0
@export var max_score: float = 100.0
@export var success: bool = false
@export var duration_ms: int = 0
@export var details: Dictionary = {}

func get_score_ratio() -> float:
    if max_score <= 0.0:
        return 0.0
    return clamp(score / max_score, 0.0, 1.0)
