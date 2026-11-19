class_name MotionBus
extends Node
## The moving parts module's bus (Modules.bus("motion")): tests a design's moving parts
## (beenster, 19 Nov: "How can we test things like cargo doors, under carriage, feet, other
## major moving parts?"). Every door, ramp, hatch, leg, crane, turret and lift in the open
## design gets its motion (MotionTable), its swept volume and its clashes (MotionCheck) and the
## ship a "set her down" ground check on her legs (MotionGround). Clashes and ground problems
## go on the design's WILL IT WORK list; OPERATE on the console plays every moving part on the
## holotable (and at full size in walk-inside), its swept volume glowing and clashes red; SET
## HER DOWN stands her on a pad. Both are shared with the crew.
##
##   var bus := Modules.bus("motion") as MotionBus
##   bus.report()      # {movers, clashes, ground, openings} for the open design, kept per edit
##   bus.operating     # OPERATE is on (everyone sees it)
##   bus.set_operating(on)
##   bus.grounded      # SET HER DOWN is on; bus.pad ("flat" | "rough"), bus.full_hold
##   bus.cycle(rec)    # a surveyor's cycle of every moving part (Wave 4 trial): a report
##
## Features (Flags): "motion" (the module: checks on WILL IT WORK), "motion.operate" (OPERATE
## on the console and the holotable), "motion.ground" (SET HER DOWN), "motion.walk" (OPERATE
## in walk-inside), "motion.wall" (the MOVING PARTS wall panel).

signal operate_changed
signal report_changed

const OPERATE_FLAG := "motion.operate"
const GROUND_FLAG := "motion.ground"
const WALK_FLAG := "motion.walk"
const WALL_FLAG := "motion.wall"
const WALL_VIEW := "motion"
const CHECK_ID := "motion"

const HoloOperate := preload("res://modules/motion/internal/holo_operate.gd")
const WalkOperate := preload("res://modules/motion/internal/walk_operate.gd")
const MotionWall := preload("res://modules/motion/internal/motion_wall.gd")

## Test blocks carried through the openings (w x h x length, m): what a crew would move.
const BLOCKS := [
	{"id": "crate", "name": "Crate", "size": Vector3(1.2, 1.2, 1.2)},
	{"id": "pallet", "name": "Loaded pallet", "size": Vector3(1.2, 1.6, 1.0)},
	{"id": "engine", "name": "Engine pod", "size": Vector3(2.2, 2.2, 3.0)},
	{"id": "container", "name": "Container", "size": Vector3(2.44, 2.59, 6.06)},
]

var operating := false
## When OPERATE was pressed (msec, this machine's clock): every part starts stowed then.
var started_msec := 0
var grounded := false
var pad := "flat"
var full_hold := true

var _design: DesignBus
var _net: Object
var _report: Dictionary = {}
var _report_of: DesignRecord


func register_module() -> void:
	if Modules.ready_done:
		_hook_up()
	else:
		Modules.modules_ready.connect(_hook_up, CONNECT_ONE_SHOT)


func _hook_up() -> void:
	_design = Modules.bus("design") as DesignBus
	if _design == null:
		return
	_design.design_changed.connect(_on_design_changed)
	_design.register_check(CHECK_ID, _check)
	if Flags.is_on(OPERATE_FLAG):
		_design.register_console_tool("motion.operate", "OPERATE", func() -> void: set_operating(not operating),
				"Play every door, ramp, hatch, leg, crane and turret on the holotable, their swept volume glowing, clashes red", 10)
		_design.holo_built.connect(_on_holo_built)
	if Flags.is_on(GROUND_FLAG):
		_design.register_console_tool("motion.ground", "SET HER DOWN", func() -> void: set_grounded(not grounded),
				"Stand her on a landing pad on her legs: level, load per foot, clearance, tipping", 11)
	if Flags.is_on(WALK_FLAG):
		_design.walk_built.connect(_on_walk_built)
	if Flags.is_on(WALL_FLAG):
		_design.register_wall_view(WALL_VIEW, "MOVING PARTS", make_wall)
	hook_net(Modules.bus("multiplayer"))


func unregister_module() -> void:
	_unhook_net()
	if _design == null:
		return
	_design.unregister_check(CHECK_ID)
	_design.unregister_console_tool("motion.operate")
	_design.unregister_console_tool("motion.ground")
	_design.unregister_wall_view(WALL_VIEW)
	if _design.design_changed.is_connected(_on_design_changed):
		_design.design_changed.disconnect(_on_design_changed)
	if _design.holo_built.is_connected(_on_holo_built):
		_design.holo_built.disconnect(_on_holo_built)
	if _design.walk_built.is_connected(_on_walk_built):
		_design.walk_built.disconnect(_on_walk_built)


func design() -> DesignBus:
	return _design


func _on_design_changed() -> void:
	_report = {}
	_report_of = null
	report_changed.emit()


## WILL IT WORK's share: the clashes and the ground check of the design being checked.
func _check(rec: DesignRecord, cat: DesignCatalog, totals: DesignTotals) -> Array:
	var r := report_for(rec, cat, totals)
	var out: Array = []
	out.append_array(r.get("problems", []))
	return out


## The open design's report, kept till the next edit.
func report() -> Dictionary:
	if _design == null or _design.library.current == null:
		return {}
	return report_for(_design.library.current, _design.catalog, _design.totals())


func report_for(rec: DesignRecord, cat: DesignCatalog, totals: DesignTotals) -> Dictionary:
	if rec == null:
		return {}
	if _report_of == rec and not _report.is_empty():
		return _report
	var r := build_report(rec, cat, totals)
	if _design and rec == _design.library.current:
		_report = r
		_report_of = rec
	return r


## Everything about a design's moving parts: {movers, clashes, ground, openings, problems}.
static func build_report(rec: DesignRecord, cat: DesignCatalog, totals: DesignTotals) -> Dictionary:
	var movers := MotionMovers.list(rec, cat)
	var clashes := MotionCheck.clashes(rec, cat, movers)
	var ground := MotionGround.check(rec, cat, totals, movers)
	var problems: Array[Dictionary] = MotionCheck.problems(rec, cat, clashes)
	problems.append_array(ground.problems)
	return {"movers": movers, "clashes": clashes, "ground": ground, "openings": openings(movers), "problems": problems}


## What each opening lets through (the test blocks, BLOCKS): [{id, name, open: Vector2,
## fits: {block id -> bool}}], widest first.
static func openings(movers: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mv in movers:
		var o: Vector2 = mv.spec.get("open", Vector2.ZERO)
		if o.x <= 0.0 or o.y <= 0.0:
			continue
		var fits := {}
		for b: Dictionary in BLOCKS:
			var s: Vector3 = b.size
			# Through square on, or on its side when that fits better.
			fits[b.id] = (s.x <= o.x - 0.05 and s.y <= o.y - 0.05) or (s.y <= o.x - 0.05 and s.x <= o.y - 0.05)
		out.append({"id": mv.id, "name": mv.name, "open": o, "fits": fits})
	out.sort_custom(func(a, b) -> bool: return a.open.x * a.open.y > b.open.x * b.open.y)
	return out


## Where a mover is in its move now (0 stowed .. 1 deployed): stowed, out over its seconds,
## a hold, back, a hold, round again. With SET HER DOWN on, legs stay down.
func phase_of(mv: Dictionary, now_msec: int = -1) -> float:
	var kind := str(mv.spec.kind)
	if grounded and kind == "leg":
		return 1.0
	if not operating:
		return 0.0
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()
	return cycle_phase(float(mv.spec.get("seconds", 2.0)), (now_msec - started_msec) / 1000.0)


## The loop every moving part plays: out over `seconds`, hold 1 s, back, hold 1 s.
static func cycle_phase(seconds: float, elapsed: float) -> float:
	var s := maxf(seconds, 0.5)
	var loop := s * 2.0 + 2.0
	var at := fposmod(elapsed, loop)
	if at < s:
		return smoothstep(0.0, 1.0, at / s)
	if at < s + 1.0:
		return 1.0
	if at < s * 2.0 + 1.0:
		return 1.0 - smoothstep(0.0, 1.0, (at - s - 1.0) / s)
	return 0.0


## A surveyor's cycle of every moving part (the Wave 4 trial): each one run out and back,
## with its time, power, load and whether it moved clear: [{id, name, kind, seconds, kw,
## load_kg, open, clear, notes: [text]}], and the ground check's cases.
func cycle(rec: DesignRecord = null) -> Dictionary:
	if rec == null and _design:
		rec = _design.library.current
	if rec == null:
		return {}
	var r := report_for(rec, _design.catalog, _design.totals() if rec == _design.library.current else null)
	var rows: Array[Dictionary] = []
	for mv: Dictionary in r.movers:
		var notes: Array = []
		for c: Dictionary in r.clashes.get(mv.id, []):
			notes.append(c.text)
		rows.append({"id": mv.id, "name": mv.name, "kind": str(mv.spec.kind), "seconds": float(mv.spec.get("seconds", 0.0)),
				"kw": float(mv.spec.get("kw", 0.0)), "load_kg": float(mv.spec.get("load_kg", 0.0)),
				"open": mv.spec.get("open", Vector2.ZERO), "clear": notes.is_empty(), "notes": notes})
	return {"parts": rows, "ground": r.ground}


# Shared with the crew: OPERATE and SET HER DOWN pressed by anyone play for everyone.

func hook_net(net: Object) -> void:
	if net == null or not net.has_method("register_event"):
		return
	_unhook_net()
	_net = net
	_net.call("register_event", "motion.state", _apply_state)
	if _net.has_method("register_snapshot_provider"):
		_net.call("register_snapshot_provider", "motion", self)


func _unhook_net() -> void:
	if _net == null:
		return
	_net.call("unregister_event", "motion.state")
	if _net.has_method("unregister_snapshot_provider"):
		_net.call("unregister_snapshot_provider", "motion")
	_net = null


func set_operating(on: bool) -> void:
	_send({"operating": on, "grounded": grounded, "pad": pad, "full": full_hold})


func set_grounded(on: bool) -> void:
	_send({"operating": operating, "grounded": on, "pad": pad, "full": full_hold})


func set_pad(which: String, full: bool) -> void:
	_send({"operating": operating, "grounded": grounded, "pad": which, "full": full})


func _send(p: Dictionary) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", "motion.state", p)
	else:
		_apply_state(p)


func _apply_state(p: Dictionary) -> void:
	var on := bool(p.get("operating", false))
	if on and not operating:
		started_msec = Time.get_ticks_msec()
	operating = on
	grounded = bool(p.get("grounded", false))
	pad = str(p.get("pad", "flat")) if str(p.get("pad", "flat")) in MotionGround.PADS else "flat"
	full_hold = bool(p.get("full", true))
	operate_changed.emit()


func get_net_snapshot() -> Dictionary:
	return {"operating": operating, "grounded": grounded, "pad": pad, "full": full_hold}


func apply_net_snapshot(data: Dictionary) -> void:
	_apply_state(data)


# Views

func _on_holo_built(table: Node3D, ship: Node3D) -> void:
	var v: Node3D = HoloOperate.new()
	v.name = "MotionOperate"
	ship.add_child(v)
	v.call("setup", self, table)


func _on_walk_built(root: Node3D, _builder: Object) -> void:
	var old := root.get_node_or_null("MotionWalk")
	if old:
		root.remove_child(old)
		old.queue_free()
	var v: Node3D = WalkOperate.new()
	v.name = "MotionWalk"
	root.add_child(v)
	v.call("setup", self)


## The MOVING PARTS wall panel.
func make_wall(px_per_m: float) -> Control:
	var w: Control = MotionWall.new()
	w.call("setup", self, px_per_m)
	return w
