// G4, the yard's sky as Graphics draws it (flag "graphics.sky"): Core and UI's AlienSky sky
// (same uniforms, so AlienSky still drives the sun and the hour) with a deep blue day, light
// scattered round the sun and along the horizon, painted clouds lit by the sun (gold and
// rose at dusk, blue-grey under the planets at night), a denser star field with a faint
// galaxy band, and stars and clouds in front of or behind the planets as they should be.
// No TIME: a sky that reads TIME redraws its reflection map every frame. The clouds move
// with `cloud_offset`, which Graphics sets from the hour.
shader_type sky;

// Where the sun is (toward the sun, world space) and how high: 1 noon, 0 horizon, <0 night.
uniform vec3 sun_dir = vec3(0.3, 0.6, -0.7);
uniform float day : hint_range(0.0, 1.0) = 1.0;
uniform vec3 zenith_day : source_color = vec3(0.10, 0.34, 0.42);
uniform vec3 horizon_day : source_color = vec3(0.62, 0.78, 0.66);
uniform vec3 zenith_dusk : source_color = vec3(0.16, 0.10, 0.26);
uniform vec3 horizon_dusk : source_color = vec3(0.98, 0.46, 0.22);
uniform vec3 zenith_night : source_color = vec3(0.012, 0.008, 0.035);
uniform vec3 horizon_night : source_color = vec3(0.07, 0.035, 0.11);
uniform vec3 ground_color : source_color = vec3(0.24, 0.13, 0.09);
uniform float star_brightness = 3.0;
// How much daylight air veils the planets (0 = crisp discs).
uniform float day_veil : hint_range(0.0, 1.0) = 1.0;
// Scattered light: the sun's halo (Mie) and the bright band along the horizon.
uniform float halo = 0.35;
uniform float horizon_glow = 0.18;
// Clouds: how much of the sky they cover (0 clear .. 1 overcast), their scale, where the
// wind has blown them, how high they ride (larger: flatter toward the horizon).
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_scale = 1.6;
uniform vec2 cloud_offset = vec2(0.0);
uniform float cloud_height = 0.18;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 cloud_shade : source_color = vec3(0.42, 0.48, 0.58);
uniform vec3 cloud_night : source_color = vec3(0.05, 0.055, 0.09);
// Faint stars between the bright ones, and the galaxy's band.
uniform float faint_stars = 1.0;
uniform float galaxy = 0.6;
uniform float nebula = 1.0;
// How bright the planets are against the sky (1 as drawn; lower sits them back in the air).
uniform float planet_dim : hint_range(0.0, 1.0) = 1.0;

// Each planet: direction (normalised in code), angular radius (radians), two colours.
uniform vec3 giant_dir = vec3(-0.55, 0.42, -0.72);
uniform float giant_radius = 0.30;
uniform vec3 giant_a : source_color = vec3(0.86, 0.62, 0.38);
uniform vec3 giant_b : source_color = vec3(0.52, 0.28, 0.20);
uniform vec3 ring_normal = vec3(0.25, 0.92, 0.3);
uniform vec3 ice_dir = vec3(0.62, 0.30, -0.73);
uniform float ice_radius = 0.085;
uniform vec3 ice_a : source_color = vec3(0.62, 0.86, 0.96);
uniform vec3 ice_b : source_color = vec3(0.24, 0.42, 0.66);
uniform vec3 moon_dir = vec3(0.12, 0.70, 0.70);
uniform float moon_radius = 0.045;
uniform vec3 moon_a : source_color = vec3(0.70, 0.66, 0.62);
uniform vec3 moon_b : source_color = vec3(0.36, 0.33, 0.31);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float t = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		t += a * noise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return t;
}

vec3 stars(vec3 dir) {
	vec3 p = dir * 260.0;
	vec3 dp = fwidth(p);
	float pixel = max(max(dp.x, dp.y), dp.z);
	vec3 cell = floor(p);
	float h = hash(cell);
	if (h < 0.955) {
		return vec3(0.0);
	}
	vec3 centre = cell + 0.25 + 0.5 * vec3(hash(cell + 1.7), hash(cell + 3.1), hash(cell + 5.3));
	float r = max(0.08, pixel * 0.75);
	float d = length(p - centre);
	float s = smoothstep(r, 0.0, d) * min(1.0, 0.2 / r);
	vec3 tint = mix(vec3(1.0, 0.8, 0.7), vec3(0.7, 0.85, 1.0), hash(cell + 9.0));
	return tint * s * (0.25 + 0.75 * (h - 0.955) / 0.045);
}

// A planet at `centre` (unit direction) of angular radius `rad`, seen along `v`. Returns
// colour in rgb and coverage in a. `kind`: 0 banded gas giant, 1 ice, 2 cratered rock.
vec4 planet(vec3 v, vec3 centre, float rad, vec3 ca, vec3 cb, int kind) {
	float sr = sin(rad);
	// Ray from the eye (origin) to a sphere of radius sin(rad) at distance 1.
	float b = dot(v, centre);
	float disc = b * b - (1.0 - sr * sr);
	if (disc < 0.0 || b <= 0.0) {
		return vec4(0.0);
	}
	float t = b - sqrt(disc);
	vec3 n = normalize(v * t - centre);
	// Planet frame: tilt the bands a little.
	vec3 up = normalize(vec3(0.22, 1.0, 0.1));
	float lat = dot(n, up);
	vec3 col;
	if (kind == 0) {
		float bands = sin(lat * 26.0 + fbm(n * 5.0) * 3.2) * 0.5 + 0.5;
		float storm = smoothstep(0.08, 0.0, length(n - normalize(centre * -0.2 + up * 0.35 - v * 0.9)) - 0.12);
		col = mix(cb, ca, bands) * (0.85 + 0.3 * fbm(n * 14.0));
		col = mix(col, vec3(0.9, 0.42, 0.26), storm * 0.7);
	} else if (kind == 1) {
		float land = smoothstep(0.48, 0.56, fbm(n * 6.0));
		col = mix(cb, ca, land);
		col = mix(col, vec3(0.95), smoothstep(0.75, 0.9, abs(lat)));
	} else {
		float crater = smoothstep(0.62, 0.7, fbm(n * 11.0));
		col = mix(ca, cb, crater + 0.4 * fbm(n * 30.0));
	}
	float lit = max(dot(n, sun_dir), 0.0);
	// The night side keeps a trace of light, so the disc still reads against the stars.
	vec3 shade = col * (lit * 1.25 + 0.035);
	// A thin rim of atmosphere on the lit limb.
	float limb = pow(1.0 - max(dot(n, -v), 0.0), 3.0);
	shade += mix(ca, vec3(0.6, 0.8, 1.0), 0.5) * limb * (0.15 + lit) * 0.6;
	float edge = smoothstep(0.0, 0.0025, disc);
	return vec4(shade, edge);
}

// The giant's rings: a flat annulus round its centre, behind or in front of the disc.
vec4 rings(vec3 v, vec3 centre, float rad, vec3 tint, out float ring_t) {
	ring_t = 1e9;
	vec3 nrm = normalize(ring_normal);
	float denom = dot(v, nrm);
	if (abs(denom) < 1e-4) {
		return vec4(0.0);
	}
	float t = dot(centre, nrm) / denom;
	if (t <= 0.0) {
		return vec4(0.0);
	}
	float sr = sin(rad);
	float r = length(v * t - centre) / sr;
	if (r < 1.35 || r > 2.3) {
		return vec4(0.0);
	}
	ring_t = t;
	float band = 0.55 + 0.45 * sin(r * 40.0) * sin(r * 13.0);
	float gap = smoothstep(0.02, 0.0, abs(r - 1.85) - 0.03);
	float a = band * (1.0 - gap) * smoothstep(1.35, 1.42, r) * smoothstep(2.3, 2.2, r) * 0.8;
	float lit = 0.35 + 0.65 * abs(dot(nrm, sun_dir));
	return vec4(tint * lit, a);
}

// Clouds seen along v: rgb colour, a coverage.
vec4 clouds(vec3 v, vec3 sun_col) {
	if (v.y <= 0.0) {
		return vec4(0.0);
	}
	vec2 uv = v.xz / (v.y + cloud_height) * cloud_scale + cloud_offset;
	vec3 p = vec3(uv, 0.37);
	float d = fbm(p) + 0.5 * fbm(p * 2.3 + vec3(3.1, 0.0, 1.7)) - 0.25;
	float shape = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, d);
	// Thinner toward the horizon, where the layer is seen edge on and through more air.
	shape *= smoothstep(0.0, 0.16, v.y);
	if (shape <= 0.001) {
		return vec4(0.0);
	}
	// Lit from the sun's side: sample a little toward the sun for a cheap self-shadow.
	vec2 toward = normalize(sun_dir.xz + 1e-4) * 0.18;
	float ahead = fbm(p + vec3(toward, 0.0));
	float lit = clamp(0.55 + (d - ahead) * 2.2, 0.0, 1.0);
	float sd = max(dot(v, sun_dir), 0.0);
	vec3 day_col = mix(cloud_shade, cloud_lit * sun_col, lit) + sun_col * pow(sd, 6.0) * 0.6 * shape;
	vec3 col = mix(cloud_night, day_col, smoothstep(0.0, 0.3, day));
	return vec4(col, shape * 0.92);
}

// A band of faint unresolved stars and dust across the night.
vec3 galaxy_band(vec3 v) {
	vec3 axis = normalize(vec3(0.35, 0.55, -0.76));
	float across = dot(v, axis);
	float band = exp(-across * across * 18.0);
	float grain = fbm(v * 9.0) * fbm(v * 23.0 + vec3(2.0));
	float dust = smoothstep(0.35, 0.6, fbm(v * 5.0 + vec3(11.0)));
	return vec3(0.55, 0.6, 0.85) * band * (0.25 + grain * 1.6) * (1.0 - dust * 0.7);
}

// The faint stars: many more, much dimmer, finer than stars().
vec3 faint(vec3 dir) {
	vec3 p = dir * 620.0;
	vec3 cell = floor(p);
	float h = hash(cell);
	if (h < 0.93) {
		return vec3(0.0);
	}
	vec3 centre = cell + 0.5;
	float s = smoothstep(0.45, 0.0, length(p - centre));
	return vec3(0.8, 0.85, 1.0) * s * (h - 0.93) * 6.0;
}

void sky() {
	vec3 v = EYEDIR;
	float h = v.y;
	float dusk = clamp(1.0 - abs(day - 0.25) * 4.0, 0.0, 1.0) * step(0.0, day + 0.05);
	vec3 zen = mix(zenith_night, zenith_day, smoothstep(0.0, 0.45, day));
	vec3 hor = mix(horizon_night, horizon_day, smoothstep(0.0, 0.45, day));
	zen = mix(zen, zenith_dusk, dusk * 0.6);
	// Dusk glows hottest on the sun's side of the sky.
	float toward = max(dot(normalize(vec3(v.x, 0.0, v.z) + 1e-4), normalize(vec3(sun_dir.x, 0.0, sun_dir.z) + 1e-4)), 0.0);
	hor = mix(hor, horizon_dusk, dusk * (0.35 + 0.65 * toward));
	vec3 col = mix(hor, zen, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		col = mix(hor * 0.8, ground_color * (0.15 + 0.85 * day), smoothstep(0.0, -0.12, h));
	}
	// The sun: a hot disc and a wide glow.
	float sd = max(dot(v, sun_dir), 0.0);
	col += vec3(1.0, 0.85, 0.6) * pow(sd, 900.0) * 30.0 * step(-0.02, sun_dir.y);
	col += mix(vec3(1.0, 0.6, 0.3), vec3(1.0, 0.95, 0.85), day) * pow(sd, 12.0) * 0.45 * smoothstep(-0.1, 0.1, sun_dir.y);
	// Scattered light: a wide halo round the sun and a bright band of air along the horizon,
	// warmest on the sun's side.
	vec3 sun_col = mix(vec3(1.0, 0.55, 0.3), vec3(1.0, 0.96, 0.9), smoothstep(0.05, 0.45, day));
	float up = smoothstep(-0.12, 0.05, sun_dir.y);
	col += sun_col * pow(sd, 4.0) * halo * up;
	col += mix(hor, sun_col, 0.3 + 0.4 * toward) * exp(-abs(h) * 14.0) * horizon_glow * up * (0.4 + 0.6 * day);
	// Stars come out as the light goes.
	float night = 1.0 - smoothstep(0.0, 0.35, day);
	if (h > 0.0) {
		col += stars(v) * star_brightness * night * smoothstep(0.0, 0.15, h);
		col += faint(v) * faint_stars * night * smoothstep(0.0, 0.2, h);
		col += galaxy_band(v) * galaxy * 0.08 * night * smoothstep(0.0, 0.2, h);
		float neb = fbm(v * 3.0 + vec3(7.0)) * smoothstep(0.2, 0.0, abs(dot(v, normalize(vec3(0.4, 0.3, 1.0)))));
		col += vec3(0.25, 0.08, 0.32) * neb * night * 0.9 * nebula;
	}
	// Planets show by day as pale discs and at night in full colour. Haze near the horizon.
	vec3 sky = col;
	float haze = smoothstep(-0.02, 0.25, h);
	float vis = mix(0.8, 1.0, night) * haze;
	vec3 dimmed = mix(sky, vec3(0.0), night);   // a dim planet fades toward the air by day, darkens by night
	vec4 moon = planet(v, normalize(moon_dir), moon_radius, moon_a, moon_b, 2);
	moon.rgb = mix(dimmed, moon.rgb, planet_dim);
	col = mix(col, col * (1.0 - vis) + moon.rgb * vis + hor * 0.15 * (1.0 - night), moon.a);
	vec4 ice = planet(v, normalize(ice_dir), ice_radius, ice_a, ice_b, 1);
	ice.rgb = mix(dimmed, ice.rgb, planet_dim);
	col = mix(col, col * (1.0 - vis) + ice.rgb * vis + hor * 0.15 * (1.0 - night), ice.a);
	vec3 gc = normalize(giant_dir);
	float ring_t;
	vec4 ring = rings(v, gc, giant_radius, mix(giant_a, vec3(0.9), 0.4), ring_t);
	vec4 giant = planet(v, gc, giant_radius, giant_a, giant_b, 0);
	giant.rgb = mix(dimmed, giant.rgb, planet_dim);
	ring.rgb = mix(dimmed, ring.rgb, planet_dim);
	ring.a *= mix(0.5, 1.0, planet_dim);
	float giant_t = dot(v, gc);
	// Rings behind the disc first, then the disc, then rings in front of it.
	if (ring_t > giant_t || giant.a < 0.01) {
		col = mix(col, ring.rgb * vis + col * (1.0 - vis * 0.7), ring.a * haze);
		col = mix(col, col * (1.0 - vis) + giant.rgb * vis + hor * 0.12 * (1.0 - night), giant.a);
	} else {
		col = mix(col, col * (1.0 - vis) + giant.rgb * vis + hor * 0.12 * (1.0 - night), giant.a);
		col = mix(col, ring.rgb * vis + col * (1.0 - vis * 0.7), ring.a * haze);
	}
	// By day the planets sit behind the whole depth of the air: veil them toward the sky,
	// more near the horizon, so the city's hazed far towers read as nearer than the discs
	// instead of pale cut-outs over a dark planet.
	float cover = max(max(moon.a, ice.a), max(giant.a, ring.a * haze));
	float veil = (1.0 - night) * mix(0.62, 0.3, smoothstep(0.0, 0.6, h)) * day_veil;
	col = mix(col, sky, cover * veil);
	// Clouds ride in front of everything in the sky; the air veils them toward the horizon.
	vec4 cl = clouds(v, sun_col);
	vec3 cloud = mix(cl.rgb, hor, (1.0 - smoothstep(0.0, 0.35, h)) * 0.55);
	col = mix(col, cloud, cl.a);
	COLOR = col;
}
