extends Resource

## High level crafting recipe definition consumed by the UI and DataManager.
class_name BlueprintResource

@export var blueprint_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_file("*.png", "*.svg", "*.webp", "*.tres") var icon_path: String = ""
@export var icon: Texture2D  ## Icono del item resultante (como siempre)
@export var blueprint_icon: Texture2D  ## Icono del blueprint para mostrar en la cola de pedidos
@export var result_item: StringName = &""
@export var min_score: float = 0.0
@export var materials: Dictionary = {}
@export var trial_sequence: Array = []
@export var tags: PackedStringArray = []

var _icon_cache: Texture2D

func get_material_quantity(material_id: StringName) -> int:
	return int(materials.get(material_id, 0))

func has_trials() -> bool:
	return not trial_sequence.is_empty()

func get_icon() -> Texture2D:
	# PRIORIDAD 1: Si icon ya está cargado como objeto, usarlo directamente
	if icon:
		# Caso A: Ya es un Texture2D directo
		if icon is Texture2D:
			_icon_cache = icon
			return _icon_cache
		# Caso B: Es un ItemResource con método get_icon()
		elif icon.has_method("get_icon"):
			_icon_cache = icon.get_icon()
			return _icon_cache
	
	# PRIORIDAD 2: Si ya tenemos cache, devolverlo
	if _icon_cache:
		return _icon_cache
	
	# PRIORIDAD 3: Cargar desde icon_path solo si icon no existe
	if icon_path == "":
		return null
	
	# Intentar cargar el recurso
	if not ResourceLoader.exists(icon_path):
		push_warning("BlueprintResource %s icon path missing: %s" % [blueprint_id, icon_path])
		return null
	
	var loaded_resource = ResourceLoader.load(icon_path)
	if not loaded_resource:
		push_warning("BlueprintResource %s failed to load icon: %s" % [blueprint_id, icon_path])
		return null
	
	# Determinar el tipo de recurso cargado
	if loaded_resource is Texture2D:
		_icon_cache = loaded_resource
		return _icon_cache
	elif loaded_resource.has_method("get_icon"):
		# Es un ItemResource u otro recurso con get_icon()
		_icon_cache = loaded_resource.get_icon()
		return _icon_cache
	else:
		push_warning("BlueprintResource %s icon at %s is not a Texture2D or ItemResource" % [blueprint_id, icon_path])
		return null

func get_blueprint_icon() -> Texture2D:
	"""Devuelve el icono del blueprint para mostrar en la cola de pedidos"""
	return blueprint_icon if blueprint_icon else get_icon()
