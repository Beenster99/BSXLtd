extends Control
## Play Online, from the title screen: host your latest game (or a new one) for the crew,
## or join someone else's by address. Hosting stays on this screen until the router has
## answered, so the host can copy the address to send the crew, then enters the yard.
## Laid out like the main menu. Router.args may carry {"note": reason} when a session the
## player had joined ended and sent them back here.

var net: MultiplayerBus
var _name: LineEdit
var _address: LineEdit
var _host: Button
var _join: Button
var _note: Label
var _setup: VBoxContainer  # name, Host, address, Join: while not in a session
var _live: VBoxContainer  # where crew can reach you, Copy, Enter the yard, Stop: while hosting
var _reach: Label
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

	var title := BsxTheme.title("PLAY ONLINE", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_setup = VBoxContainer.new()
	_setup.add_theme_constant_override("separation", 14)
	box.add_child(_setup)
	_setup.add_child(BsxTheme.muted("Your name"))
	_name = _field("Your name", str(Settings.get_value("multiplayer", "player_name")), "PlayerName")
	_setup.add_child(_name)
	_setup.add_child(BsxTheme.muted("Host a game for your crew"))
	_host = BsxTheme.button(_host_label(), _on_host)
	_host.name = "Host"
	_host.custom_minimum_size.y = 52
	_setup.add_child(_host)
	_setup.add_child(BsxTheme.muted("Join a crew: the host's address"))
	_address = _field("e.g. 81.2.69.160", str(Settings.get_value("multiplayer", "last_address")), "Address")
	_address.text_submitted.connect(func(_t: String) -> void: _on_join())
	_setup.add_child(_address)
	_join = BsxTheme.button("Join", _on_join)
	_join.name = "Join"
	_setup.add_child(_join)

	_live = VBoxContainer.new()
	_live.name = "Hosting"
	_live.add_theme_constant_override("separation", 14)
	box.add_child(_live)
	_reach = BsxTheme.muted("")
	_reach.name = "Reach"
	_reach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_live.add_child(_reach)
	var copy := BsxTheme.button("Copy address", func() -> void: DisplayServer.clipboard_set(_best_address()))
	copy.name = "CopyAddress"
	_live.add_child(copy)
	var enter := BsxTheme.button("Enter the yard", _go_play)
	enter.name = "EnterYard"
	enter.custom_minimum_size.y = 52
	_live.add_child(enter)
	var stop := BsxTheme.button("Stop hosting", func() -> void: net.leave())
	stop.name = "StopHosting"
	_live.add_child(stop)

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
	net.router_changed.connect(func(_i: Dictionary) -> void: _show())
	var playable := not Menu.start().is_empty() and Router.has_scene(Menu.start().scene)
	_host.disabled = not playable
	_join.disabled = not playable
	_show()


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


## Setup while not hosting; while hosting, where the crew can reach you.
func _show() -> void:
	var hosting := net.is_online() and net.is_host()
	_setup.visible = not hosting
	_live.visible = hosting
	if hosting:
		_reach.text = _hosting_note(net.router_info())


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
		var err := net.host(_port())
		if err != OK:
			_note.text = "Could not host on port %d (%s)." % [_port(), error_string(err)]
			return
	_note.text = ""
	_show()


func _on_join() -> void:
	var address := _address.text.strip_edges()
	if address == "":
		_note.text = "Type the host's address first."
		return
	_keep_name()
	Settings.set_value("multiplayer", "last_address", address)
	# The host's yard is not one of this player's saved games, so nothing saves over them.
	Saves.close_game()
	var err := net.join(address, _port())
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
	else:
		_show()


func _on_ended(reason: String) -> void:
	if _joining:
		_joining = false
		_host.disabled = false
		_join.disabled = false
		_note.text = "Could not join: %s" % reason
	_host.text = _host_label()
	_show()


## Where the crew can reach this host: over the internet once the router opened the port,
## and on the same network always.
func _hosting_note(router: Dictionary) -> String:
	var lines: PackedStringArray = ["Hosting on port %d." % _port()]
	match str(router.get("state", "off")):
		"open":
			lines.append("Over the internet: %s" % router.external)
		"opening":
			lines.append("Opening the port on your router...")
		"failed":
			lines.append("Internet play needs port %d (UDP) forwarded to this PC by hand: %s." % [_port(), router.reason])
	lines.append("Same network: %s" % _addresses())
	return "\n".join(lines)


func _best_address() -> String:
	var router := net.router_info()
	return str(router.external) if router.get("state") == "open" else _addresses().get_slice(",", 0)


func _port() -> int:
	return int(Settings.get_value("multiplayer", "port"))


## This machine's local network addresses, for crew on the same network.
static func _addresses() -> String:
	var out: PackedStringArray = []
	for a in IP.get_local_addresses():
		if a.contains(".") and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return ", ".join(out) if not out.is_empty() else "127.0.0.1"


func _go_play() -> void:
	var start := Menu.start()
	Router.goto(start.scene, start.args)


func _back() -> void:
	if _joining:
		net.leave()
	Router.goto(UiBus.MAIN_MENU)
