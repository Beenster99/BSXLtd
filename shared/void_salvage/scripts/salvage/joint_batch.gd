class_name JointBatch
extends Node3D
## Draws a structure's small repeated details (rivet and bolt heads, weld beads, loom plugs,
## sheared stubs, weld scars) in batches: one MultiMesh per distinct mesh and material,
## instead of one node and one draw call per joint. A big wreck has nearly 3,000 joints,
## so this turns ~3,000 objects into a few dozen.
##
## Presentation only. Each thing drawn is an Item: its mesh, material, transform in the
## structure's space and a custom colour (x = heat). Items can be updated, removed, or moved
## to another structure's batch when parts split off. Sits at the structure's origin.

## One drawn thing. Keep the reference to update or remove it.
class Item:
	extends RefCounted
	var mesh: Mesh
	var material: Material
	## In the owning structure's space.
	var xform := Transform3D.IDENTITY
	## x = heat (0 cold .. 1 glowing).
	var custom := Color(0.0, 0.0, 0.0, 0.0)
	var bucket: Bucket
	var index: int = -1

	func _init(p_mesh: Mesh, p_material: Material, p_xform: Transform3D) -> void:
		mesh = p_mesh
		material = p_material
		xform = p_xform


## Everything drawn with one mesh and one material.
class Bucket:
	extends RefCounted
	var node: MultiMeshInstance3D
	var multimesh: MultiMesh
	## Slots handed out so far (some may be free again).
	var count: int = 0
	var free: Array[int] = []


const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

## [mesh, material] -> Bucket
var _buckets: Dictionary = {}


func _ready() -> void:
	name = "JointBatch"


## Starts drawing `item`.
func add(item: Item) -> void:
	var key := [item.mesh, item.material]
	var b: Bucket = _buckets.get(key)
	if b == null:
		b = _make_bucket(item.mesh, item.material)
		_buckets[key] = b
	var i: int
	if not b.free.is_empty():
		i = b.free.pop_back()
	else:
		i = b.count
		b.count += 1
		if b.count > b.multimesh.instance_count:
			_grow(b)
	item.bucket = b
	item.index = i
	b.multimesh.set_instance_transform(i, item.xform)
	b.multimesh.set_instance_custom_data(i, item.custom)
	b.multimesh.visible_instance_count = b.count


## Stops drawing `item` (it can be added again, here or elsewhere).
func remove(item: Item) -> void:
	var b := item.bucket
	if b == null or item.index < 0:
		return
	b.multimesh.set_instance_transform(item.index, HIDDEN)
	b.free.append(item.index)
	item.bucket = null
	item.index = -1


## Pushes a changed transform or heat to the GPU.
func update(item: Item) -> void:
	if item.bucket == null:
		return
	item.bucket.multimesh.set_instance_transform(item.index, item.xform)
	item.bucket.multimesh.set_instance_custom_data(item.index, item.custom)


## Hands `item` over to another structure's batch (its transform stays: a piece that splits
## off starts with the same transform as the structure it came from).
func move(item: Item, to: JointBatch) -> void:
	remove(item)
	to.add(item)


## Swaps an item's mesh (a weld bead ground down a level).
func change_mesh(item: Item, mesh: Mesh) -> void:
	remove(item)
	item.mesh = mesh
	add(item)


## How many draw calls this batch costs (for the performance readout).
func bucket_count() -> int:
	return _buckets.size()


func _make_bucket(mesh: Mesh, material: Material) -> Bucket:
	var b := Bucket.new()
	b.multimesh = MultiMesh.new()
	b.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	b.multimesh.use_custom_data = true
	b.multimesh.mesh = mesh
	b.multimesh.instance_count = 16
	b.multimesh.visible_instance_count = 0
	b.node = MultiMeshInstance3D.new()
	b.node.name = "Batch_%d" % _buckets.size()
	b.node.multimesh = b.multimesh
	b.node.material_override = material
	b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(b.node)
	return b


## Doubles a bucket's room, keeping what it holds (setting instance_count clears the data).
func _grow(b: Bucket) -> void:
	var mm := b.multimesh
	var kept := mm.buffer
	# 12 floats of transform and 4 of custom data per instance.
	const STRIDE := 16
	var was := mm.instance_count
	mm.instance_count = maxi(was * 2, 16)
	# Unused slots are never drawn (visible_instance_count), so the padding can stay zero.
	# (Headless runs have no buffer to keep.)
	if kept.size() == was * STRIDE:
		kept.resize(STRIDE * mm.instance_count)
		mm.buffer = kept
