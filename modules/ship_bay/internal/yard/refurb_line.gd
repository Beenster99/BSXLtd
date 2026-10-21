extends Node3D
## The refurbishment line in Pre-assembly: five machines on a roller conveyor that take worn
## goods out of the stores and either grind them to dust for sale or bring them back to 100%.
##
##   SURVEY  -> scans a lot and says GRIND (condition GRIND_BELOW or worse) or REFURBISH;
##              ROUTE overrides it. Its screen picks the lot from the stores (worst first).
##   GRINDER -> (the grind branch, west off the diverter) reduces the lot to dust in the
##              DUST VESSEL beside it; SEND TO STORES has the large trolley take the vessel
##              to the bulk floor, where its raw materials are ready for sale.
##   STRAIGHTENER -> a press that takes the dents and bends out (60%)
##   BATH         -> a chemical bath that strips the surface back to bare metal (85%)
##   COATER       -> a spray booth that lays the protective coats on (100%)
##   OUTPUT       -> three pallets at the end of the line; CALL TROLLEY puts them away.
##
## By hand each machine's screen has START (run what is in it) and SEND ON (pass a finished
## lot on). AUTO (on any screen) runs the whole line: it loads the worst lot in the stores,
## runs and sends every machine, empties the vessel when it is full and calls trolleys.
## The line's state is the bus's (line_state(), host-authoritative, saved with the bay);
## this node draws it, times the machines and, on the host, drives AUTO.
##
## Built in yard space: the node sits at the yard's origin, the survey clear of the floor in
## front of Business's hall TV on the north wall. The main line runs south (+Z)
## along x = LINE_X with the machines' fronts to the hall (-X); the grind branch runs west.

const Touch := preload("res://modules/ship_bay/internal/kit/touch_screen.gd")
const T := preload("res://modules/ui/api/terminal_kit.gd")
const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")

## The main line's centre line (x) and the conveyor's top over the floor, metres.
const LINE_X := 46.4
const BED := 0.9
## Where each machine's lot sits (yard space, on the bed) and which way its lot travels.
const STATIONS := {
	"survey": {"at": Vector3(LINE_X, BED, -19.1), "travel": Vector3(0, 0, 1)},
	"grinder": {"at": Vector3(42.4, BED, -16.0), "travel": Vector3(-1, 0, 0)},
	"straightener": {"at": Vector3(LINE_X, BED, -12.6), "travel": Vector3(0, 0, 1)},
	"bath": {"at": Vector3(LINE_X, BED, -9.2), "travel": Vector3(0, 0, 1)},
	"coater": {"at": Vector3(LINE_X, BED, -5.8), "travel": Vector3(0, 0, 1)},
}
## The turntable where the grind branch leaves the main line.
const DIVERTER := Vector3(LINE_X, BED, -16.0)
## The end of the main line's conveyor, over the output pallets.
const LINE_END := Vector3(LINE_X, BED, -4.0)
## The output pallets on the floor (yard space): where refurbished lots wait for a trolley.
const OUT_SPOTS: Array[Vector3] = [Vector3(LINE_X, 0, -2.5), Vector3(LINE_X, 0, -0.8), Vector3(LINE_X, 0, 0.9)]
## The dust vessel's place on the floor at the end of the grind branch.
const DUST_SPOT := Vector3(38.9, 0, -16.0)
## An empty vessel's own mass, kg.
const VESSEL_TARE := 900.0
## Machine footprint along the line and across it, metres.
const LENGTH := 2.2
const WIDTH := 1.6
## The machines' names on their plates and screens.
const TITLES := {"survey": "SURVEY  SV-1", "grinder": "GRINDER  GX-9", "straightener": "STRAIGHTENER  PR-4",
		"bath": "CHEMICAL BATH  CB-2", "coater": "COATER  PC-3"}

## What each machine does, for the tip shown while you look at it.
const HINTS := {
	"survey": "Pick a worn lot from the stores, LOAD and SCAN it: it says grind or refurbish. ROUTE overrides it.",
	"grinder": "Grinds a lot to dust in the vessel beside it. The dust goes to the stores as raw materials.",
	"straightener": "Presses the dents and bends out of a lot (to 60%).",
	"bath": "Strips a lot back to bare metal (to 85%).",
	"coater": "Sprays on the protective coats: the lot comes out at 100%.",
}

## Seconds a machine takes over a lot, and a lot takes from one machine to the next.
@export var run_time := 5.0
@export var travel_time := 1.4

## Each machine: id -> {node, screen, lamp, parts used by its run animation}.
var machines: Dictionary = {}
var dust_screen: Node3D
var out_screen: Node3D
## The stored lots the survey's screen offers (bus.line_candidates()) and which it shows.
var lots: Array[Dictionary] = []
var pick := 0
## Seconds left on each running machine (every peer times them; the host's says finish).
var running: Dictionary = {}

var _bus: ShipBayBus
var _state: Dictionary = {}
var _mats: Dictionary = {}
var _lot_mats: Dictionary = {}
var _lamp_on: Material
var _lamp_idle: Material
var _lamp_done: Material
## The lot drawn on each machine, and the ones travelling between them.
var _lot_nodes: Dictionary = {}
var _movers: Array[Node3D] = []
## Output pallets' and the vessel's waiting crates as drawn (crate id -> node).
var _crate_nodes: Dictionary = {}
var _crates_root: Node3D
var _dust_fill: Node3D
var _dust_label: Label3D
var _auto_clock := 0.0
## Line crates the AUTO line has already called a trolley for.
var _called: Dictionary = {}
var _want_dust_trolley := false


func _ready() -> void:
	name = "RefurbLine"
	_mats = {
		"dark": _paint(Color(0.12, 0.13, 0.15), 0.5, 0.5, "gunmetal"),
		"steel": _paint(Color(0.6, 0.62, 0.64), 0.75, 0.4, "galvanised"),
		"roller": _paint(Color(0.7, 0.72, 0.74), 0.85, 0.3, "brushed_steel"),
		"yellow": _paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"),
		"survey": _paint(Color(0.22, 0.38, 0.52), 0.35, 0.45, "satin_paint"),
		"grinder": _paint(Color(0.3, 0.32, 0.34), 0.55, 0.5, "cast_iron"),
		"straightener": _paint(Color(0.95, 0.68, 0.1), 0.2, 0.5, "hazard_paint"),
		"bath": _paint(Color(0.2, 0.46, 0.4), 0.3, 0.45, "satin_paint"),
		"coater": _paint(Color(0.86, 0.85, 0.82), 0.2, 0.45, "satin_paint"),
		"orange": _paint(Color("e8792b"), 0.2, 0.45, "satin_paint"),
		"wood": _paint(Color(0.55, 0.42, 0.28), 0.0, 0.8, "wood"),
		"vessel": _paint(Color(0.24, 0.42, 0.58), 0.4, 0.45, "satin_paint"),
		"dust": _paint(Color(0.38, 0.35, 0.32), 0.3, 0.95, "cast_iron"),
	}
	_lot_mats = {
		"rust": _paint(Color(0.44, 0.25, 0.13), 0.3, 0.9, "cast_iron"),
		"worn": _paint(Color(0.5, 0.44, 0.36), 0.35, 0.8, "bare_steel"),
		"bare": _paint(Color(0.8, 0.81, 0.83), 0.85, 0.3, "bare_steel"),
		"coat": _paint(Color(0.22, 0.4, 0.56), 0.25, 0.4, "satin_paint"),
	}
	_lamp_on = ShipKit.glow(Color(1.0, 0.55, 0.15), 4.0)
	_lamp_idle = ShipKit.glow(Color(0.5, 0.55, 0.6), 0.8)
	_lamp_done = ShipKit.glow(Color(0.25, 0.9, 0.45), 2.0)
	_build_conveyors()
	for s: String in STATIONS:
		_build_machine(s)
	_build_dust()
	_build_output()
	_crates_root = Node3D.new()
	_crates_root.name = "Crates"
	add_child(_crates_root)
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if _bus:
		_bus.line_changed.connect(_on_line_changed)
		_bus.stock_changed.connect(_on_stock_changed)
	_state = _bus.line_state() if _bus else {}
	_on_stock_changed()
	_show_all()


func _exit_tree() -> void:
	if _bus:
		if _bus.line_changed.is_connected(_on_line_changed):
			_bus.line_changed.disconnect(_on_line_changed)
		if _bus.stock_changed.is_connected(_on_stock_changed):
			_bus.stock_changed.disconnect(_on_stock_changed)


# --- What the screens do -------------------------------------------------------------------

## The survey's PREV / NEXT: which stored lot LOAD takes.
func next(way := 1) -> void:
	if lots.is_empty():
		return
	pick = posmod(pick + way, lots.size())
	Sfx.play("tick", machines["survey"].node, -10.0)
	_show("survey")


## A machine's big button: LOAD (the survey, empty), START, or SEND ON.
func go(station: String) -> void:
	var at: Dictionary = _station(station)
	if at.is_empty():
		if station == "survey" and pick < lots.size():
			_bus.line_request("load", {"location": str(lots[pick].location)})
			Sfx.play("clunk", machines[station].node)
			return
		Sfx.play("error", machines[station].node)
		return
	match str(at.state):
		"waiting":
			_bus.line_request("start", {"station": station})
		"done":
			_bus.line_request("send", {"station": station})
		_:
			Sfx.play("error", machines[station].node)


## The survey's ROUTE: swaps its call between grinding and refurbishing.
func swap_route() -> void:
	var at: Dictionary = _station("survey")
	if at.is_empty():
		Sfx.play("error", machines["survey"].node)
		return
	_bus.line_request("route", {"route": "refurb" if str(at.lot.route) == "grind" else "grind"})


## AUTO on any screen: the whole line runs itself, or goes back to hand.
func toggle_auto() -> void:
	_bus.line_request("auto", {"on": not bool(_state.get("auto", false))})


## The vessel's SEND TO STORES: it becomes a crate and the large trolley takes it.
func send_dust() -> void:
	if _bus.dust_kg() <= 0.0 and not _has_crate("dust"):
		Sfx.play("error", dust_screen)
		return
	_want_dust_trolley = true
	if not _has_crate("dust"):
		_bus.line_request("empty_dust")
	_call_dust_trolley()


## The output's CALL TROLLEY: a trolley for each refurbished lot waiting on a pallet.
func call_trolleys() -> void:
	var sent := false
	for id: String in _bus.line_crates():
		if str(_bus.line_crates()[id].line) == "out" and not _called.has(id):
			var t := _bus.call_trolley_for(id)
			if t != "":
				_called[id] = t
				sent = true
	Sfx.play("chime" if sent else "error", out_screen, -8.0)
	_show_out()


func _call_dust_trolley() -> void:
	for id: String in _bus.line_crates():
		if str(_bus.line_crates()[id].line) == "dust" and not _called.has(id):
			var t := _bus.call_trolley_for(id)
			if t != "":
				_called[id] = t
				_want_dust_trolley = false


# --- Running ---------------------------------------------------------------------------------

func _on_line_changed() -> void:
	var was := _state
	_state = _bus.line_state()
	var st: Dictionary = _state.get("stations", {})
	var old: Dictionary = was.get("stations", {})
	for s: String in st:
		var now_state := str((st[s] as Dictionary).get("state", ""))
		var then_state := str((old.get(s, {}) as Dictionary).get("state", ""))
		if now_state == "running" and then_state != "running":
			running[s] = run_time
			_start_sound(s, true)
		elif now_state != "running" and running.has(s):
			running.erase(s)
			_start_sound(s, false)
			if now_state == "done" or (s == "grinder" and now_state == ""):
				Sfx.play("chime", machines[s].node, -10.0)
		# A lot arriving from the machine before it rides the conveyor across.
		if then_state == "" and now_state == "waiting":
			for from: String in old:
				if from != s and str((old[from] as Dictionary).get("state", "")) == "done" and (st.get(from, {}) as Dictionary).is_empty() \
						and ShipBayBus._line_next(from, old[from].lot) == s:
					_travel(_path(from, s), old[from].lot)
	# A lot off the coater onto an output pallet rides down the end of the line.
	var coater_was: Dictionary = old.get("coater", {})
	if str(coater_was.get("state", "")) == "done" and (st.get("coater", {}) as Dictionary).is_empty():
		var newest := _newest_out()
		if newest >= 0:
			_travel([STATIONS.coater.at, LINE_END, OUT_SPOTS[newest] + Vector3(0, BED, 0), OUT_SPOTS[newest] + Vector3(0, 0.15, 0)], coater_was.lot)
	_show_all()


func _on_stock_changed() -> void:
	var was := str(lots[pick].location) if pick < lots.size() else ""
	lots = _bus.line_candidates() if _bus else ([] as Array[Dictionary])
	pick = 0
	for i in lots.size():
		if str(lots[i].location) == was:
			pick = i
	for id: String in _called.keys():
		if not _bus.line_crates().has(id):
			_called.erase(id)
	if _want_dust_trolley:
		_call_dust_trolley()
	_draw_crates()
	_show_all()


func _process(delta: float) -> void:
	for s: String in running.keys():
		running[s] = maxf(float(running[s]) - delta, 0.0)
		_animate(s, 1.0 - float(running[s]) / maxf(run_time, 0.01))
		if float(running[s]) <= 0.0 and _bus and _bus.line_runs_here() and not bool(machines[s].get("finishing", false)):
			machines[s]["finishing"] = true
			_bus.line_request("finish", {"station": s})
	for s: String in machines:
		if not running.has(s) and bool(machines[s].get("finishing", false)):
			machines[s]["finishing"] = false
	if _bus and bool(_state.get("auto", false)) and _bus.line_runs_here():
		_auto_clock -= delta
		if _auto_clock <= 0.0:
			_auto_clock = 0.5
			_auto_step()


## One look round the line on AUTO (host): pass finished lots on from the end of the line
## back, start whatever waits, load the survey, empty a full vessel, call trolleys.
func _auto_step() -> void:
	var st: Dictionary = _state.get("stations", {})
	for s: String in ["coater", "bath", "straightener", "grinder", "survey"]:
		var at: Dictionary = st.get(s, {})
		if at.is_empty() or _moving():
			continue
		if str(at.state) == "done":
			_bus.line_request("send", {"station": s})
		elif str(at.state) == "waiting":
			_bus.line_request("start", {"station": s})
	if (st.get("survey", {}) as Dictionary).is_empty() and not lots.is_empty():
		_bus.line_request("load", {"location": str(lots[0].location)})
	if _bus.dust_kg() >= ShipBayBus.DUST_CAPACITY and not _has_crate("dust"):
		_want_dust_trolley = true
		_bus.line_request("empty_dust")
	for id: String in _bus.line_crates():
		if not _called.has(id):
			var t := _bus.call_trolley_for(id)
			if t != "":
				_called[id] = t


func _moving() -> bool:
	for m in _movers:
		if is_instance_valid(m):
			return true
	return false


# --- Drawing the state ---------------------------------------------------------------------

func _station(s: String) -> Dictionary:
	return (_state.get("stations", {}) as Dictionary).get(s, {})


func _has_crate(kind: String) -> bool:
	if _bus == null:
		return false
	for c: Dictionary in _bus.line_crates().values():
		if str(c.line) == kind:
			return true
	return false


func _newest_out() -> int:
	var best := -1
	var best_n := -1
	for id: String in _bus.line_crates():
		var c: Dictionary = _bus.line_crates()[id]
		var n := int(id.get_slice("/", 1))
		if str(c.line) == "out" and n > best_n:
			best_n = n
			best = int(c.get("out_spot", 0))
	return best


func _show_all() -> void:
	for s: String in machines:
		_show(s)
		_draw_lot(s)
	_show_dust()
	_show_out()


func _show(s: String) -> void:
	var m: Dictionary = machines.get(s, {})
	if m.is_empty():
		return
	var screen: Node3D = m.screen
	var at := _station(s)
	var auto := bool(_state.get("auto", false))
	screen.call("set_button", "auto", "AUTO ON" if auto else "AUTO", auto)
	var state := str(at.get("state", ""))
	(m.lamp as MeshInstance3D).material_override = _lamp_on if state == "running" else (_lamp_done if state == "done" else _lamp_idle)
	match state:
		"running":
			screen.call("set_status", "RUNNING", T.AMBER)
		"done":
			screen.call("set_status", "DONE", T.GOOD)
		"waiting":
			screen.call("set_status", "READY", T.CYAN)
		_:
			screen.call("set_status", "EMPTY", T.DIM)
	if s == "survey":
		_show_survey(screen, at)
		return
	if at.is_empty():
		var hint := "Lots the survey sends to grind\ncome here." if s == "grinder" else "Waiting for a lot."
		screen.call("set_body", hint, T.DIM)
		screen.call("set_button", "go", "START", false)
		return
	var lot: Dictionary = at.lot
	var head := "%s x%d  %d%%" % [str(lot.name).to_upper().left(20), int(lot.qty), roundi(float(lot.condition) * 100.0)]
	if s == "grinder":
		var mats := ShipBayBus.scrap_materials(str(lot.item), int(lot.qty))
		var kg := 0.0
		for k: String in mats:
			kg += float(mats[k])
		screen.call("set_body", "%s\n-> %s KG OF DUST" % [head, _kg(kg)])
	else:
		var to := roundi(float(ShipBayBus.LINE_AFTER.get(s, 1.0)) * 100.0)
		var what: String = {"straightener": "STRAIGHTEN", "bath": "STRIP TO BARE METAL", "coater": "COAT"}[s]
		screen.call("set_body", "%s\n%s -> %d%%" % [head, what, maxi(to, roundi(float(lot.condition) * 100.0))])
	screen.call("set_button", "go", "SEND ON" if state == "done" else "START", state != "running")


func _show_survey(screen: Node3D, at: Dictionary) -> void:
	var state := str(at.get("state", ""))
	if at.is_empty():
		if lots.is_empty():
			screen.call("set_body", "Nothing in the stores needs it.\nGoods under 100% come here.", T.DIM)
		else:
			var lot: Dictionary = lots[pick]
			screen.call("set_body", "STORES %d / %d  %s\n%s x%d  %d%%" % [pick + 1, lots.size(), str(lot.location),
					str(lot.name).to_upper().left(20), int(lot.qty), roundi(float(lot.condition) * 100.0)])
		screen.call("set_button", "go", "LOAD", not lots.is_empty())
		screen.call("set_button", "route", "ROUTE", false)
		return
	var lot: Dictionary = at.lot
	var head := "%s x%d  %d%%" % [str(lot.name).to_upper().left(20), int(lot.qty), roundi(float(lot.condition) * 100.0)]
	var grind := str(lot.route) == "grind"
	var call := "GRIND TO DUST" if grind else "REFURBISH"
	if state == "done":
		var said := ShipBayBus.survey_route(float(lot.condition)) == str(lot.route)
		screen.call("set_body", "%s\nSURVEY: %s%s" % [head, call, "" if said else " (YOUR CALL)"], T.AMBER if grind else T.GOOD)
	else:
		screen.call("set_body", "%s\n%s" % [head, "SCANNING..." if state == "running" else "SCAN TO SURVEY IT"])
	screen.call("set_button", "go", "SEND ON" if state == "done" else "SCAN", state != "running")
	screen.call("set_button", "route", "TO GRINDER" if not grind else "TO REFURB", false)


func _show_dust() -> void:
	if dust_screen == null or _bus == null:
		return
	var waiting := _has_crate("dust")
	var kg := _bus.dust_kg()
	var full := 0.0
	if waiting:
		for c: Dictionary in _bus.line_crates().values():
			if str(c.line) == "dust":
				full = float(c.mass) - VESSEL_TARE
	var shown := full if waiting else kg
	_dust_fill.visible = shown > 0.0
	var k := clampf(shown / ShipBayBus.DUST_CAPACITY, 0.0, 1.0)
	_dust_fill.scale = Vector3(1, maxf(k, 0.02), 1)
	_dust_label.text = "DUST  %s / %s KG" % [_kg(shown), _kg(ShipBayBus.DUST_CAPACITY)]
	if waiting:
		dust_screen.call("set_status", "FOR THE STORES", T.AMBER)
		dust_screen.call("set_body", "The vessel waits for the large\ntrolley to the bulk floor.")
	else:
		dust_screen.call("set_status", "%d%% FULL" % roundi(k * 100.0), T.GOOD if kg > 0.0 else T.DIM)
		var dust: Dictionary = _state.get("dust", {})
		var parts := PackedStringArray()
		for m: String in dust:
			parts.append("%s %s" % [m.to_upper(), _kg(float(dust[m]))])
		dust_screen.call("set_body", "  ".join(parts) + " KG" if not parts.is_empty() else "Empty. The grinder fills it.", T.TEXT if not parts.is_empty() else T.DIM)
	dust_screen.call("set_button", "send", "CALL TROLLEY" if waiting else "SEND TO STORES", kg > 0.0 or waiting)


func _show_out() -> void:
	if out_screen == null or _bus == null:
		return
	var n := 0
	var names := PackedStringArray()
	for id: String in _bus.line_crates():
		var c: Dictionary = _bus.line_crates()[id]
		if str(c.line) == "out":
			n += 1
			names.append("%s x%d%s" % [str(c.name).to_upper().left(18), int(c.qty), "  (TROLLEY COMING)" if _called.has(id) else ""])
	out_screen.call("set_status", "%d WAITING" % n if n > 0 else "CLEAR", T.AMBER if n > 0 else T.DIM)
	out_screen.call("set_body", "\n".join(names) if n > 0 else "Refurbished lots land here\nfor a trolley to put away.", T.TEXT if n > 0 else T.DIM)
	out_screen.call("set_button", "call", "CALL TROLLEY", n > 0)


## The lot sitting in a machine: a part-shaped block sized by its mass, rusty, worn, bare or
## coated by how far along the line it has come.
func _draw_lot(s: String) -> void:
	var at := _station(s)
	var node: Node3D = _lot_nodes.get(s)
	if at.is_empty() or (str(at.state) == "waiting" and _moving()):
		if node:
			node.visible = false
		return
	if node == null:
		node = Node3D.new()
		node.name = "Lot_" + s
		add_child(node)
		_lot_nodes[s] = node
	_dress_lot(node, at.lot)
	node.visible = true
	node.position = _rest(s)
	node.scale = Vector3.ONE


func _dress_lot(node: Node3D, lot: Dictionary) -> void:
	var key := "%s|%.2f|%s" % [str(lot.item), float(lot.mass), _look(lot)]
	if node.get_meta("key", "") == key:
		return
	node.set_meta("key", key)
	for c in node.get_children():
		c.free()
	var size := _lot_size(float(lot.mass))
	var mat: Material = _lot_mats[_look(lot)]
	var dented := ["rust", "worn"].has(_look(lot)) and str(lot.get("stage", "")) != "straightener"
	var bend := Basis(Vector3(0.0, 0.0, 1.0), 0.09) * Basis(Vector3(1.0, 0.0, 0.0), -0.06) if dented else Basis()
	var body := Node3D.new()
	body.name = "Body"
	body.basis = bend
	node.add_child(body)
	_part(PartShapes.chamfer_box(size, minf(size.y, size.x) * 0.12).mesh, Vector3(0, size.y * 0.5, 0), mat, body)
	_part(PartShapes.prism(12, size.x * 0.22, size.y * 0.35).mesh, Vector3(size.x * 0.15, size.y * 1.15, -size.z * 0.15), mat, body)
	_part(PartShapes.box(Vector3(size.x * 1.04, size.y * 0.1, size.z * 0.12)).mesh, Vector3(0, size.y * 0.5, size.z * 0.3), mat, body)


static func _look(lot: Dictionary) -> String:
	match str(lot.get("stage", "")):
		"coater":
			return "coat"
		"bath":
			return "bare"
	return "rust" if float(lot.get("condition", 1.0)) < 0.6 else "worn"


static func _lot_size(mass: float) -> Vector3:
	var k := clampf(0.35 + sqrt(maxf(mass, 0.0)) / 60.0, 0.35, 1.05)
	return Vector3(k, k * 0.7, k * 1.1)


## Where a machine's lot rests (yard space, its bottom on the bed or in the bath).
func _rest(s: String) -> Vector3:
	var p: Vector3 = STATIONS[s].at
	if s == "grinder":
		return p - (STATIONS[s].travel as Vector3) * 0.75   # in the grinder's mouth
	if s == "bath":
		return p + Vector3(0, 0.12, 0)
	return p


## The way a lot rides from one machine to the next.
func _path(from: String, to: String) -> Array:
	var pts: Array = [_rest(from)]
	if from == "survey":
		pts.append(DIVERTER)
	pts.append(_rest(to))
	return pts


## A lot riding the conveyor along `points` (a copy of it; the machine draws its own once
## it arrives).
func _travel(points: Array, lot: Dictionary) -> void:
	var mover := Node3D.new()
	mover.name = "Moving"
	add_child(mover)
	_dress_lot(mover, lot)
	mover.position = points[0]
	_movers.append(mover)
	var tw := create_tween()
	var total := 0.0
	for i in range(1, points.size()):
		total += (points[i] as Vector3).distance_to(points[i - 1])
	for i in range(1, points.size()):
		var leg := (points[i] as Vector3).distance_to(points[i - 1])
		tw.tween_property(mover, "position", points[i], travel_time * leg / maxf(total, 0.01))
	tw.tween_callback(func() -> void:
		_movers.erase(mover)
		mover.queue_free()
		_show_all()
		_draw_crates())
	_show_all()


## The waiting line crates: a refurbished lot on its output pallet, and the vessel.
func _draw_crates() -> void:
	if _bus == null or _crates_root == null:
		return
	var crates := _bus.line_crates()
	for id: String in _crate_nodes.keys():
		if not crates.has(id):
			(_crate_nodes[id] as Node3D).queue_free()
			_crate_nodes.erase(id)
	for id: String in crates:
		var c: Dictionary = crates[id]
		if str(c.line) != "out" or _crate_nodes.has(id):
			continue
		var node := Node3D.new()
		node.name = "Crate_" + id.replace("/", "_")
		node.position = _bus.crate_position(id) + Vector3(0, 0.15, 0)
		_crates_root.add_child(node)
		_dress_lot(node, {"item": c.item, "mass": c.mass, "condition": c.condition, "stage": "coater"})
		var tag := Label3D.new()
		tag.text = "%s  x%d\nREFURBISHED  %d%%" % [c.name, int(c.qty), roundi(float(c.condition) * 100.0)]
		tag.font = ShipKit.mono_font()
		tag.font_size = 40
		tag.pixel_size = 0.0025
		tag.outline_size = 6
		tag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		tag.position = Vector3(0, 1.4, 0)
		node.add_child(tag)
		_crate_nodes[id] = node
	# A lot still riding down the line hides its pallet's copy until it lands.
	for id: String in _crate_nodes:
		(_crate_nodes[id] as Node3D).visible = not _moving()


# --- Run animations ------------------------------------------------------------------------

## A machine at `k` (0..1) through its run.
func _animate(s: String, k: float) -> void:
	var m: Dictionary = machines[s]
	var lot: Node3D = _lot_nodes.get(s)
	match s:
		"survey":
			# The scan bar sweeps the lot twice.
			(m.bar as Node3D).position.z = -0.8 + 1.6 * absf(fmod(k * 2.0, 2.0) - 1.0)
		"grinder":
			(m.housing as Node3D).position.x = sin(k * 300.0) * 0.004
			(m.stream as Node3D).visible = k < 0.97
			if lot:
				lot.position = _rest(s) + (STATIONS[s].travel as Vector3) * 0.9 * minf(k * 2.0, 1.0)
				lot.scale = Vector3.ONE * maxf(1.0 - k, 0.05)
		"straightener":
			# The platen comes down onto the lot three times.
			var top := float(m.platen_top)
			var low := BED + (_lot_size(float(_station(s).get("lot", {}).get("mass", 0.0))).y + 0.06 if lot else 0.5)
			(m.platen as Node3D).position.y = lerpf(top, low, absf(sin(k * PI * 3.0)))
			if lot and k > 0.5:
				(lot.get_node("Body") as Node3D).basis = Basis()
		"bath":
			if lot:
				lot.position = _rest(s) - Vector3(0, 0.75 * sin(k * PI), 0)
			(m.bubbles as Node3D).visible = k < 0.95
		"coater":
			(m.mist as Node3D).visible = k < 0.95
			(m.mist as Node3D).rotation.z = k * 40.0
			if lot and k > 0.5:
				var lot_d: Dictionary = (_station(s).get("lot", {}) as Dictionary).duplicate()
				lot_d["stage"] = "coater"
				_dress_lot(lot, lot_d)


## A machine's motor on or off; its run's moving parts back at rest when it stops.
func _start_sound(s: String, on: bool) -> void:
	var m: Dictionary = machines[s]
	var motor: AudioStreamPlayer3D = m.get("motor")
	if motor:
		if on:
			motor.play()
		else:
			motor.stop()
	if on:
		Sfx.play("whoosh" if s == "coater" else "clunk", m.node, -6.0)
		return
	match s:
		"survey":
			(m.bar as Node3D).position.z = -0.8
		"grinder":
			(m.housing as Node3D).position.x = 0.0
			(m.stream as Node3D).visible = false
		"straightener":
			(m.platen as Node3D).position.y = float(m.platen_top)
		"bath":
			(m.bubbles as Node3D).visible = false
		"coater":
			(m.mist as Node3D).visible = false


# --- Building ------------------------------------------------------------------------------

## A machine in its own frame: the lot rides along +Z through it at the origin, its front
## (the screen, where you stand) faces `side` * X.
func _build_machine(s: String) -> void:
	var travel: Vector3 = STATIONS[s].travel
	var at: Vector3 = STATIONS[s].at
	var root := Node3D.new()
	root.name = s.capitalize().replace(" ", "")
	root.add_to_group("gfx_interactable")
	root.set_meta("gfx_id", "line:" + s)
	root.set_meta("look_hint", {"title": str(TITLES[s]).get_slice("  ", 0).capitalize(), "text": str(HINTS[s]),
			"keys": [["LMB", "Press a button on its screen"]]})
	# Local +Z along the travel; the grinder's front faces south (+Z yard) so it has side +1.
	var yaw := atan2(travel.x, travel.z)
	root.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, 0, at.z))
	add_child(root)
	var side := 1.0 if s == "grinder" else -1.0
	var body := StaticBody3D.new()
	body.name = "Body"
	body.set_meta("surface", "metal")
	root.add_child(body)
	var m := {"node": root}
	var paint: Material = _mats[s]
	# A plinth and the roller bed through the machine.
	_part(PartShapes.chamfer_box(Vector3(WIDTH + 0.2, 0.12, LENGTH + 0.1), 0.02).mesh, Vector3(0, 0.06, 0), _mats["dark"], root)
	if s != "bath":
		_bed(root, LENGTH, Vector3.ZERO)
	_collide(body, Vector3(WIDTH, BED, LENGTH), Vector3(0, BED * 0.5, 0))
	match s:
		"survey":
			# A scanning arch over the bed, the scan bar riding it, a cabinet behind.
			for z: float in [-0.95, 0.95]:
				for x: float in [-0.75, 0.75]:
					_part(PartShapes.box(Vector3(0.12, 1.4, 0.12)).mesh, Vector3(x, BED + 0.7, z), paint, root)
				# A hair shallower than the side bars, so their tops don't meet in one plane.
				_part(PartShapes.box(Vector3(1.62, 0.136, 0.136)).mesh, Vector3(0, BED + 1.45, z), paint, root)
			for x: float in [-0.75, 0.75]:
				_part(PartShapes.box(Vector3(0.14, 0.14, 2.0)).mesh, Vector3(x, BED + 1.45, 0), paint, root)
			var bar := Node3D.new()
			bar.name = "ScanBar"
			bar.position = Vector3(0, 0, -0.8)
			root.add_child(bar)
			_part(PartShapes.box(Vector3(1.4, 0.06, 0.08)).mesh, Vector3(0, BED + 1.36, 0), _mats["dark"], bar)
			_part(PartShapes.box(Vector3(1.3, 0.02, 0.03)).mesh, Vector3(0, BED + 1.32, 0), ShipKit.glow(Color(0.4, 0.86, 1.0), 6.0), bar)
			for x: float in [-0.6, 0.6]:
				_part(PartShapes.box(Vector3(0.02, 1.2, 0.03)).mesh, Vector3(x, BED + 0.72, 0), ShipKit.glow(Color(0.4, 0.86, 1.0), 3.0), bar)
			m["bar"] = bar
			_part(PartShapes.chamfer_box(Vector3(0.6, 2.0, 1.6), 0.04).mesh, Vector3(-side * 1.15, 1.0, 0), paint, root)
			_collide(body, Vector3(0.6, 2.0, 1.6), Vector3(-side * 1.15, 1.0, 0))
			_collide(body, Vector3(WIDTH, 0.2, LENGTH), Vector3(0, BED + 1.45, 0))
		"grinder":
			# A heavy housing over the bed with a hopper, a motor behind and a chute out the end.
			var housing := Node3D.new()
			housing.name = "Housing"
			root.add_child(housing)
			_part(PartShapes.chamfer_box(Vector3(WIDTH + 0.2, 1.5, 1.6), 0.06).mesh, Vector3(0, BED + 0.75, 0.25), paint, housing)
			_part(PartShapes.frustum(0.55, 0.85, 0.7, 4).mesh, Vector3(0, BED + 1.85, 0.25), _mats["steel"], housing, Basis(Vector3.UP, PI * 0.25))
			_part(PartShapes.box(Vector3(WIDTH + 0.22, 0.2, 0.05)).mesh, Vector3(0, BED + 1.3, -0.56), _mats["yellow"], housing)
			_part(PartShapes.box(Vector3(1.2, 0.5, 0.04)).mesh, Vector3(0, BED + 0.28, -0.56), _mats["dark"], housing)
			_part(WreckParts.generator(Vector3(1.0, 0.8, 0.9)).mesh, Vector3(-side * 1.25, 0.55, 0.3), _mats["dark"], root)
			_collide(body, Vector3(WIDTH + 0.2, 2.6, 1.6), Vector3(0, 1.3, 0.25))
			_collide(body, Vector3(1.0, 0.9, 0.9), Vector3(-side * 1.25, 0.45, 0.3))
			# The chute down from the end of the housing into the dust vessel.
			var chute_len := (DUST_SPOT - Vector3(at.x, 0, at.z)).length() - 1.6
			_part(PartShapes.box(Vector3(0.5, 0.05, chute_len)).mesh, Vector3(0, BED + 0.55, 1.05 + chute_len * 0.5), _mats["steel"], root, Basis(Vector3.RIGHT, 0.3))
			var stream := _part(PartShapes.box(Vector3(0.3, 0.06, chute_len)).mesh, Vector3(0, BED + 0.6, 1.05 + chute_len * 0.5), _mats["dust"], root, Basis(Vector3.RIGHT, 0.3))
			stream.visible = false
			m["housing"] = housing
			m["stream"] = stream
		"straightener":
			# A press: two columns, a crosshead and a ram platen over the bed.
			for x: float in [-0.85, 0.85]:
				_part(PartShapes.box(Vector3(0.24, 2.6, 0.5)).mesh, Vector3(x, 1.3, 0), paint, root)
			_part(PartShapes.chamfer_box(Vector3(2.0, 0.45, 0.8), 0.04).mesh, Vector3(0, 2.7, 0), paint, root)
			_part(PartShapes.prism(16, 0.2, 0.6).mesh, Vector3(0, 2.2, 0), _mats["roller"], root)
			var platen := Node3D.new()
			platen.name = "Platen"
			var top := BED + 1.15
			platen.position = Vector3(0, top, 0)
			root.add_child(platen)
			_part(PartShapes.chamfer_box(Vector3(1.3, 0.12, 1.1), 0.02).mesh, Vector3(0, 0.06, 0), _mats["dark"], platen)
			_part(PartShapes.prism(16, 0.12, 0.9).mesh, Vector3(0, 0.55, 0), _mats["roller"], platen)
			m["platen"] = platen
			m["platen_top"] = top
			_stripes(root, Vector3(0, 2.7, 0.405), 2.0, 0.2)
			for x: float in [-0.85, 0.85]:
				_collide(body, Vector3(0.24, 2.6, 0.5), Vector3(x, 1.3, 0))
			_collide(body, Vector3(2.0, 0.45, 0.8), Vector3(0, 2.7, 0))
		"bath":
			# An open tank of glowing green stripper with a hoist frame over it.
			_part(PartShapes.chamfer_box(Vector3(WIDTH, BED + 0.05, LENGTH), 0.03).mesh, Vector3(0, (BED + 0.05) * 0.5, 0), paint, root)
			var liquid := ShipKit.glow(Color(0.35, 0.95, 0.4), 1.2)
			_part(PartShapes.box(Vector3(WIDTH - 0.16, 0.02, LENGTH - 0.16)).mesh, Vector3(0, BED - 0.1, 0), liquid, root)
			for k: float in [-1.0, 1.0]:
				_part(PartShapes.box(Vector3(WIDTH + 0.04, 0.056, 0.056)).mesh, Vector3(0, BED + 0.08, k * LENGTH * 0.5), _mats["steel"], root)
				_part(PartShapes.box(Vector3(0.06, 0.06, LENGTH + 0.04)).mesh, Vector3(k * WIDTH * 0.5, BED + 0.08, 0), _mats["steel"], root)
			var bubbles := Node3D.new()
			bubbles.name = "Bubbles"
			bubbles.visible = false
			root.add_child(bubbles)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 14:
				_part(PartShapes.dome(0.04 + rng.randf() * 0.04, 0.03, 8, 2).mesh, Vector3(rng.randf_range(-0.6, 0.6), BED - 0.09, rng.randf_range(-0.9, 0.9)),
						ShipKit.glow(Color(0.6, 1.0, 0.6), 2.0), bubbles)
			m["bubbles"] = bubbles
			for z: float in [-1.0, 1.0]:
				for x: float in [-0.88, 0.88]:
					_part(PartShapes.box(Vector3(0.1, 2.0, 0.1)).mesh, Vector3(x, 1.0, z), _mats["steel"], root)
				_part(PartShapes.box(Vector3(1.86, 0.116, 0.116)).mesh, Vector3(0, 2.0, z), _mats["steel"], root)
			_part(PartShapes.box(Vector3(0.12, 0.12, 2.1)).mesh, Vector3(0, 2.0, 0), _mats["yellow"], root)
			_part(WreckParts.junction_box(Vector3(0.4, 0.35, 0.35), Color(1.0, 0.6, 0.15)).mesh, Vector3(0, 1.75, 0), _mats["dark"], root)
			var warn := _plate("CORROSIVE", Color(0.35, 0.95, 0.4))
			warn.position = Vector3(side * (WIDTH * 0.5 + 0.012), 0.6, 0.55)
			warn.rotation.y = side * PI * 0.5
			root.add_child(warn)
		"coater":
			# A spray booth: walls each side, a roof, a ring of nozzles and the mist.
			# The back wall solid; the front a framed window so you can watch the coats go on.
			_part(PartShapes.chamfer_box(Vector3(0.16, 2.2, LENGTH), 0.03).mesh, Vector3(-side * 0.815, 1.1, 0), paint, root)
			_part(PartShapes.chamfer_box(Vector3(0.16, BED + 0.1, LENGTH), 0.03).mesh, Vector3(side * 0.815, (BED + 0.1) * 0.5, 0), paint, root)
			for z: float in [-LENGTH * 0.5 + 0.07, LENGTH * 0.5 - 0.07]:
				_part(PartShapes.box(Vector3(0.16, 2.2 - BED - 0.1, 0.14)).mesh, Vector3(side * 0.815, (2.2 + BED + 0.1) * 0.5, z), paint, root)
			_part(PartShapes.box(Vector3(0.03, 2.2 - BED - 0.1, LENGTH - 0.28)).mesh, Vector3(side * 0.815, (2.2 + BED + 0.1) * 0.5, 0), Glazing.material(Glazing.Kind.CLEAR), root)
			for x: float in [-0.815, 0.815]:
				_collide(body, Vector3(0.16, 2.2, LENGTH), Vector3(x, 1.1, 0))
			_part(PartShapes.chamfer_box(Vector3(1.8, 0.2, LENGTH), 0.03).mesh, Vector3(0, 2.3, 0), paint, root)
			_part(PartShapes.box(Vector3(1.0, 0.3, 1.0)).mesh, Vector3(0, 2.55, 0), _mats["dark"], root)
			_part(PartShapes.louvre(0.9, 0.9, 0.05, 6).mesh, Vector3(0, 2.71, 0), _mats["steel"], root)
			for i in 6:
				var a := TAU * i / 6.0
				_part(PartShapes.frustum(0.05, 0.02, 0.18).mesh, Vector3(cos(a) * 0.65, BED + 0.7 + sin(a) * 0.6, 0),
						_mats["dark"], root, Basis(Vector3.FORWARD, a + PI * 0.5))
			var mist := Node3D.new()
			mist.name = "Mist"
			mist.visible = false
			mist.position = Vector3(0, BED + 0.6, 0)
			root.add_child(mist)
			var fog := StandardMaterial3D.new()
			fog.albedo_color = Color(0.4, 0.6, 0.8, 0.28)
			fog.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fog.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fog.cull_mode = BaseMaterial3D.CULL_DISABLED
			_part(PartShapes.prism(10, 0.62, LENGTH - 0.3).mesh, Vector3.ZERO, fog, mist, Basis(Vector3.RIGHT, PI * 0.5))
			m["mist"] = mist
			_stripes(root, Vector3(0, 2.3, LENGTH * 0.5 + 0.012), 1.8, 0.16)
	# The lamp, the plate and the screen on a console at the front.
	var lamp_at := Vector3(side * 0.6, 2.05 if s != "straightener" else 2.95, -0.75)
	if s == "grinder":
		lamp_at = Vector3(side * 0.6, BED + 1.55, -0.4)
	m["lamp"] = _part(PartShapes.prism(12, 0.06, 0.1).mesh, lamp_at, _lamp_idle, root)
	var console := Vector3(side * (WIDTH * 0.5 + 0.45), 0, -0.45)
	_part(PartShapes.box(Vector3(0.14, 1.1, 0.14)).mesh, console + Vector3(0, 0.55, 0), _mats["dark"], root)
	_part(PartShapes.box(Vector3(0.5, 0.06, 0.4)).mesh, console + Vector3(0, 0.03, 0), _mats["dark"], root)
	_collide(body, Vector3(0.3, 1.2, 0.3), console + Vector3(0, 0.6, 0))
	var face := Basis(Vector3.UP, side * PI * 0.5) * Basis(Vector3.RIGHT, -0.35)
	_part(PartShapes.chamfer_box(Vector3(0.66, 0.46, 0.06), 0.015).mesh, console + Vector3(0, 1.25, 0), _mats["dark"], root, face)
	var screen := Touch.new()
	screen.name = "Screen"
	screen.transform = Transform3D(face, console + Vector3(0, 1.25, 0) + face * Vector3(0, 0, 0.04))
	root.add_child(screen)
	screen.call("setup", Vector2(0.62, 0.42), str(TITLES[s]), 3 if s == "survey" else 2)
	if s == "survey":
		screen.call("add_button", "prev", "PREV", next.bind(-1))
		screen.call("add_button", "next", "NEXT", next.bind(1))
		screen.call("add_button", "route", "ROUTE", swap_route)
	screen.call("add_button", "go", "START", go.bind(s), true)
	screen.call("add_button", "auto", "AUTO", toggle_auto)
	m["screen"] = screen
	var plate := _plate(str(TITLES[s]), Color(0.95, 0.95, 0.92))
	plate.position = console + Vector3(side * 0.075, 0.75, 0)
	plate.rotation.y = side * PI * 0.5
	root.add_child(plate)
	var motor := Sfx.loop("servo", root, -14.0)
	if motor:
		motor.stop()
		motor.pitch_scale = {"survey": 1.6, "grinder": 0.6, "straightener": 0.8, "bath": 1.1, "coater": 1.3}[s]
	m["motor"] = motor
	machines[s] = m


## Roller conveyor between the machines and the turntable where the grind branch leaves.
func _build_conveyors() -> void:
	var root := Node3D.new()
	root.name = "Conveyors"
	add_child(root)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.set_meta("surface", "metal")
	root.add_child(body)
	var order := ["survey", "straightener", "bath", "coater"]
	var runs: Array = []
	for i in order.size() - 1:
		runs.append([STATIONS[order[i]].at, STATIONS[order[i + 1]].at])
	runs.append([STATIONS.coater.at, LINE_END + Vector3(0, 0, 0.3)])
	runs.append([DIVERTER, STATIONS.grinder.at])
	for r: Array in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var along := b - a
		along.y = 0.0
		var len := along.length()
		var dir := along / len
		# Only the stretch between the machines' ends (they carry their own bed).
		var from := a + dir * LENGTH * 0.5
		var to := b - dir * (LENGTH * 0.5 if r[1] != LINE_END + Vector3(0, 0, 0.3) else 0.0)
		if r[0] == DIVERTER:
			from = a + dir * 0.7
		var mid := (from + to) * 0.5
		var span := from.distance_to(to)
		if span <= 0.05:
			continue
		var seg := Node3D.new()
		seg.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), Vector3(mid.x, 0, mid.z))
		root.add_child(seg)
		_bed(seg, span, Vector3.ZERO, true)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, BED, span)
		col.shape = box
		col.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), Vector3(mid.x, BED * 0.5, mid.z))
		body.add_child(col)
	# The turntable: a round bed on a drum, with its own short rollers.
	var turn := Node3D.new()
	turn.name = "Diverter"
	turn.position = Vector3(DIVERTER.x, 0, DIVERTER.z)
	root.add_child(turn)
	_part(PartShapes.prism(20, 0.75, BED - 0.12).mesh, Vector3(0, (BED - 0.12) * 0.5, 0), _mats["dark"], turn)
	_part(PartShapes.prism(20, 0.8, 0.06).mesh, Vector3(0, BED - 0.09, 0), _mats["steel"], turn)
	for i in 5:
		_part(PartShapes.prism(10, 0.05, 1.0).mesh, Vector3(0, BED - 0.03, -0.4 + i * 0.2), _mats["roller"], turn, Basis(Vector3.FORWARD, PI * 0.5))
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, BED, 1.6)
	col.shape = box
	col.position = Vector3(DIVERTER.x, BED * 0.5, DIVERTER.z)
	body.add_child(col)
	# A run of yellow floor paint round the line, where you stand to work it.
	var paint: Material = _mats["yellow"]
	_part(PartShapes.box(Vector3(0.12, 0.01, 18.2)).mesh, Vector3(LINE_X - 2.05, 0.006, -11.0), paint, root)
	_part(PartShapes.box(Vector3(7.6, 0.01, 0.12)).mesh, Vector3(41.9, 0.006, -14.2), paint, root)


## A roller bed `length` long along +Z in `parent`'s frame: side rails, rollers, legs.
func _bed(parent: Node3D, length: float, at: Vector3, legs := false) -> void:
	for x: float in [-0.56, 0.56]:
		_part(PartShapes.box(Vector3(0.08, 0.16, length)).mesh, at + Vector3(x, BED - 0.08, 0), _mats["steel"], parent)
	var n := maxi(2, floori(length / 0.22))
	for i in n:
		var z := -length * 0.5 + (i + 0.5) * length / n
		_part(PartShapes.prism(10, 0.045, 1.04).mesh, at + Vector3(0, BED - 0.05, z), _mats["roller"], parent, Basis(Vector3.FORWARD, PI * 0.5))
	if legs:
		for z: float in [-length * 0.5 + 0.15, length * 0.5 - 0.15]:
			for x: float in [-0.5, 0.5]:
				_part(PartShapes.box(Vector3(0.07, BED - 0.16, 0.07)).mesh, at + Vector3(x, (BED - 0.16) * 0.5, z), _mats["dark"], parent)


## The dust vessel at the end of the grind branch, its fill showing through a sight glass,
## and a small screen on a post.
func _build_dust() -> void:
	var root := Node3D.new()
	root.name = "DustVessel"
	root.position = DUST_SPOT
	root.add_to_group("gfx_interactable")
	root.set_meta("gfx_id", "line:dust")
	add_child(root)
	# A square skid, the drum on it, a cone lid with the chute's mouth.
	_part(PartShapes.chamfer_box(Vector3(2.0, 0.16, 2.0), 0.02).mesh, Vector3(0, 0.08, 0), _mats["dark"], root)
	_part(PartShapes.prism(20, 0.85, 1.6).mesh, Vector3(0, 0.96, 0), _mats["vessel"], root)
	_part(PartShapes.frustum(0.85, 0.3, 0.35, 20).mesh, Vector3(0, 1.935, 0), _mats["vessel"], root)
	_part(PartShapes.prism(12, 0.3, 0.1).mesh, Vector3(0, 2.15, 0), _mats["steel"], root)
	for k: float in [0.5, 1.4]:
		_part(PartShapes.ring(0.85, 0.89, 0.06).mesh, Vector3(0, k, 0), _mats["steel"], root, Basis(Vector3.RIGHT, PI * 0.5))
	# The sight glass on the hall side: a dark slot with the dust rising in it.
	var face := Vector3(0, 0, 0.86)
	_part(PartShapes.box(Vector3(0.24, 1.36, 0.03)).mesh, face + Vector3(0, 0.98, 0), _mats["dark"], root)
	# The fill grows from the bottom: its node sits at the glass's foot, the mesh over it.
	_dust_fill = Node3D.new()
	_dust_fill.name = "Fill"
	_dust_fill.position = face + Vector3(0, 0.33, 0.012)
	root.add_child(_dust_fill)
	_part(PartShapes.box(Vector3(0.18, 1.3, 0.02)).mesh, Vector3(0, 0.65, 0), ShipKit.glow(Color(0.9, 0.62, 0.3), 1.2), _dust_fill)
	_dust_label = _plate("DUST  0 / 3000 KG", Color(0.95, 0.95, 0.92))
	_dust_label.position = face + Vector3(0.0, 1.78, 0.03)
	root.add_child(_dust_label)
	var post := Vector3(1.25, 0, 0.8)
	_part(PartShapes.box(Vector3(0.12, 1.1, 0.12)).mesh, post + Vector3(0, 0.55, 0), _mats["dark"], root)
	var tilt := Basis(Vector3.RIGHT, -0.35)
	_part(PartShapes.chamfer_box(Vector3(0.56, 0.4, 0.06), 0.015).mesh, post + Vector3(0, 1.22, 0), _mats["dark"], root, tilt)
	dust_screen = Touch.new()
	dust_screen.name = "Screen"
	dust_screen.transform = Transform3D(tilt, post + Vector3(0, 1.22, 0) + tilt * Vector3(0, 0, 0.04))
	root.add_child(dust_screen)
	dust_screen.call("setup", Vector2(0.52, 0.36), "DUST VESSEL", 1)
	dust_screen.call("add_button", "send", "SEND TO STORES", send_dust, true)


## The output pallets at the end of the line and the screen that calls a trolley for them.
func _build_output() -> void:
	var root := Node3D.new()
	root.name = "Output"
	root.add_to_group("gfx_interactable")
	root.set_meta("gfx_id", "line:out")
	add_child(root)
	for p: Vector3 in OUT_SPOTS:
		_part(PartShapes.box(Vector3(1.1, 0.14, 1.3)).mesh, p + Vector3(0, 0.07, 0), _mats["wood"], root)
		for k: float in [-1.0, 1.0]:
			_part(PartShapes.box(Vector3(1.3, 0.01, 0.08)).mesh, p + Vector3(0, 0.006, k * 0.78), _mats["yellow"], root)
	# The bed's end: a stop bar over the first pallet.
	_part(PartShapes.box(Vector3(1.2, 0.12, 0.08)).mesh, LINE_END + Vector3(0, -0.02, 0.34), _mats["yellow"], root)
	var post := Vector3(LINE_X - 1.3, 0, -3.5)
	_part(PartShapes.box(Vector3(0.12, 1.1, 0.12)).mesh, post + Vector3(0, 0.55, 0), _mats["dark"], root)
	var face := Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, -0.35)
	_part(PartShapes.chamfer_box(Vector3(0.56, 0.4, 0.06), 0.015).mesh, post + Vector3(0, 1.22, 0), _mats["dark"], root, face)
	out_screen = Touch.new()
	out_screen.name = "Screen"
	out_screen.transform = Transform3D(face, post + Vector3(0, 1.22, 0) + face * Vector3(0, 0, 0.04))
	root.add_child(out_screen)
	out_screen.call("setup", Vector2(0.52, 0.36), "LINE OUTPUT", 1)
	out_screen.call("add_button", "call", "CALL TROLLEY", call_trolleys, true)


func _stripes(parent: Node3D, at: Vector3, width: float, height: float) -> void:
	var n := 9
	for i in n:
		if i % 2 == 1:
			_part(PartShapes.box(Vector3(width / n, height, 0.012)).mesh, at + Vector3(-width * 0.5 + (i + 0.5) * width / n, 0, 0), _mats["dark"], parent)
		else:
			_part(PartShapes.box(Vector3(width / n, height, 0.01)).mesh, at + Vector3(-width * 0.5 + (i + 0.5) * width / n, 0, 0), _mats["yellow"], parent)


func _plate(text: String, colour: Color) -> Label3D:
	var plate := Label3D.new()
	plate.text = text
	plate.font = ShipKit.mono_font()
	plate.font_size = 36
	plate.pixel_size = 0.0025
	plate.modulate = colour
	plate.outline_size = 0
	return plate


static func _kg(kg: float) -> String:
	return "%d" % roundi(kg) if kg >= 10.0 else "%.1f" % kg


static func _paint(colour: Color, metallic: float, roughness: float, finish: String) -> Material:
	return ShipSurface.of(ShipKit.paint(colour, metallic, roughness, finish))


func _part(mesh: Mesh, at: Vector3, mat: Material, parent: Node3D = null, basis := Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, at)
	(parent if parent else self).add_child(mi)
	return mi


func _collide(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = at
	body.add_child(col)
