extends ModuleTest
## The crew see and hear each other's tools (beenster's 0.3.16 two-player playtest), through
## a stand-in for Multiplayer's bus: your hands and what you hold go out; a crewmate's tool
## shows in their avatar's hand with its sound and their shield; dropped bolts and the
## stand's joints match; a late joiner gets the stand from the snapshot.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const FAKE_NET := """extends Node
signal held_changed(peer_id: int, held: Dictionary)
signal avatar_added(peer_id: int, avatar: Node3D)
var hands := []
var held_sent := {}
var requests := []
var events := {}
var providers := {}
var heads := {}
var hand_nodes := {}
func is_online() -> bool: return true
func local_peer_id() -> int: return 1
func set_local_hands(right: Node3D, left: Node3D) -> void: hands = [right, left]
func set_held(state: Dictionary) -> void: held_sent = state
func held(_peer: int) -> Dictionary: return {}
func register_event(n: String, apply: Callable, validate := Callable()) -> void: events[n] = [apply, validate]
func unregister_event(n: String) -> void: events.erase(n)
func request(n: String, payload: Dictionary = {}) -> void: requests.append([n, payload])
func register_snapshot_provider(section: String, p: Object) -> void: providers[section] = p
func unregister_snapshot_provider(section: String) -> void: providers.erase(section)
func avatar_hand(peer: int, _right := true) -> Node3D:
	if not hand_nodes.has(peer):
		var h := Node3D.new()
		add_child(h)
		hand_nodes[peer] = h
	return hand_nodes[peer]
func avatar_head(peer: int) -> Node3D:
	if not heads.has(peer):
		var h := Node3D.new()
		add_child(h)
		heads[peer] = h
	return heads[peer]
"""


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in ["trades.test_stand", "trades.crew_tools", "trades.power_wrench"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	ship_bus.load_ship("vs_kestrel")
	var yard := _make(FAKE_YARD, Node3D.new()) as Node3D
	var walker := CharacterBody3D.new()
	yard.set("walker", walker)
	yard.add_child(walker)
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var station := rig.ship_station()
	var net := _make(FAKE_NET, Node.new())
	add_child(net)
	var crew := TradesCrew.new()
	crew.bay = rig
	rig.add_child(crew)
	# The bay's own crew (when Multiplayer is loaded) steps aside for the stand-in.
	if rig.crew:
		rig.crew.stop()
	rig.crew = crew
	crew.start(net)

	# Your hands and what you hold go to the crew.
	var hands: Array = net.get("hands")
	check(hands.size() == 2 and hands[0] == rig.worker.right_hand and hands[1] == rig.worker.left_hand, "your hands stream to the crew")
	rig.set_tool(&"welder")
	rig.loop(&"arc", true)
	crew._process(0.0)
	var sent: Dictionary = net.get("held_sent")
	check(sent.get("tool") == "welder" and sent.get("sound") == "arc", "what you hold and its sound go out: %s" % sent)
	rig.loop(&"arc", false)
	crew._process(0.0)
	check((net.get("held_sent") as Dictionary).get("sound") == "", "and the sound stops with yours")

	# A crewmate's power wrench in their avatar's hand, running, with their shield down.
	net.emit_signal("held_changed", 7, {"tool": "torque_wrench", "sound": "impact", "helmet": true})
	var theirs := crew.crew_tool(7)
	check(theirs is TradesPowerWrench and theirs.get_parent() == net.call("avatar_hand", 7, true), "their wrench is in their avatar's hand")
	check(crew.crew_sound(7) == &"impact", "with its rattle")
	var r: Dictionary = rig.remote_torches.get(7, {})
	check(is_instance_valid(r.get("helmet")) and bool(r.get("crew_shield")), "and their shield on their head, down")
	net.emit_signal("held_changed", 7, {"tool": "welder", "sound": "", "helmet": false})
	await frames(1)
	check(crew.crew_tool(7) is TradesWeldTorch and not is_instance_valid(theirs), "they swap to the welder: the wrench goes")
	check(crew.crew_sound(7) == &"" and not bool(rig.remote_torches[7].crew_shield), "quiet, shield up")
	net.emit_signal("held_changed", 1, {"tool": "welder"})
	check(crew.crew_tool(1) == null, "your own never shows on you")

	# A bolt you take out falls for the crew; theirs falls here.
	var b := -1
	for i in station.points.size():
		var f := station.points[i]
		if TradesShipJoints.is_practice(f) and f.kind == "bolt" and station.is_tight(f):
			b = i
			break
	(net.get("requests") as Array).clear()
	station._note_removed(station.points[b])
	var names := (net.get("requests") as Array).map(func(q: Array) -> String: return q[0])
	check(names.has(TradesCrew.POP_EVENT) and names.has(TradesCrew.PRACTICE_EVENT), "a bolt out: its fall and the stand's state go out (%s)" % [names])
	var pops := rig.sparks.pop_count()
	var events: Dictionary = net.get("events")
	var apply_pop: Callable = events[TradesCrew.POP_EVENT][0]
	var validate_pop: Callable = events[TradesCrew.POP_EVENT][1]
	apply_pop.call(validate_pop.call(7, {"kind": "rivet_hot", "at": station.points_world[b], "vel": Vector3.UP}))
	check(rig.sparks.pop_count() == pops + 1, "a crewmate's hot rivet head falls here")
	apply_pop.call(validate_pop.call(1, {"kind": "bolt", "at": station.points_world[b], "vel": Vector3.UP}))
	check(rig.sparks.pop_count() == pops + 1, "your own isn't dropped twice")
	check(validate_pop.call(7, {"kind": "bolt"}) is String, "a fall with no position is refused")

	# Their stand joint made shows made here, and a late joiner gets the stand as it is.
	var id := station.points[b].joint_id
	var apply_practice: Callable = events[TradesCrew.PRACTICE_EVENT][0]
	var validate_practice: Callable = events[TradesCrew.PRACTICE_EVENT][1]
	apply_practice.call(validate_practice.call(7, {"id": id, "made": true}))
	check(station.is_tight(station.points[b]), "a crewmate's bolt in on the stand is in here")
	var snap := crew.get_net_snapshot()
	station.set_practice(id, false)
	(net.get("providers") as Dictionary)[TradesCrew.SECTION].call("apply_net_snapshot", snap)
	check(station.is_tight(station.points[b]), "a late joiner's stand matches")

	# Leaving the yard: hands back, their tools gone.
	crew.stop()
	await frames(1)
	hands = net.get("hands")
	check(hands == [null, null] and crew.crew_tool(7) == null, "leaving: hands withdrawn, their tools gone")
	rig.crew = null

	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])
	yard.queue_free()
	net.queue_free()
	await frames(1)


func _make(source: String, node: Node) -> Node:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	node.set_script(script)
	return node
