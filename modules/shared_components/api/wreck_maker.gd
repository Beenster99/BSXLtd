class_name WreckMaker
extends RefCounted
## Makes a wreck out of a vsship 2.0 file: the same ship with a `damage` block saying what
## the events did to it, part by part and joint by joint, so BSX can put wrecks in the yard
## before Void Salvage sends real wreck files. The events follow Void Salvage's own wreck
## events (WreckEvents: weathered, impact, fire, stripped) in their numbers and their rolls, on
## the file's data alone (no scene): a part is its `xform` and `box`, a joint its two ends.
##
##   var wreck := WreckMaker.make(file, 84, [["fire", 3], ["stripped", 1]])
##   VsShipImport.new().build(wreck, body)   # builds what is left, scorched and worn
##
## The block (keyed by path, as BSX asked Void Salvage for in docs/shared/BSX_VSSHIP2_FEEDBACK.md):
##   damage: {events: [[name, strength, seed]], seed, parts: {path: {condition: {wear, scorch,
##     scorch_at?, scorch_radius?, dents?: [{at, push, depth, radius, crumple}], bend?},
##     removal: ON THE WRECK | INTACT | FORCED | CUT, state: attached | gone | detached, group?}},
##     joints: {path: {health, max_health, broken, seized?}}}
##   derived_only: true (a reader builds from `parts` and `joints`, never replays the recipe).
## A real vswreck file from Void Salvage carries the same facts, so VsShipImport takes either.

const EVENTS: PackedStringArray = ["weathered", "collision", "fire", "breach", "stripped"]
## Void Salvage's names for the same events (its "impact" is a collision).
const ALIASES := {"impact": "collision", "scraped": "weathered", "torn": "breach", "abandoned": "weathered"}
const STATE_ATTACHED := "attached"
const STATE_GONE := "gone"
const STATE_DETACHED := "detached"

## Parts the events leave alone (doors and their leaves, as Void Salvage protects them).
const PROTECTED_WORDS: PackedStringArray = ["door", "leaf", "hatch", "breaker", "reactor"]
const OUTER_PLATES: PackedStringArray = ["HullPlate", "CapPlate", "NosePlate"]
const INNER_PANELS: PackedStringArray = ["WallPanel", "CeilingPanel", "FloorPanel", "InnerPanel", "DeckPlate"]
## Components heavier than this are left by a stripping (nobody could lift them out), kg.
const STRIPPED_MAX_KG := 8000.0
## A section cut off the wreck weighing under this share of it has drifted off (gone).
const DRIFT_SHARE := 0.15

var _parts: Array[Dictionary] = []        # the file's parts, by id order
var _by_path: Dictionary = {}             # path -> part record
var _joints: Array[Dictionary] = []
var _state: Dictionary = {}               # part path -> its damage entry
var _jstate: Dictionary = {}              # joint path -> its damage entry
var _rooms: Array = []
var _bounds := AABB()
var _last := {}


## A copy of `file` with the damage of `events` ([[name, strength 1..5, seed?], ...] or
## "fire:3,stripped:1") rolled from `seed`. The ship's own blocks are untouched, so the file
## still checks out (both hashes hold); `damage` and `derived_only` are added.
static func make(file: Dictionary, seed_value: int, events: Variant) -> Dictionary:
	var list := parse_events(events)
	var out := file.duplicate(true)
	var maker := WreckMaker.new()
	maker._load(file)
	var noted: Array = []
	for i in list.size():
		var e: Array = list[i]
		var s: int = int(e[1])
		var event_seed: int = int(e[2]) if e.size() > 2 else seed_value + 31 * i
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([event_seed, e[0], s])
		maker._last = {}
		match str(e[0]):
			"weathered": maker._weathered(s, rng)
			"collision": maker._collision(s, rng)
			"fire": maker._fire(s, rng)
			"breach": maker._breach(s, rng)
			"stripped": maker._stripped(s, rng)
		var note := [str(e[0]), s, event_seed]
		if not maker._last.is_empty():
			note.append(maker._last)
		noted.append(note)
	maker._drift()
	# Encoded as the file writes it (vectors as lists, numbers to 4 places), so the block in
	# memory is the block on disk.
	out["damage"] = ShipRecorder.encode({"events": noted, "seed": seed_value, "parts": maker._state, "joints": maker._jstate})
	out["derived_only"] = true
	var ship: Dictionary = out.get("ship", {})
	ship["wreck"] = true
	out["ship"] = ship
	return out


## "fire:3,stripped:1:84" -> [["fire", 3], ["stripped", 1, 84]]; a list goes through as is,
## names mapped by ALIASES, unknown ones dropped, strengths clamped to 1..5.
static func parse_events(events: Variant) -> Array:
	var raw: Array = []
	if events is String:
		for piece: String in (events as String).split(",", false):
			var bits := piece.strip_edges().split(":")
			var one: Array = [bits[0]]
			one.append(int(bits[1]) if bits.size() > 1 else 2)
			if bits.size() > 2:
				one.append(int(bits[2]))
			raw.append(one)
	elif events is Array:
		raw = events
	var out: Array = []
	for e in raw:
		if not (e is Array) or (e as Array).is_empty():
			continue
		var name: String = ALIASES.get(str(e[0]), str(e[0]))
		if not EVENTS.has(name):
			continue
		var one: Array = [name, clampi(int(e[1]) if e.size() > 1 else 2, 1, 5)]
		if e.size() > 2:
			one.append(int(e[2]))
		out.append(one)
	return out


## The damage a file carries, or {} for a clean ship.
static func damage_of(file: Dictionary) -> Dictionary:
	return file.get("damage", {}) if file.get("damage") is Dictionary else {}


## What is left, for a summary line: {parts, gone, detached, broken, scorched, worn}.
static func summary(file: Dictionary) -> Dictionary:
	var d := damage_of(file)
	var out := {"parts": file.get("parts", []).size(), "gone": 0, "detached": 0, "broken": 0, "scorched": 0, "worn": 0}
	for path: String in d.get("parts", {}):
		var e: Dictionary = d["parts"][path]
		match str(e.get("state", STATE_ATTACHED)):
			STATE_GONE: out["gone"] += 1
			STATE_DETACHED: out["detached"] += 1
		var c: Dictionary = e.get("condition", {})
		if float(c.get("scorch", 0.0)) > 0.05:
			out["scorched"] += 1
		if float(c.get("wear", 0.0)) > 0.05:
			out["worn"] += 1
	for path: String in d.get("joints", {}):
		if bool(d["joints"][path].get("broken", false)):
			out["broken"] += 1
	return out


# --- events ---------------------------------------------------------------------------------

## Age: everything worn, the odd shallow dent in the skin, fasteners loose or missing, a
## panel or two adrift, a plate sprung up on one rivet.
func _weathered(s: int, rng: RandomNumberGenerator) -> void:
	var f := float(s)
	for p in _parts:
		_wear(p, 0.08 + 0.13 * f + rng.randf() * 0.18)
	for p in _parts:
		if _named(p, OUTER_PLATES) and rng.randf() < 0.04 * f:
			var x := VsShipImport.xform(p.get("xform", {}))
			var spot := x * Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.5, 0.5))
			_dent(p, spot, -x.basis.y.normalized(), rng.randf_range(0.015, 0.035) * (0.7 + 0.3 * f),
					rng.randf_range(0.35, 0.7), 0.0)
	var by_part := _fasteners_by_part()
	for p in _parts:
		if _protected(p) or not by_part.has(p["path"]):
			continue
		var fasteners: Array = by_part[p["path"]]
		if _named(p, INNER_PANELS) and rng.randf() < 0.03 * f:
			for j: Dictionary in fasteners:
				_break(j)                                  # come adrift
			continue
		if _named(p, OUTER_PLATES) and fasteners.size() > 1 and rng.randf() < 0.02 * f:
			for j: Dictionary in fasteners.slice(1):
				_break(j)                                  # hanging by one rivet
			_set_removal(p, "FORCED")
			continue
		for j: Dictionary in fasteners:
			var r := rng.randf()
			if r < 0.025 * f and fasteners.size() > 2:
				_break(j)                                  # missing
			elif r < 0.09 * f:
				_weaken(j, 0.5)                            # loose


## Something hit the hull: scorch and grime round the hit, plates dented in toward where it
## was going, frame members bent sideways, fasteners near the middle sprung, glass gone, the
## plate it struck torn out at strength 3 and over.
func _collision(s: int, rng: RandomNumberGenerator) -> void:
	var f := float(s)
	var targets: Array[Dictionary] = []
	for p in _parts:
		if _named(p, ["HullPlate"]) and not _protected(p) and _alive(p):
			targets.append(p)
	if targets.is_empty():
		return
	var hit_plate := targets[rng.randi() % targets.size()]
	var x := VsShipImport.xform(hit_plate.get("xform", {}))
	var at := x.origin
	var out := x.basis.y.normalized()
	var tilt := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.35
	var push := (-out + tilt).normalized()
	var radius := 1.6 + 0.7 * f
	var depth := 0.1 + 0.07 * f
	_last = {"at": at, "radius": radius, "push": push, "plate": hit_plate["path"]}
	var by_part := _fasteners_by_part()
	for p in _parts:
		if not _alive(p):
			continue
		var d := maxf(_centre(p).distance_to(at) - _half_size(p) * 0.5, 0.0)
		var reach := radius * 1.6
		if d >= reach:
			continue
		var fall := 1.0 - d / reach
		var hit := fall * rng.randf_range(0.75, 1.15)
		_scorch(p, clampf(hit * 0.55, 0.0, 1.0), at, radius)
		_wear(p, hit * 0.25)
		var box := _box_size(p)
		var is_frame := str(p.get("kind", "")) == "frame"
		if is_frame and d < radius:
			var long := _long_axis(p)
			var sideways := (push - long * push.dot(long)).normalized()
			_bend(p, sideways * (0.04 + 0.035 * f) * hit * (1.0 - d / radius))
		elif not is_frame and box != Vector3.ZERO:
			_dent(p, at, push, depth * hit * (1.0 if _named(p, OUTER_PLATES) else 0.6), radius,
					clampf(hit * hit * f / 4.0, 0.0, 1.0))
		if _protected(p):
			continue
		if str(p.get("kind", "")) == "glass" and d < radius and rng.randf() < hit:
			_gone(p, "FORCED")                             # shattered
			continue
		if by_part.has(p["path"]) and d < radius:
			for j: Dictionary in by_part[p["path"]]:
				if rng.randf() < hit * 0.6:
					_break(j)                              # sprung
				else:
					_weaken(j, 1.0 - 0.4 * hit)
	if s >= 3:
		_gone(hit_plate, "FORCED")                         # torn out and away


## A fire inside: scorch fading from where it started, the outer skin only scorched through,
## panels buckled and fallen, powered parts burnt out, every joint the heat reached weaker.
func _fire(s: int, rng: RandomNumberGenerator) -> void:
	var f := float(s)
	var origin := _inside_origin(rng)
	var radius := 3.0 + 1.6 * f
	var peak := 0.55 + 0.11 * f
	_last = {"origin": origin, "radius": radius}
	var by_part := _fasteners_by_part()
	var heat_of := {}
	for p in _parts:
		if not _alive(p):
			continue
		var d := maxf(_centre(p).distance_to(origin) - _half_size(p), 0.0)
		var heat := clampf((1.0 - d / radius) * peak * rng.randf_range(0.8, 1.2), 0.0, 1.0)
		if heat <= 0.0:
			continue
		if _named(p, OUTER_PLATES):
			heat *= 0.45
		heat_of[p["path"]] = heat
		_scorch(p, heat, origin, radius * 1.2)
		_wear(p, heat * 0.3)
		if _protected(p):
			continue
		if _named(p, INNER_PANELS) and heat > 0.55 and rng.randf() < 0.5 and by_part.has(p["path"]):
			for j: Dictionary in by_part[p["path"]]:
				_break(j)                                  # buckled and fallen
		elif str(p.get("power", "")) == "consumer" and heat > 0.45:
			for j in _joints:
				if str(j.get("kind", "")) == "connector" and (j["a"] == p["path"] or j["b"] == p["path"]):
					_break(j)                              # burnt out
	for j in _joints:
		var heat := maxf(float(heat_of.get(j["a"], 0.0)), float(heat_of.get(j["b"], 0.0)))
		if heat > 0.05:
			_weaken(j, 1.0 - 0.55 * heat)


## A hole in the side: the skin and lining round a point blown out, the frame behind it
## sprung and bent, scorched round the edges.
func _breach(s: int, rng: RandomNumberGenerator) -> void:
	var f := float(s)
	var targets: Array[Dictionary] = []
	for p in _parts:
		if _named(p, OUTER_PLATES) and not _protected(p) and _alive(p):
			targets.append(p)
	if targets.is_empty():
		return
	var centre_plate := targets[rng.randi() % targets.size()]
	var x := VsShipImport.xform(centre_plate.get("xform", {}))
	var at := x.origin
	var out := x.basis.y.normalized()
	var radius := 0.9 + 0.45 * f
	_last = {"at": at, "radius": radius, "out": out, "plate": centre_plate["path"]}
	for p in _parts:
		if not _alive(p):
			continue
		var d := _centre(p).distance_to(at)
		var reach := radius * 2.2
		if d >= reach:
			continue
		var fall := 1.0 - d / reach
		_scorch(p, clampf(fall * 0.7, 0.0, 1.0), at, radius * 1.5)
		_wear(p, fall * 0.3)
		if _protected(p):
			continue
		var kind := str(p.get("kind", ""))
		if d < radius and (_named(p, OUTER_PLATES) or _named(p, INNER_PANELS) or kind == "glass" or kind == "conduit"):
			_gone(p, "FORCED")                             # blown out
		elif kind == "frame" and d < radius * 1.3:
			var long := _long_axis(p)
			var sideways := (out - long * out.dot(long)).normalized()
			_bend(p, sideways * (0.05 + 0.03 * f) * fall)
			for j in _joints_of(p):
				if rng.randf() < fall * 0.7:
					_break(j)
				else:
					_weaken(j, 0.5)
		elif d < radius * 1.6 and _box_size(p) != Vector3.ZERO:
			_dent(p, at, -out, (0.04 + 0.03 * f) * fall, radius, clampf(fall * f / 5.0, 0.0, 1.0))


## Picked over: hull plates and the named components gone (someone took them, intact),
## heavy machines left.
func _stripped(s: int, rng: RandomNumberGenerator) -> void:
	var f := float(s - 1)
	var plates := clampf(0.5 + 0.1 * f, 0.0, 1.0)
	var components := clampf(0.7 + 0.08 * f, 0.0, 1.0)
	var taken := 0
	for p in _parts:
		var r := rng.randf()
		if _protected(p) or not _alive(p):
			continue
		var kind := str(p.get("kind", ""))
		if kind == "hull" and _named(p, OUTER_PLATES) and r < plates:
			_gone(p, "INTACT")
			taken += 1
		elif kind == "component" and float(p.get("mass", 0.0)) <= STRIPPED_MAX_KG and r < components:
			_gone(p, "INTACT")
			taken += 1
	_last = {"taken": taken}


## After the events: what no unbroken joint holds to the heaviest group has come off. Small
## bits have drifted away (gone); a big section is kept, marked detached, with its group.
func _drift() -> void:
	var alive := {}
	for p in _parts:
		if _alive(p):
			alive[p["path"]] = true
	var links := {}
	for j in _joints:
		if _broken(j) or not alive.has(j["a"]) or not alive.has(j["b"]):
			continue
		(links.get_or_add(j["a"], []) as Array).append(j["b"])
		(links.get_or_add(j["b"], []) as Array).append(j["a"])
	var seen := {}
	var groups: Array = []
	for p in _parts:
		var path: String = p["path"]
		if not alive.has(path) or seen.has(path):
			continue
		var group: Array = []
		var stack: Array = [path]
		seen[path] = true
		while not stack.is_empty():
			var cur: String = stack.pop_back()
			group.append(cur)
			for other: String in links.get(cur, []):
				if not seen.has(other):
					seen[other] = true
					stack.append(other)
		groups.append(group)
	groups.sort_custom(func(a: Array, b: Array) -> bool: return _group_mass(a) > _group_mass(b))
	if groups.is_empty():
		return
	var main_mass := _group_mass(groups[0])
	for i in range(1, groups.size()):
		var group: Array = groups[i]
		var drifted := _group_mass(group) < main_mass * DRIFT_SHARE
		for path: String in group:
			var e := _entry(path)
			if drifted:
				e["state"] = STATE_GONE
				if not e.has("removal"):
					e["removal"] = "FORCED"
			else:
				e["state"] = STATE_DETACHED
				e["group"] = i


# --- the file's data ---------------------------------------------------------------------------

func _load(file: Dictionary) -> void:
	_parts.clear()
	for p: Dictionary in file.get("parts", []):
		_parts.append(p)
		_by_path[p.get("path", "")] = p
	_parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", 0)) < int(b.get("id", 0)))
	for j: Dictionary in file.get("joints", []):
		_joints.append(j)
	_rooms = file.get("layout", {}).get("rooms", [])
	var b: Dictionary = file.get("derived", {}).get("bounds", {})
	_bounds = AABB(VsShipImport.vec3(b.get("pos", [-4, -2, -8])), VsShipImport.vec3(b.get("size", [8, 4, 16])))


func _entry(path: String) -> Dictionary:
	if not _state.has(path):
		_state[path] = {"condition": {"wear": 0.0, "scorch": 0.0}, "removal": "ON THE WRECK", "state": STATE_ATTACHED}
	return _state[path]


func _jentry(j: Dictionary) -> Dictionary:
	var path: String = j.get("path", "")
	if not _jstate.has(path):
		var max_health := float(ConnectionData.MAX_HEALTH.get(_jkind(j), 100.0))
		_jstate[path] = {"health": max_health, "max_health": max_health, "broken": false}
	return _jstate[path]


func _jkind(j: Dictionary) -> ConnectionData.Kind:
	var name := str(j.get("kind", "weld")).to_upper()
	return ConnectionData.Kind[name] if ConnectionData.Kind.has(name) else ConnectionData.Kind.WELD


func _alive(p: Dictionary) -> bool:
	return not _state.has(p["path"]) or str(_state[p["path"]].get("state", STATE_ATTACHED)) == STATE_ATTACHED


func _broken(j: Dictionary) -> bool:
	return _jstate.has(j.get("path", "")) and bool(_jstate[j["path"]].get("broken", false))


func _wear(p: Dictionary, amount: float) -> void:
	var c: Dictionary = _entry(p["path"])["condition"]
	c["wear"] = clampf(float(c["wear"]) + amount, 0.0, 1.0)


func _scorch(p: Dictionary, amount: float, at: Vector3, radius: float) -> void:
	if amount <= 0.0:
		return
	var c: Dictionary = _entry(p["path"])["condition"]
	if amount < float(c["scorch"]):
		return
	c["scorch"] = amount
	c["scorch_at"] = at
	c["scorch_radius"] = radius


func _dent(p: Dictionary, at: Vector3, push: Vector3, depth: float, radius: float, crumple: float) -> void:
	var c: Dictionary = _entry(p["path"])["condition"]
	(c.get_or_add("dents", []) as Array).append({"at": at, "push": push, "depth": depth, "radius": radius, "crumple": crumple})


func _bend(p: Dictionary, by: Vector3) -> void:
	if by.length() < 0.001:
		return
	var c: Dictionary = _entry(p["path"])["condition"]
	c["bend"] = by


func _set_removal(p: Dictionary, how: String) -> void:
	_entry(p["path"])["removal"] = how


func _gone(p: Dictionary, how: String) -> void:
	var e := _entry(p["path"])
	e["state"] = STATE_GONE
	e["removal"] = how
	for j in _joints_of(p):
		_break(j)


func _break(j: Dictionary) -> void:
	var e := _jentry(j)
	e["broken"] = true
	e["health"] = 0.0


func _weaken(j: Dictionary, factor: float) -> void:
	var e := _jentry(j)
	if bool(e["broken"]):
		return
	e["max_health"] = float(e["max_health"]) * factor
	e["health"] = minf(float(e["health"]), float(e["max_health"]))


func _joints_of(p: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for j in _joints:
		if j.get("a", "") == p["path"] or j.get("b", "") == p["path"]:
			out.append(j)
	return out


## Rivets and bolts holding each hull part on (path -> [joint]), in id order.
func _fasteners_by_part() -> Dictionary:
	var out := {}
	for j in _joints:
		var kind := str(j.get("kind", ""))
		if kind != "rivet" and kind != "bolt":
			continue
		for end in ["a", "b"]:
			var p: Dictionary = _by_path.get(j.get(end, ""), {})
			if not p.is_empty() and str(p.get("kind", "")) == "hull":
				(out.get_or_add(p["path"], []) as Array).append(j)
				break
	return out


func _group_mass(group: Array) -> float:
	var kg := 0.0
	for path: String in group:
		kg += float((_by_path.get(path, {}) as Dictionary).get("mass", 0.0))
	return kg


## Somewhere inside: a point in one of the layout's rooms, else along the middle of the hull.
func _inside_origin(rng: RandomNumberGenerator) -> Vector3:
	if not _rooms.is_empty():
		var room: Dictionary = _rooms[rng.randi() % _rooms.size()]
		var p := VsShipImport.vec3(room.get("pos", [0, 0, 0]))
		var s := VsShipImport.vec3(room.get("size", [1, 1, 1]))
		return p + Vector3(s.x * rng.randf_range(0.3, 0.7), s.y * rng.randf_range(0.3, 0.6), s.z * rng.randf_range(0.2, 0.8))
	var c := _bounds.get_center()
	return Vector3(c.x, c.y, _bounds.position.z + _bounds.size.z * rng.randf_range(0.25, 0.75))


static func _named(p: Dictionary, names: PackedStringArray) -> bool:
	return names.has(str(p.get("name", "")))


static func _protected(p: Dictionary) -> bool:
	var low := (str(p.get("name", "")) + " " + str(p.get("path", ""))).to_lower()
	for word in PROTECTED_WORDS:
		if low.contains(word):
			return true
	return false


static func _centre(p: Dictionary) -> Vector3:
	var box: Dictionary = p.get("box", {})
	if box.has("pos"):
		return VsShipImport.vec3(box["pos"]) + VsShipImport.vec3(box.get("size", [0, 0, 0])) * 0.5
	return VsShipImport.xform(p.get("xform", {})).origin


static func _box_size(p: Dictionary) -> Vector3:
	var box: Dictionary = p.get("box", {})
	return VsShipImport.vec3(box["size"]) if box.has("size") else Vector3.ZERO


static func _half_size(p: Dictionary) -> float:
	var s := _box_size(p)
	return maxf(s.x, maxf(s.y, s.z)) * 0.5 if s != Vector3.ZERO else 0.5


## The ship-space direction a member runs along (its longest side).
static func _long_axis(p: Dictionary) -> Vector3:
	var s := _box_size(p)
	if s == Vector3.ZERO:
		return Vector3.FORWARD
	if s.x >= maxf(s.y, s.z):
		return Vector3.RIGHT
	return Vector3.UP if s.y >= s.z else Vector3.BACK
