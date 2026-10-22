extends RefCounted
## Made-up survey reports for the release screenshots: a spot survey that caught a problem
## early, and the final survey that passed once it was put right.


static func reports() -> Array[SurveyReport]:
	var bolt := func(id: String, comp: String, mount: String, score: int, faults: Array) -> JointRecord:
		var r := JointRecord.new()
		r.joint_id = StringName(id)
		r.trade = &"BOLT"
		r.component_id = StringName(comp)
		r.mount_id = StringName(mount)
		r.score = score
		r.grade = JointRecord.PASS if score >= 70 else (JointRecord.MARGINAL if score >= 50 else JointRecord.FAIL)
		r.faults.assign(faults)
		return r
	var wire := func(id: String, comp: String, score: int) -> JointRecord:
		var r: JointRecord = bolt.call(id, comp, "plug_a", score, [])
		r.trade = &"WIRE"
		return r
	var spot: Array[JointRecord] = [
		bolt.call("j1", "attractor_coil_1", "mount_a", 96, []),
		bolt.call("j2", "attractor_coil_1", "mount_b", 88, []),
		bolt.call("j3", "hull_patch_plate", "frame_4", 34, [{"code": "cross_threaded", "hole": 2, "text": "Hole 3 cross-threaded"}]),
		wire.call("j4", "attractor_coil_1", 61),
	]
	spot[3].faults.assign([{"code": "pin", "hole": -1, "text": "Pin B wired wrong"}])
	var final: Array[JointRecord] = [
		bolt.call("j1", "attractor_coil_1", "mount_a", 96, []),
		bolt.call("j2", "attractor_coil_1", "mount_b", 88, []),
		bolt.call("j3", "hull_patch_plate", "frame_4", 92, []),
		wire.call("j4", "attractor_coil_1", 100),
		bolt.call("j5", "hull_patch_plate", "frame_5", 94, []),
		bolt.call("j6", "hull_patch_plate", "frame_6", 90, []),
	]
	return [
		SurveyDesk.write("S-003", SurveyReport.FINAL, "rook_salvage.bsx1", final, 6, 0),
		SurveyDesk.write("S-002", SurveyReport.CALLED, "rook_salvage.bsx1", spot.slice(3), 4, 0),
		SurveyDesk.write("S-001", SurveyReport.RANDOM, "rook_salvage.bsx1", spot, 4, 0),
	]
