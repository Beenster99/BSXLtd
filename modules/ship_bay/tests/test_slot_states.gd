extends ModuleTest
## Ship and Bay: strip a part out, fit one back, the rules between, save and restore.
##   tools/run_tests.sh ship_bay

const S := ShipBayBus.SlotState


func run_tests() -> void:
	var bay := Modules.bus("ship_bay") as ShipBayBus
	check(bay != null, "ship_bay bus loaded")
	if bay == null:
		return
	var removed: Array = []
	var installed: Array = []
	bay.component_removed.connect(func(s: String, c: String) -> void: removed.append([s, c]))
	bay.component_installed.connect(func(s: String, c: String) -> void: installed.append([s, c]))

	check(bay.load_ship("vs_kestrel"), "Kestrel loads")
	var slot := "eng_aft_port_1"
	var joints: Array[String] = []
	for f in bay.get_fasteners(slot):
		joints.append(f.joint_id)
	check(joints.size() == 6, "port engine has 4 bolts, a fuel plug and a power plug: %d" % joints.size())
	check(bay.get_slot_state(slot) == S.FITTED, "arrives fitted")
	check(bay.get_component(slot) == "KestrelEngine", "with its engine")
	check(bay.is_joint_tight(joints[0]), "bolts arrive tight")

	check(not bay.try_position(slot, "KestrelEngine"), "can't position into a fitted slot")
	check(bay.note_joint_removed(joints[0]), "undo one bolt")
	check(bay.get_slot_state(slot) == S.LOOSENED, "one bolt out: loosened")
	check(not bay.note_joint_removed(joints[0]), "the same bolt can't come out twice")
	check(bay.note_joint_made(joints[0], 0.9), "put it back")
	check(bay.get_slot_state(slot) == S.FITTED, "all back in: fitted again")

	for j in joints:
		bay.note_joint_removed(j)
	check(bay.get_slot_state(slot) == S.EMPTY, "all out: empty")
	check(bay.get_component(slot) == "", "the engine is off")
	check(removed == [[slot, "KestrelEngine"]], "component_removed sent once: %s" % [removed])
	check(not bay.note_joint_made(joints[0], 1.0), "nothing to bolt in an empty slot")

	check(not bay.try_position(slot, "hold_nets"), "slot refuses a part it doesn't take")
	check(bay.try_position(slot, "KestrelEngine"), "new engine positioned")
	check(bay.get_slot_state(slot) == S.POSITIONED, "positioned")
	check(not bay.note_joint_made("eng_aft_stbd_1/b1", 1.0), "an already tight bolt can't be made again")
	check(not bay.note_joint_made("eng_aft_port_1/nope", 1.0), "unknown joint refused")
	bay.note_joint_made(joints[0], 0.8)
	check(not bay.try_remove(slot), "can't lift it off once a bolt holds it")
	for j in joints:
		bay.note_joint_made(j, 0.95)
	check(bay.get_slot_state(slot) == S.INSTALLED, "all joints made: installed")
	check(is_equal_approx(bay.joint_quality(joints[0]), 0.8), "first bolt keeps its quality")
	check(installed == [[slot, "KestrelEngine"]], "component_installed sent once: %s" % [installed])

	var net := "net_hold_dor_1"
	var snap := bay.snapshot()
	for f in bay.get_fasteners(net):
		bay.note_joint_removed(f.joint_id)
	check(bay.get_slot_state(net) == S.EMPTY, "net stripped")
	var saved := JSON.parse_string(JSON.stringify(snap)) as Dictionary
	bay.restore(saved)
	check(bay.get_slot_state(net) == S.FITTED, "restore puts the net back")
	check(bay.get_slot_state(slot) == S.INSTALLED, "restore keeps the new engine")
	check(bay.is_joint_tight(bay.get_fasteners(net)[0].joint_id), "restored net bolts are tight")

	bay.unload_ship()
	check(bay.get_slot_state(slot) == -1, "no ship, no slots")
	bay.load_data(saved, ShipBayBus.SAVE_VERSION)
	check(bay.ship != null and bay.ship.ship_id == "vs_kestrel", "loading a save loads its ship")
	bay.unload_ship()
