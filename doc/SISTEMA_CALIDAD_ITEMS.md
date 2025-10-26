# Sistema de Calidad de Items

## Resumen
Sistema completo de items crafteados con calidad variable (0-100%), estadísticas escaladas, sistema de rareza con colores, y equipamiento que afecta las stats del héroe.

## Cambios Implementados

### 1. Layout Dungeon Ajustado
- **DungeonArea** reposicionado de Y=3000 a **Y=2350**
- Alineación correcta del suelo con el héroe
- Debug logging removido de `Corridor.gd`

### 2. Clase `CraftedItem` (NUEVO)
**Ubicación**: `res://scripts/data/CraftedItem.gd`

Representa un item crafteado individual con:
- Referencia a `ItemResource` (stats base)
- **Quality**: float 0.0-1.0 (normalizado)
- **Calculated stats**: Dictionary con stats finales según calidad
- Metadatos: timestamp, is_equipped

#### Métodos clave:
```gdscript
get_quality_percent() -> int  # 0-100
get_quality_tier() -> String  # legendary/epic/rare/uncommon/common
get_quality_color() -> Color  # Color de outline
get_quality_label() -> String  # LEGENDARIO, ÉPICO, etc.
calculate_stats(quality)  # Interpola min-max por calidad
```

#### Umbrales de Rareza:
- **LEGENDARIO** (Naranja): 99-100% - EXTREMADAMENTE difícil
- **ÉPICO** (Morado): 90-98% - Muy difícil
- **RARO** (Azul): 70-89% - Difícil
- **COMÚN** (Verde): 40-69% - Moderado
- **BÁSICO** (Blanco): 0-39% - Fácil

### 3. `ItemResource` Expandido
**Ubicación**: `res://scripts/data/ItemResource.gd`

Ahora incluye **estadísticas base con rangos**:
```gdscript
@export var base_damage_min: int = 0
@export var base_damage_max: int = 0
@export var base_str_min: int = 0
@export var base_str_max: int = 0
# ... agi, int, hp, armor, crit, aps
```

#### Ejemplo: Espada Básica
```gdscript
base_damage_min = 1  # Calidad 0% = 1 de daño
base_damage_max = 5  # Calidad 100% = 5 de daño
base_str_min = 0
base_str_max = 3
```

**Quality 15%**: dmg=1, str=0  
**Quality 99%**: dmg=5, str=3  

#### Slots de Equipamiento:
- `weapon` → `main_hand`
- `helmet` → `head`
- `armor` → `body`
- `shield` → `off_hand`
- `boots` → `feet`

### 4. `InventoryManager` - Separación Items/Materiales
**Ubicación**: `res://scripts/autoload/InventoryManager.gd`

#### Nuevas Propiedades:
```gdscript
var inventory: Dictionary = {}  # Materiales (wood, iron, etc.)
var crafted_items: Array[CraftedItem] = []  # Items crafteados
var equipped_items: Dictionary = {}  # slot_name -> CraftedItem
```

#### Nuevos Métodos:
```gdscript
add_crafted_item(item: CraftedItem)
get_crafted_items() -> Array[CraftedItem]
get_unequipped_items() -> Array[CraftedItem]
equip_item(item: CraftedItem) -> bool
unequip_item(slot: String) -> bool
get_equipped_item(slot: String) -> CraftedItem
calculate_total_stats() -> Dictionary  # Suma stats de equipamiento
remove_crafted_item(item: CraftedItem) -> bool
```

#### Señales:
```gdscript
signal crafted_items_changed(items_array)
```

### 5. `CraftingManager` - Crear Items al Completar
**Ubicación**: `res://scripts/autoload/CraftingManager.gd`

Método `_finalize_task()` modificado:
1. Calcula `quality_normalized = ratio` (0.0-1.0)
2. Obtiene `ItemResource` desde `DataManager.get_item_resource()`
3. Crea `CraftedItem.new(item_res, quality)`
4. Añade a `InventoryManager.add_crafted_item()`
5. Emite resultado con `crafted_item` incluido

**Output de consola**:
```
CraftingManager: ✨ Item crafteado: Espada Básica (87%) (calidad: 87%, tier: RARO)
```

### 6. `DataManager` - Resolver ItemResources
**Ubicación**: `res://scripts/autoload/DataManager.gd`

#### Nuevo Método:
```gdscript
get_item_resource(item_id: StringName) -> ItemResource
```

Busca en blueprints el que tenga `result_item == item_id` y devuelve:
1. ItemResource cargado desde `icon_path` (si es .tres)
2. Fallback: ItemResource generado desde datos del blueprint

### 7. `Hero.gd` - Aplicar Bonuses de Equipamiento
**Ubicación**: `res://scripts/gameplay/Hero.gd`

Método `reset_stats()` modificado:
```gdscript
# Obtener stats de equipamiento
var equipment_stats = inv_manager.calculate_total_stats()

# Sumar a bonuses existentes
bonus_str += equipment_stats.get("str", 0)
bonus_dmg += equipment_stats.get("damage", 0)
bonus_hp += equipment_stats.get("hp", 0)
# ... etc

# Aplicar a stats finales
max_hp = BASE_HP + STR * 10 + bonus_hp
dmg = BASE_DMG + STR * 1.5 + bonus_dmg
```

**NUEVO**: Variable `ARMOR` guardada en `loadout_bonus["ARMOR"]` para futura mitigación de daño.

### 8. `DungeonHUD.gd` - Mostrar Items con Calidad
**Ubicación**: `res://scripts/ui/DungeonHUD.gd`

#### Nuevas Funcionalidades:
- **_update_inventory()**: Muestra grid de items crafteados
  - Cada slot tiene outline coloreado según tier
  - Icono del item + label de calidad (%)
  - Clickeable para equipar
  
- **_create_item_slot(item)**: Genera slot visual con:
  - `PanelContainer` con `StyleBoxFlat`
  - Border de 3px con `item.get_quality_color()`
  - `TextureRect` con icono
  - Label con porcentaje coloreado
  
- **_update_equipment()**: Muestra items equipados
  - Nombre del item en cada slot
  - Color según tier de calidad
  
- **_update_stats()**: Calcula stats totales
  - Base stats del héroe
  - + Bonuses de `calculate_total_stats()`
  - Muestra en formato `STR: 15 (+5)`

#### Callbacks:
```gdscript
_on_item_slot_clicked(event, item)  # Equipar item
_on_items_changed(items_array)  # Refrescar UI
```

## Flujo Completo

### 1. Craftear Item
```
Player completa minijuegos
→ CraftingManager._finalize_task()
→ quality = score_ratio (0.0-1.0)
→ CraftedItem.new(ItemResource, quality)
→ InventoryManager.add_crafted_item()
→ Signal: crafted_items_changed
```

### 2. Ver en Inventario
```
DungeonHUD escucha crafted_items_changed
→ _update_inventory()
→ Limpia grid
→ Para cada item: _create_item_slot()
  → PanelContainer con border color tier
  → Icono + label calidad
→ Añade a inventory_grid
```

### 3. Equipar Item
```
Player hace click en slot
→ _on_item_slot_clicked()
→ InventoryManager.equip_item()
→ Desequipa item previo del slot
→ Marca nuevo item.is_equipped = true
→ equipped_items[slot] = item
→ Signal: crafted_items_changed
→ DungeonHUD actualiza equipment y stats
```

### 4. Stats del Héroe
```
Hero.reset_stats()
→ InventoryManager.calculate_total_stats()
  → Suma stats de todos equipped_items
→ bonus_str += equipment_stats.str
→ dmg = BASE + STR*1.5 + bonus_dmg
→ max_hp = BASE + STR*10 + bonus_hp
→ Aplica a combat
```

## Ejemplo de Stats Escalados

### Espada Básica
```gdscript
# ItemResource
base_damage_min = 1
base_damage_max = 5
base_str_min = 0
base_str_max = 3
```

| Calidad | Dmg | STR | Tier | Color |
|---------|-----|-----|------|-------|
| 15% | 1 | 0 | BÁSICO | Blanco |
| 50% | 3 | 2 | COMÚN | Verde |
| 75% | 4 | 2 | RARO | Azul |
| 95% | 5 | 3 | ÉPICO | Morado |
| 100% | 5 | 3 | LEGENDARIO | Naranja |

### Armadura de Cuero
```gdscript
base_armor_min = 2
base_armor_max = 10
base_hp_min = 10
base_hp_max = 50
```

| Calidad | Armor | HP | Tier |
|---------|-------|-----|------|
| 30% | 4 | 22 | BÁSICO |
| 60% | 7 | 34 | COMÚN |
| 85% | 9 | 44 | RARO |
| 98% | 10 | 49 | ÉPICO |

## Próximos Pasos Sugeridos

### Fase 1: Crear ItemResources
1. Editar blueprints existentes en `res://data/blueprints/*.tres`
2. Cambiar `icon_path` para apuntar a nuevos `.tres` de ItemResource
3. Crear 16 ItemResources con:
   - Stats min/max balanceados por tipo
   - Slots correctos (main_hand, body, etc.)
   - Iconos placeholder

### Fase 2: Balance de Dificultad
1. Ajustar `MinigameDifficultyPreset` para hacer legendarios MUY difíciles
2. Tweakear umbrales de ventanas perfectas
3. Testing: ¿Cuántos intentos para conseguir 99%?

### Fase 3: Sistema de Venta
1. `RequestsManager` acepta items crafteados
2. Pago en oro según:
   - Base price del item
   - × quality multiplier (1.0 + quality)
3. Cliente más feliz con mayor calidad

### Fase 4: Mitigación de Armor
1. Hero.take_damage() reduce daño por armor
2. Fórmula: `damage_final = damage * (100 / (100 + armor))`
3. Ejemplo: 10 armor = 9.1% reducción, 50 armor = 33% reducción

### Fase 5: Efectos Visuales
1. Partículas al equipar item épico+
2. Glow en slots equipados
3. Animación de calidad en item recién crafteado

## Testing Checklist

- [ ] Craftear item y verificar que aparece en inventario dungeon
- [ ] Verificar colores de outline: blanco/verde/azul/morado/naranja
- [ ] Equipar item y ver stats actualizados en HUD
- [ ] Equipar 2 items del mismo tipo (debe reemplazar)
- [ ] Verificar que stats del héroe cambian en combate
- [ ] Craftear múltiples items y ver scroll en inventario
- [ ] Items con calidad 99-100% deben ser naranja (legendario)
- [ ] Stats de items escalan correctamente con calidad
- [ ] Desequipar item (click en slot equipado) - TODO
- [ ] Vender item crafteado a cliente - TODO

## Archivos Modificados

### Nuevos:
- `scripts/data/CraftedItem.gd` (115 líneas)
- `doc/SISTEMA_CALIDAD_ITEMS.md` (este archivo)

### Modificados:
- `scenes/Main.tscn` (DungeonArea Y=2350)
- `scripts/data/ItemResource.gd` (+30 líneas stats)
- `scripts/autoload/InventoryManager.gd` (+120 líneas items)
- `scripts/autoload/CraftingManager.gd` (_finalize_task +20 líneas)
- `scripts/autoload/DataManager.gd` (+20 líneas get_item_resource)
- `scripts/gameplay/Hero.gd` (reset_stats +15 líneas equipment)
- `scripts/ui/DungeonHUD.gd` (+100 líneas inventory/equipment)

## Notas de Diseño

### ¿Por qué estos umbrales?
- **Legendario 99-100%**: Solo 2% de rango - requiere ejecución casi perfecta en TODOS los minijuegos
- **Épico 90-98%**: 9% de rango - jugadores habilidosos pero no perfectos
- **Raro 70-89%**: 20% de rango - jugadores consistentes
- **Común 40-69%**: 30% de rango - rendimiento promedio
- **Básico 0-39%**: 40% de rango - fallos significativos

### Progresión Esperada
Run 1-2: Items básicos/comunes (40-60%)  
Run 3-5: Items comunes/raros (60-80%)  
Run 6-10: Items raros/épicos (75-95%)  
Run 10+: Chance de legendario con práctica extrema

### Balance de Stats
**Arma**: dmg, str, crit  
**Armadura**: hp, armor, str  
**Casco**: int, agi, hp  
**Botas**: agi, aps, hp  
**Escudo**: armor, hp, block_chance (futuro)  

Multiplicadores sugeridos:
- Daño: 1-5 (armas) / 0-2 (otros)
- HP: 10-50 (armadura) / 5-20 (otros)
- Stats primarios: 0-3 por item
- Armor: 2-10 (armadura/escudo) / 0-3 (otros)
- Crit: 0-5% por item
- APS: 0-0.2 por item

Total con 5 items épicos: +150 HP, +15 dmg, +10 stats, +30 armor, +15% crit, +0.5 APS
