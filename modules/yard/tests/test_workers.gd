extends ModuleTest
## TartanCo's worker androids in the build berth (19 Nov: "heavy bots with arms which articulate
## ... holding objects and welding, riveting or bolting objects in place. Some carry the large
## components and put them in place, others weld and rivet etc. The movers bring supplies to them
## when they need them or bring quantities of stock and wait until they have depleted them"):
## four trades with jointed arms and legs, bolters on the girders, trades clamped to the work,
## a fit-out of components brought on demand, and the calls the maintenance ship services them by.
##   tools/run_tests.sh yard

const Traffic := preload("res://modules/yard/internal/stores_traffic.gd")
const Workers := preload("res://modules/yard/internal/yard_workers.gd")
const WorkerLook := preload("res://modules/yard/internal/yard_worker_look.gd")


func run_tests() -> void:
	_look()
	await _crew()


## Every trade's android has its arms, legs, tools and markings; IK puts a tool tip and a foot
## where they're asked.
func _look() -> void:
	for role: String in ["F", "W", "R", "B"]:
		var bot := WorkerLook.make(role, "01")
		add_child(bot)
		var parts := ["UpperR", "ForeL", "HandR", "ThighR", "ShinL", "FootR", "Pack", "Tartan"]
		check(parts.all(func(n: String) -> bool: return bot.has_node(n)), "%s has arms, legs, a pack and its tartan" % role)
		check(String(bot.get_meta("tartanco_model")).begins_with(role) and String(bot.get_meta("serial")) != "",
				"%s carries its TartanCo model and serial" % role)
		var tip := bot.global_position + Vector3(0.3, 0.4, -1.2)
		WorkerLook.reach(bot, "R", tip, Vector3.FORWARD)
		check(WorkerLook.tip_of(bot, "R").distance_to(tip) < 0.02, "%s's tool reaches its spot" % role)
		var sole := bot.global_position + Vector3(0.3, -1.1, -0.2)
		WorkerLook.plant(bot, "R", sole, Vector3.DOWN)
		var foot := bot.get_node("FootR") as Node3D
		check(foot.global_position.distance_to(sole + Vector3.UP * WorkerLook.ANKLE) < 0.02, "%s's foot clamps where it's put" % role)
		bot.queue_free()
	var fitter := WorkerLook.make("F", "02")
	add_child(fitter)
	check(fitter.has_node("Laser"), "the fitter has its alignment laser")
	WorkerLook.aim_laser(fitter, Vector3(0, 0, -3))
	check((fitter.get_node("Laser") as Node3D).visible, "and it shines on the part's place")
	fitter.queue_free()


func _crew() -> void:
	var store := YardRackStore.new()
	store.fill_demo(0.6)
	var traffic := Traffic.new()
	traffic.set_process(false)
	add_child(traffic)
	traffic.build(store)
	var crew: Node3D = Workers.new()
	crew.set_process(false)
	add_child(crew)
	crew.build(traffic)
	crew.wear_per_job = 0.0   # no faults while it builds
	var roles: Array = crew.workers.map(func(w: Dictionary) -> String: return w.role)
	check(roles.has("F") and roles.has("W") and roles.has("R") and roles.has("B"), "fitters, welders, a riveter and a bolter")
	# A ring: bolts on the girders, and the trades clamp their feet to the work.
	var rings: int = crew.rings_built()
	var clamped := {}
	var t := 0.0
	while crew.rings_built() == rings and t < 900.0:
		traffic.step(0.2)
		crew.step(0.2)
		t += 0.2
		for w: Dictionary in crew.workers:
			var task: Dictionary = w.task
			if not task.is_empty() and task.kind != "fit" and task.phase != "go":
				var foot := (w.node as Node3D).get_node("FootR") as Node3D
				var m: Dictionary = task.member
				var s: Dictionary = crew._span(m)
				# The sole on the member's face: no further off it than the face's own reach.
				var off := (foot.global_position - (s.mid as Vector3)).dot(s.out as Vector3)
				if off > float(s.skin) and off < float(s.skin) + WorkerLook.ANKLE + 0.08:
					clamped[w.role] = true
	check(crew.rings_built() == rings + 1, "a ring went on (%.0f s)" % t)
	var bolted := 0
	for n in (crew.rings.back() as Node3D).get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh == crew._bolt_mesh:
			bolted += 1
	check(bolted >= 4 * crew.bolts_per_joint * 2, "the bolter ran %d bolts into the girders' ends" % bolted)
	check(clamped.has("W") and clamped.has("R") and clamped.has("B"), "welders, riveters and bolters clamp on to the work (%s)" % str(clamped.keys()))
	# A fit-out: the power kit brought to the lead fitter when it's wanted, set on the ring and
	# bolted down.
	t = 0.0
	while crew.fitted_out.is_empty() and t < 1200.0:
		traffic.step(0.2)
		crew.step(0.2)
		t += 0.2
	check(not crew.fitted_out.is_empty(), "the crew fitted a ring out (%.0f s)" % t)
	var on_demand: bool = traffic.kit_orders.any(func(o: Dictionary) -> bool: return o.kit == Workers.FITOUT_KIT and not bool(o.get("wait", false)) and o.to == crew.foreman())
	check(on_demand, "its kit was brought to the lead fitter, not left waiting")
	var fitted := 0
	var ring: Node3D = crew.rings[int(crew.fitted_out[0]) - 1]
	for n in ring.get_children():
		if String(n.name).begins_with("Piece_") and not String(n.name).contains("BoxBeam") and not String(n.name).contains("Girder"):
			fitted += 1
	check(fitted >= 3, "%d components set in the ring" % fitted)
	# Service by the maintenance ship: it listens on the yard's bus, so the yard's own visit stays
	# away and the ship takes the bot, works on it and hands it back.
	var bus := Modules.bus("yard")
	var asked := {"bots": []}
	var listener := func(bots: Array) -> void: asked.bots = bots
	if bus:
		bus.connect("workers_need_service", listener)
	crew.service_needed.connect(func(bots: Array) -> void: asked.bots = bots)
	var w: Dictionary = crew.workers[2]
	w.fault = "E-42 SERVO HEAT"
	w.wear = 0.9
	crew.step(0.2)
	check(asked.bots.has(w.node), "a faulted bot asks for the maintenance ship")
	check(not bus or crew.service.state == "away", "and the yard's own visit stays away while the ship's module listens")
	var c: Dictionary = crew.condition(w.node)
	check(is_zero_approx(float(c.productivity)) and (c.errors as Array).has("E-42 SERVO HEAT"), "its condition shows the error")
	check(crew.begin_service(w.node), "the ship takes it")
	var held_at: Vector3 = (w.node as Node3D).global_position + Vector3(0, 3, 0)
	(w.node as Node3D).global_position = held_at
	for i in 10:
		crew.step(0.2)
	check((w.node as Node3D).global_position.distance_to(held_at) < 0.01, "and the crew leaves it where the ship put it")
	crew.end_service(w.node)
	c = crew.condition(w.node)
	check(is_equal_approx(float(c.productivity), 1.0) and (c.errors as Array).is_empty(), "serviced: as new, back to work")
	if bus:
		bus.disconnect("workers_need_service", listener)
	crew.queue_free()
	traffic.queue_free()
	await frames(1)
