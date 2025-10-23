extends Node2D

@onready var hero: Node = $Hero
@onready var enemy: Node = $Enemy
@onready var combat_controller: Node = $CombatController
@onready var particle_manager: Node = $ParticleManager
@onready var camera: Camera2D = get_node_or_null("Camera2D")

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
var _game_manager := get_node_or_null("/root/GameManager")

func _ready():
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

        reset_room(true)

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
        if particle_manager and particle_manager.has_method("update_particles"):
                particle_manager.update_particles(delta)
        queue_redraw()

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
        level = min(BOSS_LEVEL, level + 1)
        spawn_enemy(level, hero.position.x + SPAWN_DISTANCE)
        state = State.RUN
        dist_ref = enemy.position.x - hero.position.x

func spawn_enemy(lv: int, x: float):
        if enemy == null:
                return
        var boss := lv >= BOSS_LEVEL
        if enemy.has_method("configure_for_level"):
                enemy.configure_for_level(lv, boss)
        else:
                enemy.level = lv
                enemy.is_boss = boss
                enemy.reset_stats()
        enemy.position = Vector2(x, GROUND_Y)
        enemy.velocity = Vector2.ZERO
        if combat_controller and combat_controller.has_method("stop_combat"):
                combat_controller.stop_combat()

func reset_room(full_reset: bool):
        if hero:
                hero.respawn(HERO_START)
        if full_reset:
                level = 1
        spawn_enemy(level, HERO_START.x + SPAWN_DISTANCE)
        state = State.RUN
        cam_x = hero.position.x - 960.0 * 0.33 if hero else 0.0
        ground_offset = 0.0
        dist_ref = enemy.position.x - hero.position.x if hero and enemy else 0.0

func _draw():
        draw_parallax(0.12, Color(0x0e / 255.0, 0x17 / 255.0, 0x26 / 255.0), 40, 0.6)
        draw_parallax(0.3, Color(0x0a / 255.0, 0x1a / 255.0, 0x2f / 255.0), 20, 0.8)
        draw_rect(Rect2(-1000, GROUND_Y, 2000, 540 - GROUND_Y), Color(0x11 / 255.0, 0x18 / 255.0, 0x27 / 255.0))
        draw_ground()
        draw_hero()
        draw_enemy()
        if particle_manager and particle_manager.has_method("draw_particles"):
                particle_manager.draw_particles(self, cam_x)

func draw_parallax(factor: float, color: Color, stripe: int, alpha: float):
        var w := 960
        var off := -int(fmod(cam_x * factor, float(stripe)))
        color.a = alpha
        for x in range(off - stripe, w + stripe, stripe):
                draw_rect(Rect2(x, 0, 2, GROUND_Y - 40), color)

func draw_ground():
        var w := 960
        var step := 32
        var off := -int(fmod(ground_offset * 0.8, float(step)))
        for x in range(off - step, w + step, step):
                var y := GROUND_Y + ((x * 0.15) as int & 7)
                draw_line(Vector2(x, y), Vector2(x + step, y), Color(0x1f / 255.0, 0x29 / 255.0, 0x37 / 255.0), 2)

func draw_hero():
        if hero == null:
                return
        var pos := hero.position - Vector2(cam_x, 0)
        var size := hero.size
        draw_rect(Rect2(pos - size / 2.0, size), Color(0x38 / 255.0, 0xbf / 255.0, 0xf8 / 255.0))
        var stripe_size := size - Vector2(16, 16)
        draw_rect(Rect2(pos - stripe_size / 2.0, stripe_size), Color(0x0e / 255.0, 0xa5 / 255.0, 0xe9 / 255.0))

func draw_enemy():
        if enemy == null:
                return
        var pos := enemy.position - Vector2(cam_x, 0)
        var size := enemy.size
        var color := Color.from_hsv((enemy.level - 1) / 7.0, 1.0, 1.0)
        if enemy.shape == "rect":
                draw_rect(Rect2(pos - size / 2.0, size), color)
        else:
                draw_circle(pos, size.x / 2.0, color)

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
        reset_room(false)

func _on_enemy_stats_reset():
        dist_ref = enemy.position.x - hero.position.x if hero and enemy else 0.0

func _on_boss_defeated():
        state = State.COMPLETE
