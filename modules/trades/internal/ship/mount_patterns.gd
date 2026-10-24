class_name TradesMountPatterns
extends RefCounted
## The joints at a unit's internal mount points on an upgrade rig (Component Upgrades U1,
## beenster 2026-10-24: an attractor coil opened on its emitter frame, its quantum core and
## field emitters fitted by hand). Ship and Bay holds the mounts as slots; this lays out each
## mount's fasteners so the rig's slots get them without placing joints by hand, and Tools
## works them like any ship joint.
##
## Mount space: the mount's origin on the face the part sits on, +Y out of that face, the
## box `size` (m) the part fills, centred on the origin in X and Z and standing up +Y.

## The kinds of mount and what holds a part on each.
const KINDS := ["cover", "core", "emitter", "board"]
## How far in from a cover's corners its bolts sit, and its tack welds' length (m).
const COVER_INSET_M := 0.03
const TACK_M := 0.04
## The core's bolt circle: bolts and how far in from the seat's edge (m).
const CORE_BOLTS := 6
const CORE_INSET_M := 0.025
## A weld round an emitter horn's foot: one seam per side, inset from the edge (m).
const SEAM_WIDTH_M := 0.008


## The fasteners holding a part on a mount of `kind`, ids "<slot_id>/<letter><n>", in the
## space `mount` is given in (rig space for a rig slot).
static func pattern(kind: String, slot_id: String, mount: Transform3D, size: Vector3) -> Array[FastenerPoint]:
	var out: Array[FastenerPoint] = []
	var up := mount.basis.y.normalized()
	match kind:
		"cover":
			var hx := maxf(size.x * 0.5 - COVER_INSET_M, 0.01)
			var hz := maxf(size.z * 0.5 - COVER_INSET_M, 0.01)
			var n := 0
			for c: Vector2 in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
				n += 1
				out.append(_point(slot_id, "b%d" % n, "bolt", "M10", mount * Vector3(c.x, 0, c.y), up))
			# Two tack welds, one each side, along the long edges' middles.
			for k: int in 2:
				var side := -1.0 if k == 0 else 1.0
				var w := _point(slot_id, "w%d" % (k + 1), "weld", "", mount * Vector3(0, 0, side * size.z * 0.5), up)
				w.seam_up = mount.basis.x.normalized()
				w.seam_size = Vector2(TACK_M, SEAM_WIDTH_M)
				out.append(w)
		"core":
			var r := maxf(minf(size.x, size.z) * 0.5 - CORE_INSET_M, 0.02)
			for i: int in CORE_BOLTS:
				var a := TAU * i / CORE_BOLTS
				out.append(_point(slot_id, "b%d" % (i + 1), "bolt", "M12", mount * Vector3(cos(a) * r, 0, sin(a) * r), up))
		"emitter":
			# Two seams along the horn foot's long sides.
			for k: int in 2:
				var side := -1.0 if k == 0 else 1.0
				var w := _point(slot_id, "w%d" % (k + 1), "weld", "", mount * Vector3(0, 0, side * size.z * 0.5), up)
				w.seam_up = mount.basis.x.normalized()
				w.seam_size = Vector2(maxf(size.x - 0.01, 0.02), SEAM_WIDTH_M)
				out.append(w)
		"board":
			# The power plug and the data plug, side by side on the board's front edge.
			for k: int in 2:
				var at := mount * Vector3((-0.25 if k == 0 else 0.25) * size.x, size.y, size.z * 0.5)
				out.append(_point(slot_id, "c%d" % (k + 1), "connector", "power" if k == 0 else "data", at, mount.basis.z.normalized()))
	return out


static func _point(slot_id: String, n: String, kind: String, spec: String, at: Vector3, normal: Vector3) -> FastenerPoint:
	var f := FastenerPoint.new()
	f.joint_id = "%s/%s" % [slot_id, n]
	f.kind = kind
	f.spec = spec
	f.position = at
	f.normal = normal
	return f
