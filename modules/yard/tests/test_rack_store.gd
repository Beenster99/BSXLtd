extends ModuleTest
## The racking hall's store as data: three aisles of slots (small, medium, large), demo stock
## the same on every machine, a crane taking the nearest load to its port and back, and every
## slot inside the hall without two loads in one place.
##   tools/run_tests.sh yard


func run_tests() -> void:
	var store := YardRackStore.new()
	check(store.slot_count(YardRackStore.SMALL) == 528, "528 small tote slots")
	check(store.slot_count(YardRackStore.MEDIUM) == 144, "144 medium crate slots")
	check(store.slot_count(YardRackStore.LARGE) == 36, "36 large cage slots")
	check(store.filled_count(YardRackStore.SMALL) == 0, "a new store is empty")

	store.fill_demo()
	var again := YardRackStore.new()
	again.fill_demo()
	var same := true
	for i in store.slots.size():
		same = same and store.slots[i].load == again.slots[i].load
	check(same, "demo stock is the same on every machine")
	for size in 3:
		var share := float(store.filled_count(size)) / float(store.slot_count(size))
		check(share > 0.4 and share < 0.8, "about 60%% of the %s slots filled (%.2f)" % [YardRackStore.SIZE_NAMES[size], share])

	# Every slot inside the racking hall, none sharing a place.
	var hall: AABB = YardLayout.ROOMS.racking.box
	var seen := {}
	var inside := true
	for i in store.slots.size():
		var p := store.slot_position(i)
		inside = inside and hall.has_point(p)
		seen[Vector3i((p * 100.0).round())] = true
	check(inside, "every slot is inside the racking hall")
	check(seen.size() == store.slots.size(), "no two slots in one place")
	for size in 3:
		check(hall.has_point(YardRackStore.PORTS[size]), "the %s port is in the hall" % YardRackStore.SIZE_NAMES[size])
		check((YardRackStore.PORTS[size] as Vector3).z > -10.0, "and in front of the fence")

	# Taking out and putting back.
	var size := YardRackStore.MEDIUM
	var before := store.filled_count(size)
	var slot := store.take_out(size)
	check(slot >= 0 and not store.ports[size].is_empty(), "a crate came to the medium port")
	check(store.slots[slot].load.is_empty() and store.filled_count(size) == before - 1, "its slot is empty now")
	check(int(store.slots[slot].bay) == 0, "the crane took the nearest one")
	check(store.take_out(size) == -1, "a busy port takes no second load")
	var label: String = store.ports[size].label
	var back := store.put_away(size)
	check(back >= 0 and store.ports[size].is_empty(), "the crate went back")
	check(store.slots[back].load.get("label", "") == label and store.filled_count(size) == before, "with what it held")
	check(store.put_away(size) == -1, "nothing to put away from an empty port")

	var full := YardRackStore.new()
	full.fill_demo(1.0)
	check(full.store(YardRackStore.LARGE, "Hull plate", 6) == -1, "a full aisle takes nothing more")
	var empty := YardRackStore.new()
	check(empty.take_out(YardRackStore.SMALL) == -1, "an empty aisle has nothing to bring")
	check(empty.store(YardRackStore.SMALL, "Rivets", 1000) >= 0 and empty.filled_count(YardRackStore.SMALL) == 1, "storing fills one slot")
