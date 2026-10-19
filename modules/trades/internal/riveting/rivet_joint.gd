class_name RivetJoint
extends RefCounted
## One riveted lap joint in progress: a strap lapped on a sheet with a row of marked rivet
## positions. Per hole: drill it (where you aimed, wider if the drill wobbled), deburr it,
## set a rivet of some length, squeeze its tail into a head. Pure logic with no nodes, so
## tests drive it directly and the station only turns input into calls.
##
## The head comes from the tail: a tail sticking out p mm squeezed to height h spreads to
## diameter D * sqrt(fill_share * p / h) (some of the metal swells into the hole). Too
## short a rivet never draws the sheets tight; squeezing too far cracks the head.

signal changed
signal completed

enum Hole { MARKED, DRILLED, RIVET, FORMED }

## Rivet lengths in the tray (mm); Tab picks one.
const LENGTHS: Array[float] = [6.0, 8.0, 10.0]

var spec: JointSpec
var hole_count: int
## Drilling speed multiplier, from the player's skill (Progression's "rivet_speed").
var speed := 1.0

# Rivet
var rivet_d_mm := 3.2
## Strap plus sheet.
var stack_mm := 3.2
## The drill bit: a clean hole is this much over the rivet.
var bit_mm := 3.3
var head_height_target_mm := 1.6
var head_dia_target_mm := 4.8
## Share of the tail's metal that ends up in the head (the rest swells the shank).
var fill_share := 0.75
## The squeezer bottoms out here (share of the tail squashed).
var max_squeeze := 0.85
## A head spread wider than this many rivet diameters splits.
var crack_spread := 1.9
## A tail shorter than this many diameters can't pull the sheets together.
var seat_protrusion := 1.2

# Hands
var drill_seconds := 1.2
## Hole growth per pixel of mouse wobble while drilling.
var wobble_mm_per_px := 0.002
var deburr_seconds := 0.6
## A squeeze that ends below this share has not formed a head yet.
var min_formed := 0.3

var state: Array[Hole] = []
## How far each hole landed from its mark, and how much wider than the rivet it is (mm).
var offset_mm: PackedFloat64Array
var clearance_mm: PackedFloat64Array
var deburred: Array[bool] = []
var length_mm: PackedFloat64Array
var squeeze: PackedFloat64Array
var _drilled: PackedFloat64Array
var _deburr: PackedFloat64Array
var _squeeze_hole := -1
var _complete := false


func _init(p_spec: JointSpec, p_hole_count: int) -> void:
	spec = p_spec
	hole_count = p_hole_count
	reset()


func reset() -> void:
	state.clear()
	deburred.clear()
	for i in hole_count:
		state.append(Hole.MARKED)
		deburred.append(false)
	offset_mm = _zeros()
	clearance_mm = _zeros()
	length_mm = _zeros()
	squeeze = _zeros()
	_drilled = _zeros()
	_deburr = _zeros()
	_squeeze_hole = -1
	_complete = false
	changed.emit()


## Hold the drill on a mark. `at_mm` is how far from the mark the bit landed, `wobble_px`
## how far the mouse moved this frame. Returns "drilling", "through" or "" (nothing to drill).
func drill(hole: int, at_mm: float, wobble_px: float, dt: float) -> StringName:
	if state[hole] != Hole.MARKED:
		return &""
	if _drilled[hole] == 0.0:
		offset_mm[hole] = at_mm
		clearance_mm[hole] = bit_mm - rivet_d_mm
	clearance_mm[hole] += wobble_px * wobble_mm_per_px
	_drilled[hole] = minf(1.0, _drilled[hole] + dt * speed / drill_seconds)
	if _drilled[hole] < 1.0:
		return &"drilling"
	state[hole] = Hole.DRILLED
	changed.emit()
	return &"through"


func drill_progress(hole: int) -> float:
	return _drilled[hole]


## Twist the deburring tool in a fresh hole. True once it is clean.
func deburr(hole: int, dt: float) -> bool:
	if state[hole] != Hole.DRILLED or deburred[hole]:
		return deburred[hole]
	_deburr[hole] += dt / deburr_seconds
	if _deburr[hole] >= 1.0:
		deburred[hole] = true
		changed.emit()
	return deburred[hole]


func insert(hole: int, rivet_length_mm: float) -> bool:
	if state[hole] != Hole.DRILLED:
		return false
	state[hole] = Hole.RIVET
	length_mm[hole] = rivet_length_mm
	squeeze[hole] = 0.0
	changed.emit()
	return true


func begin_squeeze(hole: int) -> bool:
	if _complete or (state[hole] != Hole.RIVET and state[hole] != Hole.FORMED):
		return false
	_squeeze_hole = hole
	return true


## The squeezer closed this far (0..1 of the tail squashed). A head only ever gets flatter.
func press(share: float) -> void:
	if _squeeze_hole < 0:
		return
	var s := clampf(share, 0.0, max_squeeze)
	if s > squeeze[_squeeze_hole]:
		squeeze[_squeeze_hole] = s
		changed.emit()


func end_squeeze() -> void:
	var hole := _squeeze_hole
	_squeeze_hole = -1
	if hole < 0:
		return
	if squeeze[hole] >= min_formed:
		state[hole] = Hole.FORMED
	changed.emit()
	if not _complete and is_complete():
		_complete = true
		completed.emit()


func squeezing_hole() -> int:
	return _squeeze_hole


## Drill a rivet back out: the hole is left a little wider and rough again. True if the
## joint had been finished (so its result is stale).
func drill_out(hole: int) -> bool:
	if state[hole] != Hole.RIVET and state[hole] != Hole.FORMED:
		return false
	var was_complete := _complete
	_complete = false
	state[hole] = Hole.DRILLED
	clearance_mm[hole] += 0.15
	deburred[hole] = false
	_deburr[hole] = 0.0
	length_mm[hole] = 0.0
	squeeze[hole] = 0.0
	changed.emit()
	return was_complete


func protrusion_mm(hole: int) -> float:
	return maxf(0.0, length_mm[hole] - stack_mm)


func head_height_mm(hole: int) -> float:
	return protrusion_mm(hole) * (1.0 - squeeze[hole])


func head_dia_mm(hole: int) -> float:
	var h := head_height_mm(hole)
	if h <= 0.0:
		return 0.0
	return maxf(rivet_d_mm, rivet_d_mm * sqrt(fill_share * protrusion_mm(hole) / h))


func is_cracked(hole: int) -> bool:
	return head_dia_mm(hole) > crack_spread * rivet_d_mm


func is_seated(hole: int) -> bool:
	return protrusion_mm(hole) >= seat_protrusion * rivet_d_mm


func is_complete() -> bool:
	return state.all(func(s: Hole) -> bool: return s == Hole.FORMED)


func progress() -> float:
	var done := 0.0
	for s in state:
		done += float(s) / float(Hole.FORMED)
	return done / maxf(1.0, hole_count)


func measurements() -> Dictionary:
	var heights: Array[float] = []
	var dias: Array[float] = []
	var fits: Array[float] = []
	var lengths: Array[float] = []
	var tails: Array[float] = []
	var offsets: Array[float] = []
	var seated: Array[bool] = []
	var cracked: Array[bool] = []
	for i in hole_count:
		heights.append(snappedf(head_height_mm(i), 0.01))
		dias.append(snappedf(head_dia_mm(i), 0.01))
		fits.append(snappedf(clearance_mm[i], 0.01))
		lengths.append(length_mm[i])
		tails.append(snappedf(protrusion_mm(i), 0.01))
		offsets.append(snappedf(offset_mm[i], 0.1))
		seated.append(is_seated(i))
		cracked.append(is_cracked(i))
	return {
		"head_height_mm": heights,
		"head_height_target_mm": head_height_target_mm,
		"head_dia_mm": dias,
		"head_dia_target_mm": head_dia_target_mm,
		"hole_fit_mm": fits,
		"deburred": deburred.duplicate(),
		"seated": seated,
		"cracked_head": cracked,
		"rivet_length_mm": lengths,
		"protrusion_mm": tails,
		"hole_offset_mm": offsets,
		"rivet_diameter_mm": rivet_d_mm,
		"stack_mm": stack_mm,
	}


func _zeros() -> PackedFloat64Array:
	var a := PackedFloat64Array()
	a.resize(hole_count)
	return a
