extends ModuleTest
## BSX-only stock beams: box tube, I-beam, channel and angle in steel, alloy and titanium,
## 6 m and 12 m long; their ids, sections and outlines, masses from the materials table,
## values and shapes.
##   tools/run_tests.sh shared_components


func run_tests() -> void:
	StockBeams.reread()
	var t := StockBeams.table()
	check(int(t.get("version", 0)) >= 1 and t.get("format", "") == "bsx-stock-beams", "the beams file has a version")
	check(StockBeams.materials() == PackedStringArray(["alloy", "steel", "titanium"]), "three materials: %s" % [StockBeams.materials()])
	check(StockBeams.lengths() == PackedInt32Array([6000, 12000]), "6 m and 12 m bars")
	var sections := 0
	for f: String in StockBeams.FAMILIES:
		sections += (StockBeams.family(f).get("sections", []) as Array).size()
	check(StockBeams.items().size() == 3 * sections * 2, "every material x section x length: %d" % StockBeams.items().size())
	for f: String in StockBeams.FAMILIES:
		check(not StockBeams.item_ids(f).is_empty(), "%s bars are stocked" % f)
	# Ids and lookup.
	var id := StockBeams.item_id("steel", "box", 100, 100, 5, 6000)
	check(id == "SteelBox_100x100x5_6000", "ids read material and kind, w x h x t, length: %s" % id)
	check(StockBeams.item_id("steel", "box", 100, 100, 7, 6000) == "" and StockBeams.item_id("copper", "box", 100, 100, 5, 6000) == ""
			and StockBeams.item_id("steel", "box", 100, 100, 5, 9000) == "", "unstocked sections, materials and lengths have no id")
	check(StockBeams.is_beam(id) and not StockBeams.is_beam("SteelPlate_1000x1000_2"), "a beam is a beam, a plate isn't")
	var it := StockBeams.item(id)
	var area := 0.1 * 0.1 - 0.09 * 0.09
	check(is_equal_approx(float(it["area"]), area), "a box tube's area is the outline less its bore: %f" % it["area"])
	check(is_equal_approx(float(it["mass"]), snappedf(area * 6.0 * 7800.0, 0.1)), "mass from steel's density: %s kg" % it["mass"])
	check(it["category"] == "stock_beams" and it["material"] == "steel" and it["family"] == "box", "a steel box tube is beam stock")
	check(is_equal_approx(float(it["section"]["t"]), 0.005) and is_equal_approx(float(it["length"]), 6.0), "section and length in metres")
	check(str(it["name"]) == "Steel box tube 100 x 100 x 5, 6 m", "its name: %s" % it["name"])
	check(StockBeams.item_ids("", "alloy")[0] == "AlloyBox_50x50x3_6000", "sorted by family, then smallest and shortest first")
	var ibeam := StockBeams.item("SteelIBeam_150x200x8_12000")
	check(is_equal_approx(float(ibeam["area"]), 2.0 * 0.15 * 0.008 + 0.008 * (0.2 - 0.016)), "an I-beam's area is two flanges and the web: %f" % ibeam["area"])
	var chan := StockBeams.item("SteelChannel_75x150x6_6000")
	check(is_equal_approx(float(chan["area"]), 2.0 * 0.075 * 0.006 + 0.006 * (0.15 - 0.012)), "a channel's area: %f" % chan["area"])
	var ang := StockBeams.item("SteelAngle_75x75x6_6000")
	check(is_equal_approx(float(ang["area"]), 0.075 * 0.006 + 0.006 * (0.075 - 0.006)), "an angle's area: %f" % ang["area"])
	# Every bar is complete and in the shape of a market catalogue entry; its outline and shape agree.
	for bid: String in StockBeams.items():
		var b: Dictionary = StockBeams.item(bid)
		check(b.has("name") and b.has("category") and b.has("value") and b.has("mass") and b.has("blurb"),
				"%s: has a catalogue entry's fields" % bid)
		check(float(b["mass"]) > 0.0 and int(b["value"]) > 0 and Materials.TABLE.has(b["material"]) and not bid.contains(" "),
				"%s: weighs and costs something, in a shared material" % bid)
		var edge := StockBeams.outline(bid)
		var r := Rect2(edge[0], Vector2.ZERO)
		for p in edge:
			r = r.expand(p)
		check(r.size.is_equal_approx(Vector2(b["section"]["w"], b["section"]["h"])) and r.get_center().is_zero_approx(),
				"%s: its outline fills its section, centred" % bid)
		var shape := StockBeams.make_shape(bid)
		check(shape != null and is_equal_approx(shape.volume, float(b["area"]) * float(b["length"]))
				and shape.mesh.get_aabb().size.is_equal_approx(b["size"]), "%s: its shape is the section along its length" % bid)
	check(StockBeams.holes("SteelBox_50x50x3_6000").size() == 1 and StockBeams.holes("SteelAngle_50x50x5_6000").is_empty(),
			"a box tube has a bore, an angle none")
	check(StockBeams.outline("NoSuchBeam").is_empty() and StockBeams.make_shape("NoSuchBeam") == null, "unknown ids have no outline or shape")
	# Faces point out of the metal: every triangle's drawn side faces its normal.
	var faces := StockBeams.make_shape("SteelIBeam_100x100x6_6000").mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = faces[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = faces[Mesh.ARRAY_NORMAL]
	var wound := true
	for k in range(0, verts.size(), 3):
		wound = wound and -(verts[k + 1] - verts[k]).cross(verts[k + 2] - verts[k]).dot(normals[k]) > 0.0
	check(wound, "faces wound to face out")
	# Longer, bigger and dearer.
	var short := StockBeams.item("AlloyAngle_50x50x5_6000")
	var long := StockBeams.item("AlloyAngle_50x50x5_12000")
	check(is_equal_approx(float(long["mass"]), float(short["mass"]) * 2.0), "a 12 m bar weighs twice a 6 m one")
	check(int(StockBeams.item("TitaniumBox_100x100x5_6000")["value"]) > int(StockBeams.item("SteelBox_100x100x5_6000")["value"]),
			"titanium costs more than steel")
