extends ModuleTest
## The shared part library: the Void Salvage copy, every build spec and fastener, and that a
## spec's joints become Void Salvage joints.
##   tools/run_tests.sh shared_components

const KINDS := [ConnectionData.Kind.WELD, ConnectionData.Kind.RIVET, ConnectionData.Kind.BOLT,
		ConnectionData.Kind.CONNECTOR]
## How far a joint may sit outside its part's bounds, metres.
const SLACK := 0.02


func run_tests() -> void:
	var lib := Modules.bus("shared_components") as SharedComponentsBus
	check(lib != null, "shared_components bus is loaded")
	if lib == null:
		return
	check(lib.source_commit.length() == 40, "SOURCE_COMMIT names a Void Salvage commit: '%s'" % lib.source_commit)
	check(lib.specs_version >= 1, "specs carry a schema version")
	check(lib.fastener("M12") != null and lib.fastener("M12").torque_nm.x > 0.0, "M12 has a torque window")
	check(lib.build_spec("NoSuchPart") == null and not lib.is_buildable("NoSuchPart"), "unknown part is not buildable")
	check(lib.make_shape("NoSuchPart") == null, "unknown part has no shape")
	check(lib.part_names("frame").has("TankBracket"), "the 0.1 bracket is in the frame category")
	check(lib.is_buildable("DeckPlate") and lib.is_buildable("TankBracket"), "release 0.1 parts are buildable")

	check(lib.material_ids().size() == Materials.TABLE.size() and lib.material_ids()[0] != "", "the materials table is shared")
	check(lib.is_material("steel") and lib.is_material("titanium") and not lib.is_material("cheese"), "material ids resolve")
	check(Materials.tier("veil") > Materials.tier("steel"), "Materials tiers come through")
	var plate := PartData.new(1, "DeckPlate", PartData.Kind.HULL, 100.0, 10.0, Transform3D.IDENTITY)
	Materials.assign(plate, "alloy")
	check(plate.material == "alloy" and plate.mass < 100.0, "Materials.assign rescales mass by density")

	_check_fittings()

	for part_name in lib.part_names():
		_check_spec(lib, lib.build_spec(part_name))


## Void Salvage's player-ship fittings build on a BSX body with its own ShipKit.
func _check_fittings() -> void:
	var body := RigidBody3D.new()
	var kit := ShipKit.new(body)
	var frame := Transform3D.IDENTITY
	var built: Array[Dictionary] = [
		ShipParts.seat(kit, Vector3.ZERO, "seat_0"),
		ShipParts.console(kit, frame, 1.2),
		ShipParts.locker(kit, frame),
		ShipParts.breaker_panel(kit, frame),
		ShipParts.reactor_cabinet(kit, frame, 1.0),
	]
	for f in built:
		check(f.has("name") and f.has("box") and (f["box"] as AABB).size.length() > 0.0,
				"ShipParts fitting '%s' builds with a box" % f.get("name", "?"))
	check(body.get_child_count() > 0, "ShipParts fittings add their pieces to the body")
	check(ShipKit.mono_font() != null, "ShipKit.mono_font is shared")
	body.free()


func _check_spec(lib: SharedComponentsBus, s: BuildSpec) -> void:
	var p := s.part_name
	check(s.version >= 1, "%s: version" % p)
	check(s.display_name != "" and s.category != "", "%s: display name and category" % p)
	check(s.mass > 0.0, "%s: mass" % p)
	check(lib.is_material(s.material), "%s: material '%s' is a Void Salvage material" % [p, s.material])
	check(s.shape in SharedComponentsBus.SHAPES, "%s: known shape builder '%s'" % [p, s.shape])
	var shape := lib.make_shape(p)
	check(shape != null and shape.mesh != null and shape.collision != null and shape.volume > 0.0,
			"%s: Void Salvage builds its mesh, collision and volume" % p)
	if shape == null:
		return
	var box := shape.aabb().grow(SLACK)
	check(not s.joints.is_empty(), "%s: has joints" % p)
	var seen := {}
	for i in s.joints.size():
		var jt := s.joints[i]
		var what := "%s joint %d" % [p, i]
		check(jt.kind in KINDS, "%s: a ConnectionData kind" % what)
		check(box.has_point(jt.at), "%s: on the part (%s in %s)" % [what, jt.at, box])
		check(is_equal_approx(jt.normal.length(), 1.0), "%s: unit normal" % what)
		if jt.kind == ConnectionData.Kind.BOLT or jt.kind == ConnectionData.Kind.RIVET:
			var f := lib.fastener(jt.fastener)
			check(f != null and f.kind == jt.kind, "%s: fastener '%s' exists and matches" % [what, jt.fastener])
		if jt.kind == ConnectionData.Kind.CONNECTOR:
			check(jt.port != "", "%s: connector names a port" % what)
		if jt.kind == ConnectionData.Kind.WELD:
			check(jt.seam_size.x > 0.0 and jt.seam_up != Vector3.ZERO, "%s: weld has a seam" % what)
		var c := jt.to_connection(100 + i, 1, 2, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(1, 2, 3)))
		check(c.kind == jt.kind and c.health == c.max_health, "%s: becomes a whole Void Salvage joint" % what)
		check(c.local_position.is_equal_approx(Vector3(1, 2, 3) + Basis(Vector3.UP, PI / 2) * jt.at),
				"%s: joint moves into structure space" % what)
	for k in s.order:
		check(k >= 0 and k < s.joints.size() and not seen.has(k), "%s: order %d is a joint, once" % [p, k])
		seen[k] = true
	check(seen.size() == s.joints.size(), "%s: order covers every joint" % p)
	for lp in s.lift_points:
		check(box.has_point(lp), "%s: lift point on the part" % p)
