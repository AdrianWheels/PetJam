extends Node2D

## Puerta de sala provisional en pixel (fase 1 del spec de pixel art): marco de piedra y placa numerada.
## Marca la frontera entre salas y se dibuja detrás de los personajes (z_index negativo en la escena).
## La fase 4 la sustituye por el arco dibujado.

var room := 1
var is_boss := false
var palette: Dictionary = {}


func _ready() -> void:
	visible = false


func setup(p_room: int, x: float, p_palette: Dictionary) -> void:
	room = p_room
	is_boss = Biomes.is_boss_room(p_room)
	palette = p_palette
	position = Vector2(roundf(x), 0)
	visible = true
	# Se coloca dentro de la pantalla tras cada victoria: aparece con un fundido, no de golpe
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	queue_redraw()


func set_palette(p: Dictionary) -> void:
	palette = p
	queue_redraw()


## Medidas del marco: ancho, alto y grosor de las jambas.
func _frame() -> Vector3:
	return Vector3(34, 46, 4) if is_boss else Vector3(28, 40, 4)


## Placa con el número de sala, relativa al nodo (crece con las cifras).
func plate_rect() -> Rect2:
	var f := _frame()
	var w := float(PixelFont.width(str(room))) + 4.0
	return Rect2(roundf(-w * 0.5), PixelView.FLOOR_Y - f.y - 9.0, w, 8.0)


func _draw() -> void:
	if palette.is_empty():
		return
	var stone: Color = palette.get("pillar", Color(0.3, 0.25, 0.25))
	var dark: Color = palette.get("pillar_dark", stone.darkened(0.4))
	var hi: Color = palette.get("pillar_hi", stone.lightened(0.2))
	var f := _frame()
	var left := roundf(-f.x * 0.5)
	var top := PixelView.FLOOR_Y - f.y
	# Hueco en sombra
	draw_rect(Rect2(left + f.z, top + f.z, f.x - f.z * 2.0, f.y - f.z), Color(0, 0, 0, 0.35))
	# Jambas y dintel con luz arriba-izquierda
	for r in [Rect2(left, top, f.z, f.y), Rect2(left + f.x - f.z, top, f.z, f.y), Rect2(left, top, f.x, f.z)]:
		draw_rect(r, stone)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), hi)
		draw_rect(Rect2(r.position, Vector2(1.0, r.size.y)), hi)
		draw_rect(Rect2(r.position.x + r.size.x - 1.0, r.position.y, 1.0, r.size.y), dark)
	# Placa con el número
	var plate := plate_rect()
	draw_rect(plate.grow(1.0), PixelHud.OUTLINE)
	draw_rect(plate, Color("7a2020") if is_boss else Color("3b2a1c"))
	PixelFont.draw_centered(self, Vector2(0, plate.position.y - 2.0), str(room), Color("f3d9a4"))
