class_name TradesBus
extends Node
## Tools module bus (Modules.bus("trades"); shown to players as Tools, its id stays "trades").
## The hands-on tools the player owns: bolting, riveting, welding, wiring, lifting and fitting.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
## Trades reports what was built (JointResult measurements); Quality decides if it is good.

signal tool_equipped(peer_id: int, tool_id: StringName)
signal joint_started(joint_id: StringName, trade: StringName, peer_id: int)
## 0..1, for HUDs and spectators.
signal joint_progress(joint_id: StringName, progress: float)
signal joint_completed(result: JointResult)
## The joint was taken apart for rework; any record of it is stale.
signal joint_removed(joint_id: StringName)
## A player's tractor beam moved a loose part (yard space is the world here), or let go of it
## (holding false). Multiplayer can mirror the part from this.
signal part_beamed(peer_id: int, slot_id: String, xform: Transform3D, holding: bool)
## Component Upgrades (trades.unit_mounts): a joint inside a unit on an upgrade rig was made
## or taken out ("unit_<rig>_<mount>/<b1|w1|c1...>"; quality 0..1 as for ship joints).
signal unit_joint_changed(rig_id: String, joint_id: String, made: bool, quality: float)
## The unit on a rig changed: its state as unit_state() gives it ({} once it's off the rig).
signal unit_changed(rig_id: String, state: Dictionary)
## trades.parts_on_decks: a part beamed onto a trolley (Ship and Bay's part_beamed, its crate
## `crate_id`) has landed and come to rest on that trolley's `deck`, as itself: the loose part
## `body` stays, stacks with the others and rides with the deck. Ship and Bay draws no crate for
## it, and its deck_part_left(crate_id, trolley_id) when the crate leaves the trolley sends the
## body away.
signal part_on_deck(crate_id: String, body: Node3D, deck: Node3D)
## trades.cutting_bed: a plate template was traced at the ship or deleted; templates() has them.
signal templates_changed
## trades.beam_designer: a ship's beam design changed; beam_design(ship_id) has it.
signal beam_design_changed(ship_id: String)
## trades.beam_versions: the versions a design may keep side by side.
const BEAM_VERSIONS: Array[String] = ["A", "B", "C"]

const WORKBENCH := "workbench"
const BENCH_SCENE := "res://modules/trades/internal/bench/workbench.tscn"
## The trades, each behind its flag "trades.<trade>". Their practice bench is no longer on
## the menu: the work happens on the ship in the yard.
const TRADES: Array[String] = ["bolting", "riveting", "welding", "wiring"]
## What we add to Ship and Bay's shipyard (behind the flag "trades.shipyard"): you, the
## worker with the tools.
const YARD_RIG := "ToolsRig"
## The group Ship and Bay knows other modules' nodes in the yard by.
const YARD_GUEST_GROUP := "yard_guest"
## The Tools keys, input actions in Settings > Key binds ("Tools"); walking, F and Esc are
## Core's (Keys.FORWARD..., Keys.INTERACT, Keys.CANCEL).
const KEY_TOOL := "trades.tool_"         # + 1..9: pick a tool off the hotbar
const KEY_VIEW := "trades.view"
const KEY_TURN_LEFT := "trades.turn_left"
const KEY_TURN_RIGHT := "trades.turn_right"
## Held: the mouse turns the part in the tractor beam instead of the view.
const KEY_ROTATE := "trades.rotate"
## Held: the key data of the part or joint you are looking at.
## The practice bench's: start the job again, the next part in the tray.
const KEY_RESET := "trades.reset"
const KEY_NEXT := "trades.next"
const KEY_MODE := "trades.mode"           # the powered tools' mode: fasten / undo
const KEY_HELMET := "trades.helmet"       # the welding shield up / down
## Your hover board in the yard (trades.hover_board): out / away, and up / down while riding.
const KEY_BOARD := "trades.board"
const KEY_BOARD_UP := "trades.board_up"
const KEY_BOARD_DOWN := "trades.board_down"
const KEY_GROUP := "Tools"
## The wrist screen's Specs channel: torque windows and rivet heights (its flag too).
const SPECS_CHANNEL := "trades.specs"
const HOTBAR_KEYS := 9
## Saves section version for the traced templates.
const SAVE_VERSION := 1

var _sites: Dictionary = {}
var _results: Dictionary = {}
var _modifiers: Dictionary = {}  # str(player_id) -> {effect_key: value}
var _units: Dictionary = {}  # rig_id -> unit_state()
var _deck_parts: Dictionary = {}  # crate_id -> the loose part on a trolley's deck
var _traced: Array[Dictionary] = []  # trades.cutting_bed: templates traced off plates
var _next_template := 1
var _beam_designs: Dictionary = {}  # trades.beam_designer: ship id -> {showing, versions {letter: rows}}


func register_module() -> void:
	for i in HOTBAR_KEYS:
		Keys.register(KEY_TOOL + str(i + 1), "Tool %d" % (i + 1), (KEY_1 + i) as Key, KEY_GROUP)
	Keys.register(KEY_VIEW, "First / third person", KEY_V, KEY_GROUP)
	Keys.register(KEY_TURN_LEFT, "Turn left / amps down", KEY_Q, KEY_GROUP)
	Keys.register(KEY_TURN_RIGHT, "Turn right / amps up", KEY_E, KEY_GROUP)
	Keys.register(KEY_ROTATE, "Rotate the part in the beam (hold)", KEY_R, KEY_GROUP)
	Keys.register(KEY_RESET, "Start the bench job again", KEY_BACKSPACE, KEY_GROUP)
	Keys.register(KEY_NEXT, "Next part in the tray", KEY_G, KEY_GROUP)
	Keys.register(KEY_MODE, "Tool mode: fasten / undo", KEY_X, KEY_GROUP)
	Keys.register(KEY_HELMET, "Welding shield up / down", KEY_H, KEY_GROUP)
	if Flags.is_on("trades.hover_board"):
		Keys.register(KEY_BOARD, "Hover board out / away", KEY_B, KEY_GROUP)
		Keys.register(KEY_BOARD_UP, "Hover board higher (hold)", KEY_SPACE, KEY_GROUP)
		Keys.register(KEY_BOARD_DOWN, "Hover board lower (hold)", KEY_CTRL, KEY_GROUP)
	if Flags.is_on(SPECS_CHANNEL):
		HudSlots.register_holo_channel(SPECS_CHANNEL, "Specs",
				func(glass: bool) -> Control: return TradesSpecsScreen.new(glass), 55)
	if TRADES.any(func(t: String) -> bool: return Flags.is_on("trades." + t)):
		Router.register_scene(WORKBENCH, BENCH_SCENE)
	if Flags.is_on("trades.cutting_bed") or Flags.is_on("trades.beam_designer"):
		Saves.register_section("trades", self)
	if Flags.is_on("trades.shipyard"):
		var yard_bus := Modules.bus("ship_bay") as ShipBayBus
		if yard_bus and not yard_bus.shipyard_ready.is_connected(_on_shipyard_ready):
			yard_bus.shipyard_ready.connect(_on_shipyard_ready)
		if Router.has_scene(ShipBayBus.SHIPYARD_SCENE):
			for shot: Array in [["bolt", false], ["bolt", true], ["connector", false]]:
				Shots.register("tools_%s_on_kestrel%s" % [shot[0], "_third_person" if shot[1] else ""], ShipBayBus.SHIPYARD_SCENE,
						func(scene: Node) -> void: await scene.get_node(YARD_RIG).call("stage_on_ship", shot[0], shot[1]), 40)
			if Flags.is_on("trades.test_stand"):
				for third: bool in [false, true]:
					Shots.register("tools_test_stand%s" % ("_third_person" if third else ""), ShipBayBus.SHIPYARD_SCENE,
							func(scene: Node) -> void: await scene.get_node(YARD_RIG).call("stage_test_stand", third), 40)
			if Flags.is_on("trades.tractor"):
				Shots.register("tools_tractor_lifting_engine", ShipBayBus.SHIPYARD_SCENE,
						func(scene: Node) -> void: await scene.get_node(YARD_RIG).call("stage_tractor", true), 40)


## Ship and Bay built its shipyard: put you in it, the worker with every tool to hand.
func _on_shipyard_ready(yard: Node3D) -> void:
	var rig: Node3D = load(BENCH_SCENE).instantiate()
	rig.set("in_yard", true)
	rig.name = YARD_RIG
	rig.add_to_group(YARD_GUEST_GROUP)
	yard.add_child(rig)


## The part itself on a trolley's deck for this crate (trades.parts_on_decks), or null: then
## there is no body (it never landed, or the yard was rebuilt) and the crate is drawn as before.
func deck_part(crate_id: String) -> Node3D:
	var body: Node3D = _deck_parts.get(crate_id)
	if body and not is_instance_valid(body):
		_deck_parts.erase(crate_id)
		return null
	return body


## The crate has left its trolley: the part on the deck goes (Ship and Bay's deck_part_left does
## this; for anyone else, and tests).
func release_deck_part(crate_id: String) -> void:
	var body := deck_part(crate_id)
	_deck_parts.erase(crate_id)
	_landed.erase(crate_id)
	if body:
		body.queue_free()


## Tools' own: a beamed part is going onto its trolley's deck (deck null), at rest on it, or
## gone (body null).
var _landed: Dictionary = {}  # crate_id -> true once part_on_deck went out


func note_deck_part(crate_id: String, body: Node3D, deck: Node3D) -> void:
	if body == null:
		_deck_parts.erase(crate_id)
		_landed.erase(crate_id)
		return
	_deck_parts[crate_id] = body
	if deck and not _landed.has(crate_id):
		_landed[crate_id] = true
		part_on_deck.emit(crate_id, body, deck)


## trades.cutting_bed: the plate templates the cutting bed holds, its own library first, then the
## ones traced at the ship (Dictionaries: id, name, outline (PackedVector2Array m, centred), holes,
## size (Vector2 m), kind "library" or "traced", source (the plate slot traced)).
func templates() -> Array[Dictionary]:
	var out := TradesPlateShapes.library()
	for t in _traced:
		out.append(t)
	return out


## The id the next traced template gets: "T-001", "T-002"...
func next_template_id() -> String:
	return "T-%03d" % _next_template


## Keeps a traced template (the tracer's event on every machine); returns it as kept.
func add_template(t: Dictionary) -> Dictionary:
	var kept := t.duplicate(true)
	_traced = _traced.filter(func(o: Dictionary) -> bool: return o.id != kept.id)
	_traced.append(kept)
	var n := str(kept.id).trim_prefix("T-").to_int()
	_next_template = maxi(_next_template, n + 1)
	templates_changed.emit()
	return kept


## Deletes a traced template (the library's stay).
func remove_template(id: String) -> void:
	var before := _traced.size()
	_traced = _traced.filter(func(o: Dictionary) -> bool: return o.id != id)
	if _traced.size() != before:
		templates_changed.emit()


func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	var rows: Array = []
	for t in _traced:
		rows.append({"id": t.id, "name": t.name, "source": t.get("source", ""), "outline": _points_out(t.outline)})
	return {"templates": rows, "next": _next_template, "beam_designs": _beam_designs.duplicate(true)}


func load_data(data: Dictionary, _from_version: int) -> void:
	_traced.clear()
	for row: Dictionary in data.get("templates", []):
		_traced.append(TradesPlateShapes.finish({"id": str(row.get("id", "")), "name": str(row.get("name", "Plate")),
				"outline": _points_in(row.get("outline", [])), "holes": [], "kind": "traced", "source": str(row.get("source", ""))}))
	_next_template = int(data.get("next", 1))
	for t in _traced:
		_next_template = maxi(_next_template, str(t.id).trim_prefix("T-").to_int() + 1)
	templates_changed.emit()
	# The tracer's late-join snapshot carries only the templates: the designs stay.
	if data.has("beam_designs") or data.is_empty():
		_beam_designs.clear()
	var designs: Variant = data.get("beam_designs", {})
	if designs is Dictionary:
		for ship_id: Variant in designs:
			restore_beam_design(str(ship_id), designs[ship_id])


func reset_data() -> void:
	load_data({}, SAVE_VERSION)


## trades.beam_designer: the beams drawn round a ship in the courtyard (rows: id, a and b
## (ship-space ends, [x, y, z] m), section (TradesBeamSections id), turn (degrees about its length)).
## trades.beam_versions: a ship keeps up to three versions (BEAM_VERSIONS); `version` "" is the
## one showing.
func beam_design(ship_id: String, version := "") -> Array:
	var d: Dictionary = _beam_designs.get(ship_id, {})
	var v := version if BEAM_VERSIONS.has(version) else beam_version(ship_id)
	return ((d.get("versions", {}) as Dictionary).get(v, []) as Array).duplicate(true)


## The version of a ship's design showing ("A" when it has none).
func beam_version(ship_id: String) -> String:
	return str((_beam_designs.get(ship_id, {}) as Dictionary).get("showing", "A"))


## Shows another version of a ship's design (the designer's event on every machine).
func show_beam_version(ship_id: String, version: String) -> void:
	if not BEAM_VERSIONS.has(version) or beam_version(ship_id) == version:
		return
	var d: Dictionary = _beam_designs.get(ship_id, {"versions": {}})
	d["showing"] = version
	_beam_designs[ship_id] = d
	beam_design_changed.emit(ship_id)


## Replaces a version of a ship's beam design ("" the one showing; the designer's event on
## every machine). Rows that don't read are dropped.
func set_beam_design(ship_id: String, rows: Variant, version := "") -> void:
	var v := version if BEAM_VERSIONS.has(version) else beam_version(ship_id)
	var d: Dictionary = _beam_designs.get(ship_id, {"showing": "A", "versions": {}})
	var versions: Dictionary = d.get("versions", {})
	var kept := _beam_rows(rows)
	if kept.is_empty():
		versions.erase(v)
	else:
		versions[v] = kept
	d["versions"] = versions
	if versions.is_empty() and str(d.get("showing", "A")) == "A":
		_beam_designs.erase(ship_id)
	else:
		_beam_designs[ship_id] = d
	beam_design_changed.emit(ship_id)


## Puts back a ship's whole design as save_data wrote it: {showing, versions}, or (a save from
## before versions) one list of rows, which becomes version A.
func restore_beam_design(ship_id: String, entry: Variant) -> void:
	_beam_designs.erase(ship_id)
	if entry is Array:
		set_beam_design(ship_id, entry, "A")
		return
	if not entry is Dictionary:
		beam_design_changed.emit(ship_id)
		return
	var versions: Variant = (entry as Dictionary).get("versions", {})
	if versions is Dictionary:
		for v: Variant in versions:
			if BEAM_VERSIONS.has(str(v)):
				set_beam_design(ship_id, versions[v], str(v))
	var showing := str((entry as Dictionary).get("showing", "A"))
	if showing != "A":
		show_beam_version(ship_id, showing)
	beam_design_changed.emit(ship_id)


static func _beam_rows(rows: Variant) -> Array:
	var kept: Array = []
	if rows is Array:
		for r: Variant in rows:
			if r is Dictionary and (r as Dictionary).get("a") is Array and (r as Dictionary).get("b") is Array \
					and ((r as Dictionary).a as Array).size() == 3 and ((r as Dictionary).b as Array).size() == 3:
				var d := r as Dictionary
				kept.append({"id": int(d.get("id", 0)), "a": (d.a as Array).map(func(x: Variant) -> float: return float(x)),
						"b": (d.b as Array).map(func(x: Variant) -> float: return float(x)),
						"section": str(d.get("section", "box_100x100x5")), "turn": float(d.get("turn", 0.0))})
	return kept


static func _points_out(points: PackedVector2Array) -> Array:
	var out: Array = []
	for p in points:
		out.append([snappedf(p.x, 0.0001), snappedf(p.y, 0.0001)])
	return out


static func _points_in(rows: Variant) -> PackedVector2Array:
	var out := PackedVector2Array()
	if rows is PackedVector2Array:
		return rows
	for r: Variant in rows:
		if r is Array and (r as Array).size() >= 2:
			out.append(Vector2(float(r[0]), float(r[1])))
	return out


func register_site(site: JointSite) -> void:
	_sites[site.joint_id] = site


func unregister_site(site: JointSite) -> void:
	if _sites.get(site.joint_id) == site:
		_sites.erase(site.joint_id)


func site(joint_id: StringName) -> JointSite:
	return _sites.get(joint_id)


## Last result for a joint, or null if it is not finished (or was taken apart).
func get_result(joint_id: StringName) -> JointResult:
	return _results.get(joint_id)


func is_tool_enabled(tool_id: StringName) -> bool:
	match tool_id:
		&"hands":
			return TRADES.any(func(t: String) -> bool: return Flags.is_on("trades." + t))
		&"torque_wrench":
			return Flags.is_on("trades.bolting")
		&"drill", &"rivet_squeezer":
			return Flags.is_on("trades.riveting")
		&"welder":
			return Flags.is_on("trades.welding")
		&"wire_tool":
			return Flags.is_on("trades.wiring")
		&"tractor":
			return Flags.is_on("trades.tractor")
	return false


## Progression pushes each player's skill effects down here, since Trades can't call up.
## Trades reads "bolt_speed" and "rivet_speed" (share faster turning and drilling). Unknown keys are kept and ignored.
func set_player_modifiers(player_id: Variant, effects: Dictionary) -> void:
	_modifiers[str(player_id)] = effects.duplicate()


func modifier(player_id: Variant, effect_key: StringName, default: float = 0.0) -> float:
	return float(_modifiers.get(str(player_id), {}).get(effect_key, default))


## Called by the module's own tools when a joint is finished.
func complete_joint(joint_site: JointSite, measurements: Dictionary, peer_id: int = 1) -> JointResult:
	var r := JointResult.new()
	r.joint_id = joint_site.joint_id
	r.trade = joint_site.spec.trade
	r.component_id = joint_site.component_id
	r.mount_id = joint_site.mount_id
	r.measurements = measurements
	r.peer_id = peer_id
	r.time = int(Time.get_unix_time_from_system())
	_results[r.joint_id] = r
	joint_completed.emit(r)
	return r


## The unit on an upgrade rig as Tools has it: {unit (id), tier, open (cover off), seats (the
## add-on seats it has: "core", "emitter", "board"), fitted (seat -> the add-on part in it,
## Shared Components' id: "quantum_core_3", "field_emitter_3", "control_board"),
## joints (joint_id -> quality 0..1, or -1.0 while not made)}; {} with no unit on the rig.
func unit_state(rig_id: String) -> Dictionary:
	return (_units.get(rig_id, {}) as Dictionary).duplicate(true)


## Called by the module's own station when a unit's joints or add-ons change.
func note_unit(rig_id: String, state: Dictionary) -> void:
	if state.is_empty():
		_units.erase(rig_id)
	else:
		_units[rig_id] = state.duplicate(true)
	unit_changed.emit(rig_id, state)


## Called by the module's own tools when a finished joint is taken apart.
func remove_joint(joint_id: StringName) -> void:
	if _results.erase(joint_id):
		joint_removed.emit(joint_id)
