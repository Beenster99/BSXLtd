extends ModuleTest
## BSX-only stock plates: metal and glass in sizes and thicknesses, their ids, masses from
## the materials table, values, shapes, and what they and wreck sheet parts crush into.
##   tools/run_tests.sh shared_components


func run_tests() -> void:
	StockPlates.reread()
	var t := StockPlates.table()
	check(int(t.get("version", 0)) >= 1 and t.get("format", "") == "bsx-stock-plates", "the plates file has a version")
	check(StockPlates.kinds().size() == 5, "five kinds: %s" % [StockPlates.kinds()])
	var metal := StockPlates.item_ids("metal")
	var glass := StockPlates.item_ids("glass")
	check(metal.size() == 3 * 4 * 5, "metal: 3 kinds x 4 sizes x 5 thicknesses (%d)" % metal.size())
	check(glass.size() == 2 * 4 * 4, "glass: 2 kinds x 4 sizes x 4 thicknesses (%d)" % glass.size())
	check(StockPlates.items().size() == metal.size() + glass.size(), "every plate is metal or glass")
	# Ids and lookup.
	var id := StockPlates.item_id("SteelPlate", 2500, 1250, 5)
	check(id == "SteelPlate_2500x1250_5", "ids read kind, length x width, thickness: %s" % id)
	check(StockPlates.item_id("SteelPlate", 2500, 1250, 7) == "" and StockPlates.item_id("PaperPlate", 1000, 1000, 2) == "",
			"unstocked sizes and kinds have no id")
	check(StockPlates.is_plate(id) and not StockPlates.is_plate("HullPlate"), "a plate is a plate, a hull plate isn't stock")
	var it := StockPlates.item(id)
	check(is_equal_approx(float(it["mass"]), snappedf(2.5 * 1.25 * 0.005 * 7800.0, 0.1)), "mass from steel's density: %s kg" % it["mass"])
	check(it["category"] == "stock_metal" and it["material"] == "steel", "a steel plate is metal stock in steel")
	check(str(it["name"]) == "Steel plate 2500 x 1250, 5 mm", "its name: %s" % it["name"])
	check(StockPlates.item_ids("", "SteelPlate")[0] == "SteelPlate_1000x1000_2", "sorted smallest and thinnest first")
	# Every plate is complete and in the shape of a market catalogue entry.
	for pid: String in StockPlates.items():
		var p: Dictionary = StockPlates.item(pid)
		check(p.has("name") and p.has("category") and p.has("value") and p.has("mass") and p.has("blurb"),
				"%s: has a catalogue entry's fields" % pid)
		check(float(p["mass"]) > 0.0 and int(p["value"]) > 0, "%s: weighs something and costs something" % pid)
		check(Materials.TABLE.has(p["material"]), "%s: its material is a shared one" % pid)
		check(not pid.contains(" "), "%s: id has no spaces" % pid)
	# Thicker and bigger weigh more; dearer materials cost more a kilogram.
	var thin := StockPlates.item("AlloyPlate_2000x1000_2")
	var thick := StockPlates.item("AlloyPlate_2000x1000_12")
	check(float(thick["mass"]) > float(thin["mass"]) and int(thick["value"]) > int(thin["value"]), "a thicker plate weighs and costs more")
	var steel := StockPlates.item("SteelPlate_1000x1000_5")
	var ti := StockPlates.item("TitaniumPlate_1000x1000_5")
	check(float(ti["value"]) / float(ti["mass"]) > float(steel["value"]) / float(steel["mass"]), "titanium costs more a kilogram than steel")
	check(StockPlates.item("GlassPlate_1000x1000_10")["category"] == "stock_glass", "glass is glass stock")
	# Shapes.
	var shape := StockPlates.make_shape(id)
	check(shape != null and shape.mesh != null and shape.collision != null, "a plate has a shape")
	if shape:
		var box := shape.mesh.get_aabb()
		check(box.size.is_equal_approx(Vector3(2.5, 0.005, 1.25)), "the shape is the plate's size: %s" % box.size)
	check(StockPlates.make_shape("nothing") == null, "no shape for an unknown id")
	check(StockPlates.paint(id) != null and StockPlates.paint("GlassPlate_1000x1000_6") != null, "plates have paint")
	# Crushing.
	var c := StockPlates.crush_materials(id, 2)
	check(c.keys() == ["steel"] and is_equal_approx(float(c["steel"]), snappedf(float(it["mass"]) * 2 * StockPlates.RECOVERY, 0.1)),
			"two steel plates crush into steel at the recovery share: %s" % [c])
	check(StockPlates.crush_materials("CrystalPlate_1000x1000_6", 1).keys() == ["crystal"], "crystal glass crushes into crystal")
	check(StockPlates.is_sheet("HullPlate") and StockPlates.is_sheet("WindowPane") and not StockPlates.is_sheet("IonThruster"),
			"wreck sheet parts are known")
	var hull := StockPlates.crush_materials("HullPlate", 3, 10.0, "alloy")
	check(hull == {"alloy": 22.5}, "hull plates crush into their own material: %s" % [hull])
	check(StockPlates.crush_materials("WindowPane", 1, 40.0, "steel") == {"glass": 30.0}, "a pane built as steel is still glass")
	check(StockPlates.crush_materials("DeckPlate", 1, 20.0, "") == {"steel": 15.0}, "an unknown material is steel")
	check(StockPlates.crush_materials("TitaniumPlate_1000x1000_5:cut:T1", 2, 10.0) == {"titanium": 15.0}, "a cut piece crushes as its plate's material")
	check(StockPlates.crush_materials("TitaniumPlate_1000x1000_5:cut:T1", 1) == {}, "a cut piece needs its mass")
	check(StockPlates.crush_materials("NotAPlate:cut:T1", 1, 10.0) == {}, "a cut of something else is not a plate")
	check(StockPlates.crush_materials("IonThruster", 1, 100.0, "steel").is_empty(), "anything else is left to the crusher's mix")
	check(StockPlates.crush_materials("HullPlate", 1).is_empty(), "a sheet part needs its mass")
