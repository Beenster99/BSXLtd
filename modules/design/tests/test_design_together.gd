extends ModuleTest
## Designing together (Wave 3): one design open for the whole session. Every player's edit
## goes to the host, which puts them in one order and applies them on every machine; each
## player undoes only their own edits; opening a design opens it for everyone; a player who
## joins late gets the open design. Two design rooms here talk through a stand-in for the
## multiplayer module that holds messages until pumped, as a network would.
##   tools/run_tests.sh design


class Hub:
	## Peers in join order; the first is the host. Requests wait in `queue` until pump().
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

	func join(n: Net) -> void:
		nets.append(n)
		if nets.size() > 1:
			for section: String in (nets[0] as Net).snapshots:
				var data: Dictionary = (nets[0] as Net).snapshots[section].get_net_snapshot()
				n.snapshots[section].apply_net_snapshot(data.duplicate(true))


class Net:
	var hub: Hub
	var id := 1
	var events: Dictionary = {}
	var snapshots: Dictionary = {}

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


func run_tests() -> void:
	var hub := Hub.new()
	var ana := _room(hub, 1)
	var ben := _room(hub, 7)
	hub.join(ana.net)
	ana.bus.library.create("Shared skiff")
	hub.pump()
	hub.join(ben.net)
	check(ben.bus.library.current != null and ben.bus.library.current.name == "Shared skiff",
			"joining, Ben gets the design Ana has open")

	# Both edit at once: the host orders them, and both end up with the same design.
	ana.bus.editor.do({"op": "add_room", "room": {"type": "bridge", "deck": 0, "x": 0, "z": -6, "w": 4, "d": 3}})
	ben.bus.editor.do({"op": "add_room", "room": {"type": "cargo", "deck": 0, "x": 0, "z": 0, "w": 6, "d": 6}})
	check(ben.bus.library.current.rooms.is_empty(), "Ben's edit waits for the host, like a real network")
	hub.pump()
	var a: DesignRecord = ana.bus.library.current
	var b: DesignRecord = ben.bus.library.current
	check(a.rooms.size() == 2 and _same(a, b), "both edits land on both machines, the same: %d rooms" % a.rooms.size())
	check(a.rooms.keys() == b.rooms.keys(), "the same ids everywhere: %s %s" % [a.rooms.keys(), b.rooms.keys()])

	# Each undoes only their own.
	ben.bus.editor.undo()
	hub.pump()
	var types: Array = a.rooms.values().map(func(r): return str(r.type))
	check(types == ["bridge"] and _same(a, b), "Ben's undo takes back his cargo hold, not Ana's bridge: %s" % [types])
	check(not ben.bus.editor.can_undo() and ana.bus.editor.can_undo(), "Ana can still undo hers, Ben has nothing left")
	ben.bus.editor.redo()
	hub.pump()
	check(a.rooms.size() == 2 and _same(a, b), "Ben's redo puts it back for everyone")

	# A player who joins late gets the design as it is now.
	var cal := _room(hub, 9)
	hub.join(cal.net)
	check(_same(cal.bus.library.current, a), "Cal joins late and sees both rooms")
	cal.bus.editor.do({"op": "add_door", "door": {"a": a.rooms.keys()[0], "b": a.rooms.keys()[1], "deck": 0, "x": 2, "z": 0}})
	hub.pump()
	check(a.doors.size() == 1 and _same(a, b) and _same(a, cal.bus.library.current), "Cal's door reaches everyone")

	# Opening another design opens it for everyone.
	ben.bus.library.create("Ben's tug")
	hub.pump()
	check(ana.bus.library.current.name == "Ben's tug" and cal.bus.library.current.name == "Ben's tug",
			"Ben opens a new design and everyone moves to it")
	ana.bus.editor.do({"op": "add_room", "room": {"type": "engineering", "deck": 0, "x": 0, "z": 0, "w": 5, "d": 5}})
	hub.pump()
	check(ben.bus.library.current.rooms.size() == 1, "and Ana's edit lands in it on Ben's machine")
	for r: Dictionary in [ana, ben, cal]:
		(r.bus as DesignBus).free()


func _room(hub: Hub, id: int) -> Dictionary:
	var net := Net.new()
	net.hub = hub
	net.id = id
	var bus := DesignBus.new()
	bus.hook_net(net)
	return {"bus": bus, "net": net}


static func _same(x: DesignRecord, y: DesignRecord) -> bool:
	if x == null or y == null:
		return false
	var a := x.to_dict()
	var b := y.to_dict()
	a.erase("id")
	b.erase("id")
	return a == b
