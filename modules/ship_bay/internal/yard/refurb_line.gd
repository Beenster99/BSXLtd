extends Node3D
## One of the two refurbishment lines that fill Pre-assembly side by side: four big machines
## on a roller conveyor that bring worn goods back to 100%, between an intake bay at the
## north end and the line's own trolley at the south end.
##
##   INTAKE BAY   -> a painted bay big enough for the large trolley: trolleys set worn parts
##                   down on its three drop-off zones (a clean-up's, or anyone's); the red zone
##                   beside them is for scrap the survey sends back.
##   SURVEY       -> scans a lot and says SCRAP (condition GRIND_BELOW or worse) or REFURBISH;
##                   ROUTE overrides it. Its screen picks the lot: the bay's first, then the
##                   stores' (worst first). Scrap goes onto the red scrap zone and a trolley takes
##                   it outside to the crusher (CrusherPlant).
##   STRAIGHTENER -> a press that takes the dents and bends out (60%)
##   BATH         -> a chemical bath that strips the surface back to bare metal (85%)
##   COATER       -> a spray booth that lays the protective coats on (100%)
##   LINE TROLLEY -> the line's own big trolley stands under the end of the conveyor and the
##                   finished lots are stacked on it as they come off (up to 50). When it is
##                   full, or SEND TO STORES is pressed, it drives to the stores, the picking
##                   lift shelves its goods, and it comes back.
##
## By hand each machine's screen has START (run what is in it) and SEND ON (pass a finished
## lot on). AUTO (on any screen, both lines) runs the lines: each loads its next lot, runs
## and sends every machine, and sends its trolley off when it is full or the line has run
## dry. The lines' state is the bus's (line_state(), host-authoritative, saved with the bay);
## this node draws its line, times its machines and, on the host, drives AUTO.
##
## Built in yard space: the node sits at the yard's origin; the line runs south (+Z) along
## x = LINES[line_id] with the machines' fronts to the west (-X).

const Touch := preload("res://modules/ship_bay/internal/kit/touch_screen.gd")
const T := preload("res://modules/ui/api/terminal_kit.gd")
const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
const LineParts := preload("res://modules/ship_bay/internal/yard/line_parts.gd")
const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")
const BeamLine := preload("res://modules/ship_bay/internal/yard/trolley_beam_line.gd")

## The lines: id -> centre line (x, yard space). Their trolleys have the same ids.
const LINES := {"a": 35.0, "b": 45.0}
## The machines in work order, and where each stands along its line (z, yard space).
const ORDER: PackedStringArray = ["survey", "straightener", "bath", "coater"]
const STATION_Z := {"survey": -14.4, "straightener": -8.2, "bath": -2.0, "coater": 4.2}
## A machine's own frame: conveyor top, footprint along the line and across it (metres).
const BED := 0.9
const LENGTH := 2.2
const WIDTH := 1.6
## The frames are drawn this many times bigger (across, up, along), so that the biggest goods
## in the catalogue fit through the machines.
const SCALE := Vector3(1.9, 1.15, 2.4)
## The conveyor's top over the floor, metres (yard space).
const BED_Y := BED * 1.15
## The end of the conveyor (z), over the nose of the line's trolley.
const LINE_END_Z := 9.4
## The intake bay: its north and south edges (z) and half its width (x).
const BAY_Z := Vector2(-23.6, -18.0)
const BAY_HALF := 4.9
## The bay's drop-off zones (x from the line, at IN_Z): three for parts in, one for scrap out.
const IN_X: Array[float] = [-3.4, -1.1, 1.2]
## The one drop area's places: columns (x from the line) and rows (z either side of IN_Z),
## and the area itself (x from the line, width, depth).
const AREA_X: Array[float] = [-3.5, -1.25, 1.0]
const AREA_ROW := 1.3
const AREA := Vector3(-1.25, 6.9, 5.0)
const SCRAP_X := 3.5
const IN_Z := -20.8
## The machines' names on their plates and screens.
const TITLES := {"survey": "SURVEY  SV-%s", "straightener": "STRAIGHTENER  PR-%s", "bath": "CHEMICAL BATH  CB-%s",
		"coater": "COATER  PC-%s"}

## What each machine does, for the tip shown while you look at it.
const HINTS := {
	"survey": "Pick a worn lot from the intake bay or the stores, LOAD and SCAN it: it says scrap or refurbish. ROUTE overrides it.",
	"straightener": "Presses the dents and bends out of a lot (to 60%).",
	"bath": "Strips a lot back to bare metal (to 85%).",
	"coater": "Sprays on the protective coats: the lot comes out at 100% onto the line's trolley.",
}

## Seconds a machine takes over a lot, and a lot takes from one machine to the next.
@export var run_time := 5.0
@export var travel_time := 1.4

## Which line this is ("a" or "b").
var line_id := "a"
## Each machine: id -> {node, frame, screen, lamp, parts used by its run animation}.
var machines: Dictionary = {}
## The screen at the end of the line, by the line's trolley.
var end_screen: Node3D
## The lots the survey's screen offers (bus.line_candidates()) and which it shows.
var lots: Array[Dictionary] = []
var pick := 0
## Seconds left on each running machine (every peer times them; the host's says finish).
var running: Dictionary = {}

var _bus: ShipBayBus
var _state: Dictionary = {}
var _mats: Dictionary = {}
var _lamp_on: Material
var _lamp_idle: Material
var _lamp_done: Material
## The lot drawn on each machine, and the ones travelling between them.
var _lot_nodes: Dictionary = {}
var _movers: Array[Node3D] = []
## Tractor beams drawing lots in: [beam, mover, from (yard space)].
var _beams: Array = []
## The bay's waiting crates as drawn (crate id -> node).
var _crate_nodes: Dictionary = {}
var _crates_root: Node3D
var _auto_clock := 0.0
## Scrap crates a trolley has been called for.
var _called: Dictionary = {}


func _init(id := "a") -> void:
	line_id = id


## A machine's lot place on line `line` (yard space, on the bed).
static func station_at(line: String, s: String) -> Vector3:
	return Vector3(float(LINES[line]), BED_Y, float(STATION_Z[s]))


## The intake bay's drop-off zones for parts coming in (floor points, yard space).
static func in_spots(line: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	# One drop area (ship_bay.open_feed_areas, beenster 0.3.19): two rows of three places
	# over the bay west of the scrap zone, so a trolley leaves all its parts and goes.
	if Flags.is_on("ship_bay.open_feed_areas"):
		for z: float in [IN_Z - AREA_ROW, IN_Z + AREA_ROW]:
			for x: float in AREA_X:
				out.append(Vector3(float(LINES[line]) + x, 0, z))
		return out
	for x: float in IN_X:
		out.append(Vector3(float(LINES[line]) + x, 0, IN_Z))
	return out


## The bay's scrap zone, where the survey sets down what goes to the crusher.
static func scrap_spot(line: String) -> Vector3:
	return Vector3(float(LINES[line]) + SCRAP_X, 0, IN_Z)


## The end of the line's conveyor (yard space, on the bed).
static func line_end(line: String) -> Vector3:
	return Vector3(float(LINES[line]), BED_Y, LINE_END_Z)


## A machine's title on line `line`.
static func title(line: String, s: String) -> String:
	return str(TITLES[s]) % line.to_upper()


func _ready() -> void:
	name = "RefurbLine" + line_id.to_upper()
	_mats = {
		"dark": _paint(Color(0.12, 0.13, 0.15), 0.5, 0.5, "gunmetal"),
		"steel": _paint(Color(0.6, 0.62, 0.64), 0.75, 0.4, "galvanised"),
		"roller": _paint(Color(0.7, 0.72, 0.74), 0.85, 0.3, "brushed_steel"),
		"yellow": _paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"),
		"red": _paint(Color(0.75, 0.16, 0.12), 0.1, 0.6, "satin_paint"),
		"survey": _paint(Color(0.22, 0.38, 0.52), 0.35, 0.45, "satin_paint"),
		"straightener": _paint(Color(0.95, 0.68, 0.1), 0.2, 0.5, "hazard_paint"),
		"bath": _paint(Color(0.2, 0.46, 0.4), 0.3, 0.45, "satin_paint"),
		"coater": _paint(Color(0.86, 0.85, 0.82), 0.2, 0.45, "satin_paint"),
		"wood": _paint(Color(0.55, 0.42, 0.28), 0.0, 0.8, "wood"),
		"zone": _paint(Color(0.36, 0.32, 0.16), 0.0, 0.85, "satin_paint"),
		"zone_red": _paint(Color(0.36, 0.13, 0.11), 0.0, 0.85, "satin_paint"),
	}
	_lamp_on = ShipKit.glow(Color(1.0, 0.55, 0.15), 4.0)
	_lamp_idle = ShipKit.glow(Color(0.5, 0.55, 0.6), 0.8)
	_lamp_done = ShipKit.glow(Color(0.25, 0.9, 0.45), 2.0)
	_build_conveyors()
	for s: String in ORDER:
		_build_machine(s)
	_build_intake()
	_build_end()
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

## The survey's PREV / NEXT: which lot LOAD takes.
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
			_request("load", _load_args(lots[pick]))
			Sfx.play("clunk", machines[station].node)
			return
		Sfx.play("error", machines[station].node)
		return
	match str(at.state):
		"waiting":
			_request("start", {"station": station})
		"done":
			_request("send", {"station": station})
		_:
			Sfx.play("error", machines[station].node)


## What LOAD asks for a lot the survey offers: a stored lot, or a part in the intake bay.
static func _load_args(lot: Dictionary) -> Dictionary:
	return {"crate": str(lot.crate)} if lot.has("crate") else {"location": str(lot.location)}


## The survey's ROUTE: swaps its call between scrapping and refurbishing.
func swap_route() -> void:
	var at: Dictionary = _station("survey")
	if at.is_empty():
		Sfx.play("error", machines["survey"].node)
		return
	_request("route", {"route": "refurb" if str(at.lot.route) == "grind" else "grind"})


## AUTO on any screen: both lines run themselves, or go back to hand.
func toggle_auto() -> void:
	_request("auto", {"on": not bool(_state.get("auto", false))})


## The end screen's SEND TO STORES: the line's trolley takes what is on it to the stores.
func send_trolley() -> void:
	if _bus == null or _bus.trolley_goods(line_id) == 0 or not _bus.line_trolley_home(line_id):
		Sfx.play("error", end_screen)
		return
	_bus.command_trolley(line_id, "put_away")
	Sfx.play("chime", end_screen, -8.0)


func _request(op: String, args: Dictionary) -> void:
	var a := args.duplicate()
	a["line"] = line_id
	_bus.line_request(op, a)


# --- Running ---------------------------------------------------------------------------------

func _stations_of(state: Dictionary) -> Dictionary:
	return ((state.get("lines", {}) as Dictionary).get(line_id, {}) as Dictionary).get("stations", {})


func _on_line_changed() -> void:
	var was := _state
	_state = _bus.line_state()
	var st := _stations_of(_state)
	var old := _stations_of(was)
	for s: String in st:
		var now_state := str((st[s] as Dictionary).get("state", ""))
		var then_state := str((old.get(s, {}) as Dictionary).get("state", ""))
		if now_state == "running" and then_state != "running":
			running[s] = run_time
			_start_sound(s, true)
		elif now_state != "running" and running.has(s):
			running.erase(s)
			_start_sound(s, false)
			if now_state == "done":
				Sfx.play("chime", machines[s].node, -10.0)
		# A lot arriving from the machine before it rides the conveyor across.
		if then_state == "" and now_state == "waiting":
			for from: String in old:
				if from != s and str((old[from] as Dictionary).get("state", "")) == "done" and (st.get(from, {}) as Dictionary).is_empty() \
						and ShipBayBus._line_next(from, old[from].lot) == s:
					_travel([_rest(from), _rest(s)], old[from].lot)
	# A part out of the bay rides across into the survey.
	for id: String in _crate_nodes:
		if not _bus.line_crates().has(id) and str(_crate_nodes[id].get_meta("line", "")) == "in":
			if str((st.get("survey", {}) as Dictionary).get("state", "")) == "waiting" and (old.get("survey", {}) as Dictionary).is_empty():
				var from: Vector3 = (_crate_nodes[id] as Node3D).position
				if Flags.is_on("ship_bay.open_feed_areas"):
					# Beamed up out of the drop area and in over the survey's front.
					var mouth := _rest("survey") + Vector3(0, 0, -LENGTH * SCALE.z * 0.5)
					_travel([from, from + Vector3(0, BED_Y + 1.2, 0), mouth + Vector3(0, 0.8, 0), _rest("survey")], st["survey"].lot,
							mouth + Vector3(0, BED_Y + 1.6, 0))
				else:
					_travel([from, from + Vector3(0, BED_Y, 0), _rest("survey") + Vector3(0, 0, -LENGTH * SCALE.z * 0.5), _rest("survey")], st["survey"].lot)
	var survey_was: Dictionary = old.get("survey", {})
	if str(survey_was.get("state", "")) == "done" and (st.get("survey", {}) as Dictionary).is_empty() and str(survey_was.lot.get("route", "")) == "grind":
		# Scrap rides back off the front of the survey onto the red scrap zone.
		var p := scrap_spot(line_id)
		_travel([_rest("survey"), _rest("survey") + Vector3(0, 0, -LENGTH * SCALE.z * 0.5), Vector3(p.x, BED_Y, p.z), p + Vector3(0, 0.15, 0)], survey_was.lot)
	var coater_was: Dictionary = old.get("coater", {})
	if str(coater_was.get("state", "")) == "done" and (st.get("coater", {}) as Dictionary).is_empty():
		# A finished lot rides down the end of the line onto the trolley.
		var lot: Dictionary = (coater_was.lot as Dictionary).duplicate()
		lot["stage"] = "coater"
		var deck := Vector3(float(LINES[line_id]), 1.0, LINE_END_Z + 1.2)
		_travel([_rest("coater"), line_end(line_id), deck], lot)
	_show_all()


func _on_stock_changed() -> void:
	var was := _lot_key(lots[pick]) if pick < lots.size() else ""
	lots = _bus.line_candidates(line_id) if _bus else ([] as Array[Dictionary])
	pick = 0
	for i in lots.size():
		if _lot_key(lots[i]) == was:
			pick = i
	for id: String in _called.keys():
		if not _bus.line_crates().has(id):
			_called.erase(id)
	_draw_crates()
	_show_all()


static func _lot_key(lot: Dictionary) -> String:
	return str(lot.get("crate", lot.location))


func _process(delta: float) -> void:
	for b: Array in _beams:
		if is_instance_valid(b[1]):
			(b[0] as Node).call("draw", b[2], (b[1] as Node3D).global_position + Vector3(0, 0.3, 0), delta)
	for s: String in running.keys():
		running[s] = maxf(float(running[s]) - delta, 0.0)
		_animate(s, 1.0 - float(running[s]) / maxf(run_time, 0.01))
		if float(running[s]) <= 0.0 and _bus and _bus.line_runs_here() and not bool(machines[s].get("finishing", false)):
			machines[s]["finishing"] = true
			_request("finish", {"station": s})
	for s: String in machines:
		if not running.has(s) and bool(machines[s].get("finishing", false)):
			machines[s]["finishing"] = false
	if _bus and _bus.line_runs_here():
		_auto_clock -= delta
		if _auto_clock <= 0.0:
			_auto_clock = 0.5
			_call_for_scrap()
			if bool(_state.get("auto", false)):
				_auto_step()
			elif Flags.is_on("ship_bay.refurb_runs_intake"):
				_auto_step(true)


## Scrap on the bay's red scrap zone always gets a trolley to take it out to the crusher (host).
func _call_for_scrap() -> void:
	for id: String in _bus.line_crates():
		var c: Dictionary = _bus.line_crates()[id]
		if str(c.line) == "scrap" and str(c.get("line_id", "")) == line_id and not _called.has(id):
			var t := _bus.call_trolley_for(id)
			if t != "":
				_called[id] = t


## One look round the line on AUTO (host): pass finished lots on from the end of the line
## back, start whatever waits, load the survey, and send the trolley off when it is full or
## the line has nothing left to do. `intake_only`: AUTO is off, so only lots trolleys set
## down in the intake bay are loaded (worn goods in the stores wait for AUTO or a hand),
## though whatever is already on the line still runs on.
func _auto_step(intake_only := false) -> void:
	var todo := lots.filter(func(l: Dictionary) -> bool: return str(l.location) == "INTAKE") if intake_only else lots
	var st := _stations_of(_state)
	var busy := false
	for s: String in ["coater", "bath", "straightener", "survey"]:
		var at: Dictionary = st.get(s, {})
		if at.is_empty():
			continue
		busy = true
		if _moving():
			continue
		if str(at.state) == "done":
			_request("send", {"station": s})
		elif str(at.state) == "waiting":
			_request("start", {"station": s})
	if (st.get("survey", {}) as Dictionary).is_empty() and not todo.is_empty() and not _moving():
		_request("load", _load_args(todo[0]))
		busy = true
	var goods := _bus.trolley_goods(line_id)
	if goods > 0 and _bus.line_trolley_home(line_id) and not _moving() \
			and (goods >= _bus.trolley_capacity(line_id) or (not busy and todo.is_empty())):
		_bus.command_trolley(line_id, "put_away")


func _moving() -> bool:
	for m in _movers:
		if is_instance_valid(m):
			return true
	return false


# --- Drawing the state ---------------------------------------------------------------------

func _station(s: String) -> Dictionary:
	return _stations_of(_state).get(s, {})


func _show_all() -> void:
	for s: String in machines:
		_show(s)
		_draw_lot(s)
	_show_end()


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
		screen.call("set_body", "Waiting for a lot.", T.DIM)
		screen.call("set_button", "go", "START", false)
		return
	var lot: Dictionary = at.lot
	var head := "%s x%d  %d%%" % [str(lot.name).to_upper().left(20), int(lot.qty), roundi(float(lot.condition) * 100.0)]
	var to := roundi(float(ShipBayBus.LINE_AFTER.get(s, 1.0)) * 100.0)
	var what: String = {"straightener": "STRAIGHTEN", "bath": "STRIP TO BARE METAL", "coater": "COAT"}[s]
	screen.call("set_body", "%s\n%s -> %d%%" % [head, what, maxi(to, roundi(float(lot.condition) * 100.0))])
	screen.call("set_button", "go", "SEND ON" if state == "done" else "START", state != "running")


func _show_survey(screen: Node3D, at: Dictionary) -> void:
	var state := str(at.get("state", ""))
	if at.is_empty():
		if lots.is_empty():
			screen.call("set_body", "Nothing needs it. Goods under\n100% in the bay or the stores come here.", T.DIM)
		else:
			var lot: Dictionary = lots[pick]
			screen.call("set_body", "%s %d / %d  %s\n%s x%d  %d%%" % ["INTAKE" if lot.has("crate") else "STORES", pick + 1, lots.size(),
					"" if lot.has("crate") else str(lot.location), str(lot.name).to_upper().left(20), int(lot.qty), roundi(float(lot.condition) * 100.0)])
		screen.call("set_button", "go", "LOAD", not lots.is_empty())
		screen.call("set_button", "route", "ROUTE", false)
		return
	var lot: Dictionary = at.lot
	var head := "%s x%d  %d%%" % [str(lot.name).to_upper().left(20), int(lot.qty), roundi(float(lot.condition) * 100.0)]
	var grind := str(lot.route) == "grind"
	var call := "SCRAP: TO THE CRUSHER" if grind else "REFURBISH"
	if state == "done":
		var said := ShipBayBus.survey_route(float(lot.condition), str(lot.item)) == str(lot.route)
		screen.call("set_body", "%s\nSURVEY: %s%s" % [head, call, "" if said else " (YOUR CALL)"], T.AMBER if grind else T.GOOD)
	else:
		screen.call("set_body", "%s\n%s" % [head, "SCANNING..." if state == "running" else "SCAN TO SURVEY IT"])
	screen.call("set_button", "go", "SEND ON" if state == "done" else "SCAN", state != "running")
	screen.call("set_button", "route", "TO SCRAP" if not grind else "TO REFURB", false)


func _show_end() -> void:
	if end_screen == null or _bus == null:
		return
	var goods := _bus.trolley_goods(line_id)
	var cap := _bus.trolley_capacity(line_id)
	var home := _bus.line_trolley_home(line_id)
	end_screen.call("set_status", "%d / %d ON THE TROLLEY" % [goods, cap] if home else "TROLLEY AT THE STORES",
			(T.AMBER if goods >= cap else T.GOOD) if home else T.CYAN)
	var names := PackedStringArray()
	for cid in _bus.trolley_load(line_id):
		var c := _bus.crate_info(cid)
		names.append("%s x%d" % [str(c.get("name", "")).to_upper().left(18), int(c.get("qty", 1))])
	var body := "Finished lots are stacked on the\nline's trolley as they come off." if names.is_empty() \
			else ", ".join(names.slice(0, 6)) + (" +%d MORE" % (names.size() - 6) if names.size() > 6 else "")
	end_screen.call("set_body", body, T.DIM if names.is_empty() else T.TEXT)
	end_screen.call("set_button", "send", "SEND TO STORES", goods > 0 and home)
	end_screen.call("set_button", "auto", "AUTO ON" if bool(_state.get("auto", false)) else "AUTO", bool(_state.get("auto", false)))


## The lot sitting in a machine, as itself: rusty or worn, then bare, then coated.
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
	var key := "%s|%s|%.2f|%s" % [str(lot.item), str(lot.get("shape", "")), float(lot.mass), _look(lot)]
	if node.get_meta("key", "") == key:
		return
	node.set_meta("key", key)
	for c in node.get_children():
		c.free()
	var dented := ["rust", "worn"].has(_look(lot)) and str(lot.get("stage", "")) != "straightener"
	var bend := Basis(Vector3(0.0, 0.0, 1.0), 0.09) * Basis(Vector3(1.0, 0.0, 0.0), -0.06) if dented else Basis()
	var body := Node3D.new()
	body.name = "Body"
	body.basis = bend
	node.add_child(body)
	# The part itself, as it is: rusty or worn, then bare, then in its own paint again.
	var looks := {"rust": ItemLook.Look.RUST, "worn": ItemLook.Look.WORN, "bare": ItemLook.Look.BARE, "coat": ItemLook.Look.NEW}
	var item := ItemLook.make(ItemLook.look_id(str(lot.item), str(lot.get("shape", ""))), looks[_look(lot)], float(lot.mass))
	body.add_child(item)
	var s: Vector3 = item.get_meta("size")
	ItemLook.look_box(body, AABB(Vector3(-s.x * 0.5, 0.0, -s.z * 0.5), s), {"component": str(lot.item), "condition": float(lot.get("condition", 1.0))})


static func _look(lot: Dictionary) -> String:
	match str(lot.get("stage", "")):
		"coater":
			return "coat"
		"bath":
			return "bare"
	return "rust" if float(lot.get("condition", 1.0)) < 0.6 else "worn"


## A lot's size (its item's box, metres).
static func _lot_size(item: String, mass: float) -> Vector3:
	return ItemLook.size_of(item, mass)


## Where a machine's lot rests (yard space, its bottom on the bed or in the bath).
func _rest(s: String) -> Vector3:
	var p := station_at(line_id, s)
	if s == "bath":
		return p + Vector3(0, 0.12 * SCALE.y, 0)
	return p


## A lot riding the conveyor along `points` (a copy of it; the machine draws its own once
## it arrives).
func _travel(points: Array, lot: Dictionary, beam_from := Vector3.INF) -> void:
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
	# Drawn in by the machine's tractor beam (one drop area: the survey picks the parts out).
	var beam: Node3D = null
	if beam_from != Vector3.INF:
		beam = BeamLine.new()
		add_child(beam)
		_beams.append([beam, mover, beam_from])
	tw.tween_callback(func() -> void:
		_movers.erase(mover)
		if beam:
			_beams = _beams.filter(func(b: Array) -> bool: return b[0] != beam)
			beam.queue_free()
		mover.queue_free()
		_show_all()
		_draw_crates())
	_show_all()


## The bay's waiting crates: parts in on its drop-off zones, scrap on the red one.
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
		if not ["in", "scrap"].has(str(c.line)) or str(c.get("line_id", "")) != line_id or _crate_nodes.has(id):
			continue
		var node := Node3D.new()
		node.name = "Crate_" + id.replace("/", "_")
		node.set_meta("line", str(c.line))
		node.position = _bus.crate_position(id) + Vector3(0, 0.15, 0)
		_crates_root.add_child(node)
		_dress_lot(node, {"item": c.item, "mass": c.mass, "condition": c.condition, "shape": c.get("shape", "")})
		var tag := Label3D.new()
		tag.text = "%s  x%d\n%s  %d%%" % [c.name, int(c.qty), "FOR REFURB" if str(c.line) == "in" else "SCRAP: TO THE CRUSHER",
				roundi(float(c.condition) * 100.0)]
		tag.font = ShipKit.mono_font()
		tag.font_size = 40
		tag.pixel_size = 0.0025
		tag.outline_size = 6
		tag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		tag.position = Vector3(0, _lot_size(ItemLook.look_id(str(c.item), str(c.get("shape", ""))), float(c.mass)).y + 0.4, 0)
		node.add_child(tag)
		_crate_nodes[id] = node
	# A lot still riding along hides the bay's copies until it lands.
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
		"straightener":
			# The platen comes down onto the lot three times (in the frame's terms).
			var top := float(m.platen_top)
			var lot_d: Dictionary = _station(s).get("lot", {})
			var low := BED + (_lot_size(ItemLook.look_id(str(lot_d.get("item", "")), str(lot_d.get("shape", ""))), float(lot_d.get("mass", 0.0))).y / SCALE.y + 0.06 if lot else 0.5)
			(m.platen as Node3D).position.y = minf(lerpf(top, low, absf(sin(k * PI * 3.0))), top)
			if lot and k > 0.5:
				(lot.get_node("Body") as Node3D).basis = Basis()
		"bath":
			var dip := 0.75 * sin(k * PI)
			if lot:
				lot.position = _rest(s) - Vector3(0, dip * SCALE.y, 0)
			_hoist(m, dip)
			for p: CPUParticles3D in m.fizz:
				p.emitting = k < 0.95
			# The surface heaves with the boil; the glow brightens and flickers.
			(m.liquid as Node3D).position.y = (0.18 + (BED - 0.28) * 0.5) + sin(k * 70.0) * 0.004
			(m.bath_glow as OmniLight3D).light_energy = 0.9 + 0.25 * sin(k * 53.0) if k < 0.95 else 0.35
		"coater":
			(m.mist as Node3D).visible = k < 0.95
			for p: CPUParticles3D in m.sprays:
				p.emitting = k < 0.95
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
		if s == "bath":
			# The chemicals go live with a hiss and a cloud off the top.
			LineParts.play("hiss", m.node, -3.0)
			(m.burst as CPUParticles3D).restart()
			(m.fizz_sound as AudioStreamPlayer3D).play()
		return
	match s:
		"survey":
			(m.bar as Node3D).position.z = -0.8
		"straightener":
			(m.platen as Node3D).position.y = float(m.platen_top)
		"bath":
			for p: CPUParticles3D in m.fizz:
				p.emitting = false
			(m.fizz_sound as AudioStreamPlayer3D).stop()
			(m.bath_glow as OmniLight3D).light_energy = 0.35
			_hoist(m, 0.0)
		"coater":
			(m.mist as Node3D).visible = false
			for p: CPUParticles3D in m.sprays:
				p.emitting = false


# --- Building ------------------------------------------------------------------------------

## A machine in its own frame: the lot rides along +Z through it at the origin, its front
## (the screen, where you stand) faces `side` * X.
func _build_machine(s: String) -> void:
	var at := station_at(line_id, s)
	var root := Node3D.new()
	root.name = s.capitalize().replace(" ", "")
	root.add_to_group("gfx_interactable")
	root.set_meta("gfx_id", "line:%s:%s" % [line_id, s])
	root.set_meta("look_hint", {"title": title(line_id, s).get_slice("  ", 0).capitalize(), "text": str(HINTS[s]),
			"keys": [["LMB", "Press a button on its screen"]]})
	# Local +Z along the travel (south), the front to the hall's west side.
	root.position = Vector3(at.x, 0, at.z)
	add_child(root)
	var side := -1.0
	var body := StaticBody3D.new()
	body.name = "Body"
	body.set_meta("surface", "metal")
	root.add_child(body)
	# The machine is drawn in its own frame, scaled up to the line's size; its collision
	# boxes are scaled to match (_collide) on the unscaled body.
	var frame := Node3D.new()
	frame.name = "Frame"
	frame.scale = SCALE
	root.add_child(frame)
	var m := {"node": root, "frame": frame}
	var paint: Material = _mats[s]
	# A plinth and the roller bed through the machine.
	_part(PartShapes.chamfer_box(Vector3(WIDTH + 0.2, 0.12, LENGTH + 0.1), 0.02).mesh, Vector3(0, 0.06, 0), _mats["dark"], frame)
	if s != "bath":
		_bed(frame, LENGTH, Vector3.ZERO)
	_collide(body, Vector3(WIDTH, BED, LENGTH), Vector3(0, BED * 0.5, 0))
	match s:
		"survey":
			# A scanning arch over the bed, the scan bar riding it, a cabinet behind.
			for z: float in [-0.95, 0.95]:
				for x: float in [-0.75, 0.75]:
					_part(PartShapes.box(Vector3(0.12, 1.4, 0.12)).mesh, Vector3(x, BED + 0.7, z), paint, frame)
				# A hair shallower than the side bars and shorter than the posts' outer faces, so
				# no two faces meet in one plane.
				_part(PartShapes.box(Vector3(1.614, 0.136, 0.136)).mesh, Vector3(0, BED + 1.45, z), paint, frame)
			for x: float in [-0.75, 0.75]:
				_part(PartShapes.box(Vector3(0.14, 0.14, 2.0)).mesh, Vector3(x, BED + 1.45, 0), paint, frame)
			var bar := Node3D.new()
			bar.name = "ScanBar"
			bar.position = Vector3(0, 0, -0.8)
			frame.add_child(bar)
			_part(PartShapes.box(Vector3(1.4, 0.06, 0.08)).mesh, Vector3(0, BED + 1.36, 0), _mats["dark"], bar)
			_part(PartShapes.box(Vector3(1.3, 0.02, 0.03)).mesh, Vector3(0, BED + 1.32, 0), ShipKit.glow(Color(0.4, 0.86, 1.0), 6.0), bar)
			for x: float in [-0.6, 0.6]:
				_part(PartShapes.box(Vector3(0.02, 1.2, 0.03)).mesh, Vector3(x, BED + 0.72, 0), ShipKit.glow(Color(0.4, 0.86, 1.0), 3.0), bar)
			m["bar"] = bar
			_part(PartShapes.chamfer_box(Vector3(0.6, 2.0, 1.6), 0.04).mesh, Vector3(-side * 1.15, 1.0, 0), paint, frame)
			_collide(body, Vector3(0.6, 2.0, 1.6), Vector3(-side * 1.15, 1.0, 0))
			_collide(body, Vector3(WIDTH, 0.2, LENGTH), Vector3(0, BED + 1.45, 0))
		"straightener":
			# A press: two columns, a crosshead and a ram platen over the bed.
			for x: float in [-0.85, 0.85]:
				_part(PartShapes.box(Vector3(0.24, 2.6, 0.5)).mesh, Vector3(x, 1.3, 0), paint, frame)
			_part(PartShapes.chamfer_box(Vector3(2.0, 0.45, 0.8), 0.04).mesh, Vector3(0, 2.7, 0), paint, frame)
			_part(PartShapes.prism(16, 0.2, 0.6).mesh, Vector3(0, 2.2, 0), _mats["roller"], frame)
			var platen := Node3D.new()
			platen.name = "Platen"
			var top := BED + 1.15
			platen.position = Vector3(0, top, 0)
			frame.add_child(platen)
			_part(PartShapes.chamfer_box(Vector3(1.3, 0.12, 1.1), 0.02).mesh, Vector3(0, 0.06, 0), _mats["dark"], platen)
			_part(PartShapes.prism(16, 0.12, 0.9).mesh, Vector3(0, 0.55, 0), _mats["roller"], platen)
			m["platen"] = platen
			m["platen_top"] = top
			_stripes(frame, Vector3(0, 2.7, 0.405), 2.0, 0.2)
			for x: float in [-0.85, 0.85]:
				_collide(body, Vector3(0.24, 2.6, 0.5), Vector3(x, 1.3, 0))
			_collide(body, Vector3(2.0, 0.45, 0.8), Vector3(0, 2.7, 0))
		"bath":
			# An open tank of glowing green stripper: walls round a liquid you can see into,
			# sparge pipes on its floor that bubble it while it runs, a hoist on a frame over
			# it that lowers the lot in on two cables, vapour coming off the top.
			var wall := 0.08
			var rim := BED + 0.05
			for k: float in [-1.0, 1.0]:
				_part(PartShapes.box(Vector3(wall, rim - 0.12, LENGTH)).mesh, Vector3(k * (WIDTH - wall) * 0.5, 0.12 + (rim - 0.12) * 0.5, 0), paint, frame)
				_part(PartShapes.box(Vector3(WIDTH - wall * 2.0 - 0.002, rim - 0.12, wall)).mesh, Vector3(0, 0.12 + (rim - 0.12) * 0.5, k * (LENGTH - wall) * 0.5), paint, frame)
			_part(PartShapes.box(Vector3(WIDTH - wall * 2.0, 0.06, LENGTH - wall * 2.0)).mesh, Vector3(0, 0.15, 0), _mats["dark"], frame)
			for x: float in [-0.45, 0.0, 0.45]:
				_part(PartShapes.prism(10, 0.03, LENGTH - 0.3).mesh, Vector3(x, 0.21, 0), _mats["steel"], frame, Basis(Vector3.RIGHT, PI * 0.5))
			var surface := BED - 0.1
			var liquid := StandardMaterial3D.new()
			liquid.albedo_color = Color(0.25, 0.85, 0.35, 0.45)
			liquid.emission_enabled = true
			liquid.emission = Color(0.3, 0.95, 0.4)
			liquid.emission_energy_multiplier = 0.8
			liquid.roughness = 0.05
			liquid.metallic_specular = 0.9
			liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var fluid := _part(PartShapes.box(Vector3(WIDTH - wall * 2.0 - 0.004, surface - 0.18, LENGTH - wall * 2.0 - 0.004)).mesh,
					Vector3(0, 0.18 + (surface - 0.18) * 0.5, 0), liquid, frame)
			fluid.name = "Liquid"
			m["liquid"] = fluid
			for k: float in [-1.0, 1.0]:
				_part(PartShapes.box(Vector3(WIDTH + 0.04, 0.056, 0.056)).mesh, Vector3(0, rim + 0.03, k * LENGTH * 0.5), _mats["steel"], frame)
				_part(PartShapes.box(Vector3(0.06, 0.06, LENGTH + 0.04)).mesh, Vector3(k * WIDTH * 0.5, rim + 0.03, 0), _mats["steel"], frame)
			var inner := Vector3((WIDTH - 0.4) * 0.5, 0.01, (LENGTH - 0.4) * 0.5)
			var bubbles := LineParts.bubbles(inner, surface - 0.25)
			bubbles.position = Vector3(0, 0.25, 0)
			frame.add_child(bubbles)
			var pops := LineParts.pops(inner)
			pops.position = Vector3(0, surface + 0.005, 0)
			frame.add_child(pops)
			var vapour := LineParts.vapour(Vector3(inner.x, 0.02, inner.z), Color(0.7, 1.0, 0.75, 0.1))
			vapour.position = Vector3(0, surface + 0.08, 0)
			frame.add_child(vapour)
			var burst := LineParts.vapour(Vector3(inner.x, 0.02, inner.z), Color(0.85, 1.0, 0.85, 0.22), true)
			burst.position = Vector3(0, surface + 0.08, 0)
			frame.add_child(burst)
			m["bubbles"] = bubbles
			m["fizz"] = [bubbles, pops, vapour]
			m["burst"] = burst
			var bath_glow := OmniLight3D.new()
			bath_glow.name = "BathGlow"
			bath_glow.light_color = Color(0.4, 1.0, 0.5)
			bath_glow.omni_range = 2.6
			bath_glow.light_energy = 0.35
			bath_glow.shadow_enabled = false
			bath_glow.set_meta("gfx_no_shadow", true)
			bath_glow.position = Vector3(0, BED + 0.3, 0)
			frame.add_child(bath_glow)
			m["bath_glow"] = bath_glow
			# The hoist frame, its beam and the carriage with two cables down to the lot.
			for z: float in [-1.0, 1.0]:
				for x: float in [-0.88, 0.88]:
					_part(PartShapes.box(Vector3(0.1, 2.0, 0.1)).mesh, Vector3(x, 1.0, z), _mats["steel"], frame)
				_part(PartShapes.box(Vector3(1.854, 0.116, 0.116)).mesh, Vector3(0, 2.0, z), _mats["steel"], frame)
			_part(PartShapes.box(Vector3(0.12, 0.12, 2.1)).mesh, Vector3(0, 2.0, 0), _mats["yellow"], frame)
			_part(WreckParts.junction_box(Vector3(0.4, 0.35, 0.35), Color(1.0, 0.6, 0.15)).mesh, Vector3(0, 1.75, 0), _mats["dark"], frame)
			var cables: Array[Node3D] = []
			for z: float in [-0.35, 0.35]:
				_part(PartShapes.prism(10, 0.06, 0.1).mesh, Vector3(0, 1.88, z), _mats["dark"], frame, Basis(Vector3.FORWARD, PI * 0.5))
				var cable := _part(PartShapes.box(Vector3(0.012, 1.0, 0.012)).mesh, Vector3(0, 1.0, z), _mats["dark"], frame)
				cables.append(cable)
			var spreader := Node3D.new()
			spreader.name = "Spreader"
			frame.add_child(spreader)
			_part(PartShapes.box(Vector3(0.08, 0.06, 0.9)).mesh, Vector3.ZERO, _mats["yellow"], spreader)
			m["cables"] = cables
			m["spreader"] = spreader
			_hoist(m, 0.0)
			var warn := _plate("CORROSIVE", Color(0.35, 0.95, 0.4))
			warn.position = Vector3(side * (WIDTH * 0.5 + 0.012), 0.6, 0.55) * SCALE
			warn.rotation.y = side * PI * 0.5
			root.add_child(warn)
			m["fizz_sound"] = LineParts.loop("bubbling", root, -12.0)
		"coater":
			# A spray booth: walls each side, a roof, a ring of nozzles and the mist.
			# The back wall solid; the front a framed window so you can watch the coats go on.
			_part(PartShapes.chamfer_box(Vector3(0.16, 2.2, LENGTH), 0.03).mesh, Vector3(-side * 0.815, 1.1, 0), paint, frame)
			_part(PartShapes.chamfer_box(Vector3(0.16, BED + 0.1, LENGTH), 0.03).mesh, Vector3(side * 0.815, (BED + 0.1) * 0.5, 0), paint, frame)
			for z: float in [-LENGTH * 0.5 + 0.07, LENGTH * 0.5 - 0.07]:
				_part(PartShapes.box(Vector3(0.16, 2.2 - BED - 0.1, 0.14)).mesh, Vector3(side * 0.815, (2.2 + BED + 0.1) * 0.5, z), paint, frame)
			_part(PartShapes.box(Vector3(0.03, 2.2 - BED - 0.1, LENGTH - 0.28)).mesh, Vector3(side * 0.815, (2.2 + BED + 0.1) * 0.5, 0), Glazing.material(Glazing.Kind.CLEAR), frame)
			for x: float in [-0.815, 0.815]:
				_collide(body, Vector3(0.16, 2.2, LENGTH), Vector3(x, 1.1, 0))
			_part(PartShapes.chamfer_box(Vector3(1.8, 0.2, LENGTH), 0.03).mesh, Vector3(0, 2.3, 0), paint, frame)
			_part(PartShapes.box(Vector3(1.0, 0.3, 1.0)).mesh, Vector3(0, 2.55, 0), _mats["dark"], frame)
			_part(PartShapes.louvre(0.9, 0.9, 0.05, 6).mesh, Vector3(0, 2.71, 0), _mats["steel"], frame)
			var sprays: Array[CPUParticles3D] = []
			for i in 6:
				var a := TAU * i / 6.0
				var nozzle := Vector3(cos(a) * 0.65, BED + 0.7 + sin(a) * 0.6, 0)
				_part(PartShapes.frustum(0.05, 0.02, 0.18).mesh, nozzle, _mats["dark"], frame, Basis(Vector3.FORWARD, a + PI * 0.5))
				# Each nozzle sprays in at the lot.
				var spray := LineParts.spray(Color(0.55, 0.75, 0.95))
				var inward := (Vector3(0, BED + 0.45, 0) - nozzle).normalized()
				spray.transform = Transform3D(Basis.looking_at(-inward, Vector3.FORWARD if absf(inward.y) > 0.9 else Vector3.UP), nozzle + inward * 0.1)
				frame.add_child(spray)
				sprays.append(spray)
			m["sprays"] = sprays
			var mist := Node3D.new()
			mist.name = "Mist"
			mist.visible = false
			mist.position = Vector3(0, BED + 0.6, 0)
			frame.add_child(mist)
			var fog := StandardMaterial3D.new()
			fog.albedo_color = Color(0.4, 0.6, 0.8, 0.28)
			fog.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fog.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fog.cull_mode = BaseMaterial3D.CULL_DISABLED
			_part(PartShapes.prism(10, 0.62, LENGTH - 0.3).mesh, Vector3.ZERO, fog, mist, Basis(Vector3.RIGHT, PI * 0.5))
			m["mist"] = mist
			_stripes(frame, Vector3(0, 2.3, LENGTH * 0.5 + 0.012), 1.8, 0.16)
	# The lamp, the plate and the screen on a console at the front.
	var lamp_at := Vector3(side * 0.6, 2.05 if s != "straightener" else 2.95, -0.75)
	m["lamp"] = _part(PartShapes.prism(12, 0.06, 0.1).mesh, lamp_at, _lamp_idle, frame)
	var console := Vector3(side * (WIDTH * SCALE.x * 0.5 + 0.45), 0, -0.45 * SCALE.z)
	_part(PartShapes.box(Vector3(0.14, 1.1, 0.14)).mesh, console + Vector3(0, 0.55, 0), _mats["dark"], root)
	_part(PartShapes.box(Vector3(0.5, 0.06, 0.4)).mesh, console + Vector3(0, 0.03, 0), _mats["dark"], root)
	_collide(body, Vector3(0.3, 1.2, 0.3), console + Vector3(0, 0.6, 0), false)
	var face := Basis(Vector3.UP, side * PI * 0.5) * Basis(Vector3.RIGHT, -0.35)
	_part(PartShapes.chamfer_box(Vector3(0.66, 0.46, 0.06), 0.015).mesh, console + Vector3(0, 1.25, 0), _mats["dark"], root, face)
	var screen := Touch.new()
	screen.name = "Screen"
	screen.transform = Transform3D(face, console + Vector3(0, 1.25, 0) + face * Vector3(0, 0, 0.04))
	root.add_child(screen)
	screen.call("setup", Vector2(0.62, 0.42), title(line_id, s), 3 if s == "survey" else 2)
	if s == "survey":
		screen.call("add_button", "prev", "PREV", next.bind(-1))
		screen.call("add_button", "next", "NEXT", next.bind(1))
		screen.call("add_button", "route", "ROUTE", swap_route)
	screen.call("add_button", "go", "START", go.bind(s), true)
	screen.call("add_button", "auto", "AUTO", toggle_auto)
	m["screen"] = screen
	var plate := _plate(title(line_id, s), Color(0.95, 0.95, 0.92))
	plate.position = console + Vector3(side * 0.075, 0.75, 0)
	plate.rotation.y = side * PI * 0.5
	root.add_child(plate)
	var motor := Sfx.loop("servo", root, -14.0)
	if motor:
		motor.stop()
		motor.pitch_scale = {"survey": 1.6, "straightener": 0.8, "bath": 1.1, "coater": 1.3}[s]
	m["motor"] = motor
	machines[s] = m




## The bath's hoist: the spreader bar `dip` m below its rest over the lot, the cables
## from the carriage down to it (the machine's frame).
func _hoist(m: Dictionary, dip: float) -> void:
	var low := BED + 0.55 - dip
	(m.spreader as Node3D).position = Vector3(0, low, 0)
	for c: Node3D in m.cables:
		var span := 1.86 - low
		c.scale = Vector3(1, span, 1)
		c.position.y = low + span * 0.5


## Roller conveyor between the machines and on to the end of the line over its trolley.
func _build_conveyors() -> void:
	var root := Node3D.new()
	root.name = "Conveyors"
	add_child(root)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.set_meta("surface", "metal")
	root.add_child(body)
	var half := LENGTH * SCALE.z * 0.5
	var runs: Array = []
	for i in ORDER.size() - 1:
		runs.append([float(STATION_Z[ORDER[i]]) + half, float(STATION_Z[ORDER[i + 1]]) - half])
	runs.append([float(STATION_Z["coater"]) + half, LINE_END_Z])
	var x := float(LINES[line_id])
	for r: Array in runs:
		var span := float(r[1]) - float(r[0])
		if span <= 0.05:
			continue
		var seg := Node3D.new()
		seg.position = Vector3(x, 0, (float(r[0]) + float(r[1])) * 0.5)
		seg.scale = Vector3(SCALE.x, SCALE.y, 1.0)
		root.add_child(seg)
		_bed(seg, span, Vector3.ZERO, true)
		_collide(body, Vector3(1.2 * SCALE.x, BED_Y, span), Vector3(seg.position.x, BED_Y * 0.5, seg.position.z), false)
	# The end of the line: a stop bar and the chute's lip over the trolley's nose.
	_part(PartShapes.box(Vector3(1.2 * SCALE.x, 0.12, 0.08)).mesh, Vector3(x, BED_Y - 0.02, LINE_END_Z + 0.04), _mats["yellow"], root)
	# A run of yellow floor paint down the machines' fronts, where you stand to work them.
	var front := x - WIDTH * SCALE.x * 0.5 - 1.3
	_part(PartShapes.box(Vector3(0.12, 0.01, LINE_END_Z - BAY_Z.y)).mesh, Vector3(front, 0.006, (LINE_END_Z + BAY_Z.y) * 0.5), _mats["yellow"], root)


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


## The intake bay at the head of the line: its outline in hazard yellow (big enough for the
## large trolley to stand in), three drop-off zones painted for parts in and a red one for
## scrap, its name
## on the floor and on a board on the north wall.
func _build_intake() -> void:
	var root := Node3D.new()
	root.name = "Intake"
	add_child(root)
	var x := float(LINES[line_id])
	var depth := BAY_Z.y - BAY_Z.x
	for z: float in [BAY_Z.x + 0.06, BAY_Z.y]:
		_part(PartShapes.box(Vector3(BAY_HALF * 2.0, 0.01, 0.12)).mesh, Vector3(x, 0.006, z), _mats["yellow"], root)
	for k: float in [-1.0, 1.0]:
		_part(PartShapes.box(Vector3(0.12, 0.01, depth)).mesh, Vector3(x + k * BAY_HALF, 0.006, (BAY_Z.x + BAY_Z.y) * 0.5), _mats["yellow"], root)
		# A bollard at each front corner.
		_part(PartShapes.prism(10, 0.12, 1.0).mesh, Vector3(x + k * (BAY_HALF + 0.25), 0.5, BAY_Z.y + 0.2), _mats["yellow"], root)
	var spots := in_spots(line_id)
	if Flags.is_on("ship_bay.open_feed_areas"):
		_drop_zone(Vector3(x + AREA.x, 0, IN_Z), Vector2(AREA.y, AREA.z), _mats["zone"], _mats["yellow"], "DROP AREA", Color(0.95, 0.75, 0.1), root)
	else:
		for i in spots.size():
			_drop_zone(spots[i], Vector2(2.0, 2.1), _mats["zone"], _mats["yellow"], "DROP %d" % (i + 1), Color(0.95, 0.75, 0.1), root)
	_drop_zone(scrap_spot(line_id), Vector2(2.0, 2.1), _mats["zone_red"], _mats["red"], "SCRAP", Color(0.95, 0.4, 0.3), root)
	var words := _plate("LINE %s INTAKE" % line_id.to_upper(), Color(0.95, 0.75, 0.1))
	words.font_size = 120
	words.position = Vector3(x, 0.02, BAY_Z.y - 0.6)
	words.rotation = Vector3(-PI * 0.5, 0, 0)
	root.add_child(words)
	var sign_at := Vector3(x - 1.2, 4.6, -23.85)
	_part(PartShapes.box(Vector3(4.2, 0.5, 0.06)).mesh, sign_at, _mats["dark"], root)
	var plate := _plate("LINE %s INTAKE" % line_id.to_upper(), Color(0.95, 0.75, 0.1))
	plate.position = sign_at + Vector3(0, 0, 0.04)
	plate.font_size = 72
	root.add_child(plate)


## The end of the line: the trolley's stand painted on the floor round it and the screen
## on a post that sends it to the stores.
func _build_end() -> void:
	var root := Node3D.new()
	root.name = "LineEnd"
	root.add_to_group("gfx_interactable")
	root.set_meta("gfx_id", "line:%s:end" % line_id)
	add_child(root)
	var x := float(LINES[line_id])
	var from := LINE_END_Z + 0.3
	var to := 21.2
	for k: float in [-1.0, 1.0]:
		_part(PartShapes.box(Vector3(0.12, 0.01, to - from)).mesh, Vector3(x + k * 2.1, 0.006, (from + to) * 0.5), _mats["yellow"], root)
	_part(PartShapes.box(Vector3(4.3, 0.01, 0.12)).mesh, Vector3(x, 0.006, to), _mats["yellow"], root)
	var post := Vector3(x - WIDTH * SCALE.x * 0.5 - 0.6, 0, LINE_END_Z - 0.6)
	_part(PartShapes.box(Vector3(0.12, 1.1, 0.12)).mesh, post + Vector3(0, 0.55, 0), _mats["dark"], root)
	var face := Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, -0.35)
	_part(PartShapes.chamfer_box(Vector3(0.66, 0.46, 0.06), 0.015).mesh, post + Vector3(0, 1.25, 0), _mats["dark"], root, face)
	end_screen = Touch.new()
	end_screen.name = "Screen"
	end_screen.transform = Transform3D(face, post + Vector3(0, 1.25, 0) + face * Vector3(0, 0, 0.04))
	root.add_child(end_screen)
	end_screen.call("setup", Vector2(0.62, 0.42), "LINE %s TROLLEY" % line_id.to_upper(), 2)
	end_screen.call("add_button", "send", "SEND TO STORES", send_trolley, true)
	end_screen.call("add_button", "auto", "AUTO", toggle_auto)


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


static func _paint(colour: Color, metallic: float, roughness: float, finish: String) -> Material:
	return ShipSurface.of(ShipKit.paint(colour, metallic, roughness, finish))


## A drop-off zone painted on the floor where a trolley sets goods down (beenster, 0.3.15:
## paint the floor, no pallets): a filled patch `size` (x, z) metres with a bolder edge, corner
## marks and its name across the front.
func _drop_zone(at: Vector3, size: Vector2, fill: Material, edge: Material, text: String, colour: Color, parent: Node3D) -> void:
	_part(PartShapes.box(Vector3(size.x, 0.003, size.y)).mesh, at + Vector3(0, 0.032, 0), fill, parent)
	for k: float in [-1.0, 1.0]:
		_part(PartShapes.box(Vector3(size.x, 0.003, 0.08)).mesh, at + Vector3(0, 0.036, k * (size.y * 0.5 - 0.04)), edge, parent)
		_part(PartShapes.box(Vector3(0.08, 0.003, size.y - 0.16)).mesh, at + Vector3(k * (size.x * 0.5 - 0.04), 0.0365, 0), edge, parent)
		for j: float in [-1.0, 1.0]:
			# Corner marks: short bars just inside each corner.
			var c := at + Vector3(k * (size.x * 0.5 - 0.3), 0.041, j * (size.y * 0.5 - 0.17))
			_part(PartShapes.box(Vector3(0.4, 0.003, 0.06)).mesh, c, edge, parent)
	var words := _plate(text, colour)
	words.font_size = 64
	words.position = at + Vector3(0, 0.046, size.y * 0.5 - 0.32)
	words.rotation = Vector3(-PI * 0.5, 0, 0)
	parent.add_child(words)


func _part(mesh: Mesh, at: Vector3, mat: Material, parent: Node3D = null, basis := Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, at)
	(parent if parent else self).add_child(mi)
	return mi


## A collision box on a machine's (unscaled) body: `size` and `at` in its scaled frame's
## terms, or in its own when `framed` is off.
func _collide(body: StaticBody3D, size: Vector3, at: Vector3, framed := true) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size * SCALE if framed else size
	col.shape = box
	col.position = at * SCALE if framed else at
	body.add_child(col)
