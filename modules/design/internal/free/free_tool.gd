extends RefCounted
## Placing free beams and plates (DesignFree), the same in every view: the table's plan and
## elevations, the console's 3D view and walk-inside. A view says where the pointer is (a ray,
## or a point), the tool snaps it (nodes, beams, the grid, guidelines) and on a click makes the
## edit. BEAM: click its start, click its end; it chains on from there until right-click or Esc.
## PLATE: click three or four ends round it (back on the first, or Enter, closes three).

var bus: DesignBus
## "", "beam" or "plate".
var mode := ""
## Points placed so far (ship space): a beam's start, a plate's corners.
var pts: Array[Vector3] = []
## Where the pointer lands now: DesignFree.place's {point, kind, id, guides}.
var hover := {}


func _init(design_bus: DesignBus) -> void:
	bus = design_bus


func active() -> bool:
	return mode != ""


func start(m: String) -> void:
	mode = m
	pts.clear()
	hover = {}


## Esc: drops the points placed, else puts the tool down. False if there was nothing to drop.
func cancel() -> bool:
	if not pts.is_empty():
		pts.clear()
		return true
	if mode != "":
		mode = ""
		hover = {}
		return true
	return false


## Right-click: back one point; with none, the tool goes down.
func back() -> void:
	if pts.is_empty():
		mode = ""
		hover = {}
	else:
		pts.pop_back()


func anchor() -> Variant:
	return pts[pts.size() - 1] if not pts.is_empty() else null


func aim_ray(from: Vector3, dir: Vector3, surface: Variant = null, reach := 8.0) -> Dictionary:
	hover = DesignFree.from_ray(bus.library.current, bus.frame_plan(), from, dir, anchor(), bus.free_grid, reach, surface)
	return hover


func aim_point(raw: Vector3) -> Dictionary:
	hover = DesignFree.place(bus.library.current, bus.frame_plan(), raw, bus.free_grid)
	return hover


## Aims at a node itself (a view that found one under the pointer).
func aim_node(p: Vector3) -> Dictionary:
	hover = {"point": p, "kind": "node", "id": "", "guides": DesignFree.guides(DesignFree.nodes(bus.library.current, bus.frame_plan()), p)}
	return hover


## A click at the hover point: the beam or plate made, its id ("" while points are still being
## placed, or none could be made there).
func click() -> String:
	if hover.is_empty() or mode == "":
		return ""
	var p: Vector3 = hover.point
	match mode:
		"beam":
			if pts.is_empty():
				pts.append(p)
				return ""
			var a := pts[0]
			if a.distance_to(p) < DesignFree.MIN_BEAM:
				return ""
			var id := _do({"op": "add_free_beam", "beam": {"a": DesignFree.arr(a), "b": DesignFree.arr(p),
					"roll": 0.0, "size": bus.free_size}}, "g")
			pts.clear()
			pts.append(p)
			return id
		"plate":
			if pts.size() >= 3 and p.distance_to(pts[0]) < DesignFree.JOIN * 3.0:
				return finish()
			for q in pts:
				if q.distance_to(p) < 0.05:
					return ""
			pts.append(p)
			if pts.size() == 4:
				return finish()
	return ""


## Enter: a plate on the three (or four) corners placed.
func finish() -> String:
	if mode != "plate" or pts.size() < 3:
		return ""
	var cs := PackedVector3Array(pts)
	pts.clear()
	if not DesignFree.plate_ok(cs):
		return ""
	var arr: Array = []
	for c in cs:
		arr.append(DesignFree.arr(c))
	return _do({"op": "add_free_plate", "plate": {"pts": arr, "kind": bus.free_kind}}, "p")


func _do(op: Dictionary, prefix: String) -> String:
	var rec := bus.library.current
	if rec == null:
		return ""
	var id := rec.peek_id(prefix)
	var before := rec.free_beams.size() + rec.free_plates.size()
	bus.editor.do(DesignFree.with_twin(op, bus.mirror))
	if rec.free_beams.size() + rec.free_plates.size() == before and not bus.is_shared():
		return ""
	return id


## What a view draws for the tool: {rubber: [a, b] or [], outline: [corners...], point,
## kind, guides}.
func ghost() -> Dictionary:
	var out := {"rubber": [], "outline": [], "point": null, "kind": "", "guides": []}
	if mode == "" or hover.is_empty():
		return out
	var p: Vector3 = hover.point
	out.point = p
	out.kind = str(hover.kind)
	out.guides = hover.get("guides", [])
	if mode == "beam" and not pts.is_empty():
		out.rubber = [pts[0], p]
	elif mode == "plate" and not pts.is_empty():
		var o: Array = []
		for q in pts:
			o.append(q)
		o.append(p)
		out.outline = o
	return out


## The line under the pointer for a HUD: what clicking does.
func hint() -> String:
	var g := "grid %s m" % str(bus.free_grid)
	match mode:
		"beam":
			return ("BEAM: click its start" if pts.is_empty() else "BEAM: click its end (%.2f m)" % pts[0].distance_to(hover.get("point", pts[0]))) \
					+ "   right-click back   Esc stop   " + g
		"plate":
			return "PLATE: click corner %d of 3 or 4   Enter close   right-click back   Esc stop   %s" % [pts.size() + 1, g]
	return ""
