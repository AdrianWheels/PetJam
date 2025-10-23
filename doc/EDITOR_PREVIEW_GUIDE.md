# Cómo editar UI generada dinámicamente en Godot - Guía

## Problema
Tu UI se genera 100% por código en runtime, lo que hace imposible ver y editar cómo se ve en el editor.

## Solución 1: `@tool` (Scripts que corren en el editor)

### ¿Qué es @tool?
El decorador `@tool` hace que un script GDScript se ejecute dentro del editor de Godot, no solo en runtime.

### Cómo usarlo:

```gdscript
@tool  # <-- Esta línea mágica
extends Panel

@export var preview_blueprint_id: String = "" : set = _set_preview_blueprint
@export var preview_materials: Dictionary = {}

func _set_preview_blueprint(value: String) -> void:
    preview_blueprint_id = value
    if Engine.is_editor_hint():  # Detecta si estamos en el editor
        _update_preview()

func _update_preview() -> void:
    # Esta función actualiza la UI en el editor
    set_blueprint_name(preview_blueprint_id)
    set_materials(preview_materials)
```

### Ventajas:
✅ Puedes cambiar `@export` variables en el Inspector y ver cambios en tiempo real
✅ Previsualización instantánea sin ejecutar el juego
✅ Facilita el diseño de layouts complejos

### Desventajas:
⚠️ Debes usar `Engine.is_editor_hint()` para separar lógica de editor vs runtime
⚠️ Errores en el script pueden crashear el editor
⚠️ Autoloads no están disponibles en el editor (hay que manejar el caso null)

---

## Solución 2: Scene "Preview" dedicada

Crea una escena `res://scenes/UI/BlueprintQueueSlot_Preview.tscn` que contenga:
- El layout completo con nodos hijos ya creados
- Placeholders visuales (ej: TextureRect con icono temporal, Labels con texto "Preview")
- Esta escena NO se usa en runtime, solo para diseñar

Luego, en runtime, tu código copia la estructura:

```gdscript
func create_slot() -> Panel:
    var slot = Panel.new()
    # Replicar estructura de BlueprintQueueSlot_Preview.tscn
    var vbox = VBoxContainer.new()
    slot.add_child(vbox)
    
    var icon = TextureRect.new()
    vbox.add_child(icon)
    # etc...
    
    return slot
```

---

## Solución 3: Híbrido (Recomendado para tu proyecto)

### Paso 1: Diseña el template en el editor
`BlueprintQueueSlot.tscn` tiene la estructura visual completa:
```
Panel (BlueprintQueueSlot)
└─ VBoxContainer
   ├─ TextureRect (Icon)
   ├─ Label (NameLabel)
   └─ VBoxContainer (MaterialsContainer)
```

### Paso 2: Script solo manipula, no crea
```gdscript
extends Panel

@onready var icon_rect: TextureRect = $VBoxContainer/Icon
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var materials_container: VBoxContainer = $VBoxContainer/MaterialsContainer

func set_blueprint(blueprint: BlueprintResource) -> void:
    name_label.text = blueprint.display_name  # Solo cambia propiedades
    icon_rect.texture = blueprint.icon        # No crea nodos nuevos
```

### Paso 3: Usa `@tool` para preview en editor
```gdscript
@tool
extends Panel

@export var preview_mode: bool = false
@export_file("*.tres") var preview_blueprint_path: String = ""

func _process(delta: float) -> void:
    if Engine.is_editor_hint() and preview_mode:
        if preview_blueprint_path != "":
            var bp = load(preview_blueprint_path) as BlueprintResource
            if bp:
                set_blueprint(bp)
```

Ahora en el Inspector puedes:
1. Activar `preview_mode`
2. Seleccionar `res://data/blueprints/sword_basic.tres`
3. Ver en tiempo real cómo se ve el slot con ese blueprint

---

## Para tu proyecto PetJam - Recomendación inmediata

### Opción A: Mantener código actual + agregar @tool para preview
He creado `BlueprintQueueSlot_TOOL_VERSION.gd` que:
- Tiene `@export var preview_blueprint_id: String`
- Permite ver en el Inspector cómo se vería un blueprint
- No rompe la lógica de runtime existente

**Cómo usar:**
1. Reemplaza el script actual con la versión `@tool`
2. En el Inspector del nodo `BlueprintQueueSlot`, cambia `preview_blueprint_id` a "sword_basic"
3. Verás el blueprint renderizado en el editor

### Opción B: Crear template .tscn editable (más trabajo pero mejor UX)

Actualmente `MaterialIcon` ya usa este patrón - puedes abrir `MaterialIcon.tscn` y editarlo visualmente.

Podrías hacer lo mismo con `BlueprintQueueSlot.tscn`:
1. Abrirlo en el editor
2. Agregar Labels, TextureRects, etc. manualmente
3. Guardar la estructura
4. El script solo modifica propiedades (text, texture, visible, etc.)

---

## Ejemplo práctico para MaterialIcon

Si miras `MaterialIcon.tscn`, probablemente tenga estructura como:
```
TextureRect (MaterialIcon)
└─ Label (opcional)
```

El script `MaterialIcon.gd` solo hace:
```gdscript
@onready var texture_rect: TextureRect = self  # o $TextureRect si es hijo

func set_material(mat_name: String) -> void:
    texture = load("res://art/placeholders/forge/material_%s.png" % mat_name)
```

**No** está haciendo `TextureRect.new()` en runtime, por eso es editable.

---

## Checklist de decisión

**Usa @tool si:**
- [x] Necesitas previsualizar datos de Resources (.tres)
- [x] Tu UI depende de configuración externa (blueprints, bases de datos)
- [x] Quieres iterar rápido sin ejecutar el juego

**Usa templates .tscn editables si:**
- [x] Tu UI tiene layout complejo (margins, anchors, tamaños)
- [x] Diseñadores sin programación deben editar
- [x] Quieres theme/estilo visual consistente

**Usa generación 100% código si:**
- [x] UI es totalmente dinámica (ej: inventario de 100 items)
- [x] No necesitas previsualización
- [x] Layout es simple (listas verticales/horizontales)

---

## Para tu caso específico (BlueprintQueue)

**Mi recomendación:**
1. ✅ Usa `BlueprintQueueSlot.tscn` como template (ya lo tienes)
2. ✅ Agrega `@tool` + `@export var preview_blueprint_id`
3. ✅ Mantén el código de instanciación en `HUDMinigameLauncher`
4. ✅ Ahora puedes abrir `BlueprintQueueSlot.tscn`, cambiar `preview_blueprint_id` en el Inspector, y ver cómo se ve

**Lo que NO hagas:**
- ❌ No intentes previsualizar la cola completa (3 slots) en el editor - eso se genera en runtime
- ❌ No elimines la instanciación dinámica - es correcta para tu caso

**El truco es:**
- Diseñar UN slot en el editor → `BlueprintQueueSlot.tscn`
- Instanciar 3 copias en runtime → `HUDMinigameLauncher.update_queue_display()`

¿Tiene sentido? ¿Quieres que implemente la versión `@tool` en el archivo principal?
