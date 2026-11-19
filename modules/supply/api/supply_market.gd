class_name SupplyMarket
extends RefCounted
## The parts market's numbers, worked out from the vendors and the day alone (nothing random
## is stored, so every machine in a session sees the same prices): each vendor's price for a
## line of the open design on any day, its deals, its wait and how likely it is to deliver on
## time, given the company's standing with it and how many are bought.
##
## Prices move with the market (each category drifts over weeks and months) and with the
## vendor (its own day-to-day swing), and dip while a deal runs, so history() can draw the
## past months for any line.

## Standing with a vendor (0-100), by tier: from, name, days on (or off) its waits, percent
## off, and how much likelier an order is to come on time.
const TIERS: Array = [
	[0, "New account", 2, 0, 0.0],
	[25, "Known customer", 1, 2, 0.01],
	[50, "Trusted", 0, 4, 0.03],
	[75, "Preferred", -1, 7, 0.05],
]
## How a parts list line is bought (lines in metres or square metres come in lengths, sheets,
## reels and kits): kind -> unit -> [units per pack, pack name].
const PACKS := {
	"hull": {"m": [6.0, "6 m lengths"], "m2": [4.0, "sheets"], "x": [50.0, "packs of 50"]},
	"service": {"m": [25.0, "25 m reels"]},
	"room": {"m2": [5.0, "5 m2 kits"]},
}
## Line kinds that are not catalogue components, and the category they are sold under.
const KIND_CATEGORY := {"hull": "hull", "service": "services", "room": "fitout"}
## The supplier wait for lines that aren't catalogue components, days.
const STOCK_LEAD := 2
## Waits never come in under this, days.
const MIN_LEAD := 1
## Lines of stock and plate (not components): how many times a vendor's `stock` it holds.
const BULK_STOCK := 25
## Waits count no more batches than this (a big order is split across its deliveries).
const MAX_BATCHES := 5
## A further batch beyond a vendor's stock lowers its chance of coming on time by this.
const BATCH_RISK := 0.03
## Days of history kept to draw (about six months).
const HISTORY_DAYS := 180

## Deals by vendor and week (they follow from the two alone, so are worked out once).
static var _deal_cache: Dictionary = {}


## The design's parts list (DesignTotals.lines) as lines to buy:
## {key, name, kind, category, base_id, grade, qty, unit, units, pack, list_unit, lead, tags (the
## placed objects' IDs, DesignRecord.tag, where the parts list gives them)}.
static func buy_lines(totals: DesignTotals, cat: DesignCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if totals == null:
		return out
	for line: Dictionary in totals.lines:
		var qty := float(line.get("qty", 0.0))
		if qty <= 0.0 or float(line.get("cost", 0.0)) <= 0.0:
			continue
		var kind := str(line.get("kind", ""))
		var id := str(line.get("id", ""))
		var unit := str(line.get("unit", "x"))
		var b := {"key": kind + ":" + id, "name": str(line.get("name", id)), "kind": kind,
				"category": str(KIND_CATEGORY.get(kind, "doors" if kind == "door" else kind)),
				"base_id": id, "grade": "", "qty": qty, "unit": unit,
				"list_unit": float(line.cost) / qty, "lead": STOCK_LEAD,
				"tags": PackedStringArray(line.get("tags", []))}
		if kind == "component" and cat:
			var pt := cat.part(id)
			var base := cat.base_of(id)
			if pt and base:
				b.category = base.category
				b.base_id = base.id
				b.grade = (pt.grade if pt.grade != "" else DesignGrades.DEFAULT_GRADE) if base.graded else ""
				b.lead = pt.lead_days
		var pack: Array = (PACKS.get(kind, {}) as Dictionary).get(unit, [1.0, ""])
		b.units = maxi(1, ceili(qty / float(pack[0]) - 0.0001))
		b.pack = str(pack[1])
		out.append(b)
	return out


## Standing's tier: {name, from, next (standing for the tier above, -1 at the top), lead, off, rel}.
static func tier(standing: float) -> Dictionary:
	var at: Array = TIERS[0]
	var next := -1
	for t: Array in TIERS:
		if standing >= float(t[0]):
			at = t
		elif next < 0:
			next = int(t[0])
	return {"name": at[1], "from": at[0], "next": next, "lead": at[2], "off": at[3], "rel": at[4]}


## The market's index for a category on a day (1.0 = list price): slow swings over months,
## faster ones over a fortnight, a little daily noise.
static func market_index(category: String, day: float) -> float:
	return 1.0 + 0.07 * noise("mk:" + category + ":slow", day / 45.0) \
			+ 0.035 * noise("mk:" + category + ":mid", day / 12.0) \
			+ 0.012 * noise("mk:" + category + ":day", day / 2.5)


## The vendor's own price for one unit of a line on a day, with any deal running then.
static func list_price(v: SupplyVendor, line: Dictionary, day: int) -> float:
	var key := v.id + ":" + str(line.base_id)
	return float(line.list_unit) * v.price_factor * (1.0 + v.spread * _h(key)) \
			* market_index(str(line.category), day) * (1.0 + v.volatility * noise("vd:" + key, day / 5.0))


## Whether the vendor can supply the line at all.
static func supplies(v: SupplyVendor, line: Dictionary) -> bool:
	return v.stocks(str(line.category)) and (str(line.grade) == "" or v.sells_grade(str(line.grade)))


## The deals a vendor runs in the week holding `day`: {vendor, scope ("category" or "part"),
## key, name, percent, min_units, ends}. Even slots mark down a category, odd ones one part.
static func deals(v: SupplyVendor, day: int, cat: DesignCatalog) -> Array[Dictionary]:
	var week := floori(day / 7.0)
	var ck := "%s:%d:%d" % [v.id, week, cat.get_instance_id() if cat else 0]
	if _deal_cache.has(ck):
		return _deal_cache[ck]
	if _deal_cache.size() > 4000:
		_deal_cache.clear()
	var out: Array[Dictionary] = []
	var cats := _vendor_categories(v)
	for i in v.deals_per_week:
		var seed := "deal:%s:%d:%d" % [v.id, week, i]
		var pct := v.deal_percent.x + int(_u(seed + ":pct") * float(v.deal_percent.y - v.deal_percent.x + 1))
		var d := {"vendor": v.id, "percent": mini(pct, v.deal_percent.y), "ends": (week + 1) * 7, "min_units": 1}
		if i % 2 == 0 or cat == null:
			var c: String = cats[int(_u(seed + ":cat") * cats.size()) % cats.size()]
			d.scope = "category"
			d.key = c
			d.name = category_name(c)
		else:
			var pool: Array[DesignPartType] = []
			for c: String in cats:
				pool.append_array(cat.parts_in(c))
			if pool.is_empty():
				continue
			var p: DesignPartType = pool[int(_u(seed + ":part") * pool.size()) % pool.size()]
			d.scope = "part"
			d.key = p.id
			d.name = p.display_name
			d.min_units = 2 if _u(seed + ":min") < 0.4 else 1
		out.append(d)
	_deal_cache[ck] = out
	return out


## Percent off the best deal gives a line from this vendor on a day (0 for none), and the deal.
static func deal_on(v: SupplyVendor, line: Dictionary, day: int, cat: DesignCatalog, units := 1) -> Dictionary:
	var best := {}
	for d: Dictionary in deals(v, day, cat):
		var hit: bool = (d.scope == "category" and d.key == line.category) or (d.scope == "part" and d.key == line.base_id)
		if hit and units >= int(d.min_units) and int(d.percent) > int(best.get("percent", 0)):
			best = d
	return best


## A vendor's quote for a whole line today: {vendor, unit (each, after every discount), total,
## list_unit, deal (the deal, or {}), deal_off, volume_off, standing_off, lead (days),
## batches, on_time (0-1)}; {} when it doesn't supply the line.
static func quote(v: SupplyVendor, line: Dictionary, day: int, standing: float, cat: DesignCatalog) -> Dictionary:
	if not supplies(v, line):
		return {}
	var units := int(line.units)
	var t := tier(standing)
	var deal := deal_on(v, line, day, cat, units)
	var deal_off := int(deal.get("percent", 0))
	var vol := v.volume_off(units)
	var off := mini(deal_off + vol + int(t.off), 45)
	var each := list_price(v, line, day) * (1.0 - off / 100.0)
	# Stock and plate come by the pallet: a vendor holds BULK_STOCK times as many of them.
	var held := maxi(v.stock, 1) * (1 if str(line.kind) == "component" else BULK_STOCK)
	var batches := clampi(ceili(float(units) / float(held)), 1, MAX_BATCHES)
	var lead := maxi(MIN_LEAD, int(line.lead) + v.lead_days + int(t.lead) + (batches - 1) * v.restock_days)
	var on_time := clampf(v.reliability + float(t.rel) - BATCH_RISK * (batches - 1), 0.3, 0.995)
	return {"vendor": v.id, "unit": each, "total": each * float(line.qty), "list_unit": list_price(v, line, day),
			"deal": deal, "deal_off": deal_off, "volume_off": vol, "standing_off": int(t.off),
			"lead": lead, "batches": batches, "on_time": on_time}


## A line's price from a vendor over the `days` before (and including) `day`, one value a
## `step` days: what one unit cost then, deals included (no volume or standing discount).
static func history(v: SupplyVendor, line: Dictionary, day: int, days: int, cat: DesignCatalog, step := 1) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var from := day - days + 1
	var d := from
	while d <= day:
		var deal := deal_on(v, line, d, cat, int(line.units))
		out.append(list_price(v, line, d) * (1.0 - int(deal.get("percent", 0)) / 100.0))
		d += step
	return out


static func category_name(id: String) -> String:
	for c: Array in DesignCatalog.CATEGORIES:
		if c[0] == id:
			return c[1]
	return {"hull": "Hull and fasteners", "services": "Wiring and pipe runs", "fitout": "Room fit-out"}.get(id, id.capitalize())


static func _vendor_categories(v: SupplyVendor) -> PackedStringArray:
	if not v.categories.is_empty():
		return v.categories
	var all := PackedStringArray()
	for c: Array in DesignCatalog.CATEGORIES:
		all.append(c[0])
	all.append_array(["hull", "services", "fitout"])
	return all


## Smooth noise in -1..1 along t, the same on every machine for the same key.
static func noise(key: String, t: float) -> float:
	var i := floori(t)
	var f := t - i
	var a := _h("%s#%d" % [key, i])
	var b := _h("%s#%d" % [key, i + 1])
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(a, b, f)


## -1..1 from a key.
static func _h(key: String) -> float:
	return _u(key) * 2.0 - 1.0


## 0..1 from a key.
static func _u(key: String) -> float:
	# String.hash() barely changes between "x#370" and "x#380": mix its bits well first.
	var h := key.hash() & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h % 1000003) / 1000003.0
