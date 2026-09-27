extends Control
class_name CraftResultScreen

## Pantalla de resultado de crafteo: el momento de revelar la calidad del objeto.
## Barra VERTICAL de metal fundido (shader de fuego) que se llena desde abajo; cada umbral de calidad
## (Bueno 40 %, Raro 70 %, Épico 90 %, Legendario 99 %) se enciende con destello, "punch" y un clinc
## cada vez más agudo. Al terminar, el objeto pasa de silueta a color con rayos, chispas y su tier.

signal result_dismissed(result: Dictionary)

const SK := preload("res://scripts/gameplay/visual/ShapeKit.gd")
const TICK_SFX := preload("res://art/sounds/sfx/minigames/hammer/hammer_good.wav")
const REVEAL_SFX := {
	"legendary": preload("res://art/sounds/sfx/craft/craft_gold.wav"),
	"epic": preload("res://art/sounds/sfx/craft/craft_gold.wav"),
	"rare": preload("res://art/sounds/sfx/craft/craft_silver.wav"),
	"uncommon": preload("res://art/sounds/sfx/craft/craft_bronze.wav"),
	"common": preload("res://art/sounds/sfx/craft/craft_bronze.wav"),
}

## Umbrales de calidad (mismos que CraftedItem/QualityHelper)
const TIERS := [
	{"id": "common", "at": 0.0, "name": "BÁSICO", "color": Color("cfd6dc")},
	{"id": "uncommon", "at": 0.40, "name": "BUENO", "color": Color("6ad16a")},
	{"id": "rare", "at": 0.70, "name": "RARO", "color": Color("4ea3ff")},
	{"id": "epic", "at": 0.90, "name": "ÉPICO", "color": Color("b46bff")},
	{"id": "legendary", "at": 0.99, "name": "LEGENDARIO", "color": Color("ffa629")},
]
const STAT_NAMES := {
	"damage": "Daño", "hp": "Vida", "armor": "Armadura", "crit": "Crítico",
	"aps": "Velocidad", "str": "Fuerza", "agi": "Agilidad", "int": "Intelecto",
}

const BAR_SIZE := Vector2(120, 540)

# Nodos internos (se crean en _build_ui)
var _bg: ColorRect
var _title_label: Label
var _item_name_label: Label
var _bar_frame: Panel
var _bar_clip: Control
var _quality_bar_fill: ColorRect
var _quality_percent_label: Label
var _tick_labels: Array[Label] = []
var _tick_marks: Array[ColorRect] = []
var _rays: Control
var _medallion: Panel
var _item_icon: TextureRect
var _tier_label: Label
var _stats_container: VBoxContainer
var _continue_container: VBoxContainer
var _continue_btn: Button
var _flash_rect: ColorRect
var _burst: CPUParticles2D

# Datos del resultado
var _result: Dictionary = {}
var _quality: float = 0.0
var _tier_index := 0
var _tier_color: Color = Color.WHITE
var _tier_name: String = ""

# Estado de animación
var _bar_tween: Tween
var _progress := 0.0
var _last_tier_crossed := 0
var _is_animating := false

# Energy shader
var _energy_shader: ShaderMaterial


class Rays extends Control:
	## Rayos de luz que giran detrás del objeto (aditivos)
	var color := Color(1, 0.8, 0.4)
	var strength := 0.0
	var count := 12
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if strength > 0.0:
			queue_redraw()
	func _draw() -> void:
		if strength <= 0.0:
			return
		var c := size * 0.5
		var r := size.x * 0.75
		for i in count:
			var a := _t * 0.35 + TAU * float(i) / float(count)
			var w := 0.09
			var pts := PackedVector2Array([c, c + Vector2(cos(a - w), sin(a - w)) * r, c + Vector2(cos(a + w), sin(a + w)) * r])
			var cols := PackedColorArray([Color(color.r, color.g, color.b, 0.55 * strength), Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, 0.0)])
			draw_polygon(pts, cols)


func _ready() -> void:
	_build_ui()
	# Empezar invisible para fade in
	modulate.a = 0.0


## Configura y muestra el resultado con animación
func show_result(result: Dictionary) -> void:
	_result = result
	_quality = clampf(result.get("quality", 0.0), 0.0, 1.0)
	_tier_index = _tier_for(_quality)
	# El tier final lo decide el objeto creado (mismo criterio que inventario, equipo y héroe)
	var item_for_tier = result.get("crafted_item")
	if item_for_tier is CraftedItem:
		var tier_id: String = item_for_tier.get_quality_tier()
		for i in TIERS.size():
			if TIERS[i].id == tier_id:
				_tier_index = i
	_tier_color = TIERS[_tier_index].color
	_tier_name = TIERS[_tier_index].name

	# Textos e icono
	var bp_id: String = str(result.get("blueprint_id", ""))
	var item_name := ""
	var icon: Texture2D = null
	var crafted_item = result.get("crafted_item")
	if crafted_item is CraftedItem:
		icon = crafted_item.get_icon()
	var dm = get_node_or_null("/root/DataManager")
	if dm:
		var bp = dm.get_blueprint(StringName(bp_id))
		if bp:
			if bp.display_name != "":
				item_name = bp.display_name
			if icon == null:
				icon = bp.get_icon()  # resuelve icon_path (bp.icon queda vacío al cargar)
	if item_name == "":
		item_name = bp_id.capitalize()
	_item_name_label.text = item_name
	_item_icon.texture = icon
	# Silueta mientras se templa: la calidad se revela al final
	_item_icon.modulate = Color(0.08, 0.06, 0.06, 1.0)

	var grade: String = result.get("grade", "")
	_title_label.text = _get_title_text(grade)

	_progress = 0.0
	_last_tier_crossed = 0
	_quality_percent_label.text = "0%"
	_tier_label.text = ""
	_tier_label.modulate.a = 0.0
	_rays.strength = 0.0
	for i in _tick_labels.size():
		_tick_labels[i].modulate = Color(1, 1, 1, 0.35)
	_set_fill_color(TIERS[0].color)

	_populate_stats(result)

	# Bonus de forjamagia si aplica
	var fm_bonus: float = result.get("forjamagia_bonus", 0.0)
	var fm_value: int = result.get("forjamagia", 0)
	if fm_bonus > 0.0:
		var fm_label := Label.new()
		fm_label.text = "Forjamagia %d/10 → +%d%% calidad" % [fm_value, int(fm_bonus * 100)]
		fm_label.add_theme_font_size_override("font_size", 24)
		fm_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		fm_label.add_theme_constant_override("outline_size", 5)
		fm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_container.add_child(fm_label)
	_stats_container.modulate.a = 0.0

	_animate_entrance()


func _tier_for(q: float) -> int:
	var percent := roundi(q * 100.0)  # igual que CraftedItem.get_quality_percent()
	var idx := 0
	for i in TIERS.size():
		if percent >= int(round(TIERS[i].at * 100.0)):
			idx = i
	return idx


func _get_title_text(grade: String) -> String:
	match grade:
		"gold":
			return "¡OBRA MAESTRA!"
		"silver":
			return "¡BUEN TRABAJO!"
		"bronze":
			return "TRABAJO COMPLETO"
		_:
			return "FORJADO"


func _animate_entrance() -> void:
	_is_animating = true
	_continue_container.visible = false
	var entrance_tween := create_tween()
	entrance_tween.set_ease(Tween.EASE_OUT)
	entrance_tween.set_trans(Tween.TRANS_CUBIC)
	entrance_tween.tween_property(self, "modulate:a", 1.0, 0.35)
	entrance_tween.tween_callback(_animate_quality_bar)


func _animate_quality_bar() -> void:
	# Duración proporcional a la calidad: las buenas piezas se hacen esperar un poco más
	var duration: float = lerpf(1.0, 2.4, _quality)
	if _bar_tween and _bar_tween.is_running():
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.set_ease(Tween.EASE_OUT)
	_bar_tween.set_trans(Tween.TRANS_QUART)
	_bar_tween.tween_method(_update_bar_progress, 0.0, _quality, duration)
	_bar_tween.tween_interval(0.15)
	_bar_tween.tween_callback(_show_tier_reveal)


func _update_bar_progress(progress: float) -> void:
	_progress = progress
	var inner_h := _bar_clip.get_parent_control().size.y
	var h := inner_h * progress
	_bar_clip.position.y = inner_h - h
	_bar_clip.size.y = h
	_quality_bar_fill.position.y = -(inner_h - h)
	_quality_percent_label.text = "%d%%" % roundi(progress * 100.0)
	var tier := _tier_for(progress)
	_set_fill_color(TIERS[tier].color)
	# Umbral cruzado: se enciende su marca, destello, punch y clinc más agudo
	if tier > _last_tier_crossed:
		_last_tier_crossed = tier
		_light_tick(tier)


func _set_fill_color(c: Color) -> void:
	_quality_bar_fill.color = c
	if _energy_shader:
		_energy_shader.set_shader_parameter("color_cold", c.darkened(0.55))
		_energy_shader.set_shader_parameter("color_warm", c.darkened(0.15))
		_energy_shader.set_shader_parameter("color_hot", c.lightened(0.25))
		_energy_shader.set_shader_parameter("color_core", c.lightened(0.6))


func _light_tick(tier: int) -> void:
	if tier < _tick_labels.size():
		var lbl := _tick_labels[tier]
		lbl.modulate = Color(1.6, 1.6, 1.6, 1.0)
		lbl.pivot_offset = lbl.size * Vector2(0.0, 0.5)
		var tw := create_tween()
		tw.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.06)
		tw.tween_property(lbl, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(lbl, "modulate", Color.WHITE, 0.3)
		_tick_marks[tier].color = TIERS[tier].color
	_flash(0.35)
	_bar_frame.pivot_offset = _bar_frame.size * 0.5
	var punch := create_tween()
	punch.tween_property(_bar_frame, "scale", Vector2(1.12, 1.03), 0.05)
	punch.tween_property(_bar_frame, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	_play(TICK_SFX, -8.0, 0.9 + 0.18 * float(tier))


func _flash(strength: float) -> void:
	_flash_rect.color.a = strength
	create_tween().tween_property(_flash_rect, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _show_tier_reveal() -> void:
	_is_animating = false
	_set_fill_color(_tier_color)

	# El objeto sale de la silueta con un fogonazo
	_medallion.pivot_offset = _medallion.size * 0.5
	var pop := create_tween()
	pop.tween_property(_item_icon, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.06)
	pop.tween_property(_item_icon, "modulate", Color.WHITE, 0.35)
	var scale_tw := create_tween()
	scale_tw.tween_property(_medallion, "scale", Vector2(1.18, 1.18), 0.08)
	scale_tw.tween_property(_medallion, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var med_style := _medallion.get_theme_stylebox("panel") as StyleBoxFlat
	if med_style:
		med_style.border_color = _tier_color
	_flash(0.55)

	# Rayos solo a partir de Raro (una pieza básica no merece fanfarria) y chispas del color del tier
	_rays.color = _tier_color
	var ray_strength: float = [0.0, 0.12, 0.45, 0.7, 0.95][_tier_index]
	if ray_strength > 0.0:
		create_tween().tween_property(_rays, "strength", ray_strength, 0.4)
	_burst.color = _tier_color.lightened(0.2)
	_burst.amount = 30 + 12 * _tier_index
	_burst.restart()
	_burst.emitting = true

	# Tier
	_tier_label.text = _tier_name
	_tier_label.add_theme_color_override("font_color", _tier_color)
	_tier_label.scale = Vector2(0.3, 0.3)
	_tier_label.pivot_offset = _tier_label.size / 2.0
	var tier_tween := create_tween()
	tier_tween.set_ease(Tween.EASE_OUT)
	tier_tween.set_trans(Tween.TRANS_BACK)
	tier_tween.tween_property(_tier_label, "modulate:a", 1.0, 0.25)
	tier_tween.parallel().tween_property(_tier_label, "scale", Vector2.ONE, 0.45)
	tier_tween.parallel().tween_property(_stats_container, "modulate:a", 1.0, 0.4).set_delay(0.15)
	tier_tween.tween_callback(func():
		_continue_container.visible = true
		_continue_container.modulate.a = 0.0
		create_tween().tween_property(_continue_container, "modulate:a", 1.0, 0.3)
	)
	_play(REVEAL_SFX.get(TIERS[_tier_index].id), -6.0, 1.0)


func _populate_stats(result: Dictionary) -> void:
	for child in _stats_container.get_children():
		child.queue_free()
	var crafted_item = result.get("crafted_item")
	if crafted_item == null or not (crafted_item is CraftedItem):
		return
	var stats: Dictionary = crafted_item.calculated_stats
	for key in stats:
		var value = stats[key]
		if typeof(value) == TYPE_FLOAT and value < 0.01:
			continue
		if typeof(value) == TYPE_INT and value == 0:
			continue
		var stat_label := Label.new()
		var display_name: String = STAT_NAMES.get(key, String(key).capitalize())
		if key == "crit":
			stat_label.text = "+%d%% %s" % [roundi(float(value) * 100.0), display_name]
		elif key == "aps":
			stat_label.text = "+%.2f %s" % [float(value), display_name]
		else:
			stat_label.text = "+%d %s" % [roundi(float(value)), display_name]
		stat_label.add_theme_font_size_override("font_size", 30)
		stat_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
		stat_label.add_theme_constant_override("outline_size", 5)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_container.add_child(stat_label)


func _on_continue_pressed() -> void:
	if _continue_btn:
		_continue_btn.disabled = true
	var exit_tween := create_tween()
	exit_tween.set_ease(Tween.EASE_IN)
	exit_tween.set_trans(Tween.TRANS_CUBIC)
	exit_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	exit_tween.tween_callback(func():
		emit_signal("result_dismissed", _result)
		queue_free()
	)


func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null or stream == null:
		return
	if am.has_method("play_sfx_pitched"):
		am.play_sfx_pitched(stream, volume_db, pitch, 0.0)
	else:
		am.play_sfx(stream, volume_db)


func _label(size: int, color: Color, outline: int = 8) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _build_ui() -> void:
	# Fondo: tonos de la forja
	_bg = ColorRect.new()
	_bg.color = Color(0.06, 0.04, 0.035, 0.96)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	_title_label = _label(64, Color(1.0, 0.85, 0.4), 10)
	_title_label.text = "FORJADO"
	main_vbox.add_child(_title_label)

	_item_name_label = _label(38, Color(0.93, 0.88, 0.8), 6)
	main_vbox.add_child(_item_name_label)

	# Cuerpo: barra vertical a la izquierda, objeto a la derecha
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 30)
	main_vbox.add_child(body)
	_build_bar(body)
	_build_showcase(body)

	# Botón continuar
	_continue_container = VBoxContainer.new()
	_continue_container.add_theme_constant_override("separation", 8)
	_continue_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_continue_container.visible = false
	main_vbox.add_child(_continue_container)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_continue_container.add_child(btn_row)
	_continue_btn = Button.new()
	_continue_btn.text = "AL INVENTARIO"
	_continue_btn.custom_minimum_size = Vector2(460, 104)
	_continue_btn.add_theme_font_size_override("font_size", 36)
	_continue_btn.pressed.connect(_on_continue_pressed)
	btn_row.add_child(_continue_btn)
	var hint_label := _label(22, Color(0.7, 0.62, 0.52), 4)
	hint_label.text = "Equípalo desde «Equipo» · véndelo en «Tienda»"
	_continue_container.add_child(hint_label)

	# Destello a pantalla completa (encima de todo)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 0.95, 0.85, 0.0)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)


func _build_bar(parent: Control) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(column)

	_quality_percent_label = _label(56, Color.WHITE, 10)
	_quality_percent_label.text = "0%"
	column.add_child(_quality_percent_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)

	# Marco de la barra (crisol)
	_bar_frame = Panel.new()
	_bar_frame.custom_minimum_size = BAR_SIZE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.04, 0.03, 0.03, 1)
	frame_style.border_color = Color(0.55, 0.41, 0.24, 1)
	frame_style.set_border_width_all(5)
	frame_style.set_corner_radius_all(22)
	frame_style.shadow_color = Color(0, 0, 0, 0.5)
	frame_style.shadow_size = 10
	_bar_frame.add_theme_stylebox_override("panel", frame_style)
	row.add_child(_bar_frame)

	var inner := Control.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 10
	inner.offset_top = 10
	inner.offset_right = -10
	inner.offset_bottom = -10
	inner.clip_contents = true
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_frame.add_child(inner)

	# El recorte crece desde abajo; el relleno mantiene su tamaño para que el fuego no se estire
	_bar_clip = Control.new()
	_bar_clip.clip_contents = true
	_bar_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_clip.position = Vector2(0, BAR_SIZE.y - 20.0)
	_bar_clip.size = Vector2(BAR_SIZE.x - 20.0, 0.0)
	inner.add_child(_bar_clip)
	_quality_bar_fill = ColorRect.new()
	_quality_bar_fill.size = BAR_SIZE - Vector2(20, 20)
	_quality_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_clip.add_child(_quality_bar_fill)
	var shader := load("res://shaders/energy_bar_fill.gdshader")
	if shader:
		_energy_shader = ShaderMaterial.new()
		_energy_shader.shader = shader
		_energy_shader.set_shader_parameter("fire_speed", 1.1)
		_energy_shader.set_shader_parameter("flame_intensity", 1.4)
		_energy_shader.set_shader_parameter("turbulence", 0.8)
		_quality_bar_fill.material = _energy_shader

	# Marcas de umbral y sus nombres
	var ticks := Control.new()
	ticks.custom_minimum_size = Vector2(190, BAR_SIZE.y)
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ticks)
	var inner_h := BAR_SIZE.y - 20.0
	for i in TIERS.size():
		var t: Dictionary = TIERS[i]
		var y: float = 10.0 + inner_h * (1.0 - float(t.at))
		var mark := ColorRect.new()
		mark.color = Color(0.35, 0.28, 0.22)
		mark.position = Vector2(-(BAR_SIZE.x + 10.0) + 6.0, y - 2.0)
		mark.size = Vector2(BAR_SIZE.x - 12.0, 4)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.visible = i > 0
		ticks.add_child(mark)
		_tick_marks.append(mark)
		var lbl := _label(24, t.color, 5)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.text = "%s %d%%" % [t.name, int(round(t.at * 100.0))] if i > 0 else t.name
		lbl.position = Vector2(4, y - 18.0)
		lbl.size = Vector2(190, 36)
		lbl.modulate = Color(1, 1, 1, 0.35)
		ticks.add_child(lbl)
		_tick_labels.append(lbl)


func _build_showcase(parent: Control) -> void:
	var show := VBoxContainer.new()
	show.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	show.alignment = BoxContainer.ALIGNMENT_CENTER
	show.add_theme_constant_override("separation", 10)
	parent.add_child(show)

	var stage := CenterContainer.new()
	stage.custom_minimum_size = Vector2(0, 360)
	show.add_child(stage)

	# Rayos detrás del medallón
	var stage_inner := Control.new()
	stage_inner.custom_minimum_size = Vector2(340, 340)
	stage_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(stage_inner)
	_rays = Rays.new()
	_rays.material = SK.additive_material()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.position = Vector2(-160, -160)
	_rays.size = Vector2(660, 660)
	stage_inner.add_child(_rays)

	_medallion = Panel.new()
	var med := StyleBoxFlat.new()
	med.bg_color = Color(0.9, 0.82, 0.64, 1)
	med.border_color = Color(0.55, 0.41, 0.24, 1)
	med.set_border_width_all(8)
	med.set_corner_radius_all(170)
	med.shadow_color = Color(0, 0, 0, 0.55)
	med.shadow_size = 16
	_medallion.add_theme_stylebox_override("panel", med)
	_medallion.size = Vector2(340, 340)
	_medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_inner.add_child(_medallion)
	_item_icon = TextureRect.new()
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item_icon.offset_left = 40
	_item_icon.offset_top = 40
	_item_icon.offset_right = -40
	_item_icon.offset_bottom = -40
	_item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion.add_child(_item_icon)

	# Chispas al revelar
	_burst = CPUParticles2D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.amount = 40
	_burst.lifetime = 1.1
	_burst.position = Vector2(170, 170)
	_burst.direction = Vector2(0, -1)
	_burst.spread = 180.0
	_burst.gravity = Vector2(0, 520)
	_burst.initial_velocity_min = 260.0
	_burst.initial_velocity_max = 620.0
	_burst.scale_amount_min = 0.08
	_burst.scale_amount_max = 0.22
	_burst.texture = SK.glow_texture()
	_burst.material = SK.additive_material()
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	_burst.color_ramp = ramp
	stage_inner.add_child(_burst)

	_tier_label = _label(64, Color.WHITE, 10)
	_tier_label.modulate.a = 0.0
	show.add_child(_tier_label)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 2)
	show.add_child(_stats_container)
