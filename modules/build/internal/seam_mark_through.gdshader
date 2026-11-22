shader_type spatial;
// The fainter copy of a fastening's outline drawn through the beams and plates in front of it
// (beenster, 0.5.3: "the welds are VERY hard to find"): a weld behind a member still shows where.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.45, 0.05, 1.0);

void fragment() {
	float pulse = 0.65 + 0.35 * sin(TIME * 5.0);
	ALBEDO = mix(colour.rgb, vec3(1.0, 0.9, 0.6), 0.25 * pulse) * (1.0 + pulse);
	ALPHA = 0.3 + 0.15 * pulse;
}
