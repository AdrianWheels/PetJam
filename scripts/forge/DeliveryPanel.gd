extends Control
class_name DeliveryPanel

signal delivery_confirmed(item_id, slot_name)
signal cancelled

const SLOT_NAMES := {
        0: &"weapon",
        1: &"armor",
        2: &"shield",
        3: &"trinket",
}

@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name_label: Label = %ItemName
@onready var grade_label: Label = %GradeLabel
@onready var slot_selector: OptionButton = %SlotSelector
@onready var score_label: Label = %ScoreLabel
@onready var deliver_button: Button = %DeliverButton
@onready var close_button: Button = %CloseButton

var _current_item_id: StringName = StringName()
var _active_loadout: Dictionary = {}

func _ready() -> void:
        visible = false
        if deliver_button:
                deliver_button.pressed.connect(_on_deliver_pressed)
        if close_button:
                close_button.pressed.connect(_on_close_pressed)

func show_delivery(payload: Dictionary) -> void:
        _current_item_id = payload.get("item_id", StringName())
        var blueprint: BlueprintResource = payload.get("blueprint")
        var grade := String(payload.get("grade", ""))
        var score := float(payload.get("score", 0.0))
        var max_score := float(payload.get("max_score", 0.0))

        if blueprint:
                if item_name_label:
                        var display_name := blueprint.display_name if blueprint.display_name != "" else String(blueprint.blueprint_id)
                        item_name_label.text = display_name
                if item_icon:
                        item_icon.texture = blueprint.get_icon()
        else:
                if item_name_label:
                        item_name_label.text = String(_current_item_id)
                if item_icon:
                        item_icon.texture = null

        if grade_label:
                grade_label.text = grade.capitalize() if grade != "" else "Sin calificar"
        if score_label:
                if max_score > 0.0:
                        var percent := clamp(score / max_score, 0.0, 1.0) * 100.0
                        score_label.text = "Puntaje: %.0f%%" % percent
                else:
                        score_label.text = "Puntaje: %.0f" % score

        if slot_selector:
                slot_selector.clear()
                slot_selector.add_item("Arma", 0)
                slot_selector.add_item("Armadura", 1)
                slot_selector.add_item("Escudo", 2)
                slot_selector.add_item("Accesorio", 3)
                slot_selector.select(_suggest_slot_index(_current_item_id))
        visible = true

func hide_delivery() -> void:
        visible = false

func set_active_loadout(loadout: Dictionary) -> void:
        _active_loadout = loadout.duplicate(true)

func _on_deliver_pressed() -> void:
        if _current_item_id == StringName():
                emit_signal("cancelled")
                return
        var selected_id := slot_selector.get_selected_id() if slot_selector else 0
        var slot := SLOT_NAMES.get(selected_id, &"weapon")
        emit_signal("delivery_confirmed", _current_item_id, slot)

func _on_close_pressed() -> void:
        emit_signal("cancelled")

func _suggest_slot_index(item_id: StringName) -> int:
        var default_slot := 0
        match String(item_id):
                "armor_leather", "helmet_iron":
                        default_slot = 1
                "shield_wooden":
                        default_slot = 2
                "potion_heal":
                        default_slot = 3
                _:
                        default_slot = 0
        return default_slot
