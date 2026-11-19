extends RefCounted
## What the yard's worker bots look like (0.4.1 playtest: "the worker bots who fix the ship up
## should be more functional, android style ... heavy bots with arms which articulate to help
## them do their work, holding objects and welding, riveting or bolting objects in place"):
## TartanCo's heavy work android, one core in four trades, after beenster's reference sheets.
## A deep chest of rounded plates over a ribbed waist, big rounded ochre pauldrons, a domed
## visored head with stereo work lamps, a backpack with RCS pods at its corners and the trade's
## own kit, two arms (shoulder, upper arm, elbow, forearm, a tool on a
## quick-change wrist) and two legs (hip, thigh, knee, shin, a magnetic clamp foot):
##   W-3 the welder:   a gimballed torch on an umbilical from two consumable tanks
##   R-3 the riveter:  a force-controlled rivet gun fed by a belt from the drum on its back
##   B-3 the bolter:   a nut runner, a socket carousel on its back
##   F-3 the fitter:   two heavy rail grippers with suction pads, an alignment laser on its brow
## Arms reach with two-bone IK (`reach`) so a tool's tip goes where the work is; legs tuck up
## in flight (`tuck`) and clamp their feet to the work (`plant`). Built in code with
## YardToolMesh so they wear the suit's finish in TartanCo's livery; meshes built once, shared.

## TartanCo makes them (0.4.1 playtest): white-grey plates, near-black trim, ochre armour.
## TartanCo's own field engineers, who come out to service them, wear charcoal and red.
const LIVERY := {"id": "tartanco_worker", "plates": Color(0.8, 0.8, 0.78), "trim": Color(0.1, 0.1, 0.11), "accent": Color(0.85, 0.6, 0.1)}
const ENGINEER := {"id": "tartanco_engineer", "plates": Color(0.24, 0.25, 0.27), "trim": Color(0.08, 0.08, 0.09), "accent": Color(0.78, 0.12, 0.1)}
const MAKER := "TARTANCO"

## Each trade: its chest code, the tool on each wrist, its backpack and livery. E is TartanCo's
## engineer.
const ROLES := {
	"F": {"code": "F-3", "job": "Component fitter", "right": "gripper", "left": "gripper", "pack": "pack_F", "livery": LIVERY},
	"W": {"code": "W-3", "job": "Welder", "right": "torch", "left": "clamp", "pack": "pack_W", "livery": LIVERY},
	"R": {"code": "R-3", "job": "Riveter", "right": "rivet_gun", "left": "clamp", "pack": "pack_R", "livery": LIVERY},
	"B": {"code": "B-3", "job": "Bolter", "right": "nut_runner", "left": "clamp", "pack": "pack_B", "livery": LIVERY},
	"E": {"code": "TC-E", "job": "TartanCo engineer", "right": "torch", "left": "clamp", "pack": "pack_W", "livery": ENGINEER},
}
## The right shoulder (worker space, m; the left mirrors it), the arm's bones and each tool's
## reach from the wrist to its tip.
const SHOULDER := Vector3(0.7, 0.86, -0.02)
const UPPER := 0.62
const FORE := 0.6
const TOOL_LEN := {"torch": 0.5, "rivet_gun": 0.66, "nut_runner": 0.5, "gripper": 0.42, "clamp": 0.3}
## The right hip (worker space, m), the leg's bones and the ankle's height over the sole.
const HIP := Vector3(0.26, -0.2, 0.0)
const THIGH := 0.58
const SHIN := 0.56
const ANKLE := 0.17
## Where the umbilical (the welder's hose, the riveter's belt) leaves the backpack (worker space)
## and how many links it has.
const HOSE_PORT := Vector3(0.4, 0.94, 0.5)
const HOSE_LINKS := 8
## Where the fitter's alignment laser sits on its head (head space).
const LASER := Vector3(-0.1, 0.33, -0.16)

static var _meshes: Dictionary = {}
static var _liveries: Dictionary = {}
static var _hose_mesh: CylinderMesh
static var _belt_mesh: BoxMesh
static var _laser_mat: StandardMaterial3D


static func meshes() -> Dictionary:
	if _meshes.is_empty():
		_meshes = _build()
	return _meshes


static func livery(brand: Dictionary = LIVERY) -> ShaderMaterial:
	var id: String = brand.id
	if not _liveries.has(id):
		var mat := YardSuitAssets.finish(YardSuitLook.default_look())
		mat.set_shader_parameter("plates", brand.plates)
		mat.set_shader_parameter("trim", brand.trim)
		mat.set_shader_parameter("accent", brand.accent)
		mat.set_shader_parameter("oxygen", Color(0.35, 0.9, 1.0))
		mat.set_shader_parameter("wear", 0.45)
		mat.set_shader_parameter("light_energy", 2.4)
		_liveries[id] = mat
	return _liveries[id]


## A worker of trade `role` ("F", "W", "R", "B" or TartanCo's "E"), numbered `number`. Its
## limbs' parts are children named Upper/Fore/Hand and Thigh/Shin/Foot + R or L, placed by
## `reach`, `rest`, `plant` and `tuck` in global space each frame (call `rest` once it is in
## the tree).
static func make(role: String, number: String) -> Node3D:
	var spec: Dictionary = ROLES[role]
	var mat := livery(spec.livery)
	var m := meshes()
	var n := Node3D.new()
	n.set_meta("role", role)
	n.set_meta("tartanco_model", spec.code)
	n.set_meta("serial", "TC-%s-%s" % [String(spec.code).replace("-", ""), number])
	_mesh(n, "Body", m.body, mat)
	_mesh(n, "Pack", m[spec.pack], mat)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.08, -0.04)
	n.add_child(head)
	_mesh(head, "HeadMesh", m.head_F if role == "F" else m.head, mat)
	var thrust := _mesh(n, "Thrust", m.thrust, mat)
	thrust.visible = false
	for side: String in ["R", "L"]:
		_mesh(n, "Upper" + side, m.upper, mat)
		_mesh(n, "Fore" + side, m.fore, mat)
		var tool: String = spec.right if side == "R" else spec.left
		var hand := _mesh(n, "Hand" + side, m[tool], mat)
		hand.set_meta("tool", tool)
		_mesh(n, "Thigh" + side, m.thigh, mat)
		_mesh(n, "Shin" + side, m.shin, mat)
		_mesh(n, "Foot" + side, m.foot, mat)
	# Its code and number in the chest's inset, the maker's name on the pauldrons and backpack (a
	# label reads from its +Z: the chest's is turned to face forward, -Z).
	var dark := (spec.livery.plates as Color).get_luminance() < 0.5
	var ink := Color(0.95, 0.95, 0.95) if dark else Color(0.08, 0.08, 0.09)
	var lit := Color(0.94, 0.93, 0.9)
	for t: Array in [[spec.code, Vector3(0, 0.75, -0.392), PI, 0.0024, lit],
			[number, Vector3(0, 0.62, -0.392), PI, 0.0015, (spec.livery.accent as Color).lightened(0.2)],
			[MAKER, Vector3(0, 0.36, 0.597), 0.0, 0.0016, Color(0.92, 0.92, 0.9)],
			[MAKER, Vector3(SHOULDER.x + 0.295, SHOULDER.y + 0.1, SHOULDER.z), PI * 0.5, 0.0009, ink],
			[MAKER, Vector3(-SHOULDER.x - 0.295, SHOULDER.y + 0.1, SHOULDER.z), -PI * 0.5, 0.0009, ink]]:
		var tag := Label3D.new()
		tag.name = "Code" if t[0] == spec.code else ("Number" if t[0] == number else "Maker")
		tag.text = t[0]
		tag.font_size = 64
		tag.pixel_size = t[3]
		tag.outline_size = 0
		tag.modulate = t[4]
		tag.position = t[1]
		tag.rotation.y = t[2]
		n.add_child(tag)
	# A fault readout over it, shown while it has an error.
	var fault := Label3D.new()
	fault.name = "Fault"
	fault.text = "ERROR"
	fault.font_size = 64
	fault.pixel_size = 0.004
	fault.outline_size = 10
	fault.modulate = Color(1.0, 0.25, 0.2)
	fault.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fault.no_depth_test = true
	fault.position = Vector3(0, 1.85, 0)
	fault.visible = false
	n.add_child(fault)
	if role == "W" or role == "E":
		_hose(n, false)
	elif role == "R":
		_hose(n, true)
	if role == "F":
		var laser := MeshInstance3D.new()
		laser.name = "Laser"
		var lm := CylinderMesh.new()
		lm.top_radius = 0.006
		lm.bottom_radius = 0.006
		lm.height = 1.0
		lm.radial_segments = 6
		lm.rings = 1
		laser.mesh = lm
		laser.material_override = laser_material()
		laser.visible = false
		n.add_child(laser)
	return n


static func laser_material() -> StandardMaterial3D:
	if _laser_mat == null:
		_laser_mat = StandardMaterial3D.new()
		_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_laser_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.55)
		_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_laser_mat.emission_enabled = true
		_laser_mat.emission = Color(1.0, 0.15, 0.1)
		_laser_mat.emission_energy_multiplier = 3.0
	return _laser_mat


## The welder's umbilical (a hose) or the riveter's feed belt (rivet links), in links.
static func _hose(n: Node3D, belt: bool) -> void:
	if _hose_mesh == null:
		_hose_mesh = CylinderMesh.new()
		_hose_mesh.top_radius = 0.035
		_hose_mesh.bottom_radius = 0.035
		_hose_mesh.height = 1.0
		_hose_mesh.radial_segments = 10
		_hose_mesh.rings = 1
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.06, 0.06, 0.07)
		hm.roughness = 0.6
		_hose_mesh.material = hm
		_belt_mesh = BoxMesh.new()
		_belt_mesh.size = Vector3(0.05, 1.0, 0.03)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.62, 0.45, 0.16)
		bm.metallic = 0.85
		bm.roughness = 0.3
		_belt_mesh.material = bm
	for i in HOSE_LINKS:
		var link := MeshInstance3D.new()
		link.name = "Hose%d" % i
		link.mesh = _belt_mesh if belt else _hose_mesh
		n.add_child(link)


static func _mesh(parent: Node3D, name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func tool_of(w: Node3D, side: String) -> String:
	var hand := w.get_node_or_null("Hand" + side)
	return String(hand.get_meta("tool", "gripper")) if hand else "gripper"


## The shoulder's centre in global space.
static func shoulder(w: Node3D, side: String) -> Vector3:
	var s := SHOULDER if side == "R" else Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z)
	return w.global_transform * s


## Puts the arm's tool tip at `tip` (global), the tool pointing along `approach` (into the work):
## the hand turned to it, the wrist behind it, elbow and shoulder by two-bone IK with the elbow
## out and down. `kick` pulls the tool back along its line (m): the rivet gun's recoil.
static func reach(w: Node3D, side: String, tip: Vector3, approach: Vector3, kick := 0.0) -> void:
	var dir := approach.normalized() if approach.length() > 0.001 else -w.global_basis.z
	var wrist := tip - dir * (float(TOOL_LEN[tool_of(w, side)]) + kick)
	var sx := 1.0 if side == "R" else -1.0
	var b := w.global_basis.orthonormalized()
	var pole := (b.x * sx * 0.6 - b.y * 0.7 + b.z * 0.25).normalized()
	var s := shoulder(w, side)
	var chain := _two_bone(s, wrist, UPPER, FORE, pole, -b.y, b.z)
	_bone(w.get_node("Upper" + side), s, chain[0], b.x * sx)
	_bone(w.get_node("Fore" + side), chain[0], chain[1], b.x * sx)
	_bone(w.get_node("Hand" + side), chain[1], chain[1] + dir, chain[2])


## The arm at rest: hanging, forearm forward, tool down and ahead.
static func rest(w: Node3D, side: String) -> void:
	var sx := 1.0 if side == "R" else -1.0
	var tip := w.global_transform * Vector3(sx * 0.66, -0.12, -0.88)
	reach(w, side, tip, w.global_basis * Vector3(0, -0.6, -0.8).normalized())


## Clamps the leg's foot to a surface: its sole at `sole` (global), pressed along `down` (into
## the surface), the toe as near `toe` as the surface lets it.
static func plant(w: Node3D, side: String, sole: Vector3, down: Vector3, toe := Vector3.ZERO) -> void:
	var sx := 1.0 if side == "R" else -1.0
	var b := w.global_basis.orthonormalized()
	var hip := w.global_transform * Vector3(HIP.x * sx, HIP.y, HIP.z)
	var d := down.normalized() if down.length() > 0.001 else -b.y
	var ankle := sole - d * ANKLE
	# Knees bend forward and a little out.
	var pole := (-b.z + b.x * sx * 0.25).normalized()
	var chain := _two_bone(hip, ankle, THIGH, SHIN, pole, -b.y, -b.z)
	_bone(w.get_node("Thigh" + side), hip, chain[0], b.x * sx)
	_bone(w.get_node("Shin" + side), chain[0], chain[1], b.x * sx)
	var t := toe if toe.length() > 0.001 else -b.z
	var fwd := t - d * d.dot(t)
	fwd = fwd.normalized() if fwd.length() > 0.001 else -b.z
	# The foot's mesh stands on its sole with -Z the toe: y up off the surface.
	var y := -d
	var z := -fwd
	node_basis(w.get_node("Foot" + side), Basis(y.cross(z).normalized(), y, z), chain[1])


## The legs in flight: drawn up under it, knees forward, feet trailing a little (`sway` swings
## them, -1..1).
static func tuck(w: Node3D, side: String, sway := 0.0) -> void:
	var sx := 1.0 if side == "R" else -1.0
	var sole := w.global_transform * Vector3(sx * 0.34, -1.06 + sway * 0.03, 0.22 + sway * 0.06 * sx)
	plant(w, side, sole, w.global_basis * Vector3(0.0, -1.0, 0.35).normalized())


## Standing as on a deck: soles under the hips at `floor` metres below the pelvis.
static func stand(w: Node3D, floor_drop := 1.28) -> void:
	for side: String in ["R", "L"]:
		var sx := 1.0 if side == "R" else -1.0
		plant(w, side, w.global_transform * Vector3(sx * 0.36, -floor_drop, -0.04), -w.global_basis.y)


## The tool tip's place now (global).
static func tip_of(w: Node3D, side: String) -> Vector3:
	var hand := w.get_node("Hand" + side) as Node3D
	return hand.global_transform * Vector3(0, -float(TOOL_LEN[tool_of(w, side)]), 0)


## Two-bone IK from `a` towards `target`: [middle joint, end, bend direction]. The middle joint
## bows towards `pole`; a chain pulled straight bows along `fallback`.
static func _two_bone(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3, fallback: Vector3, spare: Vector3) -> Array:
	var to := target - a
	var d := clampf(to.length(), absf(l1 - l2) + 0.05, l1 + l2 - 0.002)
	var along := to.normalized() if to.length() > 0.001 else fallback
	var end := a + along * d
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var bend := pole - along * pole.dot(along)
	bend = bend.normalized() if bend.length() > 0.001 else spare
	return [a + along * x + bend * h, end, bend]


## A bone whose mesh hangs along its -Y from its origin: placed at `from`, -Y towards `to`, its
## z turned towards `pole`.
static func _bone(node: Node3D, from: Vector3, to: Vector3, pole: Vector3) -> void:
	var y := from - to
	y = y.normalized() if y.length() > 0.0001 else Vector3.UP
	var z := pole - y * pole.dot(y)
	if z.length() < 0.001:
		z = y.cross(Vector3.RIGHT) if absf(y.x) < 0.9 else y.cross(Vector3.FORWARD)
	z = z.normalized()
	var x := y.cross(z)
	node_basis(node, Basis(x, y, z), from)


static func node_basis(node: Node, basis: Basis, at: Vector3) -> void:
	(node as Node3D).global_transform = Transform3D(basis.orthonormalized(), at)


## Lays the umbilical from the backpack to the tool's wrist: a sagging curve of links (the
## welder's hose, the riveter's belt of rivets).
static func lay_hose(w: Node3D) -> void:
	if not w.has_node("Hose0"):
		return
	var a := w.global_transform * HOSE_PORT
	var hand := w.get_node("HandR") as Node3D
	var b := hand.global_transform * Vector3(0.08, -0.16, 0.06)
	# The hose sags out and down; the riveter's belt runs up over its shoulder to the gun.
	var belt: bool = w.get_meta("role", "") == "R"
	var c := (a + b) * 0.5 + w.global_basis * (Vector3(0.45, 0.35, -0.05) if belt else Vector3(0.4, -0.5, 0.25))
	var prev := a
	for i in HOSE_LINKS:
		var t := float(i + 1) / HOSE_LINKS
		var p := a.lerp(c, t).lerp(c.lerp(b, t), t)
		var link := w.get_node("Hose%d" % i) as Node3D
		var length := prev.distance_to(p)
		var mid := (prev + p) * 0.5
		var y := (p - prev).normalized() if length > 0.001 else Vector3.UP
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		link.global_transform = Transform3D(Basis(x, y * (length + 0.02), x.cross(y)), mid)
		prev = p


## Points the fitter's alignment laser from its brow to `at` (global), or hides it.
static func aim_laser(w: Node3D, at: Variant) -> void:
	var laser := w.get_node_or_null("Laser") as MeshInstance3D
	if laser == null:
		return
	laser.visible = at != null
	if at == null:
		return
	var head := w.get_node("Head") as Node3D
	var from := head.global_transform * LASER
	var to: Vector3 = at
	var length := from.distance_to(to)
	if length < 0.05:
		laser.visible = false
		return
	var y := (to - from) / length
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	laser.global_transform = Transform3D(Basis(x, y * length, x.cross(y)), (from + to) * 0.5)


static func _build() -> Dictionary:
	var m := YardToolMesh.new()
	_body(m)
	_head(m, "head")
	_head(m, "head_F")
	_arm(m)
	_leg(m)
	_torch(m)
	_rivet_gun(m)
	_nut_runner(m)
	_gripper(m)
	_clamp(m)
	for pack: String in ["pack_W", "pack_R", "pack_B", "pack_F"]:
		_pack(m, pack)
	# Reaction-control flames: four pods on the backpack's corners, firing back and down.
	for p: Vector3 in [Vector3(0.5, 1.04, 0.5), Vector3(-0.5, 1.04, 0.5), Vector3(0.5, 0.22, 0.5), Vector3(-0.5, 0.22, 0.5)]:
		m.rod("thrust", "cyan", p + Vector3(0, 0, 0.14), p + Vector3(0, 0, 0.46), 0.05, 0.005, 12)
		m.rod("thrust", "lamp", p + Vector3(0, 0, 0.14), p + Vector3(0, 0, 0.26), 0.03, 0.004, 10)
	return m.meshes()


## A rounded shell (a superellipsoid) centred at `at`, `size` across: `e.x` rounds it top to
## bottom, `e.y` round its sides (1 an ellipsoid, towards 0 a box with soft edges), smooth.
static func _shell(m: YardToolMesh, key: String, stock: String, at: Vector3, size: Vector3, e := Vector2(0.5, 0.5), basis := Basis(), seg := 18, rings := 12) -> void:
	var h := size * 0.5
	var f := func(w: float, p: float) -> float: return signf(w) * pow(absf(w), p)
	var pt := func(i: int, j: int) -> Array:
		var phi := -PI * 0.5 + PI * j / rings
		var th := TAU * i / seg
		var cp := cos(phi)
		var sp := sin(phi)
		var ct := cos(th)
		var st := sin(th)
		var p := Vector3(h.x * f.call(cp, e.x) * f.call(ct, e.y), h.y * f.call(sp, e.x), h.z * f.call(cp, e.x) * f.call(st, e.y))
		var n := Vector3(f.call(cp, 2.0 - e.x) * f.call(ct, 2.0 - e.y) / h.x, f.call(sp, 2.0 - e.x) / h.y,
				f.call(cp, 2.0 - e.x) * f.call(st, 2.0 - e.y) / h.z)
		return [at + basis * p, (basis * n).normalized()]
	for j in rings:
		for i in seg:
			var q: Array = [pt.call(i, j), pt.call(i + 1, j), pt.call(i + 1, j + 1), pt.call(i, j + 1)]
			for t: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				var a: Vector3 = t[0][0]
				var b: Vector3 = t[1][0]
				var c: Vector3 = t[2][0]
				var flat := (b - a).cross(c - a)
				if flat.length_squared() < 1e-12:
					continue
				if flat.dot((a + b + c) / 3.0 - at) < 0.0:
					m._tri(key, stock, a, c, b, t[0][1], t[2][1], t[1][1])
				else:
					m._tri(key, stock, a, b, c, t[0][1], t[1][1], t[2][1])


## Pelvis, waist, chest and the shoulders' armour (the limbs and the backpack are their own),
## all in rounded shells.
static func _body(m: YardToolMesh) -> void:
	# Pelvis and hip housings.
	_shell(m, "body", "trim", Vector3(0, -0.12, 0), Vector3(0.66, 0.28, 0.48), Vector2(0.5, 0.45))
	_shell(m, "body", "plates", Vector3(0, -0.12, -0.2), Vector3(0.44, 0.22, 0.1), Vector2(0.5, 0.5))
	_shell(m, "body", "accent", Vector3(0, -0.15, -0.25), Vector3(0.22, 0.1, 0.03), Vector2(0.5, 0.5))
	for sx: float in [1.0, -1.0]:
		_shell(m, "body", "plates", Vector3(sx * 0.34, -0.08, 0), Vector3(0.12, 0.32, 0.4), Vector2(0.6, 0.6))
		m.rod("body", "dark", Vector3(sx * 0.14, HIP.y, 0), Vector3(sx * 0.4, HIP.y, 0), 0.13, -1.0, 22)
		m.ring("body", "steel", Vector3(sx * 0.4, HIP.y, 0), 0.1, 0.014, Vector3.RIGHT, 20, 5)
	# The waist: ribbed and dark, a pivot under the chest.
	m.rod("body", "gunmetal", Vector3(0, 0.0, 0), Vector3(0, 0.36, 0), 0.25, 0.29, 28)
	for k in 6:
		m.ring("body", "dark", Vector3(0, 0.05 + k * 0.055, 0), 0.26 + k * 0.006, 0.014, Vector3.UP, 28, 6)
	for sx: float in [1.0, -1.0]:
		m.rod("body", "steel", Vector3(sx * 0.2, -0.02, -0.14), Vector3(sx * 0.24, 0.4, -0.16), 0.022, -1.0, 10)
	# The chest: a deep rounded core, the breastplate over it, an inset for the trade's code.
	_shell(m, "body", "trim", Vector3(0, 0.68, 0.02), Vector3(1.08, 0.74, 0.74), Vector2(0.55, 0.5), Basis(), 24, 14)
	_shell(m, "body", "plates", Vector3(0, 0.72, -0.3), Vector3(0.9, 0.58, 0.16), Vector2(0.45, 0.45), Basis(), 24, 14)
	_shell(m, "body", "dark", Vector3(0, 0.69, -0.37), Vector3(0.36, 0.3, 0.03), Vector2(0.4, 0.4))
	_shell(m, "body", "plates", Vector3(0, 0.42, -0.28), Vector3(0.66, 0.18, 0.14), Vector2(0.6, 0.5))
	for sx: float in [1.0, -1.0]:
		# Ochre armour over the ribs and rounded flanks, vents and bolts.
		_shell(m, "body", "accent", Vector3(sx * 0.34, 0.7, -0.36), Vector3(0.18, 0.42, 0.06), Vector2(0.5, 0.5))
		_shell(m, "body", "plates", Vector3(sx * 0.46, 0.64, 0.02), Vector3(0.16, 0.56, 0.62), Vector2(0.55, 0.55))
		for k in 4:
			m.rod("body", "dark", Vector3(sx * 0.538, 0.5 + k * 0.07, 0.0), Vector3(sx * 0.538, 0.5 + k * 0.07, 0.22), 0.012, -1.0, 8)
		m.bolt("body", Vector3(sx * 0.24, 0.96, -0.36), Vector3.FORWARD, 0.014)
		m.bolt("body", Vector3(sx * 0.24, 0.48, -0.36), Vector3.FORWARD, 0.014)
	m.rod("body", "dark", Vector3(-0.2, 1.0, -0.3), Vector3(0.2, 1.0, -0.3), 0.03, -1.0, 12)
	# Collar and neck.
	m.rod("body", "dark", Vector3(0, 0.98, -0.04), Vector3(0, 1.12, -0.04), 0.14, 0.11, 20)
	m.ring("body", "gunmetal", Vector3(0, 1.02, -0.04), 0.22, 0.035, Vector3.UP, 24, 6)
	for sx: float in [1.0, -1.0]:
		m.rod("body", "steel", Vector3(sx * 0.16, 0.98, 0.04), Vector3(sx * 0.07, 1.12, -0.02), 0.022, -1.0, 8)
	# The pauldrons: a heavy rounded ochre shell in layers over the shoulder's joint housing.
	for sx: float in [1.0, -1.0]:
		var s := Vector3(SHOULDER.x * sx, SHOULDER.y, SHOULDER.z)
		m.rod("body", "dark", s - Vector3(sx * 0.2, 0, 0), s + Vector3(sx * 0.04, 0, 0), 0.17, -1.0, 24)
		_shell(m, "body", "accent", s + Vector3(sx * 0.05, 0.1, 0), Vector3(0.46, 0.38, 0.58), Vector2(0.7, 0.65), Basis(), 24, 14)
		_shell(m, "body", "plates", s + Vector3(sx * 0.03, 0.27, 0), Vector3(0.38, 0.12, 0.48), Vector2(0.6, 0.6))
		_shell(m, "body", "accent", s + Vector3(sx * 0.15, -0.08, 0), Vector3(0.18, 0.2, 0.5), Vector2(0.7, 0.6))
		m.ring("body", "dark", s + Vector3(sx * 0.05, 0.1, 0), 0.24, 0.012, Vector3.RIGHT, 28, 5)


## The head: a domed helmet, a visor band with two stereo lamps, sensor pods each side, an
## antenna; the fitter's ("head_F") also has its alignment laser over its brow.
static func _head(m: YardToolMesh, key: String) -> void:
	_shell(m, key, "plates", Vector3(0, 0.16, 0.02), Vector3(0.4, 0.36, 0.42), Vector2(0.7, 0.6), Basis(), 22, 14)
	_shell(m, key, "accent", Vector3(0, 0.3, 0.02), Vector3(0.12, 0.1, 0.4), Vector2(0.7, 0.7))
	_shell(m, key, "dark", Vector3(0, 0.13, -0.17), Vector3(0.34, 0.15, 0.1), Vector2(0.55, 0.6))
	_shell(m, key, "glass", Vector3(0, 0.13, -0.2), Vector3(0.3, 0.09, 0.05), Vector2(0.5, 0.5))
	m.box(key, "cyan", Vector3(0, 0.085, -0.222), Vector3(0.22, 0.008, 0.004), 0.002)
	for sx: float in [1.0, -1.0]:
		m.rod(key, "dark", Vector3(sx * 0.09, 0.14, -0.2), Vector3(sx * 0.09, 0.14, -0.235), 0.04, -1.0, 16)
		m.rod(key, "lamp", Vector3(sx * 0.09, 0.14, -0.235), Vector3(sx * 0.09, 0.14, -0.242), 0.03, -1.0, 16)
		_shell(m, key, "trim", Vector3(sx * 0.2, 0.14, 0.02), Vector3(0.08, 0.22, 0.3), Vector2(0.6, 0.6))
		m.rod(key, "gunmetal", Vector3(sx * 0.23, 0.14, -0.04), Vector3(sx * 0.29, 0.14, -0.04), 0.06, 0.05, 16)
		m.rod(key, "cyan", Vector3(sx * 0.29, 0.14, -0.04), Vector3(sx * 0.295, 0.14, -0.04), 0.03, -1.0, 12)
	_shell(m, key, "dark", Vector3(0, 0.02, -0.12), Vector3(0.24, 0.07, 0.14), Vector2(0.6, 0.6))
	m.rod(key, "dark", Vector3(0.13, 0.28, 0.16), Vector3(0.13, 0.54, 0.18), 0.008, 0.004, 8)
	m.rod(key, "red_lamp", Vector3(0.13, 0.54, 0.18), Vector3(0.13, 0.56, 0.18), 0.014, -1.0, 8)
	if key == "head_F":
		_shell(m, key, "trim", LASER + Vector3(0, -0.01, 0.06), Vector3(0.12, 0.08, 0.18), Vector2(0.6, 0.6))
		m.rod(key, "steel", LASER + Vector3(0, 0, 0.0), LASER + Vector3(0, 0, -0.04), 0.03, -1.0, 12)
		m.rod(key, "red_lamp", LASER + Vector3(0, 0, -0.04), LASER + Vector3(0, 0, -0.045), 0.016, -1.0, 10)
		m.rod(key, "glass", LASER + Vector3(0.06, 0, 0.0), LASER + Vector3(0.06, 0, -0.03), 0.022, -1.0, 12)


## One arm's two bones, each hanging along -Y from its joint (mirrors as it is): an actuator
## core with rounded plates over it, pistons, a big elbow, a forearm in ochre armour, umbilicals.
static func _arm(m: YardToolMesh) -> void:
	m.rod("upper", "gunmetal", Vector3.ZERO, Vector3(0, -UPPER, 0), 0.09, 0.08, 18)
	_shell(m, "upper", "plates", Vector3(0, -0.27, -0.01), Vector3(0.28, 0.4, 0.27), Vector2(0.55, 0.9))
	_shell(m, "upper", "accent", Vector3(0, -0.2, -0.135), Vector3(0.16, 0.16, 0.05), Vector2(0.6, 0.6))
	for sx: float in [1.0, -1.0]:
		m.rod("upper", "dark", Vector3(sx * 0.1, -0.08, 0.14), Vector3(sx * 0.1, -0.3, 0.15), 0.03, -1.0, 10)
		m.rod("upper", "steel", Vector3(sx * 0.1, -0.3, 0.15), Vector3(sx * 0.1, -0.54, 0.12), 0.018, -1.0, 8)
	m.rod("upper", "dark", Vector3(-0.15, -UPPER, 0), Vector3(0.15, -UPPER, 0), 0.12, -1.0, 22)
	for sx: float in [1.0, -1.0]:
		m.ring("upper", "steel", Vector3(sx * 0.152, -UPPER, 0), 0.08, 0.014, Vector3.RIGHT, 18, 5)
	_shell(m, "upper", "plates", Vector3(0, -UPPER + 0.02, 0.1), Vector3(0.2, 0.16, 0.1), Vector2(0.7, 0.7))
	m.rod("fore", "gunmetal", Vector3.ZERO, Vector3(0, -FORE, 0), 0.08, 0.07, 18)
	_shell(m, "fore", "accent", Vector3(0, -0.28, -0.02), Vector3(0.32, 0.44, 0.3), Vector2(0.55, 0.85))
	_shell(m, "fore", "plates", Vector3(0, -0.28, 0.12), Vector3(0.24, 0.36, 0.08), Vector2(0.6, 0.7))
	_shell(m, "fore", "dark", Vector3(0, -0.36, -0.16), Vector3(0.16, 0.16, 0.04), Vector2(0.6, 0.6))
	m.ring("fore", "trim", Vector3(0, -0.1, -0.02), 0.13, 0.02, Vector3.UP, 24, 6)
	for k in 3:
		m.box("fore", "rubber", Vector3(0.0, -0.08 - k * 0.15, 0.17), Vector3(0.06, 0.02, 0.04), 0.008)
	m.rod("fore", "rubber", Vector3(0.06, -0.04, 0.17), Vector3(0.06, -0.52, 0.15), 0.022, -1.0, 10)
	m.rod("fore", "dark", Vector3(0, -0.5, 0), Vector3(0, -FORE, 0), 0.095, -1.0, 20)
	m.ring("fore", "accent", Vector3(0, -FORE + 0.01, 0), 0.095, 0.012, Vector3.UP, 20, 5)


## One leg's three pieces: the thigh and shin hang along -Y from their joints (knee and shin
## armour facing -Z, forward), the clamp foot stands on its sole with its toe to -Z.
static func _leg(m: YardToolMesh) -> void:
	m.rod("thigh", "gunmetal", Vector3.ZERO, Vector3(0, -THIGH, 0), 0.11, 0.095, 18)
	_shell(m, "thigh", "plates", Vector3(0, -0.26, -0.03), Vector3(0.3, 0.44, 0.3), Vector2(0.55, 0.9))
	_shell(m, "thigh", "accent", Vector3(0, -0.24, -0.165), Vector3(0.18, 0.26, 0.06), Vector2(0.6, 0.6))
	m.rod("thigh", "steel", Vector3(0, -0.06, 0.15), Vector3(0, -0.5, 0.13), 0.026, -1.0, 10)
	m.rod("thigh", "dark", Vector3(-0.14, -THIGH, 0), Vector3(0.14, -THIGH, 0), 0.12, -1.0, 22)
	# A domed knee cap over the joint.
	_shell(m, "shin", "accent", Vector3(0, -0.02, -0.11), Vector3(0.22, 0.22, 0.12), Vector2(0.8, 0.8))
	m.rod("shin", "gunmetal", Vector3.ZERO, Vector3(0, -SHIN, 0), 0.09, 0.08, 18)
	_shell(m, "shin", "plates", Vector3(0, -0.3, -0.04), Vector3(0.28, 0.42, 0.26), Vector2(0.55, 0.85))
	_shell(m, "shin", "trim", Vector3(0, -0.3, 0.09), Vector3(0.18, 0.34, 0.1), Vector2(0.6, 0.7))
	_shell(m, "shin", "accent", Vector3(0, -0.36, -0.165), Vector3(0.14, 0.12, 0.04), Vector2(0.6, 0.6))
	for sx: float in [1.0, -1.0]:
		m.rod("shin", "steel", Vector3(sx * 0.15, -0.12, 0.04), Vector3(sx * 0.15, -0.48, 0.04), 0.018, -1.0, 8)
	m.rod("shin", "dark", Vector3(-0.11, -SHIN, 0), Vector3(0.11, -SHIN, 0), 0.09, -1.0, 18)
	# The foot (origin at the ankle, sole ANKLE below): a rounded heavy sole, a clamp jaw at the
	# toe and heel, three magnetic pads.
	_shell(m, "foot", "dark", Vector3(0, -0.04, 0), Vector3(0.18, 0.14, 0.18), Vector2(0.7, 0.7))
	_shell(m, "foot", "trim", Vector3(0, -0.11, -0.06), Vector3(0.3, 0.11, 0.5), Vector2(0.45, 0.55))
	_shell(m, "foot", "accent", Vector3(0, -0.07, -0.24), Vector3(0.26, 0.09, 0.1), Vector2(0.6, 0.6))
	_shell(m, "foot", "plates", Vector3(0, -0.05, -0.12), Vector3(0.2, 0.07, 0.2), Vector2(0.6, 0.6))
	for k in 3:
		_shell(m, "foot", "gunmetal", Vector3((k - 1) * 0.09, -0.15, -0.3), Vector3(0.06, 0.06, 0.08), Vector2(0.6, 0.6), Basis(), 10, 6)
	_shell(m, "foot", "gunmetal", Vector3(0, -0.15, 0.2), Vector3(0.16, 0.05, 0.07), Vector2(0.6, 0.6), Basis(), 12, 6)
	for p: Vector3 in [Vector3(-0.08, -0.16, -0.14), Vector3(0.08, -0.16, -0.14), Vector3(0, -0.16, 0.08)]:
		m.rod("foot", "steel", p, p - Vector3(0, ANKLE - 0.16 + 0.012, 0), 0.055, 0.06, 16)


## Each trade's backpack, on the frame they share: four rounded RCS pods, status lamps, then the
## trade's kit (the welder's tanks, the riveter's drum, the bolter's socket carousel, the
## fitter's rack of spare effectors).
static func _pack(m: YardToolMesh, key: String) -> void:
	_shell(m, key, "gunmetal", Vector3(0, 0.64, 0.44), Vector3(0.8, 0.88, 0.24), Vector2(0.4, 0.4), Basis(), 22, 12)
	for sx: float in [1.0, -1.0]:
		for y: float in [1.04, 0.22]:
			var pod := Vector3(sx * 0.5, y, 0.5)
			m.rod(key, "dark", Vector3(sx * 0.36, y, 0.46), pod, 0.035, -1.0, 10)
			_shell(m, key, "trim", pod, Vector3(0.18, 0.18, 0.2), Vector2(0.75, 0.75), Basis(), 14, 8)
			m.rod(key, "dark", pod + Vector3(0, 0, 0.095), pod + Vector3(0, 0, 0.15), 0.05, 0.065, 12)
			m.rod(key, "dark", pod + Vector3(sx * 0.085, 0, 0), pod + Vector3(sx * 0.14, 0, 0), 0.04, 0.055, 12)
			m.rod(key, "dark", pod + Vector3(0, signf(y - 0.6) * 0.085, 0), pod + Vector3(0, signf(y - 0.6) * 0.14, 0), 0.04, 0.055, 12)
	for k in 3:
		m.box(key, "accent_light", Vector3(-0.402, 0.5 + k * 0.08, 0.4), Vector3(0.006, 0.04, 0.05), 0.002)
	_shell(m, key, "dark", Vector3(0, 1.1, 0.5), Vector3(0.46, 0.09, 0.12), Vector2(0.6, 0.6))
	_shell(m, key, "plates", Vector3(0, 0.36, 0.565), Vector3(0.5, 0.14, 0.05), Vector2(0.5, 0.5))
	match key:
		"pack_W":
			for sx: float in [1.0, -1.0]:
				m.rod(key, "steel", Vector3(sx * 0.2, 0.46, 0.64), Vector3(sx * 0.2, 1.0, 0.64), 0.13, -1.0, 22)
				_shell(m, key, "steel", Vector3(sx * 0.2, 1.0, 0.64), Vector3(0.26, 0.12, 0.26), Vector2(0.9, 1.0), Basis(), 18, 8)
				_shell(m, key, "steel", Vector3(sx * 0.2, 0.46, 0.64), Vector3(0.26, 0.12, 0.26), Vector2(0.9, 1.0), Basis(), 18, 8)
				m.rod(key, "dark", Vector3(sx * 0.2, 1.04, 0.64), Vector3(sx * 0.2, 1.1, 0.64), 0.06, 0.045, 12)
				m.rod(key, "brass", Vector3(sx * 0.2, 1.1, 0.64), Vector3(sx * 0.2, 1.14, 0.64), 0.03, -1.0, 10)
				m.ring(key, "accent", Vector3(sx * 0.2, 0.58, 0.64), 0.132, 0.014, Vector3.UP, 22, 5)
				m.ring(key, "accent", Vector3(sx * 0.2, 0.9, 0.64), 0.132, 0.014, Vector3.UP, 22, 5)
			_shell(m, key, "trim", HOSE_PORT, Vector3(0.13, 0.13, 0.13), Vector2(0.7, 0.7))
		"pack_R":
			# The rivet drum, on its side behind the right shoulder, a magazine box beside it.
			m.rod(key, "dark", Vector3(0.02, 0.7, 0.64), Vector3(0.36, 0.7, 0.64), 0.27, -1.0, 28)
			m.ring(key, "accent", Vector3(0.36, 0.7, 0.64), 0.25, 0.022, Vector3.RIGHT, 28, 5)
			m.rod(key, "steel", Vector3(0.36, 0.7, 0.64), Vector3(0.38, 0.7, 0.64), 0.08, -1.0, 16)
			for k in 14:
				var a := TAU * k / 14.0
				var p := Vector3(0.37, 0.7 + cos(a) * 0.19, 0.64 + sin(a) * 0.19)
				m.rod(key, "brass", p - Vector3(0.01, 0, 0), p + Vector3(0.02, 0, 0), 0.02, -1.0, 6)
			_shell(m, key, "plates", Vector3(-0.22, 0.7, 0.62), Vector3(0.24, 0.54, 0.26), Vector2(0.5, 0.55))
			_shell(m, key, "accent", Vector3(-0.22, 0.86, 0.74), Vector3(0.16, 0.08, 0.03), Vector2(0.6, 0.6))
			_shell(m, key, "trim", HOSE_PORT, Vector3(0.13, 0.13, 0.13), Vector2(0.7, 0.7))
		"pack_B":
			# The socket carousel: a lidded drum of spare sockets, a nut hopper below it.
			m.rod(key, "plates", Vector3(0, 0.5, 0.66), Vector3(0, 0.98, 0.66), 0.25, 0.23, 24)
			m.ring(key, "accent", Vector3(0, 0.98, 0.66), 0.23, 0.02, Vector3.UP, 24, 5)
			_shell(m, key, "dark", Vector3(0, 0.99, 0.66), Vector3(0.38, 0.1, 0.38), Vector2(0.8, 1.0), Basis(), 22, 8)
			for k in 10:
				var a := TAU * k / 10.0
				var p := Vector3(cos(a) * 0.25, 0.66, 0.66 + sin(a) * 0.25)
				m.rod(key, "steel", p, p + Vector3(0, 0.12, 0), 0.035, -1.0, 6)
			_shell(m, key, "trim", Vector3(0.3, 0.34, 0.6), Vector3(0.17, 0.21, 0.19), Vector2(0.6, 0.6))
		"pack_F":
			# A rack of interchangeable effectors: two spare suction plates and a spare jaw.
			_shell(m, key, "dark", Vector3(0, 0.72, 0.6), Vector3(0.66, 0.56, 0.13), Vector2(0.45, 0.45))
			for sx: float in [1.0, -1.0]:
				m.rod(key, "rubber", Vector3(sx * 0.17, 0.82, 0.66), Vector3(sx * 0.17, 0.82, 0.72), 0.1, 0.11, 18)
				m.rod(key, "steel", Vector3(sx * 0.17, 0.82, 0.72), Vector3(sx * 0.17, 0.82, 0.73), 0.04, -1.0, 10)
			_shell(m, key, "accent", Vector3(0, 0.54, 0.68), Vector3(0.3, 0.12, 0.07), Vector2(0.6, 0.6))
			_shell(m, key, "dark", Vector3(0, 0.54, 0.72), Vector3(0.1, 0.16, 0.05), Vector2(0.6, 0.6))


## W-3's torch: a quick-change block, the gun body, a gimbal ring, a copper nozzle; the arc's tip
## at -TOOL_LEN.torch.
static func _torch(m: YardToolMesh) -> void:
	var tl: float = TOOL_LEN.torch
	m.box("torch", "trim", Vector3(0, -0.05, 0), Vector3(0.18, 0.1, 0.18), 0.02)
	m.box("torch", "accent", Vector3(0, -0.13, 0), Vector3(0.14, 0.08, 0.14), 0.02)
	m.rod("torch", "dark", Vector3(0, -0.16, 0), Vector3(0, -0.3, 0), 0.055, 0.045, 18)
	m.ring("torch", "accent", Vector3(0, -0.22, 0), 0.075, 0.016, Vector3.UP, 20, 6)
	m.ring("torch", "steel", Vector3(0, -0.22, 0), 0.075, 0.01, Vector3.RIGHT, 20, 5)
	m.rod("torch", "steel", Vector3(0, -0.3, 0), Vector3(0, -0.36, 0), 0.04, 0.034, 16)
	m.rod("torch", "copper", Vector3(0, -0.36, 0), Vector3(0, -tl + 0.02, 0), 0.03, 0.016, 16)
	m.rod("torch", "lamp", Vector3(0, -tl + 0.02, 0), Vector3(0, -tl, 0), 0.012, 0.006, 10)
	m.rod("torch", "dark", Vector3(0.08, -0.12, 0.06), Vector3(0.08, -0.04, 0.1), 0.03, -1.0, 10)


## R-3's rivet gun: a heavy barrel with its muzzle, a feed block where the belt comes in, a
## force-sensing collar, a stabilising foot beside the muzzle.
static func _rivet_gun(m: YardToolMesh) -> void:
	var tl: float = TOOL_LEN.rivet_gun
	m.box("rivet_gun", "trim", Vector3(0, -0.05, 0), Vector3(0.2, 0.1, 0.2), 0.02)
	m.rod("rivet_gun", "gunmetal", Vector3(0, -0.08, 0), Vector3(0, -0.46, 0), 0.1, 0.09, 22)
	for k in 5:
		m.ring("rivet_gun", "dark", Vector3(0, -0.12 - k * 0.065, 0), 0.104, 0.011, Vector3.UP, 22, 5)
	m.box("rivet_gun", "accent", Vector3(0.12, -0.2, 0.0), Vector3(0.12, 0.2, 0.16), 0.03)
	m.box("rivet_gun", "dark", Vector3(0.18, -0.2, 0.0), Vector3(0.02, 0.12, 0.1), 0.006)
	m.rod("rivet_gun", "dark", Vector3(0, -0.46, 0), Vector3(0, -0.53, 0), 0.075, -1.0, 18)
	m.ring("rivet_gun", "accent", Vector3(0, -0.5, 0), 0.08, 0.012, Vector3.UP, 18, 5)
	m.rod("rivet_gun", "steel", Vector3(0, -0.53, 0), Vector3(0, -tl, 0), 0.05, 0.04, 18)
	m.ring("rivet_gun", "steel", Vector3(0, -tl + 0.01, 0), 0.05, 0.008, Vector3.UP, 18, 5)
	m.rod("rivet_gun", "dark", Vector3(-0.1, -0.44, 0), Vector3(-0.1, -tl + 0.02, 0), 0.016, -1.0, 8)
	m.box("rivet_gun", "rubber", Vector3(-0.1, -tl + 0.01, 0), Vector3(0.08, 0.02, 0.08), 0.006)
	m.rod("rivet_gun", "red_lamp", Vector3(-0.1, -0.3, -0.05), Vector3(-0.1, -0.3, -0.06), 0.012, -1.0, 8)


## B-3's nut runner: a motor body, a reaction arm, a long socket on the drive.
static func _nut_runner(m: YardToolMesh) -> void:
	var tl: float = TOOL_LEN.nut_runner
	m.box("nut_runner", "trim", Vector3(0, -0.05, 0), Vector3(0.18, 0.1, 0.18), 0.02)
	m.rod("nut_runner", "accent", Vector3(0, -0.1, 0), Vector3(0, -0.28, 0), 0.085, 0.08, 20)
	for k in 4:
		m.ring("nut_runner", "dark", Vector3(0, -0.13 - k * 0.04, 0), 0.087, 0.008, Vector3.UP, 20, 4)
	m.rod("nut_runner", "dark", Vector3(0, -0.28, 0), Vector3(0, -0.34, 0), 0.065, 0.05, 18)
	m.rod("nut_runner", "steel", Vector3(0, -0.34, 0), Vector3(0, -tl + 0.04, 0), 0.03, -1.0, 12)
	m.rod("nut_runner", "gunmetal", Vector3(0, -tl + 0.06, 0), Vector3(0, -tl, 0), 0.045, -1.0, 6)
	m.box("nut_runner", "dark", Vector3(0.12, -0.3, 0), Vector3(0.05, 0.14, 0.06), 0.012)
	m.box("nut_runner", "rubber", Vector3(0.12, -0.38, 0), Vector3(0.07, 0.03, 0.08), 0.008)
	m.rod("nut_runner", "red_lamp", Vector3(-0.085, -0.2, 0), Vector3(-0.095, -0.2, 0), 0.012, -1.0, 8)


## F-3's gripper: a heavy rail gripper, two jaws on guide rods, suction pads between them,
## alignment lasers on the jaws.
static func _gripper(m: YardToolMesh) -> void:
	m.box("gripper", "trim", Vector3(0, -0.05, 0), Vector3(0.18, 0.1, 0.18), 0.02)
	m.box("gripper", "gunmetal", Vector3(0, -0.15, 0), Vector3(0.42, 0.1, 0.16), 0.03)
	m.box("gripper", "accent", Vector3(0, -0.15, -0.085), Vector3(0.24, 0.06, 0.02), 0.008)
	for sx: float in [1.0, -1.0]:
		m.rod("gripper", "steel", Vector3(-0.2, -0.2, sx * 0.05), Vector3(0.2, -0.2, sx * 0.05), 0.014, -1.0, 8)
		m.box("gripper", "dark", Vector3(sx * 0.17, -0.3, 0), Vector3(0.06, 0.2, 0.14), 0.016)
		m.box("gripper", "accent", Vector3(sx * 0.15, -0.39, 0), Vector3(0.04, 0.08, 0.14), 0.01)
		m.rod("gripper", "dark", Vector3(sx * 0.07, -0.2, 0), Vector3(sx * 0.07, -0.34, 0), 0.02, -1.0, 8)
		m.rod("gripper", "rubber", Vector3(sx * 0.07, -0.34, 0), Vector3(sx * 0.07, -TOOL_LEN.gripper + 0.02, 0), 0.05, 0.058, 16)
		m.rod("gripper", "red_lamp", Vector3(sx * 0.17, -0.24, -0.07), Vector3(sx * 0.17, -0.24, -0.08), 0.01, -1.0, 6)


## The off hand of the welder, riveter and bolter: a three-fingered clamp hand that braces on
## the work.
static func _clamp(m: YardToolMesh) -> void:
	m.box("clamp", "trim", Vector3(0, -0.04, 0), Vector3(0.16, 0.08, 0.16), 0.02)
	m.box("clamp", "dark", Vector3(0, -0.12, 0), Vector3(0.18, 0.12, 0.13), 0.025)
	m.box("clamp", "accent", Vector3(0, -0.11, -0.07), Vector3(0.12, 0.06, 0.02), 0.008)
	for k: float in [-0.055, 0.055]:
		m.box("clamp", "gunmetal", Vector3(k, -0.21, -0.02), Vector3(0.045, 0.09, 0.05), 0.012, Basis(Vector3.RIGHT, -0.25))
		m.box("clamp", "dark", Vector3(k, -0.27, -0.04), Vector3(0.04, 0.06, 0.045), 0.01, Basis(Vector3.RIGHT, -0.5))
	m.box("clamp", "gunmetal", Vector3(0, -0.2, 0.065), Vector3(0.05, 0.1, 0.05), 0.012, Basis(Vector3.RIGHT, 0.35))
	m.box("clamp", "rubber", Vector3(0, -0.28, 0), Vector3(0.12, 0.03, 0.1), 0.008)
