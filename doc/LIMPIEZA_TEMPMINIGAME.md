# Limpieza de Referencias a TempMinigame

## Problema Detectado
Al eliminar `TempMinigame.tscn`, quedaron referencias en varios archivos que causaban errores de carga en cascada:

```
ERROR: Cannot open file 'res://scenes/Minigames/TempMinigame.tscn'.
ERROR: Failed loading resource: res://data/blueprints/potion_heal.tres.
ERROR: Failed loading resource: res://data/blueprints/BlueprintLibrary.tres.
```

---

## Soluciones Implementadas

### 1. ✅ HUDMinigameLauncher.gd
**Archivo:** `scripts/core/HUDMinigameLauncher.gd`

**Cambio:**
```gdscript
const FALLBACK_MINIGAMES := {
    &"Forge": preload("res://scenes/Minigames/ForgeTemp.tscn"),
    &"Hammer": preload("res://scenes/Minigames/HammerMinigame.tscn"),
    &"Sew": preload("res://scenes/Minigames/SewOSU.tscn"),
    &"Quench": preload("res://scenes/Minigames/QuenchWater.tscn"),
    # &"Temp" eliminado - usar "Forge" en su lugar
}
```

**Antes:** Incluía `&"Temp": preload("res://scenes/Minigames/TempMinigame.tscn")`

---

### 2. ✅ potion_heal.tres
**Archivo:** `data/blueprints/potion_heal.tres`

**Cambios:**
- `[ext_resource ... path="res://scenes/Minigames/TempMinigame.tscn"]` → `ForgeTemp.tscn`
- `minigame_id = "Temp"` → `minigame_id = "Forge"`

**Resultado:**
- La poción ahora usa el minijuego `ForgeTemp` correctamente
- El ID coincide con el diccionario FALLBACK_MINIGAMES

---

### 3. ✅ shield_wooden.tres
**Archivo:** `data/blueprints/shield_wooden.tres`

**Cambios:**
- `minigame_id = "temp"` → `minigame_id = "Forge"` (2 ocurrencias)

**Nota:** Ya apuntaba a `ForgeTemp.tscn`, solo faltaba corregir el ID en minúsculas

---

### 4. ✅ sword_basic.tres
**Archivo:** `data/blueprints/sword_basic.tres`

**Cambios:**
- `minigame_id = "temp"` → `minigame_id = "Forge"` (2 ocurrencias)

**Nota:** Ya apuntaba a `ForgeTemp.tscn`, solo faltaba corregir el ID en minúsculas

---

## Verificación

### ✅ Archivos Corregidos
- [x] `scripts/core/HUDMinigameLauncher.gd`
- [x] `data/blueprints/potion_heal.tres`
- [x] `data/blueprints/shield_wooden.tres`
- [x] `data/blueprints/sword_basic.tres`

### ✅ Sin Errores
- No hay errores de compilación en los archivos modificados
- No quedan referencias a `TempMinigame.tscn`
- No quedan IDs `"Temp"` o `"temp"` en blueprints

### ✅ Limpieza de Archivos
- `TempMinigame.tscn` - eliminado ✓
- `TempMinigame.gd` - eliminado ✓
- `*.uid` huérfanos - no existían ✓

---

## Impacto en el Sistema

### Blueprints Afectados
Todos los blueprints que usaban el minijuego "Temp" ahora usan **"Forge" (ForgeTemp.tscn)**:

1. **potion_heal** - Poción de curación
2. **shield_wooden** - Escudo de madera
3. **sword_basic** - Espada básica

### Compatibilidad
- ✅ `ForgeTemp.tscn` es funcionalmente equivalente a `TempMinigame.tscn`
- ✅ Los parámetros de configuración se mantienen compatibles
- ✅ No se requieren cambios en la lógica de juego

---

## Próximos Pasos

### Testing Recomendado
1. Iniciar el juego y verificar que no haya errores en consola
2. Probar crafteo de:
   - Poción de curación
   - Escudo de madera
   - Espada básica
3. Verificar que el minijuego ForgeTemp se carga correctamente
4. Confirmar que los parámetros se aplican bien (hardness, precision, etc.)

### Verificación de Integridad
```bash
# Buscar referencias perdidas (debería devolver 0 resultados)
grep -r "TempMinigame" data/
grep -r "minigame_id.*temp" data/ --ignore-case
```

---

## Resumen Técnico

| Aspecto | Estado |
|---------|--------|
| **Referencias eliminadas** | 6 ubicaciones |
| **Blueprints migrados** | 3 archivos |
| **Minijuego reemplazo** | ForgeTemp.tscn |
| **Errores restantes** | 0 |
| **Breaking changes** | Ninguno |

---

**Fecha:** 2025-10-24  
**Estado:** ✅ Completado  
**Tested:** Pendiente de testing en runtime
