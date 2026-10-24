extends Node3D
## The emitter frame rig (Component Upgrades U1, beenster 24 Oct): a waist-high steel test
## bench in Pre-assembly that an attractor coil is bolted onto, opened, fitted with BSX
## add-ons and field-swept. Ship and Bay builds the rig and keeps which unit is on it;
## Shared Components draws the unit, Tools works its joints, Quality runs the test.
##
##   DECK      a T-slotted steel plate on four legs and two I-beam skids, four hold-down
##             bosses where the unit's feet bolt down (ShipBayBus.rig_points)
##   GANTRY    a portal hoop riding rails either side of the deck, with the field probe hung
##             from its crown: during a test it runs the deck's length and back
##   TEST MASS a steel block on a carriage at the end of a 3 m rail off the deck's +X end:
##             during a test the coil's field draws it in along the rail and lets it go
##   CONSOLE   a pedestal at the -X end with the touch screen (TEST) and a beacon lamp
##
## Rig space: origin on the floor under the deck's middle, +X along the deck (the coil's
## long axis), +Z towards where the worker stands. Presentation on every player: the rig
## follows ShipBayBus's rig state and test results.

const Touch := preload("res://modules/ship_bay/internal/kit/touch_screen.gd")
const T := preload("res://modules/ui/api/terminal_kit.gd")

## The rig's id in ShipBayBus (RIGS) and the yard's spots.
const RIG_ID := "rig_emitter"
## The deck's top over the floor, and its plate (x, z), metres.
const DECK_H := 0.95
const DECK := Vector2(2.0, 0.9)
## The hold-down bosses on the deck (x, z), metres from its middle.
const HOLD_DOWNS: Array[Vector2] = [Vector2(-0.6, -0.25), Vector2(0.6, -0.25), Vector2(-0.6, 0.25), Vector2(0.6, 0.25)]
## The biggest unit the deck takes: footprint (x, z) and height, metres.
const UNIT_MAX := Vector3(1.8, 0.8, 0.7)
## The grey-box coil housing drawn until Shared Components draws the unit (the Kestrel's
## attractor coil slot box), metres.
const STAND_IN := Vector3(1.4, 0.4, 0.3)
## The gantry's rails (z either side) and the hoop's inner radius over the deck, metres.
const RAIL_Z := 0.62
const HOOP_R := 0.78
## The test mass's rail: from the deck's end out this far along +X, metres.
const MASS_RAIL := 3.0

## Seconds a field sweep takes: the gantry runs out and back, the mass comes in.
@export var sweep_time := 6.0

var screen: Node3D
var gantry: Node3D
var probe: MeshInstance3D
var mass: Node3D
var beacon: MeshInstance3D
## The unit's look on the deck (Shared Components' or the stand-in), or null.
var unit_look: Node3D
## 0..1 through a sweep, or -1 when idle.
var sweep := -1.0
var _bus: ShipBayBus
var _steel: Material
var _blue: Material
var _dark: Material
var _yellow: Material
var _rubber: Material
var _beacon_off: Material
var _beacon_on: Material
var _solid: StaticBody3D
var _result: Dictionary = {}


func _ready() -> void:
	name = "EmitterRig"
	_steel = ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.32, "chrome"))
	_blue = ShipSurface.of(ShipKit.paint(Color(0.12, 0.32, 0.62), 0.2, 0.45, "satin_paint"))
	_dark = ShipSurface.of(ShipKit.paint(Color(0.14, 0.15, 0.17), 0.5, 0.5, "gunmetal"))
	_yellow = ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"))
	_rubber = ShipSurface.of(ShipKit.paint(Color(0.07, 0.07, 0.075), 0.0, 0.9, "rubber"))
	_beacon_off = _glow(Color(0.35, 0.22, 0.05), 0.0)
	_beacon_on = _glow(Color(1.0, 0.6, 0.1), 3.0)
	_solid = StaticBody3D.new()
	_solid.name = "Solid"
	add_child(_solid)
	_build_floor()
	_build_deck()
	_build_gantry()
	_build_mass_rail()
	_build_console()
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if _bus:
		_bus.rig_changed.connect(_on_rig_changed)
		_bus.rig_test_shown.connect(_on_test_shown)
		_on_rig_changed(RIG_ID, _bus.rig_state(RIG_ID))
	set_process(false)


func _exit_tree() -> void:
	if _bus and _bus.rig_changed.is_connected(_on_rig_changed):
		_bus.rig_changed.disconnect(_on_rig_changed)
		_bus.rig_test_shown.disconnect(_on_test_shown)


## The hold-down points in rig space: on the deck over each boss.
static func hold_down_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Vector2 in HOLD_DOWNS:
		out.append(Vector3(p.x, DECK_H + 0.03, p.y))
	return out


# --- Building ---------------------------------------------------------------------------

## A hazard-striped outline round the rig and its mass rail, and the rig's name on the floor.
func _build_floor() -> void:
	var r := Rect2(-DECK.x * 0.5 - 1.3, -1.0, DECK.x + 1.3 + MASS_RAIL + 0.6, 2.0)
	for z: float in [r.position.y, r.end.y]:
		_part(PartShapes.box(Vector3(r.size.x, 0.006, 0.1)), Vector3(r.get_center().x, 0.003, z), _yellow)
	for x: float in [r.position.x, r.end.x]:
		_part(PartShapes.box(Vector3(0.1, 0.0065, r.size.y - 0.2)), Vector3(x, 0.00325, r.get_center().y), _yellow)
	var words := Label3D.new()
	words.text = "EMITTER FRAME RIG  EF-1"
	words.font_size = 64
	words.pixel_size = 0.004
	words.modulate = Color(0.95, 0.75, 0.1)
	words.outline_size = 0
	words.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(DECK.x * 0.5 + MASS_RAIL * 0.5, 0.008, 0.75))
	add_child(words)


## The deck: two I-beam skids, four square legs with cross bracing, the T-slotted plate and
## its four hold-down bosses.
func _build_deck() -> void:
	for z: float in [-0.38, 0.38]:
		_part(PartShapes.i_beam(DECK.x + 0.3, 0.2, 0.16, 0.02), Vector3(0, 0.08, z), _blue)
	var leg_h := DECK_H - 0.16 - 0.06
	for x: float in [-DECK.x * 0.5 + 0.12, DECK.x * 0.5 - 0.12]:
		for z: float in [-0.38, 0.38]:
			_part(PartShapes.box(Vector3(0.1, leg_h, 0.1)), Vector3(x, 0.16 + leg_h * 0.5, z), _blue)
		_part(PartShapes.box(Vector3(0.06, 0.08, 0.66)), Vector3(x, 0.45, 0), _blue)
	_part(PartShapes.box(Vector3(DECK.x - 0.36, 0.08, 0.06)), Vector3(0, 0.45, -0.38), _blue)
	_part(PartShapes.box(Vector3(DECK.x - 0.36, 0.08, 0.06)), Vector3(0, 0.45, 0.38), _blue)
	_part(PartShapes.box(Vector3(DECK.x, 0.06, DECK.y)), Vector3(0, DECK_H - 0.03, 0), _steel)
	for i in 5:   # the T-slots, dark grooves along the plate
		_part(PartShapes.box(Vector3(DECK.x - 0.1, 0.004, 0.025)), Vector3(0, DECK_H + 0.001, -0.32 + i * 0.16), _dark)
	for p: Vector3 in hold_down_points():
		_part(PartShapes.prism(12, 0.055, 0.03), p - Vector3(0, 0.015, 0), _yellow)
		_part(PartShapes.prism(6, 0.022, 0.012), p + Vector3(0, 0.006, 0), _dark)
	_collide(Vector3(DECK.x, DECK_H, DECK.y), Vector3(0, DECK_H * 0.5, 0))


## The gantry: a rail each side of the deck and the portal hoop riding them, the probe hung
## from its crown pointing down at the unit.
func _build_gantry() -> void:
	var rail_y := DECK_H - 0.1
	for z: float in [-RAIL_Z, RAIL_Z]:
		_part(PartShapes.box(Vector3(DECK.x + 0.2, 0.05, 0.05)), Vector3(0, rail_y, z), _steel)
		for x: float in [-DECK.x * 0.5, DECK.x * 0.5]:
			_part(PartShapes.box(Vector3(0.05, rail_y - 0.025, 0.05)), Vector3(x, (rail_y - 0.025) * 0.5, z), _dark)
	gantry = Node3D.new()
	gantry.name = "Gantry"
	gantry.position = Vector3(-DECK.x * 0.5 + 0.15, rail_y + 0.025, 0)
	add_child(gantry)
	# The hoop stands across the deck: a half ring in the gantry's y-z plane on two trucks.
	var hoop := MeshInstance3D.new()
	hoop.mesh = PartShapes.arc_panel(HOOP_R + 0.04, 0.08, 180.0, 0.1, 24).mesh
	hoop.material_override = _yellow
	hoop.position = Vector3(0, 0.1, 0)
	gantry.add_child(hoop)
	for z: float in [-RAIL_Z, RAIL_Z]:
		var truck := MeshInstance3D.new()
		truck.mesh = PartShapes.box(Vector3(0.22, 0.12, 0.12)).mesh
		truck.material_override = _dark
		truck.position = Vector3(0, 0.07, z)
		gantry.add_child(truck)
	var head := MeshInstance3D.new()
	head.mesh = PartShapes.box(Vector3(0.16, 0.1, 0.16)).mesh
	head.material_override = _dark
	head.position = Vector3(0, 0.1 + HOOP_R - 0.04, 0)
	gantry.add_child(head)
	probe = MeshInstance3D.new()
	probe.name = "Probe"
	probe.mesh = PartShapes.frustum(0.012, 0.04, 0.22, 10).mesh
	probe.material_override = _glow(Color(0.3, 0.8, 1.0), 0.6)
	probe.position = head.position - Vector3(0, 0.16, 0)
	gantry.add_child(probe)


## The test mass's rail off the deck's +X end and the mass on its carriage at the far end.
func _build_mass_rail() -> void:
	var x0 := DECK.x * 0.5 + 0.1
	var y := 0.55
	_part(PartShapes.i_beam(MASS_RAIL, 0.16, 0.12, 0.016), Vector3(x0 + MASS_RAIL * 0.5, y, 0), _steel)
	for x: float in [x0 + 0.2, x0 + MASS_RAIL * 0.5, x0 + MASS_RAIL - 0.2]:
		_part(PartShapes.box(Vector3(0.08, y - 0.06, 0.08)), Vector3(x, (y - 0.06) * 0.5, 0), _blue)
		_part(PartShapes.box(Vector3(0.3, 0.02, 0.3)), Vector3(x, 0.01, 0), _dark)
	_part(PartShapes.box(Vector3(0.06, 0.2, 0.24)), Vector3(x0 + MASS_RAIL + 0.03, y + 0.06, 0), _rubber)   # end stop
	_collide(Vector3(MASS_RAIL, y + 0.06, 0.3), Vector3(x0 + MASS_RAIL * 0.5, (y + 0.06) * 0.5, 0))
	mass = Node3D.new()
	mass.name = "TestMass"
	mass.position = Vector3(_mass_far(), y + 0.06, 0)
	add_child(mass)
	var carriage := MeshInstance3D.new()
	carriage.mesh = PartShapes.box(Vector3(0.3, 0.05, 0.22)).mesh
	carriage.material_override = _dark
	carriage.position = Vector3(0, 0.025, 0)
	mass.add_child(carriage)
	var block := MeshInstance3D.new()
	block.mesh = PartShapes.chamfer_box(Vector3(0.26, 0.26, 0.26), 0.02).mesh
	block.material_override = _steel
	block.position = Vector3(0, 0.18, 0)
	mass.add_child(block)
	var tag := Label3D.new()
	tag.text = "50 kg"
	tag.font_size = 48
	tag.pixel_size = 0.002
	tag.modulate = Color(0.1, 0.1, 0.1)
	tag.outline_size = 0
	tag.position = Vector3(0, 0.18, 0.131)
	mass.add_child(tag)


func _mass_far() -> float:
	return DECK.x * 0.5 + 0.1 + MASS_RAIL - 0.25


func _mass_near() -> float:
	return DECK.x * 0.5 + 0.35


## The console at the deck's -X end: a pedestal with the touch screen tilted to the worker
## and a beacon on a short post that turns amber while a sweep runs.
func _build_console() -> void:
	var at := Vector3(-DECK.x * 0.5 - 0.7, 0, 0.1)
	_part(PartShapes.chamfer_box(Vector3(0.5, 1.0, 0.4), 0.03), at + Vector3(0, 0.5, 0), _blue)
	_part(PartShapes.chamfer_box(Vector3(0.62, 0.42, 0.06), 0.015), at + Vector3(0, 1.22, 0.06), _dark, Basis(Vector3.RIGHT, -0.35))
	_collide(Vector3(0.5, 1.0, 0.4), at + Vector3(0, 0.5, 0))
	screen = Touch.new()
	screen.name = "RigScreen"
	screen.transform = Transform3D(Basis(Vector3.RIGHT, -0.35), at + Vector3(0, 1.22, 0.1))
	add_child(screen)
	screen.call("setup", Vector2(0.56, 0.36), "FIELD SWEEP  EF-1", 1)
	screen.call("add_button", "test", "RUN FIELD SWEEP", _press_test, true)
	_part(PartShapes.box(Vector3(0.04, 0.5, 0.04)), at + Vector3(0.2, 1.25, -0.15), _dark)
	beacon = _part(PartShapes.prism(12, 0.05, 0.1), at + Vector3(0.2, 1.55, -0.15), _beacon_off)


# --- State ------------------------------------------------------------------------------

func _press_test() -> void:
	if _bus:
		_bus.request_rig_test(RIG_ID)


func _on_rig_changed(rig_id: String, state: Dictionary) -> void:
	if rig_id != RIG_ID:
		return
	var unit := str(state.get("unit", ""))
	var shown := str(unit_look.get_meta("unit", "")) if unit_look else ""
	if unit != shown:
		if unit_look:
			unit_look.queue_free()
			unit_look = null
		if unit != "":
			unit_look = _unit_look(unit)
			unit_look.set_meta("unit", unit)
			add_child(unit_look)
	if bool(state.get("testing", false)) and sweep < 0.0:
		_start_sweep()
	_show_screen(state)


## Shared Components' look for the unit when it has one (make_unit), else a grey-box coil
## housing with four feet on the hold-down bosses. Sits on the deck, its base at deck height.
func _unit_look(unit: String) -> Node3D:
	var shared := Modules.bus("shared_components")
	if shared and shared.has_method("make_unit"):
		var made: Variant = shared.call("make_unit", unit)
		if made is Node3D:
			(made as Node3D).position = Vector3(0, DECK_H, 0)
			return made
	var look := Node3D.new()
	look.name = "Unit"
	look.position = Vector3(0, DECK_H, 0)
	var body := MeshInstance3D.new()
	body.mesh = PartShapes.chamfer_box(STAND_IN, 0.03).mesh
	body.material_override = ShipSurface.of(ShipKit.paint(Color(0.42, 0.45, 0.48), 0.6, 0.4, "satin_paint"))
	body.position = Vector3(0, 0.06 + STAND_IN.y * 0.5, 0)
	look.add_child(body)
	for i in 3:   # the coil's winding bands
		var band := MeshInstance3D.new()
		band.mesh = PartShapes.box(Vector3(0.06, STAND_IN.y + 0.02, STAND_IN.z + 0.02)).mesh
		band.material_override = ShipSurface.of(ShipKit.paint(Color(0.72, 0.42, 0.2), 0.9, 0.3, "copper"))
		band.position = body.position + Vector3(-0.4 + i * 0.4, 0, 0)
		look.add_child(band)
	for p: Vector2 in HOLD_DOWNS:
		var foot := MeshInstance3D.new()
		foot.mesh = PartShapes.box(Vector3(0.14, 0.03, 0.12)).mesh
		foot.material_override = _dark
		foot.position = Vector3(p.x, 0.015, signf(p.y) * 0.21)
		look.add_child(foot)
		var leg := MeshInstance3D.new()
		leg.mesh = PartShapes.box(Vector3(0.06, 0.06, 0.05)).mesh
		leg.material_override = _dark
		leg.position = Vector3(p.x, 0.045, signf(p.y) * 0.17)
		look.add_child(leg)
	var plate := Label3D.new()
	plate.text = unit.to_upper().replace("_", " ")
	plate.font_size = 48
	plate.pixel_size = 0.002
	plate.outline_size = 0
	plate.modulate = Color(0.95, 0.95, 0.9)
	plate.position = body.position + Vector3(0.2, 0, STAND_IN.z * 0.5 + 0.012)
	look.add_child(plate)
	return look


func _on_test_shown(rig_id: String, result: Dictionary) -> void:
	if rig_id != RIG_ID:
		return
	_result = result.duplicate(true)
	if sweep < 0.0:
		_start_sweep()


func _start_sweep() -> void:
	sweep = 0.0
	beacon.material_override = _beacon_on
	screen.call("set_status", "SWEEPING", T.CYAN)
	set_process(true)


func _process(delta: float) -> void:
	sweep = minf(sweep + delta / maxf(sweep_time, 0.01), 1.0)
	# Out along the deck and back; the mass drawn in over the first half, let go over the second.
	var run := 1.0 - absf(sweep * 2.0 - 1.0)
	gantry.position.x = lerpf(-DECK.x * 0.5 + 0.15, DECK.x * 0.5 - 0.15, smoothstep(0.0, 1.0, run))
	mass.position.x = lerpf(_mass_far(), _mass_near(), smoothstep(0.0, 1.0, run))
	(probe.material_override as StandardMaterial3D).emission_energy_multiplier = 0.6 + 2.0 * run
	if sweep >= 1.0:
		sweep = -1.0
		set_process(false)
		beacon.material_override = _beacon_off
		_show_screen(_bus.rig_state(RIG_ID) if _bus else {})


## The screen: what's on the deck, and the last result (old against new) once a sweep has run.
func _show_screen(state: Dictionary) -> void:
	if screen == null or sweep >= 0.0:
		return
	var unit := str(state.get("unit", ""))
	var result: Dictionary = state.get("result", _result)
	if unit == "":
		screen.call("set_status", "EMPTY", T.DIM)
		screen.call("set_body", "Bolt a unit onto the deck to test it.", T.DIM)
		return
	if result.is_empty():
		screen.call("set_status", "READY", T.GOOD)
		screen.call("set_body", "%s on the deck.\nRun a field sweep to test it." % unit.to_upper().replace("_", " "))
		return
	var lines := PackedStringArray()
	for l: Array in result.get("lines", []):
		lines.append("%-14s %8s  ->  %s" % [str(l[0]), str(l[1]), str(l[2])])
	if str(result.get("note", "")) != "":
		lines.append(str(result["note"]))
	var passed := bool(result.get("passed", false))
	screen.call("set_status", "PASS" if passed else "FAIL", T.GOOD if passed else T.BAD)
	screen.call("set_body", "\n".join(lines), T.TEXT)


# --- Helpers ----------------------------------------------------------------------------

func _part(shape: PartShapes.PartShape, at: Vector3, mat: Material, basis := Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, at)
	add_child(mi)
	return mi


func _collide(size: Vector3, at: Vector3) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	c.shape = b
	c.position = at
	_solid.add_child(c)
	return c


func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	return m
