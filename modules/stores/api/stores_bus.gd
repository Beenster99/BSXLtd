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
## The racks hold the company's stock (beenster, 20 Nov: "make the warehouse actually reflect
## the company stockholding"): with "stores.company_stock" on, the business books are the stock
## and the host keeps the racks to them (CompanyStock): a fresh yard starts its racks from the
## books, parts the books gain are delivered and put away, parts they lose are taken out, and
## parts the yard uses or takes in go into the books. A new company starts with an opening
## stock (the racks' old demo stock) in its books. Its save section remembers that it has had it.
##
## Flags: "stores" (the module), "stores.wall" (the wrist channel and the wall panel),
## "stores.company_stock" (the racks follow the company's books).

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
const CompanyStock := preload("res://modules/stores/internal/company_stock.gd")
const COMPANY_FLAG := "stores.company_stock"
const SAVE_SECTION := "stores"
## How often the host lines the yard's orders up with the books (s).
const SYNC_SECONDS := 0.5

## The racks kept to the books (host), while "stores.company_stock" is on.
var company: CompanyStock
## True once this company has had its opening stock put in its books (saved).
var opening_given := false
var _section_loaded := false
var _sync_wait := 0.0

var _yard: YardBus
var _design: DesignBus
var _preview: YardRackStore
var _bound: YardRackStore
var _report: StoresReport
var _dirty := true


func register_module() -> void:
	if Flags.is_on(COMPANY_FLAG):
		company = CompanyStock.new()
		Saves.register_section(SAVE_SECTION, self)
		if not Saves.loaded.is_connected(_on_game_loaded):
			Saves.loaded.connect(_on_game_loaded)
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
	if company:
		company.business = Modules.bus("business")
		company.yard = _yard
		if _yard and company.business and company.business.has_method("get_stock"):
			_yard.stock_source = _starting_stock
	_bind()


func unregister_module() -> void:
	if company:
		company.unbind()
		Saves.unregister_section(SAVE_SECTION)
		if Saves.loaded.is_connected(_on_game_loaded):
			Saves.loaded.disconnect(_on_game_loaded)
		if _yard and _yard.stock_source == _starting_stock:
			_yard.stock_source = Callable()
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
		if _keeps_books():
			_preview.set_stock(company_parts())
		else:
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


# --- The company's stock on the racks ------------------------------------------------------

## True while the racks follow the books (the flag on and a business module to keep them).
func _keeps_books() -> bool:
	return company != null and company.business != null and company.business.has_method("get_stock")


## What the racks should hold now: the books' stock of rack parts, or, for a company that has
## not had its opening stock yet, that stock.
func company_parts() -> Dictionary:
	if company == null:
		return {}
	if not opening_given:
		var parts := company.books()
		var opening := CompanyStock.opening_stock()
		for p: String in opening:
			parts[p] = int(parts.get(p, 0)) + int(opening[p])
		return parts
	return company.books()


## YardBus.stock_source (host, a fresh yard clock): the opening stock goes into the books if it
## hasn't yet, and the racks start from the books.
func _starting_stock() -> Dictionary:
	if not _keeps_books():
		return {}
	give_opening_stock()
	var parts := company.books()
	company.start(parts)
	return parts


## A new company's opening stock goes into its books, once (host).
func give_opening_stock() -> void:
	if opening_given or not _keeps_books() or not _is_host():
		return
	opening_given = true
	var opening := CompanyStock.opening_stock()
	var ids := opening.keys()
	ids.sort()
	for p: String in ids:
		company.business.call("add_stock", p, int(opening[p]), "new", "opening stock")
	_preview = null
	_mark()


func _process(delta: float) -> void:
	if company == null or company.store == null or not _is_host():
		return
	_sync_wait -= delta
	if _sync_wait > 0.0:
		return
	_sync_wait = SYNC_SECONDS
	if _yard and _yard.station() and _yard.sim_epoch >= 0.0:
		company.sync()


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


# --- Saves provider ----------------------------------------------------------------------------

func save_version() -> int:
	return 1


func save_data() -> Dictionary:
	return {"opening_given": opening_given}


func load_data(data: Dictionary, _from_version: int) -> void:
	_section_loaded = true
	opening_given = bool(data.get("opening_given", false))
	_preview = null


func reset_data() -> void:
	opening_given = false
	_preview = null


## A game saved before this section existed had no opening stock: it gets it.
func _on_game_loaded(_slot: String) -> void:
	if not _section_loaded:
		opening_given = false
	_section_loaded = false
	_preview = null


func _bind() -> void:
	var s: YardRackStore = _yard.rack_store if _yard else null
	if company:
		if s and _is_host() and _keeps_books():
			# A yard the crew already had open replays its log up to now: that is old news.
			company.bind(s, int(_yard.sim_target_tick()))
		else:
			company.unbind()
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
