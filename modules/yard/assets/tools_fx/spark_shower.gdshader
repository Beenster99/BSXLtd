shader_type spatial;
// The shower (SparkSpray.shower): hot sparks by the hundred, moved here on the GPU, not on
// the CPU. Each MultiMesh instance is one straight stretch of a spark's flight, written once
// when it is thrown (bounces and bursts are worked out then, as more stretches starting
// later), and its transform is not a transform but the stretch's numbers:
//   origin = where it starts (world), x = its velocity (m/s),
//   y = (t0: clock when it starts, end: seconds it flies before it stops (a hit, a burst),
//        heat0: the spark's age when this stretch starts),
//   z = (life: the spark's whole glow in seconds, size, the hot colour packed 8 bits a channel);
//   a negative size keeps its hue as it cools (a dim shade of its own colour: the plasma's
//   blue), not a metal spark's dull red.
// The quad is drawn as a ribbon from where the spark was `streak_seconds` ago to where it is
// now, turned to face the camera, never thinner than about a pixel (dimmed to match), cooling
// white-hot -> its own colour -> dull red as it ages. Self-lit, added on top of what is behind.
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never, skip_vertex_transform, fog_disabled;

uniform float now = 0.0;
// Seconds of flight a streak shows (the long-exposure look).
uniform float streak_seconds = 0.045;
// Ribbon width, metres (x the spark's size).
uniform float width = 0.0055;
// Narrowest a ribbon is drawn, pixels.
uniform float min_pixels = 1.3;
uniform float energy = 3.2;

varying vec3 tint;
varying vec2 rib;   // x across -1..1, y along 0 (tail) .. 1 (head)

void vertex() {
	mat4 m = MODEL_MATRIX;
	vec3 p0 = m[3].xyz;
	vec3 vel = m[0].xyz;
	float t0 = m[1].x;
	float end = m[1].y;
	float heat0 = m[1].z;
	float life = m[2].x;
	float size = abs(m[2].y);
	bool keep_hue = m[2].y < 0.0;
	float code = m[2].z;
	float age = now - t0;
	float heat = heat0 + age;
	float head_age = min(age, end);
	float tail_age = max(age - streak_seconds, 0.0);
	rib = vec2(VERTEX.x * 2.0, VERTEX.y + 0.5);
	tint = vec3(0.0);
	if (age < 0.0 || heat >= life || tail_age >= head_age) {
		VERTEX = vec3(0.0, 0.0, 10.0);   // not flying now: behind the camera, clipped
	} else {
		vec3 head = (VIEW_MATRIX * vec4(p0 + vel * head_age, 1.0)).xyz;
		vec3 tail = (VIEW_MATRIX * vec4(p0 + vel * tail_age, 1.0)).xyz;
		vec3 along = head - tail;
		vec3 side = cross(along, head);
		side = length(side) > 1e-7 ? normalize(side) : vec3(1.0, 0.0, 0.0);
		float w = width * size;
		float pixel = max(-head.z, 0.01) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
		float drawn = max(w, pixel * min_pixels);
		VERTEX = mix(tail, head, rib.y) + side * VERTEX.x * drawn;
		float t = heat / life;
		vec3 hot = vec3(mod(code, 256.0), mod(floor(code / 256.0), 256.0), floor(code / 65536.0)) / 255.0;
		vec3 c = mix(keep_hue ? vec3(0.85, 0.93, 1.0) : vec3(1.0, 0.97, 0.88), hot, smoothstep(0.0, keep_hue ? 0.1 : 0.18, t));
		c = mix(c, keep_hue ? hot * 0.4 : vec3(1.0, 0.2, 0.03), smoothstep(0.35, 1.0, t));
		// (a kept hue a little dimmer, so the bloom doesn't wash its colour out to white)
		tint = c * energy * (keep_hue ? 0.7 : 1.0) * (1.0 - t * t) * (w / drawn);
	}
}

void fragment() {
	float across = 1.0 - abs(rib.x);
	ALBEDO = tint * across * across * mix(0.2, 1.0, rib.y * rib.y);
}
