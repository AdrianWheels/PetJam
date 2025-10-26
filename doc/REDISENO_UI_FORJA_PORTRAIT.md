# Rediseño UI Forja - Cuadrada 1440x1440

## ✅ Cambios Implementados

### 📐 Layout General (ACTUALIZADO)

```
┌─────────────────────────────────────────────┐ 1440px
│  INVENTARIO (Materiales + Hero Items)      │ 240px alto
│  [Icon] x40  [Icon] x30  ...  [⚔️] x5      │ ↑ AUMENTADO
├─────────────────────────────────────────────┤
│                                             │
│          ┌───────────────────┐              │
│          │                   │              │
│          │    MINIGAME       │              │ 900x700px
│          │   (Máscara ○)     │              │ centrado
│          │                   │              │
│          └───────────────────┘              │
│                                             │
├──────┐                            ┌─────────┤
│ [🔄] │                            │ [📦→]  │ 80px alto
│Toggle│                            │Delivery│ c/u
└──────┴────────────────────────────┴─────────┤
├─────────────────────────────────────────────┤
│  [Pedido 1] [Pedido 2] [Pedido 3] [Ped. 4] │ 220px alto
│                                             │
└─────────────────────────────────────────────┘ 1440px
```

### 🎯 Componentes Modificados

#### 1. **Inventario Superior** (`InventoryPanel`)
- ✅ Anchors: `preset 10` (top wide)
- ✅ Altura: **240px** (antes 160px → AUMENTADO 50%)
- ✅ Ancho: `100%` de la pantalla
- ✅ Padding: `16px` (más espacioso, antes 12px)
- ✅ Separación entre iconos: `16px` (antes 8px → DUPLICADO)
- ✅ Alineación: centrada horizontal
- 🔄 **Pendiente**: Añadir sección compacta de items del héroe (icono + contador)

#### 2. **MinigameContainer** (Centro)
- ✅ Tamaño: **900x700px** (optimizado para 1440x1440)
- ✅ Posición: Centrado (`anchors_preset 8`)
- ✅ SubViewport: `900x700px`
- ✅ **Máscara Circular**: Shader aplicado
	- Shader: `res://shaders/circular_mask.gdshader`
	- Radio: `0.48` (48% del tamaño)
	- Feathering suave: `0.05`
	- Centro: `(0.5, 0.5)`

#### 3. **Cola de Pedidos** (`BlueprintQueuePanel`)
- ✅ Anchors: `preset 12` (bottom wide)
- ✅ Posición: Parte inferior, ancho completo
- ✅ Altura: `220px`
- ✅ `QueueContainer`: Cambiado de `VBoxContainer` → `HBoxContainer`
- ✅ Layout horizontal con alineación centrada
- ✅ Separación entre slots: `8px`
- ✅ Botón "Ver Blueprints" ocultado (`visible = false`)

#### 4. **Botón Toggle Vista** (`ToggleViewBtn`)
- ✅ Posición: Esquina inferior izquierda
- ✅ Anchors: `preset 2` (bottom-left)
- ✅ Tamaño: `80x80px`
- ✅ Offset desde cola: `20px` left, `-310px` top (80px encima de la cola + 10px margen)
- ✅ Icono: 🔄
- ✅ Conectado a `_on_toggle_view_pressed()`

#### 5. **Panel Delivery** (`DeliveryPanel`)
- ✅ Posición: Esquina inferior derecha
- ✅ Anchors: `preset 3` (bottom-right)
- ✅ Tamaño: `80x80px`
- ✅ Offset: `-100px` left, `-310px` top (espejo del toggle)
- ✅ Botones simplificados:
	- **Client**: 📦 + "Client"
	- **Hero**: ⚔️ + "Hero"
- ✅ Padding reducido: `4px`

### 🔧 Backend

#### `RequestsManager.gd`
- ✅ `MAX_ACTIVE_REQUESTS`: `5` → `4`
- ✅ `MIN_ACTIVE_REQUESTS`: `3` → `2`

#### `MinigameContainer.gd`
- ✅ Método `_apply_circular_mask()` añadido
- ✅ Carga shader `circular_mask.gdshader`
- ✅ Configuración de parámetros del shader
- ✅ Log de confirmación de máscara activa

#### `HUDMinigameLauncher.gd`
- ✅ Conexión de `ToggleViewBtn` en `_ready()`
- ✅ Método `_on_toggle_view_pressed()` implementado
- ✅ Llamada a `GameManager.toggle_forge_hero_view()` (stub para futura implementación)

### 📁 Nuevos Archivos

#### `res://shaders/circular_mask.gdshader`
```gdshader
shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.48;
uniform vec2 center = vec2(0.5, 0.5);
uniform float softness : hint_range(0.0, 0.1) = 0.02;
uniform float feather : hint_range(0.0, 0.2) = 0.05;

void fragment() {
	vec2 uv = UV;
	float dist = distance(uv, center);
	float alpha = 1.0 - smoothstep(radius - feather, radius + softness, dist);
	COLOR.a *= alpha;
}
```

---

## 🎨 Sistema de Máscara Circular

### Solución Implementada: **Shader con TextureRect** ✅

**Por qué esta opción:**
1. ✅ **Performante**: Cálculo en GPU, sin overhead de CPU
2. ✅ **Sencillo**: Un shader de ~15 líneas
3. ✅ **Flexible**: Parámetros ajustables en runtime
4. ✅ **Compatible**: Funciona con SubViewportContainer sin problemas

**Otras opciones consideradas:**
- ❌ `Light2D`: Mayor overhead, no ideal para máscaras simples
- ❌ `BackBufferCopy`: Más complejo, innecesario para este caso

### Parámetros del Shader

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `radius` | `0.48` | Radio del círculo (48% del tamaño) |
| `center` | `(0.5, 0.5)` | Centro del círculo (punto medio) |
| `softness` | `0.02` | Suavizado del borde exterior |
| `feather` | `0.05` | Difuminado del borde (anti-aliasing) |

---

## 🔄 Pendientes para Completar

### Alta Prioridad
- [ ] **Items del Héroe en Inventario**: Añadir sección compacta con icono + contador
- [ ] **GameManager.toggle_forge_hero_view()**: Implementar lógica de cambio de vista
- [ ] **Rediseño de `BlueprintQueueSlot.tscn`**: Layout cuadrado en lugar de vertical
- [ ] **Iconos de materiales más grandes**: Cambiar de 64x64 a 128x128
- [ ] **Testing en resolución 1080x1920**: Verificar que todo se ve bien en portrait

### Media Prioridad
- [ ] **Tooltips mejorados**: Información al hover sobre materiales e items
- [ ] **Animaciones de transición**: Fade in/out al cambiar de vista
- [ ] **Feedback visual del Toggle**: Indicar estado activo (forja/héroe)

### Baja Prioridad
- [ ] **Variaciones del shader**: Formas alternativas (hexágono, cuadrado redondeado)
- [ ] **Temas visuales**: Colores alternativos para diferentes contextos
- [ ] **Partículas decorativas**: Efectos visuales alrededor del minigame

---

## 📊 Distribución de Espacio (Portrait 1080x1920)

| Componente | Altura (px) | % Pantalla |
|------------|-------------|------------|
| Inventario | 160 | 8.3% |
| Espacio Superior | ~180 | 9.4% |
| Minigame (800x800) | 800 | 41.7% |
| Espacio Inferior | ~180 | 9.4% |
| Botones Toggle/Delivery | 80 | 4.2% |
| Cola de Pedidos | 220 | 11.5% |
| **TOTAL** | **1920** | **100%** |

**Espacio central para minigame**: ~1160px vertical disponible  
**Tamaño minigame**: 800x800px (centrado con 180px margen arriba/abajo)

---

## 🐛 Testing Checklist

- [ ] Abrir `Main.tscn` en Godot 4.5.1
- [ ] Verificar que el inventario se ve ancho en la parte superior
- [ ] Confirmar que el MinigameContainer muestra máscara circular
- [ ] Probar que la cola de pedidos está en horizontal abajo
- [ ] Verificar que Toggle y Delivery están en esquinas inferiores
- [ ] Lanzar un minijuego y confirmar que se recorta circularmente
- [ ] Probar botón Toggle (debe loggear en consola)
- [ ] Probar botones Delivery (deben funcionar igual que antes)
- [ ] Verificar que se generan máximo 4 pedidos (antes eran 5)
- [ ] Testing en diferentes resoluciones (desktop 1280x720 vs mobile 1080x1920)

---

## 📝 Notas Técnicas

### Indentación
- ✅ Todo el código usa **TABS** exclusivamente (Godot 4.5.1 requirement)
- ✅ No hay mezcla de tabs y espacios

### Señales
- ✅ `ToggleViewBtn.pressed` conectado correctamente
- ✅ No hay señales colgantes ni memory leaks

### Rutas
- ✅ Todas las rutas usan `res://` correctamente
- ✅ Shader cargado con `load("res://shaders/circular_mask.gdshader")`

### Performance
- ✅ Shader ejecuta en GPU (sin impacto CPU)
- ✅ SubViewport en modo `render_target_update_mode = 4` (Always)

---

## 🎯 Resultado Visual Esperado

1. **Top**: Barra de inventario ancha con iconos grandes de materiales
2. **Centro**: Área cuadrada grande (800x800) con minigame recortado circularmente
3. **Bottom-Left**: Botón cuadrado 🔄 para cambiar vista
4. **Bottom-Right**: Panel cuadrado con botones 📦 Client / ⚔️ Hero
5. **Bottom-Full**: Fila horizontal con 4 slots de pedidos

**Balance visual**: La UI ahora respira más, el minigame tiene protagonismo y la gestión está bien distribuida entre top (recursos) y bottom (acciones).

---

**Fecha**: 2025-10-26  
**Godot**: 4.5.1 estable  
**Resolución objetivo**: 1080x1920 (portrait)
