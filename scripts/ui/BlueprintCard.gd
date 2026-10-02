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

const MATERIAL_ICON_SCENE := preload("res://scenes/UI/MaterialIcon.tscn")

signal forge_requested(bp_id: StringName, rank: int)

var max_rank: int = 0
var selected_rank: int = 1
var _rank_label: Label
var _cost_box: HFlowContainer
## Receta del rango elegido (la que cobra «Forjar»): lo que enseñan la línea de coste y el tooltip
var shown_recipe: Dictionary = {}
var _forge_btn: Button
var _shake_tween: Tween
var _rest_x: float = 0.0


func set_blueprint_data(bp_id: StringName, blueprint: BlueprintResource, unlocked: bool, unlocked_rank: int = 1) -> void:
	blueprint_id = bp_id
	blueprint_data = blueprint
	is_unlocked = unlocked
	max_rank = unlocked_rank if unlocked else 0
	selected_rank = maxi(1, max_rank)

	# Obtener ItemResource para las estadísticas
	var dm = get_node_or_null("/root/DataManager")
	if dm and blueprint.result_item != &"":
		item_resource = dm.get_item_resource(blueprint.result_item)

	# Configurar Visuales
	if blueprint_data:
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

	_build_forge_row()
	_refresh_rank()  # pone el nombre, con numeral desde el rango II
	_update_tooltip()


func _build_forge_row() -> void:
	if _forge_btn or max_rank < 1:
		return
	_cost_box = HFlowContainer.new()
	_cost_box.alignment = FlowContainer.ALIGNMENT_CENTER
	_cost_box.add_theme_constant_override("h_separation", 6)
	_cost_box.add_theme_constant_override("v_separation", 0)
	_cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$VBox.add_child(_cost_box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev := Button.new()
	prev.text = "◀"
	prev.pressed.connect(func(): selected_rank = maxi(1, selected_rank - 1); _refresh_rank())
	_rank_label = Label.new()
	_rank_label.custom_minimum_size = Vector2(36, 0)
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := Button.new()
	next.text = "▶"
	next.pressed.connect(func(): selected_rank = mini(max_rank, selected_rank + 1); _refresh_rank())
	_forge_btn = Button.new()
	_forge_btn.text = tr("Forjar")
	_forge_btn.pressed.connect(func(): forge_requested.emit(blueprint_id, selected_rank))
	for n in [prev, _rank_label, next, _forge_btn]:
		row.add_child(n)
	$VBox.add_child(row)


func _refresh_rank() -> void:
	if _rank_label:
		_rank_label.text = Biomes.roman(selected_rank)
	name_label.text = (_blueprint_name() if blueprint_data else str(blueprint_id)) + Ranks.suffix(selected_rank)
	_refresh_cost()
	_update_tooltip()


## Receta del rango elegido (materiales del plano × rango más los del bioma de su nivel).
func _rank_recipe() -> Dictionary:
	if blueprint_data == null or max_rank < 1:
		return {}
	var dm = get_node_or_null("/root/DataManager")
	var tier: StringName = dm.blueprint_tier(blueprint_id) if dm else Ranks.TIER_BASIC
	return Ranks.recipe(blueprint_data.materials, tier, selected_rank)


## Línea de coste de la tarjeta: icono de material y cantidad, como en los pedidos.
func _refresh_cost() -> void:
	shown_recipe = _rank_recipe()
	if _cost_box == null:
		return
	for child in _cost_box.get_children():
		_cost_box.remove_child(child)
		child.queue_free()
	for mat_id in shown_recipe:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 1)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_node = MATERIAL_ICON_SCENE.instantiate()
		icon_node.custom_minimum_size = Vector2(22, 22)
		icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_node.set("material_name", String(mat_id))
		item.add_child(icon_node)
		var qty := Label.new()
		qty.name = "Qty"
		qty.text = "x%d" % int(shown_recipe[mat_id])
		qty.add_theme_font_size_override("font_size", 14)
		item.add_child(qty)
		_cost_box.add_child(item)


## Sacudida cuando el encargo no se puede hacer. Si ya hay una en marcha se corta y la tarjeta
## vuelve a su x de reposo antes de empezar otra, para que dos pulsaciones no se pisen.
func reject_feedback() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		position.x = _rest_x
	else:
		_rest_x = position.x
	_shake_tween = create_tween()
	for i in 4:
		_shake_tween.tween_property(self, "position:x", _rest_x + (8.0 if i % 2 == 0 else -8.0), 0.045)
	_shake_tween.tween_property(self, "position:x", _rest_x, 0.05)


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
			["Daño", _scaled("damage", item_resource.base_damage_min), _scaled("damage", item_resource.base_damage_max)],
			["Armadura", _scaled("armor", item_resource.base_armor_min), _scaled("armor", item_resource.base_armor_max)],
			["Vida", _scaled("hp", item_resource.base_hp_min), _scaled("hp", item_resource.base_hp_max)],
			["Fuerza", _scaled("str", item_resource.base_str_min), _scaled("str", item_resource.base_str_max)],
			["Agilidad", item_resource.base_agi_min, item_resource.base_agi_max],
			["Intelecto", item_resource.base_int_min, item_resource.base_int_max],
		]
		for r in ranges:
			if r[2] > 0:
				text += "- %s: %d - %d\n" % [tr(r[0]), r[1], r[2]]
		text += "\n"

	# Materiales
	# Plano desbloqueado: la receta del rango elegido; bloqueado, la base del plano
	var recipe: Dictionary = shown_recipe if max_rank >= 1 else blueprint_data.materials
	if not recipe.is_empty():
		text += "[b]%s[/b]\n" % tr("Requisitos:")
		for mat_id in recipe:
			var qty = recipe[mat_id]
			text += "- %s: x%d\n" % [_material_name(String(mat_id)), qty]

	tooltip_text = text


## Una estadística base con el rango elegido aplicado (Ranks.scale_stats).
func _scaled(key: String, value: int) -> int:
	return int(Ranks.scale_stats({key: value}, selected_rank)[key])


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
