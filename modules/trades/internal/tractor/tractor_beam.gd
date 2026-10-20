class_name TradesTractor
extends Node3D
## The tractor beam (tool 7) in the yard: lifts parts that have come off the ship, carries
## them, and lines them up with their mounts so they can be fastened again.
##
##   aim at a loose part, hold left click   the beam takes it where it is
##   look about, walk                       it follows, out along the beam
##   mouse wheel                            pull it in / push it out
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
var _beam: MeshInstance3D
var _halo: MeshInstance3D
var _beam_mat: StandardMaterial3D
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
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.albedo_color = Color(TradesTractorTool.BEAM_COLOR, 0.55)
	_beam = _beam_mesh(0.012, 0.03)
	_halo = _beam_mesh(0.05, 0.16)
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


func release() -> void:
	if held == null:
		return
	var part := held
	held = null
	_stop_beam()
	if part.seated:
		_lock(part)
	else:
		part.drop()
		_end_hold(part)
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
		station.bay.hint("Parked in the air. Hold left click on it to take it again.")
	aligned = false
	_emit(part, false)
	return true


## Let go of it in line: it stays locked in its mount for its first joint.
func _lock(part: TradesLoosePart) -> void:
	part.anchor()
	_send_hold(part, true, true)
	station.bay.play(&"clunk", 0.7)
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


## Q / E while holding: turn it a step round the vertical.
func turn(step: int) -> bool:
	if held == null:
		return false
	_grip = Transform3D(Basis(Vector3.UP, deg_to_rad(TURN_STEP_DEG) * step), Vector3.ZERO) * _grip
	return true


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
	held.global_transform = held.global_transform.interpolate_with(target, t)
	var state := _bus.get_slot_state(held.slot_id)
	if aligned and not held.seated and state == ShipBayBus.SlotState.EMPTY:
		if _bus.try_position(held.slot_id, held.component):
			station.bay.play(&"clunk", 0.8)
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
		_draw_beam(tool.beam_from(), held.centre())
	station.bay.loop(&"beam", true, 0.9 + (0.2 if aligned else 0.0))
	_emit(held, true)


## The beam's frame: at the aim point `_distance` out, turned with the worker.
func _beam_frame() -> Transform3D:
	var worker := station.bay.worker
	return Transform3D(Basis(Vector3.UP, worker.global_rotation.y), worker.aim_origin() + worker.aim_dir() * _distance)


func _take(part: TradesLoosePart) -> void:
	held = part
	part.take_hold()
	_distance = clampf(station.bay.worker.aim_origin().distance_to(part.centre()), MIN_M, RANGE_M)
	_grip = _beam_frame().affine_inverse() * part.global_transform
	station.bay.play(&"click", 0.6)
	station.bay.hint("Got it. Wheel pulls in and pushes out, Q/E turns it, right click parks it.")


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
	_beam.visible = false
	_halo.visible = false
	_glow.visible = false
	station.bay.loop(&"beam", false)
	var tool := station.bay.tool_node(&"tractor") as TradesTractorTool
	if tool:
		tool.on = false
		tool.align = -1.0


func _draw_beam(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var y := (to - from) / length
	var x := y.cross(Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	var xform := Transform3D(Basis(x, y, x.cross(y)), (from + to) * 0.5)
	var color := TradesTractorTool.ALIGNED_COLOR if aligned else TradesTractorTool.BEAM_COLOR
	_beam_mat.albedo_color = Color(color, 0.55)
	for m: MeshInstance3D in [_beam, _halo]:
		m.global_transform = xform.scaled_local(Vector3(1.0, length, 1.0))
		m.visible = true
	(_halo.material_override as StandardMaterial3D).albedo_color = Color(color, 0.12)
	_glow.global_position = to
	_glow.light_color = color
	_glow.visible = true


func _beam_mesh(bottom: float, top: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.cap_top = false
	mesh.cap_bottom = false
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _beam_mat if bottom < 0.03 else _beam_mat.duplicate()
	m.top_level = true
	m.visible = false
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


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
	var id := str(_api().call("beam_to_trolley", part.slot_id, part.component, 1.0, part.centre()))
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
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var m: MeshInstance3D = _yard_beams.get(slot_id)
	if m == null:
		m = _beam_mesh(0.03, 0.06)
		(m.material_override as StandardMaterial3D).albedo_color = Color(TradesTractorTool.BEAM_COLOR, 0.3)
		_yard_beams[slot_id] = m
	var y := (to - from) / length
	var x := y.cross(Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	m.global_transform = Transform3D(Basis(x, y, x.cross(y)), (from + to) * 0.5).scaled_local(Vector3(1.0, length, 1.0))
	m.visible = true


func _drop_yard_beam(slot_id: String) -> void:
	var m: MeshInstance3D = _yard_beams.get(slot_id)
	if m:
		m.queue_free()
	_yard_beams.erase(slot_id)


func _emit(part: TradesLoosePart, holding: bool) -> void:
	var bus := station.bay.bus()
	if bus:
		bus.part_beamed.emit(1, part.slot_id, part.global_transform, holding)
