extends Control
## The design console: what you see when you work at the holotable (plan 2.2 to 2.7). The
## room palette and components on the left, the deck plan in the middle (the main way to
## design), the holotable's view and the live data channel on the right, and the design
## saves along the top.
##
## Keys: Ctrl+Z undo, Ctrl+Y or Ctrl+Shift+Z redo, Ctrl+S save, R turn, Delete remove,
## Page Up / Page Down change deck.

signal leave_requested
## WALK INSIDE: walk through the open design at full size (DesignFurnishing.open_walk).
signal walk_requested

const T := preload("res://modules/ui/api/terminal_kit.gd")
const PlanView := preload("res://modules/design/internal/views/plan_view.gd")
const DataChannel := preload("res://modules/design/internal/views/data_channel.gd")
const ContractFit := preload("res://modules/design/internal/views/contract_fit.gd")
const ContractTerms := preload("res://modules/design/internal/views/contract_terms.gd")
const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")
const DockPanel := preload("res://modules/design/internal/console/dock_panel.gd")
const ScaledBox := preload("res://modules/design/internal/console/scaled_box.gd")
const ConsoleLayout := preload("res://modules/design/internal/console/console_layout.gd")

var bus: DesignBus
var holo: HoloTable
var plan: PlanView
var data: DataChannel

var _title: Label
## The layout as this player left it (ConsoleLayout), and the docked panels by id.
var layout: Dictionary = {}
var panels: Dictionary = {}
var _docks: Dictionary = {}
var _dock_boxes: Dictionary = {}
var _outer: HSplitContainer
var _inner: HSplitContainer
var _top_box: Control
var _window: MenuButton
var _deck_label: Label
## The palette section being filled: one of `_sections`, each the body of its own panel.
var _palette: VBoxContainer
var _sections: Dictionary = {}
## The palette's sections, each its own panel (beenster, 20 Nov: "Modules, Contract, Rooms,
## Components, Hull Design, Views").
const SECTIONS: PackedStringArray = ["contract", "tools", "rooms", "modules", "hull", "components"]
## The side or end elevation beside the plan (the "views" panel).
var side_view: PlanView
## Size class and grade new components are picked in (0 = each type's own size).
var _pick_size := 0
var _pick_grade := DesignGrades.DEFAULT_GRADE
## The class (grade) filter: "" = any (placed as Standard).
var _class_filter := ""
## Component groups open on the palette (category -> true).
var _open_groups: Dictionary = {"flight": true}
## The components search text, and the list it filters (rebuilt alone as you type).
var _comp_search := ""
var _comp_list: VBoxContainer
## Door kind buttons under the tools (kind -> Button).
var _door_buttons: Dictionary = {}
var _room_pick: MenuButton
## The room type last armed, shown on the room drop-down.
var _last_room := ""
var _grid_pick: OptionButton
## The ship order list is open on the palette.
var _orders_open := false
## The order id the palette shows, to refill it when an undo or a crewmate changes it.
var _shown_order := ""
var _selection: VBoxContainer
var _tool_buttons: Dictionary = {}
var _view_buttons: Dictionary = {}
var _library_panel: PanelContainer
var _holo_view: SubViewport
var _holo_cam: Camera3D
var _cam_turn := 0.0
var _cam_pitch := 0.55
var _cam_dist := 7.2
## How close the 3D window's camera is (1 = the whole design fills it), wheel to change.
var view_zoom := 1.0
const VIEW_ZOOM_STEP := 1.15
const VIEW_ZOOM_MIN := 0.6
const VIEW_ZOOM_MAX := 6.0
var _dragging_holo := false


func setup(design_bus: DesignBus, table: HoloTable) -> void:
	bus = design_bus
	holo = table
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	bus.design_changed.connect(_refresh_bar)
	bus.library.modules_changed.connect(_fill_palette)
	bus.library.opened.connect(func(_r: DesignRecord) -> void: _fill_palette())
	if bus.library.current == null:
		var list := bus.library.list()
		if list.is_empty():
			bus.library.create("First design")
		else:
			bus.library.open(list[0].id)
	_refresh_bar()
	_fill_palette()
	plan.frame_all.call_deferred()
	var contracts := Modules.bus("contracts")
	if contracts and contracts.has_signal("ship_contract_changed"):
		contracts.connect("ship_contract_changed", _on_contract_changed)
		contracts.connect("board_changed", _on_contract_changed.bind(""))


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	layout = ConsoleLayout.load_layout()
	_top_box = ScaledBox.new(float(layout.text))
	_top_box.add_child(_top_bar())
	root.add_child(_top_box)
	root.add_child(T.HazardRule.new(6.0))
	# The panels dock either side of the plan, after Photoshop's (beenster, 20 Nov): drag the
	# dividers for width, a panel's foot for height; its title bar moves, folds and hides it.
	_outer = HSplitContainer.new()
	_outer.name = "Body"
	_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_outer)
	for side: String in ["left", "right"]:
		var dock := VBoxContainer.new()
		dock.name = "Dock" + side.capitalize()
		dock.add_theme_constant_override("separation", 3)
		dock.custom_minimum_size.x = 240
		var box := ScaledBox.new(float(layout.text))
		box.name = "Scaled" + side.capitalize()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(dock)
		_docks[side] = dock
		_dock_boxes[side] = box
	_outer.add_child(_dock_boxes.left)
	_inner = HSplitContainer.new()
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner.size_flags_stretch_ratio = 3.2
	_outer.add_child(_inner)
	plan = PlanView.new()
	plan.name = "Plan"
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan.size_flags_stretch_ratio = 2.2
	plan.setup(bus, PlanView.PLAN, true)
	plan.selection_changed.connect(_on_selection)
	plan.tool_changed.connect(func(_t: String) -> void: _mark_tools())
	_inner.add_child(plan)
	_inner.add_child(_dock_boxes.right)
	_outer.split_offset = int(layout.left)
	_inner.split_offset = int(layout.right)
	_outer.dragged.connect(func(o: int) -> void:
		layout.left = o
		_save_layout())
	_inner.dragged.connect(func(o: int) -> void:
		layout.right = o
		_save_layout())
	_crew_feed = T.label("", "body_medium", 17, T.TEXT)
	_crew_feed.name = "CrewFeed"
	_crew_feed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_crew_feed.position = Vector2(16, -120)
	_crew_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_crew_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.add_child(_crew_feed)
	bus.crew_edited.connect(_on_crew_edited)
	_selection = VBoxContainer.new()
	_selection.add_theme_constant_override("separation", 4)
	for sec: String in SECTIONS:
		var box := VBoxContainer.new()
		box.name = "Section_" + sec
		box.add_theme_constant_override("separation", 4)
		_sections[sec] = box
	_palette = _sections.tools
	data = DataChannel.new()
	data.name = "Data"
	data.lists = false
	data.setup(bus, true)
	data.assessment_requested.connect(toggle_assessment)
	data.problem_picked.connect(go_to_problem)
	var bodies := {"selection": _scrolled(_selection), "holo": _holo_panel(), "data": data, "views": _side_panel()}
	for sec: String in SECTIONS:
		bodies[sec] = _scrolled(_sections[sec])
	for id: String in ConsoleLayout.PANELS:
		var dp := DockPanel.new()
		dp.setup(id, str(ConsoleLayout.PANELS[id].title), bodies[id])
		dp.move_requested.connect(move_panel)
		dp.swap_requested.connect(swap_panel)
		dp.hide_requested.connect(func(pid: String) -> void: show_panel(pid, false))
		dp.collapse_changed.connect(func(pid: String, on: bool) -> void:
			layout.panels[pid].collapsed = on
			_save_layout())
		dp.height_dragged.connect(_resize_panel)
		panels[id] = dp
	_arrange()
	_library_panel = _make_library_panel()
	_library_panel.visible = false
	add_child(_library_panel)


## The crew's last few edits, newest last, each fading after a few seconds.
var _crew_feed: Label
var _crew_lines: Array = []   # [text, until msec]


func _on_crew_edited(who: String, colour: Color, what: String) -> void:
	_crew_lines.append(["%s %s" % [who, what], Time.get_ticks_msec() + 6000])
	if _crew_lines.size() > 4:
		_crew_lines.pop_front()
	_crew_feed.modulate = colour.lerp(Color.WHITE, 0.4)
	_show_crew_feed()
	get_tree().create_timer(6.1).timeout.connect(_show_crew_feed)


func _show_crew_feed() -> void:
	if not is_instance_valid(_crew_feed):
		return
	var now := Time.get_ticks_msec()
	_crew_lines = _crew_lines.filter(func(l): return int(l[1]) > now)
	_crew_feed.text = "\n".join(_crew_lines.map(func(l): return str(l[0])))


func _exit_tree() -> void:
	if bus and bus.crew_edited.is_connected(_on_crew_edited):
		bus.crew_edited.disconnect(_on_crew_edited)


func _top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", T.box(T.KIOSK, T.EDGE, 0, 8.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	bar.add_child(h)
	h.add_child(T.label("BSX DESIGN OFFICE", "display_bold", 24, T.ORANGE))
	_title = T.label("", "body_medium", 20, T.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	h.add_child(_title)
	for spec in [["NEW", _on_new], ["DESIGNS", _toggle_library], ["SAVE", _on_save], ["SAVE AS", _on_save_as],
			["UNDO", func() -> void: bus.editor.undo()], ["REDO", func() -> void: bus.editor.redo()]]:
		var b := T.button(spec[0], spec[0] == "SAVE", 17)
		b.pressed.connect(spec[1])
		b.name = "Btn" + str(spec[0]).replace(" ", "")
		h.add_child(b)
	h.add_child(_gap(16))
	for v in [PlanView.PLAN, PlanView.SIDE, PlanView.END]:
		var b := T.button(v.to_upper(), false, 17, v == PlanView.PLAN)
		b.pressed.connect(_set_view.bind(v))
		_view_buttons[v] = b
		h.add_child(b)
	# Symmetry mode: what is drawn on one side is drawn on the other (M on the plan too).
	var mirror := T.button("MIRROR OFF", false, 17)
	mirror.name = "BtnMirror"
	mirror.tooltip_text = "Symmetry: draw on one side and it is drawn on the other. X mirrors port and starboard, Y fore and aft."
	mirror.pressed.connect(bus.cycle_mirror)
	bus.mirror_changed.connect(func(a: int) -> void: mirror.text = "MIRROR " + DesignMirror.NAMES[a])
	h.add_child(mirror)
	h.add_child(_gap(16))
	var down := T.button("DECK -", false, 17)
	down.pressed.connect(func() -> void: _change_deck(-1))
	h.add_child(down)
	_deck_label = T.label("DECK 1", "mono_bold", 18, T.TEXT)
	h.add_child(_deck_label)
	var up := T.button("DECK +", false, 17)
	up.pressed.connect(func() -> void: _change_deck(1))
	h.add_child(up)
	h.add_child(_gap(16))
	h.add_child(T.label("GRID", "display_medium", 16, T.DIM))
	# Snapping from 5 cm to 2 m (beenster, 19 Nov: "grid as low as 0.05").
	_grid_pick = OptionButton.new()
	_grid_pick.name = "GridPick"
	_grid_pick.add_theme_font_size_override("font_size", 16)
	for g in DesignRecord.GRIDS:
		_grid_pick.add_item(PlanView._m(g) + " m")
	_grid_pick.item_selected.connect(func(i: int) -> void:
		bus.editor.do({"op": "set_meta", "fields": {"grid": DesignRecord.GRIDS[i]}}))
	h.add_child(_grid_pick)
	# Buttons other modules put here (DesignBus.register_console_tool: the motion module's OPERATE).
	var tools := HBoxContainer.new()
	tools.name = "ConsoleTools"
	tools.add_theme_constant_override("separation", 6)
	h.add_child(tools)
	_fill_tools(tools)
	bus.console_tools_changed.connect(_fill_tools.bind(tools))
	h.add_child(_window_menu())
	var walk := T.button("WALK INSIDE", true, 17)
	walk.name = "BtnWalkInside"
	walk.pressed.connect(func() -> void: walk_requested.emit())
	h.add_child(walk)
	var leave := T.button("LEAVE", false, 17)
	leave.pressed.connect(func() -> void: leave_requested.emit())
	h.add_child(leave)
	return bar


func _fill_tools(box: HBoxContainer) -> void:
	if not is_instance_valid(box):
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var ids: Array = bus.console_tools.keys()
	ids.sort_custom(func(a, b) -> bool: return int(bus.console_tools[a].order) < int(bus.console_tools[b].order))
	for id: String in ids:
		var t: Dictionary = bus.console_tools[id]
		var b := T.button(str(t.label), false, 17)
		b.name = "Tool_" + id.replace(".", "_")
		b.tooltip_text = str(t.get("tip", ""))
		var press: Callable = t.press
		b.pressed.connect(func() -> void: press.call())
		box.add_child(b)


## The side and end elevations beside the plan (beenster, 20 Nov: "plan, side and 3D views in
## the same interface"): a drawing that follows the design, SIDE or END at the top.
func _side_panel() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	col.add_child(row)
	side_view = PlanView.new()
	side_view.name = "SideView"
	side_view.setup(bus, PlanView.SIDE, false)
	side_view.auto_frame = true
	side_view.show_title = false
	side_view.custom_minimum_size.y = 120
	side_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for v: String in [PlanView.SIDE, PlanView.END]:
		var b := T.button(v.to_upper(), false, 13)
		b.name = "SideMode_" + v
		b.pressed.connect(func() -> void:
			side_view.mode = v
			side_view.frame_all())
		row.add_child(b)
	col.add_child(side_view)
	return col


## A panel's contents in a scroll that only scrolls up and down.
static func _scrolled(c: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(c)
	return scroll


## Puts every panel in its dock, in order, folded or hidden as the layout says; a dock with
## nothing showing gives its room to the plan.
func _arrange() -> void:
	for id: String in panels:
		var dp: Control = panels[id]
		if dp.get_parent():
			dp.get_parent().remove_child(dp)
	for side: String in ["left", "right"]:
		var ids: Array = panels.keys().filter(func(i): return str(layout.panels[i].dock) == side)
		ids.sort_custom(func(a, b) -> bool: return int(layout.panels[a].order) < int(layout.panels[b].order))
		var showing := 0
		for i in ids.size():
			var id: String = ids[i]
			layout.panels[id].order = i
			var dp: DockPanel = panels[id]
			dp.ratio = float(layout.panels[id].ratio)
			dp.set_collapsed(bool(layout.panels[id].collapsed))
			dp.visible = not bool(layout.panels[id].hidden)
			if dp.visible:
				showing += 1
			(_docks[side] as Control).add_child(dp)
		(_dock_boxes[side] as Control).visible = showing > 0
	_mark_window_menu()


## Moves a panel up (-1) or down (+1) its dock.
func move_panel(id: String, by: int) -> void:
	var side := str(layout.panels[id].dock)
	var ids: Array = panels.keys().filter(func(i): return str(layout.panels[i].dock) == side)
	ids.sort_custom(func(a, b) -> bool: return int(layout.panels[a].order) < int(layout.panels[b].order))
	var at := ids.find(id)
	var to := clampi(at + by, 0, ids.size() - 1)
	ids.remove_at(at)
	ids.insert(to, id)
	for i in ids.size():
		layout.panels[ids[i]].order = i
	_arrange()
	_save_layout()


## Moves a panel to the bottom of the other dock.
func swap_panel(id: String) -> void:
	var to := "right" if str(layout.panels[id].dock) == "left" else "left"
	layout.panels[id].dock = to
	layout.panels[id].order = 99
	layout.panels[id].hidden = false
	_arrange()
	_save_layout()


## Shows or hides a panel (WINDOW menu; a panel's X hides it).
func show_panel(id: String, on: bool) -> void:
	layout.panels[id].hidden = not on
	_arrange()
	_save_layout()


## A panel's foot dragged `dy` px: it takes height from the panel below it (or gives it).
func _resize_panel(id: String, dy: float) -> void:
	var dp: DockPanel = panels[id]
	var dock := dp.get_parent() as Control
	if dock == null or dock.size.y < 1.0:
		return
	var total := 0.0
	for c in dock.get_children():
		if c is DockPanel and (c as DockPanel).visible and not (c as DockPanel).collapsed:
			total += (c as DockPanel).ratio
	var step := dy / dock.size.y * total
	dp.ratio += step
	layout.panels[id].ratio = dp.ratio
	var below: DockPanel = null
	for c in dock.get_children().slice(dp.get_index() + 1):
		if c is DockPanel and (c as DockPanel).visible and not (c as DockPanel).collapsed:
			below = c
			break
	if below:
		below.ratio -= step
		layout.panels[below.id].ratio = below.ratio
	_save_layout.call_deferred()


## Sets the console's text size (WINDOW menu): 1 normal, down to ConsoleLayout's smallest.
func set_text_size(f: float) -> void:
	layout.text = f
	_top_box.factor = f
	for side: String in _dock_boxes:
		(_dock_boxes[side] as ScaledBox).factor = f
	_mark_window_menu()
	_save_layout()


## Back to the layout the console comes with.
func reset_layout() -> void:
	layout = ConsoleLayout.defaults()
	_outer.split_offset = 0
	_inner.split_offset = 0
	set_text_size(1.0)
	_arrange()
	_save_layout()


func _save_layout() -> void:
	ConsoleLayout.save_layout(layout)


## The WINDOW menu, as in Photoshop: tick a panel to show it, the text sizes, reset.
func _window_menu() -> MenuButton:
	var b := _menu_button("WINDOW", 17)
	b.name = "WindowMenu"
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.clip_text = false
	b.tooltip_text = "Show or hide panels, text size, reset the layout"
	var pop := b.get_popup()
	pop.hide_on_checkable_item_selection = false
	var ids: Array = ConsoleLayout.PANELS.keys()
	for i in ids.size():
		pop.add_check_item(str(ConsoleLayout.PANELS[ids[i]].title).capitalize(), i)
	pop.add_separator("Text size")
	for j in ConsoleLayout.TEXT_SIZES.size():
		pop.add_radio_check_item(str(ConsoleLayout.TEXT_SIZES[j][0]), 100 + j)
	pop.add_separator()
	pop.add_item("Reset layout", 200)
	pop.id_pressed.connect(func(id: int) -> void:
		if id < 100:
			show_panel(ids[id], bool(layout.panels[ids[id]].hidden))
		elif id < 200:
			set_text_size(float(ConsoleLayout.TEXT_SIZES[id - 100][1]))
		else:
			reset_layout.call_deferred())
	_window = b
	return b


func _mark_window_menu() -> void:
	if _window == null or not is_instance_valid(_window):
		return
	var pop := _window.get_popup()
	var ids: Array = ConsoleLayout.PANELS.keys()
	for i in ids.size():
		pop.set_item_checked(pop.get_item_index(i), not bool(layout.panels[ids[i]].hidden))
	for j in ConsoleLayout.TEXT_SIZES.size():
		pop.set_item_checked(pop.get_item_index(100 + j), is_equal_approx(float(layout.text), float(ConsoleLayout.TEXT_SIZES[j][1])))


func _fill_palette() -> void:
	for sec: String in _sections:
		for c in (_sections[sec] as Control).get_children():
			(_sections[sec] as Control).remove_child(c)
			c.queue_free()
	_tool_buttons = {}
	_door_buttons = {}
	_palette = _sections.contract
	_fill_orders()
	_palette = _sections.tools
	var tools := HBoxContainer.new()
	for spec in [["select", "SELECT"], ["door", "DOOR"]]:
		var b := T.button(spec[1], false, 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(plan.set_tool.bind(spec[0]))
		_tool_buttons[spec[0]] = b
		tools.add_child(b)
	_palette.add_child(tools)
	var kinds := GridContainer.new()
	kinds.columns = 4
	for k: String in DesignCatalog.DOOR_ORDER:
		var dk: Dictionary = DesignCatalog.DOOR_KINDS[k]
		var b := T.button(str(dk.short), false, 13)
		b.name = "DoorKind_" + k
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%s: %s m wide (%s to %s), CR %s%s" % [dk.name, PlanView._m(float(dk.w)), PlanView._m(float(dk.min_w)),
				PlanView._m(float(dk.max_w)), T.money(int(dk.cost)), ", airtight" if bool(dk.airtight) else ""]
		b.pressed.connect(func() -> void:
			plan.door_kind = k
			plan.set_tool("door"))
		_door_buttons[k] = b
		kinds.add_child(b)
	_palette.add_child(kinds)
	_palette = _sections.hull
	_palette.add_child(T.label("HULL SHAPE  (drag a corner, or a side for a new corner)", "display_medium", 15, T.DIM))
	var shape := HBoxContainer.new()
	for spec in [["hull", "DRAW HULL", func() -> void: plan.set_tool("hull")],
			["hull_rooms", "ROUND THE ROOMS", hull_round_rooms],
			["hull_clear", "CLEAR", func() -> void: bus.editor.do({"op": "set_hull", "deck": plan.deck, "points": []})]]:
		var b := T.button(spec[1], false, 15)
		b.name = "Hull_" + str(spec[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[2])
		if spec[0] == "hull":
			_tool_buttons["hull"] = b
		shape.add_child(b)
	_palette.add_child(shape)
	_palette = _sections.tools
	_palette.add_child(T.label("STRUCTURE  (drag end to end; drag an end to move it)", "display_medium", 15, T.DIM))
	var frame := HBoxContainer.new()
	for spec in [["wall", "INNER WALL"], ["beam", "BEAM"]]:
		var b := T.button(spec[1], false, 15)
		b.name = "Tool_" + str(spec[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(plan.set_tool.bind(spec[0]))
		_tool_buttons[spec[0]] = b
		frame.add_child(b)
	_palette.add_child(frame)
	_palette = _sections.rooms
	_palette.add_child(T.label("ROOMS  (pick one, then drag out on the grid or click)", "display_medium", 15, T.DIM))
	_palette.add_child(_room_dropdown())
	_palette = _sections.modules
	_palette.add_child(T.label("MODULES  (pick up, click on a plan to drop)", "display_medium", 15, T.DIM))
	var mods := bus.library.modules()
	if mods.is_empty():
		_palette.add_child(T.label("Select a room and SAVE AS MODULE to make one.", "body", 14, T.DIM))
	for m in mods:
		var rt := bus.catalog.room(str(m.room.type))
		var row := HBoxContainer.new()
		var pick_b := _swatch_button("%s   %s x %s m, %d parts" % [m.name, PlanView._m(float(m.room.w)),
				PlanView._m(float(m.room.d)), (m.components as Array).size()], rt.colour if rt else Color.GRAY)
		pick_b.name = "Module_" + str(m.id)
		pick_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick_b.pressed.connect(func() -> void:
			plan.set_tool("select")
			bus.carry(str(m.id)))
		row.add_child(pick_b)
		var del_b := T.button("X", false, 14)
		del_b.tooltip_text = "Delete this module (designs already using it keep their rooms)"
		del_b.pressed.connect(bus.library.remove_module.bind(str(m.id)))
		row.add_child(del_b)
		_palette.add_child(row)
	_palette = _sections.tools
	_palette.add_child(T.label("WIRES AND PIPES  (click points, double-click ends)", "display_medium", 15, T.DIM))
	for kind: String in DesignServices.KINDS:
		var spec: Dictionary = DesignServices.KINDS[kind]
		var row := HBoxContainer.new()
		var draw_b := _swatch_button("DRAW " + str(spec.name).to_upper(), spec.colour)
		draw_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		draw_b.pressed.connect(plan.set_tool.bind("run:" + kind))
		_tool_buttons["run:" + kind] = draw_b
		row.add_child(draw_b)
		var auto_b := T.button("ROUTE ALL", false, 14)
		auto_b.name = "Route_" + kind
		auto_b.tooltip_text = "Lay %s to every part that needs it and has none yet" % str(spec.name).to_lower()
		auto_b.pressed.connect(route_all.bind(kind))
		row.add_child(auto_b)
		_palette.add_child(row)
	_palette = _sections.hull
	_palette.add_child(T.label("BUILD SPEC  (click to swap, cost updates)", "display_medium", 15, T.DIM))
	for kind: String in ["frame", "spacing", "hull", "inner"]:
		var b := T.button(_structure_text(kind), false, 15)
		b.name = "Structure_" + kind
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			var rec := bus.library.current
			if rec == null:
				return
			bus.editor.do({"op": "set_meta", "fields": {"structure": {
					kind: DesignStructure.next_choice(kind, rec.structure.get(kind))}}})
			b.text = _structure_text(kind))
		_palette.add_child(b)
	_palette = _sections.components
	_fill_components()
	_mark_tools()


## Lays runs of `kind` to every part that needs one and has none, in one undo step.
## Draws a starting hull round the rooms on the deck in view, half a metre out.
func hull_round_rooms() -> void:
	var rec := bus.library.current
	if rec == null:
		return
	var pts := rec.hull_round_rooms(plan.deck, 0.5)
	if not pts.is_empty():
		bus.editor.do({"op": "set_hull", "deck": plan.deck, "points": pts})


func route_all(kind: String) -> int:
	var rec := bus.library.current
	if rec == null:
		return 0
	var ops: Array = []
	for run in DesignServices.route(rec, bus.catalog, kind):
		ops.append({"op": "add_run", "run": run})
	if not ops.is_empty():
		bus.editor.do({"op": "batch", "ops": ops})
		if kind == "wire":
			holo.set_layer("wiring", true)
		else:
			holo.set_layer("pipes", true)
		_sync_layer_buttons()
	return ops.size()


func _structure_text(kind: String) -> String:
	var rec := bus.library.current
	if rec == null:
		return kind.to_upper()
	var v: Variant = rec.structure.get(kind)
	if kind == "spacing":
		return "FRAME SPACING   %s m" % PlanView._m(float(v))
	var label: String = {"frame": "FRAME", "hull": "HULL", "inner": "INNER WALLS"}[kind]
	return "%s   %s" % [label, str(DesignStructure.option(kind, str(v)).get("name", v)).to_upper()]


func _sync_layer_buttons() -> void:
	for layer in HoloTable.LAYERS:
		var b := find_child("Layer_" + layer, true, false) as Button
		if b and b.button_pressed != holo.layers.get(layer, false):
			b.set_pressed_no_signal(holo.layers.get(layer, false))
			_restyle_toggle(b, b.button_pressed)


## The ship order this design answers (ShipOrders, posted by clients on the contracts board):
## its title and demands, and a list to pick another or none. The data channel scores the
## design against the order's demands.
func _fill_orders() -> void:
	var rec := bus.library.current
	var contracts := Modules.bus("contracts") as ContractsBus
	var orders: Array[Dictionary] = contracts.ship_orders() if contracts else ([] as Array[Dictionary])
	_palette.add_child(T.label("SHIP ORDER", "display_bold", 20, T.TEXT))
	var current: Dictionary = rec.order if rec else {}
	_shown_order = str(current.get("id", ""))
	if current.is_empty():
		_palette.add_child(T.label("None: designing freely.", "body", 14, T.DIM))
	else:
		var title := T.label(str(current.get("title", "")), "body_medium", 15, T.ORANGE)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_palette.add_child(title)
		if current.has("size"):
			var who := T.label(_order_tag(current), "mono_medium", 12, T.DIM)
			who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_palette.add_child(who)
			if current.has("region"):
				var where := T.label(ShipOrders.region_line(current), "mono_medium", 12, T.CYAN)
				where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_palette.add_child(where)
			_palette.add_child(_achievability_label(current, 14))
		var lines := T.label("\n".join(ShipOrders.demand_lines(current) + ShipOrders.clause_lines(current)), "mono_medium", 13, T.DIM)
		lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_palette.add_child(lines)
		if contracts and Flags.is_on(ContractsBus.SHIP_CONTRACTS_FLAG):
			_contract_block(contracts, current)
	var row := HBoxContainer.new()
	var pick := T.button("%s ORDERS (%d)" % ["HIDE" if _orders_open else "PICK FROM", orders.size()], false, 14)
	pick.name = "Orders"
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.disabled = orders.is_empty()
	pick.pressed.connect(func() -> void:
		_orders_open = not _orders_open
		_fill_palette())
	row.add_child(pick)
	if not current.is_empty():
		var clear := T.button("NONE", false, 14)
		clear.name = "OrderNone"
		clear.pressed.connect(set_order.bind({}))
		row.add_child(clear)
	_palette.add_child(row)
	if not _orders_open:
		return
	for o: Dictionary in orders:
		var text := "%s\nCR %s for the yard, %d days" % [str(o.title), T.money(int(o.pay)), int(o.days)]
		if o.has("achievability"):
			text = "%s\nBudget CR %s · %s · %d criteria%s" % [str(o.title), T.money(int(o.budget)),
					str(o.achievability.label).to_upper(), ShipOrders.criteria_count(o),
					" · NEEDS %s STANDING" % ContractClients.level_name(int(o.needs_level)).to_upper() if o.get("locked", false) else ""]
			if o.get("berth_short", false):
				text += " · NEEDS A LARGER BERTH (%s)" % ShipOrders.berth_name(int(o.berth)).to_upper()
		if contracts.has_method("ship_contract_for") and not contracts.ship_contract_for(str(o.id)).is_empty():
			text += " · SIGNED"
		var b := T.button(text, str(o.id) == str(current.get("id", "")), 13)
		b.name = "Order_" + str(o.id)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", _achievability_colour(o))
		b.tooltip_text = _order_tooltip(o)
		b.pressed.connect(set_order.bind(o))
		_palette.add_child(b)


## The contract for the order the design answers (plan 4.3 to 4.6): the quote for this design
## and SEND QUOTE, or once signed where the payments stand and DELIVER FOR TRIAL; CONTRACT
## DETAILS opens the payments page.
func _contract_block(contracts: ContractsBus, order: Dictionary) -> void:
	var rec := bus.library.current
	var c := contracts.ship_contract_for(str(order.get("id", "")))
	var row := HBoxContainer.new()
	var details := T.button("CONTRACT DETAILS", false, 14)
	details.name = "ContractDetails"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.pressed.connect(toggle_contract_terms)
	if c.is_empty():
		var cost := int(bus.totals().cost)
		var q := ShipOrders.quote(order, cost)
		var l := T.label("", "mono_medium", 13, T.GOOD)
		l.name = "QuoteLine"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_palette.add_child(l)
		_show_quote(l, q)
		var send := T.button("SEND QUOTE", true, 14)
		send.name = "SendQuote"
		send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var why := contracts.ship_sign_problem(order)
		send.disabled = why != ""
		send.tooltip_text = why.capitalize() if why != "" else "The client signs off this design at CR %s and pays the deposit of CR %s." % [
				T.money(int(q.price)), T.money(int(ShipOrders.payment_plan(int(q.price), 0, 1)[0].value))]
		send.pressed.connect(func() -> void:
			contracts.request_sign_ship(order, rec.id, rec.name, int(bus.totals().cost)))
		row.add_child(send)
	else:
		var paid := 0
		var next := ""
		for st: Dictionary in c.stages:
			if st.paid:
				paid += int(st.get("paid_value", st.value))
			elif next == "":
				next = "%s CR %s, day %d" % [str(st.name), T.money(int(st.value)), int(st.expected_day)]
		var text := "SIGNED  CR %s  ·  paid CR %s" % [T.money(int(c.price)), T.money(paid)]
		if c.state == "delivered":
			text = "DELIVERED  ·  grade %s  ·  paid CR %s" % [str(c.trial.get("grade", "")), T.money(paid)]
		elif next != "":
			text += "\nNext: " + next
		var l := T.label(text, "mono_medium", 13, T.ORANGE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_palette.add_child(l)
		if c.state == "building":
			var deliver := T.button("DELIVER FOR TRIAL", true, 14)
			deliver.name = "DeliverTrial"
			deliver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			deliver.disabled = rec == null or rec.id != str(c.design_id)
			deliver.tooltip_text = "The surveyors test this design against every demand and clause, and the client pays the delivery." \
					if not deliver.disabled else "Open the design that was signed (%s) to deliver it." % str(c.design_name)
			deliver.pressed.connect(deliver_for_trial)
			row.add_child(deliver)
	row.add_child(details)
	_palette.add_child(row)


func _show_quote(l: Label, q: Dictionary) -> void:
	l.text = "QUOTE  CR %s  ·  margin CR %s" % [T.money(int(q.price)), T.money(int(q.margin))]
	l.add_theme_color_override("font_color", T.BAD if q.over_budget else T.GOOD)


## The open design goes through the surveyors' trial as the ship its contract ordered (the
## build itself comes with Wave 5): every demand and clause scored, the delivery paid.
func deliver_for_trial() -> void:
	var rec := bus.library.current
	var contracts := Modules.bus("contracts") as ContractsBus
	if rec == null or contracts == null:
		return
	var c := contracts.ship_contract_for(str(rec.order.get("id", "")))
	if c.is_empty() or str(c.design_id) != rec.id:
		return
	var rows := DesignContractCheck.all(c.order, rec, bus.catalog, bus.totals())
	var motion := Modules.bus("motion")
	if motion and motion.has_method("cycle"):
		var cyc: Variant = motion.call("cycle", rec)
		if cyc is Dictionary:
			rows.append_array(DesignContractCheck.motion_rows(cyc))
	contracts.request_deliver_ship(str(c.id), rows)


func _on_contract_changed(_id: String) -> void:
	if is_inside_tree():
		_fill_palette()
	if _terms_panel and is_instance_valid(_terms_panel):
		toggle_contract_terms()
		toggle_contract_terms()


## "Large · Mining · Deepcut Minerals (Businesslike)" for an order.
static func _order_tag(o: Dictionary) -> String:
	var tag := "%s · %s · %s (%s)" % [str(ShipOrders.SIZES.get(str(o.size), {}).get("name", o.size)),
			ShipClients.sector_name(str(o.get("sector", ""))), str(o.client_name), str(o.get("temper", ""))]
	if o.has("berth"):
		tag += "\nAbout %d m long: %s" % [int(o.get("length_m", 0)), ShipOrders.berth_name(int(o.berth))]
	return tag


## How the budget compares with the cheapest build, coloured: green generous, amber tight,
## red unrealistic.
static func _achievability_colour(o: Dictionary) -> Color:
	match str(o.get("achievability", {}).get("label", "")):
		"Generous", "Fair":
			return T.GOOD
		"Tight":
			return T.AMBER
		"Long shot":
			return T.ORANGE
		"Unrealistic":
			return T.BAD
	return T.TEXT


static func _achievability_label(o: Dictionary, size: int) -> Label:
	var a: Dictionary = o.achievability
	var l := T.label("%s: budget CR %s against about CR %s for the cheapest build. %s" % [str(a.label).to_upper(),
			T.money(int(o.budget)), T.money(int(o.estimate)), str(a.line)], "body_medium", size, _achievability_colour(o))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _order_tooltip(o: Dictionary) -> String:
	if not o.has("achievability"):
		return "%s\n\n%s" % [str(o.brief), "\n".join(ShipOrders.demand_lines(o))]
	var a: Dictionary = o.achievability
	return "%s\n%s\n\n%s\n\n%s\n\nWHAT THEY WANT\n%s\n\n%s: CR %s budget, about CR %s for the cheapest build (x%.2f)." % [
			str(o.title), _order_tag(o), str(o.story), str(o.brief),
			"\n".join(ShipOrders.demand_lines(o) + ShipOrders.clause_lines(o) + PackedStringArray([ShipOrders.region_line(o)])),
			str(a.label).to_upper(), T.money(int(o.budget)), T.money(int(o.estimate)), float(a.ratio)]


## Makes the open design answer `order` ({} for none), one undo step.
func set_order(order: Dictionary) -> void:
	if bus.library.current == null:
		return
	_orders_open = false
	bus.editor.do({"op": "set_meta", "fields": {"order": order}})
	_fill_palette()


## The components, in groups that open and close, with the size and grade they are picked in
## (DesignGrades): each button places that type at the picked size (within its own range) and
## grade, and shows what that variant costs.
func _fill_components() -> void:
	_palette.add_child(T.label("COMPONENTS  (click in a room, R turns; hull parts click on the hull)",
			"display_medium", 15, T.DIM))
	# Size and class (grade) as drop-downs that both filter the list and set what is placed
	# (beenster, 20 Nov: "more filtering on Size and Class").
	var pick := HBoxContainer.new()
	pick.add_child(_size_dropdown())
	pick.add_child(_class_dropdown())
	_palette.add_child(pick)
	var gr: Dictionary = DesignGrades.GRADES[_pick_grade]
	_palette.add_child(T.label(("Any class: placed as Standard. " if _class_filter == "" else "%s: " % str(gr.name))
			+ str(gr.blurb), "body", 13, T.DIM))
	var search := LineEdit.new()
	search.name = "CompSearch"
	search.placeholder_text = "Search components (name, kind, size, grade)"
	search.text = _comp_search
	search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size", T.px(14))
	search.text_changed.connect(func(t: String) -> void:
		_comp_search = t
		_fill_comp_list())
	_palette.add_child(search)
	# The groups as one drop-down of sections, any number ticked (beenster, 20 Nov).
	_palette.add_child(_group_dropdown())
	_comp_list = VBoxContainer.new()
	_comp_list.name = "CompList"
	_comp_list.add_theme_constant_override("separation", 1)
	_palette.add_child(_comp_list)
	_fill_comp_list()


## The component rows under the chips: every match across the groups while there is a search,
## else the open groups. One slim row each (name and short cost); the full card is its tooltip.
func _fill_comp_list() -> void:
	if _comp_list == null:
		return
	for c in _comp_list.get_children():
		_comp_list.remove_child(c)
		c.queue_free()
	for id: String in _tool_buttons.keys():
		if not is_instance_valid(_tool_buttons[id]):
			_tool_buttons.erase(id)
	var words := _comp_search.strip_edges().to_lower().split(" ", false)
	var shown := 0
	for cat: Array in DesignCatalog.CATEGORIES:
		var list := bus.catalog.parts_in(str(cat[0]))
		if list.is_empty():
			continue
		var rows: Array = []
		for base: DesignPartType in list:
			if not passes_filters(base):
				continue
			var pt := bus.catalog.part(picked_id(base))
			if words.is_empty():
				if not bool(_open_groups.get(cat[0], false)):
					break
			elif not matches_search(words, base, pt, str(cat[1])):
				continue
			rows.append([base, pt])
		if rows.is_empty():
			continue
		_comp_list.add_child(T.label(str(cat[1]).to_upper(), "display_medium", 12, T.DIM))
		for r: Array in rows:
			_comp_list.add_child(_comp_row(r[0], r[1]))
			shown += 1
	if shown == 0:
		var why := "Pick a section above, or search."
		if not words.is_empty():
			why = "No components match."
		elif _pick_size > 0 or _class_filter != "":
			why = "Nothing in the open sections comes in that size and class."
		_comp_list.add_child(T.label(why, "body", 13, T.DIM))
	_mark_tools()


## True when every word of a search is in the part's name, id, group, size or grade.
static func matches_search(words: PackedStringArray, base: DesignPartType, pt: DesignPartType, group: String) -> bool:
	var hay := " ".join([base.display_name, base.id, group, DesignGrades.label(pt),
			"hull" if base.hull_mount else ""]).to_lower()
	for w in words:
		if not hay.contains(w):
			return false
	return true


## One slim component row: colour swatch, name and size/grade tag, its cost short on the right.
func _comp_row(base: DesignPartType, pt: DesignPartType) -> Button:
	var tag := DesignGrades.label(pt)
	var b := _swatch_button("%s%s%s" % [base.display_name, ("  " + tag) if tag != "" else "",
			"  (hull)" if base.hull_mount else ""], base.colour, 13)
	b.clip_text = true
	b.custom_minimum_size.y = 0
	var cost := T.label(short_money(pt.cost), "display", 12, T.DIM)
	cost.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	cost.offset_left = -64
	cost.offset_right = -8
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cost)
	b.add_theme_constant_override("h_separation", 6)
	b.set_meta("slim", true)
	for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var sb := b.get_theme_stylebox(state)
		if sb is StyleBoxFlat:
			b.add_theme_stylebox_override(state, _slim(sb.duplicate() as StyleBoxFlat))
	var tool := ("mount:" if base.hull_mount else "part:") + pt.id
	b.name = ("Mount_" if base.hull_mount else "Part_") + base.id
	b.pressed.connect(plan.set_tool.bind(tool))
	_tool_buttons[tool] = b
	return b


## A row's plate made slim: little above and below, room on the right for the cost.
static func _slim(sb: StyleBoxFlat) -> StyleBoxFlat:
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.content_margin_left = 6
	sb.content_margin_right = 66
	return sb


## A cost in few characters: 950, 12.4k, 3.1M.
static func short_money(v: float) -> String:
	if v >= 1000000.0:
		return "%.1fM" % (v / 1000000.0)
	if v >= 10000.0:
		return "%.0fk" % (v / 1000.0)
	if v >= 1000.0:
		return "%.1fk" % (v / 1000.0)
	return "%d" % int(v)


## The type id a palette button places for `base`: the picked size (kept inside the type's own
## range) and grade.
func picked_id(base: DesignPartType) -> String:
	return DesignGrades.variant_id(base, _pick_size, _pick_grade)


## Picks the size class (0 = each part's own) and grade new components come in.
func set_pick(size: int, grade: String) -> void:
	_pick_size = clampi(size, 0, DesignGrades.MAX_CLASS)
	_class_filter = grade if DesignGrades.GRADES.has(grade) else ""
	_pick_grade = grade if DesignGrades.GRADES.has(grade) else DesignGrades.DEFAULT_GRADE
	_fill_palette()


## The size drop-down: ANY (each part at its own size) or 1 to 8 (only parts that come in it).
func _size_dropdown() -> MenuButton:
	var b := _menu_button("SIZE", 14)
	b.name = "PickSize"
	b.text = "SIZE: %s  v" % ("ANY" if _pick_size == 0 else str(_pick_size))
	b.tooltip_text = "Show only parts that come in this size class, and place them at it. Bigger is not always better: check the numbers."
	var pop := b.get_popup()
	pop.add_radio_check_item("Any size (each part's own)", 0)
	pop.set_item_checked(0, _pick_size == 0)
	for n in range(DesignGrades.MIN_CLASS, DesignGrades.MAX_CLASS + 1):
		pop.add_radio_check_item("Size %d" % n, n)
		pop.set_item_checked(pop.get_item_index(n), _pick_size == n)
	pop.id_pressed.connect(func(id: int) -> void: set_pick.call_deferred(id, _class_filter))
	return b


## The class drop-down: ANY or one grade (only graded parts, placed in that grade).
func _class_dropdown() -> MenuButton:
	var b := _menu_button("CLASS", 14)
	b.name = "PickGrade"
	b.text = "CLASS: %s  v" % ("ANY" if _class_filter == "" else "%s %s" % [_class_filter,
			str(DesignGrades.GRADES[_class_filter].name).to_upper()])
	b.tooltip_text = "Show only parts that come in this class (grade), and place them in it."
	var pop := b.get_popup()
	pop.add_radio_check_item("Any class", 0)
	pop.set_item_checked(0, _class_filter == "")
	for i in DesignGrades.GRADE_ORDER.size():
		var g: String = DesignGrades.GRADE_ORDER[i]
		pop.add_radio_check_item("%s  %s" % [g, DesignGrades.GRADES[g].name], i + 1)
		pop.set_item_checked(i + 1, _class_filter == g)
		pop.set_item_tooltip(i + 1, str(DesignGrades.GRADES[g].blurb))
	pop.id_pressed.connect(func(id: int) -> void:
		set_pick.call_deferred(_pick_size, "" if id == 0 else DesignGrades.GRADE_ORDER[id - 1]))
	return b


## True when `base` comes in the picked size and class (the filters; 0 and "" pass anything).
func passes_filters(base: DesignPartType) -> bool:
	if _pick_size > 0:
		var span := DesignGrades.sizes(base)
		if span[0] <= 0 or _pick_size < span[0] or _pick_size > span[1]:
			return false
	if _class_filter != "" and not base.graded:
		return false
	return true


## A component's numbers, one per line, for its button's tooltip.
static func part_card(pt: DesignPartType) -> String:
	var rows: PackedStringArray = [pt.display_name]
	var span := DesignGrades.sizes(pt)
	if pt.size_class > 0:
		rows.append("Size %d (comes in %d to %d)" % [pt.size_class, span[0], span[1]])
	if pt.graded:
		rows.append("Grade %s, %s" % [pt.grade, DesignGrades.GRADES[pt.grade].name])
	rows.append("%.1f x %.1f x %.1f m, %d kg, CR %s, %.1f h to fit, %d days to get" % [pt.size.x, pt.size.y,
			pt.size.z, int(pt.mass), T.money(int(pt.cost)), pt.build_hours, pt.lead_days])
	for spec: Array in [["power", "Power %+.0f kW"], ["thrust", "Thrust %.0f kN"], ["jump", "Jump %.1f ly per 100 t"],
			["attack", "Attack %.0f dmg/s"], ["defence", "Defence %.0f"], ["signature", "Signature %+.0f"],
			["sensor", "Sensors %.0f km"], ["cargo", "Cargo %.1f m3"], ["tank", "Fuel %.1f m3"], ["crew", "Bunks %d"]]:
		var v: float = float(pt.get(spec[0]))
		if absf(v) > 0.001:
			rows.append(str(spec[1]) % (int(v) if spec[0] == "crew" else v))
	rows.append("Integrity %.0f" % pt.integrity)
	return "\n".join(rows)


## A drop-down button in the console's style: a MenuButton dressed as a T.button.
static func _menu_button(text: String, size := 15) -> MenuButton:
	var look := T.button(text, false, size)
	var b := MenuButton.new()
	b.text = text + "  v"
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, look.get_theme_stylebox(st))
	b.add_theme_font_override("font", look.get_theme_font("font"))
	b.add_theme_font_size_override("font_size", look.get_theme_font_size("font_size"))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, look.get_theme_color(c))
	look.free()
	var pop := b.get_popup()
	pop.add_theme_font_size_override("font_size", T.px(15))
	return b


static func _swatch(col: Color) -> ImageTexture:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)


## The room types in one drop-down: picking one arms it (the button shows which, lit while armed).
func _room_dropdown() -> MenuButton:
	var b := _menu_button("PICK A ROOM", 15)
	b.name = "RoomPick"
	b.add_theme_constant_override("icon_max_width", 14)
	var pop := b.get_popup()
	pop.add_theme_constant_override("icon_max_width", 14)
	var list := bus.catalog.room_list()
	for i in list.size():
		pop.add_icon_item(_swatch(list[i].colour), list[i].display_name, i)
		pop.set_item_metadata(i, list[i].id)
	pop.id_pressed.connect(func(i: int) -> void: pick_room(list[i].id))
	_room_pick = b
	_show_room_pick()
	return b


## Arms drawing a room of type `type_id` (the room drop-down's pick).
func pick_room(type_id: String) -> void:
	plan.set_tool("room:" + type_id)
	_show_room_pick()


func _show_room_pick() -> void:
	if _room_pick == null or not is_instance_valid(_room_pick):
		return
	var rt: DesignRoomType = null
	if plan.tool.begins_with("room:"):
		rt = bus.catalog.room(plan.tool.trim_prefix("room:"))
	if rt == null and _last_room != "":
		rt = bus.catalog.room(_last_room)
	if rt:
		_last_room = rt.id
		_room_pick.text = "ROOM  %s  v" % rt.display_name.to_upper()
		_room_pick.icon = _swatch(rt.colour)
	var on := plan.tool.begins_with("room:")
	_room_pick.add_theme_stylebox_override("normal", T.box(T.PLATE_HI if on else T.PLATE, T.ORANGE if on else T.EDGE, 2, 8.0))


## The component sections as one drop-down with a tick each (any number open), and ALL / NONE.
func _group_dropdown() -> MenuButton:
	var b := _menu_button("SECTIONS", 14)
	b.name = "CompGroups"
	var pop := b.get_popup()
	pop.hide_on_checkable_item_selection = false
	pop.hide_on_item_selection = false
	pop.add_item("ALL", 1000)
	pop.add_item("NONE", 1001)
	pop.add_separator()
	var ids: Array[String] = []
	for cat: Array in DesignCatalog.CATEGORIES:
		var n := bus.catalog.parts_in(str(cat[0])).size()
		if n == 0:
			continue
		pop.add_check_item("%s  (%d)" % [str(cat[1]), n], ids.size())
		pop.set_item_checked(pop.get_item_index(ids.size()), bool(_open_groups.get(cat[0], false)))
		ids.append(str(cat[0]))
	pop.id_pressed.connect(func(id: int) -> void:
		if id >= 1000:
			for g: String in ids:
				_open_groups[g] = id == 1000
		elif id < ids.size():
			_open_groups[ids[id]] = not bool(_open_groups.get(ids[id], false))
		for i in ids.size():
			pop.set_item_checked(pop.get_item_index(i), bool(_open_groups.get(ids[i], false)))
		_group_text(b, ids)
		_fill_comp_list())
	_group_text(b, ids)
	return b


## Sets which component sections are open (the drop-down's ticks), by category id.
func set_groups(groups: Array) -> void:
	_open_groups = {}
	for g: Variant in groups:
		_open_groups[str(g)] = true
	_fill_palette()


func _group_text(b: MenuButton, ids: Array[String]) -> void:
	var names: Array[String] = []
	for cat: Array in DesignCatalog.CATEGORIES:
		if str(cat[0]) in ids and bool(_open_groups.get(cat[0], false)):
			names.append(str(cat[1]).get_slice(" ", 0).trim_suffix(","))
	var t := "NONE" if names.is_empty() else ("ALL" if names.size() == ids.size() else ", ".join(names))
	b.text = "SECTIONS: %s  v" % t.to_upper()
	b.tooltip_text = "Tick the sections of components to list (or search below)."


func _swatch_button(text: String, col: Color, size := 15) -> Button:
	var b := T.button(text, false, size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", 14)
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(col)
	b.icon = ImageTexture.create_from_image(img)
	return b


func _mark_tools() -> void:
	_show_room_pick()
	for id: String in _tool_buttons:
		var b: Button = _tool_buttons[id]
		var on := id == plan.tool
		var st := T.box(T.PLATE_HI if on else T.PLATE, T.ORANGE if on else T.EDGE, 2, 8.0)
		if b.has_meta("slim"):
			st = _slim(st)
		b.add_theme_stylebox_override("normal", st)
	for k: String in _door_buttons:
		var on := plan.tool == "door" and plan.door_kind == k
		(_door_buttons[k] as Button).add_theme_stylebox_override("normal",
				T.box(T.PLATE_HI if on else T.PLATE, T.ORANGE if on else T.EDGE, 2, 8.0))


func _holo_panel() -> Control:
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", T.box(Color(0.01, 0.03, 0.05), T.EDGE, 2, 4.0))
	wrap.custom_minimum_size.y = 120
	var col := VBoxContainer.new()
	wrap.add_child(col)
	var svc := SubViewportContainer.new()
	svc.name = "HoloView"
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_holo_input)
	col.add_child(svc)
	_holo_view = SubViewport.new()
	_holo_view.msaa_3d = Viewport.MSAA_2X
	svc.add_child(_holo_view)
	_holo_cam = Camera3D.new()
	_holo_cam.fov = 45.0
	# The hologram alone, on a dark field: not the room round the table.
	_holo_cam.cull_mask = HoloTable.VIEW_LAYER
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.6, 0.7)
	_holo_cam.environment = env
	_holo_view.add_child(_holo_cam)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	col.add_child(row)
	for layer in HoloTable.LAYERS:
		var b := T.button(HoloTable.LAYER_NAMES[layer].to_upper(), false, 14, holo.layers.get(layer, false))
		b.toggle_mode = true
		b.button_pressed = holo.layers.get(layer, false)
		b.name = "Layer_" + layer
		b.toggled.connect(func(on: bool) -> void:
			holo.set_layer(layer, on)
			_restyle_toggle(b, on))
		_restyle_toggle(b, b.button_pressed)
		row.add_child(b)
	var cut_row := HBoxContainer.new()
	cut_row.add_child(T.label("CUT", "display_medium", 15, T.DIM))
	var slider := HSlider.new()
	slider.name = "Cut"
	slider.min_value = 0.05
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void: holo.set_cut(v))
	cut_row.add_child(slider)
	col.add_child(cut_row)
	return wrap


func _restyle_toggle(b: Button, on: bool) -> void:
	b.add_theme_stylebox_override("normal", T.box(T.PLATE_HI if on else T.PLATE, T.CYAN if on else T.EDGE, 2, 6.0))
	b.add_theme_color_override("font_color", T.TEXT if on else T.DIM)


## Wheel in and out on the 3D window (beenster, 20 Nov): the camera moves, only on this console;
## the table's own hologram stays as it is.
func zoom_view(factor: float) -> void:
	view_zoom = clampf(view_zoom * factor, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)


func _holo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_holo = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_view(VIEW_ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_view(1.0 / VIEW_ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging_holo:
		holo.turn += event.relative.x * 0.01
		_cam_pitch = clampf(_cam_pitch + event.relative.y * 0.005, 0.1, 1.3)


func _process(_delta: float) -> void:
	if _holo_cam == null or holo == null:
		return
	if _holo_view.world_3d != get_viewport().world_3d:
		_holo_view.world_3d = get_viewport().world_3d
	# Framed on the hologram: its middle, far enough back to see all of it.
	var target := holo.model.global_transform * holo.view_middle
	var dist := holo.view_radius * holo.model.scale.x / sin(deg_to_rad(_holo_cam.fov * 0.5)) * 1.05 / view_zoom
	var off := Vector3(sin(_cam_turn), 0, cos(_cam_turn)) * cos(_cam_pitch) * dist
	off.y = sin(_cam_pitch) * dist
	_holo_cam.global_position = target + off
	_holo_cam.look_at(target)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	if k.ctrl_pressed and k.keycode == KEY_Z:
		if k.shift_pressed:
			bus.editor.redo()
		else:
			bus.editor.undo()
	elif k.ctrl_pressed and k.keycode == KEY_Y:
		bus.editor.redo()
	elif k.ctrl_pressed and k.keycode == KEY_S:
		_on_save()
	elif k.keycode == KEY_PAGEUP:
		_change_deck(1)
	elif k.keycode == KEY_PAGEDOWN:
		_change_deck(-1)
	else:
		return
	get_viewport().set_input_as_handled()


func _change_deck(step: int) -> void:
	var rec := bus.library.current
	if step < 0 and plan.deck == 0 and rec and not rec.rooms.is_empty():
		# Below the lowest deck: everything moves up one, and you're on the new deck under it.
		bus.editor.do({"op": "shift_decks", "by": 1})
	plan.set_deck(plan.deck + step)
	_deck_label.text = "DECK %d" % (plan.deck + 1)


## Shows a WILL IT WORK problem on the plan: its first room, component or door picked, on its
## deck and in the middle of the view, with a ring round it.
func go_to_problem(p: Dictionary) -> bool:
	var rec := bus.library.current
	if rec == null:
		return false
	var at := Vector2.INF
	var dk := plan.deck
	var kind := ""
	var id := ""
	for rid: Variant in p.get("rooms", []):
		var r: Dictionary = rec.rooms.get(str(rid), {})
		if not r.is_empty():
			kind = "room"
			id = str(rid)
			dk = int(r.deck)
			at = rec.room_rect(id).get_center()
			break
	if kind == "":
		for cid: Variant in p.get("components", []):
			var c: Dictionary = rec.components.get(str(cid), {})
			var k := "part"
			if c.is_empty():
				c = rec.mounts.get(str(cid), {})
				k = "mount"
			if not c.is_empty():
				kind = k
				id = str(cid)
				dk = int(c.get("deck", rec.rooms.get(str(c.get("room", "")), {}).get("deck", plan.deck)))
				at = Vector2(float(c.get("x", 0.0)), float(c.get("z", 0.0)))
				break
	if kind == "":
		for did: Variant in p.get("doors", []):
			var d: Dictionary = rec.doors.get(str(did), {})
			if not d.is_empty():
				kind = "door"
				id = str(did)
				dk = int(d.get("deck", plan.deck))
				at = Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0)))
				break
	if kind == "":
		return false
	if plan.mode != PlanView.PLAN:
		_set_view(PlanView.PLAN)
	plan.set_tool("select")
	plan.set_deck(dk)
	_deck_label.text = "DECK %d" % (plan.deck + 1)
	plan.centre = at
	plan.zoom = maxf(plan.zoom, 22.0)
	plan.select(kind, id)
	plan.marks.on_look(dk, at, "problem", T.BAD)
	plan.queue_redraw()
	if is_inside_tree():
		get_tree().create_timer(4.1).timeout.connect(plan.queue_redraw)
	return true


func _set_view(v: String) -> void:
	plan.mode = v
	if v != PlanView.PLAN and not (plan.tool == "select" or plan.tool.begins_with("room:")):
		plan.set_tool("select")  # the elevations draw and move rooms only
	plan.frame_all()
	for k: String in _view_buttons:
		var on: bool = k == v
		(_view_buttons[k] as Button).add_theme_stylebox_override("normal",
				T.box(T.PLATE_HI if on else T.PLATE, T.ORANGE if on else T.EDGE, 2, 8.0))


func _refresh_bar() -> void:
	var rec := bus.library.current
	if _title:
		_title.text = ("  " + rec.name + ("  *" if bus.library.dirty else "")) if rec else "  No design open"
	for kind: String in ["frame", "spacing", "hull", "inner"]:
		var b := find_child("Structure_" + kind, true, false) as Button
		if b:
			b.text = _structure_text(kind)
	if _grid_pick and rec:
		for i in DesignRecord.GRIDS.size():
			if is_equal_approx(DesignRecord.GRIDS[i], rec.grid):
				_grid_pick.select(i)
	_on_selection(plan.selected_kind if plan else "", plan.selected_id if plan else "")
	if rec and str(rec.order.get("id", "")) != _shown_order:
		_fill_palette()
	var quote := find_child("QuoteLine", true, false) as Label
	if quote and rec and not rec.order.is_empty():
		_show_quote(quote, ShipOrders.quote(rec.order, bus.totals().cost))


# The selection panel: name, size and remove for the room or component picked on the plan.

func _on_selection(kind: String, id: String) -> void:
	if _selection == null:
		return
	for c in _selection.get_children():
		_selection.remove_child(c)
		c.queue_free()
	var rec := bus.library.current
	if rec == null:
		return
	holo.light_rooms([id] if kind == "room" else [])
	_selection.add_child(T.label("DESIGN", "display_bold", 20, T.TEXT))
	var name_edit := LineEdit.new()
	name_edit.text = rec.name
	name_edit.name = "DesignName"
	name_edit.text_submitted.connect(func(t: String) -> void:
		if bus.library.rename(rec.id, t):
			pass
		else:
			bus.editor.do({"op": "set_meta", "fields": {"name": t}}))
	_selection.add_child(name_edit)
	if kind == "room" and rec.rooms.has(id):
		var r: Dictionary = rec.rooms[id]
		var rt := bus.catalog.room(str(r.type))
		_selection.add_child(T.label("%s   %s" % [(rt.display_name if rt else str(r.type)).to_upper(), DesignRecord.tag(id)], "display_bold", 18, T.ORANGE))
		var room_name := LineEdit.new()
		room_name.placeholder_text = "Room name"
		room_name.text = str(r.get("name", ""))
		room_name.text_submitted.connect(func(t: String) -> void:
			bus.editor.do({"op": "set_room", "id": id, "fields": {"name": t}}))
		_selection.add_child(room_name)
		_selection.add_child(_size_row("Width", float(r.w), func(v: float) -> void:
			bus.editor.do({"op": "set_room", "id": id, "fields": {"w": v}})))
		_selection.add_child(_size_row("Depth", float(r.d), func(v: float) -> void:
			bus.editor.do({"op": "set_room", "id": id, "fields": {"d": v}})))
		_selection.add_child(_info_panel(kind, id))
		var mod_row := HBoxContainer.new()
		var mod_name := LineEdit.new()
		mod_name.name = "ModuleName"
		mod_name.placeholder_text = "Module name"
		mod_name.text = str(r.get("name", "")) if str(r.get("name", "")) != "" else (rt.display_name if rt else "")
		mod_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mod_row.add_child(mod_name)
		var mod_b := T.button("SAVE AS MODULE", false, 14)
		mod_b.name = "SaveModule"
		mod_b.tooltip_text = "Save this room and everything in it as a ready-made module"
		mod_b.pressed.connect(func() -> void: bus.library.save_module(mod_name.text, id))
		mod_row.add_child(mod_b)
		_selection.add_child(mod_row)
		_selection.add_child(_remove_button())
	elif kind == "part" and rec.components.has(id):
		var c: Dictionary = rec.components[id]
		var pt := bus.catalog.part(str(c.type))
		if pt:
			_selection.add_child(T.label("%s   %s" % [pt.display_name.to_upper(), DesignRecord.tag(id)], "display_bold", 18, T.ORANGE))
			_selection.add_child(_info_panel(kind, id))
			_grade_rows(str(c.type), func(t: String) -> void:
				bus.editor.do({"op": "set_component", "id": id, "fields": {"type": t}}))
		# Where it stands (beenster, 19 Nov: select a component and edit it to move it); it can
		# also be dragged on the plan.
		for axis: String in ["x", "z"]:
			_selection.add_child(_size_row("across" if axis == "x" else "along", float(c[axis]),
					func(v: float) -> void: _move_part(id, axis, v), -200.0, 0.1))
		var turn := T.button("TURN (R)", false, 15)
		turn.pressed.connect(plan.rotate_selected)
		_selection.add_child(turn)
		_selection.add_child(_remove_button())
	elif kind == "door" and rec.doors.has(id):
		var door: Dictionary = rec.doors[id]
		var dk := DesignCatalog.door_kind(door)
		var fit := DesignCatalog.door_cost(door)
		_selection.add_child(T.label("%s   %s" % [str(dk.name).to_upper(), DesignRecord.tag(id)], "display_bold", 18, T.ORANGE))
		_selection.add_child(_info_panel(kind, id))
		# Its own width, within what its kind comes in (beenster, 19 Nov: doors of different widths).
		var lo := float(dk.min_w)
		var hi := float(dk.max_w)
		_selection.add_child(_size_row("Width", DesignCatalog.door_w(door), func(v: float) -> void:
			bus.editor.do({"op": "set_door", "id": id, "fields": {"w": clampf(v, lo, hi)}}), lo, 0.05))
		_selection.add_child(T.label("%s comes %s to %s m wide" % [str(dk.name), PlanView._m(lo), PlanView._m(hi)],
				"body", 14, T.DIM))
		var kinds := GridContainer.new()
		kinds.columns = 4
		for k: String in DesignCatalog.DOOR_ORDER:
			var on: bool = DesignCatalog.door_kind(door) == DesignCatalog.DOOR_KINDS[k]
			var b := T.button(str(DesignCatalog.DOOR_KINDS[k].short), on, 13)
			b.name = "SetDoor_" + k
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.tooltip_text = "%s: %s to %s m wide" % [DesignCatalog.DOOR_KINDS[k].name,
					PlanView._m(float(DesignCatalog.DOOR_KINDS[k].min_w)), PlanView._m(float(DesignCatalog.DOOR_KINDS[k].max_w))]
			# A new kind takes its own default width.
			b.pressed.connect(func() -> void:
				bus.editor.do({"op": "set_door", "id": id, "fields": {"kind": k, "w": null}}))
			kinds.add_child(b)
		_selection.add_child(kinds)
		_selection.add_child(_remove_button())
	elif kind == "run" and rec.runs.has(id):
		var w: Dictionary = rec.runs[id]
		var spec: Dictionary = DesignServices.KINDS.get(str(w.kind), {})
		var live: bool = DesignServices.connected(rec, bus.catalog, str(w.kind)).runs.has(id)
		_selection.add_child(T.label("%s   %s" % [str(spec.get("name", w.kind)).to_upper(), DesignRecord.tag(id)], "display_bold", 18, T.ORANGE))
		_selection.add_child(T.label("%s m   %s" % [PlanView._m(DesignServices.length(w)),
				"LIVE" if live else "NOT CONNECTED"], "mono_medium", 15, T.GOOD if live else T.DIM))
		_selection.add_child(_remove_button())
	elif kind in ["wall", "beam"] and (rec.walls if kind == "wall" else rec.beams).has(id):
		var e: Dictionary = (rec.walls if kind == "wall" else rec.beams)[id]
		var length := DesignStructure._v(e.a).distance_to(DesignStructure._v(e.b))
		_selection.add_child(T.label("%s   %s" % ["INNER WALL" if kind == "wall" else "BEAM", DesignRecord.tag(id)], "display_bold", 18, T.ORANGE))
		var spec := DesignStructure.option("inner" if kind == "wall" else "frame",
				str(rec.structure.get("inner" if kind == "wall" else "frame")))
		_selection.add_child(T.label("%s m   %s" % [PlanView._m(length), spec.get("name", "")], "mono_medium", 15, T.DIM))
		_selection.add_child(_remove_button())
	elif kind == "mount" and rec.mounts.has(id):
		var pt := bus.catalog.part(str(rec.mounts[id].type))
		if pt:
			_selection.add_child(T.label("%s   %s" % [pt.display_name.to_upper(), DesignRecord.tag(id)], "display_bold", 18, T.ORANGE))
			_selection.add_child(_info_panel(kind, id))
			_grade_rows(str(rec.mounts[id].type), func(t: String) -> void:
				bus.editor.do({"op": "set_mount", "id": id, "fields": {"type": t}}))
		_selection.add_child(_remove_button())
	elif kind == "hull":
		var outline := rec.hull_outline(plan.deck)
		_selection.add_child(T.label("HULL CORNER", "display_bold", 18, T.ORANGE))
		_selection.add_child(T.label("%d corners, drag to reshape. Delete takes this one out." % outline.size(),
				"body", 14, T.DIM))
		_selection.add_child(_remove_button())


## SIZE and GRADE steppers for a placed component of type `type_id`: each step calls `on_type`
## with the variant's type id (DesignGrades), so the part changes in place, one undo step each.
## The INFO panel (beenster, 20 Nov: "when we have an item selected the info panel should
## populate with the important data about that object"): a box of label / value rows, then
## any WILL IT WORK problem naming the item.
func _info_panel(kind: String, id: String) -> Control:
	var box := PanelContainer.new()
	box.name = "InfoPanel"
	box.add_theme_stylebox_override("panel", T.box(T.PLATE, T.CYAN, 1, 6.0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	col.add_child(T.label("INFO", "display_bold", 14, T.CYAN))
	var grid := GridContainer.new()
	grid.name = "InfoRows"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 1)
	col.add_child(grid)
	for row: Array in info_rows(kind, id):
		grid.add_child(T.label(str(row[0]).to_upper(), "display_medium", 12, T.DIM))
		var v := T.label(str(row[1]), "mono_medium", 14, row[2] if row.size() > 2 else T.TEXT)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(v)
	for p: Dictionary in bus.problems():
		var key: String = {"room": "rooms", "part": "components", "mount": "components", "door": "doors"}.get(kind, "")
		if key != "" and str(id) in (p.get(key, []) as Array).map(func(x): return str(x)):
			var l := T.label(("! " if p.severity == DesignRules.ERROR else "? ") + str(p.text), "body", 13,
					T.BAD if p.severity == DesignRules.ERROR else T.AMBER)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(l)
	return box


## The selected item's important numbers as [label, value (, colour)] rows: what it is, its size
## and class, what it weighs, costs and takes to fit, what it does, and where it is.
func info_rows(kind: String, id: String) -> Array:
	var rec := bus.library.current
	var out: Array = []
	if rec == null:
		return out
	if kind == "room" and rec.rooms.has(id):
		var r: Dictionary = rec.rooms[id]
		var rt := bus.catalog.room(str(r.type))
		var area := DesignRecord.room_area(r)
		var parts: Array = rec.components.values().filter(func(c): return str(c.room) == id)
		var made := 0.0
		var used := 0.0
		var mass := 0.0
		var cost := 0.0
		var bunks := 0
		for c: Dictionary in parts:
			var pt := bus.catalog.part(str(c.type))
			if pt:
				made += maxf(pt.power, 0.0)
				used += maxf(-pt.power, 0.0)
				mass += pt.mass
				cost += pt.cost
				bunks += pt.crew
		var doors: Array = rec.doors.values().filter(func(d): return str(d.a) == id or str(d.b) == id)
		out.append(["Type", rt.display_name if rt else str(r.type)])
		out.append(["Deck", str(int(r.deck) + 1)])
		out.append(["Size", "%s x %s m" % [PlanView._m(float(r.w)), PlanView._m(float(r.d))]])
		out.append(["Floor", "%s m2, %s m3" % [PlanView._m(area), PlanView._m(area * rec.deck_height)]])
		out.append(["Parts", "%d, %.1f t, CR %s" % [parts.size(), mass / 1000.0, T.money(int(cost))]])
		if made > 0.0 or used > 0.0:
			out.append(["Power", "%+.0f kW (makes %.0f, uses %.0f)" % [made - used, made, used], T.GOOD if made >= used else T.AMBER])
		if bunks > 0:
			out.append(["Bunks", str(bunks)])
		out.append(["Doors", str(doors.size())])
	elif (kind == "part" and rec.components.has(id)) or (kind == "mount" and rec.mounts.has(id)):
		var c: Dictionary = rec.components[id] if kind == "part" else rec.mounts[id]
		var pt := bus.catalog.part(str(c.type))
		if pt == null:
			return [["Type", str(c.type), T.BAD]]
		var span := DesignGrades.sizes(pt)
		var group := pt.category
		for cat: Array in DesignCatalog.CATEGORIES:
			if str(cat[0]) == pt.category:
				group = str(cat[1])
		out.append(["Kind", group])
		if pt.size_class > 0:
			out.append(["Size", "%d (comes %d to %d)" % [pt.size_class, span[0], span[1]]])
		if pt.graded:
			out.append(["Class", "%s %s" % [pt.grade, DesignGrades.GRADES[pt.grade].name]])
		out.append(["Box", "%.1f x %.1f x %.1f m" % [pt.size.x, pt.size.y, pt.size.z]])
		out.append(["Mass", "%s kg" % T.money(int(pt.mass))])
		out.append(["Cost", "CR %s" % T.money(int(pt.cost))])
		out.append(["Fit", "%.1f h, %d days to get" % [pt.build_hours, pt.lead_days]])
		for spec: Array in [["power", "Power", "%+.0f kW"], ["thrust", "Thrust", "%.0f kN"], ["jump", "Jump", "%.1f ly per 100 t"],
				["attack", "Attack", "%.0f dmg/s"], ["defence", "Defence", "%.0f"], ["signature", "Signature", "%+.0f"],
				["sensor", "Sensors", "%.0f km"], ["cargo", "Cargo", "%.1f m3"], ["tank", "Fuel", "%.1f m3"],
				["tow_t", "Tow", "%.0f t"], ["crew", "Bunks", "%d"]]:
			var v: float = float(pt.get(spec[0]))
			if absf(v) > 0.001:
				out.append([spec[1], str(spec[2]) % (int(v) if spec[0] == "crew" else v)])
		out.append(["Integrity", "%.0f" % pt.integrity])
		# How hard it works for its size and weight (DesignMatrix: bigger is not always better).
		var grp := DesignMatrix.group_of(pt)
		if grp != "" and pt.size_class > 0:
			var g := DesignMatrix.group(grp)
			var cell := DesignMatrix.cell(bus.catalog, bus.catalog.base_of(pt.id), pt.size_class, pt.grade, grp)
			if not cell.is_empty() and float(cell.figure) > 0.0:
				out.append(["Packs", "%.1f %s per m3, %.1f per t" % [float(cell.per_m3), str(g.unit), float(cell.per_t)], T.CYAN])
		if DesignMatrix.draw_kw(pt) > 0.0:
			var by := DesignMatrix.supported_by(bus.catalog, pt.id)
			if not by.is_empty():
				var src := bus.catalog.part(by[0])
				out.append(["Run by", "%s %s or bigger (%d units can)" % [src.display_name, DesignGrades.label(src), by.size()]])
		# Moving parts: what it opens, how fast, and (where the catalogue gives them) its motor,
		# load and the room it needs to swing.
		if pt.open_size != Vector2.ZERO:
			out.append(["Opens", "%s x %s m" % [PlanView._m(pt.open_size.x), PlanView._m(pt.open_size.y)]])
		if pt.move_s > 0.0:
			out.append(["Moves", "%s, %.1f s" % [pt.move_kind.replace("_", " "), pt.move_s]])
		for spec: Array in [["move_kw", "Motor", "%.1f kW"], ["load_kg", "Load", "%.0f kg"], ["clearance", "Clearance", "%.1f m"]]:
			var mv: Variant = pt.get(spec[0])
			if (mv is float or mv is int) and absf(float(mv)) > 0.001:
				out.append([spec[1], str(spec[2]) % float(mv)])
		if kind == "part":
			var room: Dictionary = rec.rooms.get(str(c.get("room", "")), {})
			if not room.is_empty():
				out.append(["In", "%s, deck %d" % [DesignRules._label(rec, bus.catalog, str(room.id)), int(room.deck) + 1]])
			if pt.power < 0.0:
				var live: bool = DesignServices.connected(rec, bus.catalog, "wire").components.has(id)
				out.append(["Wired", "yes, to power" if live else "no power reaches it", T.GOOD if live else T.AMBER])
		else:
			out.append(["On", "the hull"])
	elif kind == "door" and rec.doors.has(id):
		var door: Dictionary = rec.doors[id]
		var dk := DesignCatalog.door_kind(door)
		var fit := DesignCatalog.door_cost(door)
		out.append(["Kind", str(dk.name)])
		out.append(["Opening", "%s x %s m" % [PlanView._m(DesignCatalog.door_w(door)), PlanView._m(DesignCatalog.door_h(door))]])
		out.append(["Mass", "%d kg" % int(fit.mass)])
		out.append(["Cost", "CR %s, %.1f h to fit" % [T.money(int(fit.cost)), float(fit.hours)]])
		out.append(["Airtight", "yes" if bool(dk.get("airtight", false)) else "no"])
		out.append(["Joins", "%s and %s" % [DesignRules._label(rec, bus.catalog, str(door.a)),
				"outside" if str(door.b) == "" else DesignRules._label(rec, bus.catalog, str(door.b))]])
		out.append(["Deck", str(int(door.get("deck", 0)) + 1)])
	return out


func _grade_rows(type_id: String, on_type: Callable) -> void:
	var base := bus.catalog.base_of(type_id)
	var pt := bus.catalog.part(type_id)
	if base == null or pt == null:
		return
	var span := DesignGrades.sizes(base)
	if span[0] > 0 and span[1] > span[0]:
		var row := HBoxContainer.new()
		row.add_child(T.label("SIZE", "display_medium", 15, T.DIM))
		for step in [-1, 1]:
			var s: int = pt.size_class + int(step)
			var b := T.button("-" if step < 0 else "+", false, 15)
			b.name = "Size" + ("Down" if step < 0 else "Up")
			b.disabled = s < span[0] or s > span[1]
			b.pressed.connect(func() -> void: on_type.call(DesignGrades.variant_id(base, s, pt.grade)))
			if step < 0:
				row.add_child(b)
				var l := T.label("  %d  (%d to %d)" % [pt.size_class, span[0], span[1]], "mono_medium", 15, T.TEXT)
				row.add_child(l)
			else:
				row.add_child(b)
		_selection.add_child(row)
	if base.graded:
		var grades := HBoxContainer.new()
		for g: String in DesignGrades.GRADE_ORDER:
			var b := T.button(g, g == pt.grade, 14)
			b.name = "Grade_" + g
			b.tooltip_text = "%s: %s" % [DesignGrades.GRADES[g].name, DesignGrades.GRADES[g].blurb]
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func() -> void: on_type.call(DesignGrades.variant_id(base, pt.size_class, g)))
			grades.add_child(b)
		_selection.add_child(grades)
		_selection.add_child(T.label("%s  %s" % [DesignGrades.label(pt), DesignGrades.GRADES[pt.grade].name],
				"body", 13, T.DIM))


func _size_row(what: String, value: float, on_set: Callable, lowest := 0.5, step := 0.0) -> Control:
	var h := HBoxContainer.new()
	var l := T.label(what.to_upper(), "display_medium", 15, T.DIM)
	l.custom_minimum_size.x = 70
	h.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = lowest
	spin.max_value = 200.0
	spin.step = step if step > 0.0 else bus.library.current.grid
	spin.value = value
	spin.suffix = "m"
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(on_set)
	h.add_child(spin)
	return h


## A part moved to `v` m along one axis from the selection panel; it changes room if it
## lands in another one on its deck.
func _move_part(id: String, axis: String, v: float) -> void:
	var rec := bus.library.current
	var c: Dictionary = rec.components.get(id, {}) if rec else {}
	if c.is_empty() or is_equal_approx(float(c[axis]), v):
		return
	var fields := {axis: v}
	var at := Vector2(v if axis == "x" else float(c.x), v if axis == "z" else float(c.z))
	var deck := int(rec.rooms.get(str(c.room), {}).get("deck", plan.deck))
	var room := rec.room_at(deck, at)
	if room != "" and room != str(c.room):
		fields["room"] = room
	bus.editor.do({"op": "set_component", "id": id, "fields": fields})


func _remove_button() -> Button:
	var b := T.button("REMOVE (DEL)", false, 15)
	b.pressed.connect(plan.delete_selected)
	return b


# Saves

func _on_new() -> void:
	bus.library.save_current()
	bus.library.create("New design")
	plan.frame_all()


func _on_save() -> void:
	bus.library.save_current()


func _on_save_as() -> void:
	var rec := bus.library.current
	if rec:
		bus.library.save_as(rec.name + " Mk2")


## The contract fit assessment over the whole console (FULL ASSESSMENT on the data channel).
var _assessment_panel: Control


func toggle_assessment() -> void:
	if _assessment_panel and is_instance_valid(_assessment_panel):
		_assessment_panel.queue_free()
		_assessment_panel = null
		return
	var p := PanelContainer.new()
	p.name = "Assessment"
	p.add_theme_stylebox_override("panel", T.box(Color(T.KIOSK, 0.98), T.CYAN, 2, 12.0))
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 24
	p.offset_top = 24
	p.offset_right = -24
	p.offset_bottom = -24
	var col := VBoxContainer.new()
	p.add_child(col)
	var head := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := T.button("CLOSE", false, 16)
	close.name = "BtnCloseAssessment"
	close.pressed.connect(toggle_assessment)
	head.add_child(close)
	col.add_child(head)
	var fit := ContractFit.new()
	fit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fit)
	fit.setup(bus, 17)
	add_child(p)
	_assessment_panel = p


## The contract details page over the whole console (CONTRACT DETAILS under the ship order).
var _terms_panel: Control


func toggle_contract_terms() -> void:
	if _terms_panel and is_instance_valid(_terms_panel):
		_terms_panel.queue_free()
		_terms_panel = null
		return
	var rec := bus.library.current
	var contracts := Modules.bus("contracts") as ContractsBus
	if rec == null or rec.order.is_empty() or contracts == null:
		return
	var p := PanelContainer.new()
	p.name = "ContractTermsPanel"
	p.add_theme_stylebox_override("panel", T.box(Color(T.KIOSK, 0.98), T.ORANGE, 2, 12.0))
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 24
	p.offset_top = 24
	p.offset_right = -24
	p.offset_bottom = -24
	var col := VBoxContainer.new()
	p.add_child(col)
	var head := HBoxContainer.new()
	head.add_child(T.label("CONTRACT DETAILS", "display_bold", 20, T.ORANGE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := T.button("CLOSE", false, 16)
	close.name = "BtnCloseTerms"
	close.pressed.connect(toggle_contract_terms)
	head.add_child(close)
	col.add_child(head)
	var c := contracts.ship_contract_for(str(rec.order.get("id", "")))
	var terms := ContractTerms.new()
	terms.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(terms)
	terms.setup(c.order if not c.is_empty() else rec.order, c, int(bus.totals().cost), contracts.today(), 17)
	add_child(p)
	_terms_panel = p


func _toggle_library() -> void:
	_library_panel.visible = not _library_panel.visible
	if _library_panel.visible:
		_fill_library()


func _make_library_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Library"
	p.add_theme_stylebox_override("panel", T.box(Color(T.KIOSK, 0.97), T.ORANGE, 2, 16.0))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(760, 520)
	p.position = Vector2(-380, -260)
	var col := VBoxContainer.new()
	col.name = "Col"
	p.add_child(col)
	return p


func _fill_library() -> void:
	var col: VBoxContainer = _library_panel.get_node("Col")
	for c in col.get_children():
		col.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	var t := T.label("SAVED DESIGNS", "display_bold", 26, T.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := T.button("CLOSE", false, 16)
	close.pressed.connect(_toggle_library)
	head.add_child(close)
	col.add_child(head)
	col.add_child(T.HazardRule.new(6.0))
	var rows := T.list()
	col.add_child(rows.get_parent())
	var alt := false
	for item in bus.library.list():
		var is_open: bool = bus.library.current != null and bus.library.current.id == item.id
		var open_b := T.button("OPEN", is_open, 14)
		open_b.disabled = is_open
		open_b.pressed.connect(func() -> void:
			bus.library.save_current()
			bus.library.open(item.id)
			plan.frame_all()
			_fill_library())
		var copy_b := T.button("COPY", false, 14)
		copy_b.pressed.connect(func() -> void:
			bus.library.copy(item.id)
			_fill_library())
		var rename_e := LineEdit.new()
		rename_e.text = item.name
		rename_e.custom_minimum_size.x = 180
		rename_e.text_submitted.connect(func(s: String) -> void:
			bus.library.rename(item.id, s)
			_fill_library())
		var del_b := T.button("DELETE", false, 14)
		del_b.pressed.connect(func() -> void:
			bus.library.remove(item.id)
			if bus.library.current == null:
				var left := bus.library.list()
				if left.is_empty():
					bus.library.create("New design")
				else:
					bus.library.open(left[0].id)
			_fill_library())
		var info := T.cell_text(str(item.name), "%d rooms  %d components%s" % [item.rooms, item.components,
				"  OPEN NOW" if is_open else ""])
		rows.add_child(T.row([info, rename_e, _gap(6), open_b, _gap(4), copy_b, _gap(4), del_b], alt))
		alt = not alt


func _gap(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	return c
