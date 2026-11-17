// Scanned surface layers (trial, docs/review/SCAN_MATERIALS.md): photo-scanned PBR sets (the look
// lab's ambientCG maps, assets/materials/) as layers under the salvage surface's own looks. A
// finish names up to three (SurfaceScans.MAP): the BASE (the paint's or metal's micro detail: its
// colour against its own blur, so the game's paint, tint and scheme colour still rule; its
// roughness and its bumps), the BARE metal its chips and scratches show, and the RUST its age
// brings. Where they show is still the game's wear (its masks: knocked edges, chips, creep,
// streaks, blooms), never the scan's baked chips, so a plate wears the same with or without them.
// Nothing repeats: every map is laid on hexagons, each turned and shifted at random and blended
// by contrast (after Mikkelsen, "Practical Real-Time Hex-Tiling", JCGT 2022: written here), in the
// part's own space by metres (three projections, like the detail layer), from the part's seed.
// Off (scan_on false): nothing here runs.

uniform bool scan_on = false;
uniform sampler2DArray scan_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray scan_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray scan_orm : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
// Per finish code (SurfaceScans.table): texel 0 (base layer + 1, colour strength, normal
// strength, roughness strength), 1 (bare layer + 1, rust layer + 1, hue kept 0..1, rust normal),
// 2 (base tile scale, raised: a tread scan's highs stand for its raised pattern, 0..1, 0, 0).
uniform sampler2D scan_table : hint_default_black, filter_nearest, repeat_disable;
// Per layer (SurfaceScans.SETS): x m one repeat covers, y how it may turn (0 shifted only: brushed
// lines keep their direction; 1 quarter turns; 2 any angle), z the blur mip its colour is held
// against (bigger: keeps broader detail), w unused.
uniform vec4 scan_layer[16];
// How strongly the hexagons hand over (bigger: smaller hand-over bands) and how much a brighter
// tap wins there (keeps contrast: no washed-out blends).
uniform float scan_hex_sharp = 7.0;
uniform float scan_hex_contrast = 0.6;
// Broad variation over each plate (the scans' own broad blotches are taken out with their blur):
// how much and how big (m).
uniform float scan_macro = 0.35;
uniform float scan_macro_m = 2.5;

const float SCAN_SQRT3 = 1.7320508;

float scan_hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 scan_hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// The hexagon grid at `st` (in repeats): the three hexagons' centres around the point and how
// much of each (Mikkelsen's TriangleGrid).
void scan_grid(vec2 st, out vec3 w, out vec2 v1, out vec2 v2, out vec2 v3) {
	st *= 2.0 * SCAN_SQRT3;
	vec2 sk = vec2(st.x - 0.57735027 * st.y, 1.15470054 * st.y);
	vec2 base = floor(sk);
	vec3 t = vec3(fract(sk), 0.0);
	t.z = 1.0 - t.x - t.y;
	float s = step(0.0, -t.z);
	float s2 = 2.0 * s - 1.0;
	w = vec3(-t.z * s2, s - t.y * s2, s - t.x * s2);
	v1 = base + vec2(s, s);
	v2 = base + vec2(s, 1.0 - s);
	v3 = base + vec2(1.0 - s, s);
}

// A hexagon's turn (cos, sin) and shift for layer `layer` turning by `turn`.
vec4 scan_cell(vec2 v, float layer, float turn) {
	vec2 h = scan_hash2(v + vec2(layer * 17.0, layer * 3.0));
	float a = 0.0;
	if (turn > 1.5) {
		a = h.x * 6.2831853;
	} else if (turn > 0.5) {
		a = floor(h.x * 4.0) * 1.5707963;
	}
	return vec4(cos(a), sin(a), scan_hash2(v * 1.31 + vec2(5.3, 1.7)) * 4.0);
}

vec2 scan_turn(vec2 p, vec4 r) {
	return vec2(r.x * p.x - r.y * p.y, r.y * p.x + r.x * p.y);
}

// One layer at `uv` (in repeats) on the hexagons: its colour, its colour's blur (the same three
// taps at blur mip `blur`), its tangent normal xy (turned back with its hexagon) and its ORM.
void scan_hex(float layer, vec2 uv, float turn, float blur, bool want_blur, out vec3 col, out vec3 col_blur, out vec2 nxy, out vec3 orm) {
	vec3 w;
	vec2 v1;
	vec2 v2;
	vec2 v3;
	scan_grid(uv, w, v1, v2, v3);
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec2 vs[3] = {v1, v2, v3};
	vec3 c[3];
	vec3 cb[3];
	vec2 nn[3];
	vec3 oo[3];
	for (int i = 0; i < 3; i++) {
		vec4 r = scan_cell(vs[i], layer, turn);
		// The hexagon's centre in repeats (the skew undone), turned about.
		vec2 cen = vec2(vs[i].x + 0.5 * vs[i].y, 0.8660254 * vs[i].y) / (2.0 * SCAN_SQRT3);
		vec2 tuv = scan_turn(uv - cen, r) + cen + r.zw;
		vec2 tdx = scan_turn(dx, r);
		vec2 tdy = scan_turn(dy, r);
		c[i] = textureGrad(scan_albedo, vec3(tuv, layer), tdx, tdy).rgb;
		cb[i] = want_blur ? textureLod(scan_albedo, vec3(tuv, layer), blur).rgb : c[i];
		vec2 n = textureGrad(scan_normal, vec3(tuv, layer), tdx, tdy).xy * 2.0 - 1.0;
		// The map's xy turned with the hexagon: turn it back.
		nn[i] = vec2(r.x * n.x + r.y * n.y, -r.y * n.x + r.x * n.y);
		oo[i] = textureGrad(scan_orm, vec3(tuv, layer), tdx, tdy).rgb;
	}
	vec3 lw = vec3(dot(c[0], vec3(0.299, 0.587, 0.114)), dot(c[1], vec3(0.299, 0.587, 0.114)), dot(c[2], vec3(0.299, 0.587, 0.114)));
	lw = mix(vec3(1.0), lw, scan_hex_contrast);
	vec3 W = lw * pow(w, vec3(scan_hex_sharp));
	W /= max(W.x + W.y + W.z, 1e-5);
	col = c[0] * W.x + c[1] * W.y + c[2] * W.z;
	col_blur = cb[0] * W.x + cb[1] * W.y + cb[2] * W.z;
	nxy = nn[0] * W.x + nn[1] * W.y + nn[2] * W.z;
	orm = oo[0] * W.x + oo[1] * W.y + oo[2] * W.z;
}

// A layer on a part: three projections in part space (`p` m, `n` its normal) blended by the face's
// direction, each on its hexagons. Out: colour, its blur, the normal's tilt in part space (to add
// to n) and ORM.
void scan_layer_at(int layer_i, vec3 p, vec3 n, float tile_mult, bool want_blur, out vec3 col, out vec3 col_blur, out vec3 tilt, out vec3 orm) {
	vec4 L = scan_layer[layer_i];
	float layer = float(layer_i);
	vec3 tp = p / max(L.x * tile_mult, 0.05);
	vec3 w = pow(abs(n), vec3(8.0));
	w /= w.x + w.y + w.z;
	col = vec3(0.0);
	col_blur = vec3(0.0);
	tilt = vec3(0.0);
	orm = vec3(0.0);
	float ws = 0.0;
	vec3 c;
	vec3 cb;
	vec2 t;
	vec3 o;
	if (w.x > 0.04) {
		scan_hex(layer, tp.zy + vec2(0.0, 3.1), L.y, L.z, want_blur, c, cb, t, o);
		col += c * w.x; col_blur += cb * w.x; orm += o * w.x; ws += w.x;
		tilt += vec3(0.0, t.y, t.x) * w.x;
	}
	if (w.y > 0.04) {
		scan_hex(layer, tp.xz + vec2(1.7, 0.0), L.y, L.z, want_blur, c, cb, t, o);
		col += c * w.y; col_blur += cb * w.y; orm += o * w.y; ws += w.y;
		tilt += vec3(t.x, 0.0, t.y) * w.y;
	}
	if (w.z > 0.04) {
		scan_hex(layer, tp.xy + vec2(0.0, 5.9), L.y, L.z, want_blur, c, cb, t, o);
		col += c * w.z; col_blur += cb * w.z; orm += o * w.z; ws += w.z;
		tilt += vec3(t.x, t.y, 0.0) * w.z;
	}
	ws = max(ws, 1e-4);
	col /= ws;
	col_blur /= ws;
	orm /= ws;
	tilt /= ws;
	// Keep the tilt off the face's own direction (only along it).
	tilt -= n * dot(tilt, n);
}

// How a layer's colour stands against its blur (1 = as its surroundings), keeping `hue` of its
// colour (0: lightness only).
vec3 scan_ratio(vec3 col, vec3 col_blur, float hue) {
	vec3 r = col / max(col_blur, vec3(0.004));
	float l = dot(col, vec3(0.2126, 0.7152, 0.0722)) / max(dot(col_blur, vec3(0.2126, 0.7152, 0.0722)), 0.004);
	return clamp(mix(vec3(l), r, hue), vec3(0.0), vec3(3.0));
}
