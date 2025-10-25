extends Node2D
class_name DungeonLayout

# Script para gestionar el layout visual de la dungeon
# Proporciona posiciones de spawn para los 9 niveles de enemigo

@export var room_zones: Node2D

const FALLBACK_SPAWN := Vector2(620, 460)
const ROOM_SPACING := 600.0

func _ready() -> void:
	if room_zones == null:
		room_zones = get_node_or_null("RoomZones")
	print("DungeonLayout: Ready with %d room zones" % (room_zones.get_child_count() if room_zones else 0))
	
	# Ocultar ZoneRect y SpawnMarker en runtime (solo para editor)
	if room_zones:
		for room in room_zones.get_children():
			var zone_rect = room.get_node_or_null("ZoneRect")
			if zone_rect:
				zone_rect.visible = false
			var room_label = room.get_node_or_null("RoomLabel")
			if room_label:
				room_label.visible = false
			var enemy_spawn = room.get_node_or_null("EnemySpawn")
			if enemy_spawn:
				var spawn_marker = enemy_spawn.get_node_or_null("SpawnMarker")
				if spawn_marker:
					spawn_marker.visible = false

func get_enemy_spawn_for_level(level: int) -> Vector2:
	"""Obtiene la posición de spawn para el enemigo del nivel especificado.
	Devuelve posición LOCAL (relativa a DungeonLayout), no global."""
	if room_zones == null:
		push_warning("DungeonLayout: RoomZones not found, using fallback position")
		return FALLBACK_SPAWN + Vector2((level - 1) * ROOM_SPACING, 0)
	
	var room_count := room_zones.get_child_count()
	if level <= 0 or level > room_count:
		push_warning("DungeonLayout: Invalid level %d, using fallback" % level)
		return FALLBACK_SPAWN + Vector2((level - 1) * ROOM_SPACING, 0)
	
	# Obtener zona de la sala (índice 0-based)
	var zone := room_zones.get_child(level - 1)
	if zone == null:
		return FALLBACK_SPAWN + Vector2((level - 1) * ROOM_SPACING, 0)
	
	# Buscar marker de spawn en la zona
	var spawn_marker := zone.get_node_or_null("EnemySpawn")
	if spawn_marker and spawn_marker is Marker2D:
		# Convertir de global a local respecto a DungeonLayout
		return to_local(spawn_marker.global_position)
	
	# Si no hay marker, usar posición de la zona (local)
	return to_local(zone.global_position)

func get_hero_spawn() -> Vector2:
	"""Obtiene la posición inicial del héroe.
	Devuelve posición LOCAL (relativa a DungeonLayout), no global."""
	var hero_spawn := get_node_or_null("HeroSpawn")
	if hero_spawn and hero_spawn is Marker2D:
		# Convertir de global a local respecto a DungeonLayout
		return to_local(hero_spawn.global_position)
	# Fallback a posición predeterminada
	return Vector2(100, 460)

func is_boss_level(level: int) -> bool:
	"""Verifica si el nivel corresponde al jefe."""
	return level >= 9

func get_room_zone(level: int) -> Area2D:
	"""Obtiene la zona de sala para el nivel especificado."""
	if room_zones == null:
		return null
	var room_count := room_zones.get_child_count()
	if level <= 0 or level > room_count:
		return null
	var zone := room_zones.get_child(level - 1)
	return zone as Area2D
