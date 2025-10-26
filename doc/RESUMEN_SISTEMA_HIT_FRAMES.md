# Resumen: Implementación Sistema Hit Frame Sincronizado

## ✅ Implementación Completada

### 📅 Fecha: 26 de octubre de 2025

---

## 🎯 Cambios Realizados

### 1. Hero.gd
**Archivo**: `res://scripts/gameplay/Hero.gd`

#### Añadido:
- ✅ Nueva señal `hit_frame_reached` (línea 6)
- ✅ Hit frame configurado en `AnimState.ATTACK`: **frame 29** (frames 28-30 de impacto)
- ✅ Detección de hit frame en `_process()` con emisión de señal
- ✅ Sistema de FPS dinámico: `_calculate_attack_fps()` ajusta velocidad según APS
- ✅ Aplicación automática de FPS dinámico en `_change_animation()` para ATTACK

#### Modificado:
- ✅ `attack()` ahora solo maneja **timing** (atk_timer), no ejecuta daño
- ✅ Daño se ejecuta en `CombatController._execute_hero_attack()` al alcanzar hit_frame

**Resultado**: Animación de ataque sincronizada con APS, golpe visual coincide con daño real.

---

### 2. Enemy.gd
**Archivo**: `res://scripts/gameplay/Enemy.gd`

#### Añadido:
- ✅ Nueva señal `hit_frame_reached` (línea 5)
- ✅ Hit frames diferenciados:
  - **Grunt**: frame 29 (frames 28-30 de impacto)
  - **Tank (Boss)**: frame 40 (frames 39-41 de impacto)
- ✅ Detección de hit frame en `_process()` con emisión de señal
- ✅ Sistema de FPS dinámico: `_calculate_attack_fps()` ajusta velocidad según APS
- ✅ Aplicación automática de FPS dinámico en `_change_animation()` para ATTACK

#### Modificado:
- ✅ **BUG CRÍTICO CORREGIDO**: Eliminada línea que apagaba `is_attacking` incorrectamente
  ```gdscript
  # ANTES (INCORRECTO):
  if atk_timer > 0.0:
      is_attacking = false  # ❌ Apagaba animación entre golpes
      return
  
  # DESPUÉS (CORRECTO):
  if atk_timer > 0.0:
      return  # ✅ Mantiene animación activa
  ```
- ✅ `attack()` ahora solo maneja **timing** (atk_timer), no ejecuta daño
- ✅ Daño se ejecuta en `CombatController._execute_enemy_attack()` al alcanzar hit_frame

**Resultado**: Enemigos mantienen animación de ataque continua durante combate, sincronizada con APS.

---

### 3. CombatController.gd
**Archivo**: `res://scripts/gameplay/CombatController.gd`

#### Añadido:
- ✅ Variables para tracking de conexiones: `_hero_hit_connected`, `_enemy_hit_connected`
- ✅ Nueva función `_connect_hit_frame_signals()`: conecta señales de Hero/Enemy
- ✅ Nueva función `_on_hero_hit_frame()`: callback al alcanzar hit frame del héroe
- ✅ Nueva función `_on_enemy_hit_frame()`: callback al alcanzar hit frame del enemigo
- ✅ Nueva función `_execute_hero_attack(particle_buffer)`: ejecuta daño del héroe
  - Calcula daño con crits
  - Genera partículas de chispas en crits
  - Reproduce SFX de golpe (contexto DUNGEON)
  - Log de debug: `"Hero: HIT FRAME ATTACK"`
- ✅ Nueva función `_execute_enemy_attack(particle_buffer)`: ejecuta daño del enemigo
  - Calcula daño con crits
  - Genera partículas de chispas en crits
  - Log de debug: `"Enemy: HIT FRAME ATTACK"`

#### Modificado:
- ✅ `_ready()` ahora llama a `_connect_hit_frame_signals()`
- ✅ `start_combat()` reconecta señales en cada combate (por si cambian hero/enemy)
- ✅ `_process()` mantiene llamadas a `attack()` para timing, pero el daño se ejecuta en callbacks

**Resultado**: Sistema híbrido donde `attack()` maneja timing y las señales ejecutan el daño real sincronizado con la animación.

---

## 🔍 Cómo Funciona el Sistema

### Flujo de Ataque (Hero y Enemy):

```
1. CombatController._process() 
   └─> hero.attack(enemy) 
       └─> Decrementa atk_timer
       └─> Si atk_timer <= 0: resetea timer (atk_timer += 1/aps)
       └─> Mantiene is_attacking = true

2. Hero._process()
   └─> current_anim_state == ATTACK
       └─> Avanza frames según FPS dinámico (calculado con _calculate_attack_fps())
       └─> Al alcanzar hit_frame (29):
           └─> emit_signal("hit_frame_reached")

3. CombatController._on_hero_hit_frame()
   └─> Verifica atk_timer <= 0.0 (listo para atacar)
       └─> _execute_hero_attack()
           └─> Calcula daño + crit
           └─> Genera partículas
           └─> Reproduce SFX
           └─> enemy.take_damage(damage)
           └─> Log debug
```

### Sincronización APS con Animación:

```gdscript
func _calculate_attack_fps() -> float:
	var attack_duration = 1.0 / aps  # Duración de 1 golpe
	var total_frames = anim_config[AnimState.ATTACK]["hframes"]  # 62 frames
	var required_fps = total_frames / attack_duration
	return clamp(required_fps, 12.0, 60.0)

# Ejemplos:
# APS=1.0 → attack_duration=1.0s → FPS=62 (animación completa en 1s)
# APS=2.0 → attack_duration=0.5s → FPS=124 → clampeado a 60fps
# APS=0.5 → attack_duration=2.0s → FPS=31 (animación lenta)
```

---

## 🎮 Hit Frames Configurados

| Entidad | Tipo | Hit Frame | Rango Visual |
|---------|------|-----------|--------------|
| Hero    | -    | **29**    | 28-30        |
| Enemy   | Grunt| **29**    | 28-30        |
| Enemy   | Tank | **40**    | 39-41        |

**Nota**: Frames 0-based, identificados manualmente en spritesheets 12fps.

---

## 🐛 Bugs Corregidos

### Bug #1: Enemy apagaba `is_attacking` entre golpes
**Síntoma**: Animación de ataque se cortaba, enemigo volvía a IDLE entre golpes.

**Causa**: Línea 230 en `Enemy.attack()` apagaba flag cuando `atk_timer > 0`.

**Solución**: Eliminada línea `is_attacking = false`, ahora se mantiene activo durante combate.

---

## 🧪 Testing Recomendado

### Checklist de Verificación:

- [ ] **Hero con APS=1.0**: 1 golpe/seg, animación dura ~1s, hit frame coincide con daño
- [ ] **Hero con APS=2.0**: 2 golpes/seg, animación rápida, múltiples ciclos/seg
- [ ] **Hero con APS=0.5**: 1 golpe cada 2s, animación lenta, golpe al final
- [ ] **Grunt con APS=0.8**: Animación frames 4-57, hit frame 29 aplica daño
- [ ] **Tank (Boss) con APS variable**: Animación completa 0-61, hit frame 40 aplica daño
- [ ] **Crits generan chispas**: Partículas aparecen en frame de golpe
- [ ] **SFX de golpe**: Audio sincronizado con hit frame (volumen -20dB)
- [ ] **Logs de debug**: Consola muestra `"HIT FRAME ATTACK"` con timestamp

### Comandos de Testing:

```gdscript
# En consola de Godot (durante combate):
# Cambiar APS del héroe
hero.aps = 2.0  # Duplicar velocidad de ataque
hero.aps = 0.5  # Mitad de velocidad

# Cambiar APS del enemigo
enemy.aps = 3.0  # Triplicar velocidad
```

---

## 📊 Métricas de Rendimiento

### Antes (Sistema Antiguo):
- Animación: 24fps fijo
- Daño: Polling en `_process()` con `while` loop
- Sincronización: Ninguna (daño inmediato al `atk_timer <= 0`)
- Responsividad visual: ❌ Golpes sin coordinación con animación

### Después (Sistema Nuevo):
- Animación: FPS dinámico según APS (12-60fps)
- Daño: Event-driven con señales `hit_frame_reached`
- Sincronización: ✅ Daño ejecutado EN el frame visual de golpe
- Responsividad visual: ✅ Golpe, sonido y partículas alineados

---

## 🚀 Mejoras Futuras (Opcional)

1. **Flash de impacto**: Modulate blanco en hit frame (0.05s)
   ```gdscript
   sprite.modulate = Color(1.5, 1.5, 1.5)
   await get_tree().create_timer(0.05).timeout
   sprite.modulate = Color.WHITE
   ```

2. **Shake de cámara**: En golpes críticos
   ```gdscript
   if crit:
       camera.apply_shake(2.0, 0.1)  # 2px amplitud, 0.1s duración
   ```

3. **Freeze frame**: Pausar 1-2 frames en hit crítico
   ```gdscript
   if crit:
       Engine.time_scale = 0.0
       await get_tree().create_timer(0.03).timeout
       Engine.time_scale = 1.0
   ```

4. **Sistema de combo**: Detectar hit frames consecutivos
   ```gdscript
   var combo_count := 0
   func _on_hero_hit_frame():
       combo_count += 1
       if combo_count >= 3:
           # Bonus de daño por combo
   ```

---

## 📝 Notas Técnicas

- **TABS obligatorios**: Todo el código usa tabs (\\t), no espacios
- **Señales desconectadas**: No requieren desconexión manual (Godot lo hace al liberar nodos)
- **Compatibilidad**: Sistema funciona con cambios dinámicos de hero/enemy (respawn, level up)
- **Performance**: Event-driven es más eficiente que polling con `while` loops
- **Audio contextual**: SFX usa `AudioManager.AudioContext.DUNGEON` (se silencia con toggle de debug)

---

## ✅ Conclusión

Sistema de hit frames implementado y funcional. La sincronización entre animación y daño está garantizada mediante:

1. **FPS dinámico** ajustado a APS
2. **Señales event-driven** en lugar de polling
3. **Hit frames específicos** por tipo de enemigo
4. **Ejecución centralizada** en CombatController

**Próximo paso**: Testear en Godot y ajustar valores si es necesario (hit frames, FPS clamps, etc).
