shader_type spatial;
// Graphics: the outline round a highlighted thing (the highlight's next pass). The mesh
// pushed out along its normals by a constant on-screen width, back faces only, so it reads
// as a line round the silhouette.
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

uniform vec4 colour : source_color = vec4(0.62, 0.9, 1.0, 1.0);
uniform float strength = 1.0;
uniform float width = 0.0025;  // of the distance, so about the same on screen near and far

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(CAMERA_POSITION_WORLD - world);
	VERTEX += NORMAL * dist * width;
}

void fragment() {
	ALBEDO = colour.rgb * strength;
}
