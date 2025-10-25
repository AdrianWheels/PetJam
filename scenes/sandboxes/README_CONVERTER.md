# 🔧 Herramienta de Conversión de Blueprints

## ¿Qué hace esta herramienta?

Convierte tus blueprints del sistema antiguo (donde los parámetros están en un Dictionary que no se puede editar) al nuevo sistema con clases específicas (ForgeTrialConfig, HammerTrialConfig, etc.) que **SÍ permiten editar la dificultad desde el Inspector de Godot con sliders**.

---

## 🚀 Cómo usar (paso a paso)

### Desde Godot (recomendado)

1. **Abre Godot** y carga tu proyecto
2. En el FileSystem, navega a: `res://scenes/sandboxes/BlueprintConverter.tscn`
3. Doble-clic para abrirla
4. Presiona **F6** (o el botón ▶ "Run Current Scene")
5. Se abre una ventana con un botón grande
6. Haz clic en **"▶ Convertir Blueprints"**
7. Espera a que termine (verás el progreso)
8. Listo, todos los blueprints están convertidos

### Alternativa: EditorScript

1. **Abre Godot** y carga tu proyecto
2. En el FileSystem, navega a: `res://addons/editor_scripts/convert_blueprints.gd`
3. Doble-clic para abrirlo en el editor de scripts
4. En el menú: **File → Run** (o `Ctrl+Shift+X`)
5. Mira la consola Output para ver el progreso
6. Listo

---

## ✅ Verificar que funcionó

**Opción 1: Manualmente**
1. Abre cualquier blueprint, por ejemplo: `res://data/blueprints/sword_basic.tres`
2. En el Inspector, expande `Trial Sequence`
3. Expande el primer trial → `Config`
4. **Deberías ver** campos individuales como:
   - `Temp Window Base` (slider de 30 a 150)
   - `Hardness` (slider de 0 a 1)
   - `Precision` (slider de 0 a 1)
   - etc.

**Opción 2: Con EditorScript verificador**
1. En Godot, abre `res://addons/editor_scripts/check_blueprints.gd`
2. **File → Run** (o `Ctrl+Shift+X`)
3. Mira la consola — te dirá qué blueprints están OK y cuáles necesitan conversión

Si ves sliders editables, ¡funcionó! 🎉

---

## ❌ ¿Por qué no puedo ejecutarlo desde VS Code?

Los scripts `.gd` de Godot **no se ejecutan en VS Code**, solo en el editor de Godot. VS Code es solo un editor de texto para escribir código.

Para ejecutar:
- **Herramientas visuales** (scenes `.tscn`) → F6 en Godot
- **EditorScripts** → File → Run en Godot
- **El juego completo** → F5 en Godot

---

## 📖 Más información

Lee `doc/BLUEPRINT_DIFICULTAD_EDITOR.md` para:
- Ejemplos de configuraciones de dificultad
- Qué significa cada parámetro
- Cómo crear tus propias dificultades
- Troubleshooting completo
