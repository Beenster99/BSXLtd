class_name DesignBus
extends Node
## The Design Room module's bus (Modules.bus("design")): the ship designs the crew draws up
## in the design room, and the views onto them (plans, the holotable, the walls).
##
## Other modules read designs through here:
##   var bus := Modules.bus("design") as DesignBus
##   bus.library.list()                 # saved designs
##   bus.library.current                # the open DesignRecord (or null)
##   bus.totals()                       # DesignTotals of the open design (parts list, cost...)
##   bus.problems()                     # DesignRules.check of the open design
##   bus.design_changed.connect(...)    # any edit, open or save
##   bus.register_wall_view(id, title, make)  # offer a panel to the room's walls
##
## Features (Flags): "design" (the module: designs in the save), "design.room" (the design
## room scene and its menu entry, off until the room is ready to play at test point 2).

signal design_changed

const SAVE_SECTION := "design"
const ROOM_SCENE := "design.room"
const ROOM_FLAG := "design.room"
## Keys at the holotable, standing at it with the console shut (the arrows and N are free of
## every other module's keys).
const KEY_HOLO_LEFT := "design.holo_left"
const KEY_HOLO_RIGHT := "design.holo_right"
const KEY_HOLO_IN := "design.holo_in"
const KEY_HOLO_OUT := "design.holo_out"
const KEY_HOLO_LAYER := "design.holo_layer"
const KEY_HOLO_CUT_DOWN := "design.holo_cut_down"
const KEY_HOLO_CUT_UP := "design.holo_cut_up"
## At the holotable: put what the hologram shows up on the wall you face (plan 3.3).
const KEY_HOLO_SEND := "design.holo_send"
const KEY_GROUP := "Design room"
const HOLO_KEYS: PackedStringArray = [KEY_HOLO_LEFT, KEY_HOLO_RIGHT, KEY_HOLO_IN, KEY_HOLO_OUT,
		KEY_HOLO_LAYER, KEY_HOLO_CUT_DOWN, KEY_HOLO_CUT_UP, KEY_HOLO_SEND]

var catalog: DesignCatalog = DesignCatalog.load_default()
var library := DesignLibrary.new()
var editor := DesignEditor.new(library)
## The ready-made module picked up to drop on a plan (the console's or a wall's), or "".
var carrying := ""
## The crew on the drawings: each other's cursors, friends walking inside, smart pings
## (internal/crew/design_crew.gd; plans and holotables attach themselves to it).
var crew: Node

## A module was picked up or put down.
signal carry_changed(module_id: String)
## Panels other modules offer the design room's walls (the parts market...): view id ->
## {title, make: Callable(px_per_m: float) -> Control}. WallBoard steps through them after its own.
var wall_views: Dictionary = {}
## A module offered or took back a wall panel.
signal wall_views_changed


## Offers a panel to the walls: `make` builds its Control for a wall drawn at px_per_m.
func register_wall_view(id: String, title: String, make: Callable) -> void:
	wall_views[id] = {"title": title, "make": make}
	wall_views_changed.emit()


func unregister_wall_view(id: String) -> void:
	if wall_views.erase(id):
		wall_views_changed.emit()


## Checks other modules add to WILL IT WORK (the motion module's clashes and ground check):
## id -> Callable(rec: DesignRecord, catalog: DesignCatalog, totals: DesignTotals) ->
## Array of DesignRules problem dicts. They run with the rules, once per edit (problems()).
var checks: Dictionary = {}
## Buttons other modules put on the console's top bar (the motion module's OPERATE):
## id -> {label, press: Callable(), tip, order}.
var console_tools: Dictionary = {}
signal console_tools_changed
## The holotable built its hologram again: `ship` is its "Ship" node (design space, metres;
## the table's turn, zoom, cut and section apply to anything put under it).
signal holo_built(table: Node3D, ship: Node3D)
## Walk-inside built the design at full size under `root` (design space, metres).
signal walk_built(root: Node3D, builder: Object)


## Adds a check to WILL IT WORK; it runs once per edit with the rules.
func register_check(id: String, check: Callable) -> void:
	checks[id] = check
	_problems_of = null
	_assessment_of = null
	design_changed.emit()


func unregister_check(id: String) -> void:
	if checks.erase(id):
		_problems_of = null
		_assessment_of = null
		design_changed.emit()


## Puts a button on the console's top bar (lowest order first).
func register_console_tool(id: String, label: String, press: Callable, tip: String = "", order: int = 50) -> void:
	console_tools[id] = {"label": label, "press": press, "tip": tip, "order": order}
	console_tools_changed.emit()


func unregister_console_tool(id: String) -> void:
	if console_tools.erase(id):
		console_tools_changed.emit()


## Symmetry mode for this player's plans (DesignMirror: OFF, ACROSS or ALONG); not shared.
var mirror := 0
signal mirror_changed(axis: int)


## What this player has picked on any drawing or the table (plan 3.3: touch a room on a wall
## plan and it lights up on the holotable, and the other way round): {kind, id}; not shared.
var focus := {}
signal focus_changed(kind: String, id: String)
## The section line thrown from a wall drawing onto the table as a cutting plane (plan 3.3),
## shared with the crew: {axis ("z": a cut across the ship at z = at; "x": along it at
## x = at), at}, or {} for none.
var section := {}
signal section_changed
## "Look here" (plan 3.4): someone pulled everyone's view to a spot on a deck.
signal look_requested(deck: int, at: Vector2, who: String, colour: Color)


func set_focus(kind: String, id: String) -> void:
	if str(focus.get("kind", "")) == kind and str(focus.get("id", "")) == id:
		return
	focus = {"kind": kind, "id": id} if id != "" else {}
	focus_changed.emit(kind, id)


## Throws a section line onto the table (axis "z" or "x" at `at` m), or clears it (axis "").
func set_section(axis: String, at: float = 0.0) -> void:
	var p := {"axis": axis, "at": at}
	if _net and bool(_net.call("is_online")):
		_net.call("request", "design.section", p)
	else:
		_apply_section(p)


func _apply_section(p: Dictionary) -> void:
	var axis := str(p.get("axis", ""))
	section = {"axis": axis, "at": float(p.get("at", 0.0))} if axis in ["x", "z"] else {}
	section_changed.emit()


## Pulls everyone's drawings (and this player's) to a spot on a deck.
func look_here(deck: int, at: Vector2) -> void:
	var p := {"deck": deck, "x": at.x, "z": at.y}
	if _net and bool(_net.call("is_online")):
		_net.call("request", "design.look", p)
	else:
		_apply_look(p)


func _apply_look(p: Dictionary) -> void:
	var peer := int(p.get("peer", 0))
	var who := "You"
	var col := Color(1.0, 0.7, 0.2)
	if _net and peer != 0:
		if _net.has_method("player_name"):
			who = str(_net.call("player_name", peer))
		if _net.has_method("player_colour"):
			col = _net.call("player_colour", peer)
	look_requested.emit(int(p.get("deck", 0)), Vector2(float(p.get("x", 0.0)), float(p.get("z", 0.0))), who, col)


## OFF, then mirrored across the centre line, then fore and aft, then off again.
func cycle_mirror() -> void:
	mirror = (mirror + 1) % 3
	mirror_changed.emit(mirror)


func _init() -> void:
	crew = CrewMarks.new()
	crew.set("bus", self)
	add_child(crew)
	library.opened.connect(func(_r: DesignRecord) -> void: _changed())
	library.edited.connect(func(_op: Dictionary) -> void: _changed())
	library.list_changed.connect(func() -> void: _changed())


## Every view of the design hears of an edit; what they all read (the rules, the measured
## structure) is worked out once, when first asked for after it.
func _changed() -> void:
	_problems = []
	_problems_of = null
	_structure = null
	_structure_of = null
	_totals = null
	_totals_of = null
	_plan = {}
	_plan_of = null
	_assessment = null
	_assessment_of = null
	design_changed.emit()


var _problems: Array[Dictionary] = []
var _problems_of: DesignRecord
var _structure: DesignStructure
var _structure_of: DesignRecord
var _totals: DesignTotals
var _totals_of: DesignRecord
var _plan: Dictionary = {}
var _plan_of: DesignRecord
var _assessment: DesignAssessment
var _assessment_of: DesignRecord


const ROOM_PATH := "res://modules/design/internal/room/design_room.tscn"
const Samples := preload("res://modules/design/internal/sample_designs.gd")
const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")
const CrewMarks := preload("res://modules/design/internal/crew/design_crew.gd")
const ContractFitView := preload("res://modules/design/internal/views/contract_fit.gd")
## The contract fit assessment on the wrist screen (F1): its channel id and place (the wrist
## order: 10 stock, 20 parts market, 30 contract fit, 40 accounts, 50 crew).
const FIT_CHANNEL := "design.fit"
const FIT_CHANNEL_ORDER := 30


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, library)
	HudSlots.register_holo_channel(FIT_CHANNEL, "Contract fit", _fit_channel, FIT_CHANNEL_ORDER)
	if Modules.ready_done:
		_hook_net()
	else:
		Modules.modules_ready.connect(_hook_net, CONNECT_ONE_SHOT)
	if Flags.is_on(ROOM_FLAG):
		Router.register_scene(ROOM_SCENE, ROOM_PATH)
		Keys.register(KEY_HOLO_LEFT, "Holotable: turn the hologram left", KEY_LEFT, KEY_GROUP)
		Keys.register(KEY_HOLO_RIGHT, "Holotable: turn the hologram right", KEY_RIGHT, KEY_GROUP)
		Keys.register(KEY_HOLO_IN, "Holotable: zoom in", KEY_UP, KEY_GROUP)
		Keys.register(KEY_HOLO_OUT, "Holotable: zoom out", KEY_DOWN, KEY_GROUP)
		Keys.register(KEY_HOLO_LAYER, "Holotable: next layer", KEY_N, KEY_GROUP)
		Keys.register(KEY_HOLO_CUT_DOWN, "Holotable: cut away the top deck", KEY_PAGEDOWN, KEY_GROUP)
		Keys.register(KEY_HOLO_CUT_UP, "Holotable: put the top deck back", KEY_PAGEUP, KEY_GROUP)
		Keys.register(KEY_HOLO_SEND, "Holotable: show this view on the wall you face", KEY_J, KEY_GROUP)
		Menu.register_entry(ROOM_SCENE, "Design room", ROOM_SCENE, 30)
		Shots.register("design_console", ROOM_SCENE, _shot_setup.bind(false), 40)
		Shots.register("design_room", ROOM_SCENE, _shot_setup.bind(true), 40)
		Menu.register_settings_section(Menu.DEBUG, "design.debug", "Design room",
				_debug_panel, 30)
		# The station is optional (its module may be off), so it is reached by name only,
		# once every module has registered.
		if Modules.ready_done:
			_hook_yard()
		else:
			Modules.modules_ready.connect(_hook_yard, CONNECT_ONE_SHOT)


# Designing together (Wave 3): one design open for the whole session. Every edit goes
# through the multiplayer module's host, which orders them and applies them on every
# machine; opening a design opens it for everyone; a player who joins gets the open design.

const NET_SECTION := "design"
var _net: Object
var _opening_from_net := false
## Players in walk-inside: peer id -> true (so the others can show them walking about).
var walkers: Dictionary = {}
## Someone else's edit landed here: their name, colour and what they did ("added a Cargo hold").
signal crew_edited(who: String, colour: Color, what: String)
signal walkers_changed


func _hook_net() -> void:
	hook_net(Modules.bus("multiplayer"))


## Shares the design through `net` (the multiplayer bus, or a test's stand-in with the same
## register_event / request / register_snapshot_provider / local_peer_id / is_online).
func hook_net(net: Object) -> void:
	if net == null or not net.has_method("register_event"):
		return
	_unhook_net()
	_net = net
	_net.call("register_event", "design.op", _apply_op, _stamp)
	_net.call("register_event", "design.walk", _apply_walk, _stamp)
	if _net.has_signal("peer_left") and not _net.is_connected("peer_left", _on_peer_left):
		_net.connect("peer_left", _on_peer_left)
	_net.call("register_event", "design.undo", func(p: Dictionary) -> void: editor.apply_undo(str(p.author)), _stamp)
	_net.call("register_event", "design.redo", func(p: Dictionary) -> void: editor.apply_redo(str(p.author)), _stamp)
	_net.call("register_event", "design.open", _apply_open, _stamp)
	# Saved modules and designs are shared with the crew (beenster, 19 Nov).
	_net.call("register_event", "design.module", _apply_module, _stamp)
	_net.call("register_event", "design.stored", _apply_stored, _stamp)
	_net.call("register_event", "design.section", _apply_section, _stamp)
	_net.call("register_event", "design.look", _apply_look, _stamp)
	_net.call("register_snapshot_provider", NET_SECTION, self)
	editor.send = func(kind: String, payload: Dictionary) -> void: _net.call("request", "design." + kind, payload)
	editor.me = func() -> String: return "p%d" % int(_net.call("local_peer_id"))
	if not library.opened.is_connected(_share_open):
		library.opened.connect(_share_open)
	if not library.modules_changed.is_connected(_share_modules):
		library.modules_changed.connect(_share_modules)
	if not library.stored.is_connected(_share_stored):
		library.stored.connect(_share_stored)
	crew.call("hook", _net)


func _unhook_net() -> void:
	if _net == null:
		return
	crew.call("unhook")
	if _net.has_signal("peer_left") and _net.is_connected("peer_left", _on_peer_left):
		_net.disconnect("peer_left", _on_peer_left)
	for e in ["design.op", "design.undo", "design.redo", "design.open", "design.walk", "design.module", "design.stored",
			"design.section", "design.look"]:
		_net.call("unregister_event", e)
	_net.call("unregister_snapshot_provider", NET_SECTION)
	editor.send = Callable()
	editor.me = Callable()
	if library.opened.is_connected(_share_open):
		library.opened.disconnect(_share_open)
	if library.modules_changed.is_connected(_share_modules):
		library.modules_changed.disconnect(_share_modules)
	if library.stored.is_connected(_share_stored):
		library.stored.disconnect(_share_stored)
	_net = null


## The host stamps who sent an edit, so each player's undo stays their own.
func _stamp(sender: int, payload: Dictionary) -> Variant:
	if payload.has("op") and not payload.op is Dictionary:
		return "not an edit"
	var out := payload.duplicate()
	out["author"] = "p%d" % sender
	out["peer"] = sender
	return out


func _apply_op(p: Dictionary) -> void:
	var undo_op := editor.apply_op(p.op, str(p.author))
	var peer := int(p.get("peer", 0))
	if undo_op.is_empty() or _net == null or peer == int(_net.call("local_peer_id")):
		return
	crew_edited.emit(str(_net.call("player_name", peer)) if _net.has_method("player_name") else "Crew",
			_net.call("player_colour", peer) if _net.has_method("player_colour") else Color.WHITE,
			describe_op(p.op))


## A few words on an edit, for the crew to see who did what.
func describe_op(op: Dictionary) -> String:
	var kind := str(op.get("op", ""))
	var thing := ""
	if op.has("room") and op.room is Dictionary:
		var rt := catalog.room(str(op.room.get("type", "")))
		thing = rt.display_name if rt else "a room"
	elif op.has("component") and op.component is Dictionary:
		var pt := catalog.part(str(op.component.get("type", "")))
		thing = pt.display_name if pt else "a part"
	elif op.has("mount") and op.mount is Dictionary:
		var pt := catalog.part(str(op.mount.get("type", "")))
		thing = pt.display_name if pt else "a part on the hull"
	if kind == "shift_decks":
		return "added a deck below" if int(op.get("by", 0)) > 0 else "took out the deck below"
	if kind == "set_frame":
		var key := str(op.get("key", ""))
		var v: Variant = op.get("value")
		if key.begins_with("panel:"):
			return "put a window in the hull" if v is Dictionary and bool(v.get("glass", false)) else "plated over a hull panel"
		return "reshaped the hull"
	var verb := kind.get_slice("_", 0)
	var noun := kind.substr(verb.length() + 1).replace("_", " ")
	match verb:
		"add":
			return "added %s" % (thing if thing != "" else "a " + noun)
		"remove":
			return "removed %s" % (thing if thing != "" else "a " + noun)
		"set":
			return "changed the %s" % ("design" if noun == "meta" else noun)
	return kind.replace("_", " ")


## Says whether this player is walking inside the design (the others see them there).
func set_walking(on: bool) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", "design.walk", {"on": on})


## The multiplayer module, for walk-inside's crew (null without it).
func net() -> Object:
	return _net


func _apply_walk(p: Dictionary) -> void:
	var peer := int(p.get("peer", 0))
	if bool(p.get("on", false)):
		walkers[peer] = true
	else:
		walkers.erase(peer)
	walkers_changed.emit()


func _on_peer_left(peer_id: int, _why: String) -> void:
	if walkers.erase(peer_id):
		walkers_changed.emit()


## A design opened here is opened for everyone in the session.
func _share_open(rec: DesignRecord) -> void:
	if _opening_from_net or _net == null or not bool(_net.call("is_online")) or rec == null:
		return
	_net.call("request", "design.open", {"record": rec.to_dict()})


var _from_net := false
var _shared_modules: Dictionary = {}


## Each module saved here goes to the crew once (modules_changed fires for any change).
func _share_modules() -> void:
	if _from_net or _net == null or not bool(_net.call("is_online")):
		return
	for m: Dictionary in library.modules():
		if not _shared_modules.has(m.id):
			_shared_modules[m.id] = true
			_net.call("request", "design.module", {"module": m})


func _share_stored(design_id: String) -> void:
	if _from_net or _net == null or not bool(_net.call("is_online")):
		return
	var d := library.stored_design(design_id)
	if not d.is_empty():
		_net.call("request", "design.stored", {"record": d})


func _apply_module(p: Dictionary) -> void:
	if int(p.get("peer", 0)) == (int(_net.call("local_peer_id")) if _net else 0):
		return
	_from_net = true
	var id := library.receive_module(p.get("module", {}))
	_shared_modules[id] = true
	_from_net = false


func _apply_stored(p: Dictionary) -> void:
	if int(p.get("peer", 0)) == (int(_net.call("local_peer_id")) if _net else 0):
		return
	_from_net = true
	library.receive_design(p.get("record", {}))
	_from_net = false


func _apply_open(p: Dictionary) -> void:
	var data: Dictionary = p.get("record", {})
	if data.is_empty() or library.current and _same(library.current.to_dict(), data):
		return
	_opening_from_net = true
	library.adopt(data)
	_opening_from_net = false


static func _same(a: Dictionary, b: Dictionary) -> bool:
	var x := a.duplicate()
	var y := b.duplicate()
	x.erase("id")
	y.erase("id")
	return x == y


## The open design, for a player joining the session.
func get_net_snapshot() -> Dictionary:
	var out := {"walkers": walkers.keys(), "modules": library.modules(), "section": section.duplicate()}
	var designs: Array = []
	for row: Dictionary in library.list():
		designs.append(library.stored_design(str(row.id)))
	out["designs"] = designs
	if library.current:
		out["record"] = library.current.to_dict()
	return out


func apply_net_snapshot(data: Dictionary) -> void:
	_from_net = true
	for m: Dictionary in data.get("modules", []):
		_shared_modules[library.receive_module(m)] = true
	for d: Dictionary in data.get("designs", []):
		library.receive_design(d)
	_from_net = false
	_apply_open(data)
	walkers = {}
	for w in data.get("walkers", []):
		walkers[int(w)] = true
	walkers_changed.emit()
	_apply_section(data.get("section", {}))


func _hook_yard() -> void:
	var yard := Modules.bus("yard")
	if yard and yard.has_signal("station_ready") and not yard.is_connected("station_ready", furnish_station):
		yard.connect("station_ready", furnish_station)
	# The berth grows with reputation: re-check the fit when it does.
	if yard and yard.has_signal("berth_tier_changed") and not yard.is_connected("berth_tier_changed", _on_berth_tier):
		yard.connect("berth_tier_changed", _on_berth_tier)


func _on_berth_tier(_tier: int = 0) -> void:
	_problems_of = null
	design_changed.emit()


## The design room's wall planes: the station's (the yard module's design_room_walls), or
## the stand-in planes (the same ids and convention) while it has none.
func room_walls() -> Array[Dictionary]:
	var yard := Modules.bus("yard")
	if yard and yard.has_method("design_room_walls"):
		var out: Array[Dictionary] = []
		out.assign(yard.call("design_room_walls"))
		if not out.is_empty():
			return out
	return Furnishing.stand_in_walls()


## Puts the holotable, the interactive walls and the console into the station's design room.
func furnish_station(_station: Node3D = null) -> void:
	var yard := Modules.bus("yard")
	var root: Node3D = yard.call("design_room_root") if yard and yard.has_method("design_room_root") else null
	if root == null or root.has_node("DesignFurnishing"):
		return
	var f: Node3D = Furnishing.new()
	root.add_child(f)
	f.call("setup", self, room_walls())


## The company's current build berth, {name, length, beam, height} of clear space, m: the yard
## module's `build_berth()` (it grows with reputation), else its first "build" berth, else
## DesignBerth.DEFAULT. `berth_override` wins (tests, previews).
var berth_override: Dictionary = {}
func berth() -> Dictionary:
	if not berth_override.is_empty():
		return DesignBerth.from_yard(berth_override)
	var yard := Modules.bus("yard")
	if yard and yard.has_method("build_berth"):
		return DesignBerth.from_yard(yard.call("build_berth"))
	var list_fn := "current_berths" if yard and yard.has_method("current_berths") else "berths"
	if yard and yard.has_method(list_fn):
		for b: Dictionary in yard.call(list_fn):
			if str(b.get("kind", "")) == "build" and b.get("box") is AABB:
				return DesignBerth.from_yard(b.box, str(b.get("name", "")))
	return DesignBerth.DEFAULT.duplicate()


## True when the open design's ship order needs a bigger berth tier (ShipOrders' "berth") than
## the company has now.
func order_needs_larger_berth() -> bool:
	if library.current == null or library.current.order.is_empty():
		return false
	return int(library.current.order.get("berth", 1)) > int(berth().get("tier", 1))


## How the open design sits in the build berth (DesignBerth.fit).
func berth_fit() -> Dictionary:
	if library.current == null:
		return {}
	return DesignBerth.fit(library.current, berth())


func unregister_module() -> void:
	_unhook_net()
	HudSlots.unregister_holo_channel(FIT_CHANNEL)
	Saves.unregister_section(SAVE_SECTION)
	Menu.unregister_entry(ROOM_SCENE)
	Menu.unregister_settings_section(Menu.DEBUG, "design.debug")
	for k: String in HOLO_KEYS:
		Keys.unregister(k)


## The wrist channel's view: the same contract fit screen as the walls, at wall-sized text.
func _fit_channel(_glass: bool) -> Control:
	var v := ContractFitView.new()
	v.setup(self, 24)
	return v


## Opens a new design holding the sample skiff (Debug tab, tests, screenshots).
func open_sample() -> DesignRecord:
	var rec := library.create("Sample skiff")
	Samples.skiff(rec, catalog)
	library.save_current()
	# Built straight into the record, so share it as it now stands.
	_share_open(rec)
	return rec


func _shot_setup(scene: Node, room_view: bool) -> void:
	open_sample()
	if scene.has_method("set_room_view"):
		scene.set_room_view(room_view)


func _debug_panel() -> Control:
	var b := Button.new()
	b.text = "Open the sample skiff"
	b.pressed.connect(func() -> void: open_sample())
	return b


## The open design's numbers, or null with nothing open.
## Picks up a ready-made module ("" puts it down).
func carry(module_id: String) -> void:
	carrying = module_id if library.module(module_id).size() > 0 else ""
	carry_changed.emit(carrying)


## Drops the module being carried into the open design, centred on `at` on `deck`. One undo
## takes it away. Returns the new room's id, or "".
func drop_carried(deck: int, at: Vector2) -> String:
	var rec := library.current
	var op := library.place_module_op(carrying, rec, deck, at)
	if op.is_empty():
		return ""
	var rid: String = op.ops[0].room.id
	editor.do(op)
	carry("")
	return rid if rec.rooms.has(rid) else ""


func totals() -> DesignTotals:
	if library.current == null:
		return null
	if _totals_of != library.current:
		_totals = DesignTotals.compute(library.current, catalog, structure(), frame_plan())
		_totals_of = library.current
	return _totals


## The structure proposed for the open design (DesignFrame.propose), kept till the next edit.
## Read only: it is shared by every view.
func frame_plan() -> Dictionary:
	if library.current == null:
		return {}
	if _plan_of != library.current:
		_plan = DesignFrame.propose(library.current)
		_plan_of = library.current
	return _plan


## How the open design answers its ship order (DesignAssessment), kept till the next edit
## (null with nothing open). Every contract fit view reads this one.
func assessment() -> DesignAssessment:
	if library.current == null:
		return null
	if _assessment_of != library.current:
		_assessment = DesignAssessment.assess(library.current, catalog, totals(), problems(), library.current.order)
		_assessment_of = library.current
	return _assessment


## The open design's problems ([] with nothing open).
func problems() -> Array[Dictionary]:
	if library.current == null:
		return []
	if _problems_of != library.current:
		_problems = DesignRules.check(library.current, catalog, totals())
		var bp := DesignBerth.problem(berth_fit())
		if not bp.is_empty():
			_problems.append(bp)
		for id: String in checks:
			var more: Variant = (checks[id] as Callable).call(library.current, catalog, totals())
			if more is Array:
				for p: Variant in more:
					if p is Dictionary:
						_problems.append(p)
		_problems_of = library.current
	return _problems


## The open design's measured structure (DesignStructure.measure), kept till the next edit.
func structure() -> DesignStructure:
	if library.current == null:
		return null
	if _structure_of != library.current:
		_structure = DesignStructure.measure(library.current)
		_structure_of = library.current
	return _structure
