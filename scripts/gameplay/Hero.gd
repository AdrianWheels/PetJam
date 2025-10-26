extends CharacterBody2D

signal stats_reset
signal died
signal respawned
signal hit_frame_reached  # Emitida cuando se alcanza el frame de golpe en animación

const BASE_HP := 60
const BASE_DMG := 6.0
const BASE_APS := 1.0
const BASE_STR := 10
const BASE_AGI := 10
const BASE_INT := 8
const PULSE_INTERVAL := 2.5

var STR: int = BASE_STR
var AGI: int = BASE_AGI
var INT: int = BASE_INT

var max_hp: int = BASE_HP
var hp: int = BASE_HP
var dmg: float = BASE_DMG
var aps: float = BASE_APS
var crit_p: float = 0.0
var crit_m: float = 1.5
var armor: int = 0  # Armadura del héroe (proveniente de equipamiento)
var atk_timer: float = 0.0
var pulse_timer: float = PULSE_INTERVAL
var alive: bool = true
var is_attacking: bool = false  # Flag para mostrar animación de ataque
var debug_invincible: bool = false  # Toggle de invencibilidad para debug
var stored_hp: int = 0  # Backup de HP pre-invencibilidad
var stored_dmg: float = 0.0  # Backup de DMG pre-invencibilidad

var size: Vector2 = Vector2(280, 380)  # Tamaño del CollisionShape2D
var loadout_bonus: Dictionary = {}

# Animación
enum AnimState { IDLE, WALK, ATTACK, DEATH }
var current_anim_state: AnimState = AnimState.WALK
var animation_timer: float = 0.0
var current_frame: int = 0
var death_hold_timer: float = 0.0
const DEATH_HOLD_DURATION: float = 2.5  # Pausa de 2.5s antes de reiniciar loop de muerte
var _hit_frame_triggered: bool = false  # Flag para evitar múltiples hits por ciclo

# Configuración de animaciones (usar 12fps para balance calidad/tamaño)
# Nota: Las texturas se cargarán dinámicamente en _ready()
var anim_config := {}

@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var sprite: Sprite2D = $Sprite if has_node("Sprite") else null

func _ready():
	_setup_animations()
	respawn()
	_update_health_bar()
	_change_animation(AnimState.WALK)
	print("Hero: Ready at position %v, z_index=%d, visible=%s" % [position, z_index, visible])

func _setup_animations() -> void:
	"""Cargar texturas de animaciones dinámicamente"""
	anim_config = {
		AnimState.IDLE: {
			"texture": load("res://art/assets/Spritesheets/Hero/hero_walk_01_12fps.png"),
			"hframes": 63,
			"fps": 24.0,  # Reproducir a 24fps para animación más fluida
			"start_frame": 10,  # Recortar primeros 10 frames
			"end_frame": 52  # Recortar últimos 10 frames (63-10-1)
		},
		AnimState.WALK: {
			"texture": load("res://art/assets/Spritesheets/Hero/hero_walk_01_12fps.png"),
			"hframes": 63,
			"fps": 24.0,
			"start_frame": 10,  # Recortar primeros 10 frames
			"end_frame": 52  # Recortar últimos 10 frames
		},
		AnimState.ATTACK: {
			"texture": load("res://art/assets/Spritesheets/Hero/hero_attack_01_12fps.png"),
			"hframes": 62,
			"fps": 24.0,  # Se ajustará dinámicamente según APS
			"hit_frame": 29,  # Frame donde ocurre el golpe visual (frames 28-30)
			"start_frame": 0,
			"end_frame": 61
		},
		AnimState.DEATH: {
			"texture": load("res://art/assets/Spritesheets/Hero/hero_death_12fps.png"),
			"hframes": 64,
			"fps": 24.0,  # Muerte fluida
			"start_frame": 0,
			"end_frame": 63
		}
	}

func _process(delta: float) -> void:
	# Sistema de animación con múltiples estados
	if not sprite or anim_config.is_empty():
		return
	
	# DEBUG: Estado de animación
	var debug_state = "alive=%s, is_attacking=%s, current_anim=%s" % [alive, is_attacking, AnimState.keys()[current_anim_state]]
	if Engine.get_frames_drawn() % 60 == 0:  # Cada 60 frames (~1 segundo)
		if has_node("/root/DebugManager"):
			get_node("/root/DebugManager").log_dungeon("Hero Animation State: %s" % debug_state)
	
	# Actualizar estado de animación según contexto
	if not alive:
		if current_anim_state != AnimState.DEATH:
			print("Hero: Changing to DEATH animation")
			_change_animation(AnimState.DEATH)
	elif is_attacking:
		if current_anim_state != AnimState.ATTACK:
			print("Hero: Changing to ATTACK animation (is_attacking=true)")
			_change_animation(AnimState.ATTACK)
	else:
		# Si está quieto (velocidad ~0), usar IDLE; si avanza, usar WALK
		var target_anim = AnimState.IDLE if velocity.length() < 1.0 else AnimState.WALK
		if current_anim_state != target_anim:
			var anim_name = "IDLE" if target_anim == AnimState.IDLE else "WALK"
			print("Hero: Changing to %s animation (is_attacking=false, velocity=%.1f)" % [anim_name, velocity.length()])
			_change_animation(target_anim)
	
	# Animar el spritesheet actual
	var config = anim_config[current_anim_state]
	animation_timer += delta
	var frame_duration = 1.0 / config["fps"]
	
	if animation_timer >= frame_duration:
		animation_timer -= frame_duration
		
		var prev_frame = current_frame
		var start_frame = config.get("start_frame", 0)
		var end_frame = config.get("end_frame", config["hframes"] - 1)
		
		# Caso especial: muerte con pausa antes de loop
		if current_anim_state == AnimState.DEATH:
			if current_frame < end_frame:
				current_frame += 1
			else:
				# Esperar 2.5s en el último frame antes de reiniciar
				death_hold_timer += frame_duration
				if death_hold_timer >= DEATH_HOLD_DURATION:
					current_frame = start_frame
					death_hold_timer = 0.0
		else:
			# Loop con respeto a start_frame y end_frame
			current_frame += 1
			if current_frame > end_frame:
				current_frame = start_frame
		
		sprite.frame = current_frame
		
		# Detectar hit frame y emitir señal (solo en ATTACK, una vez por animación)
		if current_anim_state == AnimState.ATTACK and "hit_frame" in config:
			var hit_frame = config["hit_frame"]
			
			# Si alcanzamos hit_frame y no hemos disparado aún
			if prev_frame != hit_frame and current_frame == hit_frame and not _hit_frame_triggered:
				print("Hero: ✨ HIT FRAME REACHED! Emitting signal")
				emit_signal("hit_frame_reached")
				_hit_frame_triggered = true  # Marcar como disparado
			
			# Resetear flag y terminar ataque SOLO si ya emitimos señal
			if current_frame == start_frame and _hit_frame_triggered:
				_hit_frame_triggered = false
				# Terminar ataque tras completar el ciclo de animación
				if is_attacking:
					print("Hero: Attack animation cycle complete (after hit), resetting is_attacking")
					is_attacking = false

func _change_animation(new_state: AnimState) -> void:
	"""Cambia la animación actual y resetea el frame"""
	if current_anim_state == new_state or anim_config.is_empty():
		return
	
	current_anim_state = new_state
	var config = anim_config[new_state]
	current_frame = config.get("start_frame", 0)  # Iniciar en start_frame
	animation_timer = 0.0
	death_hold_timer = 0.0
	_hit_frame_triggered = false  # Resetear flag al cambiar animación
	
	# Ajustar FPS dinámicamente para ATTACK según APS
	if new_state == AnimState.ATTACK:
		config["fps"] = _calculate_attack_fps()
	
	if sprite:
		sprite.texture = config["texture"]
		sprite.hframes = config["hframes"]
		sprite.frame = current_frame  # Usar start_frame
		
		# Calcular escala del sprite para que ocupe ~20% del viewport height (1920*0.20 = 384px)
		# Hero target: 226x345px en pantalla
		if config["texture"]:
			var frame_width = float(config["texture"].get_width()) / float(config["hframes"])
			var frame_height = float(config["texture"].get_height())
			var target_size = Vector2(226, 345)  # 20% viewport para Hero
			var sprite_scale = Vector2(target_size.x / frame_width, target_size.y / frame_height)
			sprite.scale = sprite_scale
		
		# DEBUG: Activado permanentemente
		print("Hero: Changed animation to %s (hframes=%d, fps=%.1f, sprite.scale=%v)" % [AnimState.keys()[new_state], config["hframes"], config["fps"], sprite.scale])

func _calculate_attack_fps() -> float:
	"""Calcula FPS de animación de ataque para que coincida con APS.
	La animación debe durar exactamente 1/APS segundos para sincronizar con el daño."""
	var attack_duration = 1.0 / aps  # Duración de 1 golpe en segundos
	var total_frames = float(anim_config[AnimState.ATTACK]["hframes"])
	var required_fps = total_frames / attack_duration
	# Clampear entre 12fps (mínimo legible) y 60fps (máximo smooth)
	return clamp(required_fps, 12.0, 60.0)

func reset_stats():
	# Obtener bonuses del equipamiento
	var equipment_stats = {}
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager and inv_manager.has_method("calculate_total_stats"):
		equipment_stats = inv_manager.calculate_total_stats()
	
	# Bonuses de stats primarios (STR, AGI, INT)
	var bonus_str: int = int(loadout_bonus.get("STR", 0)) + int(equipment_stats.get("str", 0))
	var bonus_agi: int = int(loadout_bonus.get("AGI", 0)) + int(equipment_stats.get("agi", 0))
	var bonus_int: int = int(loadout_bonus.get("INT", 0)) + int(equipment_stats.get("int", 0))
	STR = BASE_STR + bonus_str
	AGI = BASE_AGI + bonus_agi
	INT = BASE_INT + bonus_int
	
	# Bonuses de stats derivados
	var bonus_hp: int = int(loadout_bonus.get("HP", 0)) + int(equipment_stats.get("hp", 0))
	var bonus_dmg: float = float(loadout_bonus.get("DMG", 0.0)) + float(equipment_stats.get("damage", 0))
	var bonus_aps: float = float(loadout_bonus.get("APS", 0.0)) + float(equipment_stats.get("aps", 0.0))
	var bonus_crit_p: float = float(loadout_bonus.get("CRIT_P", 0.0)) + float(equipment_stats.get("crit", 0.0))
	var bonus_crit_m: float = float(loadout_bonus.get("CRIT_M", 0.0))
	var bonus_armor: int = int(equipment_stats.get("armor", 0))  # NUEVO: armor reduce daño
	
	max_hp = BASE_HP + STR * 10 + bonus_hp
	hp = max_hp
	dmg = BASE_DMG + STR * 1.5 + bonus_dmg
	aps = clamp(BASE_APS + AGI * 0.02 + bonus_aps, 0.3, 5.0)
	crit_p = clamp(AGI * 0.005 + bonus_crit_p, 0.0, 0.75)
	crit_m = clamp(1.5 + INT * 0.01 + bonus_crit_m, 1.0, 3.0)
	armor = bonus_armor  # Aplicar armor del equipamiento
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	alive = true
	
	emit_signal("stats_reset")
	print("Hero: Stats reset - HP:%d DMG:%.1f APS:%.2f CRIT:%.1f%% ARMOR:%d" % [max_hp, dmg, aps, crit_p * 100, armor])

func expected_dps() -> float:
		var hit = dmg * (1.0 + crit_p * (crit_m - 1.0))
		var pulse_dmg = (INT * 3.0) / PULSE_INTERVAL
		return aps * hit + pulse_dmg

func take_damage(amount: int, _is_pulse: bool = false):
	# Debug: invencibilidad activa ignora daño (10k HP lo absorbe todo)
	if debug_invincible:
		return
	if not alive:
		return
	hp = max(0, hp - amount)
	_update_health_bar()
	if hp == 0:
		alive = false
		emit_signal("died")

## Activa/desactiva invencibilidad (solo debug)
func set_invincible(invincible: bool) -> void:
	debug_invincible = invincible
	if invincible:
		# Backup stats y setear 10k HP + 10k ATK
		stored_hp = hp
		stored_dmg = dmg
		hp = 10000
		max_hp = 10000
		dmg = 10000.0
		_update_health_bar()
		print("Hero: Invincibility ENABLED (10k HP, 10k ATK)")
	else:
		# Restaurar stats originales
		hp = stored_hp if stored_hp > 0 else BASE_HP
		max_hp = BASE_HP
		dmg = stored_dmg if stored_dmg > 0 else BASE_DMG
		_update_health_bar()
		print("Hero: Invincibility DISABLED (stats restored)")

func attack(target, _particles: Array) -> void:
	"""Gestiona timer de ataque. Cuando llega a 0, lanza animación ATTACK."""
	if not alive or target == null or not target.alive:
		if is_attacking:
			print("Hero: Stopping attack (not alive or no target), setting is_attacking=false")
		is_attacking = false
		return
	
	# Decrementar timer continuamente
	atk_timer -= get_process_delta_time()
	
	# Si timer llega a 0 o menos, lanzar animación de ataque
	if atk_timer <= 0.0:
		if not is_attacking:
			print("Hero: Timer ready (%.2fs), launching ATTACK animation" % atk_timer)
			is_attacking = true
			_change_animation(AnimState.ATTACK)
		# Resetear timer para próximo ataque
		atk_timer = 1.0 / aps

func pulse(target, particles: Array) -> void:
		if not alive or target == null or not target.alive:
				return
		pulse_timer -= get_process_delta_time()
		if pulse_timer <= 0.0:
				pulse_timer += PULSE_INTERVAL
				target.take_damage(INT * 3, true)
				particles.append(_create_pulse_particle(target.position))

func prepare_for_combat() -> void:
	# Timer empieza lleno, fuerza espera antes del primer ataque
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	is_attacking = false  # Reset explícito

func respawn(start_position: Vector2 = Vector2(2100, 1120)) -> void:
	reset_stats()
	position = start_position
	velocity = Vector2.ZERO
	alive = true
	# CRÍTICO: Resetear animación a WALK tras morir
	current_anim_state = AnimState.IDLE  # Forzar cambio
	_change_animation(AnimState.WALK)
	animation_timer = 0.0
	current_frame = 0
	death_hold_timer = 0.0
	print("HERO RESPAWN DEBUG:")
	print("  Start position: ", start_position)
	print("  Hero position: ", position)
	print("  Hero global_position: ", global_position)
	if get_parent():
		print("  Parent: ", get_parent().name)
		print("  Parent position: ", get_parent().position if get_parent() is Node2D else "N/A")
	emit_signal("respawned")

func apply_loadout(loadout: Dictionary) -> void:
		loadout_bonus = loadout.duplicate(true)
		reset_stats()

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
		floating_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))  # Blanco para daño normal
		floating_label.add_theme_font_size_override("font_size", 20)
	
	# Posicionar sobre el personaje
	floating_label.global_position = global_position + Vector2(randf_range(-20, 20), -40)
	
	# Añadir al árbol (en root para que no se mueva con el personaje)
	get_tree().root.add_child(floating_label)

func _update_health_bar() -> void:
		if health_bar:
				health_bar.max_value = max_hp
				health_bar.value = hp
				
				# Color según vida restante
				var hp_ratio = float(hp) / float(max_hp) if max_hp > 0 else 0.0
				if hp_ratio > 0.6:
						health_bar.modulate = Color(0.3, 1.0, 0.3)  # Verde
				elif hp_ratio > 0.3:
						health_bar.modulate = Color(1.0, 0.7, 0.3)  # Naranja
				else:
						health_bar.modulate = Color(1.0, 0.3, 0.3)  # Rojo
