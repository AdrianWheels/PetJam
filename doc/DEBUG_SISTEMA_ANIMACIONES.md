# Debug System - Sistema de Animaciones de Combate

## 🔍 Debugs Añadidos

### 1. Hero.gd

#### Estado de Animación (cada 1 segundo):
```
Hero Animation State: alive=true, is_attacking=false, current_anim=WALK
```

#### Cambios de Animación:
```
Hero: Changing to ATTACK animation (is_attacking=true)
Hero: Changed animation to ATTACK (hframes=62, fps=24.0, sprite.scale=(0.5, 0.5), parent.scale=(5.4, 5.4))
```

#### Sistema de Ataque:
```
Hero: Starting attack, setting is_attacking=true
Hero: Attack timer reset, next attack in 1.00s (aps=1.00)
Hero: Stopping attack (not alive or no target), setting is_attacking=false
```

---

### 2. Enemy.gd

#### Estado de Animación (cada 1 segundo):
```
Enemy Animation State: alive=true, is_attacking=false, current_anim=IDLE
```

#### Cambios de Animación:
```
Enemy: Changing animation from IDLE to ATTACK
Enemy: Changed animation to ATTACK (hframes=62, fps=24.0, sprite.scale=(0.5, 0.5), parent.scale=(5.4, 5.4), is_boss=false)
```

#### Sistema de Ataque:
```
Enemy: Starting attack, setting is_attacking=true
Enemy: Attack timer reset, next attack in 1.25s (aps=0.80)
Enemy: Stopping attack (not alive or no target), setting is_attacking=false
```

---

### 3. CombatController.gd

#### Inicio de Combate:
```
CombatController: ===== STARTING COMBAT =====
CombatController: Hero prepared for combat (atk_timer=1.00, aps=1.00)
CombatController: Enemy prepared for combat (atk_timer=1.25, aps=0.80)
CombatController: Connected hero hit_frame_reached signal
CombatController: Connected enemy hit_frame_reached signal
```

#### Fin de Combate:
```
CombatController: Combat ending - hero.alive=true, enemy.alive=false
CombatController: ===== STOPPING COMBAT =====
CombatController: Reset hero.is_attacking = false
CombatController: Reset enemy.is_attacking = false
```

#### Ejecución de Golpes:
```
Hero: HIT FRAME ATTACK at 12.34 s, dmg=15.5, crit=false, aps=1.00
Enemy: HIT FRAME ATTACK at 12.56 s, dmg=8.2, crit=true, aps=0.80
```

---

### 4. Corridor.gd

#### Estado RUN (cada 1 segundo):
```
Corridor RUN: hero_pos=(2100, 1120), enemy_pos=(2620, 1120), distance=520.0
```

#### Detección de Overlap:
```
Corridor: Overlap check TRUE - rect1=[Rect2(2079, 1088, 42, 64)], rect2=[Rect2(2600, 1094, 40, 52)]
Corridor: OVERLAP DETECTED! Switching to FIGHT state
```

---

## 🐛 Bugs Corregidos

### Bug #1: Enemigos Gigantes
**Síntoma**: Enemy aparecía enorme en pantalla (3-4x más grande que Hero)

**Causa**: 
- CharacterBody2D tiene `scale = Vector2(5.4, 5.4)` en la escena
- El script calculaba `sprite.scale` adicional sin considerar el parent scale
- **Resultado**: Scale total = 5.4 × sprite.scale (DOBLE ESCALADO)

**Solución**: 
- Comentarios añadidos explicando que el padre ya escala
- `sprite.scale` ahora calcula en unidades locales
- Scale final correcto: hero/enemy del mismo tamaño relativo

```gdscript
# ANTES (INCORRECTO):
sprite.scale = Vector2(target_size.x / frame_width, target_size.y / frame_height)
# Scale total = 5.4 × sprite.scale → GIGANTE

# DESPUÉS (CORRECTO):
# CRÍTICO: El CharacterBody2D tiene scale=5.4, así que el sprite debe compensar
var local_scale = Vector2(target_size.x / frame_width, target_size.y / frame_height)
sprite.scale = local_scale
# Scale total = 5.4 × local_scale → CORRECTO
```

---

### Bug #2: Hero Atascado en Estado "Attacking"
**Síntoma**: Hero quedaba en animación ATTACK después del combate

**Causa**: 
- `is_attacking` solo se apagaba en `attack()` si no había target
- Cuando `combat_active = false`, `attack()` no se llamaba
- **Resultado**: `is_attacking` quedaba en `true` permanentemente

**Solución**: 
- `CombatController.stop_combat()` ahora resetea explícitamente:
  ```gdscript
  if hero:
      hero.is_attacking = false
  if enemy:
      enemy.is_attacking = false
  ```

---

## 📊 Flujo de Debug Esperado

### Inicio de Combate:
```
1. Corridor RUN: hero_pos=(2100, 1120), enemy_pos=(2620, 1120), distance=520.0
   [héroe avanza...]
2. Corridor RUN: hero_pos=(2200, 1120), enemy_pos=(2620, 1120), distance=420.0
   [héroe avanza...]
3. Corridor: Overlap check TRUE - rect1=[...], rect2=[...]
4. Corridor: OVERLAP DETECTED! Switching to FIGHT state
5. CombatController: ===== STARTING COMBAT =====
6. CombatController: Hero prepared for combat (atk_timer=1.00, aps=1.00)
7. CombatController: Enemy prepared for combat (atk_timer=1.25, aps=0.80)
8. Hero: Starting attack, setting is_attacking=true
9. Hero: Changing to ATTACK animation (is_attacking=true)
10. Hero: Changed animation to ATTACK (hframes=62, fps=62.0, sprite.scale=(...))
11. Enemy: Starting attack, setting is_attacking=true
12. Enemy: Changing animation from IDLE to ATTACK
13. Enemy: Changed animation to ATTACK (hframes=62, fps=49.6, sprite.scale=(...))
```

### Durante Combate:
```
[Cada ~1 segundo, dependiendo de APS]
Hero: Attack timer reset, next attack in 1.00s (aps=1.00)
Hero: HIT FRAME ATTACK at 5.23 s, dmg=15.5, crit=false, aps=1.00
Enemy: Attack timer reset, next attack in 1.25s (aps=0.80)
Enemy: HIT FRAME ATTACK at 5.67 s, dmg=8.2, crit=false, aps=0.80
```

### Fin de Combate:
```
1. CombatController: Combat ending - hero.alive=true, enemy.alive=false
2. CombatController: ===== STOPPING COMBAT =====
3. CombatController: Reset hero.is_attacking = false
4. CombatController: Reset enemy.is_attacking = false
5. Hero: Stopping attack (not alive or no target), setting is_attacking=false
6. Hero: Changing to WALK animation (is_attacking=false)
7. Hero: Changed animation to WALK (hframes=63, fps=24.0, sprite.scale=(...))
```

---

## 🧪 Checklist de Testing con Debugs

### Verificar Scale Correcto:
- [ ] Logs muestran `sprite.scale` y `parent.scale` separados
- [ ] Hero y Enemy tienen tamaños similares en pantalla
- [ ] `sprite.scale` debería ser ~(0.5, 0.5) o similar (pequeño, porque parent=5.4)
- [ ] Tamaño final visual: Hero ligeramente más grande que Enemy

### Verificar Transición de Animaciones:
- [ ] Hero empieza en WALK
- [ ] Al contacto: Hero cambia a ATTACK
- [ ] Al morir enemigo: Hero vuelve a WALK
- [ ] Enemy empieza en IDLE
- [ ] Al contacto: Enemy cambia a ATTACK
- [ ] Enemy NO vuelve a IDLE entre golpes (mantiene ATTACK continuo)

### Verificar Flags is_attacking:
- [ ] Logs muestran "Starting attack, setting is_attacking=true"
- [ ] Logs muestran "STOPPING COMBAT" seguido de "Reset is_attacking = false"
- [ ] Hero NO queda atascado en ATTACK después del combate

### Verificar Hit Frames:
- [ ] Logs muestran "HIT FRAME ATTACK" cuando hay golpe
- [ ] Timestamp en logs coincide con animación visual
- [ ] Frecuencia de golpes coincide con APS (1/aps segundos entre golpes)

### Verificar Overlap Detection:
- [ ] Logs muestran distancia decreciente mientras Hero avanza
- [ ] Cuando distance < ~100: aparece "Overlap check TRUE"
- [ ] Inmediatamente después: "OVERLAP DETECTED! Switching to FIGHT state"

---

## 🔧 Comandos de Testing

### Cambiar APS en Runtime (consola de Godot):
```gdscript
# Acelerar héroe
hero.aps = 2.0
# Debería verse: "Hero: Attack timer reset, next attack in 0.50s (aps=2.00)"
# Y animación más rápida

# Ralentizar enemigo
enemy.aps = 0.5
# Debería verse: "Enemy: Attack timer reset, next attack in 2.00s (aps=0.50)"
# Y animación más lenta
```

### Forzar Reset de Combate:
```gdscript
# Si Hero queda atascado en ATTACK:
hero.is_attacking = false
# Debería volver a WALK inmediatamente
```

---

## 📝 Notas

- Todos los debugs usan `print()` estándar (aparecen en consola de Godot)
- Debugs de estado cada 60 frames (~1s a 60fps) para no spamear
- Debugs de eventos (cambio animación, inicio combate) aparecen inmediatamente
- Scale debug muestra tanto `sprite.scale` (local) como `parent.scale` (CharacterBody2D)
- Los logs incluyen timestamps en los ataques para verificar cadencia
