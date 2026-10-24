extends ModuleTest
## G6, ships' screens: led_screen() lays a glowing page over a screen's glass, the same size
## and just in front of it; it starts off, boots when switched on and draws its page in its
## own viewport; the flag off gives nothing (the owner keeps its own text).
##   tools/run_tests.sh graphics


func run_tests() -> void:
	var bus := Modules.bus("graphics") as GfxBus
	Flags.set_flag(GfxBus.SCREENS, true)
	var ship := Node3D.new()
	add_child(ship)
	var glass := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.66, 0.4125)
	glass.mesh = qm
	glass.position = Vector3(1, 1.4, -2)
	ship.add_child(glass)

	var kinds := ["monitor", "cockpit_screen", "cockpit_monitor", "nav_display", "map_screen", "plain"]
	var screens: Array[Node3D] = []
	for k: String in kinds:
		var s := bus.led_screen(glass, k, "HOLD MONITOR\nHOLD  0 KG\n!BAY DOOR OPEN")
		check(s != null and s.get_parent() == ship, "a %s screen sits beside its glass" % k)
		screens.append(s)
	await frames(2)
	var s0 := screens[0]
	check(not s0.visible and not s0.is_processing(), "a screen starts off")
	check(s0.position.distance_to(glass.position + Vector3(0, 0, 0.0015)) < 0.0001, "just in front of the glass")
	var glow := s0.get_node("Glow") as MeshInstance3D
	check((glow.mesh as QuadMesh).size == qm.size, "the same size as the glass")
	var vp := s0.get_node("Page") as SubViewport
	check(vp.size.x > vp.size.y and vp.size.y >= 160 and vp.size.x <= 1024, "its page is sized to the glass: %s" % vp.size)
	for s in screens:
		s.set_on(true)
	check(s0.visible and s0.is_processing(), "switched on, it shows and runs")
	await get_tree().create_timer(1.0).timeout
	var mat := glow.material_override as ShaderMaterial
	check(is_equal_approx(float(mat.get_shader_parameter("power")), 1.0), "booted: full brightness")
	s0.set_text("NEW PAGE")
	check(s0.text == "NEW PAGE", "the page's text changes")
	s0.set_on(false)
	check(not s0.visible and not s0.is_processing(), "switched off, it blanks")

	Flags.set_flag(GfxBus.SCREENS, false)
	check(bus.led_screen(glass, "monitor", "X") == null, "flag off: no screen (the owner keeps its own text)")
	Flags.set_flag(GfxBus.SCREENS, true)
	ship.queue_free()
	await frames(2)
