extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas de juego (economía, tienda e inventario), solo desarrollo, sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/GameplayTests.tscn


# ─── Materiales ────────────────────────────────────────────────────────

## Materiales que pide algún plano de la librería.
func _materials_used_by_blueprints() -> Dictionary:
	var used := {}
	var dm := get_node("/root/DataManager")
	for bp in dm.get_all_blueprints().values():
		for mat_id in bp.materials:
			used[StringName(mat_id)] = true
	return used


func test_shop_only_sells_materials_that_blueprints_use() -> void:
	var used := _materials_used_by_blueprints()
	check(not used.is_empty(), "la librería de planos debe pedir materiales")
	for mat_id in ShopPanel.MATERIAL_CATALOG:
		check(used.has(StringName(mat_id)), "la tienda vende «%s», que no pide ningún plano" % mat_id)


func test_starting_materials_are_used_by_blueprints() -> void:
	var used := _materials_used_by_blueprints()
	var im := get_node("/root/InventoryManager")
	check(not im.STARTING_MATERIALS.is_empty(), "debe haber materiales de inicio")
	for mat_id in im.STARTING_MATERIALS:
		check(used.has(StringName(mat_id)), "se regala «%s» al empezar, pero no lo pide ningún plano" % mat_id)
