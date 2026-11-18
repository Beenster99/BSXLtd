class_name YardWelder
extends YardFastener
## The welder (0.4.0 playtest): a MIG welding gun. On a planned weld it runs the bead along the
## chalked line in about three seconds (move with it: the head follows the line out on its hose).
## The arc flickers blue-white and lights the room, spatter sparks fly everywhere and molten
## droplets spit off and stick; the bead glows and cools. No helmet: the suit's visor takes it.
##
## Look: a swan-necked MIG gun: a rubber handle with the trigger, the copper neck curving down
## to a nozzle on its hose, the wire feed's cable out of the back. It wears the cutter's fitted
## hand (the same slim handle).

## How fast the arc flickers (Hz) and how bright its light is.
@export var arc_hz: float = 30.0
@export var arc_energy: float = 0.7

var _arc: MeshInstance3D
var _arc_mat: StandardMaterial3D
var _arc_light: OmniLight3D


func _init() -> void:
	super._init()
	tool_name = "WELDER"
	tool_id = "welder"
	fasten_kind = ConnectionData.Kind.WELD
	set_rate = 0.34
	reach = 3.0
	push_force = 8.0
	bite_point = Vector3(0.0, -0.06, -0.26)
	grip = Vector3(0.0, -0.075, 0.035)
	boom = 0.5
	boom_kind = BoomKind.HOSE
	heat_rate = 2.0
	spark_color = Color(1.0, 0.85, 0.5)
	light_color = Color(0.75, 0.85, 1.0)
	light_strength = 0.9


func _ready() -> void:
	name = "YardWelder"
	var rubber := metal(Color(0.08, 0.08, 0.09), 0.05, 0.9)
	var copper := metal(Color(0.75, 0.42, 0.25), 0.95, 0.3)
	cylinder(0.022, 0.16, Vector3.ZERO, Vector3(deg_to_rad(90.0), 0.0, 0.0), rubber, 16)
	box(Vector3(0.04, 0.1, 0.045), Vector3(0.0, -0.075, 0.035), rubber, Vector3(0.3, 0.0, 0.0))
	begin_head(Vector3(0.0, 0.0, -0.1))
	rod(Vector3(0.0, 0.0, -0.1), Vector3(0.0, -0.06, -0.24), 0.012, copper, 10)
	# The arc: a small hot star at the wire's tip, only while welding.
	_arc = MeshInstance3D.new()
	var am := SphereMesh.new()
	am.radius = 0.012
	am.height = 0.024
	_arc.mesh = am
	_arc_mat = StandardMaterial3D.new()
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.albedo_color = Color(0.85, 0.92, 1.0)
	_arc.material_override = _arc_mat
	_arc.position = bite_point
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc.visible = false
	_arc.set_meta(YardToolArt.LIVE, true)
	attach(_arc)
	_arc_light = OmniLight3D.new()
	_arc_light.light_color = Color(0.7, 0.82, 1.0)
	_arc_light.light_energy = 0.0
	_arc_light.omni_range = 4.0
	_arc_light.position = bite_point + Vector3(0, 0.15, 0.35)
	attach(_arc_light)
	end_head()
	readout(Vector3(0.0, 0.045, 0.04), Vector2(0.09, 0.04))
	add_voice("welder")


func _process(_delta: float) -> void:
	var on := fastening and visible
	_arc.visible = on
	if on:
		var f := randf_range(0.55, 1.0)
		_arc.scale = Vector3.ONE * randf_range(0.7, 1.4)
		_arc_light.light_energy = arc_energy * f
	else:
		_arc_light.light_energy = 0.0


func readout_text() -> String:
	if fastening:
		return "ARC 140 A\n%d%%" % int(progress * 100.0)
	return "WIRE 0.8 mm\nGAS OK"


## The model, as YardToolArt reads it (key "tool"; the hand is the cutter's).
static func model() -> Dictionary:
	var m := YardToolMesh.new()
	m.pistol("tool", Vector3(0, -0.075, 0.035), Vector2(0.02, 0.024), 0.3, "bsx")
	m.trigger("tool", Vector3(0, -0.032, 0.0))
	# The handle body: rubber over a BSX orange collar, the wire feed's cable out of the back.
	m.rod("tool", "rubber", Vector3(0, 0, 0.09), Vector3(0, 0, -0.06), 0.022, 0.024, 28)
	m.rod("tool", "bsx", Vector3(0, 0, -0.06), Vector3(0, 0, -0.085), 0.026, 0.024, 28)
	m.ring("tool", "steel", Vector3(0, 0, -0.085), 0.024, 0.002)
	m.rod("tool", "rubber", Vector3(0, 0, 0.09), Vector3(0, -0.02, 0.17), 0.012, 0.012, 14)
	# The swan neck: copper bending down to the nozzle, the contact tip in its mouth.
	var neck: Array[Vector3] = [Vector3(0, 0, -0.085), Vector3(0, -0.006, -0.14), Vector3(0, -0.025, -0.19), Vector3(0, -0.05, -0.225)]
	for i in neck.size() - 1:
		m.rod("tool", "copper", neck[i], neck[i + 1], 0.009, 0.009, 16)
	m.rod("tool", "steel", Vector3(0, -0.05, -0.225), Vector3(0, -0.062, -0.255), 0.016, 0.012, 24)
	m.rod("tool", "brass", Vector3(0, -0.062, -0.255), Vector3(0, -0.064, -0.262), 0.004, 0.003, 10)
	m.display("tool", Vector3(0, 0.024, 0.04), Vector2(0.03, 0.018))
	return m.meshes()
