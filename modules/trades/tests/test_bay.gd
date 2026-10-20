extends ModuleTest
## The bay: four stations on one bench, the menu's trade picker, focus and the hotbar.


func run_tests() -> void:
	var bus := Modules.bus("trades") as TradesBus
	var ids: Array = Menu.entries().filter(func(e: Dictionary) -> bool: return e.group == "Workbench").map(
			func(e: Dictionary) -> String: return e.id)
	check(ids == ["bench_bolting", "bench_riveting", "bench_welding", "bench_wiring"], "a menu entry per trade, in order")
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
	bay._on_key(KEY_5)
	await frames(1)
	check(bay.tool == &"welder" and bay.tool_node(&"welder").visible, "number keys pick tools; the tool shows in hand")
	bay._on_key(KEY_3)
	await frames(1)
	check(bay.tool == &"drill" and not bay.tool_node(&"welder").visible, "only the tool in hand shows")
	bay.cycle_tool(1)
	check(bay.tool == &"rivet_squeezer", "the wheel moves to the next tool")
	bay.set_tool(&"wire_tool")
	bay.cycle_tool(1)
	check(bay.tool == &"hands", "and wraps round past the last")
	bay.cycle_tool(-1)
	check(bay.tool == &"wire_tool", "and back the other way")
	bay._on_key(KEY_E)
	bay.queue_free()
	await frames(1)
