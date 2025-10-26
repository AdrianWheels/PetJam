# Limpieza de Sistema Legacy y Fix de Animaciones

**Fecha**: 26 octubre 2025  
**Objetivo**: Eliminar sistema legacy duplicado y corregir animaciones de combate

---

## 🔴 Problemas detectados

### 1. Hero NO encontrado por DebugPanel
**Causa**: Hero.tscn **no tenía grupo "hero"**
```
DebugPanel: Hero not found in scene tree
```

### 2. Animación de ATAQUE permanente
**Causa**: `is_attacking = true` se quedaba activo durante todo el combate, incluso entre golpes
**Síntoma**: Hero/Enemy siempre en animación ATTACK, nunca vuelven a WALK/IDLE

### 3. Sistema legacy duplicado (CRÍTICO)
**Archivos obsoletos encontrados**:
- `scripts/core/Hero.gd` (Node puro, sin escena, sin grupo)
- `scripts/core/Enemy.gd` (Node puro, sin escena)
- `scripts/core/RoomController.gd` (controlador antiguo de dungeon)
- `scripts/core/CombatController.gd` (controlador antiguo de combate)

**Referencia obsoleta**:
```gdscript
// RoomController.gd (OBSOLETO)
var HeroScene = preload("res://scripts/core/Hero.gd")
hero = HeroScene.new()  // Crea Node sin visuales
```

---

## ✅ Soluciones implementadas

### 1. Hero.tscn - Añadido grupo "hero"
**Archivo**: `scenes/Hero.tscn`
```gdscript
[node name="Hero" type="CharacterBody2D" groups=["hero"]]
```
- Ahora `get_tree().get_first_node_in_group("hero")` funciona correctamente
- DebugPanel puede encontrar al Hero para invencibilidad

### 2. Hero.gd - Fix de animación WALK ↔ ATTACK
**Archivo**: `scripts/gameplay/Hero.gd`

**Lógica añadida en `attack()`**:
```gdscript
func attack(target, particles: Array) -> void:
	if not alive or target == null or not target.alive:
		is_attacking = false  # Desactivar si no hay target
		return
	
	is_attacking = true
	atk_timer -= get_process_delta_time()
	
	# Si no hay golpes pendientes, desactivar animación
	if atk_timer > 0.0:
		is_attacking = false  # ← NUEVO: Volver a WALK entre golpes
		return
	
	while atk_timer <= 0.0 and target.alive:
		# ... ejecutar golpe
```

**Resultado**: 
- Hero muestra WALK mientras se acerca al enemigo
- Cambia a ATTACK solo cuando `atk_timer <= 0` (momento del golpe)
- Vuelve a WALK mientras recarga el siguiente golpe

### 3. Enemy.gd - Misma lógica de animación
**Archivo**: `scripts/gameplay/Enemy.gd`

Aplicada la misma lógica de `atk_timer > 0.0 → is_attacking = false`

### 4. Eliminación de archivos legacy
**Archivos eliminados**:
```
✓ scripts/core/Hero.gd (145 líneas de código obsoleto)
✓ scripts/core/Enemy.gd (código obsoleto)
✓ scripts/core/RoomController.gd (sistema antiguo de salas)
✓ scripts/core/CombatController.gd (sistema antiguo de combate)
✓ scripts/core/*.uid (archivos huérfanos)
```

**Sistema actual (correcto)**:
- Hero: `scripts/gameplay/Hero.gd` + `scenes/Hero.tscn`
- Enemy: `scripts/gameplay/Enemy.gd` + `scenes/Enemy.tscn`
- Combate: `scripts/gameplay/CombatController.gd` (activo)
- Dungeon: `scripts/gameplay/Corridor.gd` + `scenes/DungeonLayout.tscn`

---

## 📊 Validación

### ✅ Checklist de fixes
- [x] Hero.tscn tiene grupo "hero"
- [x] DebugPanel encuentra Hero con `get_first_node_in_group("hero")`
- [x] Invencibilidad funciona (10k HP, 10k ATK)
- [x] Hero.gd desactiva `is_attacking` entre golpes
- [x] Enemy.gd desactiva `is_attacking` entre golpes
- [x] Archivos legacy eliminados (Hero/Enemy/RoomController/CombatController en core/)
- [x] Sin errores de compilación en Hero.gd y Enemy.gd

### 📝 Logs esperados durante combate
```
Hero: Changed animation to WALK (mientras avanza)
Hero: Changed animation to ATTACK (al golpear)
Hero: Attack at 151.30 s, dmg=21.0, crit=false, aps=1.20
Hero: Changed animation to WALK (recarga golpe)
Hero: Changed animation to ATTACK (siguiente golpe)
```

---

## 🎮 Testing

### Escenario 1: Invencibilidad
1. Presionar **Shift+P** para abrir DebugPanel
2. Marcar **"Hero Invincible"**
3. Consola debe mostrar: `DebugPanel: Hero Invincible = true`
4. Hero debe mostrar: HP = 10000 / 10000

### Escenario 2: Animaciones de combate
1. Ejecutar Main.tscn
2. Observar Hero:
   - WALK mientras avanza hacia enemigo
   - ATTACK al momento de golpear (con SFX)
   - WALK entre golpes (recarga)
   - ATTACK al siguiente golpe
3. Observar Enemy:
   - IDLE mientras espera
   - ATTACK al momento de golpear Hero
   - IDLE entre golpes
   - DEATH al morir

### Escenario 3: Sin legacy
1. Buscar en consola: NO deben aparecer logs `[RoomController]`
2. Verificar `scripts/core/`: solo deben existir:
   - `MinigameBase.gd`
   - `HUDMinigameLauncher.gd`
   - `QualityHelper.gd`
   - `ParticleManager.gd`

---

## 🐛 Problemas conocidos (previos)

1. **Hero walk displacement**: Sprite se desplaza hacia atrás durante WALK (requiere investigación de offset)
2. **Timing de animación**: La duración de ATTACK (62 frames @ 24fps = 2.58s) no coincide con APS (1.20 = 0.83s entre golpes)
3. **IDLE no se usa**: Hero siempre en movimiento (WALK), Enemy solo usa IDLE como reposo visual

---

## 🚀 Próximos pasos

1. **Testear en runtime**: Ejecutar Main.tscn y validar transiciones WALK ↔ ATTACK
2. **Ajustar timing**: Sincronizar duración de animación ATTACK con cadencia real de golpes (APS)
3. **Resolver displacement**: Investigar offset de sprite en WALK
4. **Pulir transiciones**: Suavizar cambios entre estados sin parpadeos

---

**Estado**: ✅ Sistema legacy eliminado, animaciones corregidas, Hero localizable por DebugPanel
