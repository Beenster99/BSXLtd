class_name BoltJoint
extends RefCounted
## One bolted joint in progress: the bracket, and per hole the bolt's state and torque. Pure
## logic with no nodes, so tests drive it directly and the bench only turns input into calls.

signal changed
## The torque wrench reached its set value on this hole (the click a player feels).
signal wrench_clicked(hole: int)
signal completed

enum Hole { EMPTY, STARTING, STARTED, SEATED, TORQUED }

var spec: JointSpec
var tuning: BoltingTuning
## Turning speed multiplier, from the player's skill (Progression's "bolt_speed").
var speed := 1.0
var hole_count: int
var bracket_seated := false
var misalign_mm := 0.0

var state: Array[Hole] = []
var cross: Array[bool] = []
var washer: Array[bool] = []
var fastener: Array[StringName] = []
var turns: PackedFloat64Array
var torque: PackedFloat64Array
## Holes in the order they first got final torque.
var order: PackedInt32Array = []

var _pull_hole := -1
var _pull_clicked := false


func _init(p_spec: JointSpec, p_hole_count: int, p_tuning: BoltingTuning) -> void:
	spec = p_spec
	tuning = p_tuning
	hole_count = p_hole_count
	reset()


func reset() -> void:
	bracket_seated = false
	misalign_mm = 0.0
	state.clear()
	cross.clear()
	washer.clear()
	fastener.clear()
	for i in hole_count:
		state.append(Hole.EMPTY)
		cross.append(false)
		washer.append(false)
		fastener.append(&"")
	turns = PackedFloat64Array()
	turns.resize(hole_count)
	torque = PackedFloat64Array()
	torque.resize(hole_count)
	order = PackedInt32Array()
	_pull_hole = -1
	changed.emit()


## Let go of the bracket this far from its seat. Returns true if it snapped into place.
func place_bracket(offset_mm: float, angle_deg: float) -> bool:
	if offset_mm > tuning.snap_distance_mm or absf(angle_deg) > tuning.snap_angle_deg:
		return false
	bracket_seated = true
	misalign_mm = offset_mm * tuning.snap_residual
	changed.emit()
	return true


func lift_bracket() -> bool:
	if not bracket_seated or state.any(func(s: Hole) -> bool: return s != Hole.EMPTY):
		return false
	bracket_seated = false
	changed.emit()
	return true


func tilt_for_offset(offset_mm: float) -> float:
	return offset_mm * tuning.tilt_deg_per_mm


## Turn a bolt by hand for `dt` seconds. The first turn decides whether it went in
## straight; a straight bolt then runs down by hand until it seats finger tight. Returns
## &"turning", &"started", &"seated", &"bind" (cross-threaded and stuck) or &"" (nothing to do).
func hand_turn(hole: int, tilt_deg: float, fastener_id: StringName, with_washer: bool, dt: float) -> StringName:
	if not bracket_seated:
		return &""
	if state[hole] == Hole.EMPTY:
		state[hole] = Hole.STARTING
		cross[hole] = absf(tilt_deg) > tuning.cross_thread_tilt_deg
		fastener[hole] = fastener_id
		washer[hole] = with_washer
		turns[hole] = 0.0
	if state[hole] != Hole.STARTING and state[hole] != Hole.STARTED:
		return &""
	if is_bound(hole):
		return &"bind"
	turns[hole] += dt * tuning.hand_turns_per_second * speed
	if state[hole] == Hole.STARTING and not cross[hole] and turns[hole] >= tuning.hand_start_turns:
		state[hole] = Hole.STARTED
		changed.emit()
		return &"started"
	if state[hole] == Hole.STARTED and turns[hole] >= full_turns():
		state[hole] = Hole.SEATED
		torque[hole] = maxf(torque[hole], spec.torque_target_nm * tuning.snug_share)
		changed.emit()
		return &"seated"
	changed.emit()
	return &"turning"


## A cross-threaded bolt that has jammed by hand. The torque wrench can still force it.
func is_bound(hole: int) -> bool:
	return state[hole] == Hole.STARTING and cross[hole] and turns[hole] >= tuning.cross_bind_turns


func full_turns() -> float:
	return tuning.hand_start_turns + tuning.run_down_turns


func can_pull(hole: int) -> bool:
	return state[hole] == Hole.SEATED or state[hole] == Hole.TORQUED or is_bound(hole)


func begin_pull(hole: int) -> bool:
	if not can_pull(hole):
		return false
	_pull_hole = hole
	_pull_clicked = false
	return true


## The force on the wrench handle, as torque. The bolt only turns past the torque it
## already holds. The wrench clicks once per pull at the target.
func pull(applied_nm: float) -> void:
	if _pull_hole < 0:
		return
	if state[_pull_hole] == Hole.STARTING and applied_nm >= spec.torque_target_nm * tuning.snug_share:
		# Forcing a cross-threaded bolt down: it seats, but stays cross-threaded.
		state[_pull_hole] = Hole.SEATED
		turns[_pull_hole] = full_turns()
	if applied_nm > torque[_pull_hole]:
		torque[_pull_hole] = applied_nm
		changed.emit()
	if not _pull_clicked and applied_nm >= spec.torque_target_nm:
		_pull_clicked = true
		wrench_clicked.emit(_pull_hole)


func end_pull() -> void:
	var hole := _pull_hole
	_pull_hole = -1
	if hole < 0 or state[hole] == Hole.STARTING or torque[hole] < spec.torque_target_nm * tuning.min_pull_share:
		return
	if state[hole] != Hole.TORQUED:
		state[hole] = Hole.TORQUED
		order.append(hole)
		changed.emit()
		if is_complete():
			completed.emit()


func pulling_hole() -> int:
	return _pull_hole


## Take a bolt out. Returns true if the joint was complete before (so it needs rework).
func back_out(hole: int) -> bool:
	if state[hole] == Hole.EMPTY:
		return false
	var was_complete := is_complete()
	state[hole] = Hole.EMPTY
	cross[hole] = false
	turns[hole] = 0.0
	torque[hole] = 0.0
	var at := order.find(hole)
	if at >= 0:
		order.remove_at(at)
	changed.emit()
	return was_complete


func is_complete() -> bool:
	return bracket_seated and state.all(func(s: Hole) -> bool: return s == Hole.TORQUED)


func progress() -> float:
	var done := 0.0
	for s in state:
		done += float(s) / float(Hole.TORQUED)
	return done / maxf(1.0, hole_count)


func measurements() -> Dictionary:
	var torques: Array[float] = []
	for t in torque:
		torques.append(t)
	return {
		"torque_nm": torques,
		"torque_target_nm": spec.torque_target_nm,
		"sequence": order.duplicate(),
		"sequence_ok": spec.sequence.is_empty() or order == spec.sequence,
		"cross_threaded": cross.duplicate(),
		"washer": washer.duplicate(),
		"fastener_ids": fastener.duplicate(),
		"misalign_mm": misalign_mm,
	}
