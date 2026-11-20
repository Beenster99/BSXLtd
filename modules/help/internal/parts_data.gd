extends RefCounted
## Help's parts list (beenster, 20 Nov: "the help screen needs an entire list of all of the
## building parts, components, plate, beams, glass. everything. This list of parts should show
## all of the attributes of the part and all variants of it"). Built from the design module's
## data each time, so a new part or a changed number shows here without touching Help:
##   components   every DesignPartType: every number it has, the rooms it goes in, and a row
##                for every size and grade it comes in
##   rooms        every room type: its numbers per m² and the parts that go in it
##   doors        DesignCatalog.DOOR_KINDS
##   frame        the hull's frame kit (DesignFrame.PART_NAMES) in each frame weight, the frame
##                weights, hull plating, inner walls (DesignStructure.OPTIONS) and the joints
##   services     wiring and pipes (DesignServices.KINDS)
## Each entry: {id, name, group, attrs: [[label, value]], cols: [..], rows: [[..]], search}.

const Data := preload("res://modules/help/internal/capability_data.gd")

const ROOMS_GROUP := "Rooms"
const DOORS_GROUP := "Doors and doorways"
const FRAME_GROUP := "Hull, frame and glass"
const SERVICES_GROUP := "Wires and pipes"

## What each piece of the frame kit is, in the yard's words.
const FRAME_PIECES := {
	"FrameNode": "A cast block at each corner of a frame ring, where the ring's girders and the stringers meet. Every member is welded to it all round.",
	"FrameRing": "A girder of the ring that stands across the ship at every station. Welded to the node blocks at both ends.",
	"Stringer": "A girder along the ship from ring to ring at every corner. Welded to the node blocks at both ends.",
	"HullPlate": "A metal skin panel cut to one face of the frame between two rings. Riveted to the rings and stringers round it.",
	"CapPlate": "A plate closing the front or back end of the hull. Riveted to the end ring.",
	"WindowPane": "A glass panel set in the frame in place of a hull plate (over the bridge, or anywhere you glaze). Riveted in like a plate.",
	"FramePost": "An upright either side of a door or hatch cut through the skin. Welded to the frame.",
	"FrameRail": "The rail across the top and bottom of a door or hatch opening. Welded to the posts.",
	"FrameSplice": "A short piece joining two lengths of girder where a member is too long for one.",
	"DeckBeam": "A beam across the ship under a deck, carrying the deck's girders. Welded to the frame.",
	"DeckGirder": "A girder along the ship under a deck, in lanes 1.5 m apart. Welded to the deck beams.",
	"DeckTrimmer": "A short beam framing a hole through a deck (stairs, lifts, hatches).",
	"DeckPlate": "A floor plate laid over the deck girders. Bolted down.",
	"Stud": "An upright in an inner wall, every 0.6 m. Bolted to the foot and head rails.",
	"StudSill": "The rail under a window or hatch in an inner wall.",
	"StudHead": "The rail along the top of an inner wall.",
	"StudLintel": "The rail over a doorway in an inner wall.",
	"StudFoot": "The rail along the bottom of an inner wall, bolted to the deck.",
	"WallPanel": "A lining panel over an inner wall's studs. Bolted on.",
}
## Pieces that are skin (sized per m² by the hull plating) rather than members (per m).
const SKIN := ["HullPlate", "CapPlate", "WindowPane", "DeckPlate", "WallPanel"]

const FIELD_NAMES := {
	"cost": ["Price", "cr"], "mass": ["Mass", "kg"], "build_hours": ["Fitting time", "h"],
	"power": ["Power", "kW"], "thrust": ["Thrust", "kN"], "crew": ["Bunks", ""],
	"integrity": ["Integrity", "hp"], "jump": ["Jump", "ly (100 t ship)"], "attack": ["Damage", "dps"],
	"defence": ["Defence", "pts"], "signature": ["Signature", ""], "cargo": ["Cargo", "m³"],
	"tank": ["Tank", "m³"], "sensor": ["Sensor range", "km"], "tow_t": ["Tow rating", "t"],
	"access": ["Clear floor in front", "m"], "lead_days": ["Delivery from suppliers", "days"],
	"move_s": ["Opens in", "s"], "move_range": ["Travel", ""], "move_kw": ["Motor while moving", "kW"],
	"load_kg": ["Rated load", "kg"], "clearance": ["Ground clearance", "m"],
}
const MOVES := {"hinge_out": "swings out on a hinge", "hinge_up": "lifts up on a hinge", "slide": "slides",
		"spin": "turns", "leg": "extends as a leg", "belt": "runs as a belt"}

var catalog: DesignCatalog
var _entries: Array[Dictionary] = []


func _init(cat: DesignCatalog) -> void:
	catalog = cat


## Every entry, grouped in the palette's order then by name.
func entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_build()
	return _entries


## Group names in order.
func groups() -> PackedStringArray:
	var out: PackedStringArray = []
	for e in entries():
		if not str(e.group) in out:
			out.append(str(e.group))
	return out


## Entries whose text has every word of `query` (all of them for "").
func find(query: String, group := "") -> Array[Dictionary]:
	var words := query.to_lower().split(" ", false)
	var out: Array[Dictionary] = []
	for e in entries():
		if group != "" and str(e.group) != group:
			continue
		var hay := str(e.search)
		if Array(words).all(func(w: String) -> bool: return hay.contains(w)):
			out.append(e)
	return out


func entry(id: String) -> Dictionary:
	for e in entries():
		if str(e.id) == id:
			return e
	return {}


## Everything search reads, one line a part.
func search_text() -> String:
	var lines: PackedStringArray = []
	for e in entries():
		lines.append(str(e.search))
	return "\n".join(lines)


func _build() -> void:
	for c: Array in DesignCatalog.CATEGORIES:
		for p in catalog.parts_in(str(c[0])):
			_add(_component(p, str(c[1])))
	var known := DesignCatalog.CATEGORIES.map(func(c: Array) -> String: return str(c[0]))
	for p: DesignPartType in catalog.parts.values():
		if not p.category in known:
			_add(_component(p, "Other components"))
	for r in catalog.room_list():
		_add(_room(r))
	for id in DesignCatalog.DOOR_ORDER:
		if DesignCatalog.DOOR_KINDS.has(id):
			_add(_door(id, DesignCatalog.DOOR_KINDS[id]))
	_frame()
	for id: String in DesignServices.KINDS:
		var k: Dictionary = DesignServices.KINDS[id]
		_add({"id": "service." + id, "name": str(k.name), "group": SERVICES_GROUP,
				"text": "Laid in runs along the decks; joins where runs touch and rises where one ends over another.",
				"attrs": [["Price", "%s cr per m" % _n(k.cost)], ["Mass", "%s kg per m" % _n(k.mass)],
				["Fitting time", "%s h per m" % _n(k.hours)], ["Carries", "power" if str(k.field) == "power" else "fuel"]],
				"cols": [], "rows": []})


func _add(e: Dictionary) -> void:
	# The group's name stays out: "glass" should find the glass, not all thirty frame pieces.
	var bits: PackedStringArray = [str(e.name), str(e.get("text", ""))]
	for a: Array in e.attrs:
		bits.append("%s %s" % [a[0], a[1]])
	e["search"] = " ".join(bits).to_lower()
	_entries.append(e)


func _component(p: DesignPartType, group: String) -> Dictionary:
	var attrs: Array = []
	var span := DesignGrades.sizes(p)
	attrs.append(["Sizes", "one size" if span[0] == 0 else ("size %d only" % span[0] if span[0] == span[1] else
			"sizes %d to %d (base size %d)" % [span[0], span[1], p.size_class])])
	attrs.append(["Grades", " ".join(DesignGrades.GRADE_ORDER) if p.graded else "one grade (Standard)"])
	attrs.append(["Footprint", "%.2f x %.2f x %.2f m (across x high x deep)" % [p.size.x, p.size.y, p.size.z]])
	attrs.append(["Goes in", _rooms_of(p)])
	for f in ["cost", "mass", "build_hours", "lead_days", "integrity"]:
		attrs.append(_field(p, f))
	attrs.append(["Power", ("makes %s kW" % _n(p.power)) if p.power > 0.0 else
			(("uses %s kW" % _n(-p.power)) if p.power < 0.0 else "none")])
	if p.fuel != 0:
		attrs.append(["Fuel", "pumps fuel into the lines" if p.fuel > 0 else "burns fuel (needs a fuel line)"])
	for f in ["thrust", "crew", "jump", "attack", "defence", "sensor", "cargo", "tank", "tow_t", "signature",
			"load_kg", "clearance"]:
		if float(p.get(f)) != 0.0:
			attrs.append(_field(p, f))
	if p.open_size != Vector2.ZERO:
		attrs.append(["Opening", "%.1f x %.1f m" % [p.open_size.x, p.open_size.y]])
	if p.move_kind != "":
		var unit := "°" if p.move_kind.begins_with("hinge") or p.move_kind == "spin" else " m"
		attrs.append(["Moves", "%s, %s%s in %s s, %s kW while moving" % [MOVES.get(p.move_kind, p.move_kind),
				_n(p.move_range), unit, _n(p.move_s), _n(p.move_kw)]])
	attrs.append(_field(p, "access"))
	if p.shared_part != "":
		attrs.append(["Model", p.shared_part])
	var cols := ["Variant", "Price cr", "Mass kg", "Size m", "Power kW", "Rating", "Integrity", "Delivery days"]
	var rows: Array = []
	var lo := span[0] if span[0] > 0 else 0
	var hi := span[1] if span[1] > 0 else 0
	for s in range(lo, hi + 1):
		for g in DesignGrades.GRADE_ORDER:
			if not p.graded and g != DesignGrades.DEFAULT_GRADE:
				continue
			var v := catalog.part(DesignGrades.variant_id(p, s, g)) if s > 0 else p
			if v == null:
				continue
			var m := Data.metric(v)
			rows.append([DesignGrades.label(v) if DesignGrades.label(v) != "" else "-", _n(v.cost), _n(v.mass),
					"%.1f x %.1f x %.1f" % [v.size.x, v.size.y, v.size.z],
					("+" + _n(v.power)) if v.power > 0.0 else _n(v.power),
					"%s %s %s" % [m.label, _n(Data.value_of(v, str(m.field))), m.unit], _n(v.integrity), str(v.lead_days)])
	return {"id": p.id, "name": p.display_name, "group": group, "text": "", "attrs": attrs, "cols": cols, "rows": rows}


func _room(r: DesignRoomType) -> Dictionary:
	var attrs: Array = [
		["Fit-out price", "%s cr per m²" % _n(r.cost_per_m2)], ["Fit-out mass", "%s kg per m²" % _n(r.mass_per_m2)],
		["Fit-out time", "%s h per m²" % _n(r.hours_per_m2)], ["Power", "%s kW per m²" % _n(r.power_per_m2)],
		["Smallest", "%s x %s m" % [_n(r.min_size.x), _n(r.min_size.y)]],
		["New one placed at", "%s x %s m" % [_n(r.default_size.x), _n(r.default_size.y)]]]
	if r.crew_per_m2 > 0.0:
		attrs.append(["Bunks", "%s per m²" % _n(r.crew_per_m2)])
	if r.cargo_share > 0.0:
		attrs.append(["Cargo space", "%d%% of its volume" % roundi(r.cargo_share * 100.0)])
	if r.fuel_share > 0.0:
		attrs.append(["Fuel space", "%d%% of its volume" % roundi(r.fuel_share * 100.0)])
	attrs.append(["Needs a door", "yes" if r.needs_access else "no"])
	if r.required:
		attrs.append(["Every ship needs one", "yes"])
	if r.is_airlock:
		attrs.append(["Way on and off", "yes"])
	if r.links_decks:
		attrs.append(["Joins decks", "yes, where another stands over it"])
	var only: PackedStringArray = []
	var any := 0
	for p in catalog.parts_for(r.id):
		if p.rooms.is_empty():
			any += 1
		else:
			only.append(p.display_name)
	attrs.append(["Parts made for it", ", ".join(only) if not only.is_empty() else "none"])
	attrs.append(["Also takes", "%d parts that go in any room" % any])
	return {"id": "room." + r.id, "name": r.display_name + " (room)", "group": ROOMS_GROUP, "text": "",
			"attrs": attrs, "cols": [], "rows": []}


func _door(id: String, d: Dictionary) -> Dictionary:
	var how := {"split": "two leaves slide apart", "slide": "one leaf slides aside", "swing": "one leaf on hinges",
			"roll": "a shutter rolls up", "": "an open doorway, no leaves"}
	var attrs: Array = [["Width", "%s m (%s to %s m)" % [_n(d.w), _n(d.min_w), _n(d.max_w)]], ["Height", "%s m" % _n(d.h)],
			["Opens", str(how.get(str(d.style), d.style))], ["Airtight", "yes" if bool(d.airtight) else "no"],
			["Price", "%s cr at its usual width (scales with width)" % _n(d.cost)], ["Mass", "%s kg" % _n(d.mass)],
			["Fitting time", "%s h" % _n(d.hours)]]
	if float(d.move_s) > 0.0:
		attrs.append(["Opens in", "%s s" % _n(d.move_s)])
	if float(d.get("move_kw", 0.0)) > 0.0:
		attrs.append(["Motor while moving", "%s kW" % _n(d.move_kw)])
	return {"id": "door." + id, "name": str(d.name), "group": DOORS_GROUP, "text": "", "attrs": attrs, "cols": [], "rows": []}


func _frame() -> void:
	var weights: Dictionary = DesignStructure.OPTIONS.frame
	var hulls: Dictionary = DesignStructure.OPTIONS.hull
	for key: String in DesignFrame.PART_NAMES:
		var skin := key in SKIN
		var cols: Array = ["Frame", "Section m", "Node m", "Skin m", "Price", "Mass"]
		var rows: Array = []
		for w: String in weights:
			var st: Dictionary = FrameStyle.STYLES.get(str(DesignFrame.STYLES.get(w, "channel")), {})
			var o: Dictionary = weights[w]
			var member: Vector2 = st.get("member", Vector2.ZERO)
			rows.append([str(o.name), "%.2f x %.2f" % [member.x, member.y], _n(float(st.get("node", 0.0))),
					_n(float(st.get("skin", 0.0))), "%s cr/m" % _n(o.cost), "%s kg/m" % _n(o.mass)])
		var attrs: Array = [["What it is", str(FRAME_PIECES.get(key, ""))], ["Kit name", key]]
		if key == "HullPlate" or key == "CapPlate":
			for h: String in hulls:
				var o: Dictionary = hulls[h]
				attrs.append([str(o.name), "%s cr, %s kg, %s h per m²" % [_n(o.cost), _n(o.mass), _n(o.hours)]])
		_add({"id": "frame." + key, "name": str(DesignFrame.PART_NAMES[key]), "group": FRAME_GROUP,
				"text": str(FRAME_PIECES.get(key, "")), "attrs": attrs, "cols": cols if not skin else [], "rows": rows if not skin else []})
	for kind: String in DesignStructure.OPTIONS:
		var opts: Dictionary = DesignStructure.OPTIONS[kind]
		for id: String in opts:
			var o: Dictionary = opts[id]
			var per := "m" if kind == "frame" else "m²"
			var attrs: Array = [["Price", "%s cr per %s" % [_n(o.cost), per]], ["Mass", "%s kg per %s" % [_n(o.mass), per]],
					["Fitting time", "%s h per %s" % [_n(o.hours), per]]]
			if kind == "frame":
				var st: Dictionary = FrameStyle.STYLES.get(str(DesignFrame.STYLES.get(id, "channel")), {})
				var member: Vector2 = st.get("member", Vector2.ZERO)
				attrs.append(["Girder section", "%.2f x %.2f m" % [member.x, member.y]])
				attrs.append(["Node blocks", "%s m" % _n(float(st.get("node", 0.0)))])
				attrs.append(["Hull skin", "%s m thick" % _n(float(st.get("skin", 0.0)))])
			_add({"id": "structure.%s.%s" % [kind, id], "name": str(o.name), "group": FRAME_GROUP,
					"text": "A choice for the whole ship in the design's structure settings.", "attrs": attrs, "cols": [], "rows": []})
	for j: Dictionary in [DesignFrame.WELD, DesignFrame.RIVET, DesignFrame.BOLT]:
		_add({"id": "joint." + str(j.name).to_lower().replace(" ", "_"), "name": str(j.name), "group": FRAME_GROUP,
				"text": "Each joint the yard makes.", "attrs": [["Price", "%s cr each" % _n(j.cost)],
				["Mass", "%s kg each" % _n(j.mass)], ["Time", "%s h each" % _n(j.hours)]], "cols": [], "rows": []})


func _rooms_of(p: DesignPartType) -> String:
	if p.hull_mount:
		return "outside, on the hull"
	if p.rooms.is_empty():
		return "any room"
	var names: PackedStringArray = []
	for id in p.rooms:
		var r := catalog.room(id)
		names.append(r.display_name if r else id)
	return ", ".join(names)


func _field(p: DesignPartType, f: String) -> Array:
	var spec: Array = FIELD_NAMES.get(f, [f.capitalize(), ""])
	var v := float(p.get(f))
	return [str(spec[0]), ("%s %s" % [_n(v), spec[1]]).strip_edges()]


static func _n(v: Variant) -> String:
	var f := float(v)
	if is_equal_approx(f, roundf(f)) and absf(f) < 1e7:
		var s := str(int(roundf(f)))
		if absf(f) >= 10000.0:
			var neg := s.begins_with("-")
			s = s.trim_prefix("-")
			var out := ""
			while s.length() > 3:
				out = "," + s.substr(s.length() - 3) + out
				s = s.substr(0, s.length() - 3)
			s = ("-" if neg else "") + s + out
		return s
	if absf(f) >= 100.0:
		return str(roundi(f))
	if absf(f) >= 1.0:
		return "%.1f" % f
	return "%.2f" % f
