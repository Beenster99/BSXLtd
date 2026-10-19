class_name WiringLoom
extends RefCounted
## The look of one span of a wiring loom: several insulated wires bundled together.
##
## Presentation only (the span's game state is its PartData). The mesh is built in the
## span's own space, running along local Y from -length/2 to +length/2:
##   - the wires lie in a slow helical twist around a core wire
##   - black cable ties pinch the bundle every ~30 cm; between ties the wires splay apart a
##     little, each by its own amount
##   - the whole bundle bows out with slack between its ends (zero-g: no droop, just slack),
##     pinned straight at both ends so neighbouring spans line up at the frame rings
##   - some spans hang well loose (`sag`), bellying out into the room with looser ties
##   - a metal strap marks where the span is clipped to the frame
##   - cut ends show copper
## Everything comes from `seed`, so every machine builds the same loom.


## A kind of loom: how many wires, how thick, what colours, how loose.
class Spec:
	## Core wire in the middle of the bundle, in metres.
	var core_radius: float = 0.02
	var core_color := Color(0.1, 0.1, 0.1)
	## The wires laid around the core, in metres; one colour per wire.
	var wire_radius: float = 0.015
	var wire_colors: Array[Color] = []
	## How far the span bows out with slack, at most, in metres.
	var slack: float = 0.03
	## How far wires spread apart between ties, as a fraction of the bundle radius.
	var splay: float = 0.25
	## Helical lay of the wires, in radians per metre.
	var twist: float = 2.5
	## Distance between cable ties, roughly, in metres.
	var tie_spacing: float = 0.3

	## Radius of the circle the outer wires' centres sit on.
	func ring_radius() -> float:
		var n := maxi(wire_colors.size(), 1)
		return maxf(core_radius + wire_radius, wire_radius / sin(PI / float(n)) + 0.001)

	## Radius of the tied-up bundle.
	func bundle_radius() -> float:
		return ring_radius() + wire_radius

	## A collision cylinder this wide holds the whole span, slack and splay included.
	func collision_radius() -> float:
		return bundle_radius() + ring_radius() * splay + slack + 0.005


## Main power loom: thick orange-sheathed wires around a black core.
static func main_power() -> Spec:
	var s := Spec.new()
	s.core_radius = 0.02
	s.core_color = Color(0.08, 0.08, 0.08)
	s.wire_radius = 0.015
	s.wire_colors = [Color(0.9, 0.42, 0.06), Color(0.9, 0.42, 0.06), Color(0.08, 0.08, 0.08),
			Color(0.9, 0.42, 0.06), Color(0.75, 0.1, 0.08), Color(0.9, 0.42, 0.06)]
	s.slack = 0.05
	s.twist = 2.2
	return s


## Heavy power feed: a few thick conductors, red and black, with an earth.
static func heavy_power() -> Spec:
	var s := Spec.new()
	s.core_radius = 0.018
	s.core_color = Color(0.85, 0.75, 0.1)
	s.wire_radius = 0.019
	s.wire_colors = [Color(0.08, 0.08, 0.08), Color(0.72, 0.08, 0.06), Color(0.08, 0.08, 0.08),
			Color(0.72, 0.08, 0.06)]
	s.slack = 0.045
	s.twist = 1.6
	s.splay = 0.15
	return s


## Data and control loom: lots of thin wires in many colours.
static func data() -> Spec:
	var s := Spec.new()
	s.core_radius = 0.009
	s.core_color = Color(0.6, 0.6, 0.62)
	s.wire_radius = 0.0085
	s.wire_colors = [Color(0.12, 0.3, 0.8), Color(0.9, 0.9, 0.88), Color(0.15, 0.6, 0.2),
			Color(0.45, 0.28, 0.15), Color(0.9, 0.5, 0.1), Color(0.5, 0.5, 0.52),
			Color(0.8, 0.75, 0.15), Color(0.6, 0.15, 0.6)]
	s.slack = 0.055
	s.twist = 3.2
	s.splay = 0.35
	s.tie_spacing = 0.25
	return s


# Kept coarse: a big wreck has dozens of spans, each several metres of seven wires.
const SIDES: int = 6        # facets around each wire
const STEP: float = 0.05    # metres between rings of vertices along a wire
# The clips and ties carry finish codes (SurfaceZones), like the parts library's loom bend.
const TIE_COLOR := Color(0.07, 0.07, 0.075, SurfaceZones.NYLON_A)       # black nylon cable ties
const STRAP_COLOR := Color(0.55, 0.56, 0.58, SurfaceZones.GALVANISED_A) # galvanised clip straps
const COPPER := Color(0.85, 0.45, 0.2)

static var _material: StandardMaterial3D

var spec: Spec
var length: float
## Distance between ties along this span, adjusted so ties fall evenly, in metres.
var spacing: float
## Which ties (1 = first in from the -Y end) carry a metal clip strap instead.
var strap_ties: Array[int] = []
## Where (local Y) the span's clip strap sits, over the frame ring it's clipped to; INF =
## none. Its bracket reaches out to the frame (see `hug`).
var clip_s: float = INF

## A loose span's belly: direction and distance (m) in span space. Set before building.
var sag := Vector3.ZERO
## A span lying alongside a stringer against the skin: between its ends (which stay on
## the straight centre line, lifted over the rings) the bundle drops by `dip` (span
## space) over DIP_RAMP after `dip_flat` metres of each end, and lies there in between.
var dip := Vector3.ZERO
var dip_flat: float = 0.0
const DIP_RAMP: float = 0.35
## Shift of the span's origin from its straight centre line (half the sag), so the collision
## cylinder can sit over the belly. Span space.
var origin_shift := Vector3.ZERO
## Span space: from the straight centre line to the face of the frame the span is clipped
## to (zero = not clipped to a face). The slack never bows the bundle into the frame, and
## each clip strap gets a bracket out to the face. Set with `hug_frame` before building.
var hug := Vector3.ZERO

var _bow_a := Vector3.ZERO     # main bow (half a sine wave)
var _bow_b := Vector3.ZERO     # a smaller S-bend on top
var _phase: float
var _wire_splay: Array[float] = []
var _wire_phase: Array[float] = []

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


func _init(p_spec: Spec, p_length: float, seed: int) -> void:
	spec = p_spec
	length = p_length
	var ties := maxi(int(round(length / spec.tie_spacing)), 2)
	spacing = length / float(ties)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a1 := rng.randf_range(0.0, TAU)
	var a2 := rng.randf_range(0.0, TAU)
	_bow_a = Vector3(cos(a1), 0.0, sin(a1)) * spec.slack * rng.randf_range(0.6, 0.85)
	_bow_b = Vector3(cos(a2), 0.0, sin(a2)) * spec.slack * rng.randf_range(0.1, 0.2)
	_phase = rng.randf_range(0.0, TAU)
	for i in spec.wire_colors.size():
		_wire_splay.append(rng.randf_range(0.2, 1.0))
		_wire_phase.append(rng.randf_range(-0.25, 0.25))


## Keep the span's slack from bowing along `axis` either way (span space): a span lying
## against a stringer's side keeps its distance from it.
func pin_axis(axis: Vector3) -> void:
	if axis.length() < 0.001:
		return
	var n := axis.normalized()
	_bow_a -= n * _bow_a.dot(n)
	_bow_b -= n * _bow_b.dot(n)


## Clip the span against a frame face `to_face` away (span space, from the straight centre
## line). Slack that would bow the bundle into the frame is turned to lie along it instead.
func hug_frame(to_face: Vector3) -> void:
	hug = to_face
	if to_face.length() < 0.001:
		return
	var n := to_face.normalized()
	_bow_a -= n * maxf(_bow_a.dot(n), 0.0)
	_bow_b -= n * maxf(_bow_b.dot(n), 0.0)


## The bundle's centre line at `s` (metres along local Y, -length/2 .. +length/2).
func centre_at(s: float) -> Vector3:
	var t := clampf(s / length + 0.5, 0.0, 1.0)
	var belly := pow(sin(PI * t), 0.75)
	return Vector3(0.0, s, 0.0) + _bow_a * sin(PI * t) + _bow_b * sin(TAU * t) \
			+ sag * belly + dip * _dip_profile(s) - origin_shift


## 0 on the end plateaus, 1 along the dipped middle, a smooth ramp between.
func _dip_profile(s: float) -> float:
	if dip == Vector3.ZERO:
		return 0.0
	var from_end := length * 0.5 - absf(s)
	if from_end <= dip_flat:
		return 0.0
	if from_end >= dip_flat + DIP_RAMP:
		return 1.0
	return smoothstep(0.0, 1.0, (from_end - dip_flat) / DIP_RAMP)


## Local Y position of tie `k` (0 and the last are the span's ends).
func tie_s(k: int) -> float:
	return -length * 0.5 + spacing * float(k)


func tie_count() -> int:
	return int(round(length / spacing))


func build_mesh() -> ArrayMesh:
	_verts.clear()
	_normals.clear()
	_colors.clear()
	_indices.clear()
	var samples := maxi(int(ceil(length / STEP)), 8)
	# Core wire.
	_wire_tube(samples, -1, spec.core_radius, spec.core_color)
	for i in spec.wire_colors.size():
		_wire_tube(samples, i, spec.wire_radius, spec.wire_colors[i])
	# Ties and clip straps (not at the very ends: the connectors at the rings sit there).
	var r := spec.bundle_radius()
	for k in range(1, tie_count()):
		if strap_ties.has(k):
			_band(tie_s(k), r + 0.007, 0.03, STRAP_COLOR)
		else:
			_band(tie_s(k), r + 0.004, 0.012, TIE_COLOR)
	if clip_s != INF:
		_band(clip_s, r + 0.007, 0.022, STRAP_COLOR)
		if hug.length() > 0.001:
			_bracket(clip_s, r + 0.007)
	return _finish()


func _finish() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A device lead: two thin twisted wires along a smooth curve through `points` (any space;
## the mesh is built in that space), with a black sleeve at each end.
static func lead_mesh(points: PackedVector3Array, colors: Array[Color] = [Color(0.08, 0.08, 0.08),
		Color(0.75, 0.1, 0.08)], radius: float = 0.008) -> ArrayMesh:
	var builder := WiringLoom.new(Spec.new(), 1.0, 0)
	var path := PackedVector3Array()
	# Catmull-Rom through the points, ~3 cm apart.
	for i in points.size() - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, points.size() - 1)]
		var steps := maxi(int(ceil(p1.distance_to(p2) / 0.03)), 2)
		for j in steps:
			var t := float(j) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			path.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	path.append(points[points.size() - 1])
	# Two wires twisted round the path.
	var along := 0.0
	var wires: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	for j in path.size():
		if j > 0:
			along += path[j].distance_to(path[j - 1])
		var tangent := (path[mini(j + 1, path.size() - 1)] - path[maxi(j - 1, 0)]).normalized()
		var normal := tangent.cross(Vector3.UP).normalized()
		if normal.length_squared() < 0.5:
			normal = tangent.cross(Vector3.RIGHT).normalized()
		var binormal := tangent.cross(normal)
		var a := along * 18.0
		for w in 2:
			var angle := a + PI * float(w)
			wires[w].append(path[j] + (normal * cos(angle) + binormal * sin(angle)) * radius)
	for w in 2:
		builder._tube(wires[w], radius, colors[w % colors.size()], true, 6)
	for end: int in [0, path.size() - 1]:
		var other := 1 if end == 0 else path.size() - 2
		var dir := (path[other] - path[end]).normalized()
		builder._tube(PackedVector3Array([path[end], path[end] + dir * 0.06]), radius * 2.6,
				TIE_COLOR, false, 10)
	return builder._finish()


## Plastic insulation coloured per wire (vertex colours), shared by every loom.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.55
		_material.metallic = 0.0
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


# --- Mesh building --------------------------------------------------------------------

## Where wire `i` sits at `s` (i = -1 is the core).
func _wire_point(i: int, s: float) -> Vector3:
	var c := centre_at(s)
	if i < 0:
		return c
	var n := spec.wire_colors.size()
	var angle := TAU * float(i) / float(n) + spec.twist * s + _phase + _wire_phase[i] * 0.3
	# Pinched at each tie, loosest half-way between. Loose spans splay more.
	var between := absf(sin(PI * (s + length * 0.5) / spacing))
	var splay := spec.splay * (2.0 if sag.length() > 0.05 else 1.0)
	var radius := spec.ring_radius() * (1.0 + splay * _wire_splay[i] * between)
	return c + Vector3(cos(angle), 0.0, sin(angle)) * radius


func _wire_tube(samples: int, i: int, radius: float, color: Color) -> void:
	var points := PackedVector3Array()
	for j in samples + 1:
		var s := -length * 0.5 + length * float(j) / float(samples)
		points.append(_wire_point(i, s))
	_tube(points, radius, color, true)


## A short ring around the bundle at `s` (a cable tie or clip strap).
func _band(s: float, radius: float, width: float, color: Color) -> void:
	var points := PackedVector3Array([centre_at(s - width * 0.5), centre_at(s + width * 0.5)])
	_tube(points, radius, color, false, 12)


## The clip strap's bracket at `s`: a flat steel tab from the strap out to the frame face
## (see `hug`), so the span is visibly fixed to the frame.
func _bracket(s: float, strap_radius: float) -> void:
	var n := hug.normalized()
	var c := centre_at(s)
	var face := hug.length() - origin_shift.dot(n)   # the face, as a distance along n
	var reach := face - c.dot(n)
	if reach <= strap_radius:
		return
	var foot := c + n * reach
	# Two flat plates: the tab up from the strap, and a foot flat against the frame.
	var side := n.cross(Vector3.UP).normalized() * 0.015
	var depth := 0.004
	_slab(c + n * strap_radius * 0.6, foot, side, n.cross(side).normalized() * depth, STRAP_COLOR)
	var flat := n.cross(Vector3.UP).normalized()
	_slab(foot - flat * 0.04 - n * 0.006, foot + flat * 0.04 - n * 0.006, Vector3.UP * 0.015,
			n * 0.003, STRAP_COLOR)


## A thin box from `a` to `b`, `half_w` across and `half_t` thick (both vectors, halves).
func _slab(a: Vector3, b: Vector3, half_w: Vector3, half_t: Vector3, color: Color) -> void:
	var corners: Array[Vector3] = []
	for end: Vector3 in [a, b]:
		for sw: float in [-1.0, 1.0]:
			for st: float in [-1.0, 1.0]:
				corners.append(end + half_w * sw + half_t * st)
	# Six faces, each two triangles, flat shaded.
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	var mid := (a + b) * 0.5
	for f: Array in faces:
		var p0: Vector3 = corners[f[0]]
		var p1: Vector3 = corners[f[1]]
		var p2: Vector3 = corners[f[2]]
		var p3: Vector3 = corners[f[3]]
		var normal := (p1 - p0).cross(p2 - p0).normalized()
		if normal.dot((p0 + p2) * 0.5 - mid) < 0.0:
			normal = -normal
		var start := _verts.size()
		for p: Vector3 in [p0, p1, p2, p3]:
			_verts.append(p)
			_normals.append(normal)
			_colors.append(color)
		_indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])


## A tube of `radius` through `points`, with copper end caps if `caps`.
func _tube(points: PackedVector3Array, radius: float, color: Color, caps: bool,
		sides: int = SIDES) -> void:
	var first := _verts.size()
	var count := points.size()
	for j in count:
		var tangent := (points[mini(j + 1, count - 1)] - points[maxi(j - 1, 0)]).normalized()
		var normal := tangent.cross(Vector3.BACK).normalized()
		if normal.length_squared() < 0.5:
			normal = tangent.cross(Vector3.RIGHT).normalized()
		var binormal := tangent.cross(normal)
		for k in sides:
			var a := TAU * float(k) / float(sides)
			var out := normal * cos(a) + binormal * sin(a)
			_verts.append(points[j] + out * radius)
			_normals.append(out)
			_colors.append(color)
	for j in count - 1:
		for k in sides:
			var a := first + j * sides + k
			var b := first + j * sides + (k + 1) % sides
			var c := a + sides
			var d := b + sides
			_indices.append_array([a, c, b, b, c, d])
	if caps:
		_cap(points[0], (points[0] - points[1]).normalized(), first, sides, false)
		_cap(points[count - 1], (points[count - 1] - points[count - 2]).normalized(),
				first + (count - 1) * sides, sides, true)


## A flat copper disc closing a wire end (shows where a loom was cut).
func _cap(centre: Vector3, out: Vector3, ring_start: int, sides: int, flip: bool) -> void:
	var centre_index := _verts.size()
	_verts.append(centre)
	_normals.append(out)
	_colors.append(COPPER)
	var rim := _verts.size()
	for k in sides:
		_verts.append(_verts[ring_start + k])
		_normals.append(out)
		_colors.append(COPPER)
	for k in sides:
		var a := rim + k
		var b := rim + (k + 1) % sides
		if flip:
			_indices.append_array([centre_index, a, b])
		else:
			_indices.append_array([centre_index, b, a])
