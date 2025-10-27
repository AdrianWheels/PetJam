# Resumen de cambios: Transparencia de spritesheets e iconos UI

**Fecha**: 27 de octubre de 2025

## Problema: Personajes transparentes en spritesheets

### Causa identificada
Los archivos `.import` de los spritesheets tenían configuración incorrecta:
- `detect_3d/compress_to=1` → Causaba compresión automática no deseada
- `process/fix_alpha_border=true` → Modificaba los bordes alpha de forma incorrecta

### Solución aplicada
1. ✅ Corregidos **1454 archivos** `.png.import` en `art/assets/Spritesheets/`
2. ✅ Cambios aplicados:
   - `detect_3d/compress_to=1` → `detect_3d/compress_to=0`
   - `process/fix_alpha_border=true` → `process/fix_alpha_border=false`

### Script creado
- **Archivo**: `fix_spritesheet_imports.ps1`
- **Función**: Corrige automáticamente todos los archivos `.import` de spritesheets
- **Uso**: `.\fix_spritesheet_imports.ps1` desde la raíz del proyecto

### ⚠️ IMPORTANTE
**Debes reabrir Godot** para que los cambios surtan efecto. Godot reimportará automáticamente las texturas con la nueva configuración.

---

## Nuevos iconos en UI de forja

### Iconos agregados
Se han integrado 4 botones de iconos en `HUD_Forge.tscn`:

1. **🔔 Bell Icon** (`bell_icon.png`)
   - **Función**: Enviar pedido al cliente
   - **Tooltip**: "Enviar pedido al cliente"
   - **Acción**: Abre `DeliveryPanel` en modo "client"

2. **📋 Blueprints Icon** (`blueprints_icon.png`)
   - **Función**: Abrir librería de blueprints
   - **Tooltip**: "Ver librería de blueprints"
   - **Acción**: Abre `BlueprintLibraryPanel`

3. **🗄️ Closet Icon** (`closet_icon.png`)
   - **Función**: Guardar en inventario del héroe
   - **Tooltip**: "Guardar en inventario del héroe"
   - **Acción**: Abre `DeliveryPanel` en modo "hero"

4. **⚔️ Dungeon Icon** (`dungeon_icon.png`)
   - **Función**: Ir a la mazmorra
   - **Tooltip**: "Ir a la mazmorra"
   - **Acción**: Cambia el área a "dungeon"

### Características técnicas
- **Tamaño de iconos**: 80x80 píxeles (desde 2048x2048 originales)
- **Ubicación**: Esquina superior derecha de la pantalla
- **Separación**: 12px entre botones
- **Stretch mode**: `5` (Keep Aspect Centered) para mantener proporción
- **Tooltips**: Cada botón tiene descripción al pasar el cursor

### Layout
```
┌─────────────────────────────────────────────┐ 1440px
│  INVENTARIO (Materiales + Hero Items)      │ 240px alto
│  [Icon] x40  [Icon] x30  ...  [⚔️] x5      │
├─────────────────────────────────────────────┤
│                                             │
│          ┌───────────────────┐              │
│          │                   │              │
│          │    MINIGAME       │              │ 900x700px
│          │   (Máscara ○)     │              │ centrado
│          │                   │              │
│          └───────────────────┘              │
│                                             │
├──────┬──────┐                    ┌─────────┤
│ [⚔️] │ [] │                    │ [�][�🗄️]│ 80px alto
│Dungeon│Bluep│                    │ Cliente │ c/u
└──────┴──────┴────────────────────┴─────────┤
├─────────────────────────────────────────────┤
│  [Pedido 1] [Pedido 2] [Pedido 3] [Ped. 4] │ 220px alto
│                                             │
└─────────────────────────────────────────────┘ 1440px
```

---

## Toggle con clic derecho DESACTIVADO

### Cambio en `scripts/main.gd`
Se ha **comentado** el código que permitía cambiar entre forja/dungeon con clic derecho:

```gdscript
# DESACTIVADO: Toggle de área con clic derecho
# Ahora se usan los botones de UI (bell, blueprints, closet, dungeon icons)
#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
#	...
```

### Razón
- Los botones de iconos ahora proporcionan acceso directo a cada funcionalidad
- Interfaz más clara y explícita
- Evita cambios accidentales de área

---

## Archivos modificados

### Escenas
- ✅ `scenes/UI/HUD_Forge.tscn`
  - Agregados 4 TextureButtons con iconos
  - Panel `IconButtonsPanel` en esquina superior derecha

### Scripts
- ✅ `scripts/core/HUDMinigameLauncher.gd`
  - Agregadas conexiones para los 4 botones de iconos
  - Agregadas funciones callback:
    - `_on_bell_button_pressed()`
    - `_on_blueprints_button_pressed()`
    - `_on_closet_button_pressed()`
    - `_on_dungeon_button_pressed()`

- ✅ `scripts/main.gd`
  - Desactivado toggle de clic derecho

### Imports corregidos
- ✅ `art/assets/Spritesheets/Hero/hero_walk_01_12fps.png.import`
- ✅ `art/assets/Spritesheets/Enemies/grunt_attack_12fps.png.import`
- ✅ **1454 archivos más** en `art/assets/Spritesheets/`

### Scripts de utilidad
- ✅ `fix_spritesheet_imports.ps1` (nuevo)

---

## Testing requerido

### 1. Transparencia de personajes
- [ ] Abrir Godot (se reimportarán las texturas automáticamente)
- [ ] Verificar que el héroe se ve con colores sólidos en `Hero.tscn`
- [ ] Verificar que los enemigos se ven correctamente en `Enemy.tscn`
- [ ] Probar animaciones de walk, attack, death

### 2. Iconos UI
- [ ] Ejecutar el juego y entrar en la forja
- [ ] Verificar que los 4 iconos se ven en la esquina superior derecha
- [ ] Probar cada botón:
  - [ ] Bell → Abre panel de entrega al cliente
  - [ ] Blueprints → Abre librería de blueprints
  - [ ] Closet → Abre panel de guardar en héroe
  - [ ] Dungeon → Cambia a vista de dungeon
- [ ] Verificar que los tooltips aparecen al pasar el cursor
- [ ] Verificar que el tamaño es apropiado (80x80px)

### 3. Toggle desactivado
- [ ] Verificar que el clic derecho **NO** cambia entre forja/dungeon
- [ ] Confirmar que solo los botones de UI cambian de área

---

## Notas técnicas

### Stretch mode en TextureButton
- **Mode 0** (Scale): Escala sin mantener proporción → Distorsión
- **Mode 5** (Keep Aspect Centered): Escala manteniendo proporción → ✅ Usado

### Importación de texturas en Godot 4.5
- `compress/mode=0`: Sin compresión (mejor para sprites con transparencia)
- `detect_3d/compress_to=0`: No detectar 3D ni comprimir automáticamente
- `process/fix_alpha_border=false`: No modificar bordes alpha (evita halos)

### Resolución de iconos
- **Originales**: 2048x2048px (UI de alta resolución)
- **En juego**: 80x80px (apropiado para 1280x720 y 1080x1350)
- **Beneficio**: Los iconos se ven nítidos incluso en pantallas de alta densidad

---

## Próximos pasos sugeridos

1. **Animaciones de hover**: Agregar efecto visual al pasar el cursor sobre los botones
2. **Feedback de clic**: Agregar efecto de presión o sonido al hacer clic
3. **Deshabilitación condicional**: Deshabilitar botones cuando no apliquen (ej: Bell sin ítem craftado)
4. **Badge de notificación**: Agregar indicador numérico en Bell cuando hay pedidos pendientes
5. **Teclado shortcuts**: Agregar atajos de teclado (ej: B para blueprints, D para dungeon)

---

## Referencias
- **Spritesheets**: `art/assets/Spritesheets/`
- **Iconos UI**: `art/assets/Imagenes/Menu/`
- **HUD principal**: `scenes/UI/HUD_Forge.tscn`
- **Script HUD**: `scripts/core/HUDMinigameLauncher.gd`
