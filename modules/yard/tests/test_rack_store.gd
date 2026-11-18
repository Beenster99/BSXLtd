extends ModuleTest
## The stores hall's racks as data: four kinds of rack (long stock, plates, components,
## heavy), every place inside the hall and in no other, demo stock the same on every
## machine, deliveries put away by kind and nearest goods in, bots taking parts out.
##   tools/run_tests.sh yard


func run_tests() -> void:
	var store := YardRackStore.new()
	for kind in 4:
		check(store.slot_count(kind) > 0, "%s racks have places (%d)" % [YardRackStore.KIND_NAMES[kind], store.slot_count(kind)])
		check(YardRackStore.parts_of_kind(kind).size() >= 3, "and at least three parts to hold")
	check(store.filled_count(YardRackStore.LONG) == 0, "a new store is empty")
	check(store.slots.size() >= 300, "hundreds of places (%d)" % store.slots.size())

	# Every part fits the racks of its kind.
	for part: String in YardRackStore.PARTS:
		var p: Dictionary = YardRackStore.PARTS[part]
		var fits := false
		for i in store.slots.size():
			if store.slot_kind(i) == int(p.kind):
				var room := store.slot_size(i)
				var sz: Vector3 = p.size
				fits = sz.y <= room.y and sz.z <= room.z + 0.01 and minf(sz.x, sz.z) <= room.x
				break
		check(fits, "%s fits a %s place" % [p.name, YardRackStore.KIND_NAMES[int(p.kind)]])

	store.fill_demo()
	var again := YardRackStore.new()
	again.fill_demo()
	var same := true
	for i in store.slots.size():
		same = same and store.slots[i].part == again.slots[i].part and store.slots[i].qty == again.slots[i].qty
	check(same, "demo stock is the same on every machine")
	for kind in 4:
		var share := float(store.filled_count(kind)) / float(store.slot_count(kind))
		check(share > 0.35 and share < 0.85, "about 60%% of the %s places filled (%.2f)" % [YardRackStore.KIND_NAMES[kind], share])
	var kinds_right := true
	for s in store.slots:
		if s.part != "":
			kinds_right = kinds_right and YardRackStore.kind_of(s.part) == int(YardRackStore.RACKS[int(s.rack)].kind)
	check(kinds_right, "every part is on a rack of its kind")

	# Every place inside the stores hall, clear of the open face and goods in, none sharing.
	var hall: AABB = YardLayout.ROOMS.racking.box
	var seen := {}
	var inside := true
	for i in store.slots.size():
		var p := store.slot_position(i)
		inside = inside and hall.has_point(p + Vector3(0, 0.01, 0)) and p.z > YardRackStore.YARD_SIDE_Z + 8.0 and p.x < 66.0
		seen[Vector3i((p * 100.0).round())] = true
	check(inside, "every place is inside the hall, behind the yard side and west of goods in")
	check(seen.size() == store.slots.size(), "no two places in one spot")
	for b: AABB in YardRackStore.GOODS_IN_BAYS + YardRackStore.DISPATCH_BAYS:
		check(hall.encloses(b), "bay %s is in the hall" % b)
	for p: Vector3 in YardRackStore.HAULER_BERTHS:
		check(not YardLayout.HULL_BOX.has_point(p), "a hauler berths outside the station")

	# Deliveries are put away; bots take parts out.
	var empty := YardRackStore.new()
	var slot := empty.store("hull_plate", 6)
	check(slot >= 0 and empty.slot_kind(slot) == YardRackStore.PLATE, "hull plates go on a plate rack")
	check(empty.store("hull_plate", 4) == slot and int(empty.slots[slot].qty) == 10, "more of them join the same stack")
	check(empty.store("hull_plate", 8) != slot, "a stack that would overflow starts another")
	check(empty.count("hull_plate") == 18, "18 hull plates in stock")
	check(empty.find("hull_plate") >= 0, "the stores find them")
	check(empty.take(slot, 3) == 3 and int(empty.slots[slot].qty) == 7, "a bot takes three")
	check(empty.take(slot, 99) == 7 and empty.slots[slot].part == "", "and the rest empties the place")
	check(empty.store("nonsense", 1) == -1, "an unknown part is refused")
	var full := YardRackStore.new()
	full.fill_demo(1.0)
	for i in full.slots.size():
		if full.slot_kind(i) == YardRackStore.HEAVY:
			full.slots[i].part = "reactor"
			full.slots[i].qty = 1
	check(full.store("engine_bell", 1) == -1, "full heavy cradles take nothing more")
