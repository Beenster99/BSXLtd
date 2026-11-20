extends RefCounted
## The berths and the dock arm dressed to Void Salvage's standard (beenster, 20 Nov: "bring
## them up to Void Salvage standards"; flag yard.room_detail): node blocks where the frame's
## beams meet, bolted collars where each rib crosses a chord, hazard bands on the end rings,
## hydraulic rams and a conduit on every clamp, a catwalk with handrails along each berth's
## station side, and cross bracing in every bay of the trusses. Merged meshes (DetailMesh),
## presentation only: no collision.

const Kit := preload("res://modules/yard/internal/yard_kit.gd")
const DetailMesh := preload("res://modules/yard/internal/detail_mesh.gd")

## The dock's frames are big and open: gather them by 32 m cells (a berth's eight floods are
## all its meshes see).
const CELL := 32.0
## The catwalk's width (m) and how far its rail stands (m).
const WALK := 1.4
const RAIL := 1.1

var dm := DetailMesh.new()
var _white: Material
var _orange: Material
var _dark: Material
var _steel: Material
var _chrome: Material
var _grate: Material
var _rubber: Material


func _init(kit) -> void:
	dm.cell = CELL
	_white = kit.paint(Kit.HULL, 0.2, 0.4, "gloss_paint")
	_orange = kit.paint(Kit.ORANGE, 0.15, 0.4, "hazard_paint")
	_dark = kit.paint(Kit.DARK, 0.7, 0.45, "gunmetal")
	_steel = kit.paint(Color(0.55, 0.57, 0.6), 0.8, 0.4, "galvanised")
	_chrome = kit.paint(Color(0.8, 0.82, 0.85), 0.9, 0.2, "brushed_steel")
	_grate = kit.paint(Color(0.35, 0.37, 0.4), 0.7, 0.5, "tread_diamond_steel")
	_rubber = kit.paint(Color(0.08, 0.08, 0.09), 0.0, 0.85)


## A berth's frame (`box`, its beams `beam` m square; ribs at `rib_x`).
func berth(box: AABB, beam: float, rib_x: Array[float]) -> void:
	var lo := box.position
	var hi := box.end
	var h := beam * 0.5
	# Node blocks at the eight corners, a bolt head at each corner of their faces.
	for x: float in [lo.x, hi.x]:
		for y: float in [lo.y, hi.y]:
			for z: float in [lo.z, hi.z]:
				var n := beam + 0.2
				dm.box(_dark, Vector3(n, n, n), Vector3(x, y, z))
				_bolts(Vector3(x, y, z), n * 0.5, n * 0.36)
	# Collars where each rib crosses a long chord, bolted down both sides.
	for x: float in rib_x:
		for y: float in [lo.y, hi.y]:
			for z: float in [lo.z, hi.z]:
				dm.box(_steel, Vector3(0.5, beam + 0.1, beam + 0.1), Vector3(x, y, z))
				for side: float in [-1.0, 1.0]:
					for dy: float in [-h * 0.6, h * 0.6]:
						for dx: float in [-0.15, 0.15]:
							dm.box(_dark, Vector3(0.07, 0.07, 0.03), Vector3(x + dx, y + dy, z + side * (h + 0.063)))
		# A conduit down each rib's inner face to its clamps, and the clamps' rams.
		for z: float in [lo.z, hi.z]:
			var inward := 1.0 if z == lo.z else -1.0
			dm.rod(_rubber, Vector3(x + 0.18, lo.y + h + 0.1, z + inward * 0.36), Vector3(x + 0.18, hi.y - h - 0.1, z + inward * 0.36), 0.05, 6)
			for y: float in [lo.y + box.size.y * 0.3, lo.y + box.size.y * 0.7]:
				for sx: float in [-0.34, 0.34]:
					dm.rod(_orange, Vector3(x + sx, y, z + inward * 0.32), Vector3(x + sx, y, z + inward * 1.8), 0.12, 8)
					dm.rod(_chrome, Vector3(x + sx, y, z + inward * 1.8), Vector3(x + sx, y, z + inward * 3.0), 0.06, 8)
				# The pad's rubber face.
				dm.box(_rubber, Vector3(0.9, 0.9, 0.06), Vector3(x, y, z + inward * 3.477))
	# Hazard bands round the orange end rings' uprights, every 2 m.
	for x: float in [lo.x, hi.x]:
		for z: float in [lo.z, hi.z]:
			var y := lo.y + h + 1.2
			while y < hi.y - h - 0.6:
				dm.box(_dark, Vector3(beam + 0.02, 0.4, beam + 0.02), Vector3(x, y, z))
				y += 2.0
	_catwalk(lo, hi, beam)


## A catwalk outside the station side's bottom chord: grating on brackets under each rib,
## kick plates, posts and two rails.
func _catwalk(lo: Vector3, hi: Vector3, beam: float) -> void:
	var y := lo.y + beam * 0.5
	var z0 := hi.z + beam * 0.5 + 0.06
	var z1 := z0 + WALK
	var x0 := lo.x + beam + 0.4
	var x1 := hi.x - beam - 0.4
	dm.span(_grate, Vector3(x0, y - 0.05, z0), Vector3(x1, y, z1))
	dm.span(_steel, Vector3(x0 + 0.003, y - 0.002, z1 - 0.03), Vector3(x1 - 0.003, y + 0.12, z1 + 0.002))
	var x := x0
	while x <= x1 + 0.01:
		dm.span(_steel, Vector3(x - 0.04, y - 0.25, hi.z + beam * 0.5 - 0.02), Vector3(x + 0.04, y - 0.052, z1 - 0.004))
		dm.rod(_orange, Vector3(x, y, z1 - 0.06), Vector3(x, y + RAIL, z1 - 0.06), 0.03, 6)
		x += 2.0
	for r: float in [RAIL, RAIL * 0.5]:
		dm.rod(_orange, Vector3(x0, y + r, z1 - 0.06), Vector3(x1, y + r, z1 - 0.06), 0.03, 6)


## A truss of four chords `half` m off its line from `a` to `b`, a rung frame every `n` bays:
## cross braces in each bay on all four faces, and a gusset at each end.
func truss(a: Vector3, b: Vector3, half: float) -> void:
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var t := Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5)
	var n := maxi(int(length / 3.0), 1)
	var corners: Array[Vector2] = [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	for i in n:
		var z0 := -length * 0.5 + length * float(i) / float(n)
		var z1 := -length * 0.5 + length * float(i + 1) / float(n)
		for f in 4:
			var c0 := corners[f]
			var c1 := corners[(f + 1) % 4]
			var p0 := c0.lerp(c1, 0.12)
			var p1 := c0.lerp(c1, 0.88)
			# Alternate the diagonals bay by bay, so they zigzag.
			if i % 2 == 0:
				dm.rod(_steel, t * Vector3(p0.x, p0.y, z0 + 0.1), t * Vector3(p1.x, p1.y, z1 - 0.1), 0.045, 6)
			else:
				dm.rod(_steel, t * Vector3(p1.x, p1.y, z0 + 0.1), t * Vector3(p0.x, p0.y, z1 - 0.1), 0.045, 6)


func commit(parent: Node3D) -> int:
	return dm.commit(parent, "Detail")


## A bolt head near each corner of the six faces of a cube `half` m round `c`, `off` m out
## from its face's middle.
func _bolts(c: Vector3, half: float, off: float) -> void:
	for axis in 3:
		for s: float in [-1.0, 1.0]:
			var nrm := Vector3.ZERO
			nrm[axis] = s
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			for du: float in [-off, off]:
				for dv: float in [-off, off]:
					var size := Vector3(0.09, 0.09, 0.09)
					size[axis] = 0.04
					dm.box(_dark, size, c + nrm * (half + 0.017) + u * du + v * dv)
