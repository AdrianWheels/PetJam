shader_type canvas_item;

// Transición entre duelos: un humo que sube del suelo y tapa la franja hasta el negro (progress 1), y que al
// bajar descubre el duelo siguiente (progress 0). Ruido fractal que se arremolina con el tiempo; donde el humo
// empieza a tapar hay un reborde gris de humo iluminado.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 2.25;  // ancho / alto del rectángulo, para que las volutas no salgan estiradas
uniform vec4 smoke_color : source_color = vec4(0.55, 0.5, 0.46, 1.0);
uniform vec4 dark_color : source_color = vec4(0.012, 0.008, 0.006, 1.0);

const float W = 0.12;  // ancho del borde del humo

// Hash sin seno (Dave Hoskins): el clásico fract(sin(dot(...)) * 43758) pierde precisión con coordenadas grandes y el
// humo salía con bloques cuadrados; este se mantiene estable también en la precisión media de los móviles
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * vec2(aspect, 1.0);
	float t = TIME * 0.4;
	// Remolino: el ruido desplaza al ruido, y todo sube despacio
	vec2 q = vec2(fbm(uv * 1.8 + vec2(0.0, t)), fbm(uv * 1.8 + vec2(5.2, -t * 0.7)));
	float n = fbm(uv * 2.4 + q * 1.6 + vec2(0.0, t * 0.8));
	// El fbm se queda casi siempre entre 0,22 y 0,78: estirado a 0-1, el humo avanza durante toda la transición en vez de
	// tapar casi todo de golpe a mitad de camino
	n = clamp((n - 0.22) / 0.56, 0.0, 1.0);
	// Sube del suelo: abajo tapa antes que arriba
	float f = mix(n, 1.0 - UV.y, 0.4);
	// Con progress 0 no tapa nada y con 1 todo es negro, sea cual sea el ruido
	float p = progress * (1.0 + 4.0 * W) - 2.0 * W;
	float cover = smoothstep(f - W, f + W, p);
	float rim = smoothstep(f - 1.5 * W, f, p) * (1.0 - smoothstep(f, f + 2.0 * W, p));
	vec3 col = mix(smoke_color.rgb, dark_color.rgb, smoothstep(f, f + 2.0 * W, p));
	COLOR = vec4(col, max(cover, rim * 0.8));
}
