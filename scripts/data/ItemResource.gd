extends Resource

## Recurso de item crafteable con icono y estadísticas base
class_name ItemResource

# Identificación y display
@export var item_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

# Tipo y categoría
@export_enum("weapon", "helmet", "armor", "shield", "boots", "accessory", "consumable") var item_type: String = "weapon"
@export_enum("head", "body", "hand", "feet", "off_hand", "main_hand") var equipment_slot: String = "main_hand"
@export var rarity: String = "basic"  # "basic", "advanced", "master"

# Estadísticas base (rango mínimo-máximo según calidad)
@export_group("Base Stats")
@export var base_damage_min: int = 0
@export var base_damage_max: int = 0
@export var base_str_min: int = 0
@export var base_str_max: int = 0
@export var base_agi_min: int = 0
@export var base_agi_max: int = 0
@export var base_int_min: int = 0
@export var base_int_max: int = 0
@export var base_hp_min: int = 0
@export var base_hp_max: int = 0
@export var base_armor_min: int = 0
@export var base_armor_max: int = 0
@export var base_crit_min: float = 0.0
@export var base_crit_max: float = 0.0
@export var base_aps_min: float = 0.0
@export var base_aps_max: float = 0.0

func get_icon() -> Texture2D:
	return icon

## Calcula estadísticas finales basado en calidad (0.0 - 1.0)
func calculate_stats(quality: float) -> Dictionary:
	var clamped_quality = clampf(quality, 0.0, 1.0)
	return {
		"damage": roundi(lerp(float(base_damage_min), float(base_damage_max), clamped_quality)),
		"str": roundi(lerp(float(base_str_min), float(base_str_max), clamped_quality)),
		"agi": roundi(lerp(float(base_agi_min), float(base_agi_max), clamped_quality)),
		"int": roundi(lerp(float(base_int_min), float(base_int_max), clamped_quality)),
		"hp": roundi(lerp(float(base_hp_min), float(base_hp_max), clamped_quality)),
		"armor": roundi(lerp(float(base_armor_min), float(base_armor_max), clamped_quality)),
		"crit": lerp(base_crit_min, base_crit_max, clamped_quality),
		"aps": lerp(base_aps_min, base_aps_max, clamped_quality)
	}
