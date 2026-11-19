extends Node3D
## The worker bots building in the build berth (0.4.1 playtest: "they also deliver to the
## worker bots who actually make the ship in the yard", then "the worker bots who fix the ship
## up should be more functional, android style ... Some carry the large components and put them
## in place, others weld and rivet etc. The movers bring supplies to them when they need them
## or bring quantities of stock and wait until they have depleted them").
##
## A crew of heavy android bots (YardWorkerLook) round a keel frame of Void Salvage's box beams
## and girders, a ring at a time. When a ring needs parts they ask the stores for a keel ring
## kit; mover bots bring it out and hover by the keel holding their loads till every part is
## used. F-3 fitters take a part off a mover, carry it in their grippers and hold it in place;
## W-3 welders tack it at both ends, sparks at the torch; R-3 riveters punch rivets along it,
## each with a kick and a flash. Presentation only: it stands in for Wave 5's real building.
##
## The bots are TartanCo's, and they wear: every job wears a bot a little, a worn bot slows
## down, and past a point it starts throwing errors and stops till it's seen to. Then the crew
## calls TartanCo (YardService), whose engineers come out by ship and put it right.

const WorkerLook := preload("res://modules/yard/internal/yard_worker_look.gd")
const Look := preload("res://modules/yard/internal/yard_stock_look.gd")
const Service := preload("res://modules/yard/internal/yard_service.gd")

## The keel's first ring, the way it grows (m), the rings' pitch and how many it has room for.
const KEEL_START := Vector3(-16.0, -3.0, -85.0)
const KEEL_STEP := 3.2
const RINGS := 11
## The ring's side (m): a BoxBeam's length.
const RING := 6.0
## The kit the crew asks for, enough for one ring.
const KIT := "keel_ring"
## The crew by trade, in order: fitters, welders, riveters.
const CREW := ["F", "F", "W", "W", "R", "R"]

## Seconds a fitter takes to ease a part into place, a weld per joint, a rivet (pressure, then
## the punch).
@export var fit_seconds := 2.4
@export var weld_seconds := 2.6
@export var rivet_seconds := 1.0
## The crew's flying speed (m/s), and how long they'll wait on the stores for a part before a
## spare turns up from the berth's own stock (s).
@export var fly_speed := 4.0
@export var spare_after := 120.0
## Rings standing when the yard opens.
@export var start_rings := 3
## Wear (0 new, 1 worn out) a job puts on a bot, on average; past `slow_from` it slows (down to
## `worn_pace` of its speed when worn out), past `faults_from` it may fault at the end of a job.
@export var wear_per_job := 0.045
@export var slow_from := 0.4
@export var worn_pace := 0.55
@export var faults_from := 0.6
## TartanCo is sent for when a bot faults or one is this worn; on a visit every bot worn past
## `service_from` gets seen to.
@export var call_at := 0.75
@export var service_from := 0.3
@export var auto_service := true

## The faults a worn bot throws.
const FAULTS: PackedStringArray = ["E-17 ACTUATOR", "E-42 SERVO HEAT", "E-08 SENSOR DRIFT", "E-31 FEED JAM", "E-23 JOINT LASH"]

var traffic: Node
## {node, role, index, task (Dictionary: {} when idle), vel, sparks, light}.
var workers: Array[Dictionary] = []
var rings: Array[Node3D] = []
## The ring going on now: {part, t (ring space), stage, piece, fitter, waited}. Stages: need,
## carry, held, welding, welded, riveting, done.
var members: Array[Dictionary] = []
var ring_node: Node3D
## Where the movers wait with their loads (just off the keel's front).
var supply: Node3D
var _order := -1
var _time := 0.0
var _rivet_mesh: CylinderMesh
var _rivet_mat: StandardMaterial3D
var service: Node3D
var _rng := RandomNumberGenerator.new()


func build(stores_traffic: Node) -> void:
	name = "YardWorkers"
	traffic = stores_traffic
	for i in start_rings:
		_whole_ring()
	supply = Node3D.new()
	supply.name = "Supply"
	add_child(supply)
	var counts := {}
	for i in CREW.size():
		var role: String = CREW[i]
		counts[role] = int(counts.get(role, 0)) + 1
		var bot := WorkerLook.make(role, "%02d" % counts[role])
		bot.name = "Worker%d" % (i + 1)
		add_child(bot)
		var w := {"node": bot, "role": role, "index": i, "task": {}, "vel": Vector3.ZERO, "wear": 0.05 * i,
				"fault": "", "servicing": false}
		if role == "W":
			w.sparks = make_sparks()
			add_child(w.sparks)
		if role != "F":
			var light := OmniLight3D.new()
			light.name = "WorkLight%d" % (i + 1)
			light.light_color = Color(0.6, 0.8, 1.0) if role == "W" else Color(1.0, 0.85, 0.6)
			light.omni_range = 6.0
			light.light_energy = 0.0
			add_child(light)
			w.light = light
		bot.position = _idle_spot(i)
		WorkerLook.rest(bot, "R")
		WorkerLook.rest(bot, "L")
		workers.append(w)
	_rng.seed = 4021
	service = Service.new()
	add_child(service)
	service.build(self)
	_start_ring()


## The fitter the movers' first loads come to (the crew's lead).
func foreman() -> Node3D:
	return workers[0].node if not workers.is_empty() else null


func rings_built() -> int:
	return rings.size()


## Sends for TartanCo's engineers now (false if they're already coming or here).
func call_service() -> bool:
	return bool(service.call("call_in"))


## A bot waiting to be seen to (faulted, or worn past `service_from`), idle, and not already
## someone's (`taken`: the jobs the engineers have now), or {}.
func needs_service(taken: Array) -> Dictionary:
	for w: Dictionary in workers:
		if (w.fault != "" or float(w.wear) >= service_from) and (w.task as Dictionary).is_empty() and not bool(w.servicing):
			if not taken.any(func(t: Dictionary) -> bool: return not t.is_empty() and t.node == w.node):
				return w
	return {}


## An engineer has put `w` right: as new, its error cleared.
func serviced(w: Dictionary) -> void:
	w.wear = 0.0
	w.fault = ""
	w.servicing = false
	(w.node.get_node("Fault") as Label3D).visible = false


## How fast a bot works for its wear (1 new).
func pace(w: Dictionary) -> float:
	var over := clampf((float(w.wear) - slow_from) / (1.0 - slow_from), 0.0, 1.0)
	return lerpf(1.0, worn_pace, over)


## A job done: wear on the bot, and a worn bot may fault.
func _job_done(w: Dictionary) -> void:
	w.task = {}
	w.wear = minf(1.0, float(w.wear) + wear_per_job * _rng.randf_range(0.6, 1.4))
	if float(w.wear) > faults_from and _rng.randf() < (float(w.wear) - faults_from) * 1.6:
		w.fault = FAULTS[_rng.randi() % FAULTS.size()]
		var label := w.node.get_node("Fault") as Label3D
		label.text = "%s\n%s" % ["ERROR", w.fault]


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_time += delta
	if ring_node == null and rings.size() < RINGS:
		_start_ring()
	_keep_supplied()
	_assign()
	for w: Dictionary in workers:
		_work(w, delta * pace(w))
	if auto_service and service.state == "away":
		for w: Dictionary in workers:
			if w.fault != "" or float(w.wear) >= call_at:
				call_service()
				break
	service.call("step", delta)
	if ring_node and not members.is_empty() and members.all(func(m: Dictionary) -> bool: return m.stage == "done"):
		rings.append(ring_node)
		ring_node = null
		members.clear()


# --- The ring -------------------------------------------------------------------------------

## The face the next ring goes on (station space).
func _front() -> Vector3:
	return KEEL_START + Vector3(KEEL_STEP * rings.size(), 0, 0)


## Its members (ring space): four box beams round a square, then girders back to the last ring.
func _member_list(with_girders: bool) -> Array[Dictionary]:
	var h := RING * 0.5
	var out: Array[Dictionary] = []
	# BoxBeam is built along x: turned for the uprights and the cross members.
	for t: Transform3D in [
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, 0)),
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, h, -h)),
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, h, h)),
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, RING, 0)),
	]:
		out.append({"part": "BoxBeam", "t": t})
	if with_girders:
		for c: Vector3 in [Vector3(0, 0, -h), Vector3(0, 0, h), Vector3(0, RING, -h), Vector3(0, RING, h)]:
			# Girder is built along x, 4 m: scaled to the pitch, from this ring back to the last.
			out.append({"part": "Girder", "t": Transform3D(Basis().scaled(Vector3(KEEL_STEP / 4.0, 1, 1)), c - Vector3(KEEL_STEP * 0.5, 0, 0))})
	return out


## A ring standing whole (the ones there when the yard opens).
func _whole_ring() -> void:
	var ring := Node3D.new()
	ring.name = "Ring%d" % rings.size()
	ring.position = _front()
	add_child(ring)
	for m: Dictionary in _member_list(rings.size() > 0):
		for l: Dictionary in Look.layers(m.part):
			var mi := MeshInstance3D.new()
			mi.mesh = l.mesh
			mi.material_override = l.material
			mi.transform = m.t
			ring.add_child(mi)
	rings.append(ring)


func _start_ring() -> void:
	ring_node = Node3D.new()
	ring_node.name = "Ring%d" % rings.size()
	ring_node.position = _front()
	add_child(ring_node)
	members.clear()
	for m: Dictionary in _member_list(rings.size() > 0):
		m.stage = "need"
		m.piece = null
		m.waited = 0.0
		members.append(m)
	# The movers wait beside the new ring, on the side away from the station.
	supply.position = _front() + Vector3(KEEL_STEP * 0.5, -0.5, RING * 0.5 + 4.5)


## The ring's axis at its front (station space): where "out" is measured from.
func _axis() -> Vector3:
	return _front() + Vector3(0, RING * 0.5, 0)


## Away from the keel's axis through `p`, square to it (a worker stands off the work this way).
func _out(p: Vector3) -> Vector3:
	var a := _axis()
	var v := Vector3(0, p.y - a.y, p.z - a.z)
	return v.normalized() if v.length() > 0.05 else Vector3.BACK


## A member's ends and its middle (station space), and how far its surface stands out along
## `out` from its centre line.
func _span(m: Dictionary) -> Dictionary:
	var box := AABB()
	var first := true
	for l: Dictionary in Look.layers(m.part):
		var b: AABB = (l.mesh as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var c := box.get_center()
	var g: Transform3D = ring_node.global_transform * (m.t as Transform3D)
	var a := g * Vector3(box.position.x, c.y, c.z)
	var b2 := g * Vector3(box.end.x, c.y, c.z)
	var mid := (a + b2) * 0.5
	var o := _out(mid)
	var half := box.size * 0.5
	var reach := absf(g.basis.x.dot(o)) * half.x + absf(g.basis.y.dot(o)) * half.y + absf(g.basis.z.dot(o)) * half.z
	return {"a": a, "b": b2, "mid": mid, "out": o, "skin": reach}


# --- Supplies --------------------------------------------------------------------------------

## Asks for a keel ring kit when the ring needs parts that no mover is holding and none is on
## its way.
func _keep_supplied() -> void:
	if traffic == null or ring_node == null:
		return
	if _order >= 0:
		var o: Dictionary = traffic.call("kit_order", _order)
		if not o.is_empty() and not bool(o.done):
			return
	var need := {}
	for m: Dictionary in members:
		if m.stage == "need":
			need[m.part] = int(need.get(m.part, 0)) + 1
	if need.is_empty():
		return
	for l: Dictionary in traffic.call("waiting_loads", supply):
		if need.has(l.part):
			need[l.part] = int(need[l.part]) - (int(l.qty) - int(l.get("promised", 0)))
	for part: String in need:
		if int(need[part]) > 0:
			_order = int(traffic.call("deliver_kit", KIT, supply, true))
			return


## A load a mover is holding with a part of `part` not yet promised to a fitter.
func _load_with(part: String) -> Dictionary:
	if traffic == null:
		return {}
	for l: Dictionary in traffic.call("waiting_loads", supply):
		if l.part == part and int(l.qty) - int(l.get("promised", 0)) > 0:
			return l
	return {}


# --- Who does what -----------------------------------------------------------------------------

func _assign() -> void:
	for m: Dictionary in members:
		match String(m.stage):
			"need":
				var f := _idle("F")
				if f.is_empty():
					continue
				var l := _load_with(m.part)
				if l.is_empty():
					m.waited = float(m.waited) + get_process_delta_time()
					if float(m.waited) < spare_after:
						continue
				else:
					l.promised = int(l.get("promised", 0)) + 1
				m.stage = "carry"
				m.fitter = f
				f.task = {"kind": "fit", "member": m, "load": l, "phase": "go", "t": 0.0}
			"held":
				var w := _idle("W")
				if w.is_empty():
					continue
				m.stage = "welding"
				var s := _span(m)
				w.task = {"kind": "weld", "member": m, "joints": [s.a, s.b], "phase": "go", "t": 0.0}
			"welded":
				var r := _idle("R")
				if r.is_empty():
					continue
				m.stage = "riveting"
				r.task = {"kind": "rivet", "member": m, "spots": [0.2, 0.5, 0.8], "phase": "go", "t": 0.0}


func _idle(role: String) -> Dictionary:
	for w: Dictionary in workers:
		if w.role == role and (w.task as Dictionary).is_empty() and w.fault == "" and not bool(w.servicing):
			return w
	return {}


## Where a worker hangs about between jobs: just off the front ring, out of the way.
func _idle_spot(i: int) -> Vector3:
	var side := 1.0 if i % 2 == 0 else -1.0
	return _front() + Vector3(KEEL_STEP * 0.8, RING * 0.5 + (float(i / 2) - 1.0) * 1.8, side * (RING * 0.5 + 2.4))


# --- Doing it -------------------------------------------------------------------------------

func _work(w: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var task: Dictionary = w.task
	var busy := true
	if w.has("sparks"):
		(w.sparks as CPUParticles3D).emitting = false
	if w.has("light"):
		(w.light as OmniLight3D).light_energy = 0.0
	var label := node.get_node("Fault") as Label3D
	label.visible = w.fault != "" and fmod(_time, 1.0) < 0.7
	if task.is_empty():
		busy = false
		_fly(w, _idle_spot(int(w.index)), delta)
		if w.fault != "" or bool(w.servicing):
			# Stopped: arms hanging, waiting on TartanCo, a slow tumble if it's faulted.
			_face(node, node.global_position + Vector3(0.3, -0.25 if w.fault != "" else 0.0, -1.0), delta * 0.3)
		else:
			_face(node, _axis(), delta)
		WorkerLook.rest(node, "R")
		WorkerLook.rest(node, "L")
	else:
		match String(task.kind):
			"fit":
				_fit(w, task, delta)
			"weld":
				_weld(w, task, delta)
			"rivet":
				_rivet(w, task, delta)
	(node.get_node("Thrust") as Node3D).visible = (w.vel as Vector3).length() > 0.6
	var head := node.get_node("Head") as Node3D
	head.rotation.x = lerpf(head.rotation.x, -0.25 if busy else 0.0, minf(1.0, delta * 3.0))
	WorkerLook.lay_hose(node)


## Flies towards `to`, easing in; true once there.
func _fly(w: Dictionary, to: Vector3, delta: float) -> bool:
	var node: Node3D = w.node
	var gap := to - node.position
	var want := gap.limit_length(minf(fly_speed, gap.length() * 1.6 + 0.1))
	w.vel = (w.vel as Vector3).lerp(want, minf(1.0, delta * 3.0))
	node.position += (w.vel as Vector3) * delta
	if gap.length() < 0.08:
		node.position = to
		w.vel = Vector3.ZERO
		return true
	return false


## Turns to face `at` (station space), slowly.
func _face(node: Node3D, at: Vector3, delta: float) -> void:
	var f := at - node.global_position
	if f.length() < 0.05:
		return
	f = f.normalized()
	var up := Vector3.UP if absf(f.y) < 0.75 else Vector3.RIGHT
	var want := Basis.looking_at(f, up).get_rotation_quaternion()
	var now := node.global_basis.get_rotation_quaternion()
	node.global_basis = Basis(now.slerp(want, minf(1.0, delta * 2.5)))


## A fitter: to the mover, takes a part, carries it to the ring, eases it into place and holds
## it till it's welded.
func _fit(w: Dictionary, task: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var m: Dictionary = task.member
	var l: Dictionary = task.load
	match String(task.phase):
		"go":
			var at := supply.global_position if l.is_empty() or not is_instance_valid(l.node) else (l.node as Node3D).global_position
			var stand := at + Vector3(-1.9, 0.6, 0)
			_face(node, at, delta)
			WorkerLook.reach(node, "R", at + Vector3(-0.2, 0.15, -0.5), (at - node.global_position).normalized())
			WorkerLook.reach(node, "L", at + Vector3(-0.2, 0.15, 0.5), (at - node.global_position).normalized())
			if _fly(w, stand, delta):
				task.t = float(task.t) + delta
				if float(task.t) > 0.6:
					var piece: Node3D = traffic.call("take_piece", l) if not l.is_empty() else null
					if not l.is_empty():
						l.promised = maxi(0, int(l.get("promised", 0)) - 1)
					if piece == null:
						piece = _spare(m.part, at)
					piece.reparent(self, true)
					m.piece = piece
					task.from = piece.global_transform
					task.phase = "carry"
					task.t = 0.0
		"carry":
			var piece: Node3D = m.piece
			var s := _span(m)
			var stand: Vector3 = s.mid + (s.out as Vector3) * 2.3
			var arrived := _fly(w, stand, delta)
			_face(node, s.mid, delta)
			task.t = minf(1.0, float(task.t) + delta / 0.8)
			var held := node.global_transform * Transform3D(Basis(), Vector3(0, 0.7, -1.25))
			piece.global_transform = (task.from as Transform3D).interpolate_with(held, _ease(float(task.t)))
			_hold(node, piece, m)
			if arrived and float(task.t) >= 1.0:
				task.phase = "fit"
				task.from = piece.global_transform
				task.t = 0.0
		"fit":
			var piece: Node3D = m.piece
			task.t = minf(1.0, float(task.t) + delta / fit_seconds)
			var final := ring_node.global_transform * (m.t as Transform3D)
			piece.global_transform = (task.from as Transform3D).interpolate_with(final, _ease(float(task.t)))
			_face(node, _span(m).mid, delta)
			_hold(node, piece, m)
			if float(task.t) >= 1.0:
				piece.reparent(ring_node, true)
				m.stage = "held"
				task.phase = "hold"
		"hold":
			_face(node, _span(m).mid, delta)
			_hold(node, m.piece, m)
			if m.stage != "held" and m.stage != "welding":
				_job_done(w)


## Both grippers on the part, half a metre either side of its middle, from its near side.
func _hold(node: Node3D, piece: Node3D, m: Dictionary) -> void:
	var g := piece.global_transform
	var along := g.basis.x.normalized()
	if along.dot(node.global_basis.x) < 0.0:
		along = -along
	var mid := g * _centre(m.part)
	var into := (mid - node.global_position).normalized()
	var skin := 0.12
	WorkerLook.reach(node, "R", mid + along * 0.55 - into * skin, into)
	WorkerLook.reach(node, "L", mid - along * 0.55 - into * skin, into)


func _centre(part: String) -> Vector3:
	var layers: Array = Look.layers(part)
	return (layers[0].mesh as Mesh).get_aabb().get_center() if not layers.is_empty() else Vector3.ZERO


## A part from the berth's own stock, when the stores have none to send.
func _spare(part: String, at: Vector3) -> Node3D:
	var piece := Node3D.new()
	piece.name = "Spare_%s" % part
	add_child(piece)
	piece.global_position = at
	for l: Dictionary in Look.layers(part):
		var mi := MeshInstance3D.new()
		mi.mesh = l.mesh
		mi.material_override = l.material
		piece.add_child(mi)
	return piece


## A welder: to each end of the part, then the arc run across the joint, sparks flying, the
## other hand braced on the part.
func _weld(w: Dictionary, task: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var m: Dictionary = task.member
	var joints: Array = task.joints
	if joints.is_empty():
		m.stage = "welded"
		_job_done(w)
		return
	var joint: Vector3 = joints[0]
	var s := _span(m)
	var out := _out(joint)
	var inward := ((s.mid as Vector3) - joint).normalized()
	var face := joint + out * (float(s.skin) + 0.02)
	var stand := face + out * 1.45 + inward * 0.5 + Vector3(0, 0.0, 0)
	var across := out.cross(inward).normalized()
	_face(node, face, delta)
	WorkerLook.reach(node, "L", face + inward * 0.75 + out * 0.04, -out)
	match String(task.phase):
		"go":
			WorkerLook.reach(node, "R", face - out * -0.35 + across * 0.2, -out)
			if _fly(w, stand, delta):
				task.phase = "arc"
				task.t = 0.0
		"arc":
			task.t = float(task.t) + delta
			var k := clampf(float(task.t) / weld_seconds, 0.0, 1.0)
			var tip := face + across * lerpf(-0.16, 0.16, k)
			WorkerLook.reach(node, "R", tip, (-out + inward * 0.3).normalized())
			var sparks: CPUParticles3D = w.sparks
			sparks.global_position = WorkerLook.tip_of(node, "R")
			sparks.emitting = true
			var flick := 0.5 + 0.5 * sin(_time * 47.0) * sin(_time * 31.0 + float(w.index))
			var light: OmniLight3D = w.light
			light.global_position = sparks.global_position + out * 0.3
			light.light_energy = 1.4 + flick * 2.2
			if float(task.t) >= weld_seconds:
				_bead(face - across * 0.16, face + across * 0.16, out)
				joints.pop_front()
				task.phase = "go"
				task.t = 0.0


## A riveter: along the part, at each spot the gun builds pressure, then punches a rivet home
## with a kick and a flash.
func _rivet(w: Dictionary, task: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var m: Dictionary = task.member
	var spots: Array = task.spots
	if spots.is_empty():
		m.stage = "done"
		_job_done(w)
		return
	var s := _span(m)
	var p: Vector3 = (s.a as Vector3).lerp(s.b, float(spots[0]))
	var out: Vector3 = s.out
	var face := p + out * (float(s.skin) + 0.01)
	var along := ((s.b as Vector3) - (s.a as Vector3)).normalized()
	var stand := face + out * 1.6 + along * 0.2
	_face(node, face, delta)
	WorkerLook.reach(node, "L", face + along * 0.5 + out * 0.03, -out)
	match String(task.phase):
		"go":
			WorkerLook.reach(node, "R", face + out * 0.3, -out)
			if _fly(w, stand, delta):
				task.phase = "press"
				task.t = 0.0
		"press":
			task.t = float(task.t) + delta
			var punch := rivet_seconds * 0.75
			var kick := 0.0
			var light: OmniLight3D = w.light
			if float(task.t) < punch:
				# Building pressure: the gun pressed on, trembling a little.
				kick = -0.01 + 0.006 * sin(_time * 90.0)
			else:
				var k := (float(task.t) - punch) / (rivet_seconds - punch)
				kick = 0.14 * (1.0 - k) * (1.0 - k)
				if not task.has("fired"):
					task.fired = true
					_rivet_head(face, out)
				light.global_position = face + out * 0.3
				light.light_energy = 3.0 * (1.0 - k)
			WorkerLook.reach(node, "R", face, -out, kick)
			if float(task.t) >= rivet_seconds:
				spots.pop_front()
				task.erase("fired")
				task.phase = "go"
				task.t = 0.0


## A weld bead left across the joint: a dark, slightly glossy ridge.
func _bead(a: Vector3, b: Vector3, out: Vector3) -> void:
	var bead := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.035
	mesh.height = a.distance_to(b) + 0.07
	mesh.radial_segments = 10
	mesh.rings = 2
	bead.mesh = mesh
	bead.material_override = _rivet_material()
	ring_node.add_child(bead)
	var y := (b - a).normalized()
	var x := out.cross(y).normalized()
	bead.global_transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)


func _rivet_head(at: Vector3, out: Vector3) -> void:
	if _rivet_mesh == null:
		_rivet_mesh = CylinderMesh.new()
		_rivet_mesh.top_radius = 0.025
		_rivet_mesh.bottom_radius = 0.04
		_rivet_mesh.height = 0.03
		_rivet_mesh.radial_segments = 12
		_rivet_mesh.rings = 1
	var head := MeshInstance3D.new()
	head.mesh = _rivet_mesh
	head.material_override = _rivet_material()
	ring_node.add_child(head)
	var y := out.normalized()
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
	head.global_transform = Transform3D(Basis(x, y, x.cross(y)), at + y * 0.01)


func _rivet_material() -> StandardMaterial3D:
	if _rivet_mat == null:
		_rivet_mat = StandardMaterial3D.new()
		_rivet_mat.albedo_color = Color(0.32, 0.32, 0.34)
		_rivet_mat.metallic = 0.85
		_rivet_mat.roughness = 0.35
	return _rivet_mat


## The torch's sparks: bright specks flung out and drifting on (zero g: no fall).
func make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Sparks"
	p.emitting = false
	p.amount = 48
	p.lifetime = 0.5
	p.explosiveness = 0.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.01
	p.scale_amount_max = 0.025
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Look.glow_material(Color(1.0, 0.75, 0.35))
	p.mesh = m
	p.local_coords = false
	return p


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
