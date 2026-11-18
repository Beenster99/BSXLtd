shader_type sky;
// Orbit's sky (stage 1.5): black, three layers of stars of varied brightness and colour, the
// galaxy's band with its dust lanes, glowing knots and a faint nebula either side, and the
// sun's disc with its corona and a long soft glare (the first directional light).

uniform float star_density = 0.0035;
uniform float star_brightness = 2.4;
// The galaxy's plane (its normal) and how bright its band is.
uniform vec3 band_axis = vec3(0.3, 0.85, -0.42);
uniform float band_strength = 0.16;
uniform vec3 band_colour : source_color = vec3(0.62, 0.66, 0.82);
uniform vec3 core_colour : source_color = vec3(1.0, 0.82, 0.62);
// Where along the band its bright core lies.
uniform vec3 core_dir = vec3(-0.7, 0.1, -0.7);
uniform vec3 nebula_a : source_color = vec3(0.55, 0.16, 0.35);
uniform vec3 nebula_b : source_color = vec3(0.12, 0.3, 0.55);
uniform float nebula_strength = 0.05;
uniform vec3 sun_colour : source_color = vec3(1.0, 0.95, 0.85);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec3(3.1, 1.7, 5.3);
		a *= 0.5;
	}
	return v;
}

// One layer of stars: a point in some cells of a grid round the sky, sharp and round.
float stars(vec3 dir, float scale, float density) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	float h = hash(cell);
	if (h > density) {
		return 0.0;
	}
	vec3 centre = cell + 0.2 + 0.6 * vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1));
	float d = length(p - centre);
	float size = 0.12 + 0.2 * hash(cell + 7.7);
	return smoothstep(size, 0.0, d) * (0.25 + 0.75 * pow(hash(cell + 9.1), 3.0));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 axis = normalize(band_axis);
	float across = dot(dir, axis);
	float band = exp(-pow(across * 3.2, 2.0));
	float core = pow(max(dot(dir, normalize(core_dir)), 0.0), 3.0);
	// More stars along the band, as along a real galaxy's plane.
	float crowd = 1.0 + band * 2.5;
	float s = stars(dir, 300.0, 0.012 * crowd) + stars(dir, 600.0, 0.02 * crowd) * 0.55
			+ stars(dir, 140.0, 0.006 * crowd) * 1.6;
	float tint = hash(floor(dir * 300.0) + 3.3);
	vec3 star_col = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.7), tint);
	vec3 col = star_col * s * star_brightness;
	// The band's glow, clumpy, darkened by dust lanes down its middle.
	float clumps = fbm(dir * 9.0);
	float dust = smoothstep(0.45, 0.75, fbm(dir * 6.0 + 7.0)) * exp(-pow(across * 9.0, 2.0));
	float glow = band * (0.35 + 0.9 * clumps) * (1.0 - 0.85 * dust);
	col += mix(band_colour, core_colour, core) * glow * band_strength * (1.0 + core * 3.0);
	// Unresolved stars: a fine grain of light in the band.
	col += band_colour * pow(noise(dir * 420.0), 6.0) * band * 0.25;
	// Two faint nebulae off the band.
	float n1 = smoothstep(0.55, 0.85, fbm(dir * 3.5 + 11.0)) * exp(-pow(across * 1.6, 2.0));
	float n2 = smoothstep(0.55, 0.85, fbm(dir * 4.5 - 5.0)) * exp(-pow((across - 0.4) * 2.0, 2.0));
	col += (nebula_a * n1 + nebula_b * n2) * nebula_strength;
	if (LIGHT0_ENABLED) {
		float d = dot(dir, LIGHT0_DIRECTION);
		float disc = smoothstep(0.99955, 0.99975, d);
		float corona = pow(max(d, 0.0), 2200.0) * 6.0 + pow(max(d, 0.0), 300.0) * 1.4;
		float glare = pow(max(d, 0.0), 24.0) * 0.07 + pow(max(d, 0.0), 6.0) * 0.015;
		col = mix(col, sun_colour * 50.0, disc);
		col += sun_colour * (corona + glare);
	}
	COLOR = col;
}
