extends ModuleTest

const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const DesignConsole := preload("res://modules/design/internal/console/design_console.gd")
## Design Room: the component catalogue (rooms, every component's data), size classes and
## grades (DesignGrades), the ship ratings they add up to (jump range, speed, defence, attack,
## stealth) and the palette's size and grade pickers.
##   tools/run_tests.sh design

var cat := DesignCatalog.load_default()


func run_tests() -> void:
	_catalogue()
	_variants()
	_ratings()
	_masses()
	_moving()
	_doors()
	_orders()
	await _palette()


func _catalogue() -> void:
	for id in ["planning", "recreation", "hall"]:
		check(cat.room(id) != null, "room type %s exists" % id)
	check(cat.parts.size() >= 150, "a big catalogue: %d components" % cat.parts.size())
	var known := {}
	for c: Array in DesignCatalog.CATEGORIES:
		known[c[0]] = true
	var bad: PackedStringArray = []
	for p: DesignPartType in cat.parts.values():
		if not known.has(p.category):
			bad.append("%s: category %s" % [p.id, p.category])
		for r in p.rooms:
			if cat.room(r) == null:
				bad.append("%s: room %s" % [p.id, r])
		if p.shared_part != "" and not VsParts.has(p.shared_part):
			bad.append("%s: VS part %s" % [p.id, p.shared_part])
		var span := DesignGrades.sizes(p)
		if p.size_class > 0 and not (span[0] <= p.size_class and p.size_class <= span[1]):
			bad.append("%s: size range" % p.id)
	check(bad.is_empty(), "every component's data is sound: %s" % [bad])
	for id in ["cooker", "fridge", "kitchen_sink", "seat", "sofa", "corner_sofa", "cupboard", "wall_cupboard",
			"cargo_ramp", "jump_drive", "shield_generator", "turret", "signature_damper", "planning_table"]:
		check(cat.part(id) != null, "component %s exists" % id)


func _variants() -> void:
	var base := cat.part("reactor_small")
	check(base.grade == "S" and DesignGrades.label(base) == "3S", "the base reactor is 3S: %s" % DesignGrades.label(base))
	var big := cat.part("reactor_small:5S")
	check(big != null and big.size_class == 5 and big.base_id == "reactor_small", "a size 5 reactor derives")
	check(big.power > base.power * 3.5 and big.mass > base.mass * 3.0 and big.cost > base.cost * 4.0,
			"two classes up: about 4x the power, more mass and cost")
	check(big.model_scale > 1.5 and big.size.x > base.size.x * 1.5, "and it is drawn bigger: %.2f" % big.model_scale)
	check(cat.part("reactor_small:5S") == big, "variants are cached")
	check(cat.part("reactor_small:3S") == base, "the base size in Standard is the base type itself")
	check(cat.part("reactor_small:9S") == null and cat.part("reactor_small:1S") == null, "no sizes outside its range")
	var light := cat.part("reactor_small:3L")
	var hard := cat.part("reactor_small:3H")
	var quiet := cat.part("reactor_small:3Q")
	var prec := cat.part("reactor_small:3P")
	var junk := cat.part("reactor_small:3R")
	check(light.mass < base.mass and light.cost > base.cost, "Lightweight: lighter, dearer")
	check(hard.integrity > base.integrity * 1.5 and hard.mass > base.mass, "Hardened: tougher, heavier")
	check(quiet.signature < base.signature * 0.6, "Quiet: a smaller signature")
	check(prec.power > base.power * 1.2 and prec.lead_days > base.lead_days, "Precision: more output, longer wait")
	check(junk.cost < base.cost * 0.5 and junk.power < base.power, "Reclaimed: cheap and down on output")
	check(cat.part("bunk:S") == cat.part("bunk") and cat.part("bunk:P") == null, "furniture has no grades")
	var draw := cat.part("main_engine:3P")
	check(draw.power < cat.part("main_engine").power and draw.thrust > cat.part("main_engine").thrust,
			"a Precision engine pushes harder and draws more power")
	check(DesignGrades.variant_id(base, 9, "H") == "reactor_small:8H", "a picked size is kept inside the range")
	check(DesignGrades.variant_id(base, 0, "S") == "reactor_small", "own size, Standard: the bare id")
	check(DesignGrades.variant_id(cat.part("sofa"), 4, "P") == "sofa", "a one-size ungraded part ignores the picks")
	check(cat.part("damper") == null and cat.part("nothing:3S") == null, "unknown types are null")


## A ship with a drive, guns and armour, before and after swapping in better grades.
func _ship(grade: String) -> DesignRecord:
	var d := DesignRecord.new("g", "Gunboat")
	var g := "" if grade == "S" else ":" + grade
	for op in [
		{"op": "add_room", "room": {"id": "r1", "type": "bridge", "x": 0, "z": 0, "w": 5, "d": 4}},
		{"op": "add_room", "room": {"id": "r2", "type": "engineering", "x": 0, "z": 4, "w": 8, "d": 8}},
		{"op": "add_room", "room": {"id": "r3", "type": "fuel", "x": 0, "z": 12, "w": 4, "d": 3}},
		{"op": "add_component", "component": {"id": "c1", "type": "reactor_small" + g, "room": "r2", "x": 1.5, "z": 6, "rot": 0}},
		{"op": "add_component", "component": {"id": "c2", "type": "main_engine" + g, "room": "r2", "x": 5, "z": 6, "rot": 0}},
		{"op": "add_component", "component": {"id": "c3", "type": "jump_drive" + g, "room": "r2", "x": 4, "z": 10, "rot": 0}},
		{"op": "add_component", "component": {"id": "c4", "type": "shield_generator" + g, "room": "r2", "x": 1.5, "z": 10, "rot": 0}},
		{"op": "add_mount", "mount": {"id": "m1", "type": "turret" + g, "deck": 0, "x": 0, "z": 2, "angle": PI}},
	]:
		d.apply(op)
	return d


func _ratings() -> void:
	var t := DesignTotals.compute(_ship("S"), cat)
	for g in DesignGrades.GRADE_ORDER:
		var x := DesignTotals.compute(_ship(g), cat)
		print("ratings %s: %.0f t, CR %d, jump %.1f ly, %.0f m/s, defence %.0f, attack %.0f, stealth %.0f" % [g,
				x.mass / 1000.0, int(x.cost), x.jump_range(), x.speed(), x.defence_rating(), x.attack, x.stealth()])
	check(t.jump_range() > 0.0, "a drive and fuel give a jump range: %.1f ly" % t.jump_range())
	check(t.speed() > 0.0, "an engine gives a top speed: %.0f m/s" % t.speed())
	check(t.attack > 0.0 and t.defence_rating() > t.defence, "a turret attacks, the shield and hull defend")
	check(t.stealth() > 0.0 and t.stealth() < 100.0, "stealth is between 0 and 100: %.0f" % t.stealth())
	var q := DesignTotals.compute(_ship("Q"), cat)
	check(q.stealth() > t.stealth(), "Quiet grades hide the ship better: %.0f > %.0f" % [q.stealth(), t.stealth()])
	var p := DesignTotals.compute(_ship("P"), cat)
	check(p.attack > t.attack and p.jump_range() > t.jump_range(), "Precision grades hit harder and jump further")
	var fit := t.fit({"jump_ly": 1.0, "speed": 99999.0, "defence": 1.0, "attack": 1.0, "stealth": 100.0})
	var by_key := {}
	for f in fit:
		by_key[f.key] = f
	check(by_key.jump_ly.ok and by_key.defence.ok and by_key.attack.ok, "contract demands on the ratings are met")
	check(not by_key.speed.ok and not by_key.stealth.ok, "and missed when out of reach")
	var dry := _ship("S")
	dry.apply({"op": "remove_room", "id": "r3"})
	check(DesignTotals.compute(dry, cat).jump_range() == 0.0, "no fuel aboard, no jump")


## Dry, wet and occupancy mass, and the cargo the holds and racking are rated to carry.
func _masses() -> void:
	var d := _ship("S")
	d.apply({"op": "add_room", "room": {"id": "r4", "type": "quarters", "x": 5, "z": 0, "w": 4, "d": 4}})
	d.apply({"op": "add_room", "room": {"id": "r5", "type": "cargo", "x": 8, "z": 4, "w": 8, "d": 8}})
	var t := DesignTotals.compute(d, cat)
	print("masses: dry %.1f t, fuel %.1f t (%.1f m3), wet %.1f t, occupancy %.1f t (%d aboard), flying %.1f t, cargo max %.1f t (%.0f m3)" % [
			t.dry_mass() / 1000.0, t.fuel_mass / 1000.0, t.fuel_m3, t.wet_mass() / 1000.0, t.occupancy_mass / 1000.0,
			t.crew, t.flying_mass() / 1000.0, t.cargo_max / 1000.0, t.cargo_m3])
	check(t.dry_mass() == t.mass, "dry mass is the built mass")
	check(is_equal_approx(t.fuel_mass, t.fuel_m3 * DesignTotals.FUEL_KG_PER_M3) and t.fuel_mass > 0.0, "full tanks weigh")
	check(is_equal_approx(t.wet_mass(), t.mass + t.fuel_mass), "wet mass is dry plus fuel")
	check(t.crew > 0 and is_equal_approx(t.occupancy_mass, t.crew * DesignTotals.PERSON_KG), "occupancy mass counts the bunks")
	check(t.flying_mass() > t.wet_mass(), "she flies wet and crewed")
	check(is_equal_approx(t.cargo_max, t.cargo_m3 * DesignTotals.CARGO_KG_PER_M3) and t.cargo_max > 0.0, "a cargo room sets cargo max")
	check(is_equal_approx(t.acceleration(), t.thrust * 1000.0 / t.flying_mass()), "the ratings use the flying mass")
	var racked := _ship("S")
	racked.apply({"op": "add_room", "room": {"id": "r5", "type": "cargo", "x": 8, "z": 4, "w": 8, "d": 8}})
	var before := DesignTotals.compute(racked, cat)
	racked.apply({"op": "add_component", "component": {"id": "k1", "type": "pallet_racking", "room": "r5", "x": 12, "z": 5, "rot": 0}})
	var after := DesignTotals.compute(racked, cat)
	check(after.cargo_max > before.cargo_max and after.mass > before.mass, "racking adds cargo max and dry mass, not a load")
	check(after.fuel_mass == before.fuel_mass and after.occupancy_mass == before.occupancy_mass, "empty racking carries nothing")
	for id in ["pallet_racking", "longspan_shelving", "mezzanine_racking", "container_mounting", "tie_down_rails"]:
		var pt := cat.part(id)
		check(pt != null and pt.category == "cargo" and pt.size.x >= 2.5, "%s: big cargo kit" % id)
	var fit := {}
	for f in t.fit({"dry_mass": 1.0, "wet_mass": 1e9, "fuel_mass": 1.0, "occupancy_mass": 1.0, "cargo_max": 1e9}):
		fit[f.key] = f
	check(not fit.dry_mass.ok and fit.wet_mass.ok, "dry and wet mass are caps")
	check(fit.fuel_mass.ok and fit.occupancy_mass.ok and not fit.cargo_max.ok, "fuel, occupancy and cargo max are minimums")


## Moving parts carry what the moving parts test reads: opening, travel time, power while
## moving, rated load and ground clearance, scaled by size and grade like the rest.
func _moving() -> void:
	for id in ["landing_foot_pad", "landing_skid", "undercarriage_leg", "undercarriage_doors", "clamshell_doors",
			"side_hold_door", "belly_hatch", "tail_ramp", "airstair", "stabiliser_jack", "hydraulic_ram", "door_motor",
			"docking_clamp", "folding_solar_array", "folding_radiator", "antenna_mast", "crane_boom", "gangway_tube"]:
		var pt := cat.part(id)
		check(pt != null and pt.category != "" and pt.size_class > 0, "%s is in the catalogue, sized and graded" % id)
		if pt != null:
			check(pt.move_s > 0.0 or pt.move_kw > 0.0 or pt.load_kg > 0.0, "%s has moving-part figures" % id)
	for id in ["cargo_ramp", "landing_gear", "airlock_door", "blast_door", "docking_port", "tow_winch", "turret"]:
		check(cat.part(id).move_s > 0.0, "%s says how long it takes to move" % id)
	for pt: DesignPartType in cat.parts.values():
		if pt.move_s > 0.0:
			check(pt.move_kind in ["hinge_out", "hinge_up", "slide", "spin", "leg", "belt"] and pt.move_range > 0.0,
					"%s says how it moves and how far" % pt.id)
	var leg := cat.part("undercarriage_leg")
	check(leg.load_kg > 0.0 and leg.clearance > 0.0, "a leg has a load per leg and a ground clearance")
	check(cat.part("clamshell_doors").open_size.x > float(DesignCatalog.DOOR_KINDS.cargo.max_w), "clamshell doors open wider than the biggest cargo door")
	var big := cat.part("undercarriage_leg:5H")
	check(big.load_kg > leg.load_kg * 3.0 and big.clearance > leg.clearance, "a bigger, Hardened leg bears more and stands taller")
	check(cat.part("tail_ramp:4P").move_s < cat.part("tail_ramp").move_s, "a Precision ramp opens faster")
	check(cat.part("crane_boom:6S").move_kw > cat.part("crane_boom").move_kw, "a bigger boom draws more while it slews")
	for k: String in DesignCatalog.DOOR_KINDS:
		check(DesignCatalog.DOOR_KINDS[k].has("move_s") and DesignCatalog.DOOR_KINDS[k].has("move_kw"), "door kind %s has move figures" % k)


## Door kinds: a plain door, an open doorway and a wide cargo door, priced on the parts list
## and checked against the wall they stand in.
func _doors() -> void:
	var d := DesignRecord.new("dk", "Doors")
	for op in [
		{"op": "add_room", "room": {"id": "a", "type": "corridor", "x": 0, "z": 0, "w": 2, "d": 8}},
		{"op": "add_room", "room": {"id": "b", "type": "cargo", "x": 2, "z": 0, "w": 6, "d": 8}},
		{"op": "add_room", "room": {"id": "c", "type": "mess", "x": -4, "z": 0, "w": 4, "d": 4}},
		{"op": "add_door", "door": {"id": "d1", "a": "a", "b": "b", "x": 2, "z": 4, "kind": "cargo"}},
		{"op": "add_door", "door": {"id": "d2", "a": "a", "b": "c", "x": 0, "z": 2, "kind": "doorway"}},
		{"op": "add_door", "door": {"id": "d3", "a": "c", "b": "", "x": -4, "z": 2}},
	]:
		check(not d.apply(op).is_empty(), "door op applies: %s" % [op])
	check(DesignCatalog.door_w(d.doors.d1) > 2.0 and DesignCatalog.door_w(d.doors.d3) < 1.5, "a cargo door is wider")
	check(not DesignCatalog.door_kind(d.doors.d2).leaves, "a doorway has no door in it")
	var t := DesignTotals.compute(d, cat)
	var kinds := {}
	for l in t.lines:
		if l.kind == "door":
			kinds[l.id] = l
	check(kinds.has("cargo") and kinds.has("doorway") and kinds.has("door"), "each door kind is on the parts list")
	check(float(kinds.cargo.cost) > float(kinds.door.cost) and float(kinds.doorway.cost) < float(kinds.door.cost),
			"cargo doors cost most, doorways least")
	var bad := DesignRules.check(d, cat).filter(func(p): return "door" in str(p.text).to_lower() and p.severity == DesignRules.ERROR)
	check(bad.is_empty(), "all three doors fit their walls: %s" % [bad.map(func(p): return p.text)])
	var squeeze := DesignRecord.new("sq", "Squeeze")
	squeeze.apply({"op": "add_room", "room": {"id": "a", "type": "corridor", "x": 0, "z": 0, "w": 2, "d": 2}})
	squeeze.apply({"op": "add_room", "room": {"id": "b", "type": "cargo", "x": 2, "z": 0, "w": 4, "d": 4}})
	squeeze.apply({"op": "add_door", "door": {"id": "d1", "a": "a", "b": "b", "x": 2, "z": 1, "kind": "cargo"}})
	var errs := DesignRules.check(squeeze, cat).filter(func(p): return p.severity == DesignRules.ERROR and "door" in str(p.text).to_lower())
	check(not errs.is_empty(), "a cargo door does not fit a 2 m wall")


## A design answering a client's ship order: the order is kept with the design, and every
## demand an order can make is one the numbers can score.
func _orders() -> void:
	var o: Dictionary = ShipOrders.for_cycle(1)[0]
	var d := _ship("S")
	d.apply({"op": "set_meta", "fields": {"order": o}})
	check(str(d.order.id) == str(o.id), "the design takes the order")
	var back := DesignRecord.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	check(str(back.order.get("id", "")) == str(o.id) and (back.order.demands as Dictionary).size() == o.demands.size(),
			"and keeps it through a save")
	var t := DesignTotals.compute(d, cat)
	for c in range(30):
		for order in ShipOrders.for_cycle(c):
			var rows := t.fit(order.demands)
			if rows.size() != (order.demands as Dictionary).size():
				check(false, "every demand of %s is scored: %s" % [order.id, order.demands.keys()])
				return
	check(true, "every demand any order makes is scored by the design's numbers")


func _palette() -> void:
	var bus := Modules.bus("design") as DesignBus
	bus.library.reset_data()
	var holo := HoloTable.new()
	add_child(holo)
	holo.setup(bus)
	var layer := CanvasLayer.new()
	add_child(layer)
	var console := DesignConsole.new()
	layer.add_child(console)
	console.setup(bus, holo)
	await frames(3)
	console.set_pick(5, "H")
	var b := console.find_child("Part_reactor_small", true, false) as Button
	if b == null:
		console._open_groups["power"] = true
		console._fill_palette()
		b = console.find_child("Part_reactor_small", true, false) as Button
	check(b != null and "5H" in b.text, "the palette shows the picked size and grade: %s" % (b.text if b else "none"))
	if b:
		b.pressed.emit()
		check(console.plan.tool == "part:reactor_small:5H", "picking it arms that variant: %s" % console.plan.tool)
	var cargo_b := console.find_child("DoorKind_cargo", true, false) as Button
	check(cargo_b != null, "the door kinds are on the palette")
	if cargo_b:
		cargo_b.pressed.emit()
		check(console.plan.tool == "door" and console.plan.door_kind == "cargo", "CARGO DOOR arms the door tool")
	# Changing a placed part's size and grade, and a door's kind, in place.
	var rec := bus.library.current
	for op in [
		{"op": "add_room", "room": {"id": "e1", "type": "engineering", "x": 20, "z": 20, "w": 8, "d": 8}},
		{"op": "add_room", "room": {"id": "e2", "type": "corridor", "x": 18, "z": 20, "w": 2, "d": 8}},
		{"op": "add_component", "component": {"id": "k1", "type": "reactor_small", "room": "e1", "x": 23, "z": 23, "rot": 0}},
		{"op": "add_door", "door": {"id": "k2", "a": "e2", "b": "e1", "x": 20, "z": 24}},
	]:
		bus.editor.do(op)
	console.plan.select("part", "k1")
	await frames(2)
	var up := console.find_child("SizeUp", true, false) as Button
	check(up != null and not up.disabled, "a selected part shows its size stepper")
	if up:
		up.pressed.emit()
		await frames(2)
		check(str(rec.components.k1.type) == "reactor_small:4S", "SIZE + makes it one class bigger: %s" % rec.components.k1.type)
	var gp := console.find_child("Grade_P", true, false) as Button
	if gp:
		gp.pressed.emit()
		await frames(2)
	check(str(rec.components.k1.type) == "reactor_small:4P", "a grade button changes its grade: %s" % rec.components.k1.type)
	bus.editor.undo()
	check(str(rec.components.k1.type) == "reactor_small:4S", "and undo puts it back")
	console.plan.select("door", "k2")
	await frames(2)
	var dw := console.find_child("SetDoor_doorway", true, false) as Button
	check(dw != null, "a selected door shows its kinds")
	if dw:
		dw.pressed.emit()
		await frames(2)
		check(str(rec.doors.k2.get("kind", "")) == "doorway", "a door becomes an open doorway in place")
		bus.editor.undo()
		check(DesignCatalog.door_kind(rec.doors.k2).leaves, "and undo makes it a door again")
	var orders_b := console.find_child("Orders", true, false) as Button
	check(orders_b != null and not orders_b.disabled, "the palette offers the ship orders")
	if orders_b:
		orders_b.pressed.emit()
		await frames(2)
		var first := console.find_child("Order_*", true, false) as Button
		check(first != null, "the order list opens")
		if first:
			first.pressed.emit()
			await frames(2)
			check(not rec.order.is_empty(), "picking one makes the design answer it")
			check(console.data.find_child("*", true, false) != null, "the data channel redraws")
			bus.editor.undo()
			check(rec.order.is_empty(), "and undo takes it off again")
	layer.queue_free()
	holo.queue_free()
