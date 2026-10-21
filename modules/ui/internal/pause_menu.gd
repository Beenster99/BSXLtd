class_name PauseMenu
extends CanvasLayer
## Esc in a game: the pause menu, in the terminal's look over a dimmed view. Resume (or Esc
## again) carries on where you were; Save game saves now; Main menu saves and leaves; Quit
## saves and closes the game. Offline, the game holds still while it's up. Opens on
## Menu.open_pause() or an Esc nothing else used. The UI bus owns one for the whole game.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const POINTER_ID := "ui.pause"

var is_open := false
var root: Control
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _was_paused := false
var _note: Label


func _ready() -> void:
	name = "PauseMenu"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	Menu.pause_requested.connect(open)


## True where the menu may open: in a game, not on the menus.
func allowed() -> bool:
	return not str(Router.current_id) in ["main_menu", "settings", "boot"]


func open() -> void:
	if is_open or not allowed():
		return
	is_open = true
	_build()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	HudSlots.claim_pointer(POINTER_ID)
	_was_paused = get_tree().paused
	if _offline():
		get_tree().paused = true
	Sfx.play("holo_switch", null, -14.0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if root:
		root.queue_free()
	root = null
	get_tree().paused = _was_paused
	HudSlots.release_pointer(POINTER_ID)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _mouse_before


func save_now() -> void:
	if Saves.current_slot == "":
		_note.text = "NO GAME TO SAVE"
		return
	var err := Saves.save(Saves.current_slot)
	_note.text = "SAVED" if err == OK else "COULDN'T SAVE (%s)" % error_string(err)


func to_main_menu() -> void:
	close()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Router.goto("main_menu")


func quit() -> void:
	if Saves.current_slot != "":
		Saves.save(Saves.current_slot)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	# An Esc that no screen and no scene used.
	if event is InputEventKey and event.is_action_pressed(Keys.CANCEL) and not event.is_echo():
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Up, the menu has Esc first.
	if is_open and event is InputEventKey and event.is_action_pressed(Keys.CANCEL) and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()


func _offline() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer == null or peer is OfflineMultiplayerPeer or multiplayer.get_peers().is_empty()


func _build() -> void:
	root = Control.new()
	root.name = "Pause"
	root.theme = BsxTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var pane := PanelContainer.new()
	pane.name = "Pane"
	pane.custom_minimum_size = Vector2(440, 0)
	pane.add_theme_stylebox_override("panel", T.box(T.tone(T.KIOSK, true, 0.86), Color(T.STEEL, 0.6), 2, 0))
	center.add_child(pane)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	pane.add_child(col)
	var head := HBoxContainer.new()
	head.custom_minimum_size.y = 54
	var badge := PanelContainer.new()
	var bst := T.box(T.ORANGE)
	bst.content_margin_left = 14
	bst.content_margin_right = 14
	badge.add_theme_stylebox_override("panel", bst)
	var bsx := T.label("BSX", "display_bold", 32, T.BLACK)
	bsx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(bsx)
	head.add_child(badge)
	var title := T.label("  PAUSED", "display_bold", 30, T.TEXT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	col.add_child(head)
	col.add_child(T.HazardRule.new(8.0, true))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 22)
	pad.add_child(body)
	col.add_child(pad)
	var game := Saves.current_name if Saves.current_name != "" else "Unsaved game"
	body.add_child(T.label(game.to_upper(), "display_medium", 17, T.DIM))
	for spec: Array in [["Resume", close, true], ["Save game", save_now, false],
			["Main menu", to_main_menu, false], ["Quit to desktop", quit, false]]:
		var b := T.button(str(spec[0]).to_upper(), spec[2], 22, false, true)
		b.name = str(spec[0]).replace(" ", "")
		b.custom_minimum_size.y = 50
		b.pressed.connect(spec[1])
		body.add_child(b)
	_note = T.label("", "mono_medium", 14, T.GOOD)
	_note.name = "Note"
	body.add_child(_note)
	body.add_child(T.label("%s RESUMES  ·  SETTINGS ARE ON YOUR WRIST (%s)" % [Keys.prompt(Keys.CANCEL),
			Keys.prompt(Keys.HOLO)], "display_medium", 13, T.DIM))
