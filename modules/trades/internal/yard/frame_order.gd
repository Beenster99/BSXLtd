class_name TradesFrameOrder
extends RefCounted
## Committing a finished frame and ordering its parts as one package (trades.frame_order,
## beenster 0.3.31: "Once I am happy with my new frame, what do i do to commit it and get the
## parts ordered as a package"). Static: works out which stock bars the design's beams are cut
## from (Shared Components' StockBeams, packed the way the plasma bed lays them out) and the one
## basket that buys them from Business's market. The Frame Builder (TradesBeamDesigner) shows it,
## places the order and keeps what was committed with the ship's design (TradesBus).
##
## A cut plan: {bars [{bar (the stock bar's id), lengths [{mm, a, b}] (the bed's cut list for it)}],
## counts {bar: how many}, pieces (beams cut), spliced (beams longer than a 12 m bar, cut in
## pieces to weld end to end)}.

## The longest bar stocked (mm).
const LONG_MM := 12000
const SHORT_MM := 6000


## The cut plan for a design's beams (rows: {a, b, section}).
static func cut_plan(rows: Array) -> Dictionary:
	var by_section := {}
	var spliced := 0
	for r: Dictionary in rows:
		var l := _v(r.a).distance_to(_v(r.b))
		var mm := roundi(l * 1000.0)
		if mm <= 0:
			continue
		var sec := TradesBeamSections.normal(str(r.get("section", TradesBeamSections.DEFAULT)))
		var list: Array = by_section.get(sec, [])
		# A beam longer than the longest bar is cut in equal pieces to splice.
		var n := ceili(float(mm) / float(LONG_MM))
		if n > 1:
			spliced += 1
		for i in n:
			list.append(ceili(float(mm) / float(n)))
		by_section[sec] = list
	var bars: Array = []
	var counts := {}
	var pieces := 0
	for sec: String in by_section:
		var list: Array = by_section[sec]
		list.sort()
		list.reverse()
		var open: Array = []
		for mm: int in list:
			pieces += 1
			var placed := false
			for b: Dictionary in open:
				var trial: Array = (b.lengths as Array) + [{"mm": mm, "a": 0.0, "b": 0.0}]
				if not TradesBeamCuts.layout(TradesBeamCuts.bar_info(str(b.bar)), trial).is_empty():
					b.lengths = trial
					placed = true
					break
			if placed:
				continue
			var bar := bar_for(sec, SHORT_MM)
			if TradesBeamCuts.layout(TradesBeamCuts.bar_info(bar), [{"mm": mm, "a": 0.0, "b": 0.0}]).is_empty():
				bar = bar_for(sec, LONG_MM)
			open.append({"bar": bar, "lengths": [{"mm": mm, "a": 0.0, "b": 0.0}]})
		for b: Dictionary in open:
			bars.append(b)
			counts[b.bar] = int(counts.get(b.bar, 0)) + 1
	return {"bars": bars, "counts": counts, "pieces": pieces, "spliced": spliced}


## A section's steel stock bar of a length (mm).
static func bar_for(section: String, length_mm: int) -> String:
	var info := TradesBeamSections.info(section)
	return StockBeams.item_id("steel", str(info.family), roundi(float(info.w) * 1000.0), roundi(float(info.h) * 1000.0),
			roundi(float(info.t) * 1000.0), length_mm)


## What still has to be bought: the plan's bars less those ordered already ({bar: n}).
static func still_to_buy(counts: Dictionary, ordered: Dictionary) -> Dictionary:
	var out := {}
	for bar: String in counts:
		var n := int(counts[bar]) - int(ordered.get(bar, 0))
		if n > 0:
			out[bar] = n
	return out


## The one basket that buys `need` ({bar: n}) from today's market (Business's
## {listing_id, qty} lines): from one supplier who has it all when one does (the cheapest of
## them), else the cheapest listing for each bar. {ok, reason, basket, supplier ("" when it
## takes more than one), lines [{bar, name, qty, cost}], cost}.
static func basket(business: BusinessBus, need: Dictionary) -> Dictionary:
	var out := {"ok": false, "reason": "", "basket": [], "supplier": "", "lines": [], "cost": 0}
	if need.is_empty():
		out.reason = "nothing new to order"
		return out
	if business == null:
		out.reason = "there's no shop to order from"
		return out
	var by_supplier := {}
	var cheapest := {}
	for l: MarketListing in business.get_listings():
		if not need.has(l.part) or l.condition != PartCondition.NEW or l.available < int(need[l.part]):
			continue
		var cost := business.listing_cost(l, int(need[l.part]))
		var s: Dictionary = by_supplier.get(l.supplier_id, {})
		if not s.has(l.part) or cost < int((s[l.part] as Array)[1]):
			s[l.part] = [l, cost]
		by_supplier[l.supplier_id] = s
		if not cheapest.has(l.part) or cost < int((cheapest[l.part] as Array)[1]):
			cheapest[l.part] = [l, cost]
	var pick := {}
	var best := -1
	for sid: String in by_supplier:
		var s: Dictionary = by_supplier[sid]
		if s.size() < need.size():
			continue
		var total := 0
		for bar: String in s:
			total += int((s[bar] as Array)[1])
		if best < 0 or total < best:
			best = total
			pick = s
			out.supplier = sid
	if pick.is_empty():
		if cheapest.size() < need.size():
			var missing := PackedStringArray()
			for bar: String in need:
				if not cheapest.has(bar):
					missing.append(StockBeams.item(bar).get("name", bar))
			out.reason = "nobody has enough %s today" % ", ".join(missing)
			return out
		pick = cheapest
	for bar: String in need:
		var e: Array = pick[bar]
		var l := e[0] as MarketListing
		out.basket.append({"listing_id": l.id, "qty": int(need[bar])})
		out.lines.append({"bar": bar, "name": str(StockBeams.item(bar).get("name", bar)), "qty": int(need[bar]), "cost": int(e[1])})
	var q := business.quote_market(out.basket)
	out.ok = q.ok
	out.reason = q.reason
	out.cost = q.cost if q.ok else 0
	if q.ok and q.cost > business.get_cash():
		out.ok = false
		out.reason = "not enough cash: it costs %d CR" % q.cost
	return out


static func _v(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	var arr := a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
