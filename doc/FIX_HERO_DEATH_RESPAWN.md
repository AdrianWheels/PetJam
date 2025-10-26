# Fix: Héroe Muerto tras Respawn + Búsqueda Robusta HUD

**Fecha**: 26 octubre 2025  
**Problema**: Héroe no resucitaba tras morir (animación DEATH permanente) y DungeonHUD no encontraba héroe para equipar

---

## Problemas Solucionados

### 1. **Héroe se queda en DEATH tras respawn** 🐛
**Síntoma**: Al morir y respawnear, el héroe permanecía con animación DEATH sin poder atacar ni moverse.

**Causa raíz**: `respawn()` no reseteaba el estado de animación → `current_anim_state` permanecía en `AnimState.DEATH`.

**Solución** (`scripts/gameplay/Hero.gd` línea ~274):
```gdscript
func respawn(start_position: Vector2 = Vector2(2100, 1120)) -> void:
	reset_stats()
	position = start_position
	velocity = Vector2.ZERO
	alive = true
	# CRÍTICO: Resetear animación a WALK tras morir
	current_anim_state = AnimState.IDLE  # Forzar cambio
	_change_animation(AnimState.WALK)
	animation_timer = 0.0
	current_frame = 0
	death_hold_timer = 0.0
	# ...resto del código
```

**Cambios**:
- Resetear `current_anim_state` a `IDLE` antes de cambiar a `WALK` (fuerza transición)
- Llamar explícitamente a `_change_animation(AnimState.WALK)`
- Resetear timers (`animation_timer`, `death_hold_timer`, `current_frame`)

---

### 2. **DungeonHUD no encuentra héroe tras respawn** 🔍
**Síntoma**: Logs muestran `DungeonHUD: _update_stats() - Hero no válido` tras equipar items.

**Causa raíz**: Búsqueda por path absoluto (`Main/DungeonArea/Corridor/Hero`) fallaba si el nodo cambiaba tras respawn.

**Solución** (`scripts/ui/DungeonHUD.gd` línea ~70):
```gdscript
func _find_hero_if_needed() -> void:
	"""Busca el héroe si no está asignado"""
	if hero_ref and is_instance_valid(hero_ref):
		return
	
	# Usar grupo "hero" para búsqueda más robusta
	var heroes = get_tree().get_nodes_in_group("hero")
	if heroes.size() > 0:
		hero_ref = heroes[0]
		print("DungeonHUD: ✅ Héroe encontrado via grupo 'hero'")
		_update_stats()
		return
	
	# Fallback: búsqueda por path (si grupo no configurado)
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var dungeon_area = main.get_node_or_null("DungeonArea")
		if dungeon_area:
			var corridor_node = dungeon_area.get_node_or_null("Corridor")
			if corridor_node:
				hero_ref = corridor_node.get_node_or_null("Hero")
				if hero_ref:
					print("DungeonHUD: ✅ Héroe encontrado via path")
					_update_stats()
```

**Ventajas**:
- **Primario**: Búsqueda por grupo "hero" → más robusto ante cambios de escena
- **Fallback**: Búsqueda por path absoluto → compatible con código legacy
- **Logs mejorados**: Indica método de búsqueda usado

---

### 3. **Warning de UID del font** ⚠️
**Síntoma**: `WARNING: res://art/font/default_theme.tres:3 - ext_resource, invalid UID: uid://c15xqjd7evvoe`

**Causa**: UID desincronizado en `.tres` tras mover/renombrar archivos.

**Solución** (`art/font/default_theme.tres`):
```gdscript
[gd_resource type="Theme" load_steps=2 format=3]

# ANTES:
[ext_resource type="FontFile" uid="uid://c15xqjd7evvoe" path="res://art/font/PirataOne-Regular.ttf" id="1"]

# DESPUÉS (sin UID):
[ext_resource type="FontFile" path="res://art/font/PirataOne-Regular.ttf" id="1"]

[resource]
default_font = ExtResource("1")
default_font_size = 16
```

**Resultado**: Godot regenerará el UID correcto automáticamente al guardar.

---

### 4. **Mejora de textos de estado en HUD** 📝
**Cambio** (`scripts/ui/DungeonHUD.gd` línea ~120):
```gdscript
# Estado visual del héroe basado en animación actual
if state_label and hero_ref.has("current_anim_state"):
	var state_text = ""
	var anim_state = hero_ref.current_anim_state
	match anim_state:
		0:  # IDLE
			state_text = "⏸️ Parado"
			state_label.modulate = Color.GRAY
		1:  # WALK
			state_text = "🏃 Avanzando"  # Antes: "Corriendo"
			state_label.modulate = Color.WHITE
		2:  # ATTACK
			state_text = "⚔️ Atacando"
			state_label.modulate = Color.ORANGE
		3:  # DEATH
			state_text = "💀 Muriendo"
			state_label.modulate = Color.RED
		_:
			state_text = "❓ Estado: %d" % anim_state
			state_label.modulate = Color.YELLOW
	state_label.text = state_text
```

**Cambios**:
- "Corriendo" → "🏃 Avanzando" (más preciso: héroe avanza automáticamente)
- Añadidos emojis para identificación rápida
- Fallback case añade debug de estado numérico

---

## Respuesta a Preguntas del Usuario

### "No se si está puesto que se hagan las animaciones completas"
**Respuesta**: Las animaciones **SÍ se interrumpen** al cambiar de estado:
- `_change_animation()` resetea `current_frame = 0` y `animation_timer = 0.0`
- No hay "transiciones suaves" — el cambio es inmediato frame 0

**Por qué puede parecer lento**:
- Animaciones son de **62-63 frames** a 24fps → ~2.6 segundos por ciclo completo
- En combate rápido (APS 1.33), el héroe cambia WALK → ATTACK → WALK cada ~0.75s
- El frame 0 de ATTACK puede ser visualmente similar al final de WALK

**Opciones de mejora** (futuro):
1. Reducir frames de animaciones (mantener solo 20-30 frames clave)
2. Añadir transiciones con tween de opacidad (fade)
3. Usar AnimationPlayer con blend trees

### "Deberíamos utilizar estos estados para decirle al héroe cómo está"
**Respuesta**: Los estados **YA controlan** las animaciones del héroe:
```gdscript
# En Hero._process():
if not alive:
	_change_animation(AnimState.DEATH)
elif is_attacking:
	_change_animation(AnimState.ATTACK)
else:
	_change_animation(AnimState.WALK)
```

**Flujo actual**:
1. `is_attacking = true` cuando `atk_timer <= 0` (Hero.attack())
2. `_process()` detecta `is_attacking` → cambia a `AnimState.ATTACK`
3. Entre ataques (`atk_timer > 0`): `is_attacking = false` → vuelve a `AnimState.WALK`
4. Al morir: `alive = false` → cambia a `AnimState.DEATH`

**El sistema funciona correctamente** — solo necesitaba resetear en respawn.

---

## Testing

### Checklist de Validación:
- [x] Héroe respawnea con animación WALK activa
- [x] DungeonHUD encuentra héroe via grupo "hero" tras respawn
- [x] Warning de UID de font eliminado
- [x] Estado visual en HUD usa textos descriptivos con emojis
- [x] Animaciones se interrumpen al cambiar de estado (resetean a frame 0)

### Flujo de Testing:
1. **Iniciar dungeon** → Estado: "🏃 Avanzando" (blanco)
2. **Entrar en combate** → Estado: "⚔️ Atacando" (naranja)
3. **Morir** → Estado: "💀 Muriendo" (rojo)
4. **Respawn automático** → Estado: "🏃 Avanzando" (blanco) ✅
5. **Equipar item** → DungeonHUD actualiza stats correctamente ✅

---

## Archivos Modificados

```
✏️ scripts/gameplay/Hero.gd
   - respawn(): Añadido reseteo de animación a WALK
   - Resetea current_anim_state, animation_timer, current_frame, death_hold_timer

✏️ scripts/ui/DungeonHUD.gd
   - _find_hero_if_needed(): Búsqueda por grupo "hero" + fallback por path
   - _update_stats_silent(): Textos de estado con emojis ("🏃 Avanzando", "⚔️ Atacando")

✏️ art/font/default_theme.tres
   - Eliminado UID inválido de ext_resource (Godot regenerará automáticamente)
```

---

## Notas Técnicas

### Animaciones: Loop vs. One-shot
**Actual**:
- WALK, ATTACK, IDLE: **Loop infinito** (`current_frame = (current_frame + 1) % hframes`)
- DEATH: **One-shot + hold** (pausa 2.5s en último frame antes de loop)

**Comportamiento correcto**:
- WALK loop: héroe avanza constantemente
- ATTACK loop: mantiene animación mientras `is_attacking = true`
- DEATH hold: permite ver animación completa antes de respawn

### Grupos de Godot
El héroe está en grupo "hero" (configurado en `Hero.tscn`):
```gdscript
# Búsqueda robusta:
var heroes = get_tree().get_nodes_in_group("hero")
if heroes.size() > 0:
	hero_ref = heroes[0]
```

**Ventaja**: Independiente de paths absolutos → funciona tras respawn/instanciamiento dinámico.

---

## Próximos Pasos Opcionales

1. **Optimizar duración de animaciones**: Reducir de 62 frames a 30-40 para feedback más rápido
2. **Añadir blend entre estados**: Tween de opacidad WALK→ATTACK para transición suave
3. **Debug overlay animaciones**: Panel que muestre `current_anim_state` numérico en runtime
4. **Particle effects**: Añadir VFX en cambios de animación (polvo al atacar, destello al morir)
