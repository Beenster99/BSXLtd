class_name TradesTractor
extends Node3D
## The tractor beam (tool 7) in the yard: lifts parts that have come off the ship, carries
## them, and lines them up with their mounts so they can be fastened again.
##
##   aim at a loose part, hold left click   the beam takes it where it is
##   look about, walk                       it follows, out along the beam
##   mouse wheel                            pull it in / push it out
##   hold R (rebindable) and move the mouse  turn it any way: sideways round the vertical,
##                                          up and down tips it toward or away from you
##   Q / E                                  turn it a step round the vertical
##   let go                                 it drops, or stays locked in its mount when in line
##   right click while holding              park it hovering there (pick it up again later)
##
## Near its own mount the beam eases the part into line; in line (green) it seats in its
## slot (ShipBayBus.try_position) while the beam holds it, so one player can hold a part
## up while another puts in the first bolt, rivet or weld. Letting go in line locks it
## there (the solo way: lock it, then fasten it yourself); drifting out of line or lifting
## it before any joint is in takes it back off. The first joint ends the hold. Multiplayer
## sees each hold ("unit:<slot>", MultiplayerBus.set_hold) and moves each loose part
## (register_mover); Multiplayer is optional here, so it is reached untyped.
## A part still held by its joints only says how many are left. Owned by the ship station
## (TradesShipJoints), which hands it the tractor's input.
##
## Nothing that comes off the ship disappears: its loose copy hovers where it was and the
## yard sends a hover trolley big enough for it (ShipBayBus.beam_to_trolley). A yard beam
## reaches from the part to the trolley's deck while it comes, and once the part is on the
## deck as a crate (Ship and Bay's part_beamed) the copy goes: it is stock now, to take off
## the trolley, put away or fetch for a refit. A player who takes the part with their own
## beam first calls the trolley off (cancel_beam); dropped away from the mount, it is sent
## for again. No trolley free: it waits and asks again. The trolley calls are Ship and
## Bay's, reached by name, so they work once it offers them.

const RANGE_M := 9.0
## trades.quiet_tractor: the beam's hum and its clunks this much quieter (dB).
const QUIET_DB := -14.0
const MIN_M := 1.0
const PUSH_STEP_M := 0.25
const TURN_STEP_DEG := 15.0
## Within these of its mount the beam starts drawing the part into line (metres, degrees).
const DRAW_M := 0.35
const DRAW_DEG := 25.0
## In line: close enough to seat.
const LINE_M := 0.04
const LINE_DEG := 4.0
## How quickly a held part catches up with the beam (per second).
const FOLLOW := 7.0
## Holding the rotate key, the part turns this much per pixel of mouse (degrees).
const ROTATE_DEG_PER_PX := 0.35

var station: TradesShipJoints
## slot_id -> TradesLoosePart, every part off the ship.
var loose: Dictionary = {}
var held: TradesLoosePart
## The held part is in line with its mount.
var aligned := false
## The unit ids holds were last sent for, with the aligned flag sent.
var _sent: Dictionary = {}
## slot_id -> the trolley coming for that part.
var to_trolley: Dictionary = {}
## slot_id -> seconds until asking for a trolley again (none was free).
var _retry: Dictionary = {}
## slot_id -> the yard beam drawn from the part to its trolley.
var _yard_beams: Dictionary = {}
## Stands in for Ship and Bay's trolley calls when set (tests).
var trolley_api: Object

var _bus: ShipBayBus
var _distance := 3.0
## The held part in the beam's frame (the aim point, turned with the worker).
var _grip := Transform3D.IDENTITY
var _beam: TradesBeamLine
var _glow: OmniLight3D


func _ready() -> void:
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if _bus:
		_bus.component_removed.connect(_on_component_removed)
		_bus.component_positioned.connect(_on_component_positioned)
		_bus.ship_unloaded.connect(func(_id: String) -> void: clear())
		# Ship and Bay's, once it has trolleys that take parts.
		if _bus.has_signal("part_beamed"):
			_bus.connect("part_beamed", _on_part_beamed)
		if _bus.has_signal("clean_up_claimed"):
			_bus.connect("clean_up_claimed", _on_clean_up_claimed)
	_beam = TradesBeamLine.new()
	add_child(_beam)
	_glow = OmniLight3D.new()
	_glow.top_level = true
	_glow.omni_range = 4.0
	_glow.light_energy = 1.2
	_glow.visible = false
	add_child(_glow)


func is_holding() -> bool:
	return held != null


## The loose part under the aim within range, or null.
func aimed_part() -> TradesLoosePart:
	var worker := station.bay.worker
	var best: TradesLoosePart
	var best_d := RANGE_M
	for p: TradesLoosePart in loose.values():
		var at: Variant = p.hit(worker.aim_origin(), worker.aim_dir())
		if at != null:
			var d := (at as Vector3).distance_to(worker.aim_origin())
			if d < best_d:
				best = p
				best_d = d
	return best


## Where the aim meets a slot whose part is still on the ship, or "".
func aimed_slot() -> String:
	if _bus == null:
		return ""
	var worker := station.bay.worker
	var inv := station.ship_xform.affine_inverse()
	var from := inv * worker.aim_origin()
	var dir := inv.basis * worker.aim_dir()
	var best := ""
	var best_d := RANGE_M
	for slot in _bus.get_slots():
		if loose.has(slot.slot_id):
			continue
		var at: Variant = slot.box.intersects_ray(from, dir)
		if at != null and (at as Vector3).distance_to(from) < best_d:
			best = slot.slot_id
			best_d = (at as Vector3).distance_to(from)
	return best


# --- Input from the station ---------------------------------------------------------------

func press() -> void:
	var part := aimed_part()
	if part == null:
		var slot_id := aimed_slot()
		if slot_id == "":
			station.bay.hint("Aim the beam at a part that's come off the ship.")
		elif not _lift_seated(slot_id):
			var slot := _bus.get_slot(slot_id)
			var total := slot.fasteners.size()
			var left := 0
			for f in slot.fasteners:
				if _bus.is_joint_tight(f.joint_id):
					left += 1
			station.bay.hint("%s is still held on: %d of its %d joints are in. Take them all off first." %
					[slot.display_name if slot.display_name != "" else slot_id, left, total])
		return
	_cancel_trolley(part.slot_id)
	_take(part)


## How fast the held part is moving (m/s), so letting go throws it.
var _held_velocity := Vector3.ZERO


func release() -> void:
	if held == null:
		return
	var part := held
	held = null
	_stop_beam()
	if part.seated:
		_lock(part)
	else:
		part.drop(_held_velocity if clean_up() else Vector3.ZERO)
		_end_hold(part)
		if clean_up():
			_note_loose(part)
		else:
			_send_to_trolley(part)
		station.bay.hint("Let go.")
	aligned = false
	_emit(part, false)


## Right click while holding: leave it hovering there (or locked in its mount, in line).
func park() -> bool:
	if held == null:
		return false
	var part := held
	held = null
	_stop_beam()
	if part.seated:
		_lock(part)
	else:
		part.anchor()
		_end_hold(part)
		if clean_up():
			_note_loose(part)
		station.bay.hint("Parked in the air. Hold left click on it to take it again.")
	aligned = false
	_emit(part, false)
	return true


## Let go of it in line: it stays locked in its mount for its first joint.
func _lock(part: TradesLoosePart) -> void:
	part.anchor()
	_send_hold(part, true, true)
	station.bay.play(&"clunk", 0.7, _db())
	station.bay.hint("Locked in line in its mount. Fasten it: the first joint holds it.")


## The beam's hold on this part may stop the first joint going in (another player's beam
## holding it out of line). True blocks.
func blocks_first_joint(slot_id: String) -> bool:
	var net := _net()
	if net == null:
		return false
	var unit := unit_id(slot_id)
	return not (net.call("hold_info", unit) as Dictionary).is_empty() and not net.call("is_hold_ready", unit)


static func unit_id(slot_id: String) -> String:
	return "unit:" + slot_id


## Wheel while holding: pull in (-1) or push out (+1).
func push(step: int) -> bool:
	if held == null:
		return false
	_distance = clampf(_distance + step * PUSH_STEP_M, MIN_M, RANGE_M)
	return true


## Mouse movement while the rotate key is held: turn the part round its own middle, sideways
## round the vertical and up and down round the line across your view. True while holding.
func rotate_by(relative: Vector2) -> bool:
	if held == null:
		return false
	var k := deg_to_rad(ROTATE_DEG_PER_PX)
	var turn := Basis(Vector3.UP, relative.x * k) * Basis(Vector3.RIGHT, relative.y * k)
	var middle := _grip * held.outline.get_center()
	_grip = Transform3D(Basis.IDENTITY, middle) * Transform3D(turn, Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -middle) * _grip
	_grip = _grip.orthonormalized()
	return true


## Q / E while holding: turn it a step round the vertical.
func turn(step: int) -> bool:
	if held == null:
		return false
	_grip = Transform3D(Basis(Vector3.UP, deg_to_rad(TURN_STEP_DEG) * step), Vector3.ZERO) * _grip
	return true


## The part in the beam or under its aim, for the tips' heading ("" for none).
func aim_title() -> String:
	var part := held if held else aimed_part()
	if part == null:
		return ""
	var slot := _bus.get_slot(part.slot_id) if _bus else null
	var what := slot.display_name if slot and slot.display_name != "" else part.slot_id
	return ("In the beam: %s" if held else "%s, off the ship") % what


## The tips for the beam (TradesStation.actions): holding a part, or what's under the aim.
func actions() -> Array:
	if held:
		var rotate := Keys.key_name(TradesBus.KEY_ROTATE) if InputMap.has_action(TradesBus.KEY_ROTATE) else "-"
		return [["Let go", "lock it in its mount" if aligned else "drop it"],
				[TradesBay.WHEEL, "pull it in, push it out"],
				["Hold %s, move the mouse" % rotate, "turn it any way"],
				["%s / %s" % [Keys.key_name(TradesBus.KEY_TURN_LEFT), Keys.key_name(TradesBus.KEY_TURN_RIGHT)], "turn it a step"],
				[TradesBay.RIGHT_CLICK, "park it in the air"]]
	if aimed_part():
		return [[TradesBay.HOLD_CLICK, "lift it with the beam"]]
	var slot_id := aimed_slot()
	if slot_id != "" and _bus and _bus.get_slot_state(slot_id) == ShipBayBus.SlotState.POSITIONED and _tight(slot_id) == 0:
		return [[TradesBay.HOLD_CLICK, "lift it off its mount"]]
	return []


func status_line() -> String:
	if held == null:
		return "Tractor: %d part%s off the ship" % [loose.size(), "" if loose.size() == 1 else "s"]
	return "TRACTOR  %s  %s" % [held.slot_id.to_upper(), "IN LINE" if aligned else "OUT %.1f m" % _distance]


# --- Every frame --------------------------------------------------------------------------

func update(delta: float) -> void:
	# A seated part whose first joint is in is held by the ship now.
	for p: TradesLoosePart in loose.values():
		if p.seated and _tight(p.slot_id) > 0:
			_finish(p)
	_update_trolleys(delta)
	var tool := station.bay.tool_node(&"tractor") as TradesTractorTool
	if held == null or not is_instance_valid(held):
		held = null
		if tool:
			tool.on = false
		return
	var worker := station.bay.worker
	var target := _beam_frame() * _grip
	var home := station.ship_xform * _bus.get_slot(held.slot_id).mount
	var off_m := target.origin.distance_to(home.origin)
	var off_deg := rad_to_deg(target.basis.get_rotation_quaternion().angle_to(home.basis.get_rotation_quaternion()))
	aligned = false
	if off_m < DRAW_M and off_deg < DRAW_DEG:
		# Near its mount the beam draws it into line.
		var pull := 1.0 - maxf(off_m / DRAW_M, off_deg / DRAW_DEG)
		target = target.interpolate_with(home, smoothstep(0.0, 1.0, pull))
		aligned = target.origin.distance_to(home.origin) < LINE_M and rad_to_deg(
				target.basis.get_rotation_quaternion().angle_to(home.basis.get_rotation_quaternion())) < LINE_DEG
		if aligned:
			target = home
	var t := 1.0 - exp(-FOLLOW * delta)
	var was := held.global_position
	held.global_transform = held.global_transform.interpolate_with(target, t)
	if delta > 0.0:
		_held_velocity = (held.global_position - was) / delta
	var state := _bus.get_slot_state(held.slot_id)
	if aligned and not held.seated and state == ShipBayBus.SlotState.EMPTY:
		if _bus.try_position(held.slot_id, held.component):
			station.bay.play(&"clunk", 0.8, _db())
			station.bay.hint("In line and seated. Keep holding while it's fastened, or let go to lock it.")
	elif not aligned and held.seated and _tight(held.slot_id) == 0:
		_bus.try_remove(held.slot_id)
	if not _sent.has(unit_id(held.slot_id)) or _sent[unit_id(held.slot_id)] != aligned:
		_send_hold(held, aligned, false)
	var line := clampf(1.0 - maxf(off_m / DRAW_M, off_deg / DRAW_DEG), 0.0, 1.0)
	# The projector in the right hand, its beam on the part's middle.
	if tool:
		tool.on = true
		tool.load_kg = held.mass
		tool.distance_m = worker.aim_origin().distance_to(held.centre())
		tool.align = 1.0 if aligned else line
		var palm := worker.right_hand.palm()
		station.bay.place_tool(&"tractor", tool.carried(palm))
		_draw_beam(tool.beam_from(), held.centre(), delta)
	station.bay.loop(&"beam", true, 0.9 + (0.2 if aligned else 0.0))
	_emit(held, true)


## The beam's frame: at the aim point `_distance` out, turned with the worker.
func _beam_frame() -> Transform3D:
	var worker := station.bay.worker
	return Transform3D(Basis(Vector3.UP, worker.global_rotation.y), worker.aim_origin() + worker.aim_dir() * _distance)


func _take(part: TradesLoosePart) -> void:
	_forget_loose(part.slot_id)
	_held_velocity = Vector3.ZERO
	held = part
	part.take_hold()
	_distance = clampf(station.bay.worker.aim_origin().distance_to(part.centre()), MIN_M, RANGE_M)
	_grip = _beam_frame().affine_inverse() * part.global_transform
	station.bay.play(&"click", 0.6, _db())
	station.bay.hint("Got it. Wheel pulls in and pushes out, hold %s and move the mouse to turn it, right click parks it." %
			Keys.key_name(TradesBus.KEY_ROTATE))


## A part sitting in its mount with nothing fastened yet comes straight back off.
func _lift_seated(slot_id: String) -> bool:
	if _bus.get_slot_state(slot_id) != ShipBayBus.SlotState.POSITIONED:
		return false
	for f in _bus.get_fasteners(slot_id):
		if _bus.is_joint_tight(f.joint_id):
			return false
	if not _bus.try_remove(slot_id):
		return false
	var part: TradesLoosePart = loose.get(slot_id)
	if part:
		_take(part)
		station.bay.hint("Lifted back off its mount.")
	return part != null


func _stop_beam() -> void:
	_beam.hide_line()
	_glow.visible = false
	station.bay.loop(&"beam", false)
	var tool := station.bay.tool_node(&"tractor") as TradesTractorTool
	if tool:
		tool.on = false
		tool.align = -1.0


func _draw_beam(from: Vector3, to: Vector3, delta: float) -> void:
	var color := TradesTractorTool.ALIGNED_COLOR if aligned else TradesTractorTool.BEAM_COLOR
	_beam.color = color
	_beam.draw(from, to, delta)
	_glow.global_position = to
	_glow.light_color = color
	_glow.visible = true


## How far the beam bends behind a quick swing (metres; tests).
func beam_bend() -> float:
	return _beam.bend() if _beam.visible else 0.0


# --- Parts coming off and going on -------------------------------------------------------------

func _on_component_removed(slot_id: String, comp: String) -> void:
	if _bus == null:
		return
	var existing: TradesLoosePart = loose.get(slot_id)
	if existing:
		# Out of its mount again: the copy is the part once more.
		existing.set_seated(false)
		return
	var slot := _bus.get_slot(slot_id)
	if slot == null:
		return
	var visual: Node3D
	var yard := station.bay.get_parent() as Node3D
	if yard and _bus.has_method("part_visual"):
		visual = _bus.call("part_visual", yard, slot_id) as Node3D
	var part := TradesLoosePart.new()
	part.top_level = true
	add_child(part)
	part.setup(slot, comp, visual)
	part.global_transform = station.ship_xform * slot.mount
	loose[slot_id] = part
	var net := _net()
	if net:
		net.call("register_mover", unit_id(slot_id), part)
	if clean_up():
		# Ship and Bay's clean-up (beenster, 0.3.8): it falls where it comes off and lies there,
		# losing condition on hard landings, until a trolley is told to clear the yard.
		part.condition = float(_api().call("fitted_condition", slot_id)) if _has("fitted_condition") else 1.0
		part.knocked.connect(_note_loose)
		part.drop()
		_note_loose(part)
	else:
		_send_to_trolley(part)


## In its slot again. Seated by the beam, the copy stays (hidden) until the first joint is
## in; pushed back by hands, it goes.
func _on_component_positioned(slot_id: String, _comp: String) -> void:
	var part: TradesLoosePart = loose.get(slot_id)
	if part == null:
		return
	if part == held:
		part.set_seated(true)
	else:
		_finish(part)


## The part is the ship's again: the copy and any hold on it go.
func _finish(part: TradesLoosePart) -> void:
	if part == held:
		held = null
		_stop_beam()
	_end_hold(part)
	_cancel_trolley(part.slot_id)
	_forget_loose(part.slot_id)
	loose.erase(part.slot_id)
	var net := _net()
	if net:
		net.call("unregister_mover", unit_id(part.slot_id))
	part.queue_free()


func _tight(slot_id: String) -> int:
	var n := 0
	for f in _bus.get_fasteners(slot_id):
		if _bus.is_joint_tight(f.joint_id):
			n += 1
	return n


func _send_hold(part: TradesLoosePart, in_line: bool, locked: bool) -> void:
	_sent[unit_id(part.slot_id)] = in_line
	var net := _net()
	if net:
		net.call("set_hold", unit_id(part.slot_id), in_line, locked, "slot:" + part.slot_id)


func _end_hold(part: TradesLoosePart) -> void:
	if not _sent.has(unit_id(part.slot_id)):
		return
	_sent.erase(unit_id(part.slot_id))
	var net := _net()
	if net:
		net.call("end_hold", unit_id(part.slot_id))


## Multiplayer's bus, when it is loaded.
func _net() -> Node:
	var net: Node = Modules.bus("multiplayer")
	return net if net and net.has_method("set_hold") else null


## The loose part is still about where it came off (hands can push it back in by themselves).
func near_mount(slot_id: String) -> bool:
	var part: TradesLoosePart = loose.get(slot_id)
	if part == null:
		return true
	var home := station.ship_xform * _bus.get_slot(slot_id).mount
	return part.global_position.distance_to(home.origin) < DRAW_M


func clear() -> void:
	held = null
	for p: TradesLoosePart in loose.values():
		_finish(p)
	loose.clear()
	to_trolley.clear()
	_retry.clear()


# --- Trolleys (Ship and Bay's) -----------------------------------------------------------

## How long to wait before asking again when no trolley was free, seconds.
const TROLLEY_RETRY_S := 4.0


## Who answers the trolley calls: Ship and Bay's bus (tests put a stand-in here).
func _api() -> Object:
	return trolley_api if trolley_api else _bus


func _has(method: String) -> bool:
	return _api() != null and _api().has_method(method)


## Asks the yard for a trolley to take the part; none free, it asks again later.
func _send_to_trolley(part: TradesLoosePart) -> void:
	_retry.erase(part.slot_id)
	if not _has("beam_to_trolley") or to_trolley.has(part.slot_id):
		return
	var id := str(_api().call("beam_to_trolley", part.slot_id, part.component, part.condition, part.centre()))
	if id == "":
		_retry[part.slot_id] = TROLLEY_RETRY_S
		return
	to_trolley[part.slot_id] = id


func _cancel_trolley(slot_id: String) -> void:
	_retry.erase(slot_id)
	_drop_yard_beam(slot_id)
	if not to_trolley.has(slot_id):
		return
	to_trolley.erase(slot_id)
	if _has("cancel_beam"):
		_api().call("cancel_beam", slot_id)


## The part is on its trolley's deck as a crate: the copy goes.
func _on_part_beamed(_crate_id: String, trolley_id: String, _component: String, slot_id := "") -> void:
	if slot_id == "":
		for s: String in to_trolley:
			if to_trolley[s] == trolley_id:
				slot_id = s
	var part: TradesLoosePart = loose.get(slot_id)
	if part == null or part == held or not to_trolley.has(slot_id):
		return
	to_trolley.erase(slot_id)
	_finish(part)


# --- Clean-up (Ship and Bay's flag ship_bay.clean_up) -------------------------------------------

## Loose parts lie where they fall and Ship and Bay's trolleys clear them on request, instead
## of a trolley coming for each part the moment it's off.
func clean_up() -> bool:
	return Flags.is_on("ship_bay.clean_up") and _has("note_loose")


## Tells Ship and Bay a part is lying loose (again, with its latest condition).
func _note_loose(part: TradesLoosePart) -> void:
	if clean_up() and part != held and loose.get(part.slot_id) == part:
		_api().call("note_loose", part.slot_id, part.component, part.condition, part)


func _forget_loose(slot_id: String) -> void:
	if Flags.is_on("ship_bay.clean_up") and _has("forget_loose"):
		_api().call("forget_loose", slot_id)


## A clean-up trolley is coming for it: the yard beam draws it on, part_beamed frees it.
func _on_clean_up_claimed(slot_id: String, trolley_id: String) -> void:
	if loose.has(slot_id) and loose[slot_id] != held:
		to_trolley[slot_id] = trolley_id


func _update_trolleys(delta: float) -> void:
	for slot_id: String in _retry.keys():
		_retry[slot_id] -= delta
		var part: TradesLoosePart = loose.get(slot_id)
		if part == null or part == held:
			_retry.erase(slot_id)
		elif _retry[slot_id] <= 0.0:
			_send_to_trolley(part)
	for slot_id: String in to_trolley:
		var part: TradesLoosePart = loose.get(slot_id)
		var deck: Variant = _api().call("trolley_deck_position", to_trolley[slot_id]) \
				if _has("trolley_deck_position") else null
		if part and deck is Vector3:
			_draw_yard_beam(slot_id, part.centre(), deck)
	for slot_id: String in _yard_beams.keys():
		if not to_trolley.has(slot_id):
			_drop_yard_beam(slot_id)


func _draw_yard_beam(slot_id: String, from: Vector3, to: Vector3) -> void:
	var m: TradesBeamLine = _yard_beams.get(slot_id)
	if m == null:
		m = TradesBeamLine.new()
		m.color = TradesTractorTool.BEAM_COLOR
		m.strength = 0.6
		add_child(m)
		_yard_beams[slot_id] = m
	m.draw(from, to, get_physics_process_delta_time())


func _drop_yard_beam(slot_id: String) -> void:
	var m: MeshInstance3D = _yard_beams.get(slot_id)
	if m:
		m.queue_free()
	_yard_beams.erase(slot_id)


func _emit(part: TradesLoosePart, holding: bool) -> void:
	var bus := station.bay.bus()
	if bus:
		bus.part_beamed.emit(1, part.slot_id, part.global_transform, holding)


## How much quieter the beam's sounds play (dB, trades.quiet_tractor).
static func _db() -> float:
	return QUIET_DB if Flags.is_on("trades.quiet_tractor") else 0.0
