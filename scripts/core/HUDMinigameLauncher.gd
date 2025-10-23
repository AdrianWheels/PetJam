extends CanvasLayer

const FALLBACK_MINIGAMES := {
        &"Forge": preload("res://scenes/Minigames/ForgeTemp.tscn"),
        &"Hammer": preload("res://scenes/HammerMinigame.tscn"),
        &"Sew": preload("res://scenes/Minigames/SewOSU.tscn"),
        &"Quench": preload("res://scenes/Minigames/QuenchWater.tscn"),
        &"Temp": preload("res://scenes/Minigames/TempMinigame.tscn"),
}

var _active_minigame: Node = null
var _active_task_id: int = -1
var _active_config: TrialConfig

func _find_node_any(candidates: Array) -> Node:
        for p in candidates:
                var n = get_node_or_null(str(p))
                if n:
                        return n
        return null

func _ready():
        var btn_forge = _find_node_any(["BtnForge", "MinigamesPanel/BtnForge", "MinigamesPanel/MinigamesHBox/BtnForge"])
        if btn_forge:
                btn_forge.pressed.connect(_on_btn_forge)
                print("HUD: Forge button connected")
        else:
                print("HUD: Forge button not found")

        var btn_hammer = _find_node_any(["BtnHammer", "MinigamesPanel/MinigamesHBox/BtnHammer", "MinigamesPanel/BtnHammer"])
        if btn_hammer:
                btn_hammer.pressed.connect(_on_btn_hammer)
                print("HUD: Hammer button connected")
        else:
                print("HUD: Hammer button not found")

        var btn_sew = _find_node_any(["BtnSewOSU", "MinigamesPanel/MinigamesHBox/BtnSewOSU", "MinigamesPanel/BtnSewOSU"])
        if btn_sew:
                btn_sew.pressed.connect(_on_btn_sew_osu)
                print("HUD: Sew button connected")
        else:
                print("HUD: Sew button not found")

        var btn_quench = _find_node_any(["BtnQuench", "MinigamesPanel/MinigamesHBox/BtnQuench", "MinigamesPanel/BtnQuench"])
        if btn_quench:
                btn_quench.pressed.connect(_on_btn_quench)
                print("HUD: Quench button connected")
        else:
                print("HUD: Quench button not found")

        var btn_temp = _find_node_any(["BtnTemp", "MinigamesPanel/MinigamesHBox/BtnTemp", "MinigamesPanel/BtnTemp"])
        if btn_temp:
                btn_temp.pressed.connect(_on_btn_temp)
                print("HUD: Temp button connected")
        else:
                print("HUD: Temp button not found")

        var cm = get_node("/root/CraftingManager") if has_node("/root/CraftingManager") else null
        if cm:
                cm.connect("craft_enqueued", Callable(self, "_on_craft_enqueued"))
                if not cm.is_connected("task_started", Callable(self, "_on_task_started")):
                        cm.connect("task_started", Callable(self, "_on_task_started"))
                if not cm.is_connected("task_updated", Callable(self, "_on_task_updated")):
                        cm.connect("task_updated", Callable(self, "_on_task_updated"))
                print("HUD: Connected to CraftingManager")
        else:
                print("HUD: CraftingManager not found")

        if has_node('/root/DataManager'):
                var dm = get_node('/root/DataManager')
                if dm.blueprints.size() > 0:
                        update_queue_display()
                        populate_materials_list()
                else:
                        dm.connect("data_ready", Callable(self, "update_queue_display"))
                        dm.connect("data_ready", Callable(self, "populate_materials_list"))
                        print("HUD: waiting for DataManager.data_ready to populate queue")
        else:
                print("HUD: DataManager not found; queue will not populate until available")

func _on_btn_forge() -> void:
        print("HUD: Forge pressed")
        if has_node('/root/GameManager'):
                get_node('/root/GameManager').start_minigame("Forge")

func _on_btn_hammer() -> void:
        print("HUD: Hammer pressed")
        if has_node('/root/GameManager'):
                get_node('/root/GameManager').start_minigame("Hammer")

func _on_btn_sew_osu() -> void:
        print("HUD: Sew OSU pressed")
        if has_node('/root/GameManager'):
                get_node('/root/GameManager').start_minigame("Sew")

func _on_btn_quench() -> void:
        print("HUD: Quench pressed")
        if has_node('/root/GameManager'):
                get_node('/root/GameManager').start_minigame("Quench")

func _on_btn_temp() -> void:
        print("HUD: Temp pressed")
        if has_node('/root/GameManager'):
                get_node('/root/GameManager').start_minigame("Temp")

func _on_craft_enqueued(slot_idx:int, recipe_id:String) -> void:
        print("HUD: Craft enqueued slot %d -> %s" % [slot_idx, recipe_id])
        if has_node('/root/Logger'):
                get_node('/root/Logger').info("HUD: craft_enqueued", {"slot": slot_idx, "recipe": recipe_id})
        update_queue_display()
        append_print("Craft enqueued: %s (slot %d)" % [recipe_id, slot_idx])

func _on_task_started(task_id: int, config: TrialConfig) -> void:
        if config == null:
                return
        var runtime_config := config.duplicate_config() if config.has_method("duplicate_config") else config
        _launch_trial(task_id, runtime_config)

func _on_task_updated(task_id: int, payload: Dictionary) -> void:
        var status := String(payload.get("status", ""))
        if _active_task_id != -1 and task_id == _active_task_id and status == "completed":
                _active_task_id = -1

func update_queue_display() -> void:
        var queue_container = get_node_or_null("BlueprintQueuePanel/QueueContainer")
        if not queue_container:
                queue_container = get_node_or_null("QueueContainer")
        if not queue_container:
                print("HUD: QueueContainer not found; cannot update display")
                return
        for child in queue_container.get_children():
                child.queue_free()

        var cm = get_node("/root/CraftingManager") if has_node("/root/CraftingManager") else null
        if cm == null:
                print("HUD: CraftingManager not available for queue display")
                return

        var snapshot: Array = cm.get_queue_snapshot() if cm.has_method("get_queue_snapshot") else []
        for entry in snapshot:
                if typeof(entry) != TYPE_DICTIONARY:
                        continue
                var slot_idx: int = int(entry.get("slot_index", 0))
                var slot_scene = preload("res://scenes/UI/BlueprintQueueSlot.tscn")
                var slot_node = slot_scene.instantiate()
                queue_container.add_child(slot_node)

                if entry.get("status", "") == "empty":
                        slot_node.set_blueprint_name("(vacío)")
                        continue

                var blueprint: BlueprintResource = entry.get("blueprint", null)
                var recipe_id = entry.get("blueprint_id", "")
                if blueprint and blueprint is BlueprintResource:
                        slot_node.set_blueprint(blueprint)
                else:
                        var display_name: String = entry.get("display_name", str(recipe_id))
                        slot_node.set_blueprint_name(display_name)
                        slot_node.set_materials(entry.get("materials", {}))

                if has_node('/root/Logger'):
                        get_node('/root/Logger').info("HUD: queue_slot_populated", {"slot": slot_idx, "recipe_id": recipe_id, "status": entry.get("status", "unknown")})
                append_print("Slot %d: %s" % [slot_idx, entry.get("display_name", str(recipe_id))])

func append_print(msg: String) -> void:
        var ta = get_node_or_null("BlueprintQueuePanel/QueueVBox/PrintsArea")
        if not ta:
                ta = get_node_or_null("PrintsArea")
        if ta:
                ta.append_bbcode(str(msg) + "\n")

func populate_materials_list() -> void:
        var ml = get_node_or_null("InventoryPanel/InventoryVBox/MaterialsList")
        if not ml:
                ml = get_node_or_null("MaterialsList")
        if not ml:
                print("HUD: MaterialsList node not found")
                return
        for child in ml.get_children():
                child.queue_free()
        if not has_node('/root/DataManager'):
                return
        var dm = get_node('/root/DataManager')
        for key in dm.materials.keys():
                var entry = dm.materials[key]
                var label = Label.new()
                label.text = "%s: %s" % [str(key), str(entry.get("stack", "?"))]
                ml.add_child(label)

func _launch_trial(task_id: int, config: TrialConfig) -> void:
        if config == null:
                return
        if _active_minigame and is_instance_valid(_active_minigame):
                _active_minigame.queue_free()
        var scene: PackedScene = config.minigame_scene if config.minigame_scene else _fallback_scene_for(config.minigame_id)
        if scene == null:
                push_warning("HUD: No scene for minigame %s" % String(config.minigame_id))
                return
        var instance = scene.instantiate()
        _active_minigame = instance
        _active_task_id = task_id
        _active_config = config
        _set_forge_panels_visible(false)
        var parent_layer := get_parent()
        if parent_layer:
                parent_layer.add_child(instance)
        else:
                add_child(instance)
        if instance.has_signal("trial_completed"):
                instance.connect("trial_completed", Callable(self, "_on_trial_completed").bind(instance, task_id, config))
        if instance.has_method("start_trial"):
                instance.start_trial(config)
        elif instance.has_method("start_game"):
                instance.start_game()

func _on_trial_completed(result: TrialResult, instance: Node, task_id: int, config: TrialConfig) -> void:
        var outcome := {}
        if has_node("/root/CraftingManager"):
                outcome = get_node("/root/CraftingManager").report_trial_result(task_id, result)
        if has_node("/root/TelemetryManager"):
                get_node("/root/TelemetryManager").record_trial(config.blueprint_id, config.trial_id, result)
        if _active_minigame == instance:
                _active_task_id = -1
        if typeof(outcome) == TYPE_DICTIONARY:
                var status := String(outcome.get("status", ""))
                if status == "completed" and Engine.has_singleton("UIManager"):
                        UIManager.present_delivery(outcome)

func _fallback_scene_for(minigame_id: StringName) -> PackedScene:
        var key := StringName(minigame_id)
        if FALLBACK_MINIGAMES.has(key):
                return FALLBACK_MINIGAMES[key]
        return null

func _set_forge_panels_visible(visible: bool) -> void:
        var nodes := [
                "MinigamesPanel",
                "BlueprintQueuePanel",
                "InventoryPanel",
                "Label"
        ]
        for name in nodes:
                var node = get_node_or_null(name)
                if node:
                        node.visible = visible
