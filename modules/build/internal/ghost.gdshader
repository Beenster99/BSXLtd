shader_type spatial;
// The ghost ship (master plan 5.2): the whole design as a faint holo in the berth, brighter at
// its edges. `next` makes the pieces to fit next glow and pulse.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform float strength = 0.06;
uniform float rim = 0.22;
uniform float next = 0.0;
uniform vec4 next_tint : source_color = vec4(1.0, 0.72, 0.25, 1.0);

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(1.0 - facing, 2.5);
	// Faint scan lines up the ship, as the design room's holo has.
	float line = 0.5 + 0.5 * sin((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y * 18.0);
	vec3 base = tint.rgb * (strength + rim * edge) * (0.8 + 0.2 * line);
	float pulse = 0.55 + 0.45 * sin(TIME * 3.2);
	vec3 glow = next_tint.rgb * (0.22 + 0.5 * edge) * pulse;
	ALBEDO = mix(base, glow, next);
}
