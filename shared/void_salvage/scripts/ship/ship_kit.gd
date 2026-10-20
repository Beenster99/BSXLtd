class_name ShipKit
extends RefCounted
## Builds a ship's hull and fittings into a RigidBody3D from PartShapes: every piece gets
## a mesh and a collision shape on the body. Pieces can be tagged so the ship can find them
## again (things you use, doors that slide, the lift).
##
## Not for salvage wrecks (those use ShipBuilder, with joints between parts). This is for
## ships that hold together: the players' base ship.

var body: RigidBody3D
## Tag -> Array of pieces: {mesh: MeshInstance3D, shape: CollisionShape3D, xform}
var tagged: Dictionary = {}
## Total volume of solid metal added, m^3 (the ship works out its mass from it).
var volume: float = 0.0
## Every piece's bounds and how far its look is pulled in from its true size. Pieces that
## touch get different pull-ins, so where two of them share a face (a wall meeting a floor)
## one face sits a hair behind the other instead of flickering (z-fighting).
var _bounds: Array[AABB] = []
var _insets: Array[int] = []
const INSET_STEP: float = 0.0007   # metres per step
const INSET_STEPS: int = 10


func _init(target: RigidBody3D) -> void:
	body = target


## Adds `shape` at `xform` (ship space) with `mat` (plain paint goes on the ship surface
## shader, ShipSurface). Returns the piece {mesh, shape}.
func add(shape: PartShapes.PartShape, xform: Transform3D, mat: Material, tag: String = "",
		glass_mat: Material = null, solid: bool = true) -> Dictionary:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.material_override = ShipSurface.of(mat)
	var vis := _inset(shape.mesh.get_aabb(), xform)
	mi.transform = xform * vis
	body.add_child(mi)
	if shape.glass and glass_mat:
		var g := MeshInstance3D.new()
		g.mesh = shape.glass
		g.material_override = glass_mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(g)
	var piece := {"mesh": mi, "xform": xform, "vis": vis}
	if solid:
		var col := CollisionShape3D.new()
		col.shape = shape.collision
		col.transform = xform
		body.add_child(col)
		piece["shape"] = col
	volume += shape.volume
	if tag != "":
		(tagged.get_or_add(tag, []) as Array).append(piece)
	return piece


## Shrinks a piece's look very slightly (never its collision), by an amount no piece it
## touches already uses. Returns the scale to apply to its mesh.
func _inset(local_box: AABB, xform: Transform3D) -> Transform3D:
	var box := xform * local_box
	var grown := box.grow(0.01)
	var used := {}
	for i in _bounds.size():
		if grown.intersects(_bounds[i]):
			used[_insets[i]] = true
	var step := 1
	while used.has(step) and step < INSET_STEPS:
		step += 1
	_bounds.append(box)
	_insets.append(step)
	var size := local_box.size
	var inset := INSET_STEP * float(step)
	# Thin pieces (screens, stripes) give up at most a fifth of their thickness.
	var s := Vector3.ONE
	for axis in 3:
		var d := maxf(size[axis], 0.001)
		s[axis] = 1.0 - 2.0 * minf(inset, d * 0.1) / d
	var centre := local_box.get_center()
	# Scale about the piece's own centre.
	return Transform3D(Basis.from_scale(s), centre - centre * s)


## A model from the asset kit (KitParts) at `xform`, scaled by `scale`. With `solid`, a box
## round it collides. Returns the piece {mesh, xform, vis[, shape]} (it can be tagged and
## moved like any other).
func model(model_name: String, xform: Transform3D, scale := Vector3.ONE, tag: String = "",
		solid: bool = false) -> Dictionary:
	var node := KitParts.make(model_name)
	if node == null:
		push_warning("ShipKit: no kit model '%s'" % model_name)
		return {}
	var vis := Transform3D(Basis.from_scale(scale), Vector3.ZERO)
	node.transform = xform * vis
	body.add_child(node)
	var piece := {"mesh": node, "xform": xform, "vis": vis}
	if solid:
		var box := KitParts.bounds(model_name)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = (box.size * scale).max(Vector3.ONE * 0.04)
		col.shape = shape
		col.transform = xform * Transform3D(Basis(), box.get_center() * scale)
		body.add_child(col)
		piece["shape"] = col
	if tag != "":
		(tagged.get_or_add(tag, []) as Array).append(piece)
	return piece


## A plain box from corner `a` to corner `b` (ship space).
func block(a: Vector3, b: Vector3, mat: Material, tag: String = "") -> Dictionary:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return add(PartShapes.box(hi - lo), Transform3D(Basis(), (lo + hi) * 0.5), mat, tag)


## A flat wall in a plane, as boxes around rectangular `holes` (doorways, windows). The
## wall spans `u0..u1` by `v0..v1` in the plane's own axes, `thickness` thick, centred on
## `at` along its normal. `axis` picks the plane: "x" = wall facing X (u = z, v = y),
## "z" = facing Z (u = x, v = y), "y" = floor or ceiling (u = x, v = z).
## Each hole is Rect2(u, v, width, height).
func wall(axis: String, at: float, u0: float, u1: float, v0: float, v1: float,
		thickness: float, holes: Array, mat: Material, tag: String = "") -> void:
	# Split the wall into strips between holes: columns along u, then rows inside each.
	var cuts: Array[float] = [u0, u1]
	for h: Rect2 in holes:
		cuts.append(clampf(h.position.x, u0, u1))
		cuts.append(clampf(h.position.x + h.size.x, u0, u1))
	cuts.sort()
	for i in cuts.size() - 1:
		var a := cuts[i]
		var b := cuts[i + 1]
		if b - a < 0.005:
			continue
		var mid := (a + b) * 0.5
		var spans: Array = [[v0, v1]]
		for h: Rect2 in holes:
			if mid > h.position.x and mid < h.position.x + h.size.x:
				var next: Array = []
				for s: Array in spans:
					var lo: float = s[0]
					var hi: float = s[1]
					var hlo := h.position.y
					var hhi := h.position.y + h.size.y
					if hhi <= lo or hlo >= hi:
						next.append(s)
						continue
					if hlo > lo:
						next.append([lo, hlo])
					if hhi < hi:
						next.append([hhi, hi])
				spans = next
		for s: Array in spans:
			if (s[1] as float) - (s[0] as float) < 0.005:
				continue
			_wall_piece(axis, at, a, b, s[0], s[1], thickness, mat, tag)


func _wall_piece(axis: String, at: float, a: float, b: float, lo: float, hi: float,
		t: float, mat: Material, tag: String) -> void:
	var h := t * 0.5
	match axis:
		"x":
			block(Vector3(at - h, lo, a), Vector3(at + h, hi, b), mat, tag)
		"z":
			block(Vector3(a, lo, at - h), Vector3(b, hi, at + h), mat, tag)
		_:
			block(Vector3(a, at - h, lo), Vector3(b, at + h, hi), mat, tag)


## A light hanging at `at` (ship space).
func light(at: Vector3, color: Color, energy: float, reach: float, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = shadows
	l.position = at
	body.add_child(l)
	return l


static func paint(color: Color, metallic: float = 0.4, roughness: float = 0.55, finish: String = "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if finish != "":
		m.set_meta("finish", finish)   # the SurfaceFinish it shows (ShipSurface.finish_for)
	return m


static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.03)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.65, 0.85, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.4
	m.roughness = 0.04
	return m


## A monospace system font so readout columns line up (labels, screens, the HUD); falls back
## to the default font.
static var _font: SystemFont


## One shared monospace font (a fresh one per call would reload its glyphs every time,
## and text drawn each frame would show as blocks).
static func mono_font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Consolas", "Menlo", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	return _font
