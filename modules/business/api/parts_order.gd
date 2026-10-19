class_name PartsOrder
extends RefCounted
## A parts order placed with a supplier. Read-only outside the Business module.

enum State { PLACED, DELIVERED, CANCELLED }

var id := ""
var supplier_id := ""
var lines: Array[OrderLine] = []
var cost := 0
var placed_day := 0
var eta_day := 0
var state := State.PLACED
var delayed := false
## The contract the parts are for, or "" for stock.
var contract_id := ""


func to_dict() -> Dictionary:
	return {
		"id": id, "supplier_id": supplier_id, "lines": lines.map(func(l): return l.to_dict()),
		"cost": cost, "placed_day": placed_day, "eta_day": eta_day, "state": state,
		"delayed": delayed, "contract_id": contract_id,
	}


static func from_dict(d: Dictionary) -> PartsOrder:
	var o := PartsOrder.new()
	o.id = str(d.get("id", ""))
	o.supplier_id = str(d.get("supplier_id", ""))
	for l in d.get("lines", []):
		o.lines.append(OrderLine.from_dict(l))
	o.cost = int(d.get("cost", 0))
	o.placed_day = int(d.get("placed_day", 0))
	o.eta_day = int(d.get("eta_day", 0))
	o.state = int(d.get("state", State.PLACED)) as State
	o.delayed = bool(d.get("delayed", false))
	o.contract_id = str(d.get("contract_id", ""))
	return o
