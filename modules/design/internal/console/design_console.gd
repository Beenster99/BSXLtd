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
const HoloTable := preload("res://modules/design/internal/holo/holo_table.gd")

var bus: DesignBus
var holo: HoloTable
var plan: PlanView
var data: DataChannel

var _title: Label
var _deck_label: Label
var _palette: VBoxContainer
var _selection: VBoxContainer
var _tool_buttons: Dictionary = {}
var _view_buttons: Dictionary = {}
var _library_panel: PanelContainer
var _holo_view: SubViewport
var _holo_cam: Camera3D
var _cam_turn := 0.0
var _cam_pitch := 0.55
var _cam_dist := 7.2
var _dragging_holo := false


func setup(design_bus: DesignBus, table: HoloTable) -> void:
	bus = design_bus
	holo = table
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	bus.design_changed.connect(_refresh_bar)
	bus.library.modules_changed.connect(_fill_palette)
	if bus.library.current == null:
		var list := bus.library.list()
		if list.is_empty():
			bus.library.create("First design")
		else:
			bus.library.open(list[0].id)
	_refresh_bar()
	_fill_palette()
	plan.frame_all.call_deferred()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_top_bar())
	root.add_child(T.HazardRule.new(6.0))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	body.add_child(_left_panel())
	plan = PlanView.new()
	plan.name = "Plan"
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan.size_flags_stretch_ratio = 2.2
	plan.setup(bus, PlanView.PLAN, true)
	plan.selection_changed.connect(_on_selection)
	plan.tool_changed.connect(func(_t: String) -> void: _mark_tools())
	body.add_child(plan)
	_crew_feed = T.label("", "body_medium", 17, T.TEXT)
	_crew_feed.name = "CrewFeed"
	_crew_feed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_crew_feed.position = Vector2(16, -120)
	_crew_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_crew_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.add_child(_crew_feed)
	bus.crew_edited.connect(_on_crew_edited)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.3
	right.add_theme_constant_override("separation", 0)
	body.add_child(right)
	right.add_child(_holo_panel())
	data = DataChannel.new()
	data.name = "Data"
	data.size_flags_vertical = Control.SIZE_EXPAND_FILL
	data.setup(bus, true)
	right.add_child(data)
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
	for g in DesignRecord.GRIDS:
		var b := T.button(PlanView._m(g) + " m", false, 16)
		b.pressed.connect(func() -> void: bus.editor.do({"op": "set_meta", "fields": {"grid": g}}))
		h.add_child(b)
	var walk := T.button("WALK INSIDE", true, 17)
	walk.name = "BtnWalkInside"
	walk.pressed.connect(func() -> void: walk_requested.emit())
	h.add_child(walk)
	var leave := T.button("LEAVE", false, 17)
	leave.pressed.connect(func() -> void: leave_requested.emit())
	h.add_child(leave)
	return bar


func _left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 290
	panel.add_theme_stylebox_override("panel", T.box(T.KIOSK, T.EDGE, 2, 10.0))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)
	_selection = VBoxContainer.new()
	_selection.add_theme_constant_override("separation", 4)
	col.add_child(_selection)
	_palette = VBoxContainer.new()
	_palette.add_theme_constant_override("separation", 4)
	col.add_child(_palette)
	return panel


func _fill_palette() -> void:
	for c in _palette.get_children():
		_palette.remove_child(c)
		c.queue_free()
	_tool_buttons = {}
	_palette.add_child(T.label("TOOLS", "display_bold", 20, T.TEXT))
	var tools := HBoxContainer.new()
	for spec in [["select", "SELECT"], ["door", "DOOR"]]:
		var b := T.button(spec[1], false, 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(plan.set_tool.bind(spec[0]))
		_tool_buttons[spec[0]] = b
		tools.add_child(b)
	_palette.add_child(tools)
	_palette.add_child(T.label("HULL SHAPE  (click its corners, drag them to reshape)", "display_medium", 15, T.DIM))
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
	_palette.add_child(T.label("STRUCTURE  (drag from one end to the other)", "display_medium", 15, T.DIM))
	var frame := HBoxContainer.new()
	for spec in [["wall", "INNER WALL"], ["beam", "BEAM"]]:
		var b := T.button(spec[1], false, 15)
		b.name = "Tool_" + str(spec[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(plan.set_tool.bind(spec[0]))
		_tool_buttons[spec[0]] = b
		frame.add_child(b)
	_palette.add_child(frame)
	_palette.add_child(T.label("ROOMS  (drag out on the grid, or click)", "display_medium", 15, T.DIM))
	for rt in bus.catalog.room_list():
		var b := _swatch_button(rt.display_name, rt.colour)
		b.pressed.connect(plan.set_tool.bind("room:" + rt.id))
		_tool_buttons["room:" + rt.id] = b
		_palette.add_child(b)
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
	_palette.add_child(T.label("COMPONENTS  (click in a room, R turns)", "display_medium", 15, T.DIM))
	var parts: Array = bus.catalog.parts.values()
	parts.sort_custom(func(a, b): return a.display_name < b.display_name)
	for pt: DesignPartType in parts:
		if pt.hull_mount:
			continue
		var b := _swatch_button("%s   CR %s" % [pt.display_name, T.money(int(pt.cost))], pt.colour)
		b.pressed.connect(plan.set_tool.bind("part:" + pt.id))
		_tool_buttons["part:" + pt.id] = b
		_palette.add_child(b)
	_palette.add_child(T.label("ON THE HULL  (click on the hull's side)", "display_medium", 15, T.DIM))
	for pt: DesignPartType in parts:
		if not pt.hull_mount:
			continue
		var b := _swatch_button("%s   CR %s" % [pt.display_name, T.money(int(pt.cost))], pt.colour)
		b.name = "Mount_" + pt.id
		b.pressed.connect(plan.set_tool.bind("mount:" + pt.id))
		_tool_buttons["mount:" + pt.id] = b
		_palette.add_child(b)
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


func _swatch_button(text: String, col: Color) -> Button:
	var b := T.button(text, false, 15)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", 14)
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(col)
	b.icon = ImageTexture.create_from_image(img)
	return b


func _mark_tools() -> void:
	for id: String in _tool_buttons:
		var b: Button = _tool_buttons[id]
		var on := id == plan.tool
		var st := T.box(T.PLATE_HI if on else T.PLATE, T.ORANGE if on else T.EDGE, 2, 8.0)
		b.add_theme_stylebox_override("normal", st)


func _holo_panel() -> Control:
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", T.box(Color(0.01, 0.03, 0.05), T.EDGE, 2, 4.0))
	wrap.custom_minimum_size.y = 380
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


func _holo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_holo = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			holo.zoom = clampf(holo.zoom * 1.1, 0.4, 4.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			holo.zoom = clampf(holo.zoom / 1.1, 0.4, 4.0)
	elif event is InputEventMouseMotion and _dragging_holo:
		holo.turn += event.relative.x * 0.01
		_cam_pitch = clampf(_cam_pitch + event.relative.y * 0.005, 0.1, 1.3)


func _process(_delta: float) -> void:
	if _holo_cam == null or holo == null:
		return
	if _holo_view.world_3d != get_viewport().world_3d:
		_holo_view.world_3d = get_viewport().world_3d
	var target := holo.global_position + Vector3(0, holo.TABLE_HEIGHT + 0.6, 0)
	var off := Vector3(sin(_cam_turn), 0, cos(_cam_turn)) * cos(_cam_pitch) * _cam_dist
	off.y = sin(_cam_pitch) * _cam_dist
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


func _set_view(v: String) -> void:
	plan.mode = v
	plan.editable = v == PlanView.PLAN
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
	_on_selection(plan.selected_kind if plan else "", plan.selected_id if plan else "")


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
		_selection.add_child(T.label((rt.display_name if rt else str(r.type)).to_upper(), "display_bold", 18, T.ORANGE))
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
		var area := float(r.w) * float(r.d)
		_selection.add_child(T.label("%s m2 floor, %s m3" % [PlanView._m(area), PlanView._m(area * rec.deck_height)],
				"mono_medium", 15, T.DIM))
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
			_selection.add_child(T.label(pt.display_name.to_upper(), "display_bold", 18, T.ORANGE))
			_selection.add_child(T.label("CR %s   %.1f t   %+.0f kW   %d days" % [T.money(int(pt.cost)), pt.mass / 1000.0,
					pt.power, pt.lead_days], "mono_medium", 15, T.DIM))
		var turn := T.button("TURN (R)", false, 15)
		turn.pressed.connect(plan.rotate_selected)
		_selection.add_child(turn)
		_selection.add_child(_remove_button())
	elif kind == "door":
		_selection.add_child(T.label("DOOR", "display_bold", 18, T.ORANGE))
		_selection.add_child(_remove_button())
	elif kind == "run" and rec.runs.has(id):
		var w: Dictionary = rec.runs[id]
		var spec: Dictionary = DesignServices.KINDS.get(str(w.kind), {})
		var live: bool = DesignServices.connected(rec, bus.catalog, str(w.kind)).runs.has(id)
		_selection.add_child(T.label(str(spec.get("name", w.kind)).to_upper(), "display_bold", 18, T.ORANGE))
		_selection.add_child(T.label("%s m   %s" % [PlanView._m(DesignServices.length(w)),
				"LIVE" if live else "NOT CONNECTED"], "mono_medium", 15, T.GOOD if live else T.DIM))
		_selection.add_child(_remove_button())
	elif kind in ["wall", "beam"] and (rec.walls if kind == "wall" else rec.beams).has(id):
		var e: Dictionary = (rec.walls if kind == "wall" else rec.beams)[id]
		var length := DesignStructure._v(e.a).distance_to(DesignStructure._v(e.b))
		_selection.add_child(T.label("INNER WALL" if kind == "wall" else "BEAM", "display_bold", 18, T.ORANGE))
		var spec := DesignStructure.option("inner" if kind == "wall" else "frame",
				str(rec.structure.get("inner" if kind == "wall" else "frame")))
		_selection.add_child(T.label("%s m   %s" % [PlanView._m(length), spec.get("name", "")], "mono_medium", 15, T.DIM))
		_selection.add_child(_remove_button())
	elif kind == "mount" and rec.mounts.has(id):
		var pt := bus.catalog.part(str(rec.mounts[id].type))
		if pt:
			_selection.add_child(T.label(pt.display_name.to_upper(), "display_bold", 18, T.ORANGE))
			_selection.add_child(T.label("ON THE HULL   CR %s   %.1f t   %.0f kN" % [T.money(int(pt.cost)),
					pt.mass / 1000.0, pt.thrust], "mono_medium", 15, T.DIM))
		_selection.add_child(_remove_button())
	elif kind == "hull":
		var outline := rec.hull_outline(plan.deck)
		_selection.add_child(T.label("HULL CORNER", "display_bold", 18, T.ORANGE))
		_selection.add_child(T.label("%d corners, drag to reshape. Delete takes this one out." % outline.size(),
				"body", 14, T.DIM))
		_selection.add_child(_remove_button())


func _size_row(what: String, value: float, on_set: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := T.label(what.to_upper(), "display_medium", 15, T.DIM)
	l.custom_minimum_size.x = 70
	h.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = 0.5
	spin.max_value = 200.0
	spin.step = bus.library.current.grid
	spin.value = value
	spin.suffix = "m"
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(on_set)
	h.add_child(spin)
	return h


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
