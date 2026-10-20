extends RefCounted
## The storage hall's layout: every location on its shelves and floor, and the home each
## part BSX can buy has there. Static data, the same on every machine, built once.
##
## The hall (Stock, x -50..0, z -46..-24) has three zones, all reached from the transfer
## aisle along its south wall (the doors from Deliveries and the courtyard open onto it):
## - Racks: four aisles A..D running north, a rack either side of each (A1 west of aisle A,
##   A2 east of it). Each rack has 4 bays (bay 1 at the transfer aisle), 5 levels and 2
##   pallet positions per level; location "B2-03-4-1" is rack B2, bay 3, level 4, position 1.
##   The parts are shelved by category, a category to a run of whole bays, the heaviest at
##   the bottom.
## - Bins: the first three bays of D2, by the courtyard door, hold three totes a level for
##   the small parts (under BIN_MAX kg): "D2-01-2-3".
## - Bulk: 18 painted floor bays west of the racks for the parts too big for a rack
##   (over PALLET_MAX kg): "Z-01".."Z-18".
## Locations without a home are spare: anything not in the catalogue goes to the first free one.

const CATALOGUE := "res://modules/ship_bay/internal/storage/storage_catalogue.json"
## Shelving order of the categories, and their names on the signs.
const CATEGORIES := {
	"engines": "Engines", "electronics": "Electronics", "machinery": "Machinery",
	"fluids": "Fluids", "weapons": "Weapons", "cargo": "Cargo", "hull": "Hull",
	"frame": "Frame", "wiring": "Wiring", "piping": "Piping", "glass": "Glass",
	"fittings": "Fittings", "modules": "Ship modules", "fasteners": "Fasteners",
}
## Kilograms: lighter parts go in bins, heavier ones than PALLET_MAX on the floor.
const BIN_MAX := 40.0
const PALLET_MAX := 6000.0

## Rack geometry, metres (yard space).
const RACK_DEPTH := 1.1
const AISLE_WIDTH := 2.9
const RACK_X0 := -29.4          # west face of rack A1
const RACK_Z0 := -29.2          # south end of every rack
const BAY_LENGTH := 3.4
const BAYS := 4
const LEVELS := 5
const LEVEL_PITCH := 1.8
const BEAM_Y := 0.15            # top of level 1's beams; level k's are LEVEL_PITCH higher each
const POSITIONS := 2
const BINS := 3
const BIN_BAYS := 3             # bays at the start of D2 that hold bins
const RACK_HEIGHT := 9.2        # the end frames
## Bulk floor bays: three columns (x centres) of six rows from BULK_Z0 north.
const BULK_X := [-47.3, -39.5, -34.9]
const BULK_SIZE := Vector2(4.4, 2.7)
const BULK_Z0 := -28.0
const BULK_ROW := 2.9
const BULK_ROWS := 6
## The transfer aisle's centre line (z) and the cross aisle behind the racks.
const TRANSFER_Z := -26.4
const BACK_Z := -44.3
## Goods-in floor spots in the Deliveries hall, where delivered crates are set down.
const GOODS_IN_ROWS := 6
const GOODS_IN_COLS := 3

static var _built: Dictionary = {}


## The layout: {items, locations (id -> location), homes (item -> location id), racks,
## aisles, bays, goods_in}. A location is {id, kind ("bin", "pallet" or "bulk"), rack, bay,
## level, pos, at (Vector3: the floor of the place, centred), size (the room there),
## face (towards where it is picked from), category, home (item id or "")}.
static func get_layout() -> Dictionary:
	if _built.is_empty():
		_built = _build()
	return _built


## The catalogue: item id -> {name, category, mass (kg)}.
static func items() -> Dictionary:
	return get_layout()["items"]


## "bin", "pallet" or "bulk" for a part of this mass (kg).
static func kind_for(mass: float) -> String:
	if mass < BIN_MAX:
		return "bin"
	return "pallet" if mass <= PALLET_MAX else "bulk"


## The rack ids west to east.
static func rack_ids() -> PackedStringArray:
	return PackedStringArray(["A1", "A2", "B1", "B2", "C1", "C2", "D1", "D2"])


## A rack's centre line (x) and the way its front faces (+1 east, -1 west).
static func rack_x(rack: String) -> float:
	var i := rack_ids().find(rack)
	var aisle := i / 2
	var west := RACK_X0 + aisle * (2.0 * RACK_DEPTH + AISLE_WIDTH + 0.2)
	return west + RACK_DEPTH * 0.5 if i % 2 == 0 else west + RACK_DEPTH * 1.5 + AISLE_WIDTH


static func rack_face(rack: String) -> float:
	return 1.0 if rack_ids().find(rack) % 2 == 0 else -1.0


## An aisle's centre line (x), "A".."D".
static func aisle_x(aisle: String) -> float:
	return rack_x(aisle + "1") + RACK_DEPTH * 0.5 + AISLE_WIDTH * 0.5


## Centre of a bay along its rack (z), 1..BAYS.
static func bay_z(bay: int) -> float:
	return RACK_Z0 - (bay - 0.5) * BAY_LENGTH


## Height of a level's goods (on its beams), 1..LEVELS.
static func level_y(level: int) -> float:
	return BEAM_Y + (level - 1) * LEVEL_PITCH + 0.06


static func _build() -> Dictionary:
	var items := {}
	var text := FileAccess.get_file_as_string(CATALOGUE)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed is Dictionary:
		items = (parsed as Dictionary).get("items", {})
	var locations := {}
	var bays: Array = []
	# Every rack bay in shelving order: D2's bins first, then D2 on, then east to west.
	var order: Array = []
	for r: String in ["D2", "D1", "C2", "C1", "B2", "B1", "A2", "A1"]:
		for b in range(1, BAYS + 1):
			order.append([r, b])
	var bin_bays: Array = order.slice(0, BIN_BAYS)
	var pallet_bays: Array = order.slice(BIN_BAYS)
	for rb: Array in order:
		var bins := bin_bays.has(rb)
		var rack: String = rb[0]
		var bay: int = rb[1]
		var x := rack_x(rack)
		var face := Vector3(rack_face(rack), 0, 0)
		var per := BINS if bins else POSITIONS
		var room := Vector3(RACK_DEPTH - 0.1, LEVEL_PITCH - 0.25, BAY_LENGTH / per - 0.15)
		for level in range(1, LEVELS + 1):
			for pos in range(1, per + 1):
				var id := "%s-%02d-%d-%d" % [rack, bay, level, pos]
				var z := bay_z(bay) + ((pos - 0.5) / per - 0.5) * BAY_LENGTH
				locations[id] = {"id": id, "kind": "bin" if bins else "pallet", "rack": rack,
						"bay": bay, "level": level, "pos": pos, "at": Vector3(x, level_y(level), z),
						"size": room, "face": face, "category": "", "home": ""}
		bays.append({"rack": rack, "bay": bay, "kind": "bin" if bins else "pallet", "category": ""})
	for col in BULK_X.size():
		for row in BULK_ROWS:
			var n := col * BULK_ROWS + row + 1
			var id := "Z-%02d" % n
			var at := Vector3(BULK_X[col], 0.0, BULK_Z0 - (row + 0.5) * BULK_ROW)
			# The middle column is picked from the lane west of it, the others from their east.
			var face := Vector3(-1 if col == 1 else 1, 0, 0)
			locations[id] = {"id": id, "kind": "bulk", "rack": "Z", "bay": n, "level": 1, "pos": 1,
					"at": at, "size": Vector3(BULK_SIZE.x, 3.0, BULK_SIZE.y), "face": face,
					"category": "", "home": ""}

	# Sort the parts by kind and category; heaviest first inside a category.
	var by_kind := {"bin": [], "pallet": [], "bulk": []}
	for id: String in items:
		by_kind[kind_for(float(items[id].get("mass", 0.0)))].append(id)
	var cat_order: Array = CATEGORIES.keys()
	var rank := func(a: String, b: String) -> bool:
		var ca := cat_order.find(str(items[a].get("category", "")))
		var cb := cat_order.find(str(items[b].get("category", "")))
		ca = cat_order.size() if ca < 0 else ca
		cb = cat_order.size() if cb < 0 else cb
		if ca != cb:
			return ca < cb
		var ma := float(items[a].get("mass", 0.0))
		var mb := float(items[b].get("mass", 0.0))
		return ma > mb if ma != mb else a < b
	for k: String in by_kind:
		(by_kind[k] as Array).sort_custom(rank)
	var homes := {}

	# Bins: one after another through the bin bays, bottom level up.
	var bin_slots: Array = []
	for rb: Array in bin_bays:
		for level in range(1, LEVELS + 1):
			for pos in range(1, BINS + 1):
				bin_slots.append("%s-%02d-%d-%d" % [rb[0], rb[1], level, pos])
	for i in mini(bin_slots.size(), by_kind["bin"].size()):
		_home(locations, homes, bin_slots[i], by_kind["bin"][i], items)
	# Pallets: each category starts a new bay and fills it from the bottom level up.
	var bay_i := 0
	var cat := ""
	var used := 0
	for item: String in by_kind["pallet"]:
		var c := str(items[item].get("category", ""))
		if c != cat and used > 0:
			bay_i += 1
			used = 0
		cat = c
		if used >= LEVELS * POSITIONS:
			bay_i += 1
			used = 0
		if bay_i >= pallet_bays.size():
			break
		var rb: Array = pallet_bays[bay_i]
		var id := "%s-%02d-%d-%d" % [rb[0], rb[1], used / POSITIONS + 1, used % POSITIONS + 1]
		_home(locations, homes, id, item, items)
		used += 1
	# Bulk: one floor bay each.
	for i in mini(BULK_X.size() * BULK_ROWS, by_kind["bulk"].size()):
		_home(locations, homes, "Z-%02d" % (i + 1), by_kind["bulk"][i], items)
	# A bay's category is the one most of its homes are.
	for b: Dictionary in bays:
		var counts := {}
		for level in range(1, LEVELS + 1):
			for pos in range(1, (BINS if b["kind"] == "bin" else POSITIONS) + 1):
				var c: String = locations["%s-%02d-%d-%d" % [b["rack"], b["bay"], level, pos]]["category"]
				if c != "":
					counts[c] = int(counts.get(c, 0)) + 1
		var best := ""
		for c: String in counts:
			if best == "" or int(counts[c]) > int(counts[best]):
				best = c
		b["category"] = best if b["kind"] == "pallet" else "small parts"

	var aisles := {}
	for a: String in ["A", "B", "C", "D"]:
		aisles[a] = aisle_x(a)
	var goods_in: Array = []
	for i in GOODS_IN_ROWS:
		for j in GOODS_IN_COLS:
			var spot := Vector3(-44 + j * 3.2, 0, -16 + i * 3.6 + (2.0 if j == 1 else 0.0))
			if spot.distance_to(Vector3(-44, 0, 8)) >= 3.0:   # clear of the truck door's leveller
				goods_in.append(spot)
	return {"items": items, "locations": locations, "homes": homes, "bays": bays,
			"aisles": aisles, "goods_in": goods_in}


static func _home(locations: Dictionary, homes: Dictionary, loc: String, item: String, items: Dictionary) -> void:
	locations[loc]["home"] = item
	locations[loc]["category"] = str(items[item].get("category", ""))
	homes[item] = loc
