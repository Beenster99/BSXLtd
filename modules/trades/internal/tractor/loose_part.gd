class_name TradesLoosePart
extends RigidBody3D
## A part that has come off its mount slot (every joint holding it taken off): it sits where
## it was until the tractor beam lifts it, falls when the beam lets go away from its mount,
## and goes back into the slot (ShipBayBus.try_position) when the beam lets go of it in line
## with the mount. Its origin is the slot's mounting face (MountSlot.mount), so in line
## means its transform matches the mount's.

## Kilograms per cubic metre of the part's box: machinery is mostly air inside its outline.
const DENSITY := 320.0

var slot_id := ""
var component := ""
## The part's outline in its own space (the slot's box seen from its mount).
var outline := AABB()
## Held by a beam (it follows the beam, not physics), or left hovering by one.
var held := false
var anchored := false
## Back in its slot while a beam (or a locked hold) keeps it there until its first joint is
## in: the ship shows the part, so this copy hides and stops colliding.
var seated := false

## How good it still is (0..1): Ship and Bay's fitted condition when it came off, knocked down
## by hard landings (ship_bay.clean_up). Their clean-up trolleys sort parts by it.
var condition := 1.0

## Landings harder than this (m/s of speed lost in a step) knock the condition down, by
## KNOCK_PER_MS for each m/s over it.
const KNOCK_MS := 4.0
const KNOCK_PER_MS := 0.04

## A part that lands on someone is pushed off them (N per kg, sideways), and if it still lies
## on them after PIN_S it drops through them to the floor (beenster, 0.3.16: "roof unit fell on
## me and I can't move"); it collides with them again once FREE_M clear (trades.no_pinning).
const SHOVE_N_PER_KG := 12.0
const PIN_S := 0.5
const FREE_M := 0.6

var _shape: CollisionShape3D
var _last_velocity := Vector3.ZERO
## Players it's touching: body -> seconds on them; and those it now passes through.
var _on := {}
var _through: Array[PhysicsBody3D] = []

## It hit something hard and lost condition.
signal knocked(part: TradesLoosePart)
## On its way to a trolley's deck (trades.parts_on_decks), it has come to rest: on `deck` (the
## trolley's "Deck" body, under it or under the parts it lies on), or on something else (null).
signal settled(part: TradesLoosePart, deck: Node3D)

## trades.part_landing (beenster, 26 Oct: "objects ... seem to hover slightly above ground.
## These same objects should stack on top of each other", and "should clang like in real life").
## Its collision is the hull of its own look, not the slot's box (a tilted plate's box is far
## thicker than the plate, so it lay on the box's face, in the air), and a landing clangs.
## A hit losing more than this much speed clangs (m/s); one this hard plays at CLANG_FULL_DB.
const CLANG_MS := 0.7
const CLANG_FULL_MS := 5.0
const CLANG_FULL_DB := 0.0
const CLANG_QUIET_DB := -26.0
## No new clang within this long of the last (seconds): contacts chatter as it settles.
const CLANG_GAP_S := 0.14
## Most points the hull is built from (a dense look is thinned to about this many).
const HULL_POINTS := 2400
## Grip and give of its surface: high friction and next to no bounce, so stacks hold.
const FRICTION := 0.9
const BOUNCE := 0.05

## Riding on a trolley's deck: frozen, carried with `riding` at `_ride` in its space.
var riding: Node3D
var _ride := Transform3D.IDENTITY
## Seconds it has been still while waiting to settle on a deck (-1: not waiting).
var _still_s := -1.0
var _clang_s := 0.0
## The last clang (seconds since start, speed lost, dB, pitch), for tests.
var last_clang: Array = []
## The players it made (tests count them).
var clangs := 0
## How far it sits still before it counts as settled (m/s, rad/s, seconds).
const SETTLE_MS := 0.06
const SETTLE_RAD := 0.12
const SETTLE_S := 0.35
## Lying on a deck this long, it rides even if not quite still (seconds).
const DECK_HOLD_S := 0.5
var _on_deck_s := 0.0


## Builds the part from its slot: Ship and Bay's copy of the model pieces when it offers one,
## otherwise a plain painted box of the slot's outline.
func setup(slot: MountSlot, comp: String, visual: Node3D) -> void:
	_build(slot.slot_id, comp, slot.mount.affine_inverse() * slot.box, visual)
	name = "Loose_" + slot.slot_id


## Builds goods taken off a trolley (no slot on the ship): `id` stands in for a slot id
## ("stock:<crate>"), `box` is their outline in their own space, `visual` their look.
func setup_goods(id: String, comp: String, box: AABB, visual: Node3D, cond: float) -> void:
	_build(id, comp, box, visual)
	name = "Goods_" + id.validate_node_name()
	condition = clampf(cond, 0.0, 1.0)
	set_meta("condition", condition)


func _build(id: String, comp: String, shape_box: AABB, visual: Node3D) -> void:
	slot_id = id
	component = comp
	# Graphics lights it under the pointer, and crewmates' pings find it by its id.
	add_to_group("gfx_interactable")
	set_meta("gfx_id", "trades.loose:" + id)
	set_meta("component", comp)
	outline = shape_box
	mass = maxf(5.0, outline.size.x * outline.size.y * outline.size.z * DENSITY)
	contact_monitor = true
	max_contacts_reported = 6
	_shape = CollisionShape3D.new()
	var hull := _hull_of(visual) if visual and Flags.is_on("trades.part_landing") else null
	if hull:
		_shape.shape = hull
	else:
		var box := BoxShape3D.new()
		box.size = outline.size
		_shape.shape = box
		_shape.position = outline.get_center()
	add_child(_shape)
	if Flags.is_on("trades.part_landing"):
		physics_material_override = PhysicsMaterial.new()
		physics_material_override.friction = FRICTION
		physics_material_override.bounce = BOUNCE
		angular_damp = 0.6
	if visual:
		add_child(visual)
	else:
		var mesh := BoxMesh.new()
		mesh.size = outline.size
		mesh.material = TradesLook.paint(TradesLook.SHELL.darkened(0.15), 0.35, 0.45)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = outline.get_center()
		add_child(mi)
	# Sits on its mount until something moves it.
	anchor()


## A convex hull round every mesh of the part's look, in its own space; null for none.
static func _hull_of(visual: Node3D) -> ConvexPolygonShape3D:
	var points := PackedVector3Array()
	for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != visual:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		for i in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in verts:
				points.append(t * v)
	if points.size() < 4:
		return null
	if points.size() > HULL_POINTS:
		# Keep the extremes and an even sample: the hull only needs the outermost.
		var thin := PackedVector3Array()
		var step := float(points.size()) / HULL_POINTS
		var i := 0.0
		while int(i) < points.size():
			thin.append(points[int(i)])
			i += step
		for axis in 3:
			var lo := 0
			var hi := 0
			for k in points.size():
				if points[k][axis] < points[lo][axis]:
					lo = k
				if points[k][axis] > points[hi][axis]:
					hi = k
			thin.append(points[lo])
			thin.append(points[hi])
		points = thin
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


## Its lowest point below its origin when turned as it is now (m, positive downward).
func depth_below() -> float:
	var lowest := INF
	var b := global_transform.basis
	var hull := _shape.shape as ConvexPolygonShape3D
	if hull:
		for p in hull.points:
			lowest = minf(lowest, (b * p).y)
	else:
		for k in 8:
			lowest = minf(lowest, (b * outline.get_endpoint(k)).y)
	return -lowest


func set_seated(on: bool) -> void:
	seated = on
	visible = not on
	_shape.disabled = on


## Where the beam takes hold of it, world space.
func centre() -> Vector3:
	return global_transform * outline.get_center()


## Hovering where it is (left on its mount, or parked by the beam).
func anchor() -> void:
	held = false
	anchored = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


func take_hold() -> void:
	riding = null
	_still_s = -1.0
	held = true
	anchored = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


## Let go: physics has it again and it drops, moving at `velocity` (a throw).
func drop(velocity := Vector3.ZERO) -> void:
	riding = null
	held = false
	anchored = false
	freeze = false
	sleeping = false
	linear_velocity = velocity
	_last_velocity = velocity


func _physics_process(delta: float) -> void:
	_free_players()
	_clang_s += delta
	if riding:
		if is_instance_valid(riding) and riding.is_inside_tree():
			global_transform = riding.global_transform * _ride
		else:
			drop()
		return
	if freeze:
		_last_velocity = Vector3.ZERO
		return
	var lost := (_last_velocity - linear_velocity).length()
	knock(lost)
	if Flags.is_on("trades.part_landing"):
		clang(lost)
	_last_velocity = linear_velocity
	if _still_s >= 0.0:
		_wait_to_settle(delta)
	if Flags.is_on("trades.no_pinning"):
		_off_players(delta)


# --- Landing and riding a deck (trades.part_landing, trades.parts_on_decks) -------------------

## A hit that took `speed_lost` m/s off it: hard enough, a metal clang, louder for a harder hit
## and a heavier part, lower for a heavier one.
func clang(speed_lost: float) -> void:
	if speed_lost < CLANG_MS or _clang_s < CLANG_GAP_S or not is_inside_tree():
		return
	_clang_s = 0.0
	var hard := clampf((speed_lost - CLANG_MS) / (CLANG_FULL_MS - CLANG_MS), 0.0, 1.0)
	var heavy := clampf(log(mass / 5.0) / log(100.0), 0.0, 1.0)
	var db := lerpf(CLANG_QUIET_DB, CLANG_FULL_DB, sqrt(hard)) + heavy * 4.0
	var pitch := lerpf(1.35, 0.6, heavy) * randf_range(0.94, 1.06)
	var p := AudioStreamPlayer3D.new()
	p.stream = TradesSounds.clang(heavy, hard)
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	p.max_distance = 50.0
	p.bus = Sfx.bus()
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = centre()
	p.play()
	clangs += 1
	last_clang = [speed_lost, db, pitch]


## Put on a deck: from now on, once it has sat still a moment it says what it rests on.
func wait_to_settle() -> void:
	_still_s = 0.0
	_on_deck_s = 0.0


func _wait_to_settle(delta: float) -> void:
	# On a deck already, it rides once it has lain there a moment even if the trolley is moving
	# under it (the deck drags it, so it is never quite still).
	var deck := resting_deck()
	_on_deck_s = _on_deck_s + delta if deck else 0.0
	if deck and _on_deck_s >= DECK_HOLD_S and angular_velocity.length() < 1.0:
		_still_s = -1.0
		settled.emit(self, deck)
		return
	if linear_velocity.length() > SETTLE_MS or angular_velocity.length() > SETTLE_RAD:
		_still_s = 0.0
		return
	_still_s += delta
	if _still_s < SETTLE_S:
		return
	_still_s = -1.0
	settled.emit(self, deck)


## The trolley deck it lies on, directly or through the parts under it; null for none.
func resting_deck() -> Node3D:
	for b: Node in get_colliding_bodies():
		if b.name == &"Deck" and b is AnimatableBody3D:
			return b as Node3D
		if b is TradesLoosePart and (b as TradesLoosePart).riding:
			return (b as TradesLoosePart).riding
	return null


## Frozen where it lies, carried with `deck` from now on (parts dropped later stack on it).
func ride(deck: Node3D) -> void:
	_still_s = -1.0
	riding = deck
	_ride = deck.global_transform.affine_inverse() * global_transform
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## Pushes itself off anyone it lies on, and lets them through if that doesn't do it.
func _off_players(delta: float) -> void:
	var touching := {}
	for b: Node in get_colliding_bodies():
		if b is CharacterBody3D and not _through.has(b):
			touching[b] = float(_on.get(b, 0.0)) + delta
	_on = touching
	for b: CharacterBody3D in touching:
		var away := centre() - b.global_position
		away.y = 0.0
		if away.length() < 0.05:
			away = Vector3.RIGHT
		apply_central_force(away.normalized() * mass * SHOVE_N_PER_KG)
		if float(touching[b]) >= PIN_S:
			add_collision_exception_with(b)
			_through.append(b)
			_on.erase(b)
			sleeping = false


## Collides again with those it let through once they're clear of it.
func _free_players() -> void:
	for i in range(_through.size() - 1, -1, -1):
		var b := _through[i]
		if not is_instance_valid(b):
			_through.remove_at(i)
			continue
		var box := global_transform * outline
		if box.grow(FREE_M).has_point(b.global_position) or box.grow(FREE_M).has_point(b.global_position + Vector3.UP):
			continue
		remove_collision_exception_with(b)
		_through.remove_at(i)


## Whether it's passing through someone it fell on (tests).
func lets_through(body: PhysicsBody3D) -> bool:
	return _through.has(body)


## A hit that took `speed_lost` m/s off it: hard enough, the condition drops.
func knock(speed_lost: float) -> void:
	if speed_lost <= KNOCK_MS:
		return
	condition = maxf(0.0, condition - (speed_lost - KNOCK_MS) * KNOCK_PER_MS)
	set_meta("condition", condition)
	knocked.emit(self)


## Where the aim line from `from` along `dir` first meets its outline, or null.
func hit(from: Vector3, dir: Vector3) -> Variant:
	var inv := global_transform.affine_inverse()
	var local: Variant = outline.intersects_ray(inv * from, inv.basis * dir)
	return global_transform * (local as Vector3) if local != null else null
