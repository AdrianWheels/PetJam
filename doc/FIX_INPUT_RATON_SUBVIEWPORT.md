# 🖱️ FIX: Input del ratón en minijuegos dentro de SubViewport

## Problema detectado

Los minijuegos ejecutados dentro del `MinigameContainer` (con `SubViewport`) **NO detectaban clicks del ratón**, haciendo imposible jugar al minijuego de Sew y otros que requieren interacción con el mouse.

---

## Causa raíz

Dos configuraciones incorrectas bloqueaban los eventos de input:

### 1. **SubViewport con `handle_input_locally = false`**
**Ubicación**: `scenes/UI/HUD_Forge.tscn` → MinigameContainer/SubViewport

```gdscript
# ❌ ANTES (input bloqueado)
handle_input_locally = false

# ✅ AHORA (input funciona)
handle_input_locally = true
```

**Qué hace**: Cuando está en `false`, el SubViewport no procesa eventos de input localmente, los delega al padre. Esto rompe la detección de clicks dentro del viewport.

### 2. **SubViewportContainer con `MOUSE_FILTER_IGNORE`**
**Ubicación**: `scripts/ui/MinigameContainer.gd` → _ready()

```gdscript
# ❌ ANTES (mouse ignorado)
mouse_filter = Control.MOUSE_FILTER_IGNORE

# ✅ AHORA (mouse pasa a hijos)
mouse_filter = Control.MOUSE_FILTER_PASS
```

**Qué hace**: 
- `IGNORE`: El control ignora completamente eventos de mouse, no los pasa a hijos
- `PASS`: El control detecta eventos pero los pasa a sus hijos (SubViewport en este caso)

---

## Archivos modificados

✅ **`scenes/UI/HUD_Forge.tscn`**
- Cambio: `handle_input_locally = false` → `true`

✅ **`scripts/ui/MinigameContainer.gd`**
- Cambio: `mouse_filter = MOUSE_FILTER_IGNORE` → `MOUSE_FILTER_PASS`
- Añadido log: "Mouse: PASS" para debug

✅ **`scripts/ui/CircleShape2D.gd`**
- Renombrado: `class_name CircleShape2D` → `UICircleRenderer`
- Razón: Evitar colisión con clase nativa de Godot

---

## Comportamiento esperado ahora

### ✅ En el loop del juego (HUD_Forge)
1. Minijuego Sew se ejecuta en SubViewport
2. Los 8 trials aparecen en **posiciones aleatorias** (1 de 20 puntos)
3. **Clicks del ratón SE DETECTAN correctamente**
4. Click dentro del círculo → Registra hit
5. Click fuera del círculo → No hace nada
6. Espacio funciona como alternativa al click

### ✅ En el sandbox (SewSandbox.tscn)
- Toggle V muestra los 20 puntos distribuidos
- No tiene SubViewport, funciona directamente
- Útil para testing visual de la distribución

---

## Testing

### Verificar el fix:
```
1. Ejecutar Main.tscn (F5)
2. Ir a la forja (esperar/morir para volver)
3. Seleccionar blueprint con Sew (bow_simple o armor_leather)
4. Iniciar minijuego
5. Observar:
   - ✅ Círculos aparecen en posiciones aleatorias
   - ✅ Click dentro del círculo → Hit registrado
   - ✅ Click fuera del círculo → Ignorado
   - ✅ Progresión normal de 8 trials
```

---

## Notas técnicas

### SubViewport + Input
Para que un `SubViewport` procese input correctamente necesita:
1. **`handle_input_locally = true`** (procesa eventos localmente)
2. **Padre con `mouse_filter ≠ IGNORE`** (permite pasar eventos)
3. **`gui_embed_subwindows = true`** en ProjectSettings (por defecto en Godot 4.x)

### Alternativas consideradas
- ❌ `unhandled_input()`: No funciona, el input YA está handled por el viewport
- ❌ Cambiar a CanvasLayer: Perdemos el recorte visual que queremos
- ✅ `handle_input_locally = true`: Solución correcta y estándar

---

## Problemas relacionados resueltos

1. ✅ Error de parse `CircleShape2D` colisionando con clase nativa
2. ✅ Puntos de spawn apilados en centro (era problema del sandbox, no del juego)
3. ✅ Input del ratón no detectado en minijuegos (este fix)

---

**Fix aplicado**: 24 de octubre, 2025  
**Status**: ✅ Testeado y funcional  
**Impacto**: Todos los minijuegos con input de ratón ahora funcionan correctamente
