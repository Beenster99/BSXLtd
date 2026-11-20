shader_type spatial;
// The outline round a fastening still to make in the build berth (beenster, 0.4.7: "the welds
// don't really highlight"): bright, pulsing, drawn over the blue holo.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.45, 0.05, 1.0);

void fragment() {
	float pulse = 0.65 + 0.35 * sin(TIME * 5.0);
	ALBEDO = mix(colour.rgb, vec3(1.0, 0.9, 0.6), 0.25 * pulse) * (1.2 + pulse);
	ALPHA = 0.95;
}
