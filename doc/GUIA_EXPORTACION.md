# Guía rápida de exportación - PetJam

## 🚀 Primera vez (Configuración inicial)

### 1. Instalar plantillas de exportación
1. Abre Godot
2. Ve a **Editor → Manage Export Templates**
3. Haz clic en **Download and Install**
4. Espera a que descargue las plantillas para Godot 4.5.1

### 2. Crear preset de exportación
1. Ve a **Project → Export...**
2. Haz clic en **Add...** → **Windows Desktop**
3. Configura:
   - ✅ Runnable
   - ✅ Embed PCK
   - ❌ Export With Debug (para release)
4. En **Resources → Filters to export non-resource files/folders**:
   ```
   *.wav, *.mp3, *.ogg
   ```
5. En **Exclude from export**:
   ```
   *.md, logs/*, doc/*, .git*, *.html
   ```
6. Haz clic en **Close**

### 3. Exportar manualmente (primera vez)
1. **Project → Export...**
2. Selecciona **Windows Desktop**
3. Haz clic en **Export Project...**
4. Elige carpeta: `builds/windows/`
5. Nombre: `PetJam.exe`
6. Haz clic en **Save**

---

## 🎯 Exportaciones posteriores

### Opción A: Desde Godot
1. **Project → Export...** → **Export Project...** → Save

### Opción B: Desde Terminal
```powershell
.\export_build.ps1
```

**IMPORTANTE**: Antes de ejecutar el script, edita la línea 7 de `export_build.ps1` con la ruta correcta de tu ejecutable de Godot:
```powershell
$GODOT_EXE = "C:\ruta\a\tu\Godot_v4.5.1-stable_win64.exe"
```

---

## 📦 Distribuir tu juego

Una vez exportado, comprime la carpeta `builds/windows/` en un ZIP:
- **PetJam.exe** (ejecutable principal)
- **PetJam.pck** (si no embebiste el PCK, aunque recomiendo embeber)

**Tamaño esperado**: ~50-200 MB dependiendo de los assets de audio/sprites.

---

## 🧪 Testing

Antes de distribuir:
1. ✅ Prueba el .exe en tu PC (cerrar Godot primero)
2. ✅ Prueba en otro PC Windows limpio (sin Godot instalado)
3. ✅ Verifica que el audio funcione
4. ✅ Verifica que los minijuegos carguen correctamente

---

## 🐛 Troubleshooting

### "No se encontraron plantillas de exportación"
→ Editor → Manage Export Templates → Download and Install

### "El .exe no arranca / pantalla negra"
→ Verifica en Project Settings → Application → Run → Main Scene que apunte a `res://scenes/Main.tscn`

### "Faltan texturas/sonidos"
→ En Export → Resources → asegúrate de incluir extensiones: `*.png, *.wav, *.mp3, *.tres`

### "Errores en consola"
→ Exporta con debug activado temporalmente para ver logs:
```powershell
& "C:\ruta\godot.exe" --path . --export-debug "Windows Desktop" builds/windows/PetJam.exe
```
