extends RefCounted
## The design built as the parts and joints of the finished ship, the blueprint every hand
## build works from: DesignFrame's frame, skin, decks and inner walls (Void Salvage's frame kit),
## then a part for each fitting (bolted to the deck plate under each corner, or to the hull for a
## mount) and each run of wire or pipe (a span a segment, clipped or bolted to the frame at its
## ends and joined span to span). Built the same on every machine, so its ids agree.
##
## Ship space (DesignFrame's): metres, +X starboard, -Z forward, y up, deck 0's floor at y 0.

const SURFACE := preload("res://shared/void_salvage/shaders/salvage_surface.gdshader")

var rec: DesignRecord
var catalog: DesignCatalog
var body: RigidBody3D
var model: PartModel
var frame: FrameHull
## Fitting part id -> its look (Callable(parent: Node3D)), added again on the real part.
var looks: Dictionary = {}
## Part id -> {stage, key, name, order}: the job it goes in (BuildPlan.make's group).
var groups: Dictionary = {}
## Part id -> the material it was built in (the ghost draws over it; the real part wears it).
var orig: Dictionary = {}
## The blueprint's box (ship space), all of it.
var bounds := AABB()
var _paints: Dictionary = {}
## The frame's parts and their boxes (ship space), for fixing what comes after to them.
var _structure: Array = []


func build(record: DesignRecord, cat: DesignCatalog) -> void:
	rec = record
	catalog = cat
	body = RigidBody3D.new()
	body.name = "Blueprint"
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.collision_layer = 0
	body.collision_mask = 0
	model = PartModel.new(body, true)
	var plan := DesignFrame.propose(rec)
	if plan.is_empty():
		return
	var kit := ShipKit.new(body)
	kit.model = model
	var mats := {"shell": paint(Color(0.5, 0.52, 0.55), "brushed_alloy"),
			"frame": paint(Color(0.34, 0.36, 0.38), "gunmetal"), "lining": paint(Color(0.52, 0.54, 0.54), "satin_paint"),
			"deck": paint(Color(0.46, 0.48, 0.5), "bare_steel")}
	frame = DesignFrame.build(plan, kit, mats)
	for p: PartData in model.parts.values():
		groups[p.id] = _frame_group(p)
		_structure.append([p, box_of(p.id)])
	_fittings()
	_runs()
	var first := true
	for p: PartData in model.parts.values():
		var v := model.part_visual(p.id)
		orig[p.id] = v.material_override if v else null
		var box := box_of(p.id)
		bounds = box if first else bounds.merge(box)
		first = false


## The part's job in a frame part's path ("hull/st:f3/ring/e2", "hull/bay:f3/skin/e4",
## "hull/deck:d1/bay:f2/deck/0", "wall:d0_x_-6.0_-1.9/stud/3").
func _frame_group(p: PartData) -> Dictionary:
	var path := p.path
	var segs := path.split("/")
	var station := -1
	var bay := -1
	var deck := 0
	var wall := ""
	for s in segs:
		if s.begins_with("st:f"):
			station = int(s.substr(4))
		elif s.begins_with("bay:f"):
			bay = int(s.substr(5))
		elif s.begins_with("deck:d"):
			deck = int(s.substr(6))
		elif s.begins_with("wall:"):
			wall = s.substr(5)
	if wall != "":
		var wd := int(wall.substr(1, wall.find("_") - 1)) if wall.begins_with("d") else 0
		var rank := _wall_rank(wall, wd)
		return {"stage": "plates", "key": "wall:" + wall, "name": "Inner wall %d, deck %d" % [rank + 1, wd],
				"order": 2000.0 + wd * 100.0 + rank}
	match p.part_name:
		"FrameNode", "FrameRing":
			return {"stage": "frame", "key": "ring:%d" % station, "name": "Frame ring %d" % station, "order": station * 2.0}
		"Stringer":
			return {"stage": "frame", "key": "stringers:%d" % bay,
					"name": "Stringers, frames %d to %d" % [bay, bay + 1], "order": bay * 2.0 + 2.5}
		"DeckBeam", "DeckGirder", "DeckTrimmer":
			return {"stage": "frame", "key": "deckframe:%d" % deck, "name": "Deck %d frame" % deck, "order": 1000.0 + deck}
		"HullPlate", "WindowPane":
			if path.contains("cap/"):
				var front := path.contains("front")
				return {"stage": "plates", "key": "cap:" + ("front" if front else "back"),
						"name": "Bow end plates" if front else "Stern end plates", "order": -1.0 if front else 999.0}
			return {"stage": "plates", "key": "skin:%d" % bay, "name": "Hull plates, bay %d" % bay, "order": float(bay)}
		"CapPlate":
			var front := path.contains("front")
			return {"stage": "plates", "key": "cap:" + ("front" if front else "back"),
					"name": "Bow end plates" if front else "Stern end plates", "order": -1.0 if front else 999.0}
		"DeckPlate":
			return {"stage": "plates", "key": "deckplates:%d" % deck, "name": "Deck %d plates" % deck, "order": 1000.0 + deck}
	# Door frames and anything else structural: with the frame, after the decks.
	return {"stage": "frame", "key": "openings", "name": "Door frames", "order": 1900.0}


var _walls: Dictionary = {}   # deck -> its walls' names, in the order met


func _wall_rank(wall: String, deck: int) -> int:
	var list: Array = _walls.get_or_add(deck, [])
	if not list.has(wall):
		list.append(wall)
	return list.find(wall)


# --- Fittings -------------------------------------------------------------------------------

func _fittings() -> void:
	var list: Array = rec.components.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.z) < float(b.z) or (is_equal_approx(float(a.z), float(b.z)) and str(a.id) < str(b.id)))
	for c: Dictionary in list:
		var pt := catalog.part(str(c.type))
		var r: Dictionary = rec.rooms.get(str(c.room), {})
		if pt == null or r.is_empty():
			continue
		var f := DesignRules.footprint(c, pt)
		var y := float(r.deck) * rec.deck_height
		var h := minf(pt.size.y, rec.deck_height - 0.4)
		var size := Vector3(f.size.x, h, f.size.y)
		var xf := Transform3D(Basis.IDENTITY, Vector3(f.get_center().x, y + 0.02 + h * 0.5, f.get_center().y))
		var part := _fitting_part("fit:" + str(c.id), pt, size, xf, int(c.get("rot", 0)), false)
		groups[part.id] = {"stage": "fittings", "key": "fit:" + str(c.id), "name": pt.display_name,
				"order": float(c.z) + float(r.deck) * 0.01}
		# A bolt down through each corner of its plinth, into the deck plate under it.
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var at := Vector3(xf.origin.x + corner.x * (size.x * 0.5 - 0.08), y + 0.03, xf.origin.z + corner.y * (size.z * 0.5 - 0.08))
			var under := _structure_at(at + Vector3(0, -0.06, 0), ["DeckPlate", "DeckGirder", "DeckBeam"])
			if under:
				model.connect_parts(part, under, ConnectionData.Kind.BOLT, at, Vector3.UP)
	var mounts: Array = rec.mounts.values()
	mounts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for m: Dictionary in mounts:
		var pt := catalog.part(str(m.type))
		if pt == null:
			continue
		var t := DesignRules.mount_transform(rec, m, pt)
		var xf := t * Transform3D(Basis.IDENTITY, Vector3(0, pt.size.y * 0.5, 0))
		var part := _fitting_part("mount:" + str(m.id), pt, pt.size, xf, 0, true)
		groups[part.id] = {"stage": "fittings", "key": "mount:" + str(m.id), "name": pt.display_name + " (outside)",
				"order": 500.0 + float(m.z)}
		# Its mounting face (+Z) against the hull: bolts at its corners, into the plating.
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var local := Vector3(corner.x * pt.size.x * 0.4, corner.y * pt.size.y * 0.4, pt.size.z * 0.5)
			var at := xf * local
			var n := (xf.basis * Vector3.FORWARD).normalized()
			var under := _structure_at(at + xf.basis.z.normalized() * 0.15, [])
			if under:
				model.connect_parts(part, under, ConnectionData.Kind.BOLT, at, n)


## A fitting as a part: its body (the box, or nothing with a model to show) and collision.
func _fitting_part(path: String, pt: DesignPartType, size: Vector3, xf: Transform3D, rot: int, mount: bool) -> PartData:
	var look := _look_for(pt, size, rot, mount)
	var mesh: Mesh = ArrayMesh.new() if look.is_valid() else _box(size)
	var shape := BoxShape3D.new()
	shape.size = size
	var part := model.add_part("Fitting", PartData.Kind.COMPONENT, maxf(pt.mass, 1.0), pt.cost, xf, mesh, shape,
			paint(pt.colour.darkened(0.25), "metallic_paint"))
	part.path = path
	if look.is_valid():
		looks[part.id] = look
		var holder := Node3D.new()
		holder.name = "Look"
		model.attach_to_part(part, holder)
		look.call(holder)
	return part


## Void Salvage's own part for it, else BSX's model of it (centred on the part: the part's
## origin is the middle of its box); invalid for a plain box.
func _look_for(pt: DesignPartType, size: Vector3, rot: int, mount: bool) -> Callable:
	if pt.shared_part != "" and VsParts.shape(pt.shared_part) != null:
		var id := pt.shared_part
		var s := pt.model_scale
		return func(parent: Node3D) -> void:
			var vs := VsParts.instance(id)
			if vs == null:
				return
			var bb := VsParts.shape(id).mesh.get_aabb()
			vs.scale = Vector3.ONE * s
			vs.rotation.y = rot * PI * 0.5
			vs.position = -(vs.basis * bb.get_center())
			parent.add_child(vs)
	if Flags.is_on("design.part_models"):
		var base := pt.base_id if pt.base_id != "" else pt.id
		if PartModels.has(base):
			var s := pt.model_scale
			var h := size.y
			return func(parent: Node3D) -> void:
				var n := PartModels.instance(base)
				if n == null:
					return
				n.scale = Vector3.ONE * s
				n.rotation.y = rot * PI * 0.5
				# Its origin is on the floor (a mount: its mounting face): the part's is its middle.
				n.position = Vector3(0, -h * 0.5, 0) if not mount else Vector3.ZERO
				parent.add_child(n)
	return Callable()


# --- Runs of wire and pipe ------------------------------------------------------------------

func _runs() -> void:
	var h := rec.deck_height
	var list: Array = rec.runs.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.kind) < str(b.kind) or (str(a.kind) == str(b.kind) and int(a.deck) * 1000 + _num(a.id) < int(b.deck) * 1000 + _num(b.id)))
	var counts := {"wire": 0, "fuel": 0}
	for w: Dictionary in list:
		var kind := str(w.kind)
		if not DesignServices.KINDS.has(kind):
			continue
		var pts := DesignServices.points(w)
		if pts.size() < 2:
			continue
		var wire := kind == "wire"
		var deck := int(w.deck)
		# Cables in a tray under the deckhead; fuel pipes under deck 0's plates, else low on the wall.
		var y := deck * h + (h - 0.55 if wire else (-0.32 if deck == 0 else 0.35))
		var col: Color = DesignServices.KINDS[kind].colour
		var mat := paint(col.darkened(0.25), "satin_paint") if wire else paint(col.darkened(0.15), "gloss_paint")
		counts[kind] = int(counts[kind]) + 1
		var key := "run:" + str(w.id)
		var name := ("Wiring run %d, deck %d" if wire else "Fuel pipe %d, deck %d") % [int(counts[kind]), deck]
		var spans: Array[PartData] = []
		for i in pts.size() - 1:
			var a := Vector3(pts[i].x, y, pts[i].y)
			var b := Vector3(pts[i + 1].x, y, pts[i + 1].y)
			var len := a.distance_to(b)
			if len < 0.05:
				continue
			var xf := FrameParts.along(a, b, Vector3.UP)
			xf.origin = (a + b) * 0.5
			var shape := BoxShape3D.new()
			var mesh: Mesh
			if wire:
				shape.size = Vector3(len, 0.06, 0.2)
				mesh = _box(shape.size)
			else:
				shape.size = Vector3(len, 0.1, 0.1)
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.045
				cyl.bottom_radius = 0.045
				cyl.height = len
				cyl.radial_segments = 10
				cyl.rings = 1
				var st := SurfaceTool.new()
				st.append_from(cyl, 0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO))
				mesh = st.commit()
			var part := model.add_part("CableRun" if wire else "FuelPipe", PartData.Kind.CONDUIT, len * (1.6 if wire else 4.5),
					0.0, xf, mesh, shape, mat)
			part.path = "%s/%d" % [key, i]
			groups[part.id] = {"stage": "wiring" if wire else "pipes", "key": key, "name": name,
					"order": deck * 1000.0 + float(counts[kind])}
			if not spans.is_empty():
				model.connect_parts(part, spans.back(), ConnectionData.Kind.CONNECTOR if wire else ConnectionData.Kind.BOLT,
						a, Vector3.UP)
			spans.append(part)
		if spans.is_empty():
			continue
		# Clipped (wire) or bracketed (pipe) to the frame at both ends.
		var ends := [[spans[0], Vector3(pts[0].x, y, pts[0].y)], [spans.back(), Vector3(pts[pts.size() - 1].x, y, pts[pts.size() - 1].y)]]
		for e: Array in ends:
			var p: PartData = e[0]
			var at: Vector3 = e[1]
			var to := _structure_near(at)
			if to:
				var n := Vector3.DOWN if wire else Vector3.UP
				var spot := at + n * (0.03 if wire else 0.05)
				model.connect_parts(p, to, ConnectionData.Kind.RIVET if wire else ConnectionData.Kind.BOLT, spot, n)


static func _num(id: Variant) -> int:
	var s := str(id)
	var digits := ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0


# --- Finding the frame ----------------------------------------------------------------------

## The frame part (of `names`, any if empty) whose box holds `at`, nearest its middle; null for none.
func _structure_at(at: Vector3, names: Array) -> PartData:
	var best: PartData = null
	var best_d := INF
	for e: Array in _structure:
		var p: PartData = e[0]
		if not names.is_empty() and not names.has(p.part_name):
			continue
		var box: AABB = (e[1] as AABB).grow(0.05)
		if not box.has_point(at):
			continue
		var d := box.get_center().distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = p
	return best if best else _structure_near(at)


## The frame part nearest `at` (by its box); null with no frame.
func _structure_near(at: Vector3) -> PartData:
	var best: PartData = null
	var best_d := INF
	for e: Array in _structure:
		var box: AABB = e[1]
		var d := (at.clamp(box.position, box.end) - at).length_squared()
		if d < best_d:
			best_d = d
			best = e[0]
	return best


## Part `id`'s box in ship space.
func box_of(id: int) -> AABB:
	var c := model.part_collider(id)
	return c.transform * model.part_box(id) if c else AABB()


# --- Looks ------------------------------------------------------------------------------------

func paint(c: Color, finish: String) -> ShaderMaterial:
	var key := "%s/%s" % [c.to_html(), finish]
	if not _paints.has(key):
		var info := SurfaceFinish.info(finish)
		var m := ShaderMaterial.new()
		m.shader = SURFACE
		m.set_shader_parameter("albedo", Color(c.r, c.g, c.b))
		m.set_shader_parameter("metallic", float(info.get("metallic", 0.3)))
		m.set_shader_parameter("roughness", float(info.get("roughness", 0.5)))
		m.set_shader_parameter("survey_skip", true)
		SurfaceFinish.apply(m)
		SurfaceFinish.set_finish(m, finish, Color(c.r, c.g, c.b, 1.0))
		m.set_shader_parameter("material_blend", 0.0)
		_paints[key] = m
	return _paints[key]


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
