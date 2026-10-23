class_name MarketListing
extends RefCounted
## One line on today's parts market: a supplier's offer of a part in a condition, at a
## unit price, while stock lasts. Listings change every business day.

var id := ""
var supplier_id := ""
var part := ""
var condition := PartCondition.NEW
var unit_price := 0
## How many are left today.
var available := 0
## How long an order of it takes to arrive, real seconds.
var lead_seconds := 30
## The price before today's deal, or 0 when it isn't on a deal.
var list_price := 0


func to_dict() -> Dictionary:
	return {"id": id, "supplier_id": supplier_id, "part": part, "condition": condition,
			"unit_price": unit_price, "available": available, "lead_seconds": lead_seconds, "list_price": list_price}


static func from_dict(d: Dictionary) -> MarketListing:
	var l := MarketListing.new()
	l.id = str(d.get("id", ""))
	l.supplier_id = str(d.get("supplier_id", ""))
	l.part = str(d.get("part", ""))
	l.condition = str(d.get("condition", PartCondition.NEW))
	l.unit_price = int(d.get("unit_price", 0))
	l.available = int(d.get("available", 0))
	l.lead_seconds = int(d.get("lead_seconds", 30))
	l.list_price = int(d.get("list_price", 0))
	return l


## Percent off today's deal, 0 when there isn't one.
func deal_off() -> int:
	return 0 if list_price <= unit_price else roundi(100.0 * (list_price - unit_price) / list_price)
