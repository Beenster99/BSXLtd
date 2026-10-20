class_name OrderLine
extends RefCounted
## One line of a parts order: a part (by its Void Salvage part_name), how many, the
## condition it comes in and what each one cost.

var part := ""
var qty := 1
var condition := PartCondition.NEW
var unit_price := 0


func _init(p_part := "", p_qty := 1, p_condition := PartCondition.NEW, p_unit_price := 0) -> void:
	part = p_part
	qty = p_qty
	condition = p_condition
	unit_price = p_unit_price


func to_dict() -> Dictionary:
	return {"part": part, "qty": qty, "condition": condition, "unit_price": unit_price}


static func from_dict(d: Dictionary) -> OrderLine:
	return OrderLine.new(str(d.get("part", "")), int(d.get("qty", 1)),
			str(d.get("condition", PartCondition.NEW)), int(d.get("unit_price", 0)))
