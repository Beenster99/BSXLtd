extends RefCounted
## The sleeping quarters (0.4.1 playtest: "the place needs sleeping quarters" and "the feeling
## that our station is a living space"): x 20..44, z 0..12, off the corridor (door at x 31..33)
## and the crew room. Eight cabins off a soft-lit aisle, each with Void Salvage's own bunk,
## locker and seat (VsParts), a desk with someone's things on it, a reading lamp, a rug, a
## poster, a curtain half drawn and its owner's name; night strips along the aisle's floor, a
## noticeboard and a water cooler. Built once into the station's kit.

const Kit := preload("res://modules/yard/internal/yard_kit.gd")

const X0 := 20.0
const X1 := 44.0
const Z0 := 0.0
const Z1 := 12.0
## The aisle down the middle (z from, to) and the corridor door's opening (x from, to).
const AISLE := Vector2(4.6, 7.4)
const DOOR := Vector2(31.0, 33.0)
const NAMES: PackedStringArray = ["R. OKAFOR", "J. LINDQVIST", "M. TANAKA", "S. BRENNAN", "A. KOVAC", "D. ADEYEMI",
		"L. MORENO", "K. HALE"]
const POSTERS: Array[Color] = [Color(0.9, 0.45, 0.15), Color(0.2, 0.5, 0.8), Color(0.75, 0.2, 0.3), Color(0.3, 0.65, 0.4),
		Color(0.85, 0.75, 0.3), Color(0.5, 0.35, 0.75), Color(0.15, 0.6, 0.65), Color(0.8, 0.5, 0.6)]
const RUGS: Array[Color] = [Color(0.45, 0.2, 0.15), Color(0.2, 0.28, 0.4), Color(0.35, 0.33, 0.22), Color(0.3, 0.18, 0.3)]

var _kit
var _root: Node3D
var cabins: Array[Dictionary] = []


func build(kit, root: Node3D) -> void:
	_kit = kit
	_root = root
	var k = kit
	var partition: Material = k.paint(Color(0.82, 0.8, 0.76), 0.05, 0.7, "satin_paint")
	var trim: Material = k.paint(Kit.DARK, 0.6, 0.45, "gunmetal")
	# North side: two cabins either side of the way in from the corridor; south side: four.
	var spans: Array[Vector2] = [Vector2(X0, 25.5), Vector2(25.5, DOOR.x), Vector2(DOOR.y, 38.5), Vector2(38.5, X1),
			Vector2(X0, 26.0), Vector2(26.0, 32.0), Vector2(32.0, 38.0), Vector2(38.0, X1)]
	for i in spans.size():
		var north := i < 4
		var z0 := Z0 if north else AISLE.y
		var z1 := AISLE.x if north else Z1
		_cabin(i, spans[i], z0, z1, north, partition, trim)
	# The way in from the corridor: its walls either side, back to the aisle.
	for x: float in [DOOR.x, DOOR.y]:
		k.box(Vector3(0.12, 2.6, AISLE.x - Z0), Vector3(x, 1.3, (Z0 + AISLE.x) * 0.5), partition)
	# The aisle: a runner down it, night strips along its edges, warm dim lamps.
	k.box(Vector3(X1 - X0 - 1.0, 0.012, 1.4), Vector3((X0 + X1) * 0.5, 0.006, (AISLE.x + AISLE.y) * 0.5),
			k.paint(Color(0.22, 0.26, 0.32), 0.0, 0.95, "plastic_textured"), false)
	for z: float in [AISLE.x + 0.08, AISLE.y - 0.08]:
		k.box(Vector3(X1 - X0 - 0.6, 0.03, 0.04), Vector3((X0 + X1) * 0.5, 0.05, z), k.glow(Color(0.25, 0.55, 1.0), 2.0), false)
	for x: float in [24.0, 32.0, 40.0]:
		k.ceiling_lamp(Vector3(x, 3.2, (AISLE.x + AISLE.y) * 0.5), Vector2(1.6, 0.4), 0.5, 7.0)
	# A noticeboard by the crew room door and a water cooler.
	k.box(Vector3(0.04, 0.9, 1.4), Vector3(X0 + 0.14, 1.6, 3.3), k.paint(Color(0.55, 0.42, 0.28), 0.0, 0.9), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for n in 7:
		var c := Color.from_hsv(rng.randf(), 0.15, 0.95)
		k.box(Vector3(0.01, 0.2, 0.15), Vector3(X0 + 0.17 + n * 0.0012, 1.35 + rng.randf() * 0.5, 2.8 + rng.randf() * 1.0),
				k.paint(c, 0.0, 0.9), false)
	k.sign("ROTA", Vector3(X0 + 0.18, 2.12, 3.3), Vector3.RIGHT, 0.004, Kit.DARK)
	k.box(Vector3(0.35, 1.0, 0.35), Vector3(X1 - 0.4, 0.5, AISLE.x + 0.3), k.paint(Color(0.85, 0.86, 0.88), 0.1, 0.4))
	k.box(Vector3(0.28, 0.4, 0.28), Vector3(X1 - 0.4, 1.2, AISLE.x + 0.3), k.glass())
	k.sign("QUIET PLEASE  ·  NIGHT SHIFT SLEEPING", Vector3(X1 - 0.11, 2.4, 6.0), Vector3.LEFT, 0.004, Kit.HULL)


## One cabin from x span.x to span.y, z0 to z1, its bunk against the hull side.
func _cabin(i: int, span: Vector2, z0: float, z1: float, north: bool, partition: Material, trim: Material) -> void:
	var k = _kit
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + i
	var mid_x := (span.x + span.y) * 0.5
	var back_z := z0 if north else z1   # the hull side
	var front_z := z1 if north else z0   # on the aisle
	var inward := 1.0 if north else -1.0   # from the back wall into the cabin
	# Partitions between cabins.
	# Each partition is drawn once, by the cabin to its west.
	if span.y != X1 and span.y != DOOR.x:
		k.box(Vector3(0.12, 2.6, z1 - z0), Vector3(span.y, 1.3, (z0 + z1) * 0.5), partition)
	# A front: stubs either side, a curtain rail and a curtain half drawn.
	var w := span.y - span.x
	for side: float in [-1.0, 1.0]:
		k.box(Vector3(0.5, 2.6, 0.1), Vector3(mid_x + side * (w * 0.5 - 0.31), 1.3, front_z), partition)
	k.box(Vector3(w - 0.2, 0.05, 0.05), Vector3(mid_x, 2.35, front_z - inward * 0.12), trim, false)
	var cloth: Material = k.paint(RUGS[i % RUGS.size()].lightened(0.25), 0.0, 0.95, "plastic_textured")
	var drawn := 0.35 + 0.3 * rng.randf()
	for f in 5:   # folds
		var fx := span.x + 0.6 + f * (w - 1.2) * drawn / 4.0
		k.box(Vector3((w - 1.2) * drawn / 4.5, 2.2, 0.04), Vector3(fx, 1.25, front_z - inward * (0.12 + (f % 2) * 0.05)), cloth, false)
	# The bunk along the back wall, a locker beside it, the desk and its seat, a rug.
	var bunk_at := Vector3(mid_x - w * 0.12, 0.0, back_z + inward * 0.55)
	_vs("Bunk", bunk_at, PI * 0.5)
	_vs("Locker", Vector3(span.y - 0.55, 0.0, back_z + inward * 0.4), 0.0 if north else PI)
	var desk := Vector3(span.x + 0.75, 0.0, (z0 + z1) * 0.5 + inward * 0.6)
	k.box(Vector3(1.0, 0.05, 0.6), desk + Vector3(0, 0.74, 0), k.paint(Color(0.62, 0.5, 0.36), 0.0, 0.6))
	k.box(Vector3(0.9, 0.7, 0.04), desk + Vector3(0, 0.36, -0.26), trim)
	_vs("Seat", desk + Vector3(0.55, 0.0, 0.1), -PI * 0.5)
	k.box(Vector3(w * 0.5, 0.01, 1.6), Vector3(mid_x + 0.3, 0.005, (z0 + z1) * 0.5 + inward * 0.2),
			k.paint(RUGS[(i + 1) % RUGS.size()], 0.0, 1.0, "plastic_textured"), false)
	# Someone's things on the desk: a mug, a book or two, a tablet with its screen on.
	k.box(Vector3(0.08, 0.1, 0.08), desk + Vector3(-0.3, 0.82, 0.1), k.paint(POSTERS[i].darkened(0.2), 0.0, 0.5), false)
	for b in 1 + rng.randi() % 3:
		var bc := Color.from_hsv(rng.randf(), 0.5, 0.6)
		k.box(Vector3(0.22, 0.04, 0.16), desk + Vector3(0.1, 0.79 + b * 0.04, -0.05), k.paint(bc, 0.0, 0.8), false)
	k.box(Vector3(0.24, 0.01, 0.17), desk + Vector3(0.3, 0.775, 0.12), k.glow(Color(0.3, 0.6, 1.0), 1.2), false)
	# A reading lamp over the bunk, warm.
	var lamp_at := Vector3(bunk_at.x + 0.9, 1.75, back_z + inward * 0.12)
	k.box(Vector3(0.18, 0.1, 0.14), lamp_at, k.glow(Color(1.0, 0.78, 0.5), 2.5), false)
	var warm := OmniLight3D.new()
	warm.name = "CabinLamp%d" % i
	warm.position = lamp_at + Vector3(0, -0.2, inward * 0.4)
	warm.light_color = Color(1.0, 0.74, 0.48)
	warm.light_energy = 0.55
	warm.omni_range = 3.6
	warm.omni_attenuation = 1.4
	warm.light_specular = 0.2
	_root.add_child(warm)
	# A poster on the side wall and the owner's name by the curtain.
	var px := span.x + 0.08 if span.x != DOOR.y else span.x + 0.08
	k.box(Vector3(0.02, 0.9, 0.65), Vector3(px, 1.7, (z0 + z1) * 0.5 - inward * 0.6), k.paint(POSTERS[i], 0.0, 0.7), false)
	k.box(Vector3(0.025, 0.6, 0.45), Vector3(px + 0.006, 1.74, (z0 + z1) * 0.5 - inward * 0.6), k.paint(POSTERS[(i + 3) % POSTERS.size()].lightened(0.3), 0.0, 0.7), false)
	var plate_at := Vector3(mid_x + w * 0.5 - 0.31, 1.75, front_z - inward * 0.07)
	k.sign(NAMES[i], plate_at, Vector3(0, 0, -inward), 0.0035, Kit.HULL)
	cabins.append({"id": i, "name": NAMES[i], "bunk": bunk_at, "span": span, "z": Vector2(z0, z1)})


## A Void Salvage part stood on the floor at `at` (its bottom on y = at.y, its middle over at),
## turned `yaw` about y, solid.
func _vs(id: String, at: Vector3, yaw: float) -> Node3D:
	var n := VsParts.instance(id)
	if n == null:
		return null
	var shape := VsParts.shape(id)
	var box := shape.mesh.get_aabb()
	var basis := Basis(Vector3.UP, yaw)
	var offset := basis * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	n.transform = Transform3D(basis, at - offset)
	n.name = "%s_%d" % [id, _root.get_child_count()]
	_root.add_child(n)
	if shape.collision != null:
		var cs := CollisionShape3D.new()
		cs.shape = shape.collision
		cs.transform = n.transform
		_kit.body.add_child(cs)
	return n
