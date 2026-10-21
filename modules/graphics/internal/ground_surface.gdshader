shader_type spatial;
// G5, the yard's ground surfaces: concrete, the red dust plain, epoxy hall floors, asphalt.
// Everything is laid out in world space (no UVs needed, merged and MultiMesh copies line up)
// on the plane the face lies in: soft patches, a tint per poured slab, aggregate specks,
// dirty and damp patches, oil spots on upward faces, scuffs, and a little relief. Fine
// detail fades out where it would shimmer (far away, at grazing angles).

uniform vec3 albedo = vec3(0.2);         // linear colour the owner painted
uniform float roughness = 0.9;
uniform float mottle = 0.1;              // big soft patches, share of the colour
uniform float mottle_scale = 0.3;        // per metre
uniform float slab = 0.0;                // m, one tint per poured slab (0: none)
uniform float slab_tint = 0.04;
uniform float grain = 0.08;              // aggregate specks
uniform float grain_scale = 25.0;        // per metre
uniform float stains = 0.3;              // darker dirty and damp patches
uniform float stain_scale = 0.07;        // per metre
uniform float oil = 0.0;                 // share of spots that have an oil stain, upward faces
uniform float oil_size = 0.8;            // m, the biggest stain's radius
uniform vec3 oil_colour = vec3(0.03, 0.024, 0.016);
uniform float dust = 0.0;                // drifts of dust_colour
uniform vec3 dust_colour = vec3(0.3, 0.17, 0.1);
uniform float scuffs = 0.0;              // shinier and duller streaks (traffic on epoxy)
uniform float bump = 0.25;               // relief strength
uniform float bump_scale = 5.0;          // per metre

varying vec3 wpos;
varying vec3 wnorm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s / 0.9375;
}

// The relief: broad pitting plus the specks.
float height(vec2 p) {
	return fbm(p * bump_scale) + 0.5 * grain * step(0.82, vnoise(p * grain_scale));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnorm);
	vec3 a = abs(n);
	// The plane the face lies in, and its two directions in the world.
	vec2 uv;
	vec3 t;
	vec3 b;
	if (a.y >= a.x && a.y >= a.z) {
		uv = wpos.xz; t = vec3(1.0, 0.0, 0.0); b = vec3(0.0, 0.0, 1.0);
	} else if (a.x >= a.z) {
		uv = wpos.zy; t = vec3(0.0, 0.0, 1.0); b = vec3(0.0, 1.0, 0.0);
	} else {
		uv = wpos.xy; t = vec3(1.0, 0.0, 0.0); b = vec3(0.0, 1.0, 0.0);
	}
	// Metres per pixel here: detail finer than a couple of pixels fades out.
	float px = length(fwidth(uv));
	float grain_fade = 1.0 - smoothstep(0.1, 0.5, px * grain_scale);
	float bump_fade = 1.0 - smoothstep(0.1, 0.5, px * bump_scale);

	vec3 col = albedo;
	float rough = roughness;
	// Soft patches, and drifts of dust.
	float m = fbm(uv * mottle_scale + vec2(5.2, 1.3));
	col *= 1.0 + mottle * 2.0 * (m - 0.5);
	if (dust > 0.0) {
		float d = smoothstep(0.35, 0.75, fbm(uv * mottle_scale * 0.4 + vec2(-3.7, 8.1)));
		col = mix(col, dust_colour, d * dust);
	}
	if (slab > 0.0) {
		col *= 1.0 + slab_tint * 2.0 * (hash12(floor(uv / slab) + 0.5) - 0.5);
	}
	// Aggregate: a few lighter and darker specks.
	float g = vnoise(uv * grain_scale);
	float specks = (step(0.86, g) - step(g, 0.12)) * grain * grain_fade;
	col *= 1.0 + specks;
	// Dirty and damp patches: darker, a touch shinier.
	float s = smoothstep(0.5, 0.8, fbm(uv * stain_scale + vec2(3.1, -7.4)));
	col *= 1.0 - stains * 0.4 * s;
	rough -= stains * 0.12 * s;
	// Traffic scuffs: streaks both ways, polished in places, dulled in others.
	if (scuffs > 0.0) {
		float sx = vnoise(vec2(uv.x * 0.7, uv.y * 14.0));
		float sz = vnoise(vec2(uv.x * 14.0, uv.y * 0.7));
		float sc = (max(sx, sz) - 0.5) * 2.0 * scuffs * grain_fade;
		rough += sc * 0.25;
		col *= 1.0 + sc * 0.06;
	}
	// Oil stains on upward faces: one chance per cell, dark and glossy in the middle with a
	// dried, browner ring.
	if (oil > 0.0 && n.y > 0.7) {
		float cell = oil_size * 4.0;
		vec2 c = floor(uv / cell);
		if (hash12(c + 7.31) < oil) {
			vec2 centre = (c + 0.25 + 0.5 * hash22(c)) * cell;
			float r = oil_size * (0.35 + 0.65 * hash12(c + 2.17));
			float d = length(uv - centre) / r + (fbm(uv * 2.5 / oil_size) - 0.5) * 0.6;
			float spot = 1.0 - smoothstep(0.55, 1.0, d);
			float core = 1.0 - smoothstep(0.1, 0.7, d);
			col = mix(col, mix(col * 0.55, oil_colour, core), spot * 0.85);
			rough = mix(rough, 0.5, core * 0.8);
		}
	}
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	// Relief: the height's slope tips the normal (finite differences on the plane).
	if (bump > 0.0 && bump_fade > 0.0) {
		float e = 0.15 / bump_scale;
		float h0 = height(uv);
		vec2 grad = vec2(height(uv + vec2(e, 0.0)) - h0, height(uv + vec2(0.0, e)) - h0) / e;
		vec3 bent = normalize(n - (bump * bump_fade / bump_scale) * (grad.x * t + grad.y * b));
		NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	}
}
