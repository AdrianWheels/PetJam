extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas de textos e idiomas (solo desarrollo), sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/TextTests.tscn
## El texto base del juego es el español (datos, código y escenas). locale/textos.csv lleva la traducción
## al inglés con la cabecera keys,es,en: la clave es el texto en español tal cual, la columna es la repite
## y la columna en lleva el inglés. El juego usa el idioma del móvil; con cualquier otro idioma que no sea
## español ni inglés se ve el inglés (internationalization/locale/fallback="en").
## Las pruebas que cambian de idioma dejan puesto el que había al terminar.

const CSV_PATH := "res://locale/textos.csv"
const CSV_HEADER := "keys,es,en"
const TRANSLATIONS := ["res://locale/textos.es.translation", "res://locale/textos.en.translation"]
const LIBRARY_PATH := "res://data/blueprints/BlueprintLibrary.tres"
const ITEMS_DIR := "res://data/items/"
const MATERIALS_DIR := "res://data/materials/"

## Palabras que delatan un texto en inglés. Se buscan como palabra entera, sin mirar mayúsculas.
const ENGLISH_WORDS := ["basic", "advanced", "master", "masterwork", "sword", "shield", "helmet", "boots",
	"iron", "wood", "leather", "cloth", "fire", "water", "ice", "poison", "herb", "the"]

## Escenas vivas con texto: cada texto con palabras tiene fila en el CSV.
const LIVE_SCENES := [
	"res://scenes/UI/StartScreen.tscn", "res://scenes/UI/HUD_Main.tscn", "res://scenes/UI/EquipmentPanel.tscn",
	"res://scenes/UI/BlueprintLibraryPanel.tscn", "res://scenes/UI/BlueprintCard.tscn",
	"res://scenes/UI/RequestSlot.tscn", "res://scenes/UI/ShopPanel.tscn",
	"res://scenes/Minigames/ForgeTemp.tscn", "res://scenes/Minigames/HammerMinigame.tscn",
	"res://scenes/Minigames/SewOSU.tscn", "res://scenes/Minigames/QuenchWater.tscn",
]
## Textos de esas escenas que no llevan fila: el título del juego (no se traduce) y los que el código
## sustituye antes de enseñarlos.
const SCENE_PLACEHOLDERS := ["AFK ARMORY", "Vida 100", "Daño 10", "Armadura 0", "Crítico 5%",
	"Gareth el Cazador", "Progreso: 0/3", "Puntos: 0", "Progreso: 0/5", "Combo: 0"]

## Scripts que pintan en la franja con PixelFont: sus tr("…") son los textos fijos de la franja.
const STRIP_SCRIPTS := ["res://scripts/gameplay/Corridor.gd", "res://scripts/gameplay/CombatController.gd",
	"res://scripts/gameplay/visual/CombatFX.gd", "res://scripts/gameplay/Hero.gd", "res://scripts/gameplay/Enemy.gd"]

var _csv := {}  # clave → texto en inglés
var _csv_loaded := false


# ─── Ayudantes ─────────────────────────────────────────────────────────

## Filas del CSV como clave → inglés (vacío si el fichero no existe).
func _table() -> Dictionary:
	if _csv_loaded:
		return _csv
	_csv_loaded = true
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return _csv
	f.get_line()  # cabecera
	while true:
		var row := f.get_csv_line()
		if f.eof_reached() and row.size() == 1 and row[0] == "":
			break
		if row.size() == 3:
			_csv[row[0]] = row[2]
		if f.eof_reached():
			break
	return _csv


## true si el texto tiene fila con la columna en rellena.
func _has_row(text: String) -> bool:
	return String(_table().get(text, "")).strip_edges() != ""


## Palabras de ENGLISH_WORDS que aparecen en el texto (palabras enteras, sin mirar mayúsculas).
func _english_words_in(text: String) -> Array:
	var found := []
	for word in _words(text):
		if word in ENGLISH_WORDS and not found.has(word):
			found.append(word)
	return found


## Palabras del texto en minúsculas (una letra es un carácter con mayúscula y minúscula distintas).
func _words(text: String) -> Array:
	var words := []
	var current := ""
	for i in text.length():
		var c := text.substr(i, 1)
		if c.to_lower() != c.to_upper():
			current += c.to_lower()
		elif current != "":
			words.append(current)
			current = ""
	if current != "":
		words.append(current)
	return words


## true si el texto tiene alguna palabra (dos letras seguidas): "°C", "X" o "95" no se traducen.
func _has_word(text: String) -> bool:
	for word in _words(text):
		if word.length() >= 2:
			return true
	return false


## Ficheros .tres de una carpeta (rutas completas).
func _tres_in(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			out.append(dir + file)
	return out


## Textos visibles de los datos: los planos de la librería (nombre, descripción, sus pruebas y las
## etiquetas de sus configuraciones), los objetos y los materiales. Cada entrada: [texto, origen].
func _data_texts() -> Array:
	var out := []
	var library = load(LIBRARY_PATH)
	for bp in library.blueprints:
		var where := String(bp.blueprint_id)
		out.append([bp.display_name, where + ".display_name"])
		out.append([bp.description, where + ".description"])
		for trial in bp.trial_sequence:
			var trial_where := "%s/%s" % [where, trial.trial_id]
			out.append([trial.display_name, trial_where + ".display_name"])
			var cfg = trial.config
			if cfg == null:
				continue
			if "label" in cfg:
				out.append([String(cfg.label), trial_where + ".config.label"])
			if cfg.parameters.has("label"):
				out.append([String(cfg.parameters["label"]), trial_where + ".config.parameters.label"])
	for path in _tres_in(ITEMS_DIR) + _tres_in(MATERIALS_DIR):
		var res = load(path)
		out.append([res.display_name, path.get_file() + ".display_name"])
		out.append([res.description, path.get_file() + ".description"])
	return out


## Constantes de un script (vacío si no se puede cargar).
func _consts(path: String) -> Dictionary:
	var script = load(path)
	return script.get_script_constant_map() if script else {}


## Textos base de las tablas del código que se enseñan traducidos. Cada entrada: [texto, origen].
func _code_table_texts() -> Array:
	var out := []
	for id in EnemyArchetypes.DATA:
		out.append([String(EnemyArchetypes.DATA[id].name), "EnemyArchetypes.DATA.%s" % id])
	for boss in EnemyArchetypes.BOSS_NAMES:
		out.append([String(boss), "EnemyArchetypes.BOSS_NAMES"])
	for biome in Biomes.LIST:
		out.append([String(biome.name), "Biomes.LIST"])
	for t in CraftResultScreen.TIERS:
		out.append([String(t.name), "CraftResultScreen.TIERS"])
	for key in CraftResultScreen.STAT_NAMES:
		out.append([String(CraftResultScreen.STAT_NAMES[key]), "CraftResultScreen.STAT_NAMES"])
	var equipment := _consts("res://scripts/ui/EquipmentPanel.gd")
	for table in ["TIER_NAMES", "SLOT_NAMES"]:
		var names: Dictionary = equipment.get(table, {})
		for key in names:
			out.append([String(names[key]), "EquipmentPanel.%s" % table])
	for id in ShopPanel.MATERIAL_CATALOG:
		out.append([String(ShopPanel.MATERIAL_CATALOG[id].display_name), "ShopPanel.MATERIAL_CATALOG"])
	for id in ShopPanel.POTION_CATALOG:
		out.append([String(ShopPanel.POTION_CATALOG[id].display_name), "ShopPanel.POTION_CATALOG"])
		out.append([String(ShopPanel.POTION_CATALOG[id].description), "ShopPanel.POTION_CATALOG"])
	var buffs: Dictionary = _consts("res://scripts/ui/HeroViewOverlay.gd").get("BUFF_LABELS", {})
	for id in buffs:
		out.append([String(buffs[id][0]), "HeroViewOverlay.BUFF_LABELS"])
	var titles: Array = _consts("res://scripts/autoload/RequestsManager.gd").get("CLIENT_TITLES", [])
	check(not titles.is_empty(), "RequestsManager declara CLIENT_TITLES")
	for t in titles:
		for gender in t:
			out.append([String(t[gender]), "RequestsManager.CLIENT_TITLES"])
	var qualities: Dictionary = _consts("res://scripts/ui/MinigameFX.gd").get("QUALITY_TEXT", {})
	check(qualities.size() == 4, "MinigameFX.QUALITY_TEXT da texto a las cuatro calidades (%d)" % qualities.size())
	for q in qualities:
		out.append([String(qualities[q]), "MinigameFX.QUALITY_TEXT"])
	var mat_names: Dictionary = _consts("res://scripts/ui/MaterialRow.gd").get("MATERIAL_NAMES", {})
	for id in mat_names:
		out.append([String(mat_names[id]), "MaterialRow.MATERIAL_NAMES"])
	return out


## Literales de las llamadas tr("…") de un script.
func _tr_literals(path: String) -> Array:
	var out := []
	var re := RegEx.create_from_string("\\btr\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)")
	for m in re.search_all(FileAccess.get_file_as_string(path)):
		out.append(m.get_string(1).c_unescape())
	return out


## Scripts del juego (sin herramientas ni pruebas).
func _game_scripts(dir: String = "res://scripts/") -> Array:
	var out := []
	for sub in DirAccess.get_directories_at(dir):
		if dir == "res://scripts/" and sub in ["tools", "tests"]:
			continue
		out.append_array(_game_scripts(dir + sub + "/"))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir + file)
	return out


## Formatos (%d, %s, %.0f, %%…) de un texto, ordenados: la traducción tiene que llevar los mismos.
## Un "%" suelto seguido de espacio ("50 % más") es texto, no formato.
func _formats(text: String) -> Array:
	var out := []
	var re := RegEx.create_from_string("%(?:%|[-+0-9.]*[a-zA-Z])")
	for m in re.search_all(text):
		out.append(m.get_string())
	out.sort()
	return out


## Caracteres del texto (ya en mayúsculas, como lo pinta PixelFont) que no tiene la fuente.
func _missing_pixel_chars(text: String, font: FontFile) -> String:
	var missing := ""
	var upper := text.to_upper()
	for i in upper.length():
		var c := upper.substr(i, 1)
		if not font.has_char(upper.unicode_at(i)) and not missing.contains(c):
			missing += c
	return missing


# ─── Datos en español ──────────────────────────────────────────────────

func test_los_datos_visibles_estan_en_espanol() -> void:
	var library = load(LIBRARY_PATH)
	check(library.blueprints.size() == 12, "la librería carga 12 planos (%d)" % library.blueprints.size())
	check(_tres_in(ITEMS_DIR).size() == 12, "hay 12 objetos (%d)" % _tres_in(ITEMS_DIR).size())
	check(_tres_in(MATERIALS_DIR).size() == 9, "hay 9 materiales (%d)" % _tres_in(MATERIALS_DIR).size())
	for entry in _data_texts():
		var text: String = entry[0]
		check(text.strip_edges() != "", "%s está vacío" % entry[1])
		var english := _english_words_in(text)
		check(english.is_empty(), "%s está en inglés: «%s» (%s)" % [entry[1], text, ", ".join(english)])


func test_los_datos_visibles_tienen_fila_en_el_csv() -> void:
	for entry in _data_texts():
		check(_has_row(entry[0]), "%s («%s») no tiene fila con inglés en %s" % [entry[1], entry[0], CSV_PATH])


# ─── CSV y registro en el proyecto ─────────────────────────────────────

func test_el_csv_esta_bien_formado() -> void:
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	check(f != null, "existe %s" % CSV_PATH)
	if f == null:
		return
	var header := f.get_line()
	check(header == CSV_HEADER, "cabecera exacta «%s» («%s»)" % [CSV_HEADER, header])
	var seen := {}
	var line := 1
	while true:
		var row := f.get_csv_line()
		if f.eof_reached() and row.size() == 1 and row[0] == "":
			break
		line += 1
		check(row.size() == 3, "la fila %d tiene 3 columnas (%s)" % [line, row])
		if row.size() == 3:
			var key: String = row[0]
			check(key != "" and key == key.strip_edges(), "la fila %d tiene clave sin espacios sobrantes («%s»)" % [line, key])
			check(not seen.has(key), "clave repetida: «%s»" % key)
			check(row[1] == key, "la columna es repite la clave en «%s» («%s»)" % [key, row[1]])
			check(row[2].strip_edges() != "" and row[2] == row[2].strip_edges(), "«%s» tiene inglés sin espacios sobrantes («%s»)" % [key, row[2]])
			check(_formats(row[2]) == _formats(key), "«%s» y «%s» llevan los mismos formatos" % [key, row[2]])
			seen[key] = row[2]
		if f.eof_reached():
			break
	check(seen.size() >= 150, "el CSV tiene las filas del juego (%d)" % seen.size())
	# Un Label traduce su texto: si el inglés de una fila fuera la clave de otra, se traduciría dos veces
	for key in seen:
		var en: String = seen[key]
		if seen.has(en) and seen[en] != en:
			check(false, "«%s» → «%s», que es la clave de otra fila (→ «%s»)" % [key, en, seen[en]])


func test_el_proyecto_registra_las_traducciones() -> void:
	var list: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	for path in TRANSLATIONS:
		check(list.has(path), "project.godot registra %s (%s)" % [path, list])
		check(ResourceLoader.exists(path), "existe %s (sale de importar el CSV)" % path)
	check(String(ProjectSettings.get_setting("internationalization/locale/fallback", "")) == "en", "el idioma de reserva es el inglés")
	check(String(ProjectSettings.get_setting("internationalization/locale/test", "")) == "", "project.godot no fuerza ningún idioma de prueba")
	var loaded := TranslationServer.get_loaded_locales()
	check(loaded.has("es") and loaded.has("en"), "cargan las traducciones es y en (%s)" % loaded)


func test_el_ingles_sale_de_la_traduccion() -> void:
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	check(tr("Espada básica") == "Basic Sword", "en: Espada básica → «%s»" % tr("Espada básica"))
	check(tr("Hierro") == "Iron", "en: Hierro → «%s»" % tr("Hierro"))
	check(tr("Cripta Musgosa") == "Mossy Crypt", "en: Cripta Musgosa → «%s»" % tr("Cripta Musgosa"))
	check(tr("Rey Osario") == "Bone King", "en: Rey Osario → «%s»" % tr("Rey Osario"))
	check(tr("Limo") == "Slime", "en: Limo → «%s»" % tr("Limo"))
	TranslationServer.set_locale("es")
	check(tr("Espada básica") == "Espada básica", "es: Espada básica → «%s»" % tr("Espada básica"))
	check(tr("Hierro") == "Hierro", "es: Hierro → «%s»" % tr("Hierro"))
	TranslationServer.set_locale("es_MX")
	check(tr("Escudo maestro") == "Escudo maestro", "es_MX usa el español («%s»)" % tr("Escudo maestro"))
	TranslationServer.set_locale("fr")
	check(tr("Espada básica") == "Basic Sword", "un móvil en francés ve el inglés («%s»)" % tr("Espada básica"))
	# Cada fila del CSV llega a las traducciones importadas (una fila mal escrita se saltaría sin avisar)
	var table := _table()
	check(table.size() >= 150, "el CSV se lee (%d filas)" % table.size())
	for locale in ["en", "es"]:
		TranslationServer.set_locale(locale)
		var wrong := []
		for key in table:
			var expected: String = table[key] if locale == "en" else key
			if tr(key) != expected:
				wrong.append("«%s» → «%s»" % [key, tr(key)])
		check(wrong.is_empty(), "%s: todas las filas se traducen bien (%s)" % [locale, ", ".join(wrong)])
	TranslationServer.set_locale(before)
	check(TranslationServer.get_locale() == before, "se deja el idioma que había (%s)" % before)


# ─── Todo lo visible tiene traducción ──────────────────────────────────

func test_las_tablas_del_codigo_estan_en_espanol_y_tienen_fila() -> void:
	for entry in _code_table_texts():
		check(_english_words_in(entry[0]).is_empty(), "%s está en inglés: «%s»" % [entry[1], entry[0]])
		check(_has_row(entry[0]), "%s: «%s» no tiene fila con inglés" % [entry[1], entry[0]])


func test_cada_tr_del_codigo_tiene_fila() -> void:
	var count := 0
	for path in _game_scripts():
		for key in _tr_literals(path):
			count += 1
			check(_has_row(key), "%s: tr(«%s») no tiene fila con inglés" % [path.get_file(), key])
			check(_english_words_in(key).is_empty(), "%s: tr(«%s») está en inglés" % [path.get_file(), key])
	check(count >= 80, "los textos del código pasan por tr() (%d)" % count)


func test_los_textos_de_las_escenas_vivas_tienen_fila() -> void:
	var re := RegEx.create_from_string("(?m)^(text|tooltip_text) = \"((?:[^\"\\\\]|\\\\.)*)\"")
	var with_row := 0
	for path in LIVE_SCENES:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			var text := m.get_string(2).c_unescape()
			if not _has_word(text):
				continue
			check(_english_words_in(text).is_empty(), "%s: «%s» está en inglés" % [path.get_file(), text])
			if text in SCENE_PLACEHOLDERS:
				continue
			with_row += 1
			check(_has_row(text), "%s: «%s» no tiene fila con inglés" % [path.get_file(), text])
	check(with_row >= 25, "se revisan los textos de las escenas (%d)" % with_row)


# ─── Franja pixel ──────────────────────────────────────────────────────

func test_la_fuente_pixel_tiene_las_letras_de_la_franja_en_los_dos_idiomas() -> void:
	# La consulta tiene que distinguir: la fuente no tiene "@" ni minúsculas con tilde
	check(not PixelFont.small().has_char("@".unicode_at(0)) and not PixelFont.big().has_char("é".unicode_at(0)), "has_char detecta las letras que faltan")
	check(PixelFont.small().has_char("Ñ".unicode_at(0)) and PixelFont.big().has_char("¡".unicode_at(0)), "has_char encuentra las que hay")
	var fixed := []
	for path in STRIP_SCRIPTS:
		fixed.append_array(_tr_literals(path))
	check(fixed.size() >= 4, "los textos fijos de la franja pasan por tr() (%s)" % [fixed])
	var texts := fixed.duplicate()
	for id in EnemyArchetypes.DATA:
		texts.append(String(EnemyArchetypes.DATA[id].name))
	texts.append_array(EnemyArchetypes.BOSS_NAMES)
	for biome in Biomes.LIST:
		texts.append(String(biome.name))
	for path in _tres_in(MATERIALS_DIR):
		texts.append(String(load(path).display_name))
	texts.append(String(_consts("res://scripts/gameplay/Hero.gd").get("HERO_NAME", "")))
	var fmt := RegEx.create_from_string("%[-+0-9.]*[a-zA-Z]")
	var before := TranslationServer.get_locale()
	for locale in ["es", "en"]:
		TranslationServer.set_locale(locale)
		for base in texts:
			var shown := fmt.sub(tr(base), "", true)  # los huecos (%s, %d) se prueban con sus valores
			for font in [PixelFont.small(), PixelFont.big()]:
				var missing := _missing_pixel_chars(shown, font)
				check(missing == "", "%s: a la fuente pixel le falta «%s» para «%s»" % [locale, missing, tr(base).to_upper()])
		# El nombre de jefe más largo, con su nivel, cabe en la franja en los dos idiomas
		for boss in EnemyArchetypes.BOSS_NAMES:
			var label := tr("%s Nv %d") % [tr(boss), 150]
			check(PixelFont.width(label) < int(PixelView.VIEW_W), "%s: «%s» cabe en la franja" % [locale, label.to_upper()])
	TranslationServer.set_locale(before)


# ─── Calidades y nombres compuestos ────────────────────────────────────

func test_las_calidades_de_crafted_item_son_las_del_resultado() -> void:
	var before := TranslationServer.get_locale()
	for locale in ["es", "en"]:
		TranslationServer.set_locale(locale)
		for t in CraftResultScreen.TIERS:
			var item := CraftedItem.new(null, float(t.at) + 0.005)
			check(item.get_quality_tier() == t.id, "%s: %d %% es %s (%s)" % [locale, item.get_quality_percent(), t.id, item.get_quality_tier()])
			var expected: String = tr(t.name) if locale == "en" else String(t.name)
			check(item.get_quality_label() == expected, "%s: la calidad %s se llama «%s» («%s»)" % [locale, t.id, expected, item.get_quality_label()])
	TranslationServer.set_locale(before)


func test_los_nombres_compuestos_salen_en_el_idioma_del_movil() -> void:
	var before := TranslationServer.get_locale()
	var sword := CraftedItem.new(load("res://data/items/sword_basic.tres"), 0.5)
	var rm := get_node("/root/RequestsManager")
	var brenna := {"client_name": "Brenna la Guerrera", "client_first": "Brenna", "client_title": "la Guerrera"}
	TranslationServer.set_locale("es")
	check(sword.get_display_name() == "Espada básica (50%)", "es: «%s»" % sword.get_display_name())
	check(CraftedItem.new(null, 0.5).get_display_name() == "Objeto desconocido", "es: objeto sin recurso")
	check(Biomes.display_name(1) == "Cripta Musgosa" and Biomes.display_name(6) == "Cripta Musgosa II", "es: biomas «%s», «%s»" % [Biomes.display_name(1), Biomes.display_name(6)])
	check(rm.client_display_name(brenna) == "Brenna la Guerrera", "es: cliente «%s»" % rm.client_display_name(brenna))
	TranslationServer.set_locale("en")
	check(sword.get_display_name() == "Basic Sword (50%)", "en: «%s»" % sword.get_display_name())
	check(CraftedItem.new(null, 0.5).get_display_name() == "Unknown item", "en: objeto sin recurso")
	check(Biomes.display_name(1) == "Mossy Crypt" and Biomes.display_name(6) == "Mossy Crypt II", "en: biomas «%s», «%s»" % [Biomes.display_name(1), Biomes.display_name(6)])
	check(rm.client_display_name(brenna) == "Brenna the Warrior", "en: cliente «%s»" % rm.client_display_name(brenna))
	TranslationServer.set_locale(before)


func test_los_titulos_de_cliente_concuerdan_con_el_nombre() -> void:
	var rm := get_node("/root/RequestsManager")
	var consts := _consts("res://scripts/autoload/RequestsManager.gd")
	var names: Dictionary = consts.get("CLIENT_NAMES", {})
	var titles: Array = consts.get("CLIENT_TITLES", [])
	check(names.size() == 8 and titles.size() == 6, "8 nombres y 6 títulos (%d, %d)" % [names.size(), titles.size()])
	for first in names:
		check(names[first] in ["m", "f"], "%s tiene género m o f («%s»)" % [first, names[first]])
	for t in titles:
		check(String(t.get("m", "")).begins_with("el ") and String(t.get("f", "")).begins_with("la "), "título con «el» y «la»: %s" % t)
	for i in 40:
		var client: Dictionary = rm._generate_client()
		var first: String = client.get("client_first", "")
		var title: String = client.get("client_title", "")
		var gender: String = names.get(first, "")
		check(titles.any(func(t): return t.get(gender, "") == title), "«%s %s» concuerda en género" % [first, title])
		check(client.get("client_name", "") == "%s %s" % [first, title], "el nombre completo es «%s %s» («%s»)" % [first, title, client.get("client_name", "")])
