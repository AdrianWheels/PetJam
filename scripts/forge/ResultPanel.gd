extends Control

@export var fill_path: NodePath
@export var percent_label_path: NodePath
@export var title_label_path: NodePath

var _fill: ColorRect
var _percent_label: Label
var _title_label: Label
var _ratio := 0.0
var _current_task_id := -1
var _current_name := ""

func _ready() -> void:
        _fill = get_node_or_null(fill_path)
        _percent_label = get_node_or_null(percent_label_path)
        _title_label = get_node_or_null(title_label_path)
        if has_node("/root/CraftingManager"):
                get_node("/root/CraftingManager").connect("task_updated", Callable(self, "_on_task_updated"))
        update_display()
        if _fill:
                _fill.connect("resized", Callable(self, "_update_fill_rect"))
        connect("resized", Callable(self, "_update_fill_rect"))

func _on_task_updated(task_id: int, payload: Dictionary) -> void:
        if not payload.has("score") and payload.get("status", "") != "empty":
                return
        var status := String(payload.get("status", ""))
        if status == "in_progress":
                _current_task_id = task_id
        elif status == "empty" and task_id == _current_task_id:
                _current_task_id = -1
        elif status == "completed" and task_id == _current_task_id:
                _current_task_id = -1

        var score := float(payload.get("score", 0.0))
        var max_score := float(payload.get("max_score", 0.0))
        if max_score > 0.0:
                _ratio = clamp(score / max_score, 0.0, 1.0)
        elif status == "completed":
                _ratio = 1.0 if score > 0.0 else 0.0
        elif status == "empty":
                _ratio = 0.0

        if payload.has("display_name") and payload.get("display_name") != "":
                _current_name = payload.get("display_name")

        update_display()

func update_display() -> void:
        _update_fill_rect()
        if _percent_label:
                _percent_label.text = "%d%%" % int(round(_ratio * 100))
        if _title_label:
                _title_label.text = _current_name if _current_name != "" else "Sin asignar"

func _update_fill_rect() -> void:
        if not _fill:
                return
        var container := _fill.get_parent() if is_instance_valid(_fill) else null
        if container == null:
                return
        var height := container.size.y
        var fill_height := height * clamp(_ratio, 0.0, 1.0)
        _fill.position.y = height - fill_height
        _fill.size = Vector2(container.size.x, fill_height)
