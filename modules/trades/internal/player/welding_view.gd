class_name TradesWeldingView
extends ColorRect
## Looking out through the welding shield in first person (beenster, 0.3.7): as it flicks down
## a dark shell sweeps over the view from the top, leaving a letterbox of green glass. The work
## shows dimly through it and the arc, the hot metal and the sparks bright, so you can see where
## the seam starts and ends and watch the bead or the cut. Presentation only.

## How far down the shield is (0 up and out of view, 1 over the eyes).
var down := 0.0:
	set(value):
		down = clampf(value, 0.0, 1.0)
		visible = down > 0.001
		(material as ShaderMaterial).set_shader_parameter("down", down)

const SHADER := """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float down = 0.0;
// The window, as shares of the screen: half its width and half its height.
uniform vec2 half_size = vec2(0.32, 0.15);
void fragment() {
	vec2 uv = SCREEN_UV;
	// The shield covers y < down, sliding in from the top; its own y runs 0..1 over it.
	float sy = uv.y - (down - 1.0);
	if (uv.y > down) {
		discard;
	}
	vec2 d = abs(vec2(uv.x, sy) - vec2(0.5, 0.5)) - half_size;
	float corner = length(max(d + 0.012, 0.0)) - 0.012;
	float inside = 1.0 - smoothstep(-0.002, 0.002, max(max(d.x, d.y), corner));
	vec3 c = texture(screen, uv).rgb;
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	// Shade 9 glass (beenster, 2026-10-22: too dark to see where to start and finish): the
	// work shows dimly in green, so you can follow the seam, and the arc, hot metal and sparks
	// stand out bright.
	float hot = max(lum - 0.84, 0.0) / 0.16;
	vec3 glass = vec3(0.32, 1.0, 0.4) * (sqrt(lum) * 0.26 + hot * hot * 0.9);
	float shade = 0.5 + 0.5 * smoothstep(0.0, 0.5, abs(uv.x - 0.5));
	vec3 shell = vec3(0.018, 0.02, 0.019) * (1.2 - shade * 0.6);
	COLOR = vec4(mix(shell, glass, inside), 1.0);
}
"""


func _init() -> void:
	name = "WeldingView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	material = mat
	visible = false
