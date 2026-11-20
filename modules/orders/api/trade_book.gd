class_name TradeBook
extends RefCounted
## The numbers behind selling parts (master plan 7.6, a sideline to building ships): what the
## yard can trade (catalogue components, one at a time), what buying them for stock costs, what
## each vendor pays to buy them back, and what a second-hand lot costs. Worked out from the
## market, the day and the catalogue alone, so every machine agrees.
##
## The rule that keeps it honest: a vendor's buy-back is always under the cheapest price anyone
## could buy the same part for that day (any vendor, any deal, the best standing, the biggest
## volume): no buy-and-sell on one day ever pays. The money is in timing (buy when the market or a
## weekly deal is low, sell when it is high) and in flipping (cheap second-hand lots through the
## refurb works, sold on as certified parts).

## A vendor buys back at this share of its own list price that day...
const SPREAD := 0.74
## ...less this much for each more of one part sold at once (a glut), down to VOLUME_FLOOR.
const VOLUME_FALL := 0.03
const VOLUME_FLOOR := 0.6
## ...and never over this share of the cheapest price anyone sells the part for that day (under
## a buyer's 5% off, the company's crew roles, too).
const CAP := 0.92
## A second-hand lot of at least BULK_LOT comes cheaper: this share of the median new price
## (OrderBook.USED_SHARE for fewer).
const BULK_LOT := 4
const BULK_USED_SHARE := 0.24
## The standing a cap is worked against (the best there is).
const BEST_STANDING := 100.0
## Units a cap is worked against (more than anyone buys: the biggest volume discount).
const BEST_UNITS := 9999


## Components in the sample designs' parts lists, one each: the lines the yard trades in.
static func lines(cat: DesignCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if cat == null:
		return out
	var seen := {}
	for maker: String in ["freighter", "skiff"]:
		var rec := DesignRecord.new()
		if maker == "freighter":
			DesignBus.Samples.freighter(rec, cat)
		else:
			DesignBus.Samples.skiff(rec, cat)
		var totals := DesignTotals.compute(rec, cat, DesignStructure.measure(rec), DesignFrame.propose(rec))
		for l: Dictionary in SupplyMarket.buy_lines(totals, cat):
			if str(l.kind) != "component" or seen.has(str(l.key)):
				continue
			seen[str(l.key)] = true
			var one := l.duplicate(true)
			one.list_unit = float(l.list_unit) * float(l.qty) / maxf(1.0, float(l.units))
			one.qty = 1.0
			one.units = 1
			out.append(one)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name) < str(b.name))
	return out


## `line` for `qty` of it.
static func sized(line: Dictionary, qty: int) -> Dictionary:
	var l := line.duplicate(true)
	l.qty = float(qty)
	l.units = maxi(1, qty)
	return l


## The cheapest price anyone sells one of `line` for on `day` (any vendor, the best standing,
## the biggest volume, any deal).
static func floor_price(line: Dictionary, vendors: Array, day: int, cat: DesignCatalog) -> float:
	var best := INF
	var big := sized(line, BEST_UNITS)
	for v: SupplyVendor in vendors:
		var q := SupplyMarket.quote(v, big, day, BEST_STANDING, cat)
		if not q.is_empty():
			best = minf(best, float(q.unit))
	return best


## The new price to buy `qty` of `line` for stock today: the cheapest vendor's quote at the
## yard's standing with it, {vendor, name, unit, total, lead} ({} if nobody sells it).
static func buy_quote(line: Dictionary, qty: int, vendors: Array, standing: Dictionary, day: int, cat: DesignCatalog) -> Dictionary:
	var best := {}
	var l := sized(line, qty)
	for v: SupplyVendor in vendors:
		var q := SupplyMarket.quote(v, l, day, float(standing.get(v.id, 0.0)), cat)
		if not q.is_empty() and (best.is_empty() or float(q.unit) < float(best.unit)):
			best = q
			best["name"] = v.display_name
	return best


## What each vendor that deals in `line` pays for `qty` of it today, best first:
## [{vendor, name, each, total}].
static func offers(line: Dictionary, qty: int, vendors: Array, day: int, cat: DesignCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cap := floor_price(line, vendors, day, cat) * CAP
	if cap == INF or qty < 1:
		return out
	var glut := maxf(VOLUME_FLOOR, 1.0 - VOLUME_FALL * float(qty - 1))
	for v: SupplyVendor in vendors:
		if not SupplyMarket.supplies(v, line):
			continue
		var each := minf(SupplyMarket.list_price(v, line, day) * SPREAD * glut, cap)
		each = floorf(each)
		out.append({"vendor": v.id, "name": v.display_name, "each": each, "total": each * qty})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.each) > float(b.each))
	return out


## The best buy-back for one of `line` on each of the `days` up to `day` (the trend to time a sale).
static func trend(line: Dictionary, vendors: Array, day: int, days: int, cat: DesignCatalog) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for d in range(day - days + 1, day + 1):
		var o := offers(line, 1, vendors, d, cat)
		out.append(float(o[0].each) if not o.is_empty() else 0.0)
	return out


## A second-hand lot of `qty`: each one's price (a share of `median_unit`, cheaper in bulk) plus
## the refurb works' bill.
static func used_each(qty: int, median_unit: float, refurb_cost: float) -> float:
	return median_unit * (BULK_USED_SHARE if qty >= BULK_LOT else OrderBook.USED_SHARE) + refurb_cost
