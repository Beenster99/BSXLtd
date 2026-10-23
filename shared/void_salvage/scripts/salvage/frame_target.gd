class_name FrameTarget
extends RefCounted
## What a FrameHull builds into (docs/SHIP_FRAME_PLAN.md 4.2): something that makes parts and
## joins them on a body's PartModel. Two games' builders are one: ShipKit (a player ship's
## parts, in the ship's paint) and ShipBuilder (a wreck's, priced and surveyed as salvage)
## extend it and override `part` and `join`; this base builds straight into `model` (a bare
## body's parts, as BSX takes a hull in), weighing each part as steel.
##
## The shaped makers (`box`, `member`, `flush_box`, `flush_part`) build their shape here and
## hand it to `part`, so an override of `part` is all a builder needs; ShipBuilder keeps its
## own for the wrecks.

## Steel, kg per cubic metre (a part's mass from its volume).
const STEEL: float = 7800.0
## Insulated copper wire, kg per cubic metre (a loom span's mass).
const COPPER_PVC: float = 5200.0
## How far a loom span's clip sits from the ring it's clipped to (beside the 10 cm plug
## sleeve, still over a 16 cm wide ring member), metres.
const LOOM_CLIP: float = 0.065

## How many heads each row of one plate or panel keeps when only `share` of them are: `counts`
## the heads its rows would have at the pitch, in order. Every other head along the plate at 0.5,
## counted on from row to row (so a short row may keep none), rounded down, but never fewer than
## `least` on the plate: the rows that lost every head get one back first, in order, then any with
## heads to spare, then (a plate that had fewer than `least` even at the pitch) the rows in turn
## get more than the pitch gives. A share of 1 and `least` 1 keep them all, as laid.
static func share_rows(counts: Array[int], share: float, least: int = 1) -> Array[int]:
	var kept: Array[int] = []
	var before := 0
	var total := 0
	for c in counts:
		var n := _shared(before + c, share) - _shared(before, share)
		kept.append(n)
		before += c
		total += n
	if kept.is_empty():
		return kept
	var want := maxi(least, 1)
	for bare: bool in [true, false]:
		for i in kept.size():
			if total >= want:
				return kept
			if kept[i] < counts[i] and (kept[i] == 0) == bare:
				kept[i] += 1
				total += 1
	while total < want:   # Every row is full at the pitch: closer than it on a short plate.
		for i in kept.size():
			if total < want:
				kept[i] += 1
				total += 1
	return kept


static func _shared(heads: int, share: float) -> int:
	return floori(float(heads) * share + 0.0001)


## The parts and joints being built (a builder that reaches its model another way leaves it
## null and overrides `parts_model`).
var model: PartModel
## The build step the joints made from now on belong to (ConnectionData.phase): a design sets
## it per step ("deck", "wall", "fitting"), a FrameHull sets its own ("frame", "skin",
## "lining") and puts back what it found. It lives on the model.
var phase: String:
	get:
		var m := parts_model()
		return m.phase if m else ""
	set(value):
		var m := parts_model()
		if m:
			m.phase = value
## How many device leads `power_lead` has drawn (routed or hand-typed).
var lead_count: int = 0
## The builders at work, outermost first (`begin_builder`): a part made while one is at work is
## that builder's (the ship file writes it under the builder's recipe, not as a piece).
var builders: Array[String] = []
## How many builder runs have begun: each run's place in the build order (the ship file's `seq`).
var build_seq: int = 0
## Loom span part id -> [span transform, WiringLoom], so leads can plug onto the real curve.
var _loom_curves: Dictionary = {}


## The parts and joints being built.
func parts_model() -> PartModel:
	return model


## A builder (FrameHull, DeckFrame, StudWall, PipeRouter, a loom) starts a run named `who`
## ("frame:body", "deck:body/upper", "wall:bulkhead", "pipes"). Returns the run's place in the
## build order. Pair with `end_builder`.
func begin_builder(who: String) -> int:
	builders.append(who)
	build_seq += 1
	return build_seq


func end_builder() -> void:
	if not builders.is_empty():
		builders.pop_back()


## The outermost builder at work, or "" (a design's own part).
func builder() -> String:
	return builders[0] if not builders.is_empty() else ""


## Adds a part of `shape` at `xform` (body space) in `mat`, weighing its volume of steel
## times `fill`. `tag` and `glass_mat` are for builders that use them (ShipKit); `path` names
## it (PartData.path, docs/SHIP_FRAME_PLAN.md 4.7).
func part(part_name: String, kind: PartData.Kind, shape: PartShapes.PartShape, xform: Transform3D,
		mat: Material, tag: String = "", fill: float = 1.0, glass_mat: Material = null, path: String = "") -> PartData:
	var made := model.add_part(part_name, kind, maxf(shape.volume * STEEL * fill, 0.1), 0.0, xform, shape.mesh,
			shape.collision, mat)
	made.path = path
	if not shape.extra_collision.is_empty():
		model.add_extra_collision(made, shape.extra_collision)
	return made


## Joins two parts with a joint of `kind` at `at`, facing `normal` (body space); its head hangs
## on `a`. Welds: `seam_up` and `seam_size` as in ConnectionData. `path` names it.
func join(a: PartData, b: PartData, kind: ConnectionData.Kind, at: Vector3, normal: Vector3,
		seam_up := Vector3.ZERO, seam_size := Vector2.ZERO, path: String = "") -> ConnectionData:
	var made := model.connect_parts(a, b, kind, at, normal, seam_up, seam_size)
	if made:
		made.path = path
	return made


## A box part of `size` (it dents and tears, like a wreck's plates).
func box(part_name: String, kind: PartData.Kind, size: Vector3, xform: Transform3D,
		mat: Material, fill: float, density: float = STEEL) -> PartData:
	var shape := _shape(_box_mesh(size), _box_shape(size), size.x * size.y * size.z)
	return part(part_name, kind, shape, xform, mat, "", fill * density / STEEL)


## A box part drawn bigger than its collision (a flush skin): the collision is the box of
## `size`, the look a plate over `outline` (local XZ, round the box's +Y face) with a `bevel`
## round its outer edge (FrameParts.plate).
func flush_box(part_name: String, kind: PartData.Kind, size: Vector3, outline: PackedVector2Array,
		xform: Transform3D, mat: Material, fill: float, bevel: float = 0.005, density: float = STEEL) -> PartData:
	var visual := FrameParts.plate(outline, size.y, bevel, size.y * 0.5)
	var made := part(part_name, kind, _shape(visual.mesh, _box_shape(size), size.x * size.y * size.z), xform, mat,
			"", fill * density / STEEL)
	_mark(made, visual.mesh, size)
	return made


## A part with a convex collision and a bigger look over it (a flush skin's cut-to-fit plate).
func flush_part(part_name: String, kind: PartData.Kind, collision: PartShapes.PartShape, visual: ArrayMesh,
		xform: Transform3D, mat: Material, fill: float = 1.0) -> PartData:
	var made := part(part_name, kind, _shape(visual, collision.collision, collision.volume), xform, mat, "", fill)
	_mark(made, visual)
	return made


## A mitred frame member (FrameMember): `outline` its side outline in its own XY plane,
## `width` thick along Z. It can bend, like a box part.
func member(part_name: String, kind: PartData.Kind, outline: PackedVector2Array, width: float,
		xform: Transform3D, mat: Material, fill: float) -> PartData:
	var shape := FrameMember.build(outline, width)
	var made := part(part_name, kind, _shape(shape.mesh, shape.collision, shape.volume), xform, mat, "", fill)
	_mark(made, shape.mesh, shape.mesh.get_aabb().size)
	return made


## Dents draw on the look (meta "base_mesh"); tears cut a box's collision (meta "box_size").
func _mark(made: PartData, look: Mesh, size := Vector3.ZERO) -> void:
	var node := model.part_visual(made.id)
	if node == null:
		return
	node.set_meta("base_mesh", look)
	if size != Vector3.ZERO:
		node.set_meta("box_size", size)


static func _shape(mesh: Mesh, collision: Shape3D, volume: float) -> PartShapes.PartShape:
	var shape := PartShapes.PartShape.new()
	shape.mesh = mesh
	shape.collision = collision
	shape.volume = volume
	return shape


static func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


# --- Pipes (PipeRouter) ----------------------------------------------------------------

## A pipe part (a span, an elbow, a union: PipeRouter lays them) of `shape` at `xform` in
## `mat`, weighing its steel; a CONDUIT, like a loom span. `path` names it.
func pipe_part(part_name: String, shape: PartShapes.PartShape, xform: Transform3D, mat: Material,
		path: String = "") -> PartData:
	var made := parts_model().add_part(part_name, PartData.Kind.CONDUIT, maxf(shape.volume * STEEL, 0.05), 0.0, xform,
			shape.mesh, shape.collision, mat)
	made.path = path
	if not shape.extra_collision.is_empty():
		parts_model().add_extra_collision(made, shape.extra_collision)
	return made


# --- Wiring (looms and leads) ----------------------------------------------------------

## A loom span's part: wiring, its mass `kg` (a builder prices it its own way).
func _wire_part(part_name: String, kg: float, xform: Transform3D, mesh: Mesh, shape: Shape3D) -> PartData:
	return parts_model().add_part(part_name, PartData.Kind.CONDUIT, kg, 0.0, xform, mesh, shape, WiringLoom.material())


## One loom span as a part: `length` along the local Y of `xform`, with its clip strap at
## the start tie (`clip_at_start`) or the end tie, bowing out by `sag` (span space, zero
## for a taut span). `solid` (span space, along local Y) is where its collision runs, if not
## the whole length (a channel loom through a node block). Returns [the part, its WiringLoom].
## loom_run builds its spans with
## this; designs use it for drops and odd runs that don't follow a frame.
func loom_span(part_name: String, spec: WiringLoom.Spec, length: float, xform: Transform3D,
		seed: int, clip_at_start: bool = true, sag := Vector3.ZERO, hug := Vector3.ZERO,
		clip_offset: float = LOOM_CLIP, dip := Vector3.ZERO, dip_flat: float = 0.0,
		pin := Vector3.ZERO, solid := Vector2(-INF, INF)) -> Array:
	var loom := WiringLoom.new(spec, length, seed)
	loom.sag = sag
	loom.origin_shift = loom.sag * 0.5
	loom.dip = dip
	loom.dip_flat = dip_flat
	loom.pin_axis(pin)
	loom.hug_frame(hug)
	# The clip strap sits over the ring at that end, just clear of the plug sleeve there.
	var off := minf(clip_offset, length * 0.5)
	loom.clip_s = -length * 0.5 + off if clip_at_start else length * 0.5 - off
	# Collision hugs the real curve (slack and sag included): a convex hull around it,
	# so tools hit the wires, not the empty space a fat cylinder would add.
	var shape := ConvexPolygonShape3D.new()
	var hull := PackedVector3Array()
	var reach := spec.collision_radius() - spec.slack
	var samples := 10 if dip == Vector3.ZERO else 24
	var s0 := maxf(-length * 0.5, solid.x)
	var s1 := minf(length * 0.5, solid.y)
	for j in samples + 1:
		var sj := s0 + (s1 - s0) * float(j) / float(samples)
		var c := loom.centre_at(sj)
		for a in 8:
			var angle := TAU * float(a) / 8.0
			hull.append(c + Vector3(cos(angle), 0.0, sin(angle)) * reach)
	shape.points = hull
	var kg := 0.0
	for w in spec.wire_colors.size():
		kg += PI * spec.wire_radius * spec.wire_radius * length * COPPER_PVC
	kg += PI * spec.core_radius * spec.core_radius * length * COPPER_PVC
	kg = maxf(kg, 1.0)
	var span := _wire_part(part_name, kg, xform, loom.build_mesh(), shape)
	span.power = PartData.Power.CONDUCTOR
	_loom_curves[span.id] = [xform, loom]
	return [span, loom]


## The centre of loom span `span` where it crosses `z` (body space), slack included.
func loom_point(span: PartData, z: float) -> Vector3:
	var curve: Array = _loom_curves[span.id]
	var xform: Transform3D = curve[0]
	return xform * (curve[1] as WiringLoom).centre_at(z - xform.origin.z)


## The z range (body space) a `loom_run` span covers, for picking where to tap it.
## Zero-length for a part that isn't a span running along z (a drop, a bend, a box).
func loom_extent(span: PartData) -> Vector2:
	if not _loom_curves.has(span.id):
		return Vector2(span.local_transform.origin.z, span.local_transform.origin.z)
	var curve: Array = _loom_curves[span.id]
	var xform: Transform3D = curve[0]
	if absf(xform.basis.y.z) < 0.99:
		return Vector2(xform.origin.z, xform.origin.z)
	var half: float = (curve[1] as WiringLoom).length * 0.5
	return Vector2(xform.origin.z - half, xform.origin.z + half)


## Plugs a device into a loom span with a lead: a CONNECTOR joint (the plug, at the last
## point, on the loom; named `path`) and a twisted lead running through `points` (body space,
## from the device to the loom) that hangs on the device and leaves with it.
func power_lead(device: PartData, span: PartData, points: PackedVector3Array, path: String = "") -> ConnectionData:
	lead_count += 1
	var last := points[points.size() - 1]
	var before := points[points.size() - 2]
	var plug := join(span, device, ConnectionData.Kind.CONNECTOR, last, (last - before).normalized(), Vector3.ZERO,
			Vector2.ZERO, path)
	var lead := MeshInstance3D.new()
	lead.name = "Lead"
	var local := PackedVector3Array()
	var to_device := device.local_transform.affine_inverse()
	for p in points:
		local.append(to_device * p)
	lead.mesh = WiringLoom.lead_mesh(local)
	lead.material_override = WiringLoom.material()
	parts_model().attach_to_part(device, lead)
	return plug
