extends Node
class_name QualityHelper

## Helper estático para gestionar colores y tiers de calidad de items

## Convierte grade de CraftingManager (gold/silver/bronze) a quality normalizada
static func grade_to_quality(grade: String) -> float:
	match grade:
		"gold":
			return 0.95  # 95%
		"silver":
			return 0.75  # 75%
		"bronze":
			return 0.50  # 50%
		_:
			return 0.20  # 20% para fail

## Retorna el tier de rareza según quality normalizada (0.0-1.0)
static func get_quality_tier(quality: float) -> String:
	var percent = int(quality * 100.0)
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
static func get_quality_color(quality: float) -> Color:
	var tier = get_quality_tier(quality)
	match tier:
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

## Retorna label de calidad en español
static func get_quality_label(quality: float) -> String:
	var tier = get_quality_tier(quality)
	match tier:
		"legendary":
			return "LEGENDARY"
		"epic":
			return "EPIC"
		"rare":
			return "RARE"
		"uncommon":
			return "COMMON"
		_:
			return "BASIC"

## Retorna calidad como porcentaje (0-100)
static func get_quality_percent(quality: float) -> int:
	return roundi(clampf(quality, 0.0, 1.0) * 100.0)

## Crea un StyleBoxFlat con borde de calidad
static func create_quality_border_style(quality: float, bg_color: Color = Color(0.15, 0.15, 0.2, 0.9), border_width: int = 3) -> StyleBoxFlat:
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bg_color
	style_box.border_width_left = border_width
	style_box.border_width_right = border_width
	style_box.border_width_top = border_width
	style_box.border_width_bottom = border_width
	style_box.border_color = get_quality_color(quality)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	return style_box
