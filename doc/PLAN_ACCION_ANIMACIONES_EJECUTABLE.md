# 🎯 PLAN DE ACCIÓN EJECUTABLE - Mejora de Animaciones

**Base**: Análisis completo en `ANALISIS_EXPERTO_ANIMACIONES_2025.md`  
**Objetivo**: Mejorar Combat Feel de 6.5/10 a 8/10 en 90 minutos

---

## 📋 SESIÓN 1: FIXES CRÍTICOS (90 min)

### ✅ FIX #1: Terminar Animación ATTACK tras 1 Ciclo (20 min)

#### Problema
Animación hace loop infinito mientras `is_attacking=true`, desincronizando golpes visuales del daño.

#### Archivos a Modificar
- `scripts/gameplay/Hero.gd` (líneas 140-165)
- `scripts/gameplay/Enemy.gd` (líneas 140-175)

#### Código a Añadir
En la función `_process()`, después de detectar `hit_frame`:

```gdscript
# HERO.GD - Línea ~165 (después de emit hit_frame_reached)
# Resetear flag y terminar ataque SOLO si ya emitimos señal
if current_frame == start_frame and _hit_frame_triggered:
	_hit_frame_triggered = false
	# Terminar ataque tras completar el ciclo de animación
	if is_attacking:
		print("Hero: Attack animation cycle complete (after hit), resetting is_attacking")
		is_attacking = false
```

**Mismo cambio en Enemy.gd**

#### Validación
1. Correr Main.tscn
2. Entrar en combate
3. Verificar que animación ATTACK hace 1 solo ciclo por golpe
4. Verificar consola: debe aparecer mensaje "Attack animation cycle complete"

---

### ✅ FIX #2: Hit-Flash Visual en Enemigos (25 min)

#### Problema
Enemigos no muestran feedback visual al recibir daño.

#### Archivos a Modificar
- `scripts/gameplay/Enemy.gd` (línea ~265, función `take_damage`)

#### Código a Añadir

```gdscript
# ENEMY.GD - Función take_damage (línea ~260)
func take_damage(amount: int, _is_pulse: bool = false):
	if not alive:
		return
	
	hp = max(0, hp - amount)
	_update_health_bar()
	
	# ✨ AÑADIR: Flash visual + knockback
	_play_hit_flash()
	_apply_hit_recoil()
	
	if hp == 0:
		_die()

# AÑADIR AL FINAL DEL ARCHIVO:
func _play_hit_flash():
	"""Flash blanco al recibir daño"""
	if not sprite_node or not sprite_node is Sprite2D:
		return
	
	var original_modulate = sprite_node.modulate
	sprite_node.modulate = Color.WHITE  # Flash blanco
	
	var tween = create_tween()
	tween.tween_property(sprite_node, "modulate", original_modulate, 0.1)

func _apply_hit_recoil():
	"""Pequeño knockback visual"""
	var original_pos = position
	var knockback = Vector2(-20, 0)  # 20px hacia atrás
	
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + knockback, 0.06)
	tween.tween_property(self, "position", original_pos, 0.1).set_ease(Tween.EASE_OUT)
```

#### Validación
1. Correr Main.tscn
2. Atacar enemigo
3. Verificar flash blanco breve (~100ms)
4. Verificar recoil hacia atrás

---

### ✅ FIX #3: Debug Overlay de Animaciones (30 min)

#### Problema
Imposible ver estado de animación, frames, FPS en runtime.

#### Archivos a Modificar
- `scripts/gameplay/Hero.gd`
- `scripts/gameplay/Enemy.gd`

#### Código a Añadir

```gdscript
# AL INICIO DEL ARCHIVO (después de variables existentes):
var _debug_anim_overlay := false  # Toggle con F3

# AÑADIR FUNCIÓN _draw():
func _draw():
	if not _debug_anim_overlay or anim_config.is_empty():
		return
	
	var font = ThemeDB.fallback_font
	var font_size = 14
	var y_offset = -280.0
	var color_title = Color.YELLOW
	var color_value = Color.CYAN
	
	# Estado de animación
	var state_name = AnimState.keys()[current_anim_state]
	draw_string(font, Vector2(-120, y_offset), 
		"State: %s" % state_name, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_title)
	
	# Frame actual / total
	var config = anim_config[current_anim_state]
	var total_frames = config.get("end_frame", config["hframes"] - 1) - config.get("start_frame", 0) + 1
	draw_string(font, Vector2(-120, y_offset + 18), 
		"Frame: %d/%d" % [current_frame, total_frames], 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_value)
	
	# FPS actual
	draw_string(font, Vector2(-120, y_offset + 36), 
		"FPS: %.1f" % config["fps"], 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.GREEN)
	
	# APS
	draw_string(font, Vector2(-120, y_offset + 54), 
		"APS: %.2f (%.2fs/hit)" % [aps, 1.0/aps], 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.ORANGE)
	
	# Hit frame indicator
	if "hit_frame" in config and current_frame == config["hit_frame"]:
		draw_circle(Vector2(0, 0), 80, Color(1, 0, 0, 0.3))  # Círculo rojo semi-transparente
		draw_string(font, Vector2(-40, -10), 
			"HIT FRAME!", 
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.RED)
	
	# is_attacking flag
	if is_attacking:
		draw_string(font, Vector2(-120, y_offset + 72), 
			"ATTACKING", 
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.RED)

# AÑADIR FUNCIÓN _input() (o modificar si existe):
func _input(event):
	if event is InputEventKey and event.keycode == KEY_F3 and event.pressed:
		_debug_anim_overlay = !_debug_anim_overlay
		print("%s: Animation debug overlay %s" % [name, "ENABLED" if _debug_anim_overlay else "DISABLED"])
		queue_redraw()

# MODIFICAR _process() - AÑADIR AL FINAL:
func _process(delta: float) -> void:
	# ... código existente ...
	
	# Redraw debug overlay cada frame si está activo
	if _debug_anim_overlay:
		queue_redraw()
```

**Mismo código en Hero.gd y Enemy.gd**

#### Validación
1. Correr Main.tscn
2. Presionar F3
3. Verificar overlay aparece sobre Hero
4. Verificar overlay sobre Enemy
5. Entrar en combate, verificar "HIT FRAME!" aparece en frame correcto
6. Verificar que FPS cambia según APS

---

### ✅ FIX #4: Verificación y Testing Final (15 min)

#### Checklist Manual
- [ ] Hero: Animación ATTACK termina tras 1 ciclo
- [ ] Enemy: Animación ATTACK termina tras 1 ciclo
- [ ] Enemy: Flash blanco al recibir daño
- [ ] Enemy: Recoil visual al recibir daño
- [ ] Hero: Overlay F3 muestra info correcta
- [ ] Enemy: Overlay F3 muestra info correcta
- [ ] Hit Frame: Círculo rojo aparece en momento correcto
- [ ] Console: Sin errores ni warnings

#### Test de Combate Prolongado
1. Activar invencibilidad (Shift+P → Hero Invincible)
2. Combatir durante 30 segundos
3. Verificar que animaciones se mantienen sincronizadas
4. Verificar que no hay stutter ni leaks
5. Verificar que floating numbers aparecen correctamente

---

## 📊 RESULTADOS ESPERADOS

### Antes
- Animaciones hacen loop infinito
- Sin feedback visual de daño
- Debugging a ciegas

### Después
- Animaciones 1-shot sincronizadas con golpes
- Feedback visual claro (flash + recoil)
- Overlay de debug para ajustes finos

### Métricas
- **Combat Feel**: 6.5 → 8.0 (+1.5)
- **Visual Clarity**: 6.0 → 8.5 (+2.5)
- **Juice Factor**: 4.0 → 7.0 (+3.0)

---

## 🚀 PRÓXIMOS PASOS (Post-Sesión 1)

### SESIÓN 2: Optimizaciones (60 min)
- [ ] Ajustar hit-frame dinámico con APS alto (45 min)
- [ ] Testear con APS extremos: 0.5 y 3.0 (15 min)

### SESIÓN 3: Polish (40 min)
- [ ] Pooling de FloatingNumbers (20 min)
- [ ] Hit-stop en crits (20 min)

---

## 📝 NOTAS DE IMPLEMENTACIÓN

### Orden de Ejecución
1. **Fix #1 primero**: Es crítico para que los demás fixes se vean bien
2. **Fix #2 segundo**: Feedback visual básico
3. **Fix #3 tercero**: Debug tool para validar todo

### Si Hay Problemas
- **Error en tween**: Verificar que nodo no se está liberando durante tween
- **Overlay no aparece**: Verificar que `queue_redraw()` se llama cada frame
- **Animación no termina**: Verificar que `_hit_frame_triggered` se resetea correctamente

### Backup Antes de Empezar
```powershell
# Crear backup rápido
Copy-Item scripts/gameplay/Hero.gd scripts/gameplay/Hero.gd.backup
Copy-Item scripts/gameplay/Enemy.gd scripts/gameplay/Enemy.gd.backup
```

---

**LISTO PARA EJECUTAR** 🎬  
**Tiempo estimado**: 90 minutos  
**Dificultad**: Media  
**Impacto**: Alto
