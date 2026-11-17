shader_type sky;
// Orbit's sky: black, a field of stars of varied brightness and colour, a faint band of the
// galaxy, and the sun's disc with a soft glow (from the first directional light).

uniform float star_density = 0.0035;
uniform float star_brightness = 2.2;
uniform vec3 band_axis = vec3(0.3, 0.85, -0.42);
uniform float band_strength = 0.05;
uniform vec3 sun_colour : source_color = vec3(1.0, 0.95, 0.85);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float stars(vec3 dir, float scale) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	float h = hash(cell);
	if (h > star_density * scale * 0.01 * 3.0) {
		return 0.0;
	}
	vec3 centre = cell + vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1));
	float d = length(p - centre);
	return smoothstep(0.35, 0.0, d) * (0.3 + 0.7 * hash(cell + 9.1));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float s = stars(dir, 260.0) + stars(dir, 520.0) * 0.6 + stars(dir, 140.0) * 1.3;
	float tint = hash(floor(dir * 260.0) + 3.3);
	vec3 star_col = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.88, 0.75), tint);
	float band = exp(-pow(dot(dir, normalize(band_axis)) * 4.0, 2.0));
	vec3 col = star_col * s * star_brightness + vec3(0.35, 0.38, 0.5) * band * band_strength;
	if (LIGHT0_ENABLED) {
		float d = dot(dir, LIGHT0_DIRECTION);
		col += sun_colour * (smoothstep(0.9995, 0.9998, d) * 40.0 + pow(max(d, 0.0), 400.0) * 1.5 + pow(max(d, 0.0), 30.0) * 0.08);
	}
	COLOR = col;
}
