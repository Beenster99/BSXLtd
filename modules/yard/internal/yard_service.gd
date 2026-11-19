extends Node3D
## TartanCo's field service (0.4.1 playtest: "since our bots need maintenance we need to call
## in their engineers when they start to become less productive or develop errors. TartanCo
## arrive in a space ship and perform the maintenance on our bots at the yard"). Called by the
## crew (YardWorkers) when its bots wear down or fault: TartanCo's service ship, TS-1, comes in
## from deep space on her engines, slows, berths beside the keel with her service bays facing
## it and rolls up her shutters. Her engineers (people in TartanCo's suits, one per bay) fly
## out to each bot that needs them:
##   - a worn bot gets a tune-up where it is: wand and torch over its chest and shoulders,
##     sparks and a scan light, till it's as new;
##   - a faulted bot is taken aboard: its engineer leads it into their bay's cradle, the bay's
##     handling arm comes down and works it over while the engineer runs the diagnostics at
##     the console, then they fly it back to the keel, fault cleared.
## Then they go back aboard, the shutters come down and she leaves, bow first. Presentation over
## the crew's own wear and faults (YardWorkers: needs_service, serviced; a bot with "external" set
## is flown by the engineer, not the crew).

const ShipLook := preload("res://modules/yard/internal/yard_service_ship_look.gd")
const EngineerLook := preload("res://modules/yard/internal/tartanco_engineer_look.gd")

## Where she berths (station space: her middle bay's deck), how far off she comes from (m, -X),
## her top speed in and out (m/s) and how far out she starts slowing (m), the shutters' time
## (s), her engineers (one per bay), how long a tune-up and a bay service take (s), and their
## flying speed (m/s).
## Beyond the berths at their largest tier (they grow with reputation, YardLayout.BERTH_TIERS),
## so she never comes in through a bigger frame; fixed, so the shared clock's yard is the same
## whatever tier each player's dock is drawn at.
const BERTH := Vector3(-4.0, -1.0, YardLayout.DOCK_FAR_Z - 14.0)
@export var approach := 420.0
@export var ship_speed := 30.0
@export var slow_from := 120.0
@export var door_seconds := 3.0
@export var engineers := 3
@export var service_seconds := 7.0
@export var bay_seconds := 10.0
@export var engineer_speed := 4.5

var crew: Node   # YardWorkers
var ship: Node3D
## "away", "in", "open", "closing", "out".
var state := "away"
## Each engineer: {node, job (a worker's dict or {}), stage, t, bay, sparks, light, from}.
## Stages: "" (free), "go" (to the bot), "tune" (on site), "lead" (taking it to the bay mouth),
## "dock" (into the cradle), "bay" (in the cradle), "undock" (out of the bay), "back" (to where
## it was), "home" (back aboard).
var team: Array[Dictionary] = []
var visits := 0
## Bots seen to in the bays this visit and in all (for tests and the debug line).
var bay_services := 0
var _door := 0.0
var _time := 0.0


func build(workers: Node) -> void:
	name = "TartanCoService"
	crew = workers
	ship = ShipLook.make()
	ship.visible = false
	add_child(ship)
	for i in engineers:
		var e := EngineerLook.make("%d" % (i + 1))
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
		team.append({"node": e, "job": {}, "stage": "", "t": 0.0, "bay": i % ShipLook.BAYS.size(),
				"sparks": sparks, "light": light, "from": Vector3.ZERO})


## Sends for TartanCo. False if she's already on her way or here.
func call_in() -> bool:
	if state != "away":
		return false
	state = "in"
	ship.visible = true
	ship.global_position = BERTH - Vector3(approach, 0, 0)
	ship.rotation = Vector3.ZERO
	ShipLook.open_door(ship, 0.0)
	for i in ShipLook.BAYS.size():
		ShipLook.pose_arm(ship, i, 0.0, 0.0)
	_door = 0.0
	return true


func step(delta: float) -> void:
	_time += delta
	match state:
		"in":
			var gap := BERTH - ship.global_position
			var speed := ship_speed * clampf(gap.length() / slow_from, 0.02, 1.0) + 0.3
			ship.global_position += gap.limit_length(speed * delta)
			_glow(gap.length() > slow_from * 0.5)
			if gap.length() < 0.05:
				ship.global_position = BERTH
				state = "open"
		"open":
			_glow(false)
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
			_glow(true)
			var gone := ship.global_position.x - BERTH.x
			ship.global_position += Vector3(minf(ship_speed, 1.0 + gone * 0.4), 0, 0) * delta
			if gone > approach:
				ship.visible = false
				state = "away"


func _glow(on: bool) -> void:
	(ship.get_node("Model/Glow") as Node3D).visible = on


## The engineers: out to each bot that needs them, a tune-up where it is or a service in their
## bay, back aboard when none do.
func _step_team(delta: float) -> void:
	var all_home := true
	var arm_work: Array[float] = [0.0, 0.0, 0.0]
	for e: Dictionary in team:
		var node: Node3D = e.node
		var sparks: CPUParticles3D = e.sparks
		var light: OmniLight3D = e.light
		sparks.emitting = false
		light.light_energy = 0.0
		(node.get_node("Lamp") as SpotLight3D).light_energy = 0.0
		var bay: int = e.bay
		if (e.job as Dictionary).is_empty():
			var w: Dictionary = crew.call("needs_service", team.map(func(x: Dictionary) -> Dictionary: return x.job))
			if not w.is_empty():
				e.job = w
				e.t = 0.0
				e.stage = "go"
				w.servicing = true
				if not node.visible:
					node.global_position = ship.global_transform * ShipLook.berth_spot(bay)
					node.global_basis = ship.global_basis
					node.visible = true
				continue
			e.stage = "home" if node.visible else ""
			if node.visible:
				all_home = false
				if _fly(node, ship.global_transform * ShipLook.berth_spot(bay), delta):
					node.visible = false
				_face(node, ship.global_transform * ShipLook.cradle(bay), delta)
				_arms(node, 0.0, 0.0)
			continue
		all_home = false
		var job: Dictionary = e.job
		var bot: Node3D = job.node
		var chest := bot.global_transform * Vector3(0, 0.62, -0.36)
		match String(e.stage):
			"go":
				_arms(node, 0.2, 0.0)
				_face(node, chest, delta)
				if _fly(node, bot.global_transform * Vector3(0, 0.2, -1.7), delta):
					e.t = 0.0
					if String(job.get("fault", "")) != "":
						e.from = bot.global_position
						job.external = true
						e.stage = "lead"
					else:
						e.stage = "tune"
			"tune":
				_tune(e, bot, chest, delta)
			"lead", "dock", "undock", "back":
				_lead(e, bot, delta)
			"bay":
				arm_work[bay] = 1.0
				_bay(e, bot, delta)
	for i in ShipLook.BAYS.size():
		ShipLook.pose_arm(ship, i, arm_work[i], _time)
	if all_home and (crew.call("needs_service", []) as Dictionary).is_empty():
		state = "closing"


## A tune-up where the bot is: wand over its chest and shoulders, sparks, a scan light.
func _tune(e: Dictionary, bot: Node3D, chest: Vector3, delta: float) -> void:
	var node: Node3D = e.node
	e.t = float(e.t) + delta
	var k := float(e.t) / service_seconds
	_face(node, chest, delta)
	_fly(node, bot.global_transform * Vector3(0, 0.2, -1.4), delta)
	_arms(node, 1.0, float(e.t))
	var sweep := bot.global_basis * Vector3(sin(k * TAU * 2.0) * 0.35, cos(k * TAU) * 0.2, 0)
	var sparks: CPUParticles3D = e.sparks
	sparks.global_position = chest + sweep - bot.global_basis.z * 0.2
	sparks.emitting = fmod(k * 4.0, 1.0) < 0.6
	var light: OmniLight3D = e.light
	light.global_position = chest - bot.global_basis.z * 0.6
	light.light_energy = 1.2 + 0.6 * sin(float(e.t) * 9.0)
	(node.get_node("Lamp") as SpotLight3D).light_energy = 2.0
	if e.t >= service_seconds:
		_done(e)


## Taking a faulted bot aboard and back: the engineer flies a little ahead with a hand on it,
## the bot keeps station beside them.
func _lead(e: Dictionary, bot: Node3D, delta: float) -> void:
	var node: Node3D = e.node
	var bay: int = e.bay
	var xf := ship.global_transform
	var to: Vector3
	var bot_at: Vector3
	match String(e.stage):
		"lead", "undock":
			to = xf * ShipLook.bay_mouth(bay)
			bot_at = to - ship.global_basis.x * 1.4 + Vector3(0, -0.6, 0)
		"dock":
			to = xf * ShipLook.berth_spot(bay)
			bot_at = xf * ShipLook.cradle(bay)
		_:
			bot_at = e.from
			to = bot_at + (xf * ShipLook.bay_mouth(bay) - bot_at).normalized() * 1.6 + Vector3(0, 0.6, 0)
	var there := _fly(node, to, delta)
	var gap := bot_at - bot.global_position
	bot.global_position += gap.limit_length(minf(engineer_speed, gap.length() * 1.5 + 0.1) * delta)
	var settled := gap.length() < 0.1
	_face(node, bot.global_position + Vector3(0, 0.6, 0), delta)
	# The bot faces out of the bay while in it, back at the keel the way it came.
	var out := ship.global_basis.z
	_face(bot, bot.global_position + (out if String(e.stage) == "dock" else -out), delta * 0.6)
	_arms(node, 0.6, 0.0)
	if not (there and settled):
		return
	match String(e.stage):
		"lead":
			e.stage = "dock"
		"dock":
			e.stage = "bay"
			e.t = 0.0
		"undock":
			e.stage = "back"
		"back":
			(e.job as Dictionary).external = false
			_done(e)


## In the bay: the arm works the bot over (sparks at its tool) while the engineer runs the
## diagnostics at the console.
func _bay(e: Dictionary, bot: Node3D, delta: float) -> void:
	var node: Node3D = e.node
	var bay: int = e.bay
	e.t = float(e.t) + delta
	_fly(node, ship.global_transform * ShipLook.berth_spot(bay), delta)
	_face(node, bot.global_position + Vector3(0, 0.6, 0), delta)
	_arms(node, 0.8, float(e.t))
	var sparks: CPUParticles3D = e.sparks
	sparks.global_position = ShipLook.arm_tip(ship, bay)
	sparks.emitting = fmod(float(e.t) * 0.8, 1.0) < 0.55
	var light: OmniLight3D = e.light
	light.global_position = sparks.global_position
	light.light_energy = 1.0 + 0.8 * sin(float(e.t) * 11.0)
	if e.t >= bay_seconds:
		bay_services += 1
		var job: Dictionary = e.job
		job.fault = ""
		e.stage = "undock"


func _done(e: Dictionary) -> void:
	var job: Dictionary = e.job
	job.erase("external")
	crew.call("serviced", job)
	visits += 1
	e.job = {}
	e.stage = ""


## The engineer's arms: `reach` 0 at their sides, 1 out in front working (the right sweeping
## the wand with `t`).
func _arms(node: Node3D, reach: float, t: float) -> void:
	var r := node.get_node("ShoulderR") as Node3D
	var l := node.get_node("ShoulderL") as Node3D
	r.rotation.x = lerpf(r.rotation.x, reach * (1.25 + 0.25 * sin(t * 4.0)), 0.2)
	r.rotation.z = lerpf(r.rotation.z, reach * 0.2 * sin(t * 2.5), 0.2)
	l.rotation.x = lerpf(l.rotation.x, reach * 0.9, 0.2)


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
