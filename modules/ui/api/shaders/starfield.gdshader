// Procedural space sky: two layers of stars, a faint nebula band and a sun disc.
// The sun disc follows the first DirectionalLight3D in the scene (the Sun node).
shader_type sky;

uniform float star_threshold : hint_range(0.9, 1.0) = 0.965;
uniform float star_brightness = 3.4;
uniform vec3 nebula_color_a : source_color = vec3(0.10, 0.035, 0.16);
uniform vec3 nebula_color_b : source_color = vec3(0.015, 0.07, 0.13);
uniform float nebula_strength = 0.9;
// 0: a band across the sky. 1: inside a nebula, gas in every direction.
uniform float nebula_cover : hint_range(0.0, 1.0) = 0.0;
// cos of the sun disc's apparent radius (set per site by SiteBackdrop).
uniform float sun_disc_size : hint_range(0.99, 1.0) = 0.99985;
// Quantum travel: 0 still, 1 the stars pulled into streaks toward warp_dir (TransitFx).
uniform float warp : hint_range(0.0, 1.0) = 0.0;
uniform vec3 warp_dir = vec3(0.0, 0.0, -1.0);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		total += amplitude * value_noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

// One layer of stars. Each star is drawn at least ~1.5 pixels wide, and dimmed to keep the
// same total light, so stars never shrink below a pixel. Sub-pixel stars are what made the
// sky sparkle: they flicker on and off as pixels sweep across them while the view turns.
vec3 star_layer(vec3 dir, float scale, float seed) {
	vec3 p = dir * scale;
	// Size of one screen pixel, measured in star-grid cells.
	vec3 dp = fwidth(p);
	float pixel = max(max(dp.x, dp.y), dp.z);
	vec3 cell = floor(p);
	float h = hash(cell + seed);
	if (h < star_threshold) {
		return vec3(0.0);
	}
	// Centres stay away from cell edges so a widened star is never cut off.
	vec3 centre = vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 5.1)) * 0.3 + 0.35;
	float d = length(fract(p) - centre);
	float base_radius = 0.08;
	float radius = clamp(pixel * 1.5, base_radius, 0.34);
	float energy = (base_radius * base_radius) / (radius * radius);
	float shape = 1.0 - smoothstep(0.0, radius, d);
	float brightness = shape * shape * energy * (0.3 + 1.7 * hash(cell + 9.1)) * 2.2;
	vec3 tint = mix(vec3(1.0, 0.82, 0.68), vec3(0.72, 0.84, 1.0), hash(cell + 3.3));
	return tint * brightness;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = star_layer(dir, 110.0, 0.0) + star_layer(dir, 190.0, 17.0) * 0.6;
	if (warp > 0.001) {
		// Streaks: the same stars sampled along a pull toward the heading, brightest at the
		// head. Stars straight ahead barely move; those beside you stream past.
		vec3 wd = normalize(warp_dir);
		float side = 1.0 - abs(dot(dir, wd));
		vec3 streaked = vec3(0.0);
		for (int i = 1; i <= 5; i++) {
			float t = float(i) / 5.0;
			vec3 s = normalize(dir + wd * t * warp * 0.35 * side);
			streaked = max(streaked, (star_layer(s, 110.0, 0.0) + star_layer(s, 190.0, 17.0) * 0.6) * (1.0 - 0.6 * t));
		}
		col = mix(col, max(col, streaked), warp);
		// The tunnel's glow ahead, and a violet wash to the sky.
		float ahead = pow(max(dot(dir, wd), 0.0), 6.0);
		col += (vec3(0.25, 0.4, 1.0) * ahead * 0.8 + vec3(0.12, 0.05, 0.22)) * warp;
	}
	col *= star_brightness;

	// A soft, wavy band of nebula across the sky.
	float n = fbm(dir * 2.6);
	float band = exp(-pow((dir.y + 0.25 * sin(dir.x * 3.0)) * 2.4, 2.0));
	band = mix(band, 1.0, nebula_cover);
	col += mix(nebula_color_a, nebula_color_b, n) * band * smoothstep(mix(0.3, 0.08, nebula_cover), 0.8, n) * nebula_strength;
	// Inside a nebula: big slow billows behind the wisps, and the stars dimmed by the gas.
	if (nebula_cover > 0.0) {
		float billow = fbm(dir * 1.3 + 5.0);
		col += mix(nebula_color_b, nebula_color_a, billow) * smoothstep(0.3, 0.75, billow) * nebula_strength * 0.7 * nebula_cover;
		col *= 1.0 - 0.45 * nebula_cover;
	}

	if (LIGHT0_ENABLED) {
		float s = dot(dir, LIGHT0_DIRECTION);
		float disc = smoothstep(sun_disc_size - 0.00004, sun_disc_size, s) * 14.0;
		float halo = pow(max(s, 0.0), 2500.0) * 1.2 + pow(max(s, 0.0), 120.0) * 0.04;
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (disc + halo);
	}
	COLOR = col;
}
