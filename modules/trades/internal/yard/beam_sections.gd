class_name TradesBeamSections
extends RefCounted
## The beam sections the design tablet draws with (trades.beam_designer): box tube, I-beam,
## channel and angle, each with its profile (metres, across the beam: x wide, y high) and its
## mass a metre of steel. Until Shared Components has stock beams these are the designer's own;
## the sizes match the bars planned for the stock list (beam plan, B1).

## id -> {name, family (box|i|channel|angle), w, h, t (m), kg_m (steel, kg a metre)}.
const SECTIONS := {
	"box_100": {"name": "Box 100 x 100 x 5", "family": "box", "w": 0.1, "h": 0.1, "t": 0.005, "kg_m": 14.7},
	"box_150": {"name": "Box 150 x 100 x 6", "family": "box", "w": 0.1, "h": 0.15, "t": 0.006, "kg_m": 22.3},
	"i_150": {"name": "I-beam 150 x 75", "family": "i", "w": 0.075, "h": 0.15, "t": 0.007, "kg_m": 14.0},
	"channel_100": {"name": "Channel 100 x 50", "family": "channel", "w": 0.05, "h": 0.1, "t": 0.006, "kg_m": 10.2},
	"angle_75": {"name": "Angle 75 x 75 x 6", "family": "angle", "w": 0.075, "h": 0.075, "t": 0.006, "kg_m": 6.8},
}
## The order the mouse wheel steps through them.
const ORDER: Array[String] = ["box_100", "box_150", "i_150", "channel_100", "angle_75"]
const DEFAULT := "box_100"


static func has(id: String) -> bool:
	return SECTIONS.has(id)


static func name_of(id: String) -> String:
	return str((SECTIONS.get(id, SECTIONS[DEFAULT]) as Dictionary).name)


## The next section along ORDER from `id` (+1) or the one before (-1), wrapping round.
static func step(id: String, by: int) -> String:
	var i := ORDER.find(id)
	return ORDER[posmod((i if i >= 0 else 0) + by, ORDER.size())]


## Its mass for a length (kg, steel).
static func mass(id: String, length_m: float) -> float:
	return float((SECTIONS.get(id, SECTIONS[DEFAULT]) as Dictionary).kg_m) * length_m


## The section's half width across its widest side (m): how near another beam may come.
static func radius(id: String) -> float:
	var s: Dictionary = SECTIONS.get(id, SECTIONS[DEFAULT])
	return maxf(float(s.w), float(s.h)) * 0.5


## Its profile as one closed outline, counter-clockwise, about the beam's centre line (m).
## A box is drawn by its outside (the hologram has no inside to see).
static func outline(id: String) -> PackedVector2Array:
	var s: Dictionary = SECTIONS.get(id, SECTIONS[DEFAULT])
	var w := float(s.w) * 0.5
	var h := float(s.h) * 0.5
	var t := float(s.t)
	match str(s.family):
		"i":
			var web := t * 0.5
			return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, -h + t), Vector2(web, -h + t),
					Vector2(web, h - t), Vector2(w, h - t), Vector2(w, h), Vector2(-w, h), Vector2(-w, h - t),
					Vector2(-web, h - t), Vector2(-web, -h + t), Vector2(-w, -h + t)])
		"channel":
			return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, -h + t), Vector2(-w + t, -h + t),
					Vector2(-w + t, h - t), Vector2(w, h - t), Vector2(w, h), Vector2(-w, h)])
		"angle":
			return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, -h + t), Vector2(-w + t, -h + t),
					Vector2(-w + t, h), Vector2(-w, h)])
	return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])


## The section run `length_m` along -Z..+Z about the origin (centred), as a mesh.
static func mesh(id: String, length_m: float) -> ArrayMesh:
	var o := outline(id)
	var z := length_m * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := o.size()
	for i in n:
		var a := o[i]
		var b := o[(i + 1) % n]
		var side := Vector3(b.y - a.y, a.x - b.x, 0.0).normalized()
		st.set_normal(side)
		for p: Vector3 in [Vector3(a.x, a.y, -z), Vector3(b.x, b.y, -z), Vector3(b.x, b.y, z),
				Vector3(a.x, a.y, -z), Vector3(b.x, b.y, z), Vector3(a.x, a.y, z)]:
			st.add_vertex(p)
	var tris := Geometry2D.triangulate_polygon(o)
	for cap: float in [-z, z]:
		st.set_normal(Vector3(0, 0, signf(cap)))
		for k in range(0, tris.size(), 3):
			for j: int in ([0, 1, 2] if cap > 0.0 else [0, 2, 1]):
				var p := o[tris[k + j]]
				st.add_vertex(Vector3(p.x, p.y, cap))
	return st.commit()
