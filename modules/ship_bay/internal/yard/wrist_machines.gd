extends VBoxContainer
## The Machines channel on the wrist screen, drawn on glass with UI's TerminalKit: a row per
## yard machine (the hover trolleys, the picking lift, the scissor lift, the power unit and
## the scaffold rigs) with what it is doing, where it is, and its buttons: DRIVE takes it
## (and puts the wrist away so you can), COME TO ME, BRING <part> TO ME (the picking lift
## fetches the next part the ship in the bay takes), PUT AWAY / TO STORES, and the lift's and
## power unit's own controls.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const Layout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")

signal close_requested

var fleet: Node
var glass := true

var _list: VBoxContainer
## Machine id -> {state: Label, tag: PanelContainer, where: Label, buttons: {action: Button}}.
var _rows: Dictionary = {}
var _tick := 0.0


func _init(p_fleet: Node, p_glass := true) -> void:
	fleet = p_fleet
	glass = p_glass
	name = "MachinesScreen"
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(T.columns([["MACHINE", 0], ["STATE", 118], ["WHERE", 118], ["", 372]]))
	_list = T.list()
	add_child(_list.get_parent())
	_build()


func _access() -> Node:
	var yard: Node = fleet.get("yard") if fleet else null
	var bay: Node = yard.get("bay") if yard else null
	return bay.get("access") if bay else null


## The machines, in order: [id, name, actions].
func machines() -> Array:
	var out: Array = []
	if fleet:
		var trolleys: Dictionary = fleet.get("trolleys")
		for id: String in trolleys:
			var t: Node = trolleys[id]
			var acts := ["drive", "come", "bring", "stores"] if bool(t.call("is_picker")) else ["drive", "come", "put_away"]
			out.append(["trolley:" + id, str(t.get("spec")["name"]), acts])
	var access := _access()
	if access:
		if access.get("lift"):
			out.append(["lift", "Scissor lift", ["drive", "up", "down"]])
		if access.get("unit"):
			out.append(["unit", "Ground power unit", ["drive", "power"]])
		var rigs: Array = access.get("scaffolds")
		for i in rigs.size():
			out.append(["rig%d" % i, "Scaffold rig %s" % rigs[i].get("label"), ["drive"]])
	return out


func _build() -> void:
	var all := machines()
	for i in all.size():
		var m: Array = all[i]
		var id: String = m[0]
		var state := T.label("", "mono_medium", 15, T.GOOD)
		var tag_box := PanelContainer.new()
		var st := T.box(Color(T.GOOD, 0.16), T.GOOD, 1, 0.0)
		st.content_margin_left = 6
		st.content_margin_right = 6
		tag_box.add_theme_stylebox_override("panel", st)
		tag_box.add_child(state)
		tag_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tag_cell := CenterContainer.new()
		tag_cell.custom_minimum_size.x = 118
		tag_cell.add_child(tag_box)
		var where := T.cell("", 118, T.TEXT)
		var acts := HBoxContainer.new()
		acts.custom_minimum_size.x = 372
		acts.alignment = BoxContainer.ALIGNMENT_END
		acts.add_theme_constant_override("separation", 4)
		var buttons := {}
		for a: String in m[2]:
			var b := T.button(_label_for(id, a), a == "come" or a == "bring", 14, false, glass)
			b.name = a
			b.pressed.connect(press.bind(id, a))
			acts.add_child(b)
			buttons[a] = b
		var r := T.row([T.cell_text(str(m[1])), tag_cell, where, acts], i % 2 == 1, glass)
		r.name = "Row_" + id.validate_node_name()
		_list.add_child(r)
		_rows[id] = {"state": state, "tag": tag_box, "where": where, "buttons": buttons}
	refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.4
		refresh()


## Updates every row's state, place and button labels in place.
func refresh() -> void:
	var access := _access()
	for id: String in _rows:
		var row: Dictionary = _rows[id]
		var s := state_of(id)
		(row.state as Label).text = str(s[0]).to_upper()
		(row.state as Label).add_theme_color_override("font_color", s[1])
		var st := (row.tag as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		st.bg_color = Color(s[1], 0.16)
		st.border_color = s[1]
		var at := _position_of(id)
		(row.where as Label).text = room_name(at)
		for a: String in row.buttons:
			var b: Button = row.buttons[a]
			b.text = _label_for(id, a)
			if a == "bring":
				b.disabled = str(fleet.call("next_part_for_ship")) == ""
		if access and (row.buttons as Dictionary).has("drive"):
			var mine := str(access.get("driving")) == id if not id.begins_with("trolley:") else str(fleet.get("remote_id")) == id.trim_prefix("trolley:")
			(row.buttons["drive"] as Button).text = "LET GO" if mine else "DRIVE"


## [text, colour] for a machine's state.
func state_of(id: String) -> Array:
	var access := _access()
	if id.begins_with("trolley:"):
		var t: Node = fleet.get("trolleys")[id.trim_prefix("trolley:")]
		var status := str(t.get("status")).to_lower()
		if str(fleet.get("remote_id")) == id.trim_prefix("trolley:"):
			return ["remote", T.CYAN]
		if ["parked", "all put away", "here", "stopped"].has(status):
			return ["idle" if status != "here" else "waiting", T.GOOD]
		return [status.left(12), T.AMBER]
	if access == null:
		return ["—", T.DIM]
	if str(access.get("driving")) == id:
		return ["driving", T.CYAN]
	match id:
		"lift":
			return ["at %.1f m" % float(access.call("lift_height")), T.GOOD]
		"unit":
			if bool(access.get("power_on")):
				return ["power on", T.CYAN]
			return ["plugged in" if str(access.get("plug_state")) == "hull" else "off", T.GOOD if str(access.get("plug_state")) == "hull" else T.DIM]
	if id.begins_with("rig"):
		var rig: Node = access.get("scaffolds")[int(id.trim_prefix("rig"))]
		return ["%d x %d" % [int(rig.get("bays")), int(rig.get("lifts"))], T.GOOD]
	return ["—", T.DIM]


## The yard room a point is in ("Courtyard" outside them all).
static func room_name(at: Vector3) -> String:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	if bus and at != Vector3.INF:
		var rooms := bus.shipyard_rooms()
		for id: String in rooms:
			if (rooms[id]["box"] as AABB).has_point(at + Vector3(0, 0.5, 0)):
				return str(rooms[id]["name"])
	return "Courtyard"


func _position_of(id: String) -> Vector3:
	if id.begins_with("trolley:"):
		return (fleet.get("trolleys")[id.trim_prefix("trolley:")] as Node3D).global_position
	var access := _access()
	if access == null:
		return Vector3.INF
	var node: Node3D = null
	match id:
		"lift":
			node = access.get("lift")
		"unit":
			node = access.get("unit")
		_:
			if id.begins_with("rig"):
				node = access.get("scaffolds")[int(id.trim_prefix("rig"))]
	return node.global_position if node and node.is_inside_tree() else Vector3.INF


func _label_for(id: String, action: String) -> String:
	match action:
		"drive":
			return "DRIVE"
		"come":
			return "COME TO ME"
		"bring":
			var part := str(fleet.call("next_part_for_ship")) if fleet else ""
			var part_name := str(Layout.items().get(part, {}).get("name", part)) if part != "" else "PART"
			if part_name.length() > 14:
				part_name = part_name.left(13).strip_edges() + "."
			return "BRING %s" % part_name.to_upper()
		"stores":
			return "TO STORES"
		"put_away":
			return "PUT AWAY"
		"up":
			return "RAISE"
		"down":
			return "LOWER"
		"power":
			var access := _access()
			return "POWER OFF" if access and bool(access.get("switch_on")) else "POWER ON"
	return action.to_upper()


## A row's button (tests call it): id is "trolley:<s|m|l|p>", "lift", "unit" or "rig<i>".
func press(id: String, action: String) -> void:
	var access := _access()
	var trolley := id.trim_prefix("trolley:") if id.begins_with("trolley:") else ""
	Sfx.play("click")
	match action:
		"drive":
			if trolley != "":
				var taking := str(fleet.get("remote_id")) != trolley
				fleet.call("toggle_remote", trolley)
				if taking:
					close_requested.emit()
			elif access:
				var taking := str(access.get("driving")) != id
				access.call("toggle_drive", id)
				if taking:
					close_requested.emit()
		"come":
			fleet.call("call_to_me", trolley)
		"bring":
			fleet.call("fetch_for_ship")
		"stores":
			fleet.call("park", trolley)
		"put_away":
			(Modules.bus("ship_bay") as ShipBayBus).command_trolley(trolley, "put_away")
		"up":
			access.call("lift_up")
		"down":
			access.call("lift_down")
		"power":
			access.call("toggle_power")
	refresh()


## Every label's and button's text, for tests.
func text() -> String:
	var parts := PackedStringArray()
	_gather(self, parts)
	return " | ".join(parts)


func _gather(n: Node, out: PackedStringArray) -> void:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_gather(c, out)
