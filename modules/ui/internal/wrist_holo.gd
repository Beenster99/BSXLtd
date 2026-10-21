class_name WristHolo
extends CanvasLayer
## The wrist screen, like Star Citizen's mobiGlas: press the holo key (Keys.HOLO, F1 by
## default) anywhere in a game and your wrist projects the yard terminal in front of your
## face, see-through: the BSX header, the hazard rule, a numbered tab for every channel
## modules registered with HudSlots.register_holo_channel (Orders, Stock, Contracts,
## Machines...), CLOSE, and the channel's screen under them. The holo key, Esc, CLOSE or a
## click outside the screen puts it away. A channel's Control with a close_requested signal
## puts it away too. The UI bus owns one for the whole game.
## It flickers on out of the wrist as a line of light that opens into the screen, and folds
## back to a line and a spark when put away. Everything pressed or typed on it ticks
## (Sfx.press). The footer's small print is the terminal's OS, the build, the date and time.

## Where the screen sits: its size as a share of the window, and how far it leans.
const SCREEN_SHARE := Vector2(0.84, 0.8)
const TILT_DEG := -1.0
const T := preload("res://modules/ui/api/terminal_kit.gd")
## Seconds the screen takes to come up and to go away.
const APPEAR_TIME := 0.5
const VANISH_TIME := 0.28
## Its claim on the mouse (HudSlots.claim_pointer).
const POINTER_ID := "ui.wrist"

var is_open := false
var root: Control
## The terminal on the glass (HoloTerminal); pane, tabs and content are its.
var terminal: HoloTerminal
var pane: PanelContainer
var content: MarginContainer
var tabs: HBoxContainer
## The channel up now ("" while put away).
var channel: String:
	get:
		return terminal.channel if is_open and terminal else ""
var _scan: ShaderMaterial
var _wrist: Control
var _col: Control
var _last := ""
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _tween: Tween


func _ready() -> void:
	name = "WristHolo"
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	HudSlots.holo_requested.connect(open)
	get_tree().node_added.connect(_on_node_added)


## True where the holo may come up: in a game, not on the menus.
func allowed() -> bool:
	var id := str(Router.current_id)
	return not id in ["main_menu", "settings", "boot"] and get_tree() != null


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Brings the screen up on `channel_id` ("" = the channel shown last, else the first).
## Already up: switches channel.
func open(channel_id: String = "") -> void:
	if is_open:
		show_channel(channel_id)
		return
	is_open = true
	_build()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	HudSlots.claim_pointer(POINTER_ID)
	Sfx.play("holo_open", null, -13.0)
	show_channel(channel_id, false)
	_appear()


func close() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.play("holo_close", null, -15.0)
	if root:
		_vanish()
	root = null
	terminal = null
	pane = null
	content = null
	tabs = null
	_scan = null
	_wrist = null
	_col = null
	HudSlots.release_pointer(POINTER_ID)
	Input.mouse_mode = _mouse_before


## Puts a channel on the screen ("" = the last one shown, else the first).
func show_channel(channel_id: String, sound: bool = true) -> void:
	if not is_open:
		open(channel_id)
		return
	if channel_id == "" or HudSlots.holo_channel(channel_id).is_empty():
		channel_id = _last if not HudSlots.holo_channel(_last).is_empty() else ""
	terminal.show_channel(channel_id)
	if sound:
		Sfx.play("holo_switch", null, -16.0)


func _process(_delta: float) -> void:
	# The pointer stays while the screen is up, whatever a click fell through to.
	if is_open and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
	if event.is_action_pressed(Keys.HOLO) and (is_open or allowed()):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed(Keys.CANCEL):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	root = Control.new()
	root.name = "Holo"
	root.theme = BsxTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_meta("holo", true)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(root)
	var view := root.get_viewport_rect().size
	if view.x <= 0.0:
		view = Vector2(1280, 720)

	var wrist := WristArm.new()
	wrist.name = "Wrist"
	wrist.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wrist)
	_wrist = wrist

	terminal = HoloTerminal.new(true)
	terminal.name = "Pane"
	terminal.hint_text = "%s OR %s CLOSE   ·   CLICK A TAB FOR ANOTHER SCREEN   ·   %s USE" % [
			Keys.prompt(Keys.HOLO), Keys.prompt(Keys.CANCEL), Keys.prompt(Keys.INTERACT)]
	(terminal.col.find_child("Hint", true, false) as Label).text = terminal.hint_text
	var size := (view * SCREEN_SHARE).max(Vector2(900, 540))
	terminal.size = size
	terminal.position = Vector2((view.x - size.x) * 0.5 + view.x * 0.02, (view.y - size.y) * 0.4)
	terminal.rotation = deg_to_rad(TILT_DEG)
	terminal.close_requested.connect(close)
	terminal.channel_changed.connect(func(id: String) -> void:
		if id != "":
			_last = id)
	root.add_child(terminal)
	wrist.target = terminal
	pane = terminal
	tabs = terminal.tabs
	content = terminal.content
	_col = terminal.col
	_scan = terminal.scan


## Comes up out of the wrist: the emitter flares, a line of light stretches out across
## the view, opens top and bottom into the screen, and a bright line runs down it while the
## screen flickers in.
func _appear() -> void:
	if _tween:
		_tween.kill()
	pane.pivot_offset = pane.size * 0.5
	pane.scale = Vector2(0.03, 0.008)
	_col.modulate.a = 0.0
	_scan.set_shader_parameter("flash", 1.0)
	_scan.set_shader_parameter("glitch", 1.0)
	_scan.set_shader_parameter("sweep", -1.0)
	var a := APPEAR_TIME
	_tween = create_tween().set_parallel()
	_tween.tween_property(pane, "scale:x", 1.0, a * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(pane, "scale:y", 1.0, a * 0.45).set_delay(a * 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_flare, 1.0, 0.0, a * 1.4)
	_tween.tween_property(_scan, "shader_parameter/flash", 0.0, a).set_ease(Tween.EASE_IN)
	_tween.tween_property(_scan, "shader_parameter/glitch", 0.0, a * 1.2).set_ease(Tween.EASE_IN)
	_tween.tween_property(_scan, "shader_parameter/sweep", 1.08, a * 0.6).from(0.0).set_delay(a * 0.4)
	_tween.tween_method(_flicker_in, 0.0, 1.0, a * 0.55).set_delay(a * 0.45)
	_tween.chain().tween_callback(func() -> void:
		if _scan:
			_scan.set_shader_parameter("sweep", -1.0))


## Goes away the other way: a flash, the screen folds to a line, the line shrinks to a spark
## at its middle and is gone. The old screen is left to fade while a new one can come up.
func _vanish() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	var old := root
	var old_pane := pane
	var mat := _scan
	var wrist := _wrist
	old.name = "HoloVanishing"
	old.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in old.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	old_pane.pivot_offset = old_pane.size * 0.5
	var v := VANISH_TIME
	var tw := create_tween().set_parallel()
	tw.tween_property(mat, "shader_parameter/flash", 1.0, v * 0.25)
	tw.tween_property(mat, "shader_parameter/glitch", 1.0, v * 0.25)
	tw.tween_property(_col, "modulate:a", 0.0, v * 0.4)
	tw.tween_property(old_pane, "scale:y", 0.008, v * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(old_pane, "scale:x", 0.0, v * 0.4).set_delay(v * 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if wrist:
		tw.tween_property(wrist, "flare", 1.0, v * 0.3)
	tw.tween_property(old, "modulate:a", 0.0, v * 0.35).set_delay(v * 0.75)
	tw.chain().tween_callback(old.queue_free)


func _flare(f: float) -> void:
	if _wrist and is_instance_valid(_wrist):
		_wrist.set("flare", f)


## The screen's contents flicker on: off and on a few times, then steady.
func _flicker_in(t: float) -> void:
	if _col == null or not is_instance_valid(_col):
		return
	var on := t >= 0.98 or fmod(sin(t * 91.7) * 4375.85, 1.0) > 0.35 - t * 0.3
	_col.modulate.a = t if on else t * 0.2


## Anything pressed or typed on the screen ticks; TerminalKit and BsxTheme buttons tick on
## their own (meta "sfx").
func _on_node_added(node: Node) -> void:
	if not is_open or root == null or node.has_meta("sfx") or not root.is_ancestor_of(node):
		return
	node.set_meta("sfx", true)
	if node is BaseButton:
		(node as BaseButton).pressed.connect(func() -> void: Sfx.press(node))
	elif node is LineEdit:
		(node as LineEdit).text_changed.connect(func(_t: String) -> void: Sfx.press(node, -18.0))
		(node as LineEdit).text_submitted.connect(func(_t: String) -> void: Sfx.press(node))
	elif node is Slider:
		(node as Slider).drag_ended.connect(func(_c: bool) -> void: Sfx.press(node, -14.0))


## The forearm and gauntlet at the bottom left, with the emitter's light fanning up to the
## screen's lower corners.
class WristArm extends Control:
	var target: Control
	## 0..1: the emitter flaring as the screen comes and goes.
	var flare := 0.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s := size
		var cuff := Vector2(s.x * 0.16, s.y * 0.93)
		var arm := PackedVector2Array([Vector2(-20, s.y + 20), Vector2(s.x * 0.05, s.y * 0.86),
				Vector2(s.x * 0.2, s.y * 0.88), Vector2(s.x * 0.26, s.y + 20)])
		draw_colored_polygon(arm, Color(0.09, 0.1, 0.12, 0.96))
		var plate := PackedVector2Array([Vector2(s.x * 0.08, s.y * 0.885), Vector2(s.x * 0.2, s.y * 0.9),
				Vector2(s.x * 0.215, s.y * 0.97), Vector2(s.x * 0.075, s.y * 0.955)])
		draw_colored_polygon(plate, Color(0.2, 0.22, 0.25, 1.0))
		draw_polyline(plate + PackedVector2Array([plate[0]]), Color(TerminalKit.ORANGE, 0.9), 2.0)
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
		var light := Color(0.62, 0.9, 1.0)
		draw_circle(cuff, 9.0 + flare * 6.0, Color(light, minf(1.0, 0.9 * pulse + flare)))
		draw_circle(cuff, 20.0 + flare * 40.0, Color(light, 0.18 * pulse + flare * 0.3))
		if target and is_instance_valid(target):
			var t := target.get_global_transform()
			var bl := t * Vector2(0, target.size.y)
			var br := t * Vector2(target.size.x * 0.45, target.size.y)
			draw_colored_polygon(PackedVector2Array([cuff, bl, br]), Color(light, 0.06 + flare * 0.14))
			draw_line(cuff, bl, Color(light, 0.25 + flare * 0.6), 1.5 + flare * 2.0)
			draw_line(cuff, br, Color(light, 0.15 + flare * 0.5), 1.5 + flare * 2.0)
