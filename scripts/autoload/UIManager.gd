extends Node
class_name UIManager

signal area_changed(new_area)
signal delivery_opened(item_id)
signal delivery_closed

var forge_ui: CanvasLayer
var dungeon_ui: CanvasLayer
var corridor: Node
var hud: Node
var delivery_panel: Control
var dungeon_status: Node
var result_panel: Control
var fade_layer: CanvasLayer
var fade_overlay: ColorRect
var camera: Camera2D
var forge_position: Vector2 = Vector2.ZERO
var dungeon_position: Vector2 = Vector2.ZERO
var forge_zoom: Vector2 = Vector2.ONE
var dungeon_zoom: Vector2 = Vector2.ONE
var _current_area: StringName = &"forge"
var _camera_tween: Tween

var _game_manager: GameManager
var _data_manager: DataManager

func _ready() -> void:
        _game_manager = GameManager if Engine.has_singleton("GameManager") else null
        _data_manager = DataManager if Engine.has_singleton("DataManager") else null
        if _game_manager:
                if not _game_manager.is_connected("room_entered", Callable(self, "_on_room_entered")):
                        _game_manager.room_entered.connect(_on_room_entered)
                if not _game_manager.is_connected("hero_died", Callable(self, "_on_hero_died")):
                        _game_manager.hero_died.connect(_on_hero_died)
                if not _game_manager.is_connected("hero_respawned", Callable(self, "_on_hero_respawned")):
                        _game_manager.hero_respawned.connect(_on_hero_respawned)
                if not _game_manager.is_connected("boss_defeated", Callable(self, "_on_boss_defeated")):
                        _game_manager.boss_defeated.connect(_on_boss_defeated)
                if not _game_manager.is_connected("game_over", Callable(self, "_on_game_over")):
                        _game_manager.game_over.connect(_on_game_over)
                if not _game_manager.is_connected("dungeon_state_changed", Callable(self, "_on_dungeon_state_changed")):
                        _game_manager.dungeon_state_changed.connect(_on_dungeon_state_changed)
                if not _game_manager.is_connected("hero_loadout_changed", Callable(self, "_on_hero_loadout_changed")):
                        _game_manager.hero_loadout_changed.connect(_on_hero_loadout_changed)

func register_nodes(config: Dictionary) -> void:
        forge_ui = config.get("forge_ui", forge_ui)
        dungeon_ui = config.get("dungeon_ui", dungeon_ui)
        corridor = config.get("corridor", corridor)
        hud = config.get("hud", hud)
        delivery_panel = config.get("delivery_panel", delivery_panel)
        dungeon_status = config.get("dungeon_status", dungeon_status)
        result_panel = config.get("result_panel", result_panel)
        fade_layer = config.get("fade_layer", fade_layer)
        fade_overlay = config.get("fade_overlay", fade_overlay)
        camera = config.get("camera", camera)
        forge_position = config.get("forge_position", forge_position)
        dungeon_position = config.get("dungeon_position", dungeon_position)
        forge_zoom = config.get("forge_zoom", forge_zoom)
        dungeon_zoom = config.get("dungeon_zoom", dungeon_zoom)

        if delivery_panel and not delivery_panel.is_connected("delivery_confirmed", Callable(self, "_on_delivery_confirmed")):
                delivery_panel.delivery_confirmed.connect(_on_delivery_confirmed)
        if delivery_panel and not delivery_panel.is_connected("cancelled", Callable(self, "_on_delivery_cancelled")):
                delivery_panel.cancelled.connect(_on_delivery_cancelled)

        if corridor:
            corridor.process_mode = Node.PROCESS_MODE_DISABLED if _current_area == &"forge" else Node.PROCESS_MODE_INHERIT
            var hero := corridor.get_node_or_null("Hero")
            if hero and _game_manager and _game_manager.has_method("register_hero"):
                    _game_manager.register_hero(hero)

        if dungeon_status:
            if _game_manager:
                    dungeon_status.call_deferred("set_total_rooms", _game_manager.total_rooms)
                    dungeon_status.call_deferred("set_max_deaths", GameManager.MAX_DEATHS)
                    dungeon_status.call_deferred("update_room", _game_manager.current_room)
                    dungeon_status.call_deferred("update_deaths", _game_manager.death_count)
                    dungeon_status.call_deferred("update_state", _dungeon_state_name(_game_manager.dungeon_state))
        if delivery_panel:
            delivery_panel.visible = false

func show_forge() -> void:
        _current_area = &"forge"
        if forge_ui:
                forge_ui.visible = true
        if dungeon_ui:
                dungeon_ui.visible = false
        if corridor:
                corridor.process_mode = Node.PROCESS_MODE_DISABLED
                corridor.visible = false
        _apply_camera_target(forge_position, forge_zoom)
        emit_signal("area_changed", _current_area)

func show_dungeon() -> void:
        _current_area = &"dungeon"
        if forge_ui:
                forge_ui.visible = false
        if dungeon_ui:
                dungeon_ui.visible = true
        if corridor:
                corridor.visible = true
                corridor.process_mode = Node.PROCESS_MODE_INHERIT
        _apply_camera_target(dungeon_position, dungeon_zoom)
        emit_signal("area_changed", _current_area)

func get_current_area() -> StringName:
        return _current_area

func can_toggle_area() -> bool:
        if delivery_panel and delivery_panel.visible:
                return false
        return true

func deliver_item_to_hero(item_id: StringName, slot: StringName = StringName()) -> void:
        if item_id == StringName():
                return
        if _game_manager == null:
                push_warning("UIManager: GameManager unavailable when delivering item")
                return
        _game_manager.deliver_item_to_hero(item_id, slot)

func present_delivery(result: Dictionary) -> void:
        if delivery_panel == null:
                return
        var item_id: StringName = result.get("result_item", StringName())
        var blueprint_id: StringName = result.get("blueprint_id", StringName())
        var grade := String(result.get("grade", ""))
        var score := float(result.get("score", 0.0))
        var max_score := float(result.get("max_score", 0.0))
        var blueprint: BlueprintResource = null
        if _data_manager:
                blueprint = _data_manager.get_blueprint(blueprint_id)
        var payload := {
                "item_id": item_id,
                "blueprint": blueprint,
                "grade": grade,
                "score": score,
                "max_score": max_score,
        }
        delivery_panel.call("show_delivery", payload)
        delivery_panel.visible = true
        show_forge()
        emit_signal("delivery_opened", item_id)

func is_delivery_open() -> bool:
        return delivery_panel != null and delivery_panel.visible

func register_camera(camera_node: Camera2D, forge_pos: Vector2, dungeon_pos: Vector2, forge_zoom_value: Vector2 = Vector2.ONE, dungeon_zoom_value: Vector2 = Vector2.ONE) -> void:
        camera = camera_node
        forge_position = forge_pos
        dungeon_position = dungeon_pos
        forge_zoom = forge_zoom_value
        dungeon_zoom = dungeon_zoom_value

func _apply_camera_target(target_position: Vector2, target_zoom: Vector2) -> void:
        if camera == null:
                return
        if _camera_tween and _camera_tween.is_running():
                _camera_tween.stop()
        _camera_tween = camera.get_tree().create_tween()
        _camera_tween.tween_property(camera, "position", target_position, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        _camera_tween.parallel().tween_property(camera, "zoom", target_zoom, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_room_entered(room_idx: int) -> void:
        if dungeon_status:
                dungeon_status.call("update_room", room_idx)

func _on_hero_died(death_count: int) -> void:
        if dungeon_status:
                dungeon_status.call("update_deaths", death_count)
                dungeon_status.call("show_result", "¡Héroe derrotado!", Color(1, 0.45, 0.35))

func _on_hero_respawned(death_count: int) -> void:
        if dungeon_status:
                dungeon_status.call("update_deaths", death_count)
                dungeon_status.call("clear_result")

func _on_boss_defeated() -> void:
        if dungeon_status:
                dungeon_status.call("show_result", "¡Jefe derrotado!", Color(0.45, 0.95, 0.55))

func _on_game_over() -> void:
        if dungeon_status:
                dungeon_status.call("show_result", "Fin de la expedición", Color(1, 0.85, 0.35))

func _on_dungeon_state_changed(new_state: int) -> void:
        if dungeon_status:
                dungeon_status.call("update_state", _dungeon_state_name(new_state))

func _on_hero_loadout_changed(loadout: Dictionary) -> void:
        if delivery_panel and delivery_panel.visible:
                delivery_panel.call("set_active_loadout", loadout)

func _on_delivery_confirmed(item_id: StringName, slot: StringName) -> void:
        deliver_item_to_hero(item_id, slot)
        if delivery_panel:
                delivery_panel.call("hide_delivery")
        emit_signal("delivery_closed")

func _on_delivery_cancelled() -> void:
        if delivery_panel:
                delivery_panel.call("hide_delivery")
        emit_signal("delivery_closed")

func _dungeon_state_name(state: int) -> String:
        if _game_manager == null:
                return "Desconocido"
        var keys := GameManager.DungeonState.keys()
        if state >= 0 and state < keys.size():
                return String(keys[state]).capitalize()
        return "Desconocido"
