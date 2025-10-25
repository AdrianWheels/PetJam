extends Node2D

@onready var hero: Node = $Hero
@onready var enemy: Node = $Enemy
@onready var combat_controller: Node = $CombatController
@onready var particle_manager: Node = $ParticleManager
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var parallax_bg: Node2D = get_node_or_null("ParallaxBG")

const HERO_SPEED := 120.0
const SPAWN_DISTANCE := 520.0
const GROUND_Y := 460.0
const CAM_LERP := 0.12
const HERO_START := Vector2(2100, GROUND_Y)
const BOSS_LEVEL := 8
const RESPAWN_DELAY := 1.5

enum State { RUN, FIGHT, DEAD, COMPLETE }

var state := State.RUN
var level := 1
var cam_x := 0.0
var ground_offset := 0.0
var dist_ref := 0.0

var _respawn_timer: Timer
var _game_manager: Node
var _dungeon_layout: Node2D

func _ready():
        _game_manager = get_node_or_null("/root/GameManager")
        # Buscar DungeonLayout en el árbol
        _dungeon_layout = get_node_or_null("../DungeonLayout")
        if _dungeon_layout == null:
                _dungeon_layout = get_tree().root.find_child("DungeonLayout", true, false)
        if _dungeon_layout:
                print("Corridor: DungeonLayout found at %s" % _dungeon_layout.get_path())
        
        # Activar cámara de Corridor cuando está visible
        if camera:
                camera.enabled = visible
        
        _respawn_timer = Timer.new()
        _respawn_timer.one_shot = true
        _respawn_timer.wait_time = RESPAWN_DELAY
        add_child(_respawn_timer)
        _respawn_timer.timeout.connect(_on_respawn_timeout)

        if hero and hero.has_signal("died"):
                hero.connect("died", Callable(self, "_on_local_hero_died"))
        if enemy and enemy.has_signal("stats_reset"):
                enemy.connect("stats_reset", Callable(self, "_on_enemy_stats_reset"))

        if _game_manager:
                if _game_manager.has_signal("hero_died"):
                        _game_manager.connect("hero_died", Callable(self, "_on_game_manager_hero_died"))
                if _game_manager.has_signal("hero_respawned"):
                        _game_manager.connect("hero_respawned", Callable(self, "_on_game_manager_hero_respawned"))
                if _game_manager.has_signal("boss_defeated"):
                        _game_manager.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
                if _game_manager.has_signal("enemy_level_changed"):
                        _game_manager.connect("enemy_level_changed", Callable(self, "_on_enemy_level_changed"))

        reset_combat(true)

func _notification(what: int) -> void:
        # Detectar cuando Corridor se hace visible/invisible
        if what == NOTIFICATION_VISIBILITY_CHANGED:
                if camera:
                        camera.enabled = visible
                        if visible:
                                print("Corridor: Camera enabled")
                        else:
                                print("Corridor: Camera disabled")

func _process(delta: float):
        match state:
                State.RUN:
                        update_run(delta)
                State.FIGHT:
                        update_fight(delta)
                State.DEAD:
                        update_dead(delta)
                State.COMPLETE:
                        update_complete(delta)
        cam_follow(delta)
        
        # Actualizar parallax con el offset del suelo
        if parallax_bg and parallax_bg.has_method("update_from_corridor"):
                parallax_bg.update_from_corridor(ground_offset)
        
        if particle_manager and particle_manager.has_method("update_particles"):
                particle_manager.update_particles(delta)
        # queue_redraw() desactivado - DungeonLayout maneja los visuales ahora

func update_run(delta: float):
        if hero and hero.alive:
                hero.position.x += HERO_SPEED * delta
        if hero and enemy and hero.alive and enemy.alive:
                if check_overlap(hero.position, hero.size, enemy.position, enemy.size):
                        state = State.FIGHT
                        if combat_controller and combat_controller.has_method("start_combat"):
                                combat_controller.start_combat()
        ground_offset += HERO_SPEED * delta

func update_fight(_delta: float):
        pass

func update_dead(_delta: float):
        pass

func update_complete(_delta: float):
        pass

func cam_follow(delta: float):
        if hero == null or camera == null:
                return
        var target_x = hero.position.x - 960.0 * 0.33
        cam_x = lerp(cam_x, target_x, 1.0 - pow(1.0 - CAM_LERP, max(1.0, delta * 60.0)))
        camera.position.x = cam_x

func check_overlap(pos1: Vector2, size1: Vector2, pos2: Vector2, size2: Vector2) -> bool:
        var rect1 = Rect2(pos1 - size1 / 2.0, size1)
        var rect2 = Rect2(pos2 - size2 / 2.0, size2)
        return rect1.intersects(rect2)

func advance_enemy():
        if state == State.COMPLETE:
                return
        if enemy and enemy.is_boss and not enemy.alive:
                state = State.COMPLETE
                return
        # Delegar al GameManager para avanzar nivel de enemigo
        if _game_manager and _game_manager.has_method("advance_enemy_level"):
                _game_manager.advance_enemy_level()
        else:
                # Fallback local si no hay GameManager
                level = min(BOSS_LEVEL, level + 1)
                spawn_enemy(level, hero.position.x + SPAWN_DISTANCE)
                state = State.RUN
                dist_ref = enemy.position.x - hero.position.x

func spawn_enemy(lv: int, x: float):
        if enemy == null:
                return
        
        # Obtener posición desde DungeonLayout si está disponible
        var spawn_pos := Vector2(x, GROUND_Y)
        if _dungeon_layout and _dungeon_layout.has_method("get_enemy_spawn_for_level"):
                spawn_pos = _dungeon_layout.get_enemy_spawn_for_level(lv)
                print("Corridor: Using DungeonLayout spawn position for level %d: %v" % [lv, spawn_pos])
        else:
                # Fallback a posición calculada
                spawn_pos = Vector2(x, GROUND_Y)
        
        var boss := lv >= BOSS_LEVEL
        if enemy.has_method("configure_for_level"):
                enemy.configure_for_level(lv, boss)
        else:
                enemy.level = lv
                enemy.is_boss = boss
                enemy.reset_stats()
        enemy.position = spawn_pos
        enemy.velocity = Vector2.ZERO
        if combat_controller and combat_controller.has_method("stop_combat"):
                combat_controller.stop_combat()

func reset_combat(full_reset: bool):
        # Obtener posición inicial del héroe desde DungeonLayout
        var hero_spawn_pos := HERO_START
        if _dungeon_layout and _dungeon_layout.has_method("get_hero_spawn"):
                hero_spawn_pos = _dungeon_layout.get_hero_spawn()
                print("Corridor: Using DungeonLayout hero spawn: %v" % hero_spawn_pos)
        
        if hero:
                hero.respawn(hero_spawn_pos)
        if full_reset:
                level = 1
        else:
                # En respawn, sincronizar con GameManager
                if _game_manager and "current_enemy_level" in _game_manager:
                        level = _game_manager.current_enemy_level
                        print("Corridor: Syncing enemy level from GameManager = %d" % level)
        spawn_enemy(level, hero_spawn_pos.x + SPAWN_DISTANCE)
        state = State.RUN
        cam_x = hero.position.x - 960.0 * 0.33 if hero else 0.0
        ground_offset = 0.0
        dist_ref = enemy.position.x - hero.position.x if hero and enemy else 0.0

func _draw():
        # Sistema de dibujo legacy DESACTIVADO - DungeonLayout maneja los visuales
        pass

# Las siguientes funciones están desactivadas (legacy):
# - draw_parallax() 
# - draw_ground()
# - draw_hero()
# - draw_enemy()
# Hero y Enemy ahora usan sus propios nodos visuales en las escenas .tscn

func _start_respawn_timer():
        if _respawn_timer.is_stopped():
                _respawn_timer.start()

func _on_local_hero_died():
        state = State.DEAD
        if combat_controller and combat_controller.has_method("stop_combat"):
                combat_controller.stop_combat()
        if _game_manager == null:
                _start_respawn_timer()

func _on_game_manager_hero_died(_death_count):
        if state != State.COMPLETE:
                _start_respawn_timer()

func _on_respawn_timeout():
        if _game_manager and _game_manager.has_method("request_respawn"):
                if _game_manager.request_respawn():
                        return
                if _game_manager.has_method("is_run_failed") and _game_manager.is_run_failed():
                        state = State.COMPLETE
                        return
        _perform_respawn()

func _on_game_manager_hero_respawned(_death_count):
        _perform_respawn()

func _perform_respawn():
        if state == State.COMPLETE:
                return
        reset_combat(false)

func _on_enemy_stats_reset():
        dist_ref = enemy.position.x - hero.position.x if hero and enemy else 0.0

func _on_boss_defeated():
        state = State.COMPLETE

func _on_enemy_level_changed(new_level: int):
        print("Corridor: Enemy level changed to %d" % new_level)
        level = new_level
        # Si avanzamos (nuevo nivel > actual), spawneamos nuevo enemigo
        if state == State.RUN or state == State.FIGHT:
                spawn_enemy(level, hero.position.x + SPAWN_DISTANCE)
                state = State.RUN
