extends RefCounted
## What is in the yard's stores: crates delivered to the Deliveries hall and not yet put
## away, and the goods on each storage location. Pure data; the bus changes it in the host's
## order on every machine, and it saves with the bay. A new game starts with it empty.

const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")

## Location id -> {item, qty, condition (0..1, the average of what is there)}.
var stock: Dictionary = {}
## Crate id ("<order id>/<n>") -> {order_id, item, name, qty, condition, grade, mass (kg
## a unit), spot (goods-in spot index; spots fill up and then crates stack)}.
var crates: Dictionary = {}


## Sets down a crate per delivered line on the next free goods-in spots. Lines are
## {item_id, qty, condition, name, grade, mass}. Returns the new crate ids.
func land(order_id: String, lines: Array) -> PackedStringArray:
	var ids := PackedStringArray()
	var n := 0
	for line: Variant in lines:
		if not (line is Dictionary):
			continue
		var d := line as Dictionary
		var item := str(d.get("item_id", d.get("part", "")))
		var qty := int(d.get("qty", 1))
		if item == "" or qty <= 0:
			continue
		n += 1
		var id := "%s/%d" % [order_id, n]
		while crates.has(id):
			n += 1
			id = "%s/%d" % [order_id, n]
		var known: Dictionary = Layout.items().get(item, {})
		var mass := float(d.get("mass", 0.0))
		if mass <= 0.0:
			mass = float(known.get("mass", 0.0))
		crates[id] = {"order_id": order_id, "item": item, "qty": qty,
				"name": str(d.get("name", known.get("name", item))),
				"condition": clampf(float(d.get("condition", 1.0)), 0.0, 1.0),
				"grade": str(d.get("grade", "new")), "mass": mass, "spot": _free_spot()}
		ids.append(id)
	return ids


## Where a crate's goods go: the item's home if it is free or already holds the same item,
## else a free spare location of its kind, else any free spare one; "" when the hall is full.
func place_for(item: String, mass := -1.0) -> String:
	var layout := Layout.get_layout()
	var home: String = layout["homes"].get(item, "")
	if home != "" and (not stock.has(home) or stock[home]["item"] == item):
		return home
	for loc: String in stock:
		if stock[loc]["item"] == item:
			return loc
	if mass < 0.0:
		mass = float(Layout.items().get(item, {}).get("mass", 0.0))
	var kind := Layout.kind_for(mass)
	var fallback := ""
	for loc: String in layout["locations"]:
		var l: Dictionary = layout["locations"][loc]
		if l["home"] != "" or stock.has(loc):
			continue
		if l["kind"] == kind:
			return loc
		if fallback == "" and (kind == "bin" or l["kind"] != "bin"):
			fallback = loc
	return fallback


## Puts a delivered crate's goods away (on `loc`, or where place_for says). Returns the
## location, or "" when there is no crate or nowhere to put it.
func store(crate_id: String, loc := "") -> String:
	var c: Dictionary = crates.get(crate_id, {})
	if c.is_empty():
		return ""
	if loc == "":
		loc = place_for(c["item"], float(c["mass"]))
	if loc == "" or (stock.has(loc) and stock[loc]["item"] != c["item"]):
		return ""
	var have: Dictionary = stock.get(loc, {"item": c["item"], "qty": 0, "condition": 0.0})
	var total := int(have["qty"]) + int(c["qty"])
	have["condition"] = (float(have["condition"]) * int(have["qty"]) + float(c["condition"]) * int(c["qty"])) / total
	have["qty"] = total
	stock[loc] = have
	crates.erase(crate_id)
	return loc


## Takes `qty` of an item out of stock, from the fewest locations. False (and nothing taken)
## when there isn't that much.
func take(item: String, qty := 1) -> bool:
	if count(item) < qty:
		return false
	for loc in where(item):
		var have: Dictionary = stock[loc]
		var n := mini(qty, int(have["qty"]))
		have["qty"] = int(have["qty"]) - n
		qty -= n
		if int(have["qty"]) <= 0:
			stock.erase(loc)
		if qty <= 0:
			break
	return true


## Locations holding an item, its home first.
func where(item: String) -> PackedStringArray:
	var out := PackedStringArray()
	var home: String = Layout.get_layout()["homes"].get(item, "")
	if stock.has(home) and stock[home]["item"] == item:
		out.append(home)
	for loc: String in stock:
		if loc != home and stock[loc]["item"] == item:
			out.append(loc)
	return out


func count(item: String) -> int:
	var n := 0
	for loc in where(item):
		n += int(stock[loc]["qty"])
	return n


func clear() -> void:
	stock = {}
	crates = {}


func to_dict() -> Dictionary:
	return {"stock": stock.duplicate(true), "crates": crates.duplicate(true)}


## Restores a saved store. Goods on a location the layout no longer has, or sitting on
## another item's home, go back to their own place.
func from_dict(d: Dictionary) -> void:
	clear()
	crates = (d.get("crates", {}) as Dictionary).duplicate(true)
	var locations: Dictionary = Layout.get_layout()["locations"]
	var lost: Array = []
	var saved: Dictionary = d.get("stock", {})
	for loc: String in saved:
		var have: Dictionary = (saved[loc] as Dictionary).duplicate()
		if locations.has(loc) and (locations[loc]["home"] == "" or locations[loc]["home"] == have.get("item")):
			stock[loc] = have
		else:
			lost.append(have)
	for have: Dictionary in lost:
		var loc := place_for(str(have.get("item", "")))
		if loc != "":
			if stock.has(loc):
				stock[loc]["qty"] = int(stock[loc]["qty"]) + int(have.get("qty", 0))
			else:
				stock[loc] = have


func _free_spot() -> int:
	var taken := {}
	for id: String in crates:
		taken[int(crates[id]["spot"])] = true
	var i := 0
	while taken.has(i):
		i += 1
	return i
