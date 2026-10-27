extends ModuleTest
## Ship and Bay: Settings > Debug > Ship's random wrecks (beenster, 26 Oct). A press rolls a
## small, medium or large generated wreck and makes it the bay's ship in place of the Kestrel,
## the same on every machine: set down on the cradle's saddles (a medium cradle for the bigger
## ones), with the scissor lift, scaffolds and power unit, and a marker on every weld, bolt and
## rivet still on it, which the trades work like the Kestrel's. "Bring the Kestrel back" puts
## things back.
##   tools/run_tests.sh ship_bay

const DebugPanel := preload("res://modules/ship_bay/internal/ui/debug_ships_panel.gd")
const FileShip := preload("res://modules/ship_bay/internal/ships/file_ship_model.gd")
const Bay := preload("res://modules/ship_bay/internal/bay/bay.gd")
const TransportCradle := preload("res://modules/ship_bay/internal/yard/transport_cradle.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var a := ShipBayBus.random_wreck(42)
	check(a == ShipBayBus.random_wreck(42) and VsWreckLibrary.is_vs_wreck(str(a.design)), "the same roll gives the same Void Salvage wreck: %s" % [a])
	check(not (a.events as Array).is_empty() and (a.events as Array).size() <= 3, "with one to three wreck events: %s" % [a.events])
	check(VsWreckLibrary.size_of(str(ShipBayBus.random_wreck(7, "L").design)) == "L"
			and VsWreckLibrary.size_of(str(a.design)) == "S", "rolled at the size asked for")
	var was := Flags.is_on("ship_bay.bay_cradle")
	Flags.set_flag("ship_bay.bay_cradle", true)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var bay: Node3D = yard.get("bay")
	var panel := DebugPanel.new(bus)
	add_child(panel)
	check(bus.ship != null and bus.ship.ship_id == "vs_kestrel", "the Kestrel is in the bay")
	# Pinned rolls: a courier on landing legs, then tugs with low sterns and wings (they once
	# sat up to 1.2 m over the saddles on loose part boxes).
	bus.wreck_seed = 9
	(panel.get_node("Wreck") as Button).pressed.emit()
	await frames(2)
	_check_wreck(bus, bay, "small")
	check(str(bay.get("cradle").get("size")) == Bay.cradle_size_for(bus.ship.bounds.size.z), "in the cradle for its length (%s, %.1f m)" % [bay.get("cradle").get("size"), bus.ship.bounds.size.z])
	check((bus.snapshot().get("bay_wreck", {}) as Dictionary) == bus.bay_wreck and str(bus.snapshot().get("ship_id", "")) == ShipBayBus.WRECK_ID,
			"it goes in the save")
	check(str((panel.get_node("Wreck") as Button).text) == "Another small wreck", "the button offers another")
	check(str((panel.get_node("Kestrel") as Button).text) == "Bring the Kestrel back", "and the Kestrel back")
	# Working it: a joint undone and made again, as the trades' tools do.
	var s: MountSlot
	for slot in bus.ship.slots:
		if slot.fasteners.size() > 1 and bus.is_joint_tight(slot.fasteners[0].joint_id):
			s = slot
			break
	var jid := s.fasteners[0].joint_id
	check(bus.note_joint_removed(jid) and not bus.is_joint_tight(jid) and bus.get_slot_state(s.slot_id) == ShipBayBus.SlotState.LOOSENED,
			"a joint on it comes undone (%s)" % jid)
	check(bus.note_joint_made(jid, 0.9) and bus.is_joint_tight(jid), "and is made again")
	var marker: MeshInstance3D = (bay.get("markers") as Dictionary)[jid]
	check(marker.material_override != null, "its marker shows it")
	# A late joiner builds the same one, with what was done to it.
	bus.note_joint_removed(jid)
	var snap := bus.snapshot()
	bus.restore({})
	await frames(1)
	check(bus.ship == null and bay.get("model") == null, "restored empty: no wreck")
	bus.restore(snap)
	await frames(1)
	check(bus.ship != null and bus.ship.ship_id == ShipBayBus.WRECK_ID and bay.get("model") is FileShip and not bus.is_joint_tight(jid),
			"restored: the same wreck again, the joint still undone")
	# 0.3.22 saved a wreck with no ship in the bay.
	var old := snap.duplicate(true)
	old.erase("ship_id")
	old.erase("slots")
	bus.restore({})
	bus.restore(old)
	await frames(1)
	check(bus.ship != null and bus.ship.ship_id == ShipBayBus.WRECK_ID, "a 0.3.22 save's wreck comes back as the bay's ship")
	for size: String in ["M", "L"]:
		bus.wreck_seed = 9 if size == "M" else 6
		var t := Time.get_ticks_msec()
		(panel.get_node("Wreck" + size) as Button).pressed.emit()
		await frames(2)
		var word := str(ShipBayBus.WRECK_SIZES[size]).to_lower()
		_check_wreck(bus, bay, word)
		check(str(bay.get("cradle").get("size")) == Bay.cradle_size_for(bus.ship.bounds.size.z), "a %s wreck in the cradle for its length (%s, %.1f m, %d ms to build)"
				% [word, bay.get("cradle").get("size"), bus.ship.bounds.size.z, Time.get_ticks_msec() - t])
	for pair: Array in [["S", 2], ["L", 2]]:
		bus.wreck_seed = pair[1]
		(panel.get_node("Wreck" if pair[0] == "S" else "Wreck" + str(pair[0])) as Button).pressed.emit()
		await frames(2)
		_check_wreck(bus, bay, "%s (roll %d)" % [str(ShipBayBus.WRECK_SIZES[pair[0]]).to_lower(), pair[1]])
	bus.wreck_seed = -1
	(panel.get_node("Kestrel") as Button).pressed.emit()
	await frames(2)
	check(bus.ship != null and bus.ship.ship_id == "vs_kestrel" and bus.bay_wreck.is_empty() and not bay.get("model") is FileShip
			and str(bay.get("cradle").get("size")) == "s", "Bring the Kestrel back: the wreck goes, the Kestrel returns to the small cradle")
	check(is_equal_approx(float(bay.get("cradle_height")), TransportCradle.REST + TransportCradle.SADDLE_TOP), "with its deck at the saddle tops")
	panel.queue_free()
	yard.queue_free()
	await frames(2)
	Flags.set_flag("ship_bay.bay_cradle", was)
	bus.reset_data()


## The wreck is the bay's ship, on the saddles, with its access kit and a marker per fastener.
func _check_wreck(bus: ShipBayBus, bay: Node3D, word: String) -> void:
	var model: Node3D = bay.get("model")
	check(bus.ship != null and bus.ship.ship_id == ShipBayBus.WRECK_ID and model is FileShip and model.get_child_count() > 50,
			"the %s wreck is the bay's ship: %d pieces" % [word, model.get_child_count() if model else 0])
	var c: Node3D = bay.get("cradle")
	check(c.get("load_node") == bay.get("ship_root"), "on the bay's cradle, so the dolly can move it")
	var kinds := {}
	var count := 0
	for s in bus.ship.slots:
		for f in s.fasteners:
			kinds[f.kind] = int(kinds.get(f.kind, 0)) + 1
			count += 1
	var markers: Dictionary = bay.get("markers")
	check(count > 200 and markers.size() == count and kinds.has("weld") and kinds.has("bolt") and kinds.has("rivet"),
			"a marker on every weld, bolt and rivet still on it: %d %s" % [markers.size(), kinds])
	var loose := bus.ship.loose
	check(loose.is_empty() or not bus.is_joint_tight(loose[0]), "its broken joints start undone (%d)" % loose.size())
	var access: Node3D = bay.get("access")
	check(access != null and (access.get("scaffolds") as Array).size() == 2 and access.get("lift") != null and access.get("unit") != null,
			"the scissor lift, scaffolds and power unit are there")
	# Down on the saddles: some saddle touches its belly, none cuts into it.
	var spec: Dictionary = TransportCradle.SIZES[str(c.get("size"))]
	var seat: Vector3 = bay.get("seat")
	var pads: Array = Bay.saddle_points(spec, Vector2(seat.x, seat.z))
	var points: Array[Vector2] = pads[0]
	var tops: Array[float] = pads[1]
	var belly: PackedFloat64Array = model.call("belly_under", points)
	var gap := INF
	for k in points.size():
		if not is_inf(belly[k]):
			gap = minf(gap, float(spec.saddle_top) + seat.y + belly[k] - tops[k])
	# A ship with a keel or a pod lower than its belly (Void Salvage's Sentinel, the Nexus) sits
	# on a cradle beam instead, its belly over the saddles.
	var on_beam := INF
	var flange := 0.4 if str(c.get("size")) == "s" else 0.6
	var beams: Array = []
	for z: float in spec.cross_z:
		beams.append([Rect2(-float(spec.side_x), z - 0.2, float(spec.side_x) * 2.0, 0.4), float(spec.cross_h)])
	for sx: float in [-float(spec.side_x), float(spec.side_x)]:
		beams.append([Rect2(sx - flange * 0.5, -float(spec.length) * 0.5, flange, float(spec.length)), float(spec.side_h)])
	for b: Array in beams:
		var r: Rect2 = b[0]
		var low: float = model.call("lowest_in", Rect2(r.position - Vector2(seat.x, seat.z), r.size))
		if not is_inf(low):
			on_beam = minf(on_beam, float(spec.saddle_top) + seat.y + low - float(b[1]))
	# A long one whose lowest point is past the medium cradle's ends stands on that on the floor.
	var on_floor := float(spec.saddle_top) + seat.y + bus.ship.bounds.position.y + TransportCradle.REST
	check((not is_inf(gap) and gap > -0.03 and gap < 0.08) or (gap > 0.0 and on_beam > -0.03 and on_beam < 0.08)
			or (gap > 0.0 and on_beam > 0.0 and on_floor > -0.03 and on_floor < 0.08),
			"its belly rests on the saddles (gap %.3f m), a keel on a beam (%.3f m) or its lowest point on the floor (%.3f m): %s"
			% [gap, on_beam, on_floor, str(bus.bay_wreck.get("design", ""))])
	var ship_root: Node3D = bay.get("ship_root")
	var nose := ship_root.global_position.z - (bay as Node3D).global_position.z + bus.ship.bounds.position.z
	check(nose > -23.0, "its nose clear of the courtyard's north wall (%.1f m)" % nose)
