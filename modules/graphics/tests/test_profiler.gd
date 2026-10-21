extends ModuleTest
## The profiler: F3 (Keys "graphics.profiler") shows and hides it, it reads the frame rate,
## frame times, draw calls and lights, and its flag takes it away.
##   tools/run_tests.sh graphics


func run_tests() -> void:
	var bus := Modules.bus("graphics") as GfxBus
	Flags.set_flag(GfxBus.PROFILER, true)
	await frames(2)
	check(bus.profiler != null, "the profiler is there with its flag on")
	check(Keys.has("graphics.profiler"), "its key is in Key binds")
	check(Keys.key_of("graphics.profiler") == KEY_F3, "on F3 by default")
	var p := bus.profiler
	check(not p.visible, "hidden until asked for")

	var lamp := OmniLight3D.new()
	lamp.shadow_enabled = true
	add_child(lamp)
	var ev := InputEventAction.new()
	ev.action = "graphics.profiler"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(30)
	check(p.visible, "F3 shows it")
	check(p.frames.size() >= 20, "it keeps frame times")
	check(p.stats.has("fps") and p.stats.has("gpu_ms") and p.stats.has("draw_calls"), "it reads the monitors")
	check(int(p.stats.get("lights", 0)) >= 1 and int(p.stats.get("shadowed", 0)) >= 1, "it counts lights and shadowed lights")
	check(p.text().contains("FPS") and p.text().contains("GPU"), "the panel shows frame rate and GPU time")
	p.toggle()
	check(not p.visible, "toggles off")

	Flags.set_flag(GfxBus.PROFILER, false)
	await frames(2)
	check(bus.profiler == null and not Keys.has("graphics.profiler"), "flag off: gone, key too")
	lamp.queue_free()
