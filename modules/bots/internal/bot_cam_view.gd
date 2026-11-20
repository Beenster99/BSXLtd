extends PanelContainer
## BOT CAMERA (master plan 6.6: "Bot cameras on the TVs"): a live picture from over a bot's
## shoulder, following it round the berth. ◀ ▶ pick the bot, AUTO goes to whichever bot is at
## work, and the caption says who it is and what it is doing. The camera renders the yard's own
## world, so what it sees is the real build.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const Types := preload("res://modules/bots/api/bot_types.gd")

## Seconds AUTO stays on one bot before it looks for another at work.
const AUTO_SECONDS := 12.0
## Where the camera sits behind and above the bot (m, in the bot's space), and how fast it follows.
const OFFSET := Vector3(0.0, 1.4, 3.2)
const FOLLOW := 3.0

var bus: Object
var fs := 15
var bot_id := -1
var auto := true
var _vp: SubViewport
var _cam: Camera3D
var _caption: Label
var _auto_in := 0.0


func setup(bots_bus: Object, density: float) -> void:
	bus = bots_bus
	fs = maxi(12, int(density * 0.1))
	name = "BotCam"
	add_theme_stylebox_override("panel", T.box(Color(0.01, 0.02, 0.03), Color.TRANSPARENT, 0, fs * 0.3))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(fs * 0.3))
	add_child(col)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(fs * 0.4))
	col.add_child(bar)
	var prev := T.button("◀", false, fs)
	prev.pressed.connect(func() -> void: _step(-1))
	bar.add_child(prev)
	var nxt := T.button("▶", false, fs)
	nxt.pressed.connect(func() -> void: _step(1))
	bar.add_child(nxt)
	var au := T.button("AUTO", auto, fs - 1, auto)
	au.pressed.connect(func() -> void:
		auto = not auto
		au.text = "AUTO" if auto else "MANUAL")
	bar.add_child(au)
	_caption = T.label("", "mono_medium", fs - 1, T.TEXT)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.clip_text = true
	bar.add_child(_caption)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(box)
	_vp = SubViewport.new()
	_vp.size = Vector2i(640, 360)
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	box.add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.far = 900.0
	_vp.add_child(_cam)


func _ready() -> void:
	# The yard's world: the camera sees the real station and build.
	_vp.world_3d = get_tree().root.world_3d


func _step(by: int) -> void:
	auto = false
	var bots: Array = bus.crew.bots
	if bots.is_empty():
		return
	var at := 0
	for i in bots.size():
		if int(bots[i].id) == bot_id:
			at = i
	bot_id = int(bots[(at + by + bots.size()) % bots.size()].id)


func _process(delta: float) -> void:
	var bots: Array = bus.crew.bots
	if bots.is_empty():
		_caption.text = "No bots"
		return
	_auto_in -= delta
	var b: Dictionary = bus.crew.call("bot", bot_id)
	if b.is_empty() or (auto and _auto_in <= 0.0):
		_auto_in = AUTO_SECONDS
		var pick: Dictionary = b if not b.is_empty() else bots[0]
		if auto:
			for c: Dictionary in bots:
				if str(c.task.get("phase", "")) in ["fasten", "fit", "scan"] and int(c.id) != bot_id:
					pick = c
					break
		b = pick
		bot_id = int(b.id)
	var t := Types.info(str(b.type))
	_caption.text = "%s · %s %s · %s" % [str(b.name).to_upper(), t.code, t.name, b.get("line", "")]
	var view: Node = bus.get("view")
	var look: Node3D = view.call("look_of", bot_id) if view and is_instance_valid(view) else null
	var at: Vector3 = look.global_position if look else b.pos
	var basis := look.global_basis if look else Basis.IDENTITY
	var want := at + basis * OFFSET
	_cam.global_position = _cam.global_position.lerp(want, clampf(delta * FOLLOW, 0.0, 1.0)) if _cam.global_position.distance_to(want) < 20.0 else want
	var focus := at + basis * Vector3(0, 0, -1.5)
	if b.task.has("spot") and str(b.task.get("phase", "")) in ["fasten", "scan", "to_k"]:
		focus = (b.task.spot as Vector3).lerp(at, 0.3)
	if _cam.global_position.distance_to(focus) > 0.1:
		_cam.look_at(focus, Vector3.UP)
