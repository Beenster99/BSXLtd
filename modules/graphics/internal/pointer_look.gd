extends Node
## Graphics: what the pointer is over, and pings. Lives under GfxBus.
##   - Hover (flag "graphics.hover"): whatever you can use under the pointer (the screen
##     centre while the mouse is captured, the mouse where it is free) within REACH gets the
##     subtle highlight: a thin soft outline. Usable things are nodes in group
##     GfxBus.INTERACTABLE.
##   - Ping (flag "graphics.ping"): the middle mouse button pings the point under the
##     pointer, and the usable thing there if any. Sent through Multiplayer's net.ping() when
##     it offers one, so the crew sees it; everyone draws pings only from ping_received.
##     Without Multiplayer the ping shows here alone. Each marker says what was pinged
##     (name_of), who pinged it and how far; a ping lasts PING_LIFE (10 s) and each player
##     has up to PINGS_EACH (5) up, the oldest going first, taken down at once on
##     Multiplayer's ping_removed. Z (ACTION, rebindable) pings too, for mice without a
##     middle button. A ping out of view gets an arrow at the screen's edge pointing to it,
##     and a crewmate's ping plays its own sound, so it isn't missed.

signal hovered(target: Node)
signal ping_shown(ping: Dictionary)

const Highlighter := preload("res://modules/graphics/internal/highlighter.gd")
const MARKER := preload("res://modules/graphics/internal/ping_marker.gdshader")
const BEAM := preload("res://modules/graphics/internal/ping_beam.gdshader")

## How far you can be from something and still have it highlight, m.
@export var reach: float = 4.0
## How far a ping can reach, m.
@export var ping_range: float = 300.0
## How long a ping lasts when Multiplayer doesn't say, s.
@export var ping_life: float = 10.0
## How many pings one player can have up at once when Multiplayer doesn't say; a new one
## past that takes down their oldest.
@export var pings_each: int = 5
## Ping fade-out at the end of its life, s.
@export var ping_fade: float = 1.0
## The light column over a ping, m.
@export var beam_height: float = 6.0
## How near a ping must land to something usable to light it when it carries no id, m.
@export var match_radius: float = 0.5

const HOVER_COLOUR := Color(0.62, 0.9, 1.0)   # BsxTheme.ACCENT
const PING_COLOUR := Color(1.0, 0.75, 0.25)
## Meta on a usable thing: what a ping on it calls it (else its look hint's title).
const NAME_META := "gfx_name"
## The ping key (as well as the middle mouse button).
const ACTION := "graphics.ping"
## How far in from the screen's edge the arrows to pings out of view sit, px.
const EDGE := 56.0

var highlighter := Highlighter.new()
var hover_on := true
var ping_on := true
## The usable thing under the pointer now, or null.
var target: Node
## Live pings: {ping: Dictionary, key: String, what: String (what was pinged), node: Node3D,
## lit: Node, born: float, life: float}
var live: Array[Dictionary] = []
var _net: Node
var _local_id := 0
var _arrows: Control


func attach_net(net: Node) -> void:
	_net = net
	if _net and _net.has_signal("ping_received") and not _net.is_connected("ping_received", show_ping):
		_net.connect("ping_received", show_ping)
	if _net and _net.has_signal("ping_removed") and not _net.is_connected("ping_removed", remove_ping):
		_net.connect("ping_removed", remove_ping)


func detach() -> void:
	if _net and _net.has_signal("ping_received") and _net.is_connected("ping_received", show_ping):
		_net.disconnect("ping_received", show_ping)
	if _net and _net.has_signal("ping_removed") and _net.is_connected("ping_removed", remove_ping):
		_net.disconnect("ping_removed", remove_ping)
	_net = null
	set_target(null)
	for p in live:
		if is_instance_valid(p.node):
			p.node.queue_free()
	live.clear()
	highlighter.clear()


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PingArrows"
	layer.layer = 5
	add_child(layer)
	_arrows = Control.new()
	_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrows.draw.connect(_draw_arrows)
	layer.add_child(_arrows)


func _process(_delta: float) -> void:
	if hover_on:
		var hit := pointer_hit(reach)
		set_target(hit.get("target"))
	elif target:
		set_target(null)
	_age_pings()
	if _arrows:
		_arrows.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not ping_on:
		return
	var mb := event as InputEventMouseButton
	var key := InputMap.has_action(ACTION) and not event is InputEventMouse and event.is_action_pressed(ACTION) and not event.is_echo()
	if key or (mb and mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE):
		if ping_at_pointer():
			get_viewport().set_input_as_handled()


## Where an arrow to a ping out of view sits on screen and which way it points:
## {at: Vector2, dir: Vector2}; {} while the ping is in view.
func edge_arrow(at: Vector3) -> Dictionary:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam == null:
		return {}
	var size := vp.get_visible_rect().size
	var edge := minf(EDGE, minf(size.x, size.y) * 0.15)
	var inner := Rect2(Vector2.ONE * edge, size - Vector2.ONE * edge * 2.0)
	var behind := cam.is_position_behind(at)
	var px := cam.unproject_position(at)
	if not behind and inner.has_point(px):
		return {}
	var centre := size * 0.5
	var dir := px - centre
	if behind:
		# Behind you: which way to turn, from where it sits round you (screen y runs down).
		# Straight behind points down; behind and to one side, down that side.
		var local := cam.global_transform.affine_inverse() * at
		dir = Vector2(local.x / maxf(absf(local.z), 0.01), 0.6)
	if dir.length() < 0.001:
		dir = Vector2.DOWN
	dir = dir.normalized()
	# Out along dir from the centre to the inner rectangle's edge.
	var half := inner.size * 0.5
	var t := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
	return {"at": centre + dir * t, "dir": dir}


func _draw_arrows() -> void:
	var font := ThemeDB.fallback_font
	for p in live:
		if not is_instance_valid(p.node):
			continue
		var e := edge_arrow((p.node as Node3D).global_position)
		if e.is_empty():
			continue
		var c: Color = p.ping.get("colour", PING_COLOUR)
		c.a = clampf((float(p.life) - (_now() - float(p.born))) / ping_fade, 0.0, 1.0)
		var at: Vector2 = e.at
		var dir: Vector2 = e.dir
		var side := dir.orthogonal()
		var tip := at + dir * 18.0
		_arrows.draw_colored_polygon(PackedVector2Array([tip, at - dir * 6.0 + side * 13.0, at - dir * 6.0 - side * 13.0]), c)
		_arrows.draw_polyline(PackedVector2Array([tip, at - dir * 6.0 + side * 13.0, at - dir * 6.0 - side * 13.0, tip]),
				Color(0, 0, 0, c.a * 0.7), 2.0, true)
		var lines := _label(String(p.what), String(p.ping.get("name", "")), p.node).split("\n")
		var y := at.y - dir.y * 30.0 - 8.0 * lines.size()
		for line in lines:
			var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var x := clampf(at.x - dir.x * 30.0 - w * 0.5, 8.0, _arrows.size.x - w - 8.0)
			_arrows.draw_string_outline(font, Vector2(x, y + 16.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0, c.a * 0.8))
			_arrows.draw_string(font, Vector2(x, y + 16.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
			y += 18.0


## Lights the usable thing under the pointer (null for none).
func set_target(t: Node) -> void:
	if t == target:
		return
	if target and is_instance_valid(target):
		highlighter.unlight(target, "hover")
	target = t
	if target:
		highlighter.light(target, "hover", HOVER_COLOUR, Highlighter.SUBTLE)
	hovered.emit(target)


## Pings what's under the pointer. False when nothing is there.
func ping_at_pointer() -> bool:
	var hit := pointer_hit(ping_range)
	if hit.is_empty():
		return false
	ping(hit.position, hit.get("target"), hit.normal, name_at(hit))
	return true


## Pings a spot, and the usable thing there if any; `label` is what it's called ("" works
## it out from the thing).
func ping(at: Vector3, thing: Node = null, normal := Vector3.UP, label := "") -> void:
	var id := id_of(thing)
	if label == "" and thing:
		label = name_of(thing)
	if _net and _net.has_method("ping"):
		if _net.get_method_argument_count("ping") >= 4:
			_net.call("ping", at, id, normal, label)
		else:
			_net.call("ping", at, id, normal)
		return
	_local_id += 1
	show_ping({"peer": 1, "name": "", "colour": PING_COLOUR, "at": at, "normal": normal,
			"object_id": id, "label": label, "id": -_local_id, "time": _now(), "target": thing})


## Draws a ping (from ping_received, or a local one): marker, light column, label and the
## pinged thing lit in the pinger's colour.
func show_ping(ping: Dictionary) -> void:
	var scene := get_tree().current_scene
	var parent: Node = scene if scene else self
	var colour: Color = ping.get("colour", PING_COLOUR)
	var at: Vector3 = ping.get("at", Vector3.ZERO)
	var key := _key_of(ping)
	# The same ping again (it came back through Multiplayer): draw it once.
	for p in live.duplicate():
		if p.key == key:
			_drop(p)
	# Up to pings_each per player: a new one past that takes down their oldest.
	var most := pings_each
	if _net and "PINGS_EACH" in _net:
		most = int(_net.get("PINGS_EACH"))
	var theirs := live.filter(func(p: Dictionary) -> bool: return p.ping.get("peer", 0) == ping.get("peer", 0))
	while theirs.size() >= maxi(most, 1):
		_drop(theirs.pop_front())
	var thing: Node = ping.get("target") if is_instance_valid(ping.get("target")) else find_thing(String(ping.get("object_id", "")), at)
	var what := String(ping.get("label", ""))
	if what == "" and thing:
		what = name_of(thing)
	var node := _marker(colour, what)
	parent.add_child(node)
	node.global_position = at
	if thing:
		highlighter.light(thing, "ping:%s" % key, colour)
	var life := ping_life
	if _net and "PING_LIFE" in _net:
		life = float(_net.get("PING_LIFE"))
	live.append({"ping": ping, "key": key, "what": what, "node": node, "lit": thing, "born": _now(), "life": life})
	(node.get_node("Label") as Label3D).text = _label(what, String(ping.get("name", "")), node)
	if _is_mine(ping):
		Sfx.play("tick", null, -8.0, 1.4)
	else:
		# A crewmate's ping: a brighter call, from where it is, so you turn to it.
		Sfx.play("chime", at, -2.0, 1.5)
	ping_shown.emit(ping)


## Whether a ping is this player's own.
func _is_mine(ping: Dictionary) -> bool:
	var me := 1
	if _net and _net.has_method("local_peer_id"):
		me = int(_net.call("local_peer_id"))
	return int(ping.get("peer", 1)) == me


## Takes a ping down at once (Multiplayer's ping_removed: its pinger went over the limit,
## or left).
func remove_ping(ping_id: int) -> void:
	for p in live.duplicate():
		if p.key == str(ping_id):
			_drop(p)


## What a thing is called, for a ping's label: its meta "gfx_name", else the title of its
## look hint (HudSlots), else its node name in words; "" when it has none worth showing.
static func name_of(thing: Node) -> String:
	if thing == null:
		return ""
	if thing.has_meta(NAME_META):
		return String(thing.get_meta(NAME_META))
	var hint := _hint_of(thing)
	if String(hint.get("title", "")) != "":
		return String(hint.title)
	var n := String(thing.name)
	return "" if n.contains("@") else n.capitalize()


## What's called at a pointer hit: the usable thing's name, else whatever the look hint says
## is there; "" for bare floor.
func name_at(hit: Dictionary) -> String:
	var thing: Node = hit.get("target")
	if thing and thing.has_meta(NAME_META):
		return String(thing.get_meta(NAME_META))
	var hint := HudSlots.look_hint_for(hit) if get_node_or_null("/root/HudSlots") else {}
	if String(hint.get("title", "")) != "":
		return String(hint.title)
	return name_of(thing)


static func _hint_of(n: Node) -> Dictionary:
	while n != null:
		if n.has_method("look_hint"):
			var h: Variant = n.call("look_hint")
			if h is Dictionary and not (h as Dictionary).is_empty():
				return h
		if n.has_meta("look_hint"):
			return n.get_meta("look_hint")
		n = n.get_parent()
	return {}


## A ping's key: Multiplayer's id when it has one, else the pinger and the time.
static func _key_of(ping: Dictionary) -> String:
	if ping.has("id"):
		return str(int(ping.id))
	return "%d@%.3f" % [int(ping.get("peer", 0)), float(ping.get("time", _now()))]


## The usable thing a ping names: by its id (meta GfxBus.ID_META), else the nearest within
## match_radius of where it landed.
func find_thing(id: String, at: Vector3) -> Node:
	var best: Node = null
	var best_d := match_radius
	for n in get_tree().get_nodes_in_group("gfx_interactable"):
		if id != "" and String(n.get_meta("gfx_id", "")) == id:
			return n
		if n is Node3D and id == "":
			var d := _distance_to(n as Node3D, at)
			if d <= best_d:
				best_d = d
				best = n
	return best


static func id_of(thing: Node) -> String:
	return String(thing.get_meta("gfx_id", "")) if thing else ""


## What's under the pointer: {position, normal, collider, target (usable thing or null)};
## empty for nothing within `length`.
func pointer_hit(length: float) -> Dictionary:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam == null or not cam.is_inside_tree():
		return {}
	var at := vp.get_visible_rect().size * 0.5
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		at = vp.get_mouse_position()
	var from := cam.project_ray_origin(at)
	var to := from + cam.project_ray_normal(at) * length
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.exclude = _own_bodies(cam)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	hit["target"] = usable_of(hit.collider)
	return hit


## The thing in group "gfx_interactable" a collider belongs to, or null.
static func usable_of(n: Object) -> Node:
	var p := n as Node
	while p:
		if p.is_in_group("gfx_interactable"):
			return p
		p = p.get_parent()
	return null


## The player's own body (the camera's parents), so the ray starts past it.
static func _own_bodies(cam: Node) -> Array[RID]:
	var out: Array[RID] = []
	var p := cam.get_parent()
	while p:
		if p is CollisionObject3D:
			out.append((p as CollisionObject3D).get_rid())
		p = p.get_parent()
	return out


func _age_pings() -> void:
	var now := _now()
	for p in live.duplicate():
		var age: float = now - float(p.born)
		var life: float = p.life
		if age >= life or not is_instance_valid(p.node):
			_drop(p)
			continue
		var a := clampf((life - age) / ping_fade, 0.0, 1.0)
		var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - age / 0.25)   # a short pop as it lands
		for c in p.node.get_children():
			if c is MeshInstance3D:
				var m := (c as MeshInstance3D).material_override as ShaderMaterial
				m.set_shader_parameter("alpha", a)
				if c.name == "Marker":
					m.set_shader_parameter("size", 0.05 * pop)
			elif c is Label3D:
				(c as Label3D).modulate.a = a
				(c as Label3D).text = _label(String(p.what), String(p.ping.get("name", "")), p.node)
		if p.lit and is_instance_valid(p.lit):
			highlighter.set_strength(p.lit, a)


func _drop(p: Dictionary) -> void:
	live.erase(p)
	if p.lit and is_instance_valid(p.lit):
		highlighter.unlight(p.lit, "ping:%s" % p.key)
	if is_instance_valid(p.node):
		p.node.queue_free()


func _marker(colour: Color, what: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Ping"
	root.add_to_group("gfx_ping")
	var quad := MeshInstance3D.new()
	quad.name = "Marker"
	quad.mesh = QuadMesh.new()
	quad.position = Vector3(0, 0.35, 0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := ShaderMaterial.new()
	mm.shader = MARKER
	mm.set_shader_parameter("colour", colour)
	quad.material_override = mm
	root.add_child(quad)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = beam_height
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	beam.position = Vector3(0, beam_height * 0.5, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bm := ShaderMaterial.new()
	bm.shader = BEAM
	bm.set_shader_parameter("colour", colour)
	beam.material_override = bm
	root.add_child(beam)
	var label := Label3D.new()
	label.name = "Label"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 28
	label.outline_size = 10
	label.modulate = colour
	label.position = Vector3(0, 0.35, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.offset = Vector2(0, 30)
	label.text = what
	root.add_child(label)
	return root


## The words by a marker: what was pinged over who pinged it and how far it is.
func _label(what: String, who: String, node: Node3D) -> String:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var dist := cam.global_position.distance_to(node.global_position) if cam else 0.0
	var line := ("%s  ·  %d m" % [who, roundi(dist)]) if who != "" else "%d m" % roundi(dist)
	return ("%s\n%s" % [what, line]) if what != "" else line


static func _distance_to(n: Node3D, at: Vector3) -> float:
	var best := n.global_position.distance_to(at)
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var v := c as VisualInstance3D
		var box := v.global_transform * v.get_aabb()
		var closest := at.clamp(box.position, box.end)
		best = minf(best, closest.distance_to(at))
	return best


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
