class_name BotRules
extends RefCounted
## The bots' priorities as rule cards (master plan 6.2: "Set what matters: which section first,
## which jobs wait, which bot helps which. Simple rule cards, not programming"). A card is a
## Dictionary {id, kind, arg, on}; the crew reads the deck top to bottom.
##
## Kinds:
##   order    arg "bow", "stern", "middle", "low", "high": which section of the ship first (the
##            topmost order card that is on counts)
##   rush     arg a build stage: its jobs go before every other
##   hold     arg a build stage: its jobs wait (the bots leave them till the card is off)
##   leave    arg a build stage: the bots leave its jobs for the crew to do by hand
##   pair     arg "<helper bot id>><lead bot id>": the helper works beside the lead, making the
##            fastenings of the lead's job (or fetching its parts) instead of taking its own
##   inspect  arg a quality (0..1): inspectors make any fastening under it again
##   charge   arg a charge (0..1): a bot goes to charge below it

const KINDS := {
	"order": {"name": "Section first", "args": ["bow", "stern", "middle", "low", "high"]},
	"rush": {"name": "Rush", "args": ["frame", "plates", "fittings", "wiring", "pipes"]},
	"hold": {"name": "Hold", "args": ["frame", "plates", "fittings", "wiring", "pipes"]},
	"leave": {"name": "Leave for the crew", "args": ["frame", "plates", "fittings", "wiring", "pipes"]},
	"pair": {"name": "Helps", "args": []},
	"inspect": {"name": "Inspect below", "args": [0.5, 0.6, 0.7, 0.8]},
	"charge": {"name": "Charge below", "args": [0.15, 0.25, 0.35]},
}
const ARG_NAMES := {"bow": "bow first", "stern": "stern first", "middle": "midships out",
		"low": "lowest deck first", "high": "top deck first"}

## A new company's deck.
static func defaults() -> Array[Dictionary]:
	return [
		{"id": "r1", "kind": "order", "arg": "bow", "on": true},
		{"id": "r2", "kind": "inspect", "arg": 0.6, "on": true},
		{"id": "r3", "kind": "charge", "arg": 0.25, "on": true},
		{"id": "r4", "kind": "hold", "arg": "pipes", "on": false},
		{"id": "r5", "kind": "rush", "arg": "frame", "on": false},
	]


## What card `c` says, for the board: "Section first: bow first".
static func text(c: Dictionary, names: Callable = Callable()) -> String:
	var k := str(c.get("kind", ""))
	var kind: Dictionary = KINDS.get(k, {})
	var arg: Variant = c.get("arg", "")
	match k:
		"order":
			return "Section first: %s" % str(ARG_NAMES.get(str(arg), str(arg)))
		"pair":
			var bits := str(arg).split(">")
			if bits.size() == 2 and names.is_valid():
				return "%s helps %s" % [str(names.call(int(bits[0]))), str(names.call(int(bits[1])))]
			return "Pair: %s" % str(arg)
		"inspect", "charge":
			return "%s %d%%" % [str(kind.get("name", k)), roundi(float(arg) * 100.0)]
	return "%s: %s" % [str(kind.get("name", k)), str(arg)]


static func _on(cards: Array, kind: String) -> Array:
	return cards.filter(func(c: Dictionary) -> bool: return bool(c.get("on", true)) and str(c.get("kind", "")) == kind)


## The stages held back (hold and leave cards that are on).
static func held(cards: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for c: Dictionary in _on(cards, "hold") + _on(cards, "leave"):
		if not out.has(str(c.arg)):
			out.append(str(c.arg))
	return out


## The stages left for the crew (leave cards that are on).
static func left_for_crew(cards: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for c: Dictionary in _on(cards, "leave"):
		out.append(str(c.arg))
	return out


## The order the bots take jobs in: `jobs` (job ids) less the held ones, sorted. `info(job)`
## gives {stage, at: Vector3 (ship space: -Z the bow, +y up), order (its place in the plan)}.
static func rank(jobs: Array, info: Callable, cards: Array) -> Array[int]:
	var hold := held(cards)
	var rush := PackedStringArray()
	for c: Dictionary in _on(cards, "rush"):
		rush.append(str(c.arg))
	var order := "bow"
	var orders := _on(cards, "order")
	if not orders.is_empty():
		order = str(orders[0].arg)
	var rows: Array = []
	for j: int in jobs:
		var i: Dictionary = info.call(j)
		if hold.has(str(i.stage)):
			continue
		var at: Vector3 = i.get("at", Vector3.ZERO)
		var key := 0.0
		match order:
			"bow":
				key = at.z
			"stern":
				key = -at.z
			"middle":
				key = absf(at.z)
			"low":
				key = at.y * 100.0 + at.z * 0.01
			"high":
				key = -at.y * 100.0 + at.z * 0.01
		rows.append([0 if rush.has(str(i.stage)) else 1, BuildPlan.STAGE_ORDER.find(str(i.stage)), key, int(i.get("order", j)), j])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		for n in 4:
			if not is_equal_approx(float(a[n]), float(b[n])):
				return float(a[n]) < float(b[n])
		return false)
	var out: Array[int] = []
	for r: Array in rows:
		out.append(int(r[4]))
	return out


## The helper -> lead pairs that are on: {helper id: lead id}.
static func pairs(cards: Array) -> Dictionary:
	var out := {}
	for c: Dictionary in _on(cards, "pair"):
		var bits := str(c.arg).split(">")
		if bits.size() == 2 and bits[0] != bits[1]:
			out[int(bits[0])] = int(bits[1])
	return out


## The threshold of the first on card of `kind` (inspect, charge), else `fallback`.
static func threshold(cards: Array, kind: String, fallback: float) -> float:
	var on := _on(cards, kind)
	return float(on[0].arg) if not on.is_empty() else fallback
