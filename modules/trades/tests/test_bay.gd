extends ModuleTest
## The bay: four stations on one bench, the menu's trade picker, focus and the hotbar.


func run_tests() -> void:
	var bus := Modules.bus("trades") as TradesBus
	check(not Menu.entries().any(func(e: Dictionary) -> bool: return String(e.id).begins_with("bench_")),
			"the practice bench is off the front menu")
	check(bus.is_tool_enabled(&"hands") and not bus.is_tool_enabled(&"spanner"), "tools follow the trade flags")

	Router.args = {"trade": "welding"}
	var bay: Node = load(TradesBus.BENCH_SCENE).instantiate()
	add_child(bay)
	await frames(2)
	Router.args = {}
	check(bay.stations.size() == 4, "four stations on the bench")
	check(bay.focus() == bay.station(&"welding"), "the menu's trade picks the station you start at")
	var welder_x: float = bay.station(&"welding").global_position.x
	check(absf(bay.worker.global_position.x - welder_x) < 0.01, "you start standing at it")
	bay.worker.face(bay.station(&"bolting").to_global(Vector3(0, 0.9, 0)))
	await frames(2)
	check(bay.focus() == bay.station(&"bolting"), "looking along the bench moves the focus to that station")
	bay._on_action(TradesBus.KEY_TOOL + "5")
	await frames(1)
	check(bay.tool == &"welder" and bay.tool_node(&"welder").visible, "number keys pick tools; the tool shows in hand")
	bay._on_action(TradesBus.KEY_TOOL + "3")
	await frames(1)
	check(bay.tool == &"drill" and not bay.tool_node(&"welder").visible, "only the tool in hand shows")
	bay.cycle_tool(1)
	check(bay.tool == &"rivet_squeezer", "the wheel moves to the next tool")
	bay.set_tool(&"wire_tool")
	bay.cycle_tool(1)
	check(bay.tool == &"hands", "and wraps round past the last")
	bay.cycle_tool(-1)
	check(bay.tool == &"wire_tool", "and back the other way")
	bay._on_action(TradesBus.KEY_TURN_RIGHT)

	# Keys are actions in Settings > Key binds: the default key works, and so does a new one.
	check(Keys.has(TradesBus.KEY_TOOL + "2") and Keys.key_of(TradesBus.KEY_VIEW) == KEY_V, "the Tools keys are in Key binds")
	bay._handle_input(_key(KEY_2))
	check(bay.tool == bay.hotbar[1], "pressing 2 picks tool 2")
	Keys.rebind(TradesBus.KEY_TOOL + "2", KEY_K)
	bay.set_tool(&"hands")
	bay._handle_input(_key(KEY_2))
	check(bay.tool == &"hands", "moved off 2, the key does nothing")
	bay._handle_input(_key(KEY_K))
	check(bay.tool == bay.hotbar[1], "and the new key picks the tool")
	Keys.reset(TradesBus.KEY_TOOL + "2")

	# Carrying: hold left click on the bracket with your hands; the wheel turns it.
	var bolting: Node = bay.station(&"bolting")
	bay.set_tool(&"hands")
	bay.worker.global_position = bolting.to_global(Vector3(0.2, 0, 0.5))
	bay.worker.face(bolting._bracket.global_position)
	await frames(2)
	bay._on_mouse_button(_click(MOUSE_BUTTON_LEFT, true))
	check(bolting._carrying, "holding left click on the bracket picks it up")
	var yaw: float = bolting._bracket_yaw
	bay._on_mouse_button(_click(MOUSE_BUTTON_WHEEL_DOWN, true))
	check(is_equal_approx(bolting._bracket_yaw, yaw + 5.0) and bay.tool == &"hands", "the wheel turns the held part, not the tool")
	bay._on_mouse_button(_click(MOUSE_BUTTON_MIDDLE, true))
	check(bay.turn_snap, "middle click swaps to 90 degree steps")
	bay._on_mouse_button(_click(MOUSE_BUTTON_WHEEL_UP, true))
	check(is_equal_approx(bolting._bracket_yaw, 0.0), "snapping squares it up a quarter turn back")
	bay._on_mouse_button(_click(MOUSE_BUTTON_WHEEL_DOWN, true))
	check(is_equal_approx(bolting._bracket_yaw, 90.0), "and turns a whole quarter a notch")
	bay._on_mouse_button(_click(MOUSE_BUTTON_LEFT, false))
	check(not bolting._carrying, "letting go of left click sets it down")
	bay._on_mouse_button(_click(MOUSE_BUTTON_WHEEL_DOWN, true))
	check(bay.tool == &"torque_wrench", "with nothing held the wheel picks tools again")
	var plain := TradesTool.new()
	check(plain.readout_fill() < 0.0, "a tool with no screen has no bar")
	plain.free()
	var wrench: TradesTorqueWrench = bay.tool_node(&"torque_wrench")
	wrench.set_nm = 25.0
	wrench.applied_nm = 12.5
	check("12.5" in wrench.readout_text() and is_equal_approx(wrench.readout_fill(), 0.5), "the wrench's screen reads the torque and fills toward the setting")
	var torch: TradesWeldTorch = bay.tool_node(&"welder")
	check("%d A" % roundi(bay.station(&"welding").seam.amps) in torch.readout_text(), "the torch's screen shows the welder's amps")
	bay.queue_free()
	await frames(1)


func _click(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.pressed = true
	return ev
