# res://scripts/ui/BlueprintCard.gd
extends PanelContainer

## Tarjeta cuadrada para mostrar un blueprint en la biblioteca

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var lock_overlay: ColorRect = %LockOverlay

var blueprint_id: StringName
var blueprint_data: BlueprintResource
var is_unlocked: bool = false
var item_resource: ItemResource

func set_blueprint_data(bp_id: StringName, blueprint: BlueprintResource, unlocked: bool) -> void:
	blueprint_id = bp_id
	blueprint_data = blueprint
	is_unlocked = unlocked
	
	# Obtener ItemResource para las estadísticas
	var dm = get_node_or_null("/root/DataManager")
	if dm and blueprint.result_item != &"":
		item_resource = dm.get_item_resource(blueprint.result_item)
	
	# Configurar Visuales
	if blueprint_data:
		name_label.text = blueprint_data.display_name if blueprint_data.display_name != "" else str(bp_id)
		
		var icon_tex = blueprint_data.get_icon()
		if icon_tex:
			icon_rect.texture = icon_tex
	
	# Estado de bloqueo
	if is_unlocked:
		lock_overlay.visible = false
		modulate = Color.WHITE
	else:
		lock_overlay.visible = true
		modulate = Color(0.7, 0.7, 0.7)
	
	# Configurar Tooltip
	_update_tooltip()

func _update_tooltip() -> void:
	if not blueprint_data:
		return
		
	var text = "[b]%s[/b]\n" % (blueprint_data.display_name if blueprint_data.display_name != "" else str(blueprint_id))
	
	if not is_unlocked:
		text += "[color=gray]Bloqueado[/color]\n\n"
	
	if blueprint_data.description != "":
		text += "%s\n\n" % blueprint_data.description
	
	# Estadísticas
	if item_resource:
		text += "[b]Estadísticas base:[/b]\n"
		if item_resource.base_damage_max > 0:
			text += "- Daño: %d - %d\n" % [item_resource.base_damage_min, item_resource.base_damage_max]
		if item_resource.base_armor_max > 0:
			text += "- Armadura: %d - %d\n" % [item_resource.base_armor_min, item_resource.base_armor_max]
		if item_resource.base_hp_max > 0:
			text += "- Vida: %d - %d\n" % [item_resource.base_hp_min, item_resource.base_hp_max]
		if item_resource.base_str_max > 0:
			text += "- Fuerza: %d - %d\n" % [item_resource.base_str_min, item_resource.base_str_max]
		if item_resource.base_agi_max > 0:
			text += "- Agilidad: %d - %d\n" % [item_resource.base_agi_min, item_resource.base_agi_max]
		if item_resource.base_int_max > 0:
			text += "- Inteligencia: %d - %d\n" % [item_resource.base_int_min, item_resource.base_int_max]
		text += "\n"
	
	# Materiales
	if not blueprint_data.materials.is_empty():
		text += "[b]Requisitos:[/b]\n"
		for mat_id in blueprint_data.materials:
			var qty = blueprint_data.materials[mat_id]
			text += "- %s: x%d\n" % [mat_id.capitalize(), qty]
	
	tooltip_text = text

# Godot 4 permite personalizar el tooltip si el texto tiene formato BBCode?
# En realidad, ScrollContainer y otros nodos usan el tooltip estándar. 
# Si queremos algo más visual, podemos implementar _make_custom_tooltip
