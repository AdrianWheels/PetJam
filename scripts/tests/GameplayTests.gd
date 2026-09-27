extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas de juego (economía, tienda, inventario y pociones), solo desarrollo, sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/GameplayTests.tscn
## El tiempo de las pociones se avanza con GameManager.tick_buffs(): ninguna prueba lo espera de verdad
## (la única espera real, de medio segundo, es para callar el sonido del botín; ver _silence_loot_sounds).

var _loot_seen: Array = []  # avisos de botín de material del Corridor (prueba del botín doble)


# ─── Materiales ────────────────────────────────────────────────────────

## Materiales que pide algún plano de la librería.
func _materials_used_by_blueprints() -> Dictionary:
	var used := {}
	var dm := get_node("/root/DataManager")
	for bp in dm.get_all_blueprints().values():
		for mat_id in bp.materials:
			used[StringName(mat_id)] = true
	return used


func test_shop_only_sells_materials_that_blueprints_use() -> void:
	var used := _materials_used_by_blueprints()
	check(not used.is_empty(), "la librería de planos debe pedir materiales")
	for mat_id in ShopPanel.MATERIAL_CATALOG:
		check(used.has(StringName(mat_id)), "la tienda vende «%s», que no pide ningún plano" % mat_id)


func test_starting_materials_are_used_by_blueprints() -> void:
	var used := _materials_used_by_blueprints()
	var im := get_node("/root/InventoryManager")
	check(not im.STARTING_MATERIALS.is_empty(), "debe haber materiales de inicio")
	for mat_id in im.STARTING_MATERIALS:
		check(used.has(StringName(mat_id)), "se regala «%s» al empezar, pero no lo pide ningún plano" % mat_id)


# ─── Pociones ──────────────────────────────────────────────────────────

func _gm() -> Node:
	return get_node("/root/GameManager")


func _im() -> Node:
	return get_node("/root/InventoryManager")


func _price(pot_id: StringName) -> int:
	return int(ShopPanel.POTION_CATALOG[pot_id].price)


## Héroe de prueba. Se queda en el grupo "hero" para que la tienda lo encuentre: aquí no hay partida.
func _new_hero() -> Node2D:
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	add_child(hero)
	return hero


func _new_shop() -> Control:
	var shop := ShopPanel.new()
	add_child(shop)
	return shop


## Deja el oro en `amount` y devuelve el que había (para restaurarlo al acabar).
func _set_gold(amount: int) -> int:
	var im := _im()
	var had: int = im.get_quantity(&"gold")
	im.consume_materials({&"gold": had})
	im.add_item(&"gold", amount)
	return had


func test_speed_potion_boosts_attack_rate_for_30_seconds() -> void:
	var gm := _gm()
	gm.clear_buffs()
	var had := _set_gold(1000)
	var hero := _new_hero()
	var shop := _new_shop()
	var base: float = hero.aps
	hero.hp = hero.max_hp - 10
	var resets := [0]
	hero.stats_reset.connect(func(): resets[0] += 1)
	shop._on_buy_potion(&"potion_speed", _price(&"potion_speed"))
	check(is_equal_approx(hero.aps, base * 1.5), "Velocidad: ataques por segundo x1,5 (%.2f → %.2f)" % [base, hero.aps])
	hero.prepare_for_combat()
	check(is_equal_approx(hero.atk_timer, 1.0 / (base * 1.5)), "el tiempo entre golpes baja en proporción (%.3f s)" % hero.atk_timer)
	check(resets[0] == 0 and hero.hp == hero.max_hp - 10, "aplicarla no recalcula el equipo ni cura (%d/%d)" % [hero.hp, hero.max_hp])
	check(is_equal_approx(gm.buff_remaining(&"speed"), 30.0), "dura 30 s (%.1f)" % gm.buff_remaining(&"speed"))
	gm.tick_buffs(29.5)
	check(is_equal_approx(hero.aps, base * 1.5), "a los 29,5 s sigue activa (%.2f)" % hero.aps)
	gm.tick_buffs(0.5)
	check(is_equal_approx(hero.aps, base), "a los 30 s caduca y el ritmo vuelve a %.2f (%.2f)" % [base, hero.aps])
	check(gm.buff_remaining(&"speed") == 0.0, "sin tiempo restante al caducar (%.2f)" % gm.buff_remaining(&"speed"))
	shop.free()
	hero.free()
	_set_gold(had)


func test_effects_tick_on_their_own_every_frame() -> void:
	var gm := _gm()
	gm.clear_buffs()
	gm.apply_buff(&"speed", 30.0)
	for i in 3:
		await get_tree().process_frame
	var left: float = gm.buff_remaining(&"speed")
	check(left < 30.0 and left > 29.0, "GameManager descuenta el tiempo real en cada fotograma (%.3f)" % left)
	gm.clear_buffs()


func test_rebuying_an_active_potion_renews_it_without_stacking() -> void:
	var gm := _gm()
	gm.clear_buffs()
	var had := _set_gold(1000)
	var hero := _new_hero()
	var shop := _new_shop()
	var base: float = hero.aps
	shop._on_buy_potion(&"potion_speed", _price(&"potion_speed"))
	gm.tick_buffs(20.0)
	var gold: int = _im().get_quantity(&"gold")
	shop._on_buy_potion(&"potion_speed", _price(&"potion_speed"))
	check(is_equal_approx(gm.buff_remaining(&"speed"), 30.0), "volver a comprar Velocidad renueva los 30 s, no los suma (%.1f)" % gm.buff_remaining(&"speed"))
	check(is_equal_approx(hero.aps, base * 1.5), "ni acumula efecto (x%.2f)" % (hero.aps / base))
	check(_im().get_quantity(&"gold") == gold - _price(&"potion_speed"), "la renovación se cobra")
	shop._on_buy_potion(&"potion_luck", _price(&"potion_luck"))
	gm.tick_buffs(45.0)
	shop._on_buy_potion(&"potion_luck", _price(&"potion_luck"))
	check(is_equal_approx(gm.buff_remaining(&"luck"), 60.0), "Suerte también renueva a 60 s (%.1f)" % gm.buff_remaining(&"luck"))
	check(is_equal_approx(gm.double_loot_chance(), 0.2), "y no acumula probabilidad (%.2f)" % gm.double_loot_chance())
	gm.clear_buffs()
	shop.free()
	hero.free()
	_set_gold(had)


func _new_enemy() -> Node2D:
	var e: Node2D = load("res://scenes/Enemy.tscn").instantiate()
	e.remove_from_group("enemy")
	add_child(e)
	e.configure_for_level(1, false)
	return e


## Materiales ganados desde `before` (id → cantidad).
func _gained_since(before: Dictionary) -> Dictionary:
	var gained := {}
	var now: Dictionary = _im().get_materials()
	for id in now:
		var diff := int(now[id]) - int(before.get(id, 0))
		if diff != 0:
			gained[id] = diff
	return gained


## Mata al enemigo y devuelve los materiales que suelta (id → cantidad). Lo deja listo para otra muerte.
func _kill(e: Node2D) -> Dictionary:
	var before: Dictionary = _im().get_materials()
	e.take_damage(e.hp)
	e.configure_for_level(1, false)
	return _gained_since(before)


## Cambiar el equipo o la sala guarda la partida en diferido (GameManager._on_trigger_save). Se deja
## pasar un fotograma para que esos guardados se escriban ya y no después de que TestSuite restaure
## save.json al acabar la suite.
func _flush_deferred_saves() -> void:
	await get_tree().process_frame


## Deja sonar el botín y luego calla las voces de AudioManager. Si la suite sale con un sonido a medias,
## Godot avisa de recursos «still in use at exit». Es la única espera real de la suite y no tiene que
## ver con el tiempo de las pociones: los tintineos van con temporizadores del árbol (0,12 s y 0,22 s)
## que siguen vivos aunque se libere el pasillo, y el hilo de audio suelta lo parado un poco después.
func _silence_loot_sounds() -> void:
	await get_tree().create_timer(0.35).timeout
	var am := get_node_or_null("/root/AudioManager")
	if am:
		for voice in am.get_children():
			if voice is AudioStreamPlayer:
				voice.stop()
	await get_tree().create_timer(0.1).timeout


func test_luck_potion_doubles_the_loot_on_a_lucky_roll() -> void:
	var gm := _gm()
	gm.clear_buffs()
	var start: Dictionary = _im().get_materials()
	var e := _new_enemy()
	e.luck_roll = func() -> float: return 0.0  # tirada forzada: siempre dentro del 20 %
	var loot := _kill(e)
	check(loot.size() == 1 and loot.values()[0] == 15, "sin Suerte, un botín de 15 aunque la tirada salga (%s)" % loot)
	check(e.death_info.get("bonus_material", {}).is_empty(), "sin segunda tanda para la franja")
	gm.apply_buff(&"luck", 60.0)
	loot = _kill(e)
	check(loot.size() == 2, "con Suerte y la tirada a favor, dos botines de materiales distintos (%s)" % loot)
	check(loot.values().all(func(q): return q == 15), "de 15 cada uno (%s)" % loot)
	var info: Dictionary = e.death_info
	check(not info.get("material", {}).is_empty() and not info.get("bonus_material", {}).is_empty(), "death_info lleva los dos botines (%s)" % info)
	e.luck_roll = func() -> float: return 0.2  # justo fuera del 20 %
	loot = _kill(e)
	check(loot.size() == 1, "con Suerte y la tirada en contra, uno (%s)" % loot)
	gm.clear_buffs()
	e.free()
	_im().consume_materials(_gained_since(start))  # devuelve el botín de prueba


func _on_test_loot(kind: StringName, _pos: Vector2, payload: Dictionary) -> void:
	if kind == &"material":
		_loot_seen.append(payload)


func test_double_loot_shows_in_the_strip_like_the_first() -> void:
	var gm := _gm()
	gm.clear_buffs()
	gm.apply_buff(&"luck", 60.0)
	var level_before: int = gm.current_enemy_level
	var best_before: int = gm.best_enemy_level
	gm.current_enemy_level = 1  # sala 1: un Limo, sin jefe
	var start: Dictionary = _im().get_materials()
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	var enemy: Node2D = corridor.get_node("Enemy")
	var fx: Node2D = corridor.get_node("CombatFX")
	enemy.luck_roll = func() -> float: return 0.0
	_loot_seen.clear()
	corridor.loot_dropped.connect(_on_test_loot)
	enemy.take_damage(enemy.hp)
	await get_tree().process_frame
	var icons: Array = fx._parts.filter(func(p): return p.kind == fx.Kind.ICON)
	check(icons.size() == 2, "dos iconos de botín en la franja (%d)" % icons.size())
	if icons.size() == 2:
		var first: Dictionary = icons[0] if icons[0].text_row == 0 else icons[1]
		var bonus: Dictionary = icons[1] if icons[0].text_row == 0 else icons[0]
		check(first.text != bonus.text and String(first.text).begins_with("+15 ") and String(bonus.text).begins_with("+15 "), "cada uno con su «+15 material» (%s / %s)" % [first.text, bonus.text])
		check(first.text_row == 0 and bonus.text_row == 1, "la etiqueta del segundo va una fila más arriba")
		check(is_equal_approx(first.delay, bonus.delay) and bonus.pos.x > first.pos.x, "salen a la vez, el segundo un poco más adelante")
	check(_loot_seen.size() == 2, "dos avisos de botín para el HUD (%d)" % _loot_seen.size())
	check(_loot_seen.filter(func(p): return p.get("bonus", false)).size() == 1, "uno de ellos marcado como botín doble")
	corridor.queue_free()
	gm.current_enemy_level = level_before
	gm.best_enemy_level = best_before
	gm.clear_buffs()
	_im().consume_materials(_gained_since(start))  # devuelve el botín de prueba
	await _flush_deferred_saves()  # el avance de sala guarda la partida
	await _silence_loot_sounds()


func test_equipping_keeps_the_health_ratio_and_respawn_heals() -> void:
	var gm := _gm()
	var im := _im()
	var hero := _new_hero()
	var prev_hero: Node = gm.get_hero()
	gm.register_hero(hero)  # GameManager recalcula sus stats en cada cambio de equipo
	var prev_boots: CraftedItem = im.get_equipped_item("feet")
	var res: ItemResource = load("res://data/items/boots_master.tres")
	var boots := CraftedItem.new(res, 1.0)
	im.add_crafted_item(boots)
	hero.hp = roundi(hero.max_hp * 0.5)
	var max_before: int = hero.max_hp
	im.equip_item(boots)
	check(hero.max_hp > max_before, "las botas suben la vida máxima (%d → %d)" % [max_before, hero.max_hp])
	check(absi(hero.hp - roundi(hero.max_hp * 0.5)) <= 1, "equipar no cura: conserva la mitad de la vida (%d/%d)" % [hero.hp, hero.max_hp])
	im.unequip_item("feet")
	check(hero.max_hp == max_before and absi(hero.hp - roundi(max_before * 0.5)) <= 1, "quitárselas tampoco (%d/%d)" % [hero.hp, hero.max_hp])
	hero.take_damage(hero.hp * 10, true)
	im.equip_item(boots)
	check(not hero.alive and hero.hp == 0, "equipar con Tico caído no le da vida (%d)" % hero.hp)
	hero.respawn()
	check(hero.alive and hero.hp == hero.max_hp, "reaparecer sí cura del todo (%d/%d)" % [hero.hp, hero.max_hp])
	im.remove_crafted_item(boots)
	if prev_boots:
		im.equip_item(prev_boots)
	gm.register_hero(prev_hero)
	hero.free()
	await _flush_deferred_saves()  # cada cambio de equipo guarda la partida


func test_heal_potion_only_for_a_wounded_hero_standing() -> void:
	var im := _im()
	var had := _set_gold(1000)
	var hero := _new_hero()
	var shop := _new_shop()
	var price := _price(&"potion_heal")
	shop._on_buy_potion(&"potion_heal", price)
	check(im.get_quantity(&"gold") == 1000, "con la vida llena no cobra (%d)" % im.get_quantity(&"gold"))
	check(shop._toast_label.text.contains("vida llena"), "y lo avisa («%s»)" % shop._toast_label.text)
	hero.hp = 7
	shop._on_buy_potion(&"potion_heal", price)
	check(hero.hp == hero.max_hp, "herido, cura al máximo (%d/%d)" % [hero.hp, hero.max_hp])
	check(im.get_quantity(&"gold") == 1000 - price, "y cobra %d" % price)
	hero.take_damage(hero.hp * 10, true)
	shop._on_buy_potion(&"potion_heal", price)
	check(im.get_quantity(&"gold") == 1000 - price, "con Tico caído no cobra (%d)" % im.get_quantity(&"gold"))
	check(not hero.alive and hero.hp == 0, "ni lo resucita (%d)" % hero.hp)
	check(shop._toast_label.text.contains("caído"), "y lo avisa («%s»)" % shop._toast_label.text)
	shop.free()
	hero.free()
	_set_gold(had)


func test_no_potion_is_applied_without_enough_gold() -> void:
	var gm := _gm()
	gm.clear_buffs()
	var had := _set_gold(99)  # menos que la poción más barata
	var hero := _new_hero()
	var shop := _new_shop()
	var base: float = hero.aps
	hero.hp = 7
	for pot_id in ShopPanel.POTION_CATALOG:
		shop._on_buy_potion(pot_id, _price(pot_id))
		check(shop._toast_label.text.contains("Oro insuficiente"), "%s sin oro: lo avisa («%s»)" % [pot_id, shop._toast_label.text])
	check(hero.hp == 7, "Vida sin oro no cura (%d)" % hero.hp)
	check(is_equal_approx(hero.aps, base) and gm.buff_remaining(&"speed") == 0.0, "Velocidad sin oro no se aplica")
	check(gm.buff_remaining(&"luck") == 0.0, "Suerte sin oro no se aplica")
	check(_im().get_quantity(&"gold") == 99, "no se cobra nada (%d)" % _im().get_quantity(&"gold"))
	shop.free()
	hero.free()
	_set_gold(had)


func test_hud_shows_each_active_effect_with_its_time_left() -> void:
	var gm := _gm()
	gm.clear_buffs()
	var overlay := Control.new()
	overlay.set_script(load("res://scripts/ui/HeroViewOverlay.gd"))
	add_child(overlay)
	gm.apply_buff(&"speed", 30.0)
	overlay._process(0.0)
	var speed: Label = overlay._buff_labels[&"speed"]
	var luck: Label = overlay._buff_labels[&"luck"]
	check(speed.visible and speed.text == "VELOCIDAD 30 s", "Velocidad activa: «%s»" % speed.text)
	check(speed.label_settings.font_size >= 22, "legible en el móvil (%d px)" % speed.label_settings.font_size)
	check(not luck.visible, "Suerte no está activa")
	var first_row := speed.position
	gm.apply_buff(&"luck", 60.0)
	gm.tick_buffs(5.5)
	overlay._process(0.0)
	check(speed.text == "VELOCIDAD 25 s" and luck.visible and luck.text == "SUERTE 55 s", "cuentan hacia atrás («%s», «%s»)" % [speed.text, luck.text])
	check(luck.position.y > speed.position.y, "una debajo de otra")
	gm.tick_buffs(25.0)
	overlay._process(0.0)
	check(not speed.visible and luck.visible, "Velocidad desaparece al caducar")
	check(luck.position == first_row, "Suerte sube a la primera fila (%s)" % luck.position)
	overlay._on_loot_dropped(&"material", Vector2.ZERO, {"id": &"iron", "quantity": 15, "bonus": true})
	overlay._process(0.0)
	check(luck.scale.x > 1.0, "un botín doble hace latir la etiqueta de Suerte (%s)" % luck.scale)
	gm.clear_buffs()
	overlay._process(0.0)
	check(not luck.visible, "sin efectos no se ve ninguno")
	overlay.free()
