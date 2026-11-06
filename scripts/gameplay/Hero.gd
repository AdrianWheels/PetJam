extends CharacterBody2D

## Héroe del corredor (IA), con cuatro poses sticker según su espada.
## La lógica conserva estadísticas del equipo y ataques por cooldown:
##  - reposo, ataque, daño y derrota; sin ciclos completos ni interpolación de poses,
##  - carga, estocada y retroceso como desplazamientos en píxeles enteros; destello al recibir daño y
##    disolución al reaparecer con shaders/pixel_sprite.gdshader,
##  - barra de vida y nombre en fuente pixel,
##  - la armadura reduce el daño físico,
##  - la Poción de Velocidad (GameManager) multiplica el ritmo de ataque mientras dura,
##  - las habilidades legendarias de la rejilla (`power`): Esquiva y Parada anulan un golpe, Segunda oportunidad
##    deja a Tico con vida una vez por duelo y la Regeneración cura con él vivo. Golpe doble, quemadura, Espinas
##    e Ímpetu los resuelve CombatController.
## Vida: cambiar de equipo conserva la proporción de vida (no cura); solo respawn() la llena y heal()
## cura sin resucitar.
## Unidades: píxeles del arte (la franja mide 216x96). El origen del nodo es el centro de los pies.

signal stats_reset
signal died
signal respawned
signal attack_triggered  # Emitida cuando el cooldown de ataque llega a 0
signal pulse_hit(amount: int, target_pos: Vector2)  # Pulso mágico aplicado (posición previa al daño)
signal hurt(amount: int)  ## tras cada golpe o pulso recibido (0 si se esquivó o paró): pociones automáticas

const SPRITE_SHADER := preload("res://shaders/pixel_sprite.gdshader")
const HERO_NAME := "Tico"

const BASE_HP := CombatMath.HERO_BASE_HP
const BASE_DMG := CombatMath.HERO_BASE_DMG
const BASE_APS := CombatMath.HERO_BASE_APS
const BASE_STR := CombatMath.HERO_BASE_STR
const BASE_AGI := CombatMath.HERO_BASE_AGI
const BASE_INT := CombatMath.HERO_BASE_INT
const PULSE_INTERVAL := CombatMath.PULSE_INTERVAL

# Armadura: reducción con rendimientos decrecientes (CombatMath.armor_mitigation)
const MAX_MITIGATION := CombatMath.MAX_MITIGATION

const WINDUP_TIME := 0.16
const HURT_TIME := 0.2
const MATERIALIZE_TIME := 0.5
## Fuerza del destello de daño en el arte de pegatinas (en pixel art, 0,8)
const STICKER_FLASH := 0.3
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
var base_aps: float = BASE_APS  ## ataques por segundo del equipo, sin efectos temporales
var aps: float = BASE_APS  ## ritmo efectivo: base_aps × efectos activos (Poción de Velocidad)
var crit_p: float = 0.0
var crit_m: float = 1.5
var armor: int = 0
var atk_timer: float = 0.0
var pulse_timer: float = PULSE_INTERVAL
var alive: bool = true
var is_attacking: bool = false
var debug_invincible: bool = false
var stored_hp: int = 0
var stored_max_hp: int = 0
var stored_dmg: float = 0.0

## Habilidades legendarias de la rejilla (LegendaryPowers.effects): se recalculan en reset_stats
var power: Dictionary = LegendaryPowers.effects([])
## Tirada de 0 a 1 para las habilidades (esquiva, parada, golpe doble); las pruebas la fuerzan
var power_roll: Callable = Callable()
## &"dodge" o &"block" si el último golpe se esquivó o paró; &"" si no
var last_avoid: StringName = &""
## Ímpetu: el primer golpe contra el enemigo actual aún no se ha dado (reset_stats lo apaga si ya no hay botas)
var first_strike_ready := false
var _second_chance_ready := false
var _second_chance_used := false  ## en este duelo (se recarga al empezar el siguiente)
var _regen_acc := 0.0
var _regen_shown := 0
var _regen_fx_cd := 0.0

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
## Segundos desde el último golpe recibido y desde la caída: llevan las animaciones de daño y derrota.
var _since_hurt := 99.0
var _since_defeat := 0.0
var _materialize := 1.0
var _hp_ghost := 1.0
var _ghost_delay := 0.0
var _block_flash := 0.0
var _sprite: Sprite2D
var _hud: Node2D
var _sprite_key := ""
var _metrics: Dictionary = {}
var _sticker := false


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
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("buffs_changed"):
		gm.buffs_changed.connect(_on_buffs_changed)
	respawn(position)


func _process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta)
	_since_hurt += delta
	_since_defeat = 0.0 if alive else _since_defeat + delta
	_block_flash = maxf(0.0, _block_flash - delta * 3.0)
	# Regeneración (casco avanzado legendario): solo con Tico vivo; un "+N" verde cada 2 s como mucho
	if alive and float(power.regen) > 0.0 and hp < max_hp:
		_regen_acc += float(max_hp) * float(power.regen) * delta
		if _regen_acc >= 1.0:
			var gain := int(_regen_acc)
			_regen_acc -= gain
			hp = mini(max_hp, hp + gain)
			_regen_shown += gain
	_regen_fx_cd = maxf(0.0, _regen_fx_cd - delta)
	if _regen_shown > 0 and _regen_fx_cd <= 0.0 and fx:
		fx.float_text(body_center() + Vector2(0, -16), "+%d" % _regen_shown, Color("7dff8a"), false, 0.8, 8.0)
		_regen_shown = 0
		_regen_fx_cd = 2.0
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

## Recalcula las stats desde el equipo. No cura: conserva la proporción de vida (con Tico caído sigue
## a 0). Tampoco reinicia el golpe ni el pulso en curso: GameManager la llama en cada cambio de la rejilla, con el
## juego en marcha detrás del panel de Equipo. respawn() llena la vida después; prepare_for_combat(), los temporizadores.
func reset_stats():
	var hp_ratio := _hp_ratio()
	var old_aps := aps
	var equipment_stats := {}
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager and inv_manager.has_method("calculate_total_stats"):
		equipment_stats = inv_manager.calculate_total_stats()

	var powers: Array = []
	if inv_manager and inv_manager.has_method("active_legendary_powers"):
		powers = inv_manager.active_legendary_powers()
	# Rango del equipo (spec de rangos, apartado 6, «Base de Tico»): la base de vida, daño y pulso crece con él
	var team_rank := 1
	if inv_manager and inv_manager.has_method("equipment_rank"):
		team_rank = inv_manager.equipment_rank()
	var s := CombatMath.hero_stats_with_powers(equipment_stats, powers, team_rank)
	power = LegendaryPowers.effects(powers)
	# Segunda oportunidad: lista si la da la rejilla y aún no se ha usado en este duelo
	_second_chance_ready = float(power.second_chance) > 0.0 and not _second_chance_used
	# Ímpetu: si el equipo cambia entre que Tico engancha al enemigo y su primer golpe, sigue listo solo con las botas
	first_strike_ready = first_strike_ready and float(power.first_strike) > 0.0
	STR = s.STR
	AGI = s.AGI
	INT = s.INT
	max_hp = s.max_hp
	hp = _hp_for_ratio(hp_ratio)
	dmg = s.dmg
	base_aps = s.aps
	aps = base_aps * _attack_speed_multiplier()
	crit_p = s.crit_p
	crit_m = s.crit_m
	armor = s.armor
	# El golpe en curso conserva la parte que le falta (cambia la velocidad a la que se carga, como en
	# refresh_attack_speed) y el pulso sigue su cuenta: reordenar la rejilla a mitad de duelo no para a Tico mientras
	# el enemigo conserva sus temporizadores. Sin golpe en curso (el primer cálculo, al aparecer Tico, o un golpe que
	# acaba de salir) arranca lleno.
	if atk_timer > 0.0:
		atk_timer = minf(atk_timer * old_aps / aps, 1.0 / aps)
	else:
		atk_timer = 1.0 / aps
	# `alive` no se toca aquí: equipar durante la caída no debe resucitarlo (lo hace respawn())
	_hp_ghost = _hp_ratio()
	_strike_time = clampf(0.6 / aps, 0.12, 0.24)
	refresh_gear()

	emit_signal("stats_reset")
	DebugManager.log_msg(&"combat", "Hero stats — HP:%d DMG:%.1f APS:%.2f CRIT:%.0f%% ARM:%d (-%d%%)" % [max_hp, dmg, aps, crit_p * 100, armor, int(armor_mitigation() * 100.0)])


## Vida para la proporción dada con el máximo actual. Vivo nunca baja de 1 (cambiar de equipo no mata)
## y caído se queda a 0 (no resucita).
func _hp_for_ratio(ratio: float) -> int:
	if ratio <= 0.0:
		return 0
	return clampi(roundi(ratio * float(max_hp)), 1, max_hp)


func _attack_speed_multiplier() -> float:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("attack_speed_multiplier"):
		return float(gm.attack_speed_multiplier())
	return 1.0


func _on_buffs_changed(_active: Dictionary) -> void:
	refresh_attack_speed()


## Aplica al ritmo de ataque los efectos activos sin recalcular el resto: reset_stats() no vale aquí
## porque también recalcula la vida y las estadísticas.
func refresh_attack_speed() -> void:
	var new_aps := base_aps * _attack_speed_multiplier()
	if is_equal_approx(new_aps, aps):
		return
	# El golpe en curso conserva la parte que le falta: solo cambia la velocidad a la que se carga
	atk_timer *= aps / new_aps
	aps = new_aps
	_strike_time = clampf(0.6 / aps, 0.12, 0.24)


## Lee la rejilla de Tico y elige el sprite: la mejor pieza de cada tipo (InventoryManager.best_hero_item).
func refresh_gear() -> void:
	gear.clear()
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager != null and inv_manager.has_method("best_hero_item"):
		for slot in ["main_hand", "off_hand", "head", "feet"]:
			var item = inv_manager.best_hero_item(slot)
			if item == null:
				continue
			var rarity := "basic"
			if item.item_resource:
				rarity = String(item.item_resource.rarity)
			gear[slot] = {"tier": item.get_quality_tier(), "rarity": rarity}
	_apply_sprite()


func expected_dps() -> float:
	return CombatMath.expected_dps({"dmg": dmg, "crit_p": crit_p, "crit_m": crit_m, "aps": aps, "INT": INT})


## Fracción de daño físico que absorbe la armadura frente a un enemigo de la sala `enemy_level`.
func armor_mitigation(enemy_level: int = 1) -> float:
	return CombatMath.armor_mitigation(armor, enemy_level)


# --- Combate ----------------------------------------------------------

## Aplica daño y devuelve el daño real recibido (tras armadura). El pulso mágico ignora la armadura.
## `attacker_level` es la sala del enemigo que golpea: la armadura se compara con su escala.
## Habilidades legendarias: Esquiva y Parada anulan un golpe (no el pulso) y dejan `last_avoid`;
## Segunda oportunidad deja a Tico con vida la primera vez que iba a caer en cada duelo.
func take_damage(amount: int, is_pulse: bool = false, attacker_level: int = 1) -> int:
	last_avoid = &""
	if debug_invincible or not alive:
		return 0
	if not is_pulse:
		if float(power.dodge) > 0.0 and roll_power() < float(power.dodge):
			last_avoid = &"dodge"
			hurt.emit(0)
			return 0
		if float(power.block) > 0.0 and roll_power() < float(power.block):
			last_avoid = &"block"
			_block_flash = 1.0
			hurt.emit(0)
			return 0
	var final := amount
	if not is_pulse:
		var mitigation := armor_mitigation(attacker_level)
		final = maxi(1, int(round(float(amount) * (1.0 - mitigation))))
		if final < amount and mitigation >= 0.15:
			_block_flash = 1.0
	_hurt = HURT_TIME
	_since_hurt = 0.0
	_ghost_delay = 0.35
	if final >= hp and _second_chance_ready:
		_second_chance_ready = false
		_second_chance_used = true
		hp = maxi(1, roundi(float(max_hp) * float(power.second_chance)))
		_on_second_chance()
	else:
		hp = max(0, hp - final)
		if hp == 0:
			alive = false
			_regen_shown = 0  # un "+N" de la regeneración que esperaba turno no sale sobre Tico caído
			_spawn_death_fx()
			emit_signal("died")
	hurt.emit(final)
	return final


func roll_power() -> float:
	return float(power_roll.call()) if power_roll.is_valid() else randf()


## Segunda oportunidad: destello, anillo y "¡OTRA VEZ!" en la franja.
func _on_second_chance() -> void:
	_materialize = 0.4
	if fx:
		var c := body_center()
		fx.ring(c, Color("ffd76a"), 2.0, 20.0, 0.45, 1.0)
		fx.float_text(c + Vector2(0, -16), tr("¡Otra vez!"), Color("ffd76a"), true, 1.2, 10.0)


func set_invincible(invincible: bool) -> void:
	debug_invincible = invincible
	if invincible:
		stored_hp = hp
		stored_max_hp = max_hp
		stored_dmg = dmg
		hp = 10000
		max_hp = 10000
		dmg = 10000.0
	else:
		# Vuelve con la vida que tenía (reset_stats conserva la proporción: dejar de ser invencible no cura)
		max_hp = stored_max_hp if stored_max_hp > 0 else BASE_HP
		hp = clampi(stored_hp, 1, max_hp) if stored_hp > 0 else max_hp
		dmg = stored_dmg if stored_dmg > 0 else BASE_DMG
		reset_stats()


## Cura hasta max_hp sin resucitar: con Tico caído no hace nada. Devuelve la vida recuperada.
func heal(amount: int) -> int:
	if not alive or amount <= 0:
		return 0
	var healed := mini(amount, max_hp - hp)
	if healed <= 0:
		return 0
	hp += healed
	if fx:
		var c := body_center()
		fx.ring(c, Color(0.45, 1.0, 0.55, 0.9), 2.0, 14.0, 0.4, 1.0)
		fx.float_text(c + Vector2(0, -16), "+%d" % healed, Color("7dff8a"), false, 1.0, 10.0)
	return healed


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
	first_strike_ready = float(power.first_strike) > 0.0
	# Segunda oportunidad: una por duelo (en el spec de rangos, cada sala es un duelo con la vida llena)
	_second_chance_used = false
	_second_chance_ready = float(power.second_chance) > 0.0


func respawn(start_position: Vector2 = PixelView.HERO_START) -> void:
	reset_stats()
	# Reaparecer sí cura del todo (reset_stats conserva la proporción de vida)
	hp = max_hp
	_hp_ghost = 1.0
	position = start_position
	velocity = Vector2.ZERO
	alive = true
	is_attacking = false
	_windup = 0.0
	_strike = 0.0
	_hurt = 0.0
	_since_hurt = 99.0
	_since_defeat = 0.0
	_materialize = 0.0
	_regen_acc = 0.0
	_regen_shown = 0  # ni un "+N" pendiente de antes (reaparecer también es viajar de sala)
	emit_signal("respawned")


func apply_loadout(_loadout: Dictionary) -> void:
	reset_stats()


func body_center() -> Vector2:
	return position + Vector2(0, -PixelView.VIEW_H * 0.45 if _sticker else float(_metrics.get("center_y", -14.0)))


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


## Clave del arte anterior para las medidas de juego y el respaldo visual.
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
	var visual_key := key + "/" + _rarity("main_hand")
	if visual_key == _sprite_key:
		return
	_sprite_key = visual_key
	_metrics = PixelSprites.metrics(key)
	_sprite.texture = PixelSprites.texture(key)
	_sprite.hframes = maxi(1, int(_metrics.get("frames", 1)))
	_sprite.vframes = 1
	var sticker_key := "tico_" + (_rarity("main_hand") if not _rarity("main_hand").is_empty() else "none")
	_sticker = StickerSprites.apply_height(_sprite, sticker_key, PixelView.VIEW_H * 0.90)
	if not _sticker:
		_sprite.scale = Vector2.ONE


func _update_sprite() -> void:
	if _sprite == null:
		return
	_sprite.visible = alive or _sticker
	if not alive and not _sticker:
		return
	_sprite.frame = StickerSprites.frame_for(_sprite, alive, _t, _since_defeat, _since_hurt, _hurt, _windup, _strike) if _sticker else int(_t / IDLE_FRAME_TIME) % _sprite.hframes
	var flash := clampf(_hurt / HURT_TIME, 0.0, 1.0)
	var lunge := -1.6 * _windup + 5.2 * pow(_strike, 1.4) - 2.4 * flash
	var bob := 1.0 if walking and absf(sin(_walk_phase)) > 0.5 else 0.0
	_sprite.position = _sprite_origin() + (Vector2.ZERO if _sticker else Vector2(roundf(lunge), -bob))
	var mat := _sprite.material as ShaderMaterial
	# En las pegatinas ilustradas un destello casi blanco parece un fantasma translúcido: ya está la pose de daño, basta un toque
	mat.set_shader_parameter("flash", flash * (STICKER_FLASH if _sticker else 0.8))
	mat.set_shader_parameter("dissolve", 1.0 - clampf(_materialize * 1.6, 0.0, 1.0))


## Esquina superior izquierda del fotograma para que los pies apoyen en el origen del nodo.
func _sprite_origin() -> Vector2:
	if _sticker:
		return _sprite.get_meta("sticker_origin", Vector2(-18.0, -33.0))
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
