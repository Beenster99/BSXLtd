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
## A planned fastening was set (the riveter's rivet, the welder's weld): its new joint.
signal fastened(c: ConnectionData)

## Fastenings planned but not yet in (0.4.0 playtest: the riveter and the welder put them in):
## {kind, a, b (part ids), at, normal, seam_up, seam_size (body space, as connect_parts takes
## them), done (0..1)}. Each is marked on the work: a rivet's hole ringed, a weld's line chalked,
## and as it goes in the rivet's head swells and the bead runs along its line, glowing.
var planned: Array[Dictionary] = []
var _plan_marks: Dictionary = {}   # a plan's id -> its marks (Node3D)
var _next_plan: int = 0
static var _chalk: StandardMaterial3D
static var _hot: StandardMaterial3D


func _init() -> void:
	gravity_scale = 0.0
	can_sleep = false
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	model = PartModel.new(self, true)
	add_to_group(GROUP)


func _process(delta: float) -> void:
	model.cool(delta)
	# Work under way glows and cools as the joints do.
	for id: int in _plan_marks:
		var bead := (_plan_marks[id] as Node3D).get_node_or_null("Bead") as MeshInstance3D if is_instance_valid(_plan_marks[id]) else null
		if bead and bead.visible:
			var m := bead.material_override as StandardMaterial3D
			m.emission_energy_multiplier = maxf(m.emission_energy_multiplier - delta * 1.2, 0.0)


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


## Plans a fastening of `kind` joining parts `a` and `b` at `at` (body space) facing `normal`;
## a weld runs along `seam_up` for `seam_size.x` (as connect_parts takes them).
func plan(kind: ConnectionData.Kind, a: PartData, b: PartData, at: Vector3, normal: Vector3,
		seam_up := Vector3.ZERO, seam_size := Vector2.ZERO) -> Dictionary:
	_next_plan += 1
	var p := {"id": _next_plan, "kind": kind, "a": a.id, "b": b.id, "at": at, "normal": normal.normalized(),
			"seam_up": seam_up.normalized(), "seam_size": seam_size, "done": 0.0}
	planned.append(p)
	_mark(p)
	return p


## The planned fastening of `kind` nearest `world_point` within `snap` (a weld anywhere along
## its line), or {}.
func planned_near(world_point: Vector3, snap: float, kind: int) -> Dictionary:
	var local := to_local(world_point)
	var best: Dictionary = {}
	var best_d := snap
	for p: Dictionary in planned:
		if int(p.kind) != kind:
			continue
		var d := local.distance_to(_closest_on(p, local))
		if d <= best_d:
			best_d = d
			best = p
	return best


## Where the work is on plan `p` now (world): a rivet's hole, or how far along its line a weld is.
func planned_position(p: Dictionary) -> Vector3:
	return global_transform * _along(p, float(p.done))


func planned_normal(p: Dictionary) -> Vector3:
	return (global_basis * (p.normal as Vector3)).normalized()


## Works plan `p` on by `amount` (of the whole); true once it is in, its joint made (hot).
func work_planned(p: Dictionary, amount: float) -> bool:
	if not planned.has(p) or not model.parts.has(int(p.a)) or not model.parts.has(int(p.b)):
		return false
	p.done = minf(float(p.done) + maxf(amount, 0.0), 1.0)
	_mark_progress(p)
	if float(p.done) < 1.0:
		return false
	planned.erase(p)
	var marks: Node3D = _plan_marks.get(int(p.id))
	_plan_marks.erase(int(p.id))
	if is_instance_valid(marks):
		marks.queue_free()
	var c := model.connect_parts(model.parts[int(p.a)], model.parts[int(p.b)], int(p.kind), p.at, p.normal, p.seam_up, p.seam_size)
	model.heat(c, 1.0)
	fastened.emit(c)
	return true


func _closest_on(p: Dictionary, local: Vector3) -> Vector3:
	var up: Vector3 = p.seam_up
	var half := (p.seam_size as Vector2).x * 0.5
	if up.is_zero_approx() or half <= 0.0:
		return p.at
	return (p.at as Vector3) + up * clampf((local - (p.at as Vector3)).dot(up), -half, half)


func _along(p: Dictionary, t: float) -> Vector3:
	var up: Vector3 = p.seam_up
	var half := (p.seam_size as Vector2).x * 0.5
	if up.is_zero_approx() or half <= 0.0:
		return p.at
	return (p.at as Vector3) + up * lerpf(-half, half, clampf(t, 0.0, 1.0))


## A plan's marks on the work: a chalk ring round a rivet's hole, or a chalk line down a weld's
## seam; and what goes in, hidden until work starts (the rivet's head, the weld's bead).
func _mark(p: Dictionary) -> void:
	if _chalk == null:
		_chalk = StandardMaterial3D.new()
		_chalk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_chalk.albedo_color = Color(1.0, 0.85, 0.25)
		_hot = StandardMaterial3D.new()
		_hot.albedo_color = Color(0.5, 0.48, 0.46)
		_hot.metallic = 0.7
		_hot.roughness = 0.4
		_hot.emission_enabled = true
		_hot.emission = Color(1.0, 0.45, 0.1)
		_hot.emission_energy_multiplier = 3.0
	var marks := Node3D.new()
	marks.name = "Plan_%d" % planned.size()
	marks.set_meta("gfx_coplanar_ok", true)
	var n: Vector3 = p.normal
	var up: Vector3 = p.seam_up
	if up.is_zero_approx():
		up = Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var side := up.cross(n).normalized()
	up = n.cross(side).normalized()
	marks.transform = Transform3D(Basis(side, up, n), p.at)
	add_child(marks)
	_plan_marks[int(p.id)] = marks
	var length := (p.seam_size as Vector2).x
	if length > 0.0:
		for k in int(length / 0.04):
			var dash := MeshInstance3D.new()
			var dm := BoxMesh.new()
			dm.size = Vector3(0.006, 0.022, 0.001)
			dash.mesh = dm
			dash.material_override = _chalk
			dash.position = Vector3(0, -length * 0.5 + 0.02 + k * 0.04, 0.0015)
			dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			marks.add_child(dash)
		var bead := MeshInstance3D.new()
		bead.name = "Bead"
		var bm := CapsuleMesh.new()
		bm.radius = 0.008
		bm.height = 0.02
		bead.mesh = bm
		bead.material_override = _hot.duplicate()
		bead.visible = false
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.add_child(bead)
	else:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.014
		tm.outer_radius = 0.019
		tm.rings = 16
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = _chalk
		ring.rotation = Vector3(PI * 0.5, 0, 0)
		ring.scale = Vector3(1, 0.1, 1)
		ring.position = Vector3(0, 0, 0.0015)
		marks.add_child(ring)
		var hole := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.006
		hm.bottom_radius = 0.006
		hm.height = 0.002
		hole.mesh = hm
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.03, 0.03, 0.035)
		hole.material_override = dark
		hole.rotation = Vector3(PI * 0.5, 0, 0)
		hole.position = Vector3(0, 0, 0.0012)
		marks.add_child(hole)
		var head := MeshInstance3D.new()
		head.name = "Bead"
		var sm := SphereMesh.new()
		sm.radius = 0.011
		sm.height = 0.011
		head.mesh = sm
		head.material_override = _hot.duplicate()
		head.visible = false
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.add_child(head)


func _mark_progress(p: Dictionary) -> void:
	var marks: Node3D = _plan_marks.get(int(p.id))
	if not is_instance_valid(marks):
		return
	var bead := marks.get_node_or_null("Bead") as MeshInstance3D
	if bead == null:
		return
	var t := float(p.done)
	bead.visible = t > 0.0
	var length := (p.seam_size as Vector2).x
	if length > 0.0:
		var run := maxf(length * t, 0.02)
		(bead.mesh as CapsuleMesh).height = run
		bead.position = Vector3(0, -length * 0.5 + run * 0.5, 0.004)
	else:
		bead.scale = Vector3.ONE * lerpf(0.3, 1.0, t)
		bead.position = Vector3(0, 0, 0.003)
	(bead.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0


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
