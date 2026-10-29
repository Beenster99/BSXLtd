extends ModuleTest
## Ship and Bay: every stores item is drawn as itself (ItemLook), and goods stack neatly
## on a deck.
##   tools/run_tests.sh ship_bay

const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")
const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")


func run_tests() -> void:
	var odd: Array = []
	var stand_ins := 0
	for id: String in Layout.items():
		var size := ItemLook.size_of(id)
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0 or maxf(size.x, maxf(size.y, size.z)) > (12.5 if StockPlates.is_plate(id) or StockBeams.is_beam(id) else 6.0):
			odd.append("%s %s" % [id, size])
		if ItemLook._build(id).is_empty():
			stand_ins += 1
	check(odd.is_empty(), "every item has a size between nothing and 6 m (a stock plate or bar 12.5 m): %s" % [odd])
	check(stand_ins < Layout.items().size() / 2, "most items are built as themselves (%d stand-ins of %d)" % [stand_ins, Layout.items().size()])
	var boxed: Array = []
	for id: String in Layout.items():
		var cat := str(Layout.items()[id].get("category", ""))
		if (["fasteners", "modules", "fittings"].has(cat)) and ItemLook._build(id).is_empty():
			boxed.append(id)
	check(boxed.is_empty(), "bolts, rivets, lamps and ship modules look like themselves, not a box: %s" % [boxed])
	var long_bins: Array = []
	for id: String in Layout.items():
		if Layout.kind_of(id) == "bin" and not Layout.fits(Layout.size_of(id), Layout.bin_room()):
			long_bins.append(id)
	check(long_bins.is_empty(), "every part in a bin fits it as itself: %s" % [long_bins])
	var n := ItemLook.make("BatteryRack")
	check(n.get_child_count() >= 1 and (n.get_child(0) as MeshInstance3D).mesh != null, "a battery rack is drawn as a mesh")
	var box := (n.get_child(0) as MeshInstance3D).get_aabb()
	box = n.get_child(0).transform * box
	check(absf(box.position.y) < 0.01 and absf(box.get_center().x) < 0.01, "standing on its bottom centre: %s" % box)
	n.free()
	# Six battery racks (1.2 x 1.4 x 0.5) on a 2.6 x 4.4 deck: side by side, none over the edge.
	var size := ItemLook.size_of("BatteryRack")
	var spots := ItemLook.stack(size, 6, Vector2(2.6, 4.4), 2.4)
	check(spots.size() == 6, "six fit")
	var over := false
	for xf: Transform3D in spots:
		var half := (xf.basis * size).abs() * 0.5
		if absf(xf.origin.x) + half.x > 1.3 + 0.001 or absf(xf.origin.z) + half.z > 2.2 + 0.001:
			over = true
	check(not over, "none hangs over the deck's edge")
	check(spots.all(func(xf: Transform3D) -> bool: return xf.origin.y == 0.0), "all on the deck before any goes on top")
	var tall := ItemLook.stack(size, 40, Vector2(2.6, 4.4), 3.0)
	check(tall.size() < 40 and tall.any(func(xf: Transform3D) -> bool: return xf.origin.y > 0.0), "more than a layer stacks up, to the height limit (%d)" % tall.size())
	check(ItemLook.look_for(0.3) == ItemLook.Look.RUST and ItemLook.look_for(1.0) == ItemLook.Look.NEW and ItemLook.look_for(0.4, "bath") == ItemLook.Look.BARE,
			"goods look rusty, new or bare by condition and stage")
	# The raw build material: plates flat, beams long, panes glazed, cable on a drum.
	var plate := ItemLook.size_of("HullPlate")
	check(plate.y < 0.07 and maxf(plate.x, plate.z) > 0.4, "a hull plate is a flat sheet: %s" % plate)
	var deck := ItemLook.size_of("DeckPlate")
	check(deck.y < 0.07 and deck.x * deck.z > plate.x * plate.z, "a deck plate is a bigger sheet: %s" % deck)
	var beam := ItemLook.size_of("Stringer")
	check(maxf(beam.x, beam.z) >= 3.0 and beam.y < 0.6, "a stringer comes as a length of beam: %s" % beam)
	var pane := ItemLook.pieces("WindowPane")
	check(pane.size() >= 2 and ItemLook.size_of("WindowPane").y < 0.2, "a window pane lies flat with its glass in")
	var drum := ItemLook.size_of("MainLoom")
	check(drum.y > 0.6 and absf(drum.y - drum.z) < 0.05, "loom cable comes on a drum: %s" % drum)
