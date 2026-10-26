class_name TradesShipJoints
extends TradesStation
## The work on the ship itself, in the shipyard: every joint Ship and Bay lists on the loaded
## ship (FastenerPoint: bolts, rivets, welds, connectors), worked with whichever tool is in
## your hand. Aim at a joint within reach and it lights up; then
##
##   bolt       torque wrench: hold left click and pull the mouse back until it clicks;
##              right click (hold) breaks it loose
##   rivet      squeezer: hold left click to set it; drill: hold left click to drill it out
##   weld       welder: hold left click to lay it; hold right click to cut it out (unweld)
##   connector  hands or crimper: left click plugs it, right click unplugs it; a power or
##              data plug (trades.wire_diagram) unfolds the wiring tool in front of you, on
##              whose screen you drag the loom's wires onto the pins (TradesWireLoom,
##              TradesWiringPanel, TradesWiringTablet)
##
## With trades.vs_tools (after Void Salvage's tools) the power wrench takes a tight bolt out
## and runs a loose one in to its setting on one held click, the cutter grinds rivet heads off,
## and a held click on a weld cuts it out where you point; with trades.weld_skill a bead comes
## out well only at a steady pace near the line.
##
## Ship and Bay hears about every joint made or taken off (note_joint_made/removed) and keeps
## the slot's state: take every joint off a part and the part comes off; hands on one of its
## joints puts it back in place, ready to fasten again. The station has no bench: `bay` is
## the yard rig (TradesBay in the yard). The tool test stand's practice joints
## (TradesTestStand, trades.test_stand) come after the ship's in `points`; their state stays
## here (`practice`).

## How close the aim has to pass a joint to pick it (metres).
const PICK_M := 0.09
## Seconds of holding for each job.
const SQUEEZE_S := 0.8
const DRILL_S := 1.2
const WELD_S := 2.0
const BREAK_S := 0.6
## Cutting a weld out takes longer than laying it.
const CUT_S := 2.5
const PLUG_S := 0.3
## Torque per pixel of pulling the mouse back (N m).
const NM_PER_PX := 0.35
## The torch's tilt off the surface's normal while welding (degrees).
const TORCH_TILT_DEG := 20.0
## The torch turned off the line back to the worker, so it isn't in front of the view (radians).
const TORCH_TURN := 0.9
const KIND_TOOLS := {
	"bolt": [&"torque_wrench"],
	"rivet": [&"rivet_squeezer", &"drill"],
	"weld": [&"welder"],
	"connector": [&"hands", &"wire_tool"],
}

## The powered wrench (trades.power_wrench, TradesPowerWrench): seconds to run a bolt up to
## its setting; how long the trigger can stay down after the clutch slips before the thread
## strips; the odds that a run stalls, and the share of the spec's middle a setting may be
## off before Quality marks it down (they grade it; this is the ship's own quality figure).
const RUN_S := 1.2
const STRIP_S := 1.0
const STALL_CHANCE := 0.04
## Sparks thrown each frame off the arc, laying a bead and cutting one out.
## (beenster, 2026-10-22: "lots more sparks")
const SPARKS_WELD := 12
const SPARKS_CUT := 26
const SPARKS_HEAT := 5
const SPARKS_GRIND := 22
## With trades.molten the welder's sparks live about three seconds, so fewer a frame.
const SPARKS_WELD_LONG := 7
const SPARKS_CUT_LONG := 13


## Sparks a frame off a welder's arc (trades.molten).
static func weld_sparks(cutting: bool) -> int:
	return SPARKS_CUT_LONG if cutting else SPARKS_WELD_LONG
## The powered rivet gun (trades.power_riveter): seconds for its air to build to the punch.
## A rivet heated out with the welder (trades.rivet_heat), or its head ground off with the
## cutter (trades.cutter): seconds each takes.
const PRESS_S := 0.8
const HEAT_S := 1.6
const GRIND_S := 1.8

## trades.vs_tools (beenster, 0.3.18: "copy the behaviours of the cutter ... wrench ...
## unweld should just be a point and click hold", after Void Salvage's grinder and socket):
## the wrench turns a tight bolt out or a loose one in to its setting by itself, the cutter's
## disc spins up and grinds a rivet's head off, unweld cuts a weld where you point. Let go and
## what's done stays done; drift the aim off the joint and the tool slips off it.
## Seconds for a bolt to back out, to run in to its setting, and to cut a weld out.
const UNDO_S := 2.0
const SPIN_S := 1.6
const UNWELD_S := 3.5
## How far a bolt backs out before it comes free (m).
const BOLT_TRAVEL_M := 0.022
## The cutter's disc spinning up before it bites (s).
const SPIN_UP_S := 0.3
## The aim this far off the joint and the tool slips off it (m).
const SLIP_M := 0.14

## trades.weld_skill (beenster, 0.3.18: "our welder should be more of a skill game"): a
## bead takes where the arc lingers long enough and comes out well at an even, steady pace
## near the line. The travel speed it wants (mm/s); a stretch takes once the arc has stayed
## TAKE_R of the time that speed gives it; past SLOW_R it piles up, past BURN_R it burns
## through. Off the line by more than OFF_OK_MM and the arc runs long.
const WELD_SPEED_MM_S := 50.0
const TAKE_R := 0.45
const GOOD_R := 0.6
const SLOW_R := 1.8
const BURN_R := 3.5
const OFF_OK_MM := 12.0


static func vs_tools() -> bool:
	return Flags.is_on("trades.vs_tools")


static func weld_skill() -> bool:
	return Flags.is_on("trades.weld_skill")

## Ship space to this station's world: set from the yard on every ship_loaded.
var ship_xform := Transform3D.IDENTITY
## The loaded ship's joints and where each one is in the world.
var points: Array[FastenerPoint] = []
var points_world: PackedVector3Array = PackedVector3Array()
## The joint under the aim (index into points), or -1.
var aimed := -1

var _bus: ShipBayBus
var _working := -1
var _undoing := false
var _tool_held: StringName = &""
var _held_s := 0.0
var _pull_px := 0.0
var _clicked := false
## A screenshot holds the job where it is.
var _frozen := false
## The powered wrench's run: seconds in when it stalls (-1: it won't), and seconds since its
## clutch slipped (-1: not yet).
var _stall_at := -1.0
var _clutch_s := -1.0
## trades.vs_tools: seconds since this pull of the trigger, and the work done on a joint when
## it was let go ("<joint_id>:out" or ":in" -> seconds), so pulling it again carries on.
var _run_s := 0.0
var _kept_s := {}
## Where along a seam an unweld struck its arc (joint_id -> bin), spreading from there.
var _cut_from := {}
## The bolt's shank showing under the wrench as it backs out or runs in.
var _shank: MeshInstance3D
## trades.weld_skill: per joint, seconds the arc has spent on each stretch of the seam and its
## distance off the line over that time (m s); the bead drawn for each stretch; the travel
## speed (mm/s, smoothed) and the last word said about it.
var _dwell := {}
var _off := {}
var _bin_beads := {}
var _speed_mm_s := 0.0
var _trace_s := NAN
var _pace_word := ""
## slot_id -> the component that came off it (so hands can put it back).
var _removed: Dictionary = {}
var _marker: MeshInstance3D
## The aim ring's colour says the joint's state (beenster, 0.3.14): orange while it's undone,
## green once it's made (torqued, set, welded, plugged).
var _bolt_mesh: Mesh
## Welds traced along their seam (trades.trace_weld): joint_id -> one byte per stretch of
## the seam, 1 once the arc has run over it. Kept between passes until the weld is done.
var _traced := {}
var _trace_last := NAN
## Fresh bead, glowing orange and cooling: [MeshInstance3D, material, age].
var _beads: Array = []
var _ring_loose := TradesLook.glow(Color(1.0, 0.55, 0.1), 2.5)
var _ring_tight := TradesLook.glow(Color(0.3, 1.0, 0.4), 2.5)
## trades.quiet_rings: one pale ring, thinner, whatever the state.
var _ring_quiet := TradesLook.quiet_ring()
var _ring_mesh: TorusMesh
var _quiet_mesh: TorusMesh
## The chalk line along a seam and the torch tip's point (trades.weld_guide).
var guide: TradesWeldGuide
## The tractor beam (tool 7), for lifting parts that are off the ship.
var tractor: TradesTractor
var _arc: OmniLight3D
## The wiring diagram up on screen (null when none), the joint it's for, and every plug's
## loom by joint id (what you landed stays when you close it).
var wiring: TradesWiringPanel
var _wiring_at := -1
var tablet: TradesWiringTablet
var _looms: Dictionary = {}
## The tool test stand (trades.test_stand) and its practice joints' state, kept here rather
## than by Ship and Bay: joint_id -> true while made.
var test_stand: TradesTestStand
var practice := {}
## A unit opened on an upgrade rig for its add-ons (trades.unit_mounts, TradesUnitWork): its
## joints and seats keep their state in `practice` too, and their qualities here for Quality.
var unit: TradesUnitWork
var _unit_quality := {}
## Upgrade rigs' hold-down bolts are Ship and Bay's joints (rig_points): rig_id -> the rig's
## world transform, so their points are read in with the ship's.
var rigs := {}


func build() -> void:
	title = "Ship"
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if _bus:
		_bus.ship_loaded.connect(func(_id: String) -> void: refresh_points())
		_bus.ship_unloaded.connect(func(_id: String) -> void: refresh_points())
		_bus.component_removed.connect(func(slot_id: String, comp: String) -> void: _removed[slot_id] = comp)
		_bus.component_positioned.connect(func(slot_id: String, _c: String) -> void: _removed.erase(slot_id))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.028
	ring.outer_radius = 0.036
	ring.rings = 24
	ring.ring_segments = 8
	_ring_mesh = ring
	_quiet_mesh = TorusMesh.new()
	_quiet_mesh.inner_radius = 0.029
	_quiet_mesh.outer_radius = 0.032
	_quiet_mesh.rings = 24
	_quiet_mesh.ring_segments = 6
	_marker = MeshInstance3D.new()
	_marker.mesh = ring
	_marker.material_override = _ring_loose
	_marker.top_level = true
	_marker.visible = false
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_arc = OmniLight3D.new()
	_arc.light_color = Color(0.7, 0.85, 1.0)
	_arc.omni_range = 5.0
	_arc.top_level = true
	_arc.visible = false
	add_child(_arc)
	guide = TradesWeldGuide.new()
	add_child(guide)
	var shank := CylinderMesh.new()
	shank.top_radius = 0.006
	shank.bottom_radius = 0.006
	shank.height = 1.0
	shank.radial_segments = 8
	shank.rings = 1
	shank.material = TradesTool.steel()
	_shank = MeshInstance3D.new()
	_shank.name = "BoltShank"
	_shank.mesh = shank
	_shank.top_level = true
	_shank.visible = false
	_shank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shank)
	tractor = TradesTractor.new()
	tractor.name = "Tractor"
	tractor.station = self
	add_child(tractor)
	refresh_points()


## Read the loaded ship's joints again (after a ship loads, or the ship moved), then the test
## stand's after them.
func refresh_points() -> void:
	points.clear()
	points_world.clear()
	if _bus and _bus.ship:
		for slot in _bus.get_slots():
			for f in _bus.get_fasteners(slot.slot_id):
				points.append(f)
				points_world.append(ship_xform * f.position)
	if test_stand and test_stand.is_inside_tree():
		# In ship space like the rest, so the station treats them all alike.
		var to_ship := ship_xform.affine_inverse() * test_stand.global_transform
		for f in test_stand.joints:
			var g := f.duplicate() as FastenerPoint
			g.position = to_ship * f.position
			g.normal = (to_ship.basis * f.normal).normalized()
			if f.seam_up != Vector3.ZERO:
				g.seam_up = (to_ship.basis * f.seam_up).normalized()
			points.append(g)
			points_world.append(test_stand.global_transform * f.position)
	if unit and unit.is_inside_tree():
		_add_fixture(unit.workable(), unit.global_transform)
	if _bus and _bus.has_method("rig_points"):
		for rig_id: String in rigs:
			_add_fixture(_bus.call("rig_points", rig_id), rigs[rig_id])
	aimed = -1


## Joints given in a fixture's own space (`at`: its world transform), read in as ship space.
func _add_fixture(list: Array, at: Transform3D) -> void:
	var to_ship := ship_xform.affine_inverse() * at
	for f: FastenerPoint in list:
		var g := f.duplicate() as FastenerPoint
		g.position = to_ship * f.position
		g.normal = (to_ship.basis * f.normal).normalized()
		if f.seam_up != Vector3.ZERO:
			g.seam_up = (to_ship.basis * f.seam_up).normalized()
		points.append(g)
		points_world.append(at * f.position)


## Puts a unit on the rig `rig_id` (at: the rig's world transform), closed, nothing in yet.
## `bare`: the rig draws the unit's case itself.
## `record`: Shared Components' unit on the rig (ShipBayBus.rig_unit), whose model the work is
## then done on; `at` is then its body's world transform.
func add_unit(rig_id: String, unit_id: String, tier: int, at: Transform3D, bare := false, record: Dictionary = {}) -> TradesUnitWork:
	remove_unit()
	unit = TradesUnitWork.new(rig_id, unit_id, tier, record)
	unit.bare = bare
	var start := unit.starting_state()
	for id: String in start:
		practice[id] = start[id]
	unit.state = practice
	add_child(unit)
	unit.global_transform = at
	refresh_points()
	_unit_changed()
	return unit


## The unit came off its rig.
func remove_unit() -> void:
	if unit == null:
		return
	for id: String in unit.starting_state():
		practice.erase(id)
		_unit_quality.erase(id)
	var rig_id := unit.rig_id
	unit.queue_free()
	unit = null
	refresh_points()
	var bus := bay.bus() if bay else null
	if bus:
		bus.note_unit(rig_id, {})


## A rig joint (Ship and Bay's hold-down bolts): its slot is the rig's id.
func is_rig(f: FastenerPoint) -> bool:
	return rigs.has(FastenerPoint.slot_of(f.joint_id))


static func is_unit(f: FastenerPoint) -> bool:
	return FastenerPoint.slot_of(f.joint_id).begins_with("unit_")


## The unit's joints or seats changed (here or by a crewmate): the points to work, and Quality.
func _unit_changed(joint_id: String = "") -> void:
	if unit == null:
		return
	unit.sync()
	refresh_points.call_deferred()
	var bus := bay.bus() if bay else null
	if bus == null:
		return
	if joint_id != "" and not joint_id.ends_with("/fitted"):
		bus.unit_joint_changed.emit(unit.rig_id, joint_id, bool(practice.get(joint_id, false)), float(_unit_quality.get(joint_id, 1.0)))
	bus.note_unit(unit.rig_id, unit.report(_unit_quality))


## F at the unit: puts an add-on on the empty seat you point at, or lifts one off whose
## joints are all out. True when it did something.
func use_unit() -> bool:
	if unit == null:
		return false
	var seat := unit.seat_near(bay.worker.aim_origin(), bay.worker.aim_dir())
	if seat == "":
		return false
	var id := unit.slot_of(seat) + "/fitted"
	var refused := UpgradeRules.refusal(unit.unit_id, unit.part_of(seat), unit._fitted_ids()) if unit.model and not unit.is_fitted(seat) else ""
	if refused != "":
		bay.hint("It won't go in: %s." % refused)
	elif not unit.is_fitted(seat):
		_set_seat(id, true)
		bay.play(&"clunk", 0.9)
		bay.hint("%s in. Fasten it down." % TradesUnitWork.ADDON_NAMES[seat])
	elif unit.can_lift(seat):
		_set_seat(id, false)
		bay.play(&"clunk", 1.2)
		bay.hint("%s out." % TradesUnitWork.ADDON_NAMES[seat])
	else:
		bay.hint("Undo the %s's joints first." % TradesUnitWork.ADDON_NAMES[seat].to_lower())
	return true


func _set_seat(id: String, on: bool) -> void:
	practice[id] = on
	if bay and bay.crew:
		bay.crew.share_practice(id, on)
	_unit_changed(id)


## Puts the tool test stand up at `at` (world; +Z toward where you stand).
func add_test_stand(at: Transform3D) -> TradesTestStand:
	test_stand = TradesTestStand.new()
	test_stand.is_made = func(id: String) -> bool: return practice.get(id, false)
	for f in test_stand.joints:
		practice[f.joint_id] = test_stand.made_at_start.has(f.joint_id)
	add_child(test_stand)
	test_stand.global_transform = at
	refresh_points()
	return test_stand


## A joint Tools keeps the state of itself (the test stand's, an opened unit's), rather
## than Ship and Bay.
static func is_practice(f: FastenerPoint) -> bool:
	return FastenerPoint.slot_of(f.joint_id) == TradesTestStand.SLOT or is_unit(f)


## Whether a joint is made: the ship's from Ship and Bay, the test stand's from `practice`.
func is_tight(f: FastenerPoint) -> bool:
	if is_practice(f):
		return practice.get(f.joint_id, false)
	return _bus != null and _bus.is_joint_tight(f.joint_id)


func _note_made(f: FastenerPoint, quality: float) -> bool:
	if not is_practice(f):
		return _bus.note_joint_made(f.joint_id, quality)
	if practice.get(f.joint_id, false):
		return false
	practice[f.joint_id] = true
	if bay and bay.crew:
		bay.crew.share_practice(f.joint_id, true)
	if is_unit(f):
		_unit_quality[f.joint_id] = quality
		_unit_changed(f.joint_id)
	return true


## A joint on the stand made or undone by a crewmate (TradesCrew).
func set_practice(joint_id: String, made: bool) -> void:
	if practice.has(joint_id):
		practice[joint_id] = made
		if joint_id.begins_with("unit_"):
			_unit_changed(joint_id)


func _note_removed(f: FastenerPoint) -> bool:
	var gone := false
	if not is_practice(f):
		gone = _bus.note_joint_removed(f.joint_id)
	elif practice.get(f.joint_id, false):
		practice[f.joint_id] = false
		gone = true
		if bay and bay.crew:
			bay.crew.share_practice(f.joint_id, false)
		if is_unit(f):
			_unit_quality.erase(f.joint_id)
			_unit_changed(f.joint_id)
	if gone and f.kind == "bolt":
		_drop_bolt(f)
	return gone


## A bolt that comes out falls to the floor (beenster, 0.3.14; rivet heads pop off in
## _work_rivet_out).
func _drop_bolt(f: FastenerPoint) -> void:
	var sparks := bay.sparks if bay else null
	if sparks == null or not sparks.is_inside_tree():
		return
	var i := points.find(f)
	var at := points_world[i] if i >= 0 else ship_xform * f.position
	var n := (ship_xform.basis * f.normal).normalized()
	pop_part("bolt", at + n * 0.03, n * 0.6 + Vector3.UP * 0.4)
	if bay.crew:
		bay.crew.share_pop("bolt", at + n * 0.03, n * 0.6 + Vector3.UP * 0.4)


## Something knocked off falls: "bolt", "rivet" or "rivet_hot" (a heated-out rivet).
func pop_part(kind: String, at: Vector3, vel: Vector3) -> void:
	var sparks := bay.sparks if bay else null
	if sparks == null or not sparks.is_inside_tree():
		return
	if kind == "bolt":
		if _bolt_mesh == null:
			_bolt_mesh = _make_bolt_mesh()
		sparks.pop(at, vel, _bolt_mesh, TradesTool.steel())
		return
	var heat := kind == "rivet_hot"
	var rivet := CylinderMesh.new()
	rivet.top_radius = 0.0045
	rivet.bottom_radius = 0.0045
	rivet.height = 0.01 if heat else 0.003
	sparks.pop(at, vel, rivet, TradesLook.glow(Color(1.0, 0.4, 0.1), 2.0) if heat else TradesTool.steel())


## The part a joint holds ("" when none): the ship's from Ship and Bay.
func _component_of(f: FastenerPoint) -> String:
	if is_unit(f) and unit:
		var mount := unit.mount_of(f.joint_id)
		return "Unit cover" if mount == "cover" else str(TradesUnitWork.ADDON_NAMES.get(mount, ""))
	if is_practice(f):
		return "Test panel"
	if is_rig(f):
		return "Unit hold-down"
	return _bus.get_component(FastenerPoint.slot_of(f.joint_id)) if _bus else ""


func tools() -> Array[StringName]:
	if tractor.is_holding():
		return [&"tractor"]
	if aimed < 0:
		return bay.hotbar
	var useful: Array[StringName] = []
	useful.assign(kind_tools(points[aimed].kind))
	return useful


func status_line() -> String:
	if bay.tool == &"tractor":
		return tractor.status_line()
	if aimed < 0:
		var ship := points.filter(func(f: FastenerPoint) -> bool: return not is_practice(f)).size()
		return "Ship: %d joints, %d tight" % [ship, _tight_count()] if ship > 0 else ""
	var f := points[aimed]
	var line := "%s  %s %s  %s" % [f.joint_id.to_upper(), f.spec.to_upper(), f.kind.to_upper(), _state_word(f)]
	# The powered wrench's setting is the player's to find (Tab, the wrist's Specs channel).
	if f.kind == "bolt" and not powered():
		var nm := torque_range(f.spec)
		line += "  [%d-%d N m]" % [roundi(nm.x), roundi(nm.y)]
	return line


func start_hint() -> String:
	return "Walk up to the ship and aim at a bolt, rivet, weld or plug. Mouse wheel picks the tool."


func is_busy() -> bool:
	return _working >= 0 or tractor.is_holding() or wiring != null


## The torque range (N m) for a bolt spec from Shared Components' fastener specs, or a
## sensible default. Shared Components is optional here (not in depends_on, so the modules
## that load Tools don't all need it), hence the untyped calls.
static func torque_range(spec_id: String) -> Vector2:
	var shared: Node = Modules.bus("shared_components")
	var spec: Object = shared.call("fastener", spec_id) if shared and shared.has_method("fastener") else null
	var nm: Variant = spec.get("torque_nm") if spec else null
	if nm is Vector2 and (nm as Vector2).y > 0.0:
		return nm
	return Vector2(40.0, 60.0)


## The rivet head height (mm) a rivet spec wants: half its shank diameter, the usual formed
## head, or 2 mm without Shared Components.
static func head_target_mm(spec_id: String) -> float:
	var shared: Node = Modules.bus("shared_components")
	var spec: Object = shared.call("fastener", spec_id) if shared and shared.has_method("fastener") else null
	var dia: Variant = spec.get("diameter_mm") if spec else null
	return float(dia) * 0.5 if dia is float and float(dia) > 0.0 else 2.0


# --- Input --------------------------------------------------------------------------------

func press(tool: StringName) -> void:
	if tool == &"tractor":
		tractor.press()
		return
	if aimed < 0:
		return
	var f := points[aimed]
	if _slot_empty(f):
		if tool == &"hands":
			_refit(f)
		else:
			bay.hint("The part is off. %s on one of its joints puts it back." % _named(&"hands").capitalize())
		return
	var tight := is_tight(f)
	if uses_diagram(f) and kind_tools(f.kind).has(tool):
		if tight:
			bay.hint("Plugged in. Right click pulls the plug to rewire it.")
		else:
			open_wiring(aimed)
		return
	if f.kind == "bolt" and tool == &"torque_wrench" and powered():
		if vs_tools() and (tight or not _blocked(f)):
			# No fasten or undo to pick: a tight bolt comes out, a loose one goes in.
			_begin(tight, &"torque_wrench")
		elif vs_tools():
			bay.hint("The beam holding this part has it out of line. Its first joint waits until it's in line.")
		else:
			_press_power(f, tight)
		return
	if f.kind == "weld" and tool == &"welder" and vs_tools() and tight and Flags.is_on("trades.unweld"):
		# Point and hold on a weld cuts it out; no unweld mode to switch to.
		_begin(true, tool)
		return
	if f.kind == "rivet" and tool in [&"welder", &"cutter"] and kind_tools("rivet").has(tool):
		if not tight:
			bay.hint("Nothing to take out: this rivet hole is empty.")
		else:
			_begin(true, tool)
		return
	if f.kind == "weld" and tool == &"welder" and _torch() and _torch().unweld and not vs_tools():
		if not tight:
			bay.hint("Nothing to cut out. %s switches the welder back to weld." % Keys.key_name(TradesBus.KEY_MODE))
		elif not Flags.is_on("trades.unweld"):
			bay.hint("Cutting welds isn't switched on yet.")
		else:
			_begin(true, tool)
		return
	if not kind_tools(f.kind).has(tool):
		bay.hint("That's a %s: %s." % [f.kind, kind_help(f.kind)])
		return
	if tool == &"drill":
		if not tight:
			bay.hint("Nothing to drill out: this rivet hole is empty. The %s sets a new one." % _named(&"rivet_squeezer"))
			return
		_begin(true, tool)
	elif tight:
		bay.hint("Already %s. Right click takes it off." % _state_word(f).to_lower())
	elif _blocked(f):
		bay.hint("The beam holding this part has it out of line. Its first joint waits until it's in line.")
	else:
		_begin(false, tool)


## A part held out of line in the beam: its first joint can't be made yet.
func _blocked(f: FastenerPoint) -> bool:
	return _first_joint(f) and tractor.blocks_first_joint(FastenerPoint.slot_of(f.joint_id))


func release() -> void:
	tractor.release()
	if _working < 0:
		return
	if _keep():
		bay.hint("Let go. Hold again to carry on from where you stopped.")
		_stop()
		return
	if _working_power():
		_release_power(points[_working])
		_stop()
		return
	if _working_gun():
		bay.hint("Let go before it punched: no rivet set.")
		_stop()
		return
	if not _undoing and points[_working].kind == "bolt" and not _clicked:
		bay.hint("Not torqued yet: hold left click and pull back until it clicks.")
	_stop()


func back_out(tool: StringName) -> void:
	if tool == &"tractor":
		if not tractor.park():
			bay.hint("Right click parks a part you're holding in the beam.")
		return
	if aimed < 0 or _working >= 0:
		return
	var f := points[aimed]
	if not is_tight(f):
		bay.hint("Nothing to take off here.")
		return
	match f.kind:
		"bolt":
			if tool != &"torque_wrench":
				bay.hint("Breaking a bolt loose takes the %s." % _named(&"torque_wrench"))
				return
			# The powered wrench works on left click only, X picking fasten or undo (beenster,
			# 0.3.15).
			if powered() and Flags.is_on("trades.wrench_left_only") and not vs_tools():
				var w := _power()
				bay.hint("The wrench is on left click. %s switches it to %s." % [Keys.prompt(TradesBus.KEY_MODE), "fasten" if w and w.undo else "undo"])
				return
		"rivet":
			if not tool in [&"drill", &"welder", &"cutter"] or not kind_tools("rivet").has(tool):
				bay.hint("Rivets come out with the %s." % " or the ".join(_out_tools("rivet").map(_named)))
				return
		"weld":
			if tool != &"welder":
				bay.hint("Cut a weld out with the %s." % _named(&"welder"))
				return
			if not Flags.is_on("trades.unweld"):
				bay.hint("Cutting welds isn't switched on yet.")
				return
		"connector":
			if tool != &"hands" and tool != &"wire_tool":
				bay.hint("Unplug it with your %s." % _named(&"hands"))
				return
	_begin(true, tool)


## Wheel with the powered wrench on a bolt: its torque setting.
func wheel_setting(tool: StringName, step: int) -> bool:
	if aimed >= 0 and _working < 0 and points[aimed].kind == "rivet" and _gun() and tool == &"rivet_squeezer":
		_gun().step_setting(-step)
		return true
	if tool != &"torque_wrench" or not powered() or aimed < 0 or points[aimed].kind != "bolt" or _working >= 0:
		return false
	var w := _power()
	if Flags.is_on("trades.torque_kept"):
		# Coarse steps on the wheel, fine ones with Ctrl held.
		var fine := Input.is_key_pressed(KEY_CTRL)
		w.set_nm = clampf(w.set_nm - step * (1.0 if fine else TradesPowerWrench.COARSE_STEP_NM),
				TradesPowerWrench.SET_RANGE_NM.x, TradesPowerWrench.SET_RANGE_NM.y)
		w.kept_nm = w.set_nm
		bay.hint("Wrench set to %d N m." % roundi(w.set_nm))
	else:
		w.step_setting(-step)
	return true


## Wheel while the beam holds a part: pull it in or push it out. With trades.wheel_away
## (beenster, 0.3.20: "move an object away on roll mouse up and towards on roll down") wheel
## up (-1) pushes it away.
func turn_held(step: int, _snap: bool) -> bool:
	return tractor.push(-step if Flags.is_on("trades.wheel_away") else step)


## Q / E: turn the part in the beam.
func adjust(step: int) -> bool:
	return tractor.turn(step)


func motion(relative: Vector2) -> bool:
	if tractor.is_holding() and InputMap.has_action(TradesBus.KEY_ROTATE) and Input.is_action_pressed(TradesBus.KEY_ROTATE):
		return tractor.rotate_by(relative)
	if _working < 0 or _undoing or points[_working].kind != "bolt":
		return false
	_pull_px = maxf(0.0, _pull_px + relative.y)
	return true


func update(delta: float) -> void:
	tractor.update(delta)
	_cool_beads(delta)
	if wiring:
		_update_wiring()
		guide.hide_all()
		return
	if _working < 0 and not tractor.is_holding():
		_update_aim()
	_place_marker()
	_update_ring_focus()
	_arc.visible = false
	if _working < 0:
		_update_guide()
		return
	var f := points[_working]
	var at := points_world[_working]
	var n := (ship_xform.basis * f.normal).normalized()
	var hand := bay.worker.right_hand
	if not hand.can_reach(at):
		bay.hint("Too far: step closer to the ship.")
		_stop()
		return
	if _job_key() != "" and bay.aim_distance(_aim_point(_working)) > SLIP_M:
		_keep()
		bay.play(&"clunk", 0.6)
		bay.hint("Slipped off. Aim back at it and hold again to carry on.")
		_stop()
		return
	if not _frozen:
		_run_s += delta
		# The cutter's disc spins up before it bites.
		if _run_s >= _spin_up():
			_held_s += delta
	var bus := bay.bus()
	if _working_power() and vs_tools():
		_work_power_vs(f, at, n, delta)
	elif _working_power():
		_work_power(f, at, n, delta)
	elif _working_gun():
		_work_gun(f, at, n)
	elif f.kind == "rivet" and _undoing and _tool_held in [&"welder", &"cutter"]:
		_work_rivet_out(f, at, n)
	elif f.kind == "bolt" and not _undoing:
		_work_bolt(f, at, n)
	elif f.kind == "weld" and _undoing and vs_tools():
		_work_unweld(f, at, n)
	elif f.kind == "weld" and traces(f):
		_work_trace(f, at, n, delta)
		_update_guide()
	else:
		var need := _seconds(f.kind)
		var tool := _place(f.kind, at, n, clampf(_held_s / need, 0.0, 1.0))
		if tool != &"":
			hand.reach_to(_grip_point(tool, at, n), n)
			hand.set_grip(1.0)
		if bus:
			bus.joint_progress.emit(StringName(f.joint_id), clampf(_held_s / need, 0.0, 1.0))
		if _held_s >= need:
			_finish(f)


func _work_bolt(f: FastenerPoint, at: Vector3, n: Vector3) -> void:
	var nm := torque_range(f.spec)
	var target := (nm.x + nm.y) * 0.5
	var wrench := bay.tool_node(&"torque_wrench") as TradesTorqueWrench
	wrench.set_nm = target
	wrench.applied_nm = _pull_px * NM_PER_PX
	var share := clampf(wrench.applied_nm / target, 0.0, 1.6)
	var xform := _on_surface(at, n, deg_to_rad(35.0 - share * 25.0))
	bay.place_tool(&"torque_wrench", xform)
	bay.worker.right_hand.reach_to(xform * TradesTorqueWrench.GRIP + n * 0.02, n)
	bay.worker.right_hand.set_grip(1.0)
	var bus := bay.bus()
	if bus:
		bus.joint_progress.emit(StringName(f.joint_id), clampf(share, 0.0, 1.0))
	if not _clicked and wrench.applied_nm >= target:
		_clicked = true
		wrench.click()
		bay.play(&"click")
		bay.worker.kick(0.01)
		# Pulled on past the click: the further over the range, the worse the joint.
		var over := maxf(0.0, wrench.applied_nm - nm.y) / maxf(1.0, nm.y)
		_made(f, 1.0 - clampf(over * 4.0, 0.0, 0.5))
		bay.hint("Click. %s torqued to %d N m." % [f.spec, roundi(target)])


# --- The powered wrench ------------------------------------------------------------------

## The powered wrench is the wrench (trades.power_wrench).
static func powered() -> bool:
	return Flags.is_on("trades.power_wrench")


func _power() -> TradesPowerWrench:
	return bay.tool_node(&"torque_wrench") as TradesPowerWrench


## A bolt being worked with the powered wrench.
func _working_power() -> bool:
	return _working >= 0 and points[_working].kind == "bolt" and _tool_held == &"torque_wrench" and _power() != null


## The torque middle of a bolt's spec (N m): what the wrench should be set to.
static func torque_target(spec_id: String) -> float:
	var nm := torque_range(spec_id)
	return (nm.x + nm.y) * 0.5


## Left click with the powered wrench: run the bolt in, or out in undo mode.
func _press_power(f: FastenerPoint, tight: bool) -> void:
	var w := _power()
	if w.undo:
		if tight:
			_begin(true, &"torque_wrench")
		else:
			bay.hint("Nothing to undo: this bolt is out. %s switches the wrench to fasten." % Keys.prompt(TradesBus.KEY_MODE))
	elif tight:
		bay.hint("Already tight. %s switches the wrench to undo." % Keys.prompt(TradesBus.KEY_MODE))
	elif _first_joint(f) and tractor.blocks_first_joint(FastenerPoint.slot_of(f.joint_id)):
		bay.hint("The beam holding this part has it out of line. Its first joint waits until it's in line.")
	else:
		_begin(false, &"torque_wrench")


## Each frame of a run: the motor drives the torque up to the setting, the clutch slips,
## and held on past STRIP_S the thread strips. Undo runs it out. A stall stops it dead.
func _work_power(f: FastenerPoint, at: Vector3, n: Vector3, delta: float) -> void:
	var w := _power()
	var xform := _on_surface(at, n, 0.0)
	bay.place_tool(&"torque_wrench", xform)
	bay.worker.right_hand.reach_to(xform * TradesPowerWrench.POWER_GRIP, n)
	bay.worker.right_hand.set_grip(1.0)
	if w.state == TradesPowerWrench.State.STALLED:
		return
	if _stall_at >= 0.0 and _held_s >= _stall_at:
		w.state = TradesPowerWrench.State.STALLED
		bay.loop(&"impact", false)
		bay.play(&"stall")
		bay.worker.kick(0.006)
		bay.hint("The wrench stalled. Let go and pull the trigger again.")
		return
	var bus := bay.bus()
	if _undoing:
		var out := clampf(_held_s / BREAK_S, 0.0, 1.0)
		w.turned -= delta * 35.0
		w.applied_nm = w.set_nm * (1.0 - out)
		bay.loop(&"impact", true, 0.9)
		if bus:
			bus.joint_progress.emit(StringName(f.joint_id), out)
		if out >= 1.0:
			_finish(f)
		return
	if _clutch_s < 0.0:
		var share := clampf(_held_s / RUN_S, 0.0, 1.0)
		w.applied_nm = w.set_nm * share
		w.turned += delta * 40.0 * (1.0 - share * 0.8)
		bay.loop(&"impact", true, 1.0 + share * 0.25)
		if bus:
			bus.joint_progress.emit(StringName(f.joint_id), share)
		if share >= 1.0:
			_clutch_s = 0.0
			w.state = TradesPowerWrench.State.CLUTCH
			w.click()
			bay.play(&"click")
			bay.worker.kick(0.008)
			bay.hint("Clutch: let go now.")
		return
	# Clutch slipping: it ratchets on the bolt; too long and the thread goes.
	if not _frozen:
		_clutch_s += delta
	w.turned += delta * 4.0
	bay.loop(&"impact", true, 1.6)
	if _clutch_s >= STRIP_S:
		w.state = TradesPowerWrench.State.STRIPPED
		_bolt_made(f, w.set_nm, true)
		bay.play(&"clunk", 0.7)
		bay.hint("Held on too long: the thread stripped. The quality survey will find it.")
		_stop()


## trades.vs_tools: the wrench turns the bolt by itself, out of a tight joint or in to its
## setting on a loose one. It rides up the bolt as it backs out (down as it runs in), the
## shank showing under it; at the setting the clutch clicks and it's done.
func _work_power_vs(f: FastenerPoint, at: Vector3, n: Vector3, delta: float) -> void:
	var w := _power()
	var share := clampf(_held_s / (UNDO_S if _undoing else SPIN_S), 0.0, 1.0)
	# How far the bolt stands out of its hole (0..1).
	var out := share if _undoing else 1.0 - share
	var lift := n * BOLT_TRAVEL_M * out
	var xform := _on_surface(at + lift, n, 0.0)
	bay.place_tool(&"torque_wrench", xform)
	bay.worker.right_hand.reach_to(xform * TradesPowerWrench.POWER_GRIP, n)
	bay.worker.right_hand.set_grip(1.0)
	_show_shank(at, n, BOLT_TRAVEL_M * out)
	if _undoing:
		w.turned -= delta * 30.0
		w.applied_nm = w.set_nm * (1.0 - share) * 0.4
	else:
		w.turned += delta * 30.0 * (1.0 - share * 0.8)
		# The thread bites near the end: the torque climbs to the setting.
		w.applied_nm = w.set_nm * share * share
	bay.loop(&"impact", true, (0.85 if _undoing else 1.0) + share * 0.25)
	var bus := bay.bus()
	if bus:
		bus.joint_progress.emit(StringName(f.joint_id), share)
	if share < 1.0:
		return
	if _undoing:
		_finish(f)
		return
	w.state = TradesPowerWrench.State.CLUTCH
	w.click()
	bay.play(&"click")
	bay.worker.kick(0.008)
	_kept_s.erase(_job_key())
	_bolt_made(f, w.set_nm, false)
	bay.hint("Click: %s in at %d N m." % [f.spec, roundi(w.set_nm)])
	_stop()


## The threaded shank between the joint and the wrench, `length` metres of it (0 hides it).
func _show_shank(at: Vector3, n: Vector3, length: float) -> void:
	_shank.visible = length > 0.002
	if not _shank.visible:
		return
	var x := n.cross(Vector3.UP) if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	x = x.normalized()
	_shank.global_transform = Transform3D(Basis(x, n * length, x.cross(n)), at + n * length * 0.5)


## The job in hand's key for keeping its work when let go ("" for jobs that start over).
func _job_key() -> String:
	if _working < 0 or not vs_tools():
		return ""
	var f := points[_working]
	var keeps := _working_power() or (f.kind == "rivet" and _undoing and _tool_held in [&"welder", &"cutter"]) \
			or (f.kind == "weld" and _undoing and _tool_held == &"welder")
	return "%s:%s" % [f.joint_id, "out" if _undoing else "in"] if keeps else ""


## Keeps the work done on the joint in hand (trades.vs_tools). True if it was kept.
func _keep() -> bool:
	var key := _job_key()
	if key == "":
		return false
	_kept_s[key] = _held_s
	return true


## Seconds the tool in hand runs before it bites: the cutter's disc spinning up.
func _spin_up() -> float:
	return SPIN_UP_S if vs_tools() and _tool_held == &"cutter" else 0.0


## trades.vs_tools: unweld is point and hold. The arc gouges the bead out where you aim it,
## the cut glowing as it spreads both ways along the seam until the weld gives.
func _work_unweld(f: FastenerPoint, at: Vector3, n: Vector3) -> void:
	var progress := clampf(_held_s / UNWELD_S, 0.0, 1.0)
	var p := at
	if traces(f):
		var along := _seam_dir(f, n)
		var half := f.seam_size.x * 0.5
		var s := _seam_offset(f, at, n)
		p = at + along * s
		var bins: PackedByteArray = _traced.get(f.joint_id, PackedByteArray())
		if bins.size() != TRACE_BINS:
			bins.resize(TRACE_BINS)
			bins.fill(0)
		var from: int = _cut_from.get(f.joint_id, clampi(int((s + half) / f.seam_size.x * TRACE_BINS), 0, TRACE_BINS - 1))
		_cut_from[f.joint_id] = from
		var reach := progress * TRACE_BINS
		for k in TRACE_BINS:
			if bins[k] == 0 and absf(k - from) <= reach:
				bins[k] = 1
				_bead(f, at + along * ((k + 0.5) / TRACE_BINS * f.seam_size.x - half), along, n)
		_traced[f.joint_id] = bins
	var torch := _place("weld", p, n, progress)
	if torch != &"":
		bay.worker.right_hand.reach_to(_grip_point(torch, p, n), n)
		bay.worker.right_hand.set_grip(1.0)
	var bus := bay.bus()
	if bus and not is_practice(f):
		bus.joint_progress.emit(StringName(f.joint_id), progress)
	if progress >= 1.0:
		_traced.erase(f.joint_id)
		_cut_from.erase(f.joint_id)
		_finish(f)


## Letting go of the trigger: past the clutch the bolt is in at the setting; before it, not.
func _release_power(f: FastenerPoint) -> void:
	var w := _power()
	if _undoing or w.state == TradesPowerWrench.State.STALLED:
		return
	if _clutch_s >= 0.0:
		_bolt_made(f, w.set_nm, false)
		bay.play(&"clunk", 1.2)
		bay.hint("%s in at %d N m." % [f.spec, roundi(w.set_nm)])
	else:
		bay.hint("Let go before the clutch: not tight yet.")


## A bolt in at `nm` (stripped or not): the ship's quality figure and Quality's readings.
func _bolt_made(f: FastenerPoint, nm: float, stripped: bool) -> void:
	var spec := torque_range(f.spec)
	var target := torque_target(f.spec)
	var off := maxf(spec.x - nm, nm - spec.y) / maxf(target, 1.0)
	var quality := 1.0 - clampf(off * 3.0, 0.0, 0.7) if off > 0.0 else 1.0
	if stripped:
		quality = minf(quality, 0.15)
	_made(f, quality)
	_report(f, &"BOLT", {"torque_nm": [nm], "torque_target_nm": target, "sequence_ok": true,
			"cross_threaded": [stripped], "stripped_thread": [stripped], "washer": [true],
			"needs_washer": false, "fastener_ids": [f.spec], "fastener_spec_id": f.spec})


## Tells Quality (through Tools' joint_completed) what was built on the ship.
func _report(f: FastenerPoint, trade: StringName, measurements: Dictionary) -> void:
	var bus := bay.bus()
	if bus == null or is_practice(f) or is_rig(f):
		return
	var site := JointSite.new()
	site.joint_id = StringName(f.joint_id)
	site.component_id = StringName(_bus.get_component(FastenerPoint.slot_of(f.joint_id)))
	site.mount_id = StringName(FastenerPoint.slot_of(f.joint_id))
	site.spec = JointSpec.new()
	site.spec.trade = trade
	bus.complete_joint(site, measurements)
	site.free()


# --- The rivet gun, heating rivets out, the cutter --------------------------------------------

## The tools that work a kind of joint: the rivet's grow the welder (trades.rivet_heat) and
## the cutter (trades.cutter, when it's on the hotbar).
func kind_tools(kind: String) -> Array:
	var out: Array = (KIND_TOOLS.get(kind, []) as Array).duplicate()
	if kind == "rivet":
		if Flags.is_on("trades.rivet_heat"):
			out.append(&"welder")
		out.append(&"cutter")
	# Only what's on the hotbar (trades.slim_hotbar leaves the drill, crimper and cutter off).
	return out.filter(func(t: StringName) -> bool: return bay.hotbar.has(t))


## The tools that take a made joint of `kind` off.
func _out_tools(kind: String) -> Array:
	if kind == "rivet":
		return kind_tools(kind).filter(func(t: StringName) -> bool: return t != &"rivet_squeezer")
	return kind_tools(kind)


## Which tools work a kind of joint, for hints and the inspect sheet: "rivet gun (3) to set,
## welder (4) to take out".
func kind_help(kind: String) -> String:
	match kind:
		"rivet":
			return "%s to set, %s to take out" % [_named(&"rivet_squeezer"), " or ".join(_out_tools(kind).map(_named))]
		"weld":
			if vs_tools():
				return "%s: hold left click along the seam to weld it; hold it on a weld to cut it out" % _named(&"welder")
			return "%s: left click welds; %s switches it to unweld, which cuts welds out" \
					% [_named(&"welder"), Keys.key_name(TradesBus.KEY_MODE)]
	return " or ".join(kind_tools(kind).map(_named))


## A tool's name and key: "welder (4)".
func _named(tool: StringName) -> String:
	return "%s (%s)" % [TradesBay.label_of(tool).to_lower(), bay.tool_key(tool)]


func _torch() -> TradesWeldTorch:
	return bay.tool_node(&"welder") as TradesWeldTorch


func _gun() -> TradesRivetGun:
	return bay.tool_node(&"rivet_squeezer") as TradesRivetGun


## A rivet being set with the powered rivet gun.
func _working_gun() -> bool:
	return _working >= 0 and not _undoing and points[_working].kind == "rivet" and _tool_held == &"rivet_squeezer" and _gun() != null


## The air builds to the punch: bang, jolt, and the rivet is in at the gun's head setting.
func _work_gun(f: FastenerPoint, at: Vector3, n: Vector3) -> void:
	var gun := _gun()
	var xform := _on_surface(at, n, 0.0)
	bay.place_tool(&"rivet_squeezer", xform)
	bay.worker.right_hand.reach_to(xform * TradesRivetGun.GRIP, n)
	bay.worker.right_hand.set_grip(1.0)
	gun.pressure = clampf(_held_s / PRESS_S, 0.0, 1.0)
	bay.loop(&"pressure", true, 0.7 + gun.pressure * 0.8)
	var bus := bay.bus()
	if bus:
		bus.joint_progress.emit(StringName(f.joint_id), gun.pressure)
	if gun.pressure < 1.0:
		return
	gun.punch()
	bay.play(&"punch")
	bay.worker.kick(0.03)
	_rivet_made(f, gun.set_mm)
	bay.hint("Punched: head %.1f mm." % gun.set_mm)
	_stop()


## A rivet set with its head standing `mm` out: the ship's quality figure and Quality's readings.
func _rivet_made(f: FastenerPoint, mm: float) -> void:
	var target := head_target_mm(f.spec)
	var off := absf(mm - target) / maxf(target, 0.1)
	var quality := 1.0 - clampf((off - 0.1) * 2.0, 0.0, 0.8)
	_made(f, quality)
	var dia := target * 3.0
	_report(f, &"RIVET", {"head_height_mm": [mm], "head_height_target_mm": target,
			"head_dia_mm": [dia], "head_dia_target_mm": dia, "hole_fit_mm": [0.0],
			"deburred": [true], "seated": [true], "cracked_head": [false], "fastener_spec_id": f.spec})


## Heating a rivet with the welder till it pops out, or grinding its head off with the cutter:
## sparks fly, and the rivet (or its head) jumps off when it gives.
func _work_rivet_out(f: FastenerPoint, at: Vector3, n: Vector3) -> void:
	var heat := _tool_held == &"welder"
	var need := HEAT_S if heat else GRIND_S
	var progress := clampf(_held_s / need, 0.0, 1.0)
	var sparks := bay.sparks
	if heat:
		_place(f.kind, at, n, progress)
		bay.worker.right_hand.reach_to(_grip_point(&"welder", at, n), n)
		if sparks:
			sparks.emit(at + n * 0.004, n, SPARKS_HEAT, 1.8, 0.9)
	else:
		var cutter := bay.tool_node(&"cutter") as TradesCutter
		cutter.ground = progress
		var xform := _on_surface(at, n, 0.0)
		bay.place_tool(&"cutter", xform)
		bay.worker.right_hand.reach_to(xform * TradesCutter.GRIP, n)
		if vs_tools():
			# The disc whines up to speed, then the note drops as it bites into the head.
			cutter.spin = clampf(_run_s / SPIN_UP_S, 0.0, 1.0)
			cutter.biting = _run_s >= SPIN_UP_S
			if cutter.biting:
				bay.loop(&"grind", true, 0.82 + randf() * 0.06)
				bay.worker.kick(0.0015)
			else:
				bay.loop(&"grind", true, 0.6 + cutter.spin * 0.6)
		else:
			cutter.spin = 1.0
			bay.loop(&"grind", true, 0.95 + randf() * 0.1)
		if sparks:
			# Off the disc's edge, down along the surface.
			var down := Vector3.DOWN - n * n.dot(Vector3.DOWN)
			if down.length() < 0.1:
				down = xform.basis.z
			sparks.emit(at + n * 0.003, down.normalized() + n * 0.35, SPARKS_GRIND, 4.5, 0.3)
	bay.worker.right_hand.set_grip(1.0)
	var bus := bay.bus()
	if bus:
		bus.joint_progress.emit(StringName(f.joint_id), progress)
	if progress < 1.0:
		return
	if sparks:
		var kind := "rivet_hot" if heat else "rivet"
		var vel := n * (2.0 if heat else 1.0) + Vector3.UP * 1.5
		pop_part(kind, at + n * 0.01, vel)
		if bay.crew:
			bay.crew.share_pop(kind, at + n * 0.01, vel)
	bay.play(&"pop" if heat else &"clunk", 1.3)
	_finish(f)


# --- Doing the work -------------------------------------------------------------------------

func _begin(undo: bool, tool: StringName) -> void:
	if aimed >= 0 and from_end(points[aimed]) and not (undo and vs_tools()) and not _at_start(aimed):
		bay.hint("Start at one end of the seam, at the ring, and run the arc along it.")
		return
	_working = aimed
	_trace_last = NAN
	_trace_s = NAN
	_pace_word = ""
	_speed_mm_s = 0.0
	_undoing = undo
	_tool_held = tool
	_held_s = 0.0
	_run_s = 0.0
	_pull_px = 0.0
	_clicked = false
	_held_s = _kept_s.get(_job_key(), 0.0)
	bay.worker.look_locked = points[_working].kind == "bolt" and not undo and not (vs_tools() and _working_power())
	if _working_power():
		var w := _power()
		w.state = TradesPowerWrench.State.RUNNING
		w.applied_nm = 0.0
		_clutch_s = -1.0
		_stall_at = randf_range(0.15, 0.85) * (BREAK_S if undo else RUN_S) if randf() < STALL_CHANCE else -1.0
		if vs_tools():
			# Nothing stalls; the display shows which way it's turning.
			_stall_at = -1.0
			w.undo = undo
	var bus := bay.bus()
	if bus and not undo and not is_practice(points[_working]):
		bus.joint_started.emit(StringName(points[_working].joint_id), StringName(points[_working].kind), 1)
	match points[_working].kind:
		"bolt":
			if _working_power() and vs_tools():
				bay.hint("Backing it out..." if undo else "Running it in to %d N m..." % roundi(_power().set_nm))
			elif _working_power():
				bay.hint("Undoing..." if undo else "Running it in: let go when the clutch slips.")
			else:
				bay.hint("Breaking it loose..." if undo else "Pull the mouse back until the wrench clicks.")
		"rivet":
			if _working_gun():
				bay.hint("Pressure building...")
			elif undo and _tool_held == &"welder":
				bay.hint("Heating the rivet...")
			elif undo and _tool_held == &"cutter":
				bay.hint("Grinding the head off...")
			else:
				bay.hint("Drilling it out..." if undo else "Squeezing...")
		"weld":
			if undo and vs_tools():
				bay.hint("Cutting the weld out: keep the arc on it...")
			elif traces(points[_working]) and weld_skill() and not undo:
				bay.hint("Run the arc along the line at a steady pace: too fast won't take, too slow burns.")
			elif traces(points[_working]):
				bay.hint("Run the arc along the seam to cut it out." if undo else "Run the arc along the seam, end to end.")
			else:
				bay.hint("Cutting the weld out..." if undo else "Laying the bead...")
		"connector":
			bay.hint("Unplugging..." if undo else "Plugging in...")


func _finish(f: FastenerPoint) -> void:
	_kept_s.erase(_job_key())
	if _undoing:
		if _note_removed(f):
			if _looms.has(f.joint_id):
				(_looms[f.joint_id] as TradesWireLoom).tested = false
			var bus := bay.bus()
			if bus and not is_practice(f):
				bus.remove_joint(StringName(f.joint_id))
			bay.play(&"clunk", 1.1)
			bay.hint("%s off.%s" % [f.kind.capitalize(), " The part is free." if _slot_empty(f) else ""])
	else:
		_made(f, 1.0)
		bay.play(&"clunk" if f.kind != "connector" else &"click")
	_stop()


func _made(f: FastenerPoint, quality: float) -> void:
	if not _note_made(f, quality):
		return
	if is_practice(f):
		# No Quality on the test stand, so the hint grades it.
		var how := "spot on" if quality >= 0.95 else ("near enough" if quality >= 0.6 else "poor: take it off and try again")
		bay.hint("%s done, %s." % [f.kind.capitalize(), how])
	elif f.kind != "bolt":
		bay.hint("%s done." % f.kind.capitalize())


## Hands put a part that came off back in its slot.
func _refit(f: FastenerPoint) -> void:
	var slot_id := FastenerPoint.slot_of(f.joint_id)
	if not tractor.near_mount(slot_id):
		bay.hint("The part isn't at its mount. Bring it back with the %s." % _named(&"tractor"))
		return
	var comp: String = _removed.get(slot_id, "")
	if comp == "":
		var slot := _bus.get_slot(slot_id)
		comp = slot.fitted if slot else ""
	if comp != "" and _bus.try_position(slot_id, comp):
		bay.play(&"clunk", 0.8)
		bay.hint("Part back in place. Fasten its joints to install it.")
	else:
		bay.hint("Nothing to put back here.")


func _stop() -> void:
	_frozen = false
	_working = -1
	_undoing = false
	_pull_px = 0.0
	for id: StringName in [&"drill", &"welder"]:
		var t := bay.tool_node(id)
		if t is TradesDrill:
			(t as TradesDrill).spin = 0.0
		elif t is TradesWeldTorch:
			(t as TradesWeldTorch).lit = false
			(t as TradesWeldTorch).cutting = false
	var squeezer := bay.tool_node(&"rivet_squeezer") as TradesRivetSqueezer
	if squeezer:
		squeezer.closed = 0.0
	var gun := bay.tool_node(&"rivet_squeezer") as TradesRivetGun
	if gun:
		gun.pressure = 0.0
	var cutter := bay.tool_node(&"cutter") as TradesCutter
	if cutter:
		cutter.spin = 0.0
		cutter.ground = 0.0
		cutter.biting = false
	if _shank:
		_shank.visible = false
	var torch := _torch()
	if torch:
		torch.speed_mm_s = -1.0
	bay.loop(&"pressure", false)
	bay.loop(&"grind", false)
	var wrench := bay.tool_node(&"torque_wrench") as TradesTorqueWrench
	if wrench:
		wrench.applied_nm = 0.0
	if wrench is TradesPowerWrench and (wrench as TradesPowerWrench).state != TradesPowerWrench.State.STRIPPED:
		(wrench as TradesPowerWrench).state = TradesPowerWrench.State.READY
	if wrench is TradesPowerWrench and vs_tools():
		(wrench as TradesPowerWrench).undo = false
	bay.loop(&"impact", false)
	bay.loop(&"drill", false)
	bay.loop(&"arc", false)
	if bay.worker:
		bay.worker.look_locked = false
		bay.worker.right_hand.come_back()
		bay.worker.left_hand.come_back()


func _seconds(kind: String) -> float:
	if _undoing:
		return {"bolt": BREAK_S, "rivet": DRILL_S, "weld": CUT_S, "connector": PLUG_S}.get(kind, 1.0)
	return {"rivet": SQUEEZE_S, "weld": WELD_S, "connector": PLUG_S}.get(kind, 1.0)


## Puts the tool in use on the joint (progress 0..1) and returns its id ("" for hands).
func _place(kind: String, at: Vector3, n: Vector3, progress: float) -> StringName:
	match _tool_held:
		&"torque_wrench":
			bay.place_tool(&"torque_wrench", _on_surface(at, n, deg_to_rad(35.0 + progress * 30.0)))
			return &"torque_wrench"
		&"drill":
			var drill := bay.tool_node(&"drill") as TradesDrill
			drill.spin = 1.0
			bay.loop(&"drill", true)
			bay.place_tool(&"drill", _on_surface(at - n * progress * 0.006, n, 0.0))
			return &"drill"
		&"rivet_squeezer":
			(bay.tool_node(&"rivet_squeezer") as TradesRivetSqueezer).closed = progress
			bay.place_tool(&"rivet_squeezer", _on_surface(at, n, 0.0))
			return &"rivet_squeezer"
		&"welder":
			var torch := bay.tool_node(&"welder") as TradesWeldTorch
			torch.lit = true
			torch.on_rivet = kind == "rivet"
			torch.arc_mm = 3.0
			torch.cutting = _undoing
			torch.cut = progress if _undoing else 0.0
			var xform := _on_surface(at, n, TORCH_TURN) * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(TORCH_TILT_DEG)))
			bay.place_tool(&"welder", xform)
			bay.loop(&"arc", true, 0.9 + randf() * 0.2)
			_arc.global_position = at + n * 0.05
			# Dimmer on a seam, so the plate round it doesn't flare out the bead under the
			# shield (trades.weld_from_end).
			if kind == "weld" and Flags.is_on("trades.weld_from_end"):
				var shield := 0.0 if bay.worker.third_person else bay.helmet_down()
				_arc.light_energy = (0.45 + randf() * 0.25) * (1.0 - shield * 0.85)
			else:
				_arc.light_energy = 1.8 + randf() * 1.0
			_arc.visible = true
			# A shower off the arc (beenster, 0.3.7): falling, bouncing, fading. Cutting throws more.
			if bay.sparks and Flags.is_on("trades.molten"):
				# Thrown out and down off the puddle rather than straight back at you, so the
				# bead shows (beenster, 0.3.15).
				bay.sparks.emit_weld(at + n * 0.01, n + Vector3.DOWN * 0.7, weld_sparks(_undoing), 3.2, 0.7)
			elif bay.sparks:
				bay.sparks.emit(at + n * 0.01, n, SPARKS_CUT if _undoing else SPARKS_WELD, 3.2, 0.8)
			return &"welder"
		&"wire_tool":
			bay.place_tool(&"wire_tool", _on_surface(at, n, 0.0))
			return &"wire_tool"
	# Hands on the plug.
	bay.worker.right_hand.reach_to(at + n * 0.01, n)
	bay.worker.right_hand.set_grip(0.4 + 0.6 * progress)
	return &""


## Tools sit on the work with +Y out of the surface and their handle (+Z) turned back
## toward the worker, then `turn` radians further round the normal.
func _on_surface(at: Vector3, n: Vector3, turn: float) -> Transform3D:
	var back := bay.worker.global_position + Vector3(0, 1.2, 0) - at
	back -= n * back.dot(n)
	if back.length() < 0.01:
		back = n.cross(Vector3.RIGHT) if absf(n.dot(Vector3.RIGHT)) < 0.9 else n.cross(Vector3.FORWARD)
	var z := back.normalized().rotated(n, turn)
	return Transform3D(Basis(n.cross(z), n, z).orthonormalized(), at)


func _grip_point(tool: StringName, at: Vector3, n: Vector3) -> Vector3:
	var t := bay.tool_node(tool)
	return t.global_transform * t.grip + n * 0.015 if t else at


# --- Inspect (hold Tab) ---------------------------------------------------------------------

const SLOT_STATES := {
	ShipBayBus.SlotState.FITTED: "FITTED", ShipBayBus.SlotState.LOOSENED: "LOOSENED",
	ShipBayBus.SlotState.EMPTY: "OFF THE SHIP", ShipBayBus.SlotState.POSITIONED: "IN PLACE, NOT FASTENED",
	ShipBayBus.SlotState.INSTALLED: "INSTALLED",
}


## The part (and joint) under the aim: a loose part, the part a joint holds on, or a part on
## the ship the aim passes through.
func inspect_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var joint: FastenerPoint = points[aimed] if aimed >= 0 else null
	if joint and is_practice(joint):
		return _practice_lines(joint)
	if _bus == null:
		return lines
	var loose := tractor.held if tractor.held else tractor.aimed_part(Flags.is_on("trades.part_info"))
	var slot_id := ""
	if loose:
		slot_id = loose.slot_id
	elif joint:
		slot_id = FastenerPoint.slot_of(joint.joint_id)
	else:
		slot_id = tractor.aimed_slot()
	var slot := _bus.get_slot(slot_id) if slot_id != "" else null
	if slot == null:
		return lines
	var comp := _bus.get_component(slot_id)
	if comp == "":
		comp = loose.component if loose else String(_removed.get(slot_id, slot.fitted))
	var spec := _build_spec(comp)
	var title := slot.display_name if slot.display_name != "" else slot_id
	if spec and str(spec.get("display_name")) != "":
		title = str(spec.get("display_name"))
	lines.append(title.to_upper())
	lines.append("%-9s %s" % ["PART", comp if comp != "" else "-"])
	lines.append("%-9s %s" % ["SLOT", slot_id])
	lines.append("%-9s %s" % ["STATE", SLOT_STATES.get(_bus.get_slot_state(slot_id), "-")])
	var size := slot.box.size
	var mass := float(spec.get("mass")) if spec else 0.0
	if mass > 0.0:
		lines.append("%-9s %s" % ["MASS", _kg(mass)])
	else:
		lines.append("%-9s %s (est.)" % ["MASS", _kg(maxf(5.0, size.x * size.y * size.z * TradesLoosePart.DENSITY))])
	lines.append("%-9s %.2f x %.2f x %.2f m" % ["SIZE", size.x, size.y, size.z])
	if spec and str(spec.get("material")) != "":
		lines.append("%-9s %s" % ["MATERIAL", str(spec.get("material"))])
	# The joints holding it on, by kind and spec, and how many are in.
	var groups := {}
	for f in slot.fasteners:
		var key := "%s %s" % [f.kind, f.spec]
		var g: Array = groups.get_or_add(key, [0, 0, f])
		g[0] += 1
		if _bus.is_joint_tight(f.joint_id):
			g[1] += 1
	var first := true
	for key: String in groups:
		var g: Array = groups[key]
		var f: FastenerPoint = g[2]
		var what := "%d %s%s %s, %d in" % [g[0], f.kind, "" if g[0] == 1 else "s", f.spec, g[1]]
		if f.kind == "bolt":
			var nm := torque_range(f.spec)
			what += " (%d-%d N m)" % [roundi(nm.x), roundi(nm.y)]
		lines.append("%-9s %s" % ["JOINTS" if first else "", what])
		first = false
	if groups.is_empty():
		lines.append("%-9s none" % "JOINTS")
	if loose:
		var where := "in your beam" if loose == tractor.held else "hovering"
		if tractor.to_trolley.has(slot_id):
			where = "waiting for a trolley"
		if loose.riding:
			where = "on a trolley"
		elif not loose.freeze and loose != tractor.held:
			where = "lying loose"
		lines.append("%-9s %s" % ["NOW", where])
		if Flags.is_on("trades.part_info"):
			lines.append("%-9s %d%%" % ["CONDITION", roundi(loose.condition * 100.0)])
	if joint:
		lines.append("")
		lines.append("%-9s %s  %s %s  %s" % ["JOINT", joint.joint_id, joint.spec, joint.kind, _state_word(joint)])
		lines.append("%-9s %s" % ["TOOL", kind_help(joint.kind)])
	if not slot.accepts.is_empty():
		lines.append("%-9s %s" % ["TAKES", ", ".join(slot.accepts)])
	return lines


## The test stand's sheet: what's on it, how many of each are in, and the joint you're on.
func _practice_lines(joint: FastenerPoint) -> PackedStringArray:
	var lines := PackedStringArray(["TOOL TEST STAND"])
	var all := test_stand.joints if test_stand else ([] as Array[FastenerPoint])
	if is_unit(joint) and unit:
		# An opened unit's mount: what goes there, and the unit it's in.
		var mount := unit.mount_of(joint.joint_id)
		lines = PackedStringArray([_component_of(joint).to_upper()])
		lines.append("%-9s %s" % ["UNIT", unit.unit_id if unit.unit_id != "" else "-"])
		lines.append("%-9s %s" % ["MOUNT", mount])
		lines.append("%-9s %s" % ["STATE", "open" if unit.is_open() else "closed"])
		all = unit.mount_joints(mount)
	else:
		lines.append("%-9s %s" % ["PART", "Test panel (practice only)"])
		lines.append("%-9s %s" % ["SLOT", TradesTestStand.SLOT])
	var groups := {}
	for f in all:
		var g: Array = groups.get_or_add("%s %s" % [f.kind, f.spec], [0, 0, f])
		g[0] += 1
		if practice.get(f.joint_id, false):
			g[1] += 1
	var first := true
	for key: String in groups:
		var g: Array = groups[key]
		var f: FastenerPoint = g[2]
		lines.append("%-9s %d %s%s %s, %d in" % ["JOINTS" if first else "", g[0], f.kind, "" if g[0] == 1 else "s", f.spec, g[1]])
		first = false
	lines.append("")
	lines.append("%-9s %s  %s %s  %s" % ["JOINT", joint.joint_id, joint.spec, joint.kind, _state_word(joint)])
	lines.append("%-9s %s" % ["TOOL", kind_help(joint.kind)])
	return lines


## Shared Components' build spec for a component (mass, material, name), or null. Reached
## untyped: Shared Components is optional here.
## A part that isn't on this ship, by its catalogue id (trades.part_info: anything in the game
## carrying meta "component", on its collider or a parent; "condition" 0..1, "name" and
## "mass_kg" when it knows them): its name, then key details. Empty without a component.
static func component_lines(node: Node) -> PackedStringArray:
	var lines := PackedStringArray()
	var n := node
	while n != null and not n.has_meta("component"):
		n = n.get_parent()
	if n == null or str(n.get_meta("component")) == "":
		return lines
	var comp := str(n.get_meta("component"))
	var spec := _build_spec(comp)
	var stored := _storage_item(comp)
	var title := str(n.get_meta("name", ""))
	if title == "":
		title = str(spec.get("display_name")) if spec and str(spec.get("display_name")) != "" \
				else str(stored.get("name", comp))
	lines.append(title.to_upper())
	lines.append("%-9s %s" % ["PART", comp])
	var mass := float(n.get_meta("mass_kg", 0.0))
	if mass <= 0.0 and spec:
		mass = float(spec.get("mass"))
	if mass <= 0.0:
		mass = float(stored.get("mass", 0.0))
	if mass > 0.0:
		lines.append("%-9s %s" % ["MASS", _kg(mass)])
	if spec and str(spec.get("material")) != "":
		lines.append("%-9s %s" % ["MATERIAL", str(spec.get("material"))])
	if spec and str(spec.get("category")) != "":
		lines.append("%-9s %s" % ["KIND", str(spec.get("category"))])
	if n.has_meta("condition"):
		lines.append("%-9s %d%%" % ["CONDITION", roundi(clampf(float(n.get_meta("condition")), 0.0, 1.0) * 100.0)])
	if spec and spec.get("joints") is Array and not (spec.get("joints") as Array).is_empty():
		lines.append("%-9s %d" % ["JOINTS", (spec.get("joints") as Array).size()])
	return lines


## Ship and Bay's stores entry for an item ({name, mass, ...}; {} for none), for goods the
## shared catalogue doesn't describe (a bowser tank on a trolley). Read once, then kept.
static var _stored: Dictionary = {}
static func _storage_item(component: String) -> Dictionary:
	if _stored.is_empty():
		var bay_bus := Modules.bus("ship_bay") as ShipBayBus
		if bay_bus:
			_stored = bay_bus.storage_items()
	return _stored.get(component, {})


static func _build_spec(component: String) -> Object:
	var shared: Node = Modules.bus("shared_components")
	if component == "" or shared == null or not shared.has_method("build_spec"):
		return null
	return shared.call("build_spec", component)


static func _kg(kg: float) -> String:
	return "%d kg" % roundi(kg) if kg < 1000.0 else "%.1f t" % (kg / 1000.0)


# --- Welding by tracing the seam (beenster, 0.3.14) -----------------------------------------

## How many stretches a seam is traced in, how near the aim has to pass the seam line
## (metres), and how long a fresh bead takes to cool from orange (seconds).
const TRACE_BINS := 12
const TRACE_M := 0.05
const BEAD_COOL_S := 7.0
## With trades.weld_from_end a fresh bead cools to grey metal and stays this long (s), so
## you can see the line you've laid and carry on from its end.
const BEAD_KEEP_S := 25.0


## Whether this weld is laid (and cut out) by running the arc along its seam rather than
## holding still on it.
func traces(f: FastenerPoint) -> bool:
	return f.kind == "weld" and f.seam_size.x > 0.0 and Flags.is_on("trades.trace_weld")


## Whether a traced weld has to be started from an end of its seam, or from the end of the
## bead already laid (beenster, 0.3.15: "you will always start a weld or unweld from the end").
func from_end(f: FastenerPoint) -> bool:
	return traces(f) and Flags.is_on("trades.weld_from_end")


## How near a seam's end (or the bead's) the aim has to be to strike the arc (metres).
const START_M := 0.035


## Where along a traced weld's seam an arc may be struck (metres from its middle): its two
## ends, and the ends of any stretch already covered this time round.
func start_points(f: FastenerPoint) -> PackedFloat32Array:
	var half := f.seam_size.x * 0.5
	var out := PackedFloat32Array([-half, half])
	var bins: PackedByteArray = _traced.get(f.joint_id, PackedByteArray())
	var step := f.seam_size.x / maxf(1.0, bins.size())
	for k in bins.size():
		if bins[k] == 1 and (k == 0 or bins[k - 1] == 0):
			out.append(k * step - half)
		if bins[k] == 1 and (k == bins.size() - 1 or bins[k + 1] == 0):
			out.append((k + 1) * step - half)
	return out


## The start point nearest the aim on joint i (metres from the seam's middle).
func nearest_start(i: int) -> float:
	var f := points[i]
	var n := (ship_xform.basis * f.normal).normalized()
	var s := _seam_offset(f, points_world[i], n)
	var best := 0.0
	var best_d := INF
	for p in start_points(f):
		if absf(p - s) < best_d:
			best_d = absf(p - s)
			best = p
	return best


func _at_start(i: int) -> bool:
	var f := points[i]
	var n := (ship_xform.basis * f.normal).normalized()
	var s := _seam_offset(f, points_world[i], n)
	return absf(nearest_start(i) - s) <= maxf(START_M, f.seam_size.x * 0.08)


## How much of a traced weld's seam has been covered this time round (0..1).
func trace_progress(f: FastenerPoint) -> float:
	var bins: PackedByteArray = _traced.get(f.joint_id, PackedByteArray())
	if bins.is_empty():
		return 0.0
	return float(bins.count(1)) / bins.size()


## The seam's direction (world), across the surface.
func _seam_dir(f: FastenerPoint, n: Vector3) -> Vector3:
	var along := ship_xform.basis * f.seam_up
	return (along - n * along.dot(n)).normalized()


## How far along a seam (metres from its middle, clamped to its ends) the aim line passes
## closest.
func _seam_offset(f: FastenerPoint, at: Vector3, n: Vector3) -> float:
	var along := _seam_dir(f, n)
	var half := f.seam_size.x * 0.5
	var w := at - bay.worker.aim_origin()
	var d := bay.worker.aim_dir()
	var b := along.dot(d)
	var denom := 1.0 - b * b
	var s := (b * d.dot(w) - along.dot(w)) / denom if absf(denom) > 0.0001 else 0.0
	return clampf(s, -half, half)


## Where the aim is judged against a joint: its point, or for a traced weld the nearest
## point of its seam, so the aim stays on it all the way along.
func _aim_point(i: int) -> Vector3:
	var f := points[i]
	if not traces(f):
		return points_world[i]
	var n := (ship_xform.basis * f.normal).normalized()
	return points_world[i] + _seam_dir(f, n) * _seam_offset(f, points_world[i], n)


## The arc follows your aim along the seam: wherever the aim line passes within TRACE_M of
## the seam, that stretch is covered (and every stretch between it and the last, so a quick
## sweep doesn't skip any). All of it covered and the weld is made, or cut out.
func _work_trace(f: FastenerPoint, at: Vector3, n: Vector3, delta := 0.0) -> void:
	var along := _seam_dir(f, n)
	var half := f.seam_size.x * 0.5
	var s := _seam_offset(f, at, n)
	var p := at + along * s
	var on := bay.aim_distance(p) < TRACE_M
	var bins: PackedByteArray = _traced.get(f.joint_id, PackedByteArray())
	if bins.size() != TRACE_BINS:
		bins.resize(TRACE_BINS)
		bins.fill(0)
	var bin := clampi(int((s + half) / f.seam_size.x * TRACE_BINS), 0, TRACE_BINS - 1)
	var skill := weld_skill() and not _undoing
	if on:
		var from := bin if is_nan(_trace_last) else int(_trace_last)
		if skill:
			_lay(f, bins, mini(from, bin), maxi(from, bin), delta, bay.aim_distance(p), at, along, n)
		else:
			for k in range(mini(from, bin), maxi(from, bin) + 1):
				if bins[k] == 0:
					bins[k] = 1
					_bead(f, at + along * ((k + 0.5) / TRACE_BINS * f.seam_size.x - half), along, n)
		_trace_last = bin
	else:
		_trace_last = NAN
	_traced[f.joint_id] = bins
	if skill:
		_pace(f, s, bin, on, delta)
	var progress := trace_progress(f)
	var torch := _place("weld", p, n, progress)
	_arc.visible = on
	if not on:
		(bay.tool_node(&"welder") as TradesWeldTorch).lit = false
		bay.loop(&"arc", false)
		bay.hint("Run the arc along the seam: follow the line with your aim.")
		_pace_word = ""
	if torch != &"":
		bay.worker.right_hand.reach_to(_grip_point(torch, p, n), n)
		bay.worker.right_hand.set_grip(1.0)
	var bus := bay.bus()
	if bus and not is_practice(f):
		bus.joint_progress.emit(StringName(f.joint_id), progress)
	if progress >= 1.0 and skill:
		_traced.erase(f.joint_id)
		bay.play(&"clunk")
		_weld_made(f)
		_stop()
	elif progress >= 1.0:
		_traced.erase(f.joint_id)
		_finish(f)


## Seconds the arc should spend on each stretch of a seam at the speed a weld wants.
func _ideal_dwell(f: FastenerPoint) -> float:
	return f.seam_size.x / TRACE_BINS / (WELD_SPEED_MM_S / 1000.0)


## trades.weld_skill: the arc over stretches lo..hi this frame (more than one when it moves
## fast, sharing the frame between them). A stretch takes once the arc has stayed on it long
## enough; its bead swells the longer it stays.
func _lay(f: FastenerPoint, bins: PackedByteArray, lo: int, hi: int, delta: float, off_m: float,
		at: Vector3, along: Vector3, n: Vector3) -> void:
	var dwell: PackedFloat32Array = _dwell.get(f.joint_id, PackedFloat32Array())
	var off: PackedFloat32Array = _off.get(f.joint_id, PackedFloat32Array())
	if dwell.size() != TRACE_BINS:
		dwell.resize(TRACE_BINS)
		dwell.fill(0.0)
		off.resize(TRACE_BINS)
		off.fill(0.0)
	var beads: Dictionary = _bin_beads.get(f.joint_id, {})
	var ideal := _ideal_dwell(f)
	var share := delta / (hi - lo + 1)
	for k in range(lo, hi + 1):
		dwell[k] += share
		off[k] += share * off_m
		var r := dwell[k] / ideal
		if bins[k] == 0 and r >= TAKE_R:
			bins[k] = 1
			beads[k] = _bead(f, at + along * ((k + 0.5) / TRACE_BINS - 0.5) * f.seam_size.x, along, n)
		var bead: MeshInstance3D = beads.get(k)
		if is_instance_valid(bead):
			var fat := clampf(sqrt(r), 0.7, 1.8)
			bead.scale = Vector3(fat, 1.0, fat)
	_dwell[f.joint_id] = dwell
	_off[f.joint_id] = off
	_bin_beads[f.joint_id] = beads


## trades.weld_skill: the travel speed along the seam (shown on the torch), and a word when
## the pace changes: too fast and the bead doesn't take, too slow and it piles up and burns.
func _pace(f: FastenerPoint, s: float, bin: int, on: bool, delta: float) -> void:
	var torch := _torch()
	if not on or delta <= 0.0:
		_trace_s = NAN
		if torch:
			torch.speed_mm_s = -1.0
		return
	if not is_nan(_trace_s):
		var v := absf(s - _trace_s) / delta * 1000.0
		_speed_mm_s = lerpf(_speed_mm_s, v, 1.0 - exp(-delta / 0.25))
	_trace_s = s
	if torch:
		torch.speed_mm_s = _speed_mm_s
	var dwell: PackedFloat32Array = _dwell.get(f.joint_id, PackedFloat32Array())
	var r := dwell[bin] / _ideal_dwell(f) if bin < dwell.size() else 0.0
	var word := "good"
	if _speed_mm_s > WELD_SPEED_MM_S / TAKE_R:
		word = "fast"
	elif r > SLOW_R:
		word = "slow"
	if word == _pace_word:
		return
	_pace_word = word
	match word:
		"fast":
			bay.hint("Too fast: slow down, the bead isn't taking.")
		"slow":
			bay.hint("Too slow: keep moving or it burns through.")
		_:
			bay.hint("Steady. Good bead.")


## How good a stretch of bead is from how long the arc stayed on it (r: share of the time
## the right speed gives) and how far off the line it ran (mm).
static func bin_quality(r: float, off_mm: float) -> float:
	var q := 1.0
	if r < GOOD_R:
		q = lerpf(0.55, 1.0, clampf((r - TAKE_R) / (GOOD_R - TAKE_R), 0.0, 1.0))
	elif r >= BURN_R:
		q = 0.1
	elif r > SLOW_R:
		q = lerpf(1.0, 0.35, (r - SLOW_R) / (BURN_R - SLOW_R))
	return q * (1.0 - 0.5 * clampf((off_mm - OFF_OK_MM) / (TRACE_M * 1000.0 - OFF_OK_MM), 0.0, 1.0))


## A traced weld finished under trades.weld_skill: its quality from each stretch, and the
## readings Quality grades (travel speed, arc length, penetration, burn through).
func _weld_made(f: FastenerPoint) -> void:
	var dwell: PackedFloat32Array = _dwell.get(f.joint_id, PackedFloat32Array())
	var off: PackedFloat32Array = _off.get(f.joint_id, PackedFloat32Array())
	_dwell.erase(f.joint_id)
	_off.erase(f.joint_id)
	_bin_beads.erase(f.joint_id)
	var ideal := _ideal_dwell(f)
	var bin_mm := f.seam_size.x / TRACE_BINS * 1000.0
	var speeds: Array = []
	var arcs: Array = []
	var angles: Array = []
	var pens: Array = []
	var total := 0.0
	var fast := 0
	var slow := 0
	var burnt := false
	for k in dwell.size():
		var t := maxf(dwell[k], 0.0001)
		var r := t / ideal
		var off_mm := off[k] / t * 1000.0
		total += bin_quality(r, off_mm)
		speeds.append(snappedf(bin_mm / t, 0.1))
		# Held off the line, the arc runs long.
		arcs.append(snappedf(3.0 + off_mm * 0.04, 0.01))
		angles.append(TORCH_TILT_DEG)
		pens.append(snappedf(minf(1.0, sqrt(r)), 0.01))
		burnt = burnt or r >= BURN_R
		if r < GOOD_R:
			fast += 1
		elif r > SLOW_R:
			slow += 1
	var quality := total / maxi(1, dwell.size())
	_made(f, quality)
	var amps := _torch().amps if _torch() else 110.0
	_report(f, &"WELD", {"travel_speed_mm_s": speeds, "travel_speed_target_mm_s": WELD_SPEED_MM_S,
			"torch_angle_deg": angles, "torch_angle_target_deg": TORCH_TILT_DEG,
			"arc_length_mm": arcs, "arc_length_target_mm": 3.0, "coverage": 1.0,
			"penetration": snappedf(pens.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / maxi(1, pens.size()), 0.01),
			"penetration_samples": pens, "burn_through": burnt, "restarts": 0, "amps": amps})
	var why := "a steady, even bead"
	if burnt:
		why = "it burned through where the arc stayed too long"
	elif fast > 0 and fast >= slow:
		why = "thin in places where it went on too fast"
	elif slow > 0:
		why = "lumpy in places where it went on too slowly"
	var how := "spot on" if quality >= 0.95 else ("near enough" if quality >= 0.6 else "poor: cut it out and try again")
	bay.hint("Weld done, %s: %s." % [how, why])


## With the welder in hand on a traced seam (trades.weld_guide): the chalk line over the
## stretches still to run with ticks where an arc may be struck, and the point where the
## torch's tip meets the work, lit once it's on the line.
func _update_guide() -> void:
	var i := _working if _working >= 0 else aimed
	if not Flags.is_on("trades.weld_guide") or bay.tool != &"welder" or tractor.is_holding() or i < 0 or not traces(points[i]):
		guide.hide_all()
		return
	var f := points[i]
	var n := (ship_xform.basis * f.normal).normalized()
	var along := _seam_dir(f, n)
	var bins: PackedByteArray = _traced.get(f.joint_id, PackedByteArray())
	# A made weld (trades.vs_tools) cuts out wherever you point: no ends to start from.
	var ticks := from_end(f) and _working < 0 and not (vs_tools() and is_tight(f))
	guide.show_seam(points_world[i], along, n, f.seam_size.x, bins,
			start_points(f) if ticks else PackedFloat32Array())
	var on_line := points_world[i] + along * _seam_offset(f, points_world[i], n)
	var on := bay.aim_distance(on_line) < TRACE_M
	# trades.weld_skill: the tip says the pace, pale blue too fast, amber too slow.
	var tone := Color.WHITE
	if _working >= 0 and _pace_word == "fast":
		tone = Color(0.45, 0.8, 1.0)
	elif _working >= 0 and _pace_word == "slow":
		tone = Color(1.0, 0.6, 0.2)
	guide.show_tip(on_line if on else pointer_point(), n, on, tone)


## A stretch of fresh bead (or a fresh cut), glowing orange and cooling to nothing.
func _bead(f: FastenerPoint, at: Vector3, along: Vector3, n: Vector3) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	var width := maxf(f.seam_size.y, 0.008)
	mesh.radius = width * 0.55
	mesh.height = f.seam_size.x / TRACE_BINS + width
	mesh.radial_segments = 6
	mesh.rings = 1
	var mat := TradesLook.glow(Color(1.0, 0.45, 0.08), 4.0)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_transform = Transform3D(Basis(n.cross(along), along, n).orthonormalized(), at + n * width * 0.3)
	_beads.append([mi, mat, 0.0])
	return mi


func _cool_beads(delta: float) -> void:
	for i in range(_beads.size() - 1, -1, -1):
		var b: Array = _beads[i]
		b[2] += delta
		var heat: float = 1.0 - float(b[2]) / BEAD_COOL_S
		var keep := Flags.is_on("trades.weld_from_end")
		if (heat <= 0.0 and not keep) or float(b[2]) >= BEAD_KEEP_S:
			(b[0] as Node).queue_free()
			_beads.remove_at(i)
			continue
		heat = maxf(heat, 0.0)
		var mat := b[1] as StandardMaterial3D
		mat.emission = Color(1.0, 0.45, 0.08).lerp(Color(0.6, 0.08, 0.02), 1.0 - heat)
		mat.emission_energy_multiplier = 4.0 * heat * heat
		if keep:
			mat.albedo_color = Color(0.42, 0.42, 0.44)
			(b[0] as GeometryInstance3D).transparency = clampf((float(b[2]) - (BEAD_KEEP_S - 3.0)) / 3.0, 0.0, 1.0)
		else:
			(b[0] as GeometryInstance3D).transparency = 1.0 - minf(1.0, heat * 3.0)


## Fresh bead still glowing (tests).
func hot_beads() -> int:
	return _beads.filter(func(b: Array) -> bool: return float(b[2]) < BEAD_COOL_S).size()


## Bead drawn at all, glowing or cooled (tests).
func beads() -> int:
	return _beads.size()


## A bolt to drop: a hex head on a short threaded shank (metres).
static func _make_bolt_mesh() -> Mesh:
	var st := SurfaceTool.new()
	var head := CylinderMesh.new()
	head.top_radius = 0.011
	head.bottom_radius = 0.011
	head.height = 0.008
	head.radial_segments = 6
	head.rings = 1
	var shank := CylinderMesh.new()
	shank.top_radius = 0.006
	shank.bottom_radius = 0.006
	shank.height = 0.035
	shank.radial_segments = 8
	shank.rings = 1
	st.append_from(head, 0, Transform3D(Basis(), Vector3(0, 0.0215, 0)))
	st.append_from(shank, 0, Transform3D.IDENTITY)
	return st.commit()


# --- Aim and marker ---------------------------------------------------------------------------

## Only the rings within this of where you point are lit (m; trades.near_rings, beenster
## 0.3.16: "the scene is very busy with green and orange highlights").
const NEAR_RINGS_M := 2.0
## With trades.quiet_rings only the few right round the crosshair (beenster, 0.3.17: "only
## near to where you are pointing").
const QUIET_NEAR_M := 0.5
## How far the pointer looks for something to land on (m).
const POINTER_RAY_M := 20.0
var _focus_sent := Vector3.INF
var _focus_radius_sent := -1.0


## Where the crosshair lands: the first thing the aim ray hits, else a step ahead.
func pointer_point() -> Vector3:
	var o := bay.worker.aim_origin()
	var d := bay.worker.aim_dir()
	var world := bay.worker.get_world_3d()
	if world:
		var q := PhysicsRayQueryParameters3D.create(o, o + d * POINTER_RAY_M)
		q.exclude = [bay.worker.get_rid()]
		var hit := world.direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			return hit.position
	return o + d * 3.0


## Tells the stand, and the ship's markers (Ship and Bay's set_marker_focus, when it has
## it), which rings to light.
func _update_ring_focus() -> void:
	var near := QUIET_NEAR_M if Flags.is_on("trades.quiet_rings") else NEAR_RINGS_M
	var radius := near if Flags.is_on("trades.near_rings") and bay.hud_showing() else INF
	var at := pointer_point() if radius != INF else Vector3.ZERO
	if test_stand:
		test_stand.focus = at
		test_stand.focus_radius = radius
	if unit:
		unit.focus = at
		unit.focus_radius = radius
	if radius == _focus_radius_sent and (radius == INF or at.distance_to(_focus_sent) < 0.05):
		return
	_focus_sent = at
	_focus_radius_sent = radius
	if _bus and _bus.has_method("set_marker_focus"):
		_bus.call("set_marker_focus", at, radius)

func _update_aim() -> void:
	var best := -1
	var best_d := PICK_M
	var hand := bay.worker.right_hand
	for i in points_world.size():
		var p := _aim_point(i)
		var d := bay.aim_distance(p)
		if d < best_d and hand.can_reach(p):
			best = i
			best_d = d
	if best != aimed:
		aimed = best
		# What the tool does to it is in the tips (actions); the old hint goes.
		bay.hint("")
		if aimed >= 0:
			# The wrench's screen and panel show the torque the bolt under the aim wants.
			var wrench := bay.tool_node(&"torque_wrench") as TradesTorqueWrench
			# The torque is the player's to set and stays where they left it (trades.torque_kept,
			# beenster 0.3.16).
			if wrench and points[aimed].kind == "bolt" and not (powered() and Flags.is_on("trades.torque_kept")):
				var nm := torque_range(points[aimed].spec)
				wrench.set_nm = (nm.x + nm.y) * 0.5
		bay.refresh_hud()


## What the aim is on, for the tips' heading: "M12 bolt, tight", or "" for nothing.
func aim_title(tool: StringName) -> String:
	if tool == &"tractor":
		return tractor.aim_title()
	if aimed < 0:
		return ""
	var f := points[aimed]
	return "%s %s, %s" % [f.spec.to_upper(), f.kind, _state_word(f).to_lower()]


func aim_key() -> String:
	if tractor.is_holding():
		return "beam"
	var i := _working if _working >= 0 else aimed
	if i >= 0:
		return points[i].joint_id
	var slot := tractor.aimed_slot()
	return "slot:" + slot if slot != "" else ""


## The spec of the joint under the aim and the part it holds, for the look card.
func aim_spec(tool: StringName) -> String:
	if tool == &"tractor" or aimed < 0:
		return ""
	var f := points[aimed]
	var lines := PackedStringArray([spec_line(f)])
	var comp := _component_of(f)
	if comp != "":
		lines.append("Holds %s" % comp)
	# The part's key details on the card, now there's no Tab sheet (beenster, 22 Oct).
	var part := _part_line(f)
	if part != "":
		lines.append(part)
	return "\n".join(lines)


## The part a joint holds, in a line: "Fitted, 3 of 6 joints in".
func _part_line(f: FastenerPoint) -> String:
	var all: Array[FastenerPoint] = []
	var state := ""
	if is_unit(f) and unit:
		all = unit.mount_joints(unit.mount_of(f.joint_id))
		state = "Cover" if unit.mount_of(f.joint_id) == "cover" else "Fitted"
	elif is_practice(f):
		all = test_stand.joints
		state = "Practice panel"
	elif _bus:
		var slot_id := FastenerPoint.slot_of(f.joint_id)
		all = _bus.get_fasteners(slot_id)
		state = str(SLOT_STATES.get(_bus.get_slot_state(slot_id), "")).capitalize()
	if all.is_empty():
		return ""
	var tight := all.filter(func(g: FastenerPoint) -> bool: return is_tight(g)).size()
	return "%s, %d of %d joints in" % [state, tight, all.size()] if state != "" else "%d of %d joints in" % [tight, all.size()]


## One line of what a joint's spec asks for: "M12 bolt: 80-95 N m, aim for 88".
static func spec_line(f: FastenerPoint) -> String:
	match f.kind:
		"bolt":
			var nm := torque_range(f.spec)
			return "%s bolt: %d-%d N m, aim for %d" % [f.spec, roundi(nm.x), roundi(nm.y), roundi(torque_target(f.spec))]
		"rivet":
			return "%s rivet: head %.1f mm" % [f.spec, head_target_mm(f.spec)]
		"weld":
			return "Weld seam: %d mm, both ends" % roundi(f.seam_size.x * 1000.0) if f.seam_size.x > 0.0 else "Weld seam"
		"connector":
			if TradesWireLoom.supports(f.spec):
				return "%s plug: %d pins, wire it to its diagram" % [f.spec.capitalize(), TradesWireLoom.LOOMS[f.spec].size()]
			return "%s plug: push it home" % f.spec.capitalize()
	return f.spec


## The tips for the joint under the aim with `tool` in hand: what it does to it now, or
## which tool to take up for it.
func actions(tool: StringName) -> Array:
	if tool == &"tractor":
		return tractor.actions()
	if aimed < 0:
		return _unit_actions()
	var f := points[aimed]
	if _working >= 0:
		return [["Let go", "stop"]]
	if _slot_empty(f):
		return [[TradesBay.CLICK, "put the part back"]] if tool == &"hands" else [[bay.tool_action(&"hands"), "hands, to put the part back"]]
	var tight := is_tight(f)
	var out: Array = []
	match f.kind:
		"bolt":
			if tool == &"torque_wrench" and powered() and vs_tools():
				out.append([TradesBay.HOLD_CLICK, "spin it out" if tight else "run it in to %d N m" % roundi(_power().set_nm)])
				out.append([TradesBay.WHEEL, "set the torque, %d N m now (Ctrl: fine)" % roundi(_power().set_nm)])
			elif tool == &"torque_wrench" and powered():
				var w := _power()
				if w.undo == tight:
					out.append([TradesBay.HOLD_CLICK, "undo it" if tight else "run it in, let go at the clutch"])
				if Flags.is_on("trades.torque_kept"):
					out.append([TradesBay.WHEEL, "set the torque, %d N m now (Ctrl: fine)" % roundi(w.set_nm)])
				elif not tight and not w.undo:
					out.append([TradesBay.WHEEL, "set the torque (%d N m now)" % roundi(w.set_nm)])
				out.append([TradesBus.KEY_MODE, "switch to fasten" if w.undo else "switch to undo"])
			elif tool == &"torque_wrench":
				out.append([TradesBay.HOLD_RIGHT, "break it loose"] if tight else [TradesBay.HOLD_CLICK + ", pull back", "torque it till it clicks"])
		"rivet":
			if tool == &"drill" and tight:
				out.append([TradesBay.HOLD_CLICK, "drill it out"])
			elif tool == &"welder" and tight and kind_tools("rivet").has(&"welder"):
				out.append([TradesBay.HOLD_CLICK, "heat it till it pops out"])
			elif tool == &"cutter" and tight:
				out.append([TradesBay.HOLD_CLICK, "grind the head off"])
			elif tool == &"rivet_squeezer" and not tight and _gun():
				out.append([TradesBay.HOLD_CLICK, "fire a rivet"])
				out.append([TradesBay.WHEEL, "set the head height (%.1f mm now)" % _gun().set_mm])
			elif tool == &"rivet_squeezer" and not tight:
				out.append([TradesBay.HOLD_CLICK, "set a rivet"])
		"weld":
			if tool == &"welder" and vs_tools():
				if not tight:
					out.append([TradesBay.HOLD_CLICK, "lay the bead along the line"])
				elif Flags.is_on("trades.unweld"):
					out.append([TradesBay.HOLD_CLICK, "cut the weld out where you point"])
				if Flags.is_on("trades.helmet_toggle") and Flags.is_on("trades.weld_helmet"):
					out.append([TradesBus.KEY_HELMET, "lift the shield" if bay.helmet_lowered else "drop the shield"])
			elif tool == &"welder":
				var unweld := _torch() != null and _torch().unweld
				if not tight and not unweld:
					out.append([TradesBay.HOLD_CLICK, "lay the bead"])
				elif tight and unweld and Flags.is_on("trades.unweld"):
					out.append([TradesBay.HOLD_CLICK, "cut the weld out"])
				if Flags.is_on("trades.unweld"):
					out.append([TradesBus.KEY_MODE, "switch to weld" if unweld else "switch to unweld"])
				if Flags.is_on("trades.helmet_toggle") and Flags.is_on("trades.weld_helmet"):
					out.append([TradesBus.KEY_HELMET, "lift the shield" if bay.helmet_lowered else "drop the shield"])
		"connector":
			if tool == &"hands" or tool == &"wire_tool":
				var plug := "open its wiring diagram" if uses_diagram(f) else "plug it in"
				out.append([TradesBay.RIGHT_CLICK, "unplug it"] if tight else [TradesBay.CLICK, plug])
	if out.is_empty():
		var want: StringName = &""
		match f.kind:
			"bolt":
				want = &"torque_wrench"
			"rivet":
				var out_tools := _out_tools("rivet")
				want = (out_tools[0] if not out_tools.is_empty() else &"") if tight else &"rivet_squeezer"
			"weld":
				want = &"welder"
			"connector":
				want = &"hands"
		if want != &"" and want != tool:
			out.append([bay.tool_action(want), "take the %s" % TradesBay.label_of(want).to_lower()])
	return out


func _place_marker() -> void:
	var i := _working if _working >= 0 else aimed
	_marker.visible = i >= 0
	if i < 0:
		return
	var quiet := Flags.is_on("trades.quiet_rings")
	_marker.mesh = _quiet_mesh if quiet else _ring_mesh
	_marker.material_override = _ring_quiet if quiet else (_ring_tight if is_tight(points[i]) else _ring_loose)
	var n := (ship_xform.basis * points[i].normal).normalized()
	var x := n.cross(Vector3.UP) if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var at := points_world[i]
	var size := 1.0
	# A traced weld has no ring in its middle: a small one marks the end to start from, and
	# none while the arc runs (the bead is what you follow).
	if from_end(points[i]):
		if _working >= 0:
			_marker.visible = false
			return
		at += _seam_dir(points[i], n) * nearest_start(i)
		size = 0.6
	_marker.global_transform = Transform3D(Basis(x.normalized(), n, x.normalized().cross(n)).scaled(Vector3.ONE * size), at + n * 0.012)


## No joint of its part is in yet.
func _first_joint(f: FastenerPoint) -> bool:
	if is_practice(f) or is_rig(f):
		return false
	for g in _bus.get_fasteners(FastenerPoint.slot_of(f.joint_id)):
		if _bus.is_joint_tight(g.joint_id):
			return false
	return true


func _slot_empty(f: FastenerPoint) -> bool:
	if is_practice(f) or is_rig(f):
		return false
	return _bus.get_slot_state(FastenerPoint.slot_of(f.joint_id)) == ShipBayBus.SlotState.EMPTY


func _state_word(f: FastenerPoint) -> String:
	if _slot_empty(f):
		return "PART OFF"
	if not is_tight(f):
		return "LOOSE" if f.kind != "connector" else "UNPLUGGED"
	return {"bolt": "TIGHT", "rivet": "SET", "weld": "WELDED", "connector": "PLUGGED"}.get(f.kind, "DONE")


func _tight_count() -> int:
	var n := 0
	for f in points:
		if not is_practice(f) and is_tight(f):
			n += 1
	return n


func reset() -> void:
	tractor.release()
	_stop()


func key(action: String) -> bool:
	if action == Keys.INTERACT and aimed < 0 and _working < 0:
		return use_unit()
	return false


## F's tip when you point into an opened unit, at a seat.
func _unit_actions() -> Array:
	if unit == null:
		return []
	var seat := unit.seat_near(bay.worker.aim_origin(), bay.worker.aim_dir())
	if seat == "":
		return []
	var what := str(TradesUnitWork.ADDON_NAMES[seat]).to_lower()
	if not unit.is_fitted(seat):
		return [[Keys.INTERACT, "fit the %s" % what]]
	return [[Keys.INTERACT, "lift the %s out" % what]] if unit.can_lift(seat) else []


## Release screenshot: a joint of `kind` mid-job (a bolt being torqued, a plug pulled...),
## with the worker standing `back_m` out from it. Returns [feet, look at] in world space, or
## [] when the ship has no joint of that kind.
func stage_joint(kind: String, back_m := 1.6) -> Array[Vector3]:
	# The one easiest to see: on an outside face (standing in front of it is furthest from
	# the ship's middle), and on a side rather than overhead.
	var i := -1
	var feet := Vector3.ZERO
	var best := INF
	var middle := Vector3(ship_xform.origin.x, 0.0, ship_xform.origin.z)
	for j in points.size():
		if points[j].kind != kind or is_practice(points[j]):
			continue
		var n := (ship_xform.basis * points[j].normal).normalized()
		var out := Vector3(n.x, 0.0, n.z)
		if out.length() < 0.2:
			out = Vector3(points_world[j].x, 0.0, points_world[j].z) - middle
		var stand := points_world[j] + out.normalized() * back_m
		stand.y = global_position.y
		var score := absf(n.y) * 4.0 - Vector3(stand.x, 0.0, stand.z).distance_to(middle)
		if score < best:
			best = score
			i = j
			feet = stand
	if i < 0:
		return []
	var f := points[i]
	var at := points_world[i]
	aimed = i
	match kind:
		"bolt":
			_note_removed(f)
			_begin(false, &"torque_wrench")
			_pull_px = torque_range(f.spec).x * 0.8 / NM_PER_PX
		"rivet":
			_begin(true, &"drill")
		"weld":
			_note_removed(f)
			_begin(false, &"welder")
		"connector":
			_note_removed(f)
			_begin(false, &"hands")
	_held_s = _seconds(kind) * 0.6
	_frozen = true
	return [feet, at]


# --- The wiring diagram (trades.wire_diagram) ----------------------------------------------

## True for a plug that's wired up on its diagram: power and data, not fuel.
func uses_diagram(f: FastenerPoint) -> bool:
	return f.kind == "connector" and TradesWireLoom.supports(f.spec) and Flags.is_on("trades.wire_diagram")


func loom_of(f: FastenerPoint) -> TradesWireLoom:
	if not _looms.has(f.joint_id):
		_looms[f.joint_id] = TradesWireLoom.new(f.spec, f.joint_id)
	return _looms[f.joint_id]


## Puts the diagram for joint i up on screen, with the mouse free.
func open_wiring(i: int) -> TradesWiringPanel:
	if wiring:
		return wiring
	var f := points[i]
	var loom := loom_of(f)
	var comp := _component_of(f)
	wiring = TradesWiringPanel.new(loom, "WIRING  %s" % (comp if comp != "" else FastenerPoint.slot_of(f.joint_id)).to_upper())
	wiring.plug_requested.connect(_plug_wiring)
	wiring.close_requested.connect(close_wiring)
	# The wiring tool unfolds out of your hand into a steady screen in front of you.
	tablet = TradesWiringTablet.new(wiring, bay.worker)
	add_child(tablet)
	_wiring_at = i
	HudSlots.claim_pointer("trades.wiring")
	bay.worker.look_locked = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	bay.play(&"click", 0.7)
	bay.hint("Drag each wire onto its pin, then plug it in.")
	return wiring


func close_wiring() -> void:
	if wiring == null:
		return
	if is_instance_valid(tablet):
		tablet.fold()
	tablet = null
	wiring = null
	_wiring_at = -1
	HudSlots.release_pointer("trades.wiring")
	bay.worker.look_locked = false
	if DisplayServer.get_name() != "headless" and not HudSlots.pointer_claimed():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	bay.worker.right_hand.come_back()
	bay.worker.left_hand.come_back()


## PLUG IN AND TEST: the plug goes home with the wires as they are, and Quality hears.
func _plug_wiring() -> void:
	if wiring == null or _wiring_at < 0:
		return
	var f := points[_wiring_at]
	var loom := wiring.loom
	if not loom.all_landed() or is_tight(f):
		return
	loom.plug_in()
	_made(f, 1.0 if loom.is_right() else 0.1)
	_report(f, &"WIRE", loom.measurements())
	bay.play(&"click")
	bay.hint("Plugged in. All pins good." if loom.is_right() else "Plugged in, but some pins test open.")
	wiring._refresh()
	# Done: it packs itself away once you've seen the pins test (beenster, 0.3.15).
	if Flags.is_on("trades.wiring_tidy"):
		var panel := wiring
		get_tree().create_timer(PACK_AWAY_S if loom.is_right() else PACK_AWAY_BAD_S).timeout.connect(func() -> void:
				if wiring == panel:
					close_wiring())


## How long the wiring tool stays open after PLUG IN AND TEST before it packs away (s): a
## moment to see every pin green, longer when some test open.
const PACK_AWAY_S := 1.2
const PACK_AWAY_BAD_S := 3.0


## While the wiring tool's open your hands are on it (TradesWiringTablet); walk away and it
## folds up.
func _update_wiring() -> void:
	_marker.visible = false
	if _wiring_at < 0 or _wiring_at >= points.size():
		close_wiring()
		return
	var at := points_world[_wiring_at]
	var feet := bay.worker.global_position
	if Vector2(feet.x - at.x, feet.z - at.z).length() > 3.0:
		close_wiring()
