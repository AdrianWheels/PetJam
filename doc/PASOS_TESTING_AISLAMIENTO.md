# 🚀 **PASOS PARA PROBAR EL AISLAMIENTO**

**IMPORTANTE:** Seguir estos pasos **EN ORDEN** para evitar errores.

---

## 📋 **PASO 1: Registrar DebugManager como AutoLoad**

### **En Godot Editor:**

1. **Abrir Project Settings:**
   - Menú: `Project` → `Project Settings`
   - O presionar `Alt + P`

2. **Ir a pestaña AutoLoad:**
   - Panel izquierdo → `Application` → `AutoLoad`

3. **Añadir DebugManager:**
   - Click en el icono de carpeta junto a "Path"
   - Navegar a: `res://scripts/autoload/DebugManager.gd`
   - En "Node Name" escribir: `DebugManager`
   - Verificar que "Enable" está marcado ✅
   - Click en "Add"

4. **Verificar orden de AutoLoads:**
   ```
   GameManager
   DataManager
   AudioManager        ← Ya existe (modificado)
   DebugManager        ← NUEVO - Añadir aquí
   CraftingManager
   TelemetryManager
   InventoryManager
   UIManager
   ```

5. **Cerrar Project Settings**
   - Los cambios se guardan automáticamente

---

## 📋 **PASO 2: Verificar que Main.tscn carga sin errores**

1. **Reload current project (recomendado):**
   - Menú: `Project` → `Reload Current Project`
   - Esto fuerza a Godot a recargar todos los scripts

2. **Verificar Output:**
   - Abrir panel "Output" (abajo)
   - Buscar estos mensajes:
   ```
   DebugManager ready (use log_<category>() methods)
   AudioManager ready with 2 contexts
   AudioManager: Context 'Forge' initialized
   AudioManager: Context 'Dungeon' initialized
   ```

3. **Si hay errores:**
   - Verificar que DebugManager está en la lista de AutoLoads
   - Verificar que el path es correcto: `res://scripts/autoload/DebugManager.gd`
   - Reload project de nuevo

---

## 📋 **PASO 3: Ejecutar Main.tscn**

1. **Play Scene (F6):**
   - Abrir `res://scenes/Main.tscn`
   - Presionar `F6` o click en "Play Scene"

2. **Verificar Output:**
   ```
   Main: Scene ready
   Main: DebugPanel instantiated
   ```

3. **Verificar visualmente:**
   - Debe aparecer el DebugPanel en esquina superior derecha
   - Si no aparece, presionar `F12` para mostrarlo

---

## 📋 **PASO 4: Probar controles de debug**

### **Test A: Visibilidad del panel**
- [ ] Presionar `F12` → Panel se oculta
- [ ] Presionar `F12` de nuevo → Panel aparece

### **Test B: Checkboxes funcionan (sin DebugManager aún)**
- [ ] Click en checkboxes
- [ ] Aparece mensaje: "DebugPanel: Cannot toggle - DebugManager not registered"
- [ ] Esto es **ESPERADO** por ahora

### **Test C: AudioManager con contextos**
- [ ] Checkboxes de audio deberían funcionar
- [ ] Toggle "Forge Audio" → mensaje en consola
- [ ] Toggle "Dungeon Audio" → mensaje en consola

---

## 📋 **PASO 5: Verificar que el sistema funciona**

Una vez DebugManager registrado:

### **Test 1: Debug categorizado**
1. Activar solo "Dungeon Debug"
2. Cambiar a dungeon (clic derecho)
3. Verificar que aparecen logs de dungeon

### **Test 2: Audio por contexto**
1. Desactivar "Forge Audio"
2. Iniciar un minijuego (clic en blueprint)
3. Verificar que no hay sonidos de forja
4. Cambiar a dungeon
5. Verificar que sí hay sonidos de dungeon

### **Test 3: Show All**
1. Click en "Show All"
2. Todos los checkboxes se activan
3. Aparecen logs de todas las categorías

---

## ✅ **CHECKLIST DE VERIFICACIÓN**

- [ ] DebugManager registrado como AutoLoad
- [ ] Proyecto recargado sin errores
- [ ] Main.tscn ejecuta sin crashes
- [ ] DebugPanel visible en esquina
- [ ] F12 toggle funciona
- [ ] Checkboxes de audio funcionan
- [ ] Sin errores en Output

---

## 🐛 **ERRORES COMUNES**

### **Error: "Identifier 'DebugManager' not declared"**
**Causa:** DebugManager NO está registrado como AutoLoad  
**Solución:** Volver al PASO 1

### **Error: "Cannot call method 'log_forge' on base 'Nil'"**
**Causa:** DebugManager registrado pero no inicializado  
**Solución:** Reload project (PASO 2)

### **DebugPanel no aparece**
**Causa:** F12 oculta el panel por defecto  
**Solución:** Presionar F12 para mostrarlo

### **Checkboxes no hacen nada**
**Causa:** DebugManager no registrado  
**Solución:** Ver mensajes en Output, seguir PASO 1

---

## 📝 **NOTAS**

- El sistema está diseñado para funcionar **sin DebugManager** (solo sin debug categorizado)
- AudioManager con contextos funciona independientemente
- DebugPanel siempre se instancia (puedes ocultarlo con F12)
- Los logs de "Cannot toggle" son **normales** antes de registrar DebugManager

---

**Una vez completados todos los pasos, el sistema estará 100% funcional.**
