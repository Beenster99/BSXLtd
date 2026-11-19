extends Node3D
## The holotable (plan 2.3, 2.4): a long rectangular table in the middle of the design room with the
## open design floating over it as a hologram. Turn it, zoom it, slice it with a cutting
## plane, and switch its layers on and off. Built from the same record as every plan, so it
## always matches them; it rebuilds itself on any change.
##
## Node space: y = 0 is the floor, the table top is at TABLE_HEIGHT and the model floats
## over it, its middle over the table's middle. The model is drawn at `scale_fit` (fits the
## table, its long side along the table's) times `zoom`, turned `turn` radians about the
## vertical from there.

## The table top, m: length along x, width along z (beenster, 0.4.0: larger and rectangular).
const TABLE_SIZE := Vector2(7.0, 3.5)
const TABLE_HEIGHT := 0.95
## Highest point of the model over the floor, m (the room is 6 m high).
const MODEL_TOP := 3.8
## The footprint the model is fitted into at zoom 1, m (the top less a margin).
const FIT := Vector2(6.3, 2.9)

const LAYERS: PackedStringArray = ["rooms", "frame", "plates", "components", "wiring", "pipes", "power"]
const LAYER_NAMES := {"rooms": "Rooms", "frame": "Frame", "plates": "Plates",
		"components": "Components", "wiring": "Wiring", "pipes": "Pipes", "power": "Power"}
const HOLO := Color(0.45, 0.85, 1.0)

const HoloShader := preload("res://modules/design/internal/holo/holo.gdshader")

var bus: DesignBus
var layers := {"rooms": true, "frame": true, "plates": false, "components": true, "wiring": false,
		"pipes": false, "power": false}
## Radians about the vertical.
var turn := 0.0
## Turned a quarter so a design longer across than along still lies along the table.
var align := 0.0
var zoom := 1.0
## Cut away everything above this share of the model's height (1 = no cut).
var cut := 1.0
## Room ids to light up (selected on a plan).
var lit_rooms: Dictionary = {}

var model: Node3D
var scale_fit := 1.0
var _layer_nodes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _dirty := true
var _cut_y := 100.0


func _ready() -> void:
	_build_table()
	model = Node3D.new()
	model.name = "Model"
	add_child(model)


func setup(design_bus: DesignBus) -> void:
	bus = design_bus
	bus.design_changed.connect(func() -> void: _dirty = true)
	_dirty = true
	if bus.crew:
		bus.crew.call("attach_holo", self)


func set_layer(layer: String, on: bool) -> void:
	layers[layer] = on
	if _layer_nodes.has(layer):
		(_layer_nodes[layer] as Node3D).visible = on


func set_cut(share: float) -> void:
	cut = clampf(share, 0.05, 1.0)
	_apply_cut()


func light_rooms(ids: Array) -> void:
	lit_rooms = {}
	for id in ids:
		lit_rooms[str(id)] = true
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty and bus:
		_dirty = false
		rebuild()
		tag_view_layer()
	if model:
		model.rotation.y = align + turn
		model.scale = Vector3.ONE * scale_fit * zoom
	_apply_cut()


## The render layer only the hologram is on as well, so the console's 3D view can show it alone.
const VIEW_LAYER := 1 << 14


## The hologram's middle and radius in the model's own space (before its scale), for the view
## to frame it.
var view_middle := Vector3.ZERO
var view_radius := 1.0


func tag_view_layer() -> void:
	if model == null:
		return
	var box := AABB()
	var first := true
	var inv := model.global_transform.affine_inverse()
	for v in model.find_children("*", "VisualInstance3D", true, false):
		var vi := v as VisualInstance3D
		vi.layers |= VIEW_LAYER
		var b := inv * (vi.global_transform * vi.get_aabb())
		box = b if first else box.merge(b)
		first = false
	if not first:
		view_middle = box.get_center()
		view_radius = maxf(box.size.length() * 0.5, 0.1)


## Builds the hologram again from the open design.
func rebuild() -> void:
	for c in model.get_children():
		model.remove_child(c)
		c.queue_free()
	_layer_nodes = {}
	_materials = []
	var rec := bus.library.current if bus else null
	if rec == null or rec.rooms.is_empty() and rec.hull.is_empty():
		return
	var b := rec.bounds()
	var levels := rec.decks()
	var height := (levels[levels.size() - 1] + 1) * rec.deck_height
	var long_side := maxf(b.size.x, b.size.y)
	var short_side := minf(b.size.x, b.size.y)
	align = 0.0 if b.size.x >= b.size.y else PI * 0.5
	scale_fit = minf(minf(FIT.x / maxf(long_side, 1.0), FIT.y / maxf(short_side, 1.0)),
			(MODEL_TOP - TABLE_HEIGHT - 0.3) / maxf(height, 1.0))
	# Model space: the design's middle over the table axis, its lowest deck on the table.
	var inner := Node3D.new()
	inner.name = "Ship"
	inner.position = Vector3(-b.get_center().x, 0, -b.get_center().y)
	model.add_child(inner)
	model.position = Vector3(0, TABLE_HEIGHT + 0.15, 0)
	for layer in LAYERS:
		var n := Node3D.new()
		n.name = layer.capitalize()
		n.visible = layers.get(layer, false)
		inner.add_child(n)
		_layer_nodes[layer] = n
	_build_rooms(rec, _layer_nodes.rooms)
	_build_frame(rec, _layer_nodes.frame)
	_build_plates(rec, _layer_nodes.plates)
	_build_components(rec, _layer_nodes.components)
	_build_runs(rec, _layer_nodes.wiring, "wiring")
	_build_runs(rec, _layer_nodes.pipes, "pipes")
	_build_power(rec, _layer_nodes.power)


func _mat(col: Color, alpha: float, rim := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HoloShader
	m.set_shader_parameter("tint", Color(col, alpha))
	m.set_shader_parameter("rim", rim)
	m.set_shader_parameter("cut_y", _cut_y)
	_materials.append(m)
	return m


func _box(parent: Node3D, centre: Vector3, sz: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = centre
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _lines(parent: Node3D, segments: PackedVector3Array, mat: Material) -> void:
	if segments.is_empty():
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for p in segments:
		im.surface_add_vertex(p)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _box_edges(lo: Vector3, hi: Vector3, out: PackedVector3Array) -> void:
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
			Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	for i in 4:
		out.append_array([c[i], c[(i + 1) % 4], c[i + 4], c[(i + 1) % 4 + 4], c[i], c[i + 4]])


func _room_box(rec: DesignRecord, r: Dictionary) -> AABB:
	var y := float(r.deck) * rec.deck_height
	return AABB(Vector3(r.x, y, r.z), Vector3(r.w, rec.deck_height, r.d))


func _build_rooms(rec: DesignRecord, parent: Node3D) -> void:
	var edges := PackedVector3Array()
	for r: Dictionary in rec.rooms.values():
		var rt := bus.catalog.room(str(r.type))
		var col := rt.colour if rt else HOLO
		var lit := lit_rooms.has(r.id)
		var box := _room_box(rec, r)
		var inset := Vector3(0.08, 0.08, 0.08)
		_box(parent, box.get_center(), box.size - inset, _mat(col, 0.12 if lit else 0.035, 1.2 if lit else 0.6))
		_box_edges(box.position + inset * 0.5, box.end - inset * 0.5, edges)
	_lines(parent, edges, _mat(HOLO, 0.4))
	# Doors: a bright frame in the wall.
	var door_edges := PackedVector3Array()
	for door: Dictionary in rec.doors.values():
		var y := float(door.deck) * rec.deck_height
		var ra := rec.room_rect(str(door.a))
		var p := Vector3(door.x, y, door.z)
		var along_x := absf(p.z - ra.position.y) < 0.05 or absf(p.z - ra.end.y) < 0.05
		var half := Vector3(0.5, 0, 0) if along_x else Vector3(0, 0, 0.5)
		var top := Vector3(0, 2.1, 0)
		door_edges.append_array([p - half, p - half + top, p - half + top, p + half + top, p + half + top, p + half])
	_lines(parent, door_edges, _mat(Color(0.6, 1.0, 0.95), 0.95))


## The open design's proposed frame, the bus's copy (worked out once per edit).
func _plan(rec: DesignRecord) -> Dictionary:
	return bus.frame_plan() if bus and rec == bus.library.current else DesignFrame.propose(rec)


## The frame the hull is built on (DesignFrame.propose): a ring round every station, joined
## corner to corner by stringers.
func _build_frame(rec: DesignRecord, parent: Node3D) -> void:
	var plan := _plan(rec)
	var h := rec.deck_height
	var segs := PackedVector3Array()
	var st: Array = plan.get("stations", [])
	for i in st.size():
		var a: PackedVector2Array = st[i].profile
		var z := float(st[i].z)
		for k in a.size():
			var q := a[(k + 1) % a.size()]
			segs.append_array([Vector3(a[k].x, a[k].y, z), Vector3(q.x, q.y, z)])
			if i > 0:
				var pa: PackedVector2Array = st[i - 1].profile
				segs.append_array([Vector3(pa[k].x, pa[k].y, float(st[i - 1].z)), Vector3(a[k].x, a[k].y, z)])
	# Beams placed by hand, under the deckhead.
	for bm: Dictionary in rec.beams.values():
		var y := (float(bm.deck) + 1.0) * h - 0.08
		var a := DesignStructure._v(bm.a)
		var e := DesignStructure._v(bm.b)
		segs.append_array([Vector3(a.x, y, a.y), Vector3(e.x, y, e.y)])
	_lines(parent, segs, _mat(Color(1.0, 0.7, 0.35), 0.8))


## The outer hull plating (walls facing space) and the inner walls, as see-through panels.
func _build_plates(rec: DesignRecord, parent: Node3D) -> void:
	var st := bus.structure() if bus and rec == bus.library.current else DesignStructure.measure(rec)
	var h := rec.deck_height
	var outer := _mat(Color(0.7, 0.8, 0.9), 0.14, 0.6)
	var inner := _mat(Color(0.6, 0.75, 0.9), 0.07, 0.4)
	var plan := _plan(rec)
	_build_skin(plan, parent, outer, _mat(Color(0.45, 0.75, 1.0), 0.3, 0.9))
	var edges: Array = [[st.inner_edges, inner, 0.04]]
	if plan.is_empty():
		edges.append([st.outer_edges, outer, 0.06])
	for list: Array in edges:
		for e: Dictionary in list[0]:
			var a: Vector2 = e.a
			var b: Vector2 = e.b
			var mid := (a + b) * 0.5
			var t: float = list[2]
			# Along the edge, turned to it, so a hull's angled sides plate too.
			var pane := _box(parent, Vector3(mid.x, float(e.deck) * h + h * 0.5, mid.y),
					Vector3(a.distance_to(b), h, t), list[1])
			pane.rotation.y = -(b - a).angle()
	# Decks with a drawn hull are plated out to it.
	for deck in rec.decks():
		var outline := rec.hull_outline(deck)
		if outline.size() < 3:
			continue
		var tris := Geometry2D.triangulate_polygon(outline)
		if tris.is_empty():
			continue
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y := float(deck) * h + 0.03
		for i in tris:
			st2.add_vertex(Vector3(outline[i].x, y, outline[i].y))
		var mi := MeshInstance3D.new()
		mi.name = "HullDeck_%d" % deck
		mi.mesh = st2.commit()
		mi.material_override = outer
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	for r: Dictionary in rec.rooms.values():
		if rec.hull_outline(int(r.deck)).size() >= 3:
			continue
		var box := _room_box(rec, r)
		_box(parent, Vector3(box.get_center().x, box.position.y + 0.03, box.get_center().z),
				Vector3(box.size.x, 0.06, box.size.z), outer)


## The skin over the frame: a see-through panel over each face from ring to ring (glass ones
## bluer), and the end plates.
func _build_skin(plan: Dictionary, parent: Node3D, metal: Material, glass: Material) -> void:
	if plan.is_empty():
		return
	var st: Array = plan.stations
	var panes: Dictionary = plan.glass
	for which in 2:
		var tris := PackedVector3Array()
		for i in range(1, st.size()):
			var a: PackedVector2Array = st[i - 1].profile
			var b: PackedVector2Array = st[i].profile
			var za := float(st[i - 1].z)
			var zb := float(st[i].z)
			for k in a.size():
				if panes.has("%d:%d" % [i - 1, k]) != (which == 1):
					continue
				var k1 := (k + 1) % a.size()
				var p0 := Vector3(a[k].x, a[k].y, za)
				var p1 := Vector3(a[k1].x, a[k1].y, za)
				var p2 := Vector3(b[k1].x, b[k1].y, zb)
				var p3 := Vector3(b[k].x, b[k].y, zb)
				tris.append_array([p0, p1, p2, p0, p2, p3])
		if which == 0:
			for end in 2:
				var o: PackedVector2Array = st[0 if end == 0 else st.size() - 1].profile
				var z := float(st[0 if end == 0 else st.size() - 1].z)
				for k in range(1, o.size() - 1):
					tris.append_array([Vector3(o[0].x, o[0].y, z), Vector3(o[k].x, o[k].y, z), Vector3(o[k + 1].x, o[k + 1].y, z)])
		if tris.is_empty():
			continue
		var stool := SurfaceTool.new()
		stool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in tris:
			stool.add_vertex(v)
		var mi := MeshInstance3D.new()
		mi.name = "Skin" if which == 0 else "SkinGlass"
		mi.mesh = stool.commit()
		mi.material_override = metal if which == 0 else glass
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


func _build_components(rec: DesignRecord, parent: Node3D) -> void:
	for c: Dictionary in rec.components.values():
		var pt := bus.catalog.part(str(c.type))
		var r: Dictionary = rec.rooms.get(c.room, {})
		if pt == null or r.is_empty():
			continue
		var f := DesignRules.footprint(c, pt)
		var y := float(r.deck) * rec.deck_height
		var h := minf(pt.size.y, rec.deck_height - 0.1)
		_box(parent, Vector3(f.get_center().x, y + h * 0.5 + 0.05, f.get_center().y),
				Vector3(f.size.x, h, f.size.y), _mat(pt.colour, 0.3, 0.8))
	# Parts on the hull stand out from its side.
	for m: Dictionary in rec.mounts.values():
		var mp := bus.catalog.part(str(m.type))
		if mp == null:
			continue
		var n := Vector2.from_angle(float(m.angle))
		var at := Vector2(float(m.x), float(m.z)) + n * mp.size.z * 0.5
		var h := minf(mp.size.y, rec.deck_height - 0.1)
		var box := _box(parent, Vector3(at.x, float(m.deck) * rec.deck_height + rec.deck_height * 0.5, at.y),
				Vector3(mp.size.z, h, mp.size.x), _mat(mp.colour, 0.35, 0.9))
		box.rotation.y = -float(m.angle)


## Wires (just under the deckhead) or pipes (just over the floor), and the risers between
## decks where a run ends over another.
func _build_runs(rec: DesignRecord, parent: Node3D, layer: String) -> void:
	var h := rec.deck_height
	for kind: String in DesignServices.KINDS:
		var spec: Dictionary = DesignServices.KINDS[kind]
		if str(spec.layer) != layer:
			continue
		var segs := PackedVector3Array()
		var lift := h - 0.35 if layer == "wiring" else 0.35
		for w: Dictionary in rec.runs.values():
			if str(w.kind) != kind:
				continue
			var y := float(w.deck) * h + lift
			var pts := DesignServices.points(w)
			for i in pts.size() - 1:
				segs.append_array([Vector3(pts[i].x, y, pts[i].y), Vector3(pts[i + 1].x, y, pts[i + 1].y)])
			# Risers: from each end up to the deck above if a run of this kind continues there.
			for e in [pts[0], pts[pts.size() - 1]]:
				for o: Dictionary in rec.runs.values():
					if str(o.kind) == kind and int(o.deck) == int(w.deck) + 1:
						var op := DesignServices.points(o)
						if op[0].distance_to(e) <= DesignServices.JOIN or op[op.size() - 1].distance_to(e) <= DesignServices.JOIN:
							segs.append_array([Vector3(e.x, y, e.y), Vector3(e.x, y + h, e.y)])
		_lines(parent, segs, _mat(spec.colour, 1.0))


func _build_power(rec: DesignRecord, parent: Node3D) -> void:
	# Until wiring is designed: a line from each source to each user, so the load is visible.
	var sources: Array[Vector3] = []
	var users: Array[Vector3] = []
	for c: Dictionary in rec.components.values():
		var pt := bus.catalog.part(str(c.type))
		var r: Dictionary = rec.rooms.get(c.room, {})
		if pt == null or r.is_empty() or is_zero_approx(pt.power):
			continue
		var p := Vector3(c.x, float(r.deck) * rec.deck_height + 0.4, c.z)
		if pt.power > 0.0:
			sources.append(p)
		else:
			users.append(p)
	var segs := PackedVector3Array()
	for u in users:
		var best := Vector3.INF
		for s in sources:
			if best == Vector3.INF or s.distance_to(u) < best.distance_to(u):
				best = s
		if best != Vector3.INF:
			segs.append_array([best, u])
	_lines(parent, segs, _mat(Color(0.5, 1.0, 0.5), 0.9))


func _apply_cut() -> void:
	var rec := bus.library.current if bus else null
	var y := 100.0
	if rec and cut < 0.999 and model:
		var levels := rec.decks()
		var height := (levels[levels.size() - 1] + 1) * rec.deck_height
		y = model.global_position.y + height * cut * scale_fit * zoom
	if is_equal_approx(y, _cut_y):
		return
	_cut_y = y
	for m in _materials:
		m.set_shader_parameter("cut_y", _cut_y)


func _build_table() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.2, 0.22, 0.25)
	steel.metallic = 0.7
	steel.roughness = 0.4
	# A plinth under the middle, set back from the edges so people can stand close.
	_solid("Base", Vector3(TABLE_SIZE.x - 1.2, TABLE_HEIGHT - 0.1, TABLE_SIZE.y - 1.0),
			Vector3(0, (TABLE_HEIGHT - 0.1) * 0.5, 0), steel)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.12, 0.18)
	glass.emission_enabled = true
	glass.emission = Color(0.1, 0.35, 0.5)
	glass.emission_energy_multiplier = 0.6
	glass.metallic = 0.3
	glass.roughness = 0.15
	_solid("Top", Vector3(TABLE_SIZE.x, 0.1, TABLE_SIZE.y), Vector3(0, TABLE_HEIGHT - 0.05, 0), glass)
	# A glowing rim round the top's edge.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.45, 0.9, 1.0)
	var half := TABLE_SIZE * 0.5
	var rim := Node3D.new()
	rim.name = "Ring"
	add_child(rim)
	# The rim stands on the top (2 mm clear) and the short sides fit between the long ones, so
	# no two faces share a plane (test_zfight).
	for sz: float in [-1.0, 1.0]:
		_solid("Long", Vector3(TABLE_SIZE.x, 0.04, 0.06), Vector3(0, TABLE_HEIGHT + 0.022, sz * (half.y - 0.03)), glow, rim)
		_solid("Short", Vector3(0.06, 0.036, TABLE_SIZE.y - 0.13), Vector3(sz * (half.x - 0.03), TABLE_HEIGHT + 0.02, 0), glow, rim)
	for sx: float in [-1.0, 1.0]:
		var light := OmniLight3D.new()
		light.light_color = Color(0.45, 0.85, 1.0)
		light.light_energy = 0.7
		light.omni_range = 5.0
		light.position = Vector3(sx * half.x * 0.5, TABLE_HEIGHT + 1.2, 0)
		light.name = "HoloGlow"
		add_child(light, true)


func _solid(id: String, sz: Vector3, at: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = at
	mi.material_override = mat
	mi.name = id
	parent.add_child(mi, true)
	return mi
