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
## A part beamed off the ship landed on a trolley's deck as a crate (`crate_id`, carried by
## `trolley_id`, which puts it away like a delivery): it is stock now. Every peer hears it.
signal part_beamed(crate_id: String, trolley_id: String, component: String, slot_id: String)
## A part beamed off the ship (a crate whose part_beamed carried a slot) left the trolley it
## rode on: into the stores, a line, the crusher, or onto another trolley. With
## trades.parts_on_decks on, Tools' loose body lies on the deck in place of a drawn crate,
## and lets it go on this (every peer hears it).
signal deck_part_left(crate_id: String, trolley_id: String)
## A piece of the bay's kit was changed (a scaffold rig's bays, lifts or open ends): every peer
## hears it. payload {rig, bays, lifts, ends}.
signal kit_changed(payload: Dictionary)
## The shipyard scene has built itself; add your own nodes to `yard` (at shipyard_spot()s).
signal shipyard_ready(yard: Node3D)
## This player took a hover trolley on remote control (on) or handed it back (off). While
## `remote_driving` is true, W A S D and the mouse drive the trolley (its camera shows in a
## picture-in-picture window): the player's own walker should stand still and not look round.
signal remote_driving_changed(on: bool)
## A dust vessel off the refurbishment line's grinder reached the stores (item_id is
## DUST_ITEM, qty 1): materials is {Void Salvage material id ("steel", "copper", ...): kg},
## ready for sale. Every player hears it; Business adds the raw materials to its stock (on
## the host, once).
signal scrap_recycled(item_id: String, qty: int, materials: Dictionary)
## The refurbishment line in Pre-assembly changed (line_state()).
signal line_changed
## A clean-up sent a trolley for a part lying loose in the yard (Tools adds it to the parts
## it is waiting on a trolley for, as with beam_to_trolley).
signal clean_up_claimed(slot_id: String, trolley_id: String)
## A transporter's deck, steering mode or status changed (the yard's Transporters applies it).
signal transporter_state(payload: Dictionary)
## A transport cradle's pins were thrown, or a dolly picked it up or set it down.
signal cradle_state(payload: Dictionary)
## A ship's door was opened or shut (F on its panel): {ship (the ship node's name), door, open}.
signal ship_door_state(payload: Dictionary)
## Where the transporters and cradles stand came back from a save or the host.
signal transport_restored(state: Dictionary)
## The bay's shore power plug moved or the unit was switched, on another player's machine
## (or a late join): {state ("hook", "hand", "hull"), switch, xform (bay space), by (peer)}.
signal plug_changed(payload: Dictionary)

## The fastener rings show only within `radius_m` of `at` (world space); INF shows them all.
signal marker_focus_changed(at: Vector3, radius_m: float)
## The ships stood on the apron for a look changed (Settings > Debug > Ship): short design names.
signal yard_ships_changed(ships: PackedStringArray)
## A component rig's state changed (a unit mounted or taken off, a test started or shown), on
## every player: {unit, testing, result}. See RIGS.
signal rig_changed(rig_id: String, state: Dictionary)
## Host only: a player pressed a rig's test button with a unit on it. Quality runs the test
## and answers with rig_show_test.
signal rig_test_requested(rig_id: String, unit_id: String)
## A rig's test result arrived (rig_show_test), on every player; the rig plays its sweep.
signal rig_test_shown(rig_id: String, result: Dictionary)

## Router scene id of the bay (registered while the "ship_bay.bay_view" flag is on).
const BAY_SCENE := "ship_bay.bay"
## Router scene id of the shipyard round the bay (registered while "ship_bay.shipyard" is on).
const SHIPYARD_SCENE := "ship_bay.shipyard"
const SAVE_VERSION := 2
## Deliveries made for a contract's subject (scrapyard S1) carry this order id prefix, then
## the job id.
const SUBJECT_ORDER := "subject:"
## The yard's hover trolleys, small, medium and large, "p" the picking lift and "h" the heavy lift in the
## stores, the lines' "a" and "b", the goods-in picking lifts "p2" to "p6", and Store 2's picking lift "p7". Their Multiplayer mover ids are "trolley:<id>"; claim one to drive it by remote
## control.
const TROLLEYS: PackedStringArray = ["s", "m", "l", "p", "h", "a", "b", "p2", "p3", "p4", "p5", "p6", "p7"]
const TROLLEY_COMMANDS: PackedStringArray = ["come", "follow", "put_away", "park", "stop", "deck", "fast", "fetch", "deliver", "beam", "shelve", "auto"]
## Ship id -> its folder (layout, fasteners, model).
const SHIPS := {"vs_kestrel": "res://modules/ship_bay/internal/ships/kestrel"}

const LayoutLoader := preload("res://modules/ship_bay/internal/layout_loader.gd")
const EmitterRig := preload("res://modules/ship_bay/internal/yard/emitter_rig.gd")
const DebugShipsPanel := preload("res://modules/ship_bay/internal/ui/debug_ships_panel.gd")
## The Debug page's section (Settings > Debug > Ship).
const DEBUG_SECTION := "ship_bay"
## Component rigs in the yard (Component Upgrades): id -> {kind, takes (a unit family: unit
## ids start with it), room}. The rig's place is shipyard_spot(id): origin on its deck's
## middle at deck height, +X along the unit, +Z towards the worker.
const RIGS := {"rig_emitter": {"kind": "emitter_frame", "takes": "attractor_coil", "room": "preassembly"}}
## Designs that can stand on the apron for a look (YardShips.PLACES).
const YARD_SHIP_DESIGNS: PackedStringArray = ["manta"]
const SlotTracker := preload("res://modules/ship_bay/internal/slot_tracker.gd")
const Shipyard := preload("res://modules/ship_bay/internal/yard/shipyard.gd")
const StorageLayout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
const StorageStock := preload("res://modules/ship_bay/internal/storage/storage_stock.gd")
const RefurbLine := preload("res://modules/ship_bay/internal/yard/refurb_line.gd")
const CrusherPlant := preload("res://modules/ship_bay/internal/yard/crusher_plant.gd")

## The ship in the bay, or null.
var ship: ShipDefinition
var _tracker: SlotTracker
var _definitions: Dictionary = {}
## Whether the ship in the bay is on shore power (its lamps, screens and systems live).
var ship_powered := false
var _stock := StorageStock.new()
var _part_values := Callable()
## The yard's trolley fleet while the shipyard is up (it sets this), for beam_to_trolley.
var fleet: Node
## True while this player drives a hover trolley on remote (see remote_driving_changed).
var remote_driving := false
## Slot id -> the trolley sent for a part beamed off the ship, until it lands or is called off.
var _beam_claims: Dictionary = {}
## Slot id -> {component, condition, body (the part's Node3D)}: parts off the ship lying
## loose in the yard (Tools tells us, note_loose), for a trolley clean-up to sort.
var _loose: Dictionary = {}
## Slot id -> the clean-up's route for a part a trolley has been sent for.
var _clean_routes: Dictionary = {}
## True from CLEAN UP until every loose part has had a trolley sent for it.
var cleaning := false
## Where the transporters and cradles stand: {transporters: {kind: {xform, deck, mode}},
## cradles: {name: {xform, pins, on}}}. Kept by the yard's Transporters; saved and sent to
## players who join.
var transport_state: Dictionary = {}
## The Contracts bus once it has subject_due (scrapyard S1), else null.
var _contracts: Node
## The Multiplayer bus when that module is loaded (used by duck typing, so Ship and Bay
## runs without it: tests that switch only part of the game on, and solo builds).
var _net: Node
## The power plug as last shared (plug_changed): late joiners get it in the net snapshot.
var plug_info: Dictionary = {}
## Ships stood on the apron's Dock 2 for a look (Settings > Debug > Ship): "manta".
var yard_ships: PackedStringArray = []
## True once the bay was emptied from Settings > Debug > Ship: the bay stays empty until
## the Kestrel is brought back.
var bay_cleared := false
## Rig id -> {unit, testing, result, joints}: what's on each component rig (RIGS).
var rigs: Dictionary = {}
## Rig id -> the rig's node in the yard (it adds itself), for rig_unit.
var rig_nodes: Dictionary = {}

## Where fastener rings show (set_marker_focus): round this point, world space, within the
## radius (metres; INF: everywhere).
var marker_focus_at := Vector3.ZERO
var marker_focus_radius := INF
## How far the focus point moves (m) before the rings are sorted again.
const MARKER_FOCUS_STEP := 0.1


func register_module() -> void:
	Saves.register_section("ship_bay", self)
	Menu.register_settings_section(Menu.DEBUG, DEBUG_SECTION, "Ship",
			func() -> Control: return DebugShipsPanel.new(self), 20)
	# Driving the yard's vehicles (the lift, the power unit, a trolley on remote control).
	for k: Array in [["ship_bay.raise", "Raise the lift or deck", KEY_UP], ["ship_bay.lower", "Lower the lift or deck", KEY_DOWN],
			["ship_bay.call_trolley", "Call a trolley (Shift: large, Ctrl: small)", KEY_T],
			["ship_bay.dolly_ahead", "Dolly on remote: ahead", KEY_UP], ["ship_bay.dolly_back", "Dolly on remote: back", KEY_DOWN],
			["ship_bay.dolly_left", "Dolly on remote: steer left", KEY_LEFT], ["ship_bay.dolly_right", "Dolly on remote: steer right", KEY_RIGHT],
			["ship_bay.dolly_up", "Dolly: raise the deck", KEY_PAGEUP], ["ship_bay.dolly_down", "Dolly: lower the deck", KEY_PAGEDOWN],
			["ship_bay.dolly_mode", "Dolly: steering mode", KEY_M]]:
		Keys.register(k[0], k[1], k[2], "Yard vehicles")
	# Multiplayer may load after this module, so its events are hooked up once all are in.
	if Modules.ready_done:
		_hook_net()
		_hook_contracts()
	else:
		if not Modules.modules_ready.is_connected(_hook_net):
			Modules.modules_ready.connect(_hook_net, CONNECT_ONE_SHOT)
		if not Modules.modules_ready.is_connected(_hook_contracts):
			Modules.modules_ready.connect(_hook_contracts, CONNECT_ONE_SHOT)
	if Flags.is_on("ship_bay.bay_view"):
		Router.register_scene(BAY_SCENE, "res://modules/ship_bay/internal/bay/bay.tscn")
		Shots.register("kestrel_in_bay", BAY_SCENE)
	if Flags.is_on("ship_bay.shipyard"):
		Router.register_scene(SHIPYARD_SCENE, "res://modules/ship_bay/internal/yard/shipyard.tscn")
		Menu.set_start(SHIPYARD_SCENE, 10)   # the game starts in the yard
		for view: String in ["overview", "courtyard", "deliveries", "stock", "prep", "preassembly",
				"kestrel_front", "kestrel_stern", "kestrel_rivets", "kestrel_cabin", "kestrel_hold",
				"kestrel_access", "kestrel_lift", "storage_aisle", "storage_bins", "storage_bulk", "storage_heavy",
				"dock", "launch_towers", "city", "downtown", "crusher_house", "crusher"]:
			Shots.register("shipyard_" + view, SHIPYARD_SCENE,
					func(scene: Node) -> void: scene.call("show_view", view))
		# The lift up at the side door, and the power unit's plug clipped on the hull.
		Shots.register("shipyard_lift_at_door", SHIPYARD_SCENE, func(scene: Node) -> void:
			var access: Node = (scene.get("bay") as Node).get("access")
			access.call("set_lift_height", 1.6)
			scene.call("show_view", "kestrel_lift"))
		Shots.register("shipyard_power_plugged", SHIPYARD_SCENE, func(scene: Node) -> void:
			(scene.get("bay") as Node).get("access").call("set_power", true)
			scene.call("show_view", "kestrel_power"))
		# The two scaffold rigs parked, then driven to the starboard flank and joined end to
		# end into one 10 m floor at the roof's edge.
		Shots.register("shipyard_scaffolds", SHIPYARD_SCENE, func(scene: Node) -> void:
			scene.call("show_view", "scaffolds"))
		Shots.register("shipyard_scaffold_floor", SHIPYARD_SCENE, func(scene: Node) -> void:
			var rigs: Array = ((scene.get("bay") as Node).get("access") as Node).get("scaffolds")
			rigs[0].call("configure", 2, 2, 1)
			rigs[1].call("configure", 2, 2, 2)
			rigs[0].global_position = Vector3(3.42, 0, -1.0)
			rigs[1].global_position = Vector3(3.42, 0, 4.03)
			scene.call("show_view", "scaffolds"))
		Shots.register("shipyard_night", SHIPYARD_SCENE, func(scene: Node) -> void:
			scene.call("set_time_of_day", 22.0)
			scene.call("show_view", "courtyard"))
		Shots.register("shipyard_city_night", SHIPYARD_SCENE, func(scene: Node) -> void:
			scene.call("set_time_of_day", 21.5)
			scene.call("show_view", "downtown"))
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
		# The medium trolley in aisle C with a crate raised to the third shelf.
		Shots.register("shipyard_trolley_lift", SHIPYARD_SCENE, func(scene: Node) -> void:
			var fleet: Node = scene.get("trolleys")
			var m: Node = (fleet.get("trolleys") as Dictionary)["m"]
			m.call("set_cargo", {"crate_id": "shot", "kind": "pallet", "mass": 311.0, "name": "Ion thruster"})
			m.call("pose", Vector3(StorageLayout.aisle_x("C"), 0, -33.95), 0.0, StorageLayout.level_y(3))
			scene.call("show_view", "trolley_lift"))
		# The picking lift in aisle B reaching into the top shelf.
		Shots.register("shipyard_picking_lift", SHIPYARD_SCENE, func(scene: Node) -> void:
			var lift: Node = ((scene.get("trolleys") as Node).get("trolleys") as Dictionary)["p"]
			lift.call("set_cargo", {"crate_id": "shot", "kind": "pallet", "mass": 250.0, "name": "Gyroscope"})
			lift.call("pose", Vector3(StorageLayout.aisle_x("B"), 0, StorageLayout.bay_z(2)), 0.0, StorageLayout.level_y(StorageLayout.LEVELS))
			lift.call("reach", true, signf(StorageLayout.rack_x("B1") - StorageLayout.aisle_x("B")))
			lift.set("fork_out", 0.99)
			scene.call("show_view", "picking_lift"))
		Shots.register("shipyard_hover_truck", SHIPYARD_SCENE, func(scene: Node) -> void:
			scene.call("show_view", "hover_truck"))


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
	_net.call("register_event", "ship_bay.kit", _apply_kit, _check_kit)
	_net.call("register_event", "ship_bay.beamed", _apply_beamed, _check_beamed)
	_net.call("register_event", "ship_bay.line", _apply_line, _check_line)
	_net.call("register_event", "ship_bay.transporter", _apply_transporter, _pass)
	_net.call("register_event", "ship_bay.cradle", _apply_cradle, _pass)
	_net.call("register_event", "ship_bay.ship_door", _apply_ship_door, _pass)
	_net.call("register_event", "ship_bay.joint", _apply_joint, _stamp)
	_net.call("register_event", "ship_bay.slot", _apply_slot_move, _stamp)
	_net.call("register_event", "ship_bay.plug", _apply_plug, _check_plug)
	_net.call("register_event", "ship_bay.debug_ship", _apply_debug_ship, _check_debug_ship)
	_net.call("register_event", "ship_bay.rig", _apply_rig, _check_rig)
	_net.call("register_snapshot_provider", "ship_bay", self)


## Scrapyard S1: when Contracts says a job's subject is due (a part to strip or refurbish),
## it lands in Deliveries as a crate and Contracts hears it is in. Hooked by duck typing, only
## once Contracts has the signal.
func _hook_contracts() -> void:
	var contracts := Modules.bus("contracts")
	if contracts == null or not contracts.has_signal("subject_due") or _contracts == contracts:
		return
	_contracts = contracts
	contracts.connect("subject_due", _on_subject_due)
	if not delivery_landed.is_connected(_on_subject_landed):
		delivery_landed.connect(_on_subject_landed)


## A job's subject is due: {type: "part", component: {id, material}, condition, mass_kg}.
## The host sets it down in Deliveries (other players' calls are ignored, as deliveries are).
func _on_subject_due(job_id: String, subject: Dictionary) -> void:
	if str(subject.get("type", "")) != "part":
		return
	var component: Dictionary = subject.get("component", {})
	var id := str(component.get("id", ""))
	if id == "":
		return
	receive_delivery(SUBJECT_ORDER + job_id, [{"item_id": id, "qty": 1, "condition": float(subject.get("condition", 1.0)),
			"name": str(component.get("name", id)), "grade": str(component.get("material", "")),
			"mass": float(subject.get("mass_kg", 0.0))}])


func _on_subject_landed(order_id: String, _crate_ids: PackedStringArray) -> void:
	if not order_id.begins_with(SUBJECT_ORDER) or _contracts == null:
		return
	if _net == null or bool(_net.call("is_host")):
		if _contracts.has_method("subject_landed"):
			_contracts.call("subject_landed", order_id.substr(SUBJECT_ORDER.length()))


func unregister_module() -> void:
	Saves.unregister_section("ship_bay")
	Menu.unregister_settings_section(Menu.DEBUG, DEBUG_SECTION)
	if _contracts and _contracts.is_connected("subject_due", _on_subject_due):
		_contracts.disconnect("subject_due", _on_subject_due)
	_contracts = null
	for k: String in ["ship_bay.raise", "ship_bay.lower", "ship_bay.call_trolley", "ship_bay.dolly_ahead", "ship_bay.dolly_back",
			"ship_bay.dolly_left", "ship_bay.dolly_right", "ship_bay.dolly_up", "ship_bay.dolly_down", "ship_bay.dolly_mode"]:
		Keys.unregister(k)
	if _net:
		for e: String in ["ship_bay.delivery", "ship_bay.store_crate", "ship_bay.take_stock",
				"ship_bay.trolley_carry", "ship_bay.trolley", "ship_bay.pick", "ship_bay.hand",
				"ship_bay.collect", "ship_bay.kit", "ship_bay.beamed", "ship_bay.line", "ship_bay.transporter", "ship_bay.cradle", "ship_bay.ship_door",
				"ship_bay.joint", "ship_bay.slot", "ship_bay.plug", "ship_bay.debug_ship", "ship_bay.rig"]:
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


## The look of a ship part taken off its slot, so it stays the same part when loose: a new
## Node3D holding copies of the slot's mesh pieces in the slot's mount space (its origin
## is the mount). Tools' tractor hangs it on the loose part. Null when the slot has none.
## The bay hides the originals while the slot is EMPTY, so the part never shows twice.
func part_visual(yard: Node3D, slot_id: String) -> Node3D:
	var bay_node := yard.get("bay") as Node3D if yard else null
	var ship_node := bay_node.get("ship_root") as Node3D if bay_node else null
	var slot := get_slot(slot_id)
	if ship_node == null or slot == null:
		return null
	var pieces: Array = (bay_node.get("pieces") as Dictionary).get(slot_id, [])
	if pieces.is_empty():
		return null
	var root := Node3D.new()
	root.name = "PartVisual_" + slot_id
	var to_mount := slot.mount.affine_inverse()
	for mi: MeshInstance3D in pieces:
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.material_override = mi.material_override
		for i in mi.get_surface_override_material_count():
			copy.set_surface_override_material(i, mi.get_surface_override_material(i))
		copy.cast_shadow = mi.cast_shadow
		copy.transform = to_mount * _in_ship(mi, ship_node)
		root.add_child(copy)
	return root


## A node's transform in ship space (relative to the ship's root, in the tree or not).
static func _in_ship(node: Node3D, ship_root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ship_root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


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
	# A ship comes into the bay on shore power, lit, its screens on (beenster, 0.3.17: cold,
	# it read as flat and broken); a save puts back whatever it had.
	if Flags.is_on("ship_bay.ship_starts_powered"):
		set_ship_powered(true)
	return true


func unload_ship() -> void:
	if ship == null:
		return
	var id := ship.ship_id
	ship = null
	_tracker = null
	set_ship_powered(false)
	ship_unloaded.emit(id)


## Shows the fastener rings (green tight, amber undone) only within `radius_m` metres of `at`
## (world space, the point under the crosshair); further off only the heads show. INF shows
## every ring. Cheap to call every frame: the bays re-sort only when the point has moved
## MARKER_FOCUS_STEP or the radius changes. Local only (each player's own view).
func set_marker_focus(at: Vector3, radius_m: float) -> void:
	if radius_m == marker_focus_radius and (is_inf(radius_m) or at.distance_to(marker_focus_at) < MARKER_FOCUS_STEP):
		return
	marker_focus_at = at
	marker_focus_radius = radius_m
	marker_focus_changed.emit(at, radius_m)


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
	if RIGS.has(slot_id):
		return rig_points(slot_id)
	var s := get_slot(slot_id)
	return s.fasteners if s else ([] as Array[FastenerPoint])


func is_joint_tight(joint_id: String) -> bool:
	if _is_rig_joint(joint_id):
		return _rig_joints(joint_id).has(joint_id)
	return _tracker != null and _tracker.is_tight(joint_id)


## 0..1 as Trades reported it; 0 when the joint isn't made.
func joint_quality(joint_id: String) -> float:
	if _is_rig_joint(joint_id):
		return float(_rig_joints(joint_id).get(joint_id, 0.0))
	return _tracker.joint_quality(joint_id) if _tracker else 0.0


## Holds `component` in an empty slot that takes it, ready to fasten.
func try_position(slot_id: String, component: String) -> bool:
	var ok := _tracker != null and _tracker.try_position(slot_id, component)
	if ok:
		_share("ship_bay.slot", {"slot": slot_id, "component": component, "op": "position"})
	return ok


## Lifts a positioned part back out before any joint holds it.
func try_remove(slot_id: String) -> bool:
	var ok := _tracker != null and _tracker.try_remove(slot_id)
	if ok:
		_share("ship_bay.slot", {"slot": slot_id, "op": "remove"})
	return ok


## Trades: a joint was made (bolt torqued, rivet set, seam welded, plug seated).
func note_joint_made(joint_id: String, quality: float) -> bool:
	if _is_rig_joint(joint_id):
		return _rig_joint(joint_id, true, quality, true)
	var ok := _tracker != null and _tracker.joint_made(joint_id, quality)
	if ok:
		_share("ship_bay.joint", {"joint": joint_id, "made": true, "quality": quality})
	return ok


## Trades: a joint was undone.
func note_joint_removed(joint_id: String) -> bool:
	if _is_rig_joint(joint_id):
		return _rig_joint(joint_id, false, 0.0, true)
	var ok := _tracker != null and _tracker.joint_removed(joint_id)
	if ok:
		_share("ship_bay.joint", {"joint": joint_id, "made": false})
	return ok


## Online, tells the other players about a change already made here (a joint, a slot): the
## host stamps who sent it and every other peer makes the same change to its tracker.
func _share(event_name: String, payload: Dictionary) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", event_name, payload)


## The validator for changes the sender has already made: notes who sent it.
func _stamp(sender: int, payload: Dictionary) -> Variant:
	payload["by"] = sender
	return payload


func _from_here(payload: Dictionary) -> bool:
	return _net != null and int(payload.get("by", -1)) == int(_net.call("local_peer_id"))


func _apply_joint(payload: Dictionary) -> void:
	if _from_here(payload):
		return
	var joint := str(payload.get("joint", ""))
	if _is_rig_joint(joint):
		_rig_joint(joint, bool(payload.get("made", false)), float(payload.get("quality", 1.0)), false)
		return
	if _tracker == null:
		return
	if bool(payload.get("made", false)):
		_tracker.joint_made(str(payload.get("joint", "")), float(payload.get("quality", 1.0)))
	else:
		_tracker.joint_removed(str(payload.get("joint", "")))


func _apply_slot_move(payload: Dictionary) -> void:
	if _tracker == null or _from_here(payload):
		return
	if str(payload.get("op", "")) == "position":
		_tracker.try_position(str(payload.get("slot", "")), str(payload.get("component", "")))
	else:
		_tracker.try_remove(str(payload.get("slot", "")))


## The bay's power plug (BayAccess): where it is and whether the unit is on, for every player.
## Online it goes through the host, which refuses to let a second player take it from the
## first one's hand; solo it applies at once.
func send_plug(payload: Dictionary) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", "ship_bay.plug", payload)
	else:
		payload["by"] = int(_net.call("local_peer_id")) if _net else 0
		_apply_plug(payload)


func _check_plug(sender: int, payload: Dictionary) -> Variant:
	if str(payload.get("state", "")) == "hand" and str(plug_info.get("state", "")) == "hand" \
			and int(plug_info.get("by", 0)) != sender:
		return "someone else has the plug"
	payload["by"] = sender
	return payload


func _apply_plug(payload: Dictionary) -> void:
	plug_info = payload.duplicate(true)
	plug_changed.emit(plug_info)


## Shore power to the ship in the bay on or off (the bay's ground power unit, or anyone).
func set_ship_powered(on: bool) -> void:
	if on == ship_powered:
		return
	ship_powered = on
	ship_power_changed.emit(on)


## Everything needed to put the bay back as it is: saves and late-joining players.
func snapshot() -> Dictionary:
	var out := {"storage": _stock.to_dict(), "line": line_state(), "transport": transport_state.duplicate(true),
			"yard_ships": Array(yard_ships), "bay_cleared": bay_cleared, "rigs": rigs.duplicate(true)}
	if ship:
		out.merge({"ship_id": ship.ship_id, "slots": _tracker.snapshot(), "powered": ship_powered})
	return out


func restore(state: Dictionary) -> void:
	plug_info = {}
	_stock.from_dict(state.get("storage", {}))
	_line = _new_line()
	var saved: Dictionary = state.get("line", {})
	_line["auto"] = bool(saved.get("auto", false))
	# Saves from before the twin lines held one line's stations (line A now) and the dust.
	var lines: Dictionary = saved.get("lines", {"a": {"stations": saved.get("stations", {})}})
	for l: String in lines:
		if not _line["lines"].has(l):
			continue
		var st: Dictionary = (lines[l] as Dictionary).get("stations", {})
		for s: String in st:
			if _line["lines"][l]["stations"].has(s):
				var at: Dictionary = (st[s] as Dictionary).duplicate(true)
				# A machine that was running when the game was saved runs again on load.
				if str(at.get("state", "")) == "running":
					at["state"] = "waiting"
				_line["lines"][l]["stations"][s] = at
	var crusher: Dictionary = (saved.get("crusher", {}) as Dictionary).duplicate(true)
	if crusher.is_empty():
		crusher = {"dust": (saved.get("dust", {}) as Dictionary).duplicate()}
	for k: String in crusher:
		_line["crusher"][k] = crusher[k]
	stock_changed.emit()
	line_changed.emit()
	transport_state = (state.get("transport", {}) as Dictionary).duplicate(true)
	transport_restored.emit(transport_state)
	yard_ships = PackedStringArray(state.get("yard_ships", []))
	yard_ships_changed.emit(yard_ships)
	bay_cleared = bool(state.get("bay_cleared", false))
	rigs = {}
	for id: String in (state.get("rigs", {}) as Dictionary):
		if RIGS.has(id):
			var r: Dictionary = (state["rigs"][id] as Dictionary).duplicate(true)
			r["testing"] = false   # a sweep that was running when the game was saved isn't
			rigs[id] = r
	for id: String in RIGS:
		rig_changed.emit(id, rig_state(id))
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
	var out := snapshot()
	if not plug_info.is_empty():
		out["plug"] = plug_info.duplicate(true)
	return out


func apply_net_snapshot(data: Dictionary) -> void:
	restore(data)
	if data.has("plug"):
		_apply_plug(data["plug"])


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
	if c.has("at") and str(c.get("carrier", "")) == "":
		var at: Array = c["at"]
		return Vector3(float(at[0]), float(at[1]), float(at[2]))   # set down by the line
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
## - "follow" {to: Vector3, by: peer id}: follow a player at a safe distance; their peer
##   sends it again as they move, and any other command ends it
## - "fast" {on: bool}: fast mode on or off
## - "put_away": take delivered crates it can carry to their places in the stores, one by one
## - "park": go back to its parking bay; "stop": stop where it is
## - "deck" {height}: raise or lower its deck (metres, its top over the floor)
## - "fetch" {item, qty, to: Vector3} (the picking lift "p"): pick the goods off their shelf
##   and hand them to a trolley that brings them to `to`; it waits there until collected
## - "deliver" {crate, to}: (the lift asks a trolley) take a picked crate from the lift to `to`
## - "shelve" {from} (the picking lift): take the goods off a loaded trolley standing at the
##   stores' hand-in one by one and put each on its shelf
## - "auto" {on: bool}: whether it goes to put new deliveries away by itself (on for the
##   goods-in picking lifts and the heavy lift, off for the small, medium and large trolleys)
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


## Sends a free hover trolley big enough for a part freed off the ship (Tools' tractor beam):
## it drives over to `from` (yard space, where the part floats), raises its deck, and the part
## lands on it as a crate it then puts away (part_beamed follows). Returns the trolley's id,
## or "" when none that fits is free (ask again later) or the yard isn't up.
func beam_to_trolley(slot_id: String, component: String, condition: float, from: Vector3) -> String:
	if _beam_claims.has(slot_id):
		return str(_beam_claims[slot_id])
	if fleet == null or not is_instance_valid(fleet):
		return ""
	return _send_for_part(slot_id, component, condition, from, "store")


func _send_for_part(slot_id: String, component: String, condition: float, from: Vector3, route: String) -> String:
	var mass := float(StorageLayout.items().get(component, {}).get("mass", 0.0))
	var id := str(fleet.call("free_for_beam", StorageLayout.kind_for(mass, component), from, _beam_claims.values()))
	if id == "":
		return ""
	_beam_claims[slot_id] = id
	command_trolley(id, "beam", {"slot": slot_id, "component": component, "condition": condition, "from": from, "route": route})
	return id


# --- Cleaning up the yard ------------------------------------------------------------------

## A loose part in this condition (0..1) or better goes back in the stores; worse than
## that it goes to the refurbishment line, and at the survey's grind cut-off or worse
## straight to the grinder.
const STORE_FROM := 0.9


## Where a clean-up takes a loose part in this condition: "store", "refurb" or "grind".
static func clean_up_route(condition: float) -> String:
	if condition >= STORE_FROM:
		return "store"
	return "grind" if condition <= GRIND_BELOW else "refurb"


## The condition (0..1) a part fitted in this slot of the ship in the bay is in: the active
## job's work order says (current_fit), else as new.
func fitted_condition(slot_id: String) -> float:
	var contracts := Modules.bus("contracts") as ContractsBus
	var job := contracts.get_active_job() if contracts else null
	if job and job.order:
		for f: Dictionary in job.order.current_fit:
			if str(f.get("slot", "")) == slot_id:
				return clampf(float(f.get("condition", 1.0)), 0.0, 1.0)
	return 1.0


## Tools: a part off the ship is lying loose in the yard (or its condition changed: call
## again). `body` is the part itself, so the clean-up finds it where it has come to rest.
func note_loose(slot_id: String, component: String, condition: float, body: Node3D) -> void:
	_loose[slot_id] = {"component": component, "condition": clampf(condition, 0.0, 1.0), "body": body}


## Tools: the part is loose no longer (a player's beam took it, it went back in its slot,
## or it is gone).
func forget_loose(slot_id: String) -> void:
	_loose.erase(slot_id)


## Parts lying loose in the yard, nearest the bay doors first: [{slot, component, name,
## condition, at (yard space), route ("store", "refurb", "grind"), trolley (sent, or "")}].
func loose_parts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: String in _loose.keys():
		var p: Dictionary = _loose[slot]
		var body: Node3D = p["body"] if is_instance_valid(p["body"]) else null
		if body == null or not body.is_inside_tree():
			_loose.erase(slot)
			continue
		var comp := str(p["component"])
		var cond := float(p["condition"])
		var at: Vector3 = body.call("centre") if body.has_method("centre") else body.global_position
		out.append({"slot": slot, "component": comp, "name": str(StorageLayout.items().get(comp, {}).get("name", comp)),
				"condition": cond, "at": at, "route": clean_up_route(cond), "trolley": str(_beam_claims.get(slot, ""))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.slot < b.slot)
	return out


## The wrist's CLEAN UP: sends a free trolley that can carry it for each loose part, which
## takes it to the stores, the refurbishment line's in-feed or the grinder's by its
## condition. Parts no trolley is free for wait, and the fleet asks again as trolleys come
## free (cleaning stays true until all have one). Returns how many trolleys went.
func clean_up() -> int:
	if fleet == null or not is_instance_valid(fleet):
		return 0
	cleaning = true
	var sent := 0
	var waiting := 0
	for p: Dictionary in loose_parts():
		if str(p.trolley) != "":
			continue
		var id := _send_for_part(str(p.slot), str(p.component), float(p.condition), p.at, str(p.route))
		if id == "":
			waiting += 1
			continue
		_clean_routes[str(p.slot)] = str(p.route)
		sent += 1
		clean_up_claimed.emit(str(p.slot), id)
	cleaning = waiting > 0
	return sent


## TIDY UP TO REFURB on a yard trolley's screen: the same clean-up. The refurbishment lines
## then run what lands in their intake bays by themselves (ship_bay.refurb_runs_intake), so
## parts end up refurbished in the stores, or as ingots in the crusher house.
func tidy_up() -> int:
	return clean_up()


## Calls off the trolley sent for a part (the player took it with their own beam): it parks.
func cancel_beam(slot_id: String) -> void:
	if not _beam_claims.has(slot_id):
		return
	var id := str(_beam_claims[slot_id])
	_beam_claims.erase(slot_id)
	_clean_routes.erase(slot_id)
	command_trolley(id, "park")


## The top of a trolley's deck (yard space), where a beamed part lands; null for no trolley.
func trolley_deck_position(trolley_id: String) -> Variant:
	if fleet == null or not is_instance_valid(fleet):
		return null
	return fleet.call("deck_position", trolley_id)


## The trolley under a beamed part has its deck up: the part lands on it (its driver asks).
func land_beamed(slot_id: String, trolley_id: String, component: String, condition: float, route := "store") -> void:
	var payload := {"slot": slot_id, "trolley": trolley_id, "component": component, "condition": condition, "route": route}
	if _net:
		_net.call("request", "ship_bay.beamed", payload)
	elif _check_beamed(0, payload) is Dictionary:
		_apply_beamed(payload)


## Takes a picked crate off the trolley that brought it; crate_collected follows.
func collect_crate(crate_id: String) -> void:
	var payload := {"crate_id": crate_id}
	if _net:
		_net.call("request", "ship_bay.collect", payload)
	elif _check_collect(0, payload) is Dictionary:
		_apply_collect(payload)


## Changes a scaffold rig round the bay: {rig: index, bays: 1..4, lifts: 1..4, ends: 0..3}.
## kit_changed follows on every peer.
func change_kit(payload: Dictionary) -> void:
	if _net:
		_net.call("request", "ship_bay.kit", payload)
	elif _check_kit(0, payload) is Dictionary:
		_apply_kit(payload)


## Crates picked for someone and on their way (or waiting on a trolley): id -> the crate,
## with `to` [x, z].
func picked_crates() -> Dictionary:
	var out := {}
	for id: String in _stock.crates:
		if _stock.crates[id].has("to"):
			out[id] = (_stock.crates[id] as Dictionary).duplicate(true)
	return out


## The delivered crate a trolley carries now (the first, when it has several), or "".
func trolley_cargo(trolley_id: String) -> String:
	return _stock.carried_by(trolley_id)


## Every crate a trolley carries now, in the order it took them.
func trolley_load(trolley_id: String) -> PackedStringArray:
	return _stock.load_of(trolley_id)


## How many goods a trolley has aboard, and how many it takes at most.
func trolley_goods(trolley_id: String) -> int:
	return _stock.goods_on(trolley_id)


func trolley_capacity(trolley_id: String) -> int:
	return int(StorageStock.LOAD.get(trolley_id, 1))


## Could a trolley take this crate on top of what it carries?
func trolley_has_room(trolley_id: String, crate_id: String) -> bool:
	return _stock.crates.has(crate_id) and _stock.has_room(trolley_id, _stock.crates[crate_id])


## Every storage location: id -> {id, kind ("bin", "pallet", "bulk"), rack, bay, level, pos,
## at (yard space, the floor of the place), size, face, category, home (item id or "")}.
func storage_locations() -> Dictionary:
	return (StorageLayout.get_layout()["locations"] as Dictionary).duplicate(true)


## The location an item is kept on ("" for an item without a home: it goes to a spare one).
func home_location(item_id: String) -> String:
	return StorageLayout.get_layout()["homes"].get(item_id, "")


## Where a crate of this item would be put away now ("" when the stores are full).
func place_for(item_id: String) -> String:
	if item_id == DUST_ITEM:
		# The bulk floor: any empty bay will do, since its dust goes straight on sale.
		var locations: Dictionary = StorageLayout.get_layout()["locations"]
		var fallback := ""
		for loc: String in locations:
			if locations[loc]["kind"] == "bulk" and not _stock.stock.has(loc):
				if str(locations[loc]["home"]) == "":
					return loc
				if fallback == "":
					fallback = loc
		return fallback if fallback != "" else _stock.place_for(item_id, StorageLayout.PALLET_MAX + 1.0)
	return _stock.place_for(item_id)


## What is on a location: {item, qty, condition}, or {} when it is empty.
func stock_at(location_id: String) -> Dictionary:
	return (_stock.stock.get(location_id, {}) as Dictionary).duplicate()


## Locations holding an item, its home first.
func find_stock(item_id: String) -> PackedStringArray:
	return _stock.where(item_id)


func stock_count(item_id: String) -> int:
	return _stock.count(item_id)


## Location ids that hold goods now.
func stocked_locations() -> PackedStringArray:
	return PackedStringArray(_stock.stock.keys())


## Lets another module price the stores (Business: its catalogue's new value of a part, CR;
## -1 for one it doesn't know). Until one does, the Stock screen shows no values.
##   yard_bus.set_part_values(func(item_id: String) -> int: return catalogue.value_of(item_id))
func set_part_values(getter: Callable) -> void:
	_part_values = getter
	stock_changed.emit()


## What one new part is worth, CR (-1 when nothing prices it).
func part_value(item_id: String) -> int:
	if not _part_values.is_valid():
		return -1
	return int(_part_values.call(item_id))


## The parts the stores keep a home for: item id -> {name, category, mass (kg)}.
func storage_items() -> Dictionary:
	return StorageLayout.items().duplicate(true)


# --- The refurbishment lines (Pre-assembly) and the crusher bay ----------------------------

## Each line's machines in work order. A lot goes into the survey, which says scrap or
## refurbish: scrap goes onto the intake bay's red pallet for a trolley to take out to the
## crusher; refurbished lots go through the straightener, the bath and the coater onto the
## line's own trolley, which takes them to the stores.
const LINE_STATIONS: PackedStringArray = ["survey", "straightener", "bath", "coater"]
## The two lines in Pre-assembly (their trolleys have the same ids).
const LINES: PackedStringArray = ["a", "b"]
## The condition (0..1) a lot leaves each refurbishing machine with, at least.
const LINE_AFTER := {"straightener": 0.6, "bath": 0.85, "coater": 1.0}
## The survey sends lots this poor (condition 0..1) or worse to the crusher.
const GRIND_BELOW := 0.25
## Stored goods under this condition can go on the lines.
const REFURB_BELOW := 0.995
## Of a part's mass, how much comes back out of the crusher as dust.
const RECOVERY := 0.75
## Kilograms of one material the smelter casts into an ingot.
const INGOT_KG := 50.0
## The item id scrap_recycled names for cast ingots.
const INGOT_ITEM := "Ingot"
## The dust vessel's item id (saves from before the crusher: a vessel on its way to the
## stores still turns into raw materials there).
const DUST_ITEM := "DustVessel"
## What a part of each category grinds down into: material id -> share of its mass.
const SCRAP_MIX := {
	"hull": {"steel": 0.8, "alloy": 0.2}, "frame": {"steel": 0.9, "titanium": 0.1},
	"wiring": {"copper": 0.8, "alloy": 0.2}, "electronics": {"copper": 0.5, "alloy": 0.4, "crystal": 0.1},
	"machinery": {"steel": 0.6, "copper": 0.2, "alloy": 0.2}, "engines": {"steel": 0.5, "titanium": 0.3, "copper": 0.2},
	"glass": {"glass": 1.0}, "piping": {"steel": 0.6, "copper": 0.4}, "fluids": {"steel": 0.8, "alloy": 0.2},
	"weapons": {"steel": 0.6, "tungsten": 0.2, "alloy": 0.2}, "fittings": {"steel": 0.5, "alloy": 0.5},
	"fasteners": {"steel": 1.0}, "cargo": {"steel": 0.7, "alloy": 0.3}, "modules": {"steel": 0.6, "alloy": 0.2, "copper": 0.2},
}

## The lines and the crusher: {auto (bool, both lines), lines: {line id: {stations: {id: {}
## or {lot, state ("waiting", "running" or "done")}}}}, crusher: {state ("" or "running"),
## lot, from (where it was picked up), dust: {material: kg in the smelter}, ingots:
## {material: count in the ingot yard}, cast (ingots its last run cast)}}. A lot is {item,
## name, qty, condition, mass (kg a unit), route ("grind" or "refurb", the survey's call)}.
var _line := {}


## Where the lines and the crusher stand now (a copy; see _line). line_changed follows
## every change.
func line_state() -> Dictionary:
	if _line.is_empty():
		_line = _new_line()
	return _line.duplicate(true)


## Lots that can go on a line, worst first: [{location, item, name, qty, condition, route
## (what the survey will say)}] from the stores, after the parts waiting in that line's
## intake bay ({crate, location "INTAKE", ...}, in the order they came).
func line_candidates(line := "a") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var items := StorageLayout.items()
	var fed := line_crates().keys().filter(func(id: String) -> bool:
		return str(_stock.crates[id]["line"]) == "in" and str(_stock.crates[id].get("line_id", "a")) == line)
	fed.sort_custom(func(a: String, b: String) -> bool: return int(a.get_slice("/", 1)) < int(b.get_slice("/", 1)))
	var infeed: Array[Dictionary] = []
	for id: String in fed:
		var c: Dictionary = _stock.crates[id]
		infeed.append({"crate": id, "location": "INTAKE", "item": str(c["item"]), "name": str(c["name"]), "qty": int(c["qty"]),
				"condition": float(c["condition"]), "route": str(c.get("route", survey_route(float(c["condition"]))))})
	for loc: String in _stock.stock:
		var have: Dictionary = _stock.stock[loc]
		var cond := float(have.get("condition", 1.0))
		if cond < REFURB_BELOW:
			var item := str(have["item"])
			out.append({"location": loc, "item": item, "name": str(items.get(item, {}).get("name", item)),
					"qty": int(have["qty"]), "condition": cond, "route": survey_route(cond)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.condition < b.condition if a.condition != b.condition else a.location < b.location)
	infeed.append_array(out)
	return infeed


## What the survey says for goods in this condition: "grind" (scrap) or "refurb".
static func survey_route(condition: float) -> String:
	return "grind" if condition <= GRIND_BELOW else "refurb"


## The dust `qty` of a part crushes down into: material id -> kg.
static func scrap_materials(item_id: String, qty: int) -> Dictionary:
	var d: Dictionary = StorageLayout.items().get(item_id, {})
	var kg := float(d.get("mass", 0.0)) * qty * RECOVERY
	var out := {}
	var mix: Dictionary = SCRAP_MIX.get(str(d.get("category", "")), {"steel": 1.0})
	for m: String in mix:
		out[m] = snappedf(kg * float(mix[m]), 0.1)
	return out


## Ingots in the crusher bay's ingot yard: material id -> count.
func ingots() -> Dictionary:
	return (line_state()["crusher"]["ingots"] as Dictionary).duplicate()


## Crates the lines have set down and no trolley has picked up yet: crate id -> crate
## ("line" is "in" for a part waiting in an intake bay ("line_id" says which), "scrap" for
## what a survey sent to the crusher on a bay's red pallet, "crush" for a lot on the
## crusher's feed pad).
func line_crates() -> Dictionary:
	var out := {}
	for id: String in _stock.crates:
		var c: Dictionary = _stock.crates[id]
		if c.has("line") and str(c.get("carrier", "")) == "":
			out[id] = c.duplicate(true)
	return out


## Asks a line or the crusher to do something; line_changed follows on every peer. Line ops
## take {line} ("a" or "b"; "a" if left out). `op`:
## - "load" {location}: the lot on a storage location goes into the survey (whole); or
##   {crate} a part waiting in the line's intake bay
## - "feed" {crate, line, spot}: a trolley sets a part down for a line's intake bay (line
##   "a"/"b"), or a lot for the crusher's feed pad (line "crusher")
## - "start" {station}: the machine holding a lot runs it
## - "send" {station}: a lot the machine has finished moves on (from the survey to the
##   straightener, or onto the bay's scrap pallet, by its route; from the coater onto the
##   line's trolley)
## - "route" {route}: overrides the survey's call for the lot in it ("grind" or "refurb")
## - "auto" {on}: the host's lines run themselves (loads, runs, sends, send their trolleys)
## - "finish" {station}: a machine's run is over (the host's line sends it); {line
##   "crusher"}: the crusher's run is over: the dust goes to the smelter, which casts ingots
## - "crush" {crate}: the crusher takes a lot off its feed pad and runs it (the host's plant
##   does this by itself)
func line_request(op: String, args: Dictionary = {}) -> void:
	var payload := args.duplicate()
	payload["op"] = op
	if _net:
		_net.call("request", "ship_bay.line", payload)
	else:
		var ok: Variant = _check_line(0, payload)
		if ok is Dictionary:
			_apply_line(ok)


## True where the lines run (time their machines and drive them on automatic): the host,
## or a game without Multiplayer.
func line_runs_here() -> bool:
	return _net == null or bool(_net.call("is_host"))


## True while a line's trolley stands at the end of its line, ready for finished lots
## (true when there is no yard to ask).
func line_trolley_home(line: String) -> bool:
	if fleet == null or not is_instance_valid(fleet):
		return true
	return bool(fleet.call("line_trolley_home", line))


## Sends a free trolley that can carry it to pick up a line crate. Returns its id, or ""
## when none is free.
func call_trolley_for(crate_id: String) -> String:
	var c: Dictionary = _stock.crates.get(crate_id, {})
	if c.is_empty() or fleet == null or not is_instance_valid(fleet):
		return ""
	var at := crate_position(crate_id)
	var id := str(fleet.call("free_for_beam", StorageLayout.kind_for(float(c.get("mass", 0.0)), str(c.get("item", ""))), at, _beam_claims.values()))
	if id != "":
		command_trolley(id, "put_away", {"crate": crate_id})
	return id


func _new_line() -> Dictionary:
	var lines := {}
	for l in LINES:
		var stations := {}
		for s in LINE_STATIONS:
			stations[s] = {}
		lines[l] = {"stations": stations}
	return {"auto": false, "lines": lines, "crusher": {"state": "", "lot": {}, "dust": {}, "ingots": {}, "cast": 0}}


## Where a finished lot goes from a station: another station, "scrap", "trolley", or "".
static func _line_next(station: String, lot: Dictionary) -> String:
	match station:
		"survey":
			return "scrap" if str(lot.get("route", "")) == "grind" else "straightener"
		"straightener":
			return "bath"
		"bath":
			return "coater"
		"coater":
			return "trolley"
	return ""


## The first of `count` places of this kind ("in" for a line's intake bay, "crush" for the
## crusher's pad) no waiting crate stands on, or -1.
func _free_line_spot(kind: String, line: String, count: int) -> int:
	var taken := {}
	for c: Dictionary in line_crates().values():
		if str(c["line"]) == kind and (kind == "crush" or str(c.get("line_id", "a")) == line):
			taken[int(c.get("line_spot", 0))] = true
	for i in count:
		if not taken.has(i):
			return i
	return -1


func _line_spot_taken(kind: String, line: String, spot: int) -> bool:
	for c: Dictionary in line_crates().values():
		if str(c["line"]) == kind and (kind == "crush" or str(c.get("line_id", "a")) == line) and int(c.get("line_spot", 0)) == spot:
			return true
	return false


## Where a line crate stands: an intake pallet, a scrap pallet, a crusher feed spot.
static func _line_spot_at(kind: String, line: String, spot: int) -> Vector3:
	match kind:
		"crush":
			return CrusherPlant.feed_spots()[spot]
		"scrap":
			return RefurbLine.scrap_spot(line)
	return RefurbLine.in_spots(line)[spot]


func _check_line(sender: int, payload: Dictionary) -> Variant:
	var line := line_state()
	var op := str(payload.get("op", ""))
	var l := str(payload.get("line", "a"))
	if not LINES.has(l) and not (l == "crusher" and ["feed", "finish"].has(op)):
		return "no such line"
	payload["line"] = l
	var st: Dictionary = line["lines"][l]["stations"] if LINES.has(l) else {}
	var s := str(payload.get("station", ""))
	var at: Dictionary = st.get(s, {})
	match op:
		"load":
			if not (st["survey"] as Dictionary).is_empty():
				return "the survey has a lot in it"
			if payload.has("crate"):
				var cid := str(payload["crate"])
				var c: Dictionary = _stock.crates.get(cid, {})
				if str(c.get("line", "")) != "in" or str(c.get("carrier", "")) != "" or str(c.get("line_id", "a")) != l:
					return "no such part in the intake bay"
				return {"op": op, "line": l, "crate": cid}
			var loc := str(payload.get("location", ""))
			var have: Dictionary = _stock.stock.get(loc, {})
			if have.is_empty():
				return "nothing there"
			if float(have.get("condition", 1.0)) >= REFURB_BELOW:
				return "already like new"
			return {"op": op, "line": l, "location": loc}
		"start":
			if at.is_empty() or str(at["state"]) != "waiting":
				return "nothing to start"
			return {"op": op, "line": l, "station": s}
		"finish":
			if sender != 0 and _net and sender != int(_net.call("local_peer_id")):
				return "the host's machines say when they finish"
			if l == "crusher":
				if str(line["crusher"]["state"]) != "running":
					return "not running"
				return {"op": op, "line": l}
			if at.is_empty() or str(at["state"]) != "running":
				return "not running"
			return {"op": op, "line": l, "station": s}
		"send":
			if at.is_empty() or str(at["state"]) != "done":
				return "nothing finished to send"
			var to := _line_next(s, at["lot"])
			if to == "":
				return "nowhere to send it"
			if to == "scrap":
				for c: Dictionary in line_crates().values():
					if str(c["line"]) == "scrap" and str(c.get("line_id", "")) == l:
						return "the scrap pallet is full"
				return {"op": op, "line": l, "station": s, "to": to}
			if to == "trolley":
				var lot: Dictionary = at["lot"]
				if not line_trolley_home(l) or not _stock.has_room(l, {"qty": int(lot["qty"]), "mass": float(lot["mass"])}):
					return "the line's trolley is away or full"
				return {"op": op, "line": l, "station": s, "to": to}
			if not (st[to] as Dictionary).is_empty():
				return "the next machine is busy"
			return {"op": op, "line": l, "station": s, "to": to}
		"route":
			var survey: Dictionary = st["survey"]
			var route := str(payload.get("route", ""))
			if survey.is_empty() or str(survey["state"]) == "running" or not ["grind", "refurb"].has(route):
				return "no lot to route"
			return {"op": op, "line": l, "route": route}
		"auto":
			return {"op": op, "on": bool(payload.get("on", false))}
		"feed":
			var cid := str(payload.get("crate", ""))
			var c: Dictionary = _stock.crates.get(cid, {})
			if c.is_empty() or str(c.get("carrier", "")) == "":
				return "no part on a trolley"
			var kind := "crush" if l == "crusher" else "in"
			var count := CrusherPlant.feed_spots().size() if l == "crusher" else RefurbLine.in_spots(l).size()
			var spot := int(payload.get("spot", -1))
			if spot < 0:
				spot = _free_line_spot(kind, l, count)
			if spot < 0 or spot >= count or _line_spot_taken(kind, l, spot):
				return "the crusher's pad is full" if l == "crusher" else "the intake bay is full"
			return {"op": op, "line": l, "crate": cid, "spot": spot}
		"crush":
			var cid := str(payload.get("crate", ""))
			var c: Dictionary = _stock.crates.get(cid, {})
			if str(c.get("line", "")) != "crush" or str(c.get("carrier", "")) != "":
				return "no such lot on the pad"
			if str(line["crusher"]["state"]) != "":
				return "the crusher is busy"
			return {"op": op, "crate": cid}
	return "unknown line request"


func _apply_line(payload: Dictionary) -> void:
	line_state()
	var l := str(payload.get("line", "a"))
	var st: Dictionary = _line["lines"][l]["stations"] if LINES.has(l) else {}
	var crusher: Dictionary = _line["crusher"]
	var s := str(payload.get("station", ""))
	var stock_moved := false
	match str(payload.get("op", "")):
		"load":
			if not (st["survey"] as Dictionary).is_empty():
				return
			if payload.has("crate"):
				var c: Dictionary = _stock.crates.get(str(payload["crate"]), {})
				if c.is_empty():
					return
				var cond := float(c["condition"])
				st["survey"] = {"state": "waiting", "lot": {"item": str(c["item"]), "name": str(c["name"]), "qty": int(c["qty"]),
						"condition": cond, "mass": float(c["mass"]), "route": survey_route(cond)}}
				_stock.crates.erase(str(payload["crate"]))
				stock_moved = true
			else:
				var loc := str(payload["location"])
				var have: Dictionary = _stock.stock.get(loc, {})
				if have.is_empty():
					return
				var item := str(have["item"])
				var known: Dictionary = StorageLayout.items().get(item, {})
				var cond := float(have.get("condition", 1.0))
				st["survey"] = {"state": "waiting", "lot": {"item": item, "name": str(known.get("name", item)),
						"qty": int(have["qty"]), "condition": cond, "mass": float(known.get("mass", 0.0)),
						"route": survey_route(cond)}}
				_stock.stock.erase(loc)
				stock_moved = true
		"start":
			if not (st.get(s, {}) as Dictionary).is_empty():
				st[s]["state"] = "running"
		"finish":
			if l == "crusher":
				_crushed(crusher)
			else:
				var at: Dictionary = st.get(s, {})
				if at.is_empty():
					return
				var lot: Dictionary = at["lot"]
				if LINE_AFTER.has(s):
					lot["condition"] = maxf(float(lot["condition"]), float(LINE_AFTER[s]))
					lot["stage"] = s
				at["state"] = "done"
		"send":
			var at: Dictionary = st.get(s, {})
			if at.is_empty():
				return
			var to := str(payload["to"])
			var lot: Dictionary = at["lot"]
			if to == "scrap":
				var p := RefurbLine.scrap_spot(l)
				_stock.crates[_line_crate_id()] = {"order_id": "line", "item": lot["item"], "qty": int(lot["qty"]),
						"name": lot["name"], "condition": clampf(float(lot["condition"]), 0.0, 1.0), "grade": "scrap",
						"mass": float(lot["mass"]), "spot": -1, "carrier": "", "at": [p.x, p.y, p.z],
						"line": "scrap", "line_id": l, "route": "grind"}
				stock_moved = true
			elif to == "trolley":
				# Onto the line's trolley as goods for the stores, as good as new.
				_stock.crates[_line_crate_id()] = {"order_id": "line", "item": lot["item"], "qty": int(lot["qty"]),
						"name": lot["name"], "condition": clampf(float(lot["condition"]), 0.0, 1.0), "grade": "refurbished",
						"mass": float(lot["mass"]), "spot": -1, "carrier": l}
				stock_moved = true
			else:
				st[to] = {"state": "waiting", "lot": lot}
			st[s] = {}
		"route":
			if not (st["survey"] as Dictionary).is_empty():
				st["survey"]["lot"]["route"] = str(payload["route"])
		"auto":
			_line["auto"] = bool(payload["on"])
		"feed":
			var c: Dictionary = _stock.crates.get(str(payload["crate"]), {})
			if c.is_empty():
				return
			var kind := "crush" if l == "crusher" else "in"
			var p := _line_spot_at(kind, l, int(payload["spot"]))
			c["carrier"] = ""
			c["spot"] = -1
			c["at"] = [p.x, p.y, p.z]
			c["line"] = kind
			c["line_id"] = l
			c["line_spot"] = int(payload["spot"])
			stock_moved = true
		"crush":
			var cid := str(payload["crate"])
			var c: Dictionary = _stock.crates.get(cid, {})
			if c.is_empty() or str(crusher["state"]) != "":
				return
			crusher["state"] = "running"
			crusher["lot"] = {"item": str(c["item"]), "name": str(c["name"]), "qty": int(c["qty"]), "condition": float(c["condition"]),
					"mass": float(c["mass"])}
			crusher["from"] = c.get("at", [])
			crusher["cast"] = 0
			_stock.crates.erase(cid)
			stock_moved = true
	if stock_moved:
		stock_changed.emit()
	line_changed.emit()


## The crusher's run is over: its lot's dust goes into the smelter, which casts every whole
## INGOT_KG of a material into an ingot for the ingot yard (raw materials for sale).
func _crushed(crusher: Dictionary) -> void:
	var lot: Dictionary = crusher.get("lot", {})
	var dust: Dictionary = crusher["dust"]
	var mats := scrap_materials(str(lot.get("item", "")), int(lot.get("qty", 0)))
	for m: String in mats:
		dust[m] = snappedf(float(dust.get(m, 0.0)) + float(mats[m]), 0.1)
	var cast := {}
	var n := 0
	var held: Dictionary = crusher["ingots"]
	for m: String in dust.keys():
		var k := floori(float(dust[m]) / INGOT_KG)
		if k <= 0:
			continue
		held[m] = int(held.get(m, 0)) + k
		dust[m] = snappedf(float(dust[m]) - k * INGOT_KG, 0.1)
		cast[m] = k * INGOT_KG
		n += k
	crusher["state"] = ""
	crusher["lot"] = {}
	crusher["cast"] = n
	if n > 0:
		scrap_recycled.emit(INGOT_ITEM, n, cast)


func _line_crate_id() -> String:
	var n := 1
	while _stock.crates.has("line/%d" % n):
		n += 1
	return "line/%d" % n


func _sample_delivery() -> void:
	var lines: Array = []
	# Components, fasteners, and the raw build material a ship is made of: hull plates and
	# wall panels, frame members, glass panes and cable.
	var material := {"HullPlate": 20, "DeckPlate": 6, "CabinWall": 4, "Stringer": 12, "DeckJoist": 8,
			"WindowPane": 4, "CockpitPane": 2, "MainLoom": 3, "CoolantPipe": 6}
	for item: String in ["IonThruster", "SideThruster", "LiftThruster", "HydrogenThruster", "DriveEngine",
			"BatteryRack", "Gyroscope", "HelmConsole", "M10", "M12", "RIVET_4", "Reactor", "FuelPump"] + material.keys():
		var d: Dictionary = StorageLayout.items().get(item, {})
		if d.is_empty():
			continue
		lines.append({"item_id": item, "qty": int(material[item]) if material.has(item) else (1 if float(d.get("mass", 0.0)) > 40.0 else 250),
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
	var c: Dictionary = _stock.crates.get(id, {})
	if c.has("materials"):
		# A dust vessel: its dust joins the raw materials for sale (Business keeps them).
		_stock.crates.erase(id)
		stock_changed.emit()
		crate_stored.emit(id, str(payload.get("location", "")))
		scrap_recycled.emit(DUST_ITEM, 1, c["materials"])
		return
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
	if not _stock.has_room(str(payload["trolley"]), _stock.crates[id]):
		return "that trolley is full"
	return payload


func _apply_carry(payload: Dictionary) -> void:
	if _stock.carry(str(payload.get("crate_id", "")), str(payload.get("trolley", ""))):
		stock_changed.emit()
		crate_carried.emit(str(payload["crate_id"]), str(payload["trolley"]))


## A transporter's deck, steering and status (the driving player sends it as it changes).
func send_transporter(payload: Dictionary) -> void:
	if _net:
		_net.call("request", "ship_bay.transporter", payload)
	else:
		_apply_transporter(payload)


## A cradle's pins, or a dolly picking it up ("dolly": kind) or setting it down ("dolly": "").
func send_cradle(payload: Dictionary) -> void:
	if _net:
		_net.call("request", "ship_bay.cradle", payload)
	else:
		_apply_cradle(payload)


## Settings > Debug > Ship, applied by the host for every player: "spawn" or "remove" a
## design standing on the apron (YARD_SHIP_DESIGNS), "clear_bay" takes the ship out of the
## bay, "restore_bay" brings the Kestrel back.
func debug_ship(action: String, design := "") -> void:
	var payload := {"action": action, "design": design}
	if _net:
		_net.call("request", "ship_bay.debug_ship", payload)
	elif _check_debug_ship(0, payload) is Dictionary:
		_apply_debug_ship(payload)


# --- Component rigs (Component Upgrades) -----------------------------------------------

## A rig's state: {unit ("" when empty), tier (the unit's, 0 when empty), testing (a sweep is
## running), result (the last test's, {} until one is shown), joints (hold-down joint id ->
## quality, for the ones made)}. {} for an unknown rig.
func rig_state(rig_id: String) -> Dictionary:
	if not RIGS.has(rig_id):
		return {}
	var r: Dictionary = rigs.get(rig_id, {})
	var unit := str(r.get("unit", ""))
	return {"unit": unit, "tier": EmitterRig.tier_of(unit) if unit != "" else 0,
			"testing": bool(r.get("testing", false)),
			"result": (r.get("result", {}) as Dictionary).duplicate(true),
			"joints": (r.get("joints", {}) as Dictionary).duplicate()}


## The unit on a rig as Shared Components built it (UpgradeUnits.attractor_coil's result:
## unit, tier, part, cover, bolts, tacks, box, mounts, xform, path; xform in rig space, the
## rig node's own frame), {} while the rig is empty or shows a stand-in.
func rig_unit(rig_id: String) -> Dictionary:
	var node: Node = rig_nodes.get(rig_id)
	return (node.get("unit_parts") as Dictionary) if is_instance_valid(node) else {}


## Puts a unit on a rig ("attractor_coil_1" on "rig_emitter"), for every player. Refused
## while the rig has one, or for a unit the rig doesn't take (RIGS takes).
func rig_mount(rig_id: String, unit_id: String) -> void:
	_send_rig({"rig": rig_id, "op": "mount", "unit": unit_id})


## Takes the unit off a rig, for every player. Refused while a hold-down is still made.
func rig_unmount(rig_id: String) -> void:
	_send_rig({"rig": rig_id, "op": "unmount"})


## The rig's test button: with a unit on, the host hears rig_test_requested and the rig
## shows it's waiting on the test.
func request_rig_test(rig_id: String) -> void:
	_send_rig({"rig": rig_id, "op": "test"})


## Quality's answer to rig_test_requested: {lines: [[label, old, new], ...], passed, note}.
## Every player's rig runs its sweep and shows the result.
func rig_show_test(rig_id: String, result: Dictionary) -> void:
	_send_rig({"rig": rig_id, "op": "result", "result": result.duplicate(true)})


## A rig's hold-down bolts for the unit on it, in spot space (shipyard_spot(rig_id): origin
## on the deck's middle at deck height, +X along the unit, +Z to the worker, y up): four M12
## bolts at the housing's base corners, 5 cm in ("rig_emitter/b1".."b4"), following the
## unit's tier. Tools works them. Empty for an unknown or empty rig.
func rig_points(rig_id: String) -> Array[FastenerPoint]:
	var out: Array[FastenerPoint] = []
	var unit := str(rig_state(rig_id).get("unit", ""))
	if rig_id != "rig_emitter" or unit == "":
		return out
	var i := 1
	for p: Vector3 in EmitterRig.hold_down_points(unit):
		var f := FastenerPoint.new()
		f.joint_id = "%s/b%d" % [rig_id, i]
		f.kind = "bolt"
		f.spec = "M12"
		f.position = p
		f.normal = Vector3.UP
		out.append(f)
		i += 1
	return out


func _is_rig_joint(joint_id: String) -> bool:
	return RIGS.has(FastenerPoint.slot_of(joint_id))


func _rig_joints(joint_id: String) -> Dictionary:
	return (rigs.get(FastenerPoint.slot_of(joint_id), {}) as Dictionary).get("joints", {})


## Notes a rig hold-down made or undone here (and, `share`, for the other players). Refused
## for a rig with nothing on it or a joint it doesn't have.
func _rig_joint(joint_id: String, made: bool, quality: float, share: bool) -> bool:
	var id := FastenerPoint.slot_of(joint_id)
	if not rigs.has(id) or not rig_points(id).any(func(f: FastenerPoint) -> bool: return f.joint_id == joint_id):
		return false
	var joints: Dictionary = (rigs[id] as Dictionary).get("joints", {})
	if made == joints.has(joint_id) and (not made or is_equal_approx(float(joints[joint_id]), quality)):
		return false
	if made:
		joints[joint_id] = clampf(quality, 0.0, 1.0)
	else:
		joints.erase(joint_id)
	rigs[id]["joints"] = joints
	if share:
		_share("ship_bay.joint", {"joint": joint_id, "made": made, "quality": quality})
	rig_changed.emit(id, rig_state(id))
	return true


func _send_rig(payload: Dictionary) -> void:
	if _net:
		_net.call("request", "ship_bay.rig", payload)
	elif _check_rig(0, payload) is Dictionary:
		_apply_rig(payload)


func _check_rig(_sender: int, payload: Dictionary) -> Variant:
	var id := str(payload.get("rig", ""))
	if not RIGS.has(id):
		return "no such rig"
	var on := str(rig_state(id).get("unit", ""))
	match str(payload.get("op", "")):
		"mount":
			var unit := str(payload.get("unit", ""))
			if on != "":
				return "the rig already has a unit on it"
			return payload if unit.begins_with(str(RIGS[id]["takes"])) else "that unit doesn't go on this rig"
		"unmount":
			if on == "":
				return "the rig is empty"
			return payload if (rig_state(id)["joints"] as Dictionary).is_empty() else "the unit is still bolted down"
		"test":
			return payload if on != "" else "the rig is empty"
		"result":
			return payload
	return "unknown rig action"


func _apply_rig(payload: Dictionary) -> void:
	var id := str(payload.get("rig", ""))
	var r: Dictionary = rigs.get(id, {})
	match str(payload.get("op", "")):
		"mount":
			r = {"unit": str(payload.get("unit", "")), "testing": false, "result": {}, "joints": {}}
		"unmount":
			r = {}
		"test":
			r["testing"] = true
		"result":
			r["testing"] = false
			r["result"] = (payload.get("result", {}) as Dictionary).duplicate(true)
	if r.is_empty():
		rigs.erase(id)
	else:
		rigs[id] = r
	rig_changed.emit(id, rig_state(id))
	match str(payload.get("op", "")):
		"test":
			if _net == null or bool(_net.call("is_host")):
				rig_test_requested.emit(id, str(r.get("unit", "")))
		"result":
			rig_test_shown.emit(id, rig_state(id)["result"])


## A ship's door opening or shutting, for every player.
func send_ship_door(payload: Dictionary) -> void:
	if _net:
		_net.call("request", "ship_bay.ship_door", payload)
	else:
		_apply_ship_door(payload)


func _apply_ship_door(payload: Dictionary) -> void:
	ship_door_state.emit(payload)


func _pass(_sender: int, payload: Dictionary) -> Variant:
	return payload


func _check_debug_ship(_sender: int, payload: Dictionary) -> Variant:
	var action := str(payload.get("action", ""))
	if action in ["spawn", "remove"]:
		return payload if YARD_SHIP_DESIGNS.has(str(payload.get("design", ""))) else "no such ship to stand on the apron"
	return payload if action in ["clear_bay", "restore_bay"] else "unknown debug action"


func _apply_debug_ship(payload: Dictionary) -> void:
	var design := str(payload.get("design", ""))
	match str(payload.get("action", "")):
		"spawn":
			if not yard_ships.has(design):
				yard_ships.append(design)
				yard_ships_changed.emit(yard_ships)
		"remove":
			if yard_ships.has(design):
				yard_ships.remove_at(yard_ships.find(design))
				yard_ships_changed.emit(yard_ships)
		"clear_bay":
			bay_cleared = true
			unload_ship()
		"restore_bay":
			bay_cleared = false
			if ship == null:
				load_ship("vs_kestrel")


func _apply_transporter(payload: Dictionary) -> void:
	transporter_state.emit(payload)


func _apply_cradle(payload: Dictionary) -> void:
	cradle_state.emit(payload)


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
	if not TROLLEYS.has(to) or not _stock.has_room(to, _stock.crates[id]):
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


func _check_beamed(_sender: int, payload: Dictionary) -> Variant:
	var by := str(payload.get("trolley", ""))
	var mass := float(StorageLayout.items().get(str(payload.get("component", "")), {}).get("mass", 0.0))
	if not TROLLEYS.has(by) or not _stock.has_room(by, {"qty": 1, "mass": mass}):
		return "that trolley is full"
	if str(payload.get("component", "")) == "":
		return "no part"
	var route := str(payload.get("route", "store"))
	return {"slot": str(payload.get("slot", "")), "trolley": by, "component": str(payload["component"]),
			"condition": clampf(float(payload.get("condition", 1.0)), 0.0, 1.0), "route": route if ["refurb", "grind"].has(route) else "store"}


func _apply_beamed(payload: Dictionary) -> void:
	var by := str(payload["trolley"])
	var id := _stock.beam(str(payload["component"]), float(payload["condition"]), by)
	if _beam_claims.get(str(payload["slot"])) == by:
		_beam_claims.erase(str(payload["slot"]))
	_clean_routes.erase(str(payload["slot"]))
	_loose.erase(str(payload["slot"]))
	if id == "":
		return
	if str(payload.get("route", "store")) != "store":
		# For the line: the trolley takes it to the in-feed, not the shelves.
		_stock.crates[id]["route"] = str(payload["route"])
		_stock.crates[id]["grade"] = "for the grinder" if str(payload["route"]) == "grind" else "for refurbishing"
	stock_changed.emit()
	crate_carried.emit(id, by)
	part_beamed.emit(id, by, str(payload["component"]), str(payload["slot"]))


func _check_kit(_sender: int, payload: Dictionary) -> Variant:
	var rig := int(payload.get("rig", -1))
	var bays := int(payload.get("bays", 0))
	var lifts := int(payload.get("lifts", 0))
	var ends := int(payload.get("ends", -1))
	if rig < 0 or rig > 15 or bays < 1 or bays > 4 or lifts < 1 or lifts > 4 or ends < 0 or ends > 3:
		return "not a scaffold change"
	return {"rig": rig, "bays": bays, "lifts": lifts, "ends": ends}


func _apply_kit(payload: Dictionary) -> void:
	kit_changed.emit(payload)


func _check_take(_sender: int, payload: Dictionary) -> Variant:
	if _stock.count(str(payload.get("item", ""))) < int(payload.get("qty", 1)):
		return "not enough in stock"
	return payload


func _apply_take(payload: Dictionary) -> void:
	if _stock.take(str(payload.get("item", "")), int(payload.get("qty", 1))):
		stock_changed.emit()


func _emit(signal_name: String, args: Array) -> void:
	emit_signal.callv([signal_name] + args)
