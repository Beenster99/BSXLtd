class_name TradesBeamDesigner
extends Node3D
## Designing a modification as a hologram of beams round the ship in the courtyard (beenster,
## 0.3.27: "players are able to draw a hologram of beams around an existing ship in the
## courtyard and move, rotate, delete and test different ideas for the modification"). Behind
## trades.beam_designer; the plan is the doc "Beam Designer and Assembly Packages" (stage D1).
##
## With the design tablet in hand:
##   left click     start a beam, click again to end it (ends snap to other beams' ends and
##                  the ship's frame corners, else to a 50 mm grid); on a beam, pick it up to
##                  move it, and click again to set it down
##   right click    cancel what you are drawing or moving; on a beam, delete it
##   wheel          the section of the beam you are drawing, moving or pointing at
##   Q / E          turn the beam 15 degrees about the upright (Shift: roll it about its length)
##   G              copy the beam you point at and pick the copy up
##   X              undo (Shift+X redo)
## The design is kept per ship in TradesBus (in the save) and shared with the crew by one
## event that carries the whole design; a beam clashing with the ship or another beam is red,
## an end that nothing holds is amber.

const EVENT := "trades.beams"
const SECTION := "trades_beams"
const INFO := "trades.beams"
## How far the tablet reaches (m from the eye), and where the aim lands when it meets nothing.
const REACH_M := 14.0
const AIR_M := 4.0
## Snapping: to another beam's end, to a corner of the ship's frame, else to the grid (m).
const SNAP_END_M := 0.25
const SNAP_NODE_M := 0.15
const GRID_M := 0.05
## Turning steps (degrees), the shortest beam and the most in a design.
const TURN_DEG := 15.0
const MIN_M := 0.1
const MAX_M := 30.0
const MAX_BEAMS := 300
## How near a beam's end must be to something for it to count as held (m), and how close two
## beams' ends must be to count as meeting.
const HOLD_M := 0.08
const MEET_M := 0.06
## How often the clash and support checks run while nothing changes (s).
const CHECK_S := 1.0

const BLUE := Color(0.35, 0.75, 1.0, 0.55)
const BLUE_FAINT := Color(0.35, 0.75, 1.0, 0.25)
const LIT := Color(0.7, 0.95, 1.0, 0.6)
const RED := Color(1.0, 0.25, 0.2, 0.55)
const AMBER := Color(1.0, 0.7, 0.15, 0.9)
const GHOST := Color(0.6, 0.9, 1.0, 0.35)

var bay: Node  # TradesBay
## The section the next beam is drawn in.
var section := TradesBeamSections.DEFAULT
## The beam under the aim (its id, -1 for none), picked up (-1 for none), and the start of the
## beam being drawn (INF while not drawing): ship space.
var hovered := -1
var grabbed := -1
var start := Vector3.INF
## The snapped point under the aim now (ship space) and what it snapped to: "end", "node",
## "grid" or "".
var aim_point := Vector3.INF
var snapped_to := ""
## The checks' findings: beam ids that clash, and [beam id, end 0|1] pairs nothing holds.
var clashes: Dictionary = {}
var loose_ends: Array = []

var _net: Node
var _holo: Node3D
var _ghost: MeshInstance3D
var _marker: MeshInstance3D
var _length_label: Label3D
var _mats: Dictionary = {}
var _undo: Array = []
var _redo: Array = []
## The picked-up beam where it is being moved to, drawn here and shared when it is set down.
var _moving: Dictionary = {}
var _pick_when_here := -1
var _grab_offset := Vector3.ZERO
var _grab_depth := AIR_M
var _check_s := 0.0
var _dirty := true
var _drawn_key := ""
var _shown := ""


static func enabled() -> bool:
	return Flags.is_on("trades.beam_designer")


func build(net: Node = null) -> void:
	_holo = Node3D.new()
	_holo.name = "Hologram"
	_holo.top_level = true
	add_child(_holo)
	for key: String in ["blue", "faint", "lit", "red", "amber", "ghost"]:
		_mats[key] = _material({"blue": BLUE, "faint": BLUE_FAINT, "lit": LIT, "red": RED, "amber": AMBER, "ghost": GHOST}[key])
	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.material_override = _mats.ghost
	_ghost.visible = false
	_holo.add_child(_ghost)
	_marker = MeshInstance3D.new()
	_marker.name = "Snap"
	var dot := SphereMesh.new()
	dot.radius = 0.04
	dot.height = 0.08
	_marker.mesh = dot
	_marker.material_override = _mats.lit
	_marker.visible = false
	_holo.add_child(_marker)
	_length_label = Label3D.new()
	_length_label.name = "Length"
	_length_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_length_label.no_depth_test = true
	_length_label.font = TradesLook.mono_font()
	_length_label.font_size = 40
	_length_label.pixel_size = 0.004
	_length_label.modulate = LIT
	_length_label.visible = false
	_holo.add_child(_length_label)
	var bus := Modules.bus("trades") as TradesBus
	if bus:
		bus.beam_design_changed.connect(func(_id: String) -> void: _dirty = true)
	_net = net
	if _net:
		_net.call("register_event", EVENT, _apply, _validate)
		if _net.has_method("register_snapshot_provider"):
			_net.call("register_snapshot_provider", SECTION, self)


func _exit_tree() -> void:
	HudSlots.clear_info(INFO)
	if _net:
		_net.call("unregister_event", EVENT)
		if _net.has_method("unregister_snapshot_provider"):
			_net.call("unregister_snapshot_provider", SECTION)


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --- The design ----------------------------------------------------------------------------

## The ship the design is drawn round (its id; "" with none in the bay).
func ship_id() -> String:
	var b := Modules.bus("ship_bay") as ShipBayBus
	return b.ship.ship_id if b and b.ship else ""


## The beams of the design now: rows {id, a, b (Vector3, ship space), section, turn}.
func beams() -> Array:
	var bus := Modules.bus("trades") as TradesBus
	var out: Array = []
	if bus == null:
		return out
	for r: Dictionary in bus.beam_design(ship_id()):
		var b := {"id": int(r.id), "a": _v(r.a), "b": _v(r.b), "section": TradesBeamSections.normal(str(r.section)), "turn": float(r.turn)}
		if not _moving.is_empty() and int(_moving.id) == b.id:
			b = _moving.duplicate()
		out.append(b)
	return out


func beam(id: int) -> Dictionary:
	for b: Dictionary in beams():
		if int(b.id) == id:
			return b
	return {}


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _row(b: Dictionary) -> Dictionary:
	var a: Vector3 = b.a
	var e: Vector3 = b.b
	return {"id": int(b.id), "a": [snappedf(a.x, 0.001), snappedf(a.y, 0.001), snappedf(a.z, 0.001)],
			"b": [snappedf(e.x, 0.001), snappedf(e.y, 0.001), snappedf(e.z, 0.001)],
			"section": str(b.section), "turn": snappedf(float(b.turn), 0.01)}


## Total length (m) and mass (kg, steel) of the design.
func totals() -> Vector2:
	var out := Vector2.ZERO
	for b: Dictionary in beams():
		var l := ((b.b as Vector3) - (b.a as Vector3)).length()
		out += Vector2(l, TradesBeamSections.mass(str(b.section), l))
	return out


## Puts the design in place of what is there (an edit: undoable). `list`: beam dictionaries.
func commit(list: Array, undoable := true) -> void:
	if undoable:
		_undo.append(beams())
		_redo.clear()
	var rows: Array = []
	for b: Dictionary in list:
		rows.append(_row(b))
	_ask({"ship": ship_id(), "rows": rows})


func _next_id(list: Array) -> int:
	var n := 0
	for b: Dictionary in list:
		n = maxi(n, int(b.id))
	return n + 1


## Adds a beam from `a` to `b` (ship space). Returns its id, or -1 when it is too short or long.
func add_beam(a: Vector3, b: Vector3, sec := "") -> int:
	var l := a.distance_to(b)
	if l < MIN_M or l > MAX_M:
		return -1
	var list := beams()
	if list.size() >= MAX_BEAMS:
		return -1
	var id := _next_id(list)
	list.append({"id": id, "a": a, "b": b, "section": sec if sec != "" else section, "turn": 0.0})
	commit(list)
	return id


func delete_beam(id: int) -> void:
	commit(beams().filter(func(b: Dictionary) -> bool: return int(b.id) != id))


## Changes one beam (`change` merged over it).
func edit_beam(id: int, change: Dictionary, undoable := true) -> void:
	if id == grabbed and not _moving.is_empty():
		_moving.merge(change, true)
		_dirty = true
		return
	var list := beams()
	for b: Dictionary in list:
		if int(b.id) == id:
			b.merge(change, true)
	commit(list, undoable)


## Turns a beam `deg` about the upright through its middle, or rolls it about its length.
func turn_beam(id: int, deg: float, roll := false) -> void:
	var b := beam(id)
	if b.is_empty():
		return
	if roll:
		edit_beam(id, {"turn": fposmod(float(b.turn) + deg, 360.0)})
		return
	var mid := ((b.a as Vector3) + (b.b as Vector3)) * 0.5
	var r := Basis(Vector3.UP, deg_to_rad(deg))
	edit_beam(id, {"a": mid + r * ((b.a as Vector3) - mid), "b": mid + r * ((b.b as Vector3) - mid)})


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(beams())
	commit(_undo.pop_back(), false)
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(beams())
	commit(_redo.pop_back(), false)
	return true


# --- Input (the bay hands it the tablet's clicks, keys and wheel) ---------------------------

func holding() -> bool:
	return bay != null and bay.get("tool") == &"tablet"


## Left (pressed) or right click with the tablet. Returns true when it used it.
func click(left: bool) -> bool:
	if left:
		if grabbed >= 0:
			set_down()
			_play(&"clunk")
		elif start.is_finite():
			if aim_point.is_finite() and add_beam(start, aim_point) >= 0:
				_play(&"click")
				start = Vector3.INF
			else:
				_say("A beam runs %d mm to %d m." % [roundi(MIN_M * 1000.0), roundi(MAX_M)])
		elif hovered >= 0:
			pick_up(hovered)
		elif aim_point.is_finite():
			start = aim_point
			_play(&"tick")
		return true
	if grabbed >= 0:
		# Put back where it was: the move never left this machine.
		grabbed = -1
		_moving = {}
		if not _undo.is_empty():
			_undo.pop_back()
		_dirty = true
	elif start.is_finite():
		start = Vector3.INF
	elif hovered >= 0:
		delete_beam(hovered)
		hovered = -1
		_play(&"clunk")
	return true


## Picks a beam up to move it (it follows the aim till the next left click).
func pick_up(id: int, push := true) -> void:
	var b := beam(id)
	if b.is_empty():
		return
	grabbed = id
	if push:
		_undo.append(beams())
		_redo.clear()
	_moving = b.duplicate()
	var eye := _eye_ship()
	var mid := ((b.a as Vector3) + (b.b as Vector3)) * 0.5
	_grab_depth = clampf(eye[0].distance_to(mid), 1.0, REACH_M)
	_grab_offset = mid - (eye[0] + eye[1] * _grab_depth)
	_play(&"tick")


## One wheel notch: true when it changed a section (else the bay changes tools).
func wheel(step: int) -> bool:
	var id := grabbed if grabbed >= 0 else hovered
	if start.is_finite() or id < 0:
		if not start.is_finite():
			return false
		section = TradesBeamSections.step(section, step)
	else:
		var b := beam(id)
		var sec := TradesBeamSections.step(str(b.section), step)
		section = sec
		edit_beam(id, {"section": sec}, grabbed < 0)
	_play(&"tick")
	return true


## A key with the tablet in hand (TradesBus.KEY_*). True when it used it.
func key(action: String) -> bool:
	var shift := Input.is_key_pressed(KEY_SHIFT)
	var id := grabbed if grabbed >= 0 else hovered
	match action:
		TradesBus.KEY_TURN_LEFT, TradesBus.KEY_TURN_RIGHT:
			if id < 0:
				return false
			var deg := TURN_DEG * (1.0 if action == TradesBus.KEY_TURN_RIGHT else -1.0)
			if grabbed >= 0:
				var b := beam(id)
				if shift:
					edit_beam(id, {"turn": fposmod(float(b.turn) + deg, 360.0)}, false)
				else:
					var mid := ((b.a as Vector3) + (b.b as Vector3)) * 0.5
					var r := Basis(Vector3.UP, deg_to_rad(deg))
					edit_beam(id, {"a": mid + r * ((b.a as Vector3) - mid), "b": mid + r * ((b.b as Vector3) - mid)}, false)
			else:
				turn_beam(id, deg, shift)
			_play(&"tick")
			return true
		TradesBus.KEY_NEXT:
			if hovered < 0 or grabbed >= 0:
				return false
			var b := beam(hovered)
			var list := beams()
			var copy := b.duplicate()
			copy.id = _next_id(list)
			list.append(copy)
			commit(list)
			# The copy only arrives with the event: offline at once, online a moment later.
			_pick_when_here = int(copy.id)
			_say("Copied. Move the copy and click to set it down.")
			return true
		TradesBus.KEY_MODE:
			if grabbed >= 0 or start.is_finite():
				return false
			if redo() if shift else undo():
				_play(&"tick")
			else:
				_say("Nothing to redo." if shift else "Nothing to undo.")
			return true
	return false


# --- Every step: the aim, the snapping, the checks ------------------------------------------

func ship_xform() -> Transform3D:
	return bay.call("ship_transform") if bay and bay.has_method("ship_transform") else Transform3D.IDENTITY


## The eye and the aim's direction in ship space.
func _eye_ship() -> Array:
	var w := bay.get("worker") as Node3D if bay else null
	if w == null or not w.is_inside_tree():
		return [Vector3.ZERO, Vector3.FORWARD]
	var inv := ship_xform().affine_inverse()
	var from: Vector3 = w.call("aim_origin")
	var dir: Vector3 = w.call("aim_dir")
	return [inv * from, (inv.basis * dir).normalized()]


func _physics_process(delta: float) -> void:
	if _holo == null:
		return
	_holo.global_transform = ship_xform()
	if holding():
		_aim()
	else:
		hovered = -1
		start = Vector3.INF
		if grabbed >= 0:
			set_down()
		aim_point = Vector3.INF
	_check_s -= delta
	if _dirty or _check_s <= 0.0:
		_check_s = CHECK_S
		_dirty = false
		run_checks()
	_draw()


## Sets the beam being moved down where it is now, for everyone.
func set_down() -> void:
	if grabbed < 0:
		return
	var list := beams()
	grabbed = -1
	_moving = {}
	commit(list, false)


func _aim() -> void:
	if _pick_when_here >= 0 and not beam(_pick_when_here).is_empty():
		pick_up(_pick_when_here, false)
		_pick_when_here = -1
	var w := bay.get("worker") as CollisionObject3D
	var eye := _eye_ship()
	var from: Vector3 = eye[0]
	var dir: Vector3 = eye[1]
	if grabbed >= 0:
		_follow_grab(from, dir)
		return
	# A beam under the aim, nearest first.
	hovered = -1
	var near_t := INF
	for b: Dictionary in beams():
		var c := Geometry3D.get_closest_points_between_segments(from, from + dir * REACH_M, b.a, b.b)
		if c[0].distance_to(c[1]) <= TradesBeamSections.radius(str(b.section)) + 0.05:
			var t := from.distance_to(c[0])
			if t < near_t:
				near_t = t
				hovered = int(b.id)
	# The surface under the aim.
	var world_from: Vector3 = w.call("aim_origin")
	var world_dir: Vector3 = w.call("aim_dir")
	var q := PhysicsRayQueryParameters3D.create(world_from, world_from + world_dir * REACH_M)
	q.exclude = [w.get_rid()]
	var hit := w.get_world_3d().direct_space_state.intersect_ray(q)
	var p: Vector3
	if not hit.is_empty():
		p = ship_xform().affine_inverse() * (hit.position as Vector3)
		if hovered >= 0 and near_t > from.distance_to(p):
			hovered = -1
	elif start.is_finite():
		p = from + dir * clampf(from.distance_to(start), 1.0, REACH_M)
	else:
		p = from + dir * AIR_M
	if start.is_finite():
		hovered = -1
	var s := snap(p)
	aim_point = s[0]
	snapped_to = s[1]


func _follow_grab(from: Vector3, dir: Vector3) -> void:
	var b := beam(grabbed)
	if b.is_empty():
		grabbed = -1
		return
	var a: Vector3 = b.a
	var e: Vector3 = b.b
	var mid := (a + e) * 0.5
	var want := from + dir * _grab_depth + _grab_offset
	var shift := want - mid
	# An end that comes near a snap point pulls the whole beam onto it, else the middle to the grid.
	var sa := snap(a + shift, grabbed, false)
	var se := snap(e + shift, grabbed, false)
	if sa[1] != "":
		shift = (sa[0] as Vector3) - a
		snapped_to = sa[1]
	elif se[1] != "":
		shift = (se[0] as Vector3) - e
		snapped_to = se[1]
	else:
		shift = (want - mid).snapped(Vector3.ONE * GRID_M)
		snapped_to = "grid"
	aim_point = Vector3.INF
	if shift.length() > 0.0005:
		edit_beam(grabbed, {"a": a + shift, "b": e + shift}, false)


## A ship-space point snapped: [point, what to]. To another beam's end (not `skip`'s), a corner
## of the ship's frame, else the grid (`grid` false: no grid, [p, ""] instead).
func snap(p: Vector3, skip := -1, grid := true) -> Array:
	var best := Vector3.INF
	var best_d := SNAP_END_M
	for b: Dictionary in beams():
		if int(b.id) == skip:
			continue
		for end: Vector3 in [b.a, b.b]:
			var d := end.distance_to(p)
			if d < best_d:
				best_d = d
				best = end
	if best.is_finite():
		return [best, "end"]
	best_d = SNAP_NODE_M
	var b := Modules.bus("ship_bay") as ShipBayBus
	if b:
		for s: MountSlot in b.get_slots():
			if not s.box.grow(SNAP_NODE_M).has_point(p):
				continue
			for i in 8:
				var c := s.box.get_endpoint(i)
				var d := c.distance_to(p)
				if d < best_d:
					best_d = d
					best = c
	if best.is_finite():
		return [best, "node"]
	return [p.snapped(Vector3.ONE * GRID_M), "grid"] if grid else [p, ""]


## The clash and support checks: what each beam meets.
func run_checks() -> void:
	clashes.clear()
	loose_ends.clear()
	var list := beams()
	if list.is_empty() or not is_inside_tree():
		return
	var xf := ship_xform()
	var space := get_world_3d().direct_space_state
	var w := bay.get("worker") as CollisionObject3D if bay else null
	var exclude: Array[RID] = []
	if w:
		exclude.append(w.get_rid())
	for b: Dictionary in list:
		var a: Vector3 = b.a
		var e: Vector3 = b.b
		var sec := str(b.section)
		var r := TradesBeamSections.radius(sec)
		var l := a.distance_to(e)
		# The beam's body (its ends left out, where it meets what holds it) against the world.
		if l > 0.3:
			var box := BoxShape3D.new()
			var s: Dictionary = TradesBeamSections.info(sec)
			box.size = Vector3(float(s.get("w", 0.1)) * 0.8, float(s.get("h", 0.1)) * 0.8, l - 0.2)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = box
			q.transform = xf * beam_xform(b)
			q.exclude = exclude
			if not space.intersect_shape(q, 1).is_empty():
				clashes[int(b.id)] = "ship"
		for o: Dictionary in list:
			if int(o.id) <= int(b.id):
				continue
			var c := Geometry3D.get_closest_points_between_segments(a, e, o.a, o.b)
			if c[0].distance_to(c[1]) >= (r + TradesBeamSections.radius(str(o.section))) * 0.8:
				continue
			# Meeting at an end is a joint, not a clash.
			var at: Vector3 = c[0]
			var at_end := false
			for end: Vector3 in [a, e, o.a, o.b]:
				if end.distance_to(at) < r * 2.0 + MEET_M:
					at_end = true
			if not at_end:
				clashes[int(b.id)] = "beam"
				clashes[int(o.id)] = "beam"
		for k in 2:
			var end: Vector3 = a if k == 0 else e
			if not _held(end, int(b.id), list, space, xf, exclude):
				loose_ends.append([int(b.id), k])


func _held(end: Vector3, id: int, list: Array, space: PhysicsDirectSpaceState3D, xf: Transform3D, exclude: Array[RID]) -> bool:
	for o: Dictionary in list:
		if int(o.id) == id:
			continue
		if end.distance_to(o.a) < MEET_M or end.distance_to(o.b) < MEET_M:
			return true
		var c := Geometry3D.get_closest_point_to_segment(end, o.a, o.b)
		if c.distance_to(end) < TradesBeamSections.radius(str(o.section)) + HOLD_M:
			return true
	var ball := SphereShape3D.new()
	ball.radius = HOLD_M
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.transform = Transform3D(Basis(), xf * end)
	q.exclude = exclude
	return not space.intersect_shape(q, 1).is_empty()


## A beam's transform in ship space: its middle, its length along Z, its section's height up
## (as near up as the beam lets it), rolled by its turn.
static func beam_xform(b: Dictionary) -> Transform3D:
	var a: Vector3 = b.a
	var e: Vector3 = b.b
	var dir := (e - a).normalized()
	if dir == Vector3.ZERO:
		dir = Vector3.FORWARD
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var basis := Basis.looking_at(dir, up)
	basis = basis * Basis(Vector3.BACK, deg_to_rad(float(b.get("turn", 0.0))))
	return Transform3D(basis, (a + e) * 0.5)


# --- Drawing --------------------------------------------------------------------------------

func _draw() -> void:
	var list := beams()
	var faint := not _anyone_holding()
	var key := "%s|%s|%s|%d|%d|%s" % [str(list), str(clashes), str(loose_ends), hovered, grabbed, faint]
	if key != _drawn_key:
		_drawn_key = key
		for c in _holo.get_children():
			if c.name.begins_with("Beam_") or c.name.begins_with("End_"):
				_holo.remove_child(c)
				c.queue_free()
		var meshes := {}
		for b: Dictionary in list:
			var id := int(b.id)
			var l := ((b.b as Vector3) - (b.a as Vector3)).length()
			var mk := "%s/%.3f" % [b.section, l]
			if not meshes.has(mk):
				meshes[mk] = TradesBeamSections.mesh(str(b.section), l)
			var mi := MeshInstance3D.new()
			mi.name = "Beam_%d" % id
			mi.mesh = meshes[mk]
			mi.transform = beam_xform(b)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.material_override = _mats.red if clashes.has(id) else (_mats.lit if id == hovered or id == grabbed
					else (_mats.faint if faint else _mats.blue))
			_holo.add_child(mi)
		for le: Array in loose_ends:
			var b := {}
			for o: Dictionary in list:
				if int(o.id) == int(le[0]):
					b = o
			if b.is_empty():
				continue
			var dot := MeshInstance3D.new()
			dot.name = "End_%d_%d" % [le[0], le[1]]
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			dot.mesh = sm
			dot.material_override = _mats.amber
			dot.position = b.a if int(le[1]) == 0 else b.b
			_holo.add_child(dot)
	# The beam being drawn, the snap point and the length.
	_marker.visible = holding() and aim_point.is_finite()
	if _marker.visible:
		_marker.position = aim_point
		_marker.material_override = _mats.lit if snapped_to != "end" else _mats.amber
	_ghost.visible = holding() and start.is_finite() and aim_point.is_finite() and start.distance_to(aim_point) > 0.01
	_length_label.visible = _ghost.visible or grabbed >= 0
	if _ghost.visible:
		var g := {"a": start, "b": aim_point, "section": section, "turn": 0.0}
		var l := start.distance_to(aim_point)
		var gk := "%s/%.3f" % [section, l]
		if _ghost.get_meta("key", "") != gk:
			_ghost.set_meta("key", gk)
			_ghost.mesh = TradesBeamSections.mesh(section, l)
		_ghost.transform = beam_xform(g)
		_length_label.position = (start + aim_point) * 0.5 + Vector3.UP * 0.15
		_length_label.text = "%d mm" % roundi(l * 1000.0)
	elif grabbed >= 0:
		var b := beam(grabbed)
		if not b.is_empty():
			_length_label.position = ((b.a as Vector3) + (b.b as Vector3)) * 0.5 + Vector3.UP * 0.15
			_length_label.text = "%d mm" % roundi(((b.b as Vector3) - (b.a as Vector3)).length() * 1000.0)
	_info()


func _anyone_holding() -> bool:
	return holding()


## The right-hand panel while the tablet is in hand.
func info_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var t := totals()
	var n := beams().size()
	out.append("Next beam  %s" % TradesBeamSections.name_of(section))
	out.append("Design  %d beams, %.1f m, %d kg" % [n, t.x, roundi(t.y)])
	if not clashes.is_empty():
		out.append("Clashes  %d beams (red)" % clashes.size())
	if not loose_ends.is_empty():
		out.append("Loose ends  %d (amber): nothing holds them" % loose_ends.size())
	var id := grabbed if grabbed >= 0 else hovered
	if id >= 0:
		var b := beam(id)
		if not b.is_empty():
			out.append("This beam  %s, %d mm" % [TradesBeamSections.name_of(str(b.section)),
					roundi(((b.b as Vector3) - (b.a as Vector3)).length() * 1000.0)])
	out.append(doing())
	return out


## What the tablet is doing, in a few words with its keys.
func doing() -> String:
	if grabbed >= 0:
		return "Moving: click to set it down, Q/E turn, right click cancel"
	if start.is_finite():
		return "Drawing: click the far end, wheel for the section, right click cancel"
	if hovered >= 0:
		return "Click to move, right click delete, G copy, Q/E turn, wheel section"
	return "Click to start a beam, X undo"


func _info() -> void:
	var tab := bay.call("tool_node", &"tablet") as TradesDesignTablet if bay and bay.has_method("tool_node") else null
	if tab:
		tab.section = TradesBeamSections.name_of(section)
		tab.count = beams().size()
		tab.doing = "moving" if grabbed >= 0 else ("drawing" if start.is_finite() else ("on a beam" if hovered >= 0 else "ready"))
	if not holding():
		if _shown != "":
			_shown = ""
			HudSlots.clear_info(INFO)
		return
	var text := "\n".join(info_lines())
	if text != _shown:
		_shown = text
		HudSlots.set_info(INFO, "Beam design", text, 9)


func _play(sound: StringName) -> void:
	if bay and bay.has_method("play"):
		bay.call("play", sound)


func _say(text: String) -> void:
	if bay and bay.has_method("hint"):
		bay.call("hint", text)


# --- Shared with the crew -------------------------------------------------------------------

func _ask(p: Dictionary) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", EVENT, p)
		return
	var v: Variant = _validate(1, p)
	if v is Dictionary:
		_apply(v)


func _validate(_sender: int, p: Dictionary) -> Variant:
	var rows: Variant = p.get("rows")
	if not rows is Array or (rows as Array).size() > MAX_BEAMS:
		return "bad design"
	for r: Variant in rows:
		if not r is Dictionary or not (r as Dictionary).get("a") is Array or not (r as Dictionary).get("b") is Array:
			return "bad beam"
		var d := r as Dictionary
		if (d.a as Array).size() != 3 or (d.b as Array).size() != 3:
			return "bad beam"
		var l := _v(d.a).distance_to(_v(d.b))
		if not is_finite(l) or l < MIN_M * 0.5 or l > MAX_M:
			return "bad length"
		if not TradesBeamSections.has(str(d.get("section", ""))):
			return "bad section"
	return {"ship": str(p.get("ship", "")), "rows": rows}


func _apply(p: Dictionary) -> void:
	var bus := Modules.bus("trades") as TradesBus
	if bus:
		bus.set_beam_design(str(p.ship), p.rows)


func get_net_snapshot() -> Dictionary:
	var bus := Modules.bus("trades") as TradesBus
	return {"designs": bus.save_data().get("beam_designs", {}) if bus else {}}


func apply_net_snapshot(data: Dictionary) -> void:
	var bus := Modules.bus("trades") as TradesBus
	var designs: Variant = data.get("designs", {})
	if bus and designs is Dictionary:
		for ship: Variant in designs:
			bus.set_beam_design(str(ship), designs[ship])
