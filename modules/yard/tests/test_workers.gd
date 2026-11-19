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
		var parts := ["UpperR", "ForeL", "HandR", "ThighR", "ShinL", "FootR", "Pack"]
		check(parts.all(func(n: String) -> bool: return bot.has_node(n)), "%s has arms, legs, and a pack" % role)
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
	# Only the nut runner's drive and socket turn as it runs a bolt home (beenster, 19 Nov: "only
	# the tool should rotate").
	var bolter := WorkerLook.make("B", "06")
	add_child(bolter)
	var hand := bolter.get_node("HandR") as Node3D
	var before := hand.global_transform
	WorkerLook.spin_socket(bolter, 2.0)
	var spin := bolter.get_node_or_null("HandR/Spin") as Node3D
	check(spin != null and not spin.transform.basis.is_equal_approx(Basis()), "the bolter's socket turns")
	check(hand.global_transform.is_equal_approx(before), "and the runner and hand stay still")
	bolter.queue_free()
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
	crew.charge_per_job = 0.0   # nor runs flat
	for w: Dictionary in crew.workers:
		w.charge = 1.0
	var roles: Array = crew.workers.map(func(w: Dictionary) -> String: return w.role)
	check(roles.has("F") and roles.has("W") and roles.has("R") and roles.has("B"), "fitters, welders, a riveter and a bolter")
	# A ring, by TartanCo's joining rule: its beams and girders welded, then its skin riveted at the
	# plate corners (the hull plates welded along a short seam too); the trades clamp their feet to
	# the work.
	var rings: int = crew.rings_built()
	var clamped := {}
	var jobs := {}
	var t := 0.0
	while crew.rings_built() == rings and t < 900.0:
		traffic.step(0.2)
		crew.step(0.2)
		t += 0.2
		for w: Dictionary in crew.workers:
			var task: Dictionary = w.task
			if not task.is_empty() and not jobs.has(task.kind):
				var c: Dictionary = crew.condition(w.node)
				jobs[task.kind] = "%s|%s|%s" % [c.state, c.job_kind, c.job]
			if not task.is_empty() and task.kind != "fit" and task.phase != "go":
				var foot := (w.node as Node3D).get_node("FootR") as Node3D
				var m: Dictionary = task.member
				var s: Dictionary = crew._span(m)
				# The sole on the member's face: no further off it than the face's own reach.
				var off := (foot.global_position - (s.mid as Vector3)).dot(s.out as Vector3)
				if off > float(s.skin) and off < float(s.skin) + WorkerLook.ANKLE + 0.08:
					clamped[w.role] = true
	check(crew.rings_built() == rings + 1, "a ring went on (%.0f s)" % t)
	check(jobs.has("rivet") and String(jobs.rivet).begins_with("working|rivet|Riveting keel ring") and String(jobs.rivet).contains("rivet 1/4"),
			"a busy bot's condition says what it's on: %s" % str(jobs.values()))
	var heads := {"bolt": 0, "rivet": 0, "bead": 0, "hull": 0, "lining": 0}
	for n in (crew.rings.back() as Node3D).get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh == crew._bolt_mesh:
			heads.bolt += 1
		elif n is MeshInstance3D and (n as MeshInstance3D).mesh == crew._rivet_mesh:
			heads.rivet += 1
		elif _shows(n, "HullPlate"):
			heads.hull += 1
		elif _shows(n, "DeckPlate"):
			heads.lining += 1
		elif n is MeshInstance3D:
			heads.bead += 1
	check(heads.bolt == 0, "no bolts in the frame or skin: beams are welded, plates riveted (%d)" % heads.bolt)
	check(heads.hull == 6 and heads.lining == 4, "the bay skinned: %d hull plates, %d inner linings" % [heads.hull, heads.lining])
	check(heads.rivet == 4 * (heads.hull + heads.lining), "every plate riveted at its four corners (%d rivets)" % heads.rivet)
	check(heads.bead >= 8 * 2 + heads.hull, "beams and girders welded at both ends, each hull plate a short seam (%d beads)" % heads.bead)
	var steps: Array = crew._member_list(true).map(func(m: Dictionary) -> String: return "%s:%s" % [m.part, ",".join(Workers.JOINING.get(m.part, ["bolt"]))])
	check(steps.has("BoxBeam:weld") and steps.has("Girder:weld") and steps.has("HullPlate:rivet,weld") and steps.has("DeckPlate:rivet"),
			"the joining rule: %s" % str(steps))
	check(clamped.has("W") and clamped.has("R"), "welders and riveters clamp on to the work (%s)" % str(clamped.keys()))
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
	var bolts := 0
	for n in ring.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh == crew._bolt_mesh:
			bolts += 1
	check(bolts >= 4 + 2 * 4, "components bolted down, the rack with four bolts (%d bolts)" % bolts)
	check(Workers.fitout_kit(4) == "power" and Workers.fitout_kit(6) == "piping", "fit-outs take turns: power, then pipes (bolted)")
	var pipe: Dictionary = crew._next_spot(crew._mount_spots(), "Pipe")
	check((pipe.joints as Array).size() == 3, "a pipe is bolted on at three clamps")
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
	check(c.state == "faulted" and c.role == String(w.role) and c.has("speed") and c.has("job") and c.has("job_kind"),
			"its condition has the fleet screen's fields: %s" % str(c))
	var busy: Array = crew.workers.filter(func(x: Dictionary) -> bool: return not (x.task as Dictionary).is_empty())
	if not busy.is_empty():
		var bc: Dictionary = crew.condition(busy[0].node)
		check(bc.state == "working" and String(bc.job).contains("keel ring") and bc.job_kind == busy[0].task.kind,
				"a busy bot says what it's on: %s" % bc.job)
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
	# Charging: between jobs each bot hangs on its own dock, built onto a rib of the berth's
	# frame; one run low stays there till it's full, then is back on the work.
	check(crew.has_node("ChargeDocks") and crew.charge_docks.get_child_count() == crew.workers.size(), "a charging dock in the berth's frame for each bot")
	var on_ribs: bool = crew.DOCKS.all(func(d: Vector3) -> bool: return is_equal_approx(fposmod(d.x, 10.0), 0.0) and d.z > -70.5 and d.z < -70.0)
	check(on_ribs, "each dock on a rib of the berth's station-side frame")
	var spots: Array = []
	for i in crew.workers.size():
		spots.append(crew.dock_spot(i))
	var apart := true
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			apart = apart and (spots[i] as Vector3).distance_to(spots[j]) > 3.0
	check(apart, "no two docks close enough for one bot to sit on another")
	var low: Dictionary = crew.workers[4]
	crew._drop_task(low)
	low.charge = 0.1
	var on_dock := false
	t = 0.0
	while t < 90.0 and not on_dock:
		crew.step(0.2)
		t += 0.2
		on_dock = crew._docked(low) and (low.node as Node3D).position.distance_to(crew.dock_spot(int(low.index))) < 0.05
	check(on_dock, "a bot with nothing to do flies to its dock (%.0f s)" % t)
	check(-(low.node as Node3D).basis.z.dot(Vector3.FORWARD) > 0.9, "and hangs there with its back to the frame")
	var dock: Node3D = crew.charge_docks.get_node("Dock%d" % (int(low.index) + 1))
	crew.step(0.2)
	check((dock.get_node("Bar") as Node3D).visible and bool(crew.condition(low.node).charging), "its dock shows it charging")
	check(crew._idle(low.role).is_empty(), "run low, it takes no work")
	t = 0.0
	while t < crew.charge_seconds / 0.8 + 10.0 and bool(low.low):
		crew.step(0.5)
		t += 0.5
	check(not bool(low.low) and is_equal_approx(float(low.charge), 1.0), "till it's full (%.0f s)" % t)
	check(crew._idle(low.role) == low, "then it's ready for work again")
	var paces: Array = crew.workers.map(func(w: Dictionary) -> float: return snappedf(float(w.speed), 0.01))
	var differ := true
	for i in paces.size():
		differ = differ and paces.count(paces[i]) == 1
	check(differ, "every bot has its own pace, so they don't move in unison %s" % str(paces))
	check(crew.workers.all(func(w: Dictionary) -> bool: return w.role == "F" or w.has("sparks")), "welders, riveters and bolters all throw sparks")
	# A finished keel: after a pause it makes way for a new one, and the crew starts again.
	if crew.ring_node:
		crew.ring_node.queue_free()
		crew.ring_node = null
	crew.members.clear()
	crew._fitout = {}
	while crew.rings_built() < Workers.RINGS:
		crew._whole_ring()
	for i in int(crew.keel_pause / 0.5) + 2:
		crew.step(0.5)
	check(crew.rings_built() == crew.start_rings and crew.ring_node != null, "a finished keel makes way for a new one (%d rings)" % crew.rings_built())
	crew.queue_free()
	traffic.queue_free()
	await frames(1)


## Whether `n` is a piece of `part` (it draws the part's body mesh).
func _shows(n: Node, part: String) -> bool:
	var body: Mesh = (preload("res://modules/yard/internal/yard_stock_look.gd").layers(part)[0] as Dictionary).mesh
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh == body:
			return true
	return false
