extends CharacterBody2D

signal stats_reset
signal died(drops)
signal hit_frame_reached  # Emitida cuando se alcanza el frame de golpe en animación

const BASE_HP := 40
const BASE_DMG := 5.0
const BASE_APS := 0.8
const PULSE_INTERVAL := 2.5
const BOSS_LEVEL_MULTIPLIER := 1.6

var level: int = 1
var STR: float = 0.0
var AGI: float = 0.0
var INT: float = 0.0

var max_hp: int = BASE_HP
var hp: int = BASE_HP
var dmg: float = BASE_DMG
var aps: float = BASE_APS
var crit_p: float = 0.0
var crit_m: float = 1.5
var atk_timer: float = 0.0
var pulse_timer: float = PULSE_INTERVAL
var alive: bool = true
var is_attacking: bool = false  # Flag para mostrar animación de ataque

var size: Vector2 = Vector2(350, 500)  # Tamaño del CollisionShape2D
var shape: String = "rect"

@export var is_boss: bool = false
@export var drop_table: DropTable

var _rng := RandomNumberGenerator.new()

# Animación
enum AnimState { IDLE, ATTACK, DEATH }
var current_anim_state: AnimState = AnimState.IDLE
var animation_timer: float = 0.0
var current_frame: int = 0
var death_hold_timer: float = 0.0
const DEATH_HOLD_DURATION: float = 2.5
var _hit_frame_triggered: bool = false  # Flag para evitar múltiples hits por ciclo

var anim_config := {}

const DEFAULT_DROP_TABLE := preload("res://data/drops/basic_enemy_drop.tres")

@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var level_label: Label = $LevelLabel if has_node("LevelLabel") else null
@onready var sprite_node: Node = $Sprite if has_node("Sprite") else null

func _ready():
	if drop_table == null:
		drop_table = DEFAULT_DROP_TABLE
	_rng.randomize()
	_setup_animations()
	reset_stats()
	_update_visuals()
	print("Enemy: Ready at position %v, z_index=%d, visible=%s, level=%d" % [position, z_index, visible, level])

func _setup_animations() -> void:
	"""Cargar animaciones según tipo (grunt para normal, tank para boss)"""
	var type := "tank" if is_boss else "grunt"
	
	# Configuración optimizada: grunt sin frames F0-F3 y F58-F61
	var grunt_start_frame := 4  # Empezar desde F4
	
	# Hit frames diferenciados por tipo
	var hit_frame := 40 if is_boss else 29  # Boss: 40, Grunt: 29
	
	anim_config = {
		AnimState.IDLE: {
			"texture": load("res://art/assets/Spritesheets/Enemies/%s_attack_12fps.png" % type),
			"hframes": 62,
			"fps": 0.0,  # 0 fps = estático
			"loop": false,
			"start_frame": (grunt_start_frame if not is_boss else 0)
		},
		AnimState.ATTACK: {
			"texture": load("res://art/assets/Spritesheets/Enemies/%s_attack_12fps.png" % type),
			"hframes": 62,
			"fps": 24.0,  # Se ajustará dinámicamente según APS
			"loop": true,
			"start_frame": (grunt_start_frame if not is_boss else 0),
			"end_frame": (57 if not is_boss else 61),  # grunt termina en F57, tank en F61
			"hit_frame": hit_frame  # Frame donde ocurre el golpe visual
		},
		AnimState.DEATH: {
			"texture": load("res://art/assets/Spritesheets/Enemies/%s_death_12fps.png" % type),
			"hframes": 64,
			"fps": 24.0,  # 24fps para muerte fluida
			"loop": false,
			"start_frame": 0,
			"end_frame": 63
		}
	}
	
	# Convertir ColorRect en Sprite2D si es necesario
	if sprite_node and sprite_node is ColorRect:
		var old_sprite = sprite_node
		sprite_node = Sprite2D.new()
		sprite_node.name = "Sprite"
		sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite_node)
		old_sprite.queue_free()
	
	# CRÍTICO: Aplicar animación IDLE inicial con escala correcta
	call_deferred("_change_animation", AnimState.IDLE)

func _process(delta: float) -> void:
	"""Sistema de animación para enemigos"""
	if not sprite_node or not sprite_node is Sprite2D or anim_config.is_empty():
		return
	
	# DEBUG: Estado de animación
	if Engine.get_frames_drawn() % 60 == 0:  # Cada 60 frames (~1 segundo)
		print("Enemy Animation State: alive=%s, is_attacking=%s, current_anim=%s" % [alive, is_attacking, AnimState.keys()[current_anim_state]])
	
	# Determinar estado de animación
	var target_state := AnimState.IDLE
	if not alive:
		target_state = AnimState.DEATH
	elif is_attacking:
		target_state = AnimState.ATTACK
	
	if target_state != current_anim_state:
		print("Enemy: Changing animation from %s to %s" % [AnimState.keys()[current_anim_state], AnimState.keys()[target_state]])
		_change_animation(target_state)
	
	# Animar solo si el FPS > 0
	var config = anim_config[current_anim_state]
	if config["fps"] <= 0.0:
		return
	
	animation_timer += delta
	var frame_duration = 1.0 / config["fps"]
	
	if animation_timer >= frame_duration:
		animation_timer -= frame_duration
		
		var prev_frame = current_frame
		
		# Muerte: pausa en último frame
		if current_anim_state == AnimState.DEATH:
			if current_frame < config["hframes"] - 1:
				current_frame += 1
			else:
				death_hold_timer += frame_duration
				if death_hold_timer >= DEATH_HOLD_DURATION:
					# Mantener en último frame (no reiniciar)
					pass
		# Loop normal
		elif config["loop"]:
			current_frame = (current_frame + 1) % config["hframes"]
		# Sin loop: quedarse en último frame
		else:
			current_frame = min(current_frame + 1, config["hframes"] - 1)
		
		sprite_node.frame = current_frame
		
		# Detectar hit frame y emitir señal (solo en ATTACK, una vez por ciclo)
		if current_anim_state == AnimState.ATTACK and "hit_frame" in config:
			var hit_frame = config["hit_frame"]
			var start_frame = config.get("start_frame", 0)
			
			# Si alcanzamos hit_frame y no hemos disparado aún
			if prev_frame != hit_frame and current_frame == hit_frame and not _hit_frame_triggered:
				print("Enemy: ✨ HIT FRAME REACHED! Emitting signal")
				emit_signal("hit_frame_reached")
				_hit_frame_triggered = true  # Marcar como disparado
			
			# Resetear flag y terminar ataque SOLO si ya emitimos señal
			if current_frame == start_frame and _hit_frame_triggered:
				_hit_frame_triggered = false
				# Terminar ataque tras completar el ciclo de animación
				if is_attacking:
					print("Enemy: Attack animation cycle complete (after hit), resetting is_attacking")
					is_attacking = false

func _change_animation(new_state: AnimState) -> void:
	"""Cambiar animación del enemigo"""
	if current_anim_state == new_state or anim_config.is_empty():
		return
	
	current_anim_state = new_state
	current_frame = 0
	animation_timer = 0.0
	death_hold_timer = 0.0
	_hit_frame_triggered = false  # Resetear flag al cambiar animación
	
	var config = anim_config[new_state]
	
	# Ajustar FPS dinámicamente para ATTACK según APS
	if new_state == AnimState.ATTACK:
		config["fps"] = _calculate_attack_fps()
	
	if sprite_node and sprite_node is Sprite2D:
		sprite_node.texture = config["texture"]
		sprite_node.hframes = config["hframes"]
		sprite_node.frame = 0
		# Enemy debe ser ~1.3x más grande que Hero
		# Hero: 226x345, Enemy: 297x449 (1.31x ratio)
		if config["texture"]:
			var tex_width = config["texture"].get_width() / config["hframes"]
			var tex_height = config["texture"].get_height()
			var target_size = Vector2(297, 449)  # 1.3x Hero size
			var sprite_scale = Vector2(target_size.x / tex_width, target_size.y / tex_height)
			sprite_node.scale = sprite_scale
		# DEBUG: Activado permanentemente
		print("Enemy: Changed animation to %s (hframes=%d, fps=%.1f, sprite.scale=%v, is_boss=%s)" % [AnimState.keys()[new_state], config["hframes"], config["fps"], sprite_node.scale, is_boss])

func _calculate_attack_fps() -> float:
	"""Calcula FPS de animación de ataque para que coincida con APS.
	La animación debe durar exactamente 1/APS segundos para sincronizar con el daño."""
	var attack_duration = 1.0 / aps  # Duración de 1 golpe en segundos
	var total_frames = float(anim_config[AnimState.ATTACK]["hframes"])
	var required_fps = total_frames / attack_duration
	# Clampear entre 12fps (mínimo legible) y 60fps (máximo smooth)
	return clamp(required_fps, 12.0, 60.0)

func configure_for_level(lv: int, boss: bool) -> void:
	level = lv
	is_boss = boss
	_setup_animations()  # Recargar animaciones según tipo
	reset_stats()
	_update_visuals()

func reset_stats():
	# Escala MUCHO más agresiva - necesitas crafteo para avanzar
	STR = 3.0 + level * 2.5  # Era 1.4, ahora 2.5
	AGI = 1.5 + level * 1.2  # Era 0.8, ahora 1.2
	INT = 1.5 + level * 0.9  # Era 0.6, ahora 0.9
	var multiplier := (BOSS_LEVEL_MULTIPLIER if is_boss else 1.0)
	# HP escala mucho más: nivel 1 = 40, nivel 2 = 72, nivel 3 = 112
	var base_hp := BASE_HP * (1.0 + (level - 1) * 0.8) * multiplier  # Era 0.15, ahora 0.8
	max_hp = int(base_hp)
	hp = max_hp
	dmg = (BASE_DMG + STR * 1.8) * multiplier  # Era 1.5, ahora 1.8
	aps = clamp(BASE_APS + AGI * 0.03, 0.3, 5.0)  # Era 0.02, ahora 0.03
	crit_p = min(0.5, AGI * 0.008)  # Era 0.005, ahora 0.008
	crit_m = clamp(1.5 + INT * 0.015, 1.0, 2.5)  # Era 0.01/2.0, ahora 0.015/2.5
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	alive = true
	size = Vector2(40 + min(20, level * 2), 52 + min(18, level * 2))
	shape = "rect" if level % 2 == 0 else "circle"
	print("Enemy: Level %d stats: HP=%d, DMG=%.1f, APS=%.2f (STR=%.1f, AGI=%.1f, INT=%.1f)" % [level, max_hp, dmg, aps, STR, AGI, INT])
	emit_signal("stats_reset")

func expected_dps() -> float:
	var hit = dmg * (1.0 + crit_p * (crit_m - 1.0))
	var pulse_dmg = (INT * 3.0) / PULSE_INTERVAL
	return aps * hit + pulse_dmg

func take_damage(amount: int, _is_pulse: bool = false):
	if not alive:
		return
	hp = max(0, hp - amount)
	_update_health_bar()
	if hp == 0:
		_die()

func attack(target, _particles: Array):
	"""Gestiona timer de ataque. Cuando llega a 0, lanza animación ATTACK."""
	if not alive or target == null or not target.alive:
		if is_attacking:
			print("Enemy: Stopping attack (not alive or no target), setting is_attacking=false")
		is_attacking = false
		return
	
	# Decrementar timer continuamente
	atk_timer -= get_process_delta_time()
	
	# Si timer llega a 0 o menos, lanzar animación de ataque
	if atk_timer <= 0.0:
		if not is_attacking:
			print("Enemy: Timer ready (%.2fs), launching ATTACK animation" % atk_timer)
			is_attacking = true
			_change_animation(AnimState.ATTACK)
		# Resetear timer para próximo ataque
		atk_timer = 1.0 / aps

func pulse(target, particles: Array):
	if not alive or target == null or not target.alive:
		return
	pulse_timer -= get_process_delta_time()
	if pulse_timer <= 0.0:
		pulse_timer += PULSE_INTERVAL
		target.take_damage(int(INT * 3), true)
		particles.append(_create_pulse_particle(target.position))

func prepare_for_combat() -> void:
	# Timer empieza lleno, fuerza espera antes del primer ataque
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	is_attacking = false  # Reset explícito

func generate_drops() -> Array:
	if drop_table == null:
		return []
	
	# Drop de materiales aleatorios
	_drop_random_materials()
	
	return drop_table.roll_drops(_rng)

func _drop_random_materials() -> void:
	"""Dropea 15 unidades de un material aleatorio de los disponibles en blueprints"""
	var dm := get_node_or_null("/root/DataManager")
	if not dm or not dm.has_method("get_all_blueprints"):
		return
	
	# Recopilar todos los materiales únicos de todos los blueprints
	var all_materials: Array[StringName] = []
	var all_blueprints: Dictionary = dm.get_all_blueprints()
	
	for bp_id in all_blueprints:
		var blueprint = all_blueprints[bp_id]
		if blueprint is BlueprintResource and not blueprint.materials.is_empty():
			for mat_id in blueprint.materials.keys():
				if not all_materials.has(mat_id):
					all_materials.append(StringName(mat_id))
	
	if all_materials.is_empty():
		print("Enemy: No materials found in blueprints")
		return
	
	# Elegir material aleatorio y dar 15 unidades (aumentado desde 5 para evitar softlocks)
	var random_material: StringName = all_materials[_rng.randi() % all_materials.size()]
	var drop_amount := 15
	
	var im := get_node_or_null("/root/InventoryManager")
	if im and im.has_method("add_item"):
		im.add_item(random_material, drop_amount)
		print("Enemy: Dropped %d x %s" % [drop_amount, random_material])
	else:
		print("Enemy: InventoryManager not found, cannot drop materials")

func _die() -> void:
	if not alive:
		return
	alive = false
	hp = 0
	is_attacking = false  # CRÍTICO: Resetear al morir para volver a IDLE
	emit_signal("died", generate_drops())

func _create_spark_particle(pos: Vector2) -> Dictionary:
	var angle := randf() * PI * 2.0
	var speed := 80.0 + randf() * 80.0
	return {
		"type": "spark",
		"position": pos,
		"velocity": Vector2(cos(angle), sin(angle)) * speed,
		"timer": 0.35
	}

func _create_pulse_particle(pos: Vector2) -> Dictionary:
	return {
		"type": "pulse",
		"position": pos,
		"timer": 0.35
	}

func _spawn_floating_number(damage: int, is_crit: bool):
	"""Spawner floating number con animación Tween"""
	var floating_label = Label.new()
	floating_label.text = str(damage)
	floating_label.set_script(preload("res://scripts/gameplay/FloatingNumber.gd"))
	
	# Configuración visual
	if is_crit:
		floating_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))  # Dorado para crits
		floating_label.add_theme_font_size_override("font_size", 28)
	else:
		floating_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Rojo para daño al enemigo
		floating_label.add_theme_font_size_override("font_size", 20)
	
	# Posicionar sobre el personaje
	floating_label.global_position = global_position + Vector2(randf_range(-20, 20), -40)
	
	# Añadir al árbol (en root para que no se mueva con el personaje)
	get_tree().root.add_child(floating_label)

func _update_health_bar() -> void:
	if not health_bar:
		return
	health_bar.max_value = max_hp
	health_bar.value = hp
	
	# Color coding basado en % de HP
	var hp_percent := (hp / float(max_hp)) * 100.0
	if hp_percent > 60.0:
		health_bar.modulate = Color.GREEN
	elif hp_percent > 30.0:
		health_bar.modulate = Color.ORANGE
	else:
		health_bar.modulate = Color.RED

func _update_visuals() -> void:
	# Actualizar etiqueta de nivel
	if level_label:
		var text := "Lv %d" % level
		if is_boss:
			text += " BOSS"
		level_label.text = text
	
	# Aplicar tintes de boss (sin tocar sprite.scale - se maneja en _change_animation)
	if sprite_node and sprite_node is Sprite2D:
		# Bosses tienen tinte dorado, normales blanco (sin tinte)
		if is_boss:
			sprite_node.modulate = Color(1.0, 0.85, 0.0)  # Amarillo/Oro
		else:
			sprite_node.modulate = Color.WHITE
	
	# CRÍTICO: Forzar actualización de HP bar al crear enemigo
	_update_health_bar()
