class_name TradeBook
extends RefCounted
## The numbers behind selling parts (master plan 7.6, a sideline to building ships): what the
## yard can trade (catalogue components, one at a time), what buying them for stock costs, what
## each vendor pays to buy them back, and what a second-hand lot costs. Worked out from the
## market, the day and the catalogue alone, so every machine agrees.
##
## Each part has its own trading market on top of the suppliers' prices (`market`): a slow swing
## over months, a quicker one over weeks and a daily wobble, so prices rise and fall and the money
## is in buying at a low and selling at a high. It moves buying new, a lot's parts and buy-backs
## alike.
##
## The rule that keeps it honest: a vendor's buy-back is always under the cheapest price anyone
## could buy the same part for that day (any vendor, any deal, the best standing, the biggest
## volume): no buy-and-sell on one day ever pays. Profit comes from timing, and from second-hand
## lots (cheap parts, plus the refurb works' bill to fix them up).

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
## Second-hand lots on offer each day (different parts each day), each of LOT_SIZE parts.
const LOTS_A_DAY := 3
const LOT_SIZE := 5
## The trading market's swings: the slow one (months), the quicker one (weeks), the daily wobble,
## each a share of the price either way; the slow and quick ones' lengths in days, from..to.
const SWING_LONG := 0.16
const SWING_MID := 0.08
const WOBBLE := 0.015
const LONG_DAYS := Vector2(70.0, 120.0)
const MID_DAYS := Vector2(14.0, 30.0)
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


## The trading market for `line` on `day`: a share of the suppliers' price (about 0.75 to 1.25),
## the same on every machine.
static func market(line: Dictionary, day: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bsx_market_" + str(line.key))
	var long_len := rng.randf_range(LONG_DAYS.x, LONG_DAYS.y)
	var mid_len := rng.randf_range(MID_DAYS.x, MID_DAYS.y)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var d := float(day)
	var f := 1.0 + SWING_LONG * sin(TAU * d / long_len + p1) + SWING_MID * sin(TAU * d / mid_len + p2)
	var w := RandomNumberGenerator.new()
	w.seed = hash("bsx_wobble_%s_%d" % [str(line.key), day])
	return f + w.randf_range(-WOBBLE, WOBBLE)


## The keys of the lines whose second-hand lots are on offer on `day` (LOTS_A_DAY of them, the
## same on every machine).
static func lots(all: Array[Dictionary], day: int) -> Array[String]:
	var keys: Array[String] = []
	for l in all:
		keys.append(str(l.key))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bsx_lots_%d" % day)
	var out: Array[String] = []
	while out.size() < mini(LOTS_A_DAY, keys.size()):
		var k: String = keys[rng.randi_range(0, keys.size() - 1)]
		if not out.has(k):
			out.append(k)
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
	return best * market(line, day)


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
	if not best.is_empty():
		var m := market(line, day)
		best.unit = float(best.unit) * m
		best.total = float(best.total) * m
	return best


## What each vendor that deals in `line` pays for `qty` of it today, best first:
## [{vendor, name, each, total}].
static func offers(line: Dictionary, qty: int, vendors: Array, day: int, cat: DesignCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cap := floor_price(line, vendors, day, cat) * CAP
	if cap == INF or qty < 1:
		return out
	var glut := maxf(VOLUME_FLOOR, 1.0 - VOLUME_FALL * float(qty - 1))
	var m := market(line, day)
	for v: SupplyVendor in vendors:
		if not SupplyMarket.supplies(v, line):
			continue
		var each := minf(SupplyMarket.list_price(v, line, day) * m * SPREAD * glut, cap)
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


## A second-hand lot of `qty`: each part's price before the refurb works' bill (a share of
## `median_unit`, cheaper in bulk).
static func used_each(qty: int, median_unit: float) -> float:
	return median_unit * (BULK_USED_SHARE if qty >= BULK_LOT else OrderBook.USED_SHARE)
