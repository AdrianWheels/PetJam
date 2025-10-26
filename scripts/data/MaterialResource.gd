extends Resource

## Recurso de material con icono
class_name MaterialResource

@export var material_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

func get_icon() -> Texture2D:
	return icon
