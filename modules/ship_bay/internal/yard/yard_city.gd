extends Node3D
## The city round the shipyard: a busy industrial metropolis on the plain. Close in, a ring
## of other works (sheds, stacks with smoke, tank farms, rival yards' gantry cranes, pipe
## racks); further out, the towers of the city, thickest round downtown to the north-west,
## their windows lit at night and beacons blinking on the tall ones; avenues with street
## lamps and hover trucks; and the sky busy with hover traffic in lanes and cargo ships
## coming and going. All presentation: built once from a fixed seed, every repeated piece a
## MultiMesh, only the near works solid to walk into.
##   var city := YardCity.new(); yard.add_child(city); city.set_night(0.8)

## The yard and its apron, props and road stay clear of the city (x, z, metres).
const KEEP_OUT := Rect2(-200, -100, 400, 270)
## The road from the truck doors runs west through the city along this z, metres.
const ROAD_Z := 30.0
const ROAD_HALF := 12.0
## The city's reach and its plots' pitch, metres.
const REACH := 1150.0
const PLOT := 46.0
## Inside this distance the plots are works, beyond it city blocks, metres.
const WORKS_OUT := 330.0
## Every so many plots an avenue runs through instead (both ways).
const AVENUE_EVERY := 4
## Downtown, where the towers are tallest (x, z, metres).
const DOWNTOWN := Vector2(-560, -620)
## Window pitch on the towers' faces (across, up), metres.
const WINDOW := Vector2(3.2, 3.6)

var night := 0.0
## Moving things: hover cars in sky lanes, trucks on the avenues, cargo ships.
var cars: Array[Dictionary] = []
var trucks: Array[Dictionary] = []
var ships: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}   # key -> {mesh, mat, xforms, colours, shadows}
var _solid: StaticBody3D
var _window_mat: StandardMaterial3D
var _beacon_mat: StandardMaterial3D
var _lamp_mat: StandardMaterial3D
var _car_mm: MultiMesh
var _car_lights: MultiMesh
var _truck_mm: MultiMesh
var _ship_nodes: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	name = "City"
	_rng.seed = 7719
	_solid = StaticBody3D.new()
	_solid.name = "CitySolid"
	add_child(_solid)
	_materials()
	_build_plots()
	_build_avenues()
	_flush()
	_build_traffic()
	_build_ships()
	set_night(night)


## 0 by day .. 1 at full night: windows, street lamps and running lights come up.
func set_night(n: float) -> void:
	night = clampf(n, 0.0, 1.0)
	if _window_mat:
		_window_mat.emission_energy_multiplier = lerpf(0.0, 0.32, night)
	if _lamp_mat:
		_lamp_mat.emission_energy_multiplier = lerpf(0.0, 5.0, night)


## How many towers, works and moving things the city has (tests and the build report).
func counts() -> Dictionary:
	var out := {"cars": cars.size(), "trucks": trucks.size(), "ships": ships.size()}
	for key: String in _batches:
		out[key] = (_batches[key]["xforms"] as Array).size()
	for mmi: MultiMeshInstance3D in find_children("*", "MultiMeshInstance3D", false, false):
		if not out.has(mmi.name):
			out[mmi.name] = mmi.multimesh.instance_count
	return out


func _process(delta: float) -> void:
	_time += delta
	_move_cars(delta)
	_move_trucks(delta)
	_move_ships(delta)
	if _beacon_mat:
		_beacon_mat.emission_energy_multiplier = 6.0 if fmod(_time, 1.6) < 0.35 else 0.4


# --- Materials --------------------------------------------------------------------------------

func _materials() -> void:
	# A tile of 4 x 4 windows: dark glass in pale frames; the emission lights some of them.
	var size := 64
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var lit := Image.create(size, size, false, Image.FORMAT_RGB8)
	albedo.fill(Color(0.5, 0.52, 0.55))
	lit.fill(Color.BLACK)
	var cell := size / 4
	for i in 4:
		for j in 4:
			var glass := Rect2i(i * cell + 2, j * cell + 3, cell - 4, cell - 6)
			albedo.fill_rect(glass, Color(0.12, 0.15, 0.19).lerp(Color(0.2, 0.26, 0.3), _rng.randf()))
			var r := _rng.randf()
			if r < 0.42:
				var warm := Color(1.0, 0.76, 0.42) if r < 0.3 else Color(0.6, 0.8, 1.0)
				lit.fill_rect(glass, warm * _rng.randf_range(0.35, 0.8))
	_window_mat = StandardMaterial3D.new()
	_window_mat.albedo_texture = ImageTexture.create_from_image(albedo)
	_window_mat.emission_enabled = true
	_window_mat.emission_texture = ImageTexture.create_from_image(lit)
	_window_mat.emission = Color.WHITE
	_window_mat.uv1_triplanar = true
	_window_mat.uv1_world_triplanar = true
	_window_mat.uv1_scale = Vector3(1.0 / (WINDOW.x * 4.0), 1.0 / (WINDOW.y * 4.0), 1.0 / (WINDOW.x * 4.0))
	_window_mat.vertex_color_use_as_albedo = true
	_window_mat.roughness = 0.35
	_window_mat.metallic = 0.3
	_window_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_beacon_mat = _glow(Color(1.0, 0.1, 0.05), 6.0)
	_lamp_mat = _glow(Color(1.0, 0.82, 0.55), 5.0)


func _plain(c: Color, metallic := 0.2, roughness := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	m.vertex_color_use_as_albedo = true
	return m


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


# --- Plots ------------------------------------------------------------------------------------

func _build_plots() -> void:
	var n := int(REACH / PLOT)
	for gx in range(-n, n + 1):
		for gz in range(-n, n + 1):
			if posmod(gx, AVENUE_EVERY) == 0 or posmod(gz, AVENUE_EVERY) == 0:
				continue
			var c := Vector2(gx * PLOT, gz * PLOT)
			var d := c.length()
			if d > REACH or KEEP_OUT.grow(PLOT * 0.5).has_point(c):
				continue
			if absf(c.y - ROAD_Z) < ROAD_HALF + PLOT * 0.5 and c.x < KEEP_OUT.position.x:
				continue
			# Plots thin out at the edge.
			if d > REACH - 250.0 and _rng.randf() < (d - (REACH - 250.0)) / 300.0:
				continue
			if d < WORKS_OUT:
				_works(c, d)
			else:
				_tower_block(c, d)


## A plot of works close to the yard: a shed, a rival yard's gantry crane, a tank farm or
## a stack with its smoke. These are solid.
func _works(c: Vector2, d: float) -> void:
	var r := _rng.randf()
	var at := Vector3(c.x, 0, c.y) + Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
	var yaw := (PI * 0.5) * _rng.randi_range(0, 1)
	if r < 0.45:
		# A big shed: cladding in works colours, a darker roof, a lit band of clerestory windows.
		var size := Vector3(_rng.randf_range(22, 36), _rng.randf_range(9, 17), _rng.randf_range(16, 32))
		var col: Color = [Color(0.72, 0.72, 0.7), Color(0.58, 0.6, 0.62), Color(0.62, 0.5, 0.38), Color(0.4, 0.46, 0.52)][_rng.randi_range(0, 3)]
		var b := Basis(Vector3.UP, yaw)
		_add("shed", Transform3D(b.scaled(size), at + Vector3(0, size.y * 0.5, 0)), col)
		_add("roof", Transform3D(b.scaled(Vector3(size.x + 0.6, 0.6, size.z + 0.6)), at + Vector3(0, size.y + 0.3, 0)), Color(0.22, 0.23, 0.25))
		_add("band", Transform3D(b.scaled(Vector3(size.x + 0.05, 1.4, size.z + 0.05)), at + Vector3(0, size.y - 1.6, 0)), Color(0.5, 0.52, 0.55))
		_add("door", Transform3D(b.scaled(Vector3(size.x * 0.4, size.y * 0.6, size.z + 0.1)), at + Vector3(0, size.y * 0.3, 0)), Color(0.9, 0.55, 0.15))
		_collide(at + Vector3(0, size.y * 0.5, 0), b, size)
	elif r < 0.62:
		# A rival yard's gantry crane over a slab.
		var span := _rng.randf_range(24, 34)
		var high := _rng.randf_range(18, 30)
		var b := Basis(Vector3.UP, yaw)
		_add("slab", Transform3D(b.scaled(Vector3(span + 8, 0.2, span + 4)), at + Vector3(0, 0.1, 0)), Color(0.5, 0.5, 0.5))
		for s: float in [-1.0, 1.0]:
			var leg := at + b * Vector3(s * span * 0.5, high * 0.5, 0)
			_add("crane", Transform3D(b.scaled(Vector3(1.4, high, 1.4)), leg), Color(0.95, 0.72, 0.1))
			_add("crane", Transform3D(b.scaled(Vector3(1.6, 0.8, 8.0)), at + b * Vector3(s * span * 0.5, 0.4, 0)), Color(0.95, 0.72, 0.1))
			_collide(leg, b, Vector3(1.4, high, 1.4))
		_add("crane", Transform3D(b.scaled(Vector3(span + 4, 2.2, 2.0)), at + Vector3(0, high + 1.1, 0)), Color(0.95, 0.72, 0.1))
		_add("cab", Transform3D(b.scaled(Vector3(3, 2.4, 2.6)), at + b * Vector3(_rng.randf_range(-span * 0.3, span * 0.3), high - 1.5, 0)), Color(0.85, 0.85, 0.8))
		# A hull on its cradles under it.
		var hull := Vector3(span * 0.6, _rng.randf_range(5, 8), _rng.randf_range(9, 14))
		_add("shed", Transform3D(b.scaled(Vector3(hull.z, hull.y, hull.x)) * Basis(Vector3.UP, PI * 0.5), at + Vector3(0, hull.y * 0.5 + 1.2, 0)),
				[Color(0.5, 0.55, 0.62), Color(0.7, 0.42, 0.25), Color(0.85, 0.85, 0.82)][_rng.randi_range(0, 2)])
		_collide(at + Vector3(0, hull.y * 0.5 + 1.2, 0), b * Basis(Vector3.UP, PI * 0.5), Vector3(hull.z, hull.y + 2.4, hull.x))
	elif r < 0.8:
		# A tank farm: a row of upright tanks and a pipe rack.
		var b := Basis(Vector3.UP, yaw)
		var count := _rng.randi_range(2, 4)
		var rad := _rng.randf_range(4, 7)
		var high := _rng.randf_range(10, 18)
		for i in count:
			var p := at + b * Vector3((i - (count - 1) * 0.5) * rad * 2.3, high * 0.5, 0)
			_add("tank", Transform3D(Basis().scaled(Vector3(rad, high, rad)), p), Color(0.82, 0.82, 0.8))
			_add("tank_top", Transform3D(Basis().scaled(Vector3(rad, rad * 0.35, rad)), p + Vector3(0, high * 0.5, 0)), Color(0.7, 0.7, 0.7))
			_collide(p, Basis(), Vector3(rad * 1.8, high, rad * 1.8))
		_add("pipe", Transform3D(b.scaled(Vector3(count * rad * 2.3, 0.8, 0.8)), at + b * Vector3(0, 3.5, rad + 2.0)), Color(0.55, 0.57, 0.6))
	else:
		# A stack (a chimney with red bands) by a boiler house, smoking.
		var high := _rng.randf_range(35, 70)
		var rad := _rng.randf_range(2.0, 3.4)
		_add("stack", Transform3D(Basis().scaled(Vector3(rad, high, rad)), at + Vector3(0, high * 0.5, 0)), Color(0.75, 0.72, 0.68))
		for k in 2:
			_add("stack", Transform3D(Basis().scaled(Vector3(rad + 0.08, 2.0, rad + 0.08)), at + Vector3(0, high - 3.0 - k * 6.0, 0)), Color(0.75, 0.15, 0.1))
		_add("beacon", Transform3D(Basis().scaled(Vector3.ONE * 0.8), at + Vector3(0, high + 0.4, 0)), Color.WHITE)
		_collide(at + Vector3(0, high * 0.5, 0), Basis(), Vector3(rad * 1.8, high, rad * 1.8))
		var house := Vector3(14, 9, 12)
		var hp := at + Vector3(rad + 8, house.y * 0.5, 0)
		_add("shed", Transform3D(Basis().scaled(house), hp), Color(0.55, 0.5, 0.45))
		_collide(hp, Basis(), house)
		_smoke(at + Vector3(0, high + 1.0, 0), rad)


## A city block: one to three towers with set-back tiers, roofs and beacons on the tall ones.
func _tower_block(c: Vector2, d: float) -> void:
	var to_downtown := c.distance_to(DOWNTOWN)
	var tall := clampf(1.0 - to_downtown / 900.0, 0.0, 1.0)
	var count := _rng.randi_range(1, 3) if tall < 0.6 else _rng.randi_range(1, 2)
	var palettes := [Color(0.78, 0.8, 0.84), Color(0.42, 0.5, 0.6), Color(0.66, 0.58, 0.48), Color(0.34, 0.38, 0.44), Color(0.85, 0.84, 0.8), Color(0.55, 0.36, 0.3)]
	for i in count:
		var foot := Vector2(_rng.randf_range(12, 22), _rng.randf_range(12, 22)) * (1.0 if count == 1 else 0.7)
		var off := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * (PLOT * 0.5 - foot.length() * 0.5 - 3.0)
		var base := Vector3(c.x + off.x, 0, c.y + off.y)
		var h := 24.0 + pow(_rng.randf(), 1.8) * (60.0 + tall * 300.0)
		var col: Color = palettes[_rng.randi_range(0, palettes.size() - 1)]
		var tiers := 1 if h < 70.0 else _rng.randi_range(2, 3)
		var y := 0.0
		var size := Vector3(foot.x, 0, foot.y)
		for t in tiers:
			var th: float = h * ([1.0] if tiers == 1 else ([0.65, 0.35] if tiers == 2 else [0.5, 0.3, 0.2]))[t]
			var s := Vector3(size.x, th, size.z)
			_add("tower", Transform3D(Basis().scaled(s), base + Vector3(0, y + th * 0.5, 0)), col)
			y += th
			_add("roof", Transform3D(Basis().scaled(Vector3(s.x + 0.4, 0.8, s.z + 0.4)), base + Vector3(0, y + 0.4, 0)), Color(0.18, 0.19, 0.21))
			size = Vector3(size.x * _rng.randf_range(0.6, 0.8), 0, size.z * _rng.randf_range(0.6, 0.8))
		if h > 110.0:
			_add("mast", Transform3D(Basis().scaled(Vector3(0.6, h * 0.12, 0.6)), base + Vector3(0, y + h * 0.06, 0)), Color(0.6, 0.6, 0.62))
			_add("beacon", Transform3D(Basis().scaled(Vector3.ONE * 1.6), base + Vector3(0, y + h * 0.12 + 0.8, 0)), Color.WHITE)
		elif _rng.randf() < 0.5:
			# Roof plant.
			_add("roof", Transform3D(Basis().scaled(Vector3(size.x * 0.5, 3.0, size.z * 0.4)), base + Vector3(0, y + 2.3, 0)), Color(0.4, 0.42, 0.45))


## Avenues on the grid's lines, the road west along ROAD_Z, street lamps down them.
func _build_avenues() -> void:
	var n := int(REACH / PLOT)
	var asphalt := Color(0.16, 0.16, 0.17)
	for g in range(-n, n + 1):
		if posmod(g, AVENUE_EVERY) != 0:
			continue
		var line := g * PLOT
		for along_x: bool in [true, false]:
			# Each avenue in two halves either side of the yard, stopping at its keep-out.
			for half: Array in _avenue_spans(line, along_x):
				var a: float = half[0]
				var b: float = half[1]
				if b - a < 20.0:
					continue
				var mid := (a + b) * 0.5
				var centre := Vector3(mid, 0.01, line) if along_x else Vector3(line, 0.01, mid)
				var size := Vector3(b - a, 0.02, 16.0) if along_x else Vector3(16.0, 0.02, b - a)
				_add("asphalt", Transform3D(Basis().scaled(size), centre), asphalt, false)
				var s := a + 20.0
				while s < b:
					for side: float in [-1.0, 1.0]:
						var p := Vector3(s, 0, line + side * 9.0) if along_x else Vector3(line + side * 9.0, 0, s)
						_add("pole", Transform3D(Basis().scaled(Vector3(0.25, 9.0, 0.25)), p + Vector3(0, 4.5, 0)), Color(0.3, 0.3, 0.32), false)
						_add("lamp", Transform3D(Basis().scaled(Vector3(1.2, 0.35, 0.6)), p + Vector3(0, 9.0, 0) - (Vector3(0, 0, side) if along_x else Vector3(side, 0, 0)) * 0.8), Color.WHITE, false)
					s += 60.0
	# The road west from the truck doors.
	var west := KEEP_OUT.position.x
	_add("asphalt", Transform3D(Basis().scaled(Vector3(REACH + west, 0.02, ROAD_HALF * 1.4)), Vector3((west - REACH) * 0.5, 0.01, ROAD_Z)), asphalt, false)


## The parts of the avenue along line `line` (along x or z) outside the yard's keep-out and
## within the city: [[from, to], ...].
func _avenue_spans(line: float, along_x: bool) -> Array:
	var lo := -REACH
	var hi := REACH
	var k0 := KEEP_OUT.position.y if along_x else KEEP_OUT.position.x
	var k1 := KEEP_OUT.end.y if along_x else KEEP_OUT.end.x
	var crosses := line > k0 and line < k1
	if not crosses:
		return [[lo, hi]]
	var a0 := KEEP_OUT.position.x if along_x else KEEP_OUT.position.y
	var a1 := KEEP_OUT.end.x if along_x else KEEP_OUT.end.y
	return [[lo, a0], [a1, hi]]


# --- Batches ----------------------------------------------------------------------------------

const MESHES := {
	"shed": "box", "roof": "box", "band": "box", "door": "box", "slab": "box", "crane": "box", "cab": "box",
	"tank": "cyl", "tank_top": "dome", "pipe": "box", "stack": "cyl", "beacon": "ball", "tower": "box",
	"mast": "box", "asphalt": "box", "pole": "box", "lamp": "box",
}


func _add(key: String, xform: Transform3D, colour: Color, shadows := true) -> void:
	if not _batches.has(key):
		_batches[key] = {"xforms": [], "colours": [], "shadows": shadows}
	(_batches[key]["xforms"] as Array).append(xform)
	(_batches[key]["colours"] as Array).append(colour)


func _flush() -> void:
	for key: String in _batches:
		var b: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mesh_for(str(MESHES.get(key, "box")))
		var xs: Array = b["xforms"]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
			mm.set_instance_color(i, b["colours"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key
		mmi.multimesh = mm
		mmi.material_override = _mat_for(key)
		var far := key == "tower" or key == "roof" or key == "mast" or not bool(b["shadows"])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)


func _mesh_for(kind: String) -> Mesh:
	match kind:
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 14
			c.rings = 1
			return c
		"dome":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 0.5
			s.is_hemisphere = true
			s.radial_segments = 14
			s.rings = 4
			return s
		"ball":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 8
			s.rings = 4
			return s
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return b


var _mats: Dictionary = {}


func _mat_for(key: String) -> Material:
	match key:
		"tower":
			return _window_mat
		"beacon":
			return _beacon_mat
		"lamp":
			return _lamp_mat
	var metal := key in ["crane", "tank", "tank_top", "pipe", "pole", "mast"]
	var id := "metal" if metal else "plain"
	if not _mats.has(id):
		_mats[id] = _plain(Color.WHITE, 0.45 if metal else 0.05, 0.55 if metal else 0.85)
	return _mats[id]


func _collide(centre: Vector3, basis: Basis, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(basis.orthonormalized(), centre)
	_solid.add_child(shape)


## Grey smoke puffing up out of a stack's top, drifting with the wind.
func _smoke(top: Vector3, radius: float) -> void:
	var p := GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 18
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.position = top
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 90, 80))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.35, 1, 0.15)
	pm.spread = 12.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0.6, 0.25, 0.2)
	pm.scale_min = radius * 1.6
	pm.scale_max = radius * 2.4
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 3.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(0.55, 0.55, 0.56, 0.55))
	fade.set_color(1, Color(0.7, 0.7, 0.72, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	pm.color_ramp = fade_tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff()
	quad.material = m
	p.draw_pass_1 = quad
	add_child(p)


var _puff_tex: Texture2D


func _puff() -> Texture2D:
	if _puff_tex:
		return _puff_tex
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for x in size:
		for y in size:
			var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.5))
	_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex


# --- Traffic ----------------------------------------------------------------------------------

## Hover cars in sky lanes (rings round downtown and the yard at several heights, each way)
## and trucks down the avenues.
func _build_traffic() -> void:
	var lanes := [
		[Vector2(-200, -150), 520.0, 60.0, 1.0], [Vector2(-200, -150), 540.0, 75.0, -1.0],
		[DOWNTOWN, 300.0, 130.0, 1.0], [DOWNTOWN, 320.0, 150.0, -1.0],
		[Vector2(-50, 0), 820.0, 95.0, 1.0], [Vector2(-50, 0), 850.0, 110.0, -1.0],
		[Vector2(300, 500), 260.0, 70.0, -1.0], [Vector2(-700, 400), 220.0, 85.0, 1.0],
	]
	for lane: Array in lanes:
		var count := int(TAU * float(lane[1]) / 38.0)
		for i in count:
			cars.append({"centre": lane[0], "radius": float(lane[1]) + _rng.randf_range(-6, 6), "height": float(lane[2]) + _rng.randf_range(-3, 3),
					"way": float(lane[3]), "a": TAU * (i + _rng.randf()) / count, "speed": _rng.randf_range(24.0, 38.0)})
	_car_mm = _moving_mm("Cars", _car_body(), _plain(Color(0.85, 0.86, 0.88), 0.6, 0.3), cars.size())
	_car_lights = _moving_mm("CarLights", _car_lamp(), _glow(Color(1.0, 0.95, 0.85), 4.0), cars.size())
	# Trucks on the avenues, both ways.
	var n := int(REACH / PLOT)
	for g in range(-n, n + 1):
		if posmod(g, AVENUE_EVERY) != 0 or _rng.randf() < 0.35:
			continue
		var along_x := _rng.randf() < 0.5
		for half: Array in _avenue_spans(g * PLOT, along_x):
			if float(half[1]) - float(half[0]) < 200.0:
				continue
			for k in _rng.randi_range(1, 3):
				var way := 1.0 if k % 2 == 0 else -1.0
				trucks.append({"line": g * PLOT, "along_x": along_x, "from": float(half[0]), "to": float(half[1]), "way": way,
						"s": _rng.randf_range(float(half[0]), float(half[1])), "speed": _rng.randf_range(10.0, 16.0)})
	_truck_mm = _moving_mm("Trucks", _truck_body(), _plain(Color(0.9, 0.55, 0.15), 0.3, 0.6), trucks.size())
	_move_cars(0.0)
	_move_trucks(0.0)


func _moving_mm(node_name: String, mesh: Mesh, mat: Material, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


func _car_body() -> Mesh:
	var b := BoxMesh.new()
	b.size = Vector3(2.2, 1.0, 4.6)
	return b


## A hover car's head and tail lights as one strip, a little wider than the car.
func _car_lamp() -> Mesh:
	var b := BoxMesh.new()
	b.size = Vector3(2.4, 0.25, 4.9)
	return b


func _truck_body() -> Mesh:
	var b := BoxMesh.new()
	b.size = Vector3(3.0, 3.2, 11.0)
	return b


func _move_cars(delta: float) -> void:
	if _car_mm == null:
		return
	for i in cars.size():
		var c: Dictionary = cars[i]
		c["a"] = float(c["a"]) + float(c["way"]) * float(c["speed"]) / float(c["radius"]) * delta
		var a: float = c["a"]
		var centre: Vector2 = c["centre"]
		var pos := Vector3(centre.x + cos(a) * float(c["radius"]), float(c["height"]) + sin(a * 3.0 + i) * 2.0, centre.y + sin(a) * float(c["radius"]))
		var tangent := Vector3(-sin(a), 0, cos(a)) * float(c["way"])
		var xf := Transform3D(Basis.looking_at(tangent, Vector3.UP), pos)
		_car_mm.set_instance_transform(i, xf)
		_car_lights.set_instance_transform(i, xf.translated_local(Vector3(0, -0.45, 0)))


func _move_trucks(delta: float) -> void:
	if _truck_mm == null:
		return
	for i in trucks.size():
		var t: Dictionary = trucks[i]
		var s := float(t["s"]) + float(t["way"]) * float(t["speed"]) * delta
		if s > float(t["to"]):
			s = float(t["from"])
		elif s < float(t["from"]):
			s = float(t["to"])
		t["s"] = s
		var lane := float(t["line"]) + float(t["way"]) * 3.5
		var pos := Vector3(s, 2.2, lane) if bool(t["along_x"]) else Vector3(lane, 2.2, s)
		var dir := (Vector3(1, 0, 0) if bool(t["along_x"]) else Vector3(0, 0, 1)) * float(t["way"])
		_truck_mm.set_instance_transform(i, Transform3D(Basis.looking_at(dir, Vector3.UP), pos))


# --- Ships ------------------------------------------------------------------------------------

## Cargo ships on long slow loops over the city, climbing out and coming in to land.
func _build_ships() -> void:
	var hull := _plain(Color(0.7, 0.72, 0.75), 0.5, 0.45)
	var dark := _plain(Color(0.25, 0.26, 0.28), 0.3, 0.6)
	var lit := _glow(Color(0.4, 0.86, 1.0), 5.0)
	var engine := _glow(Color(1.0, 0.6, 0.3), 6.0)
	for k in 4:
		var ship := Node3D.new()
		ship.name = "CargoShip%d" % k
		var length := _rng.randf_range(60, 120)
		for part: Array in [[Vector3(0, 0, 0), Vector3(length * 0.18, length * 0.12, length), hull],
				[Vector3(0, length * 0.08, -length * 0.38), Vector3(length * 0.12, length * 0.08, length * 0.16), dark],
				[Vector3(length * 0.13, -length * 0.02, length * 0.1), Vector3(length * 0.08, length * 0.07, length * 0.6), dark],
				[Vector3(-length * 0.13, -length * 0.02, length * 0.1), Vector3(length * 0.08, length * 0.07, length * 0.6), dark],
				[Vector3(0, length * 0.061, 0), Vector3(length * 0.185, 0.6, length * 0.9), lit],
				[Vector3(length * 0.13, -length * 0.02, length * 0.41), Vector3(length * 0.07, length * 0.06, 0.8), engine],
				[Vector3(-length * 0.13, -length * 0.02, length * 0.41), Vector3(length * 0.07, length * 0.06, 0.8), engine]]:
			var mi := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = part[1]
			mi.mesh = b
			mi.position = part[0]
			mi.material_override = part[2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ship.add_child(mi)
		add_child(ship)
		_ship_nodes.append(ship)
		ships.append({"centre": Vector2(_rng.randf_range(-700, 300), _rng.randf_range(-800, 400)), "radius": Vector2(_rng.randf_range(500, 900), _rng.randf_range(300, 600)),
				"low": _rng.randf_range(160, 220), "high": _rng.randf_range(420, 700), "t": _rng.randf() * TAU, "rate": _rng.randf_range(0.008, 0.016) * (1.0 if k % 2 == 0 else -1.0)})
	_move_ships(0.0)


func _move_ships(delta: float) -> void:
	for i in ships.size():
		var s: Dictionary = ships[i]
		s["t"] = float(s["t"]) + float(s["rate"]) * delta
		var t: float = s["t"]
		var centre: Vector2 = s["centre"]
		var r: Vector2 = s["radius"]
		var pos := Vector3(centre.x + cos(t) * r.x, lerpf(float(s["low"]), float(s["high"]), 0.5 + 0.5 * sin(t * 2.0)), centre.y + sin(t) * r.y)
		var ahead := Vector3(centre.x + cos(t + signf(float(s["rate"])) * 0.01) * r.x, pos.y, centre.y + sin(t + signf(float(s["rate"])) * 0.01) * r.y)
		var node := _ship_nodes[i]
		node.position = pos
		if ahead.distance_to(pos) > 0.01:
			node.basis = Basis.looking_at(ahead - pos, Vector3.UP)
