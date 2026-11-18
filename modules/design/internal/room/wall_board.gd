extends PanelContainer
## A whole wall of the design room as one interactive surface (beenster, 18 Nov: "instead of
## TV screens the walls themselves should be interactive"). The wall is split into panels side
## by side; each shows one view of the open design (a deck plan, the side or end elevation, the
## parts and cost channel) and has a header with < and > to change what it shows, so anyone in
## the room can put up what they need. Shown on a TouchScreen that covers the wall's plane.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")
const DataChannel := preload("res://modules/design/internal/views/data_channel.gd")
const Whiteboard := preload("res://modules/design/internal/views/whiteboard.gd")

## Every view a panel can show, in the order < and > step through. "plan:<deck>" for decks.
const BASE_VIEWS: PackedStringArray = ["side", "end", "data", "modules", "whiteboard"]
const VIEW_NAMES := {"side": "SIDE ELEVATION", "end": "END ELEVATION", "data": "PARTS, COST AND CHECKS",
		"modules": "READY-MADE MODULES", "whiteboard": "WHITEBOARD"}
## Decks offered even before the design has them (so a panel can wait on deck 2).
const MIN_DECKS := 2

var bus: DesignBus
var wall_id := ""
## Pixels per metre the wall is drawn at (sizes text so it reads from across the room).
var px_per_m := 150.0
## One entry per panel: {view, share (of the wall's width)}.
var panels: Array[Dictionary] = []
var _row: HBoxContainer
var _slots: Array[Control] = []


func setup(design_bus: DesignBus, id: String, layout: Array, density: float) -> void:
	bus = design_bus
	wall_id = id
	px_per_m = density
	name = "Wall_" + id
	add_theme_stylebox_override("panel", T.box(Color(0.02, 0.05, 0.09), Color(0.2, 0.45, 0.65, 0.6), 2, 0.0))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", int(px_per_m * 0.12))
	add_child(_row)
	for p in layout:
		panels.append({"view": str(p[0]), "share": float(p[1])})
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_stretch_ratio = float(p[1])
		slot.add_theme_constant_override("separation", 0)
		_row.add_child(slot)
		_slots.append(slot)
		_fill(_slots.size() - 1)
	bus.design_changed.connect(_refresh_titles)


## The views a panel can step through for the open design.
func views() -> PackedStringArray:
	var out := PackedStringArray()
	var decks := MIN_DECKS
	var rec := bus.library.current if bus else null
	if rec and not rec.rooms.is_empty():
		decks = maxi(decks, (rec.decks()[rec.decks().size() - 1] as int) + 1)
	for d in decks:
		out.append("plan:%d" % d)
	out.append_array(BASE_VIEWS)
	return out


static func view_name(view: String) -> String:
	if view.begins_with("plan:"):
		return "DECK %d PLAN" % (int(view.get_slice(":", 1)) + 1)
	return VIEW_NAMES.get(view, view.to_upper())


## Steps panel `i` to the next (or previous) view.
func step(i: int, by: int) -> void:
	var all := views()
	var at := all.find(str(panels[i].view))
	panels[i].view = all[posmod(at + by, all.size())]
	_fill(i)


func set_view(i: int, view: String) -> void:
	panels[i].view = view
	_fill(i)


## The control panel `i` shows now (a PlanView, a DataChannel, a Whiteboard or the modules).
func content(i: int) -> Control:
	var slot := _slots[i]
	return slot.get_child(1) as Control if slot.get_child_count() > 1 else null


func _fill(i: int) -> void:
	var slot := _slots[i]
	for c in slot.get_children():
		slot.remove_child(c)
		c.queue_free()
	var view := str(panels[i].view)
	var font := int(px_per_m * 0.16)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", T.box(Color(0.06, 0.13, 0.2), Color.TRANSPARENT, 0, px_per_m * 0.04))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(px_per_m * 0.08))
	head.add_child(bar)
	var prev := T.button("<", false, font)
	prev.name = "Prev"
	prev.pressed.connect(step.bind(i, -1))
	bar.add_child(prev)
	var title := T.label(view_name(view), "display_bold", font, T.TEXT)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var next := T.button(">", false, font)
	next.name = "Next"
	next.pressed.connect(step.bind(i, 1))
	bar.add_child(next)
	slot.add_child(head)
	var body: Control
	if view == "modules":
		body = _modules_list(font)
	elif view == "whiteboard":
		var wb := Whiteboard.new()
		wb.setup(bus, font)
		body = wb
	elif view == "data":
		var dc := DataChannel.new()
		dc.setup(bus, false)
		body = dc
	else:
		var pv := PlanView.new()
		if view.begins_with("plan:"):
			pv.setup(bus, PlanView.PLAN, false)
			pv.deck = int(view.get_slice(":", 1))
		else:
			pv.setup(bus, view, false)
		pv.auto_frame = true
		body = pv
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_child(body)


## The ready-made modules as big buttons: press one to pick it up, then press a plan (on this
## wall, another, or the table's) to drop it there.
func _modules_list(font: int) -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(px_per_m * 0.06))
	scroll.add_child(col)
	var fill := func() -> void:
		for c in col.get_children():
			col.remove_child(c)
			c.queue_free()
		var mods := bus.library.modules()
		if mods.is_empty():
			col.add_child(T.label("No modules yet. At the table, select a room and SAVE AS MODULE.", "body", font, T.DIM))
		for m in mods:
			var carried: bool = bus.carrying == str(m.id)
			var b := T.button(("CARRYING  " if carried else "") + str(m.name).to_upper()
					+ "   %s x %s m   %d parts" % [_m(float(m.room.w)), _m(float(m.room.d)), (m.components as Array).size()],
					carried, font)
			b.name = "Module_" + str(m.id)
			b.pressed.connect(func() -> void: bus.carry("" if bus.carrying == str(m.id) else str(m.id)))
			col.add_child(b)
	fill.call()
	var on_carry := func(_id: String) -> void: fill.call()
	bus.library.modules_changed.connect(fill)
	bus.carry_changed.connect(on_carry)
	scroll.tree_exiting.connect(func() -> void:
		bus.library.modules_changed.disconnect(fill)
		bus.carry_changed.disconnect(on_carry))
	return scroll


static func _m(v: float) -> String:
	return ("%d" % int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)


func _refresh_titles() -> void:
	for i in _slots.size():
		var t := _slots[i].find_child("Title", true, false) as Label
		if t:
			t.text = view_name(str(panels[i].view))
