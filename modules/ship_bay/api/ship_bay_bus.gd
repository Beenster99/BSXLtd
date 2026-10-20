class_name ShipBayBus
extends Node
## Ship and Bay module bus (Modules.bus("ship_bay")). Loads a ship into a bay, knows where
## every part attaches (mount slots and their fasteners), and tracks each slot from fitted
## to stripped to installed.
##
## Methods are requests and the signals are the results; Multiplayer will run the requests
## on the host and replay the signals. Trades sits above this module, so it reports its work
## here (note_joint_made / note_joint_removed) rather than this module listening to it.
## Doc: https://claude.ai/code/artifact/90dd6ae6-1824-4c96-b030-11772e90cd28

enum SlotState { FITTED, LOOSENED, EMPTY, POSITIONED, INSTALLED }

signal ship_loaded(ship_id: String)
signal ship_unloaded(ship_id: String)
signal slot_state_changed(slot_id: String, old_state: SlotState, new_state: SlotState)
signal component_removed(slot_id: String, component: String)
signal component_positioned(slot_id: String, component: String)
signal component_installed(slot_id: String, component: String)
## The ship in the bay was powered up (shore power on) or down.
signal ship_power_changed(on: bool)
## Business delivered an order: a crate per line, set down in the Deliveries hall.
signal delivery_landed(order_id: String, crate_ids: PackedStringArray)
## A delivered crate's goods were put away on a storage location.
signal crate_stored(crate_id: String, location_id: String)
## A hover trolley picked a delivered crate up (trolley "s", "m" or "l").
signal crate_carried(crate_id: String, trolley_id: String)
## The picking lift took goods off a shelf for someone (a "pick/<n>" crate it now carries).
signal stock_picked(crate_id: String, location_id: String)
## Someone took a picked crate off its trolley: those goods have left the stores.
signal crate_collected(crate_id: String, item_id: String, qty: int)
## A hover trolley was told to do something (see command_trolley); the yard's fleet acts.
signal trolley_command(trolley_id: String, command: String, args: Dictionary)
## Anything in the stores changed (crates landed or put away, stock taken, a load).
signal stock_changed
## The shipyard scene has built itself; add your own nodes to `yard` (at shipyard_spot()s).
signal shipyard_ready(yard: Node3D)

## Router scene id of the bay (registered while the "ship_bay.bay_view" flag is on).
const BAY_SCENE := "ship_bay.bay"
## Router scene id of the shipyard round the bay (registered while "ship_bay.shipyard" is on).
const SHIPYARD_SCENE := "ship_bay.shipyard"
const SAVE_VERSION := 2
## The yard's hover trolleys, small, medium and large, and "p" the picking lift in the
## stores. Their Multiplayer mover ids are "trolley:<id>"; claim one to drive it by remote
## control.
const TROLLEYS: PackedStringArray = ["s", "m", "l", "p"]
const TROLLEY_COMMANDS: PackedStringArray = ["come", "put_away", "park", "stop", "deck", "fetch", "deliver"]
## Ship id -> its folder (layout, fasteners, model).
const SHIPS := {"vs_kestrel": "res://modules/ship_bay/internal/ships/kestrel"}

const LayoutLoader := preload("res://modules/ship_bay/internal/layout_loader.gd")
const SlotTracker := preload("res://modules/ship_bay/internal/slot_tracker.gd")
const Shipyard := preload("res://modules/ship_bay/internal/yard/shipyard.gd")
const StorageLayout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
const StorageStock := preload("res://modules/ship_bay/internal/storage/storage_stock.gd")

## The ship in the bay, or null.
var ship: ShipDefinition
var _tracker: SlotTracker
var _definitions: Dictionary = {}
## Whether the ship in the bay is on shore power (its lamps, screens and systems live).
var ship_powered := false
var _stock := StorageStock.new()
## The Multiplayer bus when that module is loaded (used by duck typing, so Ship and Bay
## runs without it: tests that switch only part of the game on, and solo builds).
var _net: Node


func register_module() -> void:
	Saves.register_section("ship_bay", self)
	# Multiplayer may load after this module, so its events are hooked up once all are in.
	if Modules.ready_done:
		_hook_net()
	elif not Modules.modules_ready.is_connected(_hook_net):
		Modules.modules_ready.connect(_hook_net, CONNECT_ONE_SHOT)
	if Flags.is_on("ship_bay.bay_view"):
		Router.register_scene(BAY_SCENE, "res://modules/ship_bay/internal/bay/bay.tscn")
		Shots.register("kestrel_in_bay", BAY_SCENE)
	if Flags.is_on("ship_bay.shipyard"):
		Router.register_scene(SHIPYARD_SCENE, "res://modules/ship_bay/internal/yard/shipyard.tscn")
		Menu.set_start(SHIPYARD_SCENE, 10)   # the game starts in the yard
		for view: String in ["overview", "courtyard", "deliveries", "stock", "prep", "preassembly",
				"kestrel_front", "kestrel_stern", "kestrel_rivets", "kestrel_cabin", "kestrel_hold",
				"kestrel_access", "kestrel_lift", "storage_aisle", "storage_bins", "storage_bulk",
				"dock", "overlook", "launch_towers"]:
			Shots.register("shipyard_" + view, SHIPYARD_SCENE,
					func(scene: Node) -> void: scene.call("show_view", view))
		Shots.register("shipyard_night", SHIPYARD_SCENE, func(scene: Node) -> void:
			scene.call("set_time_of_day", 22.0)
			scene.call("show_view", "courtyard"))
		# A sample delivery in the hall, then some of it put away (these change the stores).
		Shots.register("shipyard_goods_in", SHIPYARD_SCENE, func(scene: Node) -> void:
			_sample_delivery()
			scene.call("show_view", "goods_in"))
		Shots.register("shipyard_storage_stocked", SHIPYARD_SCENE, func(scene: Node) -> void:
			_sample_delivery()
			for id: String in delivered_crates():
				if not id.ends_with("/1"):
					store_crate(id)
			scene.call("show_view", "storage_aisle_d"))
		Shots.register("shipyard_trolleys", SHIPYARD_SCENE, func(scene: Node) -> void:
			_sample_delivery()
			scene.call("show_view", "trolleys"))
		# The medium trolley in aisle D with a crate raised to the fourth shelf.
		Shots.register("shipyard_trolley_lift", SHIPYARD_SCENE, func(scene: Node) -> void:
			var fleet: Node = scene.get("trolleys")
			var m: Node = (fleet.get("trolleys") as Dictionary)["m"]
			m.call("set_cargo", {"crate_id": "shot", "kind": "pallet", "mass": 311.0, "name": "Ion thruster"})
			m.call("pose", Vector3(-10.95, 0, -33.95), 0.0, 5.61)
			scene.call("show_view", "trolley_lift"))
		# The picking lift in aisle B reaching into the top shelf.
		Shots.register("shipyard_picking_lift", SHIPYARD_SCENE, func(scene: Node) -> void:
			var lift: Node = ((scene.get("trolleys") as Node).get("trolleys") as Dictionary)["p"]
			lift.call("set_cargo", {"crate_id": "shot", "kind": "pallet", "mass": 250.0, "name": "Gyroscope"})
			lift.call("pose", Vector3(StorageLayout.aisle_x("B"), 0, StorageLayout.bay_z(2)), 0.0, StorageLayout.level_y(StorageLayout.LEVELS))
			lift.call("reach", true, signf(StorageLayout.rack_x("B1") - StorageLayout.aisle_x("B")))
			lift.set("fork_out", 0.99)
			scene.call("show_view", "picking_lift"))


func _hook_net() -> void:
	var net := Modules.bus("multiplayer")
	if net == null or not net.has_method("register_event") or net == _net:
		return
	_net = net
	_net.call("register_event", "ship_bay.delivery", _apply_delivery, _host_only)
	_net.call("register_event", "ship_bay.store_crate", _apply_store, _check_store)
	_net.call("register_event", "ship_bay.take_stock", _apply_take, _check_take)
	_net.call("register_event", "ship_bay.trolley_carry", _apply_carry, _check_carry)
	_net.call("register_event", "ship_bay.trolley", _apply_trolley, _check_trolley)
	_net.call("register_event", "ship_bay.pick", _apply_pick, _check_pick)
	_net.call("register_event", "ship_bay.hand", _apply_hand, _check_hand)
	_net.call("register_event", "ship_bay.collect", _apply_collect, _check_collect)
	_net.call("register_snapshot_provider", "ship_bay", self)


func unregister_module() -> void:
	Saves.unregister_section("ship_bay")
	if _net:
		for e: String in ["ship_bay.delivery", "ship_bay.store_crate", "ship_bay.take_stock",
				"ship_bay.trolley_carry", "ship_bay.trolley", "ship_bay.pick", "ship_bay.hand",
				"ship_bay.collect"]:
			_net.call("unregister_event", e)
		_net.call("unregister_snapshot_provider", "ship_bay")
		_net = null
	Menu.clear_start(SHIPYARD_SCENE)


## The shipyard's rooms in work order: id -> {name, box (AABB, metres, yard space with the
## courtyard centred on the origin, north -Z)}. "deliveries", "stock", "prep",
## "preassembly", and "bay" (the courtyard the ship sits in).
func shipyard_rooms() -> Dictionary:
	return Shipyard.ROOMS.duplicate(true)


## A clear work place in the shipyard ("bench_preassembly", "bench_prep"): origin on the
## floor, +Z towards where the worker stands. Identity for an unknown id.
func shipyard_spot(id: String) -> Transform3D:
	return Shipyard.SPOTS.get(id, Transform3D.IDENTITY)


## Hands the shipyard's walker over (on = false: it stops where it is, leaves the mouse and
## keys alone and its camera stands down) or takes it back (true), for a module that puts
## its own worker and camera in the yard. `yard` is the node shipyard_ready handed you.
func set_walker_active(yard: Node3D, on: bool) -> void:
	if yard and yard.has_method("set_walker_active"):
		yard.call("set_walker_active", on)


## Where the shipyard's walker stands (its feet, yard space), or Vector3.ZERO without one.
func walker_position(yard: Node3D) -> Vector3:
	var walker := yard.get("walker") as Node3D if yard else null
	return walker.position if walker else Vector3.ZERO


## Ship space (the loaded ship's own frame: FastenerPoint positions and normals) to yard
## space, for the ship sitting in the yard's bay; identity without one.
func ship_transform(yard: Node3D) -> Transform3D:
	var bay_node := yard.get("bay") as Node3D if yard else null
	var ship_node := bay_node.get("ship_root") as Node3D if bay_node else null
	if ship_node == null:
		return Transform3D.IDENTITY
	return bay_node.transform * ship_node.transform


## The same as ship_transform.
func ship_to_yard(yard: Node3D) -> Transform3D:
	return ship_transform(yard)


## Ships BSX can take into a bay.
func ship_ids() -> PackedStringArray:
	return PackedStringArray(SHIPS.keys())


## The definition of a known ship (read once, then cached), or null.
func definition(ship_id: String) -> ShipDefinition:
	if not _definitions.has(ship_id) and SHIPS.has(ship_id):
		_definitions[ship_id] = LayoutLoader.load_ship(SHIPS[ship_id])
	return _definitions.get(ship_id)


func load_ship(ship_id: String) -> bool:
	var def := definition(ship_id)
	if def == null:
		return false
	if ship:
		unload_ship()
	ship = def
	_tracker = SlotTracker.new(def, _emit)
	ship_loaded.emit(ship_id)
	return true


func unload_ship() -> void:
	if ship == null:
		return
	var id := ship.ship_id
	ship = null
	_tracker = null
	set_ship_powered(false)
	ship_unloaded.emit(id)


func get_slots() -> Array[MountSlot]:
	return ship.slots if ship else ([] as Array[MountSlot])


func get_slot(slot_id: String) -> MountSlot:
	return ship.slot(slot_id) if ship else null


## The slot's state, or -1 when no ship is loaded or it has no such slot.
func get_slot_state(slot_id: String) -> int:
	return _tracker.state(slot_id) if _tracker else -1


## What sits in the slot now ("" when empty).
func get_component(slot_id: String) -> String:
	return _tracker.component(slot_id) if _tracker else ""


func get_fasteners(slot_id: String) -> Array[FastenerPoint]:
	var s := get_slot(slot_id)
	return s.fasteners if s else ([] as Array[FastenerPoint])


func is_joint_tight(joint_id: String) -> bool:
	return _tracker != null and _tracker.is_tight(joint_id)


## 0..1 as Trades reported it; 0 when the joint isn't made.
func joint_quality(joint_id: String) -> float:
	return _tracker.joint_quality(joint_id) if _tracker else 0.0


## Holds `component` in an empty slot that takes it, ready to fasten.
func try_position(slot_id: String, component: String) -> bool:
	return _tracker != null and _tracker.try_position(slot_id, component)


## Lifts a positioned part back out before any joint holds it.
func try_remove(slot_id: String) -> bool:
	return _tracker != null and _tracker.try_remove(slot_id)


## Trades: a joint was made (bolt torqued, rivet set, seam welded, plug seated).
func note_joint_made(joint_id: String, quality: float) -> bool:
	return _tracker != null and _tracker.joint_made(joint_id, quality)


## Trades: a joint was undone.
func note_joint_removed(joint_id: String) -> bool:
	return _tracker != null and _tracker.joint_removed(joint_id)


## Shore power to the ship in the bay on or off (the bay's ground power unit, or anyone).
func set_ship_powered(on: bool) -> void:
	if on == ship_powered:
		return
	ship_powered = on
	ship_power_changed.emit(on)


## Everything needed to put the bay back as it is: saves and late-joining players.
func snapshot() -> Dictionary:
	var out := {"storage": _stock.to_dict()}
	if ship:
		out.merge({"ship_id": ship.ship_id, "slots": _tracker.snapshot(), "powered": ship_powered})
	return out


func restore(state: Dictionary) -> void:
	_stock.from_dict(state.get("storage", {}))
	stock_changed.emit()
	var id: String = state.get("ship_id", "")
	if id == "":
		unload_ship()
		return
	if (ship == null or ship.ship_id != id) and not load_ship(id):
		return
	_tracker.restore(state.get("slots", {}))
	set_ship_powered(bool(state.get("powered", false)))


## A new game: no ship in the bay and the stores empty.
func reset_data() -> void:
	restore({})


func get_net_snapshot() -> Dictionary:
	return snapshot()


func apply_net_snapshot(data: Dictionary) -> void:
	restore(data)


func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	return snapshot()


func load_data(data: Dictionary, _from_version: int) -> void:
	restore(data)


# --- The stores ------------------------------------------------------------------------

## Business: an order has arrived. Lines are {item_id (a Void Salvage part_name or a
## fastener id), qty, condition (0..1), name, grade, mass (kg a unit, 0 when unknown)}.
## The host sets a crate per line down in the Deliveries hall and every player sees it;
## delivery_landed follows. Other players' calls are ignored (the host's arrive for them).
func receive_delivery(order_id: String, lines: Array) -> void:
	var payload := {"order_id": order_id, "lines": lines.duplicate(true)}
	if _net == null:
		_apply_delivery(payload)
	elif bool(_net.call("is_host")):
		_net.call("host_emit", "ship_bay.delivery", payload)


## Crates in the Deliveries hall not yet put away: crate id -> {order_id, item, name, qty,
## condition, grade, mass, spot, carrier}. Picked crates are in picked_crates().
func delivered_crates() -> Dictionary:
	var out := {}
	for id: String in _stock.crates:
		if not _stock.crates[id].has("to"):
			out[id] = (_stock.crates[id] as Dictionary).duplicate(true)
	return out


## Any crate, delivered or picked, by id ({} when there is none).
func crate_info(crate_id: String) -> Dictionary:
	return (_stock.crates.get(crate_id, {}) as Dictionary).duplicate(true)


## Where a delivered crate stands in the yard (its floor centre), or Vector3.ZERO (none, or
## on a trolley).
func crate_position(crate_id: String) -> Vector3:
	var c: Dictionary = _stock.crates.get(crate_id, {})
	if c.is_empty():
		return Vector3.ZERO
	var spots: Array = StorageLayout.get_layout()["goods_in"]
	var spot := int(c["spot"])
	if spot < 0:
		return Vector3.ZERO   # on a trolley
	return spots[spot % spots.size()] + Vector3(0, 1.1 * (spot / spots.size()), 0)


## Asks for a delivered crate's goods to be put away (on `location_id`, or the item's
## home); crate_stored follows on every player. Trolleys call this as they set it down.
func store_crate(crate_id: String, location_id := "") -> void:
	var payload := {"crate_id": crate_id, "location": location_id}
	if _net:
		_net.call("request", "ship_bay.store_crate", payload)
	elif _check_store(0, payload) is Dictionary:
		_apply_store(payload)


## Asks for parts out of the stores (to fit them); stock_changed follows.
func take_stock(item_id: String, qty := 1) -> void:
	var payload := {"item": item_id, "qty": qty}
	if _net:
		_net.call("request", "ship_bay.take_stock", payload)
	elif _check_take(0, payload) is Dictionary:
		_apply_take(payload)


## Tells a hover trolley ("s", "m", "l") what to do; every player's yard hears it and the
## one driving the trolley carries it out:
## - "come" {to: Vector3}: come to a place (a player's feet) and wait there
## - "put_away": take delivered crates it can carry to their places in the stores, one by one
## - "park": go back to its parking bay in Deliveries; "stop": stop where it is
## - "deck" {height}: raise or lower its deck (metres, its top over the floor)
## - "fetch" {item, qty, to: Vector3} (the picking lift "p"): pick the goods off their shelf
##   and hand them to a trolley that brings them to `to`; it waits there until collected
## - "deliver" {crate, to}: (the lift asks a trolley) take a picked crate from the lift to `to`
func command_trolley(trolley_id: String, command: String, args: Dictionary = {}) -> void:
	var payload := {"trolley": trolley_id, "command": command, "args": args.duplicate()}
	if _net:
		_net.call("request", "ship_bay.trolley", payload)
	elif _check_trolley(0, payload) is Dictionary:
		_apply_trolley(payload)


## A trolley picks a delivered crate up (its driver asks when it reaches the crate).
func carry_crate(crate_id: String, trolley_id: String) -> void:
	var payload := {"crate_id": crate_id, "trolley": trolley_id}
	if _net:
		_net.call("request", "ship_bay.trolley_carry", payload)
	elif _check_carry(0, payload) is Dictionary:
		_apply_carry(payload)


## Asks for parts out of the stores, brought to you: the picking lift takes them off their
## shelf and a trolley brings them to `to` (your feet) and waits; collect_crate takes them.
func fetch_stock(item_id: String, qty := 1, to := Vector3.ZERO) -> void:
	command_trolley("p", "fetch", {"item": item_id, "qty": qty, "to": to})


## The picking lift (or the large trolley, for bulk goods) takes `qty` off a location into a
## crate for `to` (its driver asks once it is at the shelf); stock_picked follows.
func pick_stock(location_id: String, qty: int, to: Vector3, trolley_id := "p") -> void:
	var payload := {"location": location_id, "qty": qty, "to": to, "trolley": trolley_id}
	if _net:
		_net.call("request", "ship_bay.pick", payload)
	elif _check_pick(0, payload) is Dictionary:
		_apply_pick(payload)


## Passes a carried crate to another trolley (the lift to the one delivering it).
func hand_crate(crate_id: String, trolley_id: String) -> void:
	var payload := {"crate_id": crate_id, "trolley": trolley_id}
	if _net:
		_net.call("request", "ship_bay.hand", payload)
	elif _check_hand(0, payload) is Dictionary:
		_apply_hand(payload)


## Takes a picked crate off the trolley that brought it; crate_collected follows.
func collect_crate(crate_id: String) -> void:
	var payload := {"crate_id": crate_id}
	if _net:
		_net.call("request", "ship_bay.collect", payload)
	elif _check_collect(0, payload) is Dictionary:
		_apply_collect(payload)


## Crates picked for someone and on their way (or waiting on a trolley): id -> the crate,
## with `to` [x, z].
func picked_crates() -> Dictionary:
	var out := {}
	for id: String in _stock.crates:
		if _stock.crates[id].has("to"):
			out[id] = (_stock.crates[id] as Dictionary).duplicate(true)
	return out


## The delivered crate a trolley carries now, or "".
func trolley_cargo(trolley_id: String) -> String:
	return _stock.carried_by(trolley_id)


## Every storage location: id -> {id, kind ("bin", "pallet", "bulk"), rack, bay, level, pos,
## at (yard space, the floor of the place), size, face, category, home (item id or "")}.
func storage_locations() -> Dictionary:
	return (StorageLayout.get_layout()["locations"] as Dictionary).duplicate(true)


## The location an item is kept on ("" for an item without a home: it goes to a spare one).
func home_location(item_id: String) -> String:
	return StorageLayout.get_layout()["homes"].get(item_id, "")


## Where a crate of this item would be put away now ("" when the stores are full).
func place_for(item_id: String) -> String:
	return _stock.place_for(item_id)


## What is on a location: {item, qty, condition}, or {} when it is empty.
func stock_at(location_id: String) -> Dictionary:
	return (_stock.stock.get(location_id, {}) as Dictionary).duplicate()


## Locations holding an item, its home first.
func find_stock(item_id: String) -> PackedStringArray:
	return _stock.where(item_id)


func stock_count(item_id: String) -> int:
	return _stock.count(item_id)


## The parts the stores keep a home for: item id -> {name, category, mass (kg)}.
func storage_items() -> Dictionary:
	return StorageLayout.items().duplicate(true)


func _sample_delivery() -> void:
	var lines: Array = []
	for item: String in ["IonThruster", "SideThruster", "LiftThruster", "HydrogenThruster", "DriveEngine",
			"BatteryRack", "Gyroscope", "HelmConsole", "M10", "M12", "RIVET_4", "Reactor", "FuelPump"]:
		var d: Dictionary = StorageLayout.items().get(item, {})
		lines.append({"item_id": item, "qty": 1 if float(d.get("mass", 0.0)) > 40.0 else 250,
				"condition": 1.0, "name": d.get("name", item), "grade": "new", "mass": d.get("mass", 0.0)})
	receive_delivery("PO-%d" % (delivered_crates().size() + 1001), lines)


func _host_only(sender: int, payload: Dictionary) -> Variant:
	return payload if sender == 0 or (_net and sender == int(_net.call("local_peer_id"))) else "deliveries come from the host"


func _apply_delivery(payload: Dictionary) -> void:
	var ids := _stock.land(str(payload.get("order_id", "")), payload.get("lines", []))
	stock_changed.emit()
	delivery_landed.emit(str(payload.get("order_id", "")), ids)


func _check_store(_sender: int, payload: Dictionary) -> Variant:
	var id := str(payload.get("crate_id", ""))
	if not _stock.crates.has(id):
		return "no such crate"
	var loc := str(payload.get("location", ""))
	if loc == "":
		loc = _stock.place_for(_stock.crates[id]["item"], float(_stock.crates[id]["mass"]))
	if loc == "" or not StorageLayout.get_layout()["locations"].has(loc):
		return "nowhere to put it"
	var have: Dictionary = _stock.stock.get(loc, {})
	if not have.is_empty() and have["item"] != _stock.crates[id]["item"]:
		return "that place holds something else"
	return {"crate_id": id, "location": loc}


func _apply_store(payload: Dictionary) -> void:
	var id := str(payload.get("crate_id", ""))
	var loc := _stock.store(id, str(payload.get("location", "")))
	if loc != "":
		stock_changed.emit()
		crate_stored.emit(id, loc)


func _check_carry(_sender: int, payload: Dictionary) -> Variant:
	var id := str(payload.get("crate_id", ""))
	if not _stock.crates.has(id):
		return "no such crate"
	if str(_stock.crates[id].get("carrier", "")) != "":
		return "already on a trolley"
	if not TROLLEYS.has(str(payload.get("trolley", ""))):
		return "no such trolley"
	return payload


func _apply_carry(payload: Dictionary) -> void:
	if _stock.carry(str(payload.get("crate_id", "")), str(payload.get("trolley", ""))):
		stock_changed.emit()
		crate_carried.emit(str(payload["crate_id"]), str(payload["trolley"]))


func _check_trolley(_sender: int, payload: Dictionary) -> Variant:
	if not TROLLEYS.has(str(payload.get("trolley", ""))):
		return "no such trolley"
	if not TROLLEY_COMMANDS.has(str(payload.get("command", ""))):
		return "unknown command"
	if str(payload["command"]) == "fetch":
		var args: Dictionary = payload.get("args", {})
		if _stock.count(str(args.get("item", ""))) < int(args.get("qty", 1)):
			return "not enough in stock"
	return payload


func _apply_trolley(payload: Dictionary) -> void:
	trolley_command.emit(str(payload["trolley"]), str(payload["command"]), payload.get("args", {}))


func _check_pick(_sender: int, payload: Dictionary) -> Variant:
	var have: Dictionary = _stock.stock.get(str(payload.get("location", "")), {})
	if have.is_empty() or int(have["qty"]) < int(payload.get("qty", 1)):
		return "not that much there"
	var by := str(payload.get("trolley", "p"))
	if not TROLLEYS.has(by) or _stock.carried_by(by) != "":
		return "that trolley is full"
	return payload


func _apply_pick(payload: Dictionary) -> void:
	var to: Variant = payload.get("to", Vector3.ZERO)
	var by := str(payload.get("trolley", "p"))
	var id := _stock.pick(str(payload["location"]), int(payload.get("qty", 1)), by, to if to is Vector3 else Vector3.ZERO)
	if id != "":
		stock_changed.emit()
		stock_picked.emit(id, str(payload["location"]))
		crate_carried.emit(id, by)


func _check_hand(_sender: int, payload: Dictionary) -> Variant:
	var id := str(payload.get("crate_id", ""))
	if str(_stock.crates.get(id, {}).get("carrier", "")) == "":
		return "nothing carries that crate"
	var to := str(payload.get("trolley", ""))
	if not TROLLEYS.has(to) or _stock.carried_by(to) != "":
		return "that trolley can't take it"
	return payload


func _apply_hand(payload: Dictionary) -> void:
	if _stock.hand(str(payload["crate_id"]), str(payload["trolley"])):
		stock_changed.emit()
		crate_carried.emit(str(payload["crate_id"]), str(payload["trolley"]))


func _check_collect(_sender: int, payload: Dictionary) -> Variant:
	return payload if _stock.crates.get(str(payload.get("crate_id", "")), {}).has("to") else "no such picked crate"


func _apply_collect(payload: Dictionary) -> void:
	var c := _stock.collect(str(payload["crate_id"]))
	if not c.is_empty():
		stock_changed.emit()
		crate_collected.emit(str(payload["crate_id"]), str(c["item"]), int(c["qty"]))


func _check_take(_sender: int, payload: Dictionary) -> Variant:
	if _stock.count(str(payload.get("item", ""))) < int(payload.get("qty", 1)):
		return "not enough in stock"
	return payload


func _apply_take(payload: Dictionary) -> void:
	if _stock.take(str(payload.get("item", "")), int(payload.get("qty", 1))):
		stock_changed.emit()


func _emit(signal_name: String, args: Array) -> void:
	emit_signal.callv([signal_name] + args)
