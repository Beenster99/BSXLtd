extends ModuleTest
## The crew on the drawings (beenster, 19 Nov): each player's mouse on a plan shows on the
## others' plans in their colour with their name; a friend walking inside shows on the plans
## and the holotable; smart pings mark a spot for everyone, labelled with what is there.
## Two design rooms talk through a stand-in for the multiplayer module.
##   tools/run_tests.sh design

const Crew := preload("res://modules/design/internal/crew/design_crew.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")
const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")


class Hub:
	var nets: Array = []
	var queue: Array = []

	func pump() -> void:
		while not queue.is_empty():
			var q: Array = queue.pop_front()
			var host: Net = nets[0]
			var entry: Dictionary = host.events[q[1]]
			var out: Variant = entry.validate.call(q[0], q[2]) if entry.validate.is_valid() else q[2]
			if out is Dictionary:
				for n: Net in nets:
					(n.events[q[1]].apply as Callable).call((out as Dictionary).duplicate(true))

	## Movers: every player's own stream reaches the others' copies, as the session does.
	func stream() -> void:
		for a: Net in nets:
			for id: String in a.movers:
				if id.begins_with("player:%d:" % a.id):
					for b: Net in nets:
						if b != a and b.movers.has(id):
							(b.movers[id] as Node3D).transform = (a.movers[id] as Node3D).transform


class Net:
	var hub: Hub
	var id := 1
	var events: Dictionary = {}
	var snapshots: Dictionary = {}
	var movers: Dictionary = {}

	func register_event(event_name: String, apply: Callable, validate := Callable()) -> void:
		events[event_name] = {"apply": apply, "validate": validate}

	func unregister_event(event_name: String) -> void:
		events.erase(event_name)

	func register_snapshot_provider(section: String, provider: Object) -> void:
		snapshots[section] = provider

	func unregister_snapshot_provider(section: String) -> void:
		snapshots.erase(section)

	func request(event_name: String, payload: Dictionary = {}) -> void:
		hub.queue.append([id, event_name, payload.duplicate(true)])

	func local_peer_id() -> int:
		return id

	func is_online() -> bool:
		return true

	func peers() -> Dictionary:
		var out := {}
		for n: Net in hub.nets:
			out[n.id] = {}
		return out

	func register_mover(object_id: String, node: Node3D) -> void:
		movers[object_id] = node

	func unregister_mover(object_id: String) -> void:
		movers.erase(object_id)

	func player_name(peer_id: int) -> String:
		return {1: "Ana", 7: "Ben"}.get(peer_id, "Crew")

	func player_colour(peer_id: int) -> Color:
		return Color.ORANGE if peer_id == 1 else Color.CYAN


func run_tests() -> void:
	var hub := Hub.new()
	var ana := _room(hub, 1)
	var ben := _room(hub, 7)
	hub.nets = [ana.net, ben.net]
	for r: Dictionary in [ana, ben]:
		var crew: Node = (r.bus as DesignBus).crew
		crew.call("hook", r.net)
	var a_crew: Node = (ana.bus as DesignBus).crew
	var b_crew: Node = (ben.bus as DesignBus).crew
	check(ana.net.movers.has("player:1:design") and ana.net.movers.has("player:7:design"),
			"Ana streams her own spot and follows Ben's")

	var rec: DesignRecord = (ana.bus as DesignBus).library.create("Crew test")
	rec.apply({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": 0, "z": 0, "w": 6, "d": 6}})
	rec.apply({"op": "add_room", "room": {"type": "quarters", "deck": 1, "x": 0, "z": 0, "w": 4, "d": 4}})
	(ben.bus as DesignBus).library.adopt(rec.to_dict())
	await frames(1)

	# Cursors: Ana's mouse on the plan shows on Ben's, on her deck, named in her colour.
	a_crew.call("set_cursor", 0, Vector2(2.5, 3.0))
	hub.stream()
	var seen: Array = b_crew.call("crew")
	check(seen.size() == 1 and int(seen[0].state) == Crew.CURSOR and str(seen[0].name) == "Ana"
			and (seen[0].at as Vector3).is_equal_approx(Vector3(2.5, 0, 3)) and int(seen[0].deck) == 0,
			"Ben sees Ana's cursor at her spot on deck 1: %s" % [seen])
	check((a_crew.call("crew") as Array).is_empty(), "Ana does not see her own")
	a_crew.call("set_cursor", 1, Vector2(1, 1))
	hub.stream()
	seen = b_crew.call("crew")
	check(int(seen[0].deck) == 1, "she moves to the upper deck and it follows: deck %d" % int(seen[0].deck))
	a_crew.call("clear_cursor")
	hub.stream()
	check((b_crew.call("crew") as Array).is_empty(), "her mouse leaves the plan and the cursor goes")

	# Walking inside shows on the plans with the way she faces, and wins over a cursor.
	a_crew.call("set_cursor", 0, Vector2(1, 1))
	a_crew.call("walk_at", Vector3(3, 0.9, 2), PI * 0.5)
	hub.stream()
	seen = b_crew.call("crew")
	check(seen.size() == 1 and int(seen[0].state) == Crew.WALKING and absf(float(seen[0].yaw) - PI * 0.5) < 0.01,
			"Ben sees Ana walking inside, facing her way: %s" % [seen])
	a_crew.call("advance", Crew.WALK_TIMEOUT + 0.1)
	hub.stream()
	seen = b_crew.call("crew")
	check(seen.size() == 1 and int(seen[0].state) == Crew.CURSOR, "she steps out and is back to her cursor")
	a_crew.call("clear_cursor")

	# Smart pings: what is there, for everyone, one every PING_GAP, at most PINGS_EACH each.
	var what: Dictionary = a_crew.call("describe", 0, Vector2(2, 2))
	check(what.kind == "room" and str(what.label) == "Cargo hold", "a ping on a room says its name: %s" % [what])
	a_crew.call("ping", 0, Vector3(2, 1.5, 2), what.label, what.kind, what.ref)
	hub.pump()
	var bp: Array = b_crew.get("pings")
	check(bp.size() == 1 and str(bp[0].label) == "Cargo hold" and str(bp[0].name) == "Ana" and bp[0].colour == Color.ORANGE,
			"Ben sees Ana's ping, named and in her colour: %s" % [bp])
	a_crew.call("ping", 0, Vector3(1, 1.5, 1), "Here")
	hub.pump()
	check((b_crew.get("pings") as Array).size() == 1, "a second ping straight after is held back by the host")
	for i in Crew.PINGS_EACH + 2:
		a_crew.call("advance", Crew.PING_GAP + 0.01)
		b_crew.call("advance", Crew.PING_GAP + 0.01)
		a_crew.call("ping", 0, Vector3(i, 1.5, 0), "Spot %d" % i)
		hub.pump()
	check((b_crew.get("pings") as Array).size() == Crew.PINGS_EACH, "only her newest %d stay" % Crew.PINGS_EACH)
	b_crew.call("advance", Crew.PING_LIFE)
	a_crew.call("advance", Crew.PING_LIFE)
	check((b_crew.get("pings") as Array).is_empty(), "pings fade away after %d s" % int(Crew.PING_LIFE))
	check(str((a_crew.call("describe", 0, Vector2(30, 30)) as Dictionary).label) == "Here", "a ping on bare grid says Here")

	# On a real plan: the overlay sits on it, and a middle-click tap pings what is under it.
	var view: Control = PlanView.new()
	view.size = Vector2(800, 600)
	add_child(view)
	view.call("setup", ben.bus, PlanView.PLAN, true)
	view.set("centre", Vector2(3, 3))
	await frames(1)
	check(view.get_node_or_null("CrewMarks") != null, "every plan gets the crew drawn over it")
	var spot: Vector2 = view.call("to_screen", Vector2(1.5, 4.5))
	b_crew.call("advance", 1.0)
	_click(view, spot, true)
	_click(view, spot, false)
	hub.pump()
	var ap: Array = a_crew.get("pings")
	check(ap.size() == 1 and str(ap[0].label) == "Cargo hold" and str(ap[0].name) == "Ben"
			and absf(float(ap[0].x) - 1.5) < 0.01 and absf(float(ap[0].z) - 4.5) < 0.01,
			"Ben's tap on the plan pings the cargo hold for Ana: %s" % [ap])
	var side: Control = PlanView.new()
	side.size = Vector2(600, 400)
	add_child(side)
	side.call("setup", ben.bus, PlanView.SIDE, false)
	await frames(1)
	check(side.get_node_or_null("CrewMarks") != null, "the side view shows the crew too")

	# The holotable: marks ride over the hologram, and a look at it finds the deck floor.
	var holo: Node3D = HoloTable.new()
	add_child(holo)
	holo.call("setup", ana.bus)
	a_crew.call("attach_holo", holo)
	await frames(3)
	a_crew.call("_process", 0.0)
	var marks: Node3D = holo.get_node_or_null("CrewMarks")
	check(marks != null and marks.get_child_count() == 1, "Ben's ping shows over Ana's hologram")
	var ship: Node3D = (holo.get("model") as Node3D).get_node("Ship")
	var target: Vector3 = ship.global_transform * Vector3(2, 0, 2)
	var hit: Dictionary = a_crew.call("holo_hit", target + Vector3(0, 2, 1.5), (target - (target + Vector3(0, 2, 1.5))).normalized())
	check(not hit.is_empty() and int(hit.deck) == 0 and Vector2(hit.at.x, hit.at.z).distance_to(Vector2(2, 2)) < 0.05,
			"looking at the hologram finds the cargo hold's floor: %s" % [hit])
	var high: Vector3 = ship.global_transform * Vector3(1, (ana.bus as DesignBus).library.current.deck_height, 1)
	hit = a_crew.call("holo_hit", high + Vector3(0, 2, 0.5), (high - (high + Vector3(0, 2, 0.5))).normalized())
	check(not hit.is_empty() and int(hit.deck) == 1, "looking down on the upper deck finds it first: %s" % [hit])

	view.queue_free()
	side.queue_free()
	holo.queue_free()
	await frames(2)
	for r: Dictionary in [ana, ben]:
		(r.bus as DesignBus).free()


func _click(view: Control, at: Vector2, down: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_MIDDLE
	mb.pressed = down
	mb.position = at
	view.gui_input.emit(mb)


func _room(hub: Hub, id: int) -> Dictionary:
	var net := Net.new()
	net.hub = hub
	net.id = id
	var bus := DesignBus.new()
	bus.hook_net(net)
	return {"bus": bus, "net": net}
