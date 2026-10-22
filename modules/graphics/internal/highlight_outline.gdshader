shader_type spatial;
// Graphics: the outline round a highlighted thing (the highlight's next pass). The mesh
// pushed out along its normals by a constant on-screen width, back faces only, so it reads
// as a line round the silhouette. The shell is also pushed away from the camera (push), so
// on thin parts (sheet panels a few mm thick) its back faces stay behind the part's front
// instead of showing through it as a pale hatched film.
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, blend_mix, fog_disabled;

uniform vec4 colour : source_color = vec4(0.62, 0.9, 1.0, 1.0);
uniform float strength = 1.0;
uniform float width = 0.0025;  // of the distance, so about the same on screen near and far
uniform float opacity = 1.0;
uniform float push = 0.015;    // of the distance, away from the camera
uniform float min_push = 0.04; // m

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(CAMERA_POSITION_WORLD - world);
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	view.xyz += n * dist * width;
	view.xyz += normalize(view.xyz) * max(min_push, dist * push);
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	ALBEDO = colour.rgb;
	ALPHA = opacity * strength;
}
