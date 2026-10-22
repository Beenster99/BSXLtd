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
## What rivet heads made from now on look like (ConnectionData.head): 0 classic, 1 flush
## bumps. Build time, identical on every machine.
var head_style: int = 0

## part id -> MeshInstance3D (the part's visual; extra visuals such as lights hang under it)
var _visuals: Dictionary = {}
## part id -> CollisionShape3D
var _colliders: Dictionary = {}
## part id -> [CollisionShape3D] for parts with more than one shape (holed plates), in
## the part's space like `_colliders`; they follow the part through every move.
var _extra_colliders: Dictionary = {}
## connection id -> JointView (the visible rivet head, bolt head or weld bead)
var _joint_views: Dictionary = {}
## Draws every head, stub and scar on the body in a few batches (JointBatch).
var _batch: JointBatch
## Views glowing right now (connection id -> JointView), cooled each frame.
var _hot: Dictionary = {}
## Marks left on parts (sheared stubs, weld scars): part id -> Array of JointBatch.Item,
## so they travel with the part when it moves to another body.
var _decor: Dictionary = {}


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
func add_decor(part_id: int, mesh: Mesh, material: Material, xform: Transform3D) -> void:
	var item := JointBatch.Item.new(mesh, material, xform)
	joints().add(item)
	(_decor.get_or_add(part_id, []) as Array).append(item)


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


# --- Building -------------------------------------------------------------------------

## Adds a part with its own visual (`material` as given) and collision shape at
## `local_xform` (body space). Returns its data.
func add_part(part_name: String, kind: PartData.Kind, part_mass: float, part_value: float,
		local_xform: Transform3D, mesh: Mesh, shape: Shape3D, material: Material) -> PartData:
	var part := PartData.new(_take_part_id(), part_name, kind, part_mass, part_value, local_xform)
	part.material = Materials.built_for(part_name, kind)
	parts[part.id] = part

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
	connections.append(c)
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
		weighted += part.local_transform * part.centroid * part.mass   # a cut piece's own middle
	return [total, weighted / total if total > 0.0 else Vector3.ZERO]


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
				c.local_position = by * c.local_position
				c.local_normal = (by.basis * c.local_normal).normalized()
				c.seam_up = by.basis * c.seam_up
				var view: JointView = _joint_views.get(c.id)
				if view:
					view.set_part_xform(xform)
		for item: JointBatch.Item in _decor.get(part_id, []):
			item.xform = by * item.xform
			_batch.update(item)
		return
	var shift := xform.origin - part.local_transform.origin
	part.local_transform = xform
	_place_nodes(part_id, xform)
	for c in connections:
		if c.part_a == part_id:
			c.local_position += shift
			var view: JointView = _joint_views.get(c.id)
			if view:
				view.set_part_xform(xform)
	for item: JointBatch.Item in _decor.get(part_id, []):
		item.xform.origin += shift
		_batch.update(item)


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
			c.local_position = by * c.local_position
			c.local_normal = (by.basis * c.local_normal).normalized()
			c.seam_up = by.basis * c.seam_up
			var view: JointView = _joint_views.get(c.id)
			if view:
				view.set_part_xform(part.local_transform)
	for item: JointBatch.Item in _decor.get(part_id, []):
		item.xform = by * item.xform
		_batch.update(item)


## Takes joint `c` out quietly (its head stops drawing).
func drop_connection(c: ConnectionData) -> void:
	connections.erase(c)
	var view := forget_view(c)
	if view:
		view.clear()


## Takes part `id` out with its nodes and marks (its joints are the caller's to drop).
func erase_part(id: int) -> void:
	parts.erase(id)
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
	if v:
		body.remove_child(v)
		v.queue_free()
	if col:
		body.remove_child(col)
		col.queue_free()


## Moves the parts in `group` (ids) and every joint whose head is on one of them over to
## `into`, nodes, heads and marks included. Both bodies must stand in the same place (a
## split piece starts where its structure is), so every transform stays valid.
func take_group(group: Array, into: PartModel) -> void:
	var group_ids: Dictionary = {}
	for id: int in group:
		group_ids[id] = true
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
			into._decor[id] = _decor[id]
			_decor.erase(id)
	for c: ConnectionData in connections.duplicate():
		if group_ids.has(c.part_a):
			connections.erase(c)
			into.connections.append(c)
			var view: JointView = _joint_views.get(c.id)
			if view:
				view.move_to(into.joints())
				into._joint_views[c.id] = view
				_joint_views.erase(c.id)
				if _hot.has(c.id):
					into._hot[c.id] = view
					_hot.erase(c.id)


# --- Queries --------------------------------------------------------------------------

## A part's visual, or null.
func part_visual(part_id: int) -> GeometryInstance3D:
	return _visuals.get(part_id) as GeometryInstance3D


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
## itself; < 0 = max_distance.
func find_connection_near(local: Vector3, max_distance: float, seam_distance: float = -1.0) -> ConnectionData:
	var best: ConnectionData = null
	var best_dist := max_distance
	for c in connections:
		var dist := c.distance_to(local)
		if seam_distance >= 0.0 and c.seam_size != Vector2.ZERO and dist > seam_distance:
			continue
		if dist < best_dist:
			best_dist = dist
			best = c
	return best


## Groups of part ids that are joined to each other by intact connections.
func find_groups() -> Array[Array]:
	var neighbours: Dictionary = {}
	for id: int in parts:
		neighbours[id] = []
	for c in connections:
		if neighbours.has(c.part_a) and neighbours.has(c.part_b):
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
