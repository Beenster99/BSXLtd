shader_type spatial;
// The surface of every salvage part (and of the player ships' paint, ShipSurface): a finish
// per zone (SurfaceFinish: what the surface is made of and how it was treated, read from
// the finish table by the code in the vertex colour's alpha, or the part's material's
// finish), a detail layer drawn in that finish's pattern at its own scale, plus the wear and
// scorch of the part's condition (PartData). Everything is worked out in the part's own
// space, so the marks stay put on it as it moves (docs/ECONOMY_PLAN.md section 7, A1).
//   finish  metallic, roughness, specular, a clearcoat; a pattern (smooth paint, brushed
//           lines, cast lumps, chalk cells, a weave, leather pebbles, tiles, galvanised
//           spangles, ribs, wood grain) from SurfaceDetail's baked maps projected three ways
//           (the meshes have no UVs) or drawn in code; bumps fade out with distance so
//           nothing shimmers; how it wears (paint chips, metal scratches, plastic scuffs,
//           rubber dusts, fabric stains, ceramic chips) and whether bare steel rusts under it
//   wear    grime in patches and in the pattern's hollows, scratches, the finish's own ageing
//   scorch  heat tint (straw, bronze, blue) at the edge of the burn going to black soot;
//           strongest at scorch_at, fading out by scorch_radius (radius 0 = all over)
// The Graphics presets scale the layer (globals surface_detail, surface_normal).

render_mode cull_back;

uniform vec3 albedo : source_color = vec3(0.5);
// Parts coloured per vertex (components: each zone its own colour; looms; station meshes).
uniform bool use_vertex_color = false;
// The vertex colours are sRGB (station meshes), not linear.
uniform bool vertex_color_srgb = false;
uniform float metallic = 0.5;
uniform float roughness = 0.5;

// What the part is made of (Materials.TABLE looks): a tint over its paint and the finish
// its body shows (a SurfaceFinish code; 0 = the paint it was built with, from the uniforms
// above). Zones inside the part carry their own codes in their vertex colours.
uniform vec3 material_tint = vec3(1.0);
uniform int material_finish = 0;
uniform float material_blend = 0.0;   // how much the finish's own colour shows through the paint
// The finish table (SurfaceFinish.table): one row per code, four texels:
//   0 (metallic, roughness, specular, clearcoat)  1 (pattern, scale m, bump, relief)
//   2 (wear mode, rust, tint, flake)              3 (temper, iridescence, -, -)
//   4 (the finish's own colour, -)
uniform sampler2D finish_table : hint_default_black, filter_nearest, repeat_disable;
uniform int finish_count = 0;

// The detail layer (SurfaceDetail sets the maps and detail_on).
uniform sampler2D detail_map : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_on = 0.0;
// Ship paint (ShipSurface): never part of the survey glass's view.
uniform bool survey_skip = false;
global uniform float surface_detail;  // Graphics: the detail layer's strength (0 = off)
global uniform float surface_normal;  // Graphics: its bumps' strength (0 = flat)

// The survey glass: each part's layer (SurveySystem Layer, 0 = none) and hazard (0 none,
// 1 live wiring, 2 charged fuel). Seen through the glass, the shown layer's parts glow in its
// colour and the rest go to a dithered ghost; hazards glow red or orange in every layer; a
// bright sweep line crosses the wreck when the layer changes (parts behind it still show the
// old one).
uniform int part_layer = 0;
uniform int part_hazard = 0;
#include "res://shared/void_salvage/shaders/survey_glass.gdshaderinc"

// A part's condition: (wear, scorch, scorch_radius, seed), and where the scorch is worst
// (part space). Undamaged parts share one material; a damaged part gets its own copy
// (instance uniforms ran out on some graphics cards).
uniform vec4 condition = vec4(0.0);
uniform vec4 scorch_at = vec4(0.0);
// A streak instead of a spot: the scorch runs along this direction (part space; w = 1 on).
uniform vec4 scorch_line = vec4(0.0);
// A fresh wreck (x, 0..1: SalvageStructure.fresh): its darkest soot still glows dull orange;
// on a torn part (yzw, its thin axis in part space) the faces square to it, its edges, too.
uniform vec4 fresh = vec4(0.0);

varying vec3 local_pos;
varying vec3 local_normal;
varying vec3 vertex_tint;
varying vec3 world_pos;
varying flat int v_zone;

const int PAT_SMOOTH = 0;
const int PAT_BRUSHED = 1;
const int PAT_CAST = 2;
const int PAT_CELLS = 3;
const int PAT_WEAVE = 4;
const int PAT_PEBBLE = 5;
const int PAT_TILES = 6;
const int PAT_SPANGLE = 7;
const int PAT_RIBS = 8;
const int PAT_GRAIN = 9;

const int WEAR_PAINT = 0;
const int WEAR_METAL = 1;
const int WEAR_PLASTIC = 2;
const int WEAR_RUBBER = 3;
const int WEAR_FABRIC = 4;
const int WEAR_CERAMIC = 5;
const int WEAR_WOOD = 6;
const int WEAR_NONE = 7;

const vec3 LAYER_COLOR[8] = vec3[8](vec3(1.0), vec3(0.35, 0.7, 1.0), vec3(0.95, 0.75, 0.3),
		vec3(1.0, 0.3, 0.25), vec3(0.3, 1.0, 0.6), vec3(0.75, 0.45, 1.0), vec3(1.0, 0.55, 0.15),
		vec3(1.0, 1.0, 0.45));

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 vc = COLOR.rgb;
	if (vertex_color_srgb) {
		vc = mix(pow((vc + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), vc * (1.0 / 12.92), lessThan(vc, vec3(0.04045)));
	}
	vertex_tint = use_vertex_color ? vc : vec3(1.0);
	// The finish code (SurfaceZones: STEP = 6/255 of alpha per code, below an alpha of 1).
	v_zone = 0;
	if (use_vertex_color) {
		float z = (1.0 - COLOR.a) * 255.0 / 6.0;
		int n = int(round(z));
		if (n > 0 && n <= finish_count && abs(z - float(n)) < 0.34) {
			v_zone = n;
		}
	}
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

// Steel heated more and more: thin straw, bronze and blue bands at the edge of the burn,
// then soot over most of it, going to black.
vec3 heat_tint(vec3 base, float t) {
	vec3 c = mix(base, base * vec3(1.05, 0.9, 0.6) + vec3(0.1, 0.06, 0.0), smoothstep(0.03, 0.09, t));
	c = mix(c, vec3(0.36, 0.25, 0.17), smoothstep(0.09, 0.15, t));
	c = mix(c, vec3(0.24, 0.24, 0.27), smoothstep(0.14, 0.19, t));
	c = mix(c, vec3(0.045, 0.04, 0.035), smoothstep(0.18, 0.5, t));
	return c;
}

// One projection of the pattern: `uv` in tiles, `px` texels of the maps per screen pixel
// (for fading what would alias). Gives the height-ish `h` (0..1, the pattern's tone: 0.5 is
// flat), `t` the slope in the projection's plane, `cav` how deep in a hollow (grime gathers
// there), `tone` a per-cell or per-tile random. Brushing, ribs and wood run along the
// projection's first axis.
void pattern_tap(int pattern, vec2 uv, float px, out float h, out vec2 t, out float cav, out float tone) {
	vec4 d = texture(detail_map, uv);
	vec4 nm = texture(detail_normal, uv) * 2.0 - 1.0;
	// Smooth: a faint, broad orange peel (the grain at half strength).
	h = mix(0.5, d.r, 0.5);
	t = nm.xy * 0.5;
	cav = 0.0;
	tone = 0.5;
	// Procedural patterns alias where their period is under a few pixels: fade them out.
	float fine = 1.0 - smoothstep(0.12, 0.3, px);
	if (pattern == PAT_BRUSHED) {
		vec2 bu = uv * vec2(0.03, 4.0);
		vec4 bn = texture(detail_normal, bu) * 2.0 - 1.0;
		h = mix(d.r, texture(detail_map, bu).r, 0.8);
		t = vec2(0.0, bn.y) * 1.2 + nm.xy * 0.2;
	} else if (pattern == PAT_CAST) {
		vec4 dc = texture(detail_map, uv * 0.5);
		vec4 nc = texture(detail_normal, uv * 0.5) * 2.0 - 1.0;
		h = mix(d.r, dc.g, 0.5);
		t = nm.xy * 0.8 + nc.zw * 0.9;
		cav = (1.0 - dc.g) * 0.5;
	} else if (pattern == PAT_CELLS) {
		h = d.g;
		t = nm.zw;
		cav = 1.0 - d.g;
		tone = d.a;
	} else if (pattern == PAT_PEBBLE) {
		h = mix(d.r, d.g, 0.7);
		t = nm.zw * 0.8 + nm.xy * 0.3;
		cav = (1.0 - d.g) * 0.6;
	} else if (pattern == PAT_SPANGLE) {
		vec4 ds = texture(detail_map, uv * 0.6);
		h = 0.5;
		t = nm.xy * 0.3;
		tone = ds.a;
		cav = smoothstep(0.25, 0.0, ds.g) * 0.5;
	} else if (pattern == PAT_WEAVE) {
		vec2 w = uv * 6.0;
		vec2 cell = floor(w);
		vec2 f = fract(w);
		float over = mod(cell.x + cell.y, 2.0);
		float fx = f.x * 2.0 - 1.0;
		float fy = f.y * 2.0 - 1.0;
		float hx = 1.0 - fy * fy;   // a thread along x: domed across y
		float hy = 1.0 - fx * fx;   // a thread along y: domed across x
		float dome = mix(hy, hx, over);
		h = mix(0.5, dome, fine);
		t = mix(vec2(-2.0 * fx, 0.0), vec2(0.0, -2.0 * fy), over) * 0.5 * fine;
		cav = (1.0 - dome) * 0.5 * fine;
	} else if (pattern == PAT_TILES) {
		vec2 id = floor(uv);
		vec2 f = fract(uv);
		vec2 e = min(f, 1.0 - f);
		float edge = min(e.x, e.y);
		float groove = 1.0 - smoothstep(0.015, 0.04, edge);
		float bevel = 1.0 - smoothstep(0.04, 0.1, edge);
		vec2 dir = vec2(f.x < 0.5 ? -1.0 : 1.0, f.y < 0.5 ? -1.0 : 1.0);
		vec2 be = (e.x < e.y) ? vec2(dir.x, 0.0) : vec2(0.0, dir.y);
		h = mix(0.5 + (d.r - 0.5) * 0.4, 0.15, groove);
		t = nm.xy * 0.2 + be * bevel * (1.0 - groove) * 0.8 * fine;
		cav = groove * fine;
		tone = hash2(id);
	} else if (pattern == PAT_RIBS) {
		float ph = uv.y * 6.2831853 * 6.0;
		h = mix(0.5, 0.5 + 0.5 * sin(ph), fine);
		t = vec2(0.0, cos(ph)) * fine;
		cav = (0.5 - 0.5 * sin(ph)) * fine;
	} else if (pattern == PAT_GRAIN) {
		vec2 gu = uv * vec2(0.12, 1.0);
		vec4 dg = texture(detail_map, gu);
		float rings = fract((uv.x * 0.35 + dg.r * 0.9) * 2.0);
		float band = smoothstep(0.0, 0.25, rings) * (1.0 - smoothstep(0.55, 1.0, rings));
		h = mix(dg.r, band, 0.6);
		t = (texture(detail_normal, gu).xy * 2.0 - 1.0) * vec2(0.3, 1.0);
	}
}

void fragment() {
	float wear = condition.x;
	float scorch = condition.y;
	float scorch_radius = condition.z;
	float seed = condition.w;
	vec3 q = local_pos + vec3(seed * 13.7, seed * 7.3, seed * 3.1);
	// The finish: the zone's own, else the part's material's, else the paint as built.
	int fin = v_zone > 0 ? v_zone : material_finish;
	vec4 f0 = texelFetch(finish_table, ivec2(0, fin), 0);
	vec4 f1 = texelFetch(finish_table, ivec2(1, fin), 0);
	vec4 f2 = texelFetch(finish_table, ivec2(2, fin), 0);
	vec4 f3 = texelFetch(finish_table, ivec2(3, fin), 0);
	bool as_built = fin == 0;
	int pattern = int(f1.x + 0.5);
	float scale = max(f1.y, 0.01);
	float bump = f1.z;
	float relief = f1.w;
	int wear_mode = int(f2.x + 0.5);
	float rust = f2.y;
	float flake = f2.w;
	float temper = f3.x;
	float irid = f3.y;
	float met = as_built ? metallic : f0.x;
	float rough = as_built ? roughness : f0.y;
	float spec = f0.z;
	float coat = f0.w;
	bool tinted = as_built || v_zone == 0 || f2.z > 0.5;
	vec3 col = albedo * vertex_tint * (tinted ? material_tint : vec3(1.0));
	if (v_zone == 0 && !as_built) {
		// The part is made of this: its own colour shows through the paint by material_blend.
		vec3 own = texelFetch(finish_table, ivec2(4, fin), 0).rgb;
		col = mix(col, own * material_tint, material_blend);
	}
	// The detail layer: three projections in part space, blended by the face's direction.
	float dl = detail_on * surface_detail;
	float nl = detail_on * surface_normal;
	float cavity = 0.0;   // how deep in a hollow (0..1): grime and soot gather there
	float tone = 0.5;     // a per-cell or per-tile random
	vec3 dp = fwidth(local_pos);
	float px = length(dp) / scale * 256.0;   // texels per pixel: how much the maps are minified
	// Bumps and fine marks fade out as the maps go small on screen: what would shimmer goes flat.
	float fade = 1.0 - smoothstep(1.5, 6.0, px);
	if (dl > 0.001 || nl > 0.001) {
		vec3 n = normalize(local_normal);
		vec3 w = pow(abs(n), vec3(4.0));
		w /= w.x + w.y + w.z;
		vec3 p = local_pos + vec3(seed * 0.37, seed * 0.21, seed * 0.13);
		vec3 tp = p / scale;
		float h = 0.0;
		vec3 bmp = vec3(0.0);
		float hh;
		vec2 t;
		float cv;
		float tn;
		float wsum = 0.0;
		if (w.x > 0.02) {
			pattern_tap(pattern, tp.zy, px, hh, t, cv, tn);
			h += hh * w.x;
			cavity += cv * w.x;
			tone += (tn - 0.5) * w.x;
			bmp += vec3(0.0, t.y, t.x) * w.x;
			wsum += w.x;
		}
		if (w.y > 0.02) {
			pattern_tap(pattern, tp.xz, px, hh, t, cv, tn);
			h += hh * w.y;
			cavity += cv * w.y;
			tone += (tn - 0.5) * w.y;
			bmp += vec3(t.x, 0.0, t.y) * w.y;
			wsum += w.y;
		}
		if (w.z > 0.02) {
			pattern_tap(pattern, tp.xy, px, hh, t, cv, tn);
			h += hh * w.z;
			cavity += cv * w.z;
			tone += (tn - 0.5) * w.z;
			bmp += vec3(t.x, t.y, 0.0) * w.z;
			wsum += w.z;
		}
		wsum = max(wsum, 0.001);
		h /= wsum;
		cavity /= wsum;
		tone = 0.5 + (tone - 0.5) / wsum;
		// Tone: the pattern's height shades the colour a little, hollows a little more, and
		// a per-cell tone varies spangles and tiles.
		col *= 1.0 + (h - 0.5) * 0.5 * relief * dl;
		col *= 1.0 - 0.3 * cavity * relief * dl;
		if (pattern == PAT_SPANGLE || pattern == PAT_TILES) {
			col *= 1.0 + (tone - 0.5) * 0.35 * relief * dl;
		}
		// Broad roughness patches: fingerprints, dulled areas.
		float blotch = texture(detail_map, tp.xz * 0.5 + tp.xy * 0.3).b;
		rough = clamp(rough + (blotch - 0.5) * 0.12 * dl + (h - 0.5) * 0.1 * relief * dl, 0.03, 1.0);
		// Metal flakes in paint and galvanised spangles catch the light here and there.
		if (flake > 0.001) {
			float spark = step(0.9, hash(floor(tp * 90.0))) * flake * dl * fade;
			col *= 1.0 + 0.4 * spark;
			rough = mix(rough, 0.25, spark * 0.5);
		}
		// Temper colours: blue and straw in soft patches, as heat-treated titanium shows.
		if (temper > 0.001) {
			float pt = noise(q * 0.9 + vec3(3.3));
			vec3 tint = mix(vec3(1.08, 1.0, 0.82), vec3(0.78, 0.88, 1.25), smoothstep(0.35, 0.65, pt));
			col = mix(col, col * tint, temper * dl * smoothstep(0.2, 0.8, abs(pt - 0.5) * 2.0 + 0.3));
		}
		// The bumped normal (part space -> view), facing the camera on back faces too.
		if (nl > 0.001) {
			vec3 bn = normalize(n + bmp * bump * nl * fade);
			vec3 v = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(bn, 0.0))).xyz);
			NORMAL = FRONT_FACING ? v : -v;
		}
	}
	if (wear > 0.001) {
		// Grime in soft patches, and gathering in the pattern's hollows.
		float grime = fbm(q * vec3(1.2, 0.6, 1.2));
		col *= mix(1.0, 0.6 + 0.45 * grime, clamp(wear * 1.1, 0.0, 1.0));
		col *= 1.0 - 0.4 * cavity * clamp(wear * 1.5, 0.0, 1.0);
		rough = mix(rough, min(rough + 0.3, 1.0), wear * grime * 0.9);
		// Scratches: a few long thin lines along the part, more with wear, gone at a distance.
		float scr = max(noise(q * vec3(2.5, 70.0, 70.0)), noise(q * vec3(70.0, 2.5, 70.0)));
		float scratch = smoothstep(0.9 - 0.06 * wear, 0.94 - 0.06 * wear, scr) * min(wear * 1.3, 1.0)
				* (1.0 - smoothstep(0.004, 0.012, length(dp)));
		// Patches: chips, scuffs, stains, dust: large and soft-edged.
		float patch_n = fbm(q * 1.6 + vec3(5.0));
		float patch = smoothstep(0.62 - 0.14 * wear, 0.68 - 0.14 * wear, patch_n) * min(wear * 1.2, 1.0);
		vec3 bare = vec3(0.56, 0.56, 0.55) * (tinted ? material_tint : vec3(1.0));
		float rust_n = noise(q * 2.4 + vec3(11.0));
		vec3 rusty = mix(bare, vec3(0.4, 0.24, 0.13), smoothstep(0.45, 0.75, rust_n) * wear * rust);
		if (wear_mode == WEAR_PAINT) {
			// Paint chipped off in ragged patches: a pale primer rim, bare steel, rust in the
			// oldest; scratches show the metal too.
			float rim = smoothstep(0.56 - 0.14 * wear, 0.62 - 0.14 * wear, patch_n) * (1.0 - patch) * min(wear * 1.2, 1.0);
			col = mix(col, vec3(0.6, 0.58, 0.52) * (tinted ? material_tint : vec3(1.0)), rim * 0.7);
			col = mix(col, rusty, patch);
			col = mix(col, bare, scratch * 0.8);
			met = mix(met, 0.75, max(patch * (1.0 - rust_n * rust * 0.7), scratch * 0.8));
			rough = mix(rough, 0.5, max(patch, scratch));
			coat *= 1.0 - max(patch, scratch);
		} else if (wear_mode == WEAR_METAL) {
			// Dulled patches, bright fresh scratches, rust bloom on steel.
			col = mix(col, col * 0.8, patch * 0.6);
			rough = mix(rough, min(rough + 0.35, 1.0), patch);
			col = mix(col, col * 1.25 + vec3(0.05), scratch * 0.7);
			rough = mix(rough, 0.3, scratch * 0.5);
			float bloom = smoothstep(0.5, 0.8, rust_n) * wear * rust * 0.9 * smoothstep(0.3, 0.6, patch_n);
			col = mix(col, vec3(0.42, 0.25, 0.13), bloom);
			met = mix(met, 0.2, bloom);
			rough = mix(rough, 0.9, bloom);
		} else if (wear_mode == WEAR_PLASTIC) {
			// Scuffs: the surface whitens where it has been rubbed.
			vec3 pale = mix(col, vec3(0.75), 0.45);
			col = mix(col, pale, patch * 0.8 + scratch * 0.5);
			rough = mix(rough, min(rough + 0.4, 1.0), patch * 0.9 + scratch * 0.5);
			coat *= 1.0 - patch;
		} else if (wear_mode == WEAR_RUBBER) {
			// Dust greys it; cracks don't show at this size.
			col = mix(col, vec3(0.4, 0.39, 0.37), (patch * 0.5 + grime * 0.3) * wear);
			rough = min(rough + 0.1 * wear, 1.0);
		} else if (wear_mode == WEAR_FABRIC) {
			// Stains darken, worn highs fade.
			col = mix(col, col * vec3(0.55, 0.5, 0.45), patch * 0.8);
			col = mix(col, mix(col, vec3(0.7), 0.3), scratch * 0.6 + wear * 0.15 * (1.0 - grime));
		} else if (wear_mode == WEAR_CERAMIC) {
			// Chips to a pale core with crisp edges, grime in the cells.
			float chip = smoothstep(0.64 - 0.12 * wear, 0.66 - 0.12 * wear, patch_n) * min(wear * 1.2, 1.0);
			col = mix(col, mix(col, vec3(0.85, 0.83, 0.78), 0.7), chip);
			rough = mix(rough, 0.95, chip);
			coat *= 1.0 - chip;
			col *= 1.0 - 0.2 * cavity * wear;
		} else if (wear_mode == WEAR_WOOD) {
			col = mix(col, mix(col, vec3(0.8, 0.7, 0.55), 0.5), patch * 0.7 + scratch * 0.5);
			rough = mix(rough, 0.8, patch);
			coat *= 1.0 - patch;
		}
	}
	float soot = 0.0;
	if (scorch > 0.001) {
		float s = scorch;
		if (scorch_radius > 0.001) {
			vec3 off = local_pos - scorch_at.xyz;
			if (scorch_line.w > 0.5) {
				off -= scorch_line.xyz * dot(off, scorch_line.xyz);
			}
			float d = length(off) + (fbm(q * 0.9) - 0.5) * scorch_radius * 0.5;
			s *= 1.0 - smoothstep(scorch_radius * 0.25, scorch_radius, d);
		}
		// Patchy: soot gathers in blotches, streaks and the hollows.
		s = clamp(s * (0.6 + 0.8 * fbm(q * vec3(2.2, 1.1, 2.2))) + cavity * 0.15 * s, 0.0, 1.0);
		col = heat_tint(col, s);
		met = mix(met, 0.2, smoothstep(0.35, 0.8, s));
		rough = mix(rough, 0.95, smoothstep(0.3, 0.8, s));
		coat *= 1.0 - smoothstep(0.15, 0.5, s);
		soot = s;
	}
	if (irid > 0.001) {
		// An oil-film shimmer that shifts with the view, and a faint glow of its own.
		float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		vec3 film = 0.7 + 0.3 * cos(6.2831 * (f * 1.5 + q.x * 0.07 + vec3(0.0, 0.33, 0.67)));
		col = mix(col, col * film * 1.3, irid);
		EMISSION = film * irid * 0.06;
	}
	if (fresh.x > 0.001) {
		// Embers: patchy in the blackest soot, breathing slowly; torn edges a faint line.
		float breath = 0.75 + 0.25 * sin(TIME * 0.7 + fbm(q * 1.7) * 6.2831853);
		float ember = smoothstep(0.8, 1.0, soot) * smoothstep(0.45, 0.8, fbm(q * vec3(3.1, 1.4, 3.1)));
		float edge = 0.0;
		if (dot(fresh.yzw, fresh.yzw) > 0.5) {
			edge = smoothstep(0.85, 1.0, 1.0 - abs(dot(normalize(local_normal), fresh.yzw))) * 0.45;
		}
		EMISSION += vec3(1.0, 0.33, 0.08) * fresh.x * (ember + edge) * breath * 1.2;
	}
	if (!survey_skip && survey_layer >= 0 && survey_through_glass(world_pos, CAMERA_POSITION_WORLD)) {
		float side = dot(world_pos, survey_sweep.xyz) - survey_sweep.w;
		int layer = side < 0.0 ? survey_layer : survey_layer_old;
		if (part_hazard > 0) {
			// Live wiring red, charged fuel orange: pulsing, never ghosted.
			vec3 hazard = part_hazard == 1 ? vec3(1.0, 0.12, 0.08) : vec3(1.0, 0.5, 0.05);
			float pulse = 0.65 + 0.35 * sin(TIME * 5.0);
			col = mix(col, hazard, 0.6);
			EMISSION += hazard * 1.2 * pulse;
		} else if (layer > 0) {
			if (part_layer == layer) {
				EMISSION += LAYER_COLOR[layer] * 0.35;
				col = mix(col, LAYER_COLOR[layer], 0.25);
			} else {
				// A ghost: one pixel in five, tinted, the opaque pipeline kept.
				vec2 f = floor(FRAGCOORD.xy);
				if (mod(f.x + f.y * 3.0, 5.0) > 0.5) {
					discard;
				}
				col = vec3(0.25, 0.45, 0.55);
				EMISSION += vec3(0.05, 0.12, 0.16);
			}
		}
		EMISSION += vec3(0.6, 0.9, 1.0) * survey_glow * (1.0 - smoothstep(0.0, 0.35, abs(side)));
	}
	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rough;
	SPECULAR = spec;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.15;
}
