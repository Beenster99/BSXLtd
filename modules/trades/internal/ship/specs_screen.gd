class_name TradesSpecsScreen
extends HBoxContainer
## The wrist screen's Specs channel (beenster, 0.3.7: "the required torque is provided by
## inspecting the spec, and available on the player's wrist HUD"): the joint you're looking
## at and what its tool should be set to, then every fastener on the ship in the bay with its
## torque window or rivet head height. On the right (trades.spec_sheet, beenster 2026-10-22)
## the spec sheet of the part you're looking at, as a paper doc (TradesSpecSheet).
##
## With trades.job_pack_specs (beenster, 0.3.14: "The specs tab should be related to a
## specific contract that we are working on ... a job pack ... a spec sheet for each object,
## there shouldn't be anything shown on the right hand side if nothing is being looked at,
## but there should be access to more information about the contracts") the left is the
## contract being worked on (ContractsBus.get_active_job) with every document of its job pack
## to pick from, and the right is the spec sheet from that pack for the part you're looking
## at, or nothing when you look at nothing.

const T := preload("res://modules/ui/api/terminal_kit.gd")

var _glass := false
var _col: VBoxContainer
## The pack document open on the left ("order" first).
var doc_id := "order"
## The job the screen shows, "" for none; and the slot it's showing a spec sheet for.
var job_id := ""
var looked_slot := ""
var _doc_box: VBoxContainer
var _chips: Control
var _station: TradesShipJoints


## `station` (tests): the ship's joints; by default the yard rig's.
func _init(glass := false, station: TradesShipJoints = null) -> void:
	_glass = glass
	_station = station
	name = "TradesSpecs"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 18)


func _ready() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	var rig := get_tree().current_scene.get_node_or_null(TradesBus.YARD_RIG) as TradesBay if get_tree().current_scene else null
	var station := _station if _station else rig.ship_station() if rig else null
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 10)
	add_child(_col)
	if Flags.is_on("trades.job_pack_specs"):
		_aimed_docket(station)
		_job_pack(station)
		return
	if Flags.is_on("trades.spec_sheet"):
		add_child(TradesSpecSheet.new(station))
	_aimed_docket(station)
	_fastener_table(bus)


## The joint under the aim, if any.
func _aimed_docket(station: TradesShipJoints) -> void:
	if station and station.aimed >= 0:
		var f := station.points[station.aimed]
		var d := T.docket("Looking at", f.joint_id, _glass)
		_col.add_child(d.panel)
		var col: VBoxContainer = d.body
		col.add_child(T.label("%s %s" % [f.spec, f.kind], "display_bold", 30, T.TEXT if _glass else T.INK))
		col.add_child(T.label(setting_text(f.kind, f.spec), "mono_medium", 22, T.ORANGE))


## Every fastener on the ship, by spec.
func _fastener_table(bus: ShipBayBus) -> void:
	_col.add_child(T.columns([["FASTENER", 0], ["JOINTS", 110], ["SET THE TOOL TO", 260]]))
	var rows := T.list()
	_col.add_child(rows.get_parent())
	var counts := {}
	if bus and bus.ship:
		for slot in bus.get_slots():
			for f in bus.get_fasteners(slot.slot_id):
				if f.kind == "bolt" or f.kind == "rivet":
					var key := "%s|%s" % [f.kind, f.spec]
					counts[key] = int(counts.get(key, 0)) + 1
	if counts.is_empty():
		rows.add_child(T.label("No ship in the bay.", "body_medium", 19, T.DIM))
		return
	var keys := counts.keys()
	keys.sort()
	var alt := false
	for key: String in keys:
		var kind := key.get_slice("|", 0)
		var spec := key.get_slice("|", 1)
		rows.add_child(T.row([T.cell_text(spec, kind), T.cell(str(counts[key]), 110),
				T.cell(setting_text(kind, spec), 260, T.TEXT)], alt, _glass))
		alt = not alt


# --- The job pack (trades.job_pack_specs) -------------------------------------------------------

func _job_pack(station: TradesShipJoints) -> void:
	var contracts := Modules.bus("contracts") as ContractsBus
	var job := contracts.get_active_job() if contracts else null
	looked_slot = slot_looked_at(station)
	if job == null:
		job_id = ""
		_col.add_child(T.label("No contract on. Take one on the Contracts board to see its job pack here.",
				"body_medium", 18, T.DIM))
		_fastener_table(Modules.bus("ship_bay") as ShipBayBus)
		if looked_slot != "" and Flags.is_on("trades.spec_sheet"):
			add_child(TradesSpecSheet.new(station))
		return
	job_id = job.job_id
	var o := job.order
	var who := String(o.client.get("display_name", o.client.get("company", "")))
	var d := T.docket(o.title if o.title != "" else "Work for " + who, job.job_id.to_upper(), _glass)
	_col.add_child(d.panel)
	var body: VBoxContainer = d.body
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_child(T.tag(o.kind.to_upper(), ContractDocumentView.tone_colour(String(ContractJobPack.KIND_TONES.get(o.kind, "plain"))), 13))
	tags.add_child(T.tag(job.state.replace("_", " ").to_upper(), T.STEEL, 13))
	if who != "":
		tags.add_child(T.tag(who.to_upper(), T.CYAN, 13))
	body.add_child(tags)
	body.add_child(T.label("JOB PACK", "display_medium", 13, T.DIM if _glass else T.INK_DIM))
	var pack := contracts.job_pack(job.job_id)
	_chips = _pack_chips(pack)
	body.add_child(_chips)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_col.add_child(scroll)
	_doc_box = VBoxContainer.new()
	_doc_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_doc_box)
	open_doc(doc_id if not contracts.document(job.job_id, doc_id).is_empty() else "order")
	# On the right: the looked-at part's spec sheet from the pack, or nothing.
	if looked_slot == "":
		return
	var sheet_id := spec_doc_for(job, looked_slot)
	if sheet_id != "":
		var right := PanelContainer.new()
		right.name = "LookedSpec"
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_stretch_ratio = 0.8
		right.add_theme_stylebox_override("panel", T.plate(14, _glass))
		right.add_child(ContractDocumentView.new(contracts.document(job.job_id, sheet_id), _glass))
		add_child(right)
	elif Flags.is_on("trades.spec_sheet"):
		add_child(TradesSpecSheet.new(station))


## Shows one document of the pack on the left.
func open_doc(id: String) -> void:
	var contracts := Modules.bus("contracts") as ContractsBus
	if contracts == null or _doc_box == null:
		return
	doc_id = id
	for c in _doc_box.get_children():
		c.queue_free()
	_doc_box.add_child(ContractDocumentView.new(contracts.document(job_id, id), _glass))
	if _chips:
		# The open document's chip is lit (rebuilt: a toggled kit button clips its text).
		for b in _chips.get_children():
			b.queue_free()
		_add_chips(_chips, contracts.job_pack(job_id))


func _pack_chips(pack: Array[Dictionary]) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	_add_chips(flow, pack)
	return flow


func _add_chips(flow: Control, pack: Array[Dictionary]) -> void:
	for d in pack:
		var id := String(d.get("id", ""))
		var b := T.button(_short(d), false, 14, id == doc_id, _glass)
		b.set_meta("doc_id", id)
		b.pressed.connect(open_doc.bind(id))
		flow.add_child(b)


## A chip's words for a document: "Spec: port engine" rather than "Spec sheet: port engine".
static func _short(d: Dictionary) -> String:
	return String(d.get("title", "")).replace("Spec sheet: ", "Spec: ").to_upper()


## The slot of what you're looking at: the joint under the aim, or the part the beam is on.
static func slot_looked_at(station: TradesShipJoints) -> String:
	if station == null:
		return ""
	if station.aimed >= 0:
		var slot := FastenerPoint.slot_of(station.points[station.aimed].joint_id)
		return "" if slot == TradesTestStand.SLOT else slot
	if station.tractor:
		return station.tractor.aimed_slot()
	return ""


## The pack's spec sheet for a slot: the change fitting it ("spec:<change_id>"), the
## subject's own sheet on a strip-out job, or "" when the job doesn't touch it.
static func spec_doc_for(job: ContractJob, slot: String) -> String:
	if job.order.is_fit():
		for c in job.order.changes:
			if c.slot == slot:
				return "spec:" + c.change_id
		return ""
	return "spec:subject"


## What the tool is set to for a fastener: "80-95 N m" for a bolt, "head 2.0 mm" for a rivet.
static func setting_text(kind: String, spec: String) -> String:
	if kind == "bolt":
		var nm := TradesShipJoints.torque_range(spec)
		return "%d-%d N m" % [roundi(nm.x), roundi(nm.y)]
	if kind == "rivet":
		return "head %.1f mm" % TradesShipJoints.head_target_mm(spec)
	return "-"
