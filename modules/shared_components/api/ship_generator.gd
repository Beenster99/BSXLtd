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
## No two are the same tube: the seed rolls a hull form (`FORMS` per family: the cross-section
## (`SECTIONS`: octagon, slab, blade, boxy, round), the waist (straight, bulged, tapered,
## flared), where the nose shrinks to and so where the cockpit sits (`NOSE_ANCHORS`: middle,
## chin, high)) and what the ship carries: wings (their own "wing"-style FrameHulls, ribs
## bolted to the body's rings), engine nacelles (on pylons by the stern or at the wing tips,
## the engines on them), an exoskeleton of trusses and gantries round the holds, turrets, a
## radar dish, a crane, a cargo ramp over the stern door, vents and a heat sink. Every piece
## is a part bolted or welded on, so the file (`ship.base.form` says what rolled; `frame`
## lists every hull) and its wrecks carry them like the rest.
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
const NOSE_SCALE_Y: float = 0.45   # the nose shrinks about this share of the roof height (the middle nose)
## Cross-sections: factors on the class's width and height and on the roof's and belly's flats.
const SECTIONS := {
	"octagon": {"width": 1.0, "height": 1.0, "flats": 1.0},
	"slab": {"width": 1.3, "height": 0.78, "flats": 1.08},
	"blade": {"width": 0.78, "height": 1.3, "flats": 0.9},
	"boxy": {"width": 1.05, "height": 1.0, "flats": 1.2},
	"round": {"width": 1.0, "height": 1.05, "flats": 0.62},
}
const TOUCH := 0.03   # a part this close to a support is touching it, m
## Where the nose shrinks toward, as a share of the roof height: the cockpit sits there.
const NOSE_ANCHORS := {"middle": 0.45, "chin": 0.2, "high": 0.72}
## The hull forms each family rolls from: cross-sections and waists (one picked at random
## from the list), the nose anchors, and the chance of wings, engine nacelles, an exoskeleton
## frame, turrets, a radar dish, a crane, a cargo ramp (with a stern door) and vents.
const FORMS := {
	"courier": {"section": ["octagon", "blade", "blade", "round"], "waist": ["straight", "straight", "tapered"],
			"nose": ["middle", "high", "chin"], "wings": 0.75, "nacelles": 0.5, "exo": 0.0, "turrets": 0.2, "dish": 0.45,
			"crane": 0.0, "ramp": 0.0, "vents": 0.5},
	"freighter": {"section": ["octagon", "slab", "boxy", "boxy"], "waist": ["straight", "bulged", "bulged", "flared"],
			"nose": ["middle", "high"], "wings": 0.25, "nacelles": 0.45, "exo": 0.25, "turrets": 0.25, "dish": 0.4,
			"crane": 0.6, "ramp": 0.7, "vents": 0.6},
	"miner": {"section": ["slab", "slab", "boxy", "octagon"], "waist": ["straight", "bulged", "flared"],
			"nose": ["middle", "chin", "chin"], "wings": 0.2, "nacelles": 0.4, "exo": 0.6, "turrets": 0.15, "dish": 0.5,
			"crane": 0.5, "ramp": 0.0, "vents": 0.7},
	"tanker": {"section": ["round", "round", "octagon"], "waist": ["straight", "bulged", "bulged"],
			"nose": ["middle", "high"], "wings": 0.2, "nacelles": 0.5, "exo": 0.35, "turrets": 0.15, "dish": 0.35,
			"crane": 0.2, "ramp": 0.0, "vents": 0.7},
	"tug": {"section": ["boxy", "boxy", "octagon", "slab"], "waist": ["straight", "flared", "flared"],
			"nose": ["middle", "chin", "high"], "wings": 0.3, "nacelles": 0.55, "exo": 0.6, "turrets": 0.3, "dish": 0.5,
			"crane": 0.6, "ramp": 0.5, "vents": 0.6},
	"liner": {"section": ["octagon", "round", "blade", "slab"], "waist": ["straight", "straight", "tapered", "bulged"],
			"nose": ["middle", "high", "high"], "wings": 0.6, "nacelles": 0.55, "exo": 0.0, "turrets": 0.1, "dish": 0.5,
			"crane": 0.0, "ramp": 0.0, "vents": 0.4},
}

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
var station_scale: Array[Vector2] = []   # per station, the cross-section's width and height scales
var form: Dictionary = {}                # the rolled hull form (FORMS)
var nose_anchor: float = NOSE_SCALE_Y
var limbs: Array[FrameHull] = []         # wings and nacelles, in build order
var wing: Dictionary = {}                # the wings' planform (see _build_wings), {} without
var nacelle: Dictionary = {}             # the nacelles' placing (see _build_nacelles), {} without
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
## The surfaces things are fixed to: [{part, box}] (`_collect_supports`).
var _supports: Array = []


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
	_roll_form()
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
	_build_limbs()
	_build_deck()
	_line_hull()
	_build_exo()
	_build_walls()
	_collect_supports()
	_build_fittings()
	_dress()
	_lights()
	ShipParts.livery = livery_was
	var file := _write()
	body.free()
	return file


func _range(lo_hi: Array, factor: float = 1.0) -> float:
	return rng.randf_range(float(lo_hi[0]), float(lo_hi[1])) * factor


## Rolls the hull form from the family's table: the cross-section, the waist, the nose anchor
## and which limbs and gear the ship carries.
func _roll_form() -> void:
	var t: Dictionary = FORMS[family]
	form = {}
	for key in ["section", "waist", "nose"]:
		var options: Array = t[key]
		form[key] = options[rng.randi() % options.size()]
	for key in ["wings", "nacelles", "exo", "turrets", "dish", "crane", "ramp", "vents"]:
		form[key] = rng.randf() < float(t[key])
	# Small ships carry at most one of wings and nacelles; an exoskeleton needs holds to stand on.
	if size_class == "S" and form["wings"] and form["nacelles"]:
		form["nacelles"] = false
	nose_anchor = NOSE_ANCHORS[form["nose"]]


func _roll_dimensions() -> void:
	var sizes: Dictionary = SIZES[size_class]
	var section: Dictionary = SECTIONS[form["section"]]
	length = snappedf(_range(sizes["length"], shape["length"]), 0.1)
	half_width = snappedf(_range(sizes["width"], shape["width"] * float(section["width"])), 0.05)
	roof = snappedf(_range(sizes["height"], shape["height"] * float(section["height"])), 0.05)
	var flats: float = section["flats"]
	roof_x = snappedf(half_width * float(shape["roof_x"]) * flats * rng.randf_range(0.9, 1.1), 0.05)
	bottom_x = snappedf(half_width * float(shape["bottom_x"]) * flats * rng.randf_range(0.9, 1.1), 0.05)
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
	_roll_waist()
	var shaped := false
	for sc: Vector2 in station_scale:
		shaped = shaped or sc != Vector2.ONE
	if not shaped:
		form["waist"] = "straight"
	# The belly hatch in the middle hold bay, the stern door in the stern cap.
	if shape["hatch"]:
		var holds := _hold_bays()
		var bay: int = holds[(holds.size() - 1) / 2]
		var hw := minf(1.1, half_width * 0.4)
		var len := minf(2.6, bay_length - 0.9)
		var mid := _bay_z(bay) + bay_length * 0.5
		hatch = Rect2(-hw, mid - len * 0.5, hw * 2.0, len)
	if shape["stern_door"]:
		var stern := profile_at(stations.size() - 1)
		var hw := minf(1.8, stern[4].x * 0.8)
		stern_door = Rect2(-hw, 0.05, hw * 2.0, minf(stern[0].y - 0.6, 2.6))


## The waist: every station's cross-section scale. "bulged" swells the holds' inner stations
## (width and height), "tapered" narrows the engine bay toward the stern, "flared" widens it.
func _roll_waist() -> void:
	station_scale.clear()
	for i in stations.size():
		station_scale.append(Vector2.ONE)
	var last := stations.size() - 1
	match form["waist"]:
		"bulged":
			var inner: Array = []
			for i in range(4, bay_count):
				inner.append(i)
			if inner.size() >= 2:
				var b := snappedf(rng.randf_range(0.08, 0.16), 0.01)
				for k in inner.size():
					var i: int = inner[k]
					var edge := k == 0 or k == inner.size() - 1
					var f := b * (0.5 if edge else 1.0)
					station_scale[i] = Vector2(1.0 + f, 1.0 + f * 0.6)
		"tapered":
			var t := snappedf(rng.randf_range(0.78, 0.9), 0.01)
			station_scale[last] = Vector2(t, 1.0)
			station_scale[last - 1] = Vector2(1.0 - (1.0 - t) * 0.3, 1.0)
		"flared":
			var f := snappedf(rng.randf_range(1.1, 1.2), 0.01)
			station_scale[last] = Vector2(f, 1.0 + (f - 1.0) * 0.5)


## The cross-section at station `i`: the nose's shrunk, the rest at the waist's scale.
func profile_at(i: int) -> PackedVector2Array:
	var p := profile(float(shape["nose"]) if i == 0 else 1.0)
	var sc: Vector2 = station_scale[i] if i < station_scale.size() else Vector2.ONE
	if sc == Vector2.ONE:
		return p
	var yc := roof * nose_anchor
	for k in p.size():
		p[k] = Vector2(p[k].x * sc.x, yc + (p[k].y - yc) * sc.y)
	return p


## The hull's half width at `z`, between its stations.
func _width_at(z: float) -> float:
	for i in stations.size() - 1:
		var z0 := _station_z(i)
		var z1 := _station_z(i + 1)
		if z <= z1 or i == stations.size() - 2:
			var a := profile_at(i)[2].x
			var b := profile_at(i + 1)[2].x
			return lerpf(a, b, clampf((z - z0) / maxf(z1 - z0, 0.001), 0.0, 1.0))
	return half_width


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
	var yc := roof * nose_anchor
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
	mats["fit"] = ShipParts.mat("steel")   # library components carry their own colours (named "steel")


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
		h.add_station(_station_z(i), profile_at(i), stations[i][1])
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
			var hole := AABB(Vector3(side * _width_at(z) - 0.2, win_y - 0.3, z - 0.45), Vector3(0.4, 0.6, 0.9))
			var hole_name := "window_%s_%d" % ["r" if side > 0.0 else "l", bay]
			h.opening(2 if side > 0.0 else 6, hole, hole_name, AABB(), reveal)
	var door_z := _bay_z(2) + 0.4
	var door := AABB(Vector3(-half_width - 0.2, 0.0, door_z), Vector3(0.4, 2.05, 1.0))
	h.opening(6, door, "side_door", AABB(), reveal)
	if hatch.has_area():
		var belly_lo := BELLY
		for i in stations.size():
			belly_lo = minf(belly_lo, profile_at(i)[4].y)
		var hole := AABB(Vector3(hatch.position.x, belly_lo - 0.2, hatch.position.y), Vector3(hatch.size.x, 0.4 + BELLY - belly_lo, hatch.size.y))
		h.opening(4, hole, "hatch")
	h.build()
	# The windows' glass in the holes: a pane part bolted to its jambs.
	kit.phase = "skin"
	for bay: int in window_bays:
		var z := _bay_z(bay) + bay_length * 0.5
		for side: float in [-1.0, 1.0]:
			var hole_name := "window_%s_%d" % ["r" if side > 0.0 else "l", bay]
			var pane := PartShapes.window_panel(0.6, 0.9, "chamfer", 0.16, 0.78)
			var x := side * (_width_at(z) - 0.04)
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
		var outline := profile_at(stations.size() - 1)
		var far := half_width * 2.0 + 1.0
		for r: Rect2 in [Rect2(-far, BELLY - 2.0, far + stern_door.position.x, roof * 2.0 + 2.0),
				Rect2(stern_door.end.x, BELLY - 2.0, far, roof * 2.0 + 2.0),
				Rect2(stern_door.position.x, stern_door.end.y, stern_door.size.x, roof * 2.0 + 1.0),
				Rect2(stern_door.position.x, BELLY - 2.0, stern_door.size.x, 2.0 + stern_door.position.y)]:
			var piece := _clip(outline, r)
			if piece.size() >= 3:
				pieces.append(piece)
		h.cap(1, pieces, mat("hull_dark"))
	else:
		h.cap(1, [profile_at(stations.size() - 1)], mat("hull_dark"))


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


## Wings and engine nacelles, each its own frame hull on the body.
func _build_limbs() -> void:
	kit.group = "hull"
	wing = {}
	if form["wings"]:
		_build_wings()
	if form["nacelles"]:
		_build_nacelles()


## The body's side face (x = W) runs from the chine up to the shoulder: where a wing root or a
## pylon can land at `z`. [chine y, shoulder y].
func _side_span_at(z: float) -> Array:
	for i in stations.size() - 1:
		if z <= _station_z(i + 1) or i == stations.size() - 2:
			var a := profile_at(i)
			var b := profile_at(i + 1)
			var t := clampf((z - _station_z(i)) / maxf(_station_z(i + 1) - _station_z(i), 0.001), 0.0, 1.0)
			return [lerpf(a[3].y, b[3].y, t), lerpf(a[2].y, b[2].y, t)]
	return [BELLY + chine_rise, roof - (half_width - roof_x)]


## True when every body station from `z0` to `z1` has the plain cross-section (a limb's root
## needs a straight run of skin).
func _straight_between(z0: float, z1: float) -> bool:
	for i in stations.size():
		var z := _station_z(i)
		if z >= z0 - 0.01 and z <= z1 + 0.01 and station_scale[i] != Vector2.ONE:
			return false
	return true


## A pair of wings on the "wing" style (ribs and spars): a trapezoid planform rolled from the
## seed (span, sweep, tip chord, dihedral), rooted on the body's side face along one or two
## bays, the ribs bolted through the skin to the body's rings. `wing` keeps the planform for
## the nacelles and the gear.
func _build_wings() -> void:
	var holds := _hold_bays()
	var candidates: Array = holds.duplicate()
	candidates.append(bay_count)
	var wb: int = candidates[rng.randi() % candidates.size()]
	var span_f: float = {"S": rng.randf_range(0.9, 1.5), "M": rng.randf_range(1.0, 1.8), "L": rng.randf_range(1.0, 2.0)}[size_class]
	var span := snappedf(clampf(half_width * span_f, 1.2, 6.5), 0.05)
	var z0 := _bay_z(wb)
	var stern_z := _station_z(stations.size() - 1)
	var root_chord := snappedf(clampf(bay_length * rng.randf_range(1.0, 2.0), 1.5, minf(length * 0.3, 8.0)), 0.05)
	var z1 := minf(z0 + root_chord, stern_z - 0.2)
	if z1 - z0 < 1.4 or not _straight_between(z0, z1):
		form["wings"] = false
		return
	var sweep := snappedf(span * rng.randf_range(0.25, 0.7), 0.05)
	var tip_chord := snappedf((z1 - z0) * rng.randf_range(0.4, 0.75), 0.05)
	sweep = minf(sweep, z1 - z0 - 0.6)
	tip_chord = clampf(tip_chord, 0.5, z1 - z0 - sweep - 0.2)
	var zt0 := z0 + sweep
	var zt1 := zt0 + tip_chord
	var span_at := _side_span_at((z0 + z1) * 0.5)
	var chine: float = span_at[0]
	var shoulder: float = span_at[1]
	var t_root := snappedf(clampf(roof * 0.1, 0.22, minf(0.5, (shoulder - chine) - 0.3)), 0.01)
	var t_tip := snappedf(maxf(0.1, t_root * 0.4), 0.01)
	var wing_y := snappedf(chine + (shoulder - chine) * rng.randf_range(0.35, 0.65), 0.01)
	wing_y = clampf(wing_y, chine + t_root * 0.5 + 0.1, shoulder - t_root * 0.5 - 0.1)
	var dihedral := snappedf(span * rng.randf_range(-0.12, 0.15), 0.01)
	var root_x := _width_at((z0 + z1) * 0.5)
	wing = {"z0": z0, "z1": z1, "zt0": zt0, "zt1": zt1, "span": span, "root_x": root_x, "y": wing_y,
			"dihedral": dihedral, "t_root": t_root, "t_tip": t_tip}
	# The stations: the planform's four corners and the body's rings between them.
	var zs: Array[float] = [z0, zt0, zt1, z1]
	for i in stations.size():
		var z := _station_z(i)
		if z > z0 + 0.3 and z < z1 - 0.3:
			var near := false
			for q: float in zs:
				near = near or absf(q - z) < 0.25
			if not near:
				zs.append(z)
	zs.sort()
	for side: float in [-1.0, 1.0]:
		var key := "wing_%s" % ("l" if side < 0.0 else "r")
		var w := FrameHull.new(kit, "wing", mat("shell"), mat("frame_steel"))
		w.name = key
		w.groove = 0.0
		for k in zs.size():
			w.add_station(zs[k], _wing_outline(side, zs[k]), "w%d" % k)
		var tip_e := 1 if side > 0.0 else 3
		var shell := mat("shell")
		var trim := mat("trim")
		var dark := mat("hull_dark")
		w.style = func(seg: int, edge: int) -> Dictionary:
			if edge == 0:
				return {"mat": trim if zs[seg + 1] <= zt0 + 0.01 else shell}
			if edge == tip_e:
				return {"mat": dark}
			if edge == 2:
				return {"mat": dark}
			return {"skip": true}
		w.build()
		w.cap(0, [w.stations[0]["profile"]], trim)
		w.cap(1, [w.stations[w.stations.size() - 1]["profile"]], dark)
		_root_bolts(w, side, root_x, 2 if side > 0.0 else 6)
		limbs.append(w)


## The wing's extent out from its root at `z`: a stub at the leading and trailing ends, the
## full span along the tip chord.
func _wing_reach(z: float) -> float:
	var stub := 0.12
	var z0: float = wing["z0"]
	var z1: float = wing["z1"]
	var zt0: float = wing["zt0"]
	var zt1: float = wing["zt1"]
	var f := 1.0
	if z < zt0:
		f = lerpf(stub, 1.0, (z - z0) / maxf(zt0 - z0, 0.001))
	elif z > zt1:
		f = lerpf(1.0, stub, (z - zt1) / maxf(z1 - zt1, 0.001))
	return float(wing["span"]) * clampf(f, stub, 1.0)


## A wing's cross-section at `z` (x, y): a thin slab from the body's skin out to the tip,
## thinning and rising (or drooping) toward it. Right: edges 0 top, 1 tip, 2 bottom, 3 root;
## left: 0 top, 1 root, 2 bottom, 3 tip.
func _wing_outline(side: float, z: float) -> PackedVector2Array:
	var root: float = wing["root_x"]
	var reach := _wing_reach(z)
	var u := reach / float(wing["span"])
	var y: float = wing["y"]
	var y_tip := y + float(wing["dihedral"]) * u
	var t_root: float = wing["t_root"]
	var t_tip := lerpf(t_root, float(wing["t_tip"]), u)
	var tip := root + reach
	if side > 0.0:
		return PackedVector2Array([Vector2(root, y + t_root * 0.5), Vector2(tip, y_tip + t_tip * 0.5),
				Vector2(tip, y_tip - t_tip * 0.5), Vector2(root, y - t_root * 0.5)])
	return PackedVector2Array([Vector2(-tip, y_tip + t_tip * 0.5), Vector2(-root, y + t_root * 0.5),
			Vector2(-root, y - t_root * 0.5), Vector2(-tip, y_tip - t_tip * 0.5)])


## Bolts a limb's ribs through the body's skin to the body ring standing at the same z on
## edge `e` of the body's section, twice up the root.
func _root_bolts(w: FrameHull, side: float, root_x: float, e: int) -> void:
	for i in w.stations.size():
		var rib: PartData = w.ribs[i] if i < w.ribs.size() else null
		if rib == null:
			continue
		var z := w.ring_z(i)
		for j in hull.stations.size():
			var ring: PartData = hull.rings[j][e]
			if ring == null or absf(hull.ring_z(j) - z) > 0.25:
				continue
			var p := w.stations[i]["profile"] as PackedVector2Array
			var lo := p[3].y if side > 0.0 else p[2].y
			var hi := p[0].y if side > 0.0 else p[1].y
			var k := 0
			for y: float in [lerpf(lo, hi, 0.2), lerpf(lo, hi, 0.75)]:
				var c := kit.join(rib, ring, ConnectionData.Kind.BOLT, Vector3(side * (root_x + FrameHull.GAP), y, z),
						Vector3(-side, 0, 0), Vector3.ZERO, Vector2.ZERO, "%s/bolt:%s/%d" % [rib.path, ring.path, k])
				if c:
					c.phase = "frame"
				k += 1


## An eight-sided section `r` across its flats round (cx, cy), the body's edge order.
static func _octagon(cx: float, cy: float, r: float, s: float = 1.0) -> PackedVector2Array:
	var a := 0.42 * r * s
	var b := r * s
	return PackedVector2Array([Vector2(cx - a, cy + b), Vector2(cx + a, cy + b), Vector2(cx + b, cy + a), Vector2(cx + b, cy - a),
			Vector2(cx + a, cy - b), Vector2(cx - a, cy - b), Vector2(cx - b, cy - a), Vector2(cx - b, cy + a)])


## A pair of engine nacelles: eight-sided hulls with a tapered nose, alongside the stern on
## two pylons each (girders bolted to a body ring and a nacelle ring), or hung at the wing
## tips, bolted to the tip ribs. The engines go on their stern caps (`_dress_outside`).
func _build_nacelles() -> void:
	var r := snappedf(clampf(roof * rng.randf_range(0.16, 0.24), 0.35, 1.1), 0.01)
	var stern_z := _station_z(stations.size() - 1)
	var on_wings: bool = form["wings"] and not wing.is_empty()
	var z0: float
	var z1: float
	var cx: float
	var cy: float
	var gap := 0.0
	if on_wings:
		var len := snappedf(clampf(bay_length * rng.randf_range(1.5, 2.5), 2.5, 8.0), 0.05)
		z1 = minf(float(wing["zt1"]) + 0.5 + r, stern_z + 1.0)
		z0 = z1 - len
		cx = float(wing["root_x"]) + float(wing["span"]) + FrameHull.GAP + r
		cy = float(wing["y"]) + float(wing["dihedral"])
	else:
		var holds := _hold_bays()
		var first: int = holds[maxi(0, holds.size() - 2)]
		var nb := rng.randi_range(first, bay_count)
		z0 = _bay_z(nb)
		z1 = stern_z + snappedf(rng.randf_range(0.0, 0.8), 0.05)
		if not _straight_between(z0, stern_z) and form["waist"] == "bulged":
			z0 = _bay_z(bay_count)
		gap = snappedf(rng.randf_range(0.25, 0.45) if size_class == "S" else rng.randf_range(0.3, 0.7), 0.05)
		var side_span := _side_span_at((z0 + stern_z) * 0.5)
		var chine: float = side_span[0]
		var shoulder: float = side_span[1]
		cy = snappedf(chine + (shoulder - chine) * rng.randf_range(0.35, 0.7), 0.01)
		var wide := 0.0
		for i in stations.size():
			if _station_z(i) >= z0 - 0.01:
				wide = maxf(wide, profile_at(i)[2].x)
		cx = wide + gap + r
	nacelle = {"z0": z0, "z1": z1, "cx": cx, "cy": cy, "r": r, "on_wings": on_wings}
	# Stations: both ends (the nose tapered), the body's rings in range (for the pylons), and
	# the wing's tip chord ends (to bolt to the tip ribs).
	var zs: Array[float] = [z0, z0 + minf(1.2, (z1 - z0) * 0.3), z1]
	if on_wings:
		for q: float in [float(wing["zt0"]), float(wing["zt1"])]:
			if q > z0 + 0.3 and q < z1 - 0.3:
				zs.append(q)
	else:
		for i in stations.size():
			var z := _station_z(i)
			if z > z0 + 0.3 and z < z1 - 0.3:
				zs.append(z)
	var clean: Array[float] = []
	zs.sort()
	for z: float in zs:
		if clean.is_empty() or z - clean[clean.size() - 1] > 0.3:
			clean.append(z)
	for side: float in [-1.0, 1.0]:
		var key := "nacelle_%s" % ("l" if side < 0.0 else "r")
		var n := FrameHull.new(kit, "kestrel", mat("shell"), mat("frame_steel"))
		n.name = key
		n.groove = 0.0
		n.ring_width = 0.1
		n.depth = 0.12
		n.node_size = 0.18
		n.stringer_size = 0.1
		n.stringer_depth = 0.12
		n.skin = 0.05
		for k in clean.size():
			var sc := 0.6 if k == 0 else 1.0
			n.add_station(clean[k], _octagon(side * cx, cy, r, sc), "n%d" % k)
		var shell := mat("shell")
		var trim := mat("trim")
		var dark := mat("hull_dark")
		n.style = func(_seg: int, edge: int) -> Dictionary:
			if edge == 0:
				return {"mat": trim}
			if edge in [3, 4, 5]:
				return {"mat": dark}
			return {"mat": shell}
		n.build()
		n.cap(0, [n.stations[0]["profile"]], dark)
		n.cap(1, [n.stations[n.stations.size() - 1]["profile"]], dark)
		var inboard := 6 if side > 0.0 else 2
		if on_wings:
			var w: FrameHull = limbs[0 if side < 0.0 else 1]
			for i in n.stations.size():
				var ring: PartData = n.rings[i][inboard]
				if ring == null:
					continue
				var z := n.ring_z(i)
				for j in w.stations.size():
					var rib: PartData = w.ribs[j]
					if rib == null or absf(w.ring_z(j) - z) > 0.25 or absf(_wing_reach(w.stations[j]["z"]) - float(wing["span"])) > 0.01:
						continue
					var c := kit.join(ring, rib, ConnectionData.Kind.BOLT, Vector3(side * (cx - r - FrameHull.GAP * 0.5), cy, z),
							Vector3(side, 0, 0), Vector3.ZERO, Vector2.ZERO, "%s/bolt:%s" % [ring.path, rib.path])
					if c:
						c.phase = "frame"
		else:
			_pylons(n, side, inboard, cx - r, cy)
		limbs.append(n)


## Two pylons from the body's side to a nacelle's inboard face at the nacelle's rings that
## stand by a body ring: girders along x, bolted to both rings.
func _pylons(n: FrameHull, side: float, inboard: int, inner_x: float, cy: float) -> void:
	var made := 0
	var h := minf(0.5, float(nacelle["r"]) * 0.8)
	var e := 2 if side > 0.0 else 6
	var order: Array[int] = []
	for i in range(n.stations.size() - 1, -1, -1):
		order.append(i)
	for i: int in order:
		if made >= 2:
			break
		var ring: PartData = n.rings[i][inboard]
		if ring == null:
			continue
		var z := n.ring_z(i)
		var body_ring: PartData = null
		for j in hull.stations.size():
			if hull.rings[j][e] != null and absf(hull.ring_z(j) - z) < 0.25:
				body_ring = hull.rings[j][e]
				z = hull.ring_z(j)
		if body_ring == null:
			continue
		var side_span := _side_span_at(z)
		if cy < float(side_span[0]) + h * 0.5 or cy > float(side_span[1]) - h * 0.5:
			continue
		var a := Vector3(side * (_width_at(z) + FrameHull.GAP), cy, z)
		var b := Vector3(side * (inner_x - FrameHull.GAP), cy, z)
		var len := a.distance_to(b)
		if len < 0.1:
			continue
		var shape := PartShapes.girder(len, 0.14, h)
		var pylon := kit.part("Pylon", PartData.Kind.FRAME, shape, FrameParts.along(a, b), mat("frame_steel"), "", 0.6, null,
				"%s/pylon/%d" % [n.name, made])
		kit.join(pylon, body_ring, ConnectionData.Kind.BOLT, a, Vector3(-side, 0, 0), Vector3.ZERO, Vector2.ZERO, "%s/bolt:body" % pylon.path)
		kit.join(pylon, ring, ConnectionData.Kind.BOLT, b, Vector3(side, 0, 0), Vector3.ZERO, Vector2.ZERO, "%s/bolt:nacelle" % pylon.path)
		made += 1


## An exoskeleton frame round the holds: a lattice truss along each roof corner and each
## belly corner, one per bay, standing off the skin and bolted through it to the ring girder
## at each end; over each bay a gantry (two posts up from the roof trusses and a beam across,
## high enough to clear the roof gear) and a beam under the belly trusses (not under the hatch).
func _build_exo() -> void:
	var holds := _hold_bays()
	if not form["exo"] or holds.is_empty():
		form["exo"] = false
		return
	kit.group = "exo"
	kit.phase = "frame"
	var s := snappedf(clampf(roof * 0.08, 0.18, 0.3), 0.01)
	var off := s * 0.75 + 0.05
	var steel := mat("frame_steel")
	# Corner k of the profile, its outward bisector, and the ring edge it bolts to.
	var corners: Array = [[1, 1, "roof_r"], [0, 7, "roof_l"], [4, 3, "belly_r"], [5, 5, "belly_l"]]
	var truss_tops := {}   # bay -> [right top y, left top y] of the roof trusses (for the gantries)
	for bay: int in holds:
		var label := _bay_label(bay)
		var pa := profile_at(bay)
		var pb := profile_at(bay + 1)
		var za := hull.ring_z(bay)
		var zb := hull.ring_z(bay + 1)
		for c: Array in corners:
			var k: int = c[0]
			var e: int = c[1]
			var who: String = c[2]
			var ba := _bisector(pa, k)
			var bb := _bisector(pb, k)
			var a := Vector3(pa[k].x + ba.x * off, pa[k].y + ba.y * off, za + 0.06)
			var b := Vector3(pb[k].x + bb.x * off, pb[k].y + bb.y * off, zb - 0.06)
			var len := a.distance_to(b)
			if len < 0.6:
				continue
			var up := Vector3((ba.x + bb.x) * 0.5, (ba.y + bb.y) * 0.5, 0.0).normalized()
			var shape := PartShapes.truss(len, s, s, maxi(2, int(round(len / 0.6))))
			var truss := kit.part("ExoTruss", PartData.Kind.FRAME, shape, FrameParts.along(a, b, up), steel, "", 0.3, null,
					"exo/%s/bay:%s" % [who, label])
			for end: Array in [[bay, Vector3(pa[k].x, pa[k].y, za), "fore"], [bay + 1, Vector3(pb[k].x, pb[k].y, zb), "aft"]]:
				var ring: PartData = hull.rings[end[0]][e]
				if ring:
					kit.join(truss, ring, ConnectionData.Kind.BOLT, end[1], Vector3(up.x, up.y, 0.0), Vector3.ZERO, Vector2.ZERO,
							"%s/bolt:%s" % [truss.path, end[2]])
			if who.begins_with("roof"):
				var tops: Array = truss_tops.get(bay, [0.0, 0.0])
				tops[0 if who == "roof_r" else 1] = (a + b).y * 0.5 + s * 0.5
				truss_tops[bay] = tops
		# The gantry over the bay and the beam under it.
		var zm := (za + zb) * 0.5
		var clear := _roof_gear_height() + 0.25
		var tops: Array = truss_tops.get(bay, [])
		if tops.size() == 2:
			var post_h := maxf(0.4, roof + clear - float(tops[0]))
			var beam_y := float(tops[0]) + post_h + 0.08 + FrameHull.GAP
			var posts: Array = []
			for side: float in [1.0, -1.0]:
				var k := 1 if side > 0.0 else 0
				var x := pa[k].x + _bisector(pa, k).x * off
				var foot := Vector3(x, float(tops[0 if side > 0.0 else 1]) + FrameHull.GAP, zm)
				var post := kit.part("ExoPost", PartData.Kind.FRAME, PartShapes.girder(post_h, 0.12, 0.12),
						FrameParts.along(foot, foot + Vector3.UP * post_h, Vector3.BACK), steel, "", 0.6, null,
						"exo/gantry:%s/post_%s" % [label, "r" if side > 0.0 else "l"])
				posts.append([post, foot, x])
			var beam_a := Vector3(float(posts[0][2]) + 0.06, beam_y, zm)
			var beam_b := Vector3(float(posts[1][2]) - 0.06, beam_y, zm)
			var beam := kit.part("ExoBeam", PartData.Kind.FRAME, PartShapes.girder(beam_a.distance_to(beam_b), 0.12, 0.16),
					FrameParts.along(beam_b, beam_a), steel, "", 0.6, null, "exo/gantry:%s/beam" % label)
			for q: Array in posts:
				var post: PartData = q[0]
				var foot: Vector3 = q[1]
				var below := _part_at_path("exo/roof_%s/bay:%s" % ["r" if foot.x > 0.0 else "l", label])
				if below:
					kit.join(post, below, ConnectionData.Kind.BOLT, foot, Vector3.UP, Vector3.ZERO, Vector2.ZERO, "%s/bolt:foot" % post.path)
				kit.join(beam, post, ConnectionData.Kind.BOLT, Vector3(foot.x, beam_y - 0.08, zm), Vector3.UP, Vector3.ZERO, Vector2.ZERO,
						"%s/bolt:%s" % [beam.path, "r" if foot.x > 0.0 else "l"])
		if not (hatch.has_area() and zm > hatch.position.y - 0.3 and zm < hatch.end.y + 0.3):
			var pm := profile_at(bay)
			var yb := pm[4].y + _bisector(pm, 4).y * off - s * 0.5 - 0.08 - FrameHull.GAP
			var xa := pm[4].x + _bisector(pm, 4).x * off
			var xb := pm[5].x + _bisector(pm, 5).x * off
			var beam := kit.part("ExoBeam", PartData.Kind.FRAME, PartShapes.girder(xa - xb, 0.12, 0.16),
					FrameParts.along(Vector3(xb, yb, zm), Vector3(xa, yb, zm)), steel, "", 0.6, null, "exo/keel:%s/beam" % label)
			for side: String in ["r", "l"]:
				var above := _part_at_path("exo/belly_%s/bay:%s" % [side, label])
				if above:
					kit.join(beam, above, ConnectionData.Kind.BOLT, Vector3(xa if side == "r" else xb, yb + 0.08, zm), Vector3.DOWN,
							Vector3.ZERO, Vector2.ZERO, "%s/bolt:%s" % [beam.path, side])
	kit.group = "hull"


## The outward bisector at corner `k` of a convex outline (x, y).
static func _bisector(p: PackedVector2Array, k: int) -> Vector2:
	var n := p.size()
	var prev := p[(k - 1 + n) % n]
	var next := p[(k + 1) % n]
	var e0 := (p[k] - prev).normalized()
	var e1 := (next - p[k]).normalized()
	var n0 := Vector2(-e0.y, e0.x)
	var n1 := Vector2(-e1.y, e1.x)
	var out := (n0 + n1).normalized()
	# Outward for a clockwise outline (the profiles run roof, right side, belly, left side).
	if out.dot(p[k] - _centroid(p)) < 0.0:
		out = -out
	return out


static func _centroid(p: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for q in p:
		c += q
	return c / float(maxi(p.size(), 1))


## The part at `path`, or null.
func _part_at_path(path: String) -> PartData:
	for p: PartData in kit.model.parts.values():
		if p.path == path:
			return p
	return null


## How tall the family's roof gear over the holds stands (m): what a gantry must clear.
func _roof_gear_height() -> float:
	match family:
		"tanker":
			return minf(0.85, roof_x * 0.42) * 2.0
		"freighter":
			return 1.1
		"liner":
			return 0.15
	return 0.0


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
	var engine_st := bay_count   # the station the engine bay starts at
	var at: Array = [[2, "cockpit_wall", ["cockpit", "cabin"]], [3, "bulkhead", ["cabin", "hold"]],
			[engine_st, "engine_wall", ["hold", "engine"]]]
	for spec: Array in at:
		var room := FrameParts.inset(profile_at(spec[0]), _lining_depth() + 0.01)
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
	var st_list: Array = [0, 2, 3, engine_st, stations.size() - 1]
	var names: Array[String] = ["cockpit", "cabin", "hold", "engine"]
	for i in names.size():
		var z0: float = _station_z(st_list[i]) + 0.07
		var z1: float = _station_z(st_list[i + 1]) - 0.07
		# The room's width and height: the narrowest of its stations (the nose bay left out).
		var w := INF
		var top := INF
		for st in range(maxi(st_list[i], 1), st_list[i + 1] + 1):
			var p := profile_at(st)
			w = minf(w, p[2].x - ceiling)
			top = minf(top, p[0].y - ceiling)
		rooms.append(AABB(Vector3(-w, 0.0, z0), Vector3(w * 2.0, top, z1 - z0)))
		room_names.append(names[i])
	hold = rooms[2]
	exit_point = Vector3(-inner_w + 0.6, 0.9, _bay_z(2) + 0.9)


## The deck plate under (x, z) (the sills weld to it): the nearest row of plates in z, then
## the nearest plate across it (one row, so a sill meets each plate in one run and never
## welds to the same plate twice).
func _floor_at(x: float, z: float) -> PartData:
	var row_dz := INF
	for p: PartData in deck.plates:
		var b := _box_of(p)
		row_dz = minf(row_dz, maxf(b.position.z - z, maxf(0.0, z - b.end.z)))
	# A wall on the seam between two rows is as near both: the aft row's plates are its floor.
	var row_z := -INF
	for p: PartData in deck.plates:
		var b := _box_of(p)
		if maxf(b.position.z - z, maxf(0.0, z - b.end.z)) <= row_dz + 0.02:
			row_z = maxf(row_z, b.position.z)
	var best: PartData = null
	var best_dx := INF
	for p: PartData in deck.plates:
		var b := _box_of(p)
		if absf(b.position.z - row_z) > 0.02:
			continue
		var dx := maxf(b.position.x - x, maxf(0.0, x - b.end.x))
		if dx < best_dx:
			best_dx = dx
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


# --- Fittings and components ------------------------------------------------------------------

## How solid a library component is, of its bounding volume (its mass).
const COMPONENT_FILL: float = 0.3

## What the crew needs aboard: seats and a console in the cockpit, bunks, lockers and a galley
## or a table in the cabin, the reactor cabinet, tanks and cabinets in the engine room. Each is
## one part, spot-welded to the deck plate under it (`_mount`).
func _build_fittings() -> void:
	kit.group = "fittings"
	var cockpit: AABB = rooms[0]
	var cabin: AABB = rooms[1]
	var engine: AABB = rooms[3]
	var inner_w := cabin.size.x * 0.5
	# Wall frames: X out of the wall, Y up, Z along it.
	var right := Basis(Vector3.UP, PI)          # on the right wall (+X), out is -X
	var left := Basis()                         # on the left wall (-X), out is +X
	var back := Basis(Vector3.UP, PI * 0.5)     # on the back wall (+Z), out is -Z
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
	# The cabin's right wall: bunks aft, lockers ahead of them.
	var bunk_len := minf(1.95, cabin.size.z - 1.0)
	var fore := cabin.position.z + 0.25
	if bunk_len > 1.2:
		ShipParts.bunks(kit, Transform3D(right, Vector3(inner_w - 0.02, 0.0, cabin.end.z - bunk_len * 0.5 - 0.2)), bunk_len)
	var locker_room := cabin.end.z - 0.3 - (bunk_len if bunk_len > 1.2 else 0.0) - fore
	var locker_n := mini(3, int(locker_room / 0.45))
	for i in locker_n:
		var z := fore + 0.22 + float(i) * 0.45
		ShipParts.locker(kit, Transform3D(right, Vector3(inner_w - 0.02, 0.0, z)), 0.4, 0.42)
	# The left wall, aft of the side door: a galley where it fits, else a table.
	var door_end := _bay_z(2) + 1.5
	var left_room := cabin.end.z - 0.2 - door_end
	if left_room >= 1.2:
		var galley_len := minf(2.4, left_room)
		ShipParts.galley(kit, Transform3D(left, Vector3(-inner_w + 0.02, 0.0, cabin.end.z - 0.2 - galley_len * 0.5)), galley_len)
	elif left_room >= 0.9:
		ShipParts.table(kit, Transform3D(left, Vector3(-inner_w + 0.02, 0.0, cabin.end.z - 0.2 - 0.45)), Vector2(0.55, 0.9))
	# The engine room: the reactor cabinet in the back wall, a tank along each side wall, the
	# breaker panel over the right one.
	var eng_w := engine.size.x * 0.5
	var cab_w := minf(eng_w * 1.2, 2.0)
	ShipParts.reactor_cabinet(kit, Transform3D(back, Vector3(0.0, 0.0, engine.end.z - 0.05)), cab_w, 0.45,
			minf(2.2, engine.size.y - 0.3))
	var tank := Vector3(minf(0.9, eng_w * 0.4), minf(0.9, engine.size.y * 0.35), minf(1.6, engine.size.z - 1.4))
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * (eng_w - tank.x * 0.5 - 0.1), tank.y + 0.02, engine.end.z - 0.55 - tank.z * 0.5)
		ShipParts.jump_tank(kit, Transform3D(Basis(), at), tank, -side)
	ShipParts.breaker_panel(kit, Transform3D(right, Vector3(eng_w - 0.02, 0.0, engine.end.z - 0.55 - tank.z * 0.5)), 1.5)
	kit.group = "hull"


## The library components, bolted on: outside, the engines, manoeuvring thrusters, landing
## legs, antenna, lights, the name boards and the family's own gear (tanks, containers, drills,
## clamps, panels, fins); inside, cargo, racks, cabinets and machines.
func _dress() -> void:
	kit.group = "components"
	kit.phase = "fitting"
	_dress_outside()
	_dress_gear()
	_dress_inside()
	kit.group = "hull"


func _dress_outside() -> void:
	var stern := profile_at(stations.size() - 1)
	var w := stern[2].x
	var chine := stern[3].y
	var shoulder := stern[2].y
	var stern_roof := stern[0].y
	var stern_roof_x := stern[0].x
	var steel := mat("fit")
	var stern_face := _face("hull/cap/back", 2, 1.0)
	var nose_face := _face("hull/cap/front", 2, -1.0)
	var aft := Basis(Vector3.RIGHT, PI * 0.5)        # exhaust +Y turned to blow aft (+Z)
	var ahead := Basis(Vector3.RIGHT, -PI * 0.5)     # +Y turned to face forward (-Z)
	# The engines on the stern cap, clear of the stern door, or one on each nacelle's stern.
	var spots: Array = []   # [x, y, radius]
	if not nacelle.is_empty():
		var r := snappedf(float(nacelle["r"]) * 0.85, 0.01)
		stern_face = _face("nacelle_r/cap/back", 2, 1.0)
		for side: float in [-1.0, 1.0]:
			spots.append([side * float(nacelle["cx"]), float(nacelle["cy"]), r])
	elif stern_door.has_area():
		var door_hw := stern_door.size.x * 0.5
		var door_top := stern_door.end.y
		var r := minf(0.9, (w - door_hw - 0.55) * 0.5)
		if r >= 0.42:
			var y := clampf(door_top * 0.5, chine + r + 0.15, shoulder - r - 0.15)
			for side: float in [-1.0, 1.0]:
				spots.append([side * (door_hw + r + 0.25), y, r])
		else:
			r = minf(0.8, (stern_roof - door_top - 0.5) * 0.5)
			if r >= 0.3:
				for side: float in [-1.0, 1.0]:
					spots.append([side * minf(stern_roof_x * 0.5, 1.2), door_top + r + 0.25, r])
	else:
		var r := minf(1.0, minf(w * 0.3, stern_roof * 0.36))
		if size_class == "S":
			spots = [[-w * 0.45, stern_roof * 0.45, r], [w * 0.45, stern_roof * 0.45, r]]
		else:
			var x := maxf(w * 0.52, r * 2.2 + 0.1)
			spots = [[-x, stern_roof * 0.42, r], [0.0, stern_roof * 0.52, r], [x, stern_roof * 0.42, r]]
	for i in spots.size():
		var x: float = spots[i][0]
		var y: float = spots[i][1]
		var r: float = spots[i][2]
		var at := Vector3(x, y, stern_face)
		match family:
			"courier":
				_component("IonThruster", "ion_thruster", [snappedf(r * 1.8, 0.01), snappedf(r * 1.3, 0.01)], aft, at, Vector3.BACK, steel, "component:engine/%d" % i)
			"liner":
				_component("OvalEngine", "oval_engine", [snappedf(r * 2.0, 0.01), snappedf(r * 1.2, 0.01), snappedf(r * 0.9, 0.01)], aft, at, Vector3.BACK, steel, "component:engine/%d" % i)
			"tug":
				_component("HydrogenEngine", "hydrogen_engine", [snappedf(r, 0.01), snappedf(r * 1.5, 0.01)], aft, at, Vector3.BACK, steel, "component:engine/%d" % i)
			"miner":
				_component("TurbineEngine", "turbine_engine", [snappedf(r, 0.01), snappedf(r * 1.7, 0.01)], aft, at, Vector3.BACK, steel, "component:engine/%d" % i)
			_:
				_component("EngineBell", "engine_bell", [snappedf(r, 0.01), snappedf(r * 1.8, 0.01)], aft, at, Vector3.BACK, steel, "component:engine/%d" % i)
	# Manoeuvring thrusters: a cup on the roof and one under the belly at each corner of the
	# first full bay and the engine bay.
	var cup_r := snappedf(clampf(half_width * 0.09, 0.18, 0.32), 0.01)
	var cup_len := snappedf(cup_r * 1.7, 0.01)
	var n := 0
	for bay: int in [1, bay_count]:
		var label := _bay_label(bay)
		var roof_y := _face("hull/bay:%s/skin/e0" % label, 1, 1.0)
		var belly_y := _face("hull/bay:%s/skin/e4" % label, 1, -1.0)
		var z := _bay_z(bay) + 0.5 if bay == 1 else _bay_z(bay) + bay_length - 0.5
		for side: float in [-1.0, 1.0]:
			_component("CupThruster", "cup_thruster", [cup_r, cup_len], Basis(), Vector3(side * roof_x * 0.55, roof_y, z), Vector3.UP, steel, "component:thruster/%d" % n)
			n += 1
			var belly_x := minf(maxf(bottom_x * 0.2, cup_r + 0.05), bottom_x * 0.6)   # apart under a narrow belly
			_component("CupThruster", "cup_thruster", [cup_r, cup_len], Basis(Vector3.RIGHT, PI), Vector3(side * belly_x, belly_y, z), Vector3.DOWN, steel, "component:thruster/%d" % n)
			n += 1
	# Landing legs under the first full bay and the last hold bay.
	var leg_h := snappedf(clampf(roof * 0.3, 0.8, 1.3), 0.01)
	var pad := snappedf(clampf(half_width * 0.2, 0.45, 0.8), 0.01)
	var holds := _hold_bays()
	n = 0
	for bay: int in [1, holds[holds.size() - 1]]:
		var belly_y := _face("hull/bay:%s/skin/e4" % _bay_label(bay), 1, -1.0)
		var z := _bay_z(bay) + bay_length - 0.6
		for side: float in [-1.0, 1.0]:
			_component("LandingLeg", "landing_leg", [leg_h, pad], Basis(), Vector3(side * bottom_x * 0.6, belly_y, z), Vector3.DOWN, steel, "component:leg/%d" % n)
			n += 1
	# The antenna on the cabin's roof.
	var ant_h := snappedf(clampf(roof * 0.45, 1.0, 2.2), 0.01)
	_component("Antenna", "antenna", [ant_h, snappedf(clampf(ant_h * 0.4, 0.4, 0.9), 0.01)], Basis(),
			Vector3(roof_x * 0.45, _face("hull/bay:cabin/skin/e0", 1, 1.0), _bay_z(2) + bay_length * 0.5), Vector3.UP, steel, "component:antenna")
	# The name on both flanks of the first hold bay.
	var board_bay: int = holds[0]
	var board_z := _bay_z(board_bay) + bay_length * 0.5
	var board_y := clampf((BELLY + chine_rise + roof - (half_width - roof_x)) * 0.5 + 0.3, BELLY + chine_rise + 0.5, roof - (half_width - roof_x) - 0.4)
	var text := ship_name(seed_value, family).to_upper()
	var board_w := snappedf(minf(bay_length - 0.5, 0.26 * text.length() + 0.5), 0.01)
	var flank_x := _face("hull/bay:%s/skin/e2" % _bay_label(board_bay), 0, 1.0)
	ShipParts.name_board(kit, Transform3D(Basis(), Vector3(flank_x, board_y, board_z)), text, board_w, 0.4)
	ShipParts.name_board(kit, Transform3D(Basis(Vector3.UP, PI), Vector3(-flank_x, board_y, board_z)), text, board_w, 0.4)
	# The nose: searchlights on the cap, or a miner's drills, a tug's clamps.
	var nose_hw := half_width * float(shape["nose"])
	var nose_y := roof * nose_anchor
	var glazed: bool = shape["glazed"]
	match family:
		"miner":
			var r := snappedf(minf(0.7, nose_hw * 0.35), 0.01)
			for side: float in [-1.0, 1.0]:
				_component("DrillHead", "drill_head", [r, snappedf(r * 2.4, 0.01)], ahead, Vector3(side * nose_hw * 0.5, nose_y, nose_face), Vector3.FORWARD, steel,
						"component:drill/%d" % (0 if side < 0.0 else 1))
		"tug":
			var s := snappedf(minf(0.9, nose_hw * 0.5), 0.01)
			for side: float in [-1.0, 1.0]:
				_component("LandingClamp", "landing_clamp", [s, snappedf(s * 0.5, 0.01)], ahead, Vector3(side * nose_hw * 0.5, nose_y, nose_face), Vector3.FORWARD, steel,
						"component:clamp/%d" % (0 if side < 0.0 else 1))
		_:
			if not glazed:
				var r := snappedf(minf(0.35, nose_hw * 0.2), 0.01)
				for side: float in [-1.0, 1.0]:
					_component("Searchlight", "searchlight", [r, snappedf(r * 1.8, 0.01)], ahead, Vector3(side * nose_hw * 0.5, nose_y + 0.2, nose_face), Vector3.FORWARD, steel,
							"component:searchlight/%d" % (0 if side < 0.0 else 1))
	# The family's gear on the roof over the holds.
	var hold_z0 := _bay_z(holds[0])
	var hold_z1 := _bay_z(holds[holds.size() - 1]) + bay_length
	var hold_len := hold_z1 - hold_z0
	var mid_z := (hold_z0 + hold_z1) * 0.5
	var bulged: bool = form["waist"] == "bulged"
	match family:
		"tanker":
			var r := snappedf(minf(0.85, roof_x * 0.42), 0.01)
			var len := snappedf(minf(hold_len - 1.0, 4.0 if bulged else 7.0), 0.01)
			var hold_roof := _face_over("hull/bay:hold", 1, 1.0, mid_z - len * 0.5, mid_z + len * 0.5)
			for side: float in [-1.0, 1.0]:
				_component("RoofTank", "banded_tank", [r, len], aft, Vector3(side * roof_x * 0.5, hold_roof, mid_z), Vector3.UP, mat("shell"),
						"component:tank/%d" % (0 if side < 0.0 else 1))
		"freighter":
			var size := Vector3(snappedf(minf(1.2, roof_x * 0.85), 0.01), 1.1, snappedf(minf(2.4, bay_length * 0.9), 0.01))
			var rows := 1 if hold_len < 2.0 * size.z + 1.5 else 2
			var k := 0
			for row in rows:
				var z := mid_z if rows == 1 else mid_z + (float(row) - 0.5) * (size.z + 0.6)
				var hold_roof := _face_over("hull/bay:hold", 1, 1.0, z - size.z * 0.5, z + size.z * 0.5)
				for side: float in [-1.0, 1.0]:
					_component("Container", "container", [size, _trim_colour()], Basis(), Vector3(side * roof_x * 0.5, hold_roof, z), Vector3.UP, mat("trim"),
							"component:container/%d" % k)
					k += 1
		"liner":
			var pw := snappedf(minf(1.4, roof_x * 0.85), 0.01)
			var pl := snappedf(minf(hold_len - 1.0, 3.0 if bulged else 5.0), 0.01)
			var hold_roof := _face_over("hull/bay:hold", 1, 1.0, mid_z - pl * 0.5, mid_z + pl * 0.5)
			for side: float in [-1.0, 1.0]:
				_component("SolarPanel", "solar_panel", [pw, pl], Basis(), Vector3(side * roof_x * 0.5, hold_roof, mid_z), Vector3.UP, steel,
						"component:panel/%d" % (0 if side < 0.0 else 1), mat("glass"))
		"courier":
			var root := snappedf(minf(1.6, bay_length * 0.6), 0.01)
			var fin_h := snappedf(minf(1.3, roof * 0.45), 0.01)
			var fin_roof := _face("hull/bay:engine/skin/e0", 1, 1.0)
			var fin_holds := _hold_bays()
			for side: float in [-1.0, 1.0]:
				var fin_spots: Array = [Vector3(side * roof_x * 0.6, fin_roof, _bay_z(bay_count) + bay_length * 0.5),
						Vector3(side * roof_x * 0.6, fin_roof, _bay_z(bay_count) + root * 0.5 + 0.15)]
				if not fin_holds.is_empty():
					var last: int = fin_holds[fin_holds.size() - 1]
					fin_spots.append(Vector3(side * roof_x * 0.6, _face("hull/bay:%s/skin/e0" % _bay_label(last), 1, 1.0), _bay_z(last + 1) - root * 0.5 - 0.15))
				_component_at("Fin", "fin", [root, fin_h, snappedf(root * 0.4, 0.01), snappedf(root * 0.4, 0.01)], Basis(), fin_spots, Vector3.UP,
						mat("trim"), "component:fin/%d" % (0 if side < 0.0 else 1), mat("glass"))


## The rolled gear: turrets, a radar dish, a crane, a cargo ramp, vents.
func _dress_gear() -> void:
	var steel := mat("fit")
	var holds := _hold_bays()
	var stern_i := stations.size() - 1
	# Turrets: a dome on the cockpit bay's roof and one under the last hold bay; a twin turret
	# on a big ship's engine bay roof.
	if form["turrets"]:
		var r := snappedf(clampf(roof_x * 0.3, 0.35, 0.6), 0.01)
		var roof_y := _face("hull/bay:cockpit/skin/e0", 1, 1.0)
		_component("DomeTurret", "dome_turret", [r, snappedf(r * 2.2, 0.01)], Basis(), Vector3(0.0, roof_y, _bay_z(1) + bay_length * 0.5 + 0.4),
				Vector3.UP, steel, "component:turret/0")
		var last: int = holds[holds.size() - 1]
		var belly_y := _face("hull/bay:%s/skin/e4" % _bay_label(last), 1, -1.0)
		_component("DomeTurret", "dome_turret", [r, snappedf(r * 2.2, 0.01)], Basis(Vector3.RIGHT, PI), Vector3(0.0, belly_y, _bay_z(last) + bay_length * 0.5),
				Vector3.DOWN, steel, "component:turret/1")
		if size_class == "L":
			var eng_roof := _face_over("hull/bay:engine/skin/e0", 1, 1.0, _bay_z(bay_count), _bay_z(bay_count) + 2.0)
			_component("Turret", "turret", [snappedf(r * 1.6, 0.01), snappedf(r * 3.5, 0.01)], Basis(), Vector3(0.0, eng_roof, _bay_z(bay_count) + 0.9),
					Vector3.UP, steel, "component:turret/2")
	# The radar dish: on a wing's top, else on the engine bay's roof.
	if form["dish"]:
		var h := snappedf(clampf(roof * 0.5, 1.2, 2.5), 0.01)
		var dish := snappedf(clampf(h * 0.35, 0.45, 0.9), 0.01)   # the dish's radius, m
		if not wing.is_empty() and float(wing["span"]) > dish * 2.0 + 0.6:
			var u := 0.6
			var x := float(wing["root_x"]) + float(wing["span"]) * u
			var z := (float(wing["zt0"]) + float(wing["zt1"])) * 0.5
			var y := float(wing["y"]) + float(wing["dihedral"]) * u + lerpf(float(wing["t_root"]), float(wing["t_tip"]), u) * 0.5
			_component("RadarDish", "antenna", [h, dish], Basis(), Vector3(-x, y, z), Vector3.UP, steel, "component:dish")
		else:
			# The engine bay's roof ahead of its thrusters, else the last hold bay's roof, else
			# the cabin's.
			var spots: Array = []
			var eng_roof := _face_over("hull/bay:engine/skin/e0", 1, 1.0, _bay_z(bay_count), _bay_z(bay_count) + 2.0)
			for x: float in [-roof_x * 0.35, 0.0, roof_x * 0.35]:
				spots.append(Vector3(x, eng_roof, _bay_z(bay_count) + dish + 0.3))
			if not holds.is_empty():
				var last: int = holds[holds.size() - 1]
				var hold_roof := _face_over("hull/bay:%s/skin/e0" % _bay_label(last), 1, 1.0, _bay_z(last + 1) - 2.0, _bay_z(last + 1))
				for x: float in [-roof_x * 0.4, roof_x * 0.4, 0.0]:
					spots.append(Vector3(x, hold_roof, _bay_z(last + 1) - dish - 0.3))
			var cabin_roof := _face("hull/bay:cabin/skin/e0", 1, 1.0)
			spots.append(Vector3(-roof_x * 0.5, cabin_roof, _bay_z(2) + bay_length * 0.5))
			_component_at("RadarDish", "antenna", [h, dish], Basis(), spots, Vector3.UP, steel, "component:dish")
	# A crane on the roof at the front of the holds: a mast, a lattice boom out over the side,
	# a cable and a hook block.
	if form["crane"] and not holds.is_empty():
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var hold_roof := _face("hull/bay:%s/skin/e0" % _bay_label(holds[0]), 1, 1.0)
		var mast_h := snappedf(clampf(roof * 0.45, 1.4, 2.6), 0.01)
		var mast_at := Vector3(side * roof_x * 0.8, hold_roof + 0.01, _bay_z(holds[0]) + 0.7)
		var mast_box := AABB(mast_at + Vector3(-0.175, 0.0, -0.175), Vector3(0.35, mast_h, 0.35)).grow(-0.015)
		var clash := false
		for other: PartData in kit.model.parts.values():
			clash = clash or _box_of(other).intersects(mast_box)
		if not clash:
			var mast := kit.part("CraneMast", PartData.Kind.COMPONENT, PartShapes.box(Vector3(0.35, mast_h, 0.35)),
					Transform3D(Basis(), mast_at + Vector3(0.0, mast_h * 0.5, 0.0)), steel, "", 0.5, null, "component:crane/mast")
			tacks["component:crane/mast"] = _fix(mast, ConnectionData.Kind.BOLT, "component:crane/mast")
			var boom_len := snappedf(clampf(half_width * 1.2, 2.5, 5.0), 0.01)
			var top := mast_at + Vector3(0.0, mast_h + FrameHull.GAP, 0.0)
			var boom_a := top + Vector3(-side * 0.6, 0.15, 0.0)
			var boom_b := top + Vector3(side * (boom_len - 0.6), 0.15, 0.0)
			var boom := kit.part("CraneBoom", PartData.Kind.COMPONENT, PartShapes.truss(boom_len, 0.3, 0.3, maxi(3, int(round(boom_len / 0.6)))),
					FrameParts.along(boom_a, boom_b), steel, "", 0.3, null, "component:crane/boom")
			kit.join(boom, mast, ConnectionData.Kind.BOLT, top, Vector3.UP, Vector3.ZERO, Vector2.ZERO, "component:crane/boom/bolt/0")
			var drop := snappedf(clampf(mast_h * 0.5, 0.6, 1.2), 0.01)
			var cable_top := boom_b + Vector3(-side * 0.3, -0.15 - FrameHull.GAP, 0.0)
			var cable := kit.part("CraneCable", PartData.Kind.COMPONENT, PartShapes.box(Vector3(0.05, drop, 0.05)),
					Transform3D(Basis(), cable_top - Vector3(0.0, drop * 0.5, 0.0)), steel, "", 0.5, null, "component:crane/cable")
			kit.join(cable, boom, ConnectionData.Kind.BOLT, cable_top, Vector3.DOWN, Vector3.ZERO, Vector2.ZERO, "component:crane/cable/bolt/0")
			var hook_top := cable_top - Vector3(0.0, drop + FrameHull.GAP, 0.0)
			var hook := kit.part("CraneHook", PartData.Kind.COMPONENT, PartShapes.box(Vector3(0.3, 0.3, 0.3)),
					Transform3D(Basis(), hook_top - Vector3(0.0, 0.15, 0.0)), mat("trim"), "", 0.8, null, "component:crane/hook")
			kit.join(hook, cable, ConnectionData.Kind.BOLT, hook_top, Vector3.DOWN, Vector3.ZERO, Vector2.ZERO, "component:crane/hook/bolt/0")
	# A cargo ramp leaf closed over the stern door.
	if form["ramp"] and stern_door.has_area():
		var stern_face := _face("hull/cap/back", 2, 1.0)
		_component("CargoRamp", "cargo_ramp", [snappedf(stern_door.size.x - 0.1, 0.01), snappedf(stern_door.size.y - 0.05, 0.01), 0.12], Basis(),
				Vector3(0.0, stern_door.position.y + stern_door.size.y * 0.5, stern_face), Vector3.BACK, mat("trim"), "component:ramp")
	# Vents on both flanks of the engine bay (the last straight-sided bay) and a heat sink on
	# its roof.
	if form["vents"]:
		var bay := bay_count
		while bay > 2 and not _straight_between(_bay_z(bay), _bay_z(bay) + bay_length):
			bay -= 1
		var label := _bay_label(bay)
		var span := _side_span_at(_bay_z(bay) + bay_length * 0.5)
		var vlen := snappedf(clampf(bay_length - 0.7, 0.9, 3.0), 0.01)
		var vh := snappedf(clampf(float(span[1]) - float(span[0]) - 0.5, 0.5, 1.2), 0.01)
		var vy := (float(span[0]) + float(span[1])) * 0.5
		var vz := _bay_z(bay) + bay_length * 0.5
		var recipe := "copper_vent"
		var args: Array = [vlen, vh, 0.2, 6]
		match family:
			"liner", "courier":
				recipe = "radiator_grille"
				args = [vlen, vh, 0.14]
			"freighter":
				recipe = "louvre_panel"
				args = [vlen, vh, 0.1]
		for side: float in [-1.0, 1.0]:
			var flank := _face("hull/bay:%s/skin/e%d" % [label, 2 if side > 0.0 else 6], 0, side)
			var basis := Basis(Vector3(0, 0, 1), Vector3(side, 0, 0), Vector3(0, -side, 0))
			_component("Vent", recipe, args, basis, Vector3(flank, vy, vz), Vector3(side, 0, 0), mat("hull_dark"),
					"component:vent/%d" % (0 if side < 0.0 else 1))
		var sink_roof := _face("hull/bay:%s/skin/e0" % label, 1, 1.0)
		var sink_spots: Array = []
		for x: float in [roof_x * 0.3, -roof_x * 0.3, 0.0]:
			sink_spots.append(Vector3(x, sink_roof, _bay_z(bay) + bay_length * 0.5))
			sink_spots.append(Vector3(x, sink_roof, _bay_z(bay) + 0.6))
			sink_spots.append(Vector3(x, sink_roof, _bay_z(bay) + bay_length - 1.2))   # between the aft thrusters
		if bay != bay_count:   # else the engine bay's roof, ahead of its thrusters
			var eng_roof := _face_over("hull/bay:engine/skin/e0", 1, 1.0, _bay_z(bay_count), _bay_z(bay_count) + 1.0)
			for x: float in [0.0, roof_x * 0.3, -roof_x * 0.3]:
				sink_spots.append(Vector3(x, eng_roof, _bay_z(bay_count) + 0.6))
		_component_at("HeatSink", "heat_sink", [6, snappedf(clampf(roof * 0.2, 0.5, 1.0), 0.01), 0.3, 0.14], Basis(Vector3.RIGHT, PI * 0.5),
				sink_spots, Vector3.UP, mat("hull_dark"), "component:vent/2")


func _dress_inside() -> void:
	var hold_room: AABB = rooms[2]
	var engine: AABB = rooms[3]
	var inner_w := hold_room.size.x * 0.5
	var steel := mat("fit")
	var right := Basis(Vector3.UP, PI)
	var left := Basis()
	# Cargo crates along the hold's right wall, clear of the belly hatch; machines against the
	# engine wall in a wide hold.
	var machines := inner_w >= 2.1
	var crate := Vector3(snappedf(minf(1.0, inner_w * 0.45), 0.01), 0.9, 0.8)
	var crate_x := inner_w - crate.x * 0.5 - 0.08
	var z := hold_room.position.z + 0.3 + crate.z * 0.5
	var z_end := hold_room.end.z - (1.5 if machines else 0.3)
	var keep_out := hatch.grow(0.3) if hatch.has_area() else Rect2()
	var k := 0
	while z + crate.z * 0.5 < z_end:
		var foot := Rect2(crate_x - crate.x * 0.5, z - crate.z * 0.5, crate.x, crate.z)
		if not (keep_out.has_area() and keep_out.intersects(foot)):
			_component("CargoCrate", "cargo_crate", [crate], Basis(), Vector3(crate_x, 0.0, z), Vector3.UP, steel, "component:crate/%d" % k)
			k += 1
		z += crate.z + 0.25
	if machines:
		var gw := snappedf(minf(1.2, inner_w * 0.4), 0.01)
		_component("Generator", "generator", [Vector3(gw, 1.3, 0.8)], Basis(), Vector3(inner_w - gw * 0.5 - 0.15, 0.0, hold_room.end.z - 0.02), Vector3.FORWARD, steel, "component:generator", null, 0.0)
		_component("MachineUnit", "machine_unit", [Vector3(snappedf(minf(0.9, inner_w * 0.3), 0.01), 1.6, 0.7)], Basis(), Vector3(-inner_w + 0.65, 0.0, hold_room.end.z - 0.02), Vector3.FORWARD, steel, "component:machine", null, 0.0)
	# Racks on the hold's left wall: shelf racks in a wide hold, a wall rack in a narrow one.
	if inner_w >= 1.9:
		var rack_w := snappedf(minf(1.6, hold_room.size.z * 0.3), 0.01)
		var rack_h := snappedf(minf(2.0, hold_room.size.y - 0.4), 0.01)
		var racks := 1 if hold_room.size.z < 2.0 * rack_w + 1.5 else 2
		for i in racks:
			var rz := hold_room.position.z + hold_room.size.z * (float(i) + 0.5) / float(racks)
			_component_at("ShelfRack", "shelf_rack", [rack_w, rack_h, 0.5], Basis(Vector3.UP, -PI * 0.5),
					[Vector3(-inner_w, 0.0, rz), Vector3(-inner_w, 0.0, rz - rack_w * 0.6), Vector3(-inner_w, 0.0, rz - rack_w * 1.2)],
					Vector3.RIGHT, steel, "component:rack/%d" % i, null, 0.0)
	else:
		ShipParts.wall_rack(kit, Transform3D(left, Vector3(-inner_w + 0.02, 0.0, hold_room.position.z + hold_room.size.z * 0.5)), minf(1.4, hold_room.size.z - 0.6))
	# Railings along the hatch, and a catch net under the hold's ceiling.
	if hatch.has_area():
		for side: float in [-1.0, 1.0]:
			var x := hatch.position.x - 0.15 if side < 0.0 else hatch.end.x + 0.15
			ShipParts.railing(kit, Vector3(x, 0.0, hatch.position.y - 0.1), Vector3(x, 0.0, hatch.end.y + 0.1), 1.0)
	ShipParts.hold_net(kit, hold_room.end.y - 0.3, Rect2(-inner_w * 0.6, hold_room.position.z + 0.5, inner_w * 1.2, hold_room.size.z - 1.0))
	# The engine room's front wall: a switch cabinet and a battery rack beside the doorway.
	var eng_w := engine.size.x * 0.5
	var wall_z := engine.position.z - 0.02
	if eng_w >= 1.45:
		_component("SwitchCabinet", "switch_cabinet", [Vector3(0.7, 1.4, 0.35)], right, Vector3(-(0.55 + 0.15 + 0.35), 0.0, wall_z), Vector3.BACK, steel, "component:switch_cabinet", null, 0.0)
	if eng_w >= 1.9:
		_component("BatteryRack", "battery_rack", [1.2, 1.4, 0.5], right, Vector3(0.55 + 0.15 + 0.6, 0.0, wall_z), Vector3.BACK, steel, "component:battery_rack", null, 0.0)


## The trim colour (the stripe on a container).
func _trim_colour() -> Color:
	return (mat("trim") as StandardMaterial3D).albedo_color


## The outermost face of the parts whose path begins with `prefix` (their looks, ship space):
## the greatest coordinate along `axis` when `sign` is positive, else the least.
func _face(prefix: String, axis: int, sign: float) -> float:
	var best := -INF
	for p: PartData in kit.model.parts.values():
		if not p.path.begins_with(prefix):
			continue
		var b := _look_box(p)
		var v := b.end[axis] if sign > 0.0 else -b.position[axis]
		best = maxf(best, v)
	return best * sign if best > -INF else 0.0


## The bounds of a part's look (ship space).
func _look_box(p: PartData) -> AABB:
	var v := kit.model.part_visual(p.id) as MeshInstance3D
	if v == null or v.mesh == null:
		return _box_of(p)
	return v.transform * v.mesh.get_aabb()


## A library shape as one component part: `basis` turns it, then its bounds are set on the
## surface through `at` facing `out` (the face opposite `out` touches it, centred on `at`), and
## it is bolted to that surface. The recipe is stamped so the importer rebuilds it.
func _component(part_name: String, recipe: String, args: Array, basis: Basis, at: Vector3, out: Vector3, material: Material,
		path: String, glass_mat: Material = null, rest: float = NAN) -> PartData:
	var made_shape: Variant = Callable(WreckParts, recipe).callv(args)
	if not made_shape is PartShapes.PartShape:
		return null
	var shape: PartShapes.PartShape = made_shape
	PartShapes.stamp(shape, recipe, args)
	var ra := Transform3D(basis, Vector3.ZERO) * shape.mesh.get_aabb()
	var axis := out.abs().max_axis_index()
	var origin := Vector3.ZERO
	for i in 3:
		if i == axis:
			origin[i] = at[i] - (ra.position[i] if out[i] > 0.0 else ra.end[i]) + out[i] * 0.01
		else:
			origin[i] = at[i] - (ra.position[i] + ra.end[i]) * 0.5
	if not is_nan(rest):
		origin.y = rest - ra.position.y + 0.01   # its foot on the floor at `rest`
	# Nothing is placed through a fitting, another component or the exoskeleton.
	var placed := AABB(ra.position + origin, ra.size).grow(-0.015)
	var blocker := _blocked(placed)
	if blocker:
		if OS.has_environment("GEN_DEBUG"):
			print("gen: %s blocked by %s: %s vs %s" % [path, blocker.path, placed, _box_of(blocker)])
		return null
	var made := kit.part(part_name, PartData.Kind.COMPONENT, shape, Transform3D(basis, origin), material, "", COMPONENT_FILL,
			glass_mat if shape.glass else null, path)
	VsShipImport.glow_on(kit.model.part_visual(made.id), shape)
	var rec := _fix(made, ConnectionData.Kind.BOLT, path)
	if not rec.is_empty():
		tacks[path] = rec
	return made


## `_component` tried at each of `spots` in turn until one is clear; null when none is.
func _component_at(part_name: String, recipe: String, args: Array, basis: Basis, spots: Array, out: Vector3, material: Material,
		path: String, glass_mat: Material = null, rest: float = NAN) -> PartData:
	for spot: Vector3 in spots:
		var made := _component(part_name, recipe, args, basis, spot, out, material, path, glass_mat, rest)
		if made:
			return made
	return null


## The fitting, component or exoskeleton part whose collision `box` runs into, or null (the
## hull's slanted plates have loose bounds, so they are not checked: gear is placed on them).
func _blocked(box: AABB) -> PartData:
	for other: PartData in kit.model.parts.values():
		var group: String = kit.groups.get(other.id, "")
		if group != "components" and group != "fittings" and group != "exo":
			continue
		if _box_of(other).intersects(box):
			return other
	return null


## The outermost face (as `_face`) of the parts under `prefix` whose looks reach into
## z0..z1: the roof over a stretch of a bulged or flared hull.
func _face_over(prefix: String, axis: int, sign: float, z0: float, z1: float) -> float:
	var best := -INF
	for p: PartData in kit.model.parts.values():
		if not p.path.begins_with(prefix):
			continue
		var b := _look_box(p)
		if b.end.z < z0 or b.position.z > z1:
			continue
		var v := b.end[axis] if sign > 0.0 else -b.position[axis]
		best = maxf(best, v)
	return best * sign if best > -INF else 0.0


## The surfaces a part can be fixed to: hull skin and caps, deck plates, linings, wall panels.
func _collect_supports() -> void:
	_supports.clear()
	for p: PartData in kit.model.parts.values():
		var path := p.path
		if path.contains("/skin/") or path.contains("/deck/") or path.contains("/lining/") or path.contains("/cap/") or path.contains("/panel/"):
			_supports.append({"part": p, "box": _box_of(p)})


## The support nearest `box` and the side of `box` it lies on: {part, normal} (normal from
## the box toward the support, along one axis), or {}.
func _support_near(box: AABB) -> Dictionary:
	var best := {}
	var best_d := INF
	var best_area := -INF
	for s: Dictionary in _supports:
		var b: AABB = s["box"]
		var gap := Vector3.ZERO
		for i in 3:
			gap[i] = maxf(0.0, maxf(b.position[i] - box.end[i], box.position[i] - b.end[i]))
		var d := gap.length_squared()
		# Anything within TOUCH is touching; among those, the support meeting the most of the
		# box's face wins (the stern cap over a flared side plate whose loose bounds graze
		# the engine), else the nearest.
		var touching := d <= TOUCH * TOUCH
		var area := -INF
		if touching:
			var axis := _facing_axis(box, b)
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			area = maxf(0.0, minf(b.end[u], box.end[u]) - maxf(b.position[u], box.position[u])) \
					* maxf(0.0, minf(b.end[v], box.end[v]) - maxf(b.position[v], box.position[v]))
		if touching and (best_d > TOUCH * TOUCH or area > best_area) or not touching and d < best_d and best_d > TOUCH * TOUCH:
			best_d = d
			best_area = area
			best = s
	if best.is_empty():
		return {}
	var b: AABB = best["box"]
	var axis := _facing_axis(box, b)
	var normal := Vector3.ZERO
	normal[axis] = 1.0 if b.get_center()[axis] > box.get_center()[axis] else -1.0
	return {"part": best["part"], "normal": normal, "axis": axis}


## The axis along which support `b` lies against `box`: the widest face-to-face separation.
func _facing_axis(box: AABB, b: AABB) -> int:
	var axis := 0
	var widest := -INF
	for i in 3:
		var toward := 1.0 if b.get_center()[i] > box.get_center()[i] else -1.0
		var sep := (b.position[i] - box.end[i]) if toward > 0.0 else (box.position[i] - b.end[i])
		if sep > widest:
			widest = sep
			axis = i
	return axis


## Fixes `made` to the nearest support with joints of `kind` at the corners of the face that
## touches it (two on a narrow foot), heads facing away from the support. Returns the mount
## record {onto, spots|bolts} or {}.
func _fix(made: PartData, kind: ConnectionData.Kind, path: String) -> Dictionary:
	var box := _box_of(made)
	var s := _support_near(box)
	if s.is_empty():
		return {}
	var n: Vector3 = s["normal"]
	var axis: int = s["axis"]
	var face := box.end[axis] if n[axis] > 0.0 else box.position[axis]
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	var inset_u := minf(0.08, box.size[u] * 0.25)
	var inset_v := minf(0.08, box.size[v] * 0.25)
	var points: Array = []
	for cu: float in [box.position[u] + inset_u, box.end[u] - inset_u]:
		for cv: float in [box.position[v] + inset_v, box.end[v] - inset_v]:
			var p := Vector3.ZERO
			p[axis] = face
			p[u] = cu
			p[v] = cv
			points.append(p)
	if box.size[u] < 0.3 or box.size[v] < 0.3:
		points = [points[0], points[3]]
	var onto: PartData = s["part"]
	if kind == ConnectionData.Kind.SPOT:
		var spots := kit.tack(made, onto, points, -n, path)
		return {"onto": [onto.path], "spots": spots.size()}
	var bolts := 0
	for i in points.size():
		if kit.join(made, onto, kind, points[i], -n, Vector3.ZERO, Vector2.ZERO, "%s/bolt/%d" % [path, i]):
			bolts += 1
	return {"onto": [onto.path], "bolts": bolts}


## A fitting's part is spot-welded to the nearest surface at the corners of the face that
## touches it (the deck under a locker, the wall behind a name board; phase "fitting"); a
## looks-only unit rides on that surface.
func _mount(made: PartData, unit: Dictionary) -> void:
	if made == null:
		var box: AABB = unit.get("box", AABB())
		if box.has_volume() or box.has_surface():
			var s := _support_near(box)
			if not s.is_empty():
				unit["onto"] = s["part"]
		return
	var rec := _fix(made, ConnectionData.Kind.SPOT, made.path)
	if not rec.is_empty():
		tacks[made.path] = rec


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
				"base": {"design": id, "app_version": "bsx", "seed": seed_value, "family": family, "form": form},
				"livery": "company", "serial": "VS-BX%s-%06d" % [family.substr(0, 3).to_upper(), absi(seed_value) % 1000000],
				"owner": ""},
		"stats": {"length_m": length, "half_width_m": half_width, "roof_m": roof, "bays": bay_count},
	}
	var frames: Array = [_frame_hull(hull, mat_name)]
	for limb: FrameHull in limbs:
		frames.append(_frame_hull(limb, mat_name))
	file["frame"] = frames
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
