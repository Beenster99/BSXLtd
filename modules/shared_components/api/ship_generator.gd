class_name ShipGenerator
extends RefCounted
## BSX's own ships for its fictional clients: a hull nobody has seen before, rolled from a
## seed in a size class (S, M, L) and a family that fits the client (courier, freighter, miner,
## tanker, tug, liner), built with the shared frame-first kit Void Salvage builds the Kestrel
## and Manta with (FrameHull, DeckFrame, StudWall, ShipParts fittings) and handed over as a
## vsship 2.0 file: parts and joints with paths, phases and recipes, exactly as an import
## from Void Salvage is. So the importer builds it (`VsShipImport.build`), the wreck maker
## damages it (`WreckMaker.make`) and the bay treats it like any other ship.
##
## Use: `ShipGenerator.make(seed, "M", "freighter")` for the file, or by design id
## (`ShipGenerator.design_id(seed, "M", "freighter")` = "gen:freighter:M:<seed>", which
## `VsShipImport.design_file`'s callers may pass as a design: `file_of(id)`). The same seed,
## class and family give the same ship on every machine, so a contract need only carry those.
## `family_for(client_kind)` picks the family for a client's trade.
##
## Ship space: -Z forward, +Y up, the deck's floor y = 0. Metres and kilograms.

const ID_PREFIX := "gen:"
const CLASSES: Array[String] = ["S", "M", "L"]
const FAMILIES: Array[String] = ["courier", "freighter", "miner", "tanker", "tug", "liner"]
## A client's trade -> the family its ships come in.
const CLIENT_FAMILIES := {
	"courier": "courier", "express": "courier", "survey": "courier", "scout": "courier", "charter": "courier",
	"freight": "freighter", "freighter": "freighter", "hauler": "freighter", "cargo": "freighter", "logistics": "freighter",
	"mining": "miner", "miner": "miner", "ore": "miner", "prospecting": "miner",
	"fuel": "tanker", "tanker": "tanker", "gas": "tanker", "chemical": "tanker",
	"salvage": "tug", "tug": "tug", "towing": "tug", "recovery": "tug", "rescue": "tug",
	"passenger": "liner", "liner": "liner", "ferry": "liner", "tour": "liner", "medical": "liner",
}
## Length, half width and roof height over the deck per class: [min, max] each, metres.
const SIZES := {
	"S": {"length": [11.0, 15.0], "width": [2.0, 2.6], "height": [2.7, 3.3]},
	"M": {"length": [19.0, 27.0], "width": [3.0, 4.0], "height": [3.5, 4.5]},
	"L": {"length": [32.0, 44.0], "width": [4.3, 5.6], "height": [4.6, 6.2]},
}
## How each family bends the class's sizes and shape: length, width and height factors; the
## flat roof's and belly's share of the half width (a boxy hull has wide flats, a round one
## narrow); how far the nose shrinks; whether it has a belly hatch, a stern door, a glazed nose.
const SHAPES := {
	"courier": {"length": 1.15, "width": 0.8, "height": 0.85, "roof_x": 0.55, "bottom_x": 0.7, "nose": 0.55,
			"hatch": false, "stern_door": false, "glazed": true, "windows": 1},
	"freighter": {"length": 1.0, "width": 1.1, "height": 1.1, "roof_x": 0.85, "bottom_x": 0.85, "nose": 0.7,
			"hatch": true, "stern_door": true, "glazed": false, "windows": 1},
	"miner": {"length": 0.9, "width": 1.3, "height": 0.8, "roof_x": 0.8, "bottom_x": 0.9, "nose": 0.75,
			"hatch": true, "stern_door": false, "glazed": false, "windows": 1},
	"tanker": {"length": 1.1, "width": 1.0, "height": 1.0, "roof_x": 0.45, "bottom_x": 0.5, "nose": 0.65,
			"hatch": false, "stern_door": false, "glazed": false, "windows": 1},
	"tug": {"length": 0.75, "width": 1.0, "height": 1.15, "roof_x": 0.75, "bottom_x": 0.8, "nose": 0.7,
			"hatch": true, "stern_door": true, "glazed": false, "windows": 1},
	"liner": {"length": 1.2, "width": 1.0, "height": 1.0, "roof_x": 0.65, "bottom_x": 0.6, "nose": 0.6,
			"hatch": false, "stern_door": false, "glazed": true, "windows": 2},
}
## Hull and trim paints per family (sRGB), one pair rolled per ship.
const PALETTES := {
	"courier": [[Color(0.86, 0.87, 0.9), Color(0.1, 0.45, 0.85)], [Color(0.2, 0.24, 0.3), Color(0.95, 0.8, 0.2)],
			[Color(0.9, 0.9, 0.88), Color(0.85, 0.2, 0.2)]],
	"freighter": [[Color(0.78, 0.45, 0.15), Color(0.15, 0.15, 0.17)], [Color(0.5, 0.52, 0.5), Color(0.9, 0.55, 0.1)],
			[Color(0.3, 0.4, 0.5), Color(0.9, 0.85, 0.3)]],
	"miner": [[Color(0.85, 0.7, 0.15), Color(0.15, 0.15, 0.15)], [Color(0.45, 0.42, 0.38), Color(0.95, 0.6, 0.1)],
			[Color(0.6, 0.35, 0.15), Color(0.9, 0.9, 0.2)]],
	"tanker": [[Color(0.4, 0.45, 0.42), Color(0.9, 0.9, 0.9)], [Color(0.25, 0.5, 0.4), Color(0.95, 0.95, 0.4)],
			[Color(0.55, 0.57, 0.6), Color(0.2, 0.6, 0.3)]],
	"tug": [[Color(0.7, 0.15, 0.12), Color(0.95, 0.95, 0.9)], [Color(0.2, 0.2, 0.22), Color(0.95, 0.4, 0.1)],
			[Color(0.55, 0.25, 0.1), Color(0.85, 0.85, 0.2)]],
	"liner": [[Color(0.92, 0.92, 0.9), Color(0.2, 0.3, 0.6)], [Color(0.85, 0.82, 0.75), Color(0.6, 0.15, 0.3)],
			[Color(0.75, 0.8, 0.85), Color(0.95, 0.75, 0.2)]],
}
## Names, by family: a first word and a second word, rolled from the seed.
const NAMES := {
	"courier": [["Swift", "Arrow", "Dart", "Kite", "Lark", "Sprint"], ["Runner", "Wing", "Lance", "Courier", "Flash", "Glint"]],
	"freighter": [["Broad", "Iron", "Steady", "Grey", "Long", "Stone"], ["Hauler", "Mule", "Carrier", "Wain", "Bearer", "Packet"]],
	"miner": [["Rock", "Ore", "Deep", "Dust", "Grit", "Drill"], ["Breaker", "Digger", "Claw", "Mole", "Hammer", "Gouge"]],
	"tanker": [["Brine", "Cask", "Tide", "Still", "Vat", "Cistern"], ["Carrier", "Bearer", "Keel", "Drum", "Hold", "Flask"]],
	"tug": [["Stout", "Bull", "Anvil", "Tow", "Hard", "Short"], ["Tug", "Haul", "Pull", "Hitch", "Yoke", "Shunt"]],
	"liner": [["Fair", "Silver", "Bright", "Calm", "Gentle", "Star"], ["Voyager", "Passage", "Belle", "Crest", "Promenade", "Sail"]],
}

const BELLY: float = -0.7          # the keel's underside, below the deck floor (m): room for the deck beams
const DOORWAY := Rect2(-0.55, 0.0, 1.1, 2.1)   # a stud wall's doorway (x, y)
const NOSE_SCALE_Y: float = 0.45   # the nose shrinks about this share of the roof height

var seed_value: int = 0
var size_class: String = "S"
var family: String = "freighter"
var rng := RandomNumberGenerator.new()
var shape: Dictionary = {}
## Rolled dimensions, metres.
var length: float
var half_width: float
var roof: float
var roof_x: float
var bottom_x: float
var bay_length: float
## The lower chamfer's rise from the keel to the side (the chine stays under the deck).
var chine_rise: float
var nose_length: float
var bay_count: int
## The stations as [z, label], front to back.
var stations: Array = []
var hatch := Rect2()
var stern_door := Rect2()

var body: RigidBody3D
var kit: ShipKit
var hull: FrameHull
var deck: DeckFrame
var walls: Array[StudWall] = []
var rooms: Array[AABB] = []
var room_names: Array[String] = []
var seats: Array[Vector3] = []
var exit_point := Vector3.ZERO
var hold := AABB()
## Materials, named for the file.
var mats: Dictionary = {}
var _mat_names: Dictionary = {}
var _mat_table: Dictionary = {}
var _livery_mats: Dictionary = {}
var tacks: Dictionary = {}


# --- The API -------------------------------------------------------------------------------

## A ship's file from a seed, size class and family ("" rolls them from the seed).
static func make(seed_in: int, size_in: String = "", family_in: String = "") -> Dictionary:
	var g := ShipGenerator.new()
	return g.generate(seed_in, size_in, family_in)


## "gen:<family>:<class>:<seed>", what a contract carries as the design.
static func design_id(seed_in: int, size_in: String, family_in: String) -> String:
	return "%s%s:%s:%d" % [ID_PREFIX, family_in, size_in, seed_in]


static func is_generated(id: String) -> bool:
	return id.begins_with(ID_PREFIX) and not parse_id(id).is_empty()


## {seed, size, family} from a design id, {} if it is not one of ours.
static func parse_id(id: String) -> Dictionary:
	if not id.begins_with(ID_PREFIX):
		return {}
	var parts := id.trim_prefix(ID_PREFIX).split(":")
	if parts.size() != 3 or not FAMILIES.has(parts[0]) or not CLASSES.has(parts[1]) or not parts[2].is_valid_int():
		return {}
	return {"seed": int(parts[2]), "size": parts[1], "family": parts[0]}


## The ship a design id names, {} if the id is not one of ours.
static func file_of(id: String) -> Dictionary:
	var p := parse_id(id)
	if p.is_empty():
		return {}
	return make(int(p["seed"]), p["size"], p["family"])


## The family a client's trade calls for ("freighter" for one we have no word for).
static func family_for(client_kind: String) -> String:
	var key := client_kind.to_lower().strip_edges()
	if CLIENT_FAMILIES.has(key):
		return CLIENT_FAMILIES[key]
	for word: String in CLIENT_FAMILIES:
		if key.contains(word):
			return CLIENT_FAMILIES[word]
	return "freighter"


## The class and family a bare seed rolls (when a contract names neither).
static func roll_class(seed_in: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_in, "class"])
	var roll := r.randf()
	return "S" if roll < 0.5 else ("M" if roll < 0.85 else "L")


static func roll_family(seed_in: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_in, "family"])
	return FAMILIES[r.randi_range(0, FAMILIES.size() - 1)]


## The ship's name, from its seed and family.
static func ship_name(seed_in: int, family_in: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_in, "name"])
	var words: Array = NAMES.get(family_in, NAMES["freighter"])
	var first: Array = words[0]
	var second: Array = words[1]
	return "%s %s" % [first[r.randi_range(0, first.size() - 1)], second[r.randi_range(0, second.size() - 1)]]


# --- The build ------------------------------------------------------------------------------

func generate(seed_in: int, size_in: String, family_in: String) -> Dictionary:
	seed_value = seed_in
	size_class = size_in if CLASSES.has(size_in) else roll_class(seed_in)
	family = family_in if FAMILIES.has(family_in) else roll_family(seed_in)
	rng.seed = hash([seed_value, size_class, family, "ship"])
	shape = SHAPES[family]
	_roll_dimensions()
	_materials()
	body = RigidBody3D.new()
	body.name = "Generated"
	kit = ShipKit.new(body)
	kit.model = PartModel.new(body, true)
	kit.recorder = ShipRecorder.new()
	kit.fold = true
	kit.mount = _mount
	var livery_was := ShipParts.livery
	ShipParts.livery = "company"
	_build_hull()
	_build_deck()
	_line_hull()
	_build_walls()
	_build_fittings()
	_lights()
	ShipParts.livery = livery_was
	var file := _write()
	body.free()
	return file


func _range(lo_hi: Array, factor: float = 1.0) -> float:
	return rng.randf_range(float(lo_hi[0]), float(lo_hi[1])) * factor


func _roll_dimensions() -> void:
	var sizes: Dictionary = SIZES[size_class]
	length = snappedf(_range(sizes["length"], shape["length"]), 0.1)
	half_width = snappedf(_range(sizes["width"], shape["width"]), 0.05)
	roof = snappedf(_range(sizes["height"], shape["height"]), 0.05)
	roof_x = snappedf(half_width * float(shape["roof_x"]) * rng.randf_range(0.9, 1.1), 0.05)
	bottom_x = snappedf(half_width * float(shape["bottom_x"]) * rng.randf_range(0.9, 1.1), 0.05)
	roof_x = clampf(roof_x, half_width * 0.35, half_width - 0.3)
	bottom_x = clampf(bottom_x, half_width * 0.4, half_width - 0.2)
	# The chine stays under the deck beams (0.18 m down), so they end on the side members.
	chine_rise = clampf(half_width - bottom_x, 0.25, 0.4)
	nose_length = snappedf(clampf(length * rng.randf_range(0.14, 0.2), 1.6, 5.0), 0.1)
	var target_bay := rng.randf_range(2.4, 3.2)
	bay_count = maxi(4, int(round((length - nose_length) / target_bay)))
	bay_length = (length - nose_length) / float(bay_count)
	stations.clear()
	var z0 := -length * 0.5
	stations.append([z0, "nose"])
	for k in bay_count + 1:
		var z := z0 + nose_length + float(k) * bay_length
		var label := "stern"
		if k < bay_count:
			label = _bay_label(k + 1)
		stations.append([snappedf(z, 0.001), label])
	# The belly hatch in the middle hold bay, the stern door in the stern cap.
	if shape["hatch"]:
		var holds := _hold_bays()
		var bay: int = holds[(holds.size() - 1) / 2]
		var hw := minf(1.1, half_width * 0.4)
		var len := minf(2.6, bay_length - 0.9)
		var mid := _bay_z(bay) + bay_length * 0.5
		hatch = Rect2(-hw, mid - len * 0.5, hw * 2.0, len)
	if shape["stern_door"]:
		var hw := minf(1.8, bottom_x * 0.8)
		stern_door = Rect2(-hw, 0.05, hw * 2.0, minf(roof - 0.6, 2.6))


## Bay k (1 = the first after the nose bay) is the cockpit, the cabin, a hold bay or the engine room.
func _bay_label(k: int) -> String:
	if k == 1:
		return "cockpit"
	if k == 2:
		return "cabin"
	if k == bay_count:
		return "engine"
	return "hold" if k == 3 else "hold_%d" % (k - 2)


func _hold_bays() -> Array:
	var out: Array = []
	for k in range(3, bay_count):
		out.append(k)
	return out


## The front station's z of bay k (bay 0 is the nose bay).
func _bay_z(k: int) -> float:
	return float(stations[k][0])


func _station_z(i: int) -> float:
	return float(stations[i][0])


## The hull's cross-section at a station, `s` of full size, shrunk about the roof's middle
## height (so a nose tapers evenly). Edges: 0 roof, 1 right shoulder, 2 right side, 3 right
## chine, 4 bottom, 5 left chine, 6 left side, 7 left shoulder.
func profile(s: float = 1.0) -> PackedVector2Array:
	var yc := roof * NOSE_SCALE_Y
	var top := yc + (roof - yc) * s
	var belly := yc + (BELLY - yc) * s
	var w := half_width * s
	var r := roof_x * s
	var b := bottom_x * s
	var shoulder := top - (w - r)
	var chine := belly + chine_rise * s
	return PackedVector2Array([Vector2(-r, top), Vector2(r, top), Vector2(w, shoulder), Vector2(w, chine),
			Vector2(b, belly), Vector2(-b, belly), Vector2(-w, chine), Vector2(-w, shoulder)])


func _materials() -> void:
	var palette: Array = PALETTES[family]
	var pair: Array = palette[rng.randi_range(0, palette.size() - 1)]
	var shell_c: Color = pair[0]
	var trim_c: Color = pair[1]
	mats["shell"] = ShipKit.paint(shell_c, 0.3, 0.45)
	mats["trim"] = ShipKit.paint(trim_c, 0.35, 0.4)
	mats["frame_steel"] = ShipKit.paint(Color(0.34, 0.36, 0.38), 0.75, 0.4)
	mats["lining"] = ShipKit.paint(Color(0.74, 0.74, 0.72), 0.1, 0.65)
	mats["floor_mat"] = ShipKit.paint(Color(0.22, 0.23, 0.24), 0.6, 0.6)
	mats["dark"] = ShipKit.paint(Color(0.14, 0.15, 0.16), 0.6, 0.5)
	mats["hull_dark"] = ShipKit.paint(Color(0.26, 0.28, 0.3), 0.6, 0.45)
	var glass := ShipKit.glass()
	glass.albedo_color = Color(0.45, 0.65, 0.85, 0.28)
	glass.metallic = 0.4
	glass.roughness = 0.04
	mats["glass"] = glass
	for key: String in mats:
		_mat_names[(mats[key] as Material).get_instance_id()] = key
	for which: String in ["shell", "trim", "dark", "soft", "top", "belly", "lining", "steel", "edge", "screen", "warm", "cold"]:
		_livery_mats[ShipParts.mat(which).get_instance_id()] = which


func mat(key: String) -> Material:
	return mats[key]


func _build_hull() -> void:
	kit.group = "hull"
	var style_id := "kestrel" if size_class == "S" else "channel"
	var h := FrameHull.new(kit, style_id, mat("shell"), mat("frame_steel"), mat("glass"))
	h.name = "hull"
	h.groove = 0.0
	hull = h
	var nose_scale: float = shape["nose"]
	for i in stations.size():
		h.add_station(_station_z(i), profile(nose_scale if i == 0 else 1.0), stations[i][1])
	var zs: Array[float] = []
	for st: Array in stations:
		zs.append(float(st[0]))
	var hatch_rect := hatch
	h.frame_skip = func(station: int, edge: int) -> bool:
		if not hatch_rect.has_area():
			return false
		var z: float = zs[station]
		return edge == 4 and z > hatch_rect.position.y - 0.3 and z < hatch_rect.end.y + 0.3
	# The looks: a trim band along the shoulders, the belly in the hull's dark; the nose bay's
	# top glazed on a glazed family.
	var glazed: bool = shape["glazed"]
	var shell := mat("shell")
	var trim := mat("trim")
	var belly_mat := mat("hull_dark")
	var glass := mat("glass")
	h.style = func(seg: int, edge: int) -> Dictionary:
		if glazed and seg == 0 and edge in [0, 1, 7]:
			return {"mat": glass, "glass": true}
		match edge:
			1, 7:
				return {"mat": trim}
			3, 4, 5:
				return {"mat": belly_mat}
		return {"mat": shell}
	# The holes, framed: the cockpit's windows each side (a liner's along the cabin and holds
	# too), the side door into the cabin, the belly hatch.
	var reveal := h.lining_inset + FrameHull.GAP - 0.002
	var window_bays: Array = [1]
	if int(shape["windows"]) > 1:
		window_bays.append(2)
		window_bays.append_array(_hold_bays())
	var win_y := clampf(1.15 + (roof - 3.2) * 0.25, 1.1, roof - 1.0)
	for bay: int in window_bays:
		var z := _bay_z(bay) + bay_length * 0.5
		for side: float in [-1.0, 1.0]:
			var hole := AABB(Vector3(side * half_width - 0.2, win_y - 0.3, z - 0.45), Vector3(0.4, 0.6, 0.9))
			var hole_name := "window_%s_%d" % ["r" if side > 0.0 else "l", bay]
			h.opening(2 if side > 0.0 else 6, hole, hole_name, AABB(), reveal)
	var door_z := _bay_z(2) + 0.4
	var door := AABB(Vector3(-half_width - 0.2, 0.0, door_z), Vector3(0.4, 2.05, 1.0))
	h.opening(6, door, "side_door", AABB(), reveal)
	if hatch.has_area():
		var hole := AABB(Vector3(hatch.position.x, BELLY - 0.2, hatch.position.y), Vector3(hatch.size.x, 0.4, hatch.size.y))
		h.opening(4, hole, "hatch")
	h.build()
	# The windows' glass in the holes: a pane part bolted to its jambs.
	kit.phase = "skin"
	for bay: int in window_bays:
		var z := _bay_z(bay) + bay_length * 0.5
		for side: float in [-1.0, 1.0]:
			var hole_name := "window_%s_%d" % ["r" if side > 0.0 else "l", bay]
			var pane := PartShapes.window_panel(0.6, 0.9, "chamfer", 0.16, 0.78)
			var x := side * (half_width - 0.04)
			var p := kit.part("WindowPane", PartData.Kind.GLASS, pane, Transform3D(Basis(Vector3.BACK, -side * PI * 0.5), Vector3(x, win_y, z)),
					mat("hull_dark"), "", 1.0, glass, "hull/opening:%s/pane" % hole_name)
			var n := 0
			for jamb: PartData in h.jambs:
				if not jamb.path.begins_with("hull/opening:%s/" % hole_name):
					continue
				var at := Vector3(x + side * 0.08, clampf(_jamb_mid(h, jamb).y, win_y - 0.4, win_y + 0.4), clampf(_jamb_mid(h, jamb).z, z - 0.25, z + 0.25))
				kit.join(p, jamb, ConnectionData.Kind.BOLT, at, Vector3.RIGHT * side, Vector3.ZERO, Vector2.ZERO,
						"hull/opening:%s/pane/bolt:%d" % [hole_name, n])
				n += 1
	# The caps: the nose as one plate (glazed on a glazed family), the stern round its door.
	h.cap(0, [profile(nose_scale)], glass if glazed else mat("hull_dark"), "", glazed)
	if stern_door.has_area():
		var pieces: Array = []
		var outline := profile()
		var far := half_width + 1.0
		for r: Rect2 in [Rect2(-far, BELLY - 1.0, far + stern_door.position.x, roof + 2.0),
				Rect2(stern_door.end.x, BELLY - 1.0, far, roof + 2.0),
				Rect2(stern_door.position.x, stern_door.end.y, stern_door.size.x, roof + 1.0),
				Rect2(stern_door.position.x, BELLY - 1.0, stern_door.size.x, 1.0 + stern_door.position.y)]:
			var piece := _clip(outline, r)
			if piece.size() >= 3:
				pieces.append(piece)
		h.cap(1, pieces, mat("hull_dark"))
	else:
		h.cap(1, [profile()], mat("hull_dark"))


## A convex outline clipped to a rectangle (x, y).
static func _clip(outline: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var rect := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var out := Geometry2D.intersect_polygons(outline, rect)
	if out.is_empty():
		return PackedVector2Array()
	var best: PackedVector2Array = out[0]
	# Drop points the clip left doubled.
	var clean := PackedVector2Array()
	for p in best:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 0.001:
			clean.append(p)
	if clean.size() > 1 and clean[0].distance_to(clean[clean.size() - 1]) < 0.001:
		clean.remove_at(clean.size() - 1)
	return clean


## The middle of a jamb member (ship space).
static func _jamb_mid(h: FrameHull, jamb: PartData) -> Vector3:
	for m: Dictionary in h._members:
		if m["part"] == jamb:
			return (m["p0"] + m["p1"]) * 0.5
	return Vector3.ZERO


func _build_deck() -> void:
	kit.group = "deck"
	var d := DeckFrame.new(hull, mat("floor_mat"), mat("frame_steel"))
	d.plate = 0.04
	d.spot_pitch = 0.5
	d.z0 = _station_z(1) - 0.06
	d.z1 = _station_z(stations.size() - 1) - 0.08
	if hatch.has_area():
		d.girder_x = [hatch.position.x - 0.15, hatch.end.x + 0.15]
		d.openings = [hatch]
	else:
		var gx := snappedf(half_width * 0.35, 0.05)
		d.girder_x = [-gx, gx]
	d.build()
	deck = d
	kit.group = "hull"


## Lines every face above the deck in every full bay, the panels bolted to the frame.
func _line_hull() -> void:
	for seg in range(1, stations.size() - 1):
		for e: int in [0, 1, 2, 6, 7]:
			hull.lining(seg, e, mat("lining"))


## How far in from the skin the linings' room faces stand.
func _lining_depth() -> float:
	return hull.skin + FrameHull.GAP + hull.depth + FrameHull.GAP + hull.lining_inset + hull.lining_thickness


func _build_walls() -> void:
	kit.group = "inner"
	var room := FrameParts.inset(profile(), _lining_depth() + 0.01)
	var engine_st := bay_count   # the station the engine bay starts at
	var at: Array = [[2, "cockpit_wall", ["cockpit", "cabin"]], [3, "bulkhead", ["cabin", "hold"]],
			[engine_st, "engine_wall", ["hold", "engine"]]]
	for spec: Array in at:
		var w := StudWall.new(kit, spec[1], _station_z(spec[0]), 0.12, room, mat("lining"), mat("frame_steel"))
		var faces: Array[String] = []
		for f: String in spec[2]:
			faces.append(f)
		w.faces = faces
		w.openings = [DOORWAY]
		w.floor = _floor_at
		w.anchor = _anchor
		w.build()
		walls.append(w)
	# The rooms between them (the cockpit takes the nose bay too).
	var ceiling := _lining_depth() + 0.02
	var inner_w := half_width - ceiling
	var z_list: Array = [_station_z(0), _station_z(2), _station_z(3), _station_z(engine_st), _station_z(stations.size() - 1)]
	var names: Array[String] = ["cockpit", "cabin", "hold", "engine"]
	for i in names.size():
		var z0: float = z_list[i] + 0.07
		var z1: float = z_list[i + 1] - 0.07
		var top := roof - ceiling
		rooms.append(AABB(Vector3(-inner_w, 0.0, z0), Vector3(inner_w * 2.0, top, z1 - z0)))
		room_names.append(names[i])
	hold = rooms[2]
	exit_point = Vector3(-inner_w + 0.6, 0.9, _bay_z(2) + 0.9)


## The deck plate under (x, z) (the sills weld to it).
func _floor_at(x: float, z: float) -> PartData:
	var best: PartData = null
	var best_d := INF
	for p: PartData in deck.plates:
		var b := _box_of(p)
		var dx := maxf(b.position.x - x, maxf(0.0, x - b.end.x))
		var dz := maxf(b.position.z - z, maxf(0.0, z - b.end.z))
		var d := dx * dx + dz * dz
		if d < best_d:
			best_d = d
			best = p
	return best


## The lining panel (or hull plate) nearest `p` (what a wall's head rails bolt to).
func _anchor(p: Vector3) -> PartData:
	var best: PartData = null
	var best_d := INF
	for panel: PartData in hull.lining_panels:
		var b := _box_of(panel)
		var q := p.clamp(b.position, b.end)
		var d := q.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = panel
	return best


## The bounds of a part's collision shapes (ship space).
func _box_of(p: PartData) -> AABB:
	var cols: Array = [kit.model.part_collider(p.id)]
	cols.append_array(kit.model.extra_colliders(p.id))
	var box := AABB()
	var first := true
	for col: CollisionShape3D in cols:
		if col == null or col.shape == null:
			continue
		var b := col.transform * col.shape.get_debug_mesh().get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# --- Fittings ------------------------------------------------------------------------------

## What the crew needs aboard: seats and a console in the cockpit, lockers and bunks in the
## cabin, the reactor cabinet and tanks in the engine room. Each is one part, spot-welded to
## the deck plate it stands on (`_mount`).
func _build_fittings() -> void:
	kit.group = "fittings"
	var cockpit: AABB = rooms[0]
	var cabin: AABB = rooms[1]
	var engine: AABB = rooms[3]
	var inner_w := cabin.size.x * 0.5
	# The cockpit: a console across the front of the first full bay, a seat or two behind it.
	var console_z := _station_z(1) + 0.75
	var console_w := minf(inner_w * 1.4, 2.6)
	ShipParts.console(kit, Transform3D(Basis(), Vector3(0.0, 0.0, console_z)), console_w)
	var seat_count := 1 if size_class == "S" and inner_w < 1.9 else 2
	for i in seat_count:
		var x := 0.0 if seat_count == 1 else (-0.72 if i == 0 else 0.72)
		var at := Vector3(x, 0.0, console_z + 0.85)
		ShipParts.seat(kit, at, "seat_%d" % i)
		seats.append(at + Vector3(0.0, 0.52, 0.0))
	# The cabin: lockers along the right wall, bunks along the left (behind the side door).
	var locker_n := 2 if size_class == "S" else 3
	for i in locker_n:
		var z := cabin.position.z + 0.5 + float(i) * 0.45
		ShipParts.locker(kit, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(inner_w - 0.02, 0.0, z)), 0.4, 0.42)
	var bunk_len := minf(1.95, cabin.size.z - 2.0)
	if bunk_len > 1.2:
		ShipParts.bunks(kit, Transform3D(Basis(), Vector3(-inner_w + 0.02, 0.0, cabin.end.z - bunk_len * 0.5 - 0.3)), bunk_len)
	# The engine room: the reactor cabinet against the stern wall, a tank each side.
	var cab_w := minf(inner_w * 1.2, 2.0)
	ShipParts.reactor_cabinet(kit, Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, engine.end.z - 0.05)), cab_w, 0.45,
			minf(2.2, engine.size.y - 0.3))
	var tank := Vector3(minf(0.9, inner_w * 0.4), minf(0.9, engine.size.y * 0.35), minf(1.6, engine.size.z - 1.4))
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * (inner_w - tank.x * 0.5 - 0.1), tank.y + 0.4, engine.position.z + engine.size.z * 0.45)
		ShipParts.jump_tank(kit, Transform3D(Basis(), at), tank, 0.1)
	kit.group = "hull"


## A fitting's part is spot-welded to the deck plate under its footprint's corners (phase
## "fitting"); a looks-only unit rides on that plate.
func _mount(made: PartData, unit: Dictionary) -> void:
	var box: AABB = _box_of(made) if made else unit.get("box", AABB())
	if not box.has_volume() and not box.has_surface():
		return
	var plate := _floor_at(box.get_center().x, box.get_center().z)
	if plate == null:
		return
	if made == null:
		unit["onto"] = plate
		return
	var top := _box_of(plate).end.y
	var inset := minf(0.08, minf(box.size.x, box.size.z) * 0.25)
	var points: Array = []
	for corner: Vector2 in [Vector2(box.position.x + inset, box.position.z + inset), Vector2(box.end.x - inset, box.position.z + inset),
			Vector2(box.end.x - inset, box.end.z - inset), Vector2(box.position.x + inset, box.end.z - inset)]:
		points.append(Vector3(corner.x, top, corner.y))
	var spots := kit.tack(made, plate, points, Vector3.UP, made.path)
	tacks[made.path] = {"onto": [plate.path], "spots": spots.size()}


func _lights() -> void:
	kit.group = "lights"
	for i in rooms.size():
		var r: AABB = rooms[i]
		var n := 1 if r.size.z < 4.0 else int(ceil(r.size.z / 3.5))
		for k in n:
			var z := r.position.z + r.size.z * (float(k) + 0.5) / float(n)
			kit.light(Vector3(0.0, r.end.y - 0.15, z), Color(1.0, 0.96, 0.9), 1.2, maxf(4.0, r.size.x * 1.2))
	kit.group = ""


# --- The file ------------------------------------------------------------------------------

## A material's name in the file (its record goes in the table the first time).
func name_of(m: Material) -> String:
	if m == null:
		return ""
	var id := m.get_instance_id()
	if _mat_names.has(id):
		var known: String = _mat_names[id]
		if not _mat_table.has(known):
			_mat_table[known] = _record_of(m, known)
		return known
	if _livery_mats.has(id):
		var which: String = _livery_mats[id]
		_mat_names[id] = which
		_mat_table[which] = {"livery": which}
		return which
	var std := m as StandardMaterial3D
	var name := "mat_%d" % id
	if std:
		var c := std.albedo_color
		if std.emission_enabled:
			name = "glow_%s_e%d" % [std.emission.to_html(false), int(round(std.emission_energy_multiplier * 10.0))]
		elif std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			name = "glass_%s" % c.to_html(true)
		else:
			name = "paint_%s_%d_%d" % [c.to_html(false), int(round(std.metallic * 100.0)), int(round(std.roughness * 100.0))]
	_mat_names[id] = name
	_mat_table[name] = _record_of(m, name)
	return name


func _record_of(m: Material, _name: String) -> Dictionary:
	var std := m as StandardMaterial3D
	if std == null:
		return {"paint": [1.0, 0.0, 1.0]}
	if std.emission_enabled:
		var e := std.emission
		return {"glow": [e.r, e.g, e.b], "energy": std.emission_energy_multiplier}
	var c := std.albedo_color
	if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return {"glass": "clear", "color": [c.r, c.g, c.b, c.a], "metallic": std.metallic, "roughness": std.roughness}
	return {"paint": [c.r, c.g, c.b], "metallic": std.metallic, "roughness": std.roughness}


func _write() -> Dictionary:
	var rec := kit.recorder
	var mat_name := Callable(self, "name_of")
	var id := design_id(seed_value, size_class, family)
	var file := {
		"format": "vsship",
		"version": [2, 0],
		"generator": {"app": "bsx-ship-generator", "version": "1", "date": Time.get_date_string_from_system()},
		"ship": {"id": id, "name": ship_name(seed_value, family), "class": size_class,
				"base": {"design": id, "app_version": "bsx", "seed": seed_value, "family": family},
				"livery": "company", "serial": "VS-BX%s-%06d" % [family.substr(0, 3).to_upper(), absi(seed_value) % 1000000],
				"owner": ""},
		"stats": {"length_m": length, "half_width_m": half_width, "roof_m": roof, "bays": bay_count},
	}
	file["frame"] = [_frame_hull(hull, mat_name)]
	file["decks"] = [ShipRecorder.encode(deck.recipe(), mat_name)]
	var wall_list: Array = []
	for w: StudWall in walls:
		wall_list.append({"stud": ShipRecorder.encode(w.recipe(), mat_name), "group": "inner"})
	wall_list.append_array(ShipRecorder.encode(rec.walls, mat_name))
	file["walls"] = wall_list
	file["services"] = {"looms": [], "leads": [], "pipes": []}
	var fittings: Array = ShipRecorder.encode(rec.fittings, mat_name)
	for f: Dictionary in fittings:
		if tacks.has(f.get("path", "")):
			f["mount"] = tacks[f["path"]]
	file["fittings"] = fittings
	file["systems"] = ShipRecorder.encode(rec.systems, mat_name)
	var pieces: Array = ShipRecorder.encode(rec.pieces, mat_name)
	for p: Dictionary in pieces:
		if p.has("unit"):
			p["unit"] = rec.units[int(p["unit"])]["path"]
	file["pieces"] = pieces
	file["units"] = ShipRecorder.encode(rec.units)
	file["lights"] = ShipRecorder.encode(rec.lights, mat_name)
	file["slots"] = []
	file["layout"] = _layout()
	file["modules"] = {}
	# The derived parts and joints.
	var ids: Array = kit.model.parts.keys()
	ids.sort()
	var parts: Array = []
	var path_of := {}
	var mass := 0.0
	for pid: int in ids:
		var p: PartData = kit.model.parts[pid]
		path_of[pid] = p.path
		mass += p.mass
		var info: Dictionary = rec.parts.get(pid, {})
		var by: String = info.get("by", "")
		if by == "":
			by = "unit" if p.path.begins_with("fitting:") or p.path.begins_with("system:") else "piece"
		var e := {"id": pid, "path": p.path, "name": p.part_name, "kind": PartData.Kind.keys()[p.kind].to_lower(),
				"material": p.material, "mass": snappedf(p.mass, 0.01), "group": kit.groups.get(pid, ""), "by": by,
				"shape": info.get("shape", {}), "mat": mat_name.call(info["mat"]) if info.get("mat") is Material else "",
				"xform": ShipRecorder.encode(p.local_transform), "box": ShipRecorder.encode(_box_of(p))}
		if info.get("glass_mat") is Material:
			e["glass_mat"] = mat_name.call(info["glass_mat"])
		if p.power != PartData.Power.NONE:
			e["power"] = PartData.Power.keys()[p.power].to_lower()
		parts.append(e)
	file["parts"] = parts
	var joints: Array = []
	var by_phase := {}
	var by_kind := {}
	for c: ConnectionData in kit.model.connections:
		var kind: String = ConnectionData.Kind.keys()[c.kind].to_lower()
		var j := {"id": c.id, "path": c.path, "kind": kind, "head": c.head, "phase": c.phase,
				"a": path_of.get(c.part_a, ""), "b": path_of.get(c.part_b, ""),
				"at": ShipRecorder.encode(c.local_position), "normal": ShipRecorder.encode(c.local_normal)}
		if c.seam_size != Vector2.ZERO:
			j["seam_up"] = ShipRecorder.encode(c.seam_up)
			j["seam_size"] = ShipRecorder.encode(c.seam_size)
		joints.append(j)
		by_phase[c.phase] = int(by_phase.get(c.phase, 0)) + 1
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
	file["joints"] = joints
	file["stats"]["mass_kg"] = snappedf(mass, 1.0)
	file["materials"] = _mat_table
	file["derived"] = {"volume_m3": snappedf(rec.volume, 0.0001), "meshes": rec.mesh_count, "shapes": rec.shape_count,
			"lights": rec.light_count, "pieces": rec.pieces.size(), "fittings": rec.fittings.size(),
			"systems": rec.systems.size(), "recipe_less": rec.recipe_less,
			"hold_m3": snappedf(hold.size.x * hold.size.y * hold.size.z, 0.0001),
			"bounds": ShipRecorder.encode(rec.bounds), "parts": parts.size(), "joints": joints.size(),
			"joints_by_phase": by_phase, "joints_by_kind": by_kind, "routes": {}, "body_hash": "", "parts_hash": ""}
	file["derived"]["body_hash"] = ShipRecorder.body_hash(file)
	file["derived"]["parts_hash"] = ShipRecorder.parts_hash(file)
	var ordered := {}
	for key in ["format", "version", "generator", "ship", "stats", "materials", "frame", "decks", "walls", "services",
			"fittings", "systems", "pieces", "units", "lights", "slots", "layout", "modules", "parts", "joints", "derived"]:
		ordered[key] = file[key]
	return ordered


func _layout() -> Dictionary:
	var seat_list: Array = []
	for s: Vector3 in seats:
		seat_list.append({"at": s})
	var layout := {"rooms": rooms, "room_names": room_names, "hold": hold, "salvage_bay": null, "cargo_bay": null,
			"cabin_door": "", "hatch_area": hatch if hatch.has_area() else null, "intakes": [], "seats": seat_list,
			"exit_point": exit_point, "lift_rect": null, "doors": {}, "usable_tags": {}, "stern_door": stern_door if stern_door.has_area() else null}
	return ShipRecorder.encode(layout)


## A hull's recipe as the file writes it (as Void Salvage's ShipExport does): stations with
## repeated profiles as "same", the faces' looks as the shortest table.
func _frame_hull(h: FrameHull, mat_name: Callable) -> Dictionary:
	var r := h.recipe()
	var faces: Array = r["faces"]
	r.erase("faces")
	var out: Dictionary = ShipRecorder.encode(r, mat_name)
	var last: Variant = null
	for st: Dictionary in out["stations"]:
		var p: Variant = st["profile"]
		if last != null and p == last:
			st["profile"] = "same"
		last = p
	var skin: String = mat_name.call(h.skin_mat) if h.skin_mat else ""
	var looks := {}
	var edges := 0
	for f: Array in faces:
		looks["%d:%d" % [f[0], f[1]]] = _face_look(f[2], skin, mat_name)
		edges = maxi(edges, int(f[1]) + 1)
	var table := {}
	var common: Variant = _most_common(looks.values())
	table["default"] = common
	var by_edge := {}
	for e in edges:
		var these: Array = []
		for key: String in looks:
			if key.get_slice(":", 1) == str(e):
				these.append(looks[key])
		var look: Variant = _most_common(these)
		by_edge[e] = look
		if ShipRecorder.canonical(look) != ShipRecorder.canonical(common):
			table[str(e)] = look
	for key: String in looks:
		if ShipRecorder.canonical(looks[key]) != ShipRecorder.canonical(by_edge[int(key.get_slice(":", 1))]):
			table[key] = looks[key]
	out["faces"] = table
	return out


static func _face_look(look: Dictionary, skin: String, mat_name: Callable) -> Variant:
	if look.get("skip", false):
		return "skip"
	var out := {"mat": mat_name.call(look["mat"]) if look.get("mat") is Material else skin}
	if look.get("glass", false):
		out["glass"] = true
	if look.get("tag", "") != "":
		out["tag"] = look["tag"]
	if look.get("name", "") != "":
		out["name"] = look["name"]
	return out


static func _most_common(values: Array) -> Variant:
	var counts := {}
	var first := {}
	for v: Variant in values:
		var key := ShipRecorder.canonical(v)
		counts[key] = int(counts.get(key, 0)) + 1
		if not first.has(key):
			first[key] = v
	var best := ""
	for key: String in counts:
		if best == "" or counts[key] > counts[best]:
			best = key
	return first.get(best, {})
