# VS Code y Godot — Guía de Integración

## ⚠️ Conceptos Clave

**VS Code NO ejecuta código de Godot**. Es solo un editor de texto avanzado. Para ejecutar:
- Scripts GDScript → Godot Engine
- Scenes `.tscn` → Godot Engine (F5/F6)
- EditorScripts → Godot Engine (File → Run)

**VS Code sirve para:**
- ✅ Escribir y editar código `.gd`
- ✅ Buscar referencias con Ctrl+F
- ✅ Autocompletado con extensión Godot Tools
- ✅ Control de versiones (Git)

**VS Code NO sirve para:**
- ❌ Ejecutar scripts `.gd` directamente
- ❌ Previsualizar scenes `.tscn`
- ❌ Editar recursos `.tres`
- ❌ Ejecutar el juego

---

## 🔧 Workflow Recomendado

### Para editar código:
1. **Abre el proyecto en VS Code**
2. Edita archivos `.gd`
3. Guarda cambios (`Ctrl+S`)
4. **Cambia a Godot**
5. El código se recarga automáticamente

### Para ejecutar herramientas:
1. **Abre Godot**
2. Navega a la scene o script en el FileSystem
3. Ejecuta con F5 (proyecto), F6 (scene), o File → Run (script)

### Para editar blueprints:
1. **Abre Godot**
2. Doble-clic en el archivo `.tres` en FileSystem
3. Edita valores en el Inspector
4. Guarda con `Ctrl+S`

---

## 🎯 Caso de Uso: Conversor de Blueprints

### ❌ Intento incorrecto (desde VS Code):
```bash
# Esto NO funciona:
PS D:\Proyectos\PetJam> godot convert_blueprints.gd
# Error: EditorScript requiere el editor de Godot
```

### ✅ Método correcto (desde Godot):

**Opción A: Scene con UI (más fácil)**
1. Abre **Godot**
2. FileSystem → `res://scenes/sandboxes/BlueprintConverter.tscn`
3. Doble-clic para abrir
4. **F6** (Run Current Scene)
5. Clic en "▶ Convertir Blueprints"

**Opción B: EditorScript**
1. Abre **Godot**
2. FileSystem → `res://addons/editor_scripts/convert_blueprints.gd`
3. Doble-clic para abrir
4. **File → Run** (o `Ctrl+Shift+X`)
5. Mira Output en la consola

---

## 🛠️ Configuración Recomendada

### Extensiones de VS Code útiles:
- **godot-tools** (oficial): autocompletado, sintaxis highlighting
- **Godot Files** (unofficial): soporte para `.tscn`, `.tres`
- **GDScript Highlighter**: mejora sintaxis GDScript

### Atajos útiles en Godot:
- **F5**: Ejecutar proyecto completo
- **F6**: Ejecutar scene actual
- **F7**: Ejecutar sin depuración
- **Ctrl+Shift+X**: Ejecutar EditorScript (File → Run)
- **Ctrl+R**: Recargar recurso en Inspector
- **Ctrl+S**: Guardar archivo/recurso

---

## 📝 Flujo de Trabajo Típico

### Crear nueva clase de configuración:

**En VS Code:**
```gdscript
# scripts/data/MyCustomTrialConfig.gd
extends TrialConfig
class_name MyCustomTrialConfig

@export_range(0.0, 1.0) var my_param: float = 0.5

func prepare() -> void:
    parameters = {"my_param": my_param}
```

**En Godot:**
1. Project → Reload Current Project (para registrar `MyCustomTrialConfig`)
2. Abre un blueprint `.tres`
3. En Inspector, crea nuevo SubResource
4. Asigna script `MyCustomTrialConfig.gd`
5. Ajusta valores con sliders
6. Guarda

---

## 🚨 Errores Comunes

### "No puedo ejecutar el .gd desde VS Code"
**Causa:** VS Code no ejecuta scripts de Godot.  
**Solución:** Usa Godot Editor (ver métodos arriba).

### "El código no se actualiza en Godot"
**Causa:** Cambios no guardados o caché.  
**Solución:**
- Guarda en VS Code (`Ctrl+S`)
- En Godot: Project → Reload Current Project

### "Error: Class 'ForgeTrialConfig' not found"
**Causa:** Godot no ha registrado la nueva clase.  
**Solución:**
- Verifica que el script tenga `class_name ForgeTrialConfig`
- Project → Reload Current Project
- Cierra y reabre Godot si persiste

### "Los sliders no aparecen en el Inspector"
**Causa:** Config todavía usa `TrialConfig.gd` en vez de clase específica.  
**Solución:**
- Ejecuta `BlueprintConverter.tscn` desde Godot
- O cambia manualmente el script en el Inspector

### "Scene no se abre al hacer doble-clic"
**Causa:** VS Code no puede abrir `.tscn` nativamente.  
**Solución:**
- Configura asociación de archivos a Godot
- O navega en Godot FileSystem y abre desde allí

---

## 🎓 Conceptos Avanzados

### ¿Por qué EditorScript solo en Godot?

EditorScript es una clase especial de Godot que:
- Accede al sistema de archivos del proyecto
- Usa `ResourceLoader` y `ResourceSaver`
- Interactúa con el editor de Godot
- NO tiene equivalente en VS Code

### ¿Puedo automatizar con scripts externos?

Sí, pero limitado:
```bash
# Ejecutar Godot headless (sin GUI)
godot --headless --script my_tool_script.gd

# Exportar proyecto
godot --export "Windows Desktop" build/game.exe
```

Pero para **edición de recursos** (blueprints, scenes), necesitas el editor.

---

## 📚 Recursos Adicionales

- **Godot Docs**: https://docs.godotengine.org/
- **GDScript Style Guide**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- **VS Code + Godot Setup**: https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html

---

## ✅ Checklist de Setup

- [ ] Godot 4.5 instalado y funcionando
- [ ] Proyecto abre sin errores en Godot
- [ ] VS Code con extensión `godot-tools` instalada
- [ ] AutoLoads registrados en Project Settings
- [ ] `BlueprintConverter.tscn` se puede ejecutar con F6
- [ ] Blueprints convertidos muestran sliders en Inspector

Si todos los checkboxes están marcados, ¡estás listo para desarrollar! 🚀
