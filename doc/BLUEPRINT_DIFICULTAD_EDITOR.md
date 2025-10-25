# Configuración de Dificultad en Blueprints — Guía de Uso

## 🎯 Problema resuelto

Antes, los parámetros de dificultad estaban en un Dictionary `parameters` que **no se podía editar cómodamente** desde el Inspector de Godot. Ahora cada minijuego tiene su propia clase de configuración con propiedades `@export` individuales.

---

## 📦 Nuevas clases de configuración

### `ForgeTrialConfig` (Forja/Temperatura)
```gdscript
@export_range(30.0, 150.0, 5.0) var temp_window_base: float = 90.0
@export_range(0.0, 1.0, 0.05) var hardness: float = 0.3
@export_range(0.0, 1.0, 0.05) var precision: float = 0.5
@export var label: String = "Forja"
```

### `HammerTrialConfig` (Martillo/Timing)
```gdscript
@export_range(3, 10, 1) var notes: int = 5
@export_range(60, 180, 5) var tempo_bpm: int = 85
@export_range(0.0, 1.0, 0.05) var precision: float = 0.4
@export_range(0.0, 1.0, 0.05) var weight: float = 0.5
@export var label: String = "Martillo"
```

### `SewTrialConfig` (Coser/OSU)
```gdscript
@export_range(4, 12, 1) var events: int = 8
@export_range(0.0, 1.0, 0.05) var speed: float = 0.5
@export_range(0.0, 1.0, 0.05) var precision: float = 0.5
@export_range(0.0, 1.0, 0.05) var evasion_threshold: float = 0.7
@export var label: String = "Coser"
```

### `QuenchTrialConfig` (Temple/Agua)
```gdscript
@export_range(0.5, 3.0, 0.1) var optimal_time: float = 1.5
@export_range(0.1, 1.0, 0.05) var time_window: float = 0.3
@export_range(1.0, 2.0, 0.1) var catalyst_bonus: float = 1.2
@export var label: String = "Temple"
@export var element: String = ""
```

---

## 🔧 Cómo editar la dificultad desde el Editor

### Opción A: Conversión automática con herramienta visual (recomendado)

1. **En Godot**, abre la escena `res://scenes/sandboxes/BlueprintConverter.tscn`
2. Presiona **F6** (Run Current Scene) o el botón ▶
3. Haz clic en **"▶ Convertir Blueprints"**
4. Espera a que termine (verás el progreso en tiempo real)
5. Cierra la ventana
6. Abre cualquier blueprint `.tres` en el Inspector
7. Navega a `Trial Sequence → [n] → Config`
8. **Ahora verás campos individuales editables con sliders**

### Opción B: Conversión con EditorScript (desde Godot)

1. **En Godot**, abre el script `res://addons/editor_scripts/convert_blueprints.gd`
2. En el menú: **File → Run** (o `Ctrl+Shift+X`)
3. Verifica la consola Output — todos los blueprints se actualizan automáticamente
4. Abre cualquier blueprint `.tres` en el Inspector
5. Navega a `Trial Sequence → [n] → Config`
6. **Ahora verás campos individuales editables con sliders**

> **Nota**: Los EditorScripts solo se pueden ejecutar desde el editor de Godot, no desde VS Code.

### Opción C: Conversión manual de un blueprint (individual)

1. **En Godot**, abre `sword_basic.tres` (o cualquier blueprint)
2. En el Inspector, busca el SubResource `temp_config` (ID 1)
3. Cambia su **Script** de `TrialConfig.gd` a `ForgeTrialConfig.gd`
4. Aparecerán los campos individuales
5. Ajusta `temp_window_base`, `hardness`, `precision`, etc.
6. Guarda (`Ctrl+S`)

> **Nota**: Los blueprints `.tres` se editan en Godot, no en VS Code.

---

## 📊 Interpretación de parámetros

### Forja (Temperatura)
- **`temp_window_base`**: Ancho de la zona verde (°C). **↓ = más difícil**
- **`hardness`**: Velocidad del cursor. **↑ = más difícil** (0.0-1.0)
- **`precision`**: Penalización por salir de zona. **↑ = más difícil** (0.0-1.0)

### Martillo (Timing)
- **`notes`**: Número de golpes requeridos. **↑ = más largo**
- **`tempo_bpm`**: Velocidad del ritmo. **↑ = más difícil** (60-180)
- **`precision`**: Ventana de acierto. **↓ = más difícil** (0.0-1.0)
- **`weight`**: Inercia del martillo. **↑ = más lento**

### Coser (OSU-like)
- **`events`**: Número de círculos. **↑ = más largo** (4-12)
- **`speed`**: Velocidad de colapso. **↑ = más difícil** (0.0-1.0)
- **`precision`**: Ventana de acierto. **↓ = más difícil**
- **`evasion_threshold`**: Umbral para bonus de Evasión. **↑ = más exigente**

### Temple (Agua)
- **`optimal_time`**: Tiempo ideal de inmersión (segundos)
- **`time_window`**: Ventana de tolerancia (± segundos). **↓ = más difícil**
- **`catalyst_bonus`**: Ampliación por catalizador (1.0-2.0)
- **`element`**: Etiqueta de elemento fijado

---

## 🎮 Ejemplo práctico: crear dificultades

### Espada fácil (principiante)
```gdscript
# ForgeTrialConfig
temp_window_base = 120.0  # Zona amplia
hardness = 0.2            # Cursor lento
precision = 0.3           # Tolerante

# HammerTrialConfig
notes = 3                 # Pocos golpes
tempo_bpm = 70            # Ritmo relajado
precision = 0.5           # Ventana amplia
```

### Hacha difícil (veterano)
```gdscript
# ForgeTrialConfig
temp_window_base = 60.0   # Zona estrecha
hardness = 0.6            # Cursor rápido
precision = 0.8           # Penalización alta

# HammerTrialConfig
notes = 8                 # Muchos golpes
tempo_bpm = 140           # Ritmo frenético
precision = 0.2           # Ventana muy pequeña
```

---

## ⚙️ Integración con CraftingManager

El sistema actualizado:
1. `CraftingManager._resolve_trial_config()` llama a `config.prepare()`
2. `prepare()` sincroniza las propiedades `@export` al Dictionary `parameters`
3. Los minijuegos siguen leyendo de `parameters` (retrocompatible)

**No necesitas cambiar código de minijuegos** — todo es transparente.

---

## ✅ Checklist de validación

- [ ] El blueprint tiene `ForgeTrialConfig`/`HammerTrialConfig`/etc. asignado
- [ ] Los campos individuales son visibles en el Inspector
- [ ] Al ajustar sliders, los valores se guardan correctamente
- [ ] Los minijuegos reciben los parámetros correctos en runtime
- [ ] No hay errores en la consola al cargar blueprints

---

## 🚨 Troubleshooting

### "No puedo ejecutar el script desde VS Code"
- ✅ **Correcto** — los scripts `.gd` se ejecutan en Godot, no en VS Code
- Usa la herramienta visual: `scenes/sandboxes/BlueprintConverter.tscn`
- O ejecuta el EditorScript desde Godot: File → Run

### "No veo los campos editables en el Inspector"
- Verifica que el script sea `ForgeTrialConfig.gd` (no `TrialConfig.gd`)
- Recarga el recurso (`Ctrl+R` en el Inspector de Godot)
- Ejecuta la herramienta de conversión automática

### "Los cambios no se aplican en el juego"
- Asegúrate de guardar el blueprint (`Ctrl+S` en Godot)
- Reinicia el juego para recargar recursos
- Verifica que `CraftingManager` llame a `prepare()`

### "Error: Class not found (ForgeTrialConfig, etc.)"
- Asegúrate de que Godot ha registrado las nuevas clases
- **Project → Reload Current Project** en Godot
- Verifica que los archivos `.gd` no tengan errores de sintaxis

---

## 📁 Archivos modificados

- **Nuevos**: 
  - `scripts/data/ForgeTrialConfig.gd`
  - `scripts/data/HammerTrialConfig.gd`
  - `scripts/data/SewTrialConfig.gd`
  - `scripts/data/QuenchTrialConfig.gd`
  - `scripts/tools/BlueprintConverter.gd` ⭐ Herramienta visual
  - `scenes/sandboxes/BlueprintConverter.tscn` ⭐ Scene ejecutable
  - `addons/editor_scripts/convert_blueprints.gd` (alternativa EditorScript)
  
- **Editados**:
  - `scripts/data/TrialResource.gd` (método `get_prepared_config()`)
  - `scripts/autoload/CraftingManager.gd` (llamada a `prepare()`)
  - `data/blueprints/sword_basic.tres` (ejemplo convertido)

---

## 🎯 Próximos pasos

1. **Ejecuta el script de conversión** para actualizar todos los blueprints
2. **Ajusta dificultades** desde el Inspector según el balance deseado
3. **Prueba en juego** cada blueprint convertido
4. **Itera** ajustando parámetros basándote en telemetría

¡Ahora puedes balancear el juego visualmente sin tocar código! 🎉
