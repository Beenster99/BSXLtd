class_name SupplyOptimiser
extends RefCounted
## The company optimiser on the parts market: for every line of the open design it takes each
## vendor's quote and builds three ways to buy the whole ship: the CHEAPEST (lowest price per
## line), the MOST RELIABLE (likeliest to come on time, the cheaper of equals) and the MEDIAN
## (the middle quote per line: what the market usually charges). Run again on every edit.

const CHEAPEST := "cheapest"
const RELIABLE := "reliable"
const MEDIAN := "median"
const PLANS: PackedStringArray = [CHEAPEST, RELIABLE, MEDIAN]
const PLAN_NAMES := {CHEAPEST: "CHEAPEST", RELIABLE: "MOST RELIABLE", MEDIAN: "MEDIAN COST"}

## One per line: {line, quotes: Array (by vendor, cheapest first), picks: {plan -> quote}}.
var rows: Array[Dictionary] = []
## Plan -> {total, lead (longest wait), on_time (the whole order), worst (the shakiest line's),
## vendors (ids used), lines (how many it covers)}.
var plans: Dictionary = {}
## Lines no vendor will supply (a grade nobody stocks).
var unsupplied: Array[Dictionary] = []
## How many quotes it weighed.
var quotes_weighed := 0


static func run(lines: Array[Dictionary], vendors: Array[SupplyVendor], standing: Dictionary, day: int,
		cat: DesignCatalog) -> SupplyOptimiser:
	var o := SupplyOptimiser.new()
	for line in lines:
		var qs: Array[Dictionary] = []
		for v in vendors:
			var q := SupplyMarket.quote(v, line, day, float(standing.get(v.id, v.standing_start)), cat)
			if not q.is_empty():
				qs.append(q)
		o.quotes_weighed += qs.size()
		if qs.is_empty():
			o.unsupplied.append(line)
			continue
		qs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.total) < float(b.total))
		var reliable: Dictionary = qs[0]
		for q in qs:
			if float(q.on_time) > float(reliable.on_time) + 0.0001:
				reliable = q
		o.rows.append({"line": line, "quotes": qs,
				"picks": {CHEAPEST: qs[0], RELIABLE: reliable, MEDIAN: qs[floori((qs.size() - 1) / 2.0)]}})
	for plan in PLANS:
		o.plans[plan] = o._sum(plan)
	return o


func _sum(plan: String) -> Dictionary:
	var total := 0.0
	var lead := 0
	var worst := 1.0
	var by_vendor := {}
	for r in rows:
		var q: Dictionary = r.picks[plan]
		total += float(q.total)
		lead = maxi(lead, int(q.lead))
		worst = minf(worst, float(q.on_time))
		# One delivery a vendor: as likely to come on time as its shakiest line.
		by_vendor[q.vendor] = minf(float(by_vendor.get(q.vendor, 1.0)), float(q.on_time))
	var whole := 1.0
	for v in by_vendor:
		whole *= float(by_vendor[v])
	return {"total": total, "lead": lead, "on_time": whole if not rows.is_empty() else 0.0,
			"worst": worst if not rows.is_empty() else 0.0, "vendors": by_vendor.keys(), "lines": rows.size()}


## What a plan saves against the median (negative: costs more).
func saving(plan: String) -> float:
	return float(plans[MEDIAN].total) - float(plans[plan].total)


## The lines a deal is in this week: [{row, quote}] where the plan's pick has one.
func on_deal() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in rows:
		for q: Dictionary in r.quotes:
			if not (q.deal as Dictionary).is_empty():
				out.append({"row": r, "quote": q})
	return out
