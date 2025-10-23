extends Resource
class_name DropEntry

@export var item_id: StringName = StringName()
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_quantity: int = 1
@export var max_quantity: int = 1
@export_range(1, 8) var rolls: int = 1

func roll(rng: RandomNumberGenerator) -> Dictionary:
        if item_id == StringName():
                return {}
        var total: int = 0
        var attempts: int = max(1, rolls)
        for i in range(attempts):
                if rng.randf() <= chance:
                        total += rng.randi_range(min_quantity, max_quantity)
        if total <= 0:
                return {}
        return {
                "item_id": item_id,
                "quantity": total
        }
