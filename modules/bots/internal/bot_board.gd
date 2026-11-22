extends PanelContainer
## The BOT BOARD (master plan 6.2, 6.5, 6.6, 6.7): on any wall of the design room and on the
## wrist. Five pages:
##   CREW   every bot: its paint, name, type and mark, what it is doing, its charge and wear;
##          click one to rename it, paint it, raise its mark, teach it a trade, service or sell it
##   RULES  the rule cards, top to bottom: switch each on or off, change what it says, move it up,
##          add a card (section first, rush, hold, leave for the crew, a pair, inspect, charge)
##   WORK   the build by stage, the jobs in hand and who has them (TAKE OVER to do one yourself,
##          HAND BACK to give it back), and what is stuck and why
##   SHOP   every type of bot, what it does best, its price and upkeep: BUY
##   LOG    what the crew did lately

const T := preload("res://modules/ui/api/terminal_kit.gd")
const Types := preload("res://modules/bots/api/bot_types.gd")
const Rules := preload("res://modules/bots/api/bot_rules.gd")

const PAGES: PackedStringArray = ["CREW", "RULES", "WORK", "SHOP", "LOG"]
const BG := Color(0.02, 0.05, 0.09)
const CARD := Color(0.05, 0.1, 0.16)
const CARD_ON := Color(0.09, 0.17, 0.25)

var bus: Object
var px_per_m := 150.0
var fs := 15
var page := "CREW"
var selected := -1

var _tabs: HBoxContainer
var _body: VBoxContainer
var _status: Label
var _clock := 0.0
var _queued := false


func setup(bots_bus: Object, density: float) -> void:
	bus = bots_bus
	px_per_m = density
	fs = maxi(12, int(px_per_m * 0.1))
	name = "BotBoard"
	add_theme_stylebox_override("panel", T.box(BG, Color.TRANSPARENT, 0, fs * 0.5))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(fs * 0.5))
	add_child(col)
	_status = _label("", "mono_medium", fs - 2, T.DIM)
	_status.clip_text = true
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
	_body.add_theme_constant_override("separation", int(fs * 0.3))
	scroll.add_child(_body)
	bus.connect("crew_changed", _queue)
	bus.connect("said", func(_l: String) -> void: if page == "LOG": _queue())
	var build := Modules.bus("build")
	if build:
		build.connect("build_changed", _queue)
	refresh()


func _queue() -> void:
	if _queued:
		return
	_queued = true
	_later.call_deferred()


func _later() -> void:
	_queued = false
	if is_inside_tree():
		refresh()


func _process(delta: float) -> void:
	# The live lines (what each bot is doing, charge) every half second.
	_clock += delta
	if _clock >= 0.5:
		_clock = 0.0
		if page in ["CREW", "WORK"]:
			refresh()
		else:
			_status.text = status_line()


## True while the player types in one of the board's boxes (a bot's name): no rebuild then.
func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f is LineEdit and is_ancestor_of(f)


func refresh() -> void:
	_status.text = status_line()
	if _typing():
		return
	_clear(_tabs)
	for p in PAGES:
		var b := T.button(p, false, fs - 1, p == page)
		b.pressed.connect(func() -> void:
			page = p
			refresh())
		_tabs.add_child(b)
	_clear(_body)
	match page:
		"CREW":
			_crew_page()
		"RULES":
			_rules_page()
		"WORK":
			_work_page()
		"SHOP":
			_shop_page()
		"LOG":
			_log_page()


## The board's top line: the crew, the build, the upkeep.
func status_line() -> String:
	var working := 0
	for b: Dictionary in bus.crew.bots:
		if str(b.task.kind) in ["job", "help", "haul", "inspect"]:
			working += 1
	var build := Modules.bus("build")
	var p: Dictionary = build.call("progress", "") if build else {}
	var what := "berth empty" if p.is_empty() else "%s: %d of %d jobs" % [p.design_name, int(p.jobs_done), int(p.jobs)]
	return "%d BOTS · %d AT WORK · %s · UPKEEP CR %s A DAY" % [bus.crew.bots.size(), working, what.to_upper(),
			T.money(int(bus.call("upkeep_per_day")))]


# --- CREW ----------------------------------------------------------------------------------------

func _crew_page() -> void:
	for b: Dictionary in bus.crew.bots:
		_body.add_child(_bot_row(b))
		if int(b.id) == selected:
			_body.add_child(_bot_detail(b))


func _bot_row(b: Dictionary) -> Control:
	var on := int(b.id) == selected
	var card := _card(on)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(fs * 0.6))
	card.add_child(row)
	var swatch := ColorRect.new()
	swatch.color = Types.PAINTS.get(str(b.paint), T.ORANGE)
	swatch.custom_minimum_size = Vector2(fs * 0.8, fs * 2.2)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	var t := Types.info(str(b.type))
	var name_col := VBoxContainer.new()
	name_col.custom_minimum_size.x = fs * 11
	name_col.add_child(_label(str(b.name), "display_bold", fs + 2, T.TEXT))
	var sub := "%s %s · Mk%d" % [t.code, t.name, int(b.mark)]
	if b.has("role"):
		sub = "TartanCo %s · Mk%d" % [str(Types.TRADE_NAMES.get(str(b.role), "bot")).to_lower(), int(b.mark)]
	name_col.add_child(_label(sub, "mono_medium", fs - 3, T.DIM))
	row.add_child(name_col)
	var line := _label(str(b.get("line", "")), "body_medium", fs, T.TEXT)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.clip_text = true
	row.add_child(line)
	row.add_child(_meter("CHG", float(b.charge), T.GOOD if float(b.charge) > 0.3 else T.BAD))
	row.add_child(_meter("WEAR", float(b.wear), T.AMBER if float(b.wear) < 0.5 else T.BAD, true))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e: InputEvent) -> void:
		if _clicked(e):
			selected = -1 if selected == int(b.id) else int(b.id)
			refresh())
	return card


func _bot_detail(b: Dictionary) -> Control:
	if bool(bus.call("fleet_mode")):
		return _fleet_detail(b)
	var card := _card(true)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(fs * 0.4))
	card.add_child(col)
	var t := Types.info(str(b.type))
	col.add_child(_wrap(str(t.blurb), T.DIM))
	col.add_child(_label("Skills: %s%s" % [Types.skill_line(str(b.type)),
			("  ·  taught: " + ", ".join((b.modules as Array).map(func(m: String) -> String: return str(Types.MODULES[m].name)))) if not (b.modules as Array).is_empty() else ""],
			"mono_medium", fs - 2, T.CYAN))
	col.add_child(_label("Jobs %d · fastenings %d · %s worked" % [int(b.jobs), int(b.fastenings), _span(float(b.worked))], "mono_medium", fs - 2, T.DIM))
	# Name.
	var name_row := HBoxContainer.new()
	var edit := LineEdit.new()
	edit.text = str(b.name)
	edit.max_length = 18
	edit.custom_minimum_size.x = fs * 12
	edit.add_theme_font_size_override("font_size", fs)
	edit.text_submitted.connect(func(s: String) -> void: bus.call("rename", int(b.id), s))
	name_row.add_child(_label("NAME ", "display_medium", fs - 1, T.DIM))
	name_row.add_child(edit)
	var ok := T.button("RENAME", false, fs - 2)
	ok.pressed.connect(func() -> void: bus.call("rename", int(b.id), edit.text))
	name_row.add_child(ok)
	col.add_child(name_row)
	# Paint.
	var paints := HFlowContainer.new()
	paints.add_theme_constant_override("h_separation", 4)
	for pn: String in Types.PAINTS:
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(fs * 2.2, fs * 1.6)
		chip.tooltip_text = pn
		chip.focus_mode = Control.FOCUS_NONE
		var st := T.box(Types.PAINTS[pn], T.TEXT if pn == str(b.paint) else Color.TRANSPARENT, 2, 2)
		for k in ["normal", "hover", "pressed"]:
			chip.add_theme_stylebox_override(k, st)
		chip.pressed.connect(func() -> void: bus.call("repaint", int(b.id), pn))
		paints.add_child(chip)
	col.add_child(paints)
	# Upkeep and upgrades.
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 6)
	acts.add_theme_constant_override("v_separation", 6)
	var cost := Types.mark_cost(b)
	if cost > 0:
		var up := T.button("UPGRADE TO MK%d · CR %s" % [int(b.mark) + 1, T.money(cost)], true, fs - 2)
		up.pressed.connect(func() -> void: bus.call("upgrade", int(b.id)))
		acts.add_child(up)
	var free := Types.module_slots(b) - (b.modules as Array).size()
	if free > 0:
		for m: String in Types.MODULES:
			if (b.modules as Array).has(m) or Types.level(b, str(Types.MODULES[m].skill)) >= Types.MODULE_LEVEL:
				continue
			var mb := T.button("TEACH %s · CR %s" % [str(Types.MODULES[m].name).to_upper(), T.money(int(Types.MODULES[m].price))], false, fs - 3)
			mb.pressed.connect(func() -> void: bus.call("teach", int(b.id), m))
			acts.add_child(mb)
	var sv := T.button("SERVICE · CR %s" % T.money(int(bus.call("service_cost", b))), false, fs - 2)
	sv.pressed.connect(func() -> void: bus.call("service", int(b.id)))
	acts.add_child(sv)
	var sell := T.button("SELL · CR %s" % T.money(int(t.price) / 2), false, fs - 2)
	sell.pressed.connect(func() -> void:
		selected = -1
		bus.call("sell", int(b.id)))
	acts.add_child(sell)
	col.add_child(acts)
	return card


## A TartanCo fleet bot: what it does, its mark and modules from TartanCo, a service.
func _fleet_detail(b: Dictionary) -> Control:
	var card := _card(true)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(fs * 0.4))
	card.add_child(col)
	col.add_child(_wrap(FLEET_BLURB.get(str(b.get("role", "F")), ""), T.DIM))
	col.add_child(_label("Skills: %s" % Types.skill_line(str(b.type)), "mono_medium", fs - 2, T.CYAN))
	var yard := Modules.bus("yard")
	var fitted: Array = b.get("fleet_modules", [])
	var cat: Dictionary = yard.call("tartanco_catalogue") if yard else {}
	if not fitted.is_empty() and not cat.is_empty():
		col.add_child(_label("Modules: " + ", ".join(fitted.map(func(m: String) -> String: return str(cat.modules[m].name))),
				"mono_medium", fs - 2, T.CYAN))
	col.add_child(_label("Jobs %d · fastenings %d · %s worked" % [int(b.jobs), int(b.fastenings), _span(float(b.worked))], "mono_medium", fs - 2, T.DIM))
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 6)
	acts.add_theme_constant_override("v_separation", 6)
	var next := int(b.mark) + 1
	if not cat.is_empty() and (cat.marks as Dictionary).has(next):
		var up := T.button("UPGRADE TO MK%d · CR %s" % [next, T.money(int(cat.marks[next].price))], true, fs - 2)
		up.pressed.connect(func() -> void: bus.call("upgrade", int(b.id)))
		acts.add_child(up)
	var slots := int(yard.call("worker_slots", int(b.mark))) if yard else 0
	if fitted.size() < slots and not cat.is_empty():
		for m: String in cat.modules:
			if fitted.has(m):
				continue
			var mb := T.button("FIT %s · CR %s" % [str(cat.modules[m].name).to_upper(), T.money(int(cat.modules[m].price))], false, fs - 3)
			mb.tooltip_text = str(cat.modules[m].line)
			mb.pressed.connect(func() -> void: bus.call("teach", int(b.id), m))
			acts.add_child(mb)
	var sv := T.button("SERVICE · CR %s" % T.money(int(bus.call("service_cost", b))), false, fs - 2)
	sv.pressed.connect(func() -> void: bus.call("service", int(b.id)))
	acts.add_child(sv)
	col.add_child(acts)
	return card


const FLEET_BLURB := {
	"F": "TartanCo F-3 component fitter: grippers both hands. Lifts any job into place and makes any fastening, at a steady pace.",
	"W": "TartanCo W-3 welder: torch and clamp. Runs a frame's welds very fast and lifts frame members in.",
	"R": "TartanCo R-3 riveter: rivet gun and clamp. Sets hull plates, linings and the wiring's clips very fast.",
	"B": "TartanCo B-3 bolter: nut runner and clamp. Lifts pipe runs in and bolts fittings and pipes up.",
}


## The shop with TartanCo's fleet: a new bot of each trade from TartanCo, at its price.
func _fleet_shop() -> void:
	var yard := Modules.bus("yard")
	var cat: Dictionary = yard.call("tartanco_catalogue") if yard else {}
	_body.add_child(_wrap("New bots come from TartanCo, Mk1, with a charge dock of their own on the berth (room for %d). Upgrade them from the CREW page." % BotsBus.FLEET_MAX, T.DIM))
	for role: String in ["F", "W", "R", "B"]:
		if cat.is_empty() or not (cat.bots as Dictionary).has(role):
			continue
		var t := Types.info(str(Types.FLEET_TYPE[role]))
		var card := _card(false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(fs * 0.6))
		card.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label("%s  %s" % [str(Types.TARTANCO_CODES[role]), str(Types.TRADE_NAMES[role]).to_upper()], "display_bold", fs + 1, T.TEXT))
		col.add_child(_wrap(str(FLEET_BLURB[role]), T.DIM))
		col.add_child(_label(Types.skill_line(str(Types.FLEET_TYPE[role])), "mono_medium", fs - 3, T.CYAN))
		row.add_child(col)
		var price := VBoxContainer.new()
		price.add_child(_label("CR %s" % T.money(int(cat.bots[role].price)), "mono_medium", fs, T.TEXT))
		price.add_child(_label("CR %s a day" % T.money(int(t.upkeep)), "mono_medium", fs - 3, T.DIM))
		row.add_child(price)
		var buy := T.button("BUY", true, fs - 1)
		buy.pressed.connect(func() -> void: bus.call("buy", role))
		row.add_child(buy)
		_body.add_child(card)


# --- RULES ---------------------------------------------------------------------------------------

func _rules_page() -> void:
	_body.add_child(_wrap("The bots read the cards top to bottom. Switch one off to keep it for later.", T.DIM))
	var cards: Array = (bus.crew.cards as Array).duplicate(true)
	for i in cards.size():
		var c: Dictionary = cards[i]
		var card := _card(bool(c.get("on", true)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(fs * 0.5))
		card.add_child(row)
		var onb := T.button("ON" if bool(c.get("on", true)) else "OFF", bool(c.get("on", true)), fs - 2)
		onb.custom_minimum_size.x = fs * 4
		onb.pressed.connect(func() -> void:
			cards[i].on = not bool(cards[i].get("on", true))
			bus.call("set_cards", cards))
		row.add_child(onb)
		var txt := _label(Rules.text(c, func(id: int) -> String: return str(bus.crew.call("name_of", id))), "body_medium", fs + 1, T.TEXT)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)
		var args: Array = Rules.KINDS.get(str(c.kind), {}).get("args", [])
		if str(c.kind) == "pair":
			args = _pair_args()
		if args.size() > 1:
			var nx := T.button("CHANGE", false, fs - 3)
			nx.pressed.connect(func() -> void:
				var at := args.find(cards[i].arg)
				cards[i].arg = args[(at + 1) % args.size()]
				bus.call("set_cards", cards))
			row.add_child(nx)
		if i > 0:
			var upb := T.button("UP", false, fs - 3)
			upb.pressed.connect(func() -> void:
				var tmp: Dictionary = cards[i - 1]
				cards[i - 1] = cards[i]
				cards[i] = tmp
				bus.call("set_cards", cards))
			row.add_child(upb)
		var rm := T.button("X", false, fs - 3)
		rm.pressed.connect(func() -> void:
			cards.remove_at(i)
			bus.call("set_cards", cards))
		row.add_child(rm)
		_body.add_child(card)
	var add := HFlowContainer.new()
	add.add_theme_constant_override("h_separation", 6)
	add.add_theme_constant_override("v_separation", 6)
	for k: String in Rules.KINDS:
		var args: Array = Rules.KINDS[k].args if k != "pair" else _pair_args()
		if args.is_empty():
			continue
		var b := T.button("+ " + str(Rules.KINDS[k].name).to_upper(), false, fs - 2)
		b.pressed.connect(func() -> void:
			var list: Array = (bus.crew.cards as Array).duplicate(true)
			list.append({"id": "r%d" % (Time.get_ticks_usec() % 1000000), "kind": k, "arg": args[0], "on": true})
			bus.call("set_cards", list))
		add.add_child(b)
	_body.add_child(add)


## Every helper > lead pair of two bots, the first bots first.
func _pair_args() -> Array:
	var out := []
	var bots: Array = bus.crew.bots
	for a: Dictionary in bots:
		for b: Dictionary in bots:
			if int(a.id) != int(b.id):
				out.append("%d>%d" % [int(a.id), int(b.id)])
	return out


# --- WORK ----------------------------------------------------------------------------------------

func _work_page() -> void:
	var build := Modules.bus("build")
	var p: Dictionary = build.call("progress", "") if build else {}
	if p.is_empty():
		_body.add_child(_wrap("Nothing in the build berth. Sign a ship contract and her design comes to the berth: put the bots on her here.", T.DIM))
		return
	var bots_build := str(p.get("crew", "")) == BuildBus.CREW_BOTS
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(fs * 0.5))
	var title := _label("%s · %s" % [str(p.design_name).to_upper(), "the bots' build" if bots_build else "a hand build"],
			"display_bold", fs + 2, T.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var crew_b := T.button("BUILD HER BY HAND" if bots_build else "BOTS BUILD HER", not bots_build, fs - 2)
	crew_b.name = "CrewButton"
	crew_b.pressed.connect(func() -> void: bus.call("stand_down" if bots_build else "put_on_build"))
	head.add_child(crew_b)
	_body.add_child(head)
	if not bots_build:
		_body.add_child(_wrap("The crew is building her by hand, so the bots are standing by. Press BOTS BUILD HER to put them to work on her.", T.AMBER))
	var stages := HBoxContainer.new()
	stages.add_theme_constant_override("separation", int(fs * 0.5))
	for s: String in p.by_stage:
		var pair: Array = p.by_stage[s]
		stages.add_child(_meter(str(BuildPlan.STAGES[s].name).to_upper(), float(pair[0]) / maxf(1.0, float(pair[1])), T.CYAN))
	_body.add_child(stages)
	_body.add_child(_label("Workmanship %s · jobs %d of %d · %d fastenings made again by inspectors" % [
			str(p.grade) if str(p.grade) != "" else "-", int(p.jobs_done), int(p.jobs), int(bus.crew.totals.get("reworks", 0))],
			"mono_medium", fs - 2, T.DIM))
	_body.add_child(_label("IN HAND", "display_medium", fs, T.ORANGE))
	var pl: BuildPlan = build.call("plan", "")
	var claims: Dictionary = (build.call("active") as Dictionary).get("claims", {})
	var shown := 0
	for key: String in claims:
		var j := int(key)
		var who := str(claims[key])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(fs * 0.5))
		var name := _label(str(pl.jobs[j].name), "body_medium", fs, T.TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var by := "the crew (by hand)" if who == BuildBus.CREW_CLAIM else str(bus.crew.call("name_of", int(who.get_slice(":", 1))))
		row.add_child(_label(by, "mono_medium", fs - 1, T.CYAN if who == BuildBus.CREW_CLAIM else T.DIM))
		if who == BuildBus.CREW_CLAIM:
			var hb := T.button("HAND BACK", false, fs - 3)
			hb.pressed.connect(func() -> void: bus.call("hand_back", j))
			row.add_child(hb)
		else:
			var tb := T.button("TAKE OVER", true, fs - 3)
			tb.pressed.connect(func() -> void: bus.call("take_over", j))
			row.add_child(tb)
		var card := _card(false)
		card.add_child(row)
		_body.add_child(card)
		shown += 1
	if shown == 0:
		_body.add_child(_wrap("No job in hand.", T.DIM))
	var free: Array = build.call("free_jobs", "")
	if not free.is_empty():
		var row := HBoxContainer.new()
		var l := _label("Next free: %s" % pl.jobs[int(free[0])].name, "body_medium", fs, T.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var tb := T.button("DO IT BY HAND", false, fs - 3)
		tb.pressed.connect(func() -> void: bus.call("take_over", int(free[0])))
		row.add_child(tb)
		_body.add_child(row)
	_body.add_child(_label("STUCK", "display_medium", fs, T.BAD))
	var stuck: Array = bus.crew.stuck
	if stuck.is_empty():
		_body.add_child(_wrap("Nothing is stuck.", T.DIM))
	for s: Dictionary in stuck:
		_body.add_child(_label("%s: %s" % [s.what, s.why], "body_medium", fs, T.AMBER))


# --- SHOP ----------------------------------------------------------------------------------------

func _shop_page() -> void:
	var business := Modules.bus("business")
	if business and business.has_method("get_cash"):
		_body.add_child(_label("Company cash CR %s" % T.money(int(business.call("get_cash"))), "mono_medium", fs, T.GOOD))
	if bool(bus.call("fleet_mode")):
		_fleet_shop()
		return
	for id in Types.ORDER:
		var t := Types.info(id)
		var card := _card(false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(fs * 0.6))
		card.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label("%s  %s" % [t.code, str(t.name).to_upper()], "display_bold", fs + 1, T.TEXT))
		col.add_child(_wrap(str(t.blurb), T.DIM))
		col.add_child(_label(Types.skill_line(id), "mono_medium", fs - 3, T.CYAN))
		row.add_child(col)
		var price := VBoxContainer.new()
		price.add_child(_label("CR %s" % T.money(int(t.price)), "mono_medium", fs, T.TEXT))
		price.add_child(_label("CR %s a day" % T.money(int(t.upkeep)), "mono_medium", fs - 3, T.DIM))
		row.add_child(price)
		var buy := T.button("BUY", true, fs - 1)
		buy.pressed.connect(func() -> void: bus.call("buy", id))
		row.add_child(buy)
		_body.add_child(card)


func _log_page() -> void:
	var lines: PackedStringArray = bus.log_lines
	if lines.is_empty():
		_body.add_child(_wrap("Nothing yet.", T.DIM))
	for i in range(lines.size() - 1, -1, -1):
		_body.add_child(_label(lines[i], "body_medium", fs, T.TEXT if i == lines.size() - 1 else T.DIM))


# --- Bits ----------------------------------------------------------------------------------------

func _card(on: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(CARD_ON if on else CARD, T.ORANGE if on else Color.TRANSPARENT, 1 if on else 0, fs * 0.4))
	return p


func _meter(what: String, v: float, colour: Color, wear := false) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = fs * 5
	col.add_child(_label("%s %d%%" % [what, roundi(v * 100.0)], "mono_medium", fs - 3, T.DIM))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = v
	bar.custom_minimum_size = Vector2(fs * 5, fs * 0.45)
	bar.add_theme_stylebox_override("background", T.box(Color(0.1, 0.12, 0.15)))
	bar.add_theme_stylebox_override("fill", T.box(colour))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wear:
		col.tooltip_text = "Serviced at the bay past %d%%" % roundi(0.6 * 100.0)
	return col


func _label(text: String, face: String, size: int, col: Color) -> Label:
	var l := T.label(text, face, size, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(text: String, col: Color) -> Label:
	var l := _label(text, "body_medium", fs - 1, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = fs * 20
	return l


static func _span(s: float) -> String:
	if s < 60.0:
		return "%d s" % roundi(s)
	if s < 3600.0:
		return "%d min" % roundi(s / 60.0)
	return "%.1f h" % (s / 3600.0)


static func _clicked(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT


static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
