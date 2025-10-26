// res://shaders/circular_mask.gdshader
shader_type canvas_item;

// Máscara circular (legacy)
uniform float radius : hint_range(0.0, 1.0) = 0.48;
uniform vec2 center = vec2(0.5, 0.5);
uniform float softness : hint_range(0.0, 0.1) = 0.02;
uniform float feather : hint_range(0.0, 0.2) = 0.05;

// Máscara por textura (nuevo)
uniform bool use_texture_mask = false;
uniform sampler2D mask_texture : hint_default_white;
uniform float mask_threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = UV;
	float alpha = 1.0;
	
	if (use_texture_mask) {
		// Usar textura como máscara
		// Lee el canal rojo (o cualquier canal ya que es blanco/negro)
		vec4 mask_color = texture(mask_texture, uv);
		alpha = mask_color.r;  // Blanco (1.0) = visible, Negro (0.0) = transparente
		
		// Aplicar threshold opcional para ajustar el borde
		alpha = smoothstep(mask_threshold - 0.1, mask_threshold + 0.1, alpha);
	} else {
		// Usar máscara circular (modo original)
		float dist = distance(uv, center);
		alpha = 1.0 - smoothstep(radius - feather, radius + softness, dist);
	}
	
	// Aplicar máscara manteniendo el color original
	COLOR.a *= alpha;
}
