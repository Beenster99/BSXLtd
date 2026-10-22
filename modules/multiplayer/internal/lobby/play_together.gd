extends Control
## Play Together, from the title screen: host your latest game (or a new one) for the crew,
## or join someone else's by address. Both go on into the game's start scene (the yard).
## Laid out like the main menu. Router.args may carry {"note": reason} when a session the
## player had joined ended and sent them back here.

var net: MultiplayerBus
var _name: LineEdit
var _address: LineEdit
var _host: Button
var _join: Button
var _note: Label
var _joining := false


func _ready() -> void:
	net = Modules.bus("multiplayer") as MultiplayerBus
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = BsxTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BsxTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := BsxTheme.title("PLAY TOGETHER", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(BsxTheme.muted("Your name"))
	_name = _field("Your name", str(Settings.get_value("multiplayer", "player_name")), "PlayerName")
	box.add_child(_name)

	box.add_child(BsxTheme.muted("Host a game for your crew"))
	_host = BsxTheme.button(_host_label(), _on_host)
	_host.name = "Host"
	_host.custom_minimum_size.y = 52
	box.add_child(_host)

	box.add_child(BsxTheme.muted("Join a crew: the host's address"))
	_address = _field("e.g. 192.168.1.20", str(Settings.get_value("multiplayer", "last_address")), "Address")
	_address.text_submitted.connect(func(_t: String) -> void: _on_join())
	box.add_child(_address)
	_join = BsxTheme.button("Join", _on_join)
	_join.name = "Join"
	box.add_child(_join)

	_note = BsxTheme.muted(str(Router.args.get("note", "")))
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_note)
	var back := BsxTheme.button("Back", _back)
	back.name = "Back"
	box.add_child(back)

	net.session_started.connect(_on_started)
	net.session_ended.connect(_on_ended)
	var playable := not Menu.start().is_empty() and Router.has_scene(Menu.start().scene)
	_host.disabled = not playable
	_join.disabled = not playable


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _field(placeholder: String, value: String, node_name: String) -> LineEdit:
	var f := LineEdit.new()
	f.name = node_name
	f.placeholder_text = placeholder
	f.text = value
	f.custom_minimum_size.y = 42
	return f


func _host_label() -> String:
	var games := Saves.games()
	return "Host  -  %s" % (games[0].name if not games.is_empty() else "a new game")


func _keep_name() -> void:
	var n := _name.text.strip_edges()
	if n != "":
		Settings.set_value("multiplayer", "player_name", n)


func _on_host() -> void:
	_keep_name()
	if not net.is_online():
		var games := Saves.games()
		if not games.is_empty():
			Saves.continue_game(games[0].slot)
		else:
			Saves.new_game("Crew yard")
		var err := net.host(int(Settings.get_value("multiplayer", "port")))
		if err != OK:
			_note.text = "Could not host on port %d (%s)." % [int(Settings.get_value("multiplayer", "port")), error_string(err)]
			return
	_go_play()


func _on_join() -> void:
	var address := _address.text.strip_edges()
	if address == "":
		_note.text = "Type the host's address first."
		return
	_keep_name()
	Settings.set_value("multiplayer", "last_address", address)
	# The host's yard is not one of this player's saved games, so nothing saves over them.
	Saves.close_game()
	var err := net.join(address, int(Settings.get_value("multiplayer", "port")))
	if err != OK:
		_note.text = "Could not join %s (%s)." % [address, error_string(err)]
		return
	_joining = true
	_host.disabled = true
	_join.disabled = true
	_note.text = "Joining %s ..." % address


func _on_started(as_host: bool) -> void:
	if _joining and not as_host:
		_go_play()


func _on_ended(reason: String) -> void:
	if _joining:
		_joining = false
		_host.disabled = false
		_join.disabled = false
		_note.text = "Could not join: %s" % reason


func _go_play() -> void:
	var start := Menu.start()
	Router.goto(start.scene, start.args)


func _back() -> void:
	if _joining:
		net.leave()
	Router.goto(UiBus.MAIN_MENU)
