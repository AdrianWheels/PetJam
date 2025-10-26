# Plan de Contingencia: Sistema de Stats del Hero

**Fecha**: 26 octubre 2025  
**Estado**: 🔴 CRÍTICO - Sistema de stats no funciona completamente  
**Objetivo**: Implementar sistema funcional Calidad → Stats → Loadout Hero

---

## 🔴 PROBLEMA ACTUAL

### Síntoma
- Hero no recibe stats de items crafteados
- Items `.tres` NO tienen valores en `base_*_min/max`
- `CraftedItem.calculate_stats(quality)` devuelve **todos 0**
- `apply_loadout()` existe pero no se llama al equipar items

### Root Cause
1. **Items sin stats**: Todos los `.tres` en `data/items/` no tienen propiedades de stats configuradas
2. **No hay equipamiento automático**: Al entregar item al Hero, no se llama `apply_loadout()`
3. **Sistema fragmentado**: Hay código legacy y nuevo sin integración

---

## 📊 ANÁLISIS DEL SISTEMA ACTUAL

### ✅ Componentes que FUNCIONAN

#### 1. Sistema de calidad (minijuegos)
```gdscript
// CraftingManager.gd línea 415
func fuse_trial_results(results: Array) -> float:
	# Media geométrica ponderada 0-100
	# ✅ FUNCIONA PERFECTO
```

#### 2. Cálculo de stats por calidad
```gdscript
// ItemResource.gd línea 40
func calculate_stats(quality: float) -> Dictionary:
	# Interpola entre min/max según calidad
	# ✅ CÓDIGO CORRECTO, pero inputs son 0
```

#### 3. Aplicación de loadout
```gdscript
// Hero.gd línea 288
func apply_loadout(loadout: Dictionary) -> void:
	loadout_bonus = loadout.duplicate(true)
	# ✅ CÓDIGO CORRECTO, pero nunca se llama
```

### ❌ Componentes ROTOS

#### 1. Items sin stats base
```gdresource
// sword_basic.tres - ACTUAL (MAL)
[resource]
item_id = &"sword_basic"
display_name = "Espada Básica"
# ❌ NO HAY base_damage_min/max, base_crit_min/max, etc.
```

#### 2. No hay equipamiento automático
```gdscript
// UIManager.gd línea 287
func _on_delivered_to_hero(item_data: Dictionary) -> void:
	# ❌ NO llama GameManager.deliver_item_to_hero()
	# ❌ NO aplica stats al Hero
```

---

## 🎯 DISEÑO DE STATS PARA JAM

### Stats Core (5)
1. **HP** (vida)
2. **DMG** (daño base)
3. **CRIT** (probabilidad crítico 0-1)
4. **APS** (ataques por segundo)
5. **ARMOR** (reducción de daño)

### Mapeo de Items

#### **WEAPONS** (Espadas) → DMG + CRIT + APS
```
sword_basic:      DMG 5-10,  CRIT 0.05-0.15,  APS 0.1-0.2
sword_advanced:   DMG 10-20, CRIT 0.15-0.35,  APS 0.2-0.4
sword_masterwork: DMG 20-40, CRIT 0.35-0.70,  APS 0.4-0.8
```

#### **ARMOR** (Cascos/Botas/Escudos) → HP + ARMOR
```
helmet_basic:  HP 10-30,  ARMOR 1-3
helmet_advanced: HP 30-60, ARMOR 3-6
helmet_master: HP 60-120, ARMOR 6-12

shield_basic: HP 20-50, ARMOR 2-5
shield_advanced: HP 50-100, ARMOR 5-10
shield_master: HP 100-200, ARMOR 10-20

boots_basic: HP 5-15, ARMOR 1-2
boots_advanced: HP 15-30, ARMOR 2-4
boots_master: HP 30-60, ARMOR 4-8
```

### Fórmula de Calidad
```gdscript
quality = fuse_trial_results([forge, hammer, sew, quench])  # 0-100
quality_normalized = quality / 100.0  # 0.0-1.0
final_stat = lerp(base_min, base_max, quality_normalized)
```

**Ejemplo**: Espada Básica al 50% calidad
```
DMG = lerp(5, 10, 0.5) = 7.5 → 8
CRIT = lerp(0.05, 0.15, 0.5) = 0.10 → 10%
APS = lerp(0.1, 0.2, 0.5) = 0.15 → +0.15 APS
```

**Ejemplo**: Espada Maestra al 100% calidad
```
DMG = lerp(20, 40, 1.0) = 40
CRIT = lerp(0.35, 0.70, 1.0) = 0.70 → 70%
APS = lerp(0.4, 0.8, 1.0) = 0.8 → +0.8 APS
```

---

## 🛠️ PLAN DE IMPLEMENTACIÓN

### FASE 1: Configurar stats base en items ✅
**Archivos a editar**: 12 archivos `.tres` en `data/items/`

**Espadas (3)**:
- `sword_basic.tres`
- `sword_advanced.tres`
- `sword_masterwork.tres`

**Cascos (3)**:
- `helmet_basic.tres`
- `helmet_advanced.tres` (o `helmet_iron.tres`)
- `helmet_master.tres`

**Escudos (3)**:
- `shield_wooden.tres` o `shield_basic.tres`
- `shield_advanced.tres`
- `shield_master.tres`

**Botas (3)**:
- `boots_leather.tres` o `boots_basic.tres`
- `boots_advanced.tres`
- `boots_master.tres`

**Acción**: Añadir propiedades `@export` con valores balanceados.

---

### FASE 2: Conectar delivery → equipamiento ✅
**Archivo**: `scripts/autoload/UIManager.gd`

**Modificar**:
```gdscript
func _on_delivered_to_hero(item_data: Dictionary) -> void:
	# 1. Obtener CraftedItem con stats calculados
	var crafted_item = item_data.get("crafted_item")
	
	# 2. Equipar item (añadir a inventario equipado)
	var inv = get_node("/root/InventoryManager")
	if inv.has_method("equip_item"):
		inv.equip_item(crafted_item, crafted_item.item_resource.equipment_slot)
	
	# 3. Aplicar stats al Hero
	var hero = get_tree().get_first_node_in_group("hero")
	if hero and hero.has_method("apply_equipment_stats"):
		var total_stats = inv.get_total_equipment_stats()
		hero.apply_equipment_stats(total_stats)
```

---

### FASE 3: Implementar equipamiento en InventoryManager ✅
**Archivo**: `scripts/autoload/InventoryManager.gd`

**Añadir**:
```gdscript
var equipped_items: Dictionary = {}  # { "main_hand": CraftedItem, "head": CraftedItem, ... }

func equip_item(item: CraftedItem, slot: String) -> bool:
	if equipped_items.has(slot):
		# Desequipar anterior
		unequip_item(slot)
	
	equipped_items[slot] = item
	emit_signal("equipment_changed", equipped_items)
	return true

func get_total_equipment_stats() -> Dictionary:
	var total = {
		"damage": 0,
		"hp": 0,
		"armor": 0,
		"crit": 0.0,
		"aps": 0.0
	}
	
	for item in equipped_items.values():
		if item and item.calculated_stats:
			for key in total.keys():
				total[key] += item.calculated_stats.get(key, 0)
	
	return total

func get_equipped_item(slot: String) -> CraftedItem:
	return equipped_items.get(slot, null)
```

---

### FASE 4: Aplicar stats en Hero ✅
**Archivo**: `scripts/gameplay/Hero.gd`

**Añadir**:
```gdscript
var equipment_stats: Dictionary = {}

func apply_equipment_stats(stats: Dictionary) -> void:
	equipment_stats = stats.duplicate(true)
	reset_stats()  # Recalcular con nuevo equipo
	print("Hero: Equipment stats applied - DMG+%d, HP+%d, ARMOR+%d, CRIT+%.1f%%, APS+%.2f" % [
		stats.get("damage", 0),
		stats.get("hp", 0),
		stats.get("armor", 0),
		stats.get("crit", 0) * 100,
		stats.get("aps", 0)
	])
```

**Modificar `reset_stats()`**:
```gdscript
func reset_stats():
	# ... código existente ...
	
	# Aplicar equipment_stats
	var bonus_hp = equipment_stats.get("hp", 0)
	var bonus_dmg = equipment_stats.get("damage", 0)
	var bonus_aps = equipment_stats.get("aps", 0.0)
	var bonus_crit = equipment_stats.get("crit", 0.0)
	var bonus_armor = equipment_stats.get("armor", 0)
	
	max_hp = BASE_HP + STR * 10 + bonus_hp
	hp = min(hp, max_hp)  # No exceder nuevo max
	dmg = BASE_DMG + STR * 1.5 + bonus_dmg
	aps = clamp(BASE_APS + AGI * 0.02 + bonus_aps, 0.3, 5.0)
	crit_p = min(0.5 + bonus_crit, 1.0)  # Cap 100%
	armor = bonus_armor
```

---

### FASE 5: Testing y validación ✅
**Escenarios de prueba**:

1. **Craftear espada básica al 50%**:
   - Minijuegos: 3 "Bien", 1 "Regular" → ~60% quality
   - Stats esperados: DMG +7, CRIT +10%, APS +0.13

2. **Entregar al Hero**:
   - Botón "Hero" en DeliveryPanel
   - Log: `Hero: Equipment stats applied - DMG+7, CRIT+10.0%, APS+0.13`
   - Combat log: `Hero: Attack dmg=28.0 (21 base + 7 weapon)`

3. **Craftear armadura al 100%**:
   - 4 "Perfect" → 100% quality
   - Helmet Master: HP +120, ARMOR +12
   - Log: `Hero: Equipment stats applied - HP+120, ARMOR+12`
   - HP bar: 280/280 (160 base + 120 helmet)

4. **Test invencibilidad**:
   - Equipar espada maestra 100% (DMG +40, CRIT +70%)
   - Activar invencibilidad: 10k HP, 10k DMG
   - Desactivar: restaurar DMG a 61 (21 base + 40 weapon)

---

## ⚠️ RIESGOS Y MITIGACIONES

### Riesgo 1: Balance OP
**Síntoma**: Hero mata enemigos en 1 golpe con equipo Master  
**Mitigación**: Ajustar `base_*_max` de items Master (reducir 50%)

### Riesgo 2: Stats no se aplican tras respawn
**Síntoma**: Hero respawnea con stats base, pierde equipo  
**Mitigación**: En `Hero.respawn()` llamar `apply_equipment_stats()` tras `reset_stats()`

### Riesgo 3: Items duplicados en inventario
**Síntoma**: Equipar item no lo remueve de inventario  
**Mitigación**: `equip_item()` debe marcar item como `is_equipped = true`

---

## 📋 CHECKLIST DE IMPLEMENTACIÓN

### Fase 1: Items
- [ ] sword_basic.tres - stats configurados
- [ ] sword_advanced.tres - stats configurados
- [ ] sword_masterwork.tres - stats configurados
- [ ] helmet_basic.tres - stats configurados
- [ ] helmet_advanced.tres - stats configurados
- [ ] helmet_master.tres - stats configurados
- [ ] shield_basic/wooden.tres - stats configurados
- [ ] shield_advanced.tres - stats configurados
- [ ] shield_master.tres - stats configurados
- [ ] boots_basic/leather.tres - stats configurados
- [ ] boots_advanced.tres - stats configurados
- [ ] boots_master.tres - stats configurados

### Fase 2: UIManager
- [ ] `_on_delivered_to_hero()` llama `equip_item()`
- [ ] `_on_delivered_to_hero()` llama `apply_equipment_stats()`

### Fase 3: InventoryManager
- [ ] `equipped_items: Dictionary` añadido
- [ ] `equip_item()` implementado
- [ ] `unequip_item()` implementado
- [ ] `get_total_equipment_stats()` implementado
- [ ] `get_equipped_item()` implementado
- [ ] signal `equipment_changed` añadido

### Fase 4: Hero
- [ ] `equipment_stats: Dictionary` añadido
- [ ] `apply_equipment_stats()` implementado
- [ ] `reset_stats()` usa `equipment_stats`
- [ ] `respawn()` preserva equipo

### Fase 5: Testing
- [ ] Craftear espada básica 50% → stats correctos
- [ ] Entregar al Hero → logs de aplicación
- [ ] Combate → daño incrementado visible
- [ ] Craftear armadura 100% → HP incrementado
- [ ] Respawn → equipo preservado
- [ ] Invencibilidad → no interfiere con equipo

---

## 🚀 EJECUCIÓN INMEDIATA

**Orden de implementación** (90 minutos):
1. **15 min**: Configurar 12 items `.tres` con stats
2. **20 min**: Implementar `InventoryManager` equipamiento
3. **15 min**: Modificar `Hero.apply_equipment_stats()` y `reset_stats()`
4. **10 min**: Conectar `UIManager._on_delivered_to_hero()`
5. **30 min**: Testing completo en Main.tscn

**Siguiente paso**: Ejecutar Fase 1 (configurar items)
