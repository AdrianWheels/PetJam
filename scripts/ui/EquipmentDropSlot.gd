extends ColorRect
class_name EquipmentDropSlot

## Slot de equipamiento que acepta drops de items

signal item_equipped(item: CraftedItem)
signal item_rejected(item: CraftedItem)

@export var slot_type: String = "main_hand"  # main_hand, head, body, off_hand, feet
@export var slot_label: String = "Slot"

var equipped_item: CraftedItem = null
var _default_color: Color = Color(0.3, 0.3, 0.35, 1)

# Sonidos placeholder
const SFX_SUCCESS = preload("res://art/sounds/good.mp3")
const SFX_ERROR = preload("res://art/sounds/miss.mp3")

func _ready() -> void:
	color = _default_color

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	"""SIEMPRE permite drop para poder mostrar animación de rechazo"""
	return data is CraftedItem

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	"""Maneja el drop con animación de feedback"""
	if not data is CraftedItem:
		return
	
	var item: CraftedItem = data as CraftedItem
	var item_slot = item.get_equipment_slot()
	var compatible = item_slot == slot_type
	
	if compatible:
		# ✅ COMPATIBLE: Verde + scale bounce + equipar
		_play_success_animation()
		equipped_item = item
		emit_signal("item_equipped", item)
	else:
		# ❌ INCOMPATIBLE: Rojo + shake + rechazar
		_play_rejection_animation()
		emit_signal("item_rejected", item)

func _play_success_animation() -> void:
	"""Animación de éxito: verde + escala bounce"""
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Flash verde
	tween.tween_property(self, "color", Color(0.5, 0.9, 0.5, 1.0), 0.15)
	tween.tween_property(self, "color", _default_color, 0.3).set_delay(0.15)
	
	# Bounce scale
	tween.set_parallel(false)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	
	# Audio feedback (placeholder sound)
	if has_node("/root/AudioManager"):
		var audio = get_node("/root/AudioManager")
		audio.play_sfx(SFX_SUCCESS, 0.0, audio.AudioContext.DUNGEON)

func _play_rejection_animation() -> void:
	"""Animación de rechazo: rojo + shake horizontal"""
	var tween = create_tween()
	var original_pos = position
	
	# Flash rojo
	tween.tween_property(self, "color", Color(0.9, 0.3, 0.3, 1.0), 0.1)
	
	# Shake horizontal
	tween.tween_property(self, "position:x", original_pos.x + 8, 0.05)
	tween.tween_property(self, "position:x", original_pos.x - 8, 0.05)
	tween.tween_property(self, "position:x", original_pos.x + 5, 0.05)
	tween.tween_property(self, "position:x", original_pos.x - 5, 0.05)
	tween.tween_property(self, "position:x", original_pos.x, 0.05)
	
	# Restaurar color
	tween.tween_property(self, "color", _default_color, 0.2)
	
	# Audio feedback (placeholder sound)
	if has_node("/root/AudioManager"):
		var audio = get_node("/root/AudioManager")
		audio.play_sfx(SFX_ERROR, 0.0, audio.AudioContext.DUNGEON)
