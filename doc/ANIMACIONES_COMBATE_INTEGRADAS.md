# Animaciones de Combate Integradas

**Fecha**: 26 octubre 2025  
**Objetivo**: Integrar animaciones de ataque al Hero y Enemy + simplificar sistema de invencibilidad

---

## ✅ Cambios implementados

### 1. Hero.gd - Animación de ATAQUE activa
**Archivo**: `scripts/gameplay/Hero.gd`

**Cambios**:
- Añadida variable `is_attacking: bool = false` (línea 25)
- Activada lógica de animación ATTACK en `_process()` (línea 88-90):
  ```gdscript
  elif is_attacking:
      if current_anim_state != AnimState.ATTACK:
          _change_animation(AnimState.ATTACK)
  ```
- Flag `is_attacking = true` se activa en `attack()` cuando hay target válido
- Flag se desactiva si no hay target o target muere
- Animación usa `hero_attack_01_12fps.png` (62 frames @ 24fps)

### 2. Enemy.gd - Animación de ATAQUE activa
**Archivo**: `scripts/gameplay/Enemy.gd`

**Cambios**:
- Añadida variable `is_attacking: bool = false` (línea 25)
- Activada lógica de animación ATTACK en `_process()` (línea 109-110):
  ```gdscript
  elif is_attacking:
      target_state = AnimState.ATTACK
  ```
- Flag `is_attacking = true` se activa en `attack()` cuando hay target válido
- Flag se desactiva si no hay target o target muere
- Animación usa `grunt_attack_12fps.png` o `tank_attack_12fps.png` según `is_boss`
- Frame range optimizado: grunt F4-F57, tank F0-F61
- 24fps para fluidez

### 3. Invencibilidad simplificada (10k HP + 10k ATK)
**Archivos**: `Hero.gd`, `DebugPanel.gd`

**Hero.gd**:
- Añadidas variables de backup: `stored_hp`, `stored_dmg`
- Método `set_invincible(bool)` rediseñado:
  - **Activar**: HP → 10,000, max_HP → 10,000, DMG → 10,000
  - **Desactivar**: Restaura HP y DMG originales desde backup
- `take_damage()` ignora daño si `debug_invincible == true`

**DebugPanel.gd**:
- Simplificado `_on_hero_invincible_toggled()`:
  - Busca Hero con `get_tree().get_first_node_in_group("hero")`
  - Llama a `hero.set_invincible(active)`
  - Eliminada lógica redundante de fallbacks

**DebugPanel.tscn**:
- Añadido CheckBox `ChkHeroInvincible` con unique_name
- Nueva sección "Gameplay Cheats:" en UI

---

## 📋 Estructura de animaciones

### Hero
```gdscript
AnimState.WALK   → hero_walk_01_12fps.png (63f @ 24fps)
AnimState.ATTACK → hero_attack_01_12fps.png (62f @ 24fps)  ✅ ACTIVA
AnimState.DEATH  → hero_death_12fps.png (64f @ 24fps)
```

### Enemy (Grunt/Tank)
```gdscript
AnimState.IDLE   → {tipo}_attack_12fps.png (62f @ 0fps = frame estático)
AnimState.ATTACK → {tipo}_attack_12fps.png (grunt F4-F57, tank F0-F61 @ 24fps)  ✅ ACTIVA
AnimState.DEATH  → {tipo}_death_12fps.png (64f @ 24fps)
```

---

## 🎮 Cómo testear

1. **Abrir DebugPanel**: Presiona **Shift+P** en juego
2. **Activar invencibilidad**: Marca "Hero Invincible"
3. **Verificar stats**: Hero debe mostrar:
   - HP: 10000 / 10000 (barra verde llena)
   - Consola: "Hero: Invincibility ENABLED (10k HP, 10k ATK)"
4. **Observar animaciones**:
   - Hero camina: animación WALK
   - Hero ataca enemigo: animación ATTACK (62 frames)
   - Enemigo ataca Hero: animación ATTACK (grunt 54 frames útiles, tank 62 frames)
   - Al morir: animación DEATH con pausa de 2.5s en último frame

---

## 🐛 Problemas conocidos

1. **Hero walk displacement**: La animación de caminar sigue desplazando al sprite hacia atrás aunque el personaje avanza correctamente. Requiere investigación de autoloads o ajuste de offset de sprite.

2. **Animación ATTACK loop**: Los ataques son eventos discretos (1 hit por ciclo de `atk_timer`), pero la animación hace loop completo. Considerar:
   - Reproducir 1 ciclo de animación por golpe
   - Sincronizar duración de animación con cadencia de ataque (APS)

3. **IDLE no se usa**: Hero siempre está en WALK (auto-avance), Enemy usa IDLE como frame de reposo pero nunca se ve en combate activo.

---

## ✅ Checklist de validación

- [x] Hero.gd compila sin errores
- [x] Enemy.gd compila sin errores
- [x] DebugPanel.gd compila sin errores
- [x] DebugPanel.tscn tiene CheckBox ChkHeroInvincible
- [x] Spritesheets de ataque existen (hero_attack_01_12fps.png, grunt_attack_12fps.png, tank_attack_12fps.png)
- [x] Invencibilidad setea 10k HP + 10k ATK
- [x] Invencibilidad restaura valores originales al desactivar
- [ ] Animación ATTACK se reproduce durante combate (requiere test en Main.tscn)
- [ ] Hero invencible sobrevive múltiples salas sin morir (requiere test en dungeon)

---

## 🚀 Próximos pasos

1. **Testear en Main.tscn**: Ejecutar escena principal y verificar animaciones de ataque durante combate real
2. **Sincronizar timing**: Ajustar duración de animación ATTACK para que coincida con cadencia de golpes (APS)
3. **Resolver walk displacement**: Investigar offset de sprite o interferencia de autoloads
4. **Optimizar transiciones**: Suavizar cambio entre WALK ↔ ATTACK ↔ DEATH sin parpadeos

---

**Estado**: ✅ Implementación completa, **pendiente testing en runtime**
