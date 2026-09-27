extends CharacterBody2D

## Héroe del corredor (IA) en pixel art. La lógica es la de siempre (stats del equipo + ataques por cooldown):
##  - sprite de 32x32 con reposo de 2 fotogramas. Provisional hasta la fase 2 del spec
##    doc/specs/2026-09-27-franja-combate-pixel-art.md: la tira se elige según la espada que lleva,
##  - carga, estocada y retroceso como desplazamientos en píxeles enteros; destello al recibir daño y
##    disolución al reaparecer con shaders/pixel_sprite.gdshader,
##  - barra de vida y nombre en fuente pixel,
##  - la armadura reduce el daño físico.
## Unidades: píxeles del arte (la franja mide 216x96). El origen del nodo es el centro de los pies.

signal stats_reset
signal died
signal respawned
signal attack_triggered  # Emitida cuando el cooldown de ataque llega a 0
signal pulse_hit(amount: int, target_pos: Vector2)  # Pulso mágico aplicado (posición previa al daño)

const SPRITE_SHADER := preload("res://shaders/pixel_sprite.gdshader")
const HERO_NAME := "Tico"

const BASE_HP := 60
const BASE_DMG := 6.0
const BASE_APS := 1.0
const BASE_STR := 10
const BASE_AGI := 10
const BASE_INT := 8
const PULSE_INTERVAL := 2.5

# Armadura: reducción con rendimientos decrecientes (armor / (armor + K)), con tope.
const ARMOR_K := 40.0
const MAX_MITIGATION := 0.6

const WINDUP_TIME := 0.16
const HURT_TIME := 0.2
const MATERIALIZE_TIME := 0.5
const IDLE_FRAME_TIME := 0.5

## Colores de Tico para los fragmentos al morir (chaleco, bufanda, piel, pelo)
const DEATH_COLORS := [Color("c8905a"), Color("c23644"), Color("f7d2ae"), Color("8f4f2c")]

## Color de cada tier de calidad (más suave que los colores puros de CraftedItem)
const TIER_COLORS := {
	"common": Color("cfd6dc"),
	"uncommon": Color("6ad16a"),
	"rare": Color("4ea3ff"),
	"epic": Color("b46bff"),
	"legendary": Color("ffa629"),
}

var STR: int = BASE_STR
var AGI: int = BASE_AGI
var INT: int = BASE_INT

var max_hp: int = BASE_HP
var hp: int = BASE_HP
var dmg: float = BASE_DMG
var aps: float = BASE_APS
var crit_p: float = 0.0
var crit_m: float = 1.5
var armor: int = 0
var atk_timer: float = 0.0
var pulse_timer: float = PULSE_INTERVAL
var alive: bool = true
var is_attacking: bool = false
var debug_invincible: bool = false
var stored_hp: int = 0
var stored_dmg: float = 0.0

var size: Vector2 = Vector2(12, 28)  # Compatibilidad
var half_width: float = 6.0
var reach: float = 9.0  # Alcance del arma (para decidir cuándo se engancha el combate)

## Lo actualiza el Corridor
var walking: bool = false
var walk_speed: float = 0.0
var fx: Node = null
var look_target: Vector2 = Vector2(1, 0)  # Compatibilidad: el sprite no mueve los ojos

## Equipo visible: slot → {"tier": String, "rarity": String}
var gear: Dictionary = {}
## false en el héroe de muestra del panel de Equipo (sin barra de vida)
var show_hud: bool = true

# Estado visual
var _t := 0.0
var _walk_phase := 0.0
var _last_step_sign := 1.0
var _windup := 0.0
var _strike := 0.0
var _strike_time := 0.22
var _hurt := 0.0
var _materialize := 1.0
var _hp_ghost := 1.0
var _ghost_delay := 0.0
var _block_flash := 0.0
var _sprite: Sprite2D
var _hud: Node2D
var _sprite_key := ""
var _metrics: Dictionary = {}


## Pinta barra y nombre por encima del sprite (los hijos se dibujan después que el padre).
class HudDrawer extends Node2D:
	var hero  # sin tipo: llama a métodos del script del héroe

	func _draw() -> void:
		if hero:
			hero._draw_hud(self)


func _ready():
	_sprite = Sprite2D.new()
	_sprite.centered = false
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	_sprite.material = mat
	add_child(_sprite)
	_hud = HudDrawer.new()
	_hud.hero = self
	add_child(_hud)
	respawn(position)


func _process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta)
	_block_flash = maxf(0.0, _block_flash - delta * 3.0)
	if _strike > 0.0:
		_strike = maxf(0.0, _strike - delta / _strike_time)
	if not is_attacking:
		_windup = move_toward(_windup, 0.0, delta * 6.0)
	if _materialize < 1.0:
		_materialize = minf(1.0, _materialize + delta / MATERIALIZE_TIME)
	if walking and alive:
		# Misma cadencia de pasos que a 1080: 190 / 26 = 38 / 5.2
		_walk_phase += delta * maxf(walk_speed, 12.0) / 5.2
		var s := signf(sin(_walk_phase))
		if s != _last_step_sign:
			_last_step_sign = s
			if fx and s > 0.0:
				fx.dust_puff(position + Vector2(-1, 0), Color(0.7, 0.66, 0.6, 0.35), 2, 0.5)
	else:
		_walk_phase = 0.0
	# Barra fantasma
	var ratio := _hp_ratio()
	if _ghost_delay > 0.0:
		_ghost_delay -= delta
	elif _hp_ghost > ratio:
		_hp_ghost = move_toward(_hp_ghost, ratio, delta * 1.2)
	_hp_ghost = maxf(_hp_ghost, ratio)
	_update_sprite()
	queue_redraw()
	if _hud:
		_hud.queue_redraw()


# --- Stats ------------------------------------------------------------

func reset_stats():
	var equipment_stats := {}
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager and inv_manager.has_method("calculate_total_stats"):
		equipment_stats = inv_manager.calculate_total_stats()

	STR = BASE_STR + int(equipment_stats.get("str", 0))
	AGI = BASE_AGI + int(equipment_stats.get("agi", 0))
	INT = BASE_INT + int(equipment_stats.get("int", 0))

	var bonus_hp: int = int(equipment_stats.get("hp", 0))
	var bonus_dmg: float = float(equipment_stats.get("damage", 0))
	var bonus_aps: float = float(equipment_stats.get("aps", 0.0))
	var bonus_crit_p: float = float(equipment_stats.get("crit", 0.0))
	var bonus_armor: int = int(equipment_stats.get("armor", 0))

	max_hp = BASE_HP + STR * 10 + bonus_hp
	hp = max_hp
	dmg = BASE_DMG + STR * 1.5 + bonus_dmg
	aps = clamp(BASE_APS + AGI * 0.02 + bonus_aps, 0.3, 5.0)
	crit_p = clamp(AGI * 0.005 + bonus_crit_p, 0.0, 0.75)
	crit_m = clamp(1.5 + INT * 0.01, 1.0, 3.0)
	armor = bonus_armor
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	# `alive` no se toca aquí: equipar durante la caída no debe resucitarlo (lo hace respawn())
	_hp_ghost = 1.0
	_strike_time = clampf(0.6 / aps, 0.12, 0.24)
	refresh_gear()

	emit_signal("stats_reset")
	DebugManager.log_msg(&"combat", "Hero stats — HP:%d DMG:%.1f APS:%.2f CRIT:%.0f%% ARM:%d (-%d%%)" % [max_hp, dmg, aps, crit_p * 100, armor, int(armor_mitigation() * 100.0)])


## Lee el equipo actual (espada, escudo, casco, botas) y elige el sprite.
func refresh_gear() -> void:
	gear.clear()
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager != null and "equipped_items" in inv_manager:
		for slot in inv_manager.equipped_items.keys():
			var item = inv_manager.equipped_items[slot]
			if item == null:
				continue
			var rarity := "basic"
			if item.item_resource:
				rarity = String(item.item_resource.rarity)
			gear[String(slot)] = {"tier": item.get_quality_tier(), "rarity": rarity}
	_apply_sprite()


func expected_dps() -> float:
	var hit := dmg * (1.0 + crit_p * (crit_m - 1.0))
	var pulse_dmg := (INT * 3.0) / PULSE_INTERVAL
	return aps * hit + pulse_dmg


## Fracción de daño físico que absorbe la armadura (0..MAX_MITIGATION).
func armor_mitigation() -> float:
	if armor <= 0:
		return 0.0
	return minf(MAX_MITIGATION, float(armor) / (float(armor) + ARMOR_K))


# --- Combate ----------------------------------------------------------

## Aplica daño y devuelve el daño real recibido (tras armadura). El pulso mágico ignora la armadura.
func take_damage(amount: int, is_pulse: bool = false) -> int:
	if debug_invincible or not alive:
		return 0
	var final := amount
	if not is_pulse:
		final = maxi(1, int(round(float(amount) * (1.0 - armor_mitigation()))))
		if final < amount and armor_mitigation() >= 0.15:
			_block_flash = 1.0
	hp = max(0, hp - final)
	_hurt = HURT_TIME
	_ghost_delay = 0.35
	if hp == 0:
		alive = false
		_spawn_death_fx()
		emit_signal("died")
	return final


func set_invincible(invincible: bool) -> void:
	debug_invincible = invincible
	if invincible:
		stored_hp = hp
		stored_dmg = dmg
		hp = 10000
		max_hp = 10000
		dmg = 10000.0
	else:
		hp = stored_hp if stored_hp > 0 else BASE_HP
		max_hp = BASE_HP
		dmg = stored_dmg if stored_dmg > 0 else BASE_DMG
		reset_stats()


func attack(target, _particles: Array = []) -> void:
	"""Gestiona el timer de ataque. Emite attack_triggered cuando el cooldown llega a 0."""
	if not alive or target == null or not target.alive:
		is_attacking = false
		return
	is_attacking = true
	look_target = target.position
	atk_timer -= get_process_delta_time()
	# Anticipación ligada al cooldown: el ritmo de ataque no cambia
	var windup := minf(WINDUP_TIME, 0.45 / aps)
	if atk_timer <= windup:
		_windup = clampf(1.0 - atk_timer / windup, 0.0, 1.0)
	if atk_timer <= 0.0:
		_strike = 1.0
		_windup = 0.0
		emit_signal("attack_triggered")
		atk_timer = 1.0 / aps


func pulse(target, _particles: Array = []) -> void:
	if not alive or target == null or not target.alive:
		return
	pulse_timer -= get_process_delta_time()
	if pulse_timer <= 0.0:
		pulse_timer += PULSE_INTERVAL
		# La posición se toma antes del daño: si el enemigo muere, se recoloca en la sala siguiente
		var target_pos: Vector2 = target.body_center() if target.has_method("body_center") else target.position
		var dealt = target.take_damage(INT * 3, true)
		emit_signal("pulse_hit", int(dealt) if dealt != null else INT * 3, target_pos)


func prepare_for_combat() -> void:
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	is_attacking = false


func respawn(start_position: Vector2 = PixelView.HERO_START) -> void:
	reset_stats()
	position = start_position
	velocity = Vector2.ZERO
	alive = true
	is_attacking = false
	_windup = 0.0
	_strike = 0.0
	_hurt = 0.0
	_materialize = 0.0
	emit_signal("respawned")


func apply_loadout(_loadout: Dictionary) -> void:
	reset_stats()


func body_center() -> Vector2:
	return position + Vector2(0, float(_metrics.get("center_y", -14.0)))


func _spawn_death_fx() -> void:
	if fx == null:
		return
	var c := body_center()
	fx.shatter(c, DEATH_COLORS, 16, Vector2(1, 3), position.y)
	fx.ring(c, Color(0.75, 0.9, 1.0, 0.9), 2.0, 24.0, 0.45, 1.0)
	fx.spark_burst(c, Vector2.UP, Color("9fd0ff"), 16, Vector2(32, 84), PI)


# --- Dibujo -----------------------------------------------------------

func _hp_ratio() -> float:
	return clampf(float(hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0


func _rarity(slot: String) -> String:
	return String(gear[slot].get("rarity", "basic")) if gear.has(slot) else ""


## Provisional (fase 1): la tira de Tico según la espada. La fase 2 compone una capa por pieza.
func _hero_sprite_key() -> String:
	match _rarity("main_hand"):
		"":
			return "hero/tico_0"
		"master":
			return "hero/tico_2"
		_:
			return "hero/tico_1"


func _apply_sprite() -> void:
	if _sprite == null:
		return
	var key := _hero_sprite_key()
	if key == _sprite_key:
		return
	_sprite_key = key
	_metrics = PixelSprites.metrics(key)
	_sprite.texture = PixelSprites.texture(key)
	_sprite.hframes = maxi(1, int(_metrics.get("frames", 1)))


func _update_sprite() -> void:
	if _sprite == null:
		return
	_sprite.visible = alive
	if not alive:
		return
	_sprite.frame = int(_t / IDLE_FRAME_TIME) % _sprite.hframes
	var flash := clampf(_hurt / HURT_TIME, 0.0, 1.0)
	var lunge := -1.6 * _windup + 5.2 * pow(_strike, 1.4) - 2.4 * flash
	var bob := 1.0 if walking and absf(sin(_walk_phase)) > 0.5 else 0.0
	_sprite.position = _sprite_origin() + Vector2(roundf(lunge), -bob)
	var mat := _sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash", flash * 0.8)
	mat.set_shader_parameter("dissolve", 1.0 - clampf(_materialize * 1.6, 0.0, 1.0))


## Esquina superior izquierda del fotograma para que los pies apoyen en el origen del nodo.
func _sprite_origin() -> Vector2:
	var fw := float(_metrics.get("frame_w", 32))
	var ground := float(_metrics.get("ground_row", 28))
	return Vector2(-fw * 0.5, -(ground + 1.0))


## Barra de vida relativa al nodo: 1 px por encima de la cabeza y 2 px hacia atrás para no
## chocar con la del enemigo en combate.
func hud_bar_rect() -> Rect2:
	var top := roundf(float(_metrics.get("center_y", -14.0)) - float(_metrics.get("body_height", 28)) * 0.5)
	return Rect2(-13, top - 5, 22, 3)


## Nombre centrado sobre la barra, relativo al nodo.
func hud_label_rect() -> Rect2:
	var bar := hud_bar_rect()
	var w := PixelFont.width(HERO_NAME)
	return Rect2(roundf(bar.get_center().x - w * 0.5), bar.position.y - PixelFont.SMALL_SIZE, w, PixelFont.SMALL_SIZE)


func _draw() -> void:
	if not alive:
		return
	PixelHud.draw_shadow(self, Vector2.ZERO, 14, clampf(_materialize * 1.6, 0.0, 1.0))


func _draw_hud(canvas: CanvasItem) -> void:
	if not show_hud or not alive:
		return
	var a := clampf(_materialize * 1.6, 0.0, 1.0)
	var bar := hud_bar_rect()
	PixelHud.draw_bar(canvas, bar, _hp_ratio(), _hp_ghost, _bar_color(), a)
	PixelFont.draw(canvas, hud_label_rect().position, HERO_NAME, Color("fef6e4"), a)
	if armor > 0:
		var icon_pos := bar.position + Vector2(-6, -1)
		PixelHud.draw_armor_icon(canvas, icon_pos, a)
		if _block_flash > 0.0:
			PixelHud.draw_armor_icon(canvas, icon_pos, a * _block_flash, Color.WHITE)


func _bar_color() -> Color:
	var ratio := _hp_ratio()
	if ratio <= 0.3:
		return Color("e5433b").lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 12.0))
	if ratio <= 0.6:
		return Color("f0b43c")
	return Color("54d162")
