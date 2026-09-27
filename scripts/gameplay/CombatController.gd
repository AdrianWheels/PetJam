extends Node

## Resuelve los golpes del combate por cooldown y dispara su feedback:
## arco de corte, chispas, números de daño en el mundo, shake, hit-stop y sonido con variación.
## La lógica de daño es la de siempre (daño + crítico); la armadura la aplica Hero.take_damage.

signal combat_started
signal combat_finished

const HIT_SFX := [
	preload("res://art/sounds/sfx/combat/atk_sword_flesh_hit_01.wav"),
	preload("res://art/sounds/sfx/combat/atk_sword_flesh_hit_02.wav"),
	preload("res://art/sounds/sfx/combat/atk_sword_flesh_hit_03.wav"),
	preload("res://art/sounds/sfx/combat/atk_sword_flesh_hit_04.wav"),
	preload("res://art/sounds/sfx/combat/atk_sword_flesh_hit_05.wav"),
]
const HURT_SFX := [
	preload("res://art/sounds/sfx/combat/atk_sword_flesh_leather_01.wav"),
	preload("res://art/sounds/sfx/combat/atk_sword_flesh_leather_02.wav"),
	preload("res://art/sounds/sfx/combat/atk_sword_flesh_leather_03.wav"),
	preload("res://art/sounds/sfx/combat/atk_sword_flesh_cloth_01.wav"),
]
const CRIT_SFX := preload("res://art/sounds/sfx/minigames/hammer/hammer_perfect.wav")

const COLOR_SLASH := Color(0.95, 0.97, 1.0, 0.85)
const COLOR_CRIT := Color("ffd23f")
const COLOR_PULSE_HERO := Color("6fe3ff")

@onready var hero: Node = $"../Hero"
@onready var enemy: Node = $"../Enemy"
@onready var corridor: Node = get_parent()
@onready var fx: Node = get_node_or_null("../CombatFX")
@onready var camera: Camera2D = get_node_or_null("../Camera2D")

const CRIT_FX_COOLDOWN := 0.4
## Botín doble (Poción de Suerte): la segunda tanda sale a la vez que la primera, un icono más adelante,
## más rápida hacia delante y con la etiqueta una fila más arriba; su tintineo suena un poco después.
const BONUS_LOOT_AHEAD := 12.0
const BONUS_LOOT_SPEED := Vector2(22.0, 30.0)
const BONUS_LOOT_SOUND_LAG := 0.1

var combat_active := false
var _block_text_cd := 0.0
## Con mucha velocidad y crítico, congelar y sacudir en cada golpe frenaría el avance idle
## y la cámara no pararía: la "fanfarria" completa del crítico tiene enfriamiento.
var _crit_fx_cd := 0.0
var _game_manager: Node
var _inventory_manager: Node
var _audio: Node


func _ready():
	_game_manager = get_node_or_null("/root/GameManager")
	_inventory_manager = get_node_or_null("/root/InventoryManager")
	_audio = get_node_or_null("/root/AudioManager")

	if hero and hero.has_signal("died") and not hero.died.is_connected(_on_hero_died):
		hero.died.connect(_on_hero_died)
	if enemy and enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	if hero and hero.has_signal("attack_triggered"):
		hero.attack_triggered.connect(_on_hero_attack)
	if enemy and enemy.has_signal("attack_triggered"):
		enemy.attack_triggered.connect(_on_enemy_attack)
	if hero and hero.has_signal("pulse_hit"):
		hero.pulse_hit.connect(_on_hero_pulse)
	if enemy and enemy.has_signal("pulse_hit"):
		enemy.pulse_hit.connect(_on_enemy_pulse)


func start_combat():
	if combat_active:
		return
	combat_active = true
	if hero and hero.has_method("prepare_for_combat"):
		hero.prepare_for_combat()
	if enemy and enemy.has_method("prepare_for_combat"):
		enemy.prepare_for_combat()
	emit_signal("combat_started")


func stop_combat():
	if not combat_active:
		return
	combat_active = false
	if hero:
		hero.is_attacking = false
	if enemy:
		enemy.is_attacking = false
	emit_signal("combat_finished")


func _process(delta: float):
	_block_text_cd = maxf(0.0, _block_text_cd - delta)
	_crit_fx_cd = maxf(0.0, _crit_fx_cd - delta)
	if not combat_active or hero == null or enemy == null:
		return
	if not hero.alive or not enemy.alive:
		stop_combat()
		return
	hero.attack(enemy)
	# El golpe puede haber matado al enemigo: el nodo ya está recolocado en la sala siguiente
	if combat_active and enemy.alive:
		hero.pulse(enemy)
	if combat_active and hero.alive and enemy.alive:
		enemy.attack(hero)
		enemy.pulse(hero)
	if not hero.alive or not enemy.alive:
		stop_combat()


func _on_hero_attack():
	if not combat_active or hero == null or enemy == null:
		return
	if not hero.alive or not enemy.alive:
		return
	_execute_hero_attack()


func _on_enemy_attack():
	if not combat_active or hero == null or enemy == null:
		return
	if not hero.alive or not enemy.alive:
		return
	_execute_enemy_attack()


func _execute_hero_attack():
	var damage: float = hero.dmg
	var crit: bool = randf() < hero.crit_p
	if crit:
		damage *= hero.crit_m
	var amount := int(damage)
	# Posiciones ANTES del daño (si muere, el nodo se recoloca en la sala siguiente)
	var center: Vector2 = enemy.body_center()
	var hit_pos := center + Vector2(-enemy.half_width * 0.45, randf_range(-2.0, 2.0))
	var number_pos := center + Vector2(0, -enemy.body_height * 0.45 - 2.0)

	if fx:
		var slash_color: Color = COLOR_CRIT if crit else _weapon_color()
		fx.slash(hero.position + Vector2(6, -13), 13.0 if not crit else 15.0, -1.95, 0.85, slash_color, 0.17, 3.0 if not crit else 4.0)
		fx.spark_burst(hit_pos, Vector2(1, -0.35), Color(1, 0.93, 0.7), 16 if crit else 8, Vector2(36, 92), 0.8)
	enemy.take_damage(amount)
	if fx:
		fx.damage_number(number_pos, amount, &"crit" if crit else &"normal")
	if crit:
		if fx:
			fx.ring(hit_pos, COLOR_CRIT, 2.0, 13.0, 0.24, 1.0)
		if _crit_fx_cd <= 0.0:
			_crit_fx_cd = CRIT_FX_COOLDOWN
			if camera:
				camera.add_trauma(0.3)
			if corridor.has_method("hitstop"):
				corridor.hitstop(0.06)
			_play(CRIT_SFX, -11.0, 1.2, 0.05)
		elif camera:
			camera.add_trauma(0.1)
	elif camera:
		camera.add_trauma(0.07)
	_play_random(HIT_SFX, -12.0 if crit else -14.0, 1.0, 0.1)


func _execute_enemy_attack():
	var damage: float = enemy.dmg
	var crit: bool = randf() < enemy.crit_p
	if crit:
		damage *= enemy.crit_m
	var raw := int(damage)
	var hit_pos: Vector2 = hero.body_center() + Vector2(2, randf_range(-3.0, 2.0))
	var number_pos: Vector2 = hero.body_center() + Vector2(-2, -16)
	var style: String = enemy.style
	var heavy := style == "slam"

	var dealt: int = hero.take_damage(raw)
	if fx:
		fx.damage_number(number_pos, dealt, &"hero")
		if dealt < raw and _block_text_cd <= 0.0 and hero.has_method("armor_mitigation") and hero.armor_mitigation() >= 0.2:
			_block_text_cd = 2.5
			fx.float_text(hit_pos + Vector2(-9, -4), tr("Bloqueo"), Color("b8c4d6"), false, 0.7, 8.0)
		match style:
			"slam":
				fx.dust_puff(hero.position + Vector2(8, 0), Color(0.75, 0.7, 0.62, 0.6), 9, 1.6)
				fx.ring(hero.position + Vector2(4, -1), Color(0.9, 0.85, 0.75, 0.7), 2.0, 18.0, 0.32, 1.0)
				fx.spark_burst(hit_pos, Vector2(-1, -0.4), Color(1, 0.75, 0.5), 10, Vector2(32, 76), 0.9)
			"cast":
				fx.ring(hit_pos, enemy.accent_color, 1.0, 11.0, 0.3, 1.0)
				fx.spark_burst(hit_pos, Vector2(-1, -0.2), enemy.accent_color, 10, Vector2(28, 72), 1.0)
			_:
				fx.spark_burst(hit_pos, Vector2(-1, -0.25), Color(1, 0.55, 0.45), 8, Vector2(30, 76), 0.8)
	if camera:
		camera.add_trauma((0.42 if heavy else 0.14) + (0.2 if crit else 0.0))
	if heavy:
		Sfx.play(&"golem_slam", -1.0, 0.9 if enemy.is_boss else 1.0)
	if crit and _crit_fx_cd <= 0.0 and corridor.has_method("hitstop"):
		_crit_fx_cd = CRIT_FX_COOLDOWN
		corridor.hitstop(0.05)
	_play_random(HURT_SFX, -15.0, 0.8 if heavy else 0.95, 0.08)


func _on_hero_pulse(amount: int, target_pos: Vector2) -> void:
	if fx == null:
		return
	fx.pulse_wave(hero.body_center() + Vector2(6, 0), target_pos, COLOR_PULSE_HERO, 0.22)
	fx.ring(target_pos, COLOR_PULSE_HERO, 2.0, 9.0, 0.3, 1.0)
	fx.damage_number(target_pos + Vector2(0, -12), amount, &"pulse")


func _on_enemy_pulse(amount: int, target_pos: Vector2) -> void:
	if fx == null or enemy == null:
		return
	var from: Vector2 = enemy.death_info.get("pos", enemy.body_center()) if not enemy.alive else enemy.body_center()
	fx.pulse_wave(from + Vector2(-4, 0), target_pos, Color("c77dff"), 0.22)
	fx.ring(target_pos, Color("c77dff"), 2.0, 8.0, 0.3, 1.0)
	fx.damage_number(target_pos + Vector2(4, -12), amount, &"enemy_pulse")


func _weapon_color() -> Color:
	if hero and "gear" in hero and hero.gear.has("main_hand"):
		var tier: String = hero.gear["main_hand"].get("tier", "common")
		var c: Color = hero.TIER_COLORS.get(tier, COLOR_SLASH)
		return c.lerp(Color.WHITE, 0.45)
	return COLOR_SLASH


func _play(stream: AudioStream, volume_db: float, pitch: float = 1.0, variance: float = 0.0) -> void:
	if _audio == null or stream == null:
		return
	if _audio.has_method("play_sfx_pitched"):
		_audio.play_sfx_pitched(stream, volume_db, pitch, variance)
	else:
		_audio.play_sfx(stream, volume_db)


func _play_random(streams: Array, volume_db: float, pitch: float = 1.0, variance: float = 0.0) -> void:
	if streams.is_empty():
		return
	_play(streams[randi() % streams.size()], volume_db, pitch, variance)


func _on_hero_died(_drops := []):
	stop_combat()
	if _game_manager and _game_manager.has_method("register_hero_death"):
		_game_manager.register_hero_death()


func _on_enemy_died(drops):
	stop_combat()
	if drops is Array and drops.size() > 0 and _inventory_manager and _inventory_manager.has_method("add_drops"):
		_inventory_manager.add_drops(drops)
	# El primer botín lo presenta el Corridor (escucha después); el segundo, aquí y en el mismo fotograma
	if enemy:
		_show_bonus_loot(enemy.death_info)
	if _game_manager:
		# Primera muerte de cualquier nivel (también jefes) desbloquea plano
		if _game_manager.has_method("register_enemy_defeat"):
			_game_manager.register_enemy_defeat(enemy.level)
		if enemy and enemy.is_boss and _game_manager.has_method("register_boss_defeat"):
			_game_manager.register_boss_defeat()
	if corridor.has_method("advance_enemy"):
		corridor.advance_enemy()


## Segunda tanda de la Poción de Suerte, igual que la primera (Corridor._on_enemy_died_fx): icono con
## "+15 material" que sale del enemigo, aviso loot_dropped para el HUD ("bonus": true) y tintineo.
## El material ya está en el inventario (lo mete Enemy al morir).
func _show_bonus_loot(info: Dictionary) -> void:
	var md: Dictionary = info.get("bonus_material", {})
	if md.is_empty():
		return
	var pos: Vector2 = info.get("pos", Vector2.ZERO)
	var delay: float = 0.3 if info.get("boss", false) else 0.12  # el mismo que el primer botín
	var mat := _material_info(StringName(md.get("item_id", "")))
	if fx:
		var vx := randf_range(BONUS_LOOT_SPEED.x, BONUS_LOOT_SPEED.y)
		fx.loot_pop(pos + Vector2(2.0 + BONUS_LOOT_AHEAD, -4), mat.get("icon"), "+%d %s" % [int(md.get("quantity", 0)), tr(mat.get("name", ""))], Color(1, 0.93, 0.7), delay, PixelView.FLOOR_Y, vx, 1)
	if corridor and corridor.has_signal("loot_dropped"):
		corridor.loot_dropped.emit(&"material", pos, {"id": md.get("item_id", ""), "quantity": md.get("quantity", 0), "bonus": true})
	get_tree().create_timer(delay + BONUS_LOOT_SOUND_LAG).timeout.connect(func(): Sfx.play(&"loot_coins"))


## Nombre e icono del material: los mismos que usa el Corridor para el primer botín (con su caché).
func _material_info(mat_id: StringName) -> Dictionary:
	if corridor and corridor.has_method("_material_info"):
		return corridor._material_info(mat_id)
	return {"name": String(mat_id).capitalize(), "icon": null}
