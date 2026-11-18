class_name YardTablet
extends YardTool
## The beam tablet (stage 1.4, BSX's own tool redrawn on Void Salvage's scanner slate): held at
## the waist face up, a click brings it up in front of your eye (again: down). Its screen reads
## the work in front of it: the piece's front view with its parts and every joint still holding
## it, by kind (bolts amber, rivets steel, welds orange), its weight and what is left to undo.
## Later the design room's designs come to it, to build from (the plan's later waves).
##
## Its look: the Void Salvage scanner's slate and D-grip (tool_scanner.glb, Dan's model), its
## glass this tool's own live screen with a lit rim, and a BSX orange lens housing on its top edge.

## How far from the eye the screen's middle comes up to, m.
@export var slate_distance: float = 0.42
## The screen's size, m (width, height): the scanner's.
@export var slate_size := Vector2(0.338, 0.22)
## Seconds it takes to come up (and to go down).
@export var raise_time: float = 0.25
## Held down, how far it is turned face up toward the eye, degrees.
@export var rest_tilt_deg: float = 58.0
## How far it reads, m.
@export var read_reach: float = 12.0

## The screen's pixels a metre.
const DPM := 2400.0
## The glass's middle in the tool's space (the scanner's screen sits at its origin).
const SCREEN := Vector3(0.0, 0.0, 0.004)

## 0 down at the waist .. 1 up in front of the eye; `up` is where it is going.
var raised: float = 0.0
var up := false
## The piece the screen reads (set by the tool controller each step), or null.
var reading: YardWorkpiece

var _rest := Transform3D()
var _viewport: SubViewport
var _screen: YardTabletScreen


func _init() -> void:
	tool_name = "TABLET"
	tool_id = "tablet"
	max_mark = 1
	rivet_rate = 0.0
	bolt_rate = 0.0
	weld_rate = 0.0
	connector_rate = 0.0
	reach = read_reach
	# The glove round the D-grip down the slate's right edge (tool_designs.py's scanner centre).
	grip = Vector3(0.245, -0.03, -0.004)
	push_force = 0.0
	heat_rate = 0.0
	sparks = false
	bite_point = SCREEN


func _ready() -> void:
	name = "YardTablet"
	var tilt := Basis(Vector3.RIGHT, -deg_to_rad(rest_tilt_deg))
	_rest = Transform3D(tilt, -(tilt * grip))
	_viewport = SubViewport.new()
	_viewport.name = "Screen"
	_viewport.size = Vector2i(roundi(slate_size.x * DPM), roundi(slate_size.y * DPM))
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	_screen = YardTabletScreen.new()
	_screen.tablet = self
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_screen)
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var quad := QuadMesh.new()
	quad.size = slate_size
	glass.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glass.material_override = mat
	glass.position = SCREEN
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.set_meta(YardToolArt.LIVE, true)
	add_child(glass)
	# The lit rim just inside the bezel.
	var rim := StandardMaterial3D.new()
	rim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.albedo_color = Color(0.4, 0.9, 1.0)
	var w := slate_size.x
	var h := slate_size.y
	for y: float in [-1.0, 1.0]:
		box(Vector3(w, 0.003, 0.003), SCREEN + Vector3(0, y * (h * 0.5 + 0.0015), 0.0), rim).set_meta(YardToolArt.LIVE, true)
	for x: float in [-1.0, 1.0]:
		box(Vector3(0.003, h, 0.003), SCREEN + Vector3(x * (w * 0.5 + 0.0015), 0, 0.0), rim).set_meta(YardToolArt.LIVE, true)


## Clicks bring it up and put it down again.
func toggle() -> void:
	up = not up


func is_up() -> bool:
	return raised >= 0.5


## The slate's pose under the hand (the hold's space): at the waist, or up in front of the eye.
func pose() -> Transform3D:
	var hold := get_parent() as Node3D
	if hold == null:
		return _rest
	var up_head := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -slate_distance) - SCREEN)
	var raised_pose := hold.transform.affine_inverse() * up_head
	var s := raised * raised * (3.0 - 2.0 * raised)
	return _rest.interpolate_with(raised_pose, s)


func _process(delta: float) -> void:
	if not visible:
		raised = 0.0
		up = false
	raised = move_toward(raised, 1.0 if up else 0.0, delta / maxf(raise_time, 0.01))
	transform = pose()
	if _screen and visible:
		_screen.queue_redraw()


func readout_text() -> String:
	return ""


## The model, as YardToolArt reads it: Void Salvage's scanner slate (its glass left out there for
## a live screen) and this tool's orange lens housing on the top edge.
static func model() -> Dictionary:
	var out: Dictionary = YardSuitAssets.meshes("tool_scanner").duplicate()
	var m := YardToolMesh.new()
	m.box("lens", "bsx", Vector3(-0.09, 0.141, 0.004), Vector3(0.09, 0.016, 0.03), 0.004)
	m.box("lens", "dark", Vector3(-0.09, 0.15, 0.004), Vector3(0.07, 0.004, 0.022), 0.0015)
	m.rod("lens", "cyan", Vector3(-0.09, 0.149, 0.004), Vector3(-0.09, 0.154, 0.004), 0.008, 0.007, 24)
	m.ring("lens", "steel", Vector3(-0.09, 0.152, 0.004), 0.009, 0.0016, Vector3.UP, 24, 6)
	for x: float in [-0.125, -0.055]:
		m.bolt("lens", Vector3(x, 0.141, 0.0195), Vector3.BACK, 0.003)
	out.merge(m.meshes(), true)
	return out
