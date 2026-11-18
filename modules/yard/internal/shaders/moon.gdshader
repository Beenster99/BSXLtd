shader_type spatial;
// The planet's moon, far off: grey highlands and darker maria, craters with bright rims and
// rays, lit hard by the sun with no air to soften its terminator.

uniform vec3 highland : source_color = vec3(0.62, 0.6, 0.57);
uniform vec3 mare : source_color = vec3(0.3, 0.3, 0.31);

varying vec3 obj_dir;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
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
		p = p * 2.1 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

// Craters: in each cell of a grid on the sphere, a bowl with a bright rim.
float craters(vec3 d, float scale) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	float out_v = 0.0;
	for (int i = 0; i < 2; i++) {
		vec3 c = cell + vec3(float(i) * 0.5);
		vec3 centre = floor(c) + vec3(hash(floor(c)), hash(floor(c) + 3.1), hash(floor(c) + 7.3));
		float r = 0.2 + 0.3 * hash(floor(c) + 1.1);
		float dist = length(p - centre) / r;
		out_v += smoothstep(1.0, 0.8, dist) * -0.4 + smoothstep(0.8, 1.0, dist) * smoothstep(1.25, 1.0, dist) * 0.5;
	}
	return out_v;
}

void vertex() {
	obj_dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = obj_dir;
	float m = smoothstep(0.48, 0.58, fbm(d * 2.2 + 3.0));
	vec3 col = mix(highland, mare, m);
	col *= 0.85 + 0.3 * fbm(d * 20.0);
	col *= 1.0 + 0.5 * (craters(d, 9.0) + craters(d, 23.0) * 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}

void light() {
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * LIGHT_COLOR * ATTENUATION;
}
