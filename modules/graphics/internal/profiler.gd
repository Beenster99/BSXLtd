extends CanvasLayer
## Graphics: the in-game profiler (flag "graphics.profiler", F3 by default, Keys action
## "graphics.profiler"). A panel in the top-left corner: frames per second, a frame-time
## graph, CPU and GPU time, draw calls, objects, triangles, lights and shadowed lights,
## video memory, and the graphics settings in use. Presentation only; reads Godot's
## Performance monitors and the viewport's measured render times.

const ACTION := "graphics.profiler"
## Frames kept in the graph.
const HISTORY := 240
## How often the slower counts (lights, settings) refresh, s.
const SLOW_EVERY := 0.5
## Graph scale: the top of the graph, ms.
const GRAPH_MS := 50.0
const INK := Color(0.62, 0.9, 1.0)
const DIM := Color(0.62, 0.9, 1.0, 0.45)
const GOOD := Color(0.45, 1.0, 0.55)
const WARN := Color(1.0, 0.75, 0.25)
const BAD := Color(1.0, 0.4, 0.3)

## Frame times (ms), oldest first.
var frames: PackedFloat32Array = []
## The last readings, by name (tests read them).
var stats: Dictionary = {}
var _label: Label
var _graph: Control
var _slow := 0.0


func _init() -> void:
	name = "Profiler"
	layer = 120
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.02, 0.035, 0.82)
	style.border_color = Color(INK, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(16, 16)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(360, 90)
	_graph.draw.connect(_draw_graph)
	box.add_child(_graph)
	_label = Label.new()
	_label.add_theme_font_override("font", BsxTheme.font("mono"))
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", INK)
	box.add_child(_label)


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(ACTION) and event.is_action_pressed(ACTION):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible


func _process(delta: float) -> void:
	frames.append(delta * 1000.0)
	if frames.size() > HISTORY:
		frames = frames.slice(frames.size() - HISTORY)
	if not visible:
		return
	_slow -= delta
	if _slow <= 0.0:
		_slow = SLOW_EVERY
		_count_lights()
	sample()
	_label.text = text()
	_graph.queue_redraw()


## Reads the monitors into `stats`.
func sample() -> void:
	var vp := get_viewport().get_viewport_rid()
	stats["fps"] = Performance.get_monitor(Performance.TIME_FPS)
	stats["frame_ms"] = frames[frames.size() - 1] if not frames.is_empty() else 0.0
	stats["worst_ms"] = _worst()
	stats["cpu_ms"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	stats["physics_ms"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	stats["render_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(vp) \
			+ RenderingServer.get_frame_setup_time_cpu()
	stats["gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(vp)
	stats["draw_calls"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	stats["objects"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	stats["triangles"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	stats["vram_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	stats["ram_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	stats["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if not stats.has("lights"):
		_count_lights()


func text() -> String:
	var lines: PackedStringArray = []
	lines.append("%4.0f FPS   %5.1f ms   worst %5.1f ms" % [stats.get("fps", 0.0), stats.get("frame_ms", 0.0), stats.get("worst_ms", 0.0)])
	lines.append("CPU  game %4.1f  physics %4.1f  render %4.1f ms" % [stats.get("cpu_ms", 0.0), stats.get("physics_ms", 0.0), stats.get("render_cpu_ms", 0.0)])
	lines.append("GPU  %5.1f ms" % stats.get("gpu_ms", 0.0))
	lines.append("Draw calls %d   objects %d" % [stats.get("draw_calls", 0), stats.get("objects", 0)])
	lines.append("Triangles  %s" % _thousands(int(stats.get("triangles", 0))))
	lines.append("Lights %d   with shadows %d   sun %d" % [stats.get("lights", 0), stats.get("shadowed", 0), stats.get("suns", 0)])
	lines.append("VRAM %.0f MB   RAM %.0f MB   nodes %d" % [stats.get("vram_mb", 0.0), stats.get("ram_mb", 0.0), stats.get("nodes", 0)])
	lines.append(String(stats.get("settings", "")))
	lines.append("%s  hide" % Keys.prompt(ACTION))
	return "\n".join(lines)


func _count_lights() -> void:
	var lights := 0
	var shadowed := 0
	var suns := 0
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		var light := l as Light3D
		if not light.is_visible_in_tree() or light.light_energy <= 0.0:
			continue
		if light is DirectionalLight3D:
			suns += 1
		else:
			lights += 1
		if light.shadow_enabled:
			shadowed += 1
	stats["lights"] = lights
	stats["shadowed"] = shadowed
	stats["suns"] = suns
	stats["settings"] = _settings()


func _settings() -> String:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size if vp else Vector2.ZERO
	var gi: String = ["off", "SSIL", "SDFGI", "SDFGI+SSIL"][clampi(int(GraphicsOptions.get_value("gi")), 0, 3)]
	var up: String = ["native", "FSR 1", "FSR 2.2"][clampi(int(GraphicsOptions.get_value("upscaler")), 0, 2)]
	return "%s  %dx%d  %s x%.2f  GI %s  %s" % [GraphicsOptions.preset, size.x, size.y, up,
			float(GraphicsOptions.get_value("render_scale")), gi, RenderingServer.get_current_rendering_method()]


func _worst() -> float:
	var worst := 0.0
	for ms in frames:
		worst = maxf(worst, ms)
	return worst


func _draw_graph() -> void:
	var size := _graph.size
	_graph.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	for ms: float in [16.7, 33.3]:
		var y := size.y * (1.0 - ms / GRAPH_MS)
		_graph.draw_line(Vector2(0, y), Vector2(size.x, y), DIM, 1.0)
		_graph.draw_string(BsxTheme.font("mono"), Vector2(size.x - 64, y - 3), "%.0f ms" % ms,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
	var w := size.x / float(HISTORY)
	var start := HISTORY - frames.size()
	for i in frames.size():
		var ms := frames[i]
		var h := minf(ms / GRAPH_MS, 1.0) * size.y
		var c := GOOD if ms <= 16.7 else (WARN if ms <= 33.3 else BAD)
		_graph.draw_rect(Rect2((start + i) * w, size.y - h, maxf(w, 1.0), h), c)


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
