shader_type spatial;
// (From Void Salvage 6523ae5, shaders/fx_grip.gdshader.) A grip (VX21, FieldGrip): the faint shimmering shell a field (the attractor, the skip's, the
// claw's) wraps round a piece it has hold of, on a box a little bigger than the piece. Bright at the
// rim, bands crawling over it toward the intake, a fine shimmer; straining, it stutters. Additive.
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(0.45, 0.85, 1.0);
uniform float energy = 1.1;
// Bands across the shell (a metre) and how fast they crawl.
uniform float band_scale = 3.0;
uniform float crawl = 2.5;
// 0..1, eased in and out by the grip; and straining (0..1).
instance uniform float strength = 1.0;
instance uniform float strain = 0.0;
// The way to the intake (world): the bands crawl toward it.
instance uniform vec3 toward = vec3(0.0, 1.0, 0.0);

varying vec3 wpos;

float grip_hash(float n) {
	return fract(sin(n * 91.7) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.2);
	float along = dot(wpos, normalize(toward));
	float band = pow(0.5 + 0.5 * sin(along * band_scale * 6.2832 - TIME * crawl * 6.2832), 6.0);
	float shimmer = 0.5 + 0.5 * sin(dot(wpos, vec3(13.1, 17.7, 11.3)) + TIME * 9.0)
			* sin(dot(wpos, vec3(-9.7, 12.9, 15.1)) - TIME * 7.0);
	float flick = 1.0 - strain * 0.8 * step(0.5, grip_hash(floor(TIME * 26.0)));
	ALBEDO = colour * energy;
	ALPHA = clamp((rim * 0.55 + 0.04 + band * (0.06 + 0.3 * rim) + shimmer * 0.05 * rim) * strength * flick, 0.0, 1.0);
}
