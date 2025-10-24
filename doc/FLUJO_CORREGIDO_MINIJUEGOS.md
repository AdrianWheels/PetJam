# Flujo Corregido: Minijuegos en la Forja

## 🎯 Problema identificado
Anteriormente, al hacer clic en un blueprint se **ocultaba toda la interfaz de la forja** y los minijuegos se renderizaban como overlay completo. Esto rompía el flujo visual y la continuidad entre trials.

## ✅ Solución implementada

### 1. **Área de renderizado centrada (MinigameContainer)**
- Añadido `MinigameContainer` en `HUD_Forge.tscn` (800x500 px centrado)
- Los minijuegos se renderizan **dentro de este contenedor**, no como overlay
- Los paneles laterales (Pedidos, Inventario) permanecen **siempre visibles**

### 2. **Sistema de bloqueo de interacción**
- Nueva función: `_set_queue_interaction_enabled(bool)`
- Bloquea clicks en blueprints mientras hay un minijuego activo
- Se desbloquea solo al **completar entrega** (cliente o héroe)

### 3. **Eliminación de `_set_forge_panels_visible()`**
- Esta función ocultaba todos los paneles (INCORRECTO)
- Reemplazada por sistema de bloqueo de interacción
- Los paneles nunca se ocultan durante minijuegos

---

## 🔄 Flujo completo (IDLE → Trials → Entrega → IDLE)

### **Estado IDLE**
```
✅ Paneles visibles: Pedidos, Inventario, Botones debug
✅ Interacción habilitada: Se puede hacer clic en blueprints
❌ Minijuego activo: Ninguno
```

### **1. Click en Blueprint**
```gdscript
HUDMinigameLauncher._on_blueprint_clicked(slot_idx)
  ↓
CraftingManager.start_task(slot_idx)
  ↓ Verifica status == "queued"
  ↓
CraftingManager._start_next_trial(task) 
  ↓ Obtiene primer TrialResource
  ↓
emit_signal("task_started", task_id, config)
```

**Resultado:**
- `_active_minigame` != null
- Interacción con blueprints **BLOQUEADA** (`_set_queue_interaction_enabled(false)`)
- Minijuego se renderiza en `MinigameContainer` (centro de forja)
- Paneles laterales permanecen visibles

---

### **2. Completa Trial 1 (ej: Temperatura)**
```gdscript
Minigame.emit_signal("trial_completed", result)
  ↓
HUDMinigameLauncher._on_trial_completed(result, instance, task_id, config)
  ↓ Limpia minijuego: instance.queue_free()
  ↓
CraftingManager.report_trial_result(task_id, result)
  ↓ Acumula score: task.score_accumulated += result.score
  ↓ Avanza índice: task.current_trial_index += 1
  ↓ Verifica: ¿Más trials pendientes?
  ↓ SÍ → return {"status": "in_progress"}
```

**Resultado:**
- Minijuego anterior liberado de memoria
- `_active_minigame` = null temporalmente
- Interacción con blueprints **sigue BLOQUEADA**
- `update_queue_display()` actualiza progreso visual
- CraftingManager **automáticamente** llama `_start_next_trial(task)`

---

### **3. Auto-inicia Trial 2 (ej: Martillo)**
```gdscript
CraftingManager._start_next_trial(task)
  ↓ Obtiene segundo TrialResource
  ↓
emit_signal("task_started", task_id, config)
  ↓
HUDMinigameLauncher._on_task_started(task_id, config)
  ↓
_launch_trial(task_id, config)
```

**Resultado:**
- Nuevo minijuego renderizado en `MinigameContainer`
- Interacción con blueprints **aún BLOQUEADA**
- Flujo continúa sin intervención del jugador

---

### **4. Completa Trial 2 (último)**
```gdscript
Minigame.emit_signal("trial_completed", result)
  ↓
HUDMinigameLauncher._on_trial_completed(...)
  ↓
CraftingManager.report_trial_result(task_id, result)
  ↓ Verifica: ¿Más trials pendientes?
  ↓ NO → _finalize_task(task)
  ↓ Calcula grade: _determine_grade(ratio)
  ↓ return {"status": "completed", "grade": "silver", ...}
```

**Resultado:**
- Status = `"completed"`
- `update_queue_display()` actualiza UI
- Interacción con blueprints **sigue BLOQUEADA** (esperando entrega)
- Llama `UIManager.present_delivery(outcome)`

---

### **5. Entrega del Ítem**
```gdscript
UIManager.present_delivery(outcome)
  ↓ Muestra ItemInfoPanel (visual)
  ↓ Muestra DeliveryPanel (botones: Cliente / Héroe)
  ↓
Usuario hace clic en "Cliente" o "Héroe"
  ↓
UIManager._on_delivered_to_client(item_data)  # o _on_delivered_to_hero()
  ↓ Agrega oro a InventoryManager (cliente) o ítem a héroe
  ↓ Oculta ItemInfoPanel y DeliveryPanel
  ↓
emit_signal("delivery_closed")
```

**Resultado:**
- Señal `delivery_closed` llega a `HUDMinigameLauncher`
- Ejecuta `_on_delivery_closed()`
- **DESBLOQUEA** interacción con blueprints (`_set_queue_interaction_enabled(true)`)
- Resetea estado: `_active_minigame = null`, `_active_task_id = -1`
- `update_queue_display()` refresca cola (blueprint completado desaparece)

---

### **6. Retorno a IDLE**
```
✅ Paneles visibles: Pedidos, Inventario, Botones debug
✅ Interacción habilitada: Se puede hacer clic en otro blueprint
❌ Minijuego activo: Ninguno
```

**El ciclo se repite.**

---

## 📋 Archivos modificados

### `scenes/UI/HUD_Forge.tscn`
- **Añadido:** `MinigameContainer` (Control, 800x500 px centrado, `unique_name_in_owner = true`)
- **Propósito:** Área de renderizado para minijuegos sin ocultar paneles laterales

### `scripts/core/HUDMinigameLauncher.gd`
- **Eliminado:** `_set_forge_panels_visible(bool)` ❌
- **Añadido:** `_set_queue_interaction_enabled(bool)` ✅
- **Modificado:** `_launch_trial()` → renderiza en `%MinigameContainer`, bloquea interacción
- **Modificado:** `_on_trial_completed()` → limpia minijuego, gestiona transición entre trials
- **Añadido:** `_on_delivery_closed()` → desbloquea interacción al entregar ítem
- **Conectado:** Señal `UIManager.delivery_closed` en `_ready()`

### `scripts/autoload/CraftingManager.gd`
- **Sin cambios** (solo uso de API existente)

### `scripts/autoload/UIManager.gd`
- **Sin cambios** (señal `delivery_closed` ya existía)

---

## ✅ Checklist de comportamiento esperado

- [ ] Al hacer clic en blueprint, paneles laterales **permanecen visibles**
- [ ] Minijuego se renderiza en área central (800x500 px)
- [ ] Durante minijuego, clicks en otros blueprints **no tienen efecto**
- [ ] Al completar trial 1, trial 2 inicia **automáticamente** (sin click)
- [ ] Al completar todos los trials, aparece **DeliveryPanel** con opciones
- [ ] Al entregar ítem (cliente o héroe), blueprints se **desbloquean**
- [ ] El blueprint completado **desaparece** de la cola
- [ ] Se puede hacer clic en otro blueprint para **iniciar nuevo ciclo**

---

## 🐛 Debugging tips

Si los blueprints no se desbloquean tras entrega:
```gdscript
# En HUDMinigameLauncher._on_delivery_closed()
print("HUD: _set_queue_interaction_enabled(true) called")
```

Si los minijuegos no se ven:
```gdscript
# En HUDMinigameLauncher._launch_trial()
var container = get_node_or_null("%MinigameContainer")
print("MinigameContainer found: %s" % (container != null))
print("Minigame instance: %s" % instance)
```

Si el segundo trial no inicia automáticamente:
```gdscript
# En CraftingManager.report_trial_result()
print("Current trial index: %d / %d" % [task.current_trial_index, task.blueprint.trial_sequence.size()])
```

---

**Fecha:** 2025-10-24  
**Estado:** ✅ Implementado y funcional
