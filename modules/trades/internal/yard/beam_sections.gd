class_name TradesBeamSections
extends RefCounted
## The beam sections the design tablet draws with (trades.beam_designer): every section Shared
## Components stocks as beam bars (StockBeams: box tube, I-beam, channel and angle), named
## "<family>_<w>x<h>x<t>" in millimetres ("box_100x100x5"). A design's beams are steel for now;
## the bars to buy are StockBeams' steel ones (bar_id).

const DEFAULT := "box_100x100x5"
## The designer's first sections (before stock beams), and what they are now.
const OLD := {"box_100": "box_100x100x5", "box_150": "box_150x100x6", "i_150": "i_100x100x6",
		"channel_100": "channel_50x100x5", "angle_75": "angle_75x75x6"}

static var _sections: Dictionary = {}
static var _order: Array[String] = []


## id -> {name, family, w, h, t (m), kg_m (steel, kg a metre), bar (the steel 6 m bar's id)}.
static func sections() -> Dictionary:
	if _sections.is_empty():
		for bar: String in StockBeams.item_ids("", "steel"):
			var it := StockBeams.item(bar)
			if int(it.length_mm) != 6000:
				continue
			var id := "%s_%dx%dx%d" % [it.family, it.w_mm, it.h_mm, it.t_mm]
			_sections[id] = {"name": "%s %d x %d x %d" % [StockBeams.family(str(it.family)).get("display_name", it.family),
					it.w_mm, it.h_mm, it.t_mm], "family": str(it.family), "w": float(it.section.w), "h": float(it.section.h),
					"t": float(it.section.t), "kg_m": float(it.mass) / float(it.length), "bar": bar}
			_order.append(id)
	return _sections


## The order the mouse wheel steps through them (by family, then size). With
## trades.one_section (beenster, 0.3.30: "We only need 100 x 100 x 5 box beams") only that one;
## a design's beams drawn in another still read as theirs.
static func order() -> Array[String]:
	sections()
	if Flags.is_on("trades.one_section") and _sections.has(DEFAULT):
		return [DEFAULT] as Array[String]
	return _order


## A section id as it is now (the designer's first ids are mapped on).
static func normal(id: String) -> String:
	return str(OLD.get(id, id))


static func has(id: String) -> bool:
	return sections().has(normal(id))


static func info(id: String) -> Dictionary:
	var all := sections()
	return all.get(normal(id), all.get(DEFAULT, {}))


static func name_of(id: String) -> String:
	return str(info(id).get("name", id))


## The next section along the order from `id` (+1) or the one before (-1), wrapping round.
static func step(id: String, by: int) -> String:
	var o := order()
	if o.is_empty():
		return DEFAULT
	var i := o.find(normal(id))
	return o[posmod((i if i >= 0 else 0) + by, o.size())]


## Its mass for a length (kg, steel).
static func mass(id: String, length_m: float) -> float:
	return float(info(id).get("kg_m", 0.0)) * length_m


## The section's half width across its widest side (m): how near another beam may come.
static func radius(id: String) -> float:
	var s := info(id)
	return maxf(float(s.get("w", 0.1)), float(s.get("h", 0.1))) * 0.5


## Its profile's outer edge, counter-clockwise, about the beam's centre line (m). A box is drawn
## by its outside (the hologram has no inside to see).
static func outline(id: String) -> PackedVector2Array:
	var s := info(id)
	return StockBeams.section_outline(str(s.get("family", "box")), float(s.get("w", 0.1)), float(s.get("h", 0.1)), float(s.get("t", 0.005)))


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
