shader_type spatial;
// The planet under the yard (stage 1.5): continents shaped by warped noise with coasts,
// shallows, forest, grassland, desert and mountains by latitude and height; ice caps; a cloud
// deck of its own that drifts slowly and shades the ground under it; the sun's glint on the
// sea; the air's blue haze thickening toward the limb and a warm line along the terminator;
// city lights on the night side.

uniform vec3 deep : source_color = vec3(0.01, 0.05, 0.14);
uniform vec3 ocean : source_color = vec3(0.02, 0.1, 0.24);
uniform vec3 shallows : source_color = vec3(0.04, 0.26, 0.36);
uniform vec3 forest : source_color = vec3(0.12, 0.17, 0.09);
uniform vec3 grass : source_color = vec3(0.32, 0.33, 0.2);
uniform vec3 desert : source_color = vec3(0.62, 0.5, 0.33);
uniform vec3 rock : source_color = vec3(0.36, 0.32, 0.28);
uniform vec3 ice : source_color = vec3(0.9, 0.93, 0.97);
uniform vec3 haze : source_color = vec3(0.35, 0.55, 0.95);
uniform float cloud_cover = 0.42;
// How fast the clouds drift (radians of the sphere a second).
uniform float cloud_drift = 0.0006;
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

float fbm(vec3 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

// Warped noise: coastlines and cloud fronts that curl instead of blob.
float warped(vec3 p, int octaves) {
	vec3 q = vec3(fbm(p, 4), fbm(p + vec3(5.2, 1.3, 2.8), 4), fbm(p + vec3(1.7, 9.2, 4.4), 4));
	return fbm(p + 1.6 * q, octaves);
}

vec3 rotate_y(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}

void vertex() {
	obj_dir = normalize(VERTEX);
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 d = obj_dir;
	float h = warped(d * 2.4, 8);
	float lat = abs(d.z);  // the poles lie along Z: the yard orbits over the tropics
	float sea = 1.0 - smoothstep(0.525, 0.535, h);
	vec3 water = mix(deep, ocean, smoothstep(0.3, 0.46, h));
	water = mix(water, shallows, smoothstep(0.5, 0.53, h));
	// Land by latitude (wet near the equator, dry a band out, cold toward the poles) and height.
	float wet = fbm(d * 6.0 + 4.0, 5);
	float dry = smoothstep(0.18, 0.3, lat) * (1.0 - smoothstep(0.42, 0.55, lat)) * 0.9 + smoothstep(0.5, 0.72, wet) * 0.5;
	vec3 ground = mix(forest, grass, smoothstep(0.35, 0.6, wet));
	ground = mix(ground, desert, clamp(dry - 0.35, 0.0, 1.0));
	ground = mix(ground, rock, smoothstep(0.6, 0.72, h));
	ground *= (0.8 + 0.4 * fbm(d * 40.0, 4)) * 0.75;
	vec3 col = mix(ground, water, sea);
	col = mix(col, ice, smoothstep(0.8, 0.88, lat + (h - 0.5) * 0.4));
	// The cloud deck, drifting, and its shadow a little toward the sun.
	vec3 cd = rotate_y(d, TIME * cloud_drift);
	float c = warped(vec3(cd.x * 6.5, cd.y * 6.5, cd.z * 11.0) + 11.0, 7);
	float clouds = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.16, c);
	clouds = max(clouds, smoothstep(0.6, 0.75, fbm(cd * 18.0, 4)) * 0.35 * (1.0 - lat));
	col *= 1.0 - 0.35 * clouds;
	col = mix(col, vec3(0.58, 0.6, 0.64), clouds * 0.85);
	float view_dot = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float air = pow(1.0 - view_dot, 3.0);
	// The air: thicker toward the limb, where it glows with the sunlight it scatters
	// rather than darkening the ground (an albedo haze drew a dark ring round the limb).
	col = mix(col, haze * 0.6, 0.06 + 0.2 * air);
	ALBEDO = col;
	float open_sea = sea * (1.0 - clouds);
	ROUGHNESS = mix(0.95, 0.18, open_sea);
	SPECULAR = mix(0.2, 0.6, open_sea);
	METALLIC = 0.0;
	// City lights on the night side: where land is, clustered, never under cloud.
	float sun_side = dot(world_n, normalize(sun_dir));
	float night = smoothstep(0.05, -0.15, sun_side);
	float towns = smoothstep(0.62, 0.8, fbm(d * 60.0, 3)) * step(0.7, hash(floor(d * 1400.0)));
	float city = (1.0 - sea) * (1.0 - clouds) * towns * (1.0 - smoothstep(0.75, 0.8, lat));
	EMISSION = vec3(1.0, 0.72, 0.38) * city * 1.2 * night;
	// A warm band where day turns to night.
	EMISSION += haze * air * 0.35 * smoothstep(-0.2, 0.3, sun_side);
	EMISSION += vec3(0.9, 0.4, 0.15) * exp(-pow(sun_side * 12.0, 2.0)) * 0.03 * (0.3 + air);
}

void light() {
	float n = dot(NORMAL, LIGHT);
	// Soft terminator: the air carries a little light past it.
	float wrap = smoothstep(-0.12, 0.25, n);
	DIFFUSE_LIGHT += wrap * LIGHT_COLOR * ATTENUATION * 0.7;
	// The sun's glint on the sea (ROUGHNESS low there).
	vec3 half_v = normalize(LIGHT + VIEW);
	float gloss = 1.0 - ROUGHNESS;
	float spec = pow(max(dot(NORMAL, half_v), 0.0), mix(8.0, 900.0, gloss * gloss)) * gloss * gloss * 6.0;
	SPECULAR_LIGHT += spec * LIGHT_COLOR * ATTENUATION * step(0.0, n);
}
