class_name TradesWireLoom
extends RefCounted
## The wiring diagram job on a ship's plug (beenster, 2026-10-21: "a sort of wire dragging
## exercise against a wiring diagram"). The ship's loom ends at the plug in a bundle of
## coloured tails that come already crimped; the diagram says which pin each colour lands
## on. Drag every tail onto its pin, then plug in: the pins test green or red, and Quality
## gets the readings. Pure logic with no nodes, so tests drive it directly.

## Wire colours: [main, stripe (or transparent), name on the diagram].
const COLOURS := {
	&"red": [Color(0.8, 0.12, 0.1), Color.TRANSPARENT, "RED"],
	&"black": [Color(0.08, 0.08, 0.09), Color.TRANSPARENT, "BLACK"],
	&"blue": [Color(0.15, 0.35, 0.85), Color.TRANSPARENT, "BLUE"],
	&"white_blue": [Color(0.92, 0.92, 0.9), Color(0.15, 0.35, 0.85), "WHITE / BLUE"],
	&"yellow": [Color(0.95, 0.8, 0.15), Color.TRANSPARENT, "YELLOW"],
	&"green_yellow": [Color(0.2, 0.62, 0.25), Color(0.95, 0.8, 0.15), "GREEN / YELLOW"],
	&"orange": [Color(0.95, 0.5, 0.12), Color.TRANSPARENT, "ORANGE"],
	&"white_orange": [Color(0.92, 0.92, 0.9), Color(0.95, 0.5, 0.12), "WHITE / ORANGE"],
	&"grey": [Color(0.55, 0.57, 0.6), Color.TRANSPARENT, "GREY"],
}
## What each kind of plug carries, in pin order: [signal, colour]. The first pin is the
## supply's positive; the returns are the pins a positive wire shorts on.
const LOOMS := {
	"power": [["+28 V", &"red"], ["0 V", &"black"], ["VALVE +", &"white_blue"], ["VALVE -", &"blue"],
			["TEMP", &"yellow"], ["CHASSIS", &"green_yellow"]],
	"data": [["+5 V", &"red"], ["CAN H", &"white_orange"], ["CAN L", &"orange"], ["0 V", &"black"],
			["SHIELD", &"grey"]],
}
const RETURNS: Array[String] = ["0 V", "CHASSIS", "SHIELD"]
## Readings: the tails come crimped at the factory, so their ends are always to spec.
const STRIP_MM := 8.0
const CRIMP_N := 310.0
const CRIMP_MIN_N := 250.0
const WIRE_OHM := 0.03
const PLUG_OHM := 0.05
const CONTINUITY_MAX_OHM := 0.5
const INSULATION_MIN_MOHM := 100.0

var kind := ""
var joint_id := ""
## Each pin: {signal, colour}. Wire i is the tail meant for pin i.
var pins: Array[Dictionary] = []
## The tails down the side of the panel, top to bottom (wire indices, shuffled per plug).
var order: PackedInt32Array
## Where each wire has landed: a pin index, or -1 when it hangs loose.
var landed: PackedInt32Array
## Set by plug_in(): the plug is in with the wires as they are now.
var tested := false


static func supports(spec: String) -> bool:
	return LOOMS.has(spec)


func _init(p_kind: String, p_joint_id: String) -> void:
	kind = p_kind
	joint_id = p_joint_id
	for p: Array in LOOMS.get(kind, []):
		pins.append({"signal": p[0], "colour": p[1]})
	landed = PackedInt32Array()
	landed.resize(pins.size())
	landed.fill(-1)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(joint_id)
	var idx: Array = range(pins.size())
	# A seeded Fisher-Yates, so every machine and every visit sees the same tails.
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = idx[i]
		idx[i] = idx[j]
		idx[j] = t
	order = PackedInt32Array(idx)


## Land a wire on a pin. A wire already on that pin goes back to hanging loose.
func land(wire: int, pin: int) -> void:
	for w in landed.size():
		if landed[w] == pin and w != wire:
			landed[w] = -1
	landed[wire] = pin
	tested = false


func lift(wire: int) -> void:
	landed[wire] = -1
	tested = false


func clear() -> void:
	landed.fill(-1)
	tested = false


## The wire on a pin, or -1.
func wire_on(pin: int) -> int:
	for w in landed.size():
		if landed[w] == pin:
			return w
	return -1


func all_landed() -> bool:
	return not landed.has(-1)


func landed_count() -> int:
	return landed.size() - landed.count(-1)


## Per pin: the right wire is on it.
func pins_ok() -> Array[bool]:
	var out: Array[bool] = []
	for p in pins.size():
		out.append(wire_on(p) == p)
	return out


func is_right() -> bool:
	return not pins_ok().has(false)


func wrong_count() -> int:
	return pins_ok().count(false)


## The positive wire lands on a return pin.
func is_short() -> bool:
	var at := landed[0]
	return at >= 0 and RETURNS.has(String(pins[at].signal))


func plug_in() -> void:
	tested = true


## What Quality gets (the WIRE keys of the interface spec, section 4.7). A wrong or empty pin
## reads open on its line, so the continuity test fails.
func measurements() -> Dictionary:
	var n := pins.size()
	var strips: Array[float] = []
	var pulls: Array[float] = []
	var names: Array[StringName] = []
	for p in pins:
		strips.append(STRIP_MM)
		pulls.append(CRIMP_N)
		names.append(StringName(p.signal))
	var right := is_right()
	return {
		"strip_length_mm": strips,
		"strip_length_target_mm": STRIP_MM,
		"crimp_pull_n": pulls,
		"crimp_pull_min_n": CRIMP_MIN_N,
		"continuity_ohm": snappedf(PLUG_OHM + WIRE_OHM * n, 0.001) if right else -1.0,
		"continuity_max_ohm": CONTINUITY_MAX_OHM,
		"insulation_mohm": 0.0 if is_short() else 500.0,
		"insulation_min_mohm": INSULATION_MIN_MOHM,
		"polarity_ok": landed[0] == 0 and wire_on(_zero()) == _zero(),
		"miswired": not right,
		"bare_mm": [],
		"colour_ok": true,
		"terminals": names,
		"wire_count": n,
		"pins_ok": pins_ok(),
		"wrong_pins": wrong_count(),
		"factory_terminated": true,
		"diagram": kind,
	}


func _zero() -> int:
	for p in pins.size():
		if pins[p].signal == "0 V":
			return p
	return 1


static func colour_of(id: StringName) -> Color:
	return COLOURS[id][0]


static func stripe_of(id: StringName) -> Color:
	return COLOURS[id][1]


static func colour_name(id: StringName) -> String:
	return COLOURS[id][2]
