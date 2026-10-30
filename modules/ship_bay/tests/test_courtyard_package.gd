extends ModuleTest

const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
## Ship and Bay: a package ordered for the courtyard (beenster's Frame Builder playtest, 30
## Oct: "when ordered, the delivery should be picked up by Small, Medium or Large trolley and
## brought to the courtyard directly (not taken to stores)"). receive_delivery's destination
## "courtyard" lands the crates on the goods-in floor as usual, the goods-in lifts leave them,
## and the yard trolley whose deck fits the longest bar brings the package's crates to its bay
## in the courtyard and waits there with them; package_delivered follows.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	Flags.set_flag("ship_bay.trucks", false)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	for i in 3:
		await get_tree().physics_frame
	var fleet: Node3D = yard.get("trolleys")
	for t: Node in (fleet.get("trolleys") as Dictionary).values():
		t.set("speed_scale", 5.0)
		t.set("accel", 12.0)
		t.set("turn_rate", 8.0)
		t.set("lift_speed", 6.0)
	var bar := _beam_of(6000)
	check(bar != "" and Layout.size_of(bar).z > 5.9, "a 6 m bar to order: %s" % bar)
	var got: Array = []
	var on_delivered := func(order: String, ref: String, by: String, ids: PackedStringArray) -> void:
		got.append([order, ref, by, ids])
	bus.package_delivered.connect(on_delivered)
	bus.receive_delivery("PO-FRAME", [{"item_id": bar, "qty": 4, "condition": 1.0, "name": "Bar", "grade": "new", "mass": 0.0},
			{"item_id": bar, "qty": 2, "condition": 1.0, "name": "Bar", "grade": "new", "mass": 0.0}], "courtyard", "PKG-0007")
	await frames(2)
	var pkg := bus.courtyard_packages()
	check(pkg.size() == 2 and pkg.values().all(func(c: Dictionary) -> bool: return str(c.get("package", "")) == "PKG-0007" and not c.get("arrived", false)),
			"the package lands on the goods-in floor, marked for the courtyard: %d crates" % pkg.size())
	for i in 7200:
		await get_tree().physics_frame
		if not got.is_empty():
			break
	check(got.size() >= 1 and str(got[0][1]) == "PKG-0007" and str(got[0][0]) == "PO-FRAME",
			"package_delivered for PKG-0007 (%s)" % [got])
	var by := str(got[0][2]) if not got.is_empty() else ""
	check(by == "m", "the Medium trolley brought the 6 m bars (%s)" % by)
	var t: Node3D = (fleet.get("trolleys") as Dictionary).get(by)
	var drop: Vector3 = ShipBayBus.COURTYARD_DROPS.get(by, Vector3.INF)
	check(t != null and Vector2(t.global_position.x - drop.x, t.global_position.z - drop.z).length() < 1.0,
			"and stands in its courtyard bay with them: %s by %s" % [t.global_position if t else Vector3.ZERO, drop])
	pkg = bus.courtyard_packages()
	check(pkg.values().all(func(c: Dictionary) -> bool: return str(c.get("carrier", "")) == by and c.get("arrived", false))
			and bus.stock_count(bar) == 0, "both crates still on it, none put in the stores")
	# Taking them off (Tools' beam) sends the trolley home.
	for cid: String in pkg:
		bus.lift_off_trolley(cid)
	for i in 1200:
		await get_tree().physics_frame
		if str(fleet.call("destination_of", by)) == "" and str((fleet.get("jobs") as Dictionary).get(by, {}).get("do", "")) != "delivered":
			break
	check(str((fleet.get("jobs") as Dictionary).get(by, {}).get("do", "")) != "delivered", "emptied, it goes back to parking")
	bus.package_delivered.disconnect(on_delivered)
	yard.queue_free()
	await frames(2)


## A steel box-section bar `length_mm` long, "" for none.
func _beam_of(length_mm: int) -> String:
	for id in StockBeams.item_ids("box", "steel"):
		if int(StockBeams.item(id).get("length_mm", 0)) == length_mm:
			return id
	return ""
