extends Node3D
## TartanCo's field service (0.4.1 playtest: "since our bots need maintenance we need to call
## in their engineers when they start to become less productive or develop errors. TartanCo
## arrive in a space ship and perform the maintenance on our bots at the yard"). Called by the
## crew (YardWorkers) when its bots wear down or fault: the service ship comes in from deep
## space, berths beside the keel and lifts her bay door; her engineer bots fly out to each bot
## that needs them, open it up and work on it, sparks and a scan light, till it's as new; then
## they go back aboard, the door comes down and she leaves. Presentation over the crew's own
## wear and faults.

const ShipLook := preload("res://modules/yard/internal/yard_service_ship_look.gd")
const WorkerLook := preload("res://modules/yard/internal/yard_worker_look.gd")

## Where she berths (station space: her bays' floor), how far off she comes from (m, -X), her
## speed in and out (m/s), the door's time (s), her engineers and how long one service takes.
const BERTH := Vector3(-4.0, -1.0, -108.0)
@export var approach := 420.0
@export var ship_speed := 30.0
@export var door_seconds := 3.0
@export var engineers := 3
@export var service_seconds := 7.0
@export var engineer_speed := 4.5

var crew: Node   # YardWorkers
var ship: Node3D
## "away", "in", "open", "closing", "out".
var state := "away"
## {node, job (a worker's dict or {}), t, sparks, light, home}.
var team: Array[Dictionary] = []
var visits := 0
var _door := 0.0


func build(workers: Node) -> void:
	name = "TartanCoService"
	crew = workers
	ship = ShipLook.make()
	ship.visible = false
	add_child(ship)
	for i in engineers:
		var e := WorkerLook.make("E", "%02d" % (i + 1))
		e.name = "Engineer%d" % (i + 1)
		e.visible = false
		add_child(e)
		var sparks: CPUParticles3D = crew.call("make_sparks")
		add_child(sparks)
		var light := OmniLight3D.new()
		light.name = "ScanLight%d" % (i + 1)
		light.light_color = Color(0.5, 0.85, 1.0)
		light.omni_range = 5.0
		light.light_energy = 0.0
		add_child(light)
		team.append({"node": e, "job": {}, "t": 0.0, "sparks": sparks, "light": light, "home": Vector3(-6.0 + i * 6.0, 1.2, -1.6)})


## Sends for TartanCo. False if she's already on her way or here.
func call_in() -> bool:
	if state != "away":
		return false
	state = "in"
	ship.visible = true
	ship.global_position = BERTH - Vector3(approach, 0, 0)
	ship.rotation = Vector3.ZERO
	ShipLook.open_door(ship, 0.0)
	_door = 0.0
	return true


func step(delta: float) -> void:
	match state:
		"in":
			var gap := BERTH - ship.global_position
			ship.global_position += gap.limit_length(minf(ship_speed, gap.length() * 0.6 + 0.5) * delta)
			(ship.get_node("Glow") as Node3D).visible = gap.length() > 30.0
			if gap.length() < 0.05:
				ship.global_position = BERTH
				state = "open"
		"open":
			_door = minf(1.0, _door + delta / door_seconds)
			ShipLook.open_door(ship, _door)
			if _door >= 1.0:
				_step_team(delta)
		"closing":
			_door = maxf(0.0, _door - delta / door_seconds)
			ShipLook.open_door(ship, _door)
			if _door <= 0.0:
				state = "out"
		"out":
			(ship.get_node("Glow") as Node3D).visible = true
			ship.global_position += Vector3(minf(ship_speed, 2.0 + (ship.global_position.x - BERTH.x) * 0.5), 0, 0) * delta
			if ship.global_position.x - BERTH.x > approach:
				ship.visible = false
				state = "away"


## The engineers: out to each bot that needs them, a service each, back aboard when none do.
func _step_team(delta: float) -> void:
	var all_home := true
	for e: Dictionary in team:
		var node: Node3D = e.node
		var job: Dictionary = e.job
		var sparks: CPUParticles3D = e.sparks
		var light: OmniLight3D = e.light
		sparks.emitting = false
		light.light_energy = 0.0
		if job.is_empty():
			var w: Dictionary = crew.call("needs_service", team.map(func(x: Dictionary) -> Dictionary: return x.job))
			if not w.is_empty():
				e.job = w
				e.t = 0.0
				w.servicing = true
				if not node.visible:
					node.global_position = ship.global_transform * (e.home as Vector3)
					node.global_basis = ship.global_basis
					node.visible = true
				continue
			# Back aboard.
			if node.visible:
				var home: Vector3 = ship.global_transform * (e.home as Vector3)
				if _fly(node, home, delta):
					node.visible = false
				else:
					all_home = false
				WorkerLook.rest(node, "R")
				WorkerLook.rest(node, "L")
			continue
		all_home = false
		var bot: Node3D = job.node
		var front := bot.global_transform * Vector3(0, 0.2, -1.7)
		var chest := bot.global_transform * Vector3(0, 0.62, -0.36)
		var there := _fly(node, front, delta)
		_face(node, chest, delta)
		WorkerLook.reach(node, "L", chest + bot.global_basis * Vector3(-0.3, 0.1, 0.02), (chest - node.global_position).normalized())
		if not there:
			WorkerLook.rest(node, "R")
			continue
		e.t = float(e.t) + delta
		var k := float(e.t) / service_seconds
		# Over its chest and shoulders with the torch, a scan light on it.
		var sweep := bot.global_basis * Vector3(sin(k * TAU * 2.0) * 0.35, cos(k * TAU) * 0.2, 0)
		WorkerLook.reach(node, "R", chest + sweep, (chest - node.global_position).normalized())
		sparks.global_position = WorkerLook.tip_of(node, "R")
		sparks.emitting = fmod(k * 4.0, 1.0) < 0.6
		light.global_position = chest - bot.global_basis.z * 0.6
		light.light_energy = 1.2 + 0.6 * sin(float(e.t) * 9.0)
		if e.t >= service_seconds:
			crew.call("serviced", job)
			visits += 1
			e.job = {}
	if all_home and (crew.call("needs_service", []) as Dictionary).is_empty():
		state = "closing"


func _fly(node: Node3D, to: Vector3, delta: float) -> bool:
	var gap := to - node.global_position
	node.global_position += gap.limit_length(minf(engineer_speed, gap.length() * 1.5 + 0.1) * delta)
	return gap.length() < 0.08


func _face(node: Node3D, at: Vector3, delta: float) -> void:
	var f := at - node.global_position
	if f.length() < 0.05:
		return
	f = f.normalized()
	var up := Vector3.UP if absf(f.y) < 0.75 else Vector3.RIGHT
	var want := Basis.looking_at(f, up).get_rotation_quaternion()
	node.global_basis = Basis(node.global_basis.get_rotation_quaternion().slerp(want, minf(1.0, delta * 3.0)))
