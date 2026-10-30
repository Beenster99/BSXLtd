extends ModuleTest
## Ship and Bay, S6 (large jobs in stages; beenster, 30 Oct: "move to next stage S6 - large
## jobs"): a large wreck in Dock 2 or Dock 3 is cut into sections the dolly can carry, at its
## frame rings, and a section cut free stands beside the dock as its own body. Both docks hold
## a large hull at once.
##   tools/run_tests.sh ship_bay

const HullSections := preload("res://modules/ship_bay/internal/hull_sections.gd")


func run_tests() -> void:
	var f := VsShipImport.design_source("vsw:sentinel")
	var plan := HullSections.plan(f)
	var seen := {}
	var twice := 0
	var long := 0
	var heavy := 0
	for sec: Dictionary in plan:
		for p: String in sec["parts"]:
			if seen.has(p):
				twice += 1
			seen[p] = true
		if float(sec["z1"]) - float(sec["z0"]) > HullSections.MAX_LENGTH + 0.01:
			long += 1
		if float(sec["mass_kg"]) > HullSections.MAX_MASS:
			heavy += 1
	check(plan.size() >= 5 and seen.size() == (f["parts"] as Array).size() and twice == 0,
			"the Sentinel is cut into %d sections, every part in one (%d of %d)" % [plan.size(), seen.size(), (f["parts"] as Array).size()])
	check(long == 0, "no section is longer than the dolly's deck (%.0f m): %s" % [HullSections.MAX_LENGTH,
			plan.map(func(s: Dictionary) -> String: return "%.1f" % (float(s["z1"]) - float(s["z0"])))])
	check(heavy == 0, "and none heavier than the dolly carries (%.0f t)" % (HullSections.MAX_MASS / 1000.0))
	print("  sections: ", plan.map(func(s: Dictionary) -> String: return "%.1f m %.0f t, %d cut" % [float(s["z1"]) - float(s["z0"]), float(s["mass_kg"]) / 1000.0, (s["cut_joints"] as Array).size()]))
	check(not (plan[1]["cut_joints"] as Array).is_empty(), "a section has joints to cut to its neighbours (%d)" % (plan[1]["cut_joints"] as Array).size())

	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var was := Flags.is_on("ship_bay.bay_cradle")
	Flags.set_flag("ship_bay.bay_cradle", true)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var apron: Node = yard.find_child("Apron", true, false)
	check(apron and (apron.get("dock_cradles") as Array).size() == 2, "Docks 2 and 3 each have a large cradle")
	bus.debug_ship("dock_hull", "vsw:sentinel", "2")
	bus.debug_ship("dock_hull", "vsw:everest", "3")
	await frames(3)
	var ships: Node = yard.find_child("YardShips", true, false)
	var hulls: Dictionary = ships.get("hulls")
	var j2 := ShipBayBus.debug_dock_job("2")
	var j3 := ShipBayBus.debug_dock_job("3")
	check(hulls.has(j2) and hulls.has(j3) and str((hulls[j2] as Node).get_parent().name) == "DockCradle2"
			and str((hulls[j3] as Node).get_parent().name) == "DockCradle3", "two large wrecks at once, one in each dock")
	var whole := _parts(hulls[j2])
	bus.debug_ship("free_section", "", "2")
	await frames(3)
	var secs: Dictionary = (ships.get("sections") as Dictionary).get(j2, {})
	check(bus.free_sections(j2) == [0] and secs.has(0), "Free a section: the first comes free (%s)" % [bus.free_sections(j2)])
	var sec: Node3D = secs.get(0)
	var rest: Node3D = hulls.get(j2)
	var n_sec := _parts(sec)
	var n_rest := _parts(rest)
	check(n_sec == (plan[0]["parts"] as Array).size() and n_sec + n_rest == whole,
			"the section is its own body with its parts (%d), the hull keeps the rest (%d of %d)" % [n_sec, n_rest, whole])
	# The swing across is a tween on the clock: wait it out in real time.
	await get_tree().create_timer(ships.SWING_TIME + 1.0).timeout
	await frames(3)
	var sb := _box(sec)
	var hb := _box(rest)
	check(not sb.intersects(hb) and absf(sb.position.y - 0.0) < 3.0 and sb.get_center().x < hb.get_center().x,
			"it stands on its stand beside the hull, on the dock's outer side: %s vs %s" % [sb, hb])
	bus.debug_ship("free_section", "", "2")
	await frames(3)
	check(bus.free_sections(j2) == [0, 1] and (ships.get("sections")[j2] as Dictionary).size() == 2, "and the next")
	bus.debug_ship("dock_clear", "", "2")
	bus.debug_ship("dock_clear", "", "3")
	await frames(3)
	check(not hulls.has(j2) and not (ships.get("sections") as Dictionary).has(j2), "Clear takes the wreck and its sections away")
	Flags.set_flag("ship_bay.bay_cradle", was)
	yard.queue_free()
	await frames(2)


func _parts(body: Node) -> int:
	var im: Variant = body.get_meta("importer") if body and body.has_meta("importer") else null
	return (im as VsShipImport).parts_by_path.size() if im else 0


## The box round a body's meshes, world space.
func _box(body: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		var b := mi.global_transform * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
