class_name TradesBeamLine
extends MeshInstance3D
## The tractor beam's line (beenster, 0.3.14: "thinner, glowing, moving line which joins the
## tool to the object, more detail, more fluid"): a fine bright core with a soft glow round it
## and two strands winding round the core, pulses running down it from the tool to the part.
## Its middle lags behind when the ends move and springs back, so a quick swing bends the
## beam like a rope of light before it straightens.
##
## Drawn as camera-facing ribbons in an ImmediateMesh each frame; the shader does the glow
## and the flow. World space (top level), metres.

## Points along each ribbon.
const SEGMENTS := 40
## Ribbon widths (metres): the core, the glow round it, the winding strands.
const CORE_W := 0.007
const GLOW_W := 0.05
const STRAND_W := 0.0035
## How far the strands wind out from the core (metres), and turns per metre.
const STRAND_R := 0.016
const STRAND_TURNS := 2.2
## How stiff the middle's spring is (per second squared) and how damped (per second).
const SPRING := 90.0
const DAMP := 11.0
## The most the middle bends out, as a share of the beam's length.
const MAX_BEND := 0.22

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float strength = 1.0;
uniform float flow = 2.4;

void fragment() {
	// UV.x across the ribbon (-1..1), UV.y metres from the tool; COLOR.r how white the middle
	// burns, COLOR.g the share of the way along, COLOR.a the ribbon's strength.
	float across = 1.0 - abs(UV.x);
	float body = pow(across, 2.5);
	float pulse = pow(0.5 + 0.5 * sin(UV.y * 11.0 - TIME * flow * 11.0), 8.0);
	float ripple = 0.5 + 0.5 * sin(UV.y * 37.0 - TIME * flow * 23.0);
	float ends = smoothstep(0.0, 0.04, COLOR.g) * (0.7 + 0.3 * smoothstep(0.85, 1.0, COLOR.g));
	float a = COLOR.a * strength * body * ends * (0.5 + 1.1 * pulse + 0.25 * ripple);
	ALBEDO = mix(beam_color.rgb, vec3(1.0), body * body * COLOR.r);
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

static var _shader: Shader

var color := Color(0.35, 0.85, 1.0):
	set(value):
		color = value
		_mat.set_shader_parameter("beam_color", value)
## 0..1: how strong the whole line draws (the yard's trolley beams are fainter).
var strength := 1.0:
	set(value):
		strength = value
		_mat.set_shader_parameter("strength", value)

var _mat: ShaderMaterial
var _im := ImmediateMesh.new()
var _mid := Vector3.ZERO
var _mid_vel := Vector3.ZERO
var _fresh := true
var _bend := 0.0
var _time := 0.0


func _init() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	mesh = _im
	material_override = _mat
	top_level = true
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0


## Draws the line from `from` to `to` this frame; `delta` moves its springy middle.
func draw(from: Vector3, to: Vector3, delta: float) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		hide_line()
		return
	global_transform = Transform3D.IDENTITY
	var straight := (from + to) * 0.5
	if _fresh:
		_mid = straight
		_mid_vel = Vector3.ZERO
		_fresh = false
	elif delta > 0.0:
		_mid_vel += ((straight - _mid) * SPRING - _mid_vel * DAMP) * delta
		_mid += _mid_vel * delta
	var bend := (_mid - straight).limit_length(length * MAX_BEND)
	_mid = straight + bend
	_bend = bend.length()
	_time += delta
	# The middle of a quadratic curve through `_mid`: control = 2 * mid - the ends' middle.
	var control := straight + bend * 2.0
	var eye := _eye(from)
	_im.clear_surfaces()
	_ribbon(from, control, to, eye, GLOW_W, 0.0, 0.18, 0.0, 0.0, length)
	_ribbon(from, control, to, eye, CORE_W, 1.0, 1.0, 0.0, 0.0, length)
	for k in 2:
		_ribbon(from, control, to, eye, STRAND_W, 0.4, 0.55, STRAND_R, k * PI, length)
	visible = true


func hide_line() -> void:
	visible = false
	_fresh = true
	_bend = 0.0


## How far the line's middle sits off the straight line now (metres; tests).
func bend() -> float:
	return _bend


func _eye(fallback: Vector3) -> Vector3:
	var vp := get_viewport() if is_inside_tree() else null
	var cam := vp.get_camera_3d() if vp else null
	return cam.global_position if cam else fallback + Vector3(0, 0, 1)


static func _curve(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * (u * u) + c * (2.0 * u * t) + b * (t * t)


## One camera-facing ribbon along the curve; with `radius` it winds round the core.
func _ribbon(a: Vector3, c: Vector3, b: Vector3, eye: Vector3, width: float, white: float,
		alpha: float, radius: float, phase: float, length: float) -> void:
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var p := _curve(a, c, b, t)
		var tangent := (_curve(a, c, b, minf(t + 0.01, 1.0)) - _curve(a, c, b, maxf(t - 0.01, 0.0))).normalized()
		if radius > 0.0:
			var x := tangent.cross(Vector3.UP if absf(tangent.y) < 0.95 else Vector3.RIGHT).normalized()
			var y := tangent.cross(x)
			var turn := t * length * STRAND_TURNS * TAU - _time * 5.0 + phase
			# The strands pinch in at both ends, onto the tool's nose and the part.
			var r := radius * sin(t * PI)
			p += (x * cos(turn) + y * sin(turn)) * r
		var side := tangent.cross(eye - p).normalized() * width * 0.5
		var col := Color(white, t, 0.0, alpha)
		_im.surface_set_color(col)
		_im.surface_set_uv(Vector2(-1.0, t * length))
		_im.surface_add_vertex(p - side)
		_im.surface_set_color(col)
		_im.surface_set_uv(Vector2(1.0, t * length))
		_im.surface_add_vertex(p + side)
	_im.surface_end()
