class_name YardTractor
extends YardGrabber
## The hand tractor (stage 1.4, BSX's own tool redrawn beside the Void Salvage set): the
## grabber's hold at range. Aim at a loose piece up to `reach` away and hold the trigger: a beam
## takes it and holds it where you aim, at the distance it was caught (the wheel brings it in
## or sends it out). Softer than the grabber's claw and slower, as a field is; it lets go if
## the load is dragged too far off the beam. It never holds anything fixed in place.
##
## Its look: a BSX orange body wound with three copper field coils that light while holding,
## three emitter prongs round a lens, a battery pack on its back and a rubber pistol grip
## where the grabber's is (it wears the grabber's fitted hand).


func _init() -> void:
	super._init()
	tool_name = "TRACTOR"
	tool_id = "tractor"
	reach = 30.0
	min_hold = 2.0
	max_hold = 25.0
	wheel_step = 1.0
	break_distance = 6.0
	stiffness = 6.0
	damping = 4.5
	max_force = 900.0
	anchor_max_force = 300.0
	turn_stiffness = 4.0
	spin_damping = 3.0
	max_torque = 300.0
	planted_force = 900.0


func _ready() -> void:
	super._ready()
	name = "YardTractor"
	# The grabber's screen sits where this one's battery pack is: up on the pack's back end.
	if _readout:
		_readout.get_parent().position = Vector3(0.0, 0.112, 0.1)


func readout_text() -> String:
	if _gripping:
		return "BEAM LOCKED\n%.0f kg  %.1f m" % [held_mass, hold_range]
	return "BEAM READY\nRANGE %.0f m" % reach


## The model, as YardToolArt reads it (keys "tool" and "coil"; "hand" comes from the grabber,
## whose grip this one copies: tool_designs.py's grabber grip, centre (0, -0.1, 0.07)).
static func model() -> Dictionary:
	var m := YardToolMesh.new()
	m.pistol("tool", Vector3(0, -0.1, 0.07), Vector2(0.0225, 0.03), 0.3, "bsx")
	m.trigger("tool", Vector3(0, -0.052, 0.028))
	# The body: an orange enamel core between a rear cap and the front pole-piece.
	m.rod("tool", "bsx", Vector3(0, 0, 0.115), Vector3(0, 0, -0.125), 0.044, 0.046, 40)
	m.rod("tool", "dark", Vector3(0, 0, 0.142), Vector3(0, 0, 0.112), 0.034, 0.047, 40)
	m.ring("tool", "steel", Vector3(0, 0, 0.113), 0.047, 0.003)
	# Three field coils: copper windings in dark retaining flanges, a lit band in each.
	for z: float in [-0.085, -0.035, 0.015]:
		m.rod("tool", "copper", Vector3(0, 0, z + 0.017), Vector3(0, 0, z - 0.017), 0.053, -1.0, 40)
		m.ribs("tool", "copper", z - 0.016, z + 0.016, 0.0535, 7)
		for side: float in [-1.0, 1.0]:
			m.rod("tool", "gunmetal", Vector3(0, 0, z + side * 0.017), Vector3(0, 0, z + side * 0.021), 0.058, -1.0, 40)
		m.ring("coil", "cyan", Vector3(0, 0, z), 0.0545, 0.0022, Vector3.BACK, 40, 6)
	# Four dark armour staves along the coils, bolted at each end.
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		var out := Vector3(cos(a), sin(a), 0)
		if out.y < -0.5:
			continue
		var b := Basis.looking_at(Vector3.FORWARD, out)
		m.box("tool", "dark", out * 0.06 + Vector3(0, 0, -0.035), Vector3(0.014, 0.008, 0.15), 0.003, b)
		for z: float in [-0.1, 0.03]:
			m.bolt("tool", out * 0.064 + Vector3(0, 0, z), out, 0.003)
	# The front: a steel pole-piece flange, the emitter's ceramic collar and the lens.
	m.rod("tool", "steel", Vector3(0, 0, -0.125), Vector3(0, 0, -0.15), 0.062, 0.058, 40)
	m.ring("tool", "dark", Vector3(0, 0, -0.137), 0.0615, 0.0025)
	m.rod("tool", "ceramic", Vector3(0, 0, -0.15), Vector3(0, 0, -0.172), 0.036, 0.032, 32)
	m.ring("tool", "steel", Vector3(0, 0, -0.172), 0.031, 0.003)
	m.rod("coil", "cyan", Vector3(0, 0, -0.172), Vector3(0, 0, -0.178), 0.026, 0.024, 32)
	# Three emitter prongs round the lens, each a steel arm with a ceramic insulator and a lit tip.
	for i in 3:
		var a := TAU * i / 3.0 + PI * 0.5
		var out := Vector3(cos(a), sin(a), 0)
		var root := out * 0.05 + Vector3(0, 0, -0.145)
		var knee := out * 0.064 + Vector3(0, 0, -0.2)
		var tip := out * 0.046 + Vector3(0, 0, -0.255)
		m.rod("tool", "steel", root, knee, 0.0075, 0.0065, 12)
		m.rod("tool", "steel", knee, tip, 0.0065, 0.005, 12)
		m.rod("tool", "ceramic", knee + (tip - knee) * 0.25, knee + (tip - knee) * 0.55, 0.0095, -1.0, 16)
		m.rod("coil", "cyan", tip, tip + (tip - knee).normalized() * 0.008, 0.005, 0.003, 12)
		m.bolt("tool", root + Vector3(0, 0, 0.008), out, 0.004)
	# The battery pack on its back, its charge lights facing the eye.
	m.box("tool", "dark", Vector3(0, 0.068, 0.07), Vector3(0.07, 0.042, 0.11), 0.006)
	m.box("tool", "bsx", Vector3(0, 0.09, 0.07), Vector3(0.062, 0.004, 0.09), 0.002)
	m.box("tool", "rubber", Vector3(0, 0.068, 0.128), Vector3(0.074, 0.046, 0.01), 0.003)
	for x: float in [-0.03, 0.03]:
		m.box("tool", "gunmetal", Vector3(x, 0.048, 0.07), Vector3(0.012, 0.01, 0.1), 0.002)
	m.display("tool", Vector3(0, 0.094, 0.04), Vector2(0.044, 0.024))
	return m.meshes()
