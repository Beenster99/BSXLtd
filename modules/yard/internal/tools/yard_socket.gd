class_name YardSocket
extends YardTool
## Powered socket wrench: the only tool that takes bolts out. It unscrews a bolt whole, and
## the bolt floats free, tumbling (it drifts off for a few minutes, then goes).
##
## Some bolts are seized with rust: the socket just strains on them (the motor bogs down,
## the hammer slows and a groan). Its sound is sampled (YardSocketSound), heard by everyone. Heat one with the cutter's torch first, then switch back to the socket while
## it's still hot. Does nothing to rivets, welds or loom plugs.
##
## Look: a cordless impact gun. A green motor housing with a vented cap, a pistol grip and
## a battery pack, a grey hammer case; the square anvil with a deep six-sided socket on it
## rides out on a telescoping boom; a readout (torque, what it is on).

## Share of bolts that are seized, 0..1. Which ones follows from each bolt's id, so every
## player finds the same bolts stuck.
@export var seized_chance: float = DEFAULT_SEIZED_CHANCE
## How hot (0..1, see the cutter) a seized bolt must be before the socket can turn it.
@export var loosen_heat: float = 0.5
## YardSocket spin while unscrewing, radians per second.
@export var spin_speed: float = 25.0
## Running a planned bolt home (Wave 5's hand building): how long one takes (s), and how close to
## its spot the aim must land (m).
@export var bolt_seconds: float = 1.4
@export var plan_snap: float = 0.12

## True while the socket is on a seized bolt it can't turn (set by ToolController).
var straining := false
## (TW11) True while that is a flange bolt whose ring is too cold (set by ToolController).
var cold_flange := false
## The impact gun's sound on the head, heard by everyone (fed by ToolController).
var voice: YardSocketSound

var _head: MeshInstance3D
var _spin: float = 0.0


## The seized chance as shipped (the survey and the glass count seized bolts with it).
const DEFAULT_SEIZED_CHANCE: float = ConnectionData.SEIZED_CHANCE


func _init() -> void:
	tool_name = "SOCKET"
	tool_id = "socket"
	rivet_rate = 0.0
	bolt_rate = 40.0    # an 80-point bolt takes 2 s
	weld_rate = 0.0
	connector_rate = 0.0
	reach = 3.0
	push_force = 15.0
	bite_point = Vector3(0.0, 0.0, -0.165)   # just inside the socket's mouth, over the bolt head
	grip = Vector3(0.0, -0.1, 0.045)
	boom = 0.5
	boom_kind = BoomKind.TELESCOPE
	heat_rate = 0.0
	sparks = false
	spark_color = Color(0.7, 0.7, 0.7)
	light_color = Color(0.7, 0.7, 0.7)


func _ready() -> void:
	name = "YardSocket"
	var green := metal(Color(0.15, 0.45, 0.2), 0.3, 0.55)
	var dark := metal(Color(0.13, 0.13, 0.15), 0.4, 0.6)
	var steel := metal(Color(0.72, 0.73, 0.75), 0.95, 0.25)
	var grey := metal(Color(0.38, 0.39, 0.41), 0.8, 0.4)
	var yellow := metal(Color(0.9, 0.75, 0.1), 0.2, 0.5)
	var along := Vector3(deg_to_rad(90.0), 0.0, 0.0)
	# A cordless impact gun: the motor housing with a vented black cap, the pistol grip,
	# the battery pack under it with its yellow latch, a trigger and a direction switch.
	cylinder(0.046, 0.12, Vector3(0.0, 0.0, 0.03), along, green, 20)
	cylinder(0.044, 0.03, Vector3(0.0, 0.0, 0.1), along, dark, 20, 0.036)
	for i in 3:
		box(Vector3(0.094, 0.008, 0.01), Vector3(0.0, 0.012 - 0.012 * float(i), 0.1), green)
	box(Vector3(0.042, 0.13, 0.058), Vector3(0.0, -0.1, 0.045), dark, Vector3(0.25, 0.0, 0.0))
	box(Vector3(0.046, 0.06, 0.02), Vector3(0.0, -0.085, 0.07), green, Vector3(0.25, 0.0, 0.0))
	box(Vector3(0.09, 0.055, 0.12), Vector3(0.0, -0.19, 0.07), dark)
	box(Vector3(0.092, 0.012, 0.03), Vector3(0.0, -0.16, 0.02), yellow)
	box(Vector3(0.018, 0.035, 0.022), Vector3(0.0, -0.06, -0.005), dark)   # trigger
	box(Vector3(0.07, 0.012, 0.012), Vector3(0.0, -0.04, 0.015), grey)     # forward/reverse
	# The hammer case narrowing to the front.
	cylinder(0.04, 0.06, Vector3(0.0, 0.0, -0.06), along, grey, 20, 0.03)
	# On the boom: the square anvil and the deep socket on it (it turns while unscrewing).
	begin_head(Vector3(0.0, 0.0, -0.09))
	box(Vector3(0.016, 0.016, 0.03), Vector3(0.0, 0.0, -0.1), steel)
	_head = cylinder(0.026, 0.07, Vector3(0.0, 0.0, -0.14), along, steel, 6)
	var bore := MeshInstance3D.new()
	var bore_mesh := CylinderMesh.new()
	bore_mesh.top_radius = 0.016
	bore_mesh.bottom_radius = 0.016
	bore_mesh.height = 0.072
	bore_mesh.radial_segments = 6
	bore.mesh = bore_mesh
	bore.material_override = dark
	_head.add_child(bore)
	end_head()
	voice = YardSocketSound.new()
	head.add_child(voice)
	readout(Vector3(0.0, 0.06, 0.04), Vector2(0.1, 0.045), Color(0.6, 1.0, 0.5))
	add_voice("socket")


func _process(delta: float) -> void:
	var target := spin_speed if working and in_contact and not straining else 0.0
	_spin = move_toward(_spin, target, delta * 80.0)
	var jitter := randf_range(-0.04, 0.04) if straining and working else 0.0
	_head.rotate_object_local(Vector3.UP, _spin * delta + jitter)


func readout_text() -> String:
	if straining and working:
		return "TORQUE MAX\nCOLD FLANGE" if cold_flange else "TORQUE MAX\nSEIZED!"
	var torque := int(_spin / spin_speed * 180.0)
	return "TORQUE %3d Nm\n%s" % [torque, "TURNING" if _spin > 1.0 else "READY"]
