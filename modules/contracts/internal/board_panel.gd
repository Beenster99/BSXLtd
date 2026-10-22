extends HBoxContainer
## The wrist screen's Contracts channel: what work is on offer and what the yard has taken
## on. Chips pick Void Salvage, local work or accepted; the list shows job / client, ship,
## due day and pay; the docket on the right is the chosen job's spec sheet and parts
## manifest with ACCEPT JOB. Built with TerminalKit so it matches the yard terminal.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const TABS: PackedStringArray = ["void salvage", "local work", "accepted"]

var bus: ContractsBus
var glass := true
var tab := "void salvage"
var selected := ""


func _init(p_bus: ContractsBus, p_glass := true) -> void:
	bus = p_bus
	glass = p_glass
	name = "ContractsBoard"
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	bus.contract_imported.connect(func(_id: String) -> void: refresh())
	bus.job_state_changed.connect(func(_id: String, _a: String, _b: String) -> void: refresh())
	bus.active_job_changed.connect(func(_id: String) -> void: refresh())
	refresh()


## The jobs on the current tab.
func jobs() -> Array[ContractJob]:
	return bus.board(_tab_key(tab))


func pick_tab(t: String) -> void:
	tab = t if t in TABS else TABS[0]
	selected = ""
	refresh()


func pick(job_id: String) -> void:
	selected = job_id
	refresh()


## The docket's button: accept an offer, or make a taken job the active one.
func act() -> void:
	var job := bus.get_job(selected)
	if job == null:
		return
	if job.state == ContractJob.OFFERED:
		bus.accept(selected)
	else:
		bus.set_active_job(selected)


func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var list_jobs := jobs()
	if bus.get_job(selected) == null or not bus.get_job(selected) in list_jobs:
		selected = list_jobs[0].job_id if not list_jobs.is_empty() else ""

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.7
	col.add_child(T.chips(TABS, tab, pick_tab, glass, false))
	col.add_child(T.columns([["JOB  /  CLIENT", 0], ["SHIP", 120], ["DUE", 80], ["PAYS CR", 110]]))
	var list := T.list()
	col.add_child(list.get_parent())
	if list_jobs.is_empty():
		list.add_child(T.label(_empty_text(), "body", 17, T.DIM))
	for i in list_jobs.size():
		list.add_child(_row(list_jobs[i], i % 2 == 1))
	add_child(col)
	add_child(_docket(bus.get_job(selected)))


func _row(job: ContractJob, alt: bool) -> Control:
	var o := job.order
	var r := T.row([T.cell_text(job_title(job), client_line(job)), T.cell(subject_name(o), 120, T.TEXT),
			T.cell(due_text(o), 80), T.cell(T.money(int(o.commercial.get("price", 0))), 110, T.ORANGE, "mono_bold")], alt, glass)
	r.name = "Row_" + job.job_id.validate_node_name()
	if job.job_id == selected:
		var st := (r.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		st.border_width_left = 4
		st.border_color = T.ORANGE
		r.add_theme_stylebox_override("panel", st)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pick(job.job_id))
	return r


func _docket(job: ContractJob) -> Control:
	var d := T.docket("Spec sheet", job.job_id.to_upper() if job else "", glass)
	var body: VBoxContainer = d.body
	(d.panel as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	if job == null:
		body.add_child(T.label("Pick a job to see its spec sheet.", "body", 17, T.DIM))
		return d.panel
	var o := job.order
	var ink := T.TEXT if glass else T.INK
	var dim := T.DIM if glass else T.INK_DIM
	body.add_child(T.label("%s  ·  %s" % [String(o.client.get("display_name", o.client.get("company", ""))), subject_name(o)], "body_medium", 18, ink))
	if not o.is_fit():
		body.add_child(_wrap(T.label(subject_text(o), "body", 17, ink)))
		body.add_child(T.label("CLIENT WANTS", "display_medium", 15, dim))
		for w in o.wants:
			body.add_child(_wrap(T.label(want_text(w), "body", 15, ink)))
		body.add_child(T.label(keeps_text(o), "body", 15, dim))
		if not o.hazards.is_empty():
			body.add_child(T.tag("HAZARDS  " + "  ".join(o.hazards).to_upper(), T.ORANGE))
	for c in o.changes:
		var line := T.label(change_text(c), "body", 17, ink)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(line)
		var spec := spec_text(job, c.change_id)
		if spec != "":
			body.add_child(T.label(spec, "mono_medium", 14, dim))
		if c.notes != "":
			body.add_child(_wrap(T.label("“%s”" % c.notes, "body", 15, dim)))
	for n in o.notes:
		if String(n.get("change_id", "")) == "":
			body.add_child(_wrap(T.label("“%s”" % String(n.get("text", "")), "body", 15, dim)))
	if not o.manifest.is_empty():
		body.add_child(T.label("PARTS MANIFEST", "display_medium", 15, dim))
	for m in o.manifest:
		body.add_child(_wrap(T.label("%d × %s  ·  %s" % [m.qty, part_name(m.component.id),
				("BSX supplies, " + " or ".join(m.allowed_sources)) if m.supplied_by == "bsx" else "client supplies"], "body", 15, ink)))
	var pay := int(o.commercial.get("price", 0))
	var dep := int(o.commercial.get("deposit_pct", 0))
	body.add_child(T.label("PAYS CR %s  ·  %d%% DEPOSIT  ·  %s" % [T.money(pay), dep, due_text(o)], "mono_bold", 16, T.ORANGE))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	if job.state == ContractJob.OFFERED:
		var b := T.button("ACCEPT JOB", true, 22, false, glass)
		b.name = "Accept"
		b.pressed.connect(act)
		body.add_child(b)
	elif bus.get_active_job() == job:
		body.add_child(T.tag("Active job · " + job.state.replace("_", " "), T.GOOD))
	else:
		var b := T.button("MAKE ACTIVE JOB", false, 20, false, glass)
		b.name = "MakeActive"
		b.pressed.connect(act)
		body.add_child(b)
	return d.panel


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _empty_text() -> String:
	match tab:
		"accepted":
			return "No jobs taken on yet. Accept one from Void Salvage or local work."
		"local work":
			return "No local yards need work right now."
	return "No Void Salvage work orders right now."


static func _tab_key(t: String) -> String:
	match t:
		"local work":
			return ContractsBus.LOCAL
		"accepted":
			return ContractsBus.TAKEN
	return ContractsBus.VOID_SALVAGE


# Words for the board. Module and part ids are BSX's own strings; until Contracts reads
# names from Shared Components they are turned into words here ("attractor_coil_1" ->
# "Attractor coil Mk I").

static func part_name(id: String) -> String:
	var marks := {"1": "Mk I", "2": "Mk II", "3": "Mk III"}
	# "NavalTurret" (a Void Salvage part name) -> "naval_turret" first.
	var words := id.to_snake_case().split("_")
	if words.size() > 1 and marks.has(words[-1]):
		words[-1] = marks[words[-1]]
	var s := " ".join(words)
	return s.substr(0, 1).to_upper() + s.substr(1)


static func ship_name(design: String) -> String:
	return design.capitalize()


## The board's SHIP column: the ship a fit job is about, or where a part job happens.
static func subject_name(o: WorkOrder) -> String:
	if o.is_fit():
		return ship_name(o.design)
	if String(o.subject.get("type", "")) == "part":
		return "Bench"
	return ship_name(String(o.subject.get("design", o.design)))


## "Naval turret, 55%, 6.2 t" for a part subject; the design for a ship or wreck.
static func subject_text(o: WorkOrder) -> String:
	var s := o.subject
	var what := part_name(o.subject_part().id) if o.subject_part() else ship_name(String(s.get("design", o.design)))
	var bits := PackedStringArray([what, "%d%%" % int(round(float(s.get("condition", 1.0)) * 100.0))])
	var kg := float(s.get("mass_kg", 0.0))
	if kg > 0.0:
		bits.append("%.1f t" % (kg / 1000.0) if kg >= 1000.0 else "%d kg" % int(kg))
	return "Arrives: " + ", ".join(bits)


static func want_text(w: Dictionary) -> String:
	match String(w.get("what", "")):
		"part":
			var ref: ComponentRef = w.get("component")
			var line := "%d × %s back" % [int(w.get("qty", 1)), part_name(ref.id) if ref else "part"]
			if float(w.get("min_condition", 0.0)) > 0.0:
				line += ", %d%% or better" % int(round(float(w.get("min_condition", 0.0)) * 100.0))
			return line
		"material":
			return "%s kg of %s" % [T.money(int(w.get("kg", 0.0))), String(w.get("material", ""))]
		"condition":
			return "The subject back at %d%% or better" % int(round(float(w.get("min_condition", 1.0)) * 100.0))
	return "The subject gone: scrapped or destroyed"


static func keeps_text(o: WorkOrder) -> String:
	return "BSX keeps the rest" if o.keeps == "bsx" else "Everything else goes back to the client"


static func job_title(job: ContractJob) -> String:
	if not job.order.is_fit():
		return kind_title(job.order)
	var c := job.order.changes[0] if not job.order.changes.is_empty() else null
	if c == null:
		return job.job_id
	var what := part_name(c.install.id if c.install else c.remove.id)
	var title := ("Fit " if c.action == ChangeItem.ADD else "Remove " if c.action == ChangeItem.REMOVE else "Swap in ") + what.substr(0, 1).to_lower() + what.substr(1)
	if job.order.changes.size() > 1:
		title += " and %d more" % (job.order.changes.size() - 1)
	return title


## "Break a naval turret", "Scrap hull plating", "Refurbish a main thruster", "Dispose of a fuel tank".
static func kind_title(o: WorkOrder) -> String:
	var what := part_name(o.subject_part().id) if o.subject_part() else ship_name(String(o.subject.get("design", o.design)))
	what = what.substr(0, 1).to_lower() + what.substr(1)
	match o.kind:
		WorkOrder.BREAK:
			return "Break a " + what
		WorkOrder.SCRAP:
			return "Scrap " + what
		WorkOrder.REFURBISH:
			return "Refurbish a " + what
		WorkOrder.DISPOSE:
			return "Dispose of a " + what
	return o.kind.capitalize() + " " + what


static func client_line(job: ContractJob) -> String:
	var who := String(job.order.client.get("display_name", job.order.client.get("company", "")))
	var where := "Void Salvage" if String(job.order.client.get("game", "")) == "void_salvage" else "Local yard"
	var line := "%s · %s" % [where, who]
	if job.state != ContractJob.OFFERED:
		line += " · " + job.state.replace("_", " ")
	return line


static func due_text(o: WorkOrder) -> String:
	var day := int(o.commercial.get("due_day", ContractsBus.NO_DUE_DAY))
	return "—" if day >= ContractsBus.NO_DUE_DAY else "DAY %d" % day


static func change_text(c: ChangeItem) -> String:
	var where := c.slot.replace("_", " ")
	match c.action:
		ChangeItem.ADD:
			return "Fit %s in %s" % [part_name(c.install.id), where]
		ChangeItem.REMOVE:
			return "Take out %s from %s" % [part_name(c.remove.id), where]
	return "Swap %s for %s in %s" % [part_name(c.remove.id), part_name(c.install.id), where]


func spec_text(job: ContractJob, change_id: String) -> String:
	var spec := bus.get_spec(job.job_id, change_id)
	if spec == null:
		return ""
	var bits := PackedStringArray()
	for kind in SpecEntry.JOINT_KINDS:
		var d: Dictionary = spec.for_kind(kind)
		if d.is_empty():
			continue
		var vals := PackedStringArray()
		for k: String in d:
			var v: Variant = d[k]
			var text := str(int(v)) if v is float and v == floorf(v) else str(v)
			vals.append(text + " N·m" if k == "torque_nm" else text)
		bits.append("%s %s" % [kind.to_upper(), " ".join(vals)])
	return "  ·  ".join(bits)
