extends VBoxContainer
## Esc > Settings > Gameplay > Game time: the pace of the calendar (paused to x4), and
## skipping ahead to a date. The host sets them; a guest sees them read-only.

const T := preload("res://modules/ui/api/terminal_kit.gd")
## Times of day a skip can land on (game minutes into the day).
const SKIP_TIMES: Array[int] = [8 * 60, 12 * 60, 18 * 60]

var bus: TimeBus
var _now_label: Label
var _pace_row: HBoxContainer
var _pace_help: Label
var _day_box: SpinBox
var _time_pick: OptionButton
var _skip_button: Button
var _skip_note: Label
var _coming: VBoxContainer
var _tick := 0.0


func setup(time_bus: TimeBus) -> void:
	bus = time_bus
	name = "GameTime"
	add_theme_constant_override("separation", 8)
	_now_label = T.label("", "mono_medium", 20, T.TEXT)
	_now_label.name = "Now"
	add_child(_now_label)

	add_child(_heading("PACE"))
	_pace_row = HBoxContainer.new()
	_pace_row.name = "Pace"
	_pace_row.add_theme_constant_override("separation", 6)
	add_child(_pace_row)
	_pace_help = _note("")
	_pace_help.name = "PaceHelp"
	add_child(_pace_help)
	add_child(_note("Bots, haulers, delivery ships and TartanCo work at the same pace as the calendar. "
			+ "Paused stops both; doors and airlocks still work. At x1 a day is 12 minutes, so a "
			+ "3 hour evening is about 15 days: a small ship (15 to 30 days) is one or two evenings, "
			+ "a large one (40 to 75 days) several."))

	add_child(_heading("SKIP AHEAD"))
	var row := HBoxContainer.new()
	row.name = "SkipRow"
	row.add_theme_constant_override("separation", 8)
	row.add_child(T.label("To day", "body", 17, T.DIM))
	_day_box = SpinBox.new()
	_day_box.name = "Day"
	_day_box.step = 1
	_day_box.custom_minimum_size.x = 110
	_day_box.value_changed.connect(func(_v: float) -> void: _show_target())
	row.add_child(_day_box)
	row.add_child(T.label("at", "body", 17, T.DIM))
	_time_pick = OptionButton.new()
	_time_pick.name = "Time"
	for m in SKIP_TIMES:
		_time_pick.add_item("%02d:%02d" % [m / 60, m % 60])
	_time_pick.item_selected.connect(func(_i: int) -> void: _show_target())
	row.add_child(_time_pick)
	_skip_button = T.button("SKIP", true, 17)
	_skip_button.name = "Skip"
	_skip_button.pressed.connect(_skip)
	row.add_child(_skip_button)
	add_child(row)
	var quick := HBoxContainer.new()
	quick.name = "Quick"
	quick.add_theme_constant_override("separation", 6)
	var morning := T.button("NEXT MORNING", false, 17)
	morning.name = "NextMorning"
	morning.pressed.connect(func() -> void: bus.skip_to_morning())
	quick.add_child(morning)
	var week := T.button("A WEEK ON", false, 17)
	week.name = "AWeekOn"
	week.pressed.connect(func() -> void: bus.skip_to(TimeBus.minute_of(bus.day() + 7, TimeBus.MORNING)))
	quick.add_child(week)
	add_child(quick)
	_skip_note = _note("")
	_skip_note.name = "SkipNote"
	add_child(_skip_note)
	add_child(_note("Each day skipped closes as it would have: rent and wages are paid, the market moves, "
			+ "parts on their way arrive and payments fall due. Work the bots have under way does not jump "
			+ "ahead, so skip when the yard is waiting, and use a faster pace while they work."))

	add_child(_heading("COMING UP"))
	_coming = VBoxContainer.new()
	_coming.name = "ComingUp"
	add_child(_coming)

	bus.rate_changed.connect(func(_r: float) -> void: refresh())
	bus.skipped.connect(func(_a: int, _b: int) -> void: refresh())
	refresh()


func _heading(text: String) -> Label:
	return T.label(text, "display_medium", 17, T.ORANGE)


func _note(text: String) -> Label:
	var l := T.label(text, "body", 16, T.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 480
	return l


## Rebuilds everything from the bus (a new pace, a skip, the host's word).
func refresh() -> void:
	var control := bus.can_control()
	for c in _pace_row.get_children():
		_pace_row.remove_child(c)
		c.queue_free()
	for r: float in TimeBus.RATES:
		var b := T.button(TimeBus.rate_text(r).to_upper(), false, 19, is_equal_approx(r, bus.rate))
		b.name = "Rate_" + ("half" if is_equal_approx(r, 0.5) else TimeBus.rate_text(r).validate_node_name())
		b.disabled = not control
		b.pressed.connect(func() -> void: bus.set_rate(r))
		_pace_row.add_child(b)
	if bus.rate <= 0.0:
		_pace_help.text = "Paused: the calendar and the yard's work are stopped."
	else:
		_pace_help.text = "A game day takes %s of real time at %s." % [TimeBus.span_text(bus.day_seconds()), TimeBus.rate_text(bus.rate)]
	if not control:
		_pace_help.text += " The host sets the pace and skips ahead."
	var today := bus.day()
	_day_box.min_value = today + 1
	_day_box.max_value = today + 1 + TimeBus.MAX_SKIP_DAYS
	if _day_box.value <= today + 1 or _day_box.value > _day_box.max_value:
		_day_box.set_value_no_signal(today + 2)
	_day_box.editable = control
	_time_pick.disabled = not control
	_skip_button.disabled = not control
	for b in get_node("Quick").get_children():
		(b as Button).disabled = not control
	_fill_coming(control)
	_show_target()
	_update_now()


## The day box counts from 1, as the screens do; the bus counts from 0.
func target_minute() -> int:
	return TimeBus.minute_of(int(_day_box.value) - 1, SKIP_TIMES[maxi(0, _time_pick.selected)])


func _show_target() -> void:
	var to := target_minute()
	var days := float(to - bus.now_minute()) / TimeBus.MINUTES_PER_DAY
	if bus.last_skip.is_empty():
		_skip_note.text = "Skips %.1f days, to %s." % [days, TimeBus.date_text(to)]
	else:
		_skip_note.text = "Last skip: %s to %s. This one skips %.1f days." % [TimeBus.date_text(int(bus.last_skip.from)),
				TimeBus.date_text(int(bus.last_skip.to)), days]


func _skip() -> void:
	bus.skip_to(target_minute())


func _fill_coming(control: bool) -> void:
	for c in _coming.get_children():
		_coming.remove_child(c)
		c.queue_free()
	var list := bus.coming_up()
	if list.is_empty():
		_coming.add_child(_note("Nothing dated yet: parts on order, payments and contract due days show here."))
		return
	for e: Dictionary in list:
		var b := T.button("%s   %s" % [TimeBus.date_text(int(e.minute)), str(e.what)], false, 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not control
		b.tooltip_text = "Skip to this"
		var at := int(e.minute)
		b.pressed.connect(func() -> void: bus.skip_to(at))
		_coming.add_child(b)


func _update_now() -> void:
	_now_label.text = "NOW  %s   ·   %s" % [TimeBus.date_text(bus.now_minute()).to_upper(), TimeBus.rate_text(bus.rate).to_upper()]


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0 and bus:
		_tick = 0.5
		_update_now()
