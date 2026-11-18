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
## Finished welds' beads, kept on the work until their joint is cut: node -> ConnectionData.
var _kept_beads: Dictionary = {}
## The last weld finished: {quality (0..1), grade ("NEAT", "FAIR", "POOR")}.
var last_weld: Dictionary = {}
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
	for node: Node3D in _kept_beads.keys():
		var c: ConnectionData = _kept_beads[node]
		if not is_instance_valid(node) or c.is_broken() or not model.has_joint(c):
			if is_instance_valid(node):
				node.queue_free()
			_kept_beads.erase(node)
	for id: int in _plan_marks:
		var m: Node3D = _plan_marks[id]
		var puddle := m.get_node_or_null("Puddle") as Node3D if is_instance_valid(m) else null
		if puddle and puddle.visible:
			puddle.scale = puddle.scale.move_toward(Vector3.ZERO, delta * 2.5)
			if puddle.scale.x < 0.05:
				puddle.visible = false
	# The welder's guides show only while it is aimed at the seam.
	var now := Time.get_ticks_msec()
	for id: int in _plan_marks:
		var m: Node3D = _plan_marks[id]
		if not is_instance_valid(m):
			continue
		var tip := m.get_node_or_null("Tip") as Node3D
		if tip and tip.visible and now - int(m.get_meta("aimed_ms", 0)) > 150:
			for g: String in ["Tip", "Pace"]:
				(m.get_node(g) as Node3D).visible = false
			(m.get_node("Guide") as MeshInstance3D).transparency = 0.6
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
	if p.has("front"):   # a weld under way: where its puddle is
		return global_transform * ((p.at as Vector3) + (p.seam_up as Vector3) * (float(p.front) - (p.seam_size as Vector2).x * 0.5))
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
	_finish(p, false)
	return true


## The welder works plan `p` by hand (0.4.1 playtest: "the welding should follow your line and
## speed"): the puddle follows the arc where it is aimed (`aim_world`), along the seam from the end
## it started at, never faster than `max_speed` (m/s). A ripple of bead is laid every RIPPLE_STEP
## of travel, shaped by how fast you go against `ideal` (m/s): steady makes the even stacked
## ripples of a neat weld, too fast a thin, broken, sooty one, too slow a fat, lumpy, burnt one.
## Returns {laid (metal went down), speed (m/s), pace ("STEADY", "TOO FAST", "TOO SLOW", "OFF
## THE LINE"), done (the weld is in: its joint made, as strong as the bead was good)}.
func weld_along(p: Dictionary, aim_world: Vector3, delta: float, ideal: float, max_speed := 0.4) -> Dictionary:
	var out := {"laid": false, "speed": 0.0, "pace": "", "done": false}
	if not planned.has(p) or delta <= 0.0:
		return out
	var length := (p.seam_size as Vector2).x
	var up: Vector3 = p.seam_up
	var local := to_local(aim_world)
	var at := clampf((local - (p.at as Vector3)).dot(up) + length * 0.5, 0.0, length)
	if not p.has("front"):
		var low := at < length * 0.5
		p.dir = 1.0 if low else -1.0
		p.front = 0.0 if low else length
		p.start = p.front
		p.next_ripple = p.front
		p.speed = ideal
		p.ripples = 0
		p.q_sum = 0.0
	var ahead := (at - float(p.front)) * float(p.dir)
	if ahead < -0.025 or ahead > 0.07:
		p.speed = lerpf(float(p.speed), 0.0, minf(1.0, delta * 2.0))
		out.pace = "OFF THE LINE"
		out.speed = p.speed
		return out
	var step := clampf(ahead, 0.0, max_speed * delta)
	p.speed = lerpf(float(p.speed), step / delta, minf(1.0, delta * 5.0))
	p.front = clampf(float(p.front) + step * float(p.dir), 0.0, length)
	var r := float(p.speed) / maxf(ideal, 0.001)
	out.speed = p.speed
	out.pace = "TOO FAST" if r > 1.6 else ("TOO SLOW" if r < 0.6 else "STEADY")
	while (float(p.front) - float(p.next_ripple)) * float(p.dir) >= 0.0 and int(p.ripples) < _ripple_room(p):
		_lay_ripple(p, float(p.next_ripple) - length * 0.5, r)
		p.next_ripple = float(p.next_ripple) + RIPPLE_STEP * float(p.dir)
		out.laid = true
	p.done = absf(float(p.front) - float(p.start)) / maxf(length, 0.001)
	if float(p.done) >= 0.999:
		var q := float(p.q_sum) / maxf(float(p.ripples), 1.0)
		var c := _finish(p, true)
		if c:
			c.health = c.max_health * lerpf(0.35, 1.0, q)
			c.max_health = c.health
		last_weld = {"quality": q, "grade": "NEAT" if q >= 0.8 else ("FAIR" if q >= 0.5 else "POOR")}
		out.done = true
	return out


## Where along its seam plan `p` is aimed (0..1, from its low end).
func weld_t(p: Dictionary, world_point: Vector3) -> float:
	var length := (p.seam_size as Vector2).x
	var local := to_local(world_point)
	return clampf(((local - (p.at as Vector3)).dot(p.seam_up) + length * 0.5) / maxf(length, 0.001), 0.0, 1.0)


## A weld's bead (tests and the screen read it): how many ripples, and their mean quality.
func bead_of(p: Dictionary) -> Dictionary:
	return {"ripples": int(p.get("ripples", 0)), "quality": float(p.get("q_sum", 0.0)) / maxf(float(p.get("ripples", 0)), 1.0)}


const RIPPLE_STEP := 0.0045


func _ripple_room(p: Dictionary) -> int:
	return int((p.seam_size as Vector2).x / RIPPLE_STEP) + 2


## One ripple of bead at `y` along the seam (the marks' space), shaped by `r`, the speed over
## the ideal: its width, height, spacing, colour and whether it is there at all.
func _lay_ripple(p: Dictionary, y: float, r: float) -> void:
	var marks: Node3D = _plan_marks.get(int(p.id))
	if not is_instance_valid(marks):
		return
	var mmi := marks.get_node_or_null("Ripples") as MultiMeshInstance3D
	if mmi == null:
		mmi = MultiMeshInstance3D.new()
		mmi.name = "Ripples"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 14
		sm.rings = 7
		mm.mesh = sm
		mm.instance_count = _ripple_room(p)
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.6
		m.roughness = 0.24
		m.metallic_specular = 0.8
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.add_child(mmi)
		# The cleaned, heat-tinted band either side of the bead (a flat disc a ripple, under it).
		var halo := MultiMeshInstance3D.new()
		halo.name = "Halo"
		var hm := MultiMesh.new()
		hm.transform_format = MultiMesh.TRANSFORM_3D
		hm.use_colors = true
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 1.0
		disc.radial_segments = 14
		disc.rings = 1
		hm.mesh = disc
		hm.instance_count = mm.instance_count
		hm.visible_instance_count = 0
		halo.multimesh = hm
		var hmat := StandardMaterial3D.new()
		hmat.vertex_color_use_as_albedo = true
		hmat.metallic = 0.5
		hmat.roughness = 0.35
		halo.material_override = hmat
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.add_child(halo)
	var q := 1.0
	if r > 1.4:
		q = clampf(1.0 - (r - 1.4) / 1.4, 0.0, 1.0)
	elif r < 0.65:
		q = clampf(1.0 - (0.65 - r) / 0.45, 0.15, 1.0)
	var w := 0.016 * clampf(pow(1.0 / maxf(r, 0.05), 0.4), 0.5, 1.7)
	var h := w * (0.42 if r >= 0.65 else 0.6)
	var wobble := 0.0
	var colour := Color(0.84, 0.86, 0.88)
	if r > 1.4:
		# Too fast: thin and broken, the arc skipping (gaps), cold and sooty.
		wobble = randf_range(-1.0, 1.0) * 0.003 * (r - 1.0)
		colour = Color(0.84, 0.86, 0.88).lerp(Color(0.25, 0.23, 0.21), 1.0 - q)
		if randf() > 0.25 + q * 0.75:
			p.ripples = int(p.ripples) + 1   # a gap: counted, nothing laid
			p.q_sum = float(p.q_sum) + q * 0.5
			return
	elif r < 0.65:
		# Too slow: fat, lumpy, overheated (burnt blue and brown).
		wobble = randf_range(-1.0, 1.0) * 0.002
		h *= randf_range(0.9, 1.3)
		colour = Color(0.84, 0.86, 0.88).lerp(Color(0.32, 0.3, 0.45) if randf() < 0.5 else Color(0.45, 0.33, 0.22), 1.0 - q)
	var mm := mmi.multimesh
	var i := mm.visible_instance_count
	if i >= mm.instance_count:
		return
	# Each ripple leans back towards where the bead came from: the stacked rings of a neat weld.
	var lean := Basis(Vector3.RIGHT, -0.55 * float(p.dir))
	var basis := lean * Basis.from_scale(Vector3(w, RIPPLE_STEP * 2.8, h))
	mm.set_instance_transform(i, Transform3D(basis, Vector3(wobble, y, 0.0015 + h * 0.22)))
	mm.set_instance_color(i, colour)
	mm.visible_instance_count = i + 1
	var hm := (mmi.get_node("Halo") as MultiMeshInstance3D).multimesh
	if hm.visible_instance_count < hm.instance_count:
		var tint := Color(0.8, 0.79, 0.75) if r <= 1.4 else Color(0.62, 0.6, 0.58)
		if r < 0.65:
			tint = Color(0.6, 0.48, 0.42)
		var hw := w * 2.0
		hm.set_instance_transform(hm.visible_instance_count, Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(hw, 0.0006, RIPPLE_STEP * 3.0)), Vector3(0.0, y, 0.0004)))
		hm.set_instance_color(hm.visible_instance_count, tint)
		hm.visible_instance_count += 1
	p.ripples = int(p.ripples) + 1
	p.q_sum = float(p.q_sum) + q
	var puddle := marks.get_node_or_null("Puddle") as MeshInstance3D
	if puddle:
		puddle.visible = true
		puddle.scale = Vector3.ONE
		puddle.position = Vector3(wobble, y, 0.0015 + h * 0.25)


## A plan done: its joint made (hot) and its marks taken away (a weld's bead stays on the work
## till its joint is cut). The joint, or null.
func _finish(p: Dictionary, keep_bead: bool) -> ConnectionData:
	planned.erase(p)
	var marks: Node3D = _plan_marks.get(int(p.id))
	_plan_marks.erase(int(p.id))
	var c := model.connect_parts(model.parts[int(p.a)], model.parts[int(p.b)], int(p.kind), p.at, p.normal, p.seam_up, p.seam_size)
	model.heat(c, 1.0)
	if is_instance_valid(marks):
		if keep_bead and marks.get_node_or_null("Ripples"):
			for child in marks.get_children():
				if child.name != "Ripples":
					child.queue_free()
			marks.name = "WeldBead_%d" % int(p.id)
			_kept_beads[marks] = c
			# The bead you laid is the weld's look: the joint's own drawn seam goes.
			var view := model.forget_view(c)
			if view:
				view.clear()
		else:
			marks.queue_free()
	fastened.emit(c)
	return c


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
		# The weld puddle: a white-hot drop at the arc, where the bead is being laid.
		var puddle := MeshInstance3D.new()
		puddle.name = "Puddle"
		var pm := SphereMesh.new()
		pm.radius = 0.009
		pm.height = 0.008
		puddle.mesh = pm
		var hot := _hot.duplicate() as StandardMaterial3D
		hot.albedo_color = Color(1.0, 0.85, 0.6)
		hot.emission = Color(1.0, 0.75, 0.4)
		hot.emission_energy_multiplier = 6.0
		puddle.material_override = hot
		puddle.visible = false
		puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.add_child(puddle)
		# The welder's guides (0.4.1 playtest: "make it so our plasma tip is somehow visible for
		# tracing the weld line"): the seam still to weld lit up, a ring round where the torch
		# is aimed, and a pace mark running ahead at a steady hand's speed.
		var guide := MeshInstance3D.new()
		guide.name = "Guide"
		var gm := BoxMesh.new()
		gm.size = Vector3(0.0035, 1.0, 0.0008)
		guide.mesh = gm
		guide.material_override = _glow(Color(0.45, 0.95, 1.0), 2.5, false)
		guide.scale = Vector3(1, length, 1)
		guide.position = Vector3(0, 0, 0.0022)
		guide.transparency = 0.6
		guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.add_child(guide)
		var tip := MeshInstance3D.new()
		tip.name = "Tip"
		var tm := TorusMesh.new()
		tm.inner_radius = 0.011
		tm.outer_radius = 0.0145
		tm.rings = 24
		tm.ring_segments = 4
		tip.mesh = tm
		tip.material_override = _glow(Color(0.5, 1.0, 1.0), 4.0, true)
		tip.rotation = Vector3(PI * 0.5, 0, 0)
		tip.scale = Vector3(1, 0.1, 1)
		tip.visible = false
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dot := MeshInstance3D.new()
		var dm2 := SphereMesh.new()
		dm2.radius = 0.0028
		dm2.height = 0.0056
		dot.mesh = dm2
		dot.material_override = tip.material_override
		dot.scale = Vector3(1, 10, 1)
		tip.add_child(dot)
		marks.add_child(tip)
		var pace := MeshInstance3D.new()
		pace.name = "Pace"
		var pm2 := PrismMesh.new()
		pm2.size = Vector3(0.022, 0.012, 0.001)
		pace.mesh = pm2
		pace.material_override = _glow(Color(0.4, 1.0, 0.45), 4.0, true)
		pace.visible = false
		pace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.add_child(pace)
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


static func _glow(c: Color, energy: float, on_top: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.no_depth_test = on_top   # seen through the gun's own nozzle
	if on_top:
		m.render_priority = 1
	return m


## The welder aimed at `world_point` near weld `p` (every frame it is, trigger or not): the
## ring where it points (off the line or on it), the seam still to weld lit brighter, and the
## pace mark `lead` seconds ahead of the bead at the steady `ideal` speed (m/s), coloured by
## how the run is going ("STEADY", "TOO FAST", "TOO SLOW", "" not started).
func show_aim(p: Dictionary, world_point: Vector3, ideal: float, pace := "", lead := 0.6) -> void:
	var marks: Node3D = _plan_marks.get(int(p.id))
	if not is_instance_valid(marks) or not marks.has_node("Tip"):
		return
	marks.set_meta("aimed_ms", Time.get_ticks_msec())
	var length := (p.seam_size as Vector2).x
	var local := marks.to_local(world_point)
	var tip := marks.get_node("Tip") as Node3D
	tip.visible = true
	tip.position = Vector3(local.x, clampf(local.y, -length * 0.5 - 0.03, length * 0.5 + 0.03), 0.0025)
	var guide := marks.get_node("Guide") as MeshInstance3D
	guide.transparency = 0.0
	var pace_mark := marks.get_node("Pace") as MeshInstance3D
	if p.has("front"):
		# Lit from the bead's front to the far end of the seam.
		var front := float(p.front) - length * 0.5
		var end := length * 0.5 * float(p.dir)
		guide.scale.y = maxf(absf(end - front), 0.0005)
		guide.position.y = (front + end) * 0.5
		var ahead := clampf(front + float(p.dir) * ideal * lead, -length * 0.5, length * 0.5)
		pace_mark.visible = absf(end - front) > 0.004
		pace_mark.position = Vector3(0, ahead, 0.0025)
		pace_mark.rotation.z = 0.0 if float(p.dir) > 0.0 else PI
	else:
		guide.scale.y = length
		guide.position.y = 0.0
		# Not started: the mark shows which end it starts from (the nearer one) and the way.
		var low := local.y < 0.0
		pace_mark.visible = true
		pace_mark.position = Vector3(0, (-length * 0.5 + 0.012) if low else (length * 0.5 - 0.012), 0.0025)
		pace_mark.rotation.z = 0.0 if low else PI
	var colour := Color(0.4, 1.0, 0.45)
	match pace:
		"TOO FAST": colour = Color(1.0, 0.3, 0.2)
		"TOO SLOW": colour = Color(0.35, 0.55, 1.0)
		"OFF THE LINE": colour = Color(1.0, 0.75, 0.2)
	(pace_mark.material_override as StandardMaterial3D).albedo_color = colour
	(pace_mark.material_override as StandardMaterial3D).emission = colour
	var ring := tip.material_override as StandardMaterial3D
	var on_line := absf(local.x) < 0.02
	ring.albedo_color = Color(0.5, 1.0, 1.0) if on_line else Color(1.0, 0.75, 0.2)
	ring.emission = ring.albedo_color


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
