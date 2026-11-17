class_name PartModel
extends RefCounted
## The part-and-joint bookkeeping of a body built from parts: its PartData parts, its
## ConnectionData joints, the visual and collision nodes per part, and the joint heads
## (JointView, drawn in one JointBatch). A wreck (SalvageStructure) holds one, and so does a
## player ship (BaseShip.model, docs/SHIP_FRAME_PLAN.md 4.1).
##
## It needs only a body to hang its nodes on: nothing here knows about wrecks, tools, the
## network or the survey, so BSX Ltd can copy it as it is (CLAUDE.md "Shared files"). What
## a joint breaking does (splits, debris, power) is the holder's business.

## The ids wrecks share: every machine builds the same wreck from the same base, so the
## same joint gets the same id (SalvageStructure.reset_ids).
static var _next_part_id: int = 1
static var _next_connection_id: int = 1

## The body the nodes hang on (a RigidBody3D in play).
var body: Node3D
## Numbers its own parts and joints from 1 instead of taking the shared ids: a player ship
## is built when it spawns, at a different moment on each machine, so it must not move the
## wrecks' numbering.
var local_ids: bool = false
var _own_part_id: int = 1
var _own_connection_id: int = 1

## part id -> PartData
var parts: Dictionary = {}
## Intact connections only. Broken ones are removed.
var connections: Array[ConnectionData] = []
## Counts every change to which parts are joined to which (a joint added, broken or dropped, a
## part added or taken out, a group handed to another body): what keeps an index of the joints
## by part (JointLoad, SF6) knows it is stale. Never sent: each machine counts its own.
var break_epoch: int = 0
## The joints in `connections` as a set (ConnectionData -> true), so `has_joint` is no search of
## the list. Built again if `connections` changed behind its back (a count that no longer matches).
var _joint_set: Dictionary = {}
## The joints by where they are (find_connection_near) and by id (connection_by_id): grid
## cell (`NEAR_CELL` m, body space) -> [ConnectionData], joint id -> the cells it is filed
## under, joint id -> ConnectionData. Built at the first search, then kept up as joints are
## added, dropped, moved or handed to another model; built again if `connections` changed
## behind its back (a count that no longer matches).
var _near_cells: Dictionary = {}
var _near_keys: Dictionary = {}
var _by_id: Dictionary = {}
var _near_built: bool = false
## The filed joints that carry a lead (ConnectionData.lead), by id: what find_lead_near_ray reads.
var _lead_ids: Dictionary = {}
## A box (body space) round every filed lead's wire, grown as leads are filed (never shrunk
## till the index is built again): what a search through open space checks a body by first.
var _lead_box: AABB = AABB()
## The joints by the parts they hold (part id -> [ConnectionData], each joint filed under its
## part_a and its part_b) and where each is filed (ConnectionData -> [a, b]): what
## `joints_touching` reads (`SalvageStructure.remove_part`, `replace_part`), so taking a part out
## is no walk of every joint. Built with the grid (`build_index`), else at the first ask; kept up
## as joints are added, dropped and handed to another model; built again if `connections`
## changed behind its back (a count that no longer matches). Code that changes a joint's part_a
## or part_b outside PartModel does it through `repoint`.
var _by_part: Dictionary = {}
var _part_filed: Dictionary = {}
var _parts_built: bool = false
## (HK6b) The parts every change to which parts are joined has touched since `track_changes` (part
## id -> true: both parts of a joint broken, dropped or repointed, a part added): a split searches
## out from them (`local_groups`) instead of walking every part. Known only while every change came
## through PartModel's own methods: `changes_epoch` keeps step with `break_epoch`, so code that bumps
## break_epoch itself (FlexibleWire) leaves them unknown and the next split walks them all.
var changed: Dictionary = {}
var changes_epoch: int = -1
## (HK6b) The parts added since `track_changes` (part id -> true), apart from the body's own.
var added: Dictionary = {}
## (HK6b) Every joint taken out since `track_changes`, as [part_a, part_b] (a repointed joint's old
## pair too): what joined the body when it was one group, so searches that never meet can still be
## known to lie in one group (`local_groups`).
var links: Array = []
## The grid's cell (m), and the most cells a search looks through before it reads every joint.
const NEAR_CELL := 1.0
const NEAR_MAX_CELLS := 64
## What rivet heads made from now on look like (ConnectionData.head): 0 classic, 1 flush
## bumps. Build time, identical on every machine.
var head_style: int = 0
## The build step joints made from now on belong to (ConnectionData.phase: "frame", "deck",
## "skin", "lining", "wall", "fitting", "service"); "" for none. Build time, like head_style.
var phase: String = ""

## part id -> MeshInstance3D (the part's visual; extra visuals such as lights hang under it)
var _visuals: Dictionary = {}
## part id -> CollisionShape3D
var _colliders: Dictionary = {}
## part id -> [CollisionShape3D] for parts with more than one shape (holed plates), in
## the part's space like `_colliders`; they follow the part through every move.
var _extra_colliders: Dictionary = {}
## part id -> [its collision shape, its extra shapes' count, the middle] (`mass_middle`).
var _middles: Dictionary = {}
## connection id -> JointView (the visible rivet head, bolt head or weld bead)
var _joint_views: Dictionary = {}
## Draws every head, stub and scar on the body in a few batches (JointBatch).
var _batch: JointBatch
## Views glowing right now (connection id -> JointView), cooled each frame.
var _hot: Dictionary = {}
## Marks left on parts (sheared stubs, weld scars): part id -> Array of JointBatch.Item,
## so they travel with the part when it moves to another body.
var _decor: Dictionary = {}
## Marks glowing right now (JointBatch.Item -> heat lost a second), cooled with the heads.
var _warm: Dictionary = {}


func _init(holder: Node3D, own_ids: bool = false) -> void:
	body = holder
	local_ids = own_ids


## Restarts the shared numbering at `base` ([part id, connection id]).
static func reset_ids(base: Array = [1, 1]) -> void:
	_next_part_id = int(base[0])
	_next_connection_id = int(base[1])


## The next shared part and connection ids that would be given out.
static func next_ids() -> Array:
	return [_next_part_id, _next_connection_id]


func _take_part_id() -> int:
	if local_ids:
		_own_part_id += 1
		return _own_part_id - 1
	_next_part_id += 1
	return _next_part_id - 1


func _take_connection_id() -> int:
	if local_ids:
		_own_connection_id += 1
		return _own_connection_id - 1
	_next_connection_id += 1
	return _next_connection_id - 1


# --- Joint heads ----------------------------------------------------------------------

## The batch that draws the body's joint heads (made on first use).
func joints() -> JointBatch:
	if _batch == null:
		_batch = JointBatch.new()
		body.add_child(_batch)
	return _batch


## Draws a small mark on part `part_id` (a sheared stub, a weld scar, a strap) in the
## batch, so it costs no node or draw call of its own. `xform` is in the body's space.
## Returns its item (to `warm` it).
func add_decor(part_id: int, mesh: Mesh, material: Material, xform: Transform3D) -> JointBatch.Item:
	var item := JointBatch.Item.new(mesh, material, xform)
	add_decor_item(part_id, item)
	return item


## Draws `item` (made by the caller: a JointBatch.Item, or one of its own kind) as a mark on part
## `part_id`, as `add_decor` does: it rides the part as it moves or splits off, and goes with it.
func add_decor_item(part_id: int, item: JointBatch.Item) -> void:
	joints().add(item)
	(_decor.get_or_add(part_id, []) as Array).append(item)


## Stops drawing mark `item` on part `part_id` (false when it is not one of that part's).
func remove_decor(part_id: int, item: JointBatch.Item) -> bool:
	var items: Array = _decor.get(part_id, [])
	var i := items.find(item)
	if i < 0:
		return false
	items.remove_at(i)
	if items.is_empty():
		_decor.erase(part_id)
	_warm.erase(item)
	if _batch:
		_batch.remove(item)
	return true


## The marks drawn on part `part_id` (a copy of the list).
func decor_of(part_id: int) -> Array:
	return (_decor.get(part_id, []) as Array).duplicate()


## Marks weld or spot weld `c` hot (LK3, look only: ConnectionData.heat_marked): its view lays
## the heat's halo round it as a mark on its part, which stays when the weld goes. Returns
## false for any other kind, a weld already marked or one with no view.
func mark_heat(c: ConnectionData) -> bool:
	if c.heat_marked or (c.kind != ConnectionData.Kind.WELD and c.kind != ConnectionData.Kind.SPOT):
		return false
	var view: JointView = _joint_views.get(c.id)
	if view == null:
		return false
	c.heat_marked = true
	view.lay_halo(self)
	return true


## Whether `item` is drawn in this body's batch (a mark on one of its parts).
func holds(item: JointBatch.Item) -> bool:
	return item != null and item.bucket != null and _batch != null and item.bucket.node.get_parent() == _batch


## Makes a mark glow at `heat` (0..1; a torn weld line where it parted), losing `per_second`
## of it each second in `cool` (presentation only). Drawn by the joint shader's heat, as a
## working tool's head is.
func warm(item: JointBatch.Item, heat: float, per_second: float = JointView.COOL_RATE) -> void:
	if item == null or item.bucket == null:
		return
	item.custom.r = clampf(maxf(item.custom.r, heat), 0.0, 1.0)
	joints().update(item)
	if item.custom.r > 0.0:
		_warm[item] = maxf(per_second, 0.01)


## The view drawing connection `c`, or null.
func joint_view(c: ConnectionData) -> JointView:
	return _joint_views.get(c.id)


## Stops tracking `c`'s view and returns it (null if none): the caller pops it off or
## clears it.
func forget_view(c: ConnectionData) -> JointView:
	var view: JointView = _joint_views.get(c.id)
	_joint_views.erase(c.id)
	_hot.erase(c.id)
	return view


## The surface `part` is drawn in (a subtle joint head takes it), or null.
func _paint_of(part: PartData) -> Material:
	var node := part_visual(part.id) as GeometryInstance3D
	return node.material_override if node else null


## Draws `c`'s head afresh on `part` (the joint moved to another part: a torn plate's piece).
func remake_view(c: ConnectionData, part: PartData) -> void:
	var old := forget_view(c)
	if old:
		old.clear()
	var view := JointView.new()
	view.setup(c, part.local_transform, joints(), _paint_of(part) if c.head == 4 else null)
	_joint_views[c.id] = view


## Draw calls the joints cost (for the performance readout).
func joint_draw_calls() -> int:
	return _batch.bucket_count() if _batch else 0


## How many marks part `part_id` carries; -1 = all parts.
func mark_count(part_id: int = -1) -> int:
	if part_id >= 0:
		return (_decor.get(part_id, []) as Array).size()
	var n := 0
	for items: Array in _decor.values():
		n += items.size()
	return n


## Makes joint `c`'s head glow (presentation only, no effect on health).
func heat(c: ConnectionData, amount: float) -> void:
	var view: JointView = _joint_views.get(c.id)
	if view and view.add_heat(amount):
		_hot[c.id] = view


## Glowing heads cool (call every frame; costs nothing while none is hot).
func cool(delta: float) -> void:
	for id: int in _hot.keys():
		if not (_hot[id] as JointView).cool(delta):
			_hot.erase(id)
	for item: JointBatch.Item in _warm.keys():
		if item.bucket == null:
			_warm.erase(item)   # gone with its part
			continue
		item.custom.r = maxf(item.custom.r - float(_warm[item]) * delta, 0.0)
		joints().update(item)
		if item.custom.r <= 0.0:
			_warm.erase(item)


## How many marks are glowing (tests, the release beat).
func warm_count() -> int:
	return _warm.size()


# --- Building -------------------------------------------------------------------------

## Adds a part with its own visual (`material` as given) and collision shape at
## `local_xform` (body space). Returns its data.
func add_part(part_name: String, kind: PartData.Kind, part_mass: float, part_value: float,
		local_xform: Transform3D, mesh: Mesh, shape: Shape3D, material: Material) -> PartData:
	var part := PartData.new(_take_part_id(), part_name, kind, part_mass, part_value, local_xform)
	part.material = Materials.built_for(part_name, kind)
	parts[part.id] = part
	break_epoch += 1
	_changed([part.id])
	if changes_known():
		added[part.id] = true

	var visual := MeshInstance3D.new()
	visual.name = "%s_%d" % [part_name, part.id]
	visual.mesh = mesh
	visual.material_override = material
	visual.transform = local_xform
	body.add_child(visual)
	_visuals[part.id] = visual

	var collider := CollisionShape3D.new()
	collider.name = "%s_%d_Shape" % [part_name, part.id]
	collider.shape = shape
	collider.transform = local_xform
	collider.set_meta("part_id", part.id)
	body.add_child(collider)
	_colliders[part.id] = collider
	return part


## Gives `part` more collision shapes: a holed plate is one part made of several convex
## pieces. `offset` places them in the part's space (a fitting's further pieces); identity
## for a plate's.
func add_extra_collision(part: PartData, shapes: Array[Shape3D], offset := Transform3D.IDENTITY) -> void:
	var start := (_extra_colliders.get(part.id, []) as Array).size()
	for i in shapes.size():
		var collider := CollisionShape3D.new()
		collider.name = "%s_%d_Shape%d" % [part.part_name, part.id, start + i + 2]
		collider.shape = shapes[i]
		collider.transform = part.local_transform * offset
		collider.set_meta("part_id", part.id)
		if offset != Transform3D.IDENTITY:
			collider.set_meta("part_offset", offset)
		body.add_child(collider)
		(_extra_colliders.get_or_add(part.id, []) as Array).append(collider)


## Gives `part` a new look and collision in place (a plate a fire burnt a hole through): the part
## keeps its id, joints, marks and material; `shape`'s further pieces replace any it had. Shapes
## are in the part's space.
func reshape_part(part: PartData, mesh: Mesh, shape: Shape3D, extra: Array[Shape3D]) -> void:
	var visual := _visuals.get(part.id) as MeshInstance3D
	if visual:
		visual.mesh = mesh
	var collider := _colliders.get(part.id) as CollisionShape3D
	if collider:
		collider.shape = shape
	for old: CollisionShape3D in _extra_colliders.get(part.id, []):
		body.remove_child(old)
		old.queue_free()
	_extra_colliders.erase(part.id)
	_middles.erase(part.id)
	if not extra.is_empty():
		add_extra_collision(part, extra)


## Hangs an extra visual (a light, a screen) on a part so it travels with that part.
## `node` is positioned relative to the part.
func attach_to_part(part: PartData, node: Node3D) -> void:
	(_visuals[part.id] as Node3D).add_child(node)


## Joins two parts. `local_pos` is where the joint is exposed (a rivet head's surface point,
## or the centre of a weld seam) and `local_normal` which way it faces, both in body space.
## Its head hangs on part `a`, so put the part that carries the head first. Welds:
## `seam_up` and `seam_size` describe the seam the bead runs along (see ConnectionData).
func connect_parts(a: PartData, b: PartData, kind: ConnectionData.Kind,
		local_pos: Vector3, local_normal: Vector3, seam_up := Vector3.ZERO,
		seam_size := Vector2.ZERO) -> ConnectionData:
	var c := ConnectionData.new(_take_connection_id(), kind, a.id, b.id, local_pos, local_normal)
	c.seam_up = seam_up.normalized()
	c.seam_size = seam_size
	c.head = head_style
	c.phase = phase
	connections.append(c)
	_joint_set[c] = true
	break_epoch += 1
	_changed([a.id, b.id])
	if _near_built:
		_file_joint(c)
	if _parts_built:
		_file_part_joint(c)
	var view := JointView.new()
	view.setup(c, a.local_transform, joints(), _paint_of(a) if c.head == 4 else null)
	_joint_views[c.id] = view
	return c


## The parts' total mass and its centre (body space): [kg, Vector3]. The holder decides
## what to do with them (a wreck weighs its parts; a ship keeps its tuned mass).
func recompute_mass() -> Array:
	var total := 0.0
	var weighted := Vector3.ZERO
	for part: PartData in parts.values():
		total += part.mass
		weighted += part.local_transform * mass_middle(part) * part.mass
	return [total, weighted / total if total > 0.0 else Vector3.ZERO]


## Part space: where `part` weighs. A cut piece's own middle (`PartData.centroid`), else the
## middle of its collision. A frame builder's plate or member is drawn in its builder's space,
## metres off its origin: weighed at the origin, a freed wall panel turned about an empty point
## 4 m off, and the turn carried it through panels and linings, as a body's sweep follows only
## its middle's straight path (Dan's evening of 28 Oct).
func mass_middle(part: PartData) -> Vector3:
	if part.centroid != Vector3.ZERO:
		return part.centroid
	var collider := _colliders.get(part.id) as CollisionShape3D
	if collider == null or collider.shape == null:
		return Vector3.ZERO
	var extras: Array = _extra_colliders.get(part.id, [])
	var kept: Array = _middles.get(part.id, [])
	if not kept.is_empty() and kept[0] == collider.shape and int(kept[1]) == extras.size():
		return kept[2]
	var box := _shape_box(collider.shape, Transform3D.IDENTITY)
	var back := collider.transform.affine_inverse()
	for extra: CollisionShape3D in extras:
		var more := _shape_box(extra.shape, back * extra.transform)
		box = box.merge(more)
	var middle := box.get_center()
	_middles[part.id] = [collider.shape, extras.size(), middle]
	return middle


## The box round `shape` placed by `xform` (part space). A primitive is centred on its origin.
static func _shape_box(shape: Shape3D, xform: Transform3D) -> AABB:
	var points := PackedVector3Array()
	if shape is ConvexPolygonShape3D:
		points = (shape as ConvexPolygonShape3D).points
	elif shape is ConcavePolygonShape3D:
		points = (shape as ConcavePolygonShape3D).get_faces()
	if points.is_empty():
		return AABB(xform.origin, Vector3.ZERO)
	var box := AABB(xform * points[0], Vector3.ZERO)
	for pt in points:
		box = box.expand(xform * pt)
	return box


## Moves a part to `xform` (body space: a sliding door leaf, a hinged hatch). Its fastener
## heads and marks go with it.
func move_part(part_id: int, xform: Transform3D) -> void:
	var part: PartData = parts.get(part_id)
	if part == null:
		return
	if xform.basis != part.local_transform.basis:
		# Turned (a hinge): everything on the part turns with it.
		var by := xform * part.local_transform.affine_inverse()
		part.local_transform = xform
		_place_nodes(part_id, xform)
		for c in connections:
			if c.part_a == part_id:
				unfile_joint(c)
				c.local_position = by * c.local_position
				c.local_normal = (by.basis * c.local_normal).normalized()
				c.seam_up = by.basis * c.seam_up
				if _near_built:
					_file_joint(c)
				var view: JointView = _joint_views.get(c.id)
				if view:
					view.set_part_xform(xform)
			elif c.part_b == part_id and not c.lead.is_empty():
				_move_lead(c, by)
		for item: JointBatch.Item in _decor.get(part_id, []):
			item.xform = by * item.xform
			_batch.update(item)
		return
	var shift := xform.origin - part.local_transform.origin
	part.local_transform = xform
	_place_nodes(part_id, xform)
	for c in connections:
		if c.part_a == part_id:
			unfile_joint(c)
			c.local_position += shift
			if _near_built:
				_file_joint(c)
			var view: JointView = _joint_views.get(c.id)
			if view:
				view.set_part_xform(xform)
		elif c.part_b == part_id and not c.lead.is_empty():
			_move_lead(c, Transform3D(Basis.IDENTITY, shift))
	for item: JointBatch.Item in _decor.get(part_id, []):
		item.xform.origin += shift
		_batch.update(item)


## A plug's lead hangs on its device (part_b): it moves by `by` (body space) with it.
func _move_lead(c: ConnectionData, by: Transform3D) -> void:
	unfile_joint(c)
	for i in c.lead.size():
		c.lead[i] = by * c.lead[i]
	if _near_built:
		_file_joint(c)


## Puts a part's visual and collision shapes where its transform now says.
func _place_nodes(part_id: int, xform: Transform3D) -> void:
	(_visuals[part_id] as Node3D).transform = xform
	(_colliders[part_id] as CollisionShape3D).transform = xform
	for extra: CollisionShape3D in _extra_colliders.get(part_id, []):
		extra.transform = xform * (extra.get_meta("part_offset", Transform3D.IDENTITY) as Transform3D)


## Moves a part by `by` (body space): its fastener heads, dents and scorch go with it.
## Build time only.
func transform_part(part_id: int, by: Transform3D) -> void:
	var part: PartData = parts.get(part_id)
	if part == null:
		return
	part.local_transform = by * part.local_transform
	_place_nodes(part_id, part.local_transform)
	part.scorch_at = by * part.scorch_at
	part.scorch_line = by.basis * part.scorch_line
	for d: Array in part.dents:
		d[0] = by * (d[0] as Vector3)
		d[1] = by.basis * (d[1] as Vector3)
	part.bend = by.basis * part.bend
	for c in connections:
		if c.part_a == part_id:
			unfile_joint(c)
			c.local_position = by * c.local_position
			c.local_normal = (by.basis * c.local_normal).normalized()
			c.seam_up = by.basis * c.seam_up
			if _near_built:
				_file_joint(c)
			var view: JointView = _joint_views.get(c.id)
			if view:
				view.set_part_xform(part.local_transform)
		elif c.part_b == part_id and not c.lead.is_empty():
			_move_lead(c, by)
	for item: JointBatch.Item in _decor.get(part_id, []):
		item.xform = by * item.xform
		_batch.update(item)


## Takes joint `c` out quietly (its head stops drawing).
func drop_connection(c: ConnectionData) -> void:
	connections.erase(c)
	_joint_set.erase(c)
	break_epoch += 1
	_changed([c.part_a, c.part_b])
	_link(c.part_a, c.part_b)
	unfile_joint(c)
	_unfile_part_joint(c)
	var view := forget_view(c)
	if view:
		view.clear()


## Takes joints `list` out quietly, as `drop_connection` does each, in one walk of `connections`
## (`list` in its order, as `joints_touching` gives them, finds each from the last).
func drop_joints(list: Array[ConnectionData]) -> void:
	if list.is_empty():
		return
	for c in list:
		unfile_joint(c)
		_unfile_part_joint(c)
		var view := forget_view(c)
		if view:
			view.clear()
	_drop_joints(list)
	break_epoch += 1
	if changes_epoch == break_epoch - 1:
		for c in list:
			changed[c.part_a] = true
			changed[c.part_b] = true
			links.append([c.part_a, c.part_b])
	_changed([])


## Takes joint `c` out of `connections` and every index, as it breaks (its head is the
## caller's: it pops off or clears).
func take_out(c: ConnectionData) -> void:
	connections.erase(c)
	_joint_set.erase(c)
	break_epoch += 1
	_changed([c.part_a, c.part_b])
	_link(c.part_a, c.part_b)
	unfile_joint(c)
	_unfile_part_joint(c)


## Is `c` one of this body's intact joints? A set, not a search of `connections`.
func has_joint(c: ConnectionData) -> bool:
	if _joint_set.size() != connections.size():
		_joint_set.clear()
		for j in connections:
			_joint_set[j] = true
	return _joint_set.has(c)


## Takes part `id` out with its nodes and marks (its joints are the caller's to drop).
func erase_part(id: int) -> void:
	parts.erase(id)
	break_epoch += 1
	_changed([])   # its joints went (or go) by the methods that note their parts
	for item: JointBatch.Item in _decor.get(id, []):
		_batch.remove(item)
	_decor.erase(id)
	var v: Node = _visuals.get(id)
	var col: Node = _colliders.get(id)
	_visuals.erase(id)
	_colliders.erase(id)
	for extra: CollisionShape3D in _extra_colliders.get(id, []):
		body.remove_child(extra)
		extra.queue_free()
	_extra_colliders.erase(id)
	_middles.erase(id)
	if v:
		body.remove_child(v)
		v.queue_free()
	if col:
		body.remove_child(col)
		col.queue_free()


## Moves the parts in `group` (ids) and every joint whose head is on one of them over to
## `into`, nodes, heads and marks included. Both bodies must stand in the same place (a
## split piece starts where its structure is), so every transform stays valid. `joints`, when
## given, are those joints already found (every joint whose part_a is in the group, in
## `connections` order: a split that walked them all once hands each group its own), which
## saves the scan of every joint here.
func take_group(group: Array, into: PartModel, joints: Variant = null) -> void:
	var moving: Array[ConnectionData] = []
	if joints == null:
		var group_ids: Dictionary = {}
		for id: int in group:
			group_ids[id] = true
		for c in connections:
			if group_ids.has(c.part_a):
				moving.append(c)
	else:
		moving.assign(joints)
	# A new body takes this one's indexes as far as they are built, filed as its joints come
	# (no hitch at the first tool aimed at a big piece).
	if into.connections.is_empty() and into._near_keys.is_empty() and into._part_filed.is_empty():
		into._near_built = into._near_built or _near_built
		into._parts_built = into._parts_built or _parts_built
	for id: int in group:
		into.parts[id] = parts[id]
		parts.erase(id)
		var visual: Node3D = _visuals[id]
		var collider: CollisionShape3D = _colliders[id]
		_visuals.erase(id)
		_colliders.erase(id)
		body.remove_child(visual)
		body.remove_child(collider)
		into.body.add_child(visual)
		into.body.add_child(collider)
		into._visuals[id] = visual
		into._colliders[id] = collider
		if _extra_colliders.has(id):
			for extra: CollisionShape3D in _extra_colliders[id]:
				body.remove_child(extra)
				into.body.add_child(extra)
			into._extra_colliders[id] = _extra_colliders[id]
			_extra_colliders.erase(id)
		if _decor.has(id):
			for item: JointBatch.Item in _decor[id]:
				_batch.move(item, into.joints())
				if _warm.has(item):
					into._warm[item] = _warm[item]
					_warm.erase(item)
			into._decor[id] = _decor[id]
			_decor.erase(id)
	_drop_joints(moving)
	break_epoch += 1
	_changed([])   # what leaves takes its parts; the split tracks the rest again as it ends
	into.break_epoch += 1
	for c in moving:
		unfile_joint(c)
		_unfile_part_joint(c)
		into.connections.append(c)
		into._joint_set[c] = true
		if into._near_built:
			into._file_joint(c)
		if into._parts_built:
			into._file_part_joint(c)
		var view: JointView = _joint_views.get(c.id)
		if view:
			view.move_to(into.joints())
			into._joint_views[c.id] = view
			_joint_views.erase(c.id)
			if _hot.has(c.id):
				into._hot[c.id] = view
				_hot.erase(c.id)


## The most joints `_drop_joints` takes out one at a time; more go in one pass over the list.
const DROP_EACH_UP_TO := 32


## Takes `gone` (joints in `connections`, in its order) out of `connections`, the rest kept in
## order. A few are found one after another from where the last was (one walk of the list in
## all); many, in one pass that keeps the others.
func _drop_joints(gone: Array[ConnectionData]) -> void:
	for c in gone:
		_joint_set.erase(c)
	if gone.size() <= DROP_EACH_UP_TO:
		var from := 0
		for c in gone:
			var i := connections.find(c, from)
			if i < 0:
				i = connections.find(c)   # not in the list's order after all
				if i < 0:
					continue
			connections.remove_at(i)
			from = i
		return
	var out: Dictionary = {}
	for c in gone:
		out[c] = true
	var kept := 0
	for i in connections.size():
		var c := connections[i]
		if not out.has(c):
			connections[kept] = c
			kept += 1
	connections.resize(kept)


# --- Queries --------------------------------------------------------------------------

## A part's visual, or null.
func part_visual(part_id: int) -> GeometryInstance3D:
	return _visuals.get(part_id) as GeometryInstance3D


## Plug `c` has gone: its lead's look (meta "lead_joint", FrameTarget.power_lead) is drawn
## again. Pulled at the plug (`c.lead_cut` -1), the whole wire hangs off its device, `back`
## metres short of the loom. Severed along it by a torch, the device keeps the wire up to the cut
## and the rest stays on the part the plug is in, `back` apart. Returns [the part the device's end
## hangs on or -1, the part the plug's end hangs on or -1].
func cut_lead(c: ConnectionData, back: float) -> Array[int]:
	var held: Array[int] = [-1, -1]
	var look: Material = WiringLoom.material()   # the lead's own (the game may have redrawn it)
	for id: int in [c.part_b, c.part_a]:
		var visual: Node3D = _visuals.get(id)
		if visual == null:
			continue
		for child in visual.get_children():
			if not (child is MeshInstance3D and child.has_meta("lead_joint")) or int(child.get_meta("lead_joint")) != c.id:
				continue
			var points: PackedVector3Array = child.get_meta("lead_points")
			var cut := _shortened(points, back) if c.lead_cut < 0.0 else split_lead(points, c.lead_cut, back)[0]
			if cut.size() >= 2:
				(child as MeshInstance3D).mesh = WiringLoom.lead_mesh(cut)
			child.set_meta("lead_points", cut)
			child.remove_meta("lead_joint")
			if (child as MeshInstance3D).material_override:
				look = (child as MeshInstance3D).material_override
			held[0] = id
			break
		if held[0] >= 0:
			break
	var plugged: PartData = parts.get(c.part_a)
	if c.lead_cut >= 0.0 and plugged and c.lead.size() >= 2:
		var tail := split_lead(c.lead, c.lead_cut, back)[1]
		if tail.size() >= 2:
			var to_part := plugged.local_transform.affine_inverse()
			var local := PackedVector3Array()
			for p in tail:
				local.append(to_part * p)
			var rest := MeshInstance3D.new()
			rest.name = "LeadEnd"
			rest.mesh = WiringLoom.lead_mesh(local)
			rest.material_override = look
			rest.set_meta("lead_points", local)
			JointBatch.fit_fine(rest, WiringLoom.LEAD_SIZE)
			attach_to_part(plugged, rest)
			held[1] = plugged.id
	return held


## `points` cut at `along` metres from their first end, `gap` metres apart: [the first end up
## to the cut, the cut to the last end] (either may be a single point when the cut is at an end).
static func split_lead(points: PackedVector3Array, along: float, gap: float) -> Array[PackedVector3Array]:
	var head := PackedVector3Array([points[0]])
	var tail := PackedVector3Array()
	var stop := maxf(along - gap * 0.5, 0.0)
	var start := along + gap * 0.5
	var walked := 0.0
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var step := a.distance_to(b)
		var next := walked + step
		if walked < stop:
			head.append(b if next <= stop else a.lerp(b, (stop - walked) / maxf(step, 0.0001)))
		if next > start:
			if tail.is_empty():
				tail.append(a.lerp(b, clampf((start - walked) / maxf(step, 0.0001), 0.0, 1.0)))
			tail.append(b)
		walked = next
	return [head, tail]


## `points` with `back` metres taken off its last end (at least its first stretch kept).
static func _shortened(points: PackedVector3Array, back: float) -> PackedVector3Array:
	var out := points.duplicate()
	var left := back
	while out.size() > 2 and left > 0.0:
		var step := out[out.size() - 1].distance_to(out[out.size() - 2])
		if step > left:
			break
		left -= step
		out.remove_at(out.size() - 1)
	if out.size() >= 2 and left > 0.0:
		var a := out[out.size() - 2]
		var b := out[out.size() - 1]
		var step := a.distance_to(b)
		out[out.size() - 1] = b.lerp(a, minf(left / maxf(step, 0.001), 0.8))
	return out


## A part's main collision node, or null.
func part_collider(part_id: int) -> CollisionShape3D:
	return _colliders.get(part_id) as CollisionShape3D


## A part's further collision shapes (a holed plate's pieces), in the part's space.
func extra_colliders(part_id: int) -> Array:
	return _extra_colliders.get(part_id, [])


## A part's collision shape (in the part's own space), or null.
func part_shape(part_id: int) -> Shape3D:
	var collider := _colliders.get(part_id) as CollisionShape3D
	return collider.shape if collider else null


## The part a collision shape belongs to, or null.
func part_for_collider(collider: CollisionShape3D) -> PartData:
	if collider and collider.has_meta("part_id"):
		return parts.get(collider.get_meta("part_id"))
	return null


## Nearest intact connection to `local` (body space), or null if none within
## `max_distance` m. Welds along a seam count only within `seam_distance` m of the seam
## itself; < 0 = max_distance. Every tool aimed at a body asks this each physics step for
## each player, so it looks only in the grid cells round `local` (`_near_cells`); a wide
## search goes through them all.
func find_connection_near(local: Vector3, max_distance: float, seam_distance: float = -1.0) -> ConnectionData:
	var lo := _near_cell(local - Vector3.ONE * max_distance)
	var hi := _near_cell(local + Vector3.ONE * max_distance)
	var span := hi - lo + Vector3i.ONE
	if not is_finite(max_distance) or span.x * span.y * span.z > NEAR_MAX_CELLS:
		return _nearest_of(connections, local, max_distance, seam_distance)
	_keep_index()
	var found: Array[ConnectionData] = []
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var cell: Array = _near_cells.get(Vector3i(x, y, z), [])
				for c: ConnectionData in cell:
					if not found.has(c):
						found.append(c)
	return _nearest_of(found, local, max_distance, seam_distance)


## The joints filed in the grid cells box `box` (body space) reaches into, by id (SF5's kerf
## scorch: the parts near a cut). A box over `NEAR_MAX_CELLS` cells scans every joint.
func joints_in(box: AABB) -> Array[ConnectionData]:
	var lo := _near_cell(box.position)
	var hi := _near_cell(box.end)
	var span := hi - lo + Vector3i.ONE
	var found: Dictionary = {}
	if span.x * span.y * span.z > NEAR_MAX_CELLS:
		for c in connections:
			if box.grow(NEAR_CELL).has_point(c.local_position):
				found[c.id] = c
	else:
		_keep_index()
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					for c: ConnectionData in _near_cells.get(Vector3i(x, y, z), []):
						found[c.id] = c
	var ids: Array = found.keys()
	ids.sort()
	var out: Array[ConnectionData] = []
	for id: int in ids:
		out.append(found[id])
	return out


## A part's collision box (its main shape and any extras) in its main collider's space
## (`part_collider(id).transform` from the body's), or an empty box when it has none.
func part_box(part_id: int) -> AABB:
	var collider := _colliders.get(part_id) as CollisionShape3D
	if collider == null or collider.shape == null:
		return AABB()
	var box := _solid_box(collider.shape, Transform3D.IDENTITY)
	var back := collider.transform.affine_inverse()
	for extra: CollisionShape3D in _extra_colliders.get(part_id, []):
		box = box.merge(_solid_box(extra.shape, back * extra.transform))
	return box


## The box round `shape` placed by `xform`, primitives at their full size (`_shape_box` keeps a
## primitive's middle only, as `mass_middle` weighs it).
static func _solid_box(shape: Shape3D, xform: Transform3D) -> AABB:
	var half := Vector3.ZERO
	if shape is BoxShape3D:
		half = (shape as BoxShape3D).size * 0.5
	elif shape is SphereShape3D:
		half = Vector3.ONE * (shape as SphereShape3D).radius
	elif shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		half = Vector3(cyl.radius, cyl.height * 0.5, cyl.radius)
	elif shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		half = Vector3(cap.radius, cap.height * 0.5, cap.radius)
	else:
		return _shape_box(shape, xform)
	return xform * AABB(-half, half * 2.0)


## The nearest of `list` (ties: the lowest id, so every machine picks the same joint).
static func _nearest_of(list: Array[ConnectionData], local: Vector3, max_distance: float,
		seam_distance: float) -> ConnectionData:
	var best: ConnectionData = null
	var best_dist := max_distance
	for c in list:
		var dist := c.distance_to(local)
		if seam_distance >= 0.0 and c.seam_size != Vector2.ZERO and dist > seam_distance:
			continue
		if dist < best_dist or (best != null and dist == best_dist and c.id < best.id):
			best_dist = dist
			best = c
	return best


## The plug whose lead (ConnectionData.lead) passes nearest the ray from `origin` along `dir`
## (body space, `dir` unit) within `length`, no further than `snap` off it, or null: a tool
## aimed at a wire bites its plug wherever along the wire it is aimed. Reads the cells the ray
## crosses (ties: the lowest id, so every machine picks the same plug).
func find_lead_near_ray(origin: Vector3, dir: Vector3, length: float, snap: float) -> ConnectionData:
	_keep_index()
	if _lead_ids.is_empty() or length <= 0.0:
		return null
	var found: Dictionary = {}
	var steps := maxi(ceili(length / (NEAR_CELL * 0.5)), 1)
	for i in steps + 1:
		var p := origin + dir * (length * float(i) / float(steps))
		var lo := _near_cell(p - Vector3.ONE * snap)
		var hi := _near_cell(p + Vector3.ONE * snap)
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					for c: ConnectionData in _near_cells.get(Vector3i(x, y, z), []):
						if not c.lead.is_empty():
							found[c] = true
	var best: ConnectionData = null
	var best_off := snap
	for c: ConnectionData in found:
		var near := c.lead_near_ray(origin, dir, length)
		var off: float = near[1]
		if off < best_off or (best != null and off == best_off and c.id < best.id):
			best_off = off
			best = c
	return best


## A box (body space) round every lead's wire this body holds, or an empty AABB when it holds
## none (`has_leads`).
func lead_box() -> AABB:
	_keep_index()
	return _lead_box


func has_leads() -> bool:
	_keep_index()
	return not _lead_ids.is_empty()


## Files joint `c` again after its reach changed (a lead given to a plug).
func refile_joint(c: ConnectionData) -> void:
	unfile_joint(c)
	if _near_built:
		_file_joint(c)


## Builds the joint grid and the part-to-joint lists now, if they aren't (`SalvageStructure.
## end_build`: a body built whole comes with them, so the first tool aimed at her pays nothing).
func build_index() -> void:
	_keep_index()
	_keep_part_index()


## Has the joint grid been built (and kept up since)?
func index_built() -> bool:
	return _near_built and _near_keys.size() == connections.size() \
			and _parts_built and _part_filed.size() == connections.size()


## Every intact joint holding any of the parts in `ids` (part id -> anything), by id (the order
## they were made in, which is `connections`' order). Reads the part-to-joint lists.
func joints_touching(ids: Dictionary) -> Array[ConnectionData]:
	_keep_part_index()
	var found: Dictionary = {}
	for id: int in ids:
		var list: Variant = _by_part.get(id)
		if list == null:
			continue
		for c: ConnectionData in list:
			found[c] = true
	var out: Array[ConnectionData] = []
	out.assign(found.keys())
	if out.size() > 1:
		out.sort_custom(func(x: ConnectionData, y: ConnectionData) -> bool: return x.id < y.id)
	return out


## The intact joints holding part `id`, by id.
func joints_of(id: int) -> Array[ConnectionData]:
	return joints_touching({id: true})


## Points joint `c` at parts `a` and `b` (its head on `a`), keeping the part-to-joint lists right:
## a part torn or sliced into pieces hands each joint to the piece that keeps it.
func repoint(c: ConnectionData, a: int, b: int) -> void:
	if changes_known():
		for id: int in [c.part_a, c.part_b, a, b]:
			changed[id] = true
		if has_joint(c):
			links.append([c.part_a, c.part_b])
	_unfile_part_joint(c)
	c.part_a = a
	c.part_b = b
	if _parts_built and has_joint(c):
		_file_part_joint(c)


## Builds the part-to-joint lists if they aren't, or if `connections` no longer matches them.
func _keep_part_index() -> void:
	if _parts_built and _part_filed.size() == connections.size():
		return
	_by_part.clear()
	_part_filed.clear()
	for c in connections:
		_file_part_joint(c)
	_parts_built = true


func _file_part_joint(c: ConnectionData) -> void:
	if _part_filed.has(c):
		return
	var a := c.part_a
	var b := c.part_b
	(_by_part.get_or_add(a, []) as Array).append(c)
	if b != a:
		(_by_part.get_or_add(b, []) as Array).append(c)
	_part_filed[c] = [a, b]


func _unfile_part_joint(c: ConnectionData) -> void:
	var at: Variant = _part_filed.get(c)
	if at == null:
		return
	_part_filed.erase(c)
	for id: int in at:
		var list: Variant = _by_part.get(id)
		if list == null:
			continue
		(list as Array).erase(c)
		if (list as Array).is_empty():
			_by_part.erase(id)


## The intact joint with this id, or null.
func connection_by_id(id: int) -> ConnectionData:
	_keep_index()
	return _by_id.get(id)


## The holder took joint `c` out of `connections` itself (a break): it leaves the index.
func unfile_joint(c: ConnectionData) -> void:
	var cells: Array = _near_keys.get(c.id, [])
	for key: Vector3i in cells:
		var cell: Array = _near_cells.get(key, [])
		cell.erase(c)
		if cell.is_empty():
			_near_cells.erase(key)
	_near_keys.erase(c.id)
	_by_id.erase(c.id)
	_lead_ids.erase(c.id)


## Builds the index if it isn't, or if `connections` no longer matches it.
func _keep_index() -> void:
	if _near_built and _near_keys.size() == connections.size():
		return
	_near_cells.clear()
	_near_keys.clear()
	_by_id.clear()
	_lead_ids.clear()
	_lead_box = AABB()
	for c in connections:
		_file_joint(c)
	_near_built = true


## Files a joint under each cell its head or seam reaches into.
func _file_joint(c: ConnectionData) -> void:
	if not c.lead.is_empty():
		_file_lead(c)
		return
	var reach := Vector3.ZERO
	if c.seam_size != Vector2.ZERO and c.seam_up != Vector3.ZERO:
		var up := c.seam_up.normalized()
		var across := up.cross(c.local_normal).normalized()
		reach = (up * c.seam_size.x * 0.5).abs() + (across * c.seam_size.y * 0.5).abs()
	var lo := _near_cell(c.local_position - reach)
	var hi := _near_cell(c.local_position + reach)
	var keys: Array[Vector3i] = []
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var key := Vector3i(x, y, z)
				(_near_cells.get_or_add(key, []) as Array).append(c)
				keys.append(key)
	_near_keys[c.id] = keys
	_by_id[c.id] = c


## A plug on a lead is filed in every cell its wire's segments' boxes touch, and the plug's.
func _file_lead(c: ConnectionData) -> void:
	var keys: Array[Vector3i] = []
	var spans: Array = [[c.local_position, c.local_position]]
	for i in range(1, c.lead.size()):
		spans.append([c.lead[i - 1], c.lead[i]])
	if _lead_ids.is_empty():
		_lead_box = AABB(c.local_position, Vector3.ZERO)
	_lead_box = _lead_box.expand(c.local_position)
	for p in c.lead:
		_lead_box = _lead_box.expand(p)
	for span: Array in spans:
		var a: Vector3 = span[0]
		var b: Vector3 = span[1]
		var lo := _near_cell(a.min(b))
		var hi := _near_cell(a.max(b))
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var key := Vector3i(x, y, z)
					if not keys.has(key):
						(_near_cells.get_or_add(key, []) as Array).append(c)
						keys.append(key)
	_near_keys[c.id] = keys
	_by_id[c.id] = c
	_lead_ids[c.id] = true


static func _near_cell(p: Vector3) -> Vector3i:
	return Vector3i((p / NEAR_CELL).floor())


## (HK6b) Starts noting the parts changes touch from now (`changed`): the holder knows the body
## is one group of joined parts now (a split has just left it so).
func track_changes() -> void:
	changed.clear()
	added.clear()
	links.clear()
	changes_epoch = break_epoch


## Are the parts every change since `track_changes` touched all in `changed`?
func changes_known() -> bool:
	return changes_epoch >= 0 and changes_epoch == break_epoch


## Notes the joint between `a` and `b`, just taken out, while changes are known.
func _link(a: int, b: int) -> void:
	if changes_epoch == break_epoch:
		links.append([a, b])


## Notes `ids` as touched by the change that just moved `break_epoch` on (while they are known).
func _changed(ids: Array) -> void:
	if changes_epoch != break_epoch - 1:
		return
	changes_epoch = break_epoch
	for id: int in ids:
		changed[id] = true


## (HK6b) The groups the changes since `track_changes` cut off a body that was one group then, found
## by searching out from the parts they touched (`changed`), a part from each search in turn, so the
## small side of a break turns up in a few steps and the big side is never walked: a group no search
## could finish (or the parts no change touched) is the rest of the body, which needs no listing. Every
## group the changes made holds a part they touched; only the body's own parts can lie in none, and
## then all of them in one, so the search left may stop unfinished once it holds one of the body's own
## parts (a part added since, joined to nothing, is a group of its own). Searches that never meet (two
## rivets broken at either end of her) stop unfinished too once the joints taken out show they can
## only be one group (`_settled`). {groups: the groups found whole (each
## its part ids, lowest first), joints: per group every joint whose part_a is on it (by id, the order
## `take_group` keeps), rest: true when the rest of the body is one more group, unlisted (false: the
## groups are every part)}. {} when the changes aren't all known, or `limit` parts were searched
## before at most one search was left: walk every part (`find_groups`).
func local_groups(limit: int) -> Dictionary:
	if not changes_known():
		return {}
	_keep_part_index()
	var starts: Array = []
	for id: int in changed:
		if parts.has(id):
			starts.append(id)
	starts.sort()
	var owner: Dictionary = {}   # part id -> the search that found it (follow `root`)
	var root: Array[int] = []   # per search: the search it was merged into (itself while its own)
	var members: Array = []   # per search: its parts, in the order found
	var next: Array[int] = []   # per search: its next member to look out from
	var own: Array[bool] = []   # per search: holds one of the body's own parts (not added since)
	for id: int in starts:
		owner[id] = root.size()
		root.append(root.size())
		members.append([id])
		next.append(0)
		own.append(not added.has(id))
	var live: Array[int] = []
	for i in root.size():
		live.append(i)
	var hyper := _hyper_links()
	var due := true   # a search finished or two met: the links may settle it now
	var searched := 0
	while not live.is_empty():
		if live.size() == 1 and own[live[0]]:
			break
		if due and _settled(hyper, owner, root, live, own):
			break
		due = false
		for s: int in live:
			if root[s] != s:
				continue   # merged into another this round
			var mine: Array = members[s]
			if next[s] >= mine.size():
				continue   # finished: every part joined to it is found
			var id: int = mine[next[s]]
			next[s] += 1
			searched += 1
			for c: ConnectionData in _by_part.get(id, []):
				if not c.structural:
					continue
				var n := c.part_b if c.part_a == id else c.part_a
				if n == id or not parts.has(n):
					continue
				var o: int = owner.get(n, -1)
				if o < 0:
					owner[n] = s
					mine.append(n)
					if not own[s] and not added.has(n):
						own[s] = true
					continue
				var t := _root_of(root, o)
				if t == s:
					continue
				# Two searches met: one group. The bigger takes the other's parts (looked from again
				# at its end: what they reach is found already, or met).
				var keep := s if mine.size() >= (members[t] as Array).size() else t
				var gone := t if keep == s else s
				var kept: Array = members[keep]
				kept.append_array(members[gone])
				members[gone] = []
				next[gone] = 0
				own[keep] = own[keep] or own[gone]
				root[gone] = keep
				s = keep
				mine = kept
				due = true
		if searched > limit:
			return {}
		var still: Array[int] = []
		for s: int in live:
			if root[s] == s and next[s] < (members[s] as Array).size():
				still.append(s)
			elif root[s] == s:
				due = true   # finished
		live = still
	# Every finished search is a group; the one left (if any) is the rest of the body.
	var groups: Array[Array] = []
	var joints: Array = []
	var listed := 0
	for s in root.size():
		if root[s] != s or s in live:
			continue
		var group: Array = members[s]
		group.sort()
		listed += group.size()
		groups.append(group)
		var found: Dictionary = {}
		for id: int in group:
			for c: ConnectionData in _by_part.get(id, []):
				if c.part_a == id:
					found[c] = true
		var list: Array = found.keys()
		list.sort_custom(func(x: ConnectionData, y: ConnectionData) -> bool: return x.id < y.id)
		joints.append(list)
	var rest := not live.is_empty() or listed < parts.size()
	return {"groups": groups, "joints": joints, "rest": rest}


## (HK6b) The joints taken out since `track_changes` as the parts each joined, those that went too
## seen through: joints that met at a part gone since are one link between the parts left at their
## other ends (the body was one group through it). Each an Array of part ids still here.
func _hyper_links() -> Array:
	var up: Dictionary = {}
	for link: Array in links:
		var gone: Array = []
		for id: int in link:
			if not parts.has(id):
				gone.append(id)
		if gone.size() == 2:
			var a := _find(up, gone[0])
			var b := _find(up, gone[1])
			if a != b:
				up[b] = a
	var out: Array = []
	var through: Dictionary = {}   # a gone part's set -> the parts here its joints reached
	for link: Array in links:
		var a: int = link[0]
		var b: int = link[1]
		var has_a := parts.has(a)
		var has_b := parts.has(b)
		if has_a and has_b:
			out.append(link)
		elif has_a or has_b:
			var rep := _find(up, b if has_a else a)
			var ends: Array = through.get(rep, [])
			ends.append(a if has_a else b)
			through[rep] = ends
	out.append_array(through.values())
	return out


## (HK6b) May the searches still going (`live`) stop unfinished as one group? The body was one group
## when tracking began, so the groups now are joined to each other through the joints taken out
## since (`hyper`). If no link joins two searches still going, and no set of finished groups joined
## by links touches two of them, then the searches still going lie apart only through links that
## don't exist: they are one group. Each must hold one of the body's own parts (a part added since
## could be a group of its own).
func _settled(hyper: Array, owner: Dictionary, root: Array[int], live: Array[int],
		own: Array[bool]) -> bool:
	var going: Dictionary = {}
	for s: int in live:
		if not own[s]:
			return false
		going[s] = true
	var up: Dictionary = {}   # finished search -> the one its cluster goes by
	var touch: Dictionary = {}   # cluster -> the search still going it touches
	for link: Array in hyper:
		var open := -1
		var first := -1
		for id: int in link:
			var o: int = owner.get(id, -1)
			if o < 0:
				return false
			var r := _root_of(root, o)
			if going.has(r):
				if open >= 0 and open != r:
					return false
				open = r
				continue
			var f := _find(up, r)
			if first < 0:
				first = f
			elif f != first:
				up[f] = first
				var was: int = touch.get(f, -1)
				if was >= 0:
					var mine: int = touch.get(first, -1)
					if mine >= 0 and mine != was:
						return false
					touch[first] = was
		if open >= 0 and first >= 0:
			var mine: int = touch.get(first, -1)
			if mine >= 0 and mine != open:
				return false
			touch[first] = open
	return true


static func _find(up: Dictionary, x: int) -> int:
	var r := x
	while up.get(r, r) != r:
		r = up[r]
	while up.get(x, x) != r:
		var n: int = up[x]
		up[x] = r
		x = n
	return r


static func _root_of(root: Array[int], s: int) -> int:
	while root[s] != s:
		root[s] = root[root[s]]
		s = root[s]
	return s


## Groups of part ids that are joined to each other by intact connections.
func find_groups() -> Array[Array]:
	var neighbours: Dictionary = {}
	for id: int in parts:
		neighbours[id] = []
	for c in connections:
		if c.structural and neighbours.has(c.part_a) and neighbours.has(c.part_b):
			(neighbours[c.part_a] as Array).append(c.part_b)
			(neighbours[c.part_b] as Array).append(c.part_a)

	var groups: Array[Array] = []
	var seen: Dictionary = {}
	for start: int in parts:
		if seen.has(start):
			continue
		var group: Array[int] = []
		var queue: Array[int] = [start]
		seen[start] = true
		while not queue.is_empty():
			var id: int = queue.pop_back()
			group.append(id)
			for n: int in neighbours[id]:
				if not seen.has(n):
					seen[n] = true
					queue.append(n)
		groups.append(group)
	return groups


## The total mass of the parts in `group` (ids), kg.
func group_mass(group: Array) -> float:
	var total := 0.0
	for id: int in group:
		total += (parts[id] as PartData).mass
	return total
