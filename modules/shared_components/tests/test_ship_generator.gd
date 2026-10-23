extends ModuleTest
## ShipGenerator: a ship rolled from a seed in every class and family is a vsship 2.0 file
## that checks out, the same seed gives the same ship, another seed another, its hull has a
## frame, a deck, linings, three stud walls and the crew's fittings spot-welded to the deck,
## the importer builds it clean, the wreck maker damages it, and a design id round-trips
## through the contracts' entry points.
##   tools/run_tests.sh shared_components


func run_tests() -> void:
	_check_ids()
	_check_one("S", "courier", 3)
	_check_one("M", "freighter", 84)
	_check_one("L", "miner", 11)
	_check_every_family()
	_check_determinism()
	_check_wreck()


func _check_ids() -> void:
	var id := ShipGenerator.design_id(84, "M", "freighter")
	check(id == "gen:freighter:M:84" and ShipGenerator.is_generated(id), "a design id names family, class and seed")
	check(ShipGenerator.parse_id(id) == {"seed": 84, "size": "M", "family": "freighter"}, "and parses back")
	check(not ShipGenerator.is_generated("kestrel") and not ShipGenerator.is_generated("gen:no_such:M:1"), "other ids are not ours")
	check(ShipGenerator.family_for("Mining") == "miner" and ShipGenerator.family_for("Express Courier Co") == "courier"
			and ShipGenerator.family_for("something else") == "freighter", "a client's trade picks the family")
	check(ShipGenerator.CLASSES.has(ShipGenerator.roll_class(5)) and ShipGenerator.FAMILIES.has(ShipGenerator.roll_family(5)),
			"a bare seed rolls a class and a family")
	check(ShipGenerator.ship_name(5, "liner") != "" and ShipGenerator.ship_name(5, "liner") == ShipGenerator.ship_name(5, "liner"),
			"a name from the seed")


func _check_one(size: String, family: String, seed_value: int) -> void:
	var tag := "%s %s %d" % [family, size, seed_value]
	var f := ShipGenerator.make(seed_value, size, family)
	check(not f.is_empty() and f.get("format", "") == "vsship", "%s: a ship file" % tag)
	var problems := VsShipImport.check(f)
	check(problems.is_empty(), "%s: the file checks out: %s" % [tag, "; ".join(problems.slice(0, 4))])
	check(f["ship"]["class"] == size and f["ship"]["id"] == ShipGenerator.design_id(seed_value, size, family), "%s: named for its class and id" % tag)
	check(int(f["derived"]["recipe_less"]) == 0, "%s: every part has a recipe" % tag)
	var by := {}
	var kinds := {}
	for p: Dictionary in f["parts"]:
		by[p["by"]] = int(by.get(p["by"], 0)) + 1
		kinds[p["kind"]] = int(kinds.get(p["kind"], 0)) + 1
	check(int(by.get("frame:hull", 0)) > 100 and int(by.get("deck:hull/main", 0)) > 10, "%s: a framed hull with a deck (%s)" % [tag, str(by)])
	check(int(by.get("wall:cockpit_wall", 0)) > 5 and int(by.get("wall:bulkhead", 0)) > 5 and int(by.get("wall:engine_wall", 0)) > 5,
			"%s: three stud walls" % tag)
	check(int(by.get("unit", 0)) >= 6, "%s: the fittings as parts (%d)" % [tag, int(by.get("unit", 0))])
	check(int(kinds.get("glass", 0)) > 0, "%s: some glass" % tag)
	var phases: Dictionary = f["derived"]["joints_by_phase"]
	for phase in ["frame", "skin", "deck", "lining", "wall", "fitting"]:
		check(int(phases.get(phase, 0)) > 0, "%s: joints in phase %s" % [tag, phase])
	check(f["frame"].size() == 1 and f["decks"].size() == 1 and f["walls"].size() == 3, "%s: the recipe blocks" % tag)
	check(f["layout"]["rooms"].size() == 4 and f["layout"]["seats"].size() >= 1, "%s: four rooms and a seat" % tag)
	var bounds: Dictionary = f["derived"]["bounds"]
	var size_m: Array = bounds["size"]
	var lo: float = {"S": 9.0, "M": 18.0, "L": 28.0}[size]
	var hi: float = {"S": 19.0, "M": 32.0, "L": 54.0}[size]
	check(float(size_m[2]) > lo and float(size_m[2]) < hi, "%s: %.1f m long, a class %s" % [tag, float(size_m[2]), size])
	# The importer builds it clean.
	var body := RigidBody3D.new()
	var im := VsShipImport.new()
	var ok := im.build(f, body)
	add_child(body)
	check(ok and im.errors.is_empty() and im.warnings.is_empty(), "%s: imports clean: %s" % [tag, "; ".join(im.warnings.slice(0, 3))])
	check(im.parts_by_path.size() == f["parts"].size() and im.joints_by_path.size() == f["joints"].size(), "%s: every part and joint built" % tag)
	check(im.fittings_built.size() == f["fittings"].size() and im.fittings_built.size() >= 6, "%s: the fittings dressed (%d)" % [tag, im.fittings_built.size()])
	# A fitting is spot-welded to a deck plate.
	var console: PartData = im.part_at("fitting:console")
	check(console != null, "%s: the console is a part" % tag)
	if console:
		var held := false
		for c: ConnectionData in im.joints_of("fitting:console"):
			var other: int = c.part_b if c.part_a == console.id else c.part_a
			var plate: PartData = im.kit.model.parts.get(other)
			if c.kind == ConnectionData.Kind.SPOT and plate and plate.path.contains("/deck/"):
				held = true
		check(held, "%s: the console is spot-welded to a deck plate" % tag)


func _check_every_family() -> void:
	for family: String in ShipGenerator.FAMILIES:
		for size: String in ShipGenerator.CLASSES:
			var f := ShipGenerator.make(17, size, family)
			var problems := VsShipImport.check(f)
			check(problems.is_empty(), "%s %s: checks out: %s" % [family, size, "; ".join(problems.slice(0, 3))])


func _check_determinism() -> void:
	var a := ShipGenerator.make(42, "M", "tanker")
	var b := ShipGenerator.make(42, "M", "tanker")
	check(a["derived"]["parts_hash"] == b["derived"]["parts_hash"] and a["derived"]["body_hash"] == b["derived"]["body_hash"],
			"the same seed builds the same ship")
	var c := ShipGenerator.make(43, "M", "tanker")
	check(a["derived"]["parts_hash"] != c["derived"]["parts_hash"], "another seed another ship")
	check(a["ship"]["name"] != "" and a["stats"]["mass_kg"] > 1000.0, "it has a name and a mass")


## The contracts' entry point takes a generated design id straight.
func _check_wreck() -> void:
	var id := ShipGenerator.design_id(84, "M", "freighter")
	var w := WreckMaker.for_design(id, 7, "fire:3,stripped:2")
	check(not w.is_empty() and VsShipImport.check(w).is_empty(), "a wreck of a generated ship by its design id")
	var s := WreckMaker.summary(w)
	check(s["gone"] > 20 and s["broken"] > 20 and s["scorched"] > 20, "fire and stripping took their toll (%s)" % str(s))
	var m := WreckMaker.manifest(w)
	check(m["design"] == id and m["wreck"] == true and m["mass_kg"] < m["ship_mass_kg"], "its manifest names the design")
	var body := RigidBody3D.new()
	var im := VsShipImport.new()
	check(im.build(w, body) and im.warnings.is_empty(), "the wreck builds")
	add_child(body)
	check(VsShipImport.design_source("kestrel").size() > 0 and VsShipImport.design_source("no_such").is_empty(),
			"design_source reads pinned files and refuses unknown designs")
