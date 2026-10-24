class_name ContractsBus
extends Node
## Contracts module bus (Modules.bus("contracts")). Work order import, as-built export, and the active job's blueprint, spec sheet and parts manifest.
## Other modules use this module only through this folder: signals here, and resource
## classes placed next to it. Everything else lives in internal/.
##
## Only the host imports files and changes jobs; Multiplayer replays these signals to the
## other players. File formats and job states: the Contracts module spec.

signal contract_imported(job_id: String)
## errors: lines the foreman can read on the planning table.
signal import_failed(path: String, errors: PackedStringArray)
signal active_job_changed(job_id: String)
signal job_state_changed(job_id: String, from_state: String, to_state: String)
signal change_status_changed(job_id: String, change_id: String, status: String)
signal variation_raised(job_id: String, variation: Dictionary)
signal as_built_exported(job_id: String, path: String)
## Convenience signals for Business and Progression, fired alongside job_state_changed.
## value is the contract price; due_day is the game day it is due (commercial.due_day in
## the work order), or NO_DUE_DAY when it has none.
signal contract_accepted(contract_id: String, value: int, due_day: int)
## quality is the mean install quality, 0 to 1.
signal contract_handed_over(contract_id: String, quality: float, open_snags: int)
signal contract_cancelled(contract_id: String, by_client: bool)
signal job_closed(job_id: String)
## The scrapyard loop (plan stage S1). A non-fit job's subject is on its way once the job
## is accepted: Ship and Bay lands it (a part on a delivery trolley at the bench, later a
## hulk on the apron) and calls subject_landed(). subject: {type ("part", "ship", "wreck"),
## component ({id, material}, for a part), condition (0 to 1), mass_kg, design}.
signal subject_due(job_id: String, subject: Dictionary)
## Something came out of a job's subject (record_recovery / record_scrap): Business and
## Progression read job.recoveries. line: the recovery as appended to it.
signal recovery_recorded(job_id: String, line: Dictionary)
## Clients and standing (plan stage S4). standing_changed fires when points move; level is
## 0 (new) to 3 (preferred), see ContractClients.LEVEL_NAMES. offer_expired: a generated
## offer left the board untaken. cycle_advanced: new offers were posted for a cycle.
signal standing_changed(client_id: String, points: int, level: int)
signal offer_expired(job_id: String)
signal cycle_advanced(cycle: int)

const SAVE_VERSION := 1
const NO_DUE_DAY := 1_000_000

const Reader := preload("res://modules/contracts/internal/work_order_reader.gd")
const Writer := preload("res://modules/contracts/internal/as_built_writer.gd")
const Store := preload("res://modules/contracts/internal/job_store.gd")
const BoardPanel := preload("res://modules/contracts/internal/board_panel.gd")
const Generator := preload("res://modules/contracts/internal/offer_generator.gd")
## Work orders on offer when a game starts: Void Salvage crews' and local yards' jobs.
const BOARD_DIR := "res://modules/contracts/data/board"
const BOARD_CHANNEL := "contracts.board"
## Break, scrap, refurbish and dispose jobs (plan stage S1); off, the board offers fit jobs only.
const KINDS_FLAG := "contracts.kinds"
## Clients post offers each cycle and standing with them unlocks tiers (plan stage S4).
const CLIENTS_FLAG := "contracts.clients"
## BSX's own clients send whole ships and wrecks BSX generates itself (plan stage S3): the
## offer generator makes them with Shared Components' WreckMaker, seeded per offer.
const WRECKS_FLAG := "contracts.wrecks"
## Open generated offers a client keeps on the board at once.
const OFFERS_PER_CLIENT := 2
## The contracts board's tabs (board()).
const VOID_SALVAGE := "void_salvage"
const LOCAL := "local"
const TAKEN := "accepted"

var _jobs: Dictionary = {}
var _active := ""
## Callable(id: String) -> bool, and Callable(id: String) -> Dictionary of library build
## data per joint kind ({bolt: {...}, ...}). Unset, every id is accepted and the spec is the
## work order's overrides alone. Wired to Shared Components once that module is a dependency.
var _component_exists: Callable
var _library_spec: Callable
## client id -> standing points (S4).
var _standing: Dictionary = {}
## The board's cycle: the game day when Business runs the clock (day_closed), else a count
## of advance_cycle() calls.
var _cycle := 0
var _generator := Generator.new()


func register_module() -> void:
	Saves.register_section("contracts", self)
	seed_board()
	if Flags.is_on(BOARD_CHANNEL):
		HudSlots.register_holo_channel(BOARD_CHANNEL, "Contracts",
				func(glass: bool) -> Control: return BoardPanel.new(self, glass), 30)
	if Flags.is_on(CLIENTS_FLAG):
		if not Modules.modules_ready.is_connected(_hook_clock):
			Modules.modules_ready.connect(_hook_clock)
		if _cycle == 0:
			advance_cycle(1)
	if Flags.is_on(DEBUG_FLAG) and Flags.is_on(CLIENTS_FLAG):
		Menu.register_settings_section(Menu.DEBUG, DEBUG_SECTION, "Contracts", _debug_section, 30)
		if not Modules.modules_ready.is_connected(_hook_net):
			Modules.modules_ready.connect(_hook_net)


func unregister_module() -> void:
	Saves.unregister_section("contracts")
	HudSlots.unregister_holo_channel(BOARD_CHANNEL)
	if Modules.modules_ready.is_connected(_hook_clock):
		Modules.modules_ready.disconnect(_hook_clock)
	if Modules.modules_ready.is_connected(_hook_net):
		Modules.modules_ready.disconnect(_hook_net)
	Menu.unregister_settings_section(Menu.DEBUG, DEBUG_SECTION)
	var net := _net()
	if net:
		net.call("unregister_event", DEBUG_EVENT)


## Business runs the day clock when it is on; its day_closed is the board's cycle. Found
## by name once every module has loaded (Business depends on Contracts, so it loads after).
func _hook_clock() -> void:
	var business := Modules.bus("business")
	if business == null or not business.has_signal("day_closed"):
		return
	if not business.is_connected("day_closed", _on_day_closed):
		business.connect("day_closed", _on_day_closed)
	if business.has_method("labour_price"):
		set_pricer(func(kind: String, size: String, t: float) -> int: return int(business.call("labour_price", kind, size, t)))


func _on_day_closed(day: int) -> void:
	advance_cycle(day + 1)


## Callable(kind, size, t) -> int: what a generated offer pays. Business wires its labour
## rules in; unset, the generator's own bands apply.
func set_pricer(pricer: Callable) -> void:
	_generator.pricer = pricer


## Callable(material, kg) -> int: what a scrap job pays BSX by the tonne for cutting and
## baling (plan stage S5). Business wires its rate in; unset, the generator's own applies.
func set_scrap_pricer(pricer: Callable) -> void:
	_generator.scrap_pricer = pricer




func set_component_library(exists: Callable, library_spec: Callable = Callable()) -> void:
	_component_exists = exists
	_library_spec = library_spec


# Import

func import_work_order(path: String) -> ImportResult:
	var result := ImportResult.new()
	if not FileAccess.file_exists(path):
		result.errors.append("No file at %s." % path)
	else:
		result = import_text(FileAccess.get_file_as_string(path))
	if not result.ok():
		import_failed.emit(path, result.errors)
	return result


## Reads a work order from JSON text (the file picker and tests use this through
## import_work_order; Multiplayer may pass text received from the host).
func import_text(text: String) -> ImportResult:
	var result := ImportResult.new()
	var reader := Reader.new()
	reader.component_exists = _component_exists
	var order := reader.read_text(text)
	if order == null:
		result.errors = reader.errors
		return result
	if _jobs.has(order.contract_id):
		result.errors.append("Contract %s is already in the bay." % order.contract_id)
		return result
	var job := ContractJob.new()
	job.job_id = order.contract_id
	job.order = order
	for c in order.changes:
		job.change_status[c.change_id] = ChangeItem.PENDING
	_jobs[job.job_id] = job
	result.job_id = job.job_id
	contract_imported.emit(job.job_id)
	if _active == "":
		set_active_job(job.job_id)
	return result


# Reading jobs

func get_job(job_id: String) -> ContractJob:
	return _jobs.get(job_id)


func get_active_job() -> ContractJob:
	return _jobs.get(_active)


func job_ids() -> PackedStringArray:
	return PackedStringArray(_jobs.keys())


func set_active_job(job_id: String) -> void:
	if job_id != "" and not _jobs.has(job_id):
		return
	if job_id == _active:
		return
	_active = job_id
	active_job_changed.emit(job_id)


## What a change must meet: its part's library build data with the work order's overrides
## on top. Null for an unknown job or change.
func get_spec(job_id: String, change_id: String) -> SpecEntry:
	var job := get_job(job_id)
	var c := job.order.change(change_id) if job else null
	if c == null:
		return null
	var spec := SpecEntry.new()
	spec.change_id = change_id
	spec.component = c.install if c.install else c.remove
	if job.order.use_library and _library_spec.is_valid() and spec.component:
		spec.apply(_library_spec.call(spec.component.id))
	spec.apply(job.order.overrides.get(change_id, {}))
	return spec


## The job pack: every document that comes with a job (ContractJobPack), for the board,
## the wrist Specs channel and Quality. Empty for an unknown job.
func job_pack(job_id: String) -> Array[Dictionary]:
	var job := get_job(job_id)
	if job == null:
		return []
	return ContractJobPack.documents(job, get_spec)


## One document of a job's pack by id ("order", "spec:c1", "spec:subject", "wants",
## "manifest", "hazards", "notes", "progress"), or {}.
func document(job_id: String, doc_id: String) -> Dictionary:
	var job := get_job(job_id)
	if job == null:
		return {}
	return ContractJobPack.document(job, doc_id, get_spec)


## The contracts board: offered Void Salvage jobs (VOID_SALVAGE), offered local yard jobs
## (LOCAL), or jobs taken on and not yet handed over (TAKEN). Void Salvage first, then by
## due day.
func board(tab: String) -> Array[ContractJob]:
	var out: Array[ContractJob] = []
	for job: ContractJob in _jobs.values():
		var vs := String(job.order.client.get("game", "")) == "void_salvage"
		var offered := job.state == ContractJob.OFFERED
		var taken := not offered and not job.state in [ContractJob.HANDED_OVER, ContractJob.CLOSED,
				ContractJob.DECLINED, ContractJob.CANCELLED]
		if (tab == VOID_SALVAGE and offered and vs) or (tab == LOCAL and offered and not vs) \
				or (tab == TAKEN and taken):
			out.append(job)
	out.sort_custom(func(a: ContractJob, b: ContractJob) -> bool:
		var av := String(a.order.client.get("game", "")) == "void_salvage"
		var bv := String(b.order.client.get("game", "")) == "void_salvage"
		if av != bv:
			return av
		var ad := int(a.order.commercial.get("due_day", NO_DUE_DAY))
		var bd := int(b.order.commercial.get("due_day", NO_DUE_DAY))
		return ad < bd if ad != bd else a.job_id < b.job_id)
	return out


## Puts the bundled work orders (BOARD_DIR) on offer, skipping any the company already has
## in any state, so a declined or finished job never comes back. Host only.
func seed_board() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	for file in DirAccess.get_files_at(BOARD_DIR):
		if not file.ends_with(".workorder.json"):
			continue
		var text := FileAccess.get_file_as_string(BOARD_DIR.path_join(file))
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and _jobs.has(String(parsed.get("contract_id", ""))):
			continue
		if parsed is Dictionary and String(parsed.get("kind", WorkOrder.FIT)) != WorkOrder.FIT \
				and not Flags.is_on(KINDS_FLAG):
			continue
		var result := import_text(text)
		if not result.ok():
			push_warning("Contracts: board offer %s: %s" % [file, "; ".join(result.errors)])


## The board's ACCEPT JOB: takes an offered job on, and makes it the active job if there
## is none. A non-fit job's subject sets off at once: the job goes to arriving and
## subject_due tells Ship and Bay what to land.
func accept(job_id: String) -> bool:
	if not advance(job_id, ContractJob.ACCEPTED):
		return false
	if get_active_job() == null:
		set_active_job(job_id)
	var job := get_job(job_id)
	if not job.order.is_fit() and advance(job_id, ContractJob.ARRIVING):
		subject_due.emit(job_id, subject_of(job))
	return true


## The subject as Ship and Bay lands it (see subject_due).
static func subject_of(job: ContractJob) -> Dictionary:
	var s := job.order.subject.duplicate()
	if s.get("component") is ComponentRef:
		s["component"] = (s["component"] as ComponentRef).to_dict()
	return s


## Ship and Bay: the job's subject is in the yard (on the bench, in a dock). The job is
## ready to start.
func subject_landed(job_id: String) -> bool:
	var job := get_job(job_id)
	if job == null or job.state != ContractJob.ARRIVING:
		return false
	return advance(job_id, ContractJob.PARTS_READY)


# Clients and standing (S4)

func cycle() -> int:
	return _cycle


func standing_of(client_id: String) -> int:
	return int(_standing.get(client_id, 0))


func level_of(client_id: String) -> int:
	return ContractClients.level_for(standing_of(client_id))


func add_standing(client_id: String, points: int) -> void:
	if client_id == "" or points == 0:
		return
	_standing[client_id] = maxi(0, standing_of(client_id) + points)
	standing_changed.emit(client_id, standing_of(client_id), level_of(client_id))


## A new cycle on the board: untaken generated offers past their life leave it, and each
## client that posts this cycle (seeded) puts up an offer at its unlocked tier, up to
## OFFERS_PER_CLIENT. Host only. The cycle is the game day when Business is on.
func advance_cycle(to_cycle := -1) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_cycle = to_cycle if to_cycle >= 0 else _cycle + 1
	for id: String in _jobs.keys():
		var job: ContractJob = _jobs[id]
		if job.state == ContractJob.OFFERED and job.expires >= 0 and job.expires <= _cycle:
			_jobs.erase(id)
			offer_expired.emit(id)
	if Flags.is_on(CLIENTS_FLAG) and Flags.is_on(KINDS_FLAG):
		for client_id: String in ContractClients.TABLE:
			if not Generator.posts(client_id, _cycle) or _open_offers(client_id) >= OFFERS_PER_CLIENT:
				continue
			_post_generated(client_id, _cycle, 0)
	cycle_advanced.emit(_cycle)


## Generated offers a client has on the board.
func _open_offers(client_id: String) -> int:
	var n := 0
	for job: ContractJob in _jobs.values():
		if job.state == ContractJob.OFFERED and job.expires >= 0 and String(job.order.client.get("company", "")) == client_id:
			n += 1
	return n


# Debug: call in a contract of any level (Esc > Settings > Debug > Contracts)

## The debug tools (the "Contracts" section on the Debug settings page).
const DEBUG_FLAG := "contracts.debug"
const DEBUG_SECTION := "contracts_debug"
## The host-applied event a call-in goes through in multiplayer.
const DEBUG_EVENT := "contracts.call_in"
## Called-in offers take slots from here up, clear of the cycle's own (slot 0).
const CALL_IN_SLOT := 100
## Tiers a client posts at: tier 1 for New and Known, up to tier 3 for Preferred.
const TIERS: PackedStringArray = ["1", "2", "3"]


func _net() -> Node:
	return Modules.bus("multiplayer")


func _hook_net() -> void:
	var net := _net()
	if net and net.has_method("register_event"):
		net.call("register_event", DEBUG_EVENT, _apply_call_in, _validate_call_in)


## Asks for an offer from a client at a tier (1 to 3), whatever BSX's standing with them:
## through the host in multiplayer, so every player gets the same offer, else at once.
func request_call_in(client_id: String, tier: int) -> void:
	var net := _net()
	if net and net.has_method("request"):
		net.call("request", DEBUG_EVENT, {"client": client_id, "tier": tier})
	else:
		var p: Variant = _validate_call_in(1, {"client": client_id, "tier": tier})
		if p is Dictionary:
			_apply_call_in(p)


func _validate_call_in(_sender: int, p: Dictionary) -> Variant:
	if not Flags.is_on(DEBUG_FLAG):
		return "debug tools are off"
	var client_id := str(p.get("client", ""))
	if not ContractClients.has(client_id):
		return "no such client"
	var tier := int(p.get("tier", 0))
	if tier < 1 or tier > 3:
		return "tier must be 1 to 3"
	return {"client": client_id, "tier": tier}


func _apply_call_in(p: Dictionary) -> void:
	call_in(str(p.get("client", "")), int(p.get("tier", 1)))


## Posts a generated offer from the client at the tier now, in the first free call-in slot
## (so the same call on every machine makes the same offer). The new job's id, or "".
func call_in(client_id: String, tier: int) -> String:
	if not ContractClients.has(client_id):
		return ""
	for slot in range(CALL_IN_SLOT, CALL_IN_SLOT + 100):
		if _jobs.has("%s.g%d_%d" % [client_id, _cycle, slot]):
			continue
		return _post_generated(client_id, _cycle, slot, clampi(tier, 1, 3))
	return ""


## The Debug page's section: pick a client and a tier, call the offer in.
func _debug_section() -> Control:
	var col := VBoxContainer.new()
	col.name = "ContractsDebug"
	col.add_theme_constant_override("separation", 8)
	var intro := Label.new()
	intro.text = "Call in a contract offer from any client at any level, whatever BSX's standing with them. It lands on the board as an offer (host)."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(intro)
	var picked := {"client": String(ContractClients.TABLE.keys()[0]), "tier": "1"}
	var names := PackedStringArray()
	var by_name := {}
	for id: String in ContractClients.TABLE:
		var name := ContractClients.display_name(id)
		names.append(name)
		by_name[name] = id
	var client_row := HBoxContainer.new()
	client_row.add_child(TerminalKit.label("Client", "mono_medium", 13, TerminalKit.DIM))
	var client_chips := TerminalKit.chips(names, ContractClients.display_name(String(picked["client"])),
			func(name: String) -> void: picked["client"] = String(by_name.get(name, picked["client"])), false, false)
	client_chips.name = "ClientChips"
	client_row.add_child(client_chips)
	col.add_child(client_row)
	var tier_row := HBoxContainer.new()
	tier_row.add_child(TerminalKit.label("Level", "mono_medium", 13, TerminalKit.DIM))
	var tier_names := PackedStringArray()
	for t: String in TIERS:
		tier_names.append("Tier %s (%s)" % [t, ContractClients.level_name(int(t))])
	var tier_chips := TerminalKit.chips(tier_names, tier_names[0],
			func(name: String) -> void: picked["tier"] = name.substr(5, 1), false, false)
	tier_chips.name = "TierChips"
	tier_row.add_child(tier_chips)
	col.add_child(tier_row)
	var button := Button.new()
	button.name = "CallIn"
	button.text = "Call in an offer"
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(func() -> void: request_call_in(String(picked["client"]), int(String(picked["tier"]))))
	col.add_child(button)
	return col


func _post_generated(client_id: String, at_cycle: int, slot: int, tier := -1) -> String:
	if tier < 0:
		tier = maxi(1, level_of(client_id))
	_generator.wrecks = Flags.is_on(WRECKS_FLAG)
	var data := _generator.make(client_id, at_cycle, slot, tier)
	if data.is_empty() or _jobs.has(String(data.get("contract_id", ""))):
		return ""
	var result := import_text(JSON.stringify(data))
	if not result.ok():
		push_warning("Contracts: generated offer for %s: %s" % [client_id, "; ".join(result.errors)])
		return ""
	get_job(result.job_id).expires = int((data.get("offer", {}) as Dictionary).get("expires", -1))
	return result.job_id


# Changing jobs

## Moves a job to another state; false if the move is not allowed (see ContractJob.NEXT).
## Until Business is switched on, an offered job may go straight to parts_ready.
func advance(job_id: String, to_state: String, by_client := false) -> bool:
	var job := get_job(job_id)
	if job == null:
		return false
	var from_state := job.state
	var skip_business := from_state == ContractJob.OFFERED and to_state == ContractJob.PARTS_READY \
			and not Modules.is_loaded("business")
	if not skip_business and not ContractJob.can_move(from_state, to_state):
		return false
	if to_state == ContractJob.HANDED_OVER and not job.missing_wants().is_empty():
		return false
	job.state = to_state
	if to_state == ContractJob.IN_PROGRESS and from_state == ContractJob.INSPECTION:
		# Rework: whatever failed inspection is back to installed for another go.
		for id: String in job.change_status:
			if job.change_status[id] == ChangeItem.FAILED:
				set_change_status(job_id, id, ChangeItem.INSTALLED)
	job_state_changed.emit(job_id, from_state, to_state)
	_emit_milestone(job, to_state, by_client, from_state != ContractJob.OFFERED)
	return true


## Cancels a job before handover; by_client tells Business who pays for it.
func cancel(job_id: String, by_client: bool) -> bool:
	return advance(job_id, ContractJob.CANCELLED, by_client)


func _emit_milestone(job: ContractJob, to_state: String, by_client: bool, from_state_was_taken := false) -> void:
	match to_state:
		ContractJob.ACCEPTED:
			var c := job.order.commercial
			contract_accepted.emit(job.job_id, int(c.get("price", 0)), int(c.get("due_day", NO_DUE_DAY)))
		ContractJob.HANDED_OVER:
			var quality := job.mean_quality() if job.order.is_fit() else job.returned_condition()
			contract_handed_over.emit(job.job_id, quality, job.open_snags)
			add_standing(String(job.order.client.get("company", "")),
					maxi(ContractClients.HANDOVER_MIN, int(roundf(ContractClients.HANDOVER_POINTS * quality))))
		ContractJob.CANCELLED:
			contract_cancelled.emit(job.job_id, by_client)
			if not by_client and from_state_was_taken:
				add_standing(String(job.order.client.get("company", "")), -ContractClients.CANCEL_POINTS)
		ContractJob.CLOSED:
			job_closed.emit(job.job_id)


func set_change_status(job_id: String, change_id: String, status: String) -> void:
	var job := get_job(job_id)
	if job == null or job.order.change(change_id) == null or not status in ChangeItem.STATUSES:
		return
	if job.change_status.get(change_id) == status:
		return
	job.change_status[change_id] = status
	change_status_changed.emit(job_id, change_id, status)


## Quality: the as-built line for a fitted change. A later record replaces an earlier one.
func record_install(job_id: String, change_id: String, record: InstallRecord) -> void:
	var job := get_job(job_id)
	var c := job.order.change(change_id) if job else null
	if c == null or not c.needs_install():
		return
	job.installs[change_id] = record


## Ship and Bay: how the part that came out of a slot left it.
func record_removal(job_id: String, change_id: String, condition: float, disposition := "returned") -> void:
	var job := get_job(job_id)
	var c := job.order.change(change_id) if job else null
	if c == null or not c.needs_removal():
		return
	job.removals[change_id] = {"condition": clampf(condition, 0.0, 1.0), "disposition": disposition}


## Ship and Bay: a part came out of a non-fit job's subject (break, refurbish: the subject
## itself going back). disposition: "returned" to the client, "kept" by BSX, "scrapped",
## "destroyed". False for a fit job or an unknown one.
func record_recovery(job_id: String, component: ComponentRef, condition: float, disposition := "returned", kg := 0.0) -> bool:
	var job := get_job(job_id)
	if job == null or job.order.is_fit() or component == null:
		return false
	var line := {"component": component.to_dict(), "kg": kg, "condition": clampf(condition, 0.0, 1.0),
			"disposition": disposition}
	job.recoveries.append(line)
	recovery_recorded.emit(job_id, line)
	return true


## Deliveries made for a job's subject carry this order id prefix, then the job id (Ship and
## Bay's SUBJECT_ORDER); the crates it lands and the lots cut from them keep that order id.
const SUBJECT_ORDER := "subject:"


## The job a subject delivery or a lot cut from it belongs to ("subject:<job id>"), or "".
func job_of_order(order_id: String) -> String:
	if not order_id.begins_with(SUBJECT_ORDER):
		return ""
	var job_id := order_id.substr(SUBJECT_ORDER.length())
	return job_id if get_job(job_id) != null else ""


## What becomes of metal cut out of a job's subject (plan stage S5): a scrap job's goes back
## to a client who keeps the rest ("returned") or stays with BSX ("kept"); anything crushed
## on a break, refurbish or dispose job is "scrapped" (a dispose job's subject is gone once
## it is). "" for a fit job or an unknown one.
func scrap_disposition(job_id: String) -> String:
	var job := get_job(job_id)
	if job == null or job.order.is_fit():
		return ""
	if job.order.kind == WorkOrder.SCRAP:
		return "returned" if job.order.keeps == "client" else "kept"
	return "scrapped"


## Ship and Bay: a lot cut from a job's subject came out of the crusher as kilograms per
## material ({material id: kg}, the smelter's cast). Each goes down as scrap with the job's
## disposition (scrap_disposition). Returns the kilograms recorded, 0 for a job that takes
## none.
func record_scrap_lot(job_id: String, materials: Dictionary) -> float:
	var disposition := scrap_disposition(job_id)
	if disposition == "":
		return 0.0
	var total := 0.0
	for material: String in materials:
		var kg := float(materials[material])
		if kg > 0.0 and record_scrap(job_id, material, kg, disposition):
			total += kg
	return total


## Ship and Bay: kilograms of a material cut out of a non-fit job's subject (scrap), or the
## subject gone (dispose: disposition "destroyed").
func record_scrap(job_id: String, material: String, kg: float, disposition := "kept") -> bool:
	var job := get_job(job_id)
	if job == null or job.order.is_fit() or kg < 0.0:
		return false
	var line := {"material": material, "kg": kg, "condition": 0.0, "disposition": disposition}
	job.recoveries.append(line)
	recovery_recorded.emit(job_id, line)
	return true


## Quality: a commissioning test result.
func record_test(job_id: String, test_name: String, passed: bool, value := 0.0, unit := "") -> void:
	var job := get_job(job_id)
	if job:
		job.tests.append({"name": test_name, "passed": passed, "value": value, "unit": unit})


## Quality: who signed the job off, and how many snags were still open.
func sign_off(job_id: String, player_id: String, role: String, open_snags := 0) -> void:
	var job := get_job(job_id)
	if job:
		job.signed_by.append({"player_id": player_id, "role": role})
		job.open_snags = open_snags


## Logs a change order (hidden damage, a client change). Returns its id, or "" if no job.
func raise_variation(job_id: String, description: String, price_delta := 0.0) -> String:
	var job := get_job(job_id)
	if job == null:
		return ""
	var v := {"variation_id": "v%d" % (job.variations.size() + 1), "description": description,
			"price_delta": price_delta}
	job.variations.append(v)
	variation_raised.emit(job_id, v)
	return v["variation_id"]


# Handover

## The as-built record as data, or {} if the job is not handed over or a change has no
## install record yet.
func as_built(job_id: String) -> Dictionary:
	var job := get_job(job_id)
	if job == null or job.state != ContractJob.HANDED_OVER:
		return {}
	if job.order.is_fit() and not job.missing_installs().is_empty():
		return {}
	if job.completed_at == "":
		job.completed_at = Time.get_datetime_string_from_system(true) + "Z"
	return Writer.build(job, Modules.is_loaded("business"))


## Writes `<contract_id>.asbuilt.json` into dir (or to a full path ending in .json) and
## closes the job.
func export_as_built(job_id: String, path: String) -> Error:
	var record := as_built(job_id)
	if record.is_empty():
		return ERR_UNCONFIGURED
	if not path.ends_with(".json"):
		path = path.path_join("%s.asbuilt.json" % job_id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(record, "  "))
	f.close()
	advance(job_id, ContractJob.CLOSED)
	as_built_exported.emit(job_id, path)
	return OK


# Save section (Saves calls these)

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	var jobs := {}
	for id: String in _jobs:
		jobs[id] = Store.to_save(_jobs[id])
	return {"jobs": jobs, "active": _active, "standing": _standing, "cycle": _cycle}


func load_data(data: Dictionary, _from_version: int) -> void:
	_jobs = {}
	for id: String in data.get("jobs", {}):
		var errors := PackedStringArray()
		var job := Store.from_save(data["jobs"][id], errors)
		if job:
			_jobs[job.job_id] = job
		else:
			push_warning("Contracts: dropped saved job %s: %s" % [id, "; ".join(errors)])
	_active = ""
	set_active_job(String(data.get("active", "")))
	_standing = {}
	for id: String in data.get("standing", {}):
		_standing[id] = int(data["standing"][id])
	_cycle = int(data.get("cycle", 0))
	seed_board()
