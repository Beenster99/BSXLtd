extends RefCounted
## Detail for the refurbishment line's machines (RefurbLine): the grinder's toothed shredder
## rotors and spur gears, sparks, the bath's bubbles and vapour, the coater's spray, and the
## sounds made in code like Sfx's (no sound files): the grinder's crunch, the bath's
## bubbling and the hiss as it starts.

const RATE := 22050

static var _sounds: Dictionary = {}


## One mesh from [mesh, transform] pairs (each mesh's first surface).
static func merged(pieces: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Array in pieces:
		st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
	return st.commit()


## A shredder rotor along X: a hex shaft through `discs` cutter discs, each with `teeth`
## hooked teeth, every disc's teeth turned on from the last. `offset` (m) slides the discs
## along so a second rotor's discs fall between them.
static func rotor(length: float, radius: float, discs: int, teeth: int, offset: float) -> ArrayMesh:
	var axis := Basis(Vector3.FORWARD, PI * 0.5)
	var pieces: Array = [[PartShapes.prism(6, radius * 0.24, length + 0.7).mesh, Transform3D(axis, Vector3.ZERO)]]
	var pitch := length / discs
	for i in discs:
		var x := -length * 0.5 + pitch * (i + 0.5) + offset
		pieces.append([PartShapes.prism(16, radius * 0.74, pitch * 0.46).mesh, Transform3D(axis, Vector3(x, 0, 0))])
		for t in teeth:
			var b := Basis(Vector3.RIGHT, TAU * t / teeth + i * 0.95)
			# A hook: tall at its back, sloping away along the turn, standing off the rim.
			pieces.append([PartShapes.wedge(Vector3(pitch * 0.4, radius * 0.36, radius * 0.5)).mesh,
					Transform3D(b, b * Vector3(0, radius * 0.84, 0) + Vector3(x, 0, 0))])
	return merged(pieces)


## A spur gear turning about X: a web with a hub and `teeth` square teeth round its rim.
static func gear(radius: float, width: float, teeth: int) -> ArrayMesh:
	var axis := Basis(Vector3.FORWARD, PI * 0.5)
	var pieces: Array = [[PartShapes.prism(32, radius * 0.88, width).mesh, Transform3D(axis, Vector3.ZERO)],
			[PartShapes.prism(16, radius * 0.3, width * 1.6).mesh, Transform3D(axis, Vector3.ZERO)]]
	for t in teeth:
		var b := Basis(Vector3.RIGHT, TAU * t / teeth)
		pieces.append([PartShapes.box(Vector3(width * 0.9, radius * 0.2, TAU * radius / teeth * 0.5)).mesh,
				Transform3D(b, b * Vector3(0, radius * 0.92, 0))])
	return merged(pieces)


## A colour that glows (over 1 for the bloom) on an unshaded particle, faded by its ramp.
static func _glow_mat(colour: Color, transparent: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = colour
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _ramp(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return float(s[0])))
	g.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return s[1] as Color))
	return g


static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	return c


## Sparks thrown up out of the grinder's nip: short streaks, white-hot to orange, falling.
static func sparks(extents: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Sparks"
	p.emitting = false
	p.amount = 120
	p.lifetime = 0.55
	p.randomness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.6
	p.gravity = Vector3(0, -9.8, 0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.color_ramp = _ramp([[0.0, Color(1, 0.9, 0.6)], [0.2, Color(1, 0.65, 0.2)], [0.7, Color(1, 0.35, 0.08)],
			[1.0, Color(0.6, 0.1, 0.02, 0)]])
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.007, 0.06, 0.007)
	mesh.material = _glow_mat(Color(3.0, 1.9, 0.9), true)
	p.mesh = mesh
	return p


## Bubbles rising through the bath from the floor's sparge pipes.
static func bubbles(extents: Vector3, rise: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Bubbles"
	p.emitting = false
	p.amount = 90
	p.lifetime = sqrt(2.0 * rise / 1.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.gravity = Vector3(0, 1.6, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _curve([Vector2(0, 0.5), Vector2(1, 1)])
	p.color_ramp = _ramp([[0.0, Color(0.8, 1, 0.8, 0.0)], [0.15, Color(0.8, 1, 0.8, 0.7)], [1.0, Color(0.9, 1, 0.9, 0.8)]])
	var mesh := SphereMesh.new()
	mesh.radius = 0.022
	mesh.height = 0.044
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _glow_mat(Color(1.2, 1.6, 1.2), true)
	p.mesh = mesh
	return p


## Bubbles breaking on the surface: rings that spread and fade.
static func pops(extents: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Pops"
	p.emitting = false
	p.amount = 40
	p.lifetime = 0.45
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.gravity = Vector3.ZERO
	p.initial_velocity_max = 0.0
	p.scale_amount_curve = _curve([Vector2(0, 0.3), Vector2(1, 1.6)])
	p.color_ramp = _ramp([[0.0, Color(0.9, 1, 0.9, 0.9)], [1.0, Color(0.9, 1, 0.9, 0)]])
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.03
	mesh.outer_radius = 0.04
	mesh.rings = 12
	mesh.ring_segments = 4
	mesh.material = _glow_mat(Color(1.3, 1.7, 1.3), true)
	p.mesh = mesh
	return p


## Vapour off the bath (or the coater's spray): soft puffs that rise, swell and thin out.
## `one_shot` for the burst as the bath starts.
static func vapour(extents: Vector3, colour: Color, one_shot := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Burst" if one_shot else "Vapour"
	p.emitting = false
	p.one_shot = one_shot
	p.explosiveness = 0.85 if one_shot else 0.0
	p.amount = 40 if one_shot else 30
	p.lifetime = 1.6 if one_shot else 2.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 35.0 if one_shot else 15.0
	p.initial_velocity_min = 0.6 if one_shot else 0.15
	p.initial_velocity_max = 1.6 if one_shot else 0.35
	p.gravity = Vector3(0, 0.2, 0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _curve([Vector2(0, 0.4), Vector2(1, 2.4)])
	var clear := Color(colour, 0.0)
	p.color_ramp = _ramp([[0.0, clear], [0.15, Color(colour, colour.a)], [1.0, clear]])
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 10
	mesh.rings = 5
	var mat := _glow_mat(Color.WHITE, true)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.disable_receive_shadows = true
	mesh.material = mat
	p.mesh = mesh
	return p


## A spray cone out of one coater nozzle toward the lot.
static func spray(colour: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Spray"
	p.emitting = false
	p.amount = 50
	p.lifetime = 0.35
	p.direction = Vector3(0, 0, 1)
	p.spread = 14.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 2.4
	p.gravity = Vector3.ZERO
	p.scale_amount_curve = _curve([Vector2(0, 0.3), Vector2(1, 1.8)])
	p.color_ramp = _ramp([[0.0, Color(colour, 0.7)], [1.0, Color(colour, 0.0)]])
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _glow_mat(Color.WHITE, true)
	p.mesh = mesh
	return p


# --- Sounds -------------------------------------------------------------------------------

## "grind" (loops): a heavy motor under the crunch of the teeth biting. "bubbling" (loops):
## a bath simmering. "hiss" (once): the bath's chemicals going live.
static func sound(which: String) -> AudioStreamWAV:
	if _sounds.has(which):
		return _sounds[which]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(which)
	var samples: PackedFloat32Array
	match which:
		"grind":
			samples = _grind(rng)
		"bubbling":
			samples = _bubbling(rng)
		_:
			samples = _hiss(rng)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	wav.data = bytes
	if which != "hiss":
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	_sounds[which] = wav
	return wav


## A looping 3D player for `which` on `parent`, stopped.
static func loop(which: String, parent: Node3D, volume_db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = which.capitalize() + "Sound"
	p.stream = sound(which)
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 60.0
	parent.add_child(p)
	return p


## Plays `which` once at `parent`.
static func play(which: String, parent: Node3D, volume_db: float) -> void:
	var p := loop(which, parent, volume_db)
	p.finished.connect(p.queue_free)
	p.play()


static func _grind(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var hi := 0.0
	var bite := 0.0
	for i in n:
		var t := float(i) / RATE
		# The motor: whole cycles in the second so it loops cleanly.
		var v := sin(TAU * 50.0 * t) * 0.22 + sin(TAU * 100.0 * t) * 0.12 + sin(TAU * 151.0 * t) * 0.05
		# Teeth biting: a crunch 14 times a second, each a burst of rough noise.
		var phase := fmod(t * 14.0, 1.0)
		if phase < 0.004:
			bite = rng.randf_range(0.5, 1.0)
		bite *= 0.9993
		low += 0.08 * (rng.randf_range(-1.0, 1.0) - low)
		hi += 0.5 * (rng.randf_range(-1.0, 1.0) - hi)
		out[i] = v + low * 0.5 + hi * bite * 0.35 * (1.0 - phase)
	_seam(out)
	return out


static func _bubbling(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := RATE * 2
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		y += 0.03 * (rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * 0.25
	# Each bubble a little rising blip.
	for b in 70:
		var at := rng.randi_range(0, n - 1)
		var f := rng.randf_range(260.0, 900.0)
		var span := int(rng.randf_range(0.02, 0.06) * RATE)
		var amp := rng.randf_range(0.08, 0.3)
		for j in span:
			var k := (at + j) % n
			var t := float(j) / RATE
			out[k] += sin(TAU * f * t * (1.0 + t * 12.0)) * amp * exp(-t * 70.0)
	return out


static func _hiss(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(1.8 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		low += 0.25 * (w - low)
		var env := minf(t / 0.04, 1.0) * (1.0 if t < 0.5 else exp(-(t - 0.5) * 2.6))
		# Noise less its low end: the sharp hiss of gas through a valve, with a pop at the start.
		out[i] = (w - low) * 0.7 * env + (sin(TAU * 90.0 * t) * exp(-t * 30.0) * 0.4)
	return out


## Blends a loop's last samples into its first so it repeats without a click.
static func _seam(out: PackedFloat32Array) -> void:
	var n := out.size()
	for i in 400:
		var w := float(i) / 400.0
		out[n - 400 + i] = lerpf(out[n - 400 + i], out[i], w)
