extends Resource

## Aggregates multiple blueprint resources for easy loading.
class_name BlueprintLibrary

@export var blueprints: Array[BlueprintResource] = []

func get_blueprint_ids() -> PackedStringArray:
    var ids: PackedStringArray = []
    for bp in blueprints:
        if bp and bp.blueprint_id != StringName():
            ids.append(String(bp.blueprint_id))
    return ids
