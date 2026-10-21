extends Node
## The helmet torch (G3): a lamp on every player's helmet. L ("graphics.torch") switches
## yours on and off; it also comes on by itself as night falls and goes off at dawn (L
## still works in between). Yours follows the view camera, a little up and to the right of
## your eyes so what it lights casts a shadow you can see. Crewmates' torches show on their
## avatars: Multiplayer tags each avatar's head with group CREW_HEAD and meta "peer_id",
## and every switch goes round the crew as the event "graphics.torch" (late joiners get
## them in the "graphics" snapshot).

const ACTION := "graphics.torch"
const EVENT := "graphics.torch"
const SNAPSHOT := "graphics"
const CREW_HEAD := "crew_head"
## Where the lamp sits on the helmet, from the eyes (camera space), metres.
const OFFSET := Vector3(0.2, 0.12, 0.0)
## Daylight (AlienSky, 0 night .. 1 day) under which it comes on, and over which it goes off.
const DARK := 0.06
const LIGHT := 0.18

## The look of every torch: cool white, a tight pool with a wide spill, about 30 m.
const COLOUR := Color(0.94, 0.97, 1.0)
const ENERGY := 7.0     # Godot light energy (the yard's lamp posts are 12, 7 m up)
const RANGE := 30.0     # metres
const ANGLE := 32.0     # degrees, centre to edge
## Its share of the volumetric dust (Core multiplies a spot's by about 10): a faint beam.
const FOG := 0.02

var on := false
## This player's torch.
var lamp: SpotLight3D
## Crewmates' switches (peer -> on) and their lamps (peer -> SpotLight3D).
var crew: Dictionary = {}
var crew_lamps: Dictionary = {}
var _net: Node
var _night := false
var _sky_seen := false


func _ready() -> void:
	lamp = make_lamp()
	lamp.name = "HelmetTorch"
	lamp.top_level = true
	lamp.visible = false
	add_child(lamp)


## A torch's light, as on every helmet.
static func make_lamp() -> SpotLight3D:
	var l := SpotLight3D.new()
	l.light_color = COLOUR
	l.light_energy = ENERGY
	l.spot_range = RANGE
	l.spot_angle = ANGLE
	l.spot_angle_attenuation = 0.4     # a soft edge: brightest in the middle, fading out
	l.spot_attenuation = 1.0
	l.light_volumetric_fog_energy = FOG
	l.light_specular = 0.6
	l.set_meta("gfx_no_beam", true)
	return l


func attach_net(net: Node) -> void:
	_net = net
	if _net == null:
		return
	_net.call("register_event", EVENT, _apply, _validate)
	_net.call("register_snapshot_provider", SNAPSHOT, self)
	if not _net.is_connected("peer_left", _on_peer_left):
		_net.connect("peer_left", _on_peer_left)
	if not _net.is_connected("session_ended", _on_session_ended):
		_net.connect("session_ended", _on_session_ended)
	if not _net.is_connected("session_started", _on_session_started):
		_net.connect("session_started", _on_session_started)


func detach() -> void:
	if _net:
		_net.call("unregister_event", EVENT)
		_net.call("unregister_snapshot_provider", SNAPSHOT)
		if _net.is_connected("peer_left", _on_peer_left):
			_net.disconnect("peer_left", _on_peer_left)
		if _net.is_connected("session_ended", _on_session_ended):
			_net.disconnect("session_ended", _on_session_ended)
		if _net.is_connected("session_started", _on_session_started):
			_net.disconnect("session_started", _on_session_started)
	_net = null
	_on_session_ended("")


## Switches this player's torch, and tells the crew.
func set_on(value: bool) -> void:
	if value == on:
		return
	on = value
	lamp.visible = on
	if on:
		_follow()
	if _net and bool(_net.call("is_online")):
		_net.call("request", EVENT, {"on": on})


func toggle() -> void:
	set_on(not on)


## Daylight now (AlienSky's time_changed): on at dusk, off at dawn.
func set_daylight(daylight: float) -> void:
	var night := daylight < DARK if not _night else daylight < LIGHT
	if _sky_seen and night == _night:
		return
	var first := not _sky_seen
	_sky_seen = true
	_night = night
	if night or not first:
		set_on(night)


func _process(_delta: float) -> void:
	if on:
		_follow()
	for peer: int in crew:
		_place_crew(peer)


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(ACTION) and event.is_action_pressed(ACTION) and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func _follow() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	lamp.visible = on and cam != null
	if cam:
		lamp.global_transform = cam.global_transform * Transform3D(Basis(), OFFSET)


# --- The crew's torches -----------------------------------------------------------------

## Host: a player switched their torch. Stamped with who sent it, so nobody works another's.
func _validate(sender: int, payload: Dictionary) -> Variant:
	return {"peer": sender, "on": bool(payload.get("on", false))}


func _apply(payload: Dictionary) -> void:
	var peer := int(payload.get("peer", 0))
	if _net and peer == int(_net.call("local_peer_id")):
		return
	set_crew(peer, bool(payload.get("on", false)))


## A crewmate's torch on or off.
func set_crew(peer: int, value: bool) -> void:
	if value:
		crew[peer] = true
		_place_crew(peer)
	else:
		crew.erase(peer)
		var l: Node = crew_lamps.get(peer)
		if is_instance_valid(l):
			l.queue_free()
		crew_lamps.erase(peer)


## Puts a crewmate's torch on their avatar's head (once the avatar is there).
func _place_crew(peer: int) -> void:
	var l: SpotLight3D = crew_lamps.get(peer)
	if is_instance_valid(l) and l.is_inside_tree():
		return
	var head := head_of(peer)
	if head == null:
		return
	l = make_lamp()
	l.name = "HelmetTorch_%d" % peer
	l.position = OFFSET
	head.add_child(l)
	crew_lamps[peer] = l


## A crewmate's avatar head, or null.
func head_of(peer: int) -> Node3D:
	if not is_inside_tree():
		return null
	for h in get_tree().get_nodes_in_group(CREW_HEAD):
		if h is Node3D and int(h.get_meta("peer_id", -1)) == peer:
			return h as Node3D
	return null


func get_net_snapshot() -> Dictionary:
	var torches := {}
	for peer: int in crew:
		torches[str(peer)] = true
	if on and _net:
		torches[str(int(_net.call("local_peer_id")))] = true
	return {"torches": torches}


func apply_net_snapshot(data: Dictionary) -> void:
	var torches: Dictionary = data.get("torches", {})
	var me := int(_net.call("local_peer_id")) if _net else 0
	for key: Variant in torches:
		var peer := int(str(key))
		if peer != me:
			set_crew(peer, bool(torches[key]))


func _on_peer_left(peer: int, _reason: String) -> void:
	set_crew(peer, false)


## Joined or started hosting with the torch already on: the crew should see it.
func _on_session_started(_as_host: bool) -> void:
	if on and _net:
		_net.call("request", EVENT, {"on": true})


func _on_session_ended(_reason: String) -> void:
	for peer: int in crew.keys():
		set_crew(peer, false)
