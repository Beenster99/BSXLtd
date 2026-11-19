shader_type sky;
// Deep space (0.4.1 playtest: "no planet nearby, it may be cooler to be in deep space with a
// stunning galaxy as a backdrop, maybe one or two distant planets"): black, three layers of
// stars of varied brightness and colour, the home galaxy's band with its dust lanes and glowing
// knots, a great spiral galaxy close enough to fill a quarter of the sky (a bright core, two
// arms wound round it with blue star clusters and pink nebulae, dust lanes, a halo), coloured
// nebula clouds, two distant planets (a ringed gas giant and a small blue world) lit from the
// sun's side, and the sun's disc with its corona and a long soft glare.

uniform float star_density = 0.0035;
uniform float star_brightness = 2.6;
// The home galaxy's plane (its normal) and how bright its band is.
uniform vec3 band_axis = vec3(0.3, 0.85, -0.42);
uniform float band_strength = 0.2;
uniform vec3 band_colour : source_color = vec3(0.62, 0.66, 0.82);
uniform vec3 core_colour : source_color = vec3(1.0, 0.82, 0.62);
// Where along the band its bright core lies.
uniform vec3 core_dir = vec3(-0.7, 0.1, -0.7);
uniform vec3 nebula_a : source_color = vec3(0.6, 0.16, 0.38);
uniform vec3 nebula_b : source_color = vec3(0.12, 0.34, 0.62);
uniform float nebula_strength = 0.09;
// The spiral: which way it lies, its disc's normal (its tilt to us), how wide it shows
// (radians, its disc's radius), its brightness.
uniform vec3 spiral_dir = vec3(-0.35, 0.42, -0.84);
uniform vec3 spiral_normal = vec3(0.25, 0.75, 0.6);
uniform float spiral_radius = 0.8;
uniform float spiral_strength = 0.85;
uniform vec3 spiral_core : source_color = vec3(1.0, 0.86, 0.66);
uniform vec3 spiral_arm : source_color = vec3(0.55, 0.7, 1.0);
uniform vec3 spiral_pink : source_color = vec3(1.0, 0.4, 0.62);
// The distant planets: direction, angular radius (radians) and colours; the giant's rings.
uniform vec3 giant_dir = vec3(0.72, 0.18, 0.67);
uniform float giant_radius = 0.06;
uniform vec3 giant_a : source_color = vec3(0.86, 0.68, 0.46);
uniform vec3 giant_b : source_color = vec3(0.6, 0.4, 0.28);
uniform vec3 ring_normal = vec3(0.2, 0.95, 0.25);
uniform vec3 small_dir = vec3(-0.82, -0.08, 0.56);
uniform float small_radius = 0.014;
uniform vec3 small_colour : source_color = vec3(0.4, 0.62, 0.95);
uniform vec3 sun_colour : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 sun_way = vec3(0.55, 0.45, -0.35);

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

// The spiral galaxy: where `dir` meets its disc (polar, in units of its radius) and its light.
vec3 spiral(vec3 dir) {
	vec3 c = normalize(spiral_dir);
	vec3 n = normalize(spiral_normal);
	// Its disc's own axes, u along its long side as we see it.
	vec3 u = normalize(cross(n, c));
	if (length(cross(n, c)) < 0.01) {
		u = normalize(cross(n, vec3(0.0, 1.0, 0.0)));
	}
	vec3 v = cross(n, u);
	// A ray from us along `dir` meets the disc's plane (the disc a unit away, through c).
	float denom = dot(dir, n);
	if (abs(denom) < 0.02 || dot(dir, c) < 0.2) {
		return vec3(0.0);
	}
	float t = dot(c, n) / denom;
	if (t <= 0.0) {
		return vec3(0.0);
	}
	vec3 hit = dir * t - c;
	vec2 q = vec2(dot(hit, u), dot(hit, v)) / spiral_radius;
	float r = length(q);
	if (r > 1.6) {
		return vec3(0.0);
	}
	float a = atan(q.y, q.x);
	// Two log-spiral arms, wound about three times, with clumps along them.
	float wind = log(max(r, 0.02)) * 4.2;
	float arms = pow(0.5 + 0.5 * cos(2.0 * (a - wind)), 3.0);
	vec3 pd = vec3(q * 9.0, 0.0);
	float clumps = fbm(pd + vec3(2.0, 5.0, 1.0));
	float fade = exp(-r * 1.5);
	float disc = smoothstep(1.25, 0.0, r);
	float arm_light = arms * (0.5 + 1.1 * clumps) * disc * (0.45 + fade) * 1.6;
	// Dust lanes on the arms' inner edges.
	float lanes = pow(0.5 + 0.5 * cos(2.0 * (a - wind) + 0.9), 8.0) * smoothstep(0.08, 0.3, r) * disc;
	float dust = lanes * smoothstep(0.35, 0.7, fbm(pd * 1.7 - 3.0));
	// Knots of new stars (blue) and glowing gas (pink) along the arms.
	float knots = pow(max(fbm(pd * 2.4 + 7.0) - 0.45, 0.0) * 3.0, 3.0) * arms * disc;
	float pink = pow(max(fbm(pd * 2.0 - 11.0) - 0.5, 0.0) * 3.2, 3.0) * arms * disc;
	float bulge = exp(-r * r * 40.0) * 2.4 + exp(-r * 9.0) * 0.6;
	float halo = exp(-r * 1.8) * 0.12;
	vec3 col = spiral_arm * arm_light * 0.9 + spiral_core * bulge + spiral_arm * halo;
	col += vec3(0.75, 0.88, 1.0) * knots * 1.6 + spiral_pink * pink * 1.2;
	col *= 1.0 - 0.75 * dust;
	// Its own fine grain of unresolved stars.
	col += spiral_arm * pow(noise(pd * 18.0), 8.0) * disc * 0.6;
	// Seen near edge on its light thickens (a tilted disc).
	return col * spiral_strength * (0.6 + 0.6 / max(abs(dot(dir, n)), 0.25) * 0.25);
}

// A planet's disc at `pdir`, `rad` across: lit on the sun's side, dark on the other, its
// edge a thin glow. Returns colour and coverage in alpha.
vec4 planet(vec3 dir, vec3 pdir, float rad, vec3 a_col, vec3 b_col, float banded) {
	vec3 c = normalize(pdir);
	float ang = acos(clamp(dot(dir, c), -1.0, 1.0));
	if (ang > rad * 1.6) {
		return vec4(0.0);
	}
	vec3 u = normalize(cross(c, vec3(0.0, 1.0, 0.0)));
	vec3 v = cross(u, c);
	vec2 q = vec2(dot(dir - c, u), dot(dir - c, v)) / rad;
	float r2 = dot(q, q);
	float cover = smoothstep(1.02, 0.98, sqrt(r2));
	vec3 normal = normalize(q.x * u + q.y * v - sqrt(max(1.0 - r2, 0.0)) * c);
	float lit = clamp(dot(normal, normalize(sun_way)) * 1.1 + 0.05, 0.0, 1.0);
	float bands = 0.5 + 0.5 * sin(q.y * 14.0 + fbm(vec3(q * 3.0, 1.0)) * 4.0);
	vec3 surf = mix(a_col, b_col, mix(0.3, bands, banded));
	surf *= 0.85 + 0.3 * fbm(vec3(q * 6.0, 4.0));
	vec3 col = surf * (lit * 1.8 + 0.03);
	// A thin bright limb on the lit side, a little air.
	float limb = smoothstep(0.7, 1.0, sqrt(r2)) * cover * lit;
	col += a_col * limb * 0.4;
	return vec4(col, cover);
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
			+ stars(dir, 140.0, 0.006 * crowd) * 1.6 + stars(dir, 60.0, 0.004) * 2.4;
	float tint = hash(floor(dir * 300.0) + 3.3);
	vec3 star_col = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.7), tint);
	vec3 col = star_col * s * star_brightness;
	// The band's glow, clumpy, darkened by dust lanes down its middle.
	float clumps = fbm(dir * 9.0);
	float dust = smoothstep(0.45, 0.75, fbm(dir * 6.0 + 7.0)) * exp(-pow(across * 9.0, 2.0));
	float glow = band * (0.35 + 0.9 * clumps) * (1.0 - 0.85 * dust);
	col += mix(band_colour, core_colour, core) * glow * band_strength * (1.0 + core * 3.0);
	// Unresolved stars: a fine grain of light in the band.
	col += band_colour * pow(noise(dir * 420.0), 6.0) * band * 0.3;
	// Nebula clouds, wispy, in two colours, off the band.
	float n1 = smoothstep(0.5, 0.85, fbm(dir * 3.5 + 11.0)) * exp(-pow(across * 1.6, 2.0));
	float n2 = smoothstep(0.5, 0.85, fbm(dir * 4.5 - 5.0)) * exp(-pow((across - 0.4) * 2.0, 2.0));
	float wisps = 0.6 + 0.8 * fbm(dir * 14.0);
	col += (nebula_a * n1 + nebula_b * n2) * nebula_strength * wisps;
	col += spiral(dir);
	// The distant planets, in front of all that.
	vec4 g = planet(dir, giant_dir, giant_radius, giant_a, giant_b, 1.0);
	// The giant's rings: a flat annulus round it, behind it on the far side, in front on ours.
	vec3 gc = normalize(giant_dir);
	vec3 rn = normalize(ring_normal);
	float facing = dot(dir, rn);
	float rt = dot(gc, rn) / (abs(facing) < 0.0001 ? 0.0001 : facing);
	vec3 rhit = dir * rt - gc;
	float rr = length(rhit) / giant_radius;
	float ring = smoothstep(1.35, 1.45, rr) * smoothstep(2.4, 2.2, rr) * (0.75 + 0.25 * sin(rr * 30.0)) * step(0.0, rt);
	ring *= 1.0 - smoothstep(2.0, 2.05, rr) * smoothstep(2.12, 2.07, rr);   // a gap in them
	vec3 ring_col = giant_a * 0.9 * ring;
	bool ring_front = rt < 1.0;
	if (!ring_front) {
		col = mix(col, ring_col, ring * 0.85);
	}
	col = mix(col, g.rgb, g.a);
	if (ring_front) {
		col = mix(col, ring_col, ring * 0.85);
	}
	vec4 p2 = planet(dir, small_dir, small_radius, small_colour, vec3(0.9, 0.95, 1.0), 0.0);
	col = mix(col, p2.rgb, p2.a);
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
