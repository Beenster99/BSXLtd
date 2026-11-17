shader_type spatial;
// The heat round a marked weld (LK3, ConnectionData.heat_marked, JointView.lay_halo): the
// colours heated titanium and steel take either side of a bead, blue-grey at the bead through
// purple and bronze to a thin straw edge, ragged, on a flat quad laid on the part's surface.
// Drawn in batches with the joint heads (JointBatch). Per instance (INSTANCE_CUSTOM): x, y the
// bead's outline half sizes along and across (m), z how far the colours reach past it (m),
// w the outline: 0 a seam (a line along x), 1 a closed loop (a rectangle), 2 a spot (a disc).
// The quad is 2 x 2 in its mesh, scaled per instance to the outline plus the reach.

render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;

// Past this the halo fades out (m): a few centimetres of colour are lost in the pixels, and
// the quad lying a millimetre off the plate would start to fight it.
uniform float fade_from = 14.0;
uniform float fade_to = 22.0;

varying vec2 pos;      // m, on the surface about the bead's middle
varying vec4 outline;
varying vec3 world_pos;

void vertex() {
	outline = INSTANCE_CUSTOM;
	pos = VERTEX.xz * (outline.xy + vec2(outline.z));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Temper colours, cool to hot: the bare metal, straw, bronze, purple, blue, a grey oxide.
vec3 temper(float t) {
	vec3 c = vec3(0.6, 0.6, 0.62);
	c = mix(c, vec3(0.85, 0.72, 0.42), smoothstep(0.1, 0.3, t));
	c = mix(c, vec3(0.62, 0.38, 0.2), smoothstep(0.3, 0.45, t));
	c = mix(c, vec3(0.42, 0.2, 0.45), smoothstep(0.45, 0.6, t));
	c = mix(c, vec3(0.2, 0.3, 0.7), smoothstep(0.6, 0.75, t));
	c = mix(c, vec3(0.45, 0.5, 0.55), smoothstep(0.85, 1.0, t));
	return c;
}

void fragment() {
	vec2 half_size = outline.xy;
	float reach = max(outline.z, 0.001);
	float d;
	if (outline.w > 1.5) {
		d = length(pos) - half_size.x;
	} else if (outline.w > 0.5) {
		vec2 q = abs(pos) - half_size;
		d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
		d = abs(d);
	} else {
		d = length(vec2(max(abs(pos.x) - half_size.x, 0.0), pos.y));
	}
	// Ragged: the heat spreads further where the weld ran slower.
	float rag = noise(pos * 90.0 + world_pos.xz * 3.0) * 0.5 + noise(pos * 23.0) * 0.5;
	float t = 1.0 - (max(d, 0.0) / reach) * (0.75 + 0.5 * rag);
	float far = length(world_pos - CAMERA_POSITION_WORLD);
	float a = smoothstep(0.0, 0.3, t) * 0.85 * (1.0 - smoothstep(fade_from, fade_to, far));
	if (a < 0.01) {
		discard;
	}
	// Faint and even, not a sticker: the oxide film only tints the metal under it.
	ALBEDO = mix(vec3(0.58, 0.6, 0.64), temper(clamp(t, 0.0, 1.0)), 0.75);
	METALLIC = 0.7;
	ROUGHNESS = mix(0.3, 0.45, t);
	ALPHA = a;
}
