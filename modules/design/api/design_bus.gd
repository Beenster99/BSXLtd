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
##
## Features (Flags): "design" (the module: designs in the save), "design.room" (the design
## room scene and its menu entry, off until the room is ready to play at test point 2).

signal design_changed

const SAVE_SECTION := "design"
const ROOM_SCENE := "design.room"
const ROOM_FLAG := "design.room"

var catalog: DesignCatalog = DesignCatalog.load_default()
var library := DesignLibrary.new()
var editor := DesignEditor.new(library)
## The ready-made module picked up to drop on a plan (the console's or a wall's), or "".
var carrying := ""

## A module was picked up or put down.
signal carry_changed(module_id: String)


func _init() -> void:
	library.opened.connect(func(_r: DesignRecord) -> void: design_changed.emit())
	library.edited.connect(func(_op: Dictionary) -> void: design_changed.emit())
	library.list_changed.connect(func() -> void: design_changed.emit())


const ROOM_PATH := "res://modules/design/internal/room/design_room.tscn"
const Samples := preload("res://modules/design/internal/sample_designs.gd")
const Furnishing := preload("res://modules/design/internal/room/design_furnishing.gd")


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, library)
	if Modules.ready_done:
		_hook_net()
	else:
		Modules.modules_ready.connect(_hook_net, CONNECT_ONE_SHOT)
	if Flags.is_on(ROOM_FLAG):
		Router.register_scene(ROOM_SCENE, ROOM_PATH)
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


func _hook_net() -> void:
	hook_net(Modules.bus("multiplayer"))


## Shares the design through `net` (the multiplayer bus, or a test's stand-in with the same
## register_event / request / register_snapshot_provider / local_peer_id / is_online).
func hook_net(net: Object) -> void:
	if net == null or not net.has_method("register_event"):
		return
	_unhook_net()
	_net = net
	_net.call("register_event", "design.op", func(p: Dictionary) -> void: editor.apply_op(p.op, str(p.author)), _stamp)
	_net.call("register_event", "design.undo", func(p: Dictionary) -> void: editor.apply_undo(str(p.author)), _stamp)
	_net.call("register_event", "design.redo", func(p: Dictionary) -> void: editor.apply_redo(str(p.author)), _stamp)
	_net.call("register_event", "design.open", _apply_open, _stamp)
	_net.call("register_snapshot_provider", NET_SECTION, self)
	editor.send = func(kind: String, payload: Dictionary) -> void: _net.call("request", "design." + kind, payload)
	editor.me = func() -> String: return "p%d" % int(_net.call("local_peer_id"))
	if not library.opened.is_connected(_share_open):
		library.opened.connect(_share_open)


func _unhook_net() -> void:
	if _net == null:
		return
	for e in ["design.op", "design.undo", "design.redo", "design.open"]:
		_net.call("unregister_event", e)
	_net.call("unregister_snapshot_provider", NET_SECTION)
	editor.send = Callable()
	editor.me = Callable()
	if library.opened.is_connected(_share_open):
		library.opened.disconnect(_share_open)
	_net = null


## The host stamps who sent an edit, so each player's undo stays their own.
func _stamp(sender: int, payload: Dictionary) -> Variant:
	if payload.has("op") and not payload.op is Dictionary:
		return "not an edit"
	var out := payload.duplicate()
	out["author"] = "p%d" % sender
	return out


## A design opened here is opened for everyone in the session.
func _share_open(rec: DesignRecord) -> void:
	if _opening_from_net or _net == null or not bool(_net.call("is_online")) or rec == null:
		return
	_net.call("request", "design.open", {"record": rec.to_dict()})


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
	return {"record": library.current.to_dict()} if library.current else {}


func apply_net_snapshot(data: Dictionary) -> void:
	_apply_open(data)


func _hook_yard() -> void:
	var yard := Modules.bus("yard")
	if yard and yard.has_signal("station_ready") and not yard.is_connected("station_ready", furnish_station):
		yard.connect("station_ready", furnish_station)


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


func unregister_module() -> void:
	_unhook_net()
	Saves.unregister_section(SAVE_SECTION)
	Menu.unregister_entry(ROOM_SCENE)
	Menu.unregister_settings_section(Menu.DEBUG, "design.debug")


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
	return DesignTotals.compute(library.current, catalog) if library.current else null


## The open design's problems ([] with nothing open).
func problems() -> Array[Dictionary]:
	if library.current == null:
		return []
	return DesignRules.check(library.current, catalog)
