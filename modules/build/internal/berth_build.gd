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
const MARK_SHADER := preload("res://modules/build/internal/seam_mark.gdshader")
const THROUGH_SHADER := preload("res://modules/build/internal/seam_mark_through.gdshader")
const BEACONS := preload("res://modules/build/internal/weld_beacons.gd")
## Longest hand weld (m): short enough that aiming anywhere on the chalk starts the arc (the
## welder starts from the nearer end, within 7 cm of the aim).
const MAX_WELD := 0.13
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
## Joints made at landing that are not drawn yet, by job: they show when the job is done.
var _unwelded: Dictionary = {}
## The ghost's parts still to come, as [work-space box, to the part's own space, its own box]:
## a seam they will stand over is not chalked (beenster, 0.4.7: "another weld inside the beam").
var _blockers: Array = []
var _blockers_for := ""
## The stage being chalked: only its own parts still to come count as in the way (the frame is
## welded before the skin goes over it).
var _stage := ""
## The bright outline round each fastening still to make: plan key -> node on the work.
var _marks: Dictionary = {}
var _mark_mat: ShaderMaterial
## The screen markers and edge arrow to the fastenings still to make (flag build.weld_beacons).
var beacons: CanvasLayer
## The holo of the stages after the one in hand, drawn fainter so it doesn't wash over the work
## (beenster, 0.4.7: the welds got lost in the blue).
var _faint_mat: ShaderMaterial
var _faint_from := -1
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
	_faint_mat = ShaderMaterial.new()
	_faint_mat.shader = GHOST_SHADER
	_faint_mat.set_shader_parameter("strength", 0.012)
	_faint_mat.set_shader_parameter("rim", 0.05)
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
	if Flags.is_on(BEACONS.FLAG):
		beacons = BEACONS.new().setup(self)
		add_child(beacons)
	_glow_next()


func _exit_tree() -> void:
	# The blueprint outlives this node (the bus keeps it): give its body back untouched.
	if ghost and is_instance_valid(ghost) and ghost.get_parent() == ship:
		ship.remove_child(ghost)
	HudSlots.clear_info(CARD)


## The holo for ghost part `id`: faint when its stage comes after the one in hand.
func _holo_mat(id: int) -> Material:
	var st := BuildPlan.STAGE_ORDER.find(str(plan.jobs[int(plan.job_of.get(id, 0))].stage))
	return _faint_mat if _faint_from >= 0 and st > _faint_from else _ghost_mat


## Draws the stages after the one in hand faint, once each time the stage changes.
func _fade_later() -> void:
	var p: Dictionary = bus.call("progress", contract)
	var now := BuildPlan.STAGE_ORDER.find(str(p.get("stage", ""))) if not p.is_empty() else -1
	if now == _faint_from:
		return
	_faint_from = now
	var model: PartModel = bp.get("model")
	for id: int in model.parts:
		if not real.has(id) and not _glowing.has(id):
			_dress(id, _holo_mat(id))


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
	# Its own joints hold it together but are not drawn yet: a landed piece sits in place
	# unjoined, no beads (beenster, 20 Nov), and they show when the job is done.
	var hidden: Array = _unwelded.get_or_add(j, [])
	for i: int in job.inner:
		var c := _join(i, 1.0)
		if c:
			var v := wm.forget_view(c)
			if v:
				v.clear()
			hidden.append(c)
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
		_stage = str(plan.jobs[int(key.get_slice(":", 0))].stage)
		var kind := BuildPlan.hand_kind(c.kind)
		var weld := kind == ConnectionData.Kind.WELD
		var spot := spot_for(c)
		var line := []
		if weld:
			# The first place round the joint where a whole line lies in the open; else one met
			# from in front all along; else a short one at the best spot.
			# In the open before merely with room in front, before merely seen square on; at each,
			# faces you can stand square to before ones overhead or underfoot.
			var cands := spot_candidates(c)
			for strict: int in [2, 1, 0]:
				for steep: bool in [false, true]:
					for cand: Array in cands:
						if (absf((work.global_basis * (cand[1] as Vector3)).y) > 0.7) != steep:
							continue
						line = _weld_line(cand[0], cand[1], c, strict)
						if not line.is_empty():
							spot = cand
							break
					if not line.is_empty():
						break
				if not line.is_empty():
					break
			if line.is_empty():
				var n0: Vector3 = spot[1]
				line = [n0.cross(Vector3.UP if absf(n0.y) < 0.9 else Vector3.RIGHT).normalized(), Vector2(0.06, 0.012)]
		var at: Vector3 = spot[0]
		var n: Vector3 = spot[1]
		plans[key] = work.call("plan", kind, real[c.part_a], real[c.part_b], at, n,
				line[0] if weld else Vector3.ZERO, line[1] if weld else Vector2.ZERO)
	_sync_marks()


## A bright pulsing outline round every fastening still to make (beenster, 0.4.7: "the welds
## don't really highlight"): a frame round a weld's seam, a ring round a rivet or bolt, drawn
## over the holo so the blue never washes it out. The chalk, guide and bead show inside it.
func _sync_marks() -> void:
	for key: String in _marks.keys():
		if not plans.has(key) or not is_instance_valid(_marks[key]):
			if is_instance_valid(_marks[key]):
				(_marks[key] as Node).queue_free()
			_marks.erase(key)
	if work == null:
		return
	if _mark_mat == null:
		_mark_mat = ShaderMaterial.new()
		_mark_mat.shader = MARK_SHADER
		_mark_mat.render_priority = 10
		if Flags.is_on(BEACONS.FLAG):
			# A fainter copy drawn through whatever stands in front, so a weld behind a beam
			# still shows where it is (beenster, 0.5.3: "the welds are VERY hard to find").
			var through := ShaderMaterial.new()
			through.shader = THROUGH_SHADER
			through.render_priority = 9
			_mark_mat.next_pass = through
	var big := 1.6 if Flags.is_on(BEACONS.FLAG) else 1.0
	for key: String in plans:
		if _marks.has(key):
			continue
		var p: Dictionary = plans[key]
		var n: Vector3 = p.normal
		var up: Vector3 = p.seam_up
		if up.is_zero_approx():
			up = Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var side := up.cross(n).normalized()
		up = n.cross(side).normalized()
		var mark := Node3D.new()
		mark.name = "Mark_%s" % key.replace(":", "_")
		mark.transform = Transform3D(Basis(side, up, n), (p.at as Vector3) + n * 0.003)
		var length := (p.seam_size as Vector2).x
		if length > 0.0:
			var w := 0.09 * big
			var h := length + 0.06 * big
			var bar := 0.014 * big
			for bx: Array in [[Vector3(0, h * 0.5, 0), Vector3(w, bar, 0.002)], [Vector3(0, -h * 0.5, 0), Vector3(w, bar, 0.002)],
					[Vector3(w * 0.5, 0, 0), Vector3(bar, h, 0.002)], [Vector3(-w * 0.5, 0, 0), Vector3(bar, h, 0.002)]]:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = bx[1]
				mi.mesh = bm
				mi.position = bx[0]
				mi.material_override = _mark_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mark.add_child(mi)
		else:
			var mi := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.032 * big
			tm.outer_radius = 0.046 * big
			tm.rings = 24
			tm.ring_segments = 6
			mi.mesh = tm
			mi.rotation = Vector3(PI * 0.5, 0, 0)
			mi.scale = Vector3(1, 0.25, 1)
			mi.material_override = _mark_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mark.add_child(mi)
		if big > 1.0:
			# A warm light on the spot, so the face round a weld glows from across the berth.
			var lamp := OmniLight3D.new()
			lamp.name = "Glow"
			lamp.light_color = Color(1.0, 0.55, 0.15) if length > 0.0 else Color(0.5, 0.9, 1.0)
			lamp.light_energy = 1.6
			lamp.omni_range = 1.4
			lamp.shadow_enabled = false
			lamp.position = Vector3(0, 0, 0.18)
			mark.add_child(lamp)
		work.add_child(mark)
		_marks[key] = mark


## How many fastenings are outlined now (tests).
func marks_shown() -> int:
	return _marks.values().filter(func(m: Variant) -> bool: return is_instance_valid(m)).size()


## [seam_up, seam_size] (body space) for a hand weld at `at` facing `n`: a stretch of joint `c`'s
## seam (the jigs finish the rest) lying on the face in the open, as long as it can be: every
## point along it seen from in front, and its ends and middle open to the sides as well, so no
## member stands over it and the torch follows it end to end (beenster, 20 Nov: "a weld line is
## behind a beam").
func _weld_line(at: Vector3, n: Vector3, c: ConnectionData, strict := 2) -> Array:
	var along := c.seam_up - n * c.seam_up.dot(n)
	var ups: Array[Vector3] = []
	if along.length() > 0.3:
		ups.append(along.normalized())
		ups.append(n.cross(along).normalized())
	ups.append(n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized())
	ups.append(n.cross(ups.back()).normalized())
	var most := clampf(c.seam_size.x if c.seam_size.x > 0.05 else 0.2, 0.08, MAX_WELD)
	var thick := c.seam_size.y if c.seam_size.y > 0.004 else 0.012
	for f: float in [1.0, 0.6, 0.35, 0.2]:
		for up in ups:
			if _line_open(at, n, up, most * f, strict):
				return [up, Vector2(most * f, thick)]
	return []


## True when the weld line of plan `p` (YardWorkpiece.plan) lies where you can see it: every
## point along it seen square on from 1.5 m with nothing of hers in front.
func line_clear(p: Dictionary) -> bool:
	return _line_open(p.at, p.normal, p.seam_up, (p.seam_size as Vector2).x, 0)


## True when a weld line `length` long through `at` along `up` on the face facing `n` (body
## space) can be got at: each of seven points along it met from in front (`strict` 0); room to
## stand off its ends and middle too (1); those open to the sides as well (2).
func _line_open(at: Vector3, n: Vector3, up: Vector3, length: float, strict := 2) -> bool:
	for i in 7:
		var p := at + up * length * (float(i) / 6.0 - 0.5)
		if not _meets(p, n):
			return false
		if strict >= 1 and i % 3 == 0 and not _room(p, n):
			return false
		if strict >= 2 and i % 3 == 0 and not open_spot(p, n, up):
			return false
	return true


## True when spot `p` facing `n` (body space) is open: room to stand in front, met from there, and from at least two
## of the four sides 35 degrees off it (across `up` and along it), so it does not sit in under a
## member or down a slot where neither eye nor tool gets at it.
func open_spot(p: Vector3, n: Vector3, up: Vector3 = Vector3.ZERO) -> bool:
	if not _meets(p, n) or not _room(p, n):
		return false
	if up.is_zero_approx():
		up = n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var side := n.cross(up).normalized()
	var open := 0
	for d: Vector3 in [up, -up, side, -side]:
		if _meets(p, (n + d * 0.7).normalized()):
			open += 1
	return open >= 2


## True when there is room for a welder in front of `p` (body space) on a face facing `n`: a
## ball as wide as a suited head and shoulders, 0.9 m out, touches nothing of hers.
func _room(p: Vector3, n: Vector3) -> bool:
	var gx := work.global_transform
	var ball := SphereShape3D.new()
	ball.radius = 0.3
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.transform = Transform3D(Basis(), gx * (p + n.normalized() * 0.9))
	q.collision_mask = work.collision_layer
	for hit: Dictionary in work.get_world_3d().direct_space_state.intersect_shape(q, 8):
		if hit.collider == work:
			return false
	return true


## True when a look along -`d` at `p` (body space) from 1.5 m off meets the ship right there:
## nothing of hers in front of it.
func _meets(p: Vector3, d0: Vector3) -> bool:
	var gx := work.global_transform
	var at := gx * p
	var d := (gx.basis * d0).normalized()
	var q := PhysicsRayQueryParameters3D.create(at + d * 1.5, at - d * 0.1)
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
		return (hit.position as Vector3).distance_to(at) < 0.04 and not _ghost_over(p, d0)
	return false


## True when one of the ghost's parts still to come stands in front of `p` (body space) looking
## along -`d`: the seam would end up inside or behind it.
func _ghost_over(p: Vector3, d: Vector3) -> bool:
	_find_blockers()
	var a := p + d.normalized() * 0.004
	var b := p + d.normalized() * 1.5
	for bl: Array in _blockers:
		if not (bl[0] as AABB).intersects_segment(a, b):
			continue
		var inv: Transform3D = bl[1]
		if (bl[2] as AABB).intersects_segment(inv * a, inv * b):
			return true
	return false


func _find_blockers() -> void:
	var tag := "%d %s" % [real.size(), _stage]
	if _blockers_for == tag:
		return
	_blockers_for = tag
	_blockers.clear()
	var model: PartModel = bp.get("model")
	var to_work := work.global_transform.affine_inverse() if work.is_inside_tree() else Transform3D.IDENTITY
	for id: int in model.parts:
		if real.has(id) or str(plan.jobs[int(plan.job_of.get(id, 0))].stage) != _stage:
			continue
		var cols: Array = [model.part_collider(id)]
		cols.append_array(model.extra_colliders(id))
		for col: CollisionShape3D in cols:
			if col == null or col.shape == null or not col.is_inside_tree():
				continue
			var box := col.shape.get_debug_mesh().get_aabb().grow(-0.005)
			if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
				continue
			var xf := to_work * col.global_transform
			_blockers.append([xf * box, xf.affine_inverse(), box])


## [spot, normal] (body space) to chalk joint `c` at: where a look at its spot from in front
## (along its normal, else from the sides) meets the ship within SPOT_REACH of it, in the open
## (`open_spot`) where there is such a place.
func spot_for(c: ConnectionData) -> Array:
	return spot_candidates(c)[0]


## Every [spot, normal] (body space) round joint `c` where a look from one side meets the ship
## within SPOT_REACH of it, best first: open spots on faces you can stand square to, then open
## ones overhead or underfoot, then the rest; the joint's own spot last.
func spot_candidates(c: ConnectionData) -> Array:
	var gx := work.global_transform
	var at := gx * c.local_position
	var n := (gx.basis * c.local_normal).normalized()
	var dirs: Array[Vector3] = [n]
	for d: Vector3 in [gx.basis.x, -gx.basis.x, gx.basis.y, -gx.basis.y, gx.basis.z, -gx.basis.z]:
		dirs.append(d.normalized())
	dirs.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.dot(n) > b.dot(n))
	var space := work.get_world_3d().direct_space_state
	var open: Array = []
	var rest: Array = []
	for steep in [false, true]:
		for found: Array in _spots_along(dirs, at, steep, space, gx):
			if open_spot(found[0], found[1]):
				open.append(found)
			else:
				rest.append(found)
	# A member butted onto a face (a stringer on a ring, the joints mitred): its seam runs round
	# the member's end on that face, so look at the face just beside it, square on.
	var inv := gx.affine_inverse()
	var su := (gx.basis * c.seam_up).normalized() if not c.seam_up.is_zero_approx() else Vector3.ZERO
	var across: Array[Vector3] = []
	if not su.is_zero_approx():
		var w := n.cross(su).normalized()
		across.append_array([w, -w, su, -su])
	for o: Vector3 in across:
		for r: float in [0.12, 0.18, 0.26]:
			var p := at + o * r
			var q := PhysicsRayQueryParameters3D.create(p + n * 0.9, p - n * 0.1)
			q.collision_mask = work.collision_layer
			var hit := space.intersect_ray(q)
			if hit.is_empty() or hit.collider != work or (hit.normal as Vector3).dot(n) < 0.9:
				continue
			var found := [inv * (hit.position as Vector3), (inv.basis * (hit.normal as Vector3)).normalized()]
			if open_spot(found[0], found[1]):
				open.append(found)
			else:
				rest.append(found)
			break
	open.append_array(rest)
	open.append([c.local_position, c.local_normal.normalized()])
	return open


func _spots_along(dirs: Array[Vector3], at: Vector3, steep: bool, space: PhysicsDirectSpaceState3D, gx: Transform3D) -> Array:
	var out: Array = []
	for d in dirs:
		if (not steep and absf(d.y) > 0.7) or (steep and absf(d.y) <= 0.7):
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
				out.append([inv * (hit.position as Vector3), (inv.basis * hn).normalized()])
			break
	return out


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
func _join(i: int, quality: float) -> ConnectionData:
	var model: PartModel = bp.get("model")
	var c: ConnectionData = model.connections[i]
	if not real.has(c.part_a) or not real.has(c.part_b):
		return null
	var wm: PartModel = work.get("model")
	var n := wm.connect_parts(real[c.part_a], real[c.part_b], c.kind, c.local_position, c.local_normal, c.seam_up, c.seam_size)
	n.max_health = n.max_health * lerpf(0.35, 1.0, quality)
	n.health = n.max_health
	return n


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
	_sync_marks()
	var wm: PartModel = work.get("model")
	if (work.get("planned") as Array).has(p):
		work.call("work_planned", p, 1.0)
	# The joint the hand made (the newest between its two parts at its chalk mark) gives way to
	# the design's own, as Void Salvage draws it (beenster, 20 Nov: welds, joins and plates the
	# way VS does them): a weld's bead right round the seam where the members meet, a rivet or
	# bolt where the design sets it. Its strength is the hand's.
	for i in range(wm.connections.size() - 1, -1, -1):
		var c := wm.connections[i]
		if c.part_a == int(p.a) and c.part_b == int(p.b) and c.local_position.is_equal_approx(p.at):
			wm.drop_connection(c)
			break
	_join(int((plan.jobs[j].key as Array)[k]), q)


## Job `j` is done: the jigs tack the rest of its fixing joints, at its quality.
func finish(j: int) -> void:
	if work == null:
		return
	var q := float(bus.call("job_quality", j, contract))
	var wm: PartModel = work.get("model")
	for c: ConnectionData in _unwelded.get(j, []):
		if wm.connections.has(c) and wm.parts.has(c.part_a):
			wm.remake_view(c, wm.parts[c.part_a])
	_unwelded.erase(j)
	for i: int in plan.jobs[j].tack:
		_join(i, q)
	_glow_next()


## True when joint `c` on the work is still undrawn (its job is not done yet).
func unwelded(c: ConnectionData) -> bool:
	for list: Array in _unwelded.values():
		if list.has(c):
			return true
	return false


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

## The glowing job again (a bot claimed the one that glowed, or let one go).
func refresh_glow() -> void:
	_glow_next()


func _glow_next() -> void:
	_fade_later()
	for id: int in _glowing:
		if not real.has(id):
			_dress(id, _holo_mat(id))
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
	var bots := str(p.get("crew", "")) == "bots"
	if str(p.stage) == "":
		lines.append("Every job done: she is ready for her trial.")
	elif bots and not bool(p.floating):
		lines.append("The bots are building her: %d job%s in hand." % [int(p.get("in_hand", 0)), "" if int(p.get("in_hand", 0)) == 1 else "s"])
		lines.append("Fly to the glowing pieces and press F to take a job yourself." if int(p.get("free", 0)) > 0
				else "Every free job has a bot on it: take one over at the bot board.")
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
						lines.append("%d weld%s remaining (welder, 8)" % [n, "" if n == 1 else "s"])
					ConnectionData.Kind.BOLT:
						lines.append("%d bolt%s remaining (socket, 3)" % [n, "" if n == 1 else "s"])
					_:
						lines.append("%d rivet%s remaining (riveter, 7)" % [n, "" if n == 1 else "s"])
		elif str(p.get("parts_wait", "")) != "":
			lines.append("Waiting for parts: " + str(p.parts_wait) + ".")
		else:
			lines.append("Fly to the glowing pieces and press F to float them in.")
	if not bots and str(p.stage) != "" and Flags.is_on(BuildBus.BOT_FLAG):
		lines.append("Or put the bots on her: BOTS BUILD HER on the build plan or the bot board.")
	if bots and str(p.get("parts_wait", "")) != "" and int(p.get("free", 0)) == 0:
		lines.append("Waiting for parts: " + str(p.parts_wait) + ".")
	lines.append("Jobs %d of %d  ·  workmanship %s" % [int(p.jobs_done), int(p.jobs),
			str(p.grade) if str(p.grade) != "" else "-"])
	return "\n".join(lines)
