# Plan de Mejora: Animaciones de Combate Hero/Enemy

## Análisis del Sistema Actual

### 🔍 Detección de Combate
**Método**: Detección por **proximidad** (overlap de rectángulos)
- En `Corridor.gd`: función `check_overlap(pos1, size1, pos2, size2)`
- Se comprueba intersección de `Rect2` entre Hero y Enemy
- Cuando hay overlap → `state = State.FIGHT` → `combat_controller.start_combat()`
- **Es correcto para combate melee** ✅

### 📊 Estado Actual Hero
**Archivo**: `scripts/gameplay/Hero.gd`
- **Tamaño**: `Vector2(42, 64)` (base, sin escala)
- **Scale en escena**: `5.4` → Tamaño real ~227x346 px
- **Animaciones**: 3 estados principales
  - `WALK`: `hero_walk_01_12fps.png` (63 frames, 24fps)
  - `ATTACK`: `hero_attack_01_12fps.png` (62 frames, 24fps)
  - `DEATH`: `hero_death_12fps.png` (64 frames, 24fps)
- **Sistema**: `_process(delta)` actualiza frames según estado
- **Problema identificado**: 
  - `is_attacking` flag se activa pero **no se sincroniza con el frame de golpe**
  - La animación corre a 24fps constante sin coordinación con `aps` (attacks per second)

### 📊 Estado Actual Enemy
**Archivo**: `scripts/gameplay/Enemy.gd`
- **Tamaño**: `Vector2(40, 52)` (base, sin escala)
- **Scale en escena**: `5.4` → Tamaño real ~216x281 px
- **Animaciones**: 3 estados
  - `IDLE`: Primer frame de attack (FPS=0, estático) ✅
  - `ATTACK`: `grunt_attack_12fps.png` o `tank_attack_12fps.png` (62 frames, 24fps)
  - `DEATH`: `grunt_death_12fps.png` o `tank_death_12fps.png` (64 frames, 24fps)
- **Problema identificado**:
  - Grunt: usa frames 4-57 (skip F0-F3 y F58-F61)
  - Tank: usa frames 0-61 completos
  - `is_attacking` flag inconsistente (se apaga en medio del ataque)

### 🎯 Problemas Detectados

1. **Sincronización Animación-Daño**:
   - Hero y Enemy hacen daño en `attack()` cuando `atk_timer <= 0.0`
   - La animación corre independiente a 24fps
   - **No hay frame específico de "golpe"** coordinado con el daño real

2. **Flag `is_attacking` Inconsistente**:
   - Hero: mantiene `is_attacking=true` mientras hay target
   - Enemy: apaga `is_attacking` cuando `atk_timer > 0.0` (❌ incorrecto)

3. **Tamaños Similares pero Diferentes Scales**:
   - Hero: 42x64 base → scale 5.4 → ~227x346 px
   - Enemy: 40x52 base → scale 5.4 → ~216x281 px
   - **Diferencia**: Hero ~8% más alto (correcto para protagonista)

4. **Responsividad Layout**:
   - DungeonLayout usa posiciones fijas
   - Hero/Enemy usan scale fijo `5.4`
   - **No hay adaptación a diferentes resoluciones**

---

## 📋 Plan de Implementación

### ✅ Fase 1: Sincronización Animación-Daño (CRÍTICO)

#### 1.1 Definir Frame de Golpe
**Archivo**: `Hero.gd` y `Enemy.gd`

```gdscript
# Añadir a anim_config
AnimState.ATTACK: {
	"texture": load("..."),
	"hframes": 62,
	"fps": 24.0,
	"hit_frame": 31  # Frame medio donde ocurre el golpe (ajustar manualmente)
}
```

**Acción manual requerida**:
- Abrir spritesheets en editor de imagen
- Identificar visualmente el frame donde la espada/garrote impacta
- Para Hero: probablemente frame 30-35 (mitad de 62)
- Para Enemy grunt: probablemente frame 28-32 (mitad de 4-57 = ~30)
- Para Enemy tank: probablemente frame 30-35

#### 1.2 Sistema de Sincronización por APS
**Problema**: Animación corre a 24fps fijo, pero APS varía (0.3-5.0 golpes/seg)

**Solución**: Ajustar FPS de animación según APS

```gdscript
# En Hero.gd y Enemy.gd
func _calculate_attack_fps() -> float:
	# APS = golpes por segundo
	# Queremos que la animación de ATTACK dure 1/APS segundos
	var attack_duration = 1.0 / aps
	var total_frames = anim_config[AnimState.ATTACK]["hframes"]
	var required_fps = total_frames / attack_duration
	return clamp(required_fps, 12.0, 60.0)  # Min 12fps, max 60fps
```

**Aplicar en `_change_animation()`**:
```gdscript
if new_state == AnimState.ATTACK:
	config["fps"] = _calculate_attack_fps()
```

#### 1.3 Emitir Señal en Frame de Golpe
**Archivo**: `Hero.gd` y `Enemy.gd`

```gdscript
signal hit_frame_reached  # Nueva señal

func _process(delta: float) -> void:
	# ... código existente ...
	
	# Al avanzar frame, detectar hit_frame
	if current_anim_state == AnimState.ATTACK:
		var config = anim_config[AnimState.ATTACK]
		if "hit_frame" in config and current_frame == config["hit_frame"]:
			emit_signal("hit_frame_reached")
```

**Conectar señal en `CombatController.gd`**:
```gdscript
func _ready():
	hero.connect("hit_frame_reached", Callable(self, "_on_hero_hit_frame"))
	enemy.connect("hit_frame_reached", Callable(self, "_on_enemy_hit_frame"))

func _on_hero_hit_frame():
	if combat_active and hero.alive and enemy.alive:
		_execute_hero_attack()

func _on_enemy_hit_frame():
	if combat_active and enemy.alive and hero.alive:
		_execute_enemy_attack()
```

#### 1.4 Refactorizar `attack()` para Separar Lógica
**Archivo**: `Hero.gd` y `Enemy.gd`

```gdscript
# ANTES: attack() hace daño cuando atk_timer <= 0
# DESPUÉS: attack() solo maneja timing, CombatController ejecuta daño

func is_ready_to_attack() -> bool:
	return atk_timer <= 0.0

func consume_attack() -> Dictionary:
	"""Ejecuta un ataque y retorna info de daño"""
	if atk_timer > 0.0:
		return {}
	
	atk_timer += 1.0 / aps
	var damage := dmg
	var crit := randf() < crit_p
	if crit:
		damage *= crit_m
	
	return {
		"damage": int(damage),
		"is_crit": crit
	}
```

---

### ✅ Fase 2: Corrección Enemy IDLE y ATTACK

#### 2.1 Enemy IDLE: Mantener Primer Frame
**Estado**: ✅ Ya implementado correctamente
- `fps: 0.0` mantiene frame estático
- Grunt usa `start_frame: 4` (correcto)

#### 2.2 Enemy ATTACK: Mantener Flag Activo
**Archivo**: `Enemy.gd` líneas 218-238

**Cambio**:
```gdscript
# ANTES (líneas 227-230):
is_attacking = true
atk_timer -= get_process_delta_time()

if atk_timer > 0.0:
	is_attacking = false  # ❌ INCORRECTO
	return

# DESPUÉS:
is_attacking = true  # Mantener durante todo el combate
atk_timer -= get_process_delta_time()

if atk_timer > 0.0:
	return  # No apagar flag, solo esperar
```

---

### ✅ Fase 3: Ajuste de Tamaños y Responsividad

#### 3.1 Verificar Tamaños Relativos
**Acción**: Medir PNGs reales de spritesheets

```bash
# PowerShell
Get-Item "art/assets/Spritesheets/Hero/*.png" | 
  Select Name, @{N='Width';E={[System.Drawing.Image]::FromFile($_.FullName).Width}}, 
           @{N='Height';E={[System.Drawing.Image]::FromFile($_.FullName).Height}}

Get-Item "art/assets/Spritesheets/Enemies/*.png" | 
  Select Name, @{N='Width';E={[System.Drawing.Image]::FromFile($_.FullName).Width}}, 
           @{N='Height';E={[System.Drawing.Image]::FromFile($_.FullName).Height}}
```

**Calcular frame size real**:
- Hero walk: `width / 63` × `height` = tamaño de un frame
- Enemy grunt: `width / 62` × `height` = tamaño de un frame

#### 3.2 Sistema de Scale Dinámico
**Archivo**: `Hero.gd` y `Enemy.gd`

```gdscript
func _setup_animations() -> void:
	# ... cargar texturas ...
	
	# Calcular scale automático para viewport
	_calculate_sprite_scale()

func _calculate_sprite_scale() -> void:
	"""Ajusta scale del sprite según resolución del viewport"""
	var viewport_size = get_viewport_rect().size
	var is_portrait = viewport_size.y > viewport_size.x
	
	if is_portrait:
		# Mobile portrait: escalar según altura
		# Target: Hero ocupa ~15% de altura de viewport
		var target_height = viewport_size.y * 0.15
		var base_height = 64.0  # Altura base del Hero
		scale = Vector2.ONE * (target_height / base_height)
	else:
		# Desktop: scale fijo 5.4 (actual)
		scale = Vector2.ONE * 5.4
	
	print("Hero: Viewport %v, scale=%.2f" % [viewport_size, scale.x])
```

#### 3.3 DungeonLayout Responsive
**Archivo**: `DungeonLayout.gd`

```gdscript
func _ready() -> void:
	_adjust_for_viewport()
	# ... resto del código ...

func _adjust_for_viewport() -> void:
	"""Ajusta posiciones según resolución"""
	var viewport_size = get_viewport_rect().size
	var is_portrait = viewport_size.y > viewport_size.x
	
	if is_portrait:
		# Mobile 1080x1920: ajustar Y del suelo
		# Hero debe estar en 60% inferior = Y ~1152px
		# Aplicar offset a todas las room zones
		var y_offset = viewport_size.y * 0.6
		if room_zones:
			for room in room_zones.get_children():
				room.position.y = y_offset
	
	print("DungeonLayout: Viewport %v, adjusted=%s" % [viewport_size, is_portrait])
```

---

### ✅ Fase 4: Testing y Ajuste Manual

#### 4.1 Identificar Hit Frames Manualmente
**Proceso**:
1. Abrir `hero_attack_01_12fps.png` en GIMP/Photoshop
2. Dividir en 62 frames (width / 62)
3. Buscar visualmente el frame donde:
   - La espada está en máxima extensión
   - Hay contacto visual con el objetivo
4. Anotar número de frame (0-based)
5. Repetir para grunt y tank

**Registrar en**:
```gdscript
# Hero.gd - _setup_animations()
AnimState.ATTACK: {
	"texture": load("res://art/assets/Spritesheets/Hero/hero_attack_01_12fps.png"),
	"hframes": 62,
	"fps": 24.0,
	"hit_frame": 31  # AJUSTAR TRAS INSPECCIÓN VISUAL
}

# Enemy.gd - _setup_animations()
# Grunt
AnimState.ATTACK: {
	"texture": load("res://art/assets/Spritesheets/Enemies/grunt_attack_12fps.png"),
	"hframes": 62,
	"fps": 24.0,
	"hit_frame": 30,  # AJUSTAR
	"start_frame": 4,
	"end_frame": 57
}

# Tank
AnimState.ATTACK: {
	"texture": load("res://art/assets/Spritesheets/Enemies/tank_attack_12fps.png"),
	"hframes": 62,
	"fps": 24.0,
	"hit_frame": 31  # AJUSTAR
}
```

#### 4.2 Ajustar APS según Velocidad de Animación
**Objetivo**: Que 1 ciclo de animación = 1 golpe

**Testing**:
```
APS=1.0 → 1 golpe/seg → Animación debe durar 1.0s
APS=2.0 → 2 golpes/seg → Animación debe durar 0.5s
APS=5.0 → 5 golpes/seg → Animación debe durar 0.2s
```

**Fórmula**:
```
FPS_animación = hframes / (1.0 / APS)
              = hframes * APS

Ejemplo con 62 frames:
- APS=1.0 → FPS=62 (animación completa en 1s)
- APS=2.0 → FPS=124 (animación en 0.5s, clampear a 60fps)
- APS=0.5 → FPS=31 (animación en 2s)
```

---

## 🎬 Sistema de FX de Golpe (Opcional)

### Añadir Flash en Hit Frame
**Archivo**: `Hero.gd` / `Enemy.gd`

```gdscript
func _process(delta: float) -> void:
	# ... actualizar animación ...
	
	# Flash blanco en hit frame
	if current_anim_state == AnimState.ATTACK:
		var config = anim_config[AnimState.ATTACK]
		if "hit_frame" in config and current_frame == config["hit_frame"]:
			_trigger_hit_flash()

func _trigger_hit_flash() -> void:
	if sprite:
		sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)  # Flash blanco
		await get_tree().create_timer(0.05).timeout
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Restaurar
```

---

## 📝 Checklist de Implementación

### Fase 1: Sincronización (90 min)
- [ ] Añadir `hit_frame` a `anim_config` (Hero y Enemy)
- [ ] Implementar `_calculate_attack_fps()` (Hero y Enemy)
- [ ] Añadir señal `hit_frame_reached` (Hero y Enemy)
- [ ] Detectar y emitir en `_process()` (Hero y Enemy)
- [ ] Conectar señales en `CombatController`
- [ ] Refactorizar `attack()` → `consume_attack()` (Hero y Enemy)
- [ ] Actualizar `CombatController._process()` para usar señales

### Fase 2: Corrección Enemy (15 min)
- [ ] Eliminar `is_attacking = false` en Enemy.attack() línea 230
- [ ] Verificar que IDLE mantiene frame estático

### Fase 3: Responsividad (45 min)
- [ ] Medir tamaños reales de PNGs (PowerShell script)
- [ ] Implementar `_calculate_sprite_scale()` (Hero y Enemy)
- [ ] Añadir `_adjust_for_viewport()` en DungeonLayout
- [ ] Testear en 1280x720 y 1080x1920

### Fase 4: Testing Manual (30 min)
- [ ] Identificar hit_frame visual para Hero
- [ ] Identificar hit_frame visual para Grunt
- [ ] Identificar hit_frame visual para Tank
- [ ] Ajustar valores en código
- [ ] Testear con diferentes APS (0.5, 1.0, 2.0, 5.0)
- [ ] Verificar que animación y daño están sincronizados

### Opcional: FX (15 min)
- [ ] Implementar flash blanco en hit_frame
- [ ] Añadir shake de cámara en golpes críticos

---

## 🚀 Orden de Ejecución Recomendado

1. **Fase 4 primero** (identificar hit_frames manualmente) → 30 min
2. **Fase 1** (sincronización) → 90 min
3. **Fase 2** (corrección enemy) → 15 min
4. **Fase 3** (responsividad) → 45 min
5. **Testing final** → 30 min

**Total estimado**: 3.5 horas (dividir en 2 sesiones de ~90 min)

---

## ⚠️ Notas Importantes

- **TABS obligatorios**: Godot 4.5.1 requiere tabs, no espacios
- **No romper autoloads**: No tocar GameManager, CombatController está OK
- **Audio contextual**: SFX de golpe ya integrado con AudioManager (contexto DUNGEON)
- **Telemetría**: Considerar loggear cadencia de ataques para balanceo post-jam
