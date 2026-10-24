extends Node3D
## The emitter frame rig (Component Upgrades U1, beenster 24 Oct): a waist-high steel test
## bench in Pre-assembly that an attractor coil is bolted onto, opened, fitted with BSX
## add-ons and field-swept. Ship and Bay builds the rig and keeps which unit is on it;
## Shared Components draws the unit, Tools works its joints, Quality runs the test.
##
##   DECK      a T-slotted steel plate on four legs and two I-beam skids; four M12 bolts
##             hold the unit's base corners down (ShipBayBus.rig_points, Tools works them)
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
## The biggest unit the deck takes: footprint (x, z) and height, metres.
const UNIT_MAX := Vector3(1.8, 0.8, 0.7)
## The attractor coil's housing per tier, metres (Shared Components' UpgradeRules.unit_size,
## data/upgrades/upgrade_rules.json): x along the coil, y up, z across.
const COIL_SIZES := {1: Vector3(0.9, 0.22, 0.24), 2: Vector3(1.15, 0.26, 0.28), 3: Vector3(1.4, 0.3, 0.3)}
## How far in from the housing's base corners the hold-down clamps bite, metres.
const CLAMP_INSET := 0.05
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
## Shared Components' unit on the deck (UpgradeUnits.attractor_coil's result: unit, tier,
## part, cover, bolts, tacks, box, mounts..., plus "kit", the ShipKit it was built on, for
## fitting add-ons), {} for the stand-in or an empty deck.
var unit_parts: Dictionary = {}
## Quality's plate on the housing after a test, or null.
var plate_node: Node3D
var _quality: Node


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
	if _bus:
		_bus.rig_nodes[RIG_ID] = self
	_quality = Modules.bus("quality")
	if _quality and _quality.has_signal("rig_test_finished"):
		_quality.connect("rig_test_finished", _on_plate)
	set_process(false)


func _exit_tree() -> void:
	if _bus and _bus.rig_nodes.get(RIG_ID) == self:
		_bus.rig_nodes.erase(RIG_ID)
	if _bus and _bus.rig_changed.is_connected(_on_rig_changed):
		_bus.rig_changed.disconnect(_on_rig_changed)
		_bus.rig_test_shown.disconnect(_on_test_shown)
	if _quality and _quality.has_signal("rig_test_finished") and _quality.is_connected("rig_test_finished", _on_plate):
		_quality.disconnect("rig_test_finished", _on_plate)


## A unit's tier from its id ("attractor_coil_2" -> 2); 1 when it carries none.
static func tier_of(unit: String) -> int:
	var t := unit.get_slice("_", unit.get_slice_count("_") - 1)
	return clampi(int(t), 1, 3) if t.is_valid_int() else 1


## A unit's housing (x along it, y up, z across), metres.
static func unit_size(unit: String) -> Vector3:
	return COIL_SIZES[tier_of(unit)]


## The hold-down clamps for a unit in spot space (origin on the deck's middle at deck height,
## +X along the unit): the base corners of its housing, CLAMP_INSET in.
static func hold_down_points(unit: String) -> Array[Vector3]:
	var half := unit_size(unit) * 0.5 - Vector3(CLAMP_INSET, 0, CLAMP_INSET)
	var out: Array[Vector3] = []
	for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		out.append(Vector3(k.x * half.x, 0.0, k.y * half.z))
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


## The deck: two I-beam skids, four square legs with cross bracing and the T-slotted plate.
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


## The unit on the deck, its base on the plate and its origin (the housing's centre) over the
## deck's middle: Shared Components' coil as parts and joints (UpgradeUnits.attractor_coil on
## a frozen body; unit_parts keeps its record) once that class is in the game, else a
## tier-sized open housing as a stand-in.
func _unit_look(unit: String) -> Node3D:
	var size := unit_size(unit)
	var xform := Transform3D(Basis.IDENTITY, Vector3(0, DECK_H + size.y * 0.5, 0))
	var units := _global_script("UpgradeUnits")
	if units:
		var body := RigidBody3D.new()
		body.name = "Unit"
		body.freeze = true
		var kit := ShipKit.new(body)
		kit.model = PartModel.new(body, true)
		var made: Variant = units.call("attractor_coil", kit, tier_of(unit), xform, "rig:emitter")
		if made is Dictionary and not (made as Dictionary).is_empty():
			unit_parts = made
			unit_parts["kit"] = kit
			return body
		body.free()
	return _stand_in(unit, size, xform)


## A grey-box housing the size of the unit, open on top (Tools draws the cover and what goes
## inside), with copper windings low along it.
func _stand_in(unit: String, size: Vector3, xform: Transform3D) -> Node3D:
	var look := Node3D.new()
	look.name = "Unit"
	look.transform = xform
	var grey := ShipSurface.of(ShipKit.paint(Color(0.28, 0.3, 0.33), 0.6, 0.5, "satin_paint"))
	var h := size * 0.5
	var sheet := 0.02
	var wall_h := size.y - 0.035
	var pieces := [[Vector3(size.x, sheet, size.z), Vector3(0, -h.y + sheet * 0.5, 0)]]
	for sx: float in [-1.0, 1.0]:
		pieces.append([Vector3(sheet, wall_h, size.z), Vector3(sx * (h.x - sheet * 0.5), -h.y + wall_h * 0.5, 0)])
	for sz: float in [-1.0, 1.0]:
		pieces.append([Vector3(size.x - 2 * sheet, wall_h, sheet), Vector3(0, -h.y + wall_h * 0.5, sz * (h.z - sheet * 0.5))])
	for piece: Array in pieces:
		var mi := MeshInstance3D.new()
		mi.mesh = PartShapes.box(piece[0]).mesh
		mi.material_override = grey
		mi.position = piece[1]
		look.add_child(mi)
	var copper := ShipSurface.of(ShipKit.paint(Color(0.74, 0.46, 0.22), 0.9, 0.35, "copper"))
	var r := minf(0.1, h.z - sheet - 0.015)
	var span := size.x - 0.3
	for i in 6:   # windings, kept under 0.12 m so the inside stays clear above it
		var band := MeshInstance3D.new()
		band.mesh = PartShapes.box(Vector3(span / 8.0, 0.1, r * 2.0)).mesh
		band.material_override = copper
		band.position = Vector3(-0.08 - span * 0.5 + span * (i + 0.5) / 6.0, -h.y + sheet + 0.05, 0)
		look.add_child(band)
	var tag := Label3D.new()
	tag.text = unit.to_upper().replace("_", " ")
	tag.font_size = 40
	tag.pixel_size = 0.0018
	tag.outline_size = 0
	tag.modulate = Color(0.95, 0.95, 0.9)
	tag.position = Vector3(-h.x * 0.4, 0, h.z + 0.003)
	look.add_child(tag)
	return look


## Quality's plate after a test of this rig's unit: fixed on the housing's worker (+Z) face,
## right of the middle. It stays until the unit comes off.
func _on_plate(plate: Variant) -> void:
	if unit_look == null or _quality == null or not _quality.has_method("make_plate_node"):
		return
	var rig := str(_field(plate, "rig_id"))
	var unit := str(_field(plate, "unit_id"))
	if rig != RIG_ID and unit != str(unit_look.get_meta("unit", "")):
		return
	var made: Variant = _quality.call("make_plate_node", plate)
	if not made is Node3D:
		return
	if plate_node:
		plate_node.queue_free()
	plate_node = made
	plate_node.name = "Plate"
	var size := unit_size(str(unit_look.get_meta("unit", "")))
	plate_node.position = Vector3(size.x * 0.22, DECK_H + size.y * 0.45, size.z * 0.5 + 0.004)
	add_child(plate_node)


static func _field(o: Variant, key: String) -> Variant:
	if o is Dictionary:
		return (o as Dictionary).get(key, "")
	if o is Object:
		return (o as Object).get(key) if key in o else ""
	return ""


## A project class's script by name, or null while no module defines it.
static func _global_script(class_id: String) -> Script:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if str(c["class"]) == class_id:
			return load(str(c["path"])) as Script
	return null


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
		screen.call("set_body", "%s on the deck.\nHold-downs %d/4 tight.\nRun a field sweep to test it." % [
				unit.to_upper().replace("_", " "), (state.get("joints", {}) as Dictionary).size()])
		return
	var lines := PackedStringArray()
	for l: Array in result.get("lines", []):
		lines.append("%-14s %8s  ->  %s" % [str(l[0]), str(l[1]), str(l[2])])
	for r: Array in result.get("rated", []):
		lines.append("%-14s rated %s" % [str(r[0]), str(r[1])])
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
