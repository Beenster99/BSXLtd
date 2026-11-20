shader_type spatial;
// A build bot's paint with its wear (master plan 6.4: "detailed models with moving arms, lights,
// wear and paint"): the paint colour, chipped to bare metal on the edges and high spots as the
// bot wears, grime in the hollows, and fine scratches. Our own shader (nothing from Void Salvage).

uniform vec4 paint : source_color = vec4(0.91, 0.47, 0.17, 1.0);
uniform float metallic_paint = 0.25;
uniform float roughness_paint = 0.48;
uniform float wear : hint_range(0.0, 1.0) = 0.1;
uniform float grime : hint_range(0.0, 1.0) = 0.25;
uniform float seed = 0.0;

varying vec3 obj_pos;
varying vec3 obj_nrm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13) + seed);
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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
}

void fragment() {
	float n = fbm(obj_pos * 9.0);
	float fine = noise(obj_pos * vec3(80.0, 3.0, 80.0));
	// Chips: where the noise is high, more of them the more worn.
	float chip = smoothstep(1.0 - wear * 0.55, 1.02 - wear * 0.5, n + fine * 0.12);
	// Grime gathers low and in the noise's hollows.
	float dirt = clamp((0.55 - n) * 2.0, 0.0, 1.0) * grime * (0.4 + wear);
	dirt += smoothstep(0.2, -0.6, obj_pos.y) * grime * 0.35;
	vec3 bare = vec3(0.62, 0.63, 0.64);
	vec3 col = mix(paint.rgb, bare, chip);
	col = mix(col, col * vec3(0.35, 0.32, 0.28), clamp(dirt, 0.0, 0.85));
	float scratch = step(0.985 - wear * 0.02, fine) * (1.0 - chip);
	col = mix(col, bare * 0.9, scratch * 0.6);
	ALBEDO = col;
	METALLIC = mix(metallic_paint, 0.9, chip);
	ROUGHNESS = clamp(mix(roughness_paint, 0.32, chip) + dirt * 0.3, 0.05, 1.0);
}
