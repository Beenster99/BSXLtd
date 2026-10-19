class_name TradesStubFasteners
extends RefCounted
## Stand-in fastener data until Shared Components publishes the real library.

const ALL := {
	&"bolt_m8x25_8.8": {"label": "M8 x 25", "diameter_mm": 8.0, "length_mm": 25.0},
	&"bolt_m6x20_8.8": {"label": "M6 x 20", "diameter_mm": 6.0, "length_mm": 20.0},
}


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in ALL:
		out.append(id)
	return out


static func label(id: StringName) -> String:
	return ALL.get(id, {}).get("label", String(id))


static func diameter_m(id: StringName) -> float:
	return ALL.get(id, {}).get("diameter_mm", 8.0) / 1000.0
