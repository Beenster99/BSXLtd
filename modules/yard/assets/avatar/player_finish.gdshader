// The finish on the players' suits, hands and hand tools (PlayerAssets.finish; meshes from
// tools/blender/player_suits and tools/blender/player_concepts). One material a figure: what
// each bit of a mesh is made of rides in its vertices, the look's colours come in as uniforms.
//   COLOR     the fixed colour (roles that take no palette colour)
//   UV.x      role + metal * 0.49;  UV.y roughness
//   UV2       x edge (1 along a convex edge, where paint wears first), y occlusion (1 deep in
//             a recess); meshes without a UV2 (the hands, the tools) read 0 for both
// Roles: 0 fixed colour (metal over 0.6: bare metal; else a coating), 1 plates (the look's
// primary), 2 trim (its secondary), 3 accent light, 4 fixed light, 5 oxygen light, 6 cloth,
// 7 rubber, 8 accent paint, 9 cloth in the trim colour.
// The surface detail is scanned (assets/materials, CC0: paint, brushed metal, rubber), laid
// three ways in the mesh's own space by metres, used as layers: the scans give the grain,
// the scratches and the roughness; where paint gives way is the mesh's own edges and `wear`.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 plates : source_color = vec4(0.8, 0.82, 0.8, 1.0);
uniform vec4 trim : source_color = vec4(0.1, 0.4, 0.42, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 oxygen : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform vec4 heat : source_color = vec4(0.0);

uniform sampler2D paint_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paint_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rubber_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float paint_tile = 0.42;       // m of surface one repeat of the paint scan covers
uniform float metal_tile = 0.30;       // m, the brushed metal
uniform float rubber_tile = 0.16;      // m, the rubber's grain
uniform float weave_pitch = 0.0028;    // m between the cloth's threads
uniform float detail : hint_range(0.0, 1.0) = 1.0;      // 0 the plain finish .. 1 the scans' full relief
uniform float gloss : hint_range(0.0, 1.0) = 0.55;      // clear coat on clean paint
uniform float light_energy = 1.5;      // the lit strips' glow
uniform float shade : hint_range(0.0, 1.0) = 0.8;       // how dark the baked recesses go

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// A tangent normal from a two-channel (RGTC) picture: z rebuilt from x and y.
vec3 tangent_of(vec4 s, float strength) {
	vec3 t;
	t.xy = (s.xy * 2.0 - 1.0) * strength;
	t.z = sqrt(max(1.0 - dot(t.xy, t.xy), 0.0));
	return t;
}

// The tangent normal of projection `axis` bent onto the surface normal `n` (whiteout blend).
vec3 bend(vec3 t, vec3 n, int axis) {
	vec3 base = axis == 0 ? n.zyx : (axis == 1 ? n.xzy : n.xyz);
	vec3 b = vec3(t.xy + base.xy, abs(base.z) * t.z);
	b.z *= sign(base.z);
	return axis == 0 ? b.zyx : (axis == 1 ? b.xzy : b.xyz);
}

void fragment() {
	float role = floor(UV.x + 0.001);
	float metal_in = clamp((UV.x - role) / 0.49, 0.0, 1.0);
	float rough_in = UV.y;
	float edge = UV2.x;
	float occ = UV2.y;
	vec3 col = COLOR.rgb;
	float glow = 0.0;
	if (role == 1.0) col = plates.rgb;
	if (role == 2.0 || role == 9.0) col = trim.rgb;
	if (role == 8.0) col = accent.rgb;
	if (role == 3.0) { col = accent.rgb; glow = 1.0; }
	if (role == 4.0) glow = 1.2;
	if (role == 5.0) { col = oxygen.rgb; glow = 1.0; }
	bool lit = glow > 0.0;
	bool cloth = role == 6.0 || role == 9.0;
	bool rubber = role == 7.0;
	bool metal = role == 0.0 && metal_in >= 0.6;
	bool paint = !lit && !cloth && !rubber && !metal;

	vec3 n = normalize(local_normal);
	vec3 w = pow(abs(n), vec3(6.0));
	w /= (w.x + w.y + w.z);
	// Gradients taken outside the branches, so the mip level holds where a role changes.
	vec3 gx = dFdx(local_pos);
	vec3 gy = dFdy(local_pos);
	vec3 bent = n;
	float rough = rough_in;
	float metallic = metal_in;
	float coat = 0.0;
	float rim = 0.0;

	if (paint) {
		// The paint scan: its fine relief and scratches, its roughness, and its own bare
		// patches (ORM red: 1 paint) as the ragged shape of each chip.
		vec3 p = local_pos / paint_tile;
		vec3 dx = gx / paint_tile;
		vec3 dy = gy / paint_tile;
		vec3 orm = vec3(0.0);
		vec3 acc = vec3(0.0);
		float strength = detail * (0.3 + 0.9 * wear);
		if (w.x > 0.01) {
			orm += textureGrad(paint_orm, p.zy, dx.zy, dy.zy).rgb * w.x;
			acc += bend(tangent_of(textureGrad(paint_normal, p.zy, dx.zy, dy.zy), strength), n, 0) * w.x;
		}
		if (w.y > 0.01) {
			orm += textureGrad(paint_orm, p.xz, dx.xz, dy.xz).rgb * w.y;
			acc += bend(tangent_of(textureGrad(paint_normal, p.xz, dx.xz, dy.xz), strength), n, 1) * w.y;
		}
		if (w.z > 0.01) {
			orm += textureGrad(paint_orm, p.xy, dx.xy, dy.xy).rgb * w.z;
			acc += bend(tangent_of(textureGrad(paint_normal, p.xy, dx.xy, dy.xy), strength), n, 2) * w.z;
		}
		bent = normalize(acc);
		float gone = 1.0 - orm.r;                       // the scan's own chips and scratches
		float blotch = 0.6 * noise3(local_pos * 52.0) + 0.4 * noise3(local_pos * 118.0);
		float fine = noise3(local_pos * 210.0);
		// Bare metal: along the mesh's edges first, creeping out with wear; then the scan's
		// scratches, on worn suits only.
		float bare = edge * (0.25 + 1.5 * wear) + (blotch - 0.5) * 0.7 * wear + (fine - 0.5) * 0.35;
		bare = smoothstep(0.62, 0.78, bare) * step(0.01, wear);
		// (a dark coating keeps most of its own: grey blotches on black read as dust, not wear)
		bare = max(bare, smoothstep(0.55, 0.8, gone) * smoothstep(0.25, 0.75, wear + (blotch - 0.5) * 0.5) * (role == 0.0 ? 0.3 : 1.0));
		// Clean paint keeps a lighter line on its edges: the form reads at any range.
		col *= 1.0 + edge * 0.12 * (1.0 - bare);
		rough = clamp(rough_in * mix(1.0, 0.75 + 0.7 * orm.g, detail) + wear * 0.12, 0.08, 1.0);
		coat = gloss * (1.0 - wear) * (1.0 - metal_in) * step(rough_in, 0.5);
		// Scuffs dull the paint before it goes.
		float scuff = smoothstep(0.2, 0.55, gone) * wear;
		col = mix(col, col * 0.82 + vec3(0.03), scuff);
		// Under the paint: a pale primer at the chip's rim, bright metal in its middle.
		vec3 steel = vec3(0.60, 0.61, 0.63) * (0.8 + 0.4 * fine);
		col = mix(col, steel, bare);
		metallic = mix(metal_in, 0.75, bare);
		rough = mix(rough, 0.36 + 0.2 * fine, bare);
		coat *= 1.0 - bare;
	} else if (metal) {
		vec3 p = local_pos / metal_tile;
		vec3 dx = gx / metal_tile;
		vec3 dy = gy / metal_tile;
		vec3 orm = vec3(0.0);
		vec3 acc = vec3(0.0);
		float strength = detail * 0.9;
		if (w.x > 0.01) {
			orm += textureGrad(metal_orm, p.zy, dx.zy, dy.zy).rgb * w.x;
			acc += bend(tangent_of(textureGrad(metal_normal, p.zy, dx.zy, dy.zy), strength), n, 0) * w.x;
		}
		if (w.y > 0.01) {
			orm += textureGrad(metal_orm, p.xz, dx.xz, dy.xz).rgb * w.y;
			acc += bend(tangent_of(textureGrad(metal_normal, p.xz, dx.xz, dy.xz), strength), n, 1) * w.y;
		}
		if (w.z > 0.01) {
			orm += textureGrad(metal_orm, p.xy, dx.xy, dy.xy).rgb * w.z;
			acc += bend(tangent_of(textureGrad(metal_normal, p.xy, dx.xy, dy.xy), strength), n, 2) * w.z;
		}
		bent = normalize(acc);
		rough = clamp(rough_in * mix(1.0, 0.45 + 1.5 * orm.g, detail) + wear * 0.1, 0.06, 1.0);
		col *= 1.0 + edge * 0.25;
		col *= 1.0 - 0.18 * wear * noise3(local_pos * 60.0);
	} else if (rubber || cloth) {
		vec3 p = local_pos / rubber_tile;
		vec3 dx = gx / rubber_tile;
		vec3 dy = gy / rubber_tile;
		vec3 acc = vec3(0.0);
		float strength = detail * (rubber ? 0.9 : 0.45);
		if (w.x > 0.01) acc += bend(tangent_of(textureGrad(rubber_normal, p.zy, dx.zy, dy.zy), strength), n, 0) * w.x;
		if (w.y > 0.01) acc += bend(tangent_of(textureGrad(rubber_normal, p.xz, dx.xz, dy.xz), strength), n, 1) * w.y;
		if (w.z > 0.01) acc += bend(tangent_of(textureGrad(rubber_normal, p.xy, dx.xy, dy.xy), strength), n, 2) * w.z;
		bent = normalize(acc);
		if (cloth) {
			// A woven cloth: threads crossing in the surface's main plane, faded out with
			// distance before they can shimmer; a soft sheen at grazing angles.
			vec2 q = w.x > w.y && w.x > w.z ? local_pos.zy : (w.y > w.z ? local_pos.xz : local_pos.xy);
			vec2 th = q * 6.2832 / weave_pitch;
			float fade = clamp(1.0 - max(length(dFdx(th)), length(dFdy(th))) * 0.45, 0.0, 1.0) * detail;
			float over = sin(th.x) * sin(th.y);
			float twill = sin(th.x * 0.5 + th.y * 0.5);
			col *= 1.0 + fade * (0.16 * over + 0.08 * twill);
			rough = clamp(rough_in + 0.06 * fade * over, 0.3, 1.0);
			rim = 0.35;
			col *= 1.0 - 0.25 * wear * noise3(local_pos * 22.0);
		} else {
			col *= 1.0 + edge * 0.5 + 0.35 * wear * noise3(local_pos * 90.0);
		}
	}

	// Baked shade in the recesses, grime gathering there as the suit wears.
	float grime = wear * clamp(occ * 0.9 + (noise3(local_pos * 17.0) - 0.45) * 0.5, 0.0, 1.0);
	if (!lit) {
		col = mix(col, vec3(0.045, 0.04, 0.035), grime * 0.55);
		rough = mix(rough, 0.9, grime * 0.6);
		coat *= 1.0 - grime;
		col *= 1.0 - occ * shade * 0.45;
		AO = 1.0 - occ * shade;
		AO_LIGHT_AFFECT = 0.5;
	}
	ALBEDO = lit ? col * 0.35 : col;
	METALLIC = lit ? 0.0 : metallic;
	ROUGHNESS = lit ? 0.3 : rough;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.12;
	RIM = rim;
	RIM_TINT = 0.7;
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(bent, 0.0)).xyz);
	EMISSION = col * glow * light_energy + heat.rgb;
}
