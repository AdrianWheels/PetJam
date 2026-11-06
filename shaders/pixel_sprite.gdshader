shader_type canvas_item;

// Sprites de la franja: destello al recibir daño (mezcla hacia flash_color) y disolución por patrón
// de píxeles para aparecer y caer sin escalar. El patrón es una matriz de Bayer 4x4 sobre el píxel del arte.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
	float threshold = (BAYER[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
	if (threshold < dissolve) {
		discard;
	}
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
