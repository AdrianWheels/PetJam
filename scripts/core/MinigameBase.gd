extends Control

signal trial_completed(result: TrialResult)

var title_screen = null
var end_screen = null
var trial_config: TrialConfig
var _final_result: TrialResult
var _result_emitted := false

# Sistema anti-spam (FASE 1)
const INPUT_COOLDOWN_MS := 150
const BURST_WINDOW_MS := 500
const BURST_THRESHOLD := 3
var _last_input_time := 0
var _input_burst_count := 0
var _spam_penalty_active := false
var _spam_penalty_until := 0

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

## Sistema anti-spam: validar inputs
## Retorna true si el input es válido, false si debe ser ignorado
func _validate_input() -> bool:
        var now := Time.get_ticks_msec()
        
        # Cooldown mínimo entre inputs
        if now - _last_input_time < INPUT_COOLDOWN_MS:
                return false
        
        # Detección de ráfaga (spam)
        if now - _last_input_time < BURST_WINDOW_MS:
                _input_burst_count += 1
                if _input_burst_count > BURST_THRESHOLD:
                        # Activar penalización temporal
                        _spam_penalty_active = true
                        _spam_penalty_until = now + 2000  # 2s de penalización
                        print("[MinigameBase] Spam detectado - penalización activa")
                        return false
        else:
                _input_burst_count = 0
        
        # Verificar si la penalización sigue activa
        if _spam_penalty_active:
                if now > _spam_penalty_until:
                        _spam_penalty_active = false
                        _input_burst_count = 0
                else:
                        return false
        
        _last_input_time = now
        return true

## Obtener multiplicador de precisión (usado en subclases)
## Retorna valores < 1.0 si hay penalización activa
func get_precision_multiplier() -> float:
        if _spam_penalty_active:
                return 0.7  # -30% precisión durante penalización
        return 1.0
