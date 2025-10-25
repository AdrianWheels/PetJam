# Sistema de Activación Contextual de Audio

## Resumen
El audio ahora se activa **automáticamente según el área actual**:
- **FORGE context**: activo solo en la zona de forja y minijuegos
- **DUNGEON context**: activo solo en la zona de dungeon/combate
- **GLOBAL context**: siempre activo (UI, menús, efectos transversales)

## Estados por defecto

### AudioManager (`_setup_context`)
```gdscript
_contexts[context] = {
    "enabled": false,  // ⚠️ Desactivado por defecto
}
```
- FORGE y DUNGEON inician **desactivados**
- GLOBAL siempre activo (no se puede desactivar)

### Main.gd (`_ready`)
```gdscript
# Activar contexto inicial (FORGE por defecto)
am.set_context_enabled(am.AudioContext.FORGE, true)
am.set_context_enabled(am.AudioContext.DUNGEON, false)
```
- Al arrancar el juego, activa **FORGE** (área inicial)
- DUNGEON permanece silenciado

### Main.gd (`_on_area_changed`)
```gdscript
if is_dungeon:
    am.set_context_enabled(am.AudioContext.FORGE, false)
    am.set_context_enabled(am.AudioContext.DUNGEON, true)
else:
    am.set_context_enabled(am.AudioContext.DUNGEON, false)
    am.set_context_enabled(am.AudioContext.FORGE, true)
```
- Al cambiar de área, activa el contexto correspondiente
- **Mutuamente excluyente**: solo un contexto activo a la vez (+ GLOBAL)

### MinigameBase.gd (`start_trial`)
```gdscript
# Activar contexto FORGE al iniciar minijuego
am.set_context_enabled(am.AudioContext.FORGE, true)
```
- **Redundancia de seguridad**: asegura FORGE activo en minijuegos
- No es necesario desactivar al salir (Main.gd maneja transiciones)

## Comportamiento esperado

### Escenario 1: Inicio del juego
1. Main.gd arranca en área **FORGE**
2. AudioManager tiene FORGE=**true**, DUNGEON=**false**
3. ✅ Sonidos de forja/minijuegos se escuchan
4. ❌ Sonidos de dungeon/combate silenciados

### Escenario 2: Cambiar a Dungeon (clic derecho)
1. Usuario hace clic derecho
2. Main.gd llama `_on_area_changed(&"dungeon")`
3. AudioManager cambia a FORGE=**false**, DUNGEON=**true**
4. ❌ Sonidos de forja silenciados
5. ✅ Sonidos de combate (Hero ataque) se escuchan

### Escenario 3: Hero ataca enemy
```gdscript
// Hero.gd
am.play_sfx(hit_sfx, -20.0, am.AudioContext.DUNGEON)
```
- **Si estás en FORGE**: ❌ No suena (DUNGEON desactivado)
- **Si estás en DUNGEON**: ✅ Suena a -20dB (DUNGEON activado)

### Escenario 4: Iniciar minijuego desde forja
1. Usuario inicia Martillo/Forja/Coser/Quench
2. MinigameBase.start_trial activa FORGE (redundante, ya está activo)
3. ✅ Sonidos del minijuego se escuchan
4. Al salir, vuelve a forja (FORGE sigue activo)

## Verificación manual

### Paso 1: Testear ataque héroe en ambas áreas
```
1. Arrancar juego (Main.tscn)
2. Clic derecho → cambiar a DUNGEON
3. Observar console: "AudioManager: Playing SFX [DUNGEON]"
4. ✅ Escuchar sonido de ataque del héroe
5. Clic derecho → volver a FORGE
6. Observar console: (sin mensajes de SFX dungeon)
7. ❌ NO escuchar sonido de ataque del héroe
```

### Paso 2: Testear minijuegos
```
1. En área FORGE, iniciar Martillo
2. Observar console: "[MinigameBase] FORGE audio context activated"
3. Golpear martillo
4. ✅ Escuchar SFX de martillo
5. Completar minijuego
6. ✅ Seguir escuchando SFX de forja
```

### Paso 3: DebugPanel (Shift+P)
```
1. Presionar Shift+P para mostrar panel
2. Observar checkboxes:
   - Forge Audio: ☑ (checked)
   - Dungeon Audio: ☐ (unchecked)
3. Desmarcar "Forge Audio"
4. Iniciar Martillo
5. ❌ NO escuchar SFX de martillo
6. Marcar "Dungeon Audio"
7. Cambiar a DUNGEON
8. ✅ Escuchar ataque héroe
```

## Integración con DebugPanel

El panel refleja el estado **actual** de cada contexto:
- Al abrir el panel, `_sync_initial_state()` consulta `is_context_enabled()`
- Checkboxes muestran el estado real (FORGE activo, DUNGEON inactivo)
- Cambiar un checkbox llama `set_context_enabled()` y persiste

## Notas técnicas

### Por qué GLOBAL no se desactiva
```gdscript
func set_context_enabled(context: AudioContext, enabled: bool) -> void:
    if context == AudioContext.GLOBAL:
        push_warning("AudioManager: Cannot disable GLOBAL context")
        return
```
- UI siempre debe sonar (clicks, confirmaciones)
- Evita estados inválidos

### Por qué detener audio al desactivar
```gdscript
if not enabled:
    ctx.music_player.stop()
    ctx.sfx_player.stop()
```
- Evita audio "fantasma" de contextos inactivos
- Transiciones limpias entre áreas

### Compatibilidad backward
```gdscript
func play_sfx(stream, volume_db=0.0, context=AudioContext.GLOBAL)
```
- Código antiguo sin `context` sigue funcionando (usa GLOBAL)
- GLOBAL siempre activo → no rompe nada existente

## Archivos modificados

### 1. `scripts/autoload/AudioManager.gd`
- `_setup_context`: enabled=**false** por defecto
- `is_context_enabled`: ya existía, sin cambios

### 2. `scripts/main.gd`
- `_ready`: activa FORGE al inicio
- `_on_area_changed`: switch entre FORGE/DUNGEON según área

### 3. `scripts/core/MinigameBase.gd`
- `start_trial`: activa FORGE al entrar (seguridad)
- `_on_end_continue`: no desactiva (Main.gd maneja)

### 4. `scripts/ui/DebugPanel.gd`
- Sin cambios (ya consultaba `is_context_enabled`)

## Próximos pasos opcionales

1. **Migrar más sonidos**:
   - Enemy.gd → AudioContext.DUNGEON
   - CraftingManager → AudioContext.FORGE

2. **Persistencia**:
   - Guardar estado checkboxes en `user://debug_config.json`
   - Restaurar al reiniciar

3. **Hotkeys individuales**:
   - F5: toggle FORGE audio
   - F6: toggle DUNGEON audio

4. **Telemetría**:
   - Registrar cambios de contexto en TelemetryManager
   - Analizar patrones de uso

## Fecha
Implementado: 2025-10-24
