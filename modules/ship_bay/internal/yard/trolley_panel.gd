extends PanelContainer
## The hover trolleys' screen, in Void Salvage's terminal style: dark glass, a cyan edge,
## monospace readouts. A row per vehicle (letter, status, deck height, what it carries), the
## selected one's details and actions, and the yard-wide soft keys along the bottom.
##
## Copies: one drawn on the TV on Deliveries' east wall (display only, `live` off), one
## opened full screen when a player presses F on the TV, and a compact one on the wrist
## screen's "Hover trolleys" channel (mouse, Up/Down to pick a vehicle, Enter calls it, Esc
## or F closes). All read the fleet; actions go through it.

## Asks whoever shows the screen to put it away (the fleet's full-screen copy, the wrist screen).
signal close_requested

## Soft keys along the bottom: [action, label].
const KEYS := [["put_away", "PUT AWAY DELIVERIES"], ["park_all", "PARK ALL"],
		["fetch_ship", "FETCH FOR THE SHIP"]]
## Actions on the selected vehicle: [action, label].
const ACTIONS := [["call", "CALL TO ME"], ["park", "PARK"], ["remote", "REMOTE CONTROL"]]
const ORDER := ["s", "m", "l", "p", "h"]

var fleet: Node3D
## True for the copy a player is using (mouse and keys); false on the TV.
var live := false
## Text size factor: 1 on the TV and full screen, smaller on the wrist screen's pane.
var scale_text := 1.0
var selected := "m"
var _rows: Dictionary = {}       # id -> {box, status, deck, cargo}
var _detail: Label
var _detail_title: Label
var _footer: Label
var _message: Label
var _buttons: Dictionary = {}    # action -> Button
var _tick := 0.0


func setup(p_fleet: Node3D, p_live: bool, compact := false) -> void:
	fleet = p_fleet
	live = p_live
	scale_text = 0.68 if compact else 1.0
	theme = BsxTheme.get_theme()
	add_theme_stylebox_override("panel", BsxTheme.panel_style(12 if compact else 28))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _text("HOVER TROLLEYS", "display_bold", 52, BsxTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_text("DELIVERIES · STORES", "mono", 24, BsxTheme.MUTED))
	col.add_child(_rule())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = 1.6
	body.add_child(list)
	for id: String in ORDER:
		list.add_child(_row(id))

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(side)
	_detail_title = _text("", "display_medium", 34, BsxTheme.TEXT)
	side.add_child(_detail_title)
	_detail = _text("", "mono", 21, BsxTheme.HUD)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_detail)
	for a: Array in ACTIONS:
		side.add_child(_button(a[0], a[1]))

	col.add_child(_rule())
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 12)
	col.add_child(keys)
	for k: Array in KEYS:
		var b := _button(k[0], k[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keys.add_child(b)
	var foot := HBoxContainer.new()
	col.add_child(foot)
	_footer = _text("", "mono", 20, BsxTheme.MUTED)
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_footer)
	_message = _text("", "mono", 20, BsxTheme.LIVE)
	foot.add_child(_message)
	if live:
		foot.add_child(_text("ESC CLOSE", "mono", 20, BsxTheme.HUD_DIM))
	refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		refresh()


## _input, not _unhandled_input: F must close the screen before the bay's F handler sees it.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not live or key == null or not key.pressed or key.echo:
		return
	var i := ORDER.find(selected)
	if _is(event, "cancel", KEY_ESCAPE) or _is(event, "interact", KEY_F):
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	match key.physical_keycode:
		KEY_UP, KEY_W:
			select(ORDER[posmod(i - 1, ORDER.size())])
		KEY_DOWN, KEY_S:
			select(ORDER[posmod(i + 1, ORDER.size())])
		KEY_ENTER, KEY_KP_ENTER:
			press("call")
		_:
			return
	get_viewport().set_input_as_handled()


## Whether `event` is a press of a Core action (as the player bound it), or of `key` before
## the key map is in.
func _is(event: InputEvent, action: String, key: Key) -> bool:
	if InputMap.has_action(action):
		return event.is_action_pressed(action)
	return (event as InputEventKey).physical_keycode == key


func select(id: String) -> void:
	if ORDER.has(id):
		selected = id
		refresh()


## Runs an action from ACTIONS (on the selected vehicle) or KEYS, as a click would.
func press(action: String) -> void:
	if fleet == null:
		return
	var said := ""
	match action:
		"call":
			fleet.call("call_to_me", selected)
			said = "%s ON ITS WAY" % _spec(selected)["letter"]
		"park":
			fleet.call("park", selected)
			said = "%s PARKING" % _spec(selected)["letter"]
		"remote":
			fleet.call("toggle_remote", selected)
			if live and fleet.get("remote_id") == selected:
				close_requested.emit()
		"put_away":
			fleet.call("put_away_all")
			said = "PUTTING AWAY"
		"park_all":
			fleet.call("park_all")
			said = "ALL PARKING"
		"fetch_ship":
			said = "FETCHING " + str(fleet.call("next_part_for_ship")).to_upper() if fleet.call("fetch_for_ship") else "NOTHING TO FETCH"
	if _message:
		_message.text = said
	refresh()


## Every label's text (tests).
func text() -> String:
	var out := PackedStringArray()
	for l: Node in find_children("*", "Label", true, false):
		out.append((l as Label).text)
	for b: Node in find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return "\n".join(out)


func refresh() -> void:
	if fleet == null or _detail == null:
		return
	var trolleys: Dictionary = fleet.get("trolleys")
	var bus := Modules.bus("ship_bay") as ShipBayBus
	for id: String in ORDER:
		if not trolleys.has(id):
			continue
		var t: Node3D = trolleys[id]
		var r: Dictionary = _rows[id]
		var st := str(t.get("status"))
		(r["status"] as Label).text = st if st != "" else "READY"
		(r["deck"] as Label).text = "%4.1f m" % float(t.get("deck_height"))
		var cargo: Dictionary = t.get("cargo")
		(r["cargo"] as Label).text = str(cargo.get("name", "—")).to_upper()
		(r["box"] as PanelContainer).add_theme_stylebox_override("panel", BsxTheme.slot_style(id == selected))
		if fleet.get("remote_id") == id:
			(r["status"] as Label).text = "REMOTE"
	var t: Node3D = trolleys.get(selected)
	if t:
		var spec := _spec(selected)
		_detail_title.text = str(spec["name"]).to_upper()
		var carries := PackedStringArray()
		for k: String in spec["carries"]:
			carries.append(k)
		_detail.text = "CARRIES   %s\nDECK      %.1f × %.1f m\nLIFTS TO  %.1f m\nSPEED     %.1f m/s\n%s" % [
				", ".join(carries).to_upper(), spec["deck"].x, spec["deck"].y, float(spec["lift"]), float(spec["speed"]),
				"REACHES INTO THE RACKS" if spec.get("picker", false) else ""]
		(_buttons["remote"] as Button).text = "LET IT GO" if fleet.get("remote_id") == selected else "REMOTE CONTROL"
	var waiting := 0
	var picked := 0
	if bus:
		for c: Dictionary in bus.delivered_crates().values():
			if str(c.get("carrier", "")) == "":
				waiting += 1
		picked = bus.picked_crates().size()
	_footer.text = "%d CRATE%s WAITING IN GOODS IN  ·  %d PICKED ON THE WAY" % [waiting, "" if waiting == 1 else "S", picked]


func _row(id: String) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", BsxTheme.slot_style(false))
	box.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	box.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			select(id))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(h)
	var spec := _spec(id)
	var letter := _text(spec["letter"], "mono_bold", 34, spec["colour"])
	letter.custom_minimum_size.x = 34 * scale_text
	h.add_child(letter)
	var vehicle := _text(str(spec["name"]).replace(" hover trolley", "").to_upper(), "display_medium", 28, BsxTheme.TEXT)
	vehicle.custom_minimum_size.x = 170 * scale_text
	h.add_child(vehicle)
	var status := _text("", "mono_medium", 22, BsxTheme.STATUS)
	status.custom_minimum_size.x = 250 * scale_text
	h.add_child(status)
	var deck := _text("", "mono", 22, BsxTheme.HUD)
	deck.custom_minimum_size.x = 100 * scale_text
	h.add_child(deck)
	var cargo := _text("", "mono", 20, BsxTheme.MUTED)
	cargo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(cargo)
	_rows[id] = {"box": box, "status": status, "deck": deck, "cargo": cargo}
	return box


func _button(action: String, label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	b.add_theme_font_override("font", BsxTheme.font("mono_medium"))
	b.add_theme_font_size_override("font_size", roundi(21 * scale_text))
	for state: String in ["normal", "hover", "pressed"]:
		var s := BsxTheme.slot_style(state != "normal")
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", BsxTheme.HUD)
	b.add_theme_color_override("font_hover_color", BsxTheme.ACCENT)
	b.pressed.connect(press.bind(action))
	_buttons[action] = b
	return b


func _text(t: String, face: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", BsxTheme.font(face))
	l.add_theme_font_size_override("font_size", roundi(size * scale_text))
	l.add_theme_color_override("font_color", colour)
	return l


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(BsxTheme.ACCENT, 0.3)
	r.custom_minimum_size.y = 2
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _spec(id: String) -> Dictionary:
	var t: Node3D = (fleet.get("trolleys") as Dictionary).get(id)
	return t.get("spec") if t else {}
