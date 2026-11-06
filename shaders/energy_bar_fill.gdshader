shader_type canvas_item;

// Fire / flame visual effect for energy bar fill.
// Simulates turbulent flames using domain-warped fractal noise.

uniform float fire_speed : hint_range(0.1, 5.0) = 1.8;
uniform float turbulence : hint_range(0.0, 2.0) = 1.0;
uniform float flame_intensity : hint_range(0.5, 3.0) = 1.4;
uniform float flicker_speed : hint_range(0.5, 8.0) = 4.0;
uniform float flicker_amount : hint_range(0.0, 0.5) = 0.15;

// Fire color palette - from cool edges to white-hot core
uniform vec4 color_cold : source_color = vec4(0.5, 0.0, 0.0, 1.0);       // deep red
uniform vec4 color_warm : source_color = vec4(0.9, 0.25, 0.0, 1.0);      // red-orange
uniform vec4 color_hot : source_color = vec4(1.0, 0.65, 0.0, 1.0);       // orange-yellow
uniform vec4 color_core : source_color = vec4(1.0, 0.95, 0.5, 1.0);      // bright yellow-white

// Hash noise (no texture dependency)
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion - 5 octaves for richer detail
float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 5; i++) {
		val += amp * noise(p * freq);
		freq *= 2.1;
		amp *= 0.48;
	}
	return val;
}

// Domain warping - feeds noise back into itself for turbulent look
float warped_fbm(vec2 p, float t) {
	vec2 q = vec2(
		fbm(p + vec2(0.0, 0.0)),
		fbm(p + vec2(5.2, 1.3))
	);
	vec2 r = vec2(
		fbm(p + 4.0 * q + vec2(1.7, 9.2) + 0.15 * t),
		fbm(p + 4.0 * q + vec2(8.3, 2.8) + 0.126 * t)
	);
	return fbm(p + 4.0 * r * turbulence);
}

// Map a 0-1 value to fire color ramp
vec3 fire_color_ramp(float t) {
	t = clamp(t, 0.0, 1.0);
	if (t < 0.33) {
		return mix(color_cold.rgb, color_warm.rgb, t / 0.33);
	} else if (t < 0.66) {
		return mix(color_warm.rgb, color_hot.rgb, (t - 0.33) / 0.33);
	} else {
		return mix(color_hot.rgb, color_core.rgb, (t - 0.66) / 0.34);
	}
}

void fragment() {
	vec2 uv = UV;

	// --- Flame noise coordinates ---
	// Scroll upward (negative Y) to simulate rising flames
	// Also scroll horizontally for variety
	vec2 fire_uv = uv * vec2(3.0, 2.5);
	fire_uv.y -= TIME * fire_speed;
	fire_uv.x += TIME * fire_speed * 0.3;

	// Domain-warped turbulent noise
	float flame_noise = warped_fbm(fire_uv, TIME * fire_speed);

	// --- Secondary faster noise layer for detail ---
	vec2 detail_uv = uv * vec2(5.0, 4.0);
	detail_uv.y -= TIME * fire_speed * 1.4;
	detail_uv.x += sin(TIME * 0.7) * 0.3;
	float detail = fbm(detail_uv + vec2(TIME * 0.5, 0.0));

	// Combine noises
	float combined = flame_noise * 0.7 + detail * 0.3;

	// --- Vertical gradient: hotter at bottom, cooler at top ---
	// (In UV space, Y=0 is top, Y=1 is bottom for typical bars)
	// We make the center (Y=0.5) the hottest, edges cooler
	float center_heat = 1.0 - abs(uv.y - 0.5) * 2.0;
	center_heat = pow(center_heat, 0.6);

	// --- Horizontal variation: slight cooling toward edges ---
	float horiz_heat = smoothstep(0.0, 0.15, uv.x) * smoothstep(1.0, 0.85, uv.x);

	// Final fire intensity
	float fire_val = combined * center_heat * horiz_heat * flame_intensity;

	// --- Flickering ---
	float flicker = 1.0 - flicker_amount + flicker_amount * (
		sin(TIME * flicker_speed) * 0.4 +
		sin(TIME * flicker_speed * 2.3 + 1.0) * 0.3 +
		sin(TIME * flicker_speed * 3.7 + 2.5) * 0.3
	);
	fire_val *= flicker;

	// --- Map to fire color ramp ---
	vec3 col = fire_color_ramp(fire_val);

	// --- Ember sparks: bright tiny dots from high-frequency noise ---
	float sparks = noise(uv * vec2(30.0, 20.0) + vec2(TIME * 3.0, -TIME * 5.0));
	sparks = smoothstep(0.85, 0.95, sparks) * center_heat * horiz_heat;
	col += color_core.rgb * sparks * 0.8;

	// --- Additive glow to boost brightness at hot spots ---
	float glow = smoothstep(0.5, 1.0, fire_val);
	col += color_hot.rgb * glow * 0.3;

	// Keep original alpha from color_cold (acts as base alpha)
	COLOR = vec4(col, color_cold.a);
}

