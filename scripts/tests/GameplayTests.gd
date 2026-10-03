extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas de juego (economía, tienda, inventario y pociones), solo desarrollo, sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/GameplayTests.tscn
## El tiempo de las pociones se avanza con GameManager.tick_buffs(): ninguna prueba lo espera de verdad
## (la única espera real, de medio segundo, es para callar el sonido del botín; ver _silence_loot_sounds).

var _loot_seen: Array = []  # avisos de botín de material del Corridor (prueba del botín doble)


# ─── Materiales ────────────────────────────────────────────────────────

## Materiales que pide algún plano de la librería en su receta de rango I (incluye los de bioma).
func _materials_used_by_blueprints() -> Dictionary:
	var used := {}
	var dm := get_node("/root/DataManager")
	for bp_id in dm.get_all_blueprints():
		var bp: BlueprintResource = dm.get_all_blueprints()[bp_id]
		var item: ItemResource = dm.get_item_resource(bp.result_item)
		var tier := Ranks.tier_from_rarity(item.rarity if item else "basic")
		for mat_id in Ranks.recipe(bp.materials, tier, 1):
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


## Deja el inventario vacío y devuelve lo que había, para _restore_inventory. Las pruebas que tumban a Tico de un
## golpe mortal no pueden leer la rejilla de la partida: una habilidad legendaria suya (Segunda oportunidad) lo
## dejaría en pie, y con su equipo cambiarían también todas sus demás estadísticas.
func _empty_inventory() -> Dictionary:
	var saved: Dictionary = _im().to_save_data()
	_im().clear()
	return saved


func _restore_inventory(saved: Dictionary) -> void:
	_im().load_save_data(saved, int(_gm().best_enemy_level))


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


## Vacía los huecos de consumibles y devuelve cómo estaban.
func _empty_potion_slots() -> Array:
	var im := _im()
	var before: Array = im.consumables.duplicate(true)
	for i in im.consumables.size():
		im.consumables[i] = {"id": &"", "count": 0}
	return before


## Lo que hace la Velocidad bebida con el ritmo de Tico (comprarla ya no la aplica: se bebe sola, ver más abajo).
func test_a_drunk_speed_potion_boosts_attack_rate_for_30_seconds() -> void:
	var gm := _gm()
	gm.clear_buffs()
	var slots := _empty_potion_slots()
	var hero := _new_hero()
	var base: float = hero.aps
	hero.hp = hero.max_hp - 10
	var resets := [0]
	hero.stats_reset.connect(func(): resets[0] += 1)
	_im().add_potion(&"potion_speed")
	gm.drink_potion(&"potion_speed")
	check(is_equal_approx(hero.aps, base * 1.5), "Velocidad: ataques por segundo x1,5 (%.2f → %.2f)" % [base, hero.aps])
	hero.prepare_for_combat()
	check(is_equal_approx(hero.atk_timer, 1.0 / (base * 1.5)), "el tiempo entre golpes baja en proporción (%.3f s)" % hero.atk_timer)
	check(resets[0] == 0 and hero.hp == hero.max_hp - 10, "beberla no recalcula el equipo ni cura (%d/%d)" % [hero.hp, hero.max_hp])
	check(is_equal_approx(gm.buff_remaining(&"speed"), 30.0), "dura 30 s (%.1f)" % gm.buff_remaining(&"speed"))
	gm.tick_buffs(29.5)
	check(is_equal_approx(hero.aps, base * 1.5), "a los 29,5 s sigue activa (%.2f)" % hero.aps)
	gm.tick_buffs(0.5)
	check(is_equal_approx(hero.aps, base), "a los 30 s caduca y el ritmo vuelve a %.2f (%.2f)" % [base, hero.aps])
	check(gm.buff_remaining(&"speed") == 0.0, "sin tiempo restante al caducar (%.2f)" % gm.buff_remaining(&"speed"))
	hero.free()
	_im().consumables = slots


func test_effects_tick_on_their_own_every_frame() -> void:
	var gm := _gm()
	gm.clear_buffs()
	gm.apply_buff(&"speed", 30.0)
	for i in 3:
		await get_tree().process_frame
	var left: float = gm.buff_remaining(&"speed")
	check(left < 30.0 and left > 29.0, "GameManager descuenta el tiempo real en cada fotograma (%.3f)" % left)
	gm.clear_buffs()


func _new_enemy() -> Node2D:
	var e: Node2D = load("res://scenes/Enemy.tscn").instantiate()
	e.remove_from_group("enemy")
	add_child(e)
	e.configure_for_level(1, false)
	e.biome_drop_chance = 0.0  # el botín de estas pruebas es solo el de siempre y el doble (el de bioma tiene la suya)
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
	enemy.biome_drop_chance = 0.0  # sin el material de bioma (tiene su propia prueba): solo los dos botines
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


func test_biome_loot_is_the_third_pop_in_the_strip() -> void:
	var gm := _gm()
	gm.clear_buffs()
	gm.apply_buff(&"luck", 60.0)
	var level_before: int = gm.current_enemy_level
	var best_before: int = gm.best_enemy_level
	gm.current_enemy_level = 1  # sala 1: un Limo de las Catacumbas, sin jefe
	var start: Dictionary = _im().get_materials()
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	var enemy: Node2D = corridor.get_node("Enemy")
	var fx: Node2D = corridor.get_node("CombatFX")
	enemy.luck_roll = func() -> float: return 0.0
	enemy.biome_drop_chance = 1.0
	_loot_seen.clear()
	corridor.loot_dropped.connect(_on_test_loot)
	enemy.take_damage(enemy.hp)
	await get_tree().process_frame
	var icons: Array = fx._parts.filter(func(p): return p.kind == fx.Kind.ICON)
	check(icons.size() == 3, "tres iconos de botín: el de siempre, el doble y el de bioma (%d)" % icons.size())
	var rows: Array = icons.map(func(p): return p.text_row)
	rows.sort()
	check(rows == [0, 1, 2], "cada uno en su fila de etiqueta (%s)" % [rows])
	check(_loot_seen.size() == 3, "tres avisos de botín para el HUD (%d)" % _loot_seen.size())
	check(_loot_seen.filter(func(p): return p.get("biome", false) and p.get("id") == &"bone").size() == 1, "uno marcado como material de bioma (hueso)")
	corridor.queue_free()
	gm.current_enemy_level = level_before
	gm.best_enemy_level = best_before
	gm.clear_buffs()
	_im().consume_materials(_gained_since(start))  # devuelve el botín de prueba
	await _flush_deferred_saves()
	await _silence_loot_sounds()


func test_equipping_keeps_the_health_ratio_and_respawn_heals() -> void:
	var gm := _gm()
	var im := _im()
	var hero := _new_hero()
	var prev_hero: Node = gm.get_hero()
	gm.register_hero(hero)  # GameManager recalcula sus stats en cada cambio de equipo
	var saved: Dictionary = im.to_save_data()
	im.clear()
	var boots := CraftedItem.new(load("res://data/items/boots_master.tres"), 1.0)
	im.add_crafted_item(boots)
	hero.hp = roundi(hero.max_hp * 0.5)
	var max_before: int = hero.max_hp
	im.move_item(boots, &"hero", Vector2i(0, 0), 0)
	check(hero.max_hp > max_before, "las botas suben la vida máxima (%d → %d)" % [max_before, hero.max_hp])
	check(absi(hero.hp - roundi(hero.max_hp * 0.5)) <= 1, "colocarlas no cura: conserva la mitad de la vida (%d/%d)" % [hero.hp, hero.max_hp])
	im.move_item(boots, &"loot")
	check(hero.max_hp == max_before and absi(hero.hp - roundi(max_before * 0.5)) <= 1, "quitárselas tampoco (%d/%d)" % [hero.hp, hero.max_hp])
	hero.take_damage(hero.hp * 10, true)
	im.move_item(boots, &"hero", Vector2i(0, 0), 0)
	check(not hero.alive and hero.hp == 0, "colocar con Tico caído no le da vida (%d)" % hero.hp)
	hero.respawn()
	check(hero.alive and hero.hp == hero.max_hp, "reaparecer sí cura del todo (%d/%d)" % [hero.hp, hero.max_hp])
	im.load_save_data(saved, int(gm.best_enemy_level))
	gm.register_hero(prev_hero)
	hero.free()
	await _flush_deferred_saves()  # cada cambio de equipo guarda la partida


func test_buying_a_potion_puts_it_in_a_slot() -> void:
	var gm := _gm()
	gm.clear_buffs()
	var had := _set_gold(1000)
	var slots := _empty_potion_slots()
	var shop := _new_shop()
	shop._on_buy_potion(&"potion_speed", _price(&"potion_speed"))
	check(_im().potion_count(&"potion_speed") == 1, "la Velocidad va a su hueco")
	check(not gm.has_buff(&"speed"), "no se bebe al comprarla")
	check(_im().get_quantity(&"gold") == 1000 - _price(&"potion_speed"), "y se cobra")
	var wall: int = gm.wall_room
	gm.wall_room = 0  # sin muro: delante de uno no se bebe
	gm.on_boss_appeared()
	check(gm.has_buff(&"speed") and is_equal_approx(gm.buff_remaining(&"speed"), 30.0), "se bebe sola al aparecer un jefe: 30 s")
	gm.clear_buffs()
	gm.wall_room = wall
	shop.free()
	_im().consumables = slots
	_set_gold(had)


func test_no_slot_means_no_charge() -> void:
	var had := _set_gold(10000)
	var slots := _empty_potion_slots()
	var shop := _new_shop()
	shop._on_buy_potion(&"potion_speed", _price(&"potion_speed"))
	shop._on_buy_potion(&"potion_luck", _price(&"potion_luck"))
	var gold: int = _im().get_quantity(&"gold")
	shop._on_buy_potion(&"potion_heal", _price(&"potion_heal"))
	check(_im().get_quantity(&"gold") == gold, "sin hueco para la Vida no se cobra (%d)" % _im().get_quantity(&"gold"))
	check(shop._toast_label.text.contains(tr("No hay hueco")), "y lo avisa («%s»)" % shop._toast_label.text)
	shop.free()
	_im().consumables = slots
	_set_gold(had)


func test_no_potion_is_bought_without_enough_gold() -> void:
	var had := _set_gold(99)  # menos que la poción más barata
	var slots := _empty_potion_slots()
	var shop := _new_shop()
	for pot_id in ShopPanel.POTION_CATALOG:
		shop._on_buy_potion(pot_id, _price(pot_id))
		check(shop._toast_label.text.contains("Oro insuficiente"), "%s sin oro: lo avisa («%s»)" % [pot_id, shop._toast_label.text])
		check(_im().potion_count(pot_id) == 0, "%s sin oro no entra en ningún hueco" % pot_id)
	check(_im().get_quantity(&"gold") == 99, "no se cobra nada (%d)" % _im().get_quantity(&"gold"))
	shop.free()
	_im().consumables = slots
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


## La franja enseña las pociones que quedan en los huecos, debajo de los efectos activos (o en la primera fila si no hay).
func test_hud_shows_the_potions_left_under_the_effects() -> void:
	var gm := _gm()
	gm.clear_buffs()
	var slots := _empty_potion_slots()
	var overlay := Control.new()
	overlay.set_script(load("res://scripts/ui/HeroViewOverlay.gd"))
	add_child(overlay)
	var line: Label = overlay._potion_label
	overlay._process(0.0)
	check(not line.visible, "sin pociones en los huecos no hay línea")
	_im().add_potion(&"potion_heal")
	_im().add_potion(&"potion_heal")
	_im().add_potion(&"potion_speed")
	overlay._process(0.0)
	check(line.visible and line.text == "VIDA ×2 · VELOCIDAD ×1", "una línea con lo que queda en cada hueco («%s»)" % line.text)
	check(line.label_settings.font_size >= 22, "legible en el móvil (%d px)" % line.label_settings.font_size)
	check(line.position == overlay.BUFF_POS, "sin efectos activos va en la primera fila (%s)" % line.position)
	gm.apply_buff(&"speed", 30.0)
	overlay._process(0.0)
	check(is_equal_approx(line.position.y, overlay.BUFF_POS.y + overlay.BUFF_ROW), "con un efecto activo va debajo de él (%s)" % line.position)
	gm.apply_buff(&"luck", 60.0)
	overlay._process(0.0)
	check(is_equal_approx(line.position.y, overlay.BUFF_POS.y + overlay.BUFF_ROW * 2.0), "con dos, debajo de los dos (%s)" % line.position)
	_im().take_potion(&"potion_speed")
	overlay._process(0.0)
	check(line.text == "VIDA ×2", "al beberse la última de un tipo, su parte desaparece («%s»)" % line.text)
	_im().take_potion(&"potion_heal")
	_im().take_potion(&"potion_heal")
	overlay._process(0.0)
	check(not line.visible, "y sin ninguna, la línea también")
	gm.clear_buffs()
	overlay.free()
	_im().consumables = slots


## Cada tarjeta de poción de la tienda dice cuántas lleva Tico en los huecos y se mantiene al día con ellos.
func test_shop_cards_show_how_many_are_in_the_slot() -> void:
	var had := _set_gold(1000)
	var slots := _empty_potion_slots()
	var shop := _new_shop()
	check(_owned_text(shop, &"potion_speed") == "En hueco: 0", "al abrir la tienda, ninguna en el hueco («%s»)" % _owned_text(shop, &"potion_speed"))
	shop._on_buy_potion(&"potion_speed", _price(&"potion_speed"))
	shop._on_buy_potion(&"potion_speed", _price(&"potion_speed"))
	check(_owned_text(shop, &"potion_speed") == "En hueco: 2" and _owned_text(shop, &"potion_luck") == "En hueco: 0", "comprar la sube en su tarjeta y solo en la suya («%s»)" % _owned_text(shop, &"potion_speed"))
	check(shop._toast_label.text.contains("Poción de Velocidad: 2 en el hueco"), "el aviso de la compra dice cuántas lleva («%s»)" % shop._toast_label.text)
	_im().take_potion(&"potion_speed")
	check(_owned_text(shop, &"potion_speed") == "En hueco: 1", "y baja cuando se bebe una, aunque no sea por la tienda («%s»)" % _owned_text(shop, &"potion_speed"))
	shop.free()
	_im().consumables = slots
	_set_gold(had)


## Lo que dice la etiqueta «En hueco» de la tarjeta de una poción.
func _owned_text(shop: Control, pot_id: StringName) -> String:
	for card in shop._potions_grid.get_children():
		if card.get_meta("pot_id") == pot_id:
			var label: Label = card.find_child("OwnedLabel", true, false)
			return label.text if label else "(sin etiqueta)"
	return "(sin tarjeta)"


# ─── Muro, farmeo y selector de sala (spec de rangos, apartado 7) ─────

## Estado de la partida en GameManager, para devolverlo al acabar cada prueba (las pruebas del muro lo
## cambian con load_save_data, la misma entrada que usa el guardado).
func _gm_snapshot() -> Dictionary:
	var gm := _gm()
	var snap: Dictionary = gm.to_save_data()
	snap["_dungeon_state"] = gm.dungeon_state
	return snap


func _gm_restore(snap: Dictionary) -> void:
	var gm := _gm()
	gm.dungeon_state = snap["_dungeon_state"]  # antes de cargar: sin partida en marcha no se mueve ningún pasillo
	gm.load_save_data(snap)
	gm.clear_buffs()


## Partida de prueba con su sala, su récord y, si se dan, muro y candado. La deja en marcha.
func _gm_setup(current: int, best: int, wall: int = 0, locked: bool = false) -> void:
	var gm := _gm()
	gm.load_save_data({"current_enemy_level": current, "best_enemy_level": best, "wall_room": wall, "room_locked": locked})
	gm.dungeon_state = gm.DungeonState.RUNNING


## Pasillo de prueba sobre la partida de GameManager (empieza en su sala actual).
func _new_corridor() -> Node2D:
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	return corridor


func test_losing_leaves_a_wall_and_farms_the_room_before() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(12, 12)
	gm.register_hero_death()
	check(gm.current_enemy_level == 11 and gm.wall_room == 12, "cae en la 12: reaparece en la 11 y la 12 es el muro (%d, %d)" % [gm.current_enemy_level, gm.wall_room])
	gm.request_respawn()
	gm.room_cleared()
	gm.room_cleared()
	check(gm.current_enemy_level == 11, "las dos primeras victorias farmea la 11 (%d)" % gm.current_enemy_level)
	gm.room_cleared()
	check(gm.current_enemy_level == 12, "a la tercera vuelve al muro (%d)" % gm.current_enemy_level)
	gm.register_hero_death()
	gm.request_respawn()
	gm.room_cleared()
	gm.room_cleared()
	check(gm.current_enemy_level == 11, "tras otra caída la cuenta vuelve a empezar (%d)" % gm.current_enemy_level)
	_im().equipment_changed.emit({})
	check(gm.current_enemy_level == 12, "con equipo nuevo prueba el muro al momento (%d)" % gm.current_enemy_level)
	gm.register_hero_death()
	gm.request_respawn()
	gm.apply_buff(&"luck", 60.0)
	check(gm.current_enemy_level == 12, "y también al beber una poción de efecto (%d)" % gm.current_enemy_level)
	gm.room_cleared()
	check(gm.wall_room == 0 and gm.current_enemy_level == 13 and gm.best_enemy_level == 13, "vencer el muro lo quita y sube el récord (muro %d, sala %d, récord %d)" % [gm.wall_room, gm.current_enemy_level, gm.best_enemy_level])
	_gm_restore(snap)
	await _flush_deferred_saves()


func test_a_wall_in_room_one_is_retried_on_every_respawn() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(1, 1)
	gm.register_hero_death()
	check(gm.current_enemy_level == 1 and gm.wall_room == 1, "cae en la 1: reaparece en la 1, delante del muro (%d, %d)" % [gm.current_enemy_level, gm.wall_room])
	gm.request_respawn()
	gm.room_cleared()
	check(gm.wall_room == 0 and gm.current_enemy_level == 2 and gm.best_enemy_level == 2, "al vencerlo sigue a la 2 (muro %d, sala %d, récord %d)" % [gm.wall_room, gm.current_enemy_level, gm.best_enemy_level])
	_gm_restore(snap)
	await _flush_deferred_saves()


func test_room_selector_and_lock() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(30, 30)
	gm.travel_to_room(99)
	check(gm.current_enemy_level == 30 and not gm.room_locked, "no pasa del récord, y el récord no pone el candado (%d)" % gm.current_enemy_level)
	gm.travel_to_room(5)
	check(gm.current_enemy_level == 5 and gm.room_locked, "una sala por debajo del récord pone el candado (%d)" % gm.current_enemy_level)
	gm.room_cleared()
	check(gm.current_enemy_level == 5, "con candado repite la sala (%d)" % gm.current_enemy_level)
	gm.register_hero_death()
	gm.request_respawn()
	check(gm.current_enemy_level == 4 and gm.wall_room == 5 and gm.room_locked, "si cae con candado, el candado baja con él (sala %d, muro %d)" % [gm.current_enemy_level, gm.wall_room])
	gm.room_cleared()
	gm.room_cleared()
	gm.room_cleared()
	check(gm.current_enemy_level == 4, "con candado no reintenta el muro (%d)" % gm.current_enemy_level)
	gm.set_room_locked(false)
	check(gm.current_enemy_level == 4 and not gm.room_locked, "sin candado sigue delante del muro (%d)" % gm.current_enemy_level)
	gm.travel_to_room(0)
	check(gm.current_enemy_level == 1, "tampoco baja de la sala 1 (%d)" % gm.current_enemy_level)
	gm.travel_to_room(5)
	check(gm.current_enemy_level == 5 and not gm.room_locked, "elegir el muro es probarlo, sin candado (%d)" % gm.current_enemy_level)
	_gm_setup(7, 30, 0, true)
	gm.set_room_locked(false)
	check(gm.current_enemy_level == 29, "sin muro, quitar el candado lo lleva delante del récord (%d)" % gm.current_enemy_level)
	_gm_setup(30, 30)
	gm.set_room_locked(true)
	gm.room_cleared()
	check(gm.current_enemy_level == 30 and gm.best_enemy_level == 31, "vencer el récord con candado lo sube aunque Tico se quede (sala %d, récord %d)" % [gm.current_enemy_level, gm.best_enemy_level])
	check(gm.selector_target(25, -1, true) == 11, "mantener atrás desde la 25: principio del bioma anterior (%d)" % gm.selector_target(25, -1, true))
	check(gm.selector_target(25, 1, true) == 31, "mantener adelante: principio del siguiente (%d)" % gm.selector_target(25, 1, true))
	check(gm.selector_target(5, -1, true) == 1, "desde el primer bioma, la 1 (%d)" % gm.selector_target(5, -1, true))
	check(gm.selector_target(31, 1, false) == 31, "sin pasar del récord (%d)" % gm.selector_target(31, 1, false))
	_gm_restore(snap)
	await _flush_deferred_saves()


func test_wall_and_lock_are_saved() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(11, 12, 12, true)
	var data: Dictionary = gm.to_save_data()
	check(int(data.get("wall_room", 0)) == 12 and bool(data.get("room_locked", false)), "el guardado lleva el muro y el candado (%s)" % data)
	gm.load_save_data({"current_enemy_level": 3, "best_enemy_level": 9})
	check(gm.wall_room == 0 and not gm.room_locked, "una partida sin esos campos carga sin muro ni candado")
	gm.load_save_data({"current_enemy_level": 3, "best_enemy_level": 9, "wall_room": 50})
	check(gm.wall_room == 9, "un muro más allá del récord se queda en el récord (%d)" % gm.wall_room)
	_gm_restore(snap)
	await _flush_deferred_saves()


func test_each_room_starts_with_full_health_and_travel_abandons_the_fight() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(3, 12)
	var start: Dictionary = _im().get_materials()
	var corridor := _new_corridor()
	var hero: Node2D = corridor.get_node("Hero")
	var enemy: Node2D = corridor.get_node("Enemy")
	hero.hp = maxi(1, hero.max_hp / 2)
	corridor._enter_room(3)
	check(hero.hp == hero.max_hp, "al entrar en una sala, Tico tiene la vida llena (%d/%d)" % [hero.hp, hero.max_hp])
	corridor._begin_fight()
	hero.hp = maxi(1, hero.max_hp / 2)
	gm.travel_to_room(7)
	check(not corridor.combat_controller.combat_active, "viajar abandona el combate a medias")
	check(corridor.level == 7 and enemy.level == 7 and enemy.alive, "el pasillo pasa a la sala 7 con su enemigo (%d, %d)" % [corridor.level, enemy.level])
	check(hero.alive and hero.hp == hero.max_hp, "Tico llega con la vida llena (%d/%d)" % [hero.hp, hero.max_hp])
	check(_gained_since(start).is_empty(), "sin premio: no entra botín (%s)" % _gained_since(start))
	corridor.queue_free()
	_gm_restore(snap)
	await _flush_deferred_saves()
	await _silence_loot_sounds()


## En el duelo fijo el siguiente enemigo aparece en cuanto cae el anterior: la sala del cartel y la vida llena de
## Tico se ponen al día en ese momento, no al empezar el combate (antes el cartel decía «Sala 3» con el enemigo de la 4).
func test_winning_announces_the_next_room_with_its_enemy() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(3, 12)
	gm.enemies_defeated[3] = true  # sin plano de primera victoria
	var start: Dictionary = _im().get_materials()
	var corridor := _new_corridor()
	var rooms: Array = []
	corridor.room_entered.connect(func(room: int, _boss: bool): rooms.append(room))
	var hero: Node2D = corridor.get_node("Hero")
	var enemy: Node2D = corridor.get_node("Enemy")
	corridor._begin_fight()
	hero.hp = maxi(1, hero.max_hp / 2)
	enemy.take_damage(enemy.hp)
	check(corridor._smoke != null and not corridor._next_duel_shown, "tras vencer, el rival siguiente espera al humo")
	corridor.skip_transition()  # sin esperar la derrota, el humo y la presentación
	check(enemy.alive and enemy.level == 4, "tras vencer en la 3 espera el enemigo de la 4 (%d)" % enemy.level)
	check(rooms.has(4), "y el cartel ya dice sala 4 (%s)" % [rooms])
	check(hero.hp == hero.max_hp, "con Tico curado para el duelo siguiente (%d/%d)" % [hero.hp, hero.max_hp])
	corridor.queue_free()
	_gm_restore(snap)
	_im().consume_materials(_gained_since(start))  # devuelve el botín de prueba
	await _flush_deferred_saves()
	await _silence_loot_sounds()


func test_farming_puts_another_enemy_of_the_same_room_ahead() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(11, 12, 12)
	gm.enemies_defeated[11] = true  # sin plano de primera victoria
	var start: Dictionary = _im().get_materials()
	var corridor := _new_corridor()
	var enemy: Node2D = corridor.get_node("Enemy")
	enemy.take_damage(enemy.hp)
	corridor.skip_transition()  # sin esperar el humo entre duelos
	check(gm.current_enemy_level == 11, "tras vencer delante del muro sigue en la 11 (%d)" % gm.current_enemy_level)
	check(enemy.alive and enemy.level == 11, "el pasillo pone otro enemigo de la 11 por delante (%d)" % enemy.level)
	check(corridor.level == 11, "y el duelo sigue en la sala 11 (%d)" % corridor.level)  # duelo fijo: ya no hay puertas
	corridor.queue_free()
	_gm_restore(snap)
	_im().consume_materials(_gained_since(start))  # devuelve el botín de prueba
	await _flush_deferred_saves()
	await _silence_loot_sounds()


func test_losing_in_the_corridor_respawns_in_the_room_before() -> void:
	var gm := _gm()
	var saved := _empty_inventory()  # Tico sin las habilidades de la partida: el pulso mortal lo tumba
	var snap := _gm_snapshot()
	_gm_setup(12, 12)
	var corridor := _new_corridor()
	var hero: Node2D = corridor.get_node("Hero")
	hero.take_damage(hero.hp * 10, true)  # el pulso no mira la armadura
	check(gm.wall_room == 12 and gm.current_enemy_level == 11, "cae en la 12: muro en la 12 y vuelta a la 11 (%d, %d)" % [gm.wall_room, gm.current_enemy_level])
	corridor._respawn_timer.stop()
	corridor._on_respawn_timeout()  # sin esperar el segundo y medio de la reaparición
	check(corridor.level == 11 and corridor.enemy.level == 11, "reaparece en la 11 con su enemigo (%d, %d)" % [corridor.level, corridor.enemy.level])
	check(hero.alive and hero.hp == hero.max_hp, "con la vida llena (%d/%d)" % [hero.hp, hero.max_hp])
	corridor.queue_free()
	_gm_restore(snap)
	_restore_inventory(saved)
	await _flush_deferred_saves()
	await _silence_loot_sounds()


func test_travel_while_fallen_waits_for_the_respawn() -> void:
	var gm := _gm()
	var saved := _empty_inventory()  # Tico sin las habilidades de la partida: el pulso mortal lo tumba
	var snap := _gm_snapshot()
	_gm_setup(12, 12)
	var corridor := _new_corridor()
	var hero: Node2D = corridor.get_node("Hero")
	hero.take_damage(hero.hp * 10, true)
	gm.travel_to_room(5)
	check(corridor.state == corridor.State.DEAD and not hero.alive, "con Tico caído, el viaje espera a la reaparición")
	corridor._respawn_timer.stop()
	corridor._on_respawn_timeout()
	check(corridor.level == 5 and corridor.enemy.level == 5 and hero.alive, "reaparece en la sala elegida (%d, %d)" % [corridor.level, corridor.enemy.level])
	check(gm.room_locked, "con el candado de haberla elegido")
	corridor.queue_free()
	_gm_restore(snap)
	_restore_inventory(saved)
	await _flush_deferred_saves()
	await _silence_loot_sounds()


func test_room_selector_in_the_strip() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(11, 12, 12)
	var overlay: Control = load("res://scripts/ui/HeroViewOverlay.gd").new()
	add_child(overlay)
	check(overlay._record_label.text == "Muro: sala 12", "con muro, el indicador dice «Muro: sala 12» (%s)" % overlay._record_label.text)
	for b in [overlay._prev_button, overlay._lock_button, overlay._next_button]:
		check(b.size.x >= 88.0 and b.size.y >= 88.0, "botón del selector con tamaño de dedo (%s)" % b.size)
	overlay._on_arrow_down(1)
	overlay._on_arrow_up(1)
	check(gm.current_enemy_level == 12 and not gm.room_locked, "toque corto adelante: la 12, probar el muro sin candado (%d)" % gm.current_enemy_level)
	check(overlay._next_button.disabled, "en el récord, la flecha adelante se apaga")
	_gm_setup(25, 40)
	overlay._on_arrow_down(-1)
	overlay._process(overlay.LONG_PRESS + 0.05)
	check(gm.current_enemy_level == 11 and gm.room_locked, "mantener pulsado atrás: principio del bioma anterior, con candado (%d)" % gm.current_enemy_level)
	overlay._on_arrow_up(-1)
	check(gm.current_enemy_level == 11, "soltar tras el salto no mueve otra sala (%d)" % gm.current_enemy_level)
	overlay._on_lock_pressed()
	check(not gm.room_locked and gm.current_enemy_level == 39, "quitar el candado lo lleva delante del récord (%d)" % gm.current_enemy_level)
	check(overlay._record_label.text == "Récord: sala 40", "sin muro vuelve a decir el récord (%s)" % overlay._record_label.text)
	overlay.queue_free()
	_gm_restore(snap)
	await _flush_deferred_saves()
