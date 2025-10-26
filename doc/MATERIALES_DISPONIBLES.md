# Materiales Disponibles en el Juego

## Lista Completa de Materiales

Los siguientes materiales están disponibles en `res://data/materials/`:

| ID | Nombre | Archivo |
|----|--------|---------|
| `cloth` | Tela | `cloth.tres` |
| `fire` | Fuego | `fire.tres` |
| `herb` | Hierba | `herb.tres` |
| `ice` | Hielo | `ice.tres` |
| `iron` | Hierro | `iron.tres` |
| `leather` | Cuero | `leather.tres` |
| `poison` | Veneno | `poison.tres` |
| `water` | Agua | `water.tres` |
| `wood` | Madera | `wood.tres` |

## Inventario Inicial

El jugador comienza con estos materiales (ver `InventoryManager.gd`):

```gdscript
{
	"wood": 40,
	"iron": 40,
	"leather": 40,
	"cloth": 40,
	"herb": 30,
	"fire": 20,
	"water": 20
}
```

## ⚠️ Materiales NO Existentes

Los siguientes IDs **NO** son materiales válidos y causarán errores:

- ❌ `bottle` (usar `water` en su lugar)
- ❌ `fiber` (usar `cloth` en su lugar)
- ❌ `gold` (NO es un material, es una moneda de recompensa)

## Estructura de MaterialResource

Cada material `.tres` tiene:

```gdscript
[ext_resource type="Script" path="res://scripts/data/MaterialResource.gd"]
[ext_resource type="Texture2D" path="res://art/assets/Imagenes/Materials/{material}.png"]

material_id = &"water"
display_name = "Agua"
description = "Descripción del material"
icon = ExtResource("2")
```

## Iconos

Los iconos están en: `res://art/assets/Imagenes/Materials/{material}.png`

Fallback si no existe el resource: `res://art/placeholders/forge/material_{id}.png`

## Uso en Código

```gdscript
# ✅ CORRECTO
InventoryManager.add_item("water", 10)
InventoryManager.add_item("iron", 5)

# ❌ INCORRECTO - causará error de recurso no encontrado
InventoryManager.add_item("bottle", 10)  # NO EXISTE
InventoryManager.add_item("fiber", 5)   # NO EXISTE
```

## Changelog

### 2025-10-26: Limpieza de materiales inválidos
- Removido "bottle" del inventario inicial → reemplazado por "water"
- Removido "fiber" del inventario inicial → reemplazado por "cloth"
- Removido "gold" del inventario inicial → no es un material
- Actualizado MATERIAL_NAMES en MaterialRow.gd para incluir todos los 9 materiales
