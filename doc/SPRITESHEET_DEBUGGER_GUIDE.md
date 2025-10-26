# 🎬 Guía de Uso: Spritesheet Frame Debugger

## Ubicación
**Escena:** `res://scenes/sandboxes/SpritesheetDebugger.tscn`  
**Script:** `res://scripts/tools/SpritesheetFrameDebugger.gd`

---

## 🎯 Propósito

Herramienta para **visualizar y seleccionar frames específicos** de un spritesheet, permitiendo identificar frames redundantes, innecesarios o problemáticos antes de optimizar las animaciones.

---

## 🚀 Cómo Usar

### 1. Abrir la Herramienta
- En Godot, abre la escena: `scenes/sandboxes/SpritesheetDebugger.tscn`
- Presiona `F6` o haz clic en "Ejecutar Escena Actual"

### 2. Cargar un Spritesheet
1. **Ingresa la ruta** en el campo "Texture Path":
   ```
   res://art/assets/Spritesheets/Hero/hero_walk_01_12fps.png
   ```
2. **Ajusta "H Frames"** si es necesario (por defecto: 62)
3. Haz clic en **"Load"**

### 3. Reproducir y Analizar
- **Preview superior**: Muestra la animación en tiempo real
- **Grid de frames**: Lista todos los frames con checkboxes
- **FPS Slider**: Ajusta la velocidad de reproducción (1-60 FPS)

### 4. Seleccionar/Deseleccionar Frames
- **Checkbox individual**: Click en cada frame para incluir/excluir
- **Botón "Select All"** o tecla `A`: Selecciona todos
- **Botón "Deselect All"** o tecla `D`: Deselecciona todos
- **Tecla `R`**: Reset (selecciona todos)

### 5. Exportar Selección
- Haz clic en **"Export Selected"**
- Se copiará al clipboard la lista de frames seleccionados
- Formato: `Selected frames (X/Y): [0, 1, 2, ..., 60]`

---

## ⌨️ Atajos de Teclado

| Tecla | Acción |
|-------|--------|
| `SPACE` | Pausar/Reanudar animación |
| `A` | Seleccionar todos los frames |
| `D` | Deseleccionar todos los frames |
| `R` | Reset (volver a seleccionar todos) |

---

## 📋 Workflow Recomendado

### Para cada animación:

1. **Cargar el spritesheet** de 12fps (balance calidad/tamaño)
2. **Reproducir y observar** la animación completa
3. **Identificar frames problemáticos**:
   - Frames duplicados consecutivos
   - Frames con el personaje fuera de encuadre
   - Transiciones bruscas
   - Frames innecesarios para el loop
4. **Deseleccionar frames** que no aportan
5. **Exportar la lista** de frames seleccionados
6. **Documentar** en lista para aplicar optimización

---

## 📊 Ejemplo de Uso

### Caso: `hero_walk_01_12fps.png`
- **Total frames**: 63
- **Problema detectado**: Frames 0-10 muestran al héroe entrando en escena
- **Solución**: Deseleccionar frames 0-10, mantener solo 11-62
- **Resultado**: Animación de 52 frames, loop perfecto, ~17% más ligera

### Lista de optimización sugerida:
```
hero_walk_01: Frames 11-62 (52 frames)
hero_attack_01: Frames 5-57 (53 frames)
hero_death: Frames 0-63 (mantener todos)
grunt_attack: Frames 8-58 (51 frames)
...
```

---

## 🎨 Spritesheets Disponibles

### Hero (usar 12fps)
- `hero_walk_01_12fps.png` → 63 frames
- `hero_walk_02_12fps.png` → 62 frames
- `hero_walk_03_12fps.png` → 62 frames
- `hero_attack_01_12fps.png` → 62 frames
- `hero_attack_02_12fps.png` → 62 frames
- `hero_death_12fps.png` → 64 frames

### Enemies (usar 12fps)
- `grunt_attack_12fps.png` → 62 frames
- `grunt_death_12fps.png` → 64 frames
- `tank_attack_12fps.png` → 62 frames
- `tank_death_12fps.png` → 64 frames

---

## 🔧 Aplicar Optimizaciones

Una vez tengas la lista de frames optimizados, podrás:

1. **Método 1: Script PowerShell** (crear nuevo script)
   - Extraer solo los frames seleccionados del video original
   - Regenerar spritesheet optimizado

2. **Método 2: Recortar en código** (más rápido)
   - Actualizar `hframes` en los scripts
   - Ajustar `frame_offset` para saltar frames iniciales

3. **Método 3: Edición manual** (control total)
   - Usar ImageMagick para recortar el spritesheet
   - Eliminar frames no deseados del PNG

---

## 💡 Tips

- **Loop perfecto**: Asegúrate de que el último frame seleccionado conecte bien con el primero
- **FPS bajo para análisis**: Usa 4-6 FPS para ver cada frame en detalle
- **Frames impares**: Si tienes 63 frames pero el último es idéntico al primero, elimina el último
- **Tamaño objetivo**: Apunta a 40-50 frames por animación para balance

---

## 📝 Próximo Paso

**Genera tu lista de optimización** y comunícala para aplicar los cambios. Formato sugerido:

```
HERO:
- walk_01: frames 10-62 (53f)
- attack_01: frames 5-60 (56f)
- death: frames 0-60 (61f, pausa en 60)

GRUNT:
- attack: frames 8-58 (51f)
- death: frames 0-55 (56f)

TANK:
- attack: frames 12-60 (49f)
- death: frames 0-62 (63f)
```
