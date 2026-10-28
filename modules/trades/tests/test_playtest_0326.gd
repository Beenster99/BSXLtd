extends ModuleTest
## Playtest 0.3.26 (beenster): "copy the order of the tools directly from Void Salvage"
## (trades.vs_order); "copy the behaviour of the cutter from Void Salvage so that dealing with
## welds is much easier - remove the weld line in bsx, remove the idea of a welders helmet"
## (trades.cutter_welds; trades.trace_weld, trades.weld_guide and trades.weld_helmet off).

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const ON := ["trades.vs_tools", "trades.vs_order", "trades.cutter_welds", "trades.cutter", "trades.slim_hotbar",
		"trades.tractor", "trades.unweld", "trades.rivet_heat", "trades.metal_sounds"]
const OFF := ["trades.trace_weld", "trades.weld_guide", "trades.weld_helmet"]


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in ON + OFF:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, flag in ON)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()

	# Void Salvage's order: grinder, cutter, socket, plasma, grabber, limpets, battery.
	var want: Array[StringName] = []
	for t in TradesBay.YARD_ORDER:
		if rig.hotbar.has(t):
			want.append(t)
	check(rig.hotbar.slice(0, want.size()) == want, "the hotbar follows Void Salvage's order: %s" % str(rig.hotbar))
	check(rig.tool_key(&"cutter") == "2" and rig.tool_key(&"torque_wrench") == "3" and rig.tool_key(&"tractor") == "5",
			"the cutter on 2, the wrench (the socket) on 3, the tractor (the grabber) on 5")

	# A weld is found anywhere along its seam.
	var w := _weld(station, true)
	check(w >= 0, "the Kestrel has a made weld along a seam")
	if w < 0:
		return
	var f := station.points[w]
	check(not station.traces(f), "no traced weld line")
	check(station.kind_tools("weld").has(&"cutter"), "the cutter works welds")
	var n := (station.ship_xform.basis * f.normal).normalized()
	var along := station._seam_dir(f, n)
	var off := station.points_world[w] + along * f.seam_size.x * 0.4
	_aim_at(rig, station, w, off)
	check(station.aimed == w, "aimed near one end of the seam, the weld is under the aim")
	rig.set_tool(&"welder")
	station.press(&"welder")
	check(not station.is_busy() and ship_bus.is_joint_tight(f.joint_id), "the welder doesn't cut a made weld")
	rig.set_tool(&"cutter")
	station.press(&"cutter")
	check(station.is_busy(), "the cutter on the seam starts cutting")
	_run(station, TradesShipJoints.UNWELD_S * 0.5)
	check(ship_bus.is_joint_tight(f.joint_id), "half way it still holds")
	station.release()
	station.press(&"cutter")
	_run(station, TradesShipJoints.UNWELD_S * 0.5 + TradesShipJoints.SPIN_UP_S * 2.0 + 0.1)
	check(not ship_bus.is_joint_tight(f.joint_id) and not station.is_busy(), "hold again: it carries on and the weld is cut")
	check(not station.guide._lines.visible and not station.guide._tip.visible, "no chalk line along the seam")

	# Welding it back: the welder held still on the seam, no line to follow, no helmet.
	rig.set_tool(&"welder")
	station.press(&"welder")
	check(station.is_busy(), "the welder on the cut weld starts laying it")
	_run(station, station._seconds("weld") + 0.1)
	check(ship_bus.is_joint_tight(f.joint_id), "held there, the weld is made again")
	check(rig.helmet_down() == 0.0, "no welder's helmet comes down")

	# Metal sounds of our own (trades.metal_sounds): each joint gives way in its own voice, bits
	# tink on the floor, a hard landing bounces.
	var bolt := TradesSounds.give("bolt")
	var rivet := TradesSounds.give("rivet")
	var weld := TradesSounds.give("weld")
	check(bolt.data.size() > 0 and rivet.data.size() != bolt.data.size() and weld.data.size() > rivet.data.size(),
			"a bolt, a rivet and a weld each give way with their own sound")
	check(TradesSounds.give("weld") == weld, "made once and kept")
	check(TradesSounds.tink(0) != TradesSounds.tink(1), "fallen bits tink in a few voices")
	check(TradesSounds.clang(0.5, 0.9) != TradesSounds.clang(0.5, 0.1), "a hard landing clangs with its bounces")

	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])
	ship_bus.unload_ship()


func _weld(station: TradesShipJoints, tight: bool) -> int:
	for i in station.points.size():
		var f := station.points[i]
		if f.kind == "weld" and f.seam_size.x > 0.06 and absf(station.points[i].normal.y) < 0.5 and not TradesShipJoints.is_practice(f) and not station.is_rig(f) \
				and station.is_tight(f) == tight:
			return i
	return -1


func _run(station: TradesShipJoints, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		station.update(minf(0.05, left))
		left -= 0.05


func _aim_at(rig: TradesBay, station: TradesShipJoints, i: int, point: Vector3) -> void:
	var at := station.points_world[i]
	var n := station.ship_xform.basis * station.points[i].normal
	var out := Vector3(n.x, 0.0, n.z)
	if out.length() < 0.2:
		out = Vector3(at.x, 0.0, at.z) - Vector3(station.ship_xform.origin.x, 0.0, station.ship_xform.origin.z)
	var feet := at + out.normalized() * 0.9
	feet.y = 0.0
	rig.worker.global_position = feet
	rig.worker.face(point)
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
	return yard
