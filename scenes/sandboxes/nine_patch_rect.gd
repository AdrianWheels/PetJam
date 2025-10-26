# Crea un NinePatchRect en la escena y pega esto (Godot 4.x)
extends NinePatchRect

# ajusta a tu grosor real del marco
const M = 24

func _ready():
    texture = preload("res://art/placeholders/panel_madera.png")
    patch_margin_left = M
    patch_margin_right = M
    patch_margin_top = M
    patch_margin_bottom = M

    draw_center = true

    # 0=STRETCH, 1=TILE, 2=TILE_FIT
    axis_stretch_horizontal = 1
    axis_stretch_vertical = 1

    # que crezca con el contenedor
    set_anchors_preset(Control.PRESET_FULL_RECT)

    # no permitas que colapse por debajo del marco*2
    custom_minimum_size = Vector2(M*2 + 1, M*2 + 1)
