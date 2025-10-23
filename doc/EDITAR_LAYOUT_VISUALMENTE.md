# Guía: Editar UI visualmente en Godot (Layout, posiciones, tamaños)

## Tu caso: Quieres editar DISEÑO, no datos

**Lo que NO necesitas:**
- ❌ @tool (eso es para previsualizar DATOS dinámicos como blueprints)
- ❌ Scripts complejos
- ❌ Ejecutar el juego para ver cambios

**Lo que SÍ necesitas:**
- ✅ Abrir las escenas .tscn directamente en el editor
- ✅ Usar las herramientas visuales de Godot (arrastrar, resize, anchors)
- ✅ Placeholders con contenido fake para diseñar

---

## Cómo editar layout visualmente - Paso a paso

### 1. Para editar el HUD (paneles, botones, inventario)

**Archivo:** `res://scenes/UI/HUD.tscn`

**Pasos:**
1. En Godot, ve a FileSystem (panel izquierdo abajo)
2. Navega a `scenes/UI/HUD.tscn`
3. **Doble clic** en `HUD.tscn`
4. Se abre el editor 2D con toda la UI visible

**Ahora puedes:**
- ✅ Seleccionar `MinigamesPanel` y arrastrarlo a otra posición
- ✅ Cambiar tamaño de `BlueprintQueuePanel` con los handles en las esquinas
- ✅ Editar anchors/margins en el Inspector (panel derecho)
- ✅ Cambiar colores, fuentes, espaciados de `VBoxContainer`

**Ctrl+S** para guardar - los cambios se aplican instantáneamente al ejecutar el juego.

---

### 2. Para editar un Blueprint Slot (tamaño, espaciado de materiales)

**Archivo:** `res://scenes/UI/BlueprintQueueSlot.tscn`

**Pasos:**
1. Abre `scenes/UI/BlueprintQueueSlot.tscn` en el editor
2. Selecciona `VBoxContainer` → Inspector → `Theme Overrides` → `Constants` → `Separation: 8`
3. Selecciona `Icon` (TextureRect) → Inspector → `custom_minimum_size: (64, 64)`
4. Arrastra nodos para reordenar (Icon arriba o abajo de NameLabel)

**Truco de placeholders:**
```
Icon (TextureRect)
├─ texture: res://art/placeholders/forge/blueprint_sword.png  ← Imagen placeholder
└─ custom_minimum_size: (48, 48)

NameLabel (Label)
└─ text: "Espada de Hierro"  ← Texto placeholder
```

Ahora ves exactamente cómo se verá en runtime.

---

### 3. Para editar posición del héroe o salas

**Archivos:**
- `res://scenes/Hero.tscn` - Posición inicial del héroe
- `res://scenes/Room.tscn` - Tamaño de una sala
- `res://scenes/Corridor.tscn` - Layout del corredor completo

**Ejemplo: Mover héroe más a la izquierda**

1. Abre `scenes/Hero.tscn`
2. Selecciona el nodo raíz `Hero` (CharacterBody2D)
3. En la escena 2D, **arrastra el héroe** con el mouse
4. O en el Inspector: `Transform → Position: (100, 200)`
5. Guarda (Ctrl+S)

**Ejemplo: Hacer salas más grandes**

1. Abre `scenes/Room.tscn`
2. Si tiene un `CollisionShape2D`, selecciónalo
3. Arrastra los handles para hacerlo más grande
4. Si tiene un `Sprite2D` o `ColorRect`, ajusta `scale` o `size`

**Ejemplo: Espaciar salas del corredor**

1. Abre `scenes/Corridor.tscn`
2. Si las salas están como hijos (Room1, Room2...), selecciona cada una
3. Cambia `position.x` en el Inspector: `Room1 x=0`, `Room2 x=500`, `Room3 x=1000`

---

## Técnica de Placeholders para diseñar sin datos

### Problema actual:
Tu `BlueprintQueueSlot.tscn` probablemente se ve vacío en el editor porque:
- El script borra contenido en `_ready()`
- Los datos (nombre, icono) se llenan en runtime

### Solución: Placeholder en la escena, limpieza en script

**En BlueprintQueueSlot.tscn (editor visual):**
```
Panel
└─ VBoxContainer
   ├─ Icon (TextureRect)
   │  └─ texture: res://icon.svg  ← PLACEHOLDER para diseñar
   ├─ NameLabel (Label)
   │  └─ text: "Nombre Blueprint"  ← PLACEHOLDER
   └─ MaterialsContainer (VBoxContainer)
      └─ HBoxContainer (placeholder)
         ├─ TextureRect (icono material)
         └─ Label (text: "x5")
```

**En BlueprintQueueSlot.gd (código):**
```gdscript
func set_blueprint(blueprint: BlueprintResource) -> void:
    # Limpia los placeholders del editor
    icon_rect.texture = blueprint.icon  # Reemplaza el placeholder
    name_label.text = blueprint.name
    
    # Limpia MaterialsContainer
    for child in materials_container.get_children():
        child.queue_free()
    
    # Agrega materiales reales
    for mat in blueprint.materials:
        _add_material_row(mat.id, mat.qty)
```

**Resultado:**
- En el **editor** ves el layout con placeholders
- En **runtime** el script reemplaza los placeholders con datos reales

---

## Workflow recomendado para tu proyecto

### Paso 1: Diseña visualmente en el editor (SIN ejecutar)
1. Abre `HUD.tscn`
2. Coloca paneles donde quieras (drag & drop)
3. Ajusta tamaños, márgenes, colores
4. **Agrega placeholders:** labels con texto "PLACEHOLDER", texturas con `icon.svg`

### Paso 2: Guarda la escena
Ctrl+S - ahora tienes un layout visual completo

### Paso 3: El script solo ACTUALIZA contenido, no crea UI
```gdscript
# ❌ MAL - crea UI desde cero
func _ready():
    var label = Label.new()
    label.text = "Hola"
    add_child(label)

# ✅ BIEN - actualiza UI existente
@onready var label: Label = $MyLabel  # Ya existe en .tscn

func _ready():
    label.text = "Hola"  # Solo cambia el texto
```

### Paso 4: Ejecuta el juego - el script rellena con datos reales
Los placeholders se reemplazan automáticamente por datos de blueprints, inventario, etc.

---

## Atajos de teclado útiles en el editor

- **F** - Frame selected (centra vista en nodo seleccionado)
- **Ctrl + Arrastrar** - Mover en incrementos (grid snapping)
- **Alt + Arrastrar** - Duplicar nodo
- **W** - Modo mover (translate)
- **E** - Modo rotar
- **S** - Modo escalar

---

## Checklist de tu caso específico

**Para editar el HUD:**
- [ ] Abrir `scenes/UI/HUD.tscn`
- [ ] Arrastrar `BlueprintQueuePanel` a la posición deseada
- [ ] Ajustar `custom_minimum_size` en Inspector
- [ ] Agregar `text: "PLACEHOLDER"` a Labels para ver layout
- [ ] Guardar (Ctrl+S)

**Para editar BlueprintQueueSlot:**
- [ ] Abrir `scenes/UI/BlueprintQueueSlot.tscn`
- [ ] Agregar placeholder: `Icon.texture = icon.svg`
- [ ] Agregar placeholder: `NameLabel.text = "Espada Básica"`
- [ ] Crear un `HBoxContainer` hijo de `MaterialsContainer` con:
  - [ ] TextureRect (20x20) con `icon.svg`
  - [ ] Label con `text: "x3"`
- [ ] Guardar - ahora ves cómo se ve un slot completo

**Para editar posición del héroe:**
- [ ] Abrir `scenes/Hero.tscn`
- [ ] Seleccionar nodo raíz
- [ ] Arrastrar en la vista 2D O cambiar `position` en Inspector
- [ ] Guardar

**Para editar salas/corredor:**
- [ ] Abrir `scenes/Room.tscn` o `Corridor.tscn`
- [ ] Ajustar posiciones/tamaños con las herramientas 2D
- [ ] Guardar

---

## Resumen: @tool NO es lo que necesitas

**@tool es para:**
- Previsualizar DATOS externos (blueprints, bases de datos)
- Ejecutar lógica custom en el editor
- Generar contenido proceduralmente en edit-time

**Tú necesitas:**
- Editar LAYOUT (posiciones, tamaños, colores)
- Simplemente abre `.tscn` en el editor y usa las herramientas visuales
- Agrega placeholders para ver contenido mientras diseñas

**La solución es mucho más simple de lo que pensabas: doble clic en `.tscn` y arrastra cosas. Eso es todo.**
