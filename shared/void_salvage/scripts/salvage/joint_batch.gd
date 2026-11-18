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
	## Its own paint (`tinted`): the colour (linear) and, in the alpha, its metal and roughness
	## (`pack_finish`), sent as the instance's colour so things alike but for their paint share
	## one bucket (a head in its plate's paint: JointView.painted_material). Off, the
	## material's own colour.
	var tint := Color(1.0, 1.0, 1.0, 1.0)
	var tinted := false
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
	## Slots in use: always the first `count`, packed (a removed item's slot takes the last one's
	## item), so the GPU draws no hidden heads.
	var count: int = 0
	## The item in each slot.
	var items: Array[Item] = []
	## Its key in `_buckets`.
	var key: Array = []
	## What its items span in the structure's space (and the origin: unused slots sit there),
	## grown as items come and never shrunk.
	var box := AABB()
	## The middle size of the mesh's box (m), and the largest an item's scale makes it.
	var mesh_size: float = 0.0
	var size: float = 0.0
	## The visibility range last set on its node (m; 0 none).
	var range_end: float = -1.0


## [mesh, material, tinted] -> Bucket
var _buckets: Dictionary = {}
## Buckets made so far (names them).
var _made: int = 0

## Every JointBatch in the tree, for a change of `head_range`.
const GROUP := "joint_batches"
## Heads further than this from the camera are not drawn (m; 0 = always): at 60 m a rivet's
## 2 cm head is a third of a pixel at 1440p, and a big wreck carries 8,000 of them. A bucket of
## bigger things (a paint dab, a scar) is kept further in proportion to their size against
## HEAD_SIZE, by the middle side of each so a long thin weld bead counts as thin. The renderer
## measures from the middle of a bucket's box, so its range reaches past by the box's size.
## Set by the game's graphics settings (`set_head_range`).
static var head_range: float = 0.0
## The size (m) that `head_range` is for.
const HEAD_SIZE := 0.03
## A little either way so a head on the line doesn't blink as the camera sways (m).
const RANGE_MARGIN := 2.0


func _ready() -> void:
	name = "JointBatch"
	add_to_group(GROUP)


## Things as fine as heads drawn outside a batch (`fit_fine`: a device's wire lead).
const FINE_GROUP := "fine_detail"
## A fine thing's size (m), kept on it for a refit.
const FINE_META := "fine_size"
## A fine thing's range is rounded up to this (m).
const FINE_STEP := 20.0


## Sets `head_range` and refits every batch and fine thing in `tree`.
static func set_head_range(metres: float, tree: SceneTree) -> void:
	head_range = maxf(metres, 0.0)
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group(GROUP):
		(n as JointBatch).refit_ranges()
	for n: Node in tree.get_nodes_in_group(FINE_GROUP):
		_fit_fine(n as GeometryInstance3D)


## Draws `g`, something `size` m across that is not in a batch (a wire lead: 23,000 triangles
## for 16 m of it), only as far as a head that size (`head_range`), and again when that changes.
static func fit_fine(g: GeometryInstance3D, size: float) -> void:
	g.set_meta(FINE_META, size)
	g.add_to_group(FINE_GROUP)
	_fit_fine(g)


static func _fit_fine(g: GeometryInstance3D) -> void:
	var end := 0.0
	if head_range > 0.0:
		end = head_range * maxf(1.0, float(g.get_meta(FINE_META, HEAD_SIZE)) / HEAD_SIZE) + g.get_aabb().size.length()
		# In steps, so a ship's leads still merge into a few looks (a look's key holds its range).
		end = ceilf(end / FINE_STEP) * FINE_STEP
	g.visibility_range_end = end
	g.visibility_range_end_margin = RANGE_MARGIN if end > 0.0 else 0.0
	g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Sets each bucket's visibility range again from `head_range`.
func refit_ranges() -> void:
	for b: Bucket in _buckets.values():
		b.range_end = -1.0
		_fit_range(b)


## The far end of `b`'s range (m; 0 = no limit).
static func range_of(b: Bucket) -> float:
	if head_range <= 0.0:
		return 0.0
	return head_range * maxf(1.0, b.size / HEAD_SIZE) + b.box.size.length()


func _fit_range(b: Bucket) -> void:
	var end := range_of(b)
	if absf(end - b.range_end) < 0.5 and (end > 0.0) == (b.range_end > 0.0):
		return
	b.range_end = end
	b.node.visibility_range_end = end
	b.node.visibility_range_end_margin = RANGE_MARGIN if end > 0.0 else 0.0
	b.node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Grows `b`'s box and size by `item`.
static func _cover(b: Bucket, item: Item) -> bool:
	var grew := false
	var p := item.xform.origin
	if not b.box.has_point(p):
		b.box = b.box.expand(p)
		grew = true
	var sc := item.xform.basis.get_scale()
	var s := b.mesh_size * maxf(absf(sc.x), maxf(absf(sc.y), absf(sc.z)))
	if s > b.size:
		b.size = s
		grew = true
	return grew


## The middle side of a mesh's box (m).
static func _middle_side(mesh: Mesh) -> float:
	if mesh == null:
		return 0.0
	var e := mesh.get_aabb().size
	var lo := minf(e.x, minf(e.y, e.z))
	var hi := maxf(e.x, maxf(e.y, e.z))
	return e.x + e.y + e.z - lo - hi


## A metal (0..1) and a roughness (0..1) as one number for a tint's alpha: the metal in 31
## steps in its whole part, the roughness in its fraction (the instance's colour is stored as
## half floats: 1/64 fine at the top). The joint shader unpacks it.
static func pack_finish(metallic: float, roughness: float) -> float:
	return floorf(clampf(metallic, 0.0, 1.0) * 31.0 + 0.5) + clampf(roughness, 0.0, 0.97)


## Starts drawing `item`.
func add(item: Item) -> void:
	var key := [item.mesh, item.material, item.tinted]
	var b: Bucket = _buckets.get(key)
	if b == null:
		b = _make_bucket(item.mesh, item.material, item.tinted)
		b.key = key
		b.mesh_size = _middle_side(item.mesh)
		_buckets[key] = b
	var i := b.count
	b.count += 1
	b.items.append(item)
	if b.count > b.multimesh.instance_count:
		_grow(b)
	item.bucket = b
	item.index = i
	b.multimesh.set_instance_transform(i, item.xform)
	b.multimesh.set_instance_custom_data(i, item.custom)
	if item.tinted:
		b.multimesh.set_instance_color(i, item.tint)
	b.multimesh.visible_instance_count = b.count
	if _cover(b, item):
		_fit_range(b)


## Stops drawing `item` (it can be added again, here or elsewhere). The last slot's item moves
## into its slot, so the drawn instances stay packed (a hidden head still cost its triangles: a
## wreck's build leaves thousands, as `_frame_heads` remakes the yard's beads); a bucket left
## empty goes, and its draw call with it.
func remove(item: Item) -> void:
	var b := item.bucket
	if b == null or item.index < 0:
		return
	var last := b.count - 1
	if item.index != last:
		var moved: Item = b.items[last]
		b.items[item.index] = moved
		moved.index = item.index
		b.multimesh.set_instance_transform(moved.index, moved.xform)
		b.multimesh.set_instance_custom_data(moved.index, moved.custom)
		if moved.tinted:
			b.multimesh.set_instance_color(moved.index, moved.tint)
	b.items.pop_back()
	b.count = last
	b.multimesh.visible_instance_count = b.count
	item.bucket = null
	item.index = -1
	if b.count == 0:
		_buckets.erase(b.key)
		remove_child(b.node)
		b.node.queue_free()


## Pushes a changed transform or heat to the GPU.
func update(item: Item) -> void:
	if item.bucket == null:
		return
	item.bucket.multimesh.set_instance_transform(item.index, item.xform)
	item.bucket.multimesh.set_instance_custom_data(item.index, item.custom)
	if head_range > 0.0 and _cover(item.bucket, item):
		_fit_range(item.bucket)


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


func _make_bucket(mesh: Mesh, material: Material, tinted: bool = false) -> Bucket:
	var b := Bucket.new()
	b.multimesh = MultiMesh.new()
	b.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	b.multimesh.use_colors = tinted
	b.multimesh.use_custom_data = true
	b.multimesh.mesh = mesh
	b.multimesh.instance_count = 16
	b.multimesh.visible_instance_count = 0
	b.node = MultiMeshInstance3D.new()
	b.node.name = "Batch_%d" % _made
	_made += 1
	b.node.multimesh = b.multimesh
	b.node.material_override = material
	b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(b.node)
	return b


## Doubles a bucket's room, keeping what it holds (setting instance_count clears the data).
func _grow(b: Bucket) -> void:
	var mm := b.multimesh
	var kept := mm.buffer
	# 12 floats of transform and 4 of custom data per instance, and 4 of colour in a tinted one.
	var STRIDE := 20 if mm.use_colors else 16
	var was := mm.instance_count
	mm.instance_count = maxi(was * 2, 16)
	# Unused slots are never drawn (visible_instance_count), so the padding can stay zero.
	# (Headless runs have no buffer to keep.)
	if kept.size() == was * STRIDE:
		kept.resize(STRIDE * mm.instance_count)
		mm.buffer = kept
