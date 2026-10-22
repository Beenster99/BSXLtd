extends ModuleTest
## beenster's playtest notes of 22 Oct: no shield for heating rivets, a lighter shield glass,
## the tool's display off to one side of the aim, arms that point at the hands, more sparks
## that light their surroundings, the spec of what you look at on the look card, and a paper
## spec sheet on the wrist's Specs channel.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FLAGS := ["trades.power_riveter", "trades.rivet_heat", "trades.weld_helmet", "trades.hover_specs",
		"trades.spec_sheet", "trades.power_wrench"]


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in FLAGS:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	var torch := rig.tool_node(&"welder") as TradesWeldTorch

	# Heating a rivet out: the arc is lit, but the shield stays up.
	var r := _first(station, "rivet")
	_aim_at(rig, station, r)
	rig.set_tool(&"welder")
	station.press(&"welder")
	_run(rig, station, 0.4)
	check(torch.lit and torch.on_rivet, "heating a rivet: the welder is lit on it")
	check(rig.helmet_down() == 0.0, "no shield for riveting (%.2f)" % rig.helmet_down())
	station.release()
	_run(rig, station, 0.5)

	# The shield's glass lets the work show through.
	var view := TradesWeldingView.new()
	var code := ((view.material as ShaderMaterial).shader as Shader).code
	check(code.contains("sqrt(lum) * 0.26"), "the shield glass shows the work dimly, not black")
	view.free()

	# Sparks: lots, and they light what's round them.
	rig.sparks.emit(station.points_world[r], Vector3.UP, TradesShipJoints.SPARKS_CUT * 4, 2.0)
	rig.sparks._physics_process(0.016)
	check(rig.sparks.count() >= TradesShipJoints.SPARKS_CUT * 4, "a big shower (%d)" % rig.sparks.count())
	check(rig.sparks.lit_glows() > 0, "the sparks light their surroundings (%d lights)" % rig.sparks.lit_glows())
	check(TradesShipJoints.SPARKS_WELD >= 12 and TradesShipJoints.SPARKS_GRIND >= 20, "more sparks off every tool")

	# The arms point at the hands.
	var worker := rig.worker
	worker.set_view(true)
	worker.right_hand.reach_to(worker.global_position + Vector3(0.3, 2.4, -0.6))
	await get_tree().create_timer(0.5).timeout
	var arm: Dictionary = worker._arms[1]
	var upper := arm.upper as Node3D
	var shoulder := (upper.get_parent() as Node3D).global_transform * (arm.shoulder as Vector3)
	var to_hand := (worker.right_hand.palm().origin - shoulder).normalized()
	check(upper.global_basis.y.normalized().dot(to_hand) > 0.9, "the upper arm points at its hand (%.2f)"
			% upper.global_basis.y.normalized().dot(to_hand))
	check(worker.right_hand.arm_root.is_finite(), "third person: the stretchy arm starts at the elbow")
	worker.right_hand.come_back()
	worker.set_view(false)
	await frames(2)
	check(not worker.right_hand.arm_root.is_finite(), "first person: it starts at the hand's mount")

	# The spec of what you look at, tool in hand, on the look card.
	var b := _first(station, "bolt")
	_aim_at(rig, station, b)
	rig.set_tool(&"torque_wrench")
	var hint := rig.look_hint()
	var nm := TradesShipJoints.torque_range(station.points[b].spec)
	check(str(hint.get("text", "")).contains("%d-%d N m" % [roundi(nm.x), roundi(nm.y)]),
			"looking at a bolt, the card gives its torque spec: %s" % str(hint.get("text", "")))
	check(str(hint.get("text", "")).contains("Holds"), "and the part it holds")
	check(str(hint.get("text", "")).contains("joints in"), "and how many of its joints are in")
	# Joined-up hands (beenster, 22 Oct): first person, a forearm runs up into view to each hand.
	Flags.set_flag("trades.forearms", true)
	rig.worker.set_view(false)
	await frames(2)
	var sleeve := rig.worker.right_hand.get_node("Sleeve") as MeshInstance3D
	var wrist_end := sleeve.global_position + sleeve.global_basis.y * 0.5
	check(sleeve.visible and wrist_end.distance_to(rig.worker.right_hand.palm().origin) < 0.15,
			"first person, the hand is on the end of a forearm")

	# The wrist's Specs channel: a paper spec sheet on its right.
	var screen := TradesSpecsScreen.new(true)
	yard.add_child(screen)
	var sheets := screen.find_children("SpecSheet", "TradesSpecSheet", true, false)
	check(sheets.size() == 1 and screen.get_child(screen.get_child_count() - 1) == sheets[0], "a spec sheet on the right")
	var sheet := TradesSpecSheet.new(station)
	var text := sheet.text()
	check(text.contains("SPECIFICATION SHEET") and text.contains("YOU ARE ON") and text.contains(station.points[b].joint_id),
			"it's the sheet of the part you're on, with your joint marked")
	check((sheet.paper.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == TradesSpecSheet.PAPER, "on paper")
	sheet.free()
	screen.queue_free()
	var ship_sheet := TradesSpecSheet.new(null)
	check(ship_sheet.text().contains("FASTENER SCHEDULE"), "looking at nothing: the ship's fastener schedule")
	ship_sheet.free()

	yard.queue_free()
	await frames(1)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _run(rig: TradesBay, station: TradesShipJoints, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		station.update(minf(0.05, left))
		rig.update_helmet(minf(0.05, left))
		left -= 0.05


func _first(station: TradesShipJoints, kind: String) -> int:
	for i in station.points.size():
		if station.points[i].kind == kind:
			return i
	return -1


func _aim_at(rig: TradesBay, station: TradesShipJoints, i: int) -> void:
	var at := station.points_world[i]
	var n := station.ship_xform.basis * station.points[i].normal
	var out := Vector3(n.x, 0.0, n.z)
	if out.length() < 0.2:
		out = Vector3(at.x, 0.0, at.z) - Vector3(station.ship_xform.origin.x, 0.0, station.ship_xform.origin.z)
	var feet := at + out.normalized() * 0.9
	feet.y = 0.0
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
	return yard
