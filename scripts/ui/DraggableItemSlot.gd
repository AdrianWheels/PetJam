extends PanelContainer
class_name DraggableItemSlot

## Slot de item draggable para el inventario

var item: CraftedItem = null

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null:
		return null
	
	# Crear preview del drag
	var preview = PanelContainer.new()
	preview.custom_minimum_size = Vector2(100, 100)
	
	# Aplicar estilo con borde de calidad
	const QualityUtils = preload("res://scripts/core/QualityHelper.gd")
	var style = QualityUtils.create_quality_border_style(item.quality)
	preview.add_theme_stylebox_override("panel", style)
	
	var icon = TextureRect.new()
	icon.texture = item.get_icon()
	icon.custom_minimum_size = Vector2(80, 80)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(icon)
	
	set_drag_preview(preview)
	
	return item
