extends Node
## The crew in the design room, on every drawing of the design (Wave 3, beenster 19 Nov):
##   - each player's mouse on a deck plan shows on everyone else's plans as a pointer in their
##     crew colour with their name;
##   - a player walking inside the design shows on the plans, the side and end views and the
##     holotable as a marker facing the way they face;
##   - smart pings: a middle-click tap on a plan, or a middle-click while looking at the
##     holotable's hologram, marks the spot for the whole crew for PING_LIFE seconds, labelled
##     with what is there ("Reactor", "Cargo hold", "Door") and lighting that room or part up.
##
## Everything is in record space (x across, y up from deck 0's floor, z along, bow at -Z), so
## the plans, the elevations, walk-inside and the hologram all read the same numbers.
##
## Each player streams one mover, "player:<peer>:design" (always driven by that player): its
## origin is where they are and its basis is their heading scaled by what they are doing
## (HIDDEN, CURSOR or WALKING). Pings are the "design.ping" event, rate-limited by the host.

const PING_EVENT := "design.ping"
const PING_LIFE := 10.0
## The last seconds of a ping's life it fades out over.
const PING_FADE := 2.0
const PINGS_EACH := 5
## Seconds between one player's pings, held by the host.
const PING_GAP := 0.25
const LABEL_MAX := 40

## What a player's stream says they are doing (the scale of its basis).
const HIDDEN := 1
const CURSOR := 2
const WALKING := 3
## A walk not reported for this long has ended (walk-inside reports every physics frame).
const WALK_TIMEOUT := 0.5
## How far from the hologram a player may stand and still ping it, m.
const HOLO_REACH := 9.0
## A middle press that moves less than this before it lets go is a ping, not a pan, px.
const TAP_SLOP := 5.0
const TAP_TIME := 0.35

const DARK := Color(0.02, 0.05, 0.09, 0.85)

signal pings_changed

var bus: DesignBus
## Pings showing, oldest first: {id, peer, name, colour, deck, x, y, z, label, kind, ref, born}.
var pings: Array[Dictionary] = []
## Seconds this crew has run (pings age by it; tests move it with advance()).
var clock := 0.0

var _net: Object
var _me := 1
## This player's stream, and everyone else's copy of theirs: peer -> Node3D.
var _mine: Node3D
var _crew: Dictionary = {}
var _peers_checked := -1.0
var _registered := false
## The plans and holotables drawn on: view -> overlay (Control) / holo -> marks (Node3D).
var _views: Dictionary = {}
var _holos: Dictionary = {}
## Where this player is: on a plan (deck, at) or walking (pos, yaw, last report).
var _cursor: Dictionary = {}
var _walk: Dictionary = {}
var _tap: Dictionary = {}
var _seq := 0
## Host only: peer -> clock of their last ping.
var _last_ping: Dictionary = {}


func _init() -> void:
	name = "Crew"
	_mine = Node3D.new()
	_mine.name = "Me"
	_mine.transform = _code_transform(Vector3.ZERO, 0.0, HIDDEN)
	add_child(_mine)


# --- The network ------------------------------------------------------------------------

## Shares cursors, walks and pings through `net` (the multiplayer bus or a test's stand-in).
func hook(net: Object) -> void:
	unhook()
	_net = net
	_net.call("register_event", PING_EVENT, _apply_ping, _check_ping)
	_resync_peers()


func unhook() -> void:
	if _net == null:
		return
	_net.call("unregister_event", PING_EVENT)
	_net.call("unregister_mover", _stream_id(_me))
	for peer: int in _crew:
		_net.call("unregister_mover", _stream_id(peer))
		(_crew[peer] as Node).queue_free()
	_crew.clear()
	_registered = false
	_net = null


static func _stream_id(peer: int) -> String:
	return "player:%d:design" % peer


## Registers this player's stream and a follower for each other player in the session.
func _resync_peers() -> void:
	if _net == null:
		return
	var me := int(_net.call("local_peer_id"))
	if me != _me or not _registered:
		_net.call("unregister_mover", _stream_id(_me))
		_me = me
		_net.call("register_mover", _stream_id(_me), _mine)
		_registered = true
	var want: Array = []
	if _net.has_method("peers"):
		var all: Dictionary = _net.call("peers")
		for p in all:
			if int(p) != _me:
				want.append(int(p))
	for peer: int in _crew.keys():
		if not peer in want:
			_net.call("unregister_mover", _stream_id(peer))
			(_crew[peer] as Node).queue_free()
			_crew.erase(peer)
	for peer: int in want:
		add_peer(peer)


## A follower for `peer`'s stream (tests add them by hand; the session's peers come on their own).
func add_peer(peer: int) -> Node3D:
	if _crew.has(peer):
		return _crew[peer]
	var n := Node3D.new()
	n.name = "Peer_%d" % peer
	n.transform = _code_transform(Vector3.ZERO, 0.0, HIDDEN)
	add_child(n)
	_crew[peer] = n
	if _net:
		_net.call("register_mover", _stream_id(peer), n)
	return n


func _name_of(peer: int) -> String:
	return str(_net.call("player_name", peer)) if _net and _net.has_method("player_name") else "Crew"


func _colour_of(peer: int) -> Color:
	return _net.call("player_colour", peer) if _net and _net.has_method("player_colour") else Color("ff9a4d")


# --- Where everyone is ------------------------------------------------------------------

static func _code_transform(at: Vector3, yaw: float, code: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * float(code)), at)


## What a stream's transform says: {state: HIDDEN/CURSOR/WALKING, at: Vector3, yaw: float}.
static func read_stream(t: Transform3D) -> Dictionary:
	var code := clampi(roundi(t.basis.get_scale().x), HIDDEN, WALKING)
	return {"state": code, "at": t.origin, "yaw": t.basis.orthonormalized().get_euler().y}


## This player's mouse is over a plan of `deck` at record point `at` (x, z).
func set_cursor(deck: int, at: Vector2) -> void:
	_cursor = {"deck": deck, "at": at}
	_publish()


func clear_cursor() -> void:
	if _cursor.is_empty():
		return
	_cursor = {}
	_publish()


## Walk-inside reports where this player's body is (record space) and which way it faces,
## every physics frame while walking.
func walk_at(pos: Vector3, yaw: float) -> void:
	_walk = {"pos": pos, "yaw": yaw, "t": clock}
	_publish()


func _publish() -> void:
	var t := _code_transform(Vector3.ZERO, 0.0, HIDDEN)
	var rec := _rec()
	if not _walk.is_empty() and clock - float(_walk.t) <= WALK_TIMEOUT:
		t = _code_transform(_walk.pos, _walk.yaw, WALKING)
	elif not _cursor.is_empty() and rec:
		var at: Vector2 = _cursor.at
		t = _code_transform(Vector3(at.x, int(_cursor.deck) * rec.deck_height, at.y), 0.0, CURSOR)
	if not _mine.transform.is_equal_approx(t):
		_mine.transform = t


## The other players: [{peer, name, colour, state, at, yaw, deck}] for those on a plan or walking.
func crew() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rec := _rec()
	if rec == null:
		return out
	for peer: int in _crew:
		var s := read_stream((_crew[peer] as Node3D).transform)
		if int(s.state) == HIDDEN:
			continue
		var at: Vector3 = s.at
		s["peer"] = peer
		s["name"] = _name_of(peer)
		s["colour"] = _colour_of(peer)
		s["deck"] = maxi(int(floor((at.y + 0.5) / maxf(rec.deck_height, 0.1))), 0)
		out.append(s)
	return out


func _rec() -> DesignRecord:
	return bus.library.current if bus else null


# --- Pings ------------------------------------------------------------------------------

## Pings the spot (record space) for the whole crew; `label` says what is there.
func ping(deck: int, at: Vector3, label: String, kind := "", ref := "") -> void:
	var p := {"deck": deck, "x": at.x, "y": at.y, "z": at.z, "label": label, "kind": kind, "ref": ref}
	if _net:
		_net.call("request", PING_EVENT, p)
	else:
		var out: Variant = _check_ping(_me, p)
		if out is Dictionary:
			_apply_ping(out)


## Host: one ping per player every PING_GAP seconds, fields tidied, the sender stamped.
func _check_ping(sender: int, p: Dictionary) -> Variant:
	if clock - float(_last_ping.get(sender, -INF)) < PING_GAP:
		return "too many pings"
	_last_ping[sender] = clock
	var out := {"peer": sender, "deck": maxi(int(p.get("deck", 0)), 0),
			"x": float(p.get("x", 0.0)), "y": float(p.get("y", 0.0)), "z": float(p.get("z", 0.0)),
			"label": str(p.get("label", "")).left(LABEL_MAX), "kind": str(p.get("kind", "")).left(12),
			"ref": str(p.get("ref", "")).left(40)}
	return out


func _apply_ping(p: Dictionary) -> void:
	var peer := int(p.get("peer", 0))
	_seq += 1
	var entry := p.duplicate()
	entry["id"] = "%d:%d" % [peer, _seq]
	entry["name"] = _name_of(peer)
	entry["colour"] = _colour_of(peer)
	entry["born"] = clock
	pings.append(entry)
	var theirs := pings.filter(func(q: Dictionary) -> bool: return int(q.peer) == peer)
	if theirs.size() > PINGS_EACH:
		pings.erase(theirs[0])
	pings_changed.emit()
	_redraw()


## Moves the crew's clock on (pings age, a walk times out). _process does this every frame.
func advance(seconds: float) -> void:
	clock += seconds
	var before := pings.size()
	pings = pings.filter(func(q: Dictionary) -> bool: return clock - float(q.born) < PING_LIFE)
	if pings.size() != before:
		pings_changed.emit()
	if not _walk.is_empty() and clock - float(_walk.t) > WALK_TIMEOUT:
		_walk = {}
		_publish()


func _ping_alpha(p: Dictionary) -> float:
	return clampf((PING_LIFE - (clock - float(p.born))) / PING_FADE, 0.0, 1.0)


## What is at record point `at` on `deck`, in a few words, and what it is: {label, kind, ref}.
## Uses the plan's own picking when given one (it knows hull corners, runs and beams).
func describe(deck: int, at: Vector2, view: Control = null, screen := Vector2.INF) -> Dictionary:
	var rec := _rec()
	if rec == null:
		return {"label": "Here", "kind": "", "ref": ""}
	var hit: Dictionary = {}
	if view and screen != Vector2.INF:
		hit = view.call("pick", screen)
	if hit.is_empty():
		for c: Dictionary in rec.components.values():
			var r: Dictionary = rec.rooms.get(c.room, {})
			var pt := bus.catalog.part(str(c.type))
			if pt and not r.is_empty() and int(r.deck) == deck and DesignRules.footprint(c, pt).has_point(at):
				hit = {"kind": "part", "id": c.id}
				break
	if hit.is_empty():
		var rid := rec.room_at(deck, at)
		if rid != "":
			hit = {"kind": "room", "id": rid}
	var kind := str(hit.get("kind", ""))
	var id := str(hit.get("id", ""))
	var label := ""
	match kind:
		"room":
			label = room_name(rec.rooms.get(id, {}))
		"part":
			var pt := bus.catalog.part(str(rec.components.get(id, {}).get("type", "")))
			label = pt.display_name if pt else "Part"
		"mount":
			var pt := bus.catalog.part(str(rec.mounts.get(id, {}).get("type", "")))
			label = (pt.display_name if pt else "Part") + " on the hull"
		"door":
			var kind_name := str(rec.doors.get(id, {}).get("kind", "door")).replace("_", " ")
			label = kind_name.capitalize()
		"run":
			var spec: Dictionary = DesignServices.KINDS.get(str(rec.runs.get(id, {}).get("kind", "")), {})
			label = "%s run" % str(spec.get("name", "Service")).capitalize()
		"beam":
			label = "Beam"
		"wall":
			label = "Wall"
		"hull":
			label = "Hull corner"
		_:
			var outline := rec.hull_outline(deck)
			label = "Outside the hull" if outline.size() >= 3 and not Geometry2D.is_point_in_polygon(at, outline) else "Here"
	return {"label": label, "kind": kind, "ref": id}


func room_name(r: Dictionary) -> String:
	if r.is_empty():
		return "Room"
	if str(r.get("name", "")) != "":
		return str(r.name)
	var rt := bus.catalog.room(str(r.type))
	return rt.display_name if rt else str(r.type).capitalize()


## Pings what is under `screen` on a plan (the middle-click tap).
func ping_on_view(view: Control, screen: Vector2) -> void:
	var rec := _rec()
	if rec == null:
		return
	var mode := str(view.get("mode"))
	var p: Vector2 = view.call("to_ship", screen)
	var deck := int(view.get("deck"))
	var at := Vector3(p.x, deck * rec.deck_height + 1.5, p.y)
	var what := {"label": "Here", "kind": "", "ref": ""}
	if mode == "plan":
		what = describe(deck, p, view, screen)
	else:
		# Side (z across) or end (x across) view: the height says the deck.
		var y := -p.y
		deck = clampi(int(floor(y / maxf(rec.deck_height, 0.1))), 0, 99)
		var b := rec.bounds()
		at = Vector3(b.get_center().x, y, p.x) if mode == "side" else Vector3(p.x, y, b.get_center().y)
		what.label = "Deck %d" % (deck + 1)
	ping(deck, at, str(what.label), str(what.kind), str(what.ref))


# --- Plans --------------------------------------------------------------------------------

## Draws the crew on a plan view (PlanView.setup calls this) and reads this player's mouse
## from it when it is an editable plan.
func attach_view(view: Control) -> void:
	if _views.has(view):
		return
	var o := Control.new()
	o.name = "CrewMarks"
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.draw.connect(_draw_on.bind(o, view))
	view.add_child(o)
	_views[view] = o
	view.gui_input.connect(_on_view_input.bind(view))
	view.tree_exiting.connect(func() -> void: _views.erase(view))


func _on_view_input(event: InputEvent, view: Control) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_MIDDLE:
		return
	if mb.pressed:
		_tap = {"view": view, "at": mb.position, "t": clock}
	elif _tap.get("view") == view:
		if (mb.position - (_tap.at as Vector2)).length() <= TAP_SLOP and clock - float(_tap.t) <= TAP_TIME:
			ping_on_view(view, mb.position)
		_tap = {}


## This player's mouse, read from the editable plan it is over.
func _follow_mouse() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		clear_cursor()
		return
	for view: Control in _views:
		if not is_instance_valid(view) or not bool(view.get("editable")) or not view.is_visible_in_tree() \
				or str(view.get("mode")) != "plan":
			continue
		var local := view.get_local_mouse_position()
		if Rect2(Vector2.ZERO, view.size).has_point(local):
			set_cursor(int(view.get("deck")), view.call("to_ship", local))
			return
	clear_cursor()


func _redraw() -> void:
	for view in _views:
		if is_instance_valid(_views[view]):
			(_views[view] as Control).queue_redraw()


## Where record point `at` falls on the view, and whether it is on the deck shown.
static func _on_screen(view: Control, at: Vector3, deck: int) -> Dictionary:
	var mode := str(view.get("mode"))
	var flat := Vector2(at.x, at.z)
	if mode == "side":
		flat = Vector2(at.z, -at.y)
	elif mode == "end":
		flat = Vector2(at.x, -at.y)
	return {"s": view.call("to_screen", flat), "here": mode != "plan" or int(view.get("deck")) == deck}


func _draw_on(o: Control, view: Control) -> void:
	var rec := _rec()
	if rec == null:
		return
	var font := ThemeDB.fallback_font
	var area := Rect2(Vector2.ZERO, o.size).grow(-12)
	for p in pings:
		var a := _ping_alpha(p)
		var col: Color = p.colour
		var where := _on_screen(view, Vector3(p.x, p.y, p.z), int(p.deck))
		var here: bool = where.here
		if here and str(view.get("mode")) == "plan":
			_draw_ref(o, view, rec, p, Color(col, a))
		var s: Vector2 = where.s
		var off := not area.has_point(s)
		s = s.clamp(area.position, area.end)
		var k := a * (1.0 if here else 0.45)
		var pulse := 0.5 + 0.5 * sin((clock - float(p.born)) * 6.0)
		o.draw_arc(s, 10.0 + 8.0 * pulse, 0, TAU, 28, Color(col, k * (1.0 - pulse * 0.6)), 2.0)
		var d := 7.0
		o.draw_colored_polygon(PackedVector2Array([s + Vector2(0, -d), s + Vector2(d, 0), s + Vector2(0, d), s + Vector2(-d, 0)]), Color(col, k))
		o.draw_polyline(PackedVector2Array([s + Vector2(0, -d), s + Vector2(d, 0), s + Vector2(0, d), s + Vector2(-d, 0), s + Vector2(0, -d)]), Color(DARK, k), 1.5)
		var text := "%s: %s" % [p.name, p.label]
		if not here:
			text += " (deck %d)" % (int(p.deck) + 1)
		if off:
			text = "↗ " + text
		_tag(o, font, s + Vector2(12, -12), text, col, k)
	for c in crew():
		var where := _on_screen(view, c.at, int(c.deck))
		if int(c.state) == CURSOR and str(view.get("mode")) != "plan":
			continue
		var s: Vector2 = where.s
		if not area.grow(12).has_point(s):
			continue
		var k := 1.0 if where.here else 0.4
		var col: Color = c.colour
		var label := str(c.name)
		if not where.here:
			label += " (deck %d)" % (int(c.deck) + 1)
		if int(c.state) == CURSOR:
			_draw_pointer(o, s, Color(col, k))
			_tag(o, font, s + Vector2(14, 26), label, col, k)
		else:
			var r := clampf(float(view.get("zoom")) * 0.35, 6.0, 14.0)
			var yaw := float(c.yaw)
			# Facing: -Z is forward at yaw 0; on the plan +z is down the screen.
			var face := Vector2(-sin(yaw), -cos(yaw))
			if str(view.get("mode")) == "side":
				face = Vector2(face.y, 0)
			elif str(view.get("mode")) == "end":
				face = Vector2(face.x, 0)
			o.draw_circle(s, r + 2.0, Color(DARK, k))
			o.draw_circle(s, r, Color(col, k))
			if face.length() > 0.2:
				var f := face.normalized()
				var side := Vector2(-f.y, f.x)
				o.draw_colored_polygon(PackedVector2Array([s + f * (r + 9.0), s + side * r * 0.7, s - side * r * 0.7]), Color(col, k))
			_tag(o, font, s + Vector2(r + 6, -r - 4), label + " · inside", col, k)


## The arrow of a mouse pointer, its tip at `s`.
static func _draw_pointer(o: Control, s: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 19), Vector2(5, 14), Vector2(9, 22),
			Vector2(12.5, 20.5), Vector2(8.5, 13), Vector2(15, 13)])
	for i in pts.size():
		pts[i] = s + pts[i]
	o.draw_colored_polygon(pts, col)
	var ring := pts.duplicate()
	ring.append(pts[0])
	o.draw_polyline(ring, Color(DARK, col.a), 1.5)


static func _tag(o: Control, font: Font, pos: Vector2, text: String, col: Color, k: float) -> void:
	var fs := 13
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	o.draw_rect(Rect2(pos - Vector2(4, fs + 2), Vector2(w + 8, fs + 7)), Color(DARK, 0.8 * k))
	o.draw_rect(Rect2(pos - Vector2(4, fs + 2), Vector2(3, fs + 7)), Color(col, k))
	o.draw_string(font, pos + Vector2(2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.lightened(0.35), k))


## Lights up the room or part a ping is on, in the pinger's colour.
func _draw_ref(o: Control, view: Control, rec: DesignRecord, p: Dictionary, col: Color) -> void:
	var rect := Rect2()
	match str(p.kind):
		"room":
			var r: Dictionary = rec.rooms.get(str(p.ref), {})
			if r.is_empty():
				return
			rect = Rect2(r.x, r.z, r.w, r.d)
		"part":
			var c: Dictionary = rec.components.get(str(p.ref), {})
			var pt := bus.catalog.part(str(c.get("type", "")))
			if c.is_empty() or pt == null:
				return
			rect = DesignRules.footprint(c, pt)
		_:
			return
	var a: Vector2 = view.call("to_screen", rect.position)
	var b: Vector2 = view.call("to_screen", rect.end)
	var sr := Rect2(a, b - a).abs()
	o.draw_rect(sr, Color(col, col.a * 0.12))
	o.draw_rect(sr.grow(2.0), col, false, 3.0)


# --- The holotable --------------------------------------------------------------------------

## Shows the crew over the holotable's hologram (HoloTable.setup calls this).
func attach_holo(holo: Node3D) -> void:
	if _holos.has(holo):
		return
	var marks := Node3D.new()
	marks.name = "CrewMarks"
	# Beside the model, not in it: the hologram frees everything in its model when it rebuilds.
	holo.add_child(marks)
	_holos[holo] = {"marks": marks, "key": ""}
	holo.tree_exiting.connect(func() -> void: _holos.erase(holo))


## Keeps the marks over the hologram's ship and builds them again when what shows changes.
func _update_holo(holo: Node3D) -> void:
	var entry: Dictionary = _holos[holo]
	var marks: Node3D = entry.marks
	var model: Node3D = holo.get("model")
	if model == null or not is_instance_valid(marks) or not marks.is_inside_tree():
		return
	var ship := model.get_node_or_null("Ship") as Node3D
	marks.visible = ship != null and not ship.is_queued_for_deletion()
	if not marks.visible:
		return
	marks.global_transform = ship.global_transform
	var people := crew()
	var key := ""
	for p in pings:
		key += "p" + str(p.id)
	for c in people:
		key += "c%d.%d" % [c.peer, c.state]
	if key != entry.key:
		entry.key = key
		for n in marks.get_children():
			marks.remove_child(n)
			n.queue_free()
		for p in pings:
			marks.add_child(_holo_mark("P" + str(p.id).replace(":", "_"), p.colour, "%s: %s" % [p.name, p.label], true))
		for c in people:
			marks.add_child(_holo_mark("C%d" % c.peer, c.colour, str(c.name), false))
	# Sizes in room metres whatever the hologram's scale.
	var inv := 1.0 / maxf(model.scale.x, 0.0001)
	var rec := _rec()
	for p in pings:
		var n := marks.get_node_or_null("P" + str(p.id).replace(":", "_")) as Node3D
		if n:
			n.position = Vector3(p.x, int(p.deck) * rec.deck_height, p.z)
			n.scale = Vector3.ONE * inv
			_fade(n, _ping_alpha(p))
	for c in people:
		var n := marks.get_node_or_null("C%d" % c.peer) as Node3D
		if n:
			var at: Vector3 = c.at
			n.position = Vector3(at.x, int(c.deck) * rec.deck_height, at.z)
			n.scale = Vector3.ONE * inv
			n.rotation.y = float(c.yaw)


static func _fade(n: Node3D, a: float) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var m := (c as MeshInstance3D).material_override as StandardMaterial3D
			if m:
				m.albedo_color.a = a
		elif c is Label3D:
			(c as Label3D).modulate.a = a
			(c as Label3D).outline_modulate.a = a


## A marker over the hologram, in room metres: a pin with a light column for a ping, a small
## figure for a crewmate; the label floats above it.
static func _holo_mark(id: String, col: Color, text: String, is_ping: bool) -> Node3D:
	var n := Node3D.new()
	n.name = id
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = col
	var top := 0.0
	if is_ping:
		var column := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.008
		cyl.bottom_radius = 0.008
		cyl.height = 0.35
		column.mesh = cyl
		column.position.y = 0.175
		column.material_override = mat
		n.add_child(column)
		var gem := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.035
		sph.height = 0.07
		sph.radial_segments = 6
		sph.rings = 3
		gem.mesh = sph
		gem.position.y = 0.35
		gem.material_override = mat
		n.add_child(gem)
		var foot := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.05
		ring.outer_radius = 0.065
		foot.mesh = ring
		foot.material_override = mat
		n.add_child(foot)
		top = 0.42
	else:
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.025
		cap.height = 0.14
		body.mesh = cap
		body.position.y = 0.07
		body.material_override = mat
		n.add_child(body)
		var nose := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, 0.02, 0.05)
		nose.mesh = box
		nose.position = Vector3(0, 0.11, -0.04)
		nose.material_override = mat
		n.add_child(nose)
		top = 0.2
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0012
	label.font_size = 36
	label.outline_size = 10
	label.modulate = col.lightened(0.3)
	label.outline_modulate = Color(0.02, 0.05, 0.09)
	label.position.y = top + 0.04
	label.render_priority = 2
	n.add_child(label)
	return n


## A middle-click looking at a hologram pings the deck floor the look meets.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_MIDDLE \
			or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mid := get_viewport().get_visible_rect().size * 0.5
	var hit := holo_hit(cam.project_ray_origin(mid), cam.project_ray_normal(mid))
	if hit.is_empty():
		return
	var at: Vector3 = hit.at
	var what := describe(int(hit.deck), Vector2(at.x, at.z))
	ping(int(hit.deck), at, str(what.label), str(what.kind), str(what.ref))
	get_viewport().set_input_as_handled()


## Where a look from `origin` along `dir` (world space) meets a deck floor of a hologram:
## {deck, at (record space)}, or {} when it misses them all or stands too far off.
func holo_hit(origin: Vector3, dir: Vector3) -> Dictionary:
	var rec := _rec()
	if rec == null:
		return {}
	for holo: Node3D in _holos:
		var marks: Node3D = _holos[holo].marks
		if not is_instance_valid(holo) or not holo.is_visible_in_tree() or not marks.is_inside_tree() \
				or origin.distance_to(holo.global_position) > HOLO_REACH:
			continue
		var inv := marks.global_transform.affine_inverse()
		var o := inv * origin
		var d := (inv.basis * dir).normalized()
		if absf(d.y) < 0.001:
			continue
		var b := rec.bounds().grow(0.5)
		var best := {}
		var best_t := INF
		for deck in rec.decks():
			var y := float(deck) * rec.deck_height
			var t := (y - o.y) / d.y
			if t <= 0.0 or t >= best_t:
				continue
			var p := o + d * t
			if b.has_point(Vector2(p.x, p.z)) and rec.room_at(deck, Vector2(p.x, p.z)) != "":
				best_t = t
				best = {"deck": deck, "at": Vector3(p.x, y + 1.5, p.z)}
		if not best.is_empty():
			return best
	return {}


func _process(delta: float) -> void:
	advance(delta)
	if _net and clock - _peers_checked > 0.5:
		_peers_checked = clock
		_resync_peers()
	_follow_mouse()
	_publish()
	var busy := not pings.is_empty() or not crew().is_empty()
	if busy or _was_busy:
		_redraw()
	_was_busy = busy
	for holo in _holos.keys():
		if is_instance_valid(holo):
			_update_holo(holo)


var _was_busy := false
