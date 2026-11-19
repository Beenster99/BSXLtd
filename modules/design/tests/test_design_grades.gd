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
	_palette()


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
	layer.queue_free()
	holo.queue_free()
