extends RefCounted
## The state of every mount slot on the loaded ship, and the rules for moving between
## states (the table in the Ship and Bay doc). Pure data: the bus turns each change into
## signals, and Multiplayer will sync those signals rather than this.

const State := ShipBayBus.SlotState

## Called for every change: emit.call(signal_name, args: Array).
var emit: Callable
var _def: ShipDefinition
## slot_id -> {state, component, tight: {joint_id: quality}, tight_state}
var _slots: Dictionary = {}


func _init(def: ShipDefinition, on_change: Callable) -> void:
	_def = def
	emit = on_change
	for s in def.slots:
		var tight := {}
		if s.fitted != "":
			for f in s.fasteners:
				tight[f.joint_id] = 1.0
		_slots[s.slot_id] = {"state": State.FITTED if s.fitted != "" else State.EMPTY,
				"component": s.fitted, "tight": tight, "tight_state": State.FITTED}


func state(slot_id: String) -> int:
	return _slots[slot_id].state if _slots.has(slot_id) else -1


func component(slot_id: String) -> String:
	return _slots[slot_id].component if _slots.has(slot_id) else ""


func is_tight(joint_id: String) -> bool:
	var r: Dictionary = _slots.get(FastenerPoint.slot_of(joint_id), {})
	return r.has("tight") and r.tight.has(joint_id)


func joint_quality(joint_id: String) -> float:
	var r: Dictionary = _slots.get(FastenerPoint.slot_of(joint_id), {})
	return r.tight.get(joint_id, 0.0) if r.has("tight") else 0.0


func try_position(slot_id: String, comp: String) -> bool:
	var s := _def.slot(slot_id)
	if s == null or state(slot_id) != State.EMPTY or not s.takes(comp):
		return false
	_slots[slot_id].component = comp
	_set_state(slot_id, State.POSITIONED)
	emit.call("component_positioned", [slot_id, comp])
	return true


## Lifts a positioned part back off before anything holds it.
func try_remove(slot_id: String) -> bool:
	var r: Dictionary = _slots.get(slot_id, {})
	if r.is_empty() or r.state != State.POSITIONED or not r.tight.is_empty():
		return false
	var comp: String = r.component
	r.component = ""
	_set_state(slot_id, State.EMPTY)
	emit.call("component_removed", [slot_id, comp])
	return true


func joint_made(joint_id: String, quality: float) -> bool:
	var slot_id := FastenerPoint.slot_of(joint_id)
	var s := _def.slot(slot_id)
	if s == null or s.fastener(joint_id) == null:
		return false
	var r: Dictionary = _slots[slot_id]
	if r.state == State.EMPTY or r.tight.has(joint_id):
		return false
	r.tight[joint_id] = clampf(quality, 0.0, 1.0)
	if r.tight.size() == s.fasteners.size():
		if r.state == State.POSITIONED:
			_set_state(slot_id, State.INSTALLED)
			emit.call("component_installed", [slot_id, r.component])
		elif r.state == State.LOOSENED:
			_set_state(slot_id, r.tight_state)
	return true


func joint_removed(joint_id: String) -> bool:
	var slot_id := FastenerPoint.slot_of(joint_id)
	var r: Dictionary = _slots.get(slot_id, {})
	if r.is_empty() or not r.tight.has(joint_id):
		return false
	r.tight.erase(joint_id)
	if r.state == State.FITTED or r.state == State.INSTALLED:
		r.tight_state = r.state
		_set_state(slot_id, State.LOOSENED)
	if r.state == State.LOOSENED and r.tight.is_empty():
		var comp: String = r.component
		r.component = ""
		_set_state(slot_id, State.EMPTY)
		emit.call("component_removed", [slot_id, comp])
	return true


func snapshot() -> Dictionary:
	var out := {}
	for id: String in _slots:
		var r: Dictionary = _slots[id]
		out[id] = {"state": r.state, "component": r.component, "tight": r.tight.duplicate(),
				"tight_state": r.tight_state}
	return out


## Puts every slot back as `snap` has it. Slots the snapshot doesn't name keep their state.
func restore(snap: Dictionary) -> void:
	for id: String in snap:
		if not _slots.has(id):
			continue
		var r: Dictionary = snap[id]
		var old: int = _slots[id].state
		_slots[id] = {"state": int(r.get("state", State.EMPTY)), "component": r.get("component", ""),
				"tight": (r.get("tight", {}) as Dictionary).duplicate(),
				"tight_state": int(r.get("tight_state", State.FITTED))}
		if old != _slots[id].state:
			emit.call("slot_state_changed", [id, old, _slots[id].state])


func _set_state(slot_id: String, new_state: int) -> void:
	var old: int = _slots[slot_id].state
	if old == new_state:
		return
	_slots[slot_id].state = new_state
	emit.call("slot_state_changed", [slot_id, old, new_state])
