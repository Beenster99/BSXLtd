extends Node3D
## A mobile scaffold rig, after the inspiration shot's wheeled towers: a galvanised tube frame
## on castors, `bays` bays long (2.5 m each, along its z) and `lifts` lifts high (2 m each),
## a grating deck at every lift, guard rails on its outboard (-X) side and on any closed end,
## its +X side open as the work face (drive it up to a hull). A ladder climbs the outboard
## side of the first bay; climb past the top and you step onto the top deck. Two rigs with
## their facing ends open, the same height and driven end to end make one long floor.
##
## Its control post on the outboard side: a touch screen with BAY + / BAY -, LIFT + / LIFT -,
## ENDS (cycles which ends are open), and a push handle (F: bay_access pushes it). A change
## that would grow it into something is refused. Built and rebuilt by `configure`; the frame
## is one AnimatableBody3D (`body`), the ladder an Area3D the walker climbs in.

## Asks the kit to apply a change to this rig (the kit sends it to every peer).
signal change_requested(bays: int, lifts: int, ends: int)
## F on the handle.
signal drive_requested

const WIDTH := 1.6        # across (x), metres
const BAY := 2.5          # one bay along (z), metres
const LIFT := 2.0         # one lift, deck to deck, metres
const BASE := 0.35        # the base frame's top over the floor (castors under it), metres
const RAIL := 1.0         # guard rail height over a deck, metres
const MAX_BAYS := 4
const MAX_LIFTS := 4
const CLEAR := 0.06
## Ladder: along z in the first bay, its climbing space outboard of the frame.
const LADDER_Z := 0.9
const LADDER_W := 0.5
## ENDS: 0 both closed, 1 the -Z end open, 2 the +Z end open, 3 both open.
const Touch := preload("res://modules/ship_bay/internal/kit/touch_screen.gd")
const T := preload("res://modules/ui/api/terminal_kit.gd")
const END_NAMES := ["BOTH ENDS RAILED", "FRONT END OPEN", "BACK END OPEN", "BOTH ENDS OPEN"]

var bays := 2
var lifts := 2
var ends := 0
var label := "1"
## The post's touch screen (rebuilt with the rig).
var post_screen: Node3D
var body: AnimatableBody3D
var ladder: Area3D
var _look: Node3D
var _mats: Dictionary = {}


func _ready() -> void:
	body = AnimatableBody3D.new()
	body.name = "Frame"
	body.sync_to_physics = false
	body.set_meta("surface", "grating")
	add_child(body)
	ladder = Area3D.new()
	ladder.name = "Ladder"
	ladder.monitorable = false
	add_child(ladder)
	ladder.body_entered.connect(_on_ladder.bind(1))
	ladder.body_exited.connect(_on_ladder.bind(-1))
	_mats = {
		"galv": ShipSurface.of(ShipKit.paint(Color(0.62, 0.64, 0.66), 0.7, 0.42, "galvanised")),
		"deck": ShipSurface.of(ShipKit.paint(Color(0.42, 0.44, 0.46), 0.8, 0.45)),
		"toe": ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint")),
		"dark": ShipSurface.of(ShipKit.paint(Color(0.15, 0.16, 0.18), 0.5, 0.5, "gunmetal")),
		"rubber": ShipSurface.of(ShipKit.paint(Color(0.07, 0.07, 0.075), 0.0, 0.9, "rubber")),
	}
	_build()


## The rig's length along z and its top deck's height, metres.
func length() -> float:
	return BAY * float(bays)


func top() -> float:
	return BASE + LIFT * float(lifts)


## Deck heights, lowest first.
func decks() -> Array[float]:
	var out: Array[float] = []
	for l in range(1, lifts + 1):
		out.append(BASE + LIFT * float(l))
	return out


func end_open(which: int) -> bool:
	return (ends & (1 << which)) != 0


## Applies a change (every peer, from the kit). Growing it into something is refused (the
## kit checks with `fits` first on the asking peer).
func configure(p_bays: int, p_lifts: int, p_ends: int) -> void:
	bays = clampi(p_bays, 1, MAX_BAYS)
	lifts = clampi(p_lifts, 1, MAX_LIFTS)
	ends = posmod(p_ends, 4)
	_build()


## Whether the rig at `p_bays` x `p_lifts` would stand clear of everything but itself and
## people (it grows towards +Z and up).
func fits(p_bays: int, p_lifts: int) -> bool:
	var size := Vector3(WIDTH, BASE + LIFT * float(p_lifts) + RAIL - CLEAR, BAY * float(p_bays))
	var shape := BoxShape3D.new()
	shape.size = size - Vector3(0.06, 0.06, 0.06)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = global_transform * Transform3D(Basis(), Vector3(0, CLEAR + size.y * 0.5, size.z * 0.5))
	q.exclude = [body.get_rid()]
	q.collide_with_areas = false
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 16):
		if not (hit.collider is CharacterBody3D):
			return false
	return true


# --- Control post ---------------------------------------------------------------------------

func add_bay() -> void:
	_ask(bays + 1, lifts, ends)


func remove_bay() -> void:
	_ask(bays - 1, lifts, ends)


func add_lift() -> void:
	_ask(bays, lifts + 1, ends)


func remove_lift() -> void:
	_ask(bays, lifts - 1, ends)


func cycle_ends() -> void:
	_ask(bays, lifts, ends + 1)


func _ask(b: int, l: int, e: int) -> void:
	b = clampi(b, 1, MAX_BAYS)
	l = clampi(l, 1, MAX_LIFTS)
	if (b > bays or l > lifts) and not fits(b, l):
		Sfx.play("error", self)
		return
	Sfx.play("click", self)
	change_requested.emit(b, l, posmod(e, 4))


# --- Building -------------------------------------------------------------------------------

func _build() -> void:
	if _look:
		_look.free()
	for c: Node in body.get_children():
		c.free()
	for c: Node in ladder.get_children():
		c.free()
	_look = Node3D.new()
	_look.name = "Look"
	body.add_child(_look)
	var w := WIDTH
	var l := length()
	var t := top()
	var hx := w * 0.5
	var galv: Material = _mats["galv"]
	# The base frame on castors.
	for x: float in [-hx, hx]:
		_tube(Vector3(x, BASE - 0.05, 0), Vector3(x, BASE - 0.05, l), 0.05, galv)
	for z: float in _stations():
		_tube(Vector3(-hx, BASE - 0.05, z), Vector3(hx, BASE - 0.05, z), 0.05, galv)
		for x: float in [-hx, hx]:
			_mesh(PartShapes.box(Vector3(0.12, 0.06, 0.12)).mesh, Transform3D(Basis(), Vector3(x, BASE - 0.13, z)), _mats["dark"])
			_mesh(PartShapes.prism(14, 0.1, 0.07).mesh, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.1, z)), _mats["rubber"])
	_collide(Vector3(w, 0.1, l), Vector3(0, BASE - 0.05, l * 0.5))
	# Uprights at every station both sides, up to the top rail.
	for z: float in _stations():
		for x: float in [-hx, hx]:
			_tube(Vector3(x, BASE, z), Vector3(x, t + RAIL, z), 0.024, galv)
			_collide(Vector3(0.05, t + RAIL - BASE, 0.05), Vector3(x, (BASE + t + RAIL) * 0.5, z))
	# Decks, ledgers, braces and rails at every lift.
	for y: float in decks():
		var is_top := is_equal_approx(y, t)
		for i in bays:
			var z0 := BAY * float(i)
			_mesh(WreckParts.grating(w - 0.04, BAY - 0.04).mesh, Transform3D(Basis(), Vector3(0, y - 0.03, z0 + BAY * 0.5)), _mats["deck"])
			# Outboard braces up to this deck (one diagonal per bay and lift).
			_tube(Vector3(-hx, y - LIFT + 0.05, z0 + 0.05), Vector3(-hx, y - 0.05, z0 + BAY - 0.05), 0.018, galv)
		_collide(Vector3(w, 0.06, l), Vector3(0, y - 0.03, l * 0.5))
		for x: float in [-hx, hx]:
			_tube(Vector3(x, y - 0.06, 0), Vector3(x, y - 0.06, l), 0.024, galv)
		# Toe boards round the deck (the work face too); rails outboard and on closed ends.
		for side: Array in [[Vector3(-hx, y + 0.07, l * 0.5), Vector3(0.02, 0.14, l)], [Vector3(hx, y + 0.07, l * 0.5), Vector3(0.02, 0.14, l)],
				[Vector3(0, y + 0.07, 0), Vector3(w, 0.14, 0.02)], [Vector3(0, y + 0.07, l), Vector3(w, 0.14, 0.02)]]:
			_mesh(PartShapes.box(side[1]).mesh, Transform3D(Basis(), side[0]), _mats["toe"])
		for k: float in [RAIL * 0.5, RAIL]:
			if is_top:
				# A gap in the top's outboard rail where the ladder comes up.
				_tube(Vector3(-hx, y + k, 0), Vector3(-hx, y + k, LADDER_Z - LADDER_W * 0.5 - 0.1), 0.02, galv)
				_tube(Vector3(-hx, y + k, LADDER_Z + LADDER_W * 0.5 + 0.1), Vector3(-hx, y + k, l), 0.02, galv)
			else:
				_tube(Vector3(-hx, y + k, 0), Vector3(-hx, y + k, l), 0.02, galv)
			for e in 2:
				if not end_open(e):
					var z := 0.0 if e == 0 else l
					_tube(Vector3(-hx, y + k, z), Vector3(hx, y + k, z), 0.02, galv)
		if is_top:
			var gap0 := LADDER_Z - LADDER_W * 0.5 - 0.1
			var gap1 := LADDER_Z + LADDER_W * 0.5 + 0.1
			_collide(Vector3(0.05, RAIL, gap0), Vector3(-hx, y + RAIL * 0.5, gap0 * 0.5))
			_collide(Vector3(0.05, RAIL, l - gap1), Vector3(-hx, y + RAIL * 0.5, (gap1 + l) * 0.5))
		else:
			_collide(Vector3(0.05, RAIL, l), Vector3(-hx, y + RAIL * 0.5, l * 0.5))
		for e in 2:
			if not end_open(e):
				_collide(Vector3(w, RAIL, 0.05), Vector3(0, y + RAIL * 0.5, 0.0 if e == 0 else l))
	# The ladder up the outboard side of the first bay: stiles, rungs, a backboard that stops
	# you walking in under the decks, and the climbing space outside it.
	for dz: float in [-LADDER_W * 0.5, LADDER_W * 0.5]:
		_tube(Vector3(-hx - 0.1, 0.05, LADDER_Z + dz), Vector3(-hx - 0.1, t + RAIL, LADDER_Z + dz), 0.02, _mats["toe"])
	var y := 0.3
	while y < t + 0.1:
		_tube(Vector3(-hx - 0.1, y, LADDER_Z - LADDER_W * 0.5), Vector3(-hx - 0.1, y, LADDER_Z + LADDER_W * 0.5), 0.016, galv)
		y += 0.3
	_collide(Vector3(0.04, t - 0.1, LADDER_W + 0.2), Vector3(-hx - 0.02, 0.05 + (t - 0.1) * 0.5, LADDER_Z))
	var space := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.65, t + 0.1, LADDER_W + 0.1)
	space.shape = box
	space.position = Vector3(-hx - 0.33, (t + 0.1) * 0.5, LADDER_Z)
	ladder.add_child(space)
	_build_post()


## The control post on the outboard side by the far end (clear of both ends, so rigs can
## join end to end): a touch screen with BAY + / BAY -, LIFT + / LIFT - and ENDS, and a push
## handle (F on the post takes the rig to push).
func _build_post() -> void:
	var at := Vector3(-WIDTH * 0.5 - 0.25, 0, length() - 0.5)
	_tube(at + Vector3(0, BASE, 0), at + Vector3(0, 1.1, 0), 0.03, _mats["dark"])
	_tube(at + Vector3(0, BASE - 0.05, 0), at + Vector3(0.25, BASE - 0.05, 0.2), 0.03, _mats["dark"])
	_tube(at + Vector3(0, 1.0, -0.22), at + Vector3(0, 1.0, 0.22), 0.025, _mats["rubber"])
	var grip := _collide_xf(Vector3(0.16, 0.9, 0.5), Transform3D(Basis(), at + Vector3(0, 0.75, 0)))
	grip.name = "PushHandle"
	grip.set_meta("ship_bay_use", func() -> void: drive_requested.emit())
	var panel := Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, -0.3), at + Vector3(-0.03, 1.3, 0))
	_mesh(PartShapes.chamfer_box(Vector3(0.38, 0.3, 0.05), 0.02).mesh, panel * Transform3D(Basis(), Vector3(0, 0, -0.035)), _mats["dark"])
	var screen: Node3D = Touch.new()
	screen.name = "Screen"
	screen.transform = panel
	_look.add_child(screen)
	screen.call("setup", Vector2(0.34, 0.26), "SCAFFOLD %s" % label, 2)
	screen.call("set_status", "%d × %d" % [bays, lifts], T.GOOD)
	for b: Array in [["bay_up", "BAY +", add_bay], ["bay_down", "BAY −", remove_bay],
			["lift_up", "LIFT +", add_lift], ["lift_down", "LIFT −", remove_lift]]:
		screen.call("add_button", b[0], b[1], b[2])
	screen.call("add_button", "ends", END_NAMES[ends], cycle_ends, true)
	(screen.get("buttons")["ends"] as Button).add_theme_font_size_override("font_size", 17)
	post_screen = screen


func _stations() -> Array[float]:
	var out: Array[float] = []
	for i in bays + 1:
		out.append(BAY * float(i))
	return out


func _on_ladder(who: Node3D, way: int) -> void:
	if who is CharacterBody3D and who.has_method("set_ladder"):
		# Climbed out of the top: step onto the top deck by the ladder.
		var on_top := way < 0 and to_local(who.global_position).y > top() - 0.05
		var deck := to_global(Vector3(-WIDTH * 0.5 + 0.45, top() + 0.02, LADDER_Z))
		who.call("set_ladder", way, deck if on_top else Vector3.INF)


func _tube(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	var y := d.normalized()
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var basis := Basis(x, y, x.cross(y))
	_mesh(PartShapes.prism(8, r, d.length()).mesh, Transform3D(basis, (a + b) * 0.5), mat)


func _mesh(mesh: Mesh, xform: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xform
	_look.add_child(mi)
	return mi


func _collide(size: Vector3, at: Vector3) -> CollisionShape3D:
	return _collide_xf(size, Transform3D(Basis(), at))


func _collide_xf(size: Vector3, xform: Transform3D) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.transform = xform
	body.add_child(col)
	return col


func _sign(text: String, xform: Transform3D, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = ShipKit.mono_font()
	l.font_size = size
	l.pixel_size = 0.0018
	l.modulate = Color(1.0, 0.85, 0.5)
	l.outline_size = 0
	l.transform = xform
	_look.add_child(l)
	return l
