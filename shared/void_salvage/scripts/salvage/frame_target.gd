class_name FrameTarget
extends RefCounted
## What a FrameHull builds into (docs/SHIP_FRAME_PLAN.md 4.2): something that makes parts and
## joins them on a body's PartModel. Two games' builders are one: ShipKit (a player ship's
## parts, in the ship's paint) and ShipBuilder (a wreck's, priced and surveyed as salvage)
## extend it and override `part` and `join`; this base builds straight into `model` (a bare
## body's parts, as BSX takes a hull in), weighing each part as steel.
##
## The shaped makers (`box`, `member`, `flush_box`, `flush_part`) build their shape here and
## hand it to `part`, so an override of `part` is all a builder needs; ShipBuilder keeps its
## own for the wrecks.

## Steel, kg per cubic metre (a part's mass from its volume).
const STEEL: float = 7800.0

## The parts and joints being built (a builder that reaches its model another way leaves it
## null and overrides `parts_model`).
var model: PartModel


## The parts and joints being built.
func parts_model() -> PartModel:
	return model


## Adds a part of `shape` at `xform` (body space) in `mat`, weighing its volume of steel
## times `fill`. `tag` and `glass_mat` are for builders that use them (ShipKit); `path` names
## it (PartData.path, docs/SHIP_FRAME_PLAN.md 4.7).
func part(part_name: String, kind: PartData.Kind, shape: PartShapes.PartShape, xform: Transform3D,
		mat: Material, tag: String = "", fill: float = 1.0, glass_mat: Material = null, path: String = "") -> PartData:
	var made := model.add_part(part_name, kind, maxf(shape.volume * STEEL * fill, 0.1), 0.0, xform, shape.mesh,
			shape.collision, mat)
	made.path = path
	return made


## Joins two parts with a joint of `kind` at `at`, facing `normal` (body space); its head hangs
## on `a`. Welds: `seam_up` and `seam_size` as in ConnectionData. `path` names it.
func join(a: PartData, b: PartData, kind: ConnectionData.Kind, at: Vector3, normal: Vector3,
		seam_up := Vector3.ZERO, seam_size := Vector2.ZERO, path: String = "") -> ConnectionData:
	var made := model.connect_parts(a, b, kind, at, normal, seam_up, seam_size)
	if made:
		made.path = path
	return made


## A box part of `size` (it dents and tears, like a wreck's plates).
func box(part_name: String, kind: PartData.Kind, size: Vector3, xform: Transform3D,
		mat: Material, fill: float, density: float = STEEL) -> PartData:
	var shape := _shape(_box_mesh(size), _box_shape(size), size.x * size.y * size.z)
	return part(part_name, kind, shape, xform, mat, "", fill * density / STEEL)


## A box part drawn bigger than its collision (a flush skin): the collision is the box of
## `size`, the look a plate over `outline` (local XZ, round the box's +Y face) with a `bevel`
## round its outer edge (FrameParts.plate).
func flush_box(part_name: String, kind: PartData.Kind, size: Vector3, outline: PackedVector2Array,
		xform: Transform3D, mat: Material, fill: float, bevel: float = 0.005, density: float = STEEL) -> PartData:
	var visual := FrameParts.plate(outline, size.y, bevel, size.y * 0.5)
	var made := part(part_name, kind, _shape(visual.mesh, _box_shape(size), size.x * size.y * size.z), xform, mat,
			"", fill * density / STEEL)
	_mark(made, visual.mesh, size)
	return made


## A part with a convex collision and a bigger look over it (a flush skin's cut-to-fit plate).
func flush_part(part_name: String, kind: PartData.Kind, collision: PartShapes.PartShape, visual: ArrayMesh,
		xform: Transform3D, mat: Material, fill: float = 1.0) -> PartData:
	var made := part(part_name, kind, _shape(visual, collision.collision, collision.volume), xform, mat, "", fill)
	_mark(made, visual)
	return made


## A mitred frame member (FrameMember): `outline` its side outline in its own XY plane,
## `width` thick along Z. It can bend, like a box part.
func member(part_name: String, kind: PartData.Kind, outline: PackedVector2Array, width: float,
		xform: Transform3D, mat: Material, fill: float) -> PartData:
	var shape := FrameMember.build(outline, width)
	var made := part(part_name, kind, _shape(shape.mesh, shape.collision, shape.volume), xform, mat, "", fill)
	_mark(made, shape.mesh, shape.mesh.get_aabb().size)
	return made


## Dents draw on the look (meta "base_mesh"); tears cut a box's collision (meta "box_size").
func _mark(made: PartData, look: Mesh, size := Vector3.ZERO) -> void:
	var node := model.part_visual(made.id)
	if node == null:
		return
	node.set_meta("base_mesh", look)
	if size != Vector3.ZERO:
		node.set_meta("box_size", size)


static func _shape(mesh: Mesh, collision: Shape3D, volume: float) -> PartShapes.PartShape:
	var shape := PartShapes.PartShape.new()
	shape.mesh = mesh
	shape.collision = collision
	shape.volume = volume
	return shape


static func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape
