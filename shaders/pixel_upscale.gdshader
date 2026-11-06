shader_type canvas_item;

// Ampliación de la franja pixel ("sharp bilinear"): cada píxel del arte se ve con su color exacto y
// solo se mezcla en su borde, así los píxeles salen regulares aunque la escala no sea entera
// (ventana de 540, móviles de 720 o 1440 de ancho). Necesita filtro lineal en el nodo que lo usa.

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 pix = UV * size;
	vec2 seam = floor(pix + 0.5);
	vec2 w = max(fwidth(pix), vec2(1e-5));
	pix = seam + clamp((pix - seam) / w, -0.5, 0.5);
	COLOR = texture(TEXTURE, pix / size);
}
