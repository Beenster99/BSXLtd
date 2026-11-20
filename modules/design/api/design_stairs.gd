class_name DesignStairs
extends RefCounted
## Where the flight of stairs stands in a stairwell (beenster, 20 Nov: "the stairs are always
## the length of the room - so there is no space to get on the stairs or get off them"): a
## flight of a fixed run for the deck height, with a landing at its foot and one at its head,
## along the room's long side, against one of its long walls. The room says which way it climbs
## ("stair_flip") and which wall it stands against ("stair_side"). Walk-inside builds it, the
## plan draws it, the rules check there is room for it.
##   var f := DesignStairs.flight(room, rec.deck_height)   # {rect, along_z, climbs, length, ...}

## How far a flight runs for each metre it climbs (a steep ship's stair, about 45 degrees).
const RUN_PER_RISE := 1.0
## The clear floor at the foot of the flight and at its head, m.
const LANDING := 0.9
## The flight's width, m (at most half the room's width, so there is a way past it).
const WIDTH := 1.2


## The run a flight needs for a deck `height` m high, m.
static func run_for(height: float) -> float:
	return height * RUN_PER_RISE


## The length a stairwell needs along its long side: foot landing, flight, head landing, m.
static func needs(height: float) -> float:
	return LANDING + run_for(height) + LANDING


## The flight in stairs room `r` for decks `height` m apart: {rect (plan, m), along_z, climbs
## (+1: towards +Z or +X, -1 back), length (its run), width, foot (the landing at its foot),
## head (the landing past its top, on the deck above), fits (room for both landings)}.
static func flight(r: Dictionary, height: float) -> Dictionary:
	var along_z := float(r.d) >= float(r.w)
	var room_len := float(r.d) if along_z else float(r.w)
	var across := float(r.w) if along_z else float(r.d)
	var width := minf(WIDTH, across * 0.5)
	var run := run_for(height)
	var fits := room_len + 0.01 >= needs(height)
	# Too short: the flight takes what is left between two equal landings, never under half.
	var length := run if fits else maxf(room_len - 2.0 * LANDING, room_len * 0.5)
	var start := LANDING if fits else (room_len - length) * 0.5
	var climbs := -1 if bool(r.get("stair_flip", false)) else 1
	# Climbing back (-1), the foot is at the far end.
	var s0 := start if climbs > 0 else room_len - start - length
	var side_far := bool(r.get("stair_side", false))
	var c0 := (across - width) if side_far else 0.0
	var rx := float(r.x)
	var rz := float(r.z)
	var rect := Rect2(rx + c0, rz + s0, width, length) if along_z else Rect2(rx + s0, rz + c0, length, width)
	var foot_s := s0 - LANDING if climbs > 0 else s0 + length
	var head_s := s0 + length if climbs > 0 else s0 - LANDING
	return {"rect": rect, "along_z": along_z, "climbs": climbs, "length": length, "width": width,
			"foot": _strip(rx, rz, along_z, foot_s, c0, width), "head": _strip(rx, rz, along_z, head_s, c0, width),
			"fits": fits}


static func _strip(rx: float, rz: float, along_z: bool, s: float, c: float, width: float) -> Rect2:
	return Rect2(rx + c, rz + s, width, LANDING) if along_z else Rect2(rx + s, rz + c, LANDING, width)
