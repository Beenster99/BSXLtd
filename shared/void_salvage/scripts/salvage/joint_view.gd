class_name JointView
extends RefCounted
## What a connection looks like: a rivet head, a hex bolt head, a weld bead, a loom
## connector (a plug sleeve around a wiring loom where two spans meet), or a spot weld (a
## small round puddle where a fitting is tacked to a plate).
##
## Presentation only; the joint's real state is its ConnectionData. It shows two things:
##   heat: glows orange-white while a tool works it, then cools over a few seconds
##   wear: shrinks into the surface as its health drops (a bolt instead backs out of
##         its hole, turning, its threaded shank showing as the socket unscrews it)
## When the joint breaks, the head pops off and tumbles away as a small loose piece.
##
## Not a node: each view is one instance in its structure's JointBatch (a MultiMesh per
## kind of head), so a wreck's thousands of joints are a few draw calls. The structure
## ticks hot views (`cool`) and tells views when their part moves (`set_part_xform`).

## How fast heat fades, per second (1.0 = full glow).
const COOL_RATE: float = 0.45
## How far a bolt backs out of its hole before it comes free, metres (its shank's length).
const BOLT_TRAVEL: float = 0.07
## Turns a bolt makes while backing out all the way.
const BOLT_TURNS: float = 6.0
## Seconds a popped-off head lasts before it is cleared away.
const DEBRIS_LIFETIME: float = 10.0
## Seconds an unscrewed bolt drifts and tumbles about before it is cleared away (5 min).
const BOLT_LIFETIME: float = 300.0
## Most loose bolts kept at once; past this the oldest goes first.
const MAX_LOOSE_BOLTS: int = 150
const LOOSE_BOLTS := "loose_bolts"
## Every popped-off head and loose bolt (ships' deck gravity pulls on these too).
const DEBRIS := "joint_debris"

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

var connection: ConnectionData
## 0 = cold, 1 = glowing hot.
var heat: float = 0.0
## The drawn instance (mesh, material, transform in structure space).
var item: JointBatch.Item

var _batch: JointBatch
var _height: float
## The head's rest transform in its part's space (on the joint's surface point, +Y along
## its normal) and the part's transform in the structure.
var _anchor: Transform3D
var _part_xform: Transform3D
## Weld beads change mesh as they're ground down instead of squashing.
var _is_bead: bool = false
var _bead_level: int = -1
## A bolt being unscrewed: its shank, drawn under the head once it starts to back out.
var _shank_item: JointBatch.Item


## Builds the view for `c` on part `part_xform` (relative to the structure), drawn by
## `batch`.
func setup(c: ConnectionData, part_xform: Transform3D, batch: JointBatch) -> void:
	connection = c
	_batch = batch
	_part_xform = part_xform
	_height = _height_for(c.kind, c.head)
	_is_bead = c.kind == ConnectionData.Kind.WELD
	# Anchor: on the joint's surface point, local +Y along its normal, in the part's space.
	# A weld bead lies in the seam: X along seam_up, Y across the seam.
	var basis := _basis_from_normal(c.local_normal)
	if _is_bead and c.seam_up != Vector3.ZERO:
		var y := c.local_normal.normalized()
		var z := c.seam_up.cross(y).normalized()
		basis = Basis(y.cross(z).normalized(), y, z)
	_anchor = part_xform.affine_inverse() * Transform3D(basis, c.local_position)
	item = JointBatch.Item.new(_mesh_for(c.kind, c.head), head_material(c.kind, c.head), Transform3D.IDENTITY)
	item.custom = Color(0.0, _seized_flag(), 0.0, 0.0)
	_apply_wear()
	_batch.add(item)


## The structure's transform for this view's instance (structure space).
func structure_transform() -> Transform3D:
	return item.xform


## Cools a hot head; returns false once it is cold (the structure stops ticking it).
func cool(delta: float) -> bool:
	heat = maxf(heat - COOL_RATE * delta, 0.0)
	_apply_heat()
	return heat > 0.0


## Adds glow as a tool works this joint (1.0 = full glow). Returns true if it was cold
## before (the structure starts ticking it).
func add_heat(amount: float) -> bool:
	var was_cold := heat <= 0.0
	heat = minf(heat + amount, 1.0)
	_apply_heat()
	return was_cold


## Re-reads health after damage, so the head shrinks to match.
func refresh() -> void:
	_apply_wear()


## The part this head hangs on moved (a door leaf, a bent plate): follow it.
func set_part_xform(part_xform: Transform3D) -> void:
	_part_xform = part_xform
	_apply_wear()


## Hands the view to another structure's batch (its part split off; the piece starts with
## the same transform as this structure, so the instance transform stays valid).
func move_to(batch: JointBatch) -> void:
	_batch.move(item, batch)
	if _shank_item:
		_batch.move(_shank_item, batch)
	_batch = batch


## Stops drawing the head (the joint is gone quietly).
func clear() -> void:
	_batch.remove(item)
	_clear_shank()


func _clear_shank() -> void:
	if _shank_item:
		_batch.remove(_shank_item)
		_shank_item = null


## Detaches the head as a small loose physics piece flying off along the normal, then
## removes this view. `model` holds the body it was on.
func pop_off(model: PartModel, carrier_velocity: Vector3) -> void:
	if _is_bead or connection.kind == ConnectionData.Kind.SPOT:
		leave_scar(model)
		return
	var structure := model.body
	var world_xform := structure.global_transform * item.xform
	_batch.remove(item)
	_clear_shank()
	var bolt := connection.kind == ConnectionData.Kind.BOLT
	var debris := RigidBody3D.new()
	debris.name = "LooseBolt" if bolt else "JointDebris"
	debris.gravity_scale = 0.0
	debris.mass = 0.2
	debris.collision_layer = 0  # too small to matter; keeps it out of tool rays
	debris.collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.04
	shape.shape = sphere
	debris.add_child(shape)
	var visual := MeshInstance3D.new()
	visual.mesh = item.mesh
	visual.material_override = item.material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Keep the worn-down squash on the mesh only: physics bodies can't be squashed.
	visual.scale = world_xform.basis.get_scale()
	debris.add_child(visual)
	if bolt:
		# The whole bolt comes out: a threaded shank under the head.
		var shank := MeshInstance3D.new()
		shank.mesh = _shank_mesh()
		shank.material_override = item.material
		shank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shank.position = Vector3(0.0, -_height * 0.5 - 0.035, 0.0)
		debris.add_child(shank)
		sphere.radius = 0.035
	var tree := structure.get_tree()
	var world := tree.current_scene if tree.current_scene else tree.root
	world.add_child(debris)
	debris.add_to_group(DEBRIS)
	# A little grip and no bounce, so it settles where there's gravity.
	debris.physics_material_override = _debris_material()
	debris.global_transform = world_xform.orthonormalized()
	var out := world_xform.basis.y.normalized()
	var jitter := Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
	if bolt:
		# Unscrewed: it backs out gently, spinning on its axis, and tumbles off.
		debris.add_to_group(LOOSE_BOLTS)
		debris.linear_velocity = carrier_velocity + out * randf_range(0.25, 0.5) + jitter * 0.4
		debris.angular_velocity = out * randf_range(10.0, 16.0) + jitter * 6.0
		var loose := tree.get_nodes_in_group(LOOSE_BOLTS)
		if loose.size() > MAX_LOOSE_BOLTS:
			(loose[0] as Node).queue_free()
	else:
		debris.linear_velocity = carrier_velocity + out * randf_range(0.6, 1.4) + jitter
		debris.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	tree.create_timer(BOLT_LIFETIME if bolt else DEBRIS_LIFETIME).timeout.connect(debris.queue_free)


static var _shank: Mesh
static var _debris_mat: PhysicsMaterial


static func _debris_material() -> PhysicsMaterial:
	if _debris_mat == null:
		_debris_mat = PhysicsMaterial.new()
		_debris_mat.friction = 0.8
		_debris_mat.bounce = 0.0
	return _debris_mat


## A bolt's shank, below its head (local -Y).
static func _shank_mesh() -> Mesh:
	if _shank == null:
		var m := CylinderMesh.new()
		m.top_radius = 0.022 * BOLT_SCALE
		m.bottom_radius = 0.022 * BOLT_SCALE
		m.height = 0.07
		m.radial_segments = 8
		m.rings = 1
		_shank = m
	return _shank


## A cut weld: what's left of the bead (or the spot) stays on the steel, dark and ground flat.
func leave_scar(model: PartModel) -> void:
	_batch.remove(item)
	if connection.kind == ConnectionData.Kind.SPOT:
		model.add_decor(connection.part_a, _mesh_for(ConnectionData.Kind.SPOT), scar_material(),
				_part_xform * _anchor * Transform3D(Basis().scaled(Vector3(1.0, 0.3, 1.0)), Vector3.ZERO))
		return
	model.add_decor(connection.part_a, bead_mesh(connection.seam_size, 0.3), scar_material(),
			_part_xform * _anchor)


## 1 on a seized bolt (it glows amber through the survey glass), else 0. The default seized
## chance: a socket tuned to another one sees a slightly different set.
func _seized_flag() -> float:
	return 1.0 if connection.kind == ConnectionData.Kind.BOLT and connection.is_seized(ConnectionData.SEIZED_CHANCE) else 0.0


func _apply_heat() -> void:
	item.custom = Color(heat, _seized_flag(), 0.0, 0.0)
	_batch.update(item)
	if _shank_item:
		_shank_item.custom = item.custom
		_batch.update(_shank_item)


func _apply_wear() -> void:
	var local: Transform3D
	if _is_bead:
		# Ground down in steps toward flush with the steel.
		var level := clampi(int(ceil(connection.health_fraction() * BEAD_LEVELS)), 1, BEAD_LEVELS)
		if level != _bead_level:
			_bead_level = level
			var mesh := bead_mesh(connection.seam_size, float(level) / float(BEAD_LEVELS), connection.head)
			if item.bucket != null:
				_batch.change_mesh(item, mesh)
			else:
				item.mesh = mesh
		local = _anchor
	elif connection.kind == ConnectionData.Kind.BOLT:
		# Unscrewed, not ground: the bolt backs out of its hole, turning as it goes, and its
		# threaded shank shows under the head.
		var out := 1.0 - connection.health_fraction()
		var turn := Basis(Vector3.UP, out * BOLT_TURNS * TAU)
		local = _anchor * Transform3D(turn, Vector3(0.0, _height * 0.5 + out * BOLT_TRAVEL, 0.0))
		_place_shank(out, turn)
	else:
		# Ground down from full height to a thin stub as health runs out.
		# Rivet and bolt heads shrink down onto the surface; connectors are sleeves centred
		# on the loom, so they shrink in place.
		var keep := lerpf(0.2, 1.0, connection.health_fraction())
		var centred := connection.kind == ConnectionData.Kind.CONNECTOR
		var lift := 0.0 if centred else _height * 0.5 * keep
		local = _anchor * Transform3D(Basis().scaled(Vector3(1.0, keep, 1.0)), Vector3(0.0, lift, 0.0))
	item.xform = _part_xform * local
	_batch.update(item)


## The bolt's shank, standing out of the hole by `out` of its length (0 = still home).
func _place_shank(out: float, turn: Basis) -> void:
	if out <= 0.001:
		_clear_shank()
		return
	# The shank mesh is centred on its length: it sits under the head, its lower part
	# still in the hole.
	var xform := _part_xform * _anchor * Transform3D(turn,
			Vector3(0.0, out * BOLT_TRAVEL - _shank_mesh_length() * 0.5, 0.0))
	if _shank_item == null:
		_shank_item = JointBatch.Item.new(_shank_mesh(), material_for(ConnectionData.Kind.BOLT), xform)
		_shank_item.custom = item.custom
		_batch.add(_shank_item)
	else:
		_shank_item.xform = xform
		_shank_item.custom = item.custom
		_batch.update(_shank_item)


static func _shank_mesh_length() -> float:
	return (_shank_mesh() as CylinderMesh).height


static func _basis_from_normal(n: Vector3) -> Basis:
	var up := n.normalized()
	var side := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := side.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)


## Head sizes against the originals (0.13: rivets 25% smaller again, bolts 35%).
const RIVET_SCALE: float = 0.75
const BOLT_SCALE: float = 0.65


## A flush rivet (head style 1): a low dome this wide and this high, metres.
const FLUSH_RADIUS: float = 0.024
const FLUSH_HEIGHT: float = 0.007
## A spot weld's puddle: this wide across and this high off the plate, metres.
const SPOT_RADIUS: float = 0.014
const SPOT_HEIGHT: float = 0.004


static func _height_for(kind: ConnectionData.Kind, head: int = 0) -> float:
	match kind:
		ConnectionData.Kind.RIVET:
			if head == 1:
				return FLUSH_HEIGHT
			return 0.032 * RIVET_SCALE   # metres
		ConnectionData.Kind.BOLT:
			return 0.042 * BOLT_SCALE
		ConnectionData.Kind.CONNECTOR:
			return 0.1
		ConnectionData.Kind.SPOT:
			return SPOT_HEIGHT
	return 0.07


## The batched head surface for a joint kind (one shared material each; heat is per
## instance, see shaders/joint_head.gdshader).
static func material_for(kind: ConnectionData.Kind) -> ShaderMaterial:
	if not _materials.has(kind):
		var color: Color = {
			ConnectionData.Kind.RIVET: Color(0.62, 0.62, 0.6),
			ConnectionData.Kind.BOLT: Color(0.58, 0.55, 0.42),
			ConnectionData.Kind.WELD: Color(0.27, 0.26, 0.27),
			ConnectionData.Kind.CONNECTOR: Color(0.16, 0.17, 0.19),
			ConnectionData.Kind.SPOT: Color(0.34, 0.33, 0.33),
		}[kind]
		var metallic := 0.3 if kind == ConnectionData.Kind.CONNECTOR else 0.8
		var roughness := 0.72 if kind == ConnectionData.Kind.WELD or kind == ConnectionData.Kind.SPOT else (0.5 if kind == ConnectionData.Kind.CONNECTOR else 0.35)
		_materials[kind] = _make_material(color, metallic, roughness)
	return _materials[kind]


## A joint's head surface: a weld's by its bead style (2 machine: clean steel, 3 ground:
## bright where it was ground flush; FrameStyle), every other kind by its kind.
static func head_material(kind: ConnectionData.Kind, head: int) -> ShaderMaterial:
	if kind != ConnectionData.Kind.WELD or head < 2:
		return material_for(kind)
	var key := "weld:%d" % head
	if not _materials.has(key):
		_materials[key] = _make_material(Color(0.46, 0.46, 0.47), 0.85, 0.42) if head == 2 \
				else _make_material(Color(0.58, 0.58, 0.6), 0.9, 0.3)
	return _materials[key]


## Dark, ground-flat remains of a cut weld.
static func scar_material() -> ShaderMaterial:
	if not _materials.has("scar"):
		_materials["scar"] = _make_material(Color(0.09, 0.08, 0.08), 0.4, 0.9)
	return _materials["scar"]


## A sheared rivet or bolt stub.
static func stub_material() -> ShaderMaterial:
	if not _materials.has("stub"):
		_materials["stub"] = _make_material(Color(0.5, 0.48, 0.45), 0.9, 0.3)
	return _materials["stub"]


static func _make_material(color: Color, metallic: float, roughness: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shared/void_salvage/shaders/joint_head.gdshader")
	m.set_shader_parameter("albedo", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("roughness", roughness)
	return m


## Weld bead: how many ground-down steps it shows, its size (metres: how far it stands
## proud of the seam, how wide it spreads across it) and the ripple spacing. A wreck has
## over a thousand beads, so they're built coarse (6 sides, a ring every 12 mm).
const BEAD_LEVELS: int = 4
const BEAD_PROUD: float = 0.008
const BEAD_SPREAD: float = 0.012
const BEAD_RIPPLE: float = 0.024
const BEAD_STEP: float = 0.012
const BEAD_SIDES: int = 6
## The machine bead (head 2): how much lower and narrower than the yard bead, and how
## shallow its ripples (0 = smooth); the ground bead (head 3) is a hairline this proud and wide.
const MACHINE_PROUD: float = 0.55
const MACHINE_SPREAD: float = 0.75
const MACHINE_RIPPLE: float = 0.04
const GROUND_PROUD: float = 0.0012
const GROUND_SPREAD: float = 0.001

static var _beads: Dictionary = {}


## A weld bead along a seam of `size` (see ConnectionData.seam_size), `keep` = how much of
## it is left (1 = fresh, lower = ground down), `head` its style (0 yard, 2 machine, 3
## ground: FrameStyle). Lies in the XZ plane: X along the seam's
## up, Y across the seam. Rippled like stacked coins. Cached by size (snapped to 2 cm, so
## seams of nearly the same length share a mesh and a draw call).
static func bead_mesh(size: Vector2, keep: float, head: int = 0) -> Mesh:
	size = Vector2(snappedf(size.x, 0.02), snappedf(size.y, 0.02))
	var key := [size.x, size.y, snappedf(keep, 0.01)] if head < 2 else [size.x, size.y, snappedf(keep, 0.01), head]
	if _beads.has(key):
		return _beads[key]
	var path := PackedVector3Array()
	var closed := size.y > 0.0
	if closed:
		var hx := size.x * 0.5
		var hz := size.y * 0.5
		var rc := minf(0.012, minf(hx, hz) * 0.5)
		var corners := [Vector2(hx - rc, hz - rc), Vector2(-(hx - rc), hz - rc),
				Vector2(-(hx - rc), -(hz - rc)), Vector2(hx - rc, -(hz - rc))]
		for ci in 4:
			var c: Vector2 = corners[ci]
			var nxt: Vector2 = corners[(ci + 1) % 4]
			for a in 2:
				var ang := (float(ci) + float(a) / 2.0) * PI * 0.5
				path.append(Vector3(c.x + cos(ang) * rc, 0.0, c.y + sin(ang) * rc))
			var start := Vector3(c.x + cos((ci + 1) * PI * 0.5) * rc, 0.0, c.y + sin((ci + 1) * PI * 0.5) * rc)
			var end := Vector3(nxt.x + cos((ci + 1) * PI * 0.5) * rc, 0.0, nxt.y + sin((ci + 1) * PI * 0.5) * rc)
			var n := maxi(int(start.distance_to(end) / BEAD_STEP), 1)
			for i in n:
				path.append(start.lerp(end, float(i) / float(n)))
	else:
		var length := size.x if size.x > 0.0 else 0.12
		var n := maxi(int(length / BEAD_STEP), 2)
		for i in n + 1:
			path.append(Vector3(lerpf(-length * 0.5, length * 0.5, float(i) / float(n)), 0.0, 0.0))
	var sides := BEAD_SIDES
	var count := path.size()
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	var walked := 0.0
	for i in count:
		var prev := path[(i - 1 + count) % count] if closed or i > 0 else path[i]
		var nxt := path[(i + 1) % count] if closed or i < count - 1 else path[i]
		if i > 0:
			walked += path[i].distance_to(path[i - 1])
		var t := (nxt - prev).normalized()
		var out := t.cross(Vector3.UP).normalized()
		if closed and out.dot(path[i]) < 0.0:
			out = -out
		# Ripples: each dab of weld swells then dips; ends taper on a straight bead.
		var depth := 0.14 if head < 2 else (MACHINE_RIPPLE if head == 2 else 0.0)
		var ripple := 1.0 - depth + depth * absf(sin(walked * PI / (BEAD_RIPPLE if head < 2 else BEAD_STEP)))
		var taper := 1.0
		if not closed:
			var e := minf(float(i), float(count - 1 - i)) / 2.0
			taper = clampf(e, 0.35, 1.0)
		var proud := BEAD_PROUD * keep * ripple * taper
		var spread := BEAD_SPREAD * (0.6 + 0.4 * keep) * ripple * taper
		if head == 2:
			proud *= MACHINE_PROUD
			spread *= MACHINE_SPREAD
		elif head == 3:
			proud = GROUND_PROUD * taper
			spread = GROUND_SPREAD * taper
		var ring := PackedVector3Array()
		var norms := PackedVector3Array()
		for k in sides:
			var a := TAU * float(k) / float(sides)
			var o := out * cos(a)
			if not closed:
				o = Vector3(0, 0, 1) * cos(a)
			ring.append(path[i] + o * proud + Vector3.UP * sin(a) * spread)
			norms.append((o / maxf(proud, 0.001) + Vector3.UP * sin(a) / spread).normalized())
		rings.append(ring)
		ring_normals.append(norms)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := count if closed else count - 1
	for i in segs:
		var j := (i + 1) % count
		for k in sides:
			var k2 := (k + 1) % sides
			var quad := [[i, k], [j, k], [j, k2], [i, k2]]
			# Wind so the face points out of the tube (front faces are clockwise).
			var p0: Vector3 = rings[i][k]
			var n0: Vector3 = ring_normals[i][k]
			var tri_n := (rings[j][k] - p0).cross(rings[j][k2] - p0)
			var order := [0, 1, 2, 0, 2, 3] if tri_n.dot(n0) < 0.0 else [0, 2, 1, 0, 3, 2]
			for q: int in order:
				var ik: Array = quad[q]
				st.set_normal(ring_normals[ik[0]][ik[1]])
				st.add_vertex(rings[ik[0]][ik[1]])
	st.index()
	var m := st.commit()
	_beads[key] = m
	return m


static func _mesh_for(kind: ConnectionData.Kind, head: int = 0) -> Mesh:
	var key: Variant = kind if head == 0 else "%d:%d" % [kind, head]
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match kind:
		ConnectionData.Kind.RIVET when head == 1:
			# A flush rivet: a shallow dome, more a bump in the skin than a head.
			var dome := SphereMesh.new()
			dome.radius = FLUSH_RADIUS
			dome.height = FLUSH_HEIGHT * 2.0
			dome.radial_segments = 8
			dome.rings = 2
			dome.is_hemisphere = true
			# A hemisphere's base is at y = 0; the view centres heads on their height, so
			# drop it by half the height to sit on the surface like the others.
			var st := SurfaceTool.new()
			st.create_from(dome, 0)
			var arrays := st.commit_to_arrays()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i].y -= FLUSH_HEIGHT * 0.5
			arrays[Mesh.ARRAY_VERTEX] = verts
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			m = am
		ConnectionData.Kind.RIVET:
			var rivet := CylinderMesh.new()
			rivet.top_radius = 0.036 * RIVET_SCALE
			rivet.bottom_radius = 0.052 * RIVET_SCALE
			rivet.height = _height_for(kind)
			rivet.radial_segments = 8
			rivet.rings = 1
			m = rivet
		ConnectionData.Kind.BOLT:
			var bolt := CylinderMesh.new()
			bolt.top_radius = 0.049 * BOLT_SCALE
			bolt.bottom_radius = 0.049 * BOLT_SCALE
			bolt.height = _height_for(kind)
			bolt.radial_segments = 6  # hex head
			bolt.rings = 1
			m = bolt
		ConnectionData.Kind.CONNECTOR:
			# A plug sleeve around the loom, along the loom (the joint's normal).
			var plug := CylinderMesh.new()
			plug.top_radius = 0.072
			plug.bottom_radius = 0.072
			plug.height = _height_for(kind)
			plug.radial_segments = 8
			plug.rings = 1
			m = plug
		ConnectionData.Kind.SPOT:
			# A spot weld: a low round puddle, wider at its foot.
			var spot := CylinderMesh.new()
			spot.top_radius = SPOT_RADIUS * 0.7
			spot.bottom_radius = SPOT_RADIUS
			spot.height = SPOT_HEIGHT
			spot.radial_segments = 8
			spot.rings = 1
			m = spot
		_:
			# A weld bead: a rough collar around the seam, thin across it.
			var weld := BoxMesh.new()
			weld.size = Vector3(0.36, _height_for(kind), 0.36)
			m = weld
	_meshes[key] = m
	return m
