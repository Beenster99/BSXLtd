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
var lead_hours := 24


func to_dict() -> Dictionary:
	return {"id": id, "supplier_id": supplier_id, "part": part, "condition": condition,
			"unit_price": unit_price, "available": available, "lead_hours": lead_hours}


static func from_dict(d: Dictionary) -> MarketListing:
	var l := MarketListing.new()
	l.id = str(d.get("id", ""))
	l.supplier_id = str(d.get("supplier_id", ""))
	l.part = str(d.get("part", ""))
	l.condition = str(d.get("condition", PartCondition.NEW))
	l.unit_price = int(d.get("unit_price", 0))
	l.available = int(d.get("available", 0))
	l.lead_hours = int(d.get("lead_hours", 24))
	return l
