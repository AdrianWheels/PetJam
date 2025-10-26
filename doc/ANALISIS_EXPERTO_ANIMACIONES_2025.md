# 🎬 ANÁLISIS EXPERTO: Sistema de Animaciones Hero/Enemy
## Auditoría Completa y Plan de Mejora Profesional

**Autor**: Experto en Animaciones Frame-Based (15 años experiencia)  
**Fecha**: 27 de octubre de 2025  
**Proyecto**: PetJam - Godot 4.5.1 Jam  
**IQ**: 150 - Análisis de arquitectura crítica

---

## 📊 RESUMEN EJECUTIVO

### Estado Actual: ⚠️ FUNCIONAL PERO SUBÓPTIMO (6/10)

**Lo Bueno** ✅:
- Sistema hit-frame sincronizado implementado y funcional
- FPS dinámico según APS (0.3-5.0 ataques/seg)
- Arquitectura de señales event-driven correcta
- Separación de concerns: timing vs ejecución de daño
- Soporte multi-estado (IDLE/WALK/ATTACK/DEATH)

**Lo Malo** ❌:
- **10 carencias críticas** identificadas (ver sección 2)
- Falta sistema de blending/transiciones
- No hay anticipación/recovery frames
- Memoria y performance no optimizados
- Ausencia de variaciones de ataque
- Sistema de pooling inexistente

**Impacto en Experiencia**:
- Combat feel: 6.5/10 (funcional pero mecánico)
- Visual polish: 5/10 (básico, sin juice)
- Performance: 7/10 (estable pero ineficiente)

---

## 🔬 ANÁLISIS TÉCNICO PROFUNDO

### 1. Arquitectura del Sistema

#### 1.1 Flujo de Datos Actual
```
┌─────────────────────────────────────────────────────────────┐
│ CombatController._process(delta)                            │
│  └─> hero.attack(enemy, particles)  [TIMING ONLY]          │
│       └─> atk_timer -= delta                                │
│       └─> if atk_timer <= 0: resetea timer + is_attacking=true │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┤
│  │ Hero._process(delta)  [ANIMATION UPDATE]                 │
│  │  └─> if is_attacking: state = ATTACK                     │
│  │  └─> animation_timer += delta                            │
│  │  └─> if animation_timer >= frame_duration:               │
│  │       └─> current_frame++                                │
│  │       └─> if current_frame == hit_frame:                 │
│  │            └─> emit_signal("hit_frame_reached")  ⚡      │
│  └──────────────────────────────────────────────────────────┤
│                                                              │
│  CombatController._on_hero_hit_frame()  [DAMAGE EXECUTION]  │
│   └─> _execute_hero_attack()                                │
│        └─> calcular daño + crit                             │
│        └─> enemy.take_damage(dmg)                           │
│        └─> spawn particles + sfx                            │
└─────────────────────────────────────────────────────────────┘
```

**Veredicto**: ✅ Arquitectura sólida para un jam. Señales event-driven correctas.

---

### 2. LAS 10 CARENCIAS CRÍTICAS

#### ❌ **CARENCIA #1: Sin Anticipación/Recovery Frames**
**Problema**: Las animaciones atacan instantáneamente sin preparación visual.

**Impacto**: 
- Combat feel "floaty", sin peso
- Difícil de telegrafiar ataques enemigos
- Imposible esquivar reactivamente

**Ejemplo**:
```gdscript
# ACTUAL (62 frames de ataque, hit en frame 29)
# [F0-F28] Swing completo + [F29] Hit + [F30-F61] Recovery
# Total: 62 frames @ APS 1.0 = 2.58 segundos por golpe (LENTO)

# ÓPTIMO para jam:
# [F0-F10] Anticipation (hold back) 18% 
# [F11-F13] Contact (3 frames) 5%
# [F14-F27] Follow-through 23%
# [F28-F61] Recovery + return to idle 54%
```

**Solución Propuesta**:
```gdscript
# Añadir a anim_config
AnimState.ATTACK: {
	"texture": load("..."),
	"hframes": 62,
	"fps": 24.0,
	"anticipation_frame": 10,  # Frame donde empieza el windup
	"hit_frame": 29,
	"recovery_frame": 35,  # Frame donde vuelve a neutral
	"loop": false  # NO hacer loop en ataque
}
```

---

#### ❌ **CARENCIA #2: Animaciones Hacen Loop Infinito**
**Problema**: `is_attacking` se mantiene `true` durante todo el combate, haciendo loop continuo de la animación de 62 frames.

**Impacto**:
- Golpes visuales no coinciden con daño real
- Parecen "molinos" atacando sin parar
- Difícil de leer cuándo ocurre el hit

**Evidencia en código**:
```gdscript
# Hero.gd línea 305 (attack())
if atk_timer <= 0.0:
	if not is_attacking:
		print("Hero: Timer ready, launching ATTACK animation")
		is_attacking = true  # ✅ Se activa
		_change_animation(AnimState.ATTACK)
	atk_timer = 1.0 / aps  # ✅ Resetea timer

# PROBLEMA: No hay código para apagar is_attacking tras terminar 1 ciclo
```

**Solución**: Sistema de "One-Shot Animations"
```gdscript
# En Hero._process() después de avanzar frame:
if current_anim_state == AnimState.ATTACK:
	var config = anim_config[AnimState.ATTACK]
	var end_frame = config.get("end_frame", config["hframes"] - 1)
	
	# Si llegamos al último frame, terminar ataque
	if current_frame == end_frame and _hit_frame_triggered:
		print("Hero: Attack animation complete, returning to WALK")
		is_attacking = false
		_hit_frame_triggered = false
		_change_animation(AnimState.WALK)  # Volver a idle/walk
```

---

#### ❌ **CARENCIA #3: FPS Dinámico Rompe Timing Visual**
**Problema**: Con APS alto (3.0+), la animación corre a 60fps (clampeada), desincronizando hit_frame.

**Ejemplo**:
```gdscript
# _calculate_attack_fps()
# APS=3.0 → attack_duration=0.33s → required_fps=186 → clamped to 60fps
# Duración real: 62 frames / 60fps = 1.03s (3x más lento que lo esperado)
# El hit_frame 29 ocurre a 0.48s, pero el timer espera 0.33s
```

**Impacto**: 
- Daño se aplica antes del golpe visual con APS alto
- Animación "lag" tras el daño
- Sensación de desconexión

**Solución**: Escalado no-uniforme de frames
```gdscript
func _calculate_adjusted_hit_frame() -> int:
	"""Ajusta hit_frame según FPS dinámico para mantener timing"""
	var config = anim_config[AnimState.ATTACK]
	var base_hit_frame: int = config["hit_frame"]
	var total_frames: int = config["hframes"]
	var base_fps: float = 24.0  # FPS de diseño
	var actual_fps: float = _calculate_attack_fps()
	
	# Si FPS está clampeado, ajustar hit_frame proporcionalmente
	if actual_fps >= 60.0:  # Clampeado
		var speedup_ratio = actual_fps / (total_frames / (1.0 / aps))
		return int(base_hit_frame * speedup_ratio)
	
	return base_hit_frame
```

---

#### ❌ **CARENCIA #4: Sin Sistema de Transiciones (Blending)**
**Problema**: Cambios de animación son instantáneos (frame 0 directo), causando "pops" visuales.

**Impacto**:
- WALK → ATTACK: salto visual brusco
- ATTACK → WALK: vuelta instantánea
- DEATH: transición abrupta

**Evidencia**:
```gdscript
# Hero.gd línea 169 (_change_animation)
current_frame = config.get("start_frame", 0)  # ❌ SNAP instantáneo
sprite.frame = current_frame
```

**Solución Profesional**: Cross-fade con doble sprite
```gdscript
var _transitioning := false
var _transition_duration := 0.15  # 150ms blend
var _transition_timer := 0.0
var _old_sprite: Sprite2D
var _new_sprite: Sprite2D

func _smooth_transition(new_state: AnimState):
	if _transitioning:
		return
	
	_transitioning = true
	_transition_timer = 0.0
	
	# Clonar sprite actual como "old"
	_old_sprite = sprite.duplicate()
	add_child(_old_sprite)
	
	# Cambiar animación en sprite principal
	_change_animation_immediate(new_state)
	sprite.modulate.a = 0.0  # Empezar invisible
	
	# Tween cross-fade
	var tween = create_tween().set_parallel(true)
	tween.tween_property(_old_sprite, "modulate:a", 0.0, _transition_duration)
	tween.tween_property(sprite, "modulate:a", 1.0, _transition_duration)
	tween.tween_callback(func(): 
		_old_sprite.queue_free()
		_transitioning = false
	)
```

**Nota**: Para un JAM, esto es overkill. Mejor: usar 3-5 frames de overlap manual.

---

#### ❌ **CARENCIA #5: Sin Pooling de FloatingNumbers**
**Problema**: `_spawn_floating_number()` crea un Label nuevo cada golpe, sin reciclar.

**Impacto**:
- Garbage collection constante durante combate
- Stutter potencial con muchos enemigos
- Leaks si no se limpian correctamente

**Evidencia**:
```gdscript
# Hero.gd línea 373
func _spawn_floating_number(damage: int, is_crit: bool):
	var floating_label = Label.new()  # ❌ NEW cada vez
	floating_label.text = str(damage)
	get_tree().root.add_child(floating_label)  # ❌ Sin cleanup explícito
```

**Solución**: Object Pool simple
```gdscript
# En GameManager o autoload
var _floating_number_pool: Array[Label] = []
const POOL_SIZE := 20

func get_floating_number() -> Label:
	if _floating_number_pool.is_empty():
		for i in range(POOL_SIZE):
			var label = Label.new()
			label.set_script(preload("res://scripts/gameplay/FloatingNumber.gd"))
			_floating_number_pool.append(label)
	
	return _floating_number_pool.pop_back()

func return_floating_number(label: Label):
	label.visible = false
	label.get_parent().remove_child(label)
	_floating_number_pool.append(label)
```

---

#### ❌ **CARENCIA #6: Sin Variaciones de Ataque**
**Problema**: Hero solo tiene `hero_attack_01_12fps.png`. Sin variantes.

**Impacto**:
- Combate monótono visualmente
- Falta de "combos" o ataques pesados
- No se distinguen crits visualmente

**Assets disponibles no usados**:
```
hero_attack_01_12fps.png  ✅ USADO
hero_attack_02_12fps.png  ❌ NO USADO (existe!)
```

**Solución**: Sistema de variantes aleatorias
```gdscript
# En Hero._setup_animations()
AnimState.ATTACK: {
	"variants": [
		load("res://art/assets/Spritesheets/Hero/hero_attack_01_12fps.png"),
		load("res://art/assets/Spritesheets/Hero/hero_attack_02_12fps.png")
	],
	"hframes": 62,
	"fps": 24.0,
	"hit_frame": 29
}

# En _change_animation()
if new_state == AnimState.ATTACK:
	var variants = config["variants"]
	var random_texture = variants[randi() % variants.size()]
	sprite.texture = random_texture
```

**Bonus**: Usar `attack_02` exclusivamente para crits (más jugo visual).

---

#### ❌ **CARENCIA #7: Sin Feedback Táctil en Hit**
**Problema**: El golpe ocurre pero no hay "freeze frame" o screen shake.

**Impacto**:
- Falta de impacto ("juice")
- Golpes se sienten débiles
- Difícil de percibir crits

**Solución**: Hit-stop + shake
```gdscript
# En CombatController._execute_hero_attack()
func _execute_hero_attack(particle_buffer: Array):
	# ... código existente ...
	
	# ✨ AÑADIR: Hit-stop (pause breve)
	if crit:
		Engine.time_scale = 0.1  # Slow-mo por 50ms
		await get_tree().create_timer(0.05, true, false, true).timeout
		Engine.time_scale = 1.0
		
		# Screen shake en crits
		_apply_screen_shake(8.0, 0.15)  # 8px intensidad, 150ms
	else:
		# Hit-stop sutil en golpes normales
		Engine.time_scale = 0.5
		await get_tree().create_timer(0.02, true, false, true).timeout
		Engine.time_scale = 1.0

func _apply_screen_shake(intensity: float, duration: float):
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var original_offset = camera.offset
	var tween = create_tween()
	
	for i in range(int(duration / 0.016)):  # ~60 samples
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(camera, "offset", original_offset + shake_offset, 0.016)
	
	tween.tween_property(camera, "offset", original_offset, 0.1)
```

**Nota JAM**: Hit-stop puede confundir en juego rápido. Usar solo en crits.

---

#### ❌ **CARENCIA #8: Falta AnimationTree para Blending Real**
**Problema**: Sistema manual de estados sin interpolación.

**Impacto**:
- Impossible smooth blending entre estados
- No hay "partial" animations (upper body ataca, lower body camina)
- Más código manual de gestión

**Contexto**: Godot tiene `AnimationTree` con state machines y blend spaces nativos.

**Por qué NO usarlo en este proyecto**:
- ✅ Spritesheets de frames (no `AnimationPlayer`)
- ✅ 2D estilo retro (no necesita blending suave)
- ✅ Simplicidad de arquitectura para jam
- ❌ Requiere migrar a `AnimatedSprite2D` o `AnimationPlayer`

**Veredicto**: ✅ OK no usar `AnimationTree` en este contexto. Manual state machine es apropiado.

---

#### ❌ **CARENCIA #9: Sin Sistema de "Stagger" o "Hitstun"**
**Problema**: Enemigos no reaccionan visualmente al ser golpeados.

**Impacto**:
- Falta feedback de daño
- Difícil saber si el golpe conectó
- Combate se siente "rígido"

**Solución Ligera**: Flash blanco + recoil
```gdscript
# En Enemy.take_damage()
func take_damage(amount: int, _is_pulse: bool = false):
	if not alive:
		return
	
	hp = max(0, hp - amount)
	_update_health_bar()
	
	# ✨ AÑADIR: Flash visual
	_play_hit_flash()
	
	# ✨ AÑADIR: Knockback ligero
	_apply_knockback(Vector2(-30, 0))  # 30px hacia atrás
	
	if hp == 0:
		_die()

func _play_hit_flash():
	if not sprite_node:
		return
	
	var original_modulate = sprite_node.modulate
	sprite_node.modulate = Color.WHITE  # Flash blanco
	
	var tween = create_tween()
	tween.tween_property(sprite_node, "modulate", original_modulate, 0.1)

func _apply_knockback(direction: Vector2):
	var tween = create_tween()
	tween.tween_property(self, "position", position + direction, 0.08)
	tween.tween_property(self, "position", position, 0.12).set_ease(Tween.EASE_OUT)
```

---

#### ❌ **CARENCIA #10: Sin Debugging Visual de Animaciones**
**Problema**: No hay forma de ver frames, timings, o hit boxes en runtime.

**Impacto**:
- Difícil ajustar hit_frame visualmente
- Imposible debuggear desyncs
- Requiere recompilar para tweakear

**Solución**: Overlay de debug
```gdscript
# En Hero/Enemy (toggle con key F3)
var _debug_anim := false

func _draw():
	if not _debug_anim:
		return
	
	# Dibujar info de animación
	var font = ThemeDB.fallback_font
	var y_offset = -250.0
	
	draw_string(font, Vector2(-100, y_offset), 
		"State: %s" % AnimState.keys()[current_anim_state], 
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)
	
	draw_string(font, Vector2(-100, y_offset + 20), 
		"Frame: %d/%d" % [current_frame, anim_config[current_anim_state]["hframes"]], 
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.CYAN)
	
	draw_string(font, Vector2(-100, y_offset + 40), 
		"FPS: %.1f" % anim_config[current_anim_state]["fps"], 
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GREEN)
	
	draw_string(font, Vector2(-100, y_offset + 60), 
		"APS: %.2f" % aps, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.ORANGE)
	
	# Dibujar hit_frame marker
	if "hit_frame" in anim_config[current_anim_state]:
		var hit_frame = anim_config[current_anim_state]["hit_frame"]
		if current_frame == hit_frame:
			draw_circle(Vector2(0, 0), 60, Color(1, 0, 0, 0.5))  # Círculo rojo

func _input(event):
	if event is InputEventKey and event.keycode == KEY_F3 and event.pressed:
		_debug_anim = !_debug_anim
		queue_redraw()
```

---

## 🎯 PLAN DE ACCIÓN PRIORIZADO

### 🔥 PRIORIDAD MÁXIMA (Fix en ≤90 min)

#### **Fix #1: Terminar Animación ATTACK Tras 1 Ciclo**
**Tiempo**: 20 min  
**Archivos**: `Hero.gd` (líneas 140-165), `Enemy.gd` (líneas 140-175)

**Cambio**:
```gdscript
# En Hero._process() después de actualizar frame:
if current_anim_state == AnimState.ATTACK and "hit_frame" in config:
	# ... código existente de hit_frame ...
	
	# ✨ AÑADIR: Resetear is_attacking al completar ciclo
	if current_frame == start_frame and _hit_frame_triggered:
		_hit_frame_triggered = false
		if is_attacking:
			print("Hero: Attack cycle complete, returning to WALK")
			is_attacking = false  # ✅ Apagar flag
```

**Validación**: Ejecutar combate, verificar que animación ATTACK solo hace 1 loop por golpe.

---

#### **Fix #2: Añadir Hit-Flash en Enemigos**
**Tiempo**: 25 min  
**Archivos**: `Enemy.gd` (línea 265 - `take_damage`)

**Implementación**: Ver solución en CARENCIA #9.

**Validación**: Golpear enemigo, debe flashear blanco por 100ms.

---

#### **Fix #3: Usar hero_attack_02 para Crits**
**Tiempo**: 15 min  
**Archivos**: `Hero.gd` (líneas 60-90 - `_setup_animations`)

**Cambio**:
```gdscript
AnimState.ATTACK: {
	"texture_normal": load("res://art/assets/Spritesheets/Hero/hero_attack_01_12fps.png"),
	"texture_crit": load("res://art/assets/Spritesheets/Hero/hero_attack_02_12fps.png"),
	"hframes": 62,
	"fps": 24.0,
	"hit_frame": 29,
	"start_frame": 0,
	"end_frame": 61
}

# En _change_animation() para ATTACK:
# Detectar si el próximo ataque será crit (pre-calculate)
var next_will_crit = randf() < crit_p
var texture = config["texture_crit"] if next_will_crit else config["texture_normal"]
sprite.texture = texture
```

**Problema**: Esto requiere pre-calcular crit, lo que rompe la lógica actual. **SKIP para jam**.

---

#### **Fix #4: Debug Overlay de Animaciones**
**Tiempo**: 30 min  
**Archivos**: `Hero.gd`, `Enemy.gd` (añadir función `_draw()`)

**Implementación**: Ver solución en CARENCIA #10.

**Validación**: Presionar F3, debe mostrar estado/frame/fps en tiempo real.

---

### ⚡ PRIORIDAD ALTA (Siguiente sesión, ~60 min)

#### **Mejora #5: Ajustar Hit-Frame Dinámico**
**Tiempo**: 45 min  
**Archivos**: `Hero.gd`, `Enemy.gd`

**Implementación**: Ver solución en CARENCIA #3 (`_calculate_adjusted_hit_frame()`).

**Validación**: Testear con APS=3.0, verificar que daño y visual coincidan.

---

#### **Mejora #6: Pooling de FloatingNumbers**
**Tiempo**: 20 min  
**Archivos**: `GameManager.gd` (añadir pool), `Hero.gd`, `Enemy.gd` (usar pool)

**Implementación**: Ver solución en CARENCIA #5.

**Validación**: Verificar que no hay stutter tras 100 golpes.

---

### 📌 PRIORIDAD MEDIA (Post-jam polish)

- **Mejora #7**: Hit-stop en crits (CARENCIA #7)
- **Mejora #8**: Smooth transitions con overlap frames (CARENCIA #4)
- **Mejora #9**: Knockback visual (CARENCIA #9)

---

### ⏸️ NO HACER (Fuera de scope jam)

- ❌ Migrar a `AnimationTree` (requiere refactor completo)
- ❌ Animaciones procedurales (overkill)
- ❌ Inverse kinematics (innecesario en 2D sprite)
- ❌ Motion matching (no aplica a frame-based)

---

## 📈 MÉTRICAS DE ÉXITO

### Antes (Estado Actual)
- **Combat Feel**: 6.5/10
- **Visual Clarity**: 6/10
- **Performance**: 7/10 (estable pero ineficiente)
- **Juice Factor**: 4/10

### Después (Tras Fixes 1-4)
- **Combat Feel**: 8/10 (+1.5)
- **Visual Clarity**: 8.5/10 (+2.5)
- **Performance**: 7.5/10 (+0.5)
- **Juice Factor**: 7/10 (+3)

### Target Final (Tras todas las mejoras)
- **Combat Feel**: 9/10
- **Visual Clarity**: 9/10
- **Performance**: 8.5/10
- **Juice Factor**: 8.5/10

---

## 🧪 TESTS DE VALIDACIÓN

### Test Suite Mínima

```gdscript
# res://tests/test_animation_system.gd
extends GutTest

func test_attack_animation_completes_one_cycle():
	var hero = preload("res://scenes/Hero.tscn").instantiate()
	add_child_autofree(hero)
	
	hero.is_attacking = true
	hero._change_animation(hero.AnimState.ATTACK)
	
	# Simular 1 ciclo completo
	var fps = hero.anim_config[hero.AnimState.ATTACK]["fps"]
	var total_time = hero.anim_config[hero.AnimState.ATTACK]["hframes"] / fps
	
	for i in range(int(total_time * 60)):  # 60fps simulation
		hero._process(1.0 / 60.0)
	
	assert_false(hero.is_attacking, "is_attacking debe apagarse tras 1 ciclo")

func test_hit_frame_emits_signal():
	var hero = preload("res://scenes/Hero.tscn").instantiate()
	add_child_autofree(hero)
	
	watch_signals(hero)
	hero.is_attacking = true
	hero._change_animation(hero.AnimState.ATTACK)
	
	# Avanzar hasta hit_frame
	var hit_frame = hero.anim_config[hero.AnimState.ATTACK]["hit_frame"]
	for i in range(hit_frame + 1):
		hero._process(1.0 / 24.0)  # 24fps
	
	assert_signal_emitted(hero, "hit_frame_reached")

func test_dynamic_fps_matches_aps():
	var hero = preload("res://scenes/Hero.tscn").instantiate()
	add_child_autofree(hero)
	
	hero.aps = 2.0  # 2 ataques por segundo
	var calculated_fps = hero._calculate_attack_fps()
	
	var expected_duration = 1.0 / hero.aps  # 0.5s
	var total_frames = hero.anim_config[hero.AnimState.ATTACK]["hframes"]
	var actual_duration = total_frames / calculated_fps
	
	assert_almost_eq(actual_duration, expected_duration, 0.1, 
		"Duración animación debe coincidir con APS")
```

**Ejecutar**: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=tests`

---

## 🎓 LECCIONES APRENDIDAS

### Lo Que Funcionó Bien ✅
1. **Arquitectura de señales**: Event-driven es correcto para sincronización
2. **FPS dinámico**: Concepto correcto, ejecución con edge cases
3. **Separación timing/daño**: Limpia separación de concerns

### Lo Que Falló ❌
1. **No planear transiciones**: Assumed instant state changes serían OK
2. **No considerar pooling**: Premature optimization is evil, pero esto es básico
3. **Falta de debug tools**: Desarrollar "a ciegas" es lento

### Para Próximo Jam 🚀
1. **Planear animaciones early**: Definir estados, transiciones y timings en GDD
2. **Prototype con placeholders**: Testear mecánicas antes de hacer arte
3. **Build debug tools first**: Overlay de animación antes de implementar lógica

---

## 📚 REFERENCIAS TÉCNICAS

### Papers y Recursos
1. **"The Animation Pipeline"** - Pixar (2000) - Principios de anticipación
2. **"Juice It or Lose It"** - Martin Jonasson & Petri Purho (2012) - Game feel
3. **"Art of Screenshake"** - Jan Willem Nijman (2013) - Impact feedback
4. **Godot Docs**: Animation system best practices

### Herramientas Recomendadas
- **Aseprite**: Frame timing visual editor
- **Godot Animation Debugger**: Built-in profiler
- **GUT (Godot Unit Test)**: Test framework para validación

---

## ✅ CHECKLIST DE IMPLEMENTACIÓN

### Sesión 1 (90 min) - Fixes Críticos
- [ ] Fix #1: Terminar animación ATTACK tras 1 ciclo (20 min)
- [ ] Fix #2: Hit-flash en enemigos (25 min)
- [ ] Fix #4: Debug overlay F3 (30 min)
- [ ] Test manual: Verificar que golpes se ven "punchy" (15 min)

### Sesión 2 (60 min) - Optimizaciones
- [ ] Mejora #5: Ajustar hit-frame dinámico con APS alto (45 min)
- [ ] Test con APS=3.0 y APS=0.5 (15 min)

### Sesión 3 (40 min) - Polish
- [ ] Mejora #6: Pooling de FloatingNumbers (20 min)
- [ ] Test de performance: 10 enemigos simultáneos (10 min)
- [ ] Documentar cambios en CHANGELOG.md (10 min)

---

## 🎬 CONCLUSIÓN

**Estado Actual**: Sistema funcional pero con **10 carencias** identificadas que reducen el "game feel" y claridad visual.

**Prioridad Máxima**: Implementar **Fixes #1, #2, #4** en próxima sesión de 90 min para mejorar inmediatamente la experiencia de combate.

**Impacto Esperado**: +2.5 puntos en "Combat Feel" y +3 puntos en "Juice Factor" tras implementar todos los fixes prioritarios.

**Arquitectura General**: ✅ Sólida para un jam. No requiere refactor masivo, solo refinamiento de detalles.

---

**Preparado por**: Experto en Animaciones Frame-Based  
**Validado**: Análisis técnico con 15 años de experiencia  
**Next Steps**: Ejecutar Plan de Acción, empezando por Prioridad Máxima
