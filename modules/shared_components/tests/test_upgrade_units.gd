extends ModuleTest
## Component upgrades, stage U1: the attractor coil at three tiers builds as parts and
## joints that fit Void Salvage's slot box, each tier bigger, with a bolted cover and three
## internal mount points; the quantum core, field emitter array and control board fit on
## them by the mount's trade; the rules file says what each tier and add-on does and
## refuses what doesn't fit.
##   tools/run_tests.sh shared_components

const FAMILY := "attractor_coil"


func run_tests() -> void:
	_check_rules()
	var sizes: Array[Vector3] = []
	for tier in [1, 2, 3]:
		sizes.append(_check_unit(tier))
	check(sizes[0].x < sizes[1].x and sizes[1].x < sizes[2].x and sizes[0].y < sizes[1].y and sizes[1].y < sizes[2].y,
			"each tier's housing is bigger than the last: %s" % [sizes])
	_check_addons()


func _check_rules() -> void:
	var r := UpgradeRules.reread()
	check(int(r.get("version", 0)) >= 1 and r.get("format", "") == "bsx-upgrade-rules", "the rules file has a version")
	check(UpgradeRules.family_ids().has(FAMILY), "the attractor coil is a family")
	check(UpgradeRules.tier_count(FAMILY) == 3, "three tiers")
	check(UpgradeRules.unit_id(FAMILY, 1) == "attractor_coil_1" and UpgradeRules.unit_id(FAMILY, 3) == "attractor_coil_3",
			"tiers are the module ids the ships' saves use")
	check(UpgradeRules.unit_id(FAMILY, 4) == "" and UpgradeRules.family_of_unit("hold_net") == "", "unknown tiers and units are nothing")
	check(UpgradeRules.family_of_unit("attractor_coil_2") == FAMILY and UpgradeRules.tier_of_unit(FAMILY, "attractor_coil_2") == 2,
			"a unit id knows its family and tier")
	var lib := Modules.bus("shared_components") as SharedComponentsBus
	if lib:
		for tier in [1, 2, 3]:
			check(lib.is_ship_module(UpgradeRules.unit_id(FAMILY, tier)), "tier %d is a ship module BSX sells" % tier)
	check(UpgradeRules.max_addons(FAMILY) == 3 and UpgradeRules.mounts(FAMILY).size() == 3, "a unit holds three add-ons, one per mount point")
	check(not bool(UpgradeRules.family(FAMILY).get("tier_3_needs_bay", true)), "tier 3 needs no special bay in U1")
	var slot := UpgradeRules.slot_box(FAMILY)
	check(slot.is_equal_approx(Vector3(1.4, 0.3, 0.4)), "the slot box is Void Salvage's: %s" % slot)
	for tier in [1, 2, 3]:
		var s := UpgradeRules.unit_size(FAMILY, tier)
		check(s.x <= slot.x and s.y <= slot.y and s.z < slot.z, "tier %d's housing fits the slot box: %s" % [tier, s])
	# Figures.
	var base := UpgradeRules.base_stats(FAMILY)
	check(is_equal_approx(base.get("attract_max_mass", 0.0), 8000.0) and is_equal_approx(base.get("attract_reach", 0.0), 18.0),
			"the base figures are Void Salvage's as built")
	var last_mass := 0.0
	var last_reach := 0.0
	for tier in [1, 2, 3]:
		var st := UpgradeRules.stats(UpgradeRules.unit_id(FAMILY, tier))
		check(st["attract_max_mass"] > last_mass and st["attract_reach"] >= last_reach, "tier %d lifts more and reaches as far or further: %s" % [tier, st])
		check(st.has("attract_speed") and st.has("attract_accel"), "tier %d keeps the base's other figures" % tier)
		last_mass = st["attract_max_mass"]
		last_reach = st["attract_reach"]
	check(is_equal_approx(UpgradeRules.stats("attractor_coil_1")["attract_max_mass"], 8000.0 * 1.5)
			and is_equal_approx(UpgradeRules.stats("attractor_coil_2")["attract_max_mass"], 8000.0 * 2.5),
			"Mk I and II match Void Salvage's x1.5 and x2.5")
	var with := UpgradeRules.stats("attractor_coil_2", ["quantum_core_2", "field_emitter_1"])
	var without := UpgradeRules.stats("attractor_coil_2")
	check(is_equal_approx(with["attract_reach"], without["attract_reach"] + 4.0 + 3.0), "add-ons add their tier's reach: %s" % with["attract_reach"])
	check(is_equal_approx(with["attract_max_mass"], without["attract_max_mass"] + 2500.0), "the core adds its tier's mass")
	check(is_equal_approx(with["attract_speed"], without["attract_speed"] + 1.0), "the emitter adds speed")
	# Add-on ids and the refusals.
	check(UpgradeRules.addon_ids().size() == 3, "three add-on kinds: %s" % [UpgradeRules.addon_ids()])
	check(UpgradeRules.parse_addon("quantum_core_3") == {"kind": "quantum_core", "tier": 3}
			and UpgradeRules.parse_addon("control_board") == {"kind": "control_board", "tier": 1}, "add-on ids parse")
	check(UpgradeRules.parse_addon("quantum_core_4").is_empty() and UpgradeRules.parse_addon("warp_core").is_empty(), "bad add-on ids are nothing")
	check(UpgradeRules.addon_id("quantum_core", 2) == "quantum_core_2" and UpgradeRules.addon_id("control_board", 1) == "control_board",
			"add-on ids are made the same way back")
	check(UpgradeRules.addons_for(FAMILY).size() == 7, "the coil takes seven add-on parts: %s" % [UpgradeRules.addons_for(FAMILY)])
	check(UpgradeRules.mount_for("field_emitter_2") == "emitter_flange", "the emitter goes on the flange")
	check(UpgradeRules.can_fit("attractor_coil_1", "quantum_core_1"), "a Q1 core fits a Mk I")
	check(UpgradeRules.refusal("attractor_coil_1", "quantum_core_2") != "", "a Q2 core needs a Mk II: '%s'" % UpgradeRules.refusal("attractor_coil_1", "quantum_core_2"))
	check(UpgradeRules.can_fit("attractor_coil_3", "quantum_core_3", ["field_emitter_3", "control_board"]), "a third add-on fits on the free mount")
	check(UpgradeRules.refusal("attractor_coil_2", "quantum_core_1", ["quantum_core_2"]) != "", "one core per coil bay")
	check(UpgradeRules.refusal("attractor_coil_3", "quantum_core_1", ["a", "b", "c"]) != "", "three is the cap")
	check(UpgradeRules.refusal("hold_net", "quantum_core_1") != "" and UpgradeRules.refusal("attractor_coil_1", "warp_core") != "",
			"unknown units and add-ons are refused")


## One tier: the housing and cover as two parts, bolted and tacked, inside the slot box;
## the mount points inside the housing. Returns the housing's size.
func _check_unit(tier: int) -> Vector3:
	var body := RigidBody3D.new()
	var kit := ShipKit.new(body)
	kit.model = PartModel.new(body, true)
	var at := Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0))
	var unit := UpgradeUnits.attractor_coil(kit, tier, at, "slot:attractor_coil")
	check(not unit.is_empty() and unit.get("unit", "") == "attractor_coil_%d" % tier, "tier %d builds as its module id" % tier)
	if unit.is_empty():
		body.free()
		return Vector3.ZERO
	check(unit["part"] != null and unit["cover"] != null and unit["part"] != unit["cover"], "tier %d: a housing and a cover part" % tier)
	check(kit.model.parts.size() == 2, "tier %d: exactly two parts (%d)" % [tier, kit.model.parts.size()])
	check((unit["bolts"] as Array).size() == 4 and (unit["tacks"] as Array).size() == 2, "tier %d: the cover is bolted at four corners and tacked twice" % tier)
	for c: ConnectionData in unit["bolts"]:
		check(c != null and c.kind == ConnectionData.Kind.BOLT, "tier %d: cover bolts are bolts" % tier)
	for c: ConnectionData in unit["tacks"]:
		check(c != null and c.kind == ConnectionData.Kind.SPOT, "tier %d: tacks are spot welds" % tier)
	check(kit.model.connections.size() == 6, "tier %d: six joints hold the cover (%d)" % [tier, kit.model.connections.size()])
	var box: AABB = unit["box"]
	var slot := UpgradeRules.slot_box(FAMILY)
	check(box.size.x <= slot.x + 0.001 and box.size.y <= slot.y + 0.001 and box.size.z <= slot.z + 0.001, "tier %d: the box fits the slot: %s" % [tier, box.size])
	check(box.has_point(Vector3.ZERO), "tier %d: the box is round the unit's origin" % tier)
	check((unit["part"] as PartData).path == "slot:attractor_coil/attractor_coil_%d" % tier, "tier %d: the housing's path names the slot and unit" % tier)
	check((unit["part"] as PartData).mass > 1.0 and (unit["cover"] as PartData).mass > 0.1, "tier %d: the parts weigh something (%.1f, %.1f kg)" % [tier, (unit["part"] as PartData).mass, (unit["cover"] as PartData).mass])
	# The looks are on the body, inside the box (ship space).
	var meshes := 0
	for n in body.get_children():
		if n is MeshInstance3D:
			meshes += 1
	check(meshes >= 2, "tier %d: the parts' looks are on the body (%d)" % [tier, meshes])
	var world_box := AABB(at.origin + box.position - Vector3.ONE * 0.09, box.size + Vector3.ONE * 0.18)
	var inside := true
	for n in _all_meshes(body):
		var aabb: AABB = n.global_transform * n.mesh.get_aabb() if n.is_inside_tree() else (n.transform * n.mesh.get_aabb())
		if n.get_parent() != body:
			aabb = _to_body(n) * n.mesh.get_aabb()
		if not world_box.encloses(aabb):
			inside = false
	check(inside, "tier %d: every piece is inside the unit's box" % tier)
	# Mount points.
	var mounts: Array = unit["mounts"]
	check(mounts.size() == 3, "tier %d: three mount points" % tier)
	var ids := PackedStringArray()
	for m: Dictionary in mounts:
		ids.append(m["id"])
		var p: Vector3 = m["at"]
		check(box.grow(0.001).has_point(p), "tier %d: mount %s is in the box" % [tier, m["id"]])
		check((m["normal"] as Vector3).is_normalized() and m.has("trade") and m.has("accepts"), "tier %d: mount %s has a normal, a trade and what it takes" % [tier, m["id"]])
	check(ids.has("core_bay") and ids.has("emitter_flange") and ids.has("harness"), "tier %d: the coil bay, the emitter flange and the harness" % tier)
	check(UpgradeUnits.mount_of(unit, "core_bay")["trade"] == "bolt" and UpgradeUnits.mount_of(unit, "emitter_flange")["trade"] == "weld"
			and UpgradeUnits.mount_of(unit, "harness")["trade"] == "wire", "tier %d: bolted, welded and wired" % tier)
	body.free()
	return box.size


## Every add-on fits its mount by its trade; the rules refuse the wrong ones; a full unit
## is three add-ons.
func _check_addons() -> void:
	var body := RigidBody3D.new()
	var kit := ShipKit.new(body)
	kit.model = PartModel.new(body, true)
	var unit := UpgradeUnits.attractor_coil(kit, 3, Transform3D.IDENTITY)
	var parts_before := kit.model.parts.size()
	var joints_before := kit.model.connections.size()
	var fitted := PackedStringArray()
	var expect := {"quantum_core_3": ConnectionData.Kind.BOLT, "field_emitter_2": ConnectionData.Kind.WELD, "control_board": ConnectionData.Kind.CONNECTOR}
	for id: String in expect:
		var made := UpgradeUnits.fit_addon(kit, unit, id, fitted)
		check(not made.is_empty() and made["part"] != null, "%s fits a Mk III" % id)
		if made.is_empty():
			continue
		check(made["mount"] == UpgradeRules.mount_for(id), "%s went on the %s" % [id, made["mount"]])
		check(not (made["joints"] as Array).is_empty(), "%s is joined" % id)
		for c: ConnectionData in made["joints"]:
			check(c != null and c.kind == expect[id], "%s is joined by its mount's trade" % id)
			if c:
				check((c.part_a == (made["part"] as PartData).id and c.part_b == (unit["part"] as PartData).id) or (c.part_b == (made["part"] as PartData).id and c.part_a == (unit["part"] as PartData).id),
						"%s is joined to the housing" % id)
		check((made["part"] as PartData).part_name == UpgradeUnits.addon_part_name(made["kind"]), "%s is a %s part" % [id, (made["part"] as PartData).part_name])
		check((made["part"] as PartData).path.ends_with("/" + id), "%s's path names it" % id)
		fitted.append(id)
	check(kit.model.parts.size() == parts_before + 3, "three add-on parts (%d)" % (kit.model.parts.size() - parts_before))
	check(kit.model.connections.size() == joints_before + 4, "four add-on joints (%d)" % (kit.model.connections.size() - joints_before))
	# Collision never overlaps between parts (a core in the bore, a board beside the windings).
	check(_no_overlap(kit.model), "no two parts' collision boxes overlap")
	# A fourth is refused, and so is a core on a lesser unit.
	var fourth := UpgradeUnits.fit_addon(kit, unit, "quantum_core_1", fitted)
	check(fourth.is_empty() and UpgradeUnits.last_refusal != "", "a fourth add-on is refused: %s" % UpgradeUnits.last_refusal)
	var stats := UpgradeRules.stats(unit["unit"], fitted)
	check(is_equal_approx(stats["attract_reach"], 30.0 + 6.0 + 5.0) and is_equal_approx(stats["attract_max_mass"], 32000.0 + 5000.0),
			"the full Mk III's figures: %s" % [stats])
	body.free()
	# A core sized for its tier: Q1 fits a Mk I's bore and tray.
	var small := RigidBody3D.new()
	var skit := ShipKit.new(small)
	skit.model = PartModel.new(small, true)
	var mk1 := UpgradeUnits.attractor_coil(skit, 1, Transform3D.IDENTITY)
	var core := UpgradeUnits.fit_addon(skit, mk1, "quantum_core_1")
	check(not core.is_empty(), "a Q1 core fits a Mk I")
	var emitter := UpgradeUnits.fit_addon(skit, mk1, "field_emitter_1", ["quantum_core_1"])
	check(not emitter.is_empty(), "an E1 emitter fits a Mk I")
	var slot := UpgradeRules.slot_box(FAMILY)
	var reach := AABB(-slot * 0.5, slot)
	var all_in := true
	for n in _all_meshes(small):
		var aabb: AABB = _to_body(n) * n.mesh.get_aabb()
		if not reach.grow(0.01).encloses(aabb):
			all_in = false
			print("  outside the slot: %s %s" % [n.get_parent().name if n.get_parent() != small else n.name, aabb])
	check(all_in, "a Mk I with its core and emitter horns stays inside the slot box")
	var refused := UpgradeUnits.fit_addon(skit, mk1, "quantum_core_2", ["quantum_core_1", "field_emitter_1"])
	check(refused.is_empty(), "a Q2 core is refused on a Mk I")
	small.free()


func _all_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


## A node's transform in the body's space (nodes hang off part visuals).
func _to_body(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p is Node3D and p.get_parent() != null and not (p is RigidBody3D):
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _no_overlap(model: PartModel) -> bool:
	# Every collision shape's box (body space), by part; shapes of different parts never meet.
	var boxes: Array[Array] = []
	for id: int in model.parts:
		var colliders: Array = [model.part_collider(id)]
		colliders.append_array(model.extra_colliders(id))
		for c in colliders:
			if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
				boxes.append([id, (c as CollisionShape3D).transform * (c as CollisionShape3D).shape.get_debug_mesh().get_aabb()])
	var clear := true
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if boxes[i][0] != boxes[j][0] and (boxes[i][1] as AABB).grow(-0.001).intersects(boxes[j][1]):
				print("  overlap: %s and %s" % [model.parts[boxes[i][0]].part_name, model.parts[boxes[j][0]].part_name])
				clear = false
	return clear
