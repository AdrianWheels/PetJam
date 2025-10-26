extends RefCounted

## Representa un item crafteado con calidad y stats calculados
class_name CraftedItem

# Referencias
var item_resource: ItemResource
var quality: float = 0.5  # 0.0 - 1.0 (normalizado)
var calculated_stats: Dictionary = {}

# Metadatos
var crafted_timestamp: int = 0
var is_equipped: bool = false

func _init(item_res: ItemResource, craft_quality: float) -> void:
	item_resource = item_res
	quality = clampf(craft_quality, 0.0, 1.0)
	crafted_timestamp = Time.get_ticks_msec()
	
	if item_resource:
		calculated_stats = item_resource.calculate_stats(quality)

## Retorna la calidad como porcentaje (0-100)
func get_quality_percent() -> int:
	return roundi(quality * 100.0)

## Retorna el tier de rareza según umbrales de calidad
func get_quality_tier() -> String:
	var percent = get_quality_percent()
	if percent >= 99:
		return "legendary"  # Naranja (99-100%)
	elif percent >= 90:
		return "epic"  # Morado (90-98%)
	elif percent >= 70:
		return "rare"  # Azul (70-89%)
	elif percent >= 40:
		return "uncommon"  # Verde (40-69%)
	else:
		return "common"  # Blanco (0-39%)

## Retorna color de outline según tier
func get_quality_color() -> Color:
	match get_quality_tier():
		"legendary":
			return Color.ORANGE  # FF6A00
		"epic":
			return Color.PURPLE  # A020F0
		"rare":
			return Color.DODGER_BLUE  # 1E90FF
		"uncommon":
			return Color.GREEN  # 00FF00
		_:
			return Color.WHITE  # FFFFFF

## Retorna label de calidad
func get_quality_label() -> String:
	match get_quality_tier():
		"legendary":
			return "LEGENDARIO"
		"epic":
			return "ÉPICO"
		"rare":
			return "RARO"
		"uncommon":
			return "COMÚN"
		_:
			return "BÁSICO"

## Retorna el nombre del item con calidad
func get_display_name() -> String:
	if item_resource:
		return "%s (%d%%)" % [item_resource.display_name, get_quality_percent()]
	return "Unknown item"

## Retorna el slot de equipamiento
func get_equipment_slot() -> String:
	if item_resource:
		return item_resource.equipment_slot
	return ""

## Retorna el tipo de item
func get_item_type() -> String:
	if item_resource:
		return item_resource.item_type
	return ""

## Retorna el icono del item
func get_icon() -> Texture2D:
	if item_resource:
		return item_resource.get_icon()
	return null

## Serialización para inventario persistente
func to_dict() -> Dictionary:
	return {
		"item_id": String(item_resource.item_id) if item_resource else "",
		"quality": quality,
		"stats": calculated_stats.duplicate(),
		"timestamp": crafted_timestamp,
		"equipped": is_equipped
	}

## Deserialización desde diccionario
static func from_dict(data: Dictionary, item_res: ItemResource) -> CraftedItem:
	var item = CraftedItem.new(item_res, data.get("quality", 0.5))
	item.calculated_stats = data.get("stats", {}).duplicate()
	item.crafted_timestamp = data.get("timestamp", 0)
	item.is_equipped = data.get("equipped", false)
	return item
