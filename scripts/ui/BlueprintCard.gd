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
		name_label.text = _blueprint_name()
		
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

## Nombre del plano en el idioma del jugador.
func _blueprint_name() -> String:
	return tr(blueprint_data.display_name) if blueprint_data.display_name != "" else str(blueprint_id)


## Tooltip con descripción, estadísticas y materiales, todo en el idioma del jugador (los nombres de
## estadística son los de la pantalla de resultado y los de material, los de sus MaterialResource).
func _update_tooltip() -> void:
	if not blueprint_data:
		return

	var text = "[b]%s[/b]\n" % _blueprint_name()

	if not is_unlocked:
		text += "[color=gray]%s[/color]\n\n" % tr("Bloqueado")

	if blueprint_data.description != "":
		text += "%s\n\n" % tr(blueprint_data.description)

	# Estadísticas
	if item_resource:
		text += "[b]%s[/b]\n" % tr("Estadísticas base:")
		var ranges := [
			["Daño", item_resource.base_damage_min, item_resource.base_damage_max],
			["Armadura", item_resource.base_armor_min, item_resource.base_armor_max],
			["Vida", item_resource.base_hp_min, item_resource.base_hp_max],
			["Fuerza", item_resource.base_str_min, item_resource.base_str_max],
			["Agilidad", item_resource.base_agi_min, item_resource.base_agi_max],
			["Intelecto", item_resource.base_int_min, item_resource.base_int_max],
		]
		for r in ranges:
			if r[2] > 0:
				text += "- %s: %d - %d\n" % [tr(r[0]), r[1], r[2]]
		text += "\n"

	# Materiales
	if not blueprint_data.materials.is_empty():
		text += "[b]%s[/b]\n" % tr("Requisitos:")
		for mat_id in blueprint_data.materials:
			var qty = blueprint_data.materials[mat_id]
			text += "- %s: x%d\n" % [_material_name(String(mat_id)), qty]

	tooltip_text = text


## Nombre de un material en el idioma del jugador (el de su MaterialResource).
func _material_name(mat_id: String) -> String:
	var path := "res://data/materials/%s.tres" % mat_id
	if ResourceLoader.exists(path):
		var res = load(path)
		if res and res.display_name != "":
			return tr(res.display_name)
	return mat_id.capitalize()

# Godot 4 permite personalizar el tooltip si el texto tiene formato BBCode?
# En realidad, ScrollContainer y otros nodos usan el tooltip estándar. 
# Si queremos algo más visual, podemos implementar _make_custom_tooltip
