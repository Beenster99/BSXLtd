extends HBoxContainer
## The wrist screen's Crew channel: who is on shift (with a CAM button for each other
## player), the crew text channel, and a helmet cam looking out of the chosen player's
## helmet. Other modules add dockets under the crew list (Business: Transfer money) through
## HudSlots.register_holo_section("multiplayer.crew", ...).

const T := preload("res://modules/ui/api/terminal_kit.gd")
const CHANNEL := "multiplayer.crew"

var net: MultiplayerBus
var crew: Node  # crew_channel.gd
var glass := true
var cam_peer := 0

var _crew_list: VBoxContainer
var _crew_title: Label
var _log: VBoxContainer
var _say: LineEdit
var _cam_note: Label
var _cam_view: SubViewportContainer
var _cam: Camera3D
var _cam_empty: Label


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.add_theme_constant_override("separation", 6)
	_crew_title = T.label("", "display_bold", 20, T.TEXT)
	left.add_child(_crew_title)
	_crew_list = VBoxContainer.new()
	_crew_list.name = "CrewList"
	_crew_list.add_theme_constant_override("separation", 3)
	left.add_child(_crew_list)
	left.add_child(T.sections(CHANNEL, glass))
	add_child(left)

	var mid: Dictionary = T.docket("Crew channel", "ONLINE" if net.is_online() else "SOLO", glass)
	mid.panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log = T.list()
	_log.name = "ChatLog"
	_log.get_parent().custom_minimum_size.y = 220
	mid.body.add_child(_log.get_parent())
	var say_row := HBoxContainer.new()
	_say = T.search("Say something to the crew", func(_t: String) -> void: pass, glass)
	_say.name = "SayBox"
	_say.clear_button_enabled = false
	_say.max_length = crew.MAX_CHARS
	_say.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_say.text_submitted.connect(func(_t: String) -> void: _send())
	say_row.add_child(_say)
	var send := T.button("SEND", true, 17, false, glass)
	send.name = "Send"
	send.pressed.connect(_send)
	say_row.add_child(send)
	mid.body.add_child(say_row)
	add_child(mid.panel)

	var cam: Dictionary = T.docket("Helmet cam", "", glass)
	cam.panel.custom_minimum_size.x = 380
	_cam_view = SubViewportContainer.new()
	_cam_view.name = "HelmetCam"
	_cam_view.stretch = true
	_cam_view.custom_minimum_size = Vector2(350, 230)
	var vp := SubViewport.new()
	vp.world_3d = get_viewport().world_3d
	_cam = Camera3D.new()
	_cam.near = 0.25
	_cam.fov = 70.0
	vp.add_child(_cam)
	_cam_view.add_child(vp)
	cam.body.add_child(_cam_view)
	_cam_empty = T.label("Nobody else is on shift.\nWhen crew join, press CAM by\na name to see through their helmet.",
			"body", 17, T.DIM)
	cam.body.add_child(_cam_empty)
	_cam_note = T.label("", "mono_medium", 14, T.BAD)
	cam.body.add_child(_cam_note)
	add_child(cam.panel)

	net.peer_joined.connect(_on_crew_changed)
	net.peer_left.connect(_on_crew_changed)
	net.session_started.connect(_on_session)
	net.session_ended.connect(_on_session)
	crew.chat_received.connect(_add_line)
	crew.activity_changed.connect(_on_activity)
	for line in crew.chat_log():
		_add_line(line)
	_fill_crew()


func _process(_delta: float) -> void:
	var head: Node3D = crew.head_of(cam_peer) if cam_peer != 0 else null
	var live := is_instance_valid(head) and head.is_inside_tree()
	_cam_view.visible = live
	_cam_empty.visible = not live
	if live:
		_cam.global_transform = head.global_transform
		var me: Node3D = crew.head_of(net.local_peer_id())
		var dist := me.global_position.distance_to(head.global_position) if is_instance_valid(me) else 0.0
		_cam_note.text = "●  LIVE  ·  %s  ·  %d m" % [crew.player_name(cam_peer).to_upper(), roundi(dist)]
	else:
		_cam_note.text = ""


func _send() -> void:
	var text := _say.text.strip_edges()
	if text == "":
		return
	crew.say(text)
	_say.text = ""


func _fill_crew() -> void:
	for c in _crew_list.get_children():
		c.queue_free()
	var peers := net.peers()
	_crew_title.text = "CREW ON SHIFT  %d / %d" % [peers.size(), MultiplayerBus.MAX_CREW]
	var ids := peers.keys()
	ids.sort()
	if cam_peer != 0 and not peers.has(cam_peer):
		cam_peer = 0
	for id: int in ids:
		var you: bool = id == net.local_peer_id()
		var role := "HOST" if id == 1 else "CREW"
		var doing: String = crew.activity(id)
		var sub := role if doing == "" else "%s  ·  %s" % [role, doing]
		var end: Control
		if you:
			end = T.tag("YOU", T.CYAN)
		else:
			var b := T.button("CAM", cam_peer == id, 15, false, glass)
			b.name = "Cam_%d" % id
			b.pressed.connect(_watch.bind(id))
			end = b
			if cam_peer == 0:
				cam_peer = id
		var r := T.row([T.cell_text(str(peers[id].get("name", "Player")).to_upper(), sub), end], false, glass)
		r.name = "Crew_%d" % id
		_crew_list.add_child(r)


func _watch(peer_id: int) -> void:
	cam_peer = peer_id
	_fill_crew()


func _add_line(line: Dictionary) -> void:
	var l := HBoxContainer.new()
	l.add_theme_constant_override("separation", 8)
	l.add_child(T.label(str(line.get("time", "")), "mono_medium", 14, T.DIM))
	l.add_child(T.label(str(line.get("name", "")).to_upper(), "display_bold", 17, T.ORANGE))
	var text := T.label(str(line.get("text", "")), "body", 17, T.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_child(text)
	_log.add_child(l)
	var scroll := _log.get_parent() as ScrollContainer
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _on_crew_changed(_id: int, _x: Variant) -> void:
	_fill_crew()


func _on_session(_x: Variant) -> void:
	_fill_crew()


func _on_activity(_id: int, _text: String) -> void:
	_fill_crew()
