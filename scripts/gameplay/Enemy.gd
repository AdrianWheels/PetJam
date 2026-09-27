extends CharacterBody2D

## Enemigo del corredor en pixel art.
## Lógica de combate original (stats por nivel + ataques por cooldown) y encima:
##  - arquetipos (Limo, Esqueleto, Murciélago, Gólem, Espectro y el jefe de cada bioma) con su sprite,
##    que ya mira hacia el héroe (lo exporta tools/pixel_art); de momento solo el reposo de 2 fotogramas,
##  - entrada, carga, golpe y retroceso como desplazamientos en píxeles enteros; destello al recibir daño
##    y disolución al aparecer con shaders/pixel_sprite.gdshader,
##  - barra de vida con "daño fantasma", nombre y aviso "!" en fuente pixel.
## Unidades: píxeles del arte (la franja mide 216x96). El origen del nodo es el centro de los pies.

signal stats_reset
signal died(drops)
signal attack_triggered  # Emitida cuando el cooldown de ataque llega a 0
signal pulse_hit(amount: int, target_pos: Vector2)  # Pulso mágico aplicado (posición previa al daño)

const SPRITE_SHADER := preload("res://shaders/pixel_sprite.gdshader")
const DEFAULT_DROP_TABLE := preload("res://data/drops/basic_enemy_drop.tres")

const BASE_HP := 40
const BASE_DMG := 5.0
const BASE_APS := 0.8
const PULSE_INTERVAL := 2.5
const BOSS_LEVEL_MULTIPLIER := 1.6
const HURT_TIME := 0.18
const INTRO_TIME := 0.5
const IDLE_FRAME_TIME := 0.5
const MATERIAL_DROP_QTY := 15

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
var is_attacking: bool = false

var size: Vector2 = Vector2(16, 25)  # Compatibilidad

@export var is_boss: bool = false
@export var drop_table: DropTable

# ─── Arquetipo ─────────────────────────────────────────────────────────
var archetype: StringName = &"skeleton"
var display_name: String = "Esqueleto"
var half_width: float = 8.0
var body_height: float = 25.0
var hover: float = 0.0
var style: String = "swing"
var windup_time: float = 0.22
var strike_time: float = 0.22
var body_color: Color = Color("e8ddc2")
var shade_color: Color = Color("ab9c7c")
var accent_color: Color = Color("ff4a3a")

var fx: Node = null  # CombatFX (lo asigna el Corridor)
var last_material_drop: Dictionary = {}  # {"item_id", "quantity"} del último botín
var last_bonus_drop: Dictionary = {}  # segunda tanda de la Poción de Suerte ({} si no la hubo)
## Tirada (0..1) del botín doble de la Poción de Suerte. Vacía usa _rng; las pruebas la fijan para
## forzar el resultado (sale si la tirada es menor que GameManager.double_loot_chance()).
var luck_roll: Callable = Callable()
## Datos del último enemigo muerto. Se rellenan ANTES de emitir died, porque los que escuchan
## después (Corridor) ya ven al nodo recolocado en la sala siguiente.
var death_info: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _hurt := 0.0
var _windup := 0.0
var _strike := 0.0
var _intro := 1.0
var _awake := false
var _alert := 0.0
var _hp_ghost := 1.0
var _ghost_delay := 0.0
var _cast_launched := false
var _landed := false
var _sprite: Sprite2D
var _hud: Node2D
var _metrics: Dictionary = {}


## Pinta barra, nombre y alerta por encima del sprite.
class HudDrawer extends Node2D:
	var enemy  # sin tipo: llama a métodos del script del enemigo

	func _draw() -> void:
		if enemy:
			enemy._draw_hud(self)


func _ready() -> void:
	if drop_table == null:
		drop_table = DEFAULT_DROP_TABLE
	_rng.randomize()
	_sprite = Sprite2D.new()
	_sprite.centered = false
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	_sprite.material = mat
	add_child(_sprite)
	_hud = HudDrawer.new()
	_hud.enemy = self
	add_child(_hud)
	_apply_archetype(archetype)
	reset_stats()


func _process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta)
	if _strike > 0.0:
		_strike = maxf(0.0, _strike - delta / strike_time)
	if not is_attacking:
		_windup = move_toward(_windup, 0.0, delta * 5.0)
	if _awake and _intro < 1.0:
		_intro = minf(1.0, _intro + delta / INTRO_TIME)
		if not _landed and _intro >= 0.62:
			_landed = true
			_on_intro_landed()
	_alert = maxf(0.0, _alert - delta / 0.75)
	# Barra fantasma: espera un momento y luego alcanza a la vida real
	var ratio := _hp_ratio()
	if _ghost_delay > 0.0:
		_ghost_delay -= delta
	elif _hp_ghost > ratio:
		_hp_ghost = move_toward(_hp_ghost, ratio, delta * 1.4)
	_hp_ghost = maxf(_hp_ghost, ratio)
	_update_sprite()
	queue_redraw()
	if _hud:
		_hud.queue_redraw()


# ─── Configuración ─────────────────────────────────────────────────────

func configure_for_level(lv: int, boss: bool) -> void:
	level = lv
	is_boss = boss
	_apply_archetype(&"boss" if boss else EnemyArchetypes.pick_for_room(lv))
	reset_stats()
	_awake = false
	_intro = 0.0
	_landed = false
	_alert = 0.0
	_windup = 0.0
	_strike = 0.0
	_hurt = 0.0
	_hp_ghost = 1.0
	_cast_launched = false
	queue_redraw()
	# Ocultar ya el sprite y la barra: tras una muerte el hit-stop congela _process y el enemigo
	# de la sala siguiente asomaría por el borde derecho hasta que acabe
	_update_sprite()
	if _hud:
		_hud.queue_redraw()


func _apply_archetype(id: StringName) -> void:
	archetype = id
	var d: Dictionary = EnemyArchetypes.get_data(id)
	display_name = EnemyArchetypes.boss_name_for_room(level) if id == &"boss" else String(d.name)
	style = d.style
	windup_time = d.windup
	strike_time = d.strike
	body_color = d.body
	shade_color = d.shade
	accent_color = d.accent
	if id == &"boss":
		var bs: Dictionary = EnemyArchetypes.boss_style_for_room(level)
		body_color = bs.body
		shade_color = bs.shade
		accent_color = bs.accent
	var key := PixelSprites.enemy_key(id, level)
	_metrics = PixelSprites.metrics(key)
	half_width = float(_metrics.get("half_width", 8))
	body_height = float(_metrics.get("body_height", 25))
	hover = float(_metrics.get("hover", 0))
	size = Vector2(half_width * 2.0, body_height)
	if _sprite:
		_sprite.texture = PixelSprites.texture(key)
		_sprite.hframes = maxi(1, int(_metrics.get("frames", 1)))


## Empieza la animación de entrada (el Corridor la llama cuando entra en pantalla).
func wake() -> void:
	if _awake:
		return
	_awake = true
	_intro = 0.0
	_landed = false


func is_awake() -> bool:
	return _awake


## "!" sobre la cabeza al empezar el combate.
func alert() -> void:
	_alert = 1.0


func reset_stats():
	var exp_factor := pow(1.04, level - 1)
	var lin_factor := 1.0 + 0.15 * (level - 1)
	var stat_scale := lin_factor * exp_factor
	var multiplier := (BOSS_LEVEL_MULTIPLIER if is_boss else 1.0)
	var d: Dictionary = EnemyArchetypes.get_data(archetype)

	STR = (3.0 + level * 1.5) * exp_factor
	AGI = (1.5 + level * 0.8) * sqrt(exp_factor)
	INT = (1.5 + level * 0.6) * sqrt(exp_factor)

	max_hp = maxi(1, int(BASE_HP * stat_scale * multiplier * float(d.hp)))
	hp = max_hp
	dmg = (BASE_DMG + STR * 1.5) * multiplier * float(d.dmg)
	aps = clamp(BASE_APS + AGI * 0.02, 0.3, 4.0) * float(d.aps)
	crit_p = min(0.5, AGI * 0.006)
	crit_m = clamp(1.5 + INT * 0.012, 1.0, 3.0)
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	alive = true
	is_attacking = false
	DebugManager.log_msg(&"combat", "Enemy Lv%d %s: HP=%d, DMG=%.1f, APS=%.2f, scale=%.2f" % [level, archetype, max_hp, dmg, aps, stat_scale])
	emit_signal("stats_reset")


func expected_dps() -> float:
	var hit := dmg * (1.0 + crit_p * (crit_m - 1.0))
	var pulse_dmg := (INT * 3.0) / PULSE_INTERVAL
	return aps * hit + pulse_dmg


# ─── Combate ───────────────────────────────────────────────────────────

func take_damage(amount: int, _is_pulse: bool = false) -> int:
	if not alive:
		return 0
	hp = max(0, hp - amount)
	_hurt = HURT_TIME
	_ghost_delay = 0.3
	if hp == 0:
		_die()
	return amount


func attack(target, _particles: Array = []) -> void:
	"""Gestiona el timer de ataque. Emite attack_triggered cuando el cooldown llega a 0."""
	if not alive or target == null or not target.alive:
		is_attacking = false
		return
	is_attacking = true
	atk_timer -= get_process_delta_time()
	# Anticipación ligada al cooldown: no cambia el ritmo de ataque
	if atk_timer <= windup_time:
		_windup = clampf(1.0 - atk_timer / windup_time, 0.0, 1.0)
		if style == "cast" and not _cast_launched and fx:
			_cast_launched = true
			fx.orb(cast_origin(), target.position + Vector2(2, -13), accent_color, maxf(0.06, atk_timer))
			Sfx.play(&"wraith_orb")
	if atk_timer <= 0.0:
		_strike = 1.0
		_windup = 0.0
		_cast_launched = false
		emit_signal("attack_triggered")
		atk_timer = 1.0 / aps


func pulse(target, _particles: Array = []) -> void:
	if not alive or target == null or not target.alive:
		return
	pulse_timer -= get_process_delta_time()
	if pulse_timer <= 0.0:
		pulse_timer += PULSE_INTERVAL
		var target_pos: Vector2 = target.body_center() if target.has_method("body_center") else target.position
		var dealt = target.take_damage(int(INT * 3), true)
		emit_signal("pulse_hit", int(dealt) if dealt != null else int(INT * 3), target_pos)


func prepare_for_combat() -> void:
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	is_attacking = false


## Punto (en coordenadas del Corridor) donde nace el orbe del espectro.
func cast_origin() -> Vector2:
	return body_center() + Vector2(-half_width * 0.9, -body_height * 0.05)


## Centro de la caja de píxeles del sprite (para chispas y números).
func body_center() -> Vector2:
	return position + Vector2(0, float(_metrics.get("center_y", -body_height * 0.5)))


func generate_drops() -> Array:
	if drop_table == null:
		return []
	_drop_random_materials()
	return drop_table.roll_drops(_rng)


## Botín de materiales: 15 de un material al azar de los que piden los planos. Con la Poción de Suerte,
## a veces una segunda tanda de 15 de OTRO material del mismo conjunto (no repite, para que se lean
## dos botines distintos; solo repetiría si el conjunto tuviera un único material).
func _drop_random_materials() -> void:
	last_material_drop = {}
	last_bonus_drop = {}
	var all_materials := _blueprint_materials()
	if all_materials.is_empty():
		return
	var random_material: StringName = all_materials[_rng.randi() % all_materials.size()]
	last_material_drop = _give_material(random_material)
	if last_material_drop.is_empty() or not _rolls_double_loot():
		return
	var others: Array[StringName] = []
	for mat_id in all_materials:
		if mat_id != random_material:
			others.append(mat_id)
	if others.is_empty():
		others = all_materials
	last_bonus_drop = _give_material(others[_rng.randi() % others.size()])


## Materiales que pide algún plano (sin repetir).
func _blueprint_materials() -> Array[StringName]:
	var all_materials: Array[StringName] = []
	var dm := get_node_or_null("/root/DataManager")
	if not dm or not dm.has_method("get_all_blueprints"):
		return all_materials
	var all_blueprints: Dictionary = dm.get_all_blueprints()
	for bp_id in all_blueprints:
		var blueprint = all_blueprints[bp_id]
		if blueprint is BlueprintResource and not blueprint.materials.is_empty():
			for mat_id in blueprint.materials.keys():
				if not all_materials.has(mat_id):
					all_materials.append(StringName(mat_id))
	return all_materials


## Mete una tanda en el inventario y la devuelve ({} si no hay inventario).
func _give_material(mat_id: StringName) -> Dictionary:
	var im := get_node_or_null("/root/InventoryManager")
	if im == null or not im.has_method("add_item"):
		return {}
	im.add_item(mat_id, MATERIAL_DROP_QTY)
	return {"item_id": mat_id, "quantity": MATERIAL_DROP_QTY}


## ¿Sale el botín doble? Solo con la Poción de Suerte activa (20 % por enemigo derrotado).
func _rolls_double_loot() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	var chance: float = float(gm.double_loot_chance()) if gm and gm.has_method("double_loot_chance") else 0.0
	if chance <= 0.0:
		return false
	var roll: float = float(luck_roll.call()) if luck_roll.is_valid() else _rng.randf()
	return roll < chance


func _die() -> void:
	if not alive:
		return
	alive = false
	hp = 0
	is_attacking = false
	_spawn_death_fx()
	var drops := generate_drops()
	death_info = {
		"pos": body_center(), "boss": is_boss, "level": level, "name": display_name,
		"archetype": archetype, "material": last_material_drop.duplicate(),
		"bonus_material": last_bonus_drop.duplicate(),
	}
	emit_signal("died", drops)


func _spawn_death_fx() -> void:
	if fx == null:
		return
	var center := body_center()
	var count := 26 if is_boss else 14
	fx.shatter(center, [body_color, shade_color, accent_color, body_color.lightened(0.3)], count, Vector2(1, 3) * (1.4 if is_boss else 1.0), position.y)
	fx.ring(center, Color(1, 1, 1, 0.9), 2.0, 34.0 if is_boss else 19.0, 0.38, 1.0)
	fx.spark_burst(center, Vector2.UP, accent_color, 14, Vector2(32, 84), PI)
	fx.dust_puff(position, Color(0.8, 0.75, 0.7, 0.6), 8, 1.4)


func _on_intro_landed() -> void:
	if fx == null:
		return
	match style:
		"hop", "slam":
			fx.dust_puff(position, Color(0.75, 0.7, 0.65, 0.55), 7, 1.2 if style == "slam" else 0.8)
		"swing":
			fx.dust_puff(position, Color(0.55, 0.5, 0.45, 0.5), 5, 0.7)


# ─── Dibujo ────────────────────────────────────────────────────────────

func _hp_ratio() -> float:
	return clampf(float(hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0


func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _update_sprite() -> void:
	if _sprite == null:
		return
	_sprite.visible = _awake and alive
	if not _sprite.visible:
		return
	_sprite.frame = int(_t / IDLE_FRAME_TIME) % _sprite.hframes
	var e := _ease_out_back(_intro)
	var st := pow(_strike, 1.6)
	var w := _windup
	var flash := clampf(_hurt / HURT_TIME, 0.0, 1.0)
	# Desplazamiento en "espacio de cara": x positiva = hacia el héroe
	var off := Vector2.ZERO
	match style:
		"hop":
			off = Vector2(7.0 * st, -7.0 * sin(_strike * PI))
		"swing":
			off = Vector2(-1.2 * w + 4.0 * st, 0.0)
		"dive":
			off = Vector2(-3.2 * w + 9.2 * st, -5.6 * w + 6.0 * st)
		"slam":
			off = Vector2(2.0 * st, -1.6 * w)
		"cast":
			off = Vector2(-1.6 * st, -2.0 * w)
	off.x -= 2.0 * flash
	# Entrada: cae, entra en picado o sube; todos aparecen por disolución
	match style:
		"hop":
			off.y -= 30.0 * (1.0 - e)
		"dive":
			off += Vector2(-16.0, -18.0) * (1.0 - e)
		"cast":
			off.y += 5.0 * (1.0 - e)
	# El enemigo mira a la izquierda: la x de cara se invierte en el mundo
	_sprite.position = _sprite_origin() + Vector2(roundf(-off.x), roundf(off.y))
	var mat := _sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash", flash * 0.85)
	mat.set_shader_parameter("dissolve", 1.0 - clampf(_intro * 2.2, 0.0, 1.0))


## Esquina superior izquierda del fotograma para que los pies apoyen en el origen del nodo.
func _sprite_origin() -> Vector2:
	var fw := float(_metrics.get("frame_w", 32))
	var ground := float(_metrics.get("ground_row", 28))
	return Vector2(-fw * 0.5, -(ground + 1.0))


## Barra relativa al nodo: 1 px por encima de la cabeza, desplazada lejos del héroe (menos el jefe).
func hud_bar_rect() -> Rect2:
	var top := roundf(float(_metrics.get("center_y", -body_height * 0.5)) - body_height * 0.5)
	var boss := archetype == &"boss"
	var w := 40.0 if boss else 22.0
	var shift := 0.0 if boss else 3.0
	return Rect2(roundf(-w * 0.5 + shift), top - 5.0, w, 3.0)


func hud_label() -> String:
	return "%s Nv %d" % [display_name, level]


## El nombre arranca en el borde izquierdo de la barra y crece hacia la derecha, lejos del de Tico.
func hud_label_rect() -> Rect2:
	var bar := hud_bar_rect()
	return Rect2(bar.position.x, bar.position.y - PixelFont.SMALL_SIZE, PixelFont.width(hud_label()), PixelFont.SMALL_SIZE)


func _draw() -> void:
	if not _awake or not alive:
		return
	var a := clampf(_intro * 2.2, 0.0, 1.0)
	var sh := clampf(1.0 - hover / 44.0, 0.45, 1.0)
	PixelHud.draw_shadow(self, Vector2.ZERO, int(roundf(half_width * 2.1 * sh)), a)


func _draw_hud(canvas: CanvasItem) -> void:
	if not _awake or not alive:
		return
	var a := clampf(_intro * 2.2, 0.0, 1.0)
	var boss := archetype == &"boss"
	var bar := hud_bar_rect()
	PixelHud.draw_bar(canvas, bar, _hp_ratio(), _hp_ghost, Color("ff7a2a") if boss else Color("e5433b"), a)
	PixelFont.draw(canvas, hud_label_rect().position, hud_label(), Color("ffd54a") if boss else Color("f1e4cf"), a)
	if _alert > 0.0:
		var bounce := roundf(2.0 * (1.0 - _alert))
		var top := Vector2(bar.get_center().x, bar.position.y - PixelFont.SMALL_SIZE - PixelFont.BIG_SIZE - bounce)
		PixelFont.draw_centered(canvas, top, "!", Color(1, 0.85, 0.2), minf(1.0, _alert * 3.0) * a, true)
