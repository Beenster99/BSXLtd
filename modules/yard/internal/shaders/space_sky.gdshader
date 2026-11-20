shader_type sky;
// Deep space (0.4.1 playtest: "no planet nearby, it may be cooler to be in deep space with a
// stunning galaxy as a backdrop, maybe one or two distant planets"): black, layers of stars
// of varied brightness and colour, the home galaxy's band with its star clouds and dust lanes,
// a great spiral galaxy close enough to fill a quarter of the sky (a bright core, two arms
// wound round it with blue star clusters and pink nebulae, dust lanes, a halo), coloured
// nebula clouds, two distant planets (a ringed gas giant and a small blue world) lit from the
// sun's side, and the sun's disc with its corona and a long soft glare.
//
// High definition (20 Nov: "make the galaxy super high definition"): everything is worked out
// per pixel at the screen's own resolution, so a bigger screen shows more. Stars are drawn as
// points one pixel wide wherever they are (no shimmer, no blocks), and a star layer too fine for
// the screen fades into the soft glow it would make. Cloud and dust detail adds finer layers
// (octaves) until they reach the pixel size, and stops there. `detail` (from the player's Model
// detail setting) caps how fine it goes and how many star layers there are.

// 0 standard, 1 high, 2 ultra.
uniform int detail : hint_range(0, 2) = 2;
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
// The distant planets: direction, angular radius (radians) and colours; the giant's rings
// (their plane's normal is also the giant's spin axis).
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

// Each octave turned against the last, so the layers never line up into a grid.
const mat3 TURN = mat3(vec3(0.00, 0.80, 0.60), vec3(-0.80, 0.36, -0.48), vec3(-0.60, -0.48, 0.64));

// Hashes without sine (Hoskins): even, with no stripes at large coordinates.
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Gradient noise, smooth to the second derivative: 0..1, mean 0.5.
float gnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(hash33(i) * 2.0 - 1.0, f);
	float b = dot(hash33(i + vec3(1, 0, 0)) * 2.0 - 1.0, f - vec3(1, 0, 0));
	float c = dot(hash33(i + vec3(0, 1, 0)) * 2.0 - 1.0, f - vec3(0, 1, 0));
	float d = dot(hash33(i + vec3(1, 1, 0)) * 2.0 - 1.0, f - vec3(1, 1, 0));
	float e = dot(hash33(i + vec3(0, 0, 1)) * 2.0 - 1.0, f - vec3(0, 0, 1));
	float g = dot(hash33(i + vec3(1, 0, 1)) * 2.0 - 1.0, f - vec3(1, 0, 1));
	float h = dot(hash33(i + vec3(0, 1, 1)) * 2.0 - 1.0, f - vec3(0, 1, 1));
	float k = dot(hash33(i + vec3(1, 1, 1)) * 2.0 - 1.0, f - vec3(1, 1, 1));
	float n = mix(mix(mix(a, b, u.x), mix(c, d, u.x), u.y), mix(mix(e, g, u.x), mix(h, k, u.x), u.y), u.z);
	return clamp(0.5 + n * 1.1, 0.0, 1.0);
}

// Fractal noise, `oct` octaves at most; `fp` is a pixel's size in p's units, and octaves finer
// than a pixel fade out and are skipped (so it is sharp at any resolution and never shimmers).
float fbm(vec3 p, int oct, float fp) {
	float v = 0.0;
	float a = 0.5;
	float norm = 0.0;
	float f = 1.0;
	for (int i = 0; i < 10; i++) {
		if (i >= oct) {
			break;
		}
		float keep = 1.0 - smoothstep(0.2, 0.45, fp * f);
		if (keep <= 0.0) {
			break;
		}
		v += a * mix(0.5, gnoise(p), keep);
		norm += a;
		p = TURN * p * 2.03 + vec3(1.7, 9.2, 3.4);
		a *= 0.5;
		f *= 2.03;
	}
	return norm > 0.0 ? v / norm : 0.5;
}

// Ridged noise: thin bright ridges (filaments of dust and gas), 0..1.
float ridged(vec3 p, int oct, float fp) {
	float v = 0.0;
	float a = 0.5;
	float norm = 0.0;
	float f = 1.0;
	float w = 1.0;
	for (int i = 0; i < 10; i++) {
		if (i >= oct) {
			break;
		}
		float keep = 1.0 - smoothstep(0.2, 0.45, fp * f);
		if (keep <= 0.0) {
			break;
		}
		float r = 1.0 - abs(gnoise(p) * 2.0 - 1.0);
		r = r * r * w;
		w = clamp(r * 1.6, 0.0, 1.0);
		v += a * mix(0.3, r, keep);
		norm += a;
		p = TURN * p * 2.07 + vec3(4.1, 2.3, 7.7);
		a *= 0.5;
		f *= 2.07;
	}
	return norm > 0.0 ? v / norm : 0.3;
}

// A star's colour from its temperature (0 cool red .. 1 hot blue).
vec3 star_colour(float t) {
	vec3 c = mix(vec3(1.0, 0.58, 0.34), vec3(1.0, 0.86, 0.7), smoothstep(0.0, 0.3, t));
	c = mix(c, vec3(1.0, 0.97, 0.94), smoothstep(0.3, 0.55, t));
	return mix(c, vec3(0.66, 0.78, 1.0), smoothstep(0.55, 1.0, t));
}

// One layer of stars on a grid of `scale` cells per radian, one star in a `density` share of
// the cells, as points a pixel wide (`px`: a pixel's size, radians). Where a cell is too few
// pixels across to hold a sharp point, the layer fades into its average glow.
vec3 star_layer(vec3 dir, float scale, float density, float px, float hot) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	float pxc = px * scale;
	float sharp = 1.0 - smoothstep(0.3, 0.5, pxc);
	vec3 h = hash33(cell);
	vec3 point = vec3(0.0);
	if (sharp > 0.0 && h.x < density) {
		float b = hash13(cell + 17.31);
		float mag = 0.16 + 0.84 * pow(b, 5.0);
		vec3 centre = cell + 0.3 + 0.4 * h.yzx;
		vec3 off = p - centre;
		off -= dir * dot(off, dir);
		float s = 0.55 * pxc;
		point = star_colour(clamp(h.x / density * 1.1 - 0.1 + hot, 0.0, 1.0)) * mag * exp(-dot(off, off) / (2.0 * s * s));
	}
	// Stars per pixel times each one's light (density x 1.5 cells x mean magnitude x its spread),
	// held at what it is where they stop being sharp, so far too fine a layer is a faint grain
	// and never a grey wash.
	float pc = min(pxc, 0.5);
	vec3 glow = vec3(0.92, 0.94, 1.0) * density * 1.5 * 0.3 * 1.9 * pc * pc;
	return mix(glow, point, sharp);
}

// The brightest few stars: a soft halo and four fine diffraction spikes.
vec3 bright_stars(vec3 dir, float px) {
	float scale = 22.0;
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	vec3 h = hash33(cell + 51.7);
	if (h.x > 0.035) {
		return vec3(0.0);
	}
	vec3 centre = cell + 0.45 + 0.1 * h.yzx;
	vec3 cdir = normalize(centre);
	vec3 off = dir - cdir;
	off -= cdir * dot(off, cdir);
	vec3 u = normalize(cross(cdir, vec3(0.0, 1.0, 0.0)));
	vec3 v = cross(cdir, u);
	vec2 q = vec2(dot(off, u), dot(off, v));
	float d = length(q);
	float b = hash13(cell + 3.9);
	float mag = 0.35 + 0.65 * b * b;
	vec3 col = star_colour(fract(h.x * 29.0));
	float s = 0.6 * px;
	float core = exp(-d * d / (2.0 * s * s)) * 3.0;
	float halo = exp(-d / (px * 2.2)) * 0.25 + exp(-d / 0.004) * 0.03;
	float w = px * 0.7;
	float len = 0.0035 + 0.006 * b;
	float spikes = (exp(-abs(q.y) / w) * exp(-abs(q.x) / len) + exp(-abs(q.x) / w) * exp(-abs(q.y) / len)) * 0.35 * smoothstep(0.4, 0.9, b);
	return col * mag * (core + halo + spikes);
}

// The spiral galaxy: where `dir` meets its disc (polar, in units of its radius) and its light.
// `ext` is how much light the home galaxy's dust in front of it lets through.
vec3 spiral(vec3 dir, float px, int oct, bool cube) {
	vec3 c = normalize(spiral_dir);
	vec3 n = normalize(spiral_normal);
	vec3 u = normalize(cross(n, c));
	if (length(cross(n, c)) < 0.01) {
		u = normalize(cross(n, vec3(0.0, 1.0, 0.0)));
	}
	vec3 v = cross(n, u);
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
	// A pixel's size on the disc (its units), longest way across (the disc is tilted to us).
	float qpx = px * t / spiral_radius / max(abs(denom), 0.12);
	float a = atan(q.y, q.x);
	vec3 pd = vec3(q, 0.37);
	// Two log-spiral arms, wound about three times, their line wandering (flocculent) and
	// breaking into spurs.
	float wind = log(max(r, 0.015)) * 4.2;
	float wander = (fbm(pd * 3.0 + 2.0, oct, qpx * 3.0) - 0.5) * 2.2;
	float phase = 2.0 * (a - wind) + wander;
	float arms = pow(0.5 + 0.5 * cos(phase), 2.6);
	float spurs = pow(0.5 + 0.5 * cos(phase * 2.0 + 1.3 + wander * 2.0), 6.0) * 0.35;
	float disc = smoothstep(1.3, 0.0, r);
	float fade = exp(-r * 1.6);
	// Clumps of stars along the arms, from cloud size down to the pixel.
	float clumps = fbm(pd * 7.0, oct, qpx * 7.0);
	float grain = fbm(pd * 31.0 + 5.0, oct, qpx * 31.0);
	float arm_light = (arms + spurs) * (0.35 + 1.3 * smoothstep(0.3, 0.75, clumps)) * (0.35 + 1.3 * smoothstep(0.25, 0.75, grain));
	arm_light *= disc * (0.4 + fade) * 1.5;
	// Dust lanes along the arms' inner edges: dark filaments.
	float lane = pow(0.5 + 0.5 * cos(phase + 0.85), 6.0) * smoothstep(0.06, 0.25, r) * disc;
	float fil = ridged(pd * 9.0 + 3.0, oct, qpx * 9.0);
	float dust = clamp(lane * (0.35 + 1.3 * fil), 0.0, 1.0);
	// Knots of new stars (blue) and glowing gas (pink) on the arms.
	float knots = pow(max(fbm(pd * 13.0 + 7.0, oct, qpx * 13.0) - 0.56, 0.0) * 4.0, 2.0) * arms * disc;
	float pink = pow(max(fbm(pd * 17.0 - 11.0, oct, qpx * 17.0) - 0.6, 0.0) * 4.5, 2.0) * (arms + spurs) * disc;
	// The core: a warm bulge (not blown out) with its own dust ring, and a faint halo.
	float bulge = exp(-r * r * 90.0) * 1.2 + exp(-r * 10.0) * 0.28;
	float halo = exp(-r * 1.9) * 0.1;
	vec3 col = spiral_arm * arm_light * 0.55 + spiral_core * bulge + mix(spiral_core, spiral_arm, 0.5) * halo;
	col += vec3(0.72, 0.86, 1.0) * knots * 1.4 + spiral_pink * pink * 1.5;
	col *= 1.0 - 0.8 * dust * smoothstep(0.02, 0.12, r);
	// Its resolved clusters: points of light on the arms.
	if (!cube) {
		float scale = 260.0;
		vec3 cp = vec3(q * scale, 0.5);
		vec3 cell = floor(cp);
		vec3 h = hash33(cell + 91.0);
		float pxc = qpx * scale * 0.45;
		float sharp = 1.0 - smoothstep(0.3, 0.5, pxc);
		float chance = (arms + spurs * 0.6) * disc * 0.5 + 0.03 * disc;
		if (sharp > 0.0 && h.x < chance) {
			vec2 off = cp.xy - (cell.xy + 0.3 + 0.4 * h.yz);
			float s = 0.55 * pxc;
			float m = 0.3 + 0.7 * pow(hash13(cell), 4.0);
			col += mix(vec3(0.7, 0.85, 1.0), vec3(1.0, 0.8, 0.9), step(0.8, h.z)) * m * exp(-dot(off, off) / (2.0 * s * s)) * sharp * 0.9;
		}
	}
	// Seen near edge on its light thickens (a tilted disc).
	return col * spiral_strength * (0.6 + 0.6 / max(abs(dot(dir, n)), 0.25) * 0.25);
}

// A turn of `p` into the giant's own frame: x and z round its equator, y up its spin axis.
mat3 giant_frame(vec3 rn) {
	vec3 ex = normalize(cross(rn, vec3(0.31, 0.13, 0.94)));
	vec3 ez = cross(ex, rn);
	return mat3(ex, rn, ez);
}

// How much the giant's rings hide light at `rr` (giant radii from its middle): 0..1.
float ring_density(float rr, float rpx, int oct) {
	if (rr < 1.22 || rr > 2.45) {
		return 0.0;
	}
	float inner_c = smoothstep(1.22, 1.3, rr) * 0.25;                       // the faint inner ring
	float main_b = smoothstep(1.43, 1.5, rr) * (1.0 - smoothstep(2.0, 2.03, rr));   // the bright one
	float outer_a = smoothstep(2.1, 2.13, rr) * (1.0 - smoothstep(2.36, 2.42, rr)) * 0.7;
	float base = max(inner_c * (1.0 - smoothstep(1.4, 1.45, rr)), max(main_b, outer_a));
	// Ringlets: fine bands across their width, as fine as the pixel allows.
	float lets = fbm(vec3(rr * 28.0, 0.3, 0.7), oct, rpx * 28.0);
	float fine = fbm(vec3(rr * 140.0, 1.1, 0.2), oct, rpx * 140.0);
	float gap = 1.0 - (1.0 - smoothstep(0.0, 0.006, abs(rr - 2.3))) * 0.9;    // a narrow gap
	return clamp(base * (0.2 + 1.3 * smoothstep(0.3, 0.7, lets)) * (0.55 + 0.8 * smoothstep(0.25, 0.75, fine)) * gap, 0.0, 1.0);
}

// The ringed gas giant: colour, and coverage in alpha. Bands, swirls at their edges, a great
// storm, a soft dusk, and the rings' shadow across it.
vec4 giant(vec3 dir, float px, int oct, vec3 sun) {
	vec3 c = normalize(giant_dir);
	float rad = giant_radius;
	float ang = acos(clamp(dot(dir, c), -1.0, 1.0));
	if (ang > rad * 1.15) {
		return vec4(0.0);
	}
	vec3 u = normalize(cross(c, vec3(0.0, 1.0, 0.0)));
	vec3 v = cross(u, c);
	vec2 q = vec2(dot(dir - c, u), dot(dir - c, v)) / rad;
	float r = length(q);
	float edge = px / rad;
	float cover = 1.0 - smoothstep(1.0 - edge, 1.0 + edge, r);
	vec3 rn = normalize(ring_normal);
	vec3 col = vec3(0.0);
	// A little air past its edge, lit on the sun's side.
	vec3 rim_n = normalize(q.x * u + q.y * v);
	float air = exp(-max(r - 1.0, 0.0) * 30.0) * smoothstep(1.15, 1.0, r) * clamp(dot(rim_n, sun) + 0.3, 0.0, 1.0);
	if (r < 1.0 + edge) {
		float r2 = min(r * r, 1.0);
		vec3 normal = normalize(q.x * u + q.y * v - sqrt(1.0 - r2) * c);
		vec3 lp = normal * giant_frame(rn);   // into its own frame
		float lat = lp.y;
		float fp = edge / max(sqrt(1.0 - r2), 0.15);
		// Bands, their edges churned by eddies.
		float swirl = fbm(lp * 4.0 + 3.0, oct, fp * 4.0);
		float lat2 = lat + (swirl - 0.5) * 0.09 + (fbm(lp * vec3(9.0, 2.0, 9.0) + 8.0, oct, fp * 9.0) - 0.5) * 0.05;
		float belts = 0.5 + 0.32 * sin(lat2 * 21.0) + 0.18 * sin(lat2 * 53.0 + 1.3);
		float streaks = fbm(lp * vec3(3.0, 60.0, 3.0) + vec3(0.0, 0.0, swirl * 3.0), oct, fp * 60.0);
		vec3 surf = mix(giant_a * 1.08, giant_b * 0.85, clamp(belts + (streaks - 0.5) * 0.5, 0.0, 1.0));
		surf = mix(surf, vec3(0.95, 0.9, 0.82), smoothstep(0.75, 0.95, 1.0 - belts) * 0.25);
		// The poles dimmer and greyer.
		surf = mix(surf, giant_b * 0.6, smoothstep(0.7, 0.95, abs(lat)) * 0.7);
		// A great storm in the southern belts, facing us a little to the sun's side.
		vec3 storm_c = normalize(vec3(0.55, -0.33, -0.77));
		vec3 sd = lp - storm_c;
		float storm = exp(-(sd.x * sd.x + sd.z * sd.z) * 140.0 - sd.y * sd.y * 520.0);
		surf = mix(surf, vec3(0.78, 0.42, 0.3), smoothstep(0.15, 0.6, storm) * 0.8);
		surf *= 1.0 - 0.25 * smoothstep(0.55, 0.8, storm) * (1.0 - smoothstep(0.8, 1.0, storm));
		// Light: a soft dusk line, limb darkening.
		float nl = dot(normal, sun);
		float lit = smoothstep(-0.1, 0.35, nl) * clamp(nl * 0.8 + 0.3, 0.0, 1.0);
		float mu = sqrt(1.0 - r2);
		col = surf * (lit * 1.75 * (0.6 + 0.4 * mu) + 0.015);
		// The rings' shadow on it.
		vec3 sp = normal;   // the surface point, from its middle, in giant radii
		float to_plane = dot(sun, rn);
		if (abs(to_plane) > 0.001) {
			float s = -dot(sp, rn) / to_plane;
			if (s > 0.0) {
				float rr = length(sp + sun * s);
				col *= 1.0 - 0.75 * ring_density(rr, edge * 2.0, oct);
			}
		}
		col += giant_a * pow(1.0 - mu, 3.0) * lit * 0.35;
	}
	col += vec3(0.95, 0.8, 0.6) * air * 0.25 * (1.0 - cover);
	return vec4(col, max(cover, air * 0.35));
}

// The rings: colour and coverage, and whether they are nearer than the giant's middle.
vec4 rings(vec3 dir, float px, int oct, vec3 sun, out bool front) {
	vec3 gc = normalize(giant_dir);
	vec3 rn = normalize(ring_normal);
	float facing = dot(dir, rn);
	float rt = dot(gc, rn) / (abs(facing) < 0.0001 ? 0.0001 : facing);
	front = rt < 1.0;
	if (rt <= 0.0) {
		return vec4(0.0);
	}
	vec3 rhit = (dir * rt - gc) / giant_radius;
	float rr = length(rhit);
	if (rr < 1.2 || rr > 2.5) {
		return vec4(0.0);
	}
	float rpx = px * rt / giant_radius / max(abs(facing), 0.04);
	float dens = ring_density(rr, rpx, oct);
	// The giant's shadow across them.
	float along = dot(rhit, sun);
	float shade = 1.0;
	if (along < 0.0) {
		shade = smoothstep(0.96, 1.02, length(rhit - sun * along)) * 0.92 + 0.08;
	}
	vec3 tint = mix(giant_a * 1.05, vec3(0.82, 0.74, 0.64), smoothstep(1.5, 2.3, rr));
	tint = mix(tint, giant_b * 0.8, smoothstep(1.45, 1.22, rr));
	tint *= 0.8 + 0.4 * fbm(vec3(rr * 9.0, 4.2, 1.3), oct, rpx * 9.0);
	float lit = 0.55 + 0.6 * abs(dot(sun, rn));
	return vec4(tint * lit * shade * 1.1, dens * 0.9);
}

// The small blue world: oceans, a little land, clouds, a blue edge of air.
vec4 small_world(vec3 dir, float px, int oct, vec3 sun) {
	vec3 c = normalize(small_dir);
	float rad = small_radius;
	float ang = acos(clamp(dot(dir, c), -1.0, 1.0));
	if (ang > rad * 1.3) {
		return vec4(0.0);
	}
	vec3 u = normalize(cross(c, vec3(0.0, 1.0, 0.0)));
	vec3 v = cross(u, c);
	vec2 q = vec2(dot(dir - c, u), dot(dir - c, v)) / rad;
	float r = length(q);
	float edge = px / rad;
	float cover = 1.0 - smoothstep(1.0 - edge, 1.0 + edge, r);
	vec3 rim_n = normalize(q.x * u + q.y * v);
	float air = exp(-max(r - 1.0, 0.0) * 18.0) * smoothstep(1.3, 1.0, r) * clamp(dot(rim_n, sun) + 0.2, 0.0, 1.0);
	vec3 col = vec3(0.0);
	if (r < 1.0 + edge) {
		float r2 = min(r * r, 1.0);
		vec3 normal = normalize(q.x * u + q.y * v - sqrt(1.0 - r2) * c);
		float fp = edge / max(sqrt(1.0 - r2), 0.2);
		float land = smoothstep(0.55, 0.6, fbm(normal * 2.5 + 4.0, oct, fp * 2.5));
		float cloud = smoothstep(0.48, 0.72, fbm(normal * vec3(4.0, 7.0, 4.0) + 9.0, oct, fp * 7.0));
		vec3 surf = mix(small_colour * 0.55, vec3(0.42, 0.45, 0.32), land);
		surf = mix(surf, vec3(0.95, 0.97, 1.0), cloud * 0.85);
		float nl = dot(normal, sun);
		float lit = smoothstep(-0.08, 0.3, nl) * clamp(nl * 0.8 + 0.3, 0.0, 1.0);
		float mu = sqrt(1.0 - r2);
		col = surf * (lit * 1.9 + 0.01);
		col += small_colour * pow(1.0 - mu, 2.0) * lit * 0.8;
	}
	col += small_colour * air * 0.9 * (1.0 - cover);
	return vec4(col, max(cover, air * 0.6));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	bool cube = AT_CUBEMAP_PASS;
	// A pixel's size (radians). The light cubemap is soft: work it coarse and cheap.
	float px = cube ? 0.02 : clamp(0.5 * length(fwidth(dir)), 0.00005, 0.02);
	int oct = cube ? 4 : (detail <= 0 ? 5 : (detail == 1 ? 7 : 9));
	vec3 sun = normalize(sun_way);
	vec3 axis = normalize(band_axis);
	float across = dot(dir, axis);
	float core = pow(max(dot(dir, normalize(core_dir)), 0.0), 3.0);

	// The home galaxy's band: its edge ragged, thicker towards its core.
	float wob = fbm(dir * 2.2 + 3.0, 3, px * 2.2) - 0.5;
	float ac = across + wob * 0.14;
	float band = exp(-pow(ac * 3.3 / (1.0 + core * 0.6), 2.0));
	// Its star clouds, from great clouds down to the pixel.
	float clouds = fbm(dir * 4.5, oct, px * 4.5);
	float fine = fbm(dir * 26.0 + 4.0, oct, px * 26.0);
	float light = band * (0.2 + 1.15 * smoothstep(0.35, 0.72, clouds)) * (0.7 + 0.6 * fine);
	light += exp(-pow(ac * 9.0, 2.0)) * 0.35 * smoothstep(0.4, 0.7, clouds);   // the bright plane
	// Dust: dark filaments in a lane down its middle, and wisps off it.
	vec3 wp = dir * 6.0;
	if (detail > 0 && !cube) {
		wp += vec3(fbm(dir * 3.0 + 1.0, 4, px * 3.0), fbm(dir * 3.0 + 6.0, 4, px * 3.0), fbm(dir * 3.0 + 12.0, 4, px * 3.0)) * 2.2 - 1.1;
	}
	float fil = ridged(wp, oct, px * 6.0);
	float lane = exp(-pow((ac + 0.015) * 8.5, 2.0));
	float wisps = exp(-pow(ac * 3.6, 2.0)) * 0.6;
	float dust = clamp(lane * (0.15 + 1.1 * smoothstep(0.3, 0.8, fil)) * smoothstep(0.3, 0.6, clouds + 0.15) + wisps * smoothstep(0.6, 0.9, fil) * 0.7, 0.0, 1.0);
	float ext = 1.0 - 0.8 * dust;
	vec3 band_col = mix(band_colour, core_colour, clamp(core * 1.4, 0.0, 1.0));
	// Dust reddens the light at its edges.
	band_col *= mix(vec3(1.0, 0.72, 0.5), vec3(1.0), ext);
	vec3 col = band_col * light * band_strength * 0.55 * (1.0 + core * 2.5) * ext;

	// Stars: more along the band, as along a real galaxy's plane, and hidden by its dust.
	vec3 stars = vec3(0.0);
	if (!cube) {
		float crowd = 1.0 + band * 3.0 + core * band * 3.0;
		float d0 = star_density / 0.0035;   // the old knob still thins or thickens them
		stars += star_layer(dir, 70.0, 0.05 * d0, px, 0.0) * 2.2;
		stars += star_layer(dir, 160.0, 0.05 * crowd * d0, px, 0.05) * 1.3;
		stars += star_layer(dir, 330.0, 0.05 * crowd * d0, px, 0.0) * 0.8;
		if (detail > 0) {
			stars += star_layer(dir, 650.0, 0.07 * crowd * d0, px, -0.05) * 0.5;
		}
		if (detail > 1) {
			stars += star_layer(dir, 1250.0, 0.09 * crowd * d0, px, 0.0) * 0.32;
		}
		stars += bright_stars(dir, px);
		stars *= star_brightness / 2.6 * 1.5;
	} else {
		stars = vec3(0.012) * (1.0 + band * 3.0);
	}
	col += stars * mix(vec3(1.0, 0.8, 0.65), vec3(1.0), ext) * (0.1 + 0.9 * ext);

	// Nebula clouds off the band: glowing gas (pink and blue) in warped sheets, threaded with
	// bright filaments and dark knots.
	vec3 np = dir * 3.2 + 11.0;
	if (detail > 0 && !cube) {
		np += (vec3(fbm(dir * 2.0 + 21.0, 4, px * 2.0), fbm(dir * 2.0 + 27.0, 4, px * 2.0), fbm(dir * 2.0 + 33.0, 4, px * 2.0)) - 0.5) * 2.6;
	}
	float body = fbm(np, oct, px * 3.2);
	float threads = ridged(np * 2.6 + 5.0, oct, px * 8.3);
	float m1 = smoothstep(0.48, 0.78, body) * exp(-pow(across * 1.6, 2.0));
	float m2 = smoothstep(0.5, 0.8, fbm(dir * 4.0 - 5.0, oct, px * 4.0)) * exp(-pow((across - 0.4) * 2.0, 2.0));
	float glow_a = m1 * (0.45 + 1.4 * threads);
	float glow_b = m2 * (0.5 + 1.2 * ridged(dir * 9.0 - 2.0, oct, px * 9.0));
	float knots = smoothstep(0.62, 0.85, fbm(np * 3.0 - 7.0, oct, px * 9.6)) * (m1 + m2);
	vec3 neb = nebula_a * glow_a + nebula_b * glow_b + mix(nebula_a, nebula_b, 0.5) * glow_a * glow_b * 2.0;
	col += neb * nebula_strength * 1.3 * (1.0 - 0.7 * knots) * (0.3 + 0.7 * ext);

	// The spiral, beyond the home galaxy's dust.
	col += spiral(dir, px, oct, cube) * (0.15 + 0.85 * ext);

	// The distant planets, in front of all that. The giant's rings go behind it on the far side
	// and in front on ours.
	bool ring_front;
	vec4 rg = rings(dir, px, oct, sun, ring_front);
	vec4 g = giant(dir, px, oct, sun);
	if (!ring_front) {
		col = mix(col, rg.rgb, rg.a);
	}
	col = mix(col, g.rgb, g.a);
	if (ring_front) {
		col = mix(col, rg.rgb, rg.a);
	}
	vec4 p2 = small_world(dir, px, oct, sun);
	col = mix(col, p2.rgb, p2.a);

	if (LIGHT0_ENABLED) {
		float d = dot(dir, LIGHT0_DIRECTION);
		float ang = acos(clamp(d, -1.0, 1.0));
		float disc = 1.0 - smoothstep(0.0265 - px, 0.0265 + px, ang);
		float corona = pow(max(d, 0.0), 2200.0) * 6.0 + pow(max(d, 0.0), 300.0) * 1.4;
		float glare = pow(max(d, 0.0), 24.0) * 0.07 + pow(max(d, 0.0), 6.0) * 0.015;
		col = mix(col, sun_colour * 50.0, disc);
		col += sun_colour * (corona + glare);
	}
	COLOR = col;
}
