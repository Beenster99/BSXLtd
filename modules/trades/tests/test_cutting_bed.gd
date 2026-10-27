extends ModuleTest
## trades.cutting_bed (beenster, 0.3.23): the plate hall's plasma cutting bed and the templates
## it cuts. The bed's own stored sizes and traced ones (the scribe run round a plate of the
## Kestrel, measured into "T-001"), kept in the save; a plate on the bed, a template picked on
## the console and CUT: the gantry runs the torch round it (pierce, cut, lift, park), the kerf
## glows, and the piece and the offcut lie on the bed for the tractor beam; too big refuses; a
## plate that only fits turned is turned; glass gets the water jet; a plate let go of over the
## bed settles onto it.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const STEEL := {"id": "SteelPlate_2500x1250_5", "size": Vector2(2.5, 1.25), "thickness": 0.005,
		"material": "steel", "family": "metal", "condition": 1.0}


func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in ["trades.tractor", "trades.cutting_bed"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	bus.reset_data()

	# The bed's own stored sizes.
	var lib := bus.templates()
	check(lib.size() == TradesPlateShapes.LIBRARY.size() and lib.all(func(t: Dictionary) -> bool:
			return (t.size as Vector2).x > 0.1 and (t.outline as PackedVector2Array).size() >= 3),
			"the bed stores %d template sizes" % lib.size())
	var ring := lib.filter(func(t: Dictionary) -> bool: return t.id == "L-RING-600")[0] as Dictionary
	check(absf(TradesPlateShapes.area_of(ring) - PI * (0.09 - 0.0225)) < 0.01, "the flange ring has its hole: %.3f m²" % TradesPlateShapes.area_of(ring))

	# Measuring: a trace part way round is nothing yet; all the way round is the plate.
	var edges := PackedVector2Array([Vector2(-0.6, -0.3), Vector2(0.6, -0.3), Vector2(0.6, 0.3), Vector2(-0.6, 0.3)])
	var half_way := _trace(edges, 0.0, 0.5, 0.03)
	check(TradesPlateShapes.measure(half_way, edges, 0.09, 24, 0.85).is_empty(), "half way round isn't a template yet")
	var measured := TradesPlateShapes.measure(_trace(edges, 0.0, 1.0, 0.03), edges, 0.09, 24, 0.85)
	check(not measured.is_empty() and (measured.size as Vector2).is_equal_approx(Vector2(1.2, 0.6)), "all the way round measures 1200 x 600")

	# The yard, with the worker and the bed.
	ship_bus.load_ship("vs_kestrel")
	var yard := FAKE_YARD_node()
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 12)
	yard.set("walker", walker)
	yard.add_child(walker)
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	check(rig.hotbar.has(&"template") and rig.tool_node(&"template") is TradesTemplateScribe, "the scribe is on the hotbar")
	if rig.cutting_bed == null:
		rig.build_cutting_bed(Transform3D(Basis(), Vector3(-20, 0, 0)))
	var bed := rig.cutting_bed
	var tracer := rig.tracer
	check(bed != null and tracer != null, "the bed and the tracer are in the yard")
	check(bed.get_node_or_null("Console/Screen") is TouchScreen, "the console has its touch screen")

	# Tracing a plate of the Kestrel: the chalk round its edge makes T-001.
	var plate_slot: MountSlot = null
	for s: MountSlot in ship_bus.get_slots():
		if not TradesPlateTracer.plate_at(s.box.get_center()).is_empty() and (TradesPlateTracer.plate_at(s.box.get_center()).slot as MountSlot) == s:
			plate_slot = s
			break
	check(plate_slot != null, "the Kestrel has a plate to trace: %s" % (plate_slot.slot_id if plate_slot else "none"))
	if plate_slot:
		var found := TradesPlateTracer.plate_at(plate_slot.box.get_center())
		var ax: Vector3i = found.axes
		var b: AABB = found.box
		var c := b.get_center()
		var half := Vector2(b.size[ax.x], b.size[ax.y]) * 0.5
		var outline := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
		var normal := Vector3.ZERO
		normal[ax.z] = 1.0
		var ship := rig.ship_transform()
		var before := bus.templates().size()
		for p in _trace(outline, 0.0, 1.0, 0.025):
			var at := c
			at[ax.x] += p.x
			at[ax.y] += p.y
			tracer.chalk_at(ship * at, ship.basis * normal)
			if bus.templates().size() > before:
				break
		var made := bus.templates().filter(func(t: Dictionary) -> bool: return t.kind == "traced")
		check(made.size() == 1 and made[0].id == "T-001" and made[0].source == plate_slot.slot_id,
				"tracing round it makes template T-001 from %s" % plate_slot.slot_id)
		if not made.is_empty():
			check((made[0].size as Vector2).is_equal_approx(half * 2.0), "it measures the plate: %s" % made[0].size)
		check(bus.next_template_id() == "T-002", "the next is T-002")
		check(not (tracer.get_node("Chalk") as MeshInstance3D).mesh.get_surface_count() == 0, "a chalk line is left on it")
		# Kept in the save, gone with a new game.
		var data := bus.save_data()
		bus.reset_data()
		check(bus.templates().size() == before, "a new game has only the bed's own")
		bus.load_data(JSON.parse_string(JSON.stringify(data)), bus.save_version())
		check(bus.templates().size() == before + 1 and bus.next_template_id() == "T-002", "the traced template comes back from the save")

	# Cutting: a disc out of a steel sheet.
	bed.set_plate(STEEL)
	bed.pick("L-DISC-600")
	check(bed.refusal("L-DISC-600") == "", "a disc fits the sheet")
	var gantry_x := (bed.get_node("Gantry") as Node3D).position.x
	check(bed.cut() == "", "CUT starts it")
	check(not bed.job.is_empty(), "the run is going")
	var saw_pierce := false
	var saw_lit := false
	var lowest := 1.0
	var moved := false
	var kerf_hot := false
	for i in 2000:
		if bed.job.is_empty():
			break
		bed._process(0.05)
		var step: Dictionary = bed.job.program[mini(int(bed.job.step), bed.job.program.size() - 1)] if not bed.job.is_empty() else {}
		if step.get("kind", "") == "pierce":
			saw_pierce = true
		saw_lit = saw_lit or (bed.get_node("Arc") as OmniLight3D).visible
		lowest = minf(lowest, bed.torch_h)
		moved = moved or absf((bed.get_node("Gantry") as Node3D).position.x - gantry_x) > 0.5
		kerf_hot = kerf_hot or bed._kerf_points.size() > 20
	check(saw_pierce and saw_lit, "the torch pierces with the arc lit")
	check(lowest < 0.02, "the torch comes down to the plate: %.3f m" % lowest)
	check(moved, "the gantry runs along its rails")
	check(kerf_hot, "a kerf is left behind it")
	check(bed.job.is_empty() and bed.plate.is_empty(), "it finishes and the sheet is used")
	check(bed.head.is_equal_approx(TradesCuttingBed.PARK), "the head goes back to park")
	var beam := rig.ship_station().tractor
	check(bed.made.size() == 2 and beam.loose.has(bed.made[0]) and beam.loose.has(bed.made[1]), "the piece and the offcut lie loose for the beam")
	if bed.made.size() == 2:
		var piece: TradesLoosePart = beam.loose[bed.made[0]]
		check(piece.component == "SteelPlate_2500x1250_5:cut:L-DISC-600", "the piece is named for the sheet and template: %s" % piece.component)
		check(absf(piece.mass - PI * 0.09 * 0.005 * 7850.0) < 1.0, "it weighs a 600 mm steel disc: %.1f kg" % piece.mass)
		var off: TradesLoosePart = beam.loose[bed.made[1]]
		check(off.mass > piece.mass, "the offcut is the rest of the sheet")
		beam.take_away(bed.made[0])
		check(not beam.loose.has(bed.made[0]), "a piece can be taken away")

	# Too big, and turned to fit.
	bed.set_plate({"id": "x", "size": Vector2(0.4, 0.4), "thickness": 0.003, "material": "steel", "family": "metal"})
	check(bed.refusal("L-RECT-1000x500") == "Too big for this plate", "a template bigger than the plate is refused")
	bed.set_plate({"id": "y", "size": Vector2(0.6, 1.1), "thickness": 0.003, "material": "steel", "family": "metal"})
	check(bed.refusal("L-RECT-1000x500") == "", "a plate it only fits turned takes it turned")

	# Glass gets the water jet.
	bed.set_plate({"id": "g", "size": Vector2(1.0, 1.0), "thickness": 0.006, "material": "glass", "family": "glass"})
	bed._place_head()
	check(bed.is_glass() and bed._jet_head.visible and not bed._plasma_head.visible, "glass is cut with the water jet")
	check(bed._feed() < 0.05, "and slower: %.3f m/s" % bed._feed())
	bed.set_plate({})

	# A stock plate let go of over the bed settles on it (with Shared Components' plates).
	if TradesCuttingBed.stock_plates():
		var ids: PackedStringArray = TradesCuttingBed.stock_plates().call("item_ids", "metal")
		var pick := ""
		for id in ids:
			if TradesCuttingBed.fits_bed(TradesCuttingBed.plate_info(id).size):
				pick = id
				break
		var visual := Node3D.new()
		var info := TradesCuttingBed.plate_info(pick)
		var part := beam.adopt_piece("stock:test", pick, AABB(Vector3(-0.5, -0.003, -0.5), Vector3(1, 0.006, 1)), visual,
				bed.global_transform * Transform3D(Basis(), Vector3(0, 1.1, 0)), 20.0)
		part.freeze = true
		part.linear_velocity = Vector3.ZERO
		await physics(2)
		check(bed.plate.get("id", "") == pick and not beam.loose.has("stock:test"), "a %s let go of over the bed settles onto it" % info.get("id", pick))

	bus.reset_data()
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


## Points along an outline from `from` to `to` (0..1 of its perimeter), every `step` m.
func _trace(outline: PackedVector2Array, from: float, to: float, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var total := TradesPlateShapes.perimeter_of(outline)
	var d := from * total
	while d <= to * total:
		var run := 0.0
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			var l := a.distance_to(b)
			if d <= run + l:
				out.append(a.lerp(b, (d - run) / l))
				break
			run += l
		d += step
	return out


func FAKE_YARD_node() -> Node3D:
	var script := GDScript.new()
	script.source_code = FAKE_YARD
	script.reload()
	var n := Node3D.new()
	n.set_script(script)
	return n
