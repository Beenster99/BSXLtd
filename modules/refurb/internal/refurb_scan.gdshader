// The inspection's scan line, drawn as a pass over a part's own surface (RefurbScan): a bright
// line where the sweep plane cuts the part, a soft halo round it, and faint contour bands on the
// side it has already passed, fading behind it. Our own shader; presentation only.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 sweep = vec4(1.0, 0.0, 0.0, 0.0); // the plane: normal (xyz, world) and offset (w)
uniform float dir = 1.0;                        // the way it is going along the normal
uniform float glow = 0.0;                       // 0 off .. 1
uniform vec3 colour : source_color = vec3(0.35, 0.78, 1.0);

varying vec3 wp;

void vertex() {
	VERTEX += NORMAL * 0.003;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float side = dot(wp, sweep.xyz) - sweep.w;
	float d = abs(side);
	float line = 1.0 - smoothstep(0.008, 0.035, d);
	float halo = 1.0 - smoothstep(0.0, 0.2, d);
	// Behind the line: contour bands, as if the scan had read the part's shape.
	float behind = side * dir < 0.0 ? exp(-d / 0.45) : 0.0;
	float band_d = 0.5 - abs(fract(wp.y * 7.0) - 0.5);
	float band = 1.0 - smoothstep(0.0, max(fwidth(wp.y * 7.0) * 1.2, 0.02), band_d);
	float s = (line * 2.2 + halo * 0.35 + behind * band * 0.4 + behind * 0.03) * glow;
	ALBEDO = colour * s;
	ALPHA = clamp(s, 0.0, 1.0);
}
