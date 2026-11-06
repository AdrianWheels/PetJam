extends Node2D

## Una capa del escenario: dibuja UNA baldosa de ancho `tile_width` y el Parallax2D padre la repite.
## El contenido se redibuja solo al cambiar de paleta (el resto del tiempo lo cachea el motor).
## `kind` decide qué dibuja: "sky", "far", "wall", "pillars", "floor", "front".

const SK := preload("res://scripts/gameplay/visual/ShapeKit.gd")

var kind: String = "wall"
var tile_width: float = 1080.0
var view_height: float = 480.0
var floor_y: float = 400.0
var palette: Dictionary = {}
var decor: String = "banners"
var seed_value: int = 1


func setup(p_kind: String, p_tile_width: float, p_view_height: float, p_floor_y: float, p_seed: int) -> void:
	kind = p_kind
	tile_width = p_tile_width
	view_height = p_view_height
	floor_y = p_floor_y
	seed_value = p_seed


func set_palette(p: Dictionary) -> void:
	palette = p
	decor = String(p.get("decor", "banners"))
	queue_redraw()


func _c(key: String, fallback: Color = Color.MAGENTA) -> Color:
	return palette.get(key, fallback)


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _draw() -> void:
	if palette.is_empty():
		return
	match kind:
		"sky":
			_draw_sky()
		"far":
			_draw_far()
		"wall":
			_draw_wall()
		"pillars":
			_draw_pillars()
		"floor":
			_draw_floor()
		"front":
			_draw_front()
		"plain":
			_draw_plain()


## Provisional (fase 1 del spec de pixel art): muro y suelo lisos del color del bioma.
func _draw_plain() -> void:
	draw_rect(Rect2(0, 0, tile_width, floor_y - 2.0), _c("wall"))
	draw_rect(Rect2(0, floor_y - 2.0, tile_width, 1.0), _c("wall_dark"))
	draw_rect(Rect2(0, floor_y - 1.0, tile_width, 1.0), _c("wall_dark").darkened(0.3))
	draw_rect(Rect2(0, floor_y, tile_width, 1.0), _c("floor_hi"))
	draw_rect(Rect2(0, floor_y + 1.0, tile_width, view_height - floor_y - 1.0), _c("floor"))


# ─── Fondo lejano: degradado + niebla ─────────────────────────────────

func _draw_sky() -> void:
	SK.v_gradient(self, Rect2(-2, -40, tile_width + 4, floor_y + 40), _c("sky_top"), _c("sky_bottom"))
	# Banda de niebla cálida a media altura
	SK.v_gradient(self, Rect2(-2, floor_y * 0.45, tile_width + 4, floor_y * 0.55), SK.fade(_c("fog"), 0.0), SK.fade(_c("fog"), 0.35))


# ─── Capa lejana: arcadas en silueta, muy apagadas ────────────────────

func _draw_far() -> void:
	var r := _rng()
	var col := _c("far")
	var col_hi := _c("far_hi")
	var base := floor_y - 30.0
	# Muro lejano con arcadas recortadas
	var spacing := tile_width / 6.0
	draw_rect(Rect2(-2, 40, tile_width + 4, base - 40), col)
	for i in 6:
		var cx := spacing * (float(i) + 0.5)
		var h := 170.0 + r.randf_range(-12.0, 12.0)
		var arch := SK.arch_pts(cx, base, spacing * 0.62, h, 12)
		draw_colored_polygon(arch, _c("sky_bottom").lerp(col, 0.35))
		# ventana con luz lejana dentro del arco
		if r.randf() < 0.55:
			var wy := base - h + 48.0
			var win := SK.arch_pts(cx, wy + 34.0, 16.0, 34.0, 8)
			draw_colored_polygon(win, SK.fade(_c("light"), 0.28))
		# columnas entre arcos
		draw_rect(Rect2(cx + spacing * 0.31, 40, spacing * 0.38, base - 40), col_hi.lerp(col, 0.5))
	# Remate superior dentado (almenas/rocas)
	var top := PackedVector2Array()
	top.append(Vector2(-2, -40))
	top.append(Vector2(-2, 40.0))
	var x := 34.0
	while x < tile_width - 30.0:
		top.append(Vector2(x, 40.0 + r.randf_range(-6.0, 10.0)))
		x += 36.0
	top.append(Vector2(tile_width + 4, 40.0))
	top.append(Vector2(tile_width + 4, -40))
	draw_colored_polygon(top, col.darkened(0.25))
	# Niebla sobre la capa lejana para empujarla hacia el fondo
	SK.v_gradient(self, Rect2(-2, 40, tile_width + 4, base - 40), SK.fade(_c("sky_bottom"), 0.15), SK.fade(_c("fog"), 0.45))


# ─── Muro principal: sillares, arcos ciegos y decoración del bioma ────

func _draw_wall() -> void:
	var r := _rng()
	var wall := _c("wall")
	var dark := _c("wall_dark")
	var hi := _c("wall_hi")
	var top := 0.0
	var bottom := floor_y
	draw_rect(Rect2(-2, top - 40, tile_width + 4, bottom - top + 40), wall)
	# Sillares (hileras desplazadas)
	var row_h := 34.0
	var row := 0
	var y := bottom - row_h
	while y > top - 40:
		var brick_w := tile_width / 15.0  # ancho fijo: la baldosa repite sin costura
		var off := (brick_w * 0.5) if row % 2 == 1 else 0.0
		var x := -off
		while x < tile_width:
			var w := brick_w
			var shade := r.randf_range(-0.06, 0.06)
			var c := wall.lightened(shade) if shade > 0.0 else wall.darkened(-shade)
			var rect := Rect2(x + 2, y + 2, w - 4, row_h - 4)
			draw_rect(rect, c)
			# brillo superior del sillar
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), SK.fade(hi, 0.55))
			# grietas ocasionales
			if r.randf() < 0.06:
				var cx := rect.position.x + r.randf_range(8, rect.size.x - 8)
				draw_polyline(PackedVector2Array([Vector2(cx, rect.position.y + 3), Vector2(cx + 5, rect.position.y + 12), Vector2(cx - 2, rect.position.y + rect.size.y - 4)]), dark, 2.0, true)
			x += w
		y -= row_h
		row += 1
	# Juntas horizontales oscuras
	y = bottom - row_h
	while y > top - 40:
		draw_rect(Rect2(-2, y, tile_width + 4, 2), dark)
		y -= row_h
	# Arcos ciegos (hornacinas) a lo largo del muro
	var niches := 3
	for i in niches:
		var cx := tile_width * (float(i) + 0.5) / float(niches)
		var arch := SK.arch_pts(cx, bottom - 24.0, 150.0, 250.0, 16)
		draw_colored_polygon(arch, dark.darkened(0.35))
		var inner := SK.arch_pts(cx, bottom - 24.0, 128.0, 236.0, 16)
		SK.v_gradient_poly(self, inner, bottom - 260.0, bottom - 24.0, _c("sky_bottom").darkened(0.45), _c("fog").darkened(0.35))
		# reborde del arco
		draw_polyline(arch, hi.darkened(0.1), 4.0, true)
		draw_polyline(inner, dark.darkened(0.2), 3.0, true)
		_draw_niche_decor(cx, bottom - 24.0, r, i)
	# Sombra de contacto con el suelo
	SK.v_gradient(self, Rect2(-2, bottom - 70, tile_width + 4, 70), SK.fade(dark, 0.0), SK.fade(Color.BLACK, 0.45))


func _draw_niche_decor(cx: float, base: float, r: RandomNumberGenerator, index: int = 0) -> void:
	# Cada hornacina de la baldosa lleva algo distinto para que el muro no se repita
	var variant := index % 3
	if variant == 1:
		match decor:
			"banners", "vines":
				_decor_candles(cx, base)
			"lava":
				_decor_brazier(cx, base)
			_:
				_decor_statue(cx, base)
		return
	if variant == 2:
		match decor:
			"banners":
				_decor_weapons(cx, base)
			"vines", "crystals":
				_decor_skulls(cx, base)
			_:
				_decor_statue(cx, base)
		return
	match decor:
		"banners":
			var bc := _c("accent")
			var ban := PackedVector2Array([
				Vector2(cx - 26, base - 214), Vector2(cx + 26, base - 214),
				Vector2(cx + 26, base - 110), Vector2(cx, base - 92), Vector2(cx - 26, base - 110),
			])
			SK.shaded_poly(self, ban, bc, bc.darkened(0.35), Vector2(-5, 0), SK.OUTLINE, 2.0)
			draw_rect(Rect2(cx - 32, base - 220, 64, 7), _c("pillar_hi"))
			# emblema: rombo dorado
			draw_colored_polygon(SK.diamond_pts(Vector2(cx, base - 160), 11, 16), Color("d9a441"))
		"vines":
			var vc := _c("accent")
			for k in 3:
				var vx := cx - 40.0 + float(k) * 40.0 + r.randf_range(-6, 6)
				var pts := PackedVector2Array()
				var length := r.randf_range(90, 170)
				var yy := base - 236.0
				while yy < base - 236.0 + length:
					pts.append(Vector2(vx + sin(yy * 0.08 + float(k)) * 6.0, yy))
					yy += 10.0
				draw_polyline(pts, vc, 4.0, true)
				for p in pts:
					if r.randf() < 0.35:
						draw_colored_polygon(SK.ellipse_pts(p + Vector2(5, 0), 6, 3, 8, 0.6), vc.lightened(0.15))
		"lava":
			var lc := _c("accent")
			var pts := PackedVector2Array()
			var yy := base - 230.0
			var xx := cx + r.randf_range(-20, 20)
			while yy < base:
				pts.append(Vector2(xx, yy))
				xx += r.randf_range(-14, 14)
				yy += r.randf_range(16, 30)
			draw_polyline(pts, SK.fade(lc, 0.35), 10.0, true)
			draw_polyline(pts, lc, 3.0, true)
		"crystals":
			var cc := _c("accent")
			for k in 4:
				var bx := cx - 45.0 + float(k) * 30.0
				var h := r.randf_range(40, 90)
				var cr := PackedVector2Array([Vector2(bx - 9, base), Vector2(bx, base - h), Vector2(bx + 9, base)])
				SK.shaded_poly(self, cr, cc.lerp(Color.WHITE, 0.3), cc.darkened(0.3), Vector2(-3, 0), SK.OUTLINE, 2.0)
		"runes":
			var rc := _c("accent")
			draw_arc(Vector2(cx, base - 150), 34, 0, TAU, 32, SK.fade(rc, 0.7), 3.0, true)
			draw_arc(Vector2(cx, base - 150), 24, 0, TAU, 32, SK.fade(rc, 0.4), 2.0, true)
			for k in 6:
				var a := TAU * float(k) / 6.0
				var p := Vector2(cx, base - 150) + Vector2(cos(a), sin(a)) * 29.0
				draw_colored_polygon(SK.diamond_pts(p, 3, 5), rc)


func _decor_candles(cx: float, base: float) -> void:
	var shelf_y := base - 70.0
	draw_rect(Rect2(cx - 46, shelf_y, 92, 9), _c("pillar_dark"))
	draw_rect(Rect2(cx - 46, shelf_y, 92, 3), _c("pillar_hi"))
	var light := _c("light")
	for k in 3:
		var x := cx - 26.0 + float(k) * 26.0
		var h := 22.0 + float((k * 7) % 3) * 8.0
		draw_rect(Rect2(x - 5, shelf_y - h, 10, h), Color("e8dcc0"))
		draw_rect(Rect2(x + 1, shelf_y - h, 4, h), Color("c9b893"))
		draw_circle(Vector2(x, shelf_y - h - 7), 16.0, SK.fade(light, 0.16))
		var flame := PackedVector2Array([Vector2(x - 4, shelf_y - h - 2), Vector2(x, shelf_y - h - 15), Vector2(x + 4, shelf_y - h - 2)])
		draw_colored_polygon(flame, _c("flame_mid"))
	# Cera derramada
	draw_colored_polygon(SK.ellipse_pts(Vector2(cx, shelf_y - 1), 38, 3, 12), Color("d9cba8"))


func _decor_skulls(cx: float, base: float) -> void:
	var bone := Color("d8ccb0").lerp(_c("wall_hi"), 0.35)
	for k in 3:
		var p := Vector2(cx - 22.0 + float(k) * 22.0, base - 16.0 - (14.0 if k == 1 else 0.0))
		draw_colored_polygon(SK.ellipse_pts(p, 13, 12, 12), bone)
		draw_colored_polygon(SK.ellipse_pts(p + Vector2(-5, 0), 3.5, 4, 8), SK.OUTLINE)
		draw_colored_polygon(SK.ellipse_pts(p + Vector2(5, 0), 3.5, 4, 8), SK.OUTLINE)
		draw_rect(Rect2(p + Vector2(-5, 8), Vector2(10, 5)), bone.darkened(0.15))
	draw_line(Vector2(cx - 40, base - 4), Vector2(cx + 40, base - 12), bone.darkened(0.1), 5.0, true)


func _decor_weapons(cx: float, base: float) -> void:
	var c := Vector2(cx, base - 140)
	var steel := Color("9aa3ad").lerp(_c("wall_hi"), 0.3)
	for sgn in [-1.0, 1.0]:
		var d := Vector2(sgn * 0.62, -0.78).normalized()
		draw_line(c - d * 60.0, c + d * 64.0, SK.OUTLINE, 9.0, true)
		draw_line(c - d * 60.0, c + d * 64.0, steel, 5.0, true)
		draw_line(c - d * 40.0 + d.orthogonal() * 10.0, c - d * 40.0 - d.orthogonal() * 10.0, Color("6b4a2e"), 5.0, true)
	var shield := SK.regular_poly(c + Vector2(0, 8), 30.0, 16)
	SK.shaded_poly(self, shield, _c("accent"), _c("accent").darkened(0.35), Vector2(-4, -4), SK.OUTLINE, 3.0)
	draw_arc(c + Vector2(0, 8), 20.0, 0, TAU, 20, Color("d9a441"), 3.0, true)


func _decor_statue(cx: float, base: float) -> void:
	var st := _c("pillar").lerp(_c("wall_hi"), 0.4)
	var body := PackedVector2Array([
		Vector2(cx - 30, base), Vector2(cx - 22, base - 100), Vector2(cx - 16, base - 150),
		Vector2(cx, base - 172), Vector2(cx + 16, base - 150), Vector2(cx + 22, base - 100), Vector2(cx + 30, base),
	])
	SK.shaded_poly(self, body, st, st.darkened(0.35), Vector2(-5, -3), SK.OUTLINE, 3.0)
	draw_colored_polygon(SK.ellipse_pts(Vector2(cx + 2, base - 146), 9, 11, 10), st.darkened(0.55))
	draw_rect(Rect2(cx - 40, base - 10, 80, 12), _c("pillar_dark"))
	if decor == "runes" or decor == "crystals":
		draw_circle(Vector2(cx + 2, base - 146), 5.0, _c("accent"))


func _decor_brazier(cx: float, base: float) -> void:
	var bowl := PackedVector2Array([Vector2(cx - 34, base - 64), Vector2(cx + 34, base - 64), Vector2(cx + 22, base - 40), Vector2(cx - 22, base - 40)])
	SK.shaded_poly(self, bowl, Color("4a3a36"), Color("2a201e"), Vector2(-3, -3), SK.OUTLINE, 3.0)
	draw_rect(Rect2(cx - 6, base - 40, 12, 40), Color("2a201e"))
	draw_circle(Vector2(cx, base - 70), 40.0, SK.fade(_c("light"), 0.14))
	for k in 5:
		draw_circle(Vector2(cx - 20.0 + float(k) * 10.0, base - 66.0 - float(k % 2) * 4.0), 7.0, _c("accent"))


# ─── Columnas (con soportes de antorcha; las llamas son nodos aparte) ──

func _draw_pillars() -> void:
	var col := _c("pillar")
	var dark := _c("pillar_dark")
	var hi := _c("pillar_hi")
	var count := 2
	for i in count:
		var cx := tile_width * float(i) / float(count)
		var w := 64.0
		var rect := Rect2(cx - w * 0.5, -40, w, floor_y + 40)
		draw_rect(rect, col)
		draw_rect(Rect2(rect.position.x + w - 16, rect.position.y, 16, rect.size.y), dark)
		draw_rect(Rect2(rect.position.x + 4, rect.position.y, 8, rect.size.y), hi)
		# capitel y basa
		draw_rect(Rect2(cx - w * 0.5 - 10, floor_y - 30, w + 20, 30), dark.lerp(col, 0.4))
		draw_rect(Rect2(cx - w * 0.5 - 10, floor_y - 30, w + 20, 5), hi)
		draw_rect(Rect2(cx - w * 0.5 - 8, 40, w + 16, 22), dark.lerp(col, 0.4))
		draw_rect(Rect2(cx - w * 0.5 - 8, 40, w + 16, 4), hi)
		draw_line(Vector2(cx - w * 0.5, -40), Vector2(cx - w * 0.5, floor_y), SK.OUTLINE, 3.0, true)
		draw_line(Vector2(cx + w * 0.5, -40), Vector2(cx + w * 0.5, floor_y), SK.OUTLINE, 3.0, true)
		# soporte de antorcha
		var holder := Vector2(cx, 205)
		draw_rect(Rect2(holder.x - 5, holder.y - 4, 10, 30), Color("2a2224"))
		draw_colored_polygon(PackedVector2Array([holder + Vector2(-12, -6), holder + Vector2(12, -6), holder + Vector2(7, 6), holder + Vector2(-7, 6)]), Color("3d3234"))
		# cadena colgando
		var chain_x := cx + 150.0
		var yy := -40.0
		while yy < 110.0:
			draw_colored_polygon(SK.ellipse_pts(Vector2(chain_x, yy), 3.5, 6.5, 8), dark.darkened(0.2))
			yy += 11.0


# ─── Suelo: losas en perspectiva ───────────────────────────────────────

func _draw_floor() -> void:
	var r := _rng()
	var f := _c("floor")
	var dark := _c("floor_dark")
	var hi := _c("floor_hi")
	var h := view_height - floor_y + 40.0
	draw_rect(Rect2(-2, floor_y, tile_width + 4, h), f)
	# borde superior iluminado (arista del suelo)
	draw_rect(Rect2(-2, floor_y, tile_width + 4, 4), hi)
	# hileras de losas: más finas arriba (lejos) y más anchas abajo (cerca)
	var rows := [floor_y + 4.0, floor_y + 22.0, floor_y + 46.0, floor_y + 80.0, view_height + 40.0]
	for i in rows.size() - 1:
		var y0: float = rows[i]
		var y1: float = rows[i + 1]
		draw_rect(Rect2(-2, y1 - 2, tile_width + 4, 2), dark)
		var slab_w := 70.0 + float(i) * 34.0
		var x := r.randf_range(0.0, slab_w)
		while x < tile_width + slab_w:
			var skew := (float(i) + 1.0) * 5.0
			draw_line(Vector2(x, y0), Vector2(x - skew, y1), dark, 2.0, true)
			if r.randf() < 0.25:
				draw_rect(Rect2(x + 6, y0 + 3, slab_w * 0.4, 2), SK.fade(hi, 0.5))
			x += slab_w + r.randf_range(-8.0, 8.0)
	# Grietas y guijarros
	for k in 8:
		var px := r.randf_range(0.0, tile_width)
		var py := r.randf_range(floor_y + 10.0, view_height - 6.0)
		draw_colored_polygon(SK.ellipse_pts(Vector2(px, py), r.randf_range(3, 7), r.randf_range(2, 4), 8), dark.lerp(f, 0.3))
	if decor == "lava":
		for k in 3:
			var px := r.randf_range(0.0, tile_width)
			var pts := PackedVector2Array([Vector2(px, floor_y + 6), Vector2(px + 18, floor_y + 20), Vector2(px + 8, floor_y + 40), Vector2(px + 30, floor_y + 70)])
			draw_polyline(pts, SK.fade(_c("accent"), 0.35), 8.0, true)
			draw_polyline(pts, _c("accent"), 2.5, true)
	# Oscurecer hacia el borde inferior (profundidad)
	SK.v_gradient(self, Rect2(-2, floor_y + 20, tile_width + 4, h), SK.fade(Color.BLACK, 0.0), SK.fade(Color.BLACK, 0.45))


# ─── Primer plano: siluetas oscuras que pasan rápido ───────────────────

func _draw_front() -> void:
	var r := _rng()
	var sil := _c("sky_top").darkened(0.35)
	# Una columna gruesa en primer plano por baldosa
	var cx := tile_width * 0.62
	var w := 58.0
	draw_rect(Rect2(cx - w * 0.5, -60, w, view_height + 100), sil)
	draw_rect(Rect2(cx - w * 0.5 - 14, view_height - 60, w + 28, 70), sil)
	draw_rect(Rect2(cx + w * 0.5 - 8, -60, 8, view_height + 100), SK.fade(_c("light"), 0.08))
	# Escombros en el borde inferior
	for k in 5:
		var px := r.randf_range(0.0, tile_width)
		var rad := r.randf_range(14.0, 30.0)
		draw_colored_polygon(SK.ellipse_pts(Vector2(px, view_height + 4), rad * 1.6, rad, 10), sil)
	# Telarañas / raíces colgando del techo según bioma
	var hang := PackedVector2Array()
	hang.append(Vector2(cx - 180, -10))
	hang.append(Vector2(cx - 120, 26 + r.randf_range(0, 20)))
	hang.append(Vector2(cx - 60, -10))
	draw_polyline(hang, SK.fade(sil.lightened(0.25), 0.8), 3.0, true)
