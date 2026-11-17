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
// LK3: this part's own colour for its finish (SurfaceFinish.finished: a blue anodised plate) in
// place of the finish's swatch; w 1 on.
uniform vec4 finish_colour = vec4(0.0);
// The finish table (SurfaceFinish.table): one row per code, four texels:
//   0 (metallic, roughness, specular, clearcoat)  1 (pattern, scale m, bump, relief)
//   2 (wear mode, rust, tint, flake)              3 (temper, iridescence, raise, raise_rough)
//   4 (the finish's own colour, its own mark: SurfaceFinish.Effect)
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
// 1 live wiring, 2 charged fuel, 3 and 4 a work order's in the way and leave it; the scan pulse, VX8b, shows the hazards too). Seen through the glass, the shown layer's parts glow in its
// colour and the rest go to a dithered ghost; hazards glow red or orange in every layer; a
// bright sweep line crosses the wreck when the layer changes (parts behind it still show the
// old one).
uniform int part_layer = 0;
uniform int part_hazard = 0;
#include "res://shared/void_salvage/shaders/survey_glass.gdshaderinc"
#include "res://shared/void_salvage/shaders/scan_layers.gdshaderinc"

// A hazard's colour: 1 live wiring red, 2 charged fuel orange; a section tow's work order (TS3b,
// SectionMarks): 3 amber (a line still counts it: in the way), 4 blue (the order says leave it).
vec3 hazard_colour(int h) {
	if (h == 1) {
		return vec3(1.0, 0.12, 0.08);
	}
	if (h == 2) {
		return vec3(1.0, 0.5, 0.05);
	}
	return h == 3 ? vec3(1.0, 0.74, 0.14) : vec3(0.2, 0.6, 1.0);
}

// Its pulse: the hazards quick, the work order's marks a slow breath.
float hazard_pulse(int h) {
	return h > 2 ? 0.45 + 0.12 * sin(TIME * 1.6) : 0.65 + 0.35 * sin(TIME * 5.0);
}

// A part's condition: (wear, scorch, scorch_radius, seed), and where the scorch is worst
// (part space). Undamaged parts share one material; a damaged part gets its own copy
// (instance uniforms ran out on some graphics cards).
uniform vec4 condition = vec4(0.0);
uniform vec4 scorch_at = vec4(0.0);
// A streak instead of a spot: the scorch runs along this direction (part space; w = 1 on).
uniform vec4 scorch_line = vec4(0.0);
// A fresh wreck (x, 0..1: SalvageStructure.fresh): its darkest soot still smoulders dull red;
// on a torn part (yzw, its thin axis in part space) the faces square to it, its edges, too.
uniform vec4 fresh = vec4(0.0);
// Hot metal just after a blast (0..1: how hot it is now, cooling; HotMetal sets it), hottest
// at hot_at (part space) and cooling off to nothing by hot_at.w metres from it (0: all over).
uniform float hot = 0.0;
uniform vec4 hot_at = vec4(0.0);
// The part's look as a box in part space (LK1, docs/LOOKS_PLAN.md): its middle and half size,
// w = 1 on (plates and frame members; 0 for fittings: they never wear at their edges). Worn
// paint chips back from its edges and corners first, rust starts there, grime gathers there.
uniform vec4 part_box_centre = vec4(0.0);
uniform vec4 part_box_half = vec4(0.0);
// The ship's up in part space (w = 1 on): dust settles on faces looking up, rust streaks run
// down, grime sits low on a wall.
uniform vec4 part_up = vec4(0.0);
// A hazard plate's stripes laid in its body's space, so plates side by side carry one pattern
// across their seams (xyz: the body's (1, 1, 1) in part space, w: its offset at the part's
// origin; the game's material scheme sets it). Zero: laid in the part's own space, as before.
uniform vec4 stripe_frame = vec4(0.0);

// Merged looks (ShadowProxies, docs/PERFORMANCE.md): many undamaged parts drawn as one mesh in
// their body's space, each vertex's piece slot in UV.x. Every piece's own values sit in the
// body's part table, PART_FIELDS texels a slot, PART_ROW slots a row: 0..2 the rows of its
// body-to-piece transform (xyz the basis row, w the offset), 3 condition, 4 scorch_at, 5
// scorch_line, 6 fresh, 7 hot_at, 8 part_box_centre, 9 part_box_half, 10 part_up, 11 (hot,
// part_layer, part_hazard, 0). Off: the uniforms above, as ever.
uniform bool merged_parts = false;
uniform sampler2D part_table : hint_default_black, filter_nearest, repeat_disable;
// A ship on show (SB11, ShipShow): each vertex carries its piece's metallic, roughness and finish
// code in CUSTOM0 (x, y as shares; z the code / 255), so pieces apart only by those share one
// surface. Off: the uniforms.
uniform bool vertex_material = false;
const int PART_FIELDS = 12;
const int PART_ROW = 256;

varying vec3 local_pos;
varying vec3 local_normal;
varying flat int v_slot;
varying vec3 vertex_tint;
varying vec3 world_pos;
varying flat int v_zone;
varying vec2 v_mr;
varying flat int v_fin;

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
// Tread plate (LK3): a raised pattern drawn as a bump and a shade, never geometry.
const int PAT_TREAD_DIAMOND = 10;
const int PAT_TREAD_BARS = 11;
const int PAT_TREAD_SQUARES = 12;
const int PAT_TREAD_PERFORATED = 13;

// A finish's own mark (SurfaceFinish.Effect).
const int FX_SPARKLE = 1;
const int FX_SMUDGE = 2;
const int FX_PATINA = 3;
const int FX_SPECKLE = 4;
const int FX_STRIPES = 5;
// A hazard plate's stripes (LK4): each band this wide (m), diagonal on the part's broad face.
const float STRIPE_BAND = 0.12;

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

// A field of a piece's row in the part table (merged looks).
vec4 part_field(int slot, int field) {
	return texelFetch(part_table, ivec2((slot % PART_ROW) * PART_FIELDS + field, slot / PART_ROW), 0);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	v_slot = 0;
	v_mr = vec2(metallic, roughness);
	v_fin = material_finish;
	if (vertex_material) {
		v_mr = CUSTOM0.xy;
		v_fin = int(round(CUSTOM0.z * 255.0));
	}
	if (merged_parts) {
		v_slot = int(UV.x + 0.5);
		vec4 r0 = part_field(v_slot, 0);
		vec4 r1 = part_field(v_slot, 1);
		vec4 r2 = part_field(v_slot, 2);
		local_pos = vec3(dot(r0.xyz, VERTEX) + r0.w, dot(r1.xyz, VERTEX) + r1.w, dot(r2.xyz, VERTEX) + r2.w);
		local_normal = vec3(dot(r0.xyz, NORMAL), dot(r1.xyz, NORMAL), dot(r2.xyz, NORMAL));
	}
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

// Metal glowing at `t` (0..1): dark red, cherry, orange, yellow, nearly white.
vec3 blackbody(float t) {
	vec3 c = mix(vec3(0.45, 0.015, 0.0), vec3(1.0, 0.16, 0.02), smoothstep(0.05, 0.35, t));
	c = mix(c, vec3(1.0, 0.45, 0.08), smoothstep(0.3, 0.6, t));
	c = mix(c, vec3(1.0, 0.75, 0.35), smoothstep(0.6, 0.85, t));
	return mix(c, vec3(1.0, 0.93, 0.8), smoothstep(0.85, 1.0, t));
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

// Tread cells across one tile of a tread finish (its scale, 0.3 m): diamond lozenges and
// squares 3.75 cm apart, five-bar groups of 10 cm, holes 3 cm.
float tread_cells(int pattern) {
	return pattern == PAT_TREAD_BARS ? 3.0 : (pattern == PAT_TREAD_PERFORATED ? 10.0 : 8.0);
}

// How raised a tread plate is at `c` (in cells): 1 on the pattern, 0 on the plate between (a
// perforated plate: 1 on the plate, 0 down a hole).
float tread_mask(int pattern, vec2 c) {
	vec2 cell = floor(c);
	vec2 f = fract(c) - 0.5;
	float flip = mod(cell.x + cell.y, 2.0);
	if (pattern == PAT_TREAD_DIAMOND) {
		// Lozenges at 45 degrees, each cell's the other way to its neighbours'.
		vec2 dir = flip > 0.5 ? vec2(0.7071, 0.7071) : vec2(0.7071, -0.7071);
		float along = abs(dot(f, dir));
		float across = abs(dot(f, vec2(-dir.y, dir.x)));
		float d = along / 0.42 + across / 0.1 - 1.0;
		return 1.0 - smoothstep(-0.25, 0.05, d);
	} else if (pattern == PAT_TREAD_BARS) {
		// Five bars to a cell, the cells' bars at right angles to their neighbours'.
		if (flip > 0.5) {
			f = f.yx;
		}
		float across = (fract((f.y + 0.5) * 5.0) - 0.5) / 5.0;
		float d = length(vec2(max(abs(f.x) - 0.36, 0.0), across)) - 0.042;
		return 1.0 - smoothstep(-0.012, 0.012, d);
	} else if (pattern == PAT_TREAD_SQUARES) {
		vec2 b = max(abs(f) - vec2(0.22), vec2(0.0));
		float d = length(b) - 0.08;
		return 1.0 - smoothstep(-0.03, 0.03, d);
	}
	// Perforated: round holes, every other row a half step along.
	vec2 g = c;
	g.x += mod(floor(g.y), 2.0) * 0.5;
	float d = length(fract(g) - 0.5) - 0.3;
	return smoothstep(-0.03, 0.03, d);
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
	} else if (pattern >= PAT_TREAD_DIAMOND) {
		// The raised pattern, its slope by differences, all of it faded to its coverage as a
		// cell goes under a few pixels (the shade stays, the bump goes flat).
		float n = tread_cells(pattern);
		vec2 c = uv * n;
		float per_cell = 256.0 / max(px * n, 0.001);
		float sharp = smoothstep(2.5, 6.0, per_cell);
		float m = tread_mask(pattern, c);
		const float STEP_E = 0.03;
		vec2 g = vec2(tread_mask(pattern, c + vec2(STEP_E, 0.0)) - m, tread_mask(pattern, c + vec2(0.0, STEP_E)) - m) / STEP_E;
		float cover = pattern == PAT_TREAD_PERFORATED ? 0.72 : (pattern == PAT_TREAD_DIAMOND ? 0.16 : 0.38);
		h = mix(cover, m, sharp);
		t = -g * 0.06 * sharp + nm.xy * 0.15;
		cav = (pattern == PAT_TREAD_PERFORATED ? 1.0 - h : 0.0);
		tone = h;
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
	// The piece's own values: its material's, or its row in a merged look's part table.
	vec4 p_condition = condition;
	vec4 p_scorch_at = scorch_at;
	vec4 p_scorch_line = scorch_line;
	vec4 p_fresh = fresh;
	vec4 p_hot_at = hot_at;
	vec4 p_part_box_centre = part_box_centre;
	vec4 p_part_box_half = part_box_half;
	vec4 p_part_up = part_up;
	float p_hot = hot;
	int p_part_layer = part_layer;
	int p_part_hazard = part_hazard;
	mat3 to_body = mat3(1.0);   // piece space -> the mesh's (a merged look's: its body's)
	if (merged_parts) {
		p_condition = part_field(v_slot, 3);
		p_scorch_at = part_field(v_slot, 4);
		p_scorch_line = part_field(v_slot, 5);
		p_fresh = part_field(v_slot, 6);
		p_hot_at = part_field(v_slot, 7);
		p_part_box_centre = part_field(v_slot, 8);
		p_part_box_half = part_field(v_slot, 9);
		p_part_up = part_field(v_slot, 10);
		vec4 misc = part_field(v_slot, 11);
		p_hot = misc.x;
		p_part_layer = int(misc.y + 0.5);
		p_part_hazard = int(misc.z + 0.5);
		// The basis rows are body -> piece; turned only (mirrored pieces never merge), so the
		// matrix with them as its columns, the transpose, takes a piece's normal back to the body.
		to_body = mat3(part_field(v_slot, 0).xyz, part_field(v_slot, 1).xyz, part_field(v_slot, 2).xyz);
	}
	float wear = p_condition.x;
	float scorch = p_condition.y;
	float scorch_radius = p_condition.z;
	float seed = p_condition.w;
	vec3 q = local_pos + vec3(seed * 13.7, seed * 7.3, seed * 3.1);
	// The finish: the zone's own, else the part's material's, else the paint as built.
	int fin = v_zone > 0 ? v_zone : v_fin;
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
	float raise = f3.z;
	float raise_rough = f3.w;
	int effect = int(texelFetch(finish_table, ivec2(4, fin), 0).a + 0.5);
	// Scanned layers (scan_layers.gdshaderinc): this finish's base, bare and rust layers (-1 none).
	vec4 s0 = vec4(0.0);
	vec4 s1 = vec4(0.0);
	vec4 s2 = vec4(0.0);
	int base_l = -1;
	int bare_l = -1;
	int rust_l = -1;
	if (scan_on) {
		s0 = texelFetch(scan_table, ivec2(0, fin), 0);
		s1 = texelFetch(scan_table, ivec2(1, fin), 0);
		s2 = texelFetch(scan_table, ivec2(2, fin), 0);
		base_l = int(s0.x + 0.5) - 1;
		bare_l = int(s1.x + 0.5) - 1;
		rust_l = int(s1.y + 0.5) - 1;
	}
	bool scanned = base_l >= 0;
	if (scanned) {
		// The scan is the surface's detail: the drawn pattern neither bumps nor shades it.
		bump = 0.0;
		relief = 0.0;
		raise = 0.0;
		raise_rough = 0.0;
	}
	vec3 detail_bn = normalize(local_normal);   // the drawn pattern's bumped normal (part space)
	bool tread = pattern >= PAT_TREAD_DIAMOND;
	float raised = 0.0;   // a tread plate's raised pattern (0..1, faded to its coverage far off)
	float met = as_built ? v_mr.x : f0.x;
	float rough = as_built ? v_mr.y : f0.y;
	float spec = f0.z;
	float coat = f0.w;
	bool tinted = as_built || v_zone == 0 || f2.z > 0.5;
	vec3 col = albedo * vertex_tint * (tinted ? material_tint : vec3(1.0));
	if (v_zone == 0 && !as_built) {
		// The part is made of this: its own colour shows through the paint by material_blend.
		vec3 own = finish_colour.w > 0.5 ? finish_colour.rgb : texelFetch(finish_table, ivec2(4, fin), 0).rgb;
		col = mix(col, own * material_tint, material_blend);
	}
	if (effect == FX_STRIPES && v_zone == 0) {
		// Hazard stripes (LK4): black bands between the colour, drawn whatever the detail setting;
		// far off, where a band goes under a pixel, they blend to an even mix.
		float s;
		if (dot(stripe_frame.xyz, stripe_frame.xyz) > 0.0) {
			// One diagonal through the body: on any face square to its axes it runs as below,
			// and it carries on across a seam onto the next plate.
			s = (dot(local_pos, stripe_frame.xyz) + stripe_frame.w) / (2.0 * STRIPE_BAND);
		} else {
			vec3 an = abs(normalize(local_normal));
			vec2 sp = an.y >= max(an.x, an.z) ? local_pos.xz : (an.x >= an.z ? local_pos.zy : local_pos.xy);
			s = (sp.x + sp.y) / (2.0 * STRIPE_BAND);
		}
		float sw = max(fwidth(s), 0.0001);
		float tri = abs(fract(s) - 0.5) * 2.0;
		float dark = 1.0 - smoothstep(0.5 - sw, 0.5 + sw, tri);
		dark = mix(dark, 0.5, smoothstep(0.2, 0.5, sw));
		col = mix(col, vec3(0.02), dark);
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
		if (tread) {
			// The raised pattern: lighter and smoother than the plate (worn by boots), the holes
			// of a perforated plate dark.
			raised = h;
			col *= 1.0 + raise * raised * dl;
			rough = clamp(rough + raise_rough * raised * dl, 0.05, 1.0);
			if (pattern == PAT_TREAD_PERFORATED) {
				col *= 1.0 - 0.8 * cavity * dl;
			}
			h = 0.5;
		}
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
		// A finish's own mark (LK3), each faded out where its grain goes under a pixel.
		if (effect == FX_SPARKLE) {
			// Anodising: its colour a little uneven, and a glint here and there in the film.
			col *= 1.0 + (noise(q * 5.0) - 0.5) * 0.14 * dl;
			float glint = step(0.97, hash(floor(local_pos * 900.0 + vec3(seed)))) * dl
					* (1.0 - smoothstep(0.6, 1.6, length(dp) * 900.0));
			col = mix(col, col * 1.8 + vec3(0.12), glint);
			rough = mix(rough, 0.2, glint);
		} else if (effect == FX_SMUDGE) {
			// Chrome: soft smudges dulling the shine, prints within them.
			float smudge = smoothstep(0.5, 0.8, fbm(q * 7.0)) * dl;
			float prints = smudge * smoothstep(0.4, 0.6, noise(q * 400.0)) * (1.0 - smoothstep(0.5, 1.5, length(dp) * 400.0));
			rough = clamp(rough + 0.22 * smudge + 0.1 * prints, 0.03, 1.0);
			col *= 1.0 - 0.08 * smudge;
		} else if (effect == FX_SPECKLE) {
			// Cast iron: a fine dark-and-light grain, a little rust brown in its hollows.
			float speck = noise(q * 300.0);
			float near_px = 1.0 - smoothstep(0.6, 1.8, length(dp) * 300.0);
			col *= 1.0 + (speck - 0.5) * 0.5 * near_px * dl;
			col += vec3(0.06, 0.02, 0.0) * smoothstep(0.6, 0.8, fbm(q * 5.0)) * dl;
			rough = clamp(rough + (speck - 0.5) * 0.15 * near_px * dl, 0.03, 1.0);
		}
		// Temper colours: blue and straw in soft patches, as heat-treated titanium shows.
		if (temper > 0.001) {
			float pt = noise(q * 0.9 + vec3(3.3));
			vec3 tint = mix(vec3(1.08, 1.0, 0.82), vec3(0.78, 0.88, 1.25), smoothstep(0.35, 0.65, pt));
			col = mix(col, col * tint, temper * dl * smoothstep(0.2, 0.8, abs(pt - 0.5) * 2.0 + 0.3));
		}
		// The bumped normal (part space -> view), facing the camera on back faces too.
		if (nl > 0.001) {
			vec3 bn = normalize(n + bmp * bump * nl * (tread ? 1.0 : fade));
			detail_bn = bn;
			vec3 v = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(to_body * bn, 0.0))).xyz);
			NORMAL = FRONT_FACING ? v : -v;
		}
	}
	// Scanned layers: the base's micro detail on the finish's own colour (its colour against its
	// blur, so the paint's colour rules and the scan's broad blotches never repeat), its roughness
	// and bumps; then the bare and rust layers the wear below shows where its masks say.
	vec3 scan_p = local_pos + vec3(seed * 5.31, seed * 2.17, seed * 3.71);
	vec3 scan_n = normalize(local_normal);
	vec3 scan_tilt = vec3(0.0);
	float scan_bare_w = 0.0;   // how much of the bare layer shows (chips, scratches), for its bumps
	float scan_rust_w = 0.0;   // and of the rust layer
	if (scanned) {
		vec3 sc;
		vec3 sb;
		vec3 so;
		vec3 st;
		scan_layer_at(base_l, scan_p, scan_n, max(s2.x, 0.05), true, sc, sb, st, so);
		vec3 ratio = scan_ratio(sc, sb, s1.z);
		col *= mix(vec3(1.0), ratio, s0.y * surface_detail);
		float r_mean = textureLod(scan_orm, vec3(0.5, 0.5, float(base_l)), 12.0).g;
		rough = clamp(rough + (so.g - r_mean) * s0.w, 0.03, 1.0);
		scan_tilt = st * s0.z;
		float lum = dot(ratio, vec3(0.3333));
		cavity = max(cavity, clamp(1.0 - lum, 0.0, 1.0) * 0.8);
		if (s2.y > 0.0) {
			raised = clamp((lum - 1.0) * 3.0 + 0.35, 0.0, 1.0) * s2.y;
		}
		// Each plate a little apart from its neighbours, and broad drift over it.
		float mac = fbm(scan_p / scan_macro_m + vec3(seed));
		col *= (1.0 + (hash(vec3(seed * 3.1, 1.3, 2.7)) - 0.5) * 0.1) * (1.0 - scan_macro * 0.4 * (mac - 0.5));
		rough = clamp(rough + scan_macro * 0.2 * (mac - 0.5), 0.03, 1.0);
	}
	vec3 bare_ratio = vec3(1.0);
	vec3 bare_tilt = vec3(0.0);
	vec3 bare_orm = vec3(0.0, 0.5, 0.8);
	bool has_bare = bare_l >= 0 && p_condition.x > 0.001;
	if (has_bare) {
		vec3 bc;
		vec3 bb;
		scan_layer_at(bare_l, scan_p + vec3(2.3, 0.7, 4.1), scan_n, 1.0, true, bc, bb, bare_tilt, bare_orm);
		bare_ratio = scan_ratio(bc, bb, 0.6);
	}
	vec3 rust_c = vec3(1.0);   // the rust scan against its own mean: the game's rust colours times this
	vec3 rust_tilt = vec3(0.0);
	vec3 rust_orm = vec3(0.0, 0.85, 0.2);
	float rust_grain = 0.0;   // the rust scan's own light and dark (-1..1): the rust's edges follow it
	bool has_rust = rust_l >= 0 && p_condition.x > 0.001 && rust > 0.001;
	if (has_rust) {
		vec3 rb;
		vec3 rc;
		scan_layer_at(rust_l, scan_p + vec3(7.7, 1.1, 0.4), scan_n, 1.0, false, rc, rb, rust_tilt, rust_orm);
		vec3 r_mean = textureLod(scan_albedo, vec3(0.5, 0.5, float(rust_l)), 12.0).rgb;
		rust_c = scan_ratio(rc, r_mean, 0.7);
		rust_grain = clamp(dot(rust_c, vec3(0.3333)) - 1.0, -1.0, 1.0);
	}
	// The edges (LK1): how far this point is from the nearest edge of the face it is on (the
	// box's sides: on a face one of the three is ~0, the face itself; the next is its edge),
	// a ragged band that widens with wear and more at the corners, and how it sits in the
	// ship (LK2): its height on the face along the ship's up, and how much it faces up.
	bool edged = p_part_box_half.w > 0.5 && wear > 0.001;
	float edge_d = 1.0;      // m in from the nearest edge (ragged)
	float band = 0.0;        // m: how far chips reach in from an edge
	float edge_fade = 0.0;   // 0 where the band is under a pixel or two: nothing to draw
	float up_face = 0.0;     // 1 facing the ship's up, -1 facing down
	float height = 0.0;      // -1 at the face's bottom along the ship's up .. 1 at its top
	bool upped = p_part_up.w > 0.5;
	vec3 nrm = normalize(local_normal);
	if (upped) {
		up_face = dot(nrm, p_part_up.xyz);
	}
	if (edged) {
		vec3 rel = local_pos - p_part_box_centre.xyz;
		vec3 d = max(p_part_box_half.xyz - abs(rel), vec3(0.0));
		float lo = min(d.x, min(d.y, d.z));
		float hi = max(d.x, max(d.y, d.z));
		float mid = d.x + d.y + d.z - lo - hi;
		band = mix(0.015, 0.08, wear);
		// Corners: where both edges are near, the band runs further in.
		band *= 1.0 + 0.9 * (1.0 - smoothstep(0.0, band * 3.0, hi));
		float ragged = (noise(q * 31.0) - 0.5) * 1.1 + (noise(q * 7.3 + vec3(2.1)) - 0.5) * 0.9;
		edge_d = mid + ragged * band;
		edge_fade = smoothstep(length(dp) * 0.8, length(dp) * 2.5, band);
		if (upped) {
			float ext = max(dot(abs(p_part_up.xyz), p_part_box_half.xyz), 0.01);
			height = clamp(dot(rel, p_part_up.xyz) / ext, -1.0, 1.0);
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
		if (scanned) {
			scratch *= 0.45;   // the scan carries its own fine marks
		}
		// Patches: chips, scuffs, stains, dust: large and soft-edged.
		float patch_n = fbm(q * 1.6 + vec3(5.0));
		float patch_lo = 0.62;
		float patch_gate = 1.0;
		if (scanned) {
			// With scans: no blobs. Chips gather in clusters (a broad warped noise picks where),
			// each cluster small ragged flakes at several sizes whose edges follow the bare scan's
			// grain; most of a plate keeps its paint.
			vec3 warp = vec3(noise(q * 0.9), noise(q * 0.9 + vec3(3.1)), noise(q * 0.9 + vec3(7.3))) - 0.5;
			patch_n = fbm(q * 5.5 + vec3(5.0) + warp * 2.5) * 0.8 + noise(q * 24.0) * 0.2
					+ (dot(bare_ratio, vec3(0.3333)) - 1.0) * 0.1;
			patch_gate = smoothstep(0.6, 0.8, fbm(q * 0.55 + warp * 0.8 + vec3(9.0)) + 0.1 * wear);
			patch_lo = 0.6;
		}
		float patch = smoothstep(patch_lo - 0.14 * wear, patch_lo + 0.05 - 0.14 * wear, patch_n) * min(wear * 1.2, 1.0) * patch_gate;
		if (edged) {
			// A plate wears at its edges first: chips out in its middle only once it is old.
			patch *= smoothstep(0.45, 0.85, wear);
		}
		vec3 bare = vec3(0.56, 0.56, 0.55) * (tinted ? material_tint : vec3(1.0)) * bare_ratio;
		float rust_n = noise(q * 2.4 + vec3(11.0)) + rust_grain * 0.25;
		float rust_in = smoothstep(0.45, 0.75, rust_n) * wear * rust;
		vec3 rusty = mix(bare, vec3(0.4, 0.24, 0.13) * rust_c, rust_in);
		if (wear_mode == WEAR_PAINT) {
			// Paint chipped off in ragged patches: a pale primer rim, bare steel, rust in the
			// oldest; scratches show the metal too.
			float rim = smoothstep(patch_lo - 0.06 - 0.14 * wear, patch_lo - 0.14 * wear, patch_n) * (1.0 - patch) * min(wear * 1.2, 1.0) * patch_gate;
			if (edged) {
				rim *= smoothstep(0.45, 0.85, wear);
				// Knocked edges (LK1): crisp chips back to bare steel, a primer rim round each,
				// in runs along the edge (more of the edge as it ages), the corners first.
				float runs = smoothstep(0.62 - 0.5 * wear, 0.78 - 0.5 * wear, noise(q * 3.1 + vec3(7.7)));
				float chip_e = (1.0 - smoothstep(band * 0.82, band * 0.9, edge_d)) * runs * edge_fade;
				float rim_e = (1.0 - smoothstep(band * 0.9, band * 1.3, edge_d)) * runs * edge_fade * (1.0 - chip_e);
				// Small flecks just off the edge, where knocks landed.
				float fleck = step(0.86 - 0.08 * wear, noise(q * 46.0)) * (1.0 - smoothstep(band, band * 2.6, edge_d)) * edge_fade;
				patch = max(patch, max(chip_e, fleck * runs));
				rim = max(rim, rim_e);
			}
			col = mix(col, vec3(0.6, 0.58, 0.52) * (tinted ? material_tint : vec3(1.0)), rim * 0.7);
			col = mix(col, rusty, patch);
			col = mix(col, bare, scratch * 0.8);
			scan_bare_w = max(patch * (1.0 - rust_in), scratch * 0.8);
			scan_rust_w = patch * rust_in;
			met = mix(met, 0.75, max(patch * (1.0 - rust_n * rust * 0.7), scratch * 0.8));
			rough = mix(rough, 0.5, max(patch, scratch));
			coat *= 1.0 - max(patch, scratch);
		} else if (wear_mode == WEAR_METAL) {
			// Dulled patches, bright fresh scratches, rust bloom on steel.
			if (edged) {
				// Knocked edges (LK1): the coat (an alloy hull's paint, anodising) worn back
				// to bright bare metal in runs along the edge, a dark line where it lifts.
				float runs = smoothstep(0.62 - 0.5 * wear, 0.78 - 0.5 * wear, noise(q * 3.1 + vec3(7.7)));
				float chip_e = (1.0 - smoothstep(band * 0.82, band * 0.9, edge_d)) * runs * edge_fade;
				float lift = (1.0 - smoothstep(band * 0.9, band * 1.15, edge_d)) * runs * edge_fade * (1.0 - chip_e);
				float fleck = step(0.86 - 0.08 * wear, noise(q * 46.0)) * (1.0 - smoothstep(band, band * 2.6, edge_d)) * edge_fade * runs;
				float worn = max(chip_e, fleck);
				vec3 bright = vec3(0.68, 0.68, 0.69) * (tinted ? material_tint : vec3(1.0)) * bare_ratio;
				scan_bare_w = worn;
				col = mix(col, col * 0.75, lift * 0.6);
				col = mix(col, bright, worn);
				met = mix(met, 0.85, worn);
				rough = mix(rough, 0.32, worn);
				coat *= 1.0 - worn;
				patch *= smoothstep(0.45, 0.85, wear);
			}
			col = mix(col, col * 0.8, patch * 0.6);
			rough = mix(rough, min(rough + 0.35, 1.0), patch);
			col = mix(col, col * 1.25 + vec3(0.05), scratch * 0.7);
			rough = mix(rough, 0.3, scratch * 0.5);
			float bloom = smoothstep(0.5, 0.8, rust_n) * wear * rust * 0.9 * smoothstep(0.3, 0.6, patch_n);
			col = mix(col, vec3(0.42, 0.25, 0.13) * rust_c, bloom);
			scan_rust_w = max(scan_rust_w, bloom);
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
		// Age (LK2): rust creeping in from the edges of steel that rusts, streaks of it run
		// down the walls under the edges, grime along the edges and low on a wall, dust on
		// what faces up. None of it on a finish that never rusts (rust 0) but the grime and
		// dust, and none of it on a fresh plate (wear under 0.3).
		float age = smoothstep(0.3, 0.9, wear);
		if (edged && age > 0.001) {
			float wall = 1.0 - abs(up_face);
			if (rust > 0.001 && (wear_mode == WEAR_PAINT || wear_mode == WEAR_METAL)) {
				float pits = noise(q * 85.0);
				vec3 rust_col = mix(vec3(0.24, 0.1, 0.05), vec3(0.6, 0.3, 0.11), smoothstep(0.3, 0.8, fbm(q * 9.0)));
				rust_col *= 0.8 + 0.4 * pits;
				rust_col *= rust_c;
				// From the edge in, in blooms: reaching further, and more of the edge, with age.
				float reach = band * (1.2 + 2.5 * age);
				float creep = (1.0 - smoothstep(reach * 0.5, reach, edge_d + (fbm(q * 4.2) - 0.5) * reach - rust_grain * reach * 0.35))
						* smoothstep(0.55 - 0.35 * age, 0.75 - 0.35 * age, noise(q * 2.3 + vec3(4.4)));
				creep *= rust * age * edge_fade;
				col = mix(col, rust_col, creep * 0.9);
				scan_rust_w = max(scan_rust_w, creep);
				met = mix(met, 0.15, creep);
				rough = mix(rough, 0.9, creep);
				coat *= 1.0 - creep;
				// Streaks down a wall from its top edge and from the chips.
				if (upped) {
					vec3 across_dir = normalize(cross(nrm, p_part_up.xyz) + vec3(1e-4));
					float across = dot(local_pos, across_dir);
					float along = dot(local_pos, p_part_up.xyz);
					float column = noise(vec3(across * 34.0, along * 1.1, seed));
					float run = smoothstep(0.62, 0.9, column) * smoothstep(-0.6, 0.9, height);
					run *= (0.6 + 0.4 * noise(vec3(across * 6.0, along * 9.0, seed + 3.0)));
					float streak = run * wall * rust * age * 0.55;
					vec3 streak_col = mix(vec3(0.3, 0.14, 0.06), vec3(0.5, 0.26, 0.1), pits);
					streak_col *= mix(vec3(1.0), rust_c, 0.6);
					col = mix(col, streak_col, streak);
					rough = mix(rough, 0.85, streak * 0.7);
				}
			}
			// Grime: a dark line along the edges and seams, more low on a wall.
			float grimy = (1.0 - smoothstep(0.0, band * 2.5, edge_d)) * 0.45 * edge_fade;
			if (upped) {
				grimy += (1.0 - smoothstep(-1.0, 0.1, height)) * wall * 0.35;
			}
			grimy *= age * (0.6 + 0.6 * grime);
			col *= 1.0 - 0.45 * clamp(grimy, 0.0, 1.0);
			rough = mix(rough, 0.9, grimy * 0.5);
		}
		if (upped && age > 0.001) {
			// Dust: a grey film on faces looking up, thicker in the hollows and at the edges.
			float settle = smoothstep(0.35, 0.9, up_face) * age;
			float dust = settle * (0.35 + 0.25 * noise(q * 18.0) + 0.3 * cavity + (edged ? 0.2 * (1.0 - smoothstep(0.0, band * 3.0, edge_d)) : 0.0));
			if (scanned) {
				// On a scanned surface it lies thinner, in the scan's hollows and grain.
				dust *= 0.45 + 0.5 * clamp(cavity * 1.6, 0.0, 1.0) + 0.3 * (noise(q * 4.0) - 0.5);
			}
			dust = clamp(dust, 0.0, 0.7);
			col = mix(col, vec3(0.42, 0.4, 0.37), dust);
			met = mix(met, 0.0, dust * 0.8);
			rough = mix(rough, 0.95, dust);
			coat *= 1.0 - dust;
		}
		if (tread && wear_mode == WEAR_PAINT) {
			// A painted tread plate: boots wear the paint off the raised tops to bright steel.
			float trod = raised * smoothstep(0.1, 0.6, wear) * smoothstep(0.3, 0.6, noise(q * 2.7 + vec3(1.3)));
			col = mix(col, vec3(0.6, 0.6, 0.6), trod);
			met = mix(met, 0.8, trod);
			rough = mix(rough, 0.35, trod);
			coat *= 1.0 - trod;
		}
		if (effect == FX_PATINA) {
			// Copper (LK3): green patina as it ages, at its edges and in its hollows only.
			float at_edge = edged ? 1.0 - smoothstep(0.0, band * 2.0 + 0.02, edge_d) : 0.0;
			float where = max(at_edge, cavity * 0.8);
			float pn = fbm(q * 5.0) + 0.15 * noise(q * 60.0);
			float patina = smoothstep(0.6, 0.78, pn * 0.85 + where * 0.4 - 0.12) * where * smoothstep(0.05, 0.45, wear);
			vec3 green = mix(vec3(0.07, 0.2, 0.14), vec3(0.16, 0.33, 0.25), noise(q * 40.0));
			col = mix(col, green, patina);
			met = mix(met, 0.0, patina);
			rough = mix(rough, 0.85, patina);
			coat *= 1.0 - patina;
		}
	}
	if (scanned || has_bare || has_rust) {
		// The layers' bumps and the rust's own roughness where each shows.
		scan_bare_w = clamp(scan_bare_w, 0.0, 1.0);
		scan_rust_w = clamp(scan_rust_w, 0.0, 1.0);
		if (has_rust) {
			rough = mix(rough, clamp(rust_orm.g * 1.05, 0.4, 1.0), scan_rust_w * 0.7);
		}
		if (has_bare) {
			rough = mix(rough, clamp(rough * 0.6 + bare_orm.g * 0.4, 0.15, 1.0), scan_bare_w * 0.5);
		}
		vec3 tilt = scan_tilt * (1.0 - scan_bare_w) * (1.0 - scan_rust_w) + bare_tilt * 0.8 * scan_bare_w
				+ rust_tilt * s1.w * scan_rust_w;
		vec3 bn = normalize(detail_bn + tilt * surface_normal);
		vec3 v = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(to_body * bn, 0.0))).xyz);
		NORMAL = FRONT_FACING ? v : -v;
	}
	float soot = 0.0;
	if (scorch > 0.001) {
		float s = scorch;
		if (scorch_radius > 0.001) {
			vec3 off = local_pos - p_scorch_at.xyz;
			if (p_scorch_line.w > 0.5) {
				off -= p_scorch_line.xyz * dot(off, p_scorch_line.xyz);
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
	// Glowing metal: a temperature (0..1) drawn on the blackbody ramp. Fresh from a blast
	// (`hot`) the heart of it glows yellow-white, the rest orange; as it cools the glow draws
	// back out of the plate into the cracks and the torn edges and goes red. A fresh wreck
	// (`fresh`) smoulders: thin dull red cracks through the blackest soot, breathing slowly.
	float glow_t = 0.0;
	if (p_hot > 0.001 || p_fresh.x > 0.001) {
		float n = fbm(q * vec3(2.4, 1.2, 2.4));
		float crack = pow(clamp(1.0 - abs(n - 0.47) * 3.2, 0.0, 1.0), 5.0);
		float edge = 0.0;
		if (dot(p_fresh.yzw, p_fresh.yzw) > 0.5) {
			edge = smoothstep(0.85, 1.0, 1.0 - abs(dot(normalize(local_normal), p_fresh.yzw)));
		}
		if (p_hot > 0.001) {
			float zone = 1.0;
			if (p_hot_at.w > 0.001) {
				float d = length(local_pos - p_hot_at.xyz) + (fbm(q * 0.7) - 0.5) * p_hot_at.w * 0.4;
				zone = 1.0 - smoothstep(p_hot_at.w * 0.2, p_hot_at.w, d);
			}
			glow_t = p_hot * zone * (0.55 + 0.7 * n + 0.45 * crack + 0.6 * edge);
		}
		if (p_fresh.x > 0.001) {
			float breath = 0.75 + 0.25 * sin(TIME * 0.7 + fbm(q * 1.7) * 6.2831853);
			float ember = smoothstep(0.8, 1.0, soot) * crack;
			glow_t = max(glow_t, p_fresh.x * (ember * 0.5 + edge * 0.3) * breath);
		}
		glow_t = clamp(glow_t, 0.0, 1.0);
		float lit = smoothstep(0.05, 0.18, glow_t);
		// What glows is black scale under it: the light is all its own.
		float scale_on = smoothstep(0.15, 0.5, glow_t);
		col = mix(col, vec3(0.05, 0.045, 0.04), scale_on);
		met = mix(met, 0.3, scale_on);
		rough = mix(rough, 0.9, scale_on);
		coat *= 1.0 - scale_on;
		EMISSION += blackbody(glow_t) * (0.25 + 7.0 * glow_t * glow_t) * lit;
	}
	if (!survey_skip && survey_layer >= 0 && survey_through_glass(world_pos, CAMERA_POSITION_WORLD)) {
		float side = dot(world_pos, survey_sweep.xyz) - survey_sweep.w;
		int layer = side < 0.0 ? survey_layer : survey_layer_old;
		if (p_part_hazard > 0) {
			// Live wiring red, charged fuel orange: pulsing, never ghosted. A work order's amber
			// and blue (TS3b) breathe slower and softer.
			vec3 hazard = hazard_colour(p_part_hazard);
			float pulse = hazard_pulse(p_part_hazard);
			col = mix(col, hazard, p_part_hazard > 2 ? 0.45 : 0.6);
			EMISSION += hazard * 1.2 * pulse;
		} else if (layer > 0) {
			if (p_part_layer == layer) {
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
	} else if (!survey_skip) {
		// The scan pulse (VX8b): inside its shell the hazards glow as through the glass, for
		// everyone; no layers, no ghosts. Its edge runs over the surfaces it meets.
		float in_pulse = survey_pulse_at(world_pos);
		if (p_part_hazard > 0 && in_pulse > 0.0) {
			vec3 hazard = hazard_colour(p_part_hazard);
			float pulse = hazard_pulse(p_part_hazard);
			col = mix(col, hazard, 0.6 * in_pulse);
			EMISSION += hazard * 1.2 * pulse * in_pulse;
		}
		EMISSION += vec3(0.35, 0.75, 1.0) * survey_pulse_edge(world_pos, 0.12) * 0.8;
	}
	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rough;
	SPECULAR = spec;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.15;
}
