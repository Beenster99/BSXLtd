class_name WeldSeam
extends RefCounted
## One butt weld in progress: two plates side by side and the seam between them, run with a
## MIG torch from end to end. The seam is split into short bins; each bin the arc passes
## over records the travel speed, torch angle, arc length and penetration it was laid with.
## Pure logic with no nodes, so tests drive it directly.
##
## Penetration is 1.0 at the target heat: more amps or slower travel digs deeper, a long arc
## spreads the heat and digs less. Sitting still burns through the plate.

signal changed
signal completed
## The arc went out mid-run (too long or stubbed into the plate).
signal arc_broke

var spec: JointSpec
var length_mm := 120.0
var plate_mm := 6.0
## The welder's setting and what this plate wants.
var amps := 110.0
var amps_target := 130.0
var amps_min := 60.0
var amps_max := 200.0
var speed_target_mm_s := 8.0
## Torch lean from upright, along the seam.
var angle_target_deg := 30.0
var arc_target_mm := 3.0
## The arc goes out longer than this or shorter than stub_arc_mm.
var break_arc_mm := 8.0
var stub_arc_mm := 0.6
var burn_penetration := 1.45
var bin_mm := 2.0
## Samples reported per this much seam.
var sample_mm := 10.0
## How quickly the travel speed reading follows the torch (seconds).
var speed_smoothing_s := 0.3

var filled: Array[bool] = []
var speed_at: PackedFloat64Array
var angle_at: PackedFloat64Array
var arc_at: PackedFloat64Array
var pen_at: PackedFloat64Array
## Seconds since each bin was laid, for the glow of the fresh bead.
var age_at: PackedFloat64Array

var arc_on := false
## Where the torch is along the seam (mm from the left end) and its arc length now.
var pos_mm := 0.0
var arc_mm := 3.0
var speed_mm_s := 0.0
var strikes := 0
var burn_through := false
var _complete := false


func _init(p_spec: JointSpec) -> void:
	spec = p_spec
	reset()


func reset() -> void:
	var n := bin_count()
	filled.clear()
	filled.resize(n)
	filled.fill(false)
	speed_at = _zeros(n)
	angle_at = _zeros(n)
	arc_at = _zeros(n)
	pen_at = _zeros(n)
	age_at = _zeros(n)
	arc_on = false
	pos_mm = 0.0
	arc_mm = arc_target_mm
	speed_mm_s = 0.0
	strikes = 0
	burn_through = false
	_complete = false
	changed.emit()


func bin_count() -> int:
	return ceili(length_mm / bin_mm)


func set_amps(value: float) -> void:
	amps = clampf(snappedf(value, 5.0), amps_min, amps_max)
	changed.emit()


## Strike the arc at `at_mm` along the seam.
func strike(at_mm: float) -> bool:
	if _complete:
		return false
	arc_on = true
	strikes += 1
	pos_mm = clampf(at_mm, 0.0, length_mm)
	arc_mm = arc_target_mm
	speed_mm_s = speed_target_mm_s * 0.5
	return true


## One frame with the arc lit: the torch moved `along_mm` down the seam (backward moves
## don't lay metal), the arc length changed by `arc_change_mm`, at `angle_deg` lean.
## Returns "welding", "end" (reached the far end), "broke" or "" (no arc).
func travel(along_mm: float, arc_change_mm: float, angle_deg: float, dt: float) -> StringName:
	if not arc_on or dt <= 0.0:
		return &""
	arc_mm += arc_change_mm
	if arc_mm > break_arc_mm or arc_mm < stub_arc_mm:
		arc_on = false
		arc_broke.emit()
		changed.emit()
		return &"broke"
	var from := pos_mm
	pos_mm = clampf(pos_mm + maxf(0.0, along_mm), 0.0, length_mm)
	var now_speed := (pos_mm - from) / dt
	speed_mm_s = lerpf(speed_mm_s, now_speed, 1.0 - exp(-dt / speed_smoothing_s))
	var pen := penetration(speed_mm_s, arc_mm)
	var last := bin_count() - 1
	for b in range(mini(int(from / bin_mm), last), mini(int(pos_mm / bin_mm), last) + 1):
		filled[b] = true
		speed_at[b] = speed_mm_s
		angle_at[b] = angle_deg
		arc_at[b] = arc_mm
		pen_at[b] = pen
		age_at[b] = 0.0
		if pen > burn_penetration:
			burn_through = true
	changed.emit()
	return &"end" if pos_mm >= length_mm else &"welding"


## Let go of the trigger. Finishes the weld once both ends of the seam have metal in them.
func stop() -> void:
	if not arc_on:
		return
	arc_on = false
	changed.emit()
	if not _complete and filled[0] and filled[bin_count() - 1]:
		_complete = true
		completed.emit()


## How deep a bead laid at this speed and arc length digs, 1.0 at the target.
func penetration(travel_mm_s: float, arc_length_mm: float) -> float:
	var heat := (amps / amps_target) * sqrt(speed_target_mm_s / maxf(travel_mm_s, 0.5))
	var arc_factor := clampf(1.0 - 0.5 * (arc_length_mm - arc_target_mm) / arc_target_mm, 0.4, 1.2)
	return minf(heat * arc_factor, 2.0)


## Grind the whole bead out. True if the weld had been finished.
func grind_out() -> bool:
	var was := _complete
	reset()
	return was


func age(dt: float) -> void:
	for b in age_at.size():
		age_at[b] += dt


func coverage() -> float:
	return float(filled.count(true)) / float(maxi(1, filled.size()))


func is_complete() -> bool:
	return _complete


func progress() -> float:
	return coverage()


func measurements() -> Dictionary:
	var speeds: Array[float] = []
	var angles: Array[float] = []
	var arcs: Array[float] = []
	var pens: Array[float] = []
	var per := maxi(1, roundi(sample_mm / bin_mm))
	var n := bin_count()
	var start := 0
	while start < n:
		var count := 0
		var sums := [0.0, 0.0, 0.0, 0.0]
		for b in range(start, mini(start + per, n)):
			if filled[b]:
				count += 1
				sums[0] += speed_at[b]
				sums[1] += angle_at[b]
				sums[2] += arc_at[b]
				sums[3] += pen_at[b]
		if count > 0:
			speeds.append(snappedf(sums[0] / count, 0.01))
			angles.append(snappedf(sums[1] / count, 0.1))
			arcs.append(snappedf(sums[2] / count, 0.01))
			pens.append(snappedf(sums[3] / count, 0.01))
		start += per
	return {
		"travel_speed_mm_s": speeds,
		"travel_speed_mm_s_target": speed_target_mm_s,
		"torch_angle_deg": angles,
		"torch_angle_deg_target": angle_target_deg,
		"arc_length_mm": arcs,
		"arc_length_mm_target": arc_target_mm,
		"coverage": snappedf(coverage(), 0.001),
		"penetration": pens,
		"burn_through": burn_through,
		"restarts": maxi(0, strikes - 1),
		"amps": amps,
		"amps_target": amps_target,
		"length_mm": length_mm,
		"plate_mm": plate_mm,
	}


func _zeros(n: int) -> PackedFloat64Array:
	var a := PackedFloat64Array()
	a.resize(n)
	return a
