# ⚙️ **INSTRUCCIONES: Registro de AutoLoads**

Para que el sistema de aislamiento funcione, necesitas registrar el nuevo **DebugManager** como AutoLoad en Godot 4.5.

## 📋 **Pasos en Godot Editor:**

### **1. Abrir Project Settings**
- Menú: `Project` → `Project Settings`
- O atajo: `Alt + P` → `Project Settings`

### **2. Ir a la pestaña AutoLoad**
- En el panel izquierdo, buscar `AutoLoad`
- Debería estar en la sección `Application`

### **3. Añadir DebugManager**
Añadir una nueva entrada con estos valores:

| Campo | Valor |
|-------|-------|
| **Path** | `res://scripts/autoload/DebugManager.gd` |
| **Node Name** | `DebugManager` |
| **Enable** | ✅ (activado) |
| **Singleton** | ✅ (activado) |

### **4. Verificar orden de AutoLoads**
El orden correcto debería ser:

```
1. GameManager        (res://scripts/autoload/GameManager.gd)
2. DataManager        (res://scripts/autoload/DataManager.gd)
3. AudioManager       (res://scripts/autoload/AudioManager.gd)  ← MODIFICADO
4. DebugManager       (res://scripts/autoload/DebugManager.gd)  ← NUEVO
5. CraftingManager    (res://scripts/autoload/CraftingManager.gd)
6. TelemetryManager   (res://scripts/autoload/TelemetryManager.gd)
7. InventoryManager   (si existe)
8. UIManager          (si existe)
```

**Importante:** DebugManager debe estar ANTES de cualquier manager que use sus funciones de log.

### **5. Aplicar cambios**
- Clic en `Close` para cerrar Project Settings
- Los cambios se guardan automáticamente

---

## ✅ **Verificación**

Una vez registrado, puedes verificar que funciona:

1. **Ejecutar Main.tscn** (`F5`)
2. **Verificar en Output:**
   ```
   DebugManager ready (use log_<category>() methods)
   AudioManager ready with 2 contexts
   AudioManager: Context 'Forge' initialized
   AudioManager: Context 'Dungeon' initialized
   [INFO] Main: Scene ready
   [INFO] Main: DebugPanel instantiated
   ```

3. **Presionar F12** para mostrar/ocultar el DebugPanel
4. **Cambiar checkboxes** y observar que los logs cambian

---

## 🔧 **Troubleshooting**

### **Error: "DebugManager not found"**
- Asegúrate de que el path es exactamente `res://scripts/autoload/DebugManager.gd`
- Verifica que el checkbox "Enable" está activado
- Reinicia el editor de Godot

### **Error: "Cannot access member 'log_forge' on base 'Nil'"**
- DebugManager no está registrado como AutoLoad
- O el orden está incorrecto (debe estar antes de quien lo usa)

### **DebugPanel no aparece**
- Verifica que `res://scenes/UI/DebugPanel.tscn` existe
- Verifica que Main.tscn se está ejecutando correctamente
- Presiona F12 para mostrar el panel (puede estar oculto por defecto)

---

## 🎮 **USO EN RUNTIME**

Una vez todo funcionando:

### **Activar/desactivar debug de Forja:**
- Desactivar checkbox "Forge Debug"
- Los logs de forja desaparecen de la consola
- Los logs de dungeon siguen visibles

### **Activar/desactivar audio de Forja:**
- Desactivar checkbox "Forge Audio"
- La música/SFX de minijuegos se silencia
- La música del dungeon sigue sonando

### **Show All:**
- Activa todos los debugs y audios a la vez
- Útil para debugging general

---

**Siguiente paso:** Una vez registrado DebugManager, ejecuta Godot y verifica que todo funciona.
