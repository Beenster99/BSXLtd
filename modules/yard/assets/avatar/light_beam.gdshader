shader_type spatial;
// A faint cone of light from a helmet lamp, seen by other players. Additive and unlit. The
// mesh (PlayerModel._beam_mesh) carries its brightness along the beam in vertex alpha:
// brightest at the lamp, nothing well before the open end. Edge-on parts fade too, so it
// reads as a soft volume rather than a tube. It stops at the first wall down each edge
// (PlayerModel._probe_beam: `reach`, m along the beam, round from +X toward +Y), so it never
// stands out through a hull: a vertex past it is drawn back onto it, faded out over `cut_fade`.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 beam_color : source_color = vec3(1.0, 0.94, 0.84);
uniform float strength = 0.18;
uniform float reach[8];
uniform float cut_fade = 0.4;
varying float cut;

void vertex() {
	float a = atan(VERTEX.y, VERTEX.x) / 6.28318530718 * 8.0;
	a = a < 0.0 ? a + 8.0 : a;
	int i = int(floor(a)) % 8;
	float stop = mix(reach[i], reach[(i + 1) % 8], fract(a));
	float d = -VERTEX.z;
	cut = clamp((stop - d) / cut_fade, 0.0, 1.0);
	if (d > stop) {
		VERTEX *= max(stop, 0.0) / d;
	}
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(0.0, 0.7, facing);
	ALBEDO = beam_color * strength * edge * clamp(COLOR.a, 0.0, 1.0) * cut;
}
