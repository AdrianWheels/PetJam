---
applyTo: "**"
---
# JSON & DataManager — Godot 4.5

## Objetivo
Asegurar lectura desde `res://data/*.json` y escritura solo en `user://save/*.json`. Uso de **GDScript** y API estable para `DataManager`.

## Reglas
- No escribas en `res://` en runtime. Solo `user://`.
- JSON válido: UTF‑8 sin BOM, sin comentarios ni comas finales.
- Lectura: `FileAccess.open(...).get_as_text()` → `JSON.parse_string(text)`.
- Escritura: `JSON.stringify(data, "  ")` para pretty; crea directorios con `DirAccess.make_dir_recursive_absolute(...)`.
- Data estática en `res://data/*.json`. Datos de guardado en `user://save/`.
- Mantén una **API única** para el autoload `DataManager`.

## Autoload `DataManager`
Crea `res://scripts/autoload/DataManager.gd` y regístralo en Project → Project Settings → AutoLoad como `DataManager`.

### Contrato de API
```gdscript
# res://scripts/autoload/DataManager.gd
extends Node
class_name DataManager

static func load_json(path: String, default_value: Variant = null) -> Variant:
    if not FileAccess.file_exists(path):
        return default_value
    var f := FileAccess.open(path, FileAccess.READ)
    var text := f.get_as_text()
    f.close()
    var data := JSON.parse_string(text)
    return data if data != null else default_value

static func save_json(path: String, data: Variant, pretty: bool = true) -> bool:
    assert(path.begins_with("user://"))
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var text := JSON.stringify(data, pretty ? "  " : "")
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string(text)
    f.close()
    return true