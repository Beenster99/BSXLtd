shader_type spatial;
// G6, a ship's screen: the page its viewport draws, lit from within. Fine scanlines and a
// pixel grid up close (faded with distance so they never shimmer), a soft edge falloff, a
// little bloom-like lift of the bright text, and a short flicker as it powers up.
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D page : source_color, filter_linear;
uniform float brightness = 1.6;
uniform float power = 1.0;          // 0 off .. 1 on (the power-up ramps it)
uniform float rows = 300.0;         // scanlines across the screen's height
uniform vec2 grid = vec2(480.0, 300.0);

void fragment() {
	vec2 uv = UV;
	vec3 c = texture(page, uv).rgb;
	// A soft halo: the page blurred a touch and added back, so text glows.
	vec2 o = vec2(0.004, 0.006);
	vec3 halo = (texture(page, uv + vec2(o.x, 0.0)).rgb + texture(page, uv - vec2(o.x, 0.0)).rgb
			+ texture(page, uv + vec2(0.0, o.y)).rgb + texture(page, uv - vec2(0.0, o.y)).rgb) * 0.25;
	c += halo * 0.35;
	// Scanlines and the pixel grid, only where a pixel row is bigger than a screen pixel.
	float fine = 1.0 - smoothstep(0.5, 1.5, fwidth(uv.y * rows));
	float scan = 0.88 + 0.12 * sin(uv.y * rows * 6.2832);
	float cell = 0.92 + 0.08 * sin(uv.x * grid.x * 6.2832);
	c *= mix(1.0, scan * cell, fine);
	// Darker towards the corners, like a backlit panel.
	vec2 d = uv - 0.5;
	c *= 1.0 - 0.35 * dot(d, d) * 2.0;
	ALBEDO = c * brightness * power;
}
