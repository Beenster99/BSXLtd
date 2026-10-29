extends ModuleTest
## trades.scribe_beams (beenster, 0.3.29: "scribe tool should pick beams now too"): the scribe
## on a member of her bare frame, or on a beam of the hologram, lights it, the panel gives its
## length and section, and a left click puts that length on the cutting bed's cut list. Her
## plating is still a plate.

func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in ["trades.cutting_bed", "trades.scribe_beams", "trades.beam_designer"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	bus.reset_data()
	var yard: Node3D = load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)).instantiate()
	add_child(yard)
	await frames(30)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var tr := rig.tracer
	check(tr != null and rig.cutting_bed != null, "the scribe and the cutting bed are in the yard")
	if tr == null or rig.cutting_bed == null:
		return
	var xf := rig.ship_transform()
	# A ring member on her starboard side, from her file.
	var ring: Dictionary = {}
	for p: Variant in TradesBeamDesigner._ship_file(ship_bus.ship).get("parts", []):
		if p is Dictionary and str(p.get("name", "")) == "FrameRing" and str(p.shape.shape) == "girder" \
				and VsShipImport.vec3(p.xform.o).x > 2.0 and float(p.shape.args[0]) > 0.5:
			ring = p
			break
	check(not ring.is_empty(), "a ring member on her side")
	var o := VsShipImport.vec3(ring.xform.o)
	var from := o + Vector3(2.5, 0, 0)
	# Plated: the scribe finds the plate, not the member.
	var hit := _cast(rig, xf * from, xf.basis * Vector3.LEFT)
	check(tr.beam_at(xf * from, xf.basis * Vector3.LEFT, hit).is_empty(), "under her plating it's a plate")
	# Bare: strip the plates over it.
	for s: MountSlot in ship_bus.get_slots():
		if s.slot_id.begins_with("plate_") and s.box.grow(0.4).has_point(o):
			for f in s.fasteners:
				ship_bus.note_joint_removed(f.joint_id)
	await physics_frames(2)
	for p: Node in yard.find_children("Loose_plate_*", "RigidBody3D", true, false):
		(p as RigidBody3D).freeze = true
		(p as RigidBody3D).global_position += Vector3.DOWN * 40.0
	await physics_frames(2)
	hit = TradesPlateTracer.through_gone(rig.worker.get_world_3d().direct_space_state, xf * from, xf.basis * Vector3.LEFT, [rig.worker.get_rid()])
	var b := tr.beam_at(xf * from, xf.basis * Vector3.LEFT, hit)
	check(not b.is_empty() and str(b.source) == str(ring.path), "on the bare frame the scribe picks the member: %s" % [b.get("source", hit.get("collider"))])
	if not b.is_empty():
		var mm := roundi(float(ring.shape.args[0]) * 1000.0)
		check(TradesPlateTracer.beam_mm(b) == mm, "its length: %d mm" % TradesPlateTracer.beam_mm(b))
		tr._aim_beam(b)
		check("\n".join(tr.beam_lines()).contains("Length  %d mm" % mm) and "\n".join(tr.beam_lines()).contains("Section  140 x 180 mm"),
				"the panel gives its length and section: %s" % [tr.beam_lines()])
		check(HudSlots.infos().any(func(c: Dictionary) -> bool: return c.id == TradesPlateTracer.INFO and str(c.title) == "Beam"), "the panel shows it")
		var before: int = rig.cutting_bed.lengths.size()
		tr.set_tracing(true)
		check(rig.cutting_bed.lengths.size() == before + 1 and int(rig.cutting_bed.lengths[-1].mm) == mm, "a click puts it on the cutting bed's cut list")
	# A hologram beam in the air beside her.
	var a := o + Vector3(1.0, 1.0, 0)
	bus.set_beam_design(ship_bus.ship.ship_id, [{"id": 1, "a": [a.x, a.y, a.z - 1.0], "b": [a.x, a.y, a.z + 1.2], "section": "box_100x100x5", "turn": 0.0}])
	var eye := a + Vector3(2.0, 0, 0)
	hit = _cast(rig, xf * eye, xf.basis * Vector3.LEFT)
	var hb := tr.beam_at(xf * eye, xf.basis * Vector3.LEFT, hit)
	check(str(hb.get("source", "")) == "holo:1" and TradesPlateTracer.beam_mm(hb) == 2200, "a hologram beam: %s" % [hb])
	tr._aim_beam({})
	# Off: no beams.
	Flags.set_flag("trades.scribe_beams", false)
	check(not TradesPlateTracer.beams_on(), "the flag turns it off")

	bus.reset_data()
	yard.queue_free()
	await frames(2)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _cast(rig: TradesBay, from: Vector3, dir: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * TradesPlateTracer.REACH_M)
	q.exclude = [rig.worker.get_rid()]
	return rig.worker.get_world_3d().direct_space_state.intersect_ray(q)


func physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
