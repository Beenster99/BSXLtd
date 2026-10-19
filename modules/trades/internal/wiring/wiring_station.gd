extends TradesStation
## Wiring: a test board with a 24 V supply, a switch and a lamp, each with two screw
## terminals. Run wires between terminals with your hands (Tab picks red or black), strip
## each end and crimp a ferrule on it with the crimper, then flip the switch to test. The
## right circuit is S+ to COM, NO to L+, L- to S-. All the rules live in WireCircuit.

const BENCH_TOP := TradesBay.BENCH_TOP
const BOARD_Y := BENCH_TOP + 0.012
## The posts' tops, where the ends go.
const POST_Y := BOARD_Y + 0.012
const TERMINAL_AT: Array[Vector2] = [
	Vector2(-0.13, 0.035), Vector2(-0.09, 0.035), Vector2(-0.02, 0.035),
	Vector2(0.02, 0.035), Vector2(0.09, 0.035), Vector2(0.13, 0.035),
]
const SWITCH_AT := Vector3(0.0, BOARD_Y, -0.03)
const LAMP_AT := Vector3(0.11, BOARD_Y, -0.03)
const PICK_TERMINAL_M := 0.016
const PICK_SWITCH_M := 0.03
const STRIP_MM_PER_PX := 0.04
const CRIMP_PER_PX := 1.0 / 250.0
const SEGMENTS := 12
const WIRE_COLOURS := {&"red": Color(0.75, 0.1, 0.08), &"black": Color(0.06, 0.06, 0.07)}

var circuit: WireCircuit
var site: JointSite
var colour_index := 0
var wire_tool: TradesWireTool

var STEEL := TradesLook.paint(Color(0.62, 0.64, 0.66), 0.8, 0.3, "brushed_steel")
var DARK := TradesLook.paint(TradesLook.DARK, 0.55, 0.5)
var BODY := TradesLook.paint(TradesLook.TRIM, 0.3, 0.45)
var BRASS := TradesLook.paint(Color(0.82, 0.66, 0.3), 0.9, 0.3)
var COPPER := TradesLook.glow(Color(0.85, 0.48, 0.25), 0.15)
var FERRULE := TradesLook.paint(Color(0.85, 0.86, 0.88), 0.9, 0.25)

## A wire end being carried to its second terminal (-1 when none).
var _start := -1
var _live: Array[MeshInstance3D] = []
var _wires: Node3D
var _ends: Array[Node3D] = []
var _lever: Node3D
var _bulb: MeshInstance3D
var _bulb_on: Material
var _bulb_off: Material
var _lamp_light: OmniLight3D
var _working := -1
var _mode := ""
var _pull_px := 0.0
var _clicked := false
var _started := false


func build() -> void:
	title = "Wiring"
	half_width = 0.55
	var spec := JointSpec.new()
	spec.trade = &"WIRE"
	spec.fastener_id = &"ferrule_1.5mm2"
	spec.torque_target_nm = 0.0
	spec.needs_washer = false
	circuit = WireCircuit.new(spec)
	circuit.changed.connect(_on_circuit_changed)
	circuit.completed.connect(_on_circuit_completed)
	wire_tool = bay.tool_node(&"wire_tool") as TradesWireTool
	_build_board()
	_build_site(spec)
	_wires = Node3D.new()
	_wires.name = "Wires"
	add_child(_wires)
	for i in SEGMENTS:
		_live.append(_segment(self, Color.WHITE))
	reset()


func tools() -> Array[StringName]:
	return [&"hands", &"wire_tool"]


func status_line() -> String:
	var colour := String(WireCircuit.COLOURS[colour_index]).to_upper()
	return "WIRE    %s 1.5 MM2%s" % [colour, "  END IN HAND" if _start >= 0 else ""]


func start_hint() -> String:
	return "Wire S+ to COM, NO to L+ and L- to S-. Click a terminal with your hands to run a wire."


func key(k: Key) -> bool:
	if k == KEY_TAB:
		colour_index = (colour_index + 1) % WireCircuit.COLOURS.size()
		return true
	return false


func is_busy() -> bool:
	return _working >= 0 or _start >= 0


func reset() -> void:
	if circuit.is_complete():
		_bus_remove()
	_stop_hands()
	_start = -1
	_started = false
	circuit.reset()


func motion(relative: Vector2) -> bool:
	if _working < 0:
		return false
	_pull_px = maxf(0.0, _pull_px + relative.y)
	if _mode == "crimp" and _pull_px * CRIMP_PER_PX >= 1.0:
		_pull_px = 1.0 / CRIMP_PER_PX
		if not _clicked:
			_clicked = true
			wire_tool.click()
			bay.play(&"click", 1.2)
			bay.worker.kick(0.008)
			bay.hint("Click. Let go.")
	return true


func press(tool: StringName) -> void:
	var worker := bay.worker
	if tool == &"wire_tool":
		var t := _terminal_under_aim()
		if t < 0:
			return
		if not worker.right_hand.can_reach(_terminal_world(t)):
			bay.hint("Too far. Step closer.")
			return
		match circuit.end_state[t]:
			WireCircuit.End.LAID:
				_mode = "strip"
				bay.hint("Pull the mouse back to strip. About 8 mm for the ferrule.")
			WireCircuit.End.STRIPPED:
				_mode = "crimp"
				bay.hint("Pull the mouse back to crimp, right to the click.")
			WireCircuit.End.TERMINATED:
				bay.hint("That end is done. Right click cuts it back.")
				return
			_:
				bay.hint("Run a wire to that terminal first (hands, 1).")
				return
		_working = t
		_pull_px = 0.0
		_clicked = false
		worker.look_locked = true
		_mark_started()
		return
	if tool != &"hands":
		bay.hint("Wiring takes your hands (1) and the crimper (6).")
		return
	if bay.aim_distance(world(SWITCH_AT + Vector3(0, 0.03, 0))) < PICK_SWITCH_M and _terminal_under_aim() < 0:
		circuit.set_switch(not circuit.switch_on)
		bay.play(&"clunk", 1.6)
		worker.right_hand.reach_to(world(SWITCH_AT + Vector3(0, 0.035, 0)))
		if circuit.switch_on and not circuit.is_ready_to_test():
			bay.hint("Switched on, but some ends aren't done yet.")
		return
	var t := _terminal_under_aim()
	if t < 0:
		return
	if not worker.left_hand.can_reach(_terminal_world(t)):
		bay.hint("Too far. Step closer.")
		return
	if _start < 0:
		if circuit.end_state[t] != WireCircuit.End.EMPTY:
			bay.hint("That terminal has a wire. Right click pulls it off.")
			return
		_start = t
		_mark_started()
		bay.hint("Now click the terminal at the other end.")
	elif t == _start:
		_start = -1
		worker.left_hand.come_back()
		bay.hint("Wire dropped.")
	elif circuit.lay(_start, t, WireCircuit.COLOURS[colour_index]):
		_start = -1
		worker.left_hand.come_back()
		bay.play(&"tick", 1.2)
		bay.hint("Wire run. Strip and crimp both ends with the crimper (6).")
	else:
		bay.hint("That terminal has a wire already.")


func release() -> void:
	if _working < 0:
		return
	var t := _working
	_working = -1
	bay.worker.look_locked = false
	bay.worker.right_hand.come_back()
	if _mode == "strip":
		var mm := _pull_px * STRIP_MM_PER_PX
		if mm < 1.0:
			bay.hint("Pull further to strip it.")
		else:
			circuit.strip(t, mm)
			bay.play(&"tick", 0.8)
			bay.hint("Stripped %.1f mm. Now crimp it (click again)." % mm)
	elif _mode == "crimp":
		circuit.crimp_end(t, _pull_px * CRIMP_PER_PX)
		bay.hint("Ferrule on and screwed in." if _clicked else "Let go before the click: that crimp is loose.")
	_mode = ""
	wire_tool.mode = ""


func back_out(tool: StringName) -> void:
	var t := _terminal_under_aim()
	if t < 0:
		if tool == &"hands" and _start >= 0:
			_start = -1
			bay.worker.left_hand.come_back()
		return
	var stale := false
	if tool == &"wire_tool":
		stale = circuit.cut_back(t)
		bay.hint("End cut back. Strip it again.")
	elif tool == &"hands" and circuit.wire_at(t) >= 0:
		stale = circuit.remove_wire_at(t)
		bay.hint("Wire pulled off.")
	if stale:
		_bus_remove()
		bay.hide_result()


func update(_delta: float) -> void:
	var worker := bay.worker
	for s in _live:
		s.visible = _start >= 0
	if _start >= 0:
		var hand := worker.left_hand.palm() * Vector3(0, -0.02, -0.05)
		worker.left_hand.set_grip(0.7)
		_lay_segments(_live, _terminal_world(_start), hand, 0.0, WIRE_COLOURS[WireCircuit.COLOURS[colour_index]])
	if _working >= 0:
		var at := _terminal_world(_working) + Vector3(0, 0.006, 0)
		var xform := Transform3D(Basis(Vector3.UP, _face_yaw(at)), at)
		bay.place_tool(&"wire_tool", xform)
		worker.right_hand.reach_to(xform * TradesWireTool.GRIP + Vector3(0, 0.015, 0))
		if _mode == "strip":
			wire_tool.mode = "strip"
			wire_tool.value = _pull_px * STRIP_MM_PER_PX
			wire_tool.closed = 0.6
		else:
			wire_tool.mode = "crimp"
			wire_tool.value = _pull_px * CRIMP_PER_PX
			wire_tool.closed = wire_tool.value
		worker.right_hand.set_grip(0.6 + 0.4 * wire_tool.closed)
	else:
		wire_tool.closed = 0.0
	_bulb.material_override = _bulb_on if circuit.lamp_lit else _bulb_off
	_lamp_light.visible = circuit.lamp_lit
	_lever.rotation_degrees.x = -25.0 if circuit.switch_on else 25.0


func _stop_hands() -> void:
	_working = -1
	_mode = ""
	if wire_tool:
		wire_tool.mode = ""
	if bay and bay.worker:
		bay.worker.look_locked = false
		bay.worker.left_hand.come_back()
		bay.worker.right_hand.come_back()


func _mark_started() -> void:
	if _started:
		return
	_started = true
	var bus := bay.bus()
	if bus:
		bus.joint_started.emit(site.joint_id, site.spec.trade, 1)


func _on_circuit_changed() -> void:
	if _wires == null:
		return
	for child in _wires.get_children():
		child.queue_free()
	for w in circuit.wires:
		var holder := Node3D.new()
		_wires.add_child(holder)
		var segs: Array[MeshInstance3D] = []
		for i in SEGMENTS:
			segs.append(_segment(holder, WIRE_COLOURS[w.colour]))
		var a := _terminal_world(w.a) + Vector3(0, 0.004, 0)
		var b := _terminal_world(w.b) + Vector3(0, 0.004, 0)
		_lay_segments(segs, a, b, 0.03 + a.distance_to(b) * 0.2, WIRE_COLOURS[w.colour])
	for t in WireCircuit.TERMINALS.size():
		_pose_end(t)
	var bus := bay.bus()
	if bus and _started:
		bus.joint_progress.emit(site.joint_id, circuit.progress())


func _on_circuit_completed() -> void:
	var m := circuit.measurements()
	var bus := bay.bus()
	if bus:
		bus.complete_joint(site, m)
	var lines: PackedStringArray = ["CIRCUIT TESTED", ""]
	lines.append("Lamp: %s" % ("LIT" if circuit.lamp_lit else "dark"))
	lines.append("Continuity: %s" % ("OPEN" if m.continuity_ohm < 0.0 else "%.2f ohm (max %.1f)" % [m.continuity_ohm, m.continuity_max_ohm]))
	lines.append("Insulation: %d Mohm (min %d)" % [roundi(m.insulation_mohm), roundi(m.insulation_min_mohm)])
	var ends: Array = m.terminals
	for i in ends.size():
		lines.append("%-3s strip %.1f mm, crimp %d N%s" % [ends[i], m.strip_length_mm[i], roundi(m.crimp_pull_n[i]),
				", bare copper" if m.bare_mm[i] > circuit.bare_limit_mm else ""])
	if m.miswired:
		lines.append("MISWIRED")
	elif not m.polarity_ok:
		lines.append("Lamp polarity reversed")
	if not m.colour_ok:
		lines.append("Wire colours: red is the positive side")
	bay.show_result(lines)
	bay.hint("Tested.")


## Release screenshot: two wires terminated, the third run and the crimper closing on its end.
func stage_for_screenshot() -> void:
	circuit.lay(WireCircuit.SUPPLY_POS, WireCircuit.SWITCH_COM, &"red")
	circuit.lay(WireCircuit.SWITCH_NO, WireCircuit.LAMP_POS, &"red")
	circuit.lay(WireCircuit.LAMP_NEG, WireCircuit.SUPPLY_NEG, &"black")
	for t in [0, 2, 3, 4, 5]:
		circuit.strip(t, 8.0)
		if t != 5:
			circuit.crimp_end(t, 1.0)
	circuit.strip(1, 7.5)
	bay.set_tool(&"wire_tool")
	_working = 1
	_mode = "crimp"
	_pull_px = 0.7 / CRIMP_PER_PX
	bay.hint("Pull the mouse back to crimp, right to the click.")


func screenshot_view() -> Array[Vector3]:
	return [Vector3(-0.02, 0.0, 0.4), Vector3(-0.02, BOARD_Y, 0.0)]


# --- Building --------------------------------------------------------------------------

func _build_board() -> void:
	# The board: a dark panel with an orange edge.
	paint_box(Vector3(0.36, 0.012, 0.16), Vector3(0, BENCH_TOP + 0.006, 0), DARK)
	paint_box(Vector3(0.364, 0.004, 0.164), Vector3(0, BENCH_TOP + 0.002, 0), BODY)
	# Supply: an orange case with a lit screen.
	var supply := Vector3(-0.11, BOARD_Y, -0.03)
	paint_box(Vector3(0.09, 0.05, 0.06), supply + Vector3(0, 0.025, 0), BODY)
	var screen := TradesLook.readout(self, supply + Vector3(0, 0.03, 0.031), Vector2(0.06, 0.024))
	screen.text = "24.0 V"
	# Switch: a dark box with a toggle lever.
	paint_box(Vector3(0.05, 0.03, 0.04), SWITCH_AT + Vector3(0, 0.015, 0), DARK)
	paint_box(Vector3(0.054, 0.004, 0.044), SWITCH_AT + Vector3(0, 0.03, 0), STEEL)
	_lever = Node3D.new()
	_lever.position = SWITCH_AT + Vector3(0, 0.032, 0)
	add_child(_lever)
	paint_cylinder(0.003, 0.025, Vector3(0, 0.0125, 0), STEEL, _lever, 8)
	paint_cylinder(0.005, 0.006, Vector3(0, 0.026, 0), BODY, _lever, 10)
	# Lamp: a holder with a bulb that lights.
	paint_cylinder(0.018, 0.02, LAMP_AT + Vector3(0, 0.01, 0), DARK)
	_bulb_off = TradesLook.metal(Color(0.85, 0.85, 0.8), 0.0, 0.1)
	_bulb_on = TradesLook.glow(Color(1.0, 0.85, 0.55), 4.0)
	_bulb = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.016
	sphere.height = 0.032
	_bulb.mesh = sphere
	_bulb.position = LAMP_AT + Vector3(0, 0.034, 0)
	add_child(_bulb)
	_lamp_light = OmniLight3D.new()
	_lamp_light.position = _bulb.position + Vector3(0, 0.02, 0)
	_lamp_light.light_color = Color(1.0, 0.85, 0.6)
	_lamp_light.light_energy = 1.2
	_lamp_light.omni_range = 0.8
	_lamp_light.visible = false
	add_child(_lamp_light)
	# Terminal posts with their names, red for the supply's positive.
	for t in TERMINAL_AT.size():
		var at := Vector3(TERMINAL_AT[t].x, BOARD_Y, TERMINAL_AT[t].y)
		paint_cylinder(0.006, 0.012, at + Vector3(0, 0.006, 0), BRASS, self, 12)
		paint_cylinder(0.0045, 0.002, at + Vector3(0, 0.0125, 0), STEEL, self, 6)
		bench_label(String(WireCircuit.TERMINALS[t]), at + Vector3(0, 0.0005, 0.022))
	for x: float in [-0.11, 0.0, 0.11]:
		paint_box(Vector3(0.06, 0.0006, 0.01), Vector3(x, BOARD_Y + 0.0003, 0.012), BODY)  # bus markers


func _build_site(spec: JointSpec) -> void:
	site = JointSite.new()
	site.name = "TestCircuit"
	site.joint_id = &"bench_circuit"
	site.spec = spec
	add_child(site)
	for t in TERMINAL_AT.size():
		var m := Marker3D.new()
		m.name = String(WireCircuit.TERMINALS[t]).replace("+", "_pos").replace("-", "_neg")
		m.position = Vector3(TERMINAL_AT[t].x, POST_Y, TERMINAL_AT[t].y)
		site.add_child(m)
		# What sits on the post: bare insulation, a copper tail, or a ferrule.
		var end := Node3D.new()
		end.name = "End%d" % t
		end.position = m.position
		add_child(end)
		paint_cylinder(0.0022, 0.004, Vector3(0, 0.002, 0), COPPER, end, 8).name = "Copper"
		paint_cylinder(0.0024, 0.008, Vector3(0, 0.004, 0), FERRULE, end, 10).name = "Ferrule"
		_ends.append(end)


func _pose_end(t: int) -> void:
	var s := circuit.end_state[t]
	var end := _ends[t]
	var copper := end.get_node("Copper") as MeshInstance3D
	copper.visible = s == WireCircuit.End.STRIPPED or (s == WireCircuit.End.TERMINATED and circuit.bare_mm(t) > 0.0)
	var tail := circuit.strip_mm[t] if s == WireCircuit.End.STRIPPED else circuit.bare_mm(t)
	copper.scale.y = maxf(0.1, tail / 4.0)
	copper.position.y = (0.008 if s == WireCircuit.End.TERMINATED else 0.0) + tail / 2000.0
	end.get_node("Ferrule").visible = s == WireCircuit.End.TERMINATED


## Hang segments in an arc from a to b (world points), `lift` metres high in the middle.
func _lay_segments(segs: Array[MeshInstance3D], a: Vector3, b: Vector3, lift: float, colour: Color) -> void:
	var pts: Array[Vector3] = []
	for i in segs.size() + 1:
		var u := float(i) / segs.size()
		pts.append(to_local(a.lerp(b, u) + Vector3(0, lift * 4.0 * u * (1.0 - u), 0)))
	for i in segs.size():
		var s := segs[i]
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var dir := p1 - p0
		var length := dir.length()
		if length < 0.0001:
			s.visible = false
			continue
		var y := dir / length
		var side := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
		s.transform = Transform3D(Basis(side, y * length, side.cross(y)), (p0 + p1) * 0.5)
		(s.material_override as StandardMaterial3D).albedo_color = colour


func _segment(parent: Node, colour: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0018
	mesh.bottom_radius = 0.0018
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	var s := MeshInstance3D.new()
	s.mesh = mesh
	s.material_override = TradesLook.metal(colour, 0.0, 0.55)
	s.visible = false
	parent.add_child(s)
	if parent != self:
		s.visible = true
	return s


func _terminal_world(t: int) -> Vector3:
	return world(Vector3(TERMINAL_AT[t].x, POST_Y, TERMINAL_AT[t].y))


func _terminal_under_aim() -> int:
	var points: Array = []
	for t in TERMINAL_AT.size():
		points.append(_terminal_world(t))
	return bay.pick(points, PICK_TERMINAL_M)


func _face_yaw(at: Vector3) -> float:
	var to_worker := bay.worker.global_position - at
	return atan2(to_worker.x, to_worker.z)


func _bus_remove() -> void:
	var bus := bay.bus()
	if bus:
		bus.remove_joint(site.joint_id)
