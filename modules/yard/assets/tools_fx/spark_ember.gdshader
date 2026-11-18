shader_type spatial;
// Embers (SparkSpray._ember): sparks that stuck where they landed, glowing on and fading.
// Each MultiMesh instance is one ember, written once, in the frame of the body it landed on
// (`frame`: the body's transform, set each frame; the node itself stays at the origin); its
// transform is not a transform but the ember's numbers:
//   origin = where it sits, x = the surface's normal there,
//   y = (t0: clock when it lands, life: seconds it glows, size: metres across),
//   z = (its colour packed 8 bits a channel, a seed 0..1, unused).
// Drawn as a soft dot facing the camera, never smaller than about a pixel: hidden till it
// lands, a white flare as it hits, then its own colour at a steady dim glow that twinkles a
// little and fades out over the last part of its life. Self-lit, added on top.
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never, skip_vertex_transform, fog_disabled;

uniform float now = 0.0;
uniform mat4 frame = mat4(1.0);
uniform float energy = 2.4;
// Seconds the landing flare takes to die down, and the glow it settles to (share of the flare).
uniform float flare_seconds = 0.3;
uniform float rest = 0.55;
// Share of its life it glows steady before it starts to fade.
uniform float fade_from = 0.6;
// Narrowest a dot is drawn, pixels, and how far it is drawn toward the camera, metres (so a
// dot on a surface isn't cut by it).
uniform float min_pixels = 1.6;
uniform float pull = 0.012;

varying vec3 tint;
varying vec2 dot_uv;

void vertex() {
	mat4 m = MODEL_MATRIX;
	float t0 = m[1].x;
	float life = m[1].y;
	float size = m[1].z;
	float code = m[2].x;
	float seed = m[2].y;
	float age = now - t0;
	dot_uv = VERTEX.xy * 2.0;
	tint = vec3(0.0);
	if (age < 0.0 || age >= life) {
		VERTEX = vec3(0.0, 0.0, 10.0);   // not glowing now: behind the camera, clipped
	} else {
		vec3 at = (frame * vec4(m[3].xyz, 1.0)).xyz;
		vec3 c = (VIEW_MATRIX * vec4(at, 1.0)).xyz;
		c += normalize(-c) * pull;
		float t = age / life;
		float pixel = max(-c.z, 0.01) * 2.0 / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
		float w = size * mix(1.0, 0.55, t);
		float drawn = max(w, pixel * min_pixels);
		VERTEX = c + vec3(VERTEX.xy * drawn, 0.0);
		vec3 hot = vec3(mod(code, 256.0), mod(floor(code / 256.0), 256.0), floor(code / 65536.0)) / 255.0;
		float flare = exp(-age / flare_seconds);
		vec3 col = mix(hot, vec3(0.95, 0.97, 1.0), flare);
		col = mix(col, hot * 0.7, smoothstep(0.1, 0.9, t));
		float glow = mix(rest, 1.0, flare) * (1.0 - smoothstep(fade_from, 1.0, t));
		glow *= 0.82 + 0.18 * sin(now * (5.0 + seed * 9.0) + seed * 40.0);
		tint = col * energy * glow * (w / drawn);
	}
}

void fragment() {
	float r = 1.0 - clamp(length(dot_uv), 0.0, 1.0);
	ALBEDO = tint * r * r;
}
