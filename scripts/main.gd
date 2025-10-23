extends Node2D

const HUD_SCENE := preload("res://scenes/UI/HUD.tscn")
const CORRIDOR_SCENE := preload("res://scenes/Corridor.tscn")
const DUNGEON_STATUS_SCENE := preload("res://scenes/HUD/DungeonStatus.tscn")

@onready var camera: Camera2D = $Camera2D
@onready var forge_ui: CanvasLayer = $ForgeUI
@onready var dungeon_ui: CanvasLayer = $DungeonUI
@onready var result_panel: Control = $ForgeUI/ResultPanel
@onready var delivery_panel: Control = $ForgeUI/DeliveryPanel
@onready var fade_overlay: ColorRect = $FadeLayer/FadeOverlay
@onready var fade_layer: CanvasLayer = $FadeLayer

var hud: CanvasLayer
var corridor: Node2D
var dungeon_status: Control

var current_area: StringName = &"forge"
var forge_camera_pos := Vector2.ZERO
var dungeon_camera_pos := Vector2(2000, 270)
var forge_zoom := Vector2(0.5, 0.5)
var dungeon_zoom := Vector2(0.5, 0.5)

func _ready() -> void:
        print("Main: Scene ready")
        hud = HUD_SCENE.instantiate()
        forge_ui.add_child(hud)

        corridor = CORRIDOR_SCENE.instantiate()
        corridor.visible = false
        add_child(corridor)

        dungeon_status = DUNGEON_STATUS_SCENE.instantiate()
        dungeon_ui.add_child(dungeon_status)

        fade_overlay.size = get_viewport_rect().size
        fade_layer.visible = false
        corridor.visible = false
        forge_ui.visible = true
        dungeon_ui.visible = false

        if Engine.has_singleton("UIManager"):
                UIManager.register_camera(camera, forge_camera_pos, dungeon_camera_pos, forge_zoom, dungeon_zoom)
                UIManager.register_nodes({
                        "forge_ui": forge_ui,
                        "dungeon_ui": dungeon_ui,
                        "corridor": corridor,
                        "hud": hud,
                        "delivery_panel": delivery_panel,
                        "dungeon_status": dungeon_status,
                        "result_panel": result_panel,
                        "fade_layer": fade_layer,
                        "fade_overlay": fade_overlay,
                        "camera": camera,
                        "forge_position": forge_camera_pos,
                        "dungeon_position": dungeon_camera_pos,
                        "forge_zoom": forge_zoom,
                        "dungeon_zoom": dungeon_zoom,
                })
                if not UIManager.is_connected("area_changed", Callable(self, "_on_area_changed")):
                        UIManager.area_changed.connect(_on_area_changed)
                UIManager.show_forge()
        else:
                _apply_area_locally(&"forge")

        _register_game_manager()
        print("Main: Scene ready. Área actual: Forja")

func _register_game_manager() -> void:
        if not Engine.has_singleton("GameManager"):
                push_error("Main: GameManager not found")
                return
        var gm := GameManager
        if not gm.is_connected("room_entered", Callable(self, "_on_room_entered")):
                gm.room_entered.connect(_on_room_entered)
        if not gm.is_connected("game_over", Callable(self, "_on_game_over")):
                gm.game_over.connect(_on_game_over)
        if not gm.is_connected("hero_died", Callable(self, "_on_hero_died")):
                gm.hero_died.connect(_on_hero_died)
        if not gm.is_connected("hero_respawned", Callable(self, "_on_hero_respawned")):
                gm.hero_respawned.connect(_on_hero_respawned)
        if not gm.is_connected("boss_defeated", Callable(self, "_on_boss_defeated")):
                gm.boss_defeated.connect(_on_boss_defeated)
        var hero := corridor.get_node_or_null("Hero")
        if hero:
                gm.register_hero(hero)
        gm.start_run()

func change_area(area: StringName) -> void:
        if Engine.has_singleton("UIManager") and UIManager.get_current_area() == area:
                return
        if not Engine.has_singleton("UIManager") and current_area == area:
                return
        _fade_out_in(func():
                if Engine.has_singleton("UIManager"):
                        if area == &"forge":
                                UIManager.show_forge()
                        else:
                                UIManager.show_dungeon()
                else:
                        _apply_area_locally(area)
        )

func _apply_area_locally(area: StringName) -> void:
        current_area = area
        var is_dungeon := area == &"dungeon"
        forge_ui.visible = not is_dungeon
        dungeon_ui.visible = is_dungeon
        if corridor:
                corridor.visible = is_dungeon
                corridor.process_mode = Node.PROCESS_MODE_INHERIT if is_dungeon else Node.PROCESS_MODE_DISABLED
        camera.position = dungeon_camera_pos if is_dungeon else forge_camera_pos
        camera.zoom = dungeon_zoom if is_dungeon else forge_zoom

func _fade_out_in(callback: Callable) -> void:
        fade_overlay.modulate.a = 0
        fade_layer.visible = true
        var tween := get_tree().create_tween()
        tween.tween_property(fade_overlay, "modulate:a", 1.0, 1.0)
        tween.tween_interval(0.5)
        tween.tween_callback(callback)
        tween.tween_property(fade_overlay, "modulate:a", 0.0, 1.0)
        tween.tween_callback(func(): fade_layer.visible = false)

func _input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
                if Engine.has_singleton("UIManager") and not UIManager.can_toggle_area():
                        return
                var target_area := &"dungeon" if _get_current_area() == &"forge" else &"forge"
                change_area(target_area)

func _process(_delta: float) -> void:
        if _get_current_area() != &"dungeon" or corridor == null or dungeon_status == null:
                return
        var hero := corridor.get_node_or_null("Hero")
        var enemy := corridor.get_node_or_null("Enemy")
        if hero and enemy:
                dungeon_status.call("update_combat_info", hero, enemy, _corridor_state_name())

func _on_room_entered(room_idx: int) -> void:
        print("Main: Cambiando a Dungeon")
        change_area(&"dungeon")
        _update_hud_label("HUD - Room: %d" % room_idx)

func _on_game_over() -> void:
        print("Main: Cambiando a Forja")
        change_area(&"forge")
        _update_hud_label("GAME OVER")

func _on_hero_died(death_count: int) -> void:
        print("Main: Hero died (%d)" % death_count)
        _update_hud_label("Hero died! (%d)" % death_count)

func _on_hero_respawned(death_count: int) -> void:
        print("Main: Hero respawned after %d deaths" % death_count)
        _update_hud_label("Hero ready (deaths %d)" % death_count)

func _on_boss_defeated() -> void:
        print("Main: Boss defeated")
        _update_hud_label("Boss defeated!")

func _on_area_changed(new_area: StringName) -> void:
        current_area = new_area

func _update_hud_label(text: String) -> void:
        if hud:
                var label: Label = hud.get_node_or_null("Label")
                if label:
                        label.text = text

func _get_current_area() -> StringName:
        if Engine.has_singleton("UIManager"):
                return UIManager.get_current_area()
        return current_area

func _corridor_state_name() -> String:
        if corridor == null:
                return "IDLE"
        var state_value = corridor.get("state") if corridor.has_method("get") else 0
        if corridor.has_method("get_state_name"):
                return corridor.get_state_name()
        match state_value:
                corridor.State.RUN:
                        return "RUN"
                corridor.State.FIGHT:
                        return "FIGHT"
                corridor.State.DEAD:
                        return "DEAD"
                corridor.State.COMPLETE:
                        return "COMPLETE"
                _:
                        return str(state_value)
