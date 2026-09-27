extends PanelContainer

# Request Slot Script
# Tarjeta de un pedido en la cola: icono del plano, nombre, materiales (en rojo si faltan),
# recompensa en oro y etiqueta "GRATIS". Da feedback al pulsar y una sacudida si no se puede aceptar.

signal blueprint_clicked(slot_index: int)

const MATERIAL_ICON_SCENE := preload("res://scenes/UI/MaterialIcon.tscn")
const COLOR_OK := Color(0.93, 0.88, 0.8)
const COLOR_MISSING := Color(1.0, 0.42, 0.36)

var slot_index: int = -1
## false para tarjetas que ya estaban en la cola (al reconstruirla no deben parpadear)
var animate_in: bool = true
var _materials: Dictionary = {}
var _press_tween: Tween
var _inventory: Node

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var materials_container: HBoxContainer = %MaterialsContainer
@onready var reward_label: Label = %RewardLabel
@onready var free_tag: Label = %FreeTag
@onready var client_label: Label = %ClientLabel


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)
	_inventory = get_node_or_null("/root/InventoryManager")
	if _inventory and _inventory.has_signal("inventory_changed"):
		_inventory.inventory_changed.connect(func(_inv): _refresh_material_colors())
	# Entrada suave al aparecer (solo pedidos nuevos)
	if animate_in:
		modulate.a = 0.0
		scale = Vector2(0.9, 0.9)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.25)
		tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_gui_input(event: InputEvent) -> void:
	# Solo ratón: en móvil el toque llega también como clic emulado (emulate_mouse_from_touch),
	# y atender además InputEventScreenTouch aceptaría el pedido dos veces
	var pressed: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if pressed and slot_index >= 0 and not is_queued_for_deletion():
		_press_feedback()
		emit_signal("blueprint_clicked", slot_index)
		print("RequestSlot: Clicked slot %d" % slot_index)


## Configura la tarjeta con el diccionario del pedido (blueprint, gold_reward, client_name).
func set_request(request: Dictionary) -> void:
	set_blueprint(request.get("blueprint"))
	var reward := int(request.get("gold_reward", 0))
	reward_label.text = str(reward) if reward > 0 else "—"
	var client := String(request.get("client_name", ""))
	client_label.text = client
	client_label.visible = client != ""
	var rm := get_node_or_null("/root/RequestsManager")
	var free: bool = rm != null and rm.has_method("get_free_requests_remaining") and rm.get_free_requests_remaining() > 0
	free_tag.visible = free
	_refresh_material_colors()


func set_blueprint(blueprint: BlueprintResource) -> void:
	if blueprint == null:
		set_blueprint_name("(unknown)")
		set_icon(null)
		set_materials({})
		return

	set_blueprint_name(blueprint.display_name if blueprint.display_name != "" else String(blueprint.blueprint_id))
	set_icon(blueprint.get_blueprint_icon())  # Usar icono del blueprint para cola de pedidos
	set_materials(blueprint.materials)

func set_blueprint_name(blueprint_name: String) -> void:
	name_label.text = blueprint_name

func set_icon(texture: Texture2D) -> void:
	icon_rect.texture = texture

func set_materials(materials) -> void:
	for child in materials_container.get_children():
		child.queue_free()
	_materials = {}
	if typeof(materials) == TYPE_DICTIONARY:
		for mat_id in materials.keys():
			_materials[StringName(str(mat_id))] = int(materials[mat_id])
			_add_material_row(str(mat_id), materials[mat_id])
	elif typeof(materials) == TYPE_ARRAY:
		for entry in materials:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("id") and entry.has("qty"):
				_materials[StringName(str(entry["id"]))] = int(entry["qty"])
				_add_material_row(str(entry["id"]), entry["qty"])
	_refresh_material_colors()


func _add_material_row(material_name: String, quantity) -> void:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 1)
	container.set_meta("material_id", StringName(material_name))

	var icon_node = MATERIAL_ICON_SCENE.instantiate()
	icon_node.custom_minimum_size = Vector2(34, 34)
	icon_node.set("material_name", material_name)
	container.add_child(icon_node)

	var qty_label := Label.new()
	qty_label.name = "Qty"
	qty_label.text = "x%s" % str(quantity)
	qty_label.add_theme_font_size_override("font_size", 20)
	qty_label.add_theme_color_override("font_color", COLOR_OK)
	qty_label.add_theme_constant_override("outline_size", 4)
	container.add_child(qty_label)

	materials_container.add_child(container)


## Colorea en rojo los materiales que no alcanzan (los pedidos gratis no consumen nada).
func _refresh_material_colors() -> void:
	if _inventory == null or not is_inside_tree():
		return
	var free := free_tag != null and free_tag.visible
	for row in materials_container.get_children():
		if not row.has_meta("material_id"):
			continue
		var mat_id: StringName = row.get_meta("material_id")
		var need: int = _materials.get(mat_id, 0)
		var have: int = _inventory.get_quantity(mat_id)
		var qty: Label = row.get_node_or_null("Qty")
		if qty:
			var ok := free or have >= need
			qty.add_theme_color_override("font_color", COLOR_OK if ok else COLOR_MISSING)


func _press_feedback() -> void:
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2(0.93, 0.93), 0.06)
	_press_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sacudida + destello rojo cuando el pedido no se puede aceptar (faltan materiales).
func reject_feedback() -> void:
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
	var base_x := position.x
	_press_tween = create_tween()
	_press_tween.tween_property(self, "modulate", Color(1.5, 0.6, 0.55), 0.06)
	for i in 4:
		_press_tween.tween_property(self, "position:x", base_x + (12.0 if i % 2 == 0 else -12.0), 0.045)
	_press_tween.tween_property(self, "position:x", base_x, 0.05)
	_press_tween.tween_property(self, "modulate", Color.WHITE, 0.25)
