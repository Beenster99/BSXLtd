class_name StoresBus
extends Node
## Warehouse stock module bus (Modules.bus("stores")): the detailed screen of what the
## stores hall holds (beenster, 19 Nov: "a new detailed screen should show the current
## stockholding in the warehouses"). One screen, two places: a wrist channel (F1, first tab)
## and a panel the design room's walls can show (DesignBus.register_wall_view "stock").
##
## It reads the yard's racks (YardBus.rack_store, the same on every machine) and, for unit
## costs, masses and what the open design needs, the design catalogue and totals. Before a
## station is open it shows the stock every yard starts with, marked PREVIEW.
##
## Flags: "stores" (the module), "stores.wall" (the wrist channel and the wall panel).

signal report_changed

const FLAG := "stores"
const WALL_FLAG := "stores.wall"
const WALL_VIEW := "stock"
const WALL_TITLE := "WAREHOUSE STOCK"
const HOLO_CHANNEL := "stores.stock"
const HOLO_LABEL := "Warehouse stock"
const HOLO_ORDER := 10
## The wrist builds the screen as a wall drawn at this many px per metre (base text 15 px),
## as the other wall screens on the wrist do.
const WRIST_PX := 150.0
const StockScreen := preload("res://modules/stores/internal/stock_screen.gd")

var _yard: YardBus
var _design: DesignBus
var _preview: YardRackStore
var _bound: YardRackStore
var _report: StoresReport
var _dirty := true


func register_module() -> void:
	if Flags.is_on(WALL_FLAG):
		HudSlots.register_holo_channel(HOLO_CHANNEL, HOLO_LABEL,
				func(_glass: bool) -> Control: return make_screen(WRIST_PX), HOLO_ORDER)
	if Modules.ready_done:
		_hook_up()
	else:
		Modules.modules_ready.connect(_hook_up, CONNECT_ONE_SHOT)


func _hook_up() -> void:
	_yard = Modules.bus("yard") as YardBus
	_design = Modules.bus("design") as DesignBus
	if _design:
		if Flags.is_on(WALL_FLAG) and _design.has_method("register_wall_view"):
			_design.call("register_wall_view", WALL_VIEW, WALL_TITLE, make_screen)
		if not _design.design_changed.is_connected(_mark):
			_design.design_changed.connect(_mark)
	if _yard and not _yard.station_ready.is_connected(_on_station):
		_yard.station_ready.connect(_on_station)
	_bind()


func unregister_module() -> void:
	HudSlots.unregister_holo_channel(HOLO_CHANNEL)
	if _design:
		if _design.has_method("unregister_wall_view"):
			_design.call("unregister_wall_view", WALL_VIEW)
		if _design.design_changed.is_connected(_mark):
			_design.design_changed.disconnect(_mark)
	if _yard and _yard.station_ready.is_connected(_on_station):
		_yard.station_ready.disconnect(_on_station)
	_unbind()


## The screen, built for a wall drawn at px_per_m (the wrist uses WRIST_PX).
func make_screen(px_per_m: float) -> Control:
	var s := StockScreen.new()
	s.setup(self, px_per_m)
	return s


## The racks the screen reads: the open yard's, else the stock a yard starts with.
func store() -> YardRackStore:
	if _yard and _yard.rack_store:
		if _bound != _yard.rack_store:
			_bind()
		return _yard.rack_store
	if _preview == null:
		_preview = YardRackStore.new()
		_preview.fill_demo()
	return _preview


## True while the screen shows the starting stock, not a yard's.
func is_preview() -> bool:
	return not (_yard and _yard.rack_store)


## The report for now (built again after any change to the racks or the open design).
func report() -> StoresReport:
	var s := store()
	if _dirty or _report == null:
		_dirty = false
		var rec: DesignRecord = _design.library.current if _design else null
		_report = StoresReport.build(s, _design.catalog if _design else null,
				_design.totals() if _design and rec else null, rec.name if rec else "")
	return _report


func _bind() -> void:
	var s: YardRackStore = _yard.rack_store if _yard else null
	if s == _bound:
		return
	_unbind()
	_bound = s
	if _bound:
		_bound.changed.connect(_on_slot)
	_mark()


func _unbind() -> void:
	if _bound and _bound.changed.is_connected(_on_slot):
		_bound.changed.disconnect(_on_slot)
	_bound = null


func _on_station(_s: Node3D) -> void:
	_bind.call_deferred()


func _on_slot(_i: int) -> void:
	_mark()


func _mark() -> void:
	_dirty = true
	report_changed.emit()
