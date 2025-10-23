extends Control

const TrialResult = preload("res://scripts/data/TrialResult.gd")
const TrialConfig = preload("res://scripts/data/TrialConfig.gd")

signal trial_completed(result: TrialResult)

var title_screen = null
var end_screen = null
var trial_config: TrialConfig
var _final_result: TrialResult
var _result_emitted := false

func setup_title_screen(game_title: String, instructions: String = "", continue_text: String = ""):
        title_screen = preload("res://scenes/UI/TitleScreen.tscn").instantiate()
        title_screen.title = game_title
        if instructions != "":
                title_screen.get_node("InstructionsLabel").text = instructions
        if continue_text != "":
                title_screen.get_node("ContinueLabel").text = continue_text
        title_screen.connect("continue_pressed", Callable(self, "_on_title_continue"))
        add_child(title_screen)

func start_trial(config: TrialConfig) -> void:
        trial_config = config

func _on_title_continue():
        if title_screen:
                title_screen.visible = false
        start_game()

func start_game():
        # Override in subclasses
        pass

func setup_end_screen(title: String, result_text: String):
        end_screen = preload("res://scenes/UI/TitleScreen.tscn").instantiate()
        end_screen.title = title
        end_screen.get_node("ContinueLabel").text = result_text
        end_screen.connect("continue_pressed", Callable(self, "_on_end_continue"))
        add_child(end_screen)
        end_screen.visible = true

func _on_end_continue():
        if not _result_emitted:
                complete_trial(get_result())
        var parent_node := get_parent()
        if parent_node:
                var hud := parent_node.get_node_or_null("HUD")
                if hud and hud.has_method("_set_forge_panels_visible"):
                        hud._set_forge_panels_visible(true)
        queue_free()

func complete_trial(result: TrialResult) -> void:
        if result == null:
                result = TrialResult.new()
        if trial_config:
                if result.trial_id == StringName():
                        result.trial_id = trial_config.trial_id
                if result.blueprint_id == StringName():
                        result.blueprint_id = trial_config.blueprint_id
                if result.max_score <= 0.0:
                        result.max_score = trial_config.max_score
        _final_result = result
        if not _result_emitted:
                _result_emitted = true
                emit_signal("trial_completed", _final_result)

func get_result() -> TrialResult:
        if _final_result:
                return _final_result
        var result := TrialResult.new()
        if trial_config:
                result.trial_id = trial_config.trial_id
                result.blueprint_id = trial_config.blueprint_id
                result.max_score = trial_config.max_score
        return result
