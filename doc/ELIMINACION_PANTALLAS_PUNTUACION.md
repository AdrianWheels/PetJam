# Eliminación de Pantallas de Puntuación Legacy

## Problema
Los minijuegos tenían pantallas de puntuación final (`setup_end_screen()`) que eran legacy del sistema de pruebas individuales. Estas pantallas interrumpían el flujo correcto del sistema de trials:

1. El minijuego llamaba `complete_trial(result)` → emitía `trial_completed`
2. Después mostraba una pantalla con estadísticas esperando confirmación del usuario
3. Al presionar continuar, volvía a llamar `complete_trial()` (redundante)
4. Esto interrumpía el flujo automático de la cola de trials

## Flujo Correcto
Con el sistema de trials actual:
1. Usuario selecciona un blueprint de la cola
2. `CraftingManager` inicia la secuencia de trials (Forge → Hammer → Sew → Quench)
3. Cada trial se ejecuta **automáticamente uno tras otro**
4. Al completar TODOS los trials:
   - `CraftingManager` genera el ítem con calidad basada en resultados
   - `UIManager.present_delivery()` muestra el ítem final
   - Usuario decide: entregar al héroe o vender a cliente
5. Se actualiza la cola de pedidos (RequestsManager)

## Solución Implementada

### Cambios en MinigameBase.gd
**Eliminado:**
- Variable `end_screen`
- Función `setup_end_screen(title, result_text)`
- Función `_on_end_continue()`

**Conservado:**
- `_fade_out_and_close()` — método público usado por minijuegos para auto-cerrar

### Cambios en Minijuegos (4 archivos)

#### ForgeMinigame.gd
```gdscript
# ANTES (legacy):
complete_trial(result)
var outcome := "🎉 ÉXITO" if success else "❌ FALLO"
var stats := "Perfect: %d | Bien: %d | Regular: %d | Miss: %d" % [...]
setup_end_screen(outcome, stats + "\n\nPulsa para cerrar")

# DESPUÉS (flujo automático):
complete_trial(result)
await get_tree().create_timer(0.5).timeout
_fade_out_and_close()
```

#### HammerMinigame.gd
```gdscript
# ANTES (legacy):
complete_trial(result)
var outcome := "🎉 ÉXITO" if success else "❌ FALLO"
var stats := "Perfect: %d | Bien: %d | Regular: %d | Miss: %d\nMáx Combo: %d" % [...]
setup_end_screen(outcome, stats + "\n\nPulsa para cerrar")

# DESPUÉS (flujo automático):
complete_trial(result)
await get_tree().create_timer(0.5).timeout
_fade_out_and_close()
```

#### SewMinigame.gd
```gdscript
# ANTES (legacy):
complete_trial(result)
var outcome := "🎉 ÉXITO" if success else "❌ FALLO"
var stats := "Perfect: %d | Bien: %d | Regular: %d | Miss: %d\nMáx Combo: %d" % [...]
setup_end_screen(outcome, stats + "\n\nPulsa para cerrar")

# DESPUÉS (flujo automático):
complete_trial(result)
await get_tree().create_timer(0.5).timeout
_fade_out_and_close()
```

#### QuenchMinigame.gd
```gdscript
# ANTES (legacy):
complete_trial(result)
var outcome := "🎉 ÉXITO" if success else "❌ FALLO"
var temp_text := "Temperatura: %d°C\nÓptimo: %d-%d°C\nCalidad: %s" % [...]
if _catalyst_bonus:
	temp_text += "\n✨ Catalizador activo (+20% ventana)"
setup_end_screen(outcome, temp_text + "\n\nPulsa para cerrar")

# DESPUÉS (flujo automático):
complete_trial(result)
await get_tree().create_timer(0.5).timeout
_fade_out_and_close()
```

## Ventajas del Nuevo Flujo

1. **Automatización completa**: Los trials se ejecutan en secuencia sin interrupciones manuales
2. **UX consistente**: El usuario ve el resultado final (ítem con calidad) en lugar de 4 pantallas intermedias
3. **Mejor ritmo**: 0.5s de delay entre trials (tiempo de fade-out) mantiene el flujo dinámico
4. **Menos código**: Eliminadas ~30 líneas de código legacy innecesario
5. **Menos bugs**: Una sola emisión de `trial_completed` por trial (antes se emitía 2 veces)

## Flujo Visual del Usuario

```
[Seleccionar Blueprint]
         ↓
[Trial 1: Forge] → fade out (0.5s)
         ↓
[Trial 2: Hammer] → fade out (0.5s)
         ↓
[Trial 3: Sew] → fade out (0.5s)
         ↓
[Trial 4: Quench] → fade out (0.5s)
         ↓
[Pantalla Final: Ítem Generado]
    - Calidad: Perfecta/Alta/Media/Baja
    - Opciones: Entregar | Vender
         ↓
[Volver a Cola de Blueprints]
```

## Testing
✅ Probar secuencia completa de 4 trials
✅ Verificar que no aparecen pantallas intermedias
✅ Confirmar que `UIManager.present_delivery()` muestra el ítem final
✅ Validar que la cola de blueprints se actualiza correctamente

## Archivos Modificados
- `scripts/core/MinigameBase.gd` — Eliminado código de end_screen
- `scripts/ForgeMinigame.gd` — Auto-cerrar sin pantalla
- `scripts/HammerMinigame.gd` — Auto-cerrar sin pantalla
- `scripts/SewMinigame.gd` — Auto-cerrar sin pantalla
- `scripts/QuenchMinigame.gd` — Auto-cerrar sin pantalla

## Notas
- El delay de 0.5s permite que el fade-out sea visible y natural
- `HUDMinigameLauncher` ya manejaba el fade-out, ahora solo recibe la señal más rápido
- Las estadísticas de cada trial siguen registrándose en `TrialResult.details`
- `TelemetryManager` sigue logeando cada trial individualmente
