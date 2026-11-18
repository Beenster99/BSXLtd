shader_type spatial;
// Hot sparks and molten globs from the tools (SparkSpray): self-lit, added on top of what is
// behind them, coloured per instance. `energy` lifts them past 1 so the glow picks them up.
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

uniform float energy = 1.8;

void fragment() {
	ALBEDO = COLOR.rgb * energy * COLOR.a;
}
