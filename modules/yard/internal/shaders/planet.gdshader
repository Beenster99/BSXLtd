shader_type spatial;
// The planet under the yard: oceans, continents, ice caps and cloud bands from noise on the
// sphere's own direction, lit by the sun, with city lights on the night side.

uniform vec3 ocean : source_color = vec3(0.03, 0.12, 0.26);
uniform vec3 shallows : source_color = vec3(0.05, 0.25, 0.38);
uniform vec3 land : source_color = vec3(0.28, 0.33, 0.18);
uniform vec3 desert : source_color = vec3(0.55, 0.45, 0.3);
uniform vec3 ice : source_color = vec3(0.9, 0.93, 0.97);
uniform float cloud_cover = 0.5;
uniform vec3 sun_dir = vec3(0.55, 0.45, -0.35);

varying vec3 world_n;

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
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	obj_dir = normalize(VERTEX);
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 d = obj_dir;
	float h = fbm(d * 3.0);
	float lat = abs(d.z);  // the poles lie along Z: the yard orbits over the tropics
	vec3 col = mix(ocean, shallows, smoothstep(0.42, 0.5, h));
	float is_land = smoothstep(0.5, 0.52, h);
	vec3 ground = mix(land, desert, smoothstep(0.35, 0.65, fbm(d * 7.0 + 4.0)));
	col = mix(col, ground, is_land);
	col = mix(col, ice, smoothstep(0.78, 0.86, lat + h * 0.15));
	float c = fbm(vec3(d.x * 4.0, d.y * 4.0, d.z * 9.0) + 11.0);
	float clouds = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.2, c);
	col = mix(col, vec3(0.95), clouds * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(0.35, 0.9, max(is_land, clouds));
	SPECULAR = 0.3 * (1.0 - max(is_land, clouds));
	// Night-side city lights: brighter where the land is; the light pass hides them by day.
	float city = is_land * (1.0 - clouds) * step(0.82, hash(floor(d * 900.0)));
	float night = smoothstep(0.05, -0.2, dot(world_n, normalize(sun_dir)));
	EMISSION = vec3(1.0, 0.75, 0.4) * city * 0.5 * night;
}

void light() {
	float n = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += n * LIGHT_COLOR * ATTENUATION;
}
