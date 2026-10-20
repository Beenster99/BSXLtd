class_name BusinessResult
extends RefCounted
## Outcome of a Business call that changes something. `error` is OK on success.

var error := OK
var message := ""
## Set by place_order (the first order of a market order).
var order_id := ""
## Every order a market order made (one per supplier).
var order_ids: PackedStringArray = []
## What it cost in all.
var cost := 0


func is_ok() -> bool:
	return error == OK


static func success(p_order_id := "") -> BusinessResult:
	var r := BusinessResult.new()
	r.order_id = p_order_id
	return r


static func fail(p_error: Error, p_message: String) -> BusinessResult:
	var r := BusinessResult.new()
	r.error = p_error
	r.message = p_message
	return r
