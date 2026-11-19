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
## W-3 welders tack a box beam at both ends, sparks at the torch, and R-3 riveters punch rivets
## along it, each with a kick and a flash; B-3 bolters run bolts home at each end of a girder.
## The trades who fasten clamp their feet to the work and lean into it. Every second ring the
## crew fits it out: they send for a power kit, and movers bring it to the lead fitter when it's
## wanted; fitters set the battery rack, cabinet and junction boxes on the ring and the bolters
## bolt them down. Presentation only: it stands in for Wave 5's real building.
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
## The crew by trade, in order: fitters, welders, riveter, bolter.
const CREW := ["F", "F", "W", "W", "R", "B"]
## The kit a fit-out sends for (brought to the lead fitter when it's wanted, not held waiting),
## and how often: after every this many rings.
const FITOUT_KIT := "power"
const FITOUT_EVERY := 2

## Seconds a fitter takes to ease a part into place, a weld per joint, a rivet (pressure, then
## the punch).
@export var fit_seconds := 2.4
@export var weld_seconds := 2.6
@export var rivet_seconds := 1.0
## Seconds a bolter runs one bolt home, and bolts at each joint.
@export var bolt_seconds := 1.4
@export var bolts_per_joint := 2
## How far a trade leans into the work it's clamped to (rad), and its pelvis over the surface (m).
@export var brace_lean := 0.62
@export var brace_height := 0.8
## Fit the rings out (see the header), and how long to wait on a fit-out's kit before going on
## without it (s).
@export var fit_out := true
@export var fitout_wait := 150.0
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

## A bot needs servicing (faulted, or worn past `call_at`): the bots to see to (each a worker's
## node). Sent once until they're all seen to. While anything listens (the TartanCo
## maintenance ship's module, through YardBus.workers_need_service), the yard's own service visit
## stays away.
signal service_needed(bots: Array)

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
## The fit-out under way: {} or {order (kit order id), t, ring}; rings already fitted out.
var _fitout: Dictionary = {}
var fitted_out: Array[int] = []
var _asked := false
var _bolt_mesh: CylinderMesh


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
		WorkerLook.tuck(bot, "R")
		WorkerLook.tuck(bot, "L")
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


## The crew's bots (their nodes), for the maintenance ship.
func bots() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for w: Dictionary in workers:
		out.append(w.node)
	return out


func worker_of(bot: Node3D) -> Dictionary:
	for w: Dictionary in workers:
		if w.node == bot:
			return w
	return {}


## A bot's state for the maintenance ship: productivity 0..1 (its pace, 0 while faulted), its
## errors, and its wear.
func condition(bot: Node3D) -> Dictionary:
	var w := worker_of(bot)
	if w.is_empty():
		return {}
	var errors: Array[String] = []
	if w.fault != "":
		errors.append(String(w.fault))
	return {"productivity": 0.0 if w.fault != "" else pace(w), "errors": errors, "wear": float(w.wear),
			"model": bot.get_meta("tartanco_model", ""), "serial": bot.get_meta("serial", "")}


## The maintenance ship takes a bot: it puts its job down (a part it was holding stays put) and
## keeps still till end_service. True if it took it.
func begin_service(bot: Node3D) -> bool:
	var w := worker_of(bot)
	if w.is_empty():
		return false
	_drop_task(w)
	w.servicing = true
	w.external = true
	return true


## The maintenance ship is done with a bot: as new, its error cleared, back to work.
func end_service(bot: Node3D) -> void:
	var w := worker_of(bot)
	if not w.is_empty():
		w.external = false
		serviced(w)


## True while someone else (the maintenance ship) answers service_needed.
func external_service() -> bool:
	# Through the tree, not the autoload's name: the capture tools run this as a bare script.
	var tree := Engine.get_main_loop() as SceneTree
	var modules := tree.root.get_node_or_null("Modules") if tree else null
	var bus: Node = modules.call("bus", "yard") if modules else null
	return bus != null and bus.has_signal("workers_need_service") and not bus.get_signal_connection_list("workers_need_service").is_empty()


## Puts a bot's job down so another can pick it up: its member goes back a stage.
func _drop_task(w: Dictionary) -> void:
	var task: Dictionary = w.task
	if task.is_empty():
		return
	var m: Dictionary = task.get("member", {})
	match String(task.kind):
		"fit":
			if task.phase == "go" or task.phase == "carry":
				if m.get("piece") != null and is_instance_valid(m.piece):
					(m.piece as Node3D).queue_free()
				m.piece = null
				m.stage = "need"
				m.waited = spare_after   # its part was taken: a spare comes
			elif task.phase == "fit":
				(m.piece as Node3D).global_transform = ring_node.global_transform * (m.t as Transform3D)
				(m.piece as Node3D).reparent(ring_node, true)
				m.stage = "held"
		"weld":
			m.stage = "held"
		"bolt":
			m.stage = "held"
		"rivet":
			m.stage = "welded"
	w.task = {}


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
	if ring_node == null and _fitout.is_empty():
		if fit_out and rings.size() >= FITOUT_EVERY and rings.size() % FITOUT_EVERY == 0 \
				and not fitted_out.has(rings.size()) and rings.size() > start_rings:
			_start_fitout()
		elif rings.size() < RINGS:
			_start_ring()
	if not _fitout.is_empty():
		_step_fitout(delta)
	else:
		_keep_supplied()
	_assign()
	for w: Dictionary in workers:
		_work(w, delta * pace(w))
	_check_service()
	service.call("step", delta)
	if ring_node and not members.is_empty() and members.all(func(m: Dictionary) -> bool: return m.stage == "done"):
		if _fitout.is_empty():
			rings.append(ring_node)
		else:
			fitted_out.append(int(_fitout.ring))
			_fitout = {}
		ring_node = null
		members.clear()


## Sends for TartanCo when a bot faults or wears past `call_at`: the maintenance ship's module
## if it's listening (service_needed, once till they're seen to), else the yard's own visit.
func _check_service() -> void:
	var due: Array = []
	var urgent := false
	for w: Dictionary in workers:
		if w.fault != "" or float(w.wear) >= call_at:
			urgent = true
		if w.fault != "" or float(w.wear) >= service_from:
			due.append(w.node)
	if not urgent:
		_asked = false
		return
	if external_service():
		if not _asked:
			_asked = true
			service_needed.emit(due)
	elif auto_service and service.state == "away":
		call_service()


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
	var o := _out(mid) if not m.has("out") else ring_node.global_basis * (m.out as Vector3)
	var half := box.size * 0.5
	var reach := absf(g.basis.x.dot(o)) * half.x + absf(g.basis.y.dot(o)) * half.y + absf(g.basis.z.dot(o)) * half.z
	return {"a": a, "b": b2, "mid": mid, "out": o, "skin": reach}


# --- Fitting out ----------------------------------------------------------------------------

## Sends for the fit-out's kit, brought to the lead fitter when it's wanted.
func _start_fitout() -> void:
	_fitout = {"order": -1, "t": 0.0, "ring": rings.size()}
	if traffic:
		_fitout.order = int(traffic.call("deliver_kit", FITOUT_KIT, foreman(), false))


## Waits for the kit; once it's here, each part it brought is a member to set on the last ring.
func _step_fitout(delta: float) -> void:
	if ring_node != null:
		return
	_fitout.t = float(_fitout.t) + delta
	var o: Dictionary = traffic.call("kit_order", int(_fitout.order)) if traffic and int(_fitout.order) >= 0 else {}
	if o.is_empty() or (not bool(o.done) and float(_fitout.t) < fitout_wait):
		if o.is_empty() or float(_fitout.t) >= fitout_wait:
			fitted_out.append(int(_fitout.ring))
			_fitout = {}
		return
	var spots := _mount_spots()
	members.clear()
	for l: Dictionary in o.loads:
		if not is_instance_valid(l.node):
			continue
		l.kept = true   # the fitters set these: they don't go back
		for k in int(l.qty):
			var spot := _next_spot(spots, String(l.part))
			if spot.is_empty():
				break
			members.append({"part": l.part, "t": spot.t, "out": spot.out, "joints": spot.joints, "stage": "need",
					"piece": null, "waited": 0.0, "load": l})
	if members.is_empty():
		fitted_out.append(int(_fitout.ring))
		_fitout = {}
		return
	ring_node = rings.back()


## Places on the last ring for a fit-out's parts (ring space): big parts stand on the bottom
## beam, either side of the middle; small ones go on the uprights' inner faces. Each spot: its
## transform, the way out from its face and the bolts that hold it ({p, out, toward}).
func _mount_spots() -> Dictionary:
	var beam := _box("BoxBeam")
	var h := RING * 0.5
	var big: Array = []
	for z: float in [-1.5, 1.5]:
		big.append([Basis(), Vector3(0, beam.end.y, z), Vector3.UP])
	var small: Array = []
	for y: float in [h - 0.9, h + 0.9]:
		small.append([Basis(), Vector3(0, y, -h + beam.end.z), Vector3.BACK])
		small.append([Basis(Vector3.UP, PI), Vector3(0, y, h - beam.end.z), Vector3.FORWARD])
	return {"big": big, "small": small}


func _next_spot(spots: Dictionary, part: String) -> Dictionary:
	var size := _box(part).size
	var list: Array = spots.small if maxf(size.x, maxf(size.y, size.z)) < 0.6 else spots.big
	if list.is_empty():
		return {}
	var s: Array = list.pop_front()
	var basis: Basis = s[0]
	var contact: Vector3 = s[1]
	var normal: Vector3 = s[2]
	var ab := Transform3D(basis, Vector3.ZERO) * _box(part)
	var half := absf(ab.size.dot(normal.abs())) * 0.5
	var at := contact - ab.get_center() + normal * half
	# Two bolts at its foot, either side along the beam (or up the upright).
	var spread := Vector3(0, 0, 1) if normal == Vector3.UP else Vector3(0, 1, 0)
	var reach := maxf(0.12, absf(ab.size.dot(spread)) * 0.5 + 0.06)
	var joints: Array = []
	for sgn: float in [-1.0, 1.0]:
		joints.append({"p": contact + spread * sgn * reach, "out": normal, "toward": -spread * sgn})
	return {"t": Transform3D(basis, at), "out": normal, "joints": joints}


## A part's box in its own space.
func _box(part: String) -> AABB:
	var box := AABB()
	var first := true
	for l: Dictionary in Look.layers(part):
		var b: AABB = (l.mesh as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


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
				var l: Dictionary = m.load if m.has("load") and int(m.load.qty) > 0 else _load_with(m.part)
				if l.is_empty():
					m.waited = float(m.waited) + get_process_delta_time()
					if float(m.waited) < spare_after:
						continue
				elif not m.has("load"):
					l.promised = int(l.get("promised", 0)) + 1
				m.stage = "carry"
				m.fitter = f
				f.task = {"kind": "fit", "member": m, "load": l, "phase": "go", "t": 0.0}
			"held":
				if m.part == "BoxBeam":
					var w := _idle("W")
					if w.is_empty():
						continue
					m.stage = "welding"
					var s := _span(m)
					w.task = {"kind": "weld", "member": m, "joints": [s.a, s.b], "phase": "go", "t": 0.0}
				else:
					var b := _idle("B")
					if b.is_empty():
						continue
					m.stage = "bolting"
					b.task = {"kind": "bolt", "member": m, "joints": _bolt_joints(m), "phase": "go", "t": 0.0, "bolt": 0}
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
	if bool(w.get("external", false)):
		# The maintenance ship has it: it's theirs to move; its arms hang.
		(node.get_node("Thrust") as Node3D).visible = false
		return
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
		var sway := sin(_time * 0.7 + float(w.index))
		WorkerLook.tuck(node, "R", sway)
		WorkerLook.tuck(node, "L", -sway)
	else:
		match String(task.kind):
			"fit":
				_fit(w, task, delta)
			"weld":
				_weld(w, task, delta)
			"rivet":
				_rivet(w, task, delta)
			"bolt":
				_bolt(w, task, delta)
	if w.role == "F":
		WorkerLook.aim_laser(node, task.get("laser") if not task.is_empty() else null)
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
	var sway := sin(_time * 0.9 + float(w.index)) * 0.5
	WorkerLook.tuck(node, "R", sway)
	WorkerLook.tuck(node, "L", -sway)
	task.erase("laser")
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
						if int(l.qty) <= 0 and l.get("where") == "delivered":
							traffic.call("consume", l)
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
			# Off to the part's side, so the trades who fasten it have its face to themselves.
			var across := (s.out as Vector3).cross(((s.b as Vector3) - (s.a as Vector3)).normalized()).normalized()
			var stand: Vector3 = s.mid + (s.out as Vector3) * 1.5 + across * 1.6
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
			# The alignment laser on the part's place while it eases in.
			task.laser = final * _centre(m.part)
			if float(task.t) >= 1.0:
				piece.reparent(ring_node, true)
				m.stage = "held"
				task.phase = "hold"
		"hold":
			if m.stage != "held" and m.stage != "welding" and m.stage != "bolting" or ring_node == null:
				_job_done(w)
				return
			_face(node, _span(m).mid, delta)
			_hold(node, m.piece, m)


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
	var out: Vector3 = s.out
	var inward := ((s.mid as Vector3) - joint).normalized()
	var face := joint + out * (float(s.skin) + 0.02) + inward * 0.06
	var across := out.cross(inward).normalized()
	var there := _brace(w, face, out, -inward, delta)
	WorkerLook.reach(node, "L", face + inward * 0.45 - node.global_basis.x * 0.3 + out * 0.04, -out)
	match String(task.phase):
		"go":
			WorkerLook.reach(node, "R", face + out * 0.35 + across * 0.2, -out)
			if there:
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
	var there := _brace(w, face, out, along, delta)
	WorkerLook.reach(node, "L", face - along * 0.35 - node.global_basis.x * 0.25 + out * 0.03, -out)
	match String(task.phase):
		"go":
			WorkerLook.reach(node, "R", face + out * 0.3, -out)
			if there:
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


## Where a bolter runs bolts in: for a girder, its two ends on its outer face; for a fitted part,
## the spots its mount gave. Each {p (global), out, toward}.
func _bolt_joints(m: Dictionary) -> Array:
	var out: Array = []
	if m.has("joints"):
		for j: Dictionary in m.joints:
			out.append({"p": ring_node.global_transform * (j.p as Vector3), "out": ring_node.global_basis * (j.out as Vector3),
					"toward": ring_node.global_basis * (j.toward as Vector3)})
		return out
	var s := _span(m)
	for end: Vector3 in [s.a, s.b]:
		var inward := ((s.mid as Vector3) - end).normalized()
		out.append({"p": end + inward * 0.18 + (s.out as Vector3) * float(s.skin), "out": s.out, "toward": -inward})
	return out


## A bolter: clamped on beside each joint, the nut runner on each bolt in turn: it seats, spins
## it home (the socket turning) and leaves a bolt head and washer.
func _bolt(w: Dictionary, task: Dictionary, delta: float) -> void:
	var node: Node3D = w.node
	var m: Dictionary = task.member
	var joints: Array = task.joints
	if joints.is_empty():
		m.stage = "done"
		_job_done(w)
		return
	var j: Dictionary = joints[0]
	var out: Vector3 = (j.out as Vector3).normalized()
	var toward: Vector3 = j.toward
	var across := out.cross(toward).normalized()
	var k := int(task.bolt)
	var offset := (float(k) - (bolts_per_joint - 1) * 0.5) * 0.09
	var face: Vector3 = (j.p as Vector3) + across * offset + out * 0.01
	var there := _brace(w, j.p, out, toward, delta)
	WorkerLook.reach(node, "L", (j.p as Vector3) - toward * 0.3 - node.global_basis.x * 0.25 + out * 0.03, -out)
	match String(task.phase):
		"go":
			WorkerLook.reach(node, "R", face + out * 0.3, -out)
			if there:
				task.phase = "run"
				task.t = 0.0
		"run":
			task.t = float(task.t) + delta
			var f := clampf(float(task.t) / bolt_seconds, 0.0, 1.0)
			# Seat it, then spin it down; the hand turns with the socket.
			WorkerLook.reach(node, "R", face + out * (0.06 * (1.0 - f)), -out)
			var hand := node.get_node("HandR") as Node3D
			hand.rotate(hand.global_basis.y.normalized(), float(task.t) * 30.0)
			var light: OmniLight3D = w.light
			light.global_position = face + out * 0.4
			light.light_energy = 0.6 if f > 0.2 else 0.0
			if float(task.t) >= bolt_seconds:
				_bolt_head(face, out)
				task.bolt = k + 1
				task.t = 0.0
				if int(task.bolt) >= bolts_per_joint:
					joints.pop_front()
					task.bolt = 0
					task.phase = "go"


## Clamps a trade to the work: its feet on the surface at `face` (whose way out is `out`), facing
## along `toward` and leaning into it, pelvis `brace_height` up. Flies there first (legs tucked);
## true once it's clamped on.
func _brace(w: Dictionary, face: Vector3, out: Vector3, toward: Vector3, delta: float) -> bool:
	var node: Node3D = w.node
	var up := out.normalized()
	var fwd := toward - up * up.dot(toward)
	fwd = fwd.normalized() if fwd.length() > 0.01 else up.cross(Vector3.RIGHT).normalized()
	var z := -fwd
	var basis := Basis(up.cross(z).normalized(), up, z)
	basis = Basis(basis.x, -brace_lean) * basis
	var at := face + up * brace_height - fwd * 0.92
	var there := _fly(w, at, delta)
	var now := node.global_basis.get_rotation_quaternion()
	node.global_basis = Basis(now.slerp(basis.get_rotation_quaternion(), minf(1.0, delta * 3.0)))
	if node.global_position.distance_to(at) < 0.35:
		var x := up.cross(z).normalized()
		# Feet staggered along the member's line, magnetic clamps on its face.
		WorkerLook.plant(node, "R", face - fwd * 0.42 + x * 0.1, -up, fwd)
		WorkerLook.plant(node, "L", face - fwd * 0.86 - x * 0.1, -up, fwd)
	else:
		WorkerLook.tuck(node, "R")
		WorkerLook.tuck(node, "L")
	return there and node.global_basis.get_rotation_quaternion().angle_to(basis.get_rotation_quaternion()) < 0.15


func _bolt_head(at: Vector3, out: Vector3) -> void:
	if _bolt_mesh == null:
		_bolt_mesh = CylinderMesh.new()
		_bolt_mesh.top_radius = 0.024
		_bolt_mesh.bottom_radius = 0.024
		_bolt_mesh.height = 0.035
		_bolt_mesh.radial_segments = 6
		_bolt_mesh.rings = 1
	var y := out.normalized()
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
	var washer := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.04
	wm.bottom_radius = 0.04
	wm.height = 0.006
	wm.radial_segments = 12
	wm.rings = 1
	washer.mesh = wm
	washer.material_override = _rivet_material()
	ring_node.add_child(washer)
	washer.global_transform = Transform3D(Basis(x, y, x.cross(y)), at + y * 0.003)
	var head := MeshInstance3D.new()
	head.mesh = _bolt_mesh
	head.material_override = _rivet_material()
	ring_node.add_child(head)
	head.global_transform = Transform3D(Basis(x, y, x.cross(y)), at + y * 0.024)


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
