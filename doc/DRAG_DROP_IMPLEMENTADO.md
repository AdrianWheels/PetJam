# Sistema Drag & Drop Implementado

**Fecha**: 2025-01-XX  
**Estado**: ✅ Completado

## Objetivo
Implementar drag & drop nativo de Godot para equipar items desde el inventario de dungeon a los slots de equipamiento.

## Arquitectura

### Componentes Nuevos

#### 1. `DraggableItemSlot.gd`
**Ruta**: `res://scripts/ui/DraggableItemSlot.gd`  
**Función**: Slot de inventario draggable

```gdscript
extends PanelContainer
class_name DraggableItemSlot

var item: CraftedItem = null

func _get_drag_data(_at_position: Vector2) -> Variant:
	# Retorna el CraftedItem para arrastrar
	# Crea preview con bordes de calidad
	return item
```

**Features**:
- Override de `_get_drag_data()` nativo de Godot
- Preview visual con colores de calidad
- Acceso directo a `CraftedItem`

#### 2. `EquipmentDropSlot.gd`
**Ruta**: `res://scripts/ui/EquipmentDropSlot.gd`  
**Función**: Zona de drop para equipamiento

```gdscript
extends ColorRect
class_name EquipmentDropSlot

@export var slot_type: String = ""  # "main_hand", "head", etc.
signal item_equipped(item: CraftedItem)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# Valida compatibilidad de slot
	# Feedback visual (verde/rojo)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# Equipa item via InventoryManager
	# Flash de confirmación
	# Emite señal item_equipped
```

**Features**:
- Validación de slot_type vs equipment_slot del item
- Feedback visual en hover (verde si compatible, rojo si no)
- Flash animado al equipar
- Señal `item_equipped(item)` para actualizar UI

### Integración en DungeonHUD

#### Setup de Inventario
```gdscript
func _create_item_slot(item: CraftedItem) -> Control:
	var container = DraggableItemSlot.new()
	container.item = item
	# ... añadir children con mouse_filter = IGNORE
	return container
```

**Crítico**: Los children (VBoxContainer, TextureRect, Label) deben tener `mouse_filter = Control.MOUSE_FILTER_IGNORE` para que el drag funcione correctamente.

#### Setup de Equipment Slots
```gdscript
func _setup_equipment_drop_zones() -> void:
	# Convertir ColorRect existentes a EquipmentDropSlot
	icon_node.set_script(preload("res://scripts/ui/EquipmentDropSlot.gd"))
	icon_node.slot_type = "main_hand"  # o head, body, etc.
	icon_node.item_equipped.connect(_on_item_equipped_in_slot)
```

#### Handler de Equip
```gdscript
func _on_item_equipped_in_slot(item: CraftedItem) -> void:
	print("✨ Item equipado: %s" % item.get_display_name())
	_update_equipment()
	_update_inventory()
	_update_stats()
```

## Flujo de Uso

1. **Crafteo**: Item aparece en inventario de dungeon
2. **Drag Start**: Usuario hace click y arrastra desde slot de inventario
3. **Preview**: Se muestra panel semi-transparente con borde de calidad
4. **Hover**: Slot de equipamiento se pone verde (compatible) o rojo (incompatible)
5. **Drop**: Si compatible, item se equipa automáticamente
6. **Feedback**: Flash blanco en slot + actualización de stats

## Cambios Realizados

### Archivos Nuevos
- ✅ `scripts/ui/DraggableItemSlot.gd` (32 líneas)
- ✅ `scripts/ui/EquipmentDropSlot.gd` (52 líneas)

### Archivos Modificados
- ✅ `scripts/ui/DungeonHUD.gd`
  - `_create_item_slot()` usa `DraggableItemSlot.new()`
  - `_setup_equipment_drop_zones()` simplificado con `EquipmentDropSlot`
  - Handler `_on_item_equipped_in_slot()` añadido
  - Eliminados métodos legacy de drag forwarding

### Limpieza de HUD_Hero Legacy
**Problema**: `HUD_Hero.tscn` seguía instanciándose desde `Main.gd` y `UIManager.gd` pese a estar deshabilitado en escena.

**Solución**: Comentar todas las referencias:
- ✅ `scripts/Main.gd`:
  - `const HUD_HERO_SCENE` comentado
  - `var hud_hero` comentado
  - Instanciación comentada
  - Visibilidad comentada
  - `set_hero()` comentado
  - `update_stats()` comentado
- ✅ `scripts/autoload/UIManager.gd`:
  - `var hud_hero` comentado
  - `register_nodes()` comentado
  - `show_forge()` comentado
  - `show_dungeon()` comentado

## Ventajas sobre set_drag_forwarding()

### Problema Anterior
```gdscript
# ❌ NO FUNCIONA - firma incorrecta
icon_node.set_drag_forwarding(
	Callable(),
	Callable(self, "_can_drop"),  # Recibe 2 args, Godot pasa 1
	Callable(self, "_drop")
)
```
**Error**: "Method expected 2 argument(s), but called with 1"

### Solución Nativa
```gdscript
# ✅ FUNCIONA - override directo
func _get_drag_data(at_position: Vector2) -> Variant:
	return item

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is CraftedItem and data.get_equipment_slot() == slot_type

func _drop_data(at_position: Vector2, data: Variant) -> void:
	InventoryManager.equip_item(data)
```

**Ventajas**:
- ✅ Firma correcta garantizada por engine
- ✅ Menos indirección (sin Callable wrappers)
- ✅ Más modular (componentes reutilizables)
- ✅ Mejor para herencia (clase base puede extender)

## Testing

### Checklist de Pruebas
- [ ] Craftear item en forja
- [ ] Item aparece en inventario de dungeon
- [ ] Drag inicia correctamente desde slot
- [ ] Preview muestra borde de calidad correcto
- [ ] Slot compatible se pone verde al hover
- [ ] Slot incompatible se pone rojo
- [ ] Drop equipa item correctamente
- [ ] Flash de confirmación visible
- [ ] Stats del héroe actualizan inmediatamente
- [ ] Item equipado aparece en sección de equipment
- [ ] Item desaparece de inventario al equipar
- [ ] Re-equipar otro item del mismo tipo reemplaza anterior

### Casos Edge
- [ ] Arrastrar item a slot incorrecto (ej: espada → head)
- [ ] Arrastrar material (no debería funcionar)
- [ ] Equipar mientras héroe está en combate
- [ ] Equipar múltiples items rápidamente

## Próximos Pasos

1. **Crear ItemResource .tres**:
   - Definir stat ranges para ~16 items
   - Vincular a blueprints existentes
   - Ver: `doc/SISTEMA_CALIDAD_ITEMS.md`

2. **Testing Completo**:
   - Probar ciclo completo: craftear → inventario → equipar → combate
   - Verificar que stats aplican correctamente en batalla
   - Probar con items de todas las calidades

3. **Refinamiento Visual**:
   - Añadir SFX al equipar (AudioManager context DUNGEON)
   - Partículas en slot al equipar item legendario
   - Animación de stats subiendo

4. **Persistencia**:
   - Guardar items equipados al cerrar (user://save.dat)
   - Restaurar equipment al cargar partida

## Notas Técnicas

### Mouse Filter Crítico
Los children de `DraggableItemSlot` DEBEN tener `mouse_filter = IGNORE`:
```gdscript
vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
quality_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
```
**Razón**: Si los children capturan eventos de mouse, el parent no recibe `_get_drag_data()`.

### Conversion de ColorRect a EquipmentDropSlot
Usamos `set_script()` para convertir nodos existentes:
```gdscript
# En lugar de reemplazar todo el nodo
icon_node.set_script(preload("res://scripts/ui/EquipmentDropSlot.gd"))
icon_node.slot_type = "main_hand"
```
**Ventaja**: Mantiene posición, tamaño, anchors del nodo original en escena.

### QualityHelper Integration
Ambos componentes usan `QualityHelper` para consistencia:
```gdscript
const QualityUtils = preload("res://scripts/core/QualityHelper.gd")
# ...
var border_style = QualityUtils.create_quality_border_style(item.quality)
```

## Referencias
- Sistema de calidad: `doc/SISTEMA_CALIDAD_ITEMS.md`
- Materiales válidos: `doc/MATERIALES_DISPONIBLES.md`
- Arquitectura UI: `doc/INDEX.md`
- Godot drag & drop: https://docs.godotengine.org/en/stable/tutorials/inputs/drag_and_drop.html
