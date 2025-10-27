extends Panel

# Referencias a labels
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/StatsSection/HPLabel
@onready var str_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/StatsSection/STRLabel
@onready var agi_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/StatsSection/AGILabel
@onready var int_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/StatsSection/INTLabel
@onready var dmg_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/StatsSection/DMGLabel

@onready var weapon_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/EquipmentSection/WeaponSlot/ItemLabel
@onready var armor_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/EquipmentSection/ArmorSlot/ItemLabel
@onready var accessory_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/EquipmentSection/AccessorySlot/ItemLabel

var hero_ref: Node = null

func _ready() -> void:
	# Buscar referencia al héroe
	await get_tree().process_frame
	_find_hero()
	
	# Conectar señales si existe GameManager
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_signal("hero_stats_changed"):
			gm.connect("hero_stats_changed", Callable(self, "_on_hero_stats_changed"))

func _process(_delta: float) -> void:
	# Actualizar stats cada frame si hay héroe
	if hero_ref and is_instance_valid(hero_ref):
		_update_stats()

func _find_hero() -> void:
	# Buscar en Corridor o Main
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var main = tree.root.get_node_or_null("Main")
	if main:
		var dungeon_area = main.get_node_or_null("DungeonArea")
		if dungeon_area:
			var corridor = dungeon_area.get_node_or_null("Corridor")
			if corridor:
				hero_ref = corridor.get_node_or_null("Hero")

func _update_stats() -> void:
	if not hero_ref or not is_instance_valid(hero_ref):
		return
	
	# Actualizar labels de stats
	if hp_label:
		hp_label.text = "HP: %d / %d" % [hero_ref.hp, hero_ref.max_hp]
	
	if str_label:
		var bonus = hero_ref.STR - hero_ref.BASE_STR
		str_label.text = "STR: %d (+%d)" % [hero_ref.STR, bonus] if bonus > 0 else "STR: %d" % hero_ref.STR
	
	if agi_label:
		var bonus = hero_ref.AGI - hero_ref.BASE_AGI
		agi_label.text = "AGI: %d (+%d)" % [hero_ref.AGI, bonus] if bonus > 0 else "AGI: %d" % hero_ref.AGI
	
	if int_label:
		var bonus = hero_ref.INT - hero_ref.BASE_INT
		int_label.text = "INT: %d (+%d)" % [hero_ref.INT, bonus] if bonus > 0 else "INT: %d" % hero_ref.INT
	
	if dmg_label:
		dmg_label.text = "DMG: %.1f" % hero_ref.dmg
	
	# Actualizar equipamiento (placeholder por ahora)
	_update_equipment()

func _update_equipment() -> void:
	# TODO: Conectar con InventoryManager cuando esté listo
	if has_node("/root/InventoryManager"):
		var _inv = get_node("/root/InventoryManager")
		# Por ahora mostrar placeholders
		if weapon_label:
			weapon_label.text = "---"
		if armor_label:
			armor_label.text = "---"
		if accessory_label:
			accessory_label.text = "---"

func _on_hero_stats_changed() -> void:
	_update_stats()
