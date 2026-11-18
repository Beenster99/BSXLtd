class_name YardRiveter
extends YardFastener
## The riveter (0.4.0 playtest; 0.4.1: "build up pressure with a little hiss and then punch a
## rivet into the plate with a powerful noise"). Held on a chalked rivet it charges its air, the
## hiss rising, then punches the hot rivet home in one blow: a bang, a kick back into your hands, a
## burst of sparks and scale, the new head glowing orange as it cools.
##
## Look: a BSX orange pistol-grip air hammer, a finned barrel, a steel rivet set on its nose (on
## the telescoping boom), an air hose out of the grip's foot and a rivet magazine on its side. It
## wears the socket's fitted hand (the same pistol grip).

## Seconds to build the pressure for one punch (on harder metal, longer).
@export var charge_seconds: float = 0.9
## The kick back into you as it punches (N s).
@export var kick: float = 14.0
## The air pressure built up (0..1); at 1 it punches. Punches so far (tests).
var pressure: float = 0.0
var punches: int = 0


func _init() -> void:
	super._init()
	tool_name = "RIVETER"
	tool_id = "riveter"
	fasten_kind = ConnectionData.Kind.RIVET
	set_rate = 0.5
	reach = 3.0
	push_force = 30.0
	bite_point = Vector3(0.0, 0.0, -0.2)
	grip = Vector3(0.0, -0.1, 0.045)
	boom = 0.5
	boom_kind = BoomKind.TELESCOPE
	heat_rate = 1.0
	spark_color = Color(1.0, 0.6, 0.2)
	light_color = Color(1.0, 0.55, 0.2)
	light_strength = 0.6
	spark_amount = 0.6


func _ready() -> void:
	name = "YardRiveter"
	var body := metal(Color(0.9, 0.45, 0.1), 0.3, 0.4)
	var steel := metal(Color(0.7, 0.71, 0.73), 0.95, 0.25)
	box(Vector3(0.05, 0.11, 0.05), Vector3(0.0, -0.1, 0.045), body, Vector3(0.25, 0.0, 0.0))
	cylinder(0.034, 0.16, Vector3(0.0, 0.0, 0.0), Vector3(deg_to_rad(90.0), 0.0, 0.0), body, 20)
	begin_head(Vector3(0.0, 0.0, -0.08))
	cylinder(0.012, 0.12, Vector3(0.0, 0.0, -0.14), Vector3(deg_to_rad(90.0), 0.0, 0.0), steel, 12)
	end_head()
	readout(Vector3(0.0, 0.05, 0.04), Vector2(0.09, 0.04))
	add_voice("riveter")


func readout_text() -> String:
	if fastening:
		return "PRESSURE\n%.1f BAR" % (pressure * 8.0)
	return "RIVETS READY\nAIR 6 BAR"


## The model, as YardToolArt reads it (key "tool"; the hand is the socket's).
static func model() -> Dictionary:
	var m := YardToolMesh.new()
	m.pistol("tool", Vector3(0, -0.1, 0.045), Vector2(0.0225, 0.03), 0.25, "bsx")
	m.trigger("tool", Vector3(0, -0.05, 0.005))
	# The body: an orange air-hammer case, a dark rear cap with the exhaust, cooling fins.
	m.rod("tool", "bsx", Vector3(0, 0, 0.1), Vector3(0, 0, -0.06), 0.036, 0.034, 36)
	m.rod("tool", "dark", Vector3(0, 0, 0.125), Vector3(0, 0, 0.098), 0.03, 0.037, 36)
	for i in 5:
		var z := -0.052 + i * 0.016
		m.ring("tool", "gunmetal", Vector3(0, 0, z), 0.037, 0.003)
	m.ring("tool", "steel", Vector3(0, 0, 0.099), 0.037, 0.0025)
	# The barrel and its retaining spring, the rivet set on the nose.
	m.rod("tool", "gunmetal", Vector3(0, 0, -0.06), Vector3(0, 0, -0.12), 0.022, 0.02, 28)
	for i in 6:
		m.ring("tool", "steel", Vector3(0, 0, -0.07 - i * 0.008), 0.023, 0.0016, Vector3.BACK, 24, 6)
	m.rod("tool", "steel", Vector3(0, 0, -0.12), Vector3(0, 0, -0.19), 0.011, 0.009, 20)
	m.rod("tool", "steel", Vector3(0, 0, -0.19), Vector3(0, 0, -0.2), 0.013, 0.012, 20)
	# The rivet magazine on its left, the air hose from the grip's foot.
	m.box("tool", "dark", Vector3(-0.045, 0.0, -0.02), Vector3(0.018, 0.05, 0.09), 0.004)
	m.box("tool", "bsx", Vector3(-0.055, 0.0, -0.02), Vector3(0.003, 0.03, 0.07), 0.001)
	m.rod("tool", "rubber", Vector3(0, -0.165, 0.07), Vector3(0, -0.2, 0.13), 0.009, -1.0, 12)
	m.display("tool", Vector3(0, 0.038, 0.05), Vector2(0.036, 0.02))
	return m.meshes()
