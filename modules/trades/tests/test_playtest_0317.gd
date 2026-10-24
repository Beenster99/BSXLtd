extends ModuleTest
## beenster's 0.3.17 playtest: with the welder in hand a chalk line runs along the seam still
## to weld, with ticks at the ends you can start from, and a point shows where the torch's tip
## meets the work, lit once it's on the line and drawn over the nozzle (trades.weld_guide);
## the joint rings are one pale colour whatever their state, thinner, and only the ones right
## round the crosshair show (trades.quiet_rings).

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FLAGS := ["trades.test_stand", "trades.trace_weld", "trades.weld_helmet", "trades.weld_from_end",
		"trades.near_rings", "trades.weld_guide", "trades.quiet_rings"]


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in FLAGS:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	saved["trades.helmet_toggle"] = Flags.is_on("trades.helmet_toggle")
	Flags.set_flag("trades.helmet_toggle", false)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	var guide: TradesWeldGuide = station.guide

	# Hands: no guide on a seam.
	var w := _first(station, "weld", false)
	_aim_at(rig, station, w)
	rig.set_tool(&"hands")
	station.update(0.0)
	check(not guide.line_showing() and not guide.tip_showing(), "with bare hands there's no chalk line")

	# The welder: the line along the seam, end ticks, and the tip point.
	rig.set_tool(&"welder")
	(rig.tool_node(&"welder") as TradesWeldTorch).unweld = false
	var f := station.points[w]
	var along := (station.ship_xform.basis * f.seam_up).normalized()
	var at := station.points_world[w]
	rig.worker.face(at + along * f.seam_size.x * 0.2)
	station.update(0.0)
	check(guide.line_showing(), "with the welder the chalk line runs along the seam")
	check(guide.tip_showing() and guide._tip.material_override == guide._tip_on, "the tip point sits on the line and lights up")
	check(guide._tip.global_position.distance_to(at + along * f.seam_size.x * 0.2) < 0.01,
			"where the aim crosses the seam (%.3f m off)" % guide._tip.global_position.distance_to(at + along * f.seam_size.x * 0.2))
	check((guide._tip.material_override as StandardMaterial3D).no_depth_test, "drawn over the nozzle")
	var full: bool = guide.vertex_count > 0
	check(full, "the line has something in it")
	var verts_full: int = guide.vertex_count
	check(verts_full == 6 * 3, "one line and two end ticks (%d vertices)" % verts_full)
	var n := (station.ship_xform.basis * f.normal).normalized()
	# Half traced: the run stretch drops out of the line and its end gets a tick.
	rig.worker.face(at - along * f.seam_size.x * 0.5)
	station.update(0.0)
	station.press(&"welder")
	check(station.is_busy(), "the arc strikes at the end")
	rig.worker.face(at - along * f.seam_size.x * 0.5 + n.cross(along).normalized() * 0.3)
	station.update(0.05)
	check(guide.tip_showing() and guide._tip.material_override == guide._tip_off, "drift off the line and the point dims")
	for k in 21:
		rig.worker.face(at + along * (f.seam_size.x * (k / 40.0 - 0.5)))
		station.update(0.05)
		rig.update_helmet(0.05)
	check(guide.line_showing(), "the line stays while the arc runs")
	station.release()
	station.update(0.0)
	var verts_half: int = guide.vertex_count
	check(verts_half == 6 * 3, "half the line left, ticks at the bead's end and the far end only (%d)" % verts_half)
	rig.set_tool(&"hands")
	station.update(0.0)

	# Rings: one pale colour, thinner, and only right round the crosshair.
	var b := _first(station, "bolt", true)
	var loose := _first(station, "bolt", false)
	_aim_at(rig, station, b)
	check(station._marker.material_override == station._ring_quiet and station._marker.mesh == station._quiet_mesh,
			"the aim ring is the pale thin one on a tight bolt")
	_aim_at(rig, station, loose)
	check(station._marker.material_override == station._ring_quiet, "and on a loose one too")
	var stand := station.test_stand
	var mats := {}
	for id: String in stand._markers:
		mats[(stand._markers[id] as MeshInstance3D).material_override] = true
	check(mats.size() == 1, "the stand's rings are all one colour (%d)" % mats.size())
	var e := (station._ring_quiet as StandardMaterial3D).emission_energy_multiplier
	check(e < station._ring_tight.emission_energy_multiplier * 0.25, "and much dimmer (%.2f)" % e)
	station._update_ring_focus()
	check(stand.focus_radius == TradesShipJoints.QUIET_NEAR_M or not rig.hud_showing(), "only those within %.1f m show" % TradesShipJoints.QUIET_NEAR_M)

	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _run(rig: TradesBay, station: TradesShipJoints, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		station.update(minf(0.05, left))
		rig.update_helmet(minf(0.05, left))
		left -= 0.05


func _first(station: TradesShipJoints, kind: String, made: bool) -> int:
	for i in station.points.size():
		var f := station.points[i]
		if TradesShipJoints.is_practice(f) and f.kind == kind and station.is_tight(f) == made:
			return i
	return -1


func _aim_at(rig: TradesBay, station: TradesShipJoints, i: int) -> void:
	var at := station.points_world[i]
	var n := (station.ship_xform.basis * station.points[i].normal).normalized()
	var feet := at + Vector3(n.x, 0.0, n.z).normalized() * 0.8
	feet.y = station.test_stand.global_position.y
	rig.worker.global_position = feet
	rig.worker.face(at)
	station.update(0.0)


func _fake_yard() -> Node3D:
	var script := GDScript.new()
	script.source_code = FAKE_YARD
	script.reload()
	var yard := Node3D.new()
	yard.set_script(script)
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 6)
	yard.set("walker", walker)
	yard.add_child(walker)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.2, 80)
	floor_shape.shape = box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	yard.add_child(floor_body)
	return yard
