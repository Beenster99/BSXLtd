class_name WireCircuit
extends RefCounted
## One circuit on the wiring test board: a 24 V supply, a switch and a lamp, each with two
## screw terminals. Lay a wire between two terminals, strip each end, crimp a ferrule on it
## (it goes into its terminal), then flip the switch to test. The right circuit is
## S+ to COM, NO to L+, L- to S-. Pure logic with no nodes, so tests drive it directly.

signal changed
signal completed

enum End { EMPTY, LAID, STRIPPED, TERMINATED }

const TERMINALS: Array[StringName] = [&"S+", &"S-", &"COM", &"NO", &"L+", &"L-"]
const SUPPLY_POS := 0
const SUPPLY_NEG := 1
const SWITCH_COM := 2
const SWITCH_NO := 3
const LAMP_POS := 4
const LAMP_NEG := 5
const COLOURS: Array[StringName] = [&"red", &"black"]

var spec: JointSpec
## What the ferrules want, and what the test bench checks against.
var strip_target_mm := 8.0
var ferrule_mm := 8.0
## Below this strip the ferrule only grips insulation.
var short_strip_mm := 5.0
## Copper showing past the ferrule beyond this drops the insulation reading.
var bare_limit_mm := 1.5
var crimp_min_n := 250.0
var continuity_max_ohm := 0.5
var insulation_min_mohm := 100.0
## Ohms per wire run, and per end on top of the crimp's own.
var wire_ohm := 0.05
var end_ohm := 0.01
## A crimp closed less than this is no contact at all.
var min_contact := 0.3

## Each wire: {"a": terminal, "b": terminal, "colour": StringName}.
var wires: Array[Dictionary] = []
var end_state: Array[End] = []
var strip_mm: PackedFloat64Array
var crimp: PackedFloat64Array
var switch_on := false
var lamp_lit := false
var _complete := false


func _init(p_spec: JointSpec) -> void:
	spec = p_spec
	reset()


func reset() -> void:
	wires.clear()
	end_state.clear()
	for t in TERMINALS.size():
		end_state.append(End.EMPTY)
	strip_mm = PackedFloat64Array()
	strip_mm.resize(TERMINALS.size())
	crimp = PackedFloat64Array()
	crimp.resize(TERMINALS.size())
	switch_on = false
	lamp_lit = false
	_complete = false
	changed.emit()


## Lay a wire between two free terminals.
func lay(a: int, b: int, colour: StringName) -> bool:
	if a == b or end_state[a] != End.EMPTY or end_state[b] != End.EMPTY:
		return false
	wires.append({"a": a, "b": b, "colour": colour})
	end_state[a] = End.LAID
	end_state[b] = End.LAID
	_reset_end(a)
	_reset_end(b)
	_retest()
	return true


## Pull the wire at this terminal right off the board. True if the circuit had been
## finished (so its result is stale).
func remove_wire_at(t: int) -> bool:
	var w := wire_at(t)
	if w < 0:
		return false
	var was := _complete
	_complete = false
	for end: int in [wires[w].a, wires[w].b]:
		end_state[end] = End.EMPTY
		_reset_end(end)
	wires.remove_at(w)
	_retest()
	return was


func wire_at(t: int) -> int:
	for i in wires.size():
		if wires[i].a == t or wires[i].b == t:
			return i
	return -1


func strip(t: int, mm: float) -> bool:
	if end_state[t] != End.LAID:
		return false
	strip_mm[t] = maxf(0.0, mm)
	end_state[t] = End.STRIPPED
	changed.emit()
	return true


## Crimp a ferrule on a stripped end, closed `closed` of the way (1 = the tool's click),
## and screw it into its terminal.
func crimp_end(t: int, closed: float) -> bool:
	if end_state[t] != End.STRIPPED:
		return false
	crimp[t] = clampf(closed, 0.0, 1.0)
	end_state[t] = End.TERMINATED
	_retest()
	return true


## Cut a bad end off back to plain wire. True if the circuit had been finished.
func cut_back(t: int) -> bool:
	if end_state[t] != End.STRIPPED and end_state[t] != End.TERMINATED:
		return false
	var was := _complete
	_complete = false
	end_state[t] = End.LAID
	_reset_end(t)
	_retest()
	return was


## Flip the switch. Switching on with every laid end terminated is the test that finishes
## the circuit, lit or not.
func set_switch(on: bool) -> void:
	switch_on = on
	_retest()
	if on and not _complete and is_ready_to_test():
		_complete = true
		completed.emit()


func is_ready_to_test() -> bool:
	if wires.is_empty():
		return false
	for w in wires:
		if end_state[w.a] != End.TERMINATED or end_state[w.b] != End.TERMINATED:
			return false
	return true


func is_complete() -> bool:
	return _complete


func progress() -> float:
	var done := 0.0
	for s in end_state:
		done += float(s) / float(End.TERMINATED)
	return done / float(TERMINALS.size())


func crimp_pull_n(t: int) -> float:
	var n := 40.0 + 270.0 * crimp[t]
	return n * 0.6 if strip_mm[t] < short_strip_mm else n


func bare_mm(t: int) -> float:
	return maxf(0.0, strip_mm[t] - ferrule_mm)


## How the board tests right now: {lit, short, polarity_ok} with the ends as they are.
func evaluate(on: bool, ideal_ends := false) -> Dictionary:
	var parent: Array[int] = []
	for t in TERMINALS.size():
		parent.append(t)
	for w in wires:
		if ideal_ends or (_contact(w.a) and _contact(w.b)):
			_join(parent, w.a, w.b)
	if on:
		_join(parent, SWITCH_COM, SWITCH_NO)
	var sp := _find(parent, SUPPLY_POS)
	var sn := _find(parent, SUPPLY_NEG)
	var lp := _find(parent, LAMP_POS)
	var ln := _find(parent, LAMP_NEG)
	var short := sp == sn
	var lit := not short and ((sp == lp and sn == ln) or (sp == ln and sn == lp))
	return {"lit": lit, "short": short, "polarity_ok": lit and sp == lp}


## The wiring is wrong whatever the crimps: a short, a lamp that ignores the switch, or no
## path through the lamp at all.
func is_miswired() -> bool:
	var on := evaluate(true, true)
	var off := evaluate(false, true)
	return on.short or off.lit or not on.lit


func continuity_ohm() -> float:
	if not evaluate(true).lit:
		return -1.0
	var ohm := wire_ohm * wires.size()
	for w in wires:
		for t: int in [w.a, w.b]:
			ohm += end_ohm + 0.5 * pow(1.0 - crimp[t], 2.0) + (0.3 if strip_mm[t] < short_strip_mm else 0.0)
	return ohm


func insulation_mohm() -> float:
	if evaluate(true, true).short:
		return 0.0
	for w in wires:
		for t: int in [w.a, w.b]:
			if bare_mm(t) > bare_limit_mm:
				return 2.0
	return 500.0


## Red on the supply's positive side (switched or not), black on the return.
func colour_ok() -> bool:
	var parent: Array[int] = []
	for t in TERMINALS.size():
		parent.append(t)
	for w in wires:
		_join(parent, w.a, w.b)
	_join(parent, SWITCH_COM, SWITCH_NO)
	var positive := _find(parent, SUPPLY_POS)
	for w in wires:
		var want: StringName = &"red" if _find(parent, w.a) == positive else &"black"
		if w.colour != want:
			return false
	return true


func measurements() -> Dictionary:
	var strips: Array[float] = []
	var pulls: Array[float] = []
	var bare: Array[float] = []
	var ends: Array[StringName] = []
	for t in TERMINALS.size():
		if end_state[t] != End.TERMINATED:
			continue
		ends.append(TERMINALS[t])
		strips.append(snappedf(strip_mm[t], 0.1))
		pulls.append(snappedf(crimp_pull_n(t), 1.0))
		bare.append(snappedf(bare_mm(t), 0.1))
	var test := evaluate(true)
	return {
		"strip_length_mm": strips,
		"strip_length_target_mm": strip_target_mm,
		"crimp_pull_n": pulls,
		"crimp_pull_min_n": crimp_min_n,
		"continuity_ohm": snappedf(continuity_ohm(), 0.001),
		"continuity_max_ohm": continuity_max_ohm,
		"insulation_mohm": insulation_mohm(),
		"insulation_min_mohm": insulation_min_mohm,
		"polarity_ok": test.polarity_ok,
		"miswired": is_miswired(),
		"bare_mm": bare,
		"colour_ok": colour_ok(),
		"terminals": ends,
		"wire_count": wires.size(),
	}


func _contact(t: int) -> bool:
	return end_state[t] == End.TERMINATED and crimp[t] >= min_contact


func _reset_end(t: int) -> void:
	strip_mm[t] = 0.0
	crimp[t] = 0.0


func _retest() -> void:
	lamp_lit = switch_on and evaluate(true).lit
	changed.emit()


static func _find(parent: Array[int], t: int) -> int:
	while parent[t] != t:
		t = parent[t]
	return t


static func _join(parent: Array[int], a: int, b: int) -> void:
	parent[_find(parent, a)] = _find(parent, b)
