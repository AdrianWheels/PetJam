extends Node

## Sistema de debug modular con filtros por categoría
## Permite activar/desactivar logs por sistema independientemente

@export_group("Debug Categories")
@export var show_forge_debug := true
@export var show_dungeon_debug := true
@export var show_minigame_debug := false
@export var show_audio_debug := false
@export var show_crafting_debug := false
@export var show_combat_debug := true

@export_group("General Settings")
@export var timestamp_logs := false
@export var colored_output := false  # ANSI colors disabled for Godot compatibility

func _ready():
	print("DebugManager ready (use log_<category>() methods)")

## Log de sistema de Forja (minijuegos, crafteo UI)
func log_forge(message: String) -> void:
	if show_forge_debug:
		_print_colored("[FORGE] %s" % message, "")

## Log de sistema de Dungeon (corredor, combate, enemigos)
func log_dungeon(message: String) -> void:
	if show_dungeon_debug:
		_print_colored("[DUNGEON] %s" % message, "")

## Log de minijuegos específicos (temperatura, martillo, etc.)
func log_minigame(message: String) -> void:
	if show_minigame_debug:
		_print_colored("[MINIGAME] %s" % message, "")

## Log de sistema de audio (música, SFX)
func log_audio(message: String) -> void:
	if show_audio_debug:
		_print_colored("[AUDIO] %s" % message, "")

## Log de sistema de crafteo (CraftingManager, cola, resultados)
func log_crafting(message: String) -> void:
	if show_crafting_debug:
		_print_colored("[CRAFTING] %s" % message, "")

## Log de combate (daño, muerte, boss)
func log_combat(message: String) -> void:
	if show_combat_debug:
		_print_colored("[COMBAT] %s" % message, "")

## Log genérico (siempre visible)
func log_info(message: String) -> void:
	print("[INFO] %s" % message)

## Log de error (siempre visible)
func log_error(message: String) -> void:
	push_error("[ERROR] %s" % message)

## Activa/desactiva una categoría de debug
func set_category_enabled(category: StringName, enabled: bool) -> void:
	match category:
		&"forge":
			show_forge_debug = enabled
		&"dungeon":
			show_dungeon_debug = enabled
		&"minigame":
			show_minigame_debug = enabled
		&"audio":
			show_audio_debug = enabled
		&"crafting":
			show_crafting_debug = enabled
		&"combat":
			show_combat_debug = enabled
		_:
			push_warning("DebugManager: Unknown category '%s'" % category)
	
	print("DebugManager: Category '%s' %s" % [category, "enabled" if enabled else "disabled"])

## Activa todas las categorías
func enable_all() -> void:
	show_forge_debug = true
	show_dungeon_debug = true
	show_minigame_debug = true
	show_audio_debug = true
	show_crafting_debug = true
	show_combat_debug = true
	print("DebugManager: All categories enabled")

## Desactiva todas las categorías
func disable_all() -> void:
	show_forge_debug = false
	show_dungeon_debug = false
	show_minigame_debug = false
	show_audio_debug = false
	show_crafting_debug = false
	show_combat_debug = false
	print("DebugManager: All categories disabled")

func _print_colored(message: String, _color: String) -> void:
	var prefix = ""
	if timestamp_logs:
		var time_dict = Time.get_time_dict_from_system()
		prefix = "[%02d:%02d:%02d] " % [time_dict.hour, time_dict.minute, time_dict.second]
	
	# ANSI colors disabled for Godot compatibility
	print(prefix + message)
