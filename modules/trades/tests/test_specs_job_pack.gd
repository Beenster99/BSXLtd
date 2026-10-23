extends ModuleTest
## The wrist's Specs channel on the contract (beenster, 0.3.14: "The specs tab should be
## related to a specific contract that we are working on ... a job pack ... a spec sheet for
## each object, there shouldn't be anything shown on the right hand side if nothing is being
## looked at, but there should be access to more information about the contracts").

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
## A work order (as Contracts' kestrel_coil_fit fixture), its slot filled in by the test.
const ORDER := """{
  "schema": "bsx.work_order",
  "schema_version": 1,
  "contract_id": "rook_salvage.specs_test",
  "issued_at": "2026-10-18T17:00:00Z",
  "client": {"company": "rook_salvage", "display_name": "Rook Salvage", "game": "void_salvage"},
  "ship": {
    "ship_id": "rook_salvage/kestrel",
    "design": "kestrel",
    "current_fit": [
      {"slot": "SLOT", "component": {"id": "hold_net"}, "condition": 0.8}
    ]
  },
  "changes": [
    {
      "change_id": "c1",
      "action": "replace",
      "slot": "SLOT",
      "remove": {"id": "hold_net"},
      "install": {"id": "attractor_coil_1", "material": "copper"},
      "notes": "Keep the old net, I want it back."
    }
  ],
  "manifest": [
    {"line_id": "m1", "component": {"id": "attractor_coil_1", "material": "copper"}, "qty": 1,
     "supplied_by": "bsx", "allowed_sources": ["new", "refurbished"]}
  ],
  "spec_sheet": {
    "library": true,
    "overrides": [
      {"change_id": "c1", "bolt": {"torque_nm": 200, "pattern": "star"}}
    ]
  },
  "notes": [{"text": "Coil feed must land on the hold breaker.", "change_id": "c1"}],
  "commercial": {"price": 120000, "currency": "cr", "deposit_pct": 30,
                 "deadline": "2026-11-01T00:00:00Z", "late_penalty_per_day": 2500}
}"""


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var contracts := Modules.bus("contracts") as ContractsBus
	check(contracts != null, "Tools can reach the contracts")
	if contracts == null:
		return
	var saved := {}
	for flag: String in ["trades.job_pack_specs", "trades.spec_sheet", "trades.test_stand"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	(Modules.bus("trades") as TradesBus)._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()

	# No contract on: the ship's fasteners, and nothing on the right.
	var was_active := contracts.get_active_job().job_id if contracts.get_active_job() else ""
	contracts.set_active_job("")
	_look_away(rig)
	station.aimed = -1
	var screen := await _screen(station)
	check(screen.job_id == "" and _text(screen).contains("No contract on"), "no contract: it says so")
	check(screen.get_child_count() == 1, "looking at nothing: nothing on the right")
	screen.queue_free()

	# A contract on a slot of the ship in the bay.
	var bolt := -1
	for i in station.points.size():
		if station.points[i].kind == "bolt" and not TradesShipJoints.is_practice(station.points[i]):
			bolt = i
			break
	var slot := FastenerPoint.slot_of(station.points[bolt].joint_id)
	var text := ORDER.replace("SLOT", slot)
	var imported := contracts.import_text(text)
	check(imported.ok(), "a contract for %s comes in" % slot)
	var job_id := "rook_salvage.specs_test"
	contracts.set_active_job(job_id)

	_look_away(rig)
	station.aimed = -1
	screen = await _screen(station)
	var pack := contracts.job_pack(job_id)
	var chips := screen.find_children("*", "Button", true, false)
	check(screen.job_id == job_id and chips.size() == pack.size(), "the contract we're on, with a chip per pack document (%d)" % pack.size())
	check(_text(screen).contains("WORK ORDER") or _text(screen).contains("Work order"), "its work order open first")
	check(screen.get_child_count() == 1, "looking at nothing: nothing on the right")
	screen.open_doc("notes")
	await frames(1)
	check(screen.doc_id == "notes" and _text(screen).contains("hold breaker"), "a chip opens another document of the pack")
	screen.queue_free()

	# Looking at a joint of the part the contract changes: its spec sheet from the pack.
	station.aimed = bolt
	screen = await _screen(station)
	var right := screen.find_child("LookedSpec", false, false)
	check(screen.looked_slot == slot and right != null, "looking at its joint: the pack's spec sheet on the right")
	if right:
		var t := _text(right)
		check(t.contains("Spec sheet") and t.contains("200"), "with the client's settings for it: %s" % t.replace("\n", " | ").left(200))
	screen.queue_free()

	# A part the contract doesn't touch: its own paper sheet.
	var other := -1
	for i in station.points.size():
		var s := FastenerPoint.slot_of(station.points[i].joint_id)
		if s != slot and s != TradesTestStand.SLOT:
			other = i
			break
	if other >= 0:
		station.aimed = other
		screen = await _screen(station)
		check(screen.find_child("LookedSpec", false, false) == null and screen.find_child("SpecSheet", false, false) != null,
				"a part off the contract: its own spec sheet")
		screen.queue_free()

	contracts.set_active_job(was_active)
	yard.queue_free()
	await frames(1)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


## Stands the worker far off in the yard looking at open sky, so neither a joint nor the
## beam's aim is on anything.
func _look_away(rig: TradesBay) -> void:
	rig.worker.global_position = rig.ship_station().ship_xform.origin + Vector3(0, 0, 400)
	rig.worker.face(rig.worker.global_position + Vector3(0, 20, 60))


func _screen(station: TradesShipJoints) -> TradesSpecsScreen:
	var screen := TradesSpecsScreen.new(true, station)
	add_child(screen)
	await frames(1)
	return screen


func _text(node: Node) -> String:
	var out := PackedStringArray()
	for l in node.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return "\n".join(out)


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
