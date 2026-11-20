class_name BuildPlan
extends RefCounted
## A signed-off design broken into the jobs that build it, in order (master plan 5.1): the
## frame, then the plates, the fittings, the wiring and the pipes. Worked out from the design
## built as parts and joints (the blueprint: DesignFrame's frame and skin, plus a part for each
## fitting and each run of wire or pipe), so every joint the finished ship has is made by one job.
##
## A job is a piece of the ship that floats into place as one assembly (a frame ring with its
## node blocks, a bay's stringers, a bay's hull plates, a fitting, a wiring run) and is fixed by
## hand: a few KEY fastenings the crew makes with the tools (a weld, rivets, bolts), the rest
## tacked by the yard's jigs once those are in, at the quality the key ones were made to. That
## keeps a small ship to some fifty jobs rather than four thousand rivets.
##
## jobs: [{id (its place in the order), stage, name, parts (blueprint part ids), key, inner, tack
## (indexes into the blueprint's connections: the hand fastenings; the assembly's own joints,
## made before it floats in; the fixing joints the jigs tack once the key ones are in)}].

## The stages, in build order: id -> {name, verb, hand fastenings a job asks at most}.
const STAGES := {
	"frame": {"name": "Frame", "verb": "Weld the frame", "key": 4},
	"plates": {"name": "Plates and walls", "verb": "Close the hull", "key": 4},
	"fittings": {"name": "Fittings", "verb": "Bolt the fittings down", "key": 4},
	"wiring": {"name": "Wiring", "verb": "Clip the wiring", "key": 2},
	"pipes": {"name": "Pipes", "verb": "Bolt the pipes up", "key": 2},
}
const STAGE_ORDER: PackedStringArray = ["frame", "plates", "fittings", "wiring", "pipes"]
## The contract's staged payments the build pays (ShipOrders.PAYMENT_STAGES): each once every
## stage listed is done. "Keel laid: the frame is complete in the dock"; "Fit-out: the hull is
## closed and the main machinery is in".
const PAYMENTS := {"keel": ["frame"], "fit_out": ["frame", "plates", "fittings"]}

var jobs: Array[Dictionary] = []
## Blueprint part id -> the job that fits it.
var job_of: Dictionary = {}


## The plan for the parts and joints in `model` (the blueprint). Each part is put in a job by
## `group(part) -> {key, stage, name, order}`; jobs run stage by stage, then by `order`.
static func make(model: PartModel, group: Callable) -> BuildPlan:
	var plan := BuildPlan.new()
	var by_key: Dictionary = {}
	var ids: Array = model.parts.keys()
	ids.sort()
	for id: int in ids:
		var g: Dictionary = group.call(model.parts[id])
		var key := str(g.key)
		if not by_key.has(key):
			by_key[key] = {"stage": str(g.stage), "name": str(g.name), "order": float(g.get("order", 0.0)), "parts": []}
		(by_key[key].parts as Array).append(id)
	var list: Array = by_key.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := STAGE_ORDER.find(str(a.stage))
		var sb := STAGE_ORDER.find(str(b.stage))
		if sa != sb:
			return sa < sb
		if not is_equal_approx(float(a.order), float(b.order)):
			return float(a.order) < float(b.order)
		return str(a.name) < str(b.name))
	# Each part's joints, so a job only looks at its own.
	var joints_of: Dictionary = {}
	for i in model.connections.size():
		var c := model.connections[i]
		(joints_of.get_or_add(c.part_a, []) as Array).append(i)
		(joints_of.get_or_add(c.part_b, []) as Array).append(i)
	var placed: Dictionary = {}
	for j: Dictionary in list:
		var mine: Dictionary = {}
		for id: int in j.parts:
			mine[id] = true
		var inner: Array[int] = []
		var fixing: Array[int] = []
		var seen: Dictionary = {}
		for id: int in j.parts:
			for i: int in joints_of.get(id, []):
				if seen.has(i):
					continue
				seen[i] = true
				var c := model.connections[i]
				var other := c.part_b if mine.has(c.part_a) else c.part_a
				if mine.has(other):
					inner.append(i)
				elif placed.has(other):
					fixing.append(i)
		inner.sort()
		fixing.sort()
		var most := int((STAGES.get(str(j.stage), {}) as Dictionary).get("key", 4))
		var from := fixing if not fixing.is_empty() else inner
		var key := pick(model, from, most)
		var job := {"id": plan.jobs.size(), "stage": j.stage, "name": j.name, "parts": j.parts,
				"key": key, "inner": inner.filter(func(i: int) -> bool: return not key.has(i)),
				"tack": fixing.filter(func(i: int) -> bool: return not key.has(i))}
		for id: int in j.parts:
			placed[id] = true
			plan.job_of[id] = job.id
		plan.jobs.append(job)
	return plan


## Up to `most` of `from` (connection indexes) spread out over the assembly: the joints of the
## kind it has most of first (the welds of a frame ring, the rivets of a plate), then evenly
## through them in order.
static func pick(model: PartModel, from: Array[int], most: int) -> Array[int]:
	var out: Array[int] = []
	if from.is_empty() or most <= 0:
		return out
	if from.size() <= most:
		out.assign(from)
		return out
	var kinds: Dictionary = {}
	for i in from:
		var k := hand_kind(model.connections[i].kind)
		(kinds.get_or_add(k, []) as Array).append(i)
	var order: Array = kinds.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return (kinds[a] as Array).size() > (kinds[b] as Array).size())
	# Turn about between the kinds, the commonest first.
	var lists: Array = []
	for k: int in order:
		lists.append(kinds[k])
	var want: Array[int] = []
	want.resize(lists.size())
	want.fill(0)
	var left := most
	var more := true
	while left > 0 and more:
		more = false
		for li in lists.size():
			if left > 0 and want[li] < (lists[li] as Array).size():
				want[li] += 1
				left -= 1
				more = true
	for li in lists.size():
		var l: Array = lists[li]
		var n: int = want[li]
		for k in n:
			var at := 0 if n == 1 else roundi(float(k) * float(l.size() - 1) / float(n - 1))
			if not out.has(l[at]):
				out.append(l[at])
	out.sort()
	return out


## The fastening the hand tools make for a joint of `kind`: a spot weld is run as a short weld,
## a plug is clipped (riveted) home.
static func hand_kind(kind: int) -> int:
	match kind:
		ConnectionData.Kind.SPOT:
			return ConnectionData.Kind.WELD
		ConnectionData.Kind.CONNECTOR:
			return ConnectionData.Kind.RIVET
	return kind


## The tool that makes a fastening of `kind` (hand_kind's).
static func tool_for(kind: int) -> String:
	match hand_kind(kind):
		ConnectionData.Kind.WELD:
			return "welder"
		ConnectionData.Kind.BOLT:
			return "socket"
	return "riveter"


## Jobs of `stage`, in order.
func stage_jobs(stage: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for j in jobs:
		if str(j.stage) == stage:
			out.append(j)
	return out


## How many hand fastenings the whole build asks.
func key_count() -> int:
	var n := 0
	for j in jobs:
		n += (j.key as Array).size()
	return n


## The stages that have jobs, in order.
func stages() -> PackedStringArray:
	var out := PackedStringArray()
	for s in STAGE_ORDER:
		if not stage_jobs(s).is_empty():
			out.append(s)
	return out


## Workmanship, 0..1 per fastening -> a grade, as the welds call theirs.
static func grade(q: float) -> String:
	return "NEAT" if q >= 0.8 else ("FAIR" if q >= 0.5 else "POOR")
