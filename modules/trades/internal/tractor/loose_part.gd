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


## Builds the part from its slot: Ship and Bay's copy of the model pieces when it offers one,
## otherwise a plain painted box of the slot's outline.
func setup(slot: MountSlot, comp: String, visual: Node3D) -> void:
	slot_id = slot.slot_id
	component = comp
	name = "Loose_" + slot.slot_id
	# Graphics lights it under the pointer, and crewmates' pings find it by its id.
	add_to_group("gfx_interactable")
	set_meta("gfx_id", "trades.loose:" + slot.slot_id)
	outline = slot.mount.affine_inverse() * slot.box
	mass = maxf(5.0, outline.size.x * outline.size.y * outline.size.z * DENSITY)
	contact_monitor = true
	max_contacts_reported = 6
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = outline.size
	_shape.shape = box
	_shape.position = outline.get_center()
	add_child(_shape)
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
	held = true
	anchored = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


## Let go: physics has it again and it drops, moving at `velocity` (a throw).
func drop(velocity := Vector3.ZERO) -> void:
	held = false
	anchored = false
	freeze = false
	sleeping = false
	linear_velocity = velocity
	_last_velocity = velocity


func _physics_process(delta: float) -> void:
	_free_players()
	if freeze:
		_last_velocity = Vector3.ZERO
		return
	knock((_last_velocity - linear_velocity).length())
	_last_velocity = linear_velocity
	if Flags.is_on("trades.no_pinning"):
		_off_players(delta)


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
	knocked.emit(self)


## Where the aim line from `from` along `dir` first meets its outline, or null.
func hit(from: Vector3, dir: Vector3) -> Variant:
	var inv := global_transform.affine_inverse()
	var local: Variant = outline.intersects_ray(inv * from, inv.basis * dir)
	return global_transform * (local as Vector3) if local != null else null
