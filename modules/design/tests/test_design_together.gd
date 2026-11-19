extends ModuleTest
## Designing together (Wave 3): one design open for the whole session. Every player's edit
## goes to the host, which puts them in one order and applies them on every machine; each
## player undoes only their own edits; opening a design opens it for everyone; a player who
## joins late gets the open design. Two design rooms here talk through a stand-in for the
## multiplayer module that holds messages until pumped, as a network would.
##   tools/run_tests.sh design

const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")
const WallBoard := preload("res://modules/design/internal/room/wall_board.gd")
const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")


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

	var movers: Dictionary = {}

	func register_mover(object_id: String, node: Node3D) -> void:
		movers[object_id] = node

	func unregister_mover(object_id: String) -> void:
		movers.erase(object_id)

	func player_name(peer_id: int) -> String:
		return {1: "Ana", 7: "Ben", 9: "Cal"}.get(peer_id, "Crew")

	func player_colour(peer_id: int) -> Color:
		return Color.ORANGE if peer_id == 1 else Color.CYAN


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

	# Saved modules and designs are shared (beenster, 19 Nov: the other player could not see one).
	var bridge_id: String = a.rooms.keys()[0]
	var mid: String = ana.bus.library.save_module("Ana's bridge", bridge_id)
	hub.pump()
	check(ben.bus.library.modules().any(func(m): return m.name == "Ana's bridge"), "a module Ana saves shows in Ben's list")
	check(ana.bus.library.modules().size() == 1, "and Ana keeps one copy, not an echo: %s" % [ana.bus.library.module(mid)])
	ana.bus.library.save_current()
	hub.pump()
	check(ben.bus.library.list().any(func(r): return r.name == "Shared skiff"), "a design Ana saves shows in Ben's designs")

	# Each undoes only their own.
	ben.bus.editor.undo()
	hub.pump()
	var types: Array = a.rooms.values().map(func(r): return str(r.type))
	check(types == ["bridge"] and _same(a, b), "Ben's undo takes back his cargo hold, not Ana's bridge: %s" % [types])
	check(not ben.bus.editor.can_undo() and ana.bus.editor.can_undo(), "Ana can still undo hers, Ben has nothing left")
	ben.bus.editor.redo()
	hub.pump()
	check(a.rooms.size() == 2 and _same(a, b), "Ben's redo puts it back for everyone")

	# Who did what: Ana sees Ben's edits named, never her own.
	var seen: Array = []
	ana.bus.crew_edited.connect(func(who, _c, what): seen.append("%s %s" % [who, what]))
	ben.bus.editor.do({"op": "add_room", "room": {"type": "quarters", "deck": 1, "x": 0, "z": -2, "w": 4, "d": 4}})
	ana.bus.editor.do({"op": "set_meta", "fields": {"name": "Shared skiff Mk2"}})
	hub.pump()
	check(seen == ["Ben added Crew quarters"], "Ana's console says what Ben did: %s" % [seen])

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

	# Walking about together: Ana in walk-inside sees Ben there, named, in his colour.
	var room := Node3D.new()
	add_child(room)
	var f := Furnishing.new()
	room.add_child(f)
	f.setup(ana.bus, Furnishing.stand_in_walls())
	f.open_walk()
	await frames(2)
	hub.pump()
	check(ben.bus.walkers.has(1), "Ben's machine knows Ana is walking inside")
	check(ana.net.movers.has("player:1:walk"), "Ana's walk streams to the crew")
	ben.bus.set_walking(true)
	hub.pump()
	var fig: Node3D = f.walk.find_child("Crew_7", true, false)
	check(fig != null and (fig.find_child("Name", true, false) as Label3D).text == "Ben", "Ben walks in and Ana sees him, named")
	check(ana.net.movers.get("player:7:walk") == fig, "his figure follows his walk")
	ben.bus.set_walking(false)
	hub.pump()
	await frames(1)
	check(f.walk.find_child("Crew_7", true, false) == null, "he steps out and is gone")
	f.close_walk()
	hub.pump()
	check(not ben.bus.walkers.has(1), "Ana leaving walk-inside tells the others")
	room.queue_free()
	await frames(2)

	# The room's screens are the same for everyone (beenster, 19 Nov co-op test: "the screens
	# are not synchronized"): a wall panel's view and the holotable's layers, cut and turn.
	var boards: Array = []
	var holos: Array = []
	for r: Dictionary in [ana, ben]:
		var wb := WallBoard.new()
		add_child(wb)
		wb.setup(r.bus, "left", [["plan:0", 1.0], ["data", 1.0]], 40.0)
		boards.append(wb)
		var ht := HoloTable.new()
		add_child(ht)
		ht.setup(r.bus)
		ht.share()
		holos.append(ht)
	(boards[0] as WallBoard).set_view(0, "side")
	(holos[0] as HoloTable).set_layer("wiring", true)
	(holos[0] as HoloTable).set_cut(0.5)
	(holos[0] as HoloTable).turn = 1.25
	await frames(2)
	hub.pump()
	check(str((boards[1] as WallBoard).panels[0].view) == "side", "Ana puts the side view on the left wall; Ben sees it there")
	check(bool((holos[1] as HoloTable).layers.wiring) and is_equal_approx((holos[1] as HoloTable).cut, 0.5),
			"Ana's wiring layer and cut show on Ben's table")
	check(is_equal_approx((holos[1] as HoloTable).turn, 1.25), "and the table turns for him too")
	(boards[1] as WallBoard).step(1, 1)
	hub.pump()
	check((boards[0] as WallBoard).panels[1].view == (boards[1] as WallBoard).panels[1].view,
			"Ben steps a panel on; Ana's follows: %s" % (boards[0] as WallBoard).panels[1].view)
	var dan := _room(hub, 11)
	hub.join(dan.net)
	check(str((dan.bus as DesignBus).screens.get("wall:left:0", "")) == "side" and bool((dan.bus as DesignBus).screens.get("holo.layer.wiring", false)),
			"a late joiner gets the screens as they are")
	for n: Node in boards + holos:
		n.queue_free()
	await frames(2)
	for r: Dictionary in [ana, ben, cal, dan]:
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
