extends RefCounted
## Builds a ShipDefinition from a ship's folder:
##   <name>.vsship.json     the ship as Void Salvage exported it (vsship 2.0): its slots, parts
##                          and joints with their paths. A slot's joints are the file's joints
##                          on the slot's parts ("slot:<id>/...").
##   <name>_fasteners.json  BSX's own data on top: joints for the slots whose part the file
##                          doesn't carry (a module fitted later), what a slot's spot welds
##                          are made as in the yard ("spots"), joints BSX adds ("extra"), and
##                          file parts BSX treats as replaceable fittings ("fittings", and
##                          "skin": every riveted outer plate; "frame": every frame member
##                          by its frame welds)
##   <name>.tscn            the model, which builds the ship from the same file

## Void Salvage joint kinds as BSX's trades work them: a spot weld is a short weld.
const KINDS := {"spot": "weld", "weld": "weld", "bolt": "bolt", "rivet": "rivet", "connector": "connector"}
## Id letters per BSX kind ("eng_port/w1").
const LETTERS := {"weld": "w", "bolt": "b", "rivet": "r", "connector": "p"}
## What a file joint is made with, by kind: the bolts that hold units to pipes and decks are
## M10s; connectors carry power (a lead from the loom).
const SPECS := {"bolt": "M10", "rivet": "RIVET_4", "weld": "", "connector": "power"}
## A spot weld's bead, metres: along and across.
const SPOT_SIZE := Vector2(0.04, 0.012)
## The file's work sides as BSX names them.
const ACCESS := {"hold": "inboard", "cabin": "inboard", "outboard": "outboard", "inboard": "inboard",
		"below": "below", "above": "above"}


static func load_ship(dir: String) -> ShipDefinition:
	var name := dir.get_file()
	var f := ship_file(dir)
	if f.is_empty():
		return null
	var def := from_file(f, "vs_" + name, _read_json(dir.path_join(name + "_fasteners.json")))
	if def == null:
		return null
	var model_path := dir.path_join(name + ".tscn")
	if ResourceLoader.exists(model_path):
		def.model = load(model_path)
	return def


## BSX's rules for a ship that has no folder of its own (a generated wreck): every riveted
## outer plate, every frame member and every other part held by joints is a fitting with its
## own joints, so every weld, bolt and rivet still on the ship can be worked.
const WRECK_RULES := {
	"skin": {"under": "/skin/", "prefix": "plate_", "name": "Hull plate", "accepts": ["HullPlate"], "fitted": "HullPlate", "access": "outboard"},
	"frame": {"phase": "frame", "prefix": "frame_", "access": "inboard"},
	"rest": {"prefix": "part_", "access": "inboard", "unhide": true},
}


## The definition of the ship in file `f` (vsship 2.x) under `bsx`'s rules (a
## <name>_fasteners.json's data, or WRECK_RULES), with no model. A wreck's damage counts:
## parts gone or cut off it have no slots and their joints no fasteners, and its broken
## joints start undone (`loose`). Null when the file isn't 2.x.
static func from_file(f: Dictionary, ship_id: String, bsx: Dictionary) -> ShipDefinition:
	var version: Variant = f.get("version", [])
	if not (version is Array and int(version[0]) == 2):
		push_error("ShipBay: %s is vsship %s, not 2.x" % [ship_id, str(version)])
		return null
	var own: Dictionary = bsx.get("slots", {})
	var spots: Dictionary = bsx.get("spots", {})
	var extra: Dictionary = bsx.get("extra", {})
	var def := ShipDefinition.new()
	def.version = int(version[0])
	def.ship_id = ship_id
	var ship: Dictionary = f.get("ship", {})
	def.display_name = ship.get("name", ship_id)
	var gen: Dictionary = f.get("generator", {})
	def.source = "%s %s, design %s" % [gen.get("app", "void-salvage"), gen.get("version", "?"), ship.get("id", ship_id)]
	def.bounds = _box(f.get("derived", {}).get("bounds", {}))
	var layout: Dictionary = f.get("layout", {})
	var rooms: Array = layout.get("rooms", [])
	for i in rooms.size():
		var b := _box(rooms[i])
		def.rooms["room_%d" % i] = Vector2(b.position.z, b.end.z)
	var by_slot := joints_by_slot(f)
	var part_boxes := {}
	for p: Dictionary in f.get("parts", []):
		var path: String = p.get("path", "")
		if path.begins_with("slot:"):
			var id := path.trim_prefix("slot:").get_slice("/", 0)
			var b := _box(p.get("box", {}))
			part_boxes[id] = (part_boxes[id] as AABB).merge(b) if part_boxes.has(id) else b
	for entry: Dictionary in f.get("slots", []):
		var s := _slot(entry)
		if part_boxes.has(s.slot_id):
			s.box = s.box.merge(part_boxes[s.slot_id])   # the slot's box can be smaller than its part
		for p: Dictionary in f.get("parts", []):
			if str(p.get("path", "")).begins_with("slot:%s/" % s.slot_id):
				s.parts.append(p["path"])
		var joints: Array = by_slot.get(s.slot_id, [])
		if joints.is_empty():
			for j: Dictionary in own.get(s.slot_id, []):
				s.fasteners.append(_own_fastener(s.slot_id, j))
		else:
			var counts := {}
			for j: Dictionary in joints:
				s.fasteners.append(_file_fastener(s.slot_id, j, counts, spots.get(s.slot_id, {})))
			for j: Dictionary in extra.get(s.slot_id, []):
				s.fasteners.append(_own_fastener(s.slot_id, j))
		if not entry.get("mount", {}).has("b") and not s.fasteners.is_empty():
			s.mount = _facing(s.fasteners[0].normal, s.mount.origin)
		def.slots.append(s)
	var fitted_parts := {}
	var recs := {}
	for p: Dictionary in f.get("parts", []):
		recs[str(p.get("path", ""))] = p
	var seen := inside_seen(f)
	for entry: Dictionary in bsx.get("fittings", []):
		var s := _fitting_slot(entry, f, recs, seen)
		if s:
			def.slots.append(s)
			fitted_parts[entry.get("part", "")] = true
	if bsx.has("skin"):
		for entry: Dictionary in _skin_fittings(bsx["skin"], f, fitted_parts):
			var s := _fitting_slot(entry, f, recs, seen)
			if s:
				def.slots.append(s)
	if bsx.has("frame"):
		for s: MountSlot in _frame_fittings(bsx["frame"], f, seen):
			def.slots.append(s)
	if bsx.has("rest"):
		for s: MountSlot in _rest_fittings(bsx["rest"], f, def.slots, seen):
			def.slots.append(s)
	_apply_damage(def, f)
	return def


## The file as data (an imported JSON resource, so it is in exported builds too), {} when it
## can't be read.
static func read_file(path: String) -> Dictionary:
	return _read_json(path)


## The ship file for a ship folder: Shared Components' pinned Void Salvage export of that
## design (VsShipImport.design_source), or a <name>.vsship.json of BSX's own in the folder.
static func ship_file(dir: String) -> Dictionary:
	var name := dir.get_file()
	var own := dir.path_join(name + ".vsship.json")
	if FileAccess.file_exists(own):
		return read_file(own)
	return VsShipImport.design_source(name)


## Slot id -> the file's joints on that slot's parts, in file order.
static func joints_by_slot(f: Dictionary) -> Dictionary:
	var out := {}
	for j: Dictionary in f.get("joints", []):
		for end: String in ["a", "b"]:
			var p: String = j.get(end, "")
			if p.begins_with("slot:"):
				(out.get_or_add(p.trim_prefix("slot:").get_slice("/", 0), []) as Array).append(j)
				break
	return out


static func _slot(e: Dictionary) -> MountSlot:
	var s := MountSlot.new()
	s.slot_id = e.get("slot_id", "")
	s.display_name = e.get("display_name", s.slot_id)
	s.accepts = PackedStringArray(e.get("accepts", []))
	s.fitted = str(e["fitted"]) if e.get("fitted") != null else ""
	s.access = ACCESS.get(e.get("access", "inboard"), "inboard")
	s.box = _box(e.get("box", {}))
	var mount: Dictionary = e.get("mount", {})
	var origin := _vec(mount.get("o", [0, 0, 0]))
	s.mount = VsShipImport.xform(mount) if mount.has("b") else _facing(Vector3.BACK, origin)
	return s


## A mount whose basis Z points out of the mounting face along `facing`.
static func _facing(facing: Vector3, origin: Vector3) -> Transform3D:
	var z := facing.normalized()
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	var x := up.cross(z).normalized()
	return Transform3D(Basis(x, z.cross(x), z), origin)


## Every riveted outer plate of the hull (parts whose path has `rule.under`, "/skin/") as a
## fitting of its own, so its rivets can be heated out and the plate lifted off: slot
## "<prefix><body>_<edge>" ("plate_cabin_e3"), named "Hull plate (cabin, e3)". Plates already
## listed in "fittings" keep their own entry.
static func _skin_fittings(rule: Dictionary, f: Dictionary, taken: Dictionary) -> Array:
	var riveted := {}
	for j: Dictionary in f.get("joints", []):
		if str(j.get("kind", "")) == "rivet":
			riveted[j.get("a", "")] = true
			riveted[j.get("b", "")] = true
	var under: String = rule.get("under", "/skin/")
	var out: Array = []
	for p: Dictionary in f.get("parts", []):
		var path: String = p.get("path", "")
		if not under in path or taken.has(path) or not riveted.has(path):
			continue
		var head := path.get_slice(under, 0)   # "hull/bay:cabin"
		var body := head.get_slice(":", 1) if ":" in head else head.get_slice("/", 0)
		if not head.begins_with("hull/"):
			body = head.get_slice("/", 0) + "_" + body
		var edge := path.get_slice(under, 1).replace("/", "_")
		out.append({"slot_id": "%s%s_%s" % [rule.get("prefix", "plate_"), body, edge],
				"display_name": "%s (%s, %s)" % [rule.get("name", "Hull plate"), body.replace("_", " "), edge],
				"part": path, "accepts": rule.get("accepts", ["HullPlate"]), "fitted": rule.get("fitted", "HullPlate"),
				"access": rule.get("access", "outboard")})
	return out


## Every frame member (ring, stringer, node, post, rail) with welds of `rule.phase` ("frame")
## as a fitting of its own, holding just those welds (each weld goes to its joint's `a` end,
## so no weld is in two slots; rivets and bolts onto the member stay with the plates and
## linings they hold): slot "<prefix><body>_<member>" ("frame_cockpit_wall_ring_e0").
static func _frame_fittings(rule: Dictionary, f: Dictionary, seen: Dictionary) -> Array[MountSlot]:
	var phase: String = rule.get("phase", "frame")
	var welds := {}
	var order: Array = []
	for j: Dictionary in f.get("joints", []):
		if str(j.get("kind", "")) != "weld" or str(j.get("phase", "")) != phase:
			continue
		var a: String = j.get("a", "")
		if not welds.has(a):
			welds[a] = []
			order.append(a)
		(welds[a] as Array).append(j)
	var recs := {}
	var all_recs := {}
	for p: Dictionary in f.get("parts", []):
		all_recs[str(p.get("path", ""))] = p
		if welds.has(p.get("path", "")):
			recs[p["path"]] = p
	var out: Array[MountSlot] = []
	for path: String in order:
		if not recs.has(path):
			continue
		var rec: Dictionary = recs[path]
		# "hull/st:cockpit_wall/ring/e0" -> body "cockpit_wall", member "ring_e0".
		var bits := path.split("/")
		var body := bits[1].get_slice(":", 1) if bits.size() > 1 and ":" in bits[1] else bits[0]
		if bits[0] != "hull" and body != bits[0]:
			body = bits[0] + "_" + body   # a second hull's ("nacelle_l/st:n0" -> "nacelle_l_n0")
		var member := "_".join(bits.slice(2)) if bits.size() > 2 else path.replace("/", "_")
		var s := MountSlot.new()
		s.slot_id = "%s%s_%s" % [rule.get("prefix", "frame_"), body, member]
		s.display_name = "%s (%s, %s)" % [rec.get("name", "Frame"), body.replace("_", " "), member.replace("_", " ")]
		s.accepts = PackedStringArray([rec.get("name", "")])
		s.fitted = str(rec.get("name", ""))
		s.access = rule.get("access", "inboard")
		s.box = _box(rec.get("box", {}))
		s.parts = PackedStringArray([path])
		var counts := {}
		for j: Dictionary in welds[path]:
			s.fasteners.append_array(_bolted_inside(s.slot_id, j, counts, all_recs, seen))
		s.mount = _facing(s.fasteners[0].normal, s.box.get_center())
		out.append(s)
	return out


## Every other part with joints not yet in a slot (decks, walls, linings, fittings and units),
## a fitting holding those joints (each by its `a` end, or its `b` end when `a` has no part
## record): slot "<prefix><path>" ("part_deck_0_plate_3"), named by the part.
static func _rest_fittings(rule: Dictionary, f: Dictionary, taken: Array[MountSlot], seen: Dictionary) -> Array[MountSlot]:
	var covered := {}
	for s: MountSlot in taken:
		for p in s.fasteners:
			covered[p.path] = true
	var recs := {}
	for p: Dictionary in f.get("parts", []):
		recs[str(p.get("path", ""))] = p
	var joints := {}
	var order: Array = []
	for j: Dictionary in f.get("joints", []):
		if covered.has(str(j.get("path", ""))):
			continue
		var at := str(j.get("a", "")) if recs.has(str(j.get("a", ""))) else str(j.get("b", ""))
		if not recs.has(at):
			continue
		if not joints.has(at):
			joints[at] = []
			order.append(at)
		(joints[at] as Array).append(j)
	var out: Array[MountSlot] = []
	for path: String in order:
		var rec: Dictionary = recs[path]
		var s := MountSlot.new()
		s.slot_id = str(rule.get("prefix", "part_")) + path.replace("/", "_").replace(":", "_")
		var where := path.get_slice("/", 1).get_slice(":", 1) if ":" in path.get_slice("/", 1) else path.get_slice("/", 0)
		s.display_name = "%s (%s)" % [rec.get("name", "Part"), where.replace("_", " ")]
		s.accepts = PackedStringArray([rec.get("name", "")])
		s.fitted = str(rec.get("name", "Part"))
		s.access = rule.get("access", "inboard")
		s.box = _box(rec.get("box", {}))
		s.parts = PackedStringArray([path])
		var counts := {}
		for j: Dictionary in joints[path]:
			for fp in _bolted_inside(s.slot_id, j, counts, recs, seen):
				if bool(rule.get("unhide", false)) and unhides(path):
					_out_from_under(fp, s.box)
				s.fasteners.append(fp)
		s.mount = _facing(s.fasteners[0].normal, s.box.get_center())
		out.append(s)
	return out


## Inside floors and walls are bolted down (beenster, 0.3.31: "the internal walls and floors
## should be bolted but there didn't seem to be as many"). Void Salvage welds most partitions
## and some deck plates, and holds a wall panel by a bolt or two. In a ship's frame and
## rest fittings (flag ship_bay.bolted_inside) a weld or spot weld on such a panel is a row of bolts along
## its seam, one every BOLT_PITCH, and a panel held by fewer than FEW_BOLTS bolts has each
## edge bolt it has repeated along that edge. The extra bolts ("<slot>/x<n>", meta "copy")
## share their file joint, so they start undone with it; a weld made bolts has meta "inside"
## (the bay hides its Void Salvage bead). Rivets and connectors stay as they are.
const INSIDE_NAMES := ["DeckPlate", "WallPanel", "WallLining", "InnerPanel", "Partition", "Grating"]
const INSIDE_ENDINGS := ["Wall", "Floor"]
const BOLT_PITCH := 0.4      # m between bolts along a seam or edge
const BOLT_INSET := 0.06     # m in from a panel's corner to its end bolts
const EDGE_BAND := 0.2       # how near an edge (share of the panel's size) a bolt must be
const FEW_BOLTS := 4         # a panel with fewer file bolts gets its edge bolts repeated
const MAX_ROW := 10          # most bolts one seam or edge gets
const PANEL_SLACK := 0.03    # m outside a panel's box a bolt on it may sit
const MIN_GAP := 0.12        # m an extra bolt keeps from the panel's other bolts


static func is_inside_panel(rec: Dictionary) -> bool:
	if str(rec.get("category", "")) == "frame":
		return false
	var name := str(rec.get("name", ""))
	if name in INSIDE_NAMES:
		return true
	for e: String in INSIDE_ENDINGS:
		if name.ends_with(e):
			return true
	return false


## File joint `j` as the slot's fasteners: just `_file_fastener`'s, or bolts when it holds an
## inside floor or wall (above). `recs`: part path -> record; `seen` keeps, per panel, its
## file bolts and the edges already repeated, across the slots of one ship.
static func _bolted_inside(slot_id: String, j: Dictionary, counts: Dictionary, recs: Dictionary, seen: Dictionary) -> Array[FastenerPoint]:
	var fp := _file_fastener(slot_id, j, counts)
	var out: Array[FastenerPoint] = [fp]
	if not Flags.is_on("ship_bay.bolted_inside") or not fp.kind in ["weld", "bolt"]:
		return out
	var panel := {}
	for end: String in ["b", "a"]:
		var rec: Dictionary = recs.get(str(j.get(end, "")), {})
		if not rec.is_empty() and is_inside_panel(rec):
			panel = rec
			break
	if panel.is_empty():
		return out
	var info: Dictionary = seen.get_or_add(str(panel.get("path", "")), {"bolts": 0, "edges": {}})
	var spots: Array[Vector3] = []
	if fp.kind == "weld":
		var length := maxf(fp.seam_size.x, 0.0)
		var along := fp.seam_up.normalized()
		var n := clampi(int(round(length / BOLT_PITCH)), 1, MAX_ROW)
		var centre := fp.position
		# A seam can run on past the panel (a bulkhead's foot across several deck plates):
		# only the bolts over this panel.
		var on := _box(panel.get("box", {})).grow(PANEL_SLACK)
		for k in n:
			var p := centre + along * ((float(k) + 0.5) * length / n - length * 0.5)
			if on.has_point(p):
				spots.append(p)
		if spots.is_empty():
			spots.append(centre)
		fp.kind = "bolt"
		fp.spec = SPECS["bolt"]
		fp.seam_up = Vector3.ZERO
		fp.seam_size = Vector2.ZERO
		fp.position = spots[0]
		fp.set_meta("inside", true)
	elif int(info["bolts"]) < FEW_BOLTS:
		spots = [fp.position]
		spots.append_array(_along_edge(fp, _box(panel.get("box", {})), info))
	var taken: Array = info.get_or_add("at", [])
	taken.append(fp.position)
	for k in range(1, spots.size()):
		# Not on top of a bolt the panel already has (two seams meeting at a corner).
		if taken.any(func(q: Vector3) -> bool: return q.distance_to(spots[k]) < MIN_GAP):
			continue
		taken.append(spots[k])
		var x := FastenerPoint.new()
		x.kind = "bolt"
		x.spec = SPECS["bolt"]
		x.normal = fp.normal
		x.position = spots[k]
		x.path = fp.path
		counts["x"] = int(counts.get("x", 0)) + 1
		x.joint_id = "%s/x%d" % [slot_id, counts["x"]]
		x.set_meta("copy", true)
		out.append(x)
	return out


## `_bolted_inside`'s `seen` for ship file `f`: each part's file bolts, counted up front.
static func inside_seen(f: Dictionary) -> Dictionary:
	var out := {}
	for j: Dictionary in f.get("joints", []):
		if str(j.get("kind", "")) != "bolt":
			continue
		for end: String in ["a", "b"]:
			var info: Dictionary = out.get_or_add(str(j.get(end, "")), {"bolts": 0, "edges": {}})
			info["bolts"] = int(info["bolts"]) + 1
	return out


## More bolts along the panel edge that file bolt `fp` sits by: the panel's box must lie flat
## to an axis the bolt faces down, and the bolt within EDGE_BAND of one edge across the row.
## None when the bolt sits mid-panel or the edge already has its row.
static func _along_edge(fp: FastenerPoint, box: AABB, info: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var na := fp.normal.abs().max_axis_index()
	if absf(fp.normal[na]) < 0.98:
		return out
	var best := -1
	for s: int in [(na + 1) % 3, (na + 2) % 3]:
		var o := 3 - na - s
		if box.size[o] <= 0.0 or box.size[s] < BOLT_PITCH * 2.0:
			continue
		var rel := (fp.position[o] - box.position[o]) / box.size[o]
		if rel > EDGE_BAND and rel < 1.0 - EDGE_BAND:
			continue
		if best < 0 or box.size[s] > box.size[best]:
			best = s
	if best < 0:
		return out
	var other := 3 - na - best
	var key := "%d:%d" % [best, int(round(fp.position[other] * 20.0))]
	if (info["edges"] as Dictionary).has(key):
		return out
	info["edges"][key] = true
	var a := box.position[best] + BOLT_INSET
	var b := box.end[best] - BOLT_INSET
	var n := clampi(int(floor((b - a) / BOLT_PITCH)) + 1, 2, MAX_ROW)
	for k in n:
		var p := fp.position
		p[best] = lerpf(a, b, float(k) / float(n - 1))
		if absf(p[best] - fp.position[best]) > BOLT_PITCH * 0.5:
			out.append(p)
	return out


## Void Salvage bolts a seat, console or locker down by one bolt in the middle of its foot,
## hidden under the part itself, so nobody could see how it came off (beenster, 0.3.27). A
## bolt under its part (on the floor of a box standing at least STANDS_OFF tall, inside its
## footprint) is moved out past the box's side that faces the ship's
## middle (inboard, where you stand to work it), at the same height: the joint is the same,
## only where you find it. Welds, rivets and beam ends stay put. Wrecks only
## (WRECK_RULES "rest" unhide).
const UNDER_MARGIN := 0.03      # m in from the box's sides that counts as under it
const OUT_FROM_UNDER := 0.05    # m outside the box the fastener goes
const STANDS_OFF := 0.15        # m a part must stand out along the normal to hide a joint


## Parts whose hidden bolts are moved out: fitted furniture, units and tanks.
static func unhides(path: String) -> bool:
	return path.begins_with("component/") or path.begins_with("hazard/")


static func is_under(f: FastenerPoint, box: AABB) -> bool:
	# A bolt down through a standing part's foot onto a deck (up or down): the part stands at
	# least STANDS_OFF tall over a footprint at least that wide both ways (not a beam's end).
	var n := f.normal.abs().max_axis_index()
	if f.kind != "bolt" or n != Vector3.AXIS_Y or box.size.y < STANDS_OFF or minf(box.size.x, box.size.z) < STANDS_OFF:
		return false
	if absf(f.position[n] - box.position[n]) > UNDER_MARGIN and absf(f.position[n] - box.end[n]) > UNDER_MARGIN:
		return false
	for a in 3:
		if a != n and (f.position[a] <= box.position[a] + UNDER_MARGIN or f.position[a] >= box.end[a] - UNDER_MARGIN):
			return false
	return true


static func _out_from_under(f: FastenerPoint, box: AABB) -> void:
	if not is_under(f, box):
		return
	var n := f.normal.abs().max_axis_index()
	var sides: Array[int] = []
	for a in 3:
		if a != n:
			sides.append(a)
	var best := Vector3.INF
	for a in sides:
		for end: float in [box.position[a] - OUT_FROM_UNDER, box.end[a] + OUT_FROM_UNDER]:
			var p := f.position
			p[a] = end
			# Inboard: nearest the ship's centre line (x, y 0), then its middle along z.
			if best == Vector3.INF or Vector2(p.x, p.y).length() + absf(p.z) * 0.01 < Vector2(best.x, best.y).length() + absf(best.z) * 0.01 - 0.001:
				best = p
	f.position = best


## A wreck's damage (the file's "damage" block, WreckMaker): slots whose parts are all gone or
## cut off go, fasteners on joints to such parts go, slots left with none go, and the broken
## joints left are `loose` (undone, ready to make again).
static func _apply_damage(def: ShipDefinition, f: Dictionary) -> void:
	var d: Dictionary = f.get("damage", {}) if f.get("damage") is Dictionary else {}
	if d.is_empty():
		return
	var off := {}
	var dparts: Dictionary = d.get("parts", {})
	for path: String in dparts:
		if str((dparts[path] as Dictionary).get("state", "attached")) != "attached":
			off[path] = true
	var dead := {}
	var broken := {}
	var djoints: Dictionary = d.get("joints", {})
	for j: Dictionary in f.get("joints", []):
		var path := str(j.get("path", ""))
		if off.has(str(j.get("a", ""))) or off.has(str(j.get("b", ""))):
			dead[path] = true
		elif bool((djoints.get(path, {}) as Dictionary).get("broken", false)):
			broken[path] = true
	var kept: Array[MountSlot] = []
	for s: MountSlot in def.slots:
		if not s.parts.is_empty() and Array(s.parts).all(func(p: String) -> bool: return off.has(p)):
			continue
		var fasteners: Array[FastenerPoint] = []
		for p in s.fasteners:
			if dead.has(p.path):
				continue
			fasteners.append(p)
			if broken.has(p.path):
				def.loose.append(p.joint_id)
		if fasteners.is_empty():
			continue
		s.fasteners = fasteners
		kept.append(s)
	def.slots = kept


## A file part BSX treats as a replaceable fitting (a hull plate): its slot, box and joints
## (every file joint on the part) from the file. Null when the file has no such part.
static func _fitting_slot(e: Dictionary, f: Dictionary, recs: Dictionary, seen: Dictionary) -> MountSlot:
	var path: String = e.get("part", "")
	var rec: Dictionary = recs.get(path, {})
	if rec.is_empty():
		push_error("ShipBay: fitting %s names no part %s" % [e.get("slot_id", ""), path])
		return null
	var s := MountSlot.new()
	s.slot_id = e.get("slot_id", "")
	s.display_name = e.get("display_name", s.slot_id)
	s.accepts = PackedStringArray(e.get("accepts", []))
	s.fitted = e.get("fitted", "")
	s.access = e.get("access", "outboard")
	s.box = _box(rec.get("box", {}))
	s.parts = PackedStringArray([path])
	var counts := {}
	for j: Dictionary in f.get("joints", []):
		if j.get("a", "") == path or j.get("b", "") == path:
			s.fasteners.append_array(_bolted_inside(s.slot_id, j, counts, recs, seen))
	s.mount = _facing(s.fasteners[0].normal if not s.fasteners.is_empty() else Vector3.BACK, s.box.get_center())
	return s


## `spot` says what the slot's spot welds are made as in the yard: {kind, spec} ({} keeps
## them welds).
static func _file_fastener(slot_id: String, j: Dictionary, counts: Dictionary, spot: Dictionary = {}) -> FastenerPoint:
	var f := FastenerPoint.new()
	f.kind = KINDS.get(str(j.get("kind", "weld")), "weld")
	if str(j.get("kind", "")) == "spot" and spot.has("kind"):
		f.kind = str(spot["kind"])
	counts[f.kind] = int(counts.get(f.kind, 0)) + 1
	f.joint_id = "%s/%s%d" % [slot_id, LETTERS[f.kind], counts[f.kind]]
	f.path = j.get("path", "")
	f.spec = str(spot.get("spec", SPECS[f.kind])) if spot.has("kind") and str(j.get("kind", "")) == "spot" else SPECS[f.kind]
	f.position = _vec(j.get("at", [0, 0, 0]))
	f.normal = _vec(j.get("normal", [0, 1, 0])).normalized()
	if f.kind == "weld":
		var up := _vec(j["seam_up"]) if j.has("seam_up") else Vector3.ZERO
		if up.length() < 0.5:
			up = f.normal.cross(Vector3.UP if absf(f.normal.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT)
		f.seam_up = up.normalized()
		var size: Variant = j.get("seam_size")
		f.seam_size = Vector2(float(size[0]), float(size[1])) if size is Array and float(size[0]) > 0.0 else SPOT_SIZE
	return f


static func _own_fastener(slot_id: String, j: Dictionary) -> FastenerPoint:
	var f := FastenerPoint.new()
	f.joint_id = "%s/%s" % [slot_id, j.get("id", "")]
	f.kind = j.get("kind", "bolt")
	f.spec = j.get("spec", "")
	f.position = _vec(j.get("at", [0, 0, 0]))
	f.normal = _vec(j.get("normal", [0, 1, 0])).normalized()
	if j.has("seam_up"):
		f.seam_up = _vec(j["seam_up"]).normalized()
		var size: Array = j.get("seam_size", [0, 0])
		f.seam_size = Vector2(float(size[0]), float(size[1]))
	return f


static func _read_json(path: String) -> Dictionary:
	var res := load(path) as JSON if ResourceLoader.exists(path) else null
	if res == null or not res.data is Dictionary:
		push_error("ShipBay: can't read %s" % path)
		return {}
	return res.data


static func _vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## A file box {pos, size}.
static func _box(d: Dictionary) -> AABB:
	return AABB(_vec(d.get("pos", [0, 0, 0])), _vec(d.get("size", [0, 0, 0])))
