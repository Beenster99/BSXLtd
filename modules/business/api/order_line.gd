class_name OrderLine
extends RefCounted
## One line of a parts order: a part (by its Shared Components name) and how many.

var part := ""
var qty := 1


func _init(p_part := "", p_qty := 1) -> void:
	part = p_part
	qty = p_qty


func to_dict() -> Dictionary:
	return {"part": part, "qty": qty}


static func from_dict(d: Dictionary) -> OrderLine:
	return OrderLine.new(str(d.get("part", "")), int(d.get("qty", 1)))
