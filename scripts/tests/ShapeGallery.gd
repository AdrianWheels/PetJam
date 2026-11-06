extends Node2D
## 🧪 Galería de personajes (solo desarrollo): muestra todos los arquetipos de enemigo y el héroe
## con distintos equipos, animando reposo/anticipación/golpe/daño para revisar el dibujo.
## Ejecutar: godot --path . res://scenes/tests/ShapeGallery.tscn

const HERO_SCENE := preload("res://scenes/Hero.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

var _enemies: Array = []
var _heroes: Array = []
var _t := 0.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("2a1f25")
	bg.size = Vector2(1080, 1920)
	add_child(bg)
	var archetypes := [&"slime", &"skeleton", &"bat", &"golem", &"wraith", &"boss", &"boss", &"boss", &"boss", &"boss"]
	var boss_rooms := [10, 20, 30, 40, 50]
	var boss_i := 0
	for i in archetypes.size():
		var e: Node = ENEMY_SCENE.instantiate()
		add_child(e)
		var is_boss: bool = archetypes[i] == &"boss"
		var room: int = boss_rooms[boss_i] if is_boss else 5
		if is_boss:
			boss_i += 1
		e.configure_for_level(room, is_boss)
		if not is_boss:
			e._apply_archetype(archetypes[i])
			e.reset_stats()
		e.position = Vector2(180 + (i % 3) * 340, 330 + int(i / 3) * 300)
		e.wake()
		_enemies.append(e)
		print("[Gallery] enemy ", archetypes[i], " room ", room)
	# Héroes: sin equipo, básico, avanzado, maestro
	var loadouts := [
		{},
		{"main_hand": {"tier": "common", "rarity": "basic"}, "feet": {"tier": "uncommon", "rarity": "basic"}},
		{"main_hand": {"tier": "rare", "rarity": "advanced"}, "off_hand": {"tier": "rare", "rarity": "advanced"}, "head": {"tier": "uncommon", "rarity": "advanced"}},
		{"main_hand": {"tier": "legendary", "rarity": "master"}, "off_hand": {"tier": "epic", "rarity": "master"}, "head": {"tier": "epic", "rarity": "master"}, "feet": {"tier": "legendary", "rarity": "master"}},
	]
	for i in loadouts.size():
		var h: Node = HERO_SCENE.instantiate()
		add_child(h)
		h.position = Vector2(150 + i * 260, 1700)
		h.gear = loadouts[i]
		h.armor = 12 if i >= 2 else 0
		_heroes.append(h)
		print("[Gallery] hero loadout ", i)


func _process(delta: float) -> void:
	_t += delta
	# Ciclo: reposo → anticipación → golpe → daño
	var phase := fmod(_t, 2.4)
	for e in _enemies:
		if phase > 0.6 and phase < 0.9:
			e._windup = (phase - 0.6) / 0.3
			e.is_attacking = true
		elif phase >= 0.9 and phase < 0.95:
			e._strike = 1.0
			e._windup = 0.0
		elif phase > 1.6 and phase < 1.65:
			e._hurt = e.HURT_TIME
		else:
			e.is_attacking = false
	for i in _heroes.size():
		var h: Node = _heroes[i]
		h.walking = i % 2 == 0 and phase < 0.6
		h.walk_speed = 190.0
		h.look_target = h.position + Vector2(300, -60)
		if phase > 0.6 and phase < 0.9:
			h._windup = (phase - 0.6) / 0.3
			h.is_attacking = true
		elif phase >= 0.9 and phase < 0.95:
			h._strike = 1.0
			h._windup = 0.0
		elif phase > 1.6 and phase < 1.65:
			h._hurt = h.HURT_TIME
		else:
			h.is_attacking = false
