extends PanelContainer

## Panel de control de debug flotante
## Permite activar/desactivar categorías de debug y contextos de audio en runtime

@onready var chk_show_all: CheckButton = %ChkShowAll
@onready var chk_forge_debug: CheckBox = %ChkForgeDebug
@onready var chk_dungeon_debug: CheckBox = %ChkDungeonDebug
@onready var chk_minigame_debug: CheckBox = %ChkMinigameDebug
@onready var chk_combat_debug: CheckBox = %ChkCombatDebug
@onready var chk_forge_audio: CheckBox = %ChkForgeAudio
@onready var chk_dungeon_audio: CheckBox = %ChkDungeonAudio

func _ready():
	# Sincronizar estado inicial con managers
	_sync_initial_state()
	
	# Conectar señales
	chk_show_all.toggled.connect(_on_show_all_toggled)
	chk_forge_debug.toggled.connect(_on_forge_debug_toggled)
	chk_dungeon_debug.toggled.connect(_on_dungeon_debug_toggled)
	chk_minigame_debug.toggled.connect(_on_minigame_debug_toggled)
	chk_combat_debug.toggled.connect(_on_combat_debug_toggled)
	chk_forge_audio.toggled.connect(_on_forge_audio_toggled)
	chk_dungeon_audio.toggled.connect(_on_dungeon_audio_toggled)
	
	# Ocultar por defecto, activar con Shift+P
	visible = false
	print("DebugPanel: Ready (press Shift+P to toggle visibility)")

func _sync_initial_state() -> void:
	"""Sincroniza checkboxes con estado actual de los managers"""
	# Esperar un frame para que los autoloads estén listos
	await get_tree().process_frame
	
	if has_node("/root/DebugManager"):
		var dm = get_node("/root/DebugManager")
		chk_forge_debug.button_pressed = dm.show_forge_debug
		chk_dungeon_debug.button_pressed = dm.show_dungeon_debug
		chk_minigame_debug.button_pressed = dm.show_minigame_debug
		chk_combat_debug.button_pressed = dm.show_combat_debug
	else:
		print("DebugPanel: WARNING - DebugManager not registered as AutoLoad")
		print("  See doc/REGISTRO_AUTOLOADS.md for instructions")
	
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("is_context_enabled"):
			chk_forge_audio.button_pressed = am.is_context_enabled(am.AudioContext.FORGE)
			chk_dungeon_audio.button_pressed = am.is_context_enabled(am.AudioContext.DUNGEON)
		else:
			print("DebugPanel: AudioManager doesn't have context support yet")

func _input(event: InputEvent) -> void:
	# Toggle visibility con Shift+P
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P and event.shift_pressed:
			visible = not visible
			if visible:
				print("DebugPanel: Shown (Shift+P)")
			else:
				print("DebugPanel: Hidden (Shift+P)")
			accept_event()

func _on_show_all_toggled(active: bool) -> void:
	"""Activa/desactiva todas las categorías a la vez"""
	if has_node("/root/DebugManager"):
		var dm = get_node("/root/DebugManager")
		if active:
			dm.enable_all()
		else:
			dm.disable_all()
		_sync_initial_state()  # Refrescar checkboxes
		print("DebugPanel: Show All = %s" % active)
	else:
		print("DebugPanel: Cannot toggle - DebugManager not registered")

func _on_forge_debug_toggled(active: bool) -> void:
	if has_node("/root/DebugManager"):
		get_node("/root/DebugManager").set_category_enabled(&"forge", active)
		print("DebugPanel: Forge Debug = %s" % active)
	else:
		print("DebugPanel: Cannot toggle - DebugManager not registered")

func _on_dungeon_debug_toggled(active: bool) -> void:
	if has_node("/root/DebugManager"):
		get_node("/root/DebugManager").set_category_enabled(&"dungeon", active)
		print("DebugPanel: Dungeon Debug = %s" % active)
	else:
		print("DebugPanel: Cannot toggle - DebugManager not registered")

func _on_minigame_debug_toggled(active: bool) -> void:
	if has_node("/root/DebugManager"):
		get_node("/root/DebugManager").set_category_enabled(&"minigame", active)
		print("DebugPanel: Minigame Debug = %s" % active)
	else:
		print("DebugPanel: Cannot toggle - DebugManager not registered")

func _on_combat_debug_toggled(active: bool) -> void:
	if has_node("/root/DebugManager"):
		get_node("/root/DebugManager").set_category_enabled(&"combat", active)
		print("DebugPanel: Combat Debug = %s" % active)
	else:
		print("DebugPanel: Cannot toggle - DebugManager not registered")

func _on_forge_audio_toggled(active: bool) -> void:
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("set_context_enabled"):
			am.set_context_enabled(am.AudioContext.FORGE, active)
			print("DebugPanel: Forge Audio = %s" % active)
		else:
			print("DebugPanel: AudioManager doesn't support contexts yet")
	else:
		print("DebugPanel: AudioManager not found")

func _on_dungeon_audio_toggled(active: bool) -> void:
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("set_context_enabled"):
			am.set_context_enabled(am.AudioContext.DUNGEON, active)
			print("DebugPanel: Dungeon Audio = %s" % active)
		else:
			print("DebugPanel: AudioManager doesn't support contexts yet")
	else:
		print("DebugPanel: AudioManager not found")
