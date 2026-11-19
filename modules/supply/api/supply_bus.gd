class_name SupplyBus
extends Node
## The parts market module's bus (Modules.bus("supply")): the vendors who sell ship parts,
## the company's standing with each, the market day, and the parts market screen offered to
## the design room's walls (beenster, 19 Nov: "a new parts list screen should be viewable from
## the main walls").
##
##   var bus := Modules.bus("supply") as SupplyBus
##   bus.vendors                    # Array[SupplyVendor]
##   bus.day                        # the market day (prices, deals and history follow it)
##   bus.standing_of("orbis")       # 0-100
##   bus.optimiser()                # SupplyOptimiser for the open design (kept per edit and day)
##
## Features (Flags): "supply" (the module), "supply.wall" (the PARTS MARKET wall panel).

signal day_changed(day: int)
signal standing_changed(vendor_id: String, standing: float)
## The optimiser ran again (after an edit, a new day or a change of standing).
signal optimised

const SAVE_SECTION := "supply"
const SAVE_VERSION := 1
const WALL_FLAG := "supply.wall"
const WALL_VIEW := "market"
## The wrist screen's channel (HudSlots) showing the same panel.
const HOLO_CHANNEL := "supply.market"
const VENDORS_DIR := "res://modules/supply/internal/data/vendors"
const MarketScreen := preload("res://modules/supply/internal/market_screen.gd")
## A new game's first market day (history reaches back from it, so it starts past it).
const START_DAY := 400

var vendors: Array[SupplyVendor] = []
var day := START_DAY
## vendor id -> standing (0-100); a vendor missing here is at its standing_start.
var standing: Dictionary = {}
## What the optimiser last ran after ("added Fusion reactor", "day 401"), and when (msec).
var last_reason := ""
var last_run_msec := 0
var last_run_cost_msec := 0.0

var _design: DesignBus
var _opt: SupplyOptimiser
var _opt_key := ""


func _init() -> void:
	vendors = load_vendors()


static func load_vendors() -> Array[SupplyVendor]:
	var out: Array[SupplyVendor] = []
	var names := Array(ResourceLoader.list_directory(VENDORS_DIR))
	names.sort()
	for f: String in names:
		if f.ends_with(".tres") or f.ends_with(".tres.remap"):
			var v := load(VENDORS_DIR.path_join(f.trim_suffix(".remap"))) as SupplyVendor
			if v:
				out.append(v)
	return out


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, self)
	if Modules.ready_done:
		_hook_up()
	else:
		Modules.modules_ready.connect(_hook_up, CONNECT_ONE_SHOT)


func _hook_up() -> void:
	_design = Modules.bus("design") as DesignBus
	if _design == null:
		return
	if Flags.is_on(WALL_FLAG):
		_design.register_wall_view(WALL_VIEW, "PARTS MARKET", make_screen)
		# The same screen on the wrist (F1), after the warehouse stock.
		HudSlots.register_holo_channel(HOLO_CHANNEL, "Parts market",
				func(_glass: bool) -> Control: return make_screen(150.0), 20)
	_design.design_changed.connect(_on_design_changed)
	# The business day, where the business module runs one (reached by name: it is optional).
	var business := Modules.bus("business")
	if business and business.has_signal("day_closed"):
		business.connect("day_closed", func(_d: int) -> void: advance_day())


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)
	HudSlots.unregister_holo_channel(HOLO_CHANNEL)
	if _design:
		_design.unregister_wall_view(WALL_VIEW)
		if _design.design_changed.is_connected(_on_design_changed):
			_design.design_changed.disconnect(_on_design_changed)


## The wall panel (DesignBus.register_wall_view): px_per_m sizes its text.
func make_screen(px_per_m: float) -> Control:
	var s := MarketScreen.new()
	s.setup(self, px_per_m)
	return s


func vendor(id: String) -> SupplyVendor:
	for v in vendors:
		if v.id == id:
			return v
	return null


func standing_of(id: String) -> float:
	var v := vendor(id)
	return float(standing.get(id, v.standing_start if v else 0))


func set_standing(id: String, value: float) -> void:
	standing[id] = clampf(value, 0.0, 100.0)
	_opt_key = ""
	last_reason = "standing with %s" % (vendor(id).display_name if vendor(id) else id)
	standing_changed.emit(id, standing[id])


func advance_day(by := 1) -> void:
	day += by
	_opt_key = ""
	last_reason = "market day %d" % day
	day_changed.emit(day)


func catalog() -> DesignCatalog:
	return _design.catalog if _design else null


## The open design's parts list as lines to buy.
func lines() -> Array[Dictionary]:
	if _design == null or _design.library.current == null:
		return []
	return SupplyMarket.buy_lines(_design.totals(), catalog())


## The optimiser for the open design today, run again only after something changed.
func optimiser() -> SupplyOptimiser:
	var rec: DesignRecord = _design.library.current if _design else null
	var key := "%s|%d|%d" % [str(rec.get_instance_id()) if rec else "-", day, _edits]
	if _opt == null or key != _opt_key:
		var t0 := Time.get_ticks_usec()
		_opt = SupplyOptimiser.run(lines(), vendors, _standing_all(), day, catalog())
		_opt_key = key
		last_run_msec = Time.get_ticks_msec()
		last_run_cost_msec = (Time.get_ticks_usec() - t0) / 1000.0
		optimised.emit()
	return _opt


var _edits := 0


func _on_design_changed() -> void:
	_edits += 1
	last_reason = "design edited"


func _standing_all() -> Dictionary:
	var out := {}
	for v in vendors:
		out[v.id] = standing_of(v.id)
	return out


# Saves: the market day and the standing with each vendor.

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	return {"day": day, "standing": standing.duplicate()}


func load_data(data: Dictionary, _from_version: int) -> void:
	day = int(data.get("day", START_DAY))
	standing = (data.get("standing", {}) as Dictionary).duplicate()
	_opt_key = ""
	day_changed.emit(day)


func reset_data() -> void:
	load_data({}, SAVE_VERSION)
