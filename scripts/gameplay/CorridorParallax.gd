# res://scripts/gameplay/CorridorParallax.gd
extends Node2D

## Sistema de parallax para el corredor
## Crea 3 capas que se mueven a diferentes velocidades para dar sensación de profundidad

@export var scroll_speed: float = 1.0

var layers: Array[Dictionary] = []
var scroll_offset: float = 0.0

func _ready() -> void:
	# Layer 1: Fondo lejano (más lento)
	var layer_far := _create_layer(0.2, Color(0.15, 0.12, 0.18))
	# Decoración: antorchas en el fondo
	for i in range(3):
		var torch := ColorRect.new()
		torch.size = Vector2(8, 24)
		torch.color = Color(1.0, 0.5, 0.1)
		torch.position = Vector2(200 + i * 400, 200)
		layer_far.sprite.add_child(torch)
	layers.append(layer_far)
	
	# Layer 2: Medio (velocidad media)
	var layer_mid := _create_layer(0.5, Color(0.2, 0.18, 0.22, 0.7))
	# Decoración: pilares
	for i in range(4):
		var pillar := ColorRect.new()
		pillar.size = Vector2(40, 300)
		pillar.color = Color(0.3, 0.28, 0.32)
		pillar.position = Vector2(150 + i * 350, 200)
		layer_mid.sprite.add_child(pillar)
	layers.append(layer_mid)
	
	# Layer 3: Primer plano (más rápido)
	var layer_near := _create_layer(0.8, Color(0.25, 0.22, 0.27, 0.5))
	# Decoración: ventanas brillantes
	for i in range(5):
		var window := ColorRect.new()
		window.size = Vector2(20, 30)
		window.color = Color(1.0, 0.9, 0.5, 0.6)
		window.position = Vector2(100 + i * 280, 150)
		layer_near.sprite.add_child(window)
	layers.append(layer_near)
	
	print("CorridorParallax: 3 layers created")

func _create_layer(motion_scale: float, bg_color: Color) -> Dictionary:
	"""Crea una capa de parallax con 3 sprites repetidos"""
	var layer_node := Node2D.new()
	layer_node.z_index = -10 + int(motion_scale * 10)  # Capas lentas más atrás
	add_child(layer_node)
	
	var sprites: Array[ColorRect] = []
	# Crear 3 sprites para seamless looping
	for i in range(3):
		var sprite := ColorRect.new()
		sprite.size = Vector2(1280, 720)
		sprite.color = bg_color
		sprite.position.x = i * 1280.0
		layer_node.add_child(sprite)
		sprites.append(sprite)
	
	return {
		"node": layer_node,
		"sprite": sprites[0],  # Referencia al primero para decoración
		"sprites": sprites,
		"motion_scale": motion_scale,
		"width": 1280.0
	}

func _process(_delta: float) -> void:
	# Actualizar posición de cada capa
	for layer in layers:
		var offset: float = scroll_offset * layer.motion_scale
		layer.node.position.x = -offset
		
		# Loop seamless: cuando un sprite sale completamente, moverlo al final
		for sprite in layer.sprites:
			var global_x: float = sprite.global_position.x
			if global_x < -layer.width:
				sprite.position.x += layer.width * 3
			elif global_x > layer.width * 2:
				sprite.position.x -= layer.width * 3

func update_from_corridor(ground_offset: float) -> void:
	"""Actualiza el scroll basándose en el offset del corredor"""
	scroll_offset = ground_offset
