# res://scripts/ui/HUDHero.gd
extends CanvasLayer

## HUD del héroe en Dungeon. Muestra stats, HP, equipo y botón para volver a forja.

@onready var hp_label: Label = $StatsPanel/StatsVBox/HPLabel
@onready var hp_bar: ProgressBar = $StatsPanel/StatsVBox/HPBar
@onready var str_label: Label = $StatsPanel/StatsVBox/STRLabel
@onready var agi_label: Label = $StatsPanel/StatsVBox/AGILabel
@onready var int_label: Label = $StatsPanel/StatsVBox/INTLabel
@onready var dmg_label: Label = $StatsPanel/StatsVBox/DMGLabel
@onready var room_label: Label = $RoomLabel
@onready var back_button: Button = $BackButton

@onready var weapon_slot: Button = $EquipmentPanel/EquipHBox/WeaponSlot
@onready var armor_slot: Button = $EquipmentPanel/EquipHBox/ArmorSlot
@onready var accessory_slot: Button = $EquipmentPanel/EquipHBox/AccessorySlot

var hero: CharacterBody2D = null

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	
	# Conectar señales de GameManager
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_signal("room_changed"):
			gm.room_changed.connect(_on_room_changed)
		if gm.has_signal("hero_damaged"):
			gm.hero_damaged.connect(_on_hero_damaged)

func set_hero(h: CharacterBody2D) -> void:
	hero = h
	update_stats()

func update_stats() -> void:
	if not hero:
		return
	
	# Actualizar HP (acceso directo a propiedades del script Hero.gd)
	var current_hp: float = hero.get("hp") if hero.get("hp") != null else 60.0
	var max_hp: float = hero.get("max_hp") if hero.get("max_hp") != null else 60.0
	hp_label.text = "HP: %d / %d" % [int(current_hp), int(max_hp)]
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	
	# Color coding HP bar
	var hp_percent: float = (current_hp / max_hp) * 100.0
	if hp_percent > 60.0:
		hp_bar.modulate = Color.GREEN
	elif hp_percent > 30.0:
		hp_bar.modulate = Color.ORANGE
	else:
		hp_bar.modulate = Color.RED
	
	# Stats
	var strength: int = hero.get("strength") if hero.get("strength") != null else 5
	var agility: int = hero.get("agility") if hero.get("agility") != null else 5
	var intelligence: int = hero.get("intelligence") if hero.get("intelligence") != null else 5
	var damage: float = hero.get("dmg") if hero.get("dmg") != null else 6.0
	
	str_label.text = "STR: %d" % strength
	agi_label.text = "AGI: %d" % agility
	int_label.text = "INT: %d" % intelligence
	dmg_label.text = "DMG: %d" % int(damage)

func update_equipment() -> void:
	# TODO: Leer equipo desde InventoryManager
	weapon_slot.text = "Arma: ---"
	armor_slot.text = "Armadura: ---"
	accessory_slot.text = "Accesorio: ---"

func _on_room_changed(room_idx: int) -> void:
	room_label.text = "DUNGEON - Sala: %d" % room_idx

func _on_hero_damaged(_amount: float) -> void:
	update_stats()

func _on_back_pressed() -> void:
	# Llamar a Main para cambiar de área
	var main_node := get_tree().current_scene
	if main_node and main_node.has_method("change_area"):
		main_node.change_area(&"forge")
	else:
		push_warning("HUDHero: No se pudo encontrar Main.change_area()")
