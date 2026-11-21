extends PanelContainer
## THE COMPANY (master plan Wave 8): on any wall of the design room and on the wrist. Pages:
##   RANK     the yard's rank, what the next one asks and what each rank opens
##   CLIENTS  the ship orders on the board with the rival yards' bids, and repeat orders
##   CREW     the players on shift and their roles; pick yours
##   LAUNCH   the ships on the go: name each one before her trial
##   SHELF    the trophy shelf: a miniature of every ship the yard has built, her plaque signed
##            by the crew who built her
##   PAPERS   every contract's signed papers (design sign-offs, stage gates, delivery notes), and
##            the gates waiting for a signature

const T := preload("res://modules/ui/api/terminal_kit.gd")

const PAGES: PackedStringArray = ["RANK", "CLIENTS", "CREW", "LAUNCH", "SHELF", "PAPERS"]
const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)

var bus: Object
var fs := 15
var page := "RANK"
var _tabs: HBoxContainer
var _body: VBoxContainer
var _status: Label
var _queued := false
var _typing := false


func setup(company_bus: Object, density: float, first_page := "RANK") -> void:
	bus = company_bus
	page = first_page if PAGES.has(first_page) else "RANK"
	fs = maxi(12, int(density * 0.1))
	name = "CompanyScreen"
	add_theme_stylebox_override("panel", T.box(BG, Color.TRANSPARENT, 0, fs * 0.5))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(fs * 0.5))
	add_child(col)
	_status = _label("", "mono_medium", fs - 2, T.DIM)
	col.add_child(_status)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", int(fs * 0.4))
	col.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", int(fs * 0.35))
	scroll.add_child(_body)
	bus.connect("changed", _queue)
	refresh()


func _queue() -> void:
	if _queued:
		return
	_queued = true
	_later.call_deferred()


func _later() -> void:
	_queued = false
	if is_inside_tree() and not _typing:
		refresh()


func refresh() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for p in PAGES:
		var b := T.button(p, false, fs - 2, p == page)
		b.pressed.connect(func() -> void:
			page = p
			refresh())
		_tabs.add_child(b)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var r: Dictionary = bus.call("rank")
	_status.text = "BSX LTD · %s · %d SHIPS DELIVERED · REPUTATION %d" % [str(r.name).to_upper(), (bus.get("record") as Array).size(),
			roundi(float(bus.call("reputation")))]
	match page:
		"RANK":
			_rank(r)
		"CLIENTS":
			_clients()
		"CREW":
			_crew()
		"LAUNCH":
			_launch()
		"SHELF":
			_shelf()
		"PAPERS":
			_papers()


func _rank(r: Dictionary) -> void:
	_body.add_child(_label(str(r.name).to_upper(), "display_bold", fs + 14, T.ORANGE))
	var nxt: Dictionary = bus.call("next_rank")
	if nxt.is_empty():
		_body.add_child(_label("The top of the trade. Every ship class, every berth.", "body_medium", fs, T.GOOD))
	else:
		var ships := (bus.get("record") as Array).size()
		_body.add_child(_label("Next: %s, at %d ships delivered (%d so far) and reputation %d (%d now)." % [str(nxt.name),
				int(nxt.ships), ships, int(nxt.reputation), roundi(float(bus.call("reputation")))], "body_medium", fs, T.TEXT))
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = minf(float(ships) / maxf(1.0, float(nxt.ships)), float(bus.call("reputation")) / maxf(1.0, float(nxt.reputation)))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, fs * 0.8)
		_body.add_child(bar)
	_body.add_child(_label("WHAT EACH RANK OPENS", "mono_bold", fs - 2, T.ORANGE))
	var at := int(r.index)
	for i in CompanyBus.RANKS.size():
		var k: Dictionary = CompanyBus.RANKS[i]
		var card := _card()
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(_label("%s%s" % [str(k.name), "  ◀ BSX NOW" if i == at else ""], "display_bold", fs + 2, T.ORANGE_HI if i == at else (T.TEXT if i < at else T.DIM)))
		var opens: Array[String] = ["%d bots" % int(k.bots), "%d holding berth%s" % [int(k.holding), "" if int(k.holding) == 1 else "s"],
				"ships up to %s" % str((k.sizes as Array).back())]
		for t: String in k.bots_new:
			opens.append(t.replace("_", " ") + " bots")
		v.add_child(_label("%d ship%s · reputation %d  ·  %s" % [int(k.ships), "" if int(k.ships) == 1 else "s", int(k.reputation), ", ".join(opens)], "mono_medium", fs - 3, T.DIM))
		_body.add_child(card)


func _clients() -> void:
	var contracts := Modules.bus("contracts")
	if contracts == null or not contracts.has_method("ship_orders"):
		_body.add_child(_label("No ship orders.", "body_medium", fs, T.DIM))
		return
	_body.add_child(_label("Rival yards bid for the same orders. You sign at the lowest rival bid unless the client knows BSX well (level %d) or it is a repeat order." % CompanyBus.LOYAL_LEVEL,
			"body_medium", fs - 1, T.DIM))
	for o: Dictionary in contracts.call("ship_orders"):
		var card := _card()
		var v := VBoxContainer.new()
		card.add_child(v)
		var top := HBoxContainer.new()
		var title := _label(str(o.get("title", o.get("id", ""))), "body_medium", fs, T.AMBER if bool(o.get("repeat", false)) else T.TEXT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		top.add_child(title)
		top.add_child(_label("%s · budget CR %s" % [str(o.get("size", "")), T.money(int(o.get("budget", 0)))], "mono_medium", fs - 2, T.DIM))
		v.add_child(top)
		var why := str(bus.call("sign_check", o))
		if why != "":
			v.add_child(_label("Not yet: " + why, "mono_medium", fs - 3, T.BAD))
		var bids: Array = bus.call("rival_bids", o)
		if bool(o.get("repeat", false)):
			v.add_child(_label("REPEAT ORDER: the client comes back to BSX at its own price.", "mono_medium", fs - 3, T.GOOD))
		elif not bids.is_empty():
			var bits: Array[String] = []
			for b: Dictionary in bids:
				bits.append("%s CR %s" % [str(b.name), T.money(int(b.price))])
			v.add_child(_label("Rivals: " + "  ·  ".join(bits), "mono_medium", fs - 3, T.CYAN))
		_body.add_child(card)


func _crew() -> void:
	var roles: Dictionary = bus.get("roles")
	for who: String in bus.call("crew"):
		var card := _card()
		var v := VBoxContainer.new()
		card.add_child(v)
		var role := str(roles.get(who, ""))
		v.add_child(_label("%s  ·  %s" % [who, str((CompanyBus.ROLES.get(role, {}) as Dictionary).get("name", "no role yet"))], "display_bold", fs + 1, T.TEXT))
		if role != "":
			v.add_child(_label(str(CompanyBus.ROLES[role].what), "body_medium", fs - 2, T.DIM))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", int(fs * 0.4))
		for id: String in CompanyBus.ROLES:
			var b := T.button(str(CompanyBus.ROLES[id].name).to_upper(), false, fs - 3, id == role)
			b.tooltip_text = str(CompanyBus.ROLES[id].what)
			b.pressed.connect(func() -> void: bus.call("set_role", who, id if id != role else ""))
			row.add_child(b)
		v.add_child(row)
		_body.add_child(card)
	_body.add_child(_label("The crew's share of each trial bonus (%d%%) is split between the players on shift; a launch master doubles it." % roundi(CompanyBus.CREW_SHARE * 100.0),
			"body_medium", fs - 2, T.DIM))


func _launch() -> void:
	var build := Modules.bus("build")
	var builds: Dictionary = build.get("builds") if build else {}
	if builds.is_empty():
		_body.add_child(_label("No ship on the go to name.", "body_medium", fs, T.DIM))
		return
	_body.add_child(_label("Name her before her trial. At delivery the bots line up, a bottle breaks on her bow and she leaves the berth under her own power.",
			"body_medium", fs - 1, T.DIM))
	for cid: String in builds:
		var b: Dictionary = builds[cid]
		var p: Dictionary = build.call("progress", cid)
		var card := _card()
		var v := VBoxContainer.new()
		card.add_child(v)
		var given := str(bus.call("name_of", cid))
		v.add_child(_label("%s  ·  %s  ·  %d / %d jobs" % [given if given != "" else "Unnamed", str(b.get("design_name", "")),
				int(p.get("jobs_done", 0)), int(p.get("jobs", 0))], "display_bold", fs + 1, T.ORANGE_HI if given != "" else T.TEXT))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(fs * 0.4))
		var edit := LineEdit.new()
		edit.placeholder_text = "Her name"
		edit.text = given
		edit.max_length = 32
		edit.custom_minimum_size.x = fs * 18
		edit.add_theme_font_size_override("font_size", fs)
		edit.focus_entered.connect(func() -> void: _typing = true)
		edit.focus_exited.connect(func() -> void: _typing = false)
		row.add_child(edit)
		var go := T.button("NAME HER", true, fs - 2)
		go.pressed.connect(func() -> void:
			_typing = false
			bus.call("name_ship", cid, edit.text))
		edit.text_submitted.connect(func(t: String) -> void:
			_typing = false
			bus.call("name_ship", cid, t))
		row.add_child(go)
		v.add_child(row)
		_body.add_child(card)


func _shelf() -> void:
	var record: Array = bus.get("record")
	if record.is_empty():
		_body.add_child(_label("The shelf is empty. Every ship the yard delivers stands here, her plaque signed by the crew.", "body_medium", fs, T.DIM))
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(fs * 0.6))
	grid.add_theme_constant_override("v_separation", int(fs * 0.6))
	for i in range(record.size() - 1, -1, -1):
		var e: Dictionary = record[i]
		var card := _card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		card.add_child(v)
		var mini := Control.new()
		mini.custom_minimum_size = Vector2(fs * 16, fs * 6)
		mini.draw.connect(_draw_mini.bind(mini, e.get("side", [])))
		v.add_child(mini)
		var q := float(e.get("quality", 0.0))
		v.add_child(_label(str(e.get("name", "")).to_upper(), "display_bold", fs + 2, T.ORANGE_HI))
		v.add_child(_label("%s · %s · day %d" % [str(e.get("design", "")), str(e.get("client", "")), int(e.get("day", 0))], "mono_medium", fs - 3, T.DIM))
		v.add_child(_label("Trial %d%%%s" % [roundi(q * 100.0), ("  ·  workmanship %d%%" % roundi(float(e.workmanship) * 100.0)) if float(e.get("workmanship", -1.0)) >= 0.0 else ""],
				"mono_medium", fs - 2, T.GOOD if q >= 0.8 else (T.AMBER if q >= 0.5 else T.BAD)))
		v.add_child(_label("Signed: " + ", ".join(e.get("crew", [])), "body_medium", fs - 3, T.CYAN))
		grid.add_child(card)
	_body.add_child(grid)


func _papers() -> void:
	var contracts := Modules.bus("contracts") as ContractsBus
	if contracts == null:
		return
	if not Flags.is_on(ContractsBus.SIGNATURES_FLAG):
		_body.add_child(_label("Contract papers are off.", "body_medium", fs, T.DIM))
		return
	_body.add_child(_label("Each design is signed before its quote goes out, each stage gate before it is paid, and the delivery note at the trial. Signing as %s." % contracts.signer(),
			"body_medium", fs - 2, T.DIM))
	for c: Dictionary in contracts.ship_contracts():
		var gates: Array = contracts.gates_to_sign(str(c.id))
		for g: String in gates:
			var name := g
			for st: Dictionary in c.stages:
				if str(st.id) == g:
					name = "%s, CR %s" % [str(st.name), T.money(int(st.value))]
			var row := HBoxContainer.new()
			var l := _label("TO SIGN  %s: %s" % [str(c.design_name), name], "mono_medium", fs - 1, T.AMBER)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var b := T.button("SIGN", true, fs - 2)
			b.disabled = g != str(gates[0])
			var cid := str(c.id)
			row.add_child(b)
			_body.add_child(row)
			var gate_title := "Sign the %s stage gate as %s, on the line below." % [name, contracts.signer()]
			b.pressed.connect(func() -> void:
				if row.get_parent().has_node("SignaturePad"):
					return
				var pad := ContractSignaturePad.make(gate_title, fs - 1)
				pad.name = "SignaturePad"
				row.get_parent().add_child(pad)
				row.get_parent().move_child(pad, row.get_index() + 1)
				b.visible = false
				pad.cancelled.connect(func() -> void:
					b.visible = true
					pad.queue_free())
				pad.signed.connect(func(sig: Array) -> void:
					pad.queue_free()
					contracts.request_sign_gate(cid, g, contracts.signer(), sig)))
	var all := contracts.all_papers()
	if all.is_empty():
		_body.add_child(_label("No papers yet. Sign a design's quote in the design room to start one.", "body_medium", fs, T.DIM))
	for pp: Dictionary in all:
		var card := _card()
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(_label(str(pp.title).to_upper(), "display_bold", fs, T.ORANGE_HI))
		v.add_child(_label("%s  ·  day %d" % [str(pp.contract_title), int(pp.day)], "mono_medium", fs - 3, T.DIM))
		for t: Variant in pp.get("terms", []):
			v.add_child(_label(str(t), "mono_medium", fs - 3, T.TEXT))
		v.add_child(_label("Signed for BSX Ltd: %s" % str(pp.by), "body_medium", fs - 2, T.CYAN))
		var sig: Array = pp.get("sig", [])
		if not sig.is_empty():
			var mark := ContractSignaturePad.view(sig, Vector2(fs * 14.0, fs * 14.0 / ContractSignaturePad.ASPECT))
			mark.name = "Signature"
			mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			v.add_child(mark)
		_body.add_child(card)


## Her miniature on the shelf: the side view of her parts, in brass.
func _draw_mini(c: Control, side: Array) -> void:
	var sz := c.size
	c.draw_rect(Rect2(Vector2(0, sz.y - fs * 0.5), Vector2(sz.x, fs * 0.5)), Color(0.25, 0.2, 0.14))
	if side.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r: Array in side:
		lo = lo.min(Vector2(float(r[0]), float(r[1])))
		hi = hi.max(Vector2(float(r[0]) + float(r[2]), float(r[1]) + float(r[3])))
	var span := (hi - lo).max(Vector2(0.1, 0.1))
	var s := minf((sz.x - fs) / span.x, (sz.y - fs * 1.2) / span.y)
	var o := Vector2((sz.x - span.x * s) * 0.5, sz.y - fs * 0.6 - span.y * s) - lo * s
	for r: Array in side:
		c.draw_rect(Rect2(o + Vector2(float(r[0]), float(r[1])) * s, Vector2(maxf(float(r[2]) * s, 1.0), maxf(float(r[3]) * s, 1.0))),
				Color(0.85, 0.66, 0.32, 0.55))


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(CARD, Color.TRANSPARENT, 0, fs * 0.4))
	return p


func _label(text: String, face: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.font(face))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
