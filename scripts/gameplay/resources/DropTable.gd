extends Resource
class_name DropTable

@export var entries: Array[DropEntry] = []

func roll_drops(rng: RandomNumberGenerator = null) -> Array[Dictionary]:
        var drops: Array[Dictionary] = []
        if entries.is_empty():
                return drops
        var generator := rng
        if generator == null:
                generator = RandomNumberGenerator.new()
                generator.randomize()
        var aggregate: Dictionary = {}
        for entry in entries:
                if entry == null:
                        continue
                var result := entry.roll(generator)
                if result.is_empty():
                        continue
                var item_id: StringName = result["item_id"]
                var quantity: int = int(result["quantity"])
                aggregate[item_id] = aggregate.get(item_id, 0) + quantity
        for key in aggregate.keys():
                drops.append({
                        "item_id": key,
                        "quantity": aggregate[key]
                })
        return drops
