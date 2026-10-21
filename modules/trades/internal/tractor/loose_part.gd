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

var _shape: CollisionShape3D


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


## Let go: physics has it again and it drops.
func drop() -> void:
	held = false
	anchored = false
	freeze = false
	sleeping = false


## Where the aim line from `from` along `dir` first meets its outline, or null.
func hit(from: Vector3, dir: Vector3) -> Variant:
	var inv := global_transform.affine_inverse()
	var local: Variant = outline.intersects_ray(inv * from, inv.basis * dir)
	return global_transform * (local as Vector3) if local != null else null
