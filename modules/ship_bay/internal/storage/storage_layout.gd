extends RefCounted
## The storage hall's layout: every location on its shelves, and the home each small part
## BSX can buy has there. Static data, the same on every machine, built once.
##
## The hall (Stock, x -50..0, z -46..-24) is reached from the transfer aisle along its south
## wall (the doors from Deliveries and the courtyard open onto it). Its racks run north from
## it, each with its aisle beside it (rack A1 west of aisle A, A2 east of it); a location is
## "<rack>-<bay>-<level>-<position>", "B2-03-4-1" being rack B2, bay 3, level 4, position 1.
## A part is shelved by its size (item_sizes.json, as ItemLook draws it):
## - Small racks, aisles A..C on the east side, for parts that fit a 1.0 x 1.55 m place up to
##   2.05 m tall: 4 bays, 4 levels, 2 places a level, shelved by category (a category to a
##   run of whole bays, the heaviest at the bottom). The picking lift ("p") works them.
## - Bins: the first four bays of C2, by the courtyard door, hold three totes a level for
##   the small parts (under BIN_MAX kg): "C2-01-2-3".
## - Large racks, aisles W and X: 2.6 m deep, two 5.4 m bays, 3 levels of 2.45 m, two
##   places a level (a long bay has one, 5.25 m long) for parts up to 2.5 x 5.25 m.
## - Heavy racks, aisle H by the west wall: 3.4 m deep, two 6.2 m bays, a 4.2 m ground
##   level and two lower ones over it, one place a level, for the biggest machines.
##   Large and heavy goods ("bulk") have no fixed home: each goes on the smallest free place
##   it fits. The heavy lift ("h") works aisles H, W and X.
## Locations without a home are spare: anything not in the catalogue goes to the first free one.

const CATALOGUE := "res://modules/ship_bay/internal/storage/storage_catalogue.json"
const SIZES := "res://modules/ship_bay/internal/storage/item_sizes.json"
## Shelving order of the categories, and their names on the signs.
const CATEGORIES := {
	"engines": "Engines", "electronics": "Electronics", "machinery": "Machinery",
	"fluids": "Fluids", "weapons": "Weapons", "cargo": "Cargo", "hull": "Hull",
	"frame": "Frame", "wiring": "Wiring", "piping": "Piping", "glass": "Glass",
	"fittings": "Fittings", "modules": "Ship modules", "fasteners": "Fasteners",
}
## Kilograms: lighter parts go in bins. Parts whose size isn't known are bulk over PALLET_MAX.
const BIN_MAX := 40.0
const PALLET_MAX := 6000.0

## Small rack geometry, metres (yard space).
const RACK_DEPTH := 1.1
const AISLE_WIDTH := 3.0
const RACK_X0 := -19.1          # west face of rack A1
const RACK_Z0 := -29.2          # south end of every rack
const BAY_LENGTH := 3.4
const BAYS := 4
const LEVELS := 4
const LEVEL_PITCH := 2.3
const BEAM_Y := 0.15            # top of level 1's beams; level k's are LEVEL_PITCH higher each
const POSITIONS := 2
const BINS := 3
const BIN_BAYS := 4             # bays at the start of C2 that hold bins
const RACK_HEIGHT := 9.2        # the end frames
## The large and heavy racks: [rack, west face x, front (+1 east, -1 west), spec]. Specs
## give depth, bay length, bays, the levels' beam tops, the end frames' height, and how
## many places each bay has a level.
const LARGE := {"depth": 2.6, "bay": 5.4, "bays": 2, "beams": [0.15, 2.85, 5.55], "height": 8.2, "aisle": 4.0}
const HEAVY := {"depth": 3.4, "bay": 6.2, "bays": 2, "beams": [0.15, 4.6, 7.3], "height": 9.5, "aisle": 4.4}
const BIG_RACKS := [
	["H1", -49.6, 1.0, "heavy", [1, 1]], ["H2", -41.8, -1.0, "heavy", [1, 1]],
	["W1", -38.1, 1.0, "large", [2, 2]], ["W2", -31.5, -1.0, "large", [2, 1]],
	["X1", -28.6, 1.0, "large", [2, 2]], ["X2", -22.0, -1.0, "large", [2, 1]],
]
## The transfer aisle's centre line (z) and the cross aisle behind the racks.
const TRANSFER_Z := -26.4
const BACK_Z := -44.3
## Goods-in floor spots in the Deliveries hall, where delivered crates are set down.
const GOODS_IN_ROWS := 6
const GOODS_IN_COLS := 3

static var _built: Dictionary = {}
static var _sizes: Dictionary = {}


## The layout: {items, locations (id -> location), homes (item -> location id), racks
## (id -> rack), aisles (letter -> x), bays, goods_in}. A location is {id, kind ("bin",
## "pallet" or "bulk"), store ("small", "large", "heavy"), rack, bay, level, pos, at (Vector3:
## the floor of the place, centred), size (the room there: x across the rack, y up, z along
## it), face (towards where it is picked from), category, home (item id or "")}. A rack is
## {id, store, x (centre), face, depth, bay (length), bays, beams, height, aisle, per}.
static func get_layout() -> Dictionary:
	if _built.is_empty():
		_built = _build()
	return _built


## The catalogue: item id -> {name, category, mass (kg)}.
static func items() -> Dictionary:
	return get_layout()["items"]


## An item's size as drawn (x across, y up, z along; metres), or ZERO when not known.
static func size_of(item: String) -> Vector3:
	if _sizes.is_empty():
		var text := FileAccess.get_file_as_string(SIZES)
		var parsed: Variant = JSON.parse_string(text) if text != "" else null
		_sizes = (parsed as Dictionary).get("sizes", {}) if parsed is Dictionary else {"": []}
	var s: Variant = _sizes.get(item, [])
	return Vector3(float(s[0]), float(s[1]), float(s[2])) if s is Array and (s as Array).size() == 3 else Vector3.ZERO


## Does goods `size` big go in a place with room `room` (either way round on the floor)?
static func fits(size: Vector3, room: Vector3) -> bool:
	var a := minf(size.x, size.z)
	var b := maxf(size.x, size.z)
	return a <= minf(room.x, room.z) + 0.001 and b <= maxf(room.x, room.z) + 0.001 and size.y <= room.y + 0.001


## The room in a small rack's pallet place.
static func pallet_room() -> Vector3:
	return Vector3(RACK_DEPTH - 0.1, LEVEL_PITCH - 0.25, BAY_LENGTH / POSITIONS - 0.15)


## "bin", "pallet" or "bulk" for goods of this mass (kg) and, given an item, its size:
## a part too big for a small rack's place is bulk whatever it weighs.
static func kind_for(mass: float, item := "") -> String:
	if mass < BIN_MAX:
		return "bin"
	var size := size_of(item) if item != "" else Vector3.ZERO
	if size == Vector3.ZERO:
		return "pallet" if mass <= PALLET_MAX else "bulk"
	return "pallet" if fits(size, pallet_room()) else "bulk"


## An item's kind by its catalogue mass and size.
static func kind_of(item: String) -> String:
	return kind_for(float(items().get(item, {}).get("mass", 0.0)), item)


## The rack ids west to east.
static func rack_ids() -> PackedStringArray:
	return PackedStringArray(["H1", "H2", "W1", "W2", "X1", "X2", "A1", "A2", "B1", "B2", "C1", "C2"])


## A rack's record (see get_layout), {} for none.
static func rack(id: String) -> Dictionary:
	return (get_layout()["racks"] as Dictionary).get(id, {})


## A rack's centre line (x) and the way its front faces (+1 east, -1 west).
static func rack_x(id: String) -> float:
	return float(rack(id).get("x", 0.0))


static func rack_face(id: String) -> float:
	return float(rack(id).get("face", 1.0))


## An aisle's centre line (x), "A".."C", "W", "X" or "H".
static func aisle_x(aisle: String) -> float:
	return float((get_layout()["aisles"] as Dictionary).get(aisle, 0.0))


## An aisle's width, metres.
static func aisle_width(aisle: String) -> float:
	return float(rack(aisle + "1").get("aisle", AISLE_WIDTH))


## Centre of a bay along its rack (z), 1..bays (a small rack's unless `id` names another).
static func bay_z(bay: int, id := "") -> float:
	var length := BAY_LENGTH if id == "" else float(rack(id).get("bay", BAY_LENGTH))
	return RACK_Z0 - (bay - 0.5) * length


## Height of a level's goods (on its beams), 1..levels (a small rack's unless `id` names another).
static func level_y(level: int, id := "") -> float:
	if id != "" and rack(id).has("beams"):
		return float(rack(id)["beams"][level - 1]) + 0.06
	return BEAM_Y + (level - 1) * LEVEL_PITCH + 0.06


## The lift that works a rack: "h" for the large and heavy racks, else "p".
static func lift_for_rack(id: String) -> String:
	return "p" if str(rack(id).get("store", "small")) == "small" else "h"


static func _racks() -> Dictionary:
	var racks := {}
	for i in 3:
		var aisle: String = ["A", "B", "C"][i]
		var west := RACK_X0 + i * (2.0 * RACK_DEPTH + AISLE_WIDTH + 0.2)
		var beams: Array = []
		for level in LEVELS:
			beams.append(BEAM_Y + level * LEVEL_PITCH)
		for side in 2:
			racks[aisle + str(side + 1)] = {"id": aisle + str(side + 1), "store": "small",
					"x": west + RACK_DEPTH * 0.5 if side == 0 else west + RACK_DEPTH * 1.5 + AISLE_WIDTH,
					"face": 1.0 if side == 0 else -1.0, "depth": RACK_DEPTH, "bay": BAY_LENGTH, "bays": BAYS,
					"beams": beams, "height": RACK_HEIGHT, "aisle": AISLE_WIDTH, "per": [POSITIONS, POSITIONS, POSITIONS, POSITIONS]}
	for r: Array in BIG_RACKS:
		var spec: Dictionary = HEAVY if r[3] == "heavy" else LARGE
		racks[r[0]] = {"id": r[0], "store": r[3], "x": float(r[1]) + float(spec["depth"]) * 0.5, "face": r[2],
				"depth": spec["depth"], "bay": spec["bay"], "bays": spec["bays"], "beams": spec["beams"],
				"height": spec["height"], "aisle": spec["aisle"], "per": r[4]}
	return racks


static func _build() -> Dictionary:
	var items := {}
	var text := FileAccess.get_file_as_string(CATALOGUE)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed is Dictionary:
		items = (parsed as Dictionary).get("items", {})
	var racks := _racks()
	var locations := {}
	var bays: Array = []
	# Every small rack bay in shelving order: C2's bins first, then C2 on, then east to west.
	var order: Array = []
	for r: String in ["C2", "C1", "B2", "B1", "A2", "A1"]:
		for b in range(1, BAYS + 1):
			order.append([r, b])
	var bin_bays: Array = order.slice(0, BIN_BAYS)
	var pallet_bays: Array = order.slice(BIN_BAYS)
	for rb: Array in order:
		var bins := bin_bays.has(rb)
		var r: Dictionary = racks[rb[0]]
		var bay: int = rb[1]
		var per := BINS if bins else POSITIONS
		var room := Vector3(RACK_DEPTH - 0.1, LEVEL_PITCH - 0.25, BAY_LENGTH / per - 0.15)
		for level in range(1, LEVELS + 1):
			for pos in range(1, per + 1):
				var id := "%s-%02d-%d-%d" % [r["id"], bay, level, pos]
				var z := RACK_Z0 - (bay - 0.5) * BAY_LENGTH + ((pos - 0.5) / per - 0.5) * BAY_LENGTH
				locations[id] = {"id": id, "kind": "bin" if bins else "pallet", "store": "small", "rack": r["id"],
						"bay": bay, "level": level, "pos": pos, "at": Vector3(r["x"], float(r["beams"][level - 1]) + 0.06, z),
						"size": room, "face": Vector3(r["face"], 0, 0), "category": "", "home": ""}
		bays.append({"rack": r["id"], "bay": bay, "kind": "bin" if bins else "pallet", "category": ""})
	# The large and heavy racks, west to east: bulk places, no homes.
	for id: String in rack_ids():
		var r: Dictionary = racks[id]
		if r["store"] == "small":
			continue
		var beams: Array = r["beams"]
		var length := float(r["bay"])
		for bay in range(1, int(r["bays"]) + 1):
			var per := int(r["per"][bay - 1])
			var z0 := RACK_Z0 - (bay - 0.5) * length
			for level in range(1, beams.size() + 1):
				var top := float(beams[level]) if level < beams.size() else float(r["height"])
				var room := Vector3(float(r["depth"]) - 0.1, top - float(beams[level - 1]) - 0.25, length / per - 0.15)
				for pos in range(1, per + 1):
					var loc := "%s-%02d-%d-%d" % [id, bay, level, pos]
					locations[loc] = {"id": loc, "kind": "bulk", "store": r["store"], "rack": id, "bay": bay,
							"level": level, "pos": pos,
							"at": Vector3(r["x"], float(beams[level - 1]) + 0.06, z0 + ((pos - 0.5) / per - 0.5) * length),
							"size": room, "face": Vector3(r["face"], 0, 0), "category": "", "home": ""}
			bays.append({"rack": id, "bay": bay, "kind": "bulk", "category": ""})

	# Sort the parts by kind and category; heaviest first inside a category.
	var by_kind := {"bin": [], "pallet": [], "bulk": []}
	for id: String in items:
		by_kind[kind_for(float(items[id].get("mass", 0.0)), id)].append(id)
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
	# A bay's category is the one most of its homes are.
	for b: Dictionary in bays:
		var counts := {}
		if b["kind"] == "bulk":
			continue
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
	for id: String in rack_ids():
		if id.ends_with("1"):
			var r: Dictionary = racks[id]
			aisles[id.left(1)] = float(r["x"]) + float(r["depth"]) * 0.5 + float(r["aisle"]) * 0.5
	var goods_in: Array = []
	for i in GOODS_IN_ROWS:
		for j in GOODS_IN_COLS:
			var spot := Vector3(-44 + j * 3.2, 0, -16 + i * 3.6 + (2.0 if j == 1 else 0.0))
			if spot.distance_to(Vector3(-44, 0, 8)) >= 3.0:   # clear of the truck door's leveller
				goods_in.append(spot)
	return {"items": items, "locations": locations, "homes": homes, "bays": bays, "racks": racks,
			"aisles": aisles, "goods_in": goods_in}


static func _home(locations: Dictionary, homes: Dictionary, loc: String, item: String, items: Dictionary) -> void:
	locations[loc]["home"] = item
	locations[loc]["category"] = str(items[item].get("category", ""))
	homes[item] = loc
