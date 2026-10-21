shader_type spatial;
// Graphics: a ping's marker, a diamond that always faces you, keeps its size on screen and
// shows through walls.
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, blend_mix;

uniform vec4 colour : source_color = vec4(0.62, 0.9, 1.0, 1.0);
uniform float size = 0.035;  // of the distance
uniform float alpha = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float dist = length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	VERTEX *= dist * size;
}

void fragment() {
	vec2 p = abs(UV - 0.5) * 2.0;
	float d = p.x + p.y;                        // 1 on the diamond's edge
	float outer = 1.0 - smoothstep(0.92, 1.0, d);
	float hole = smoothstep(0.55, 0.62, d);     // a ring with a dot in it
	float dot_ = 1.0 - smoothstep(0.22, 0.3, d);
	ALBEDO = colour.rgb;
	ALPHA = (outer * hole + dot_) * alpha * colour.a;
}
