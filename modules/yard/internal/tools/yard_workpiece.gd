class_name YardWorkpiece
extends RigidBody3D
## A body built from parts and joints (the shared PartModel) that the yard's hand tools work:
## for now the practice frame in the dock, later the ships on the berths. Joints lose health
## to the tools; when one breaks, every group of parts no longer joined to the anchor part
## (or, on a loose piece, to the heaviest group) flies off as a piece of its own.
##
## Single player for now (stage 1.6 brings the crew).

const GROUP := &"yard_workpieces"

## The parts and joints.
var model: PartModel
## The part that stays put when the rest comes off (-1: none, the heaviest group stays).
var anchor_part: int = -1
## Joints broken here and on every piece split off (tests and the screen read it).
signal joint_broken(c: ConnectionData)
## A piece came off: the new body.
signal piece_freed(piece: YardWorkpiece)


func _init() -> void:
	gravity_scale = 0.0
	can_sleep = false
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	model = PartModel.new(self, true)
	add_to_group(GROUP)


func _process(delta: float) -> void:
	model.cool(delta)


## The joint nearest `world_point` within `snap` (a weld anywhere along its seam within
## `seam_snap`), or null.
func joint_near(world_point: Vector3, snap: float, seam_snap: float) -> ConnectionData:
	return model.find_connection_near(to_local(world_point), snap, seam_snap)


## Where joint `c`'s head is now (world).
func joint_position(c: ConnectionData) -> Vector3:
	var view := model.joint_view(c)
	if view:
		return global_transform * view.structure_transform().origin
	return global_transform * c.local_position


func joint_normal(c: ConnectionData) -> Vector3:
	return (global_basis * c.local_normal).normalized()


## The harder material of the two parts a joint holds ("" if unknown).
func joint_material(c: ConnectionData) -> String:
	var a: PartData = model.parts.get(c.part_a)
	var b: PartData = model.parts.get(c.part_b)
	if a == null or b == null:
		return a.material if a else (b.material if b else "")
	return a.material if Materials.tier(a.material) >= Materials.tier(b.material) else b.material


## The part a ray hit (from intersect_ray), or null.
func part_at_hit(hit: Dictionary) -> PartData:
	var owner_id := shape_find_owner(int(hit.get("shape", 0)))
	var collider := shape_owner_get_owner(owner_id) as CollisionShape3D
	return model.part_for_collider(collider) if collider else null


## Glows a joint with the tool's heat.
func heat_joint(c: ConnectionData, amount: float) -> void:
	model.heat(c, amount)


## Takes `amount` points off joint `c`; true if it broke (and anything cut off flew free).
func damage_connection(c: ConnectionData, amount: float) -> bool:
	if not model.has_joint(c) or amount <= 0.0:
		return false
	c.health -= amount
	if c.health > 0.0:
		return false
	model.drop_connection(c)
	joint_broken.emit(c)
	_split()
	return true


## Every group of parts no longer joined to the one that stays becomes its own body, moving
## as this one does where it is.
func _split() -> void:
	var groups := _groups()
	if groups.size() < 2:
		return
	var keep := 0
	for i in groups.size():
		if anchor_part >= 0 and (groups[i] as Array).has(anchor_part):
			keep = i
			break
		if anchor_part < 0 and _mass_of(groups[i]) > _mass_of(groups[keep]):
			keep = i
	for i in groups.size():
		if i == keep:
			continue
		var piece := YardWorkpiece.new()
		piece.name = "Piece_%d" % int((groups[i] as Array).min())
		piece.joint_broken.connect(func(c: ConnectionData) -> void: joint_broken.emit(c))
		piece.piece_freed.connect(func(p: YardWorkpiece) -> void: piece_freed.emit(p))
		get_parent().add_child(piece)
		piece.global_transform = global_transform
		model.take_group(groups[i], piece.model)
		piece._weigh()
		piece.linear_velocity = linear_velocity
		piece.angular_velocity = angular_velocity
		piece_freed.emit(piece)
	if not freeze:
		_weigh()


## Sets the body's mass and centre from its parts.
func _weigh() -> void:
	var m := model.recompute_mass()
	mass = maxf(float(m[0]), 0.1)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = m[1]


func _mass_of(group: Array) -> float:
	var total := 0.0
	for id: int in group:
		total += (model.parts[id] as PartData).mass
	return total


## The parts in groups joined by intact joints.
func _groups() -> Array:
	var links: Dictionary = {}
	for id: int in model.parts:
		links[id] = []
	for c in model.connections:
		if links.has(c.part_a) and links.has(c.part_b):
			(links[c.part_a] as Array).append(c.part_b)
			(links[c.part_b] as Array).append(c.part_a)
	var seen: Dictionary = {}
	var out: Array = []
	for id: int in links:
		if seen.has(id):
			continue
		var group: Array = []
		var todo: Array = [id]
		seen[id] = true
		while not todo.is_empty():
			var at: int = todo.pop_back()
			group.append(at)
			for other: int in links[at]:
				if not seen.has(other):
					seen[other] = true
					todo.append(other)
		out.append(group)
	return out
