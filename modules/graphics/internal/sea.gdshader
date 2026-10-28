// The sea (flag "graphics.sea"): calm harbour water. Long slow swells move the surface, finer
// ripples only shade it (and fade with distance), the sky reflects off it by the hour, the
// colour deepens with the water under it and further out, and foam laps round anything solid
// standing in it (quay walls, slipways, hulls).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec3 shallow : source_color = vec3(0.11, 0.23, 0.24);
uniform vec3 deep : source_color = vec3(0.015, 0.06, 0.09);
uniform vec3 foam_color : source_color = vec3(0.82, 0.86, 0.85);
// Swell height (m) and wavelength (m); ripples' size (m) and strength.
uniform float swell = 0.16;
uniform float swell_length = 26.0;
uniform float ripple_size = 2.2;
uniform float ripple = 0.22;
// Foam within this depth of something solid (m); full colour below this depth (m).
uniform float foam_depth = 0.7;
uniform float clarity = 3.5;
// Beyond this (m) the water reads as open sea: deep and flat.
uniform float far = 450.0;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Height of the swells at p (world xz), and its slope.
vec3 swells(vec2 p, float t) {
	vec2 d1 = normalize(vec2(0.8, 0.6));
	vec2 d2 = normalize(vec2(-0.3, 1.0));
	vec2 d3 = normalize(vec2(1.0, -0.45));
	float k1 = 6.2831 / swell_length;
	float k2 = 6.2831 / (swell_length * 0.62);
	float k3 = 6.2831 / (swell_length * 0.37);
	float a1 = swell, a2 = swell * 0.55, a3 = swell * 0.3;
	float p1 = dot(d1, p) * k1 + t * sqrt(9.8 * k1);
	float p2 = dot(d2, p) * k2 + t * sqrt(9.8 * k2);
	float p3 = dot(d3, p) * k3 + t * sqrt(9.8 * k3);
	float h = a1 * sin(p1) + a2 * sin(p2) + a3 * sin(p3);
	vec2 slope = d1 * a1 * k1 * cos(p1) + d2 * a2 * k2 * cos(p2) + d3 * a3 * k3 * cos(p3);
	return vec3(h, slope);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 s = swells(wpos.xz, TIME);
	VERTEX.y += s.x;
	NORMAL = normalize(vec3(-s.y, 1.0, -s.z));
	wpos.y += s.x;
}

void fragment() {
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(30.0, 180.0, dist);
	// Ripples: two layers of noise drifting across each other, shading only.
	vec2 q = wpos.xz / ripple_size;
	float e = 0.15;
	vec2 a = q + vec2(TIME * 0.11, TIME * 0.07);
	vec2 b = q * 1.7 + vec2(-TIME * 0.09, TIME * 0.13);
	float n0 = noise(a) + noise(b) * 0.6;
	float nx = noise(a + vec2(e, 0.0)) + noise(b + vec2(e, 0.0)) * 0.6;
	float nz = noise(a + vec2(0.0, e)) + noise(b + vec2(0.0, e)) * 0.6;
	vec3 s = swells(wpos.xz, TIME);
	vec3 n = normalize(vec3(-s.y - (nx - n0) / e * ripple * (0.25 + 0.75 * near),
			1.0, -s.z - (nz - n0) / e * ripple * (0.25 + 0.75 * near)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// How much water lies behind this point, along the view (m).
	float raw = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float behind = -view.z / view.w;
	float water = max(behind - (-VERTEX.z), 0.0);
	// Straight down through that slant, about.
	float down = water * clamp(abs(dot(normalize(VERTEX), (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz)), 0.15, 1.0);

	float open = smoothstep(far * 0.3, far, dist);
	vec3 col = mix(shallow, deep, max(smoothstep(0.0, clarity, down), open));
	float foam = (1.0 - smoothstep(0.0, foam_depth, down)) * smoothstep(0.35, 0.75, noise(q * 2.5 + vec2(TIME * 0.3, 0.0)) + 0.35 * (1.0 - smoothstep(0.0, foam_depth * 0.4, down)));
	foam *= 1.0 - open;
	ALBEDO = mix(col, foam_color, foam);
	ROUGHNESS = mix(0.05, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = clamp(mix(0.55, 1.0, smoothstep(0.0, clarity, down)) + foam, 0.0, 1.0);
}
