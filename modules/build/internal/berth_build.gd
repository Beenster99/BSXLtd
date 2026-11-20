extends Node3D
## The build in the berth (master plan 5.2 and 5.3), under the yard's build berth root:
##   - the ghost: the whole blueprint drawn as a faint holo; the next job's pieces glow amber and
##     pulse, and F at them (within reach) floats them in;
##   - the ship: a workpiece the hand tools work (YardBus.new_workpiece). A job floating in puts
##     its parts on it (its own joints made: it comes ready assembled) and chalks its hand
##     fastenings where they go: the welder runs the welds, the riveter sets the rivets, the
##     socket runs the bolts home. Once they are in, the jigs tack the rest of the job's fixing
##     joints at the quality the hand ones were made to, and the next pieces glow.
## Data lives on the bus (BuildBus.builds); this draws it and turns the tools' work into
## requests. Ship space is the blueprint's, centred on the berth.

const GHOST_SHADER := preload("res://modules/build/internal/ghost.gdshader")
## How long the pieces take to float in (s), and how far out they come from (m, from the
## station side of the berth).
const FLOAT_SECONDS := 2.4
const FLOAT_FROM := 9.0
## The F area's layer (bit 21: nothing else uses it; only rays that look for areas meet it).
const USE_LAYER := 1 << 20
## Show the job card while the camera is this close to the ship's box (m).
const CARD_RANGE := 45.0
const CARD := "build.job"

var bus: Object
var contract := ""
var bp: Object
var plan: BuildPlan
## The ship's node (ship space), the ghost body under it, and the workpiece being built.
var ship: Node3D
var ghost: RigidBody3D
var work: RigidBody3D
## Blueprint part id -> the real part.
var real: Dictionary = {}
## "<job>:<k>" -> the plan on the workpiece (until it is in).
var plans: Dictionary = {}
var use_area: Area3D
var _ghost_mat: ShaderMaterial
var _next_mat: ShaderMaterial
var _glowing: Array = []
var _floating: Array[Dictionary] = []   # {node, from, to: Transform3D, t, delay, parts}
var _claim_wait := 0.0
## Hand fastenings of a landed job waiting to be chalked: "<job>:<k>" -> blueprint joint index.
var _to_plan: Dictionary = {}
var _plan_wait := 0
## How far from a joint's own spot its chalk mark may be (m).
const SPOT_REACH := 0.45


func setup(build_bus: Object, contract_id: String) -> void:
	bus = build_bus
	contract = contract_id
	bp = bus.call("blueprint", contract)
	plan = bus.call("plan", contract)
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = GHOST_SHADER
	_next_mat = ShaderMaterial.new()
	_next_mat.shader = GHOST_SHADER
	_next_mat.set_shader_parameter("next", 1.0)
	ship = Node3D.new()
	ship.name = "Ship"
	add_child(ship)
	if bp == null or plan == null:
		return
	var box: AABB = bp.get("bounds")
	ship.position = -box.get_center()
	ghost = bp.get("body")
	if ghost.get_parent():
		ghost.get_parent().remove_child(ghost)
	ship.add_child(ghost)
	var model: PartModel = bp.get("model")
	model.joints().visible = false
	for id: int in model.parts:
		_dress(id, _ghost_mat)
		model.part_visual(id).visible = true
	var yard := Modules.bus("yard")
	work = yard.call("new_workpiece") if yard and yard.has_method("new_workpiece") else null
	if work == null:
		return
	work.name = "Build"
	work.set_meta("build_contract", contract)
	# Replay what is done already, all at once, before the work goes into the physics space.
	var b: Dictionary = bus.call("active") if str(bus.get("current")) == contract else {}
	for j: int in b.get("landed", []):
		land(j, false)
	for key: String in b.get("done", {}):
		fastened(int(key.get_slice(":", 0)), int(key.get_slice(":", 1)), float(b.done[key]))
	for j: int in b.get("landed", []):
		if bool(bus.call("job_finished", j, contract)):
			finish(j)
	ship.add_child(work)
	_glow_next()


func _exit_tree() -> void:
	# The blueprint outlives this node (the bus keeps it): give its body back untouched.
	if ghost and is_instance_valid(ghost) and ghost.get_parent() == ship:
		ship.remove_child(ghost)
	HudSlots.clear_info(CARD)


## The ghost part `id` drawn in `mat`, its fitting's look too.
func _dress(id: int, mat: Material) -> void:
	var model: PartModel = bp.get("model")
	var v := model.part_visual(id)
	if v == null:
		return
	v.material_override = mat
	for g in v.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_override = mat
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- A job floats in ----------------------------------------------------------------------------

## Job `j` comes in: its parts onto the workpiece, its own joints made, its hand fastenings
## chalked. `animate`: the pieces float in from the station side (else they are simply there).
func land(j: int, animate: bool) -> void:
	if work == null or j < 0 or j >= plan.jobs.size():
		return
	var job: Dictionary = plan.jobs[j]
	var model: PartModel = bp.get("model")
	var in_tree := work.is_inside_tree()
	var parent := work.get_parent()
	# Many shapes at once: off the physics space while they go on, then back.
	if in_tree:
		parent.remove_child(work)
	var made: Array[PartData] = []
	for id: int in job.parts:
		if real.has(id):
			continue
		var p := _copy_part(id)
		real[id] = p
		made.append(p)
		var gv := model.part_visual(id)
		if gv:
			gv.visible = false
	if int(work.get("anchor_part")) < 0 and not made.is_empty():
		work.set("anchor_part", made[0].id)
	var wm: PartModel = work.get("model")
	for i: int in job.inner:
		_join(i, 1.0)
	if in_tree:
		parent.add_child(work)
	for k in (job.key as Array).size():
		var key := "%d:%d" % [j, k]
		if not plans.has(key):
			_to_plan[key] = int(job.key[k])
	_plan_wait = 2
	if animate:
		_float_in(made)
	_glow_next()
	wm.recompute_mass()


## Chalks the hand fastenings waiting to be planned (a moment after their job lands, once its
## parts are in the physics space): each where the tool will meet it, found by looking at the
## joint's spot from in front of it (a frame joint's own spot can sit in the gap between two
## members), facing the way the face there does. One already made (a crewmate's, a saved one)
## is simply joined.
func _plan_waiting() -> void:
	var model: PartModel = bp.get("model")
	var done: Dictionary = (bus.call("active") as Dictionary).get("done", {}) if str(bus.get("current")) == contract else {}
	for key: String in _to_plan.keys():
		var i := int(_to_plan[key])
		_to_plan.erase(key)
		var c: ConnectionData = model.connections[i]
		if done.has(key):
			_join(i, float(done[key]))
			continue
		if not real.has(c.part_a) or not real.has(c.part_b):
			continue
		var kind := BuildPlan.hand_kind(c.kind)
		var spot := spot_for(c)
		var at: Vector3 = spot[0]
		var n: Vector3 = spot[1]
		var weld := kind == ConnectionData.Kind.WELD
		var line := _weld_line(at, n, c) if weld else []
		plans[key] = work.call("plan", kind, real[c.part_a], real[c.part_b], at, n,
				line[0] if weld else Vector3.ZERO, line[1] if weld else Vector2.ZERO)


## [seam_up, seam_size] (body space) for a hand weld at `at` facing `n`: a stretch of joint `c`'s
## seam (the jigs finish the rest) lying on the face, as long as it can be with both its ends on
## the ship, so the torch follows it end to end.
func _weld_line(at: Vector3, n: Vector3, c: ConnectionData) -> Array:
	var along := c.seam_up - n * c.seam_up.dot(n)
	var ups: Array[Vector3] = []
	if along.length() > 0.3:
		ups.append(along.normalized())
		ups.append(n.cross(along).normalized())
	ups.append(n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized())
	var most := clampf(c.seam_size.x if c.seam_size.x > 0.05 else 0.2, 0.08, 0.4)
	var thick := c.seam_size.y if c.seam_size.y > 0.004 else 0.012
	for f: float in [1.0, 0.6, 0.35]:
		for up in ups:
			var half := up * most * f * 0.5
			if _meets(at + half, n) and _meets(at - half, n):
				return [up, Vector2(most * f, thick)]
	return [ups.back(), Vector2(0.06, thick)]


## True when a look along -`n` at `p` (body space) meets the ship right there.
func _meets(p: Vector3, n: Vector3) -> bool:
	var gx := work.global_transform
	var at := gx * p
	var d := (gx.basis * n).normalized()
	var q := PhysicsRayQueryParameters3D.create(at + d * 0.9, at - d * 0.1)
	q.collision_mask = work.collision_layer
	var skip: Array[RID] = []
	for tries in 4:
		q.exclude = skip
		var hit := work.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return false
		if hit.collider != work:
			skip.append((hit.collider as CollisionObject3D).get_rid())
			continue
		return (hit.position as Vector3).distance_to(at) < 0.04
	return false


## [spot, normal] (body space) to chalk joint `c` at: where a look at its spot from in front
## (along its normal, else from the sides) meets the ship within SPOT_REACH of it.
func spot_for(c: ConnectionData) -> Array:
	var gx := work.global_transform
	var at := gx * c.local_position
	var n := (gx.basis * c.local_normal).normalized()
	var dirs: Array[Vector3] = [n]
	for d: Vector3 in [gx.basis.x, -gx.basis.x, gx.basis.y, -gx.basis.y, gx.basis.z, -gx.basis.z]:
		dirs.append(d.normalized())
	dirs.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.dot(n) > b.dot(n))
	var space := work.get_world_3d().direct_space_state
	# A face you can stand square to first (one overhead or underfoot only when nothing else is near).
	for steep in [false, true]:
		var found := _spot_along(dirs, at, steep, space, gx)
		if not found.is_empty():
			return found
	return [c.local_position, c.local_normal.normalized()]


func _spot_along(dirs: Array[Vector3], at: Vector3, steep: bool, space: PhysicsDirectSpaceState3D, gx: Transform3D) -> Array:
	for d in dirs:
		if not steep and absf(d.y) > 0.7:
			continue
		var q := PhysicsRayQueryParameters3D.create(at + d * 0.9, at - d * 0.25)
		q.collision_mask = work.collision_layer
		var skip: Array[RID] = []
		for tries in 4:
			q.exclude = skip
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			if hit.collider != work:
				skip.append((hit.collider as CollisionObject3D).get_rid())
				continue
			var hn := hit.normal as Vector3
			if (hit.position as Vector3).distance_to(at) <= SPOT_REACH and (steep or absf(hn.y) <= 0.7):
				var inv := gx.affine_inverse()
				return [inv * (hit.position as Vector3), (inv.basis * hn).normalized()]
			break
	return []


func _physics_process(_delta: float) -> void:
	if _to_plan.is_empty() or work == null or not work.is_inside_tree():
		return
	_plan_wait -= 1
	if _plan_wait <= 0:
		_plan_waiting()
		bus.emit_signal("build_changed")


func _copy_part(id: int) -> PartData:
	var model: PartModel = bp.get("model")
	var wm: PartModel = work.get("model")
	var src: PartData = model.parts[id]
	var vis := model.part_visual(id) as MeshInstance3D
	var p := wm.add_part(src.part_name, src.kind, src.mass, src.value, src.local_transform, vis.mesh if vis else null,
			model.part_shape(id), (bp.get("orig") as Dictionary).get(id))
	p.path = src.path
	p.material = src.material
	p.centroid = src.centroid
	for extra: CollisionShape3D in model.extra_colliders(id):
		var shapes: Array[Shape3D] = [extra.shape]
		wm.add_extra_collision(p, shapes, extra.get_meta("part_offset", Transform3D.IDENTITY))
	var looks: Dictionary = bp.get("looks")
	if looks.has(id):
		var holder := Node3D.new()
		holder.name = "Look"
		wm.attach_to_part(p, holder)
		(looks[id] as Callable).call(holder)
	return p


## Makes blueprint joint `i` between the real parts, as strong as `quality` makes it.
func _join(i: int, quality: float) -> void:
	var model: PartModel = bp.get("model")
	var c: ConnectionData = model.connections[i]
	if not real.has(c.part_a) or not real.has(c.part_b):
		return
	var wm: PartModel = work.get("model")
	var n := wm.connect_parts(real[c.part_a], real[c.part_b], c.kind, c.local_position, c.local_normal, c.seam_up, c.seam_size)
	n.max_health = n.max_health * lerpf(0.35, 1.0, quality)
	n.health = n.max_health


func _float_in(parts: Array[PartData]) -> void:
	var wm: PartModel = work.get("model")
	var out := (Vector3.LEFT + Vector3(0, 0.25, 0)).normalized() * FLOAT_FROM
	var rng := RandomNumberGenerator.new()
	rng.seed = parts.size() * 7919 + (parts[0].id if not parts.is_empty() else 0)
	var i := 0
	for p in parts:
		var v := wm.part_visual(p.id)
		if v == null:
			continue
		v.visible = false
		var ghost_piece := v.duplicate() as Node3D
		ghost_piece.visible = true
		ship.add_child(ghost_piece)
		var to := p.local_transform
		var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.8, 0.8), rng.randf_range(-0.6, 0.6)))
		var from := Transform3D(tilt * to.basis, to.origin + out + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)))
		_floating.append({"node": ghost_piece, "visual": v, "from": from, "to": to, "t": 0.0,
				"delay": minf(1.0, i * 0.04)})
		i += 1


func _process(delta: float) -> void:
	for f: Dictionary in _floating.duplicate():
		f.t = float(f.t) + delta
		var u := clampf((float(f.t) - float(f.delay)) / FLOAT_SECONDS, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - u, 3.0)
		var a: Transform3D = f.from
		var b: Transform3D = f.to
		(f.node as Node3D).transform = Transform3D(Basis(a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), e)),
				a.origin.lerp(b.origin, e))
		if u >= 1.0:
			(f.node as Node3D).queue_free()
			if is_instance_valid(f.visual):
				(f.visual as Node3D).visible = true
			_floating.erase(f)
	_claim_wait -= delta
	if _claim_wait <= 0.0:
		_claim_wait = 2.0
		bus.call("claim_berth")
	_update_card()


## True while pieces are still on their way in.
func floating() -> bool:
	return not _floating.is_empty()


## Ends the floating at once (tests, screenshots).
func settle() -> void:
	for f in _floating:
		f.t = 1000.0
	_process(0.0)


# --- Fastenings -------------------------------------------------------------------------------

## Hand fastening `k` of job `j` is in at `q`: a crewmate's is worked in here; its joint is as
## strong as it was made.
func fastened(j: int, k: int, q: float) -> void:
	var key := "%d:%d" % [j, k]
	if work == null:
		return
	if _to_plan.has(key):
		# Made before it was chalked here: simply joined.
		_join(int(_to_plan[key]), q)
		_to_plan.erase(key)
		return
	var p: Dictionary = plans.get(key, {})
	if p.is_empty():
		return
	plans.erase(key)
	var wm: PartModel = work.get("model")
	if (work.get("planned") as Array).has(p):
		work.call("work_planned", p, 1.0)
	# The joint it made: the newest between its two parts at its spot.
	for i in range(wm.connections.size() - 1, -1, -1):
		var c := wm.connections[i]
		if c.part_a == int(p.a) and c.part_b == int(p.b) and c.local_position.is_equal_approx(p.at):
			c.max_health = ConnectionData.MAX_HEALTH.get(c.kind, c.max_health) * lerpf(0.35, 1.0, q)
			c.health = c.max_health
			break


## Job `j` is done: the jigs tack the rest of its fixing joints, at its quality.
func finish(j: int) -> void:
	if work == null:
		return
	var q := float(bus.call("job_quality", j, contract))
	for i: int in plan.jobs[j].tack:
		_join(i, q)
	_glow_next()


## [job, k] of the hand fastening `c` made on `body`, or [] when it is not one of the build's.
func key_for(body: RigidBody3D, c: ConnectionData) -> Array:
	if body != work or c == null:
		return []
	for key: String in plans:
		var p: Dictionary = plans[key]
		if int(p.a) == c.part_a and int(p.b) == c.part_b and (p.at as Vector3).is_equal_approx(c.local_position):
			return [int(key.get_slice(":", 0)), int(key.get_slice(":", 1))]
	return []


## The plans still to make for job `j`: [{key, kind, plan}].
func pending(j: int) -> Array:
	var out := []
	var model: PartModel = bp.get("model")
	for k in (plan.jobs[j].key as Array).size():
		var key := "%d:%d" % [j, k]
		if plans.has(key):
			out.append({"key": key, "kind": int(plans[key].kind), "plan": plans[key]})
		elif _to_plan.has(key):
			out.append({"key": key, "kind": BuildPlan.hand_kind(model.connections[int(_to_plan[key])].kind), "plan": {}})
	return out


# --- The next pieces glow --------------------------------------------------------------------

func _glow_next() -> void:
	for id: int in _glowing:
		if not real.has(id):
			_dress(id, _ghost_mat)
	_glowing.clear()
	if use_area:
		use_area.queue_free()
		use_area = null
	var j := int(bus.call("next_job", contract))
	if j < 0 or plan == null:
		return
	var model: PartModel = bp.get("model")
	use_area = Area3D.new()
	use_area.name = "FloatIn"
	use_area.collision_layer = USE_LAYER
	use_area.collision_mask = 0
	use_area.monitoring = false
	use_area.monitorable = true
	var name := str(plan.jobs[j].name)
	use_area.set_meta("yard_use", func() -> void: bus.call("land_next"))
	use_area.set_meta("yard_hint", "F  Float in: %s" % name)
	for id: int in plan.jobs[j].parts:
		_glowing.append(id)
		_dress(id, _next_mat)
		var col := model.part_collider(id)
		if col:
			var s := CollisionShape3D.new()
			s.shape = col.shape
			s.transform = col.transform
			use_area.add_child(s)
	ship.add_child(use_area)


# --- What to do next, on the info panel ---------------------------------------------------------

func _update_card() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var near := false
	if cam and bp:
		var box: AABB = (bp.get("bounds") as AABB).grow(CARD_RANGE)
		near = box.has_point(ship.global_transform.affine_inverse() * cam.global_position)
	if not near:
		HudSlots.clear_info(CARD)
		return
	var p: Dictionary = bus.call("progress", contract)
	if p.is_empty():
		HudSlots.clear_info(CARD)
		return
	HudSlots.set_info(CARD, "Building %s" % str(p.design_name), card_text(p))


## The card's text for progress `p` (BuildBus.progress).
func card_text(p: Dictionary) -> String:
	var lines: Array[String] = []
	if str(p.stage) == "":
		lines.append("Every job done: she is ready for her trial.")
	else:
		lines.append("%s: %s" % [str(BuildPlan.STAGES[str(p.stage)].name), str(p.job_name)])
		if bool(p.floating):
			var counts := {}
			for e: Dictionary in pending(int(p.job)):
				counts[int(e.kind)] = int(counts.get(int(e.kind), 0)) + 1
			for kind: int in counts:
				var n := int(counts[kind])
				match kind:
					ConnectionData.Kind.WELD:
						lines.append("Weld %d chalked seam%s (welder, 8)" % [n, "" if n == 1 else "s"])
					ConnectionData.Kind.BOLT:
						lines.append("Run %d bolt%s home (socket, 3)" % [n, "" if n == 1 else "s"])
					_:
						lines.append("Set %d rivet%s (riveter, 7)" % [n, "" if n == 1 else "s"])
		else:
			lines.append("Fly to the glowing pieces and press F to float them in.")
	lines.append("Jobs %d of %d  ·  workmanship %s" % [int(p.jobs_done), int(p.jobs),
			str(p.grade) if str(p.grade) != "" else "-"])
	return "\n".join(lines)
