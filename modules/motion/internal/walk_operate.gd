extends Node3D
## OPERATE in walk-inside: the same moves at full size round you, the moving pieces solid
## enough to read, the swept volume a faint glow (red where it hits something), and through
## each opening a test block (MotionBus.BLOCKS: the biggest that fits, green; a crate in red
## when nothing does) once it is open. SET HER DOWN keeps her legs down. Built under the walk's
## design root (design space, metres) and rebuilt with it.

const CLEAR := Color(0.35, 1.0, 0.85)
const CLASH := Color(1.0, 0.25, 0.2)
const PIECE := Color(0.95, 0.75, 0.3)

var bus: MotionBus
var parts: Dictionary = {}
var blocks: Dictionary = {}
## mover id -> the part as walk-inside drew it (its body: "Part_<id>" or "Mount_<id>"), hidden
## while our moving pieces stand in for it.
var drawn: Dictionary = {}
## mover id -> {model: Node3D, id: String, motion: Dictionary}: a part drawn with its own moving
## 3D model (the part_models module's), posed as it moves instead of a stand-in.
var models: Dictionary = {}


func setup(motion_bus: MotionBus) -> void:
	bus = motion_bus
	var root := get_parent()
	var r := bus.report()
	if r.is_empty():
		return
	var fits := {}
	for o: Dictionary in r.openings:
		fits[o.id] = o
	# The part models module is optional: reached by name.
	var pm := Modules.bus("part_models")
	for mv: Dictionary in r.movers:
		var body: Node = null
		if root and mv.kind != "door":
			body = root.find_child(("Part_" if mv.kind == "component" else "Mount_") + str(mv.ref), true, false)
		var model: Node3D = null
		if body and pm and pm.has_method("find_model"):
			model = pm.call("find_model", body)
		var motion: Dictionary = pm.call("motion", str(model.get_meta("part_model"))) if model else {}
		if model and not (motion.get("pieces", []) as Array).is_empty():
			models[mv.id] = {"model": model, "id": str(model.get_meta("part_model")), "motion": motion}
		elif body:
			drawn[mv.id] = body
		_add(mv, r.clashes.has(mv.id), fits.get(mv.id, {}), models.has(mv.id))
	bus.operate_changed.connect(_show)
	_show()


func _exit_tree() -> void:
	if bus and bus.operate_changed.is_connected(_show):
		bus.operate_changed.disconnect(_show)


static func _mat(col: Color, alpha: float, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = glow
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _box(parent: Node3D, xf: Transform3D, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _add(mv: Dictionary, clash: bool, opening: Dictionary, real_model := false) -> void:
	var holder := Node3D.new()
	holder.name = "Mover_" + str(mv.id).replace(":", "_")
	add_child(holder)
	var pieces: Array[MeshInstance3D] = []
	var pm := _mat(CLASH if clash else PIECE, 0.9, 1.3)
	# Walk-inside opens its own doors as you come near: a door shows only its sweep and block.
	# A part with its own moving model shows that, posed: no stand-in.
	for p: Dictionary in (MotionMovers.pieces(mv, 0.0) if mv.kind != "door" and not real_model else []):
		var mi := _box(holder, p.xf, p.size, pm)
		mi.name = str(p.name)
		pieces.append(mi)
	var sweep := Node3D.new()
	sweep.name = "Sweep"
	holder.add_child(sweep)
	var sm := _mat(CLASH if clash else CLEAR, 0.08 if not clash else 0.14, 1.0)
	var steps := MotionMovers.SWEEP_STEPS
	for i in range(0, steps + 1, 3):
		for p: Dictionary in MotionMovers.pieces(mv, float(i) / steps):
			_box(sweep, p.xf, p.size, sm)
	parts[mv.id] = {"mv": mv, "pieces": pieces, "sweep": sweep}
	if opening.is_empty() or mv.kind == "mount" and str(mv.spec.kind) != "hinge_out":
		return
	# The test block, standing in the opening.
	var best: Dictionary = {}
	for b: Dictionary in MotionBus.BLOCKS:
		if bool(opening.fits.get(b.id, false)):
			best = b
	var ok := not best.is_empty()
	var size: Vector3 = (best if ok else MotionBus.BLOCKS[0]).size
	var depth := minf(size.z, 1.2)
	var at := Vector3(0, size.y * 0.5 + 0.02, -0.3 - depth * 0.5) if mv.kind != "door" else Vector3(0, size.y * 0.5 + 0.02, 0)
	var block := _box(holder, (mv.base as Transform3D) * Transform3D(Basis.IDENTITY, at),
			Vector3(size.x, size.y, depth), _mat(CLEAR if ok else CLASH, 0.35, 1.0))
	block.name = "TestBlock"
	blocks[mv.id] = block


## Poses a part's own model at t: its hinges and slides through the part models module, its
## turning pieces (spin) swung across their travel here.
func pose_model(m: Dictionary, t: float, spin_half_deg: float) -> void:
	var pm := Modules.bus("part_models")
	if pm:
		pm.call("pose", m.model, m.id, t)
	for pc: Dictionary in m.motion.get("pieces", []):
		if str(pc.get("kind", "")) != "spin":
			continue
		var node := (m.model as Node3D).find_child(str(pc.name), true, false) as Node3D
		if node == null:
			continue
		if not node.has_meta("spin_rest"):
			node.set_meta("spin_rest", node.transform)
		var rest: Transform3D = node.get_meta("spin_rest")
		var a: Array = pc.get("axis", [0, 1, 0])
		var axis := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
		var ang := deg_to_rad(spin_half_deg) * sin(t * PI * 2.0)
		node.transform = Transform3D(rest.basis * Basis(axis, ang), rest.origin)


func _show() -> void:
	for id: String in parts:
		var p: Dictionary = parts[id]
		var leg := str(p.mv.spec.kind) == "leg"
		(p.sweep as Node3D).visible = bus.operating
		for mi: MeshInstance3D in p.pieces:
			mi.visible = bus.operating or (leg and bus.grounded)
	for id: String in blocks:
		(blocks[id] as Node3D).visible = false
	# Parts with their own model rest stowed, or legs down when she is set down.
	for id: String in models:
		var p: Dictionary = parts.get(id, {})
		if not p.is_empty():
			pose_model(models[id], bus.phase_of(p.mv), MotionMovers.spin_half(p.mv))
	for id: String in drawn:
		var p: Dictionary = parts.get(id, {})
		var stand_in := bus.operating or (not p.is_empty() and str(p.mv.spec.kind) == "leg" and bus.grounded)
		for v in (drawn[id] as Node).find_children("*", "VisualInstance3D", true, false):
			(v as VisualInstance3D).visible = not stand_in


func _process(_delta: float) -> void:
	if bus == null or not (bus.operating or bus.grounded):
		return
	var now := Time.get_ticks_msec()
	for id: String in parts:
		var p: Dictionary = parts[id]
		var t := bus.phase_of(p.mv, now)
		var ps := MotionMovers.pieces(p.mv, t)
		var meshes: Array[MeshInstance3D] = p.pieces
		for i in mini(ps.size(), meshes.size()):
			meshes[i].transform = ps[i].xf
			var bm := meshes[i].mesh as BoxMesh
			if not bm.size.is_equal_approx(ps[i].size):
				bm.size = ps[i].size
		if blocks.has(id):
			(blocks[id] as Node3D).visible = bus.operating and t > 0.98
		if models.has(id):
			pose_model(models[id], t, MotionMovers.spin_half(p.mv))
