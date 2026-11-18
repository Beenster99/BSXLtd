class_name YardFieldGrip
extends Node3D
## A field's grip on one piece: Void Salvage's FieldGrip (VX21, scripts/world/field_grip.gd at
## 6523ae5), what its grabber's claw draws on a piece it holds, here on the grabber and the
## tractor (0.4.0 playtest: "use the same effect on the grabber (in VS) for our tractor gun"). A
## faint shimmering shell on the piece's box, `tethers` lines of light from the claw bowing and
## writhing to it and flowing in. (Void Salvage's heat haze along the line is left out.)
##
## Drawn in world space: whoever holds calls `hold` each frame and `release` when it lets go;
## the grip eases in and out on its own (`ease_seconds`).

## Lines from the intake to the piece, their width (m), how far each bows out (of its length) and
## how fast it writhes (Hz).
@export var tethers: int = 3
@export var tether_width: float = 0.05
@export var tether_bow: float = 0.12
@export var writhe_hz: float = 0.7
## The shell stands this far off the piece's box (m).
@export var shell_grow: float = 0.06
## Seconds to ease in when it takes hold, and out when it lets go.
@export var ease_seconds: float = 0.25
@export var colour: Color = Color(0.45, 0.85, 1.0)

const STRIP_SEGMENTS: int = 18

## The piece held (null once let go), how hard now (0..1, eased) and how near the limit (0..1).
var body: Node3D
var strength: float = 0.0
var strain: float = 0.0
var from_points: Array[Vector3] = []
var to_point := Vector3.ZERO
var shell: MeshInstance3D
var lines: Array[MeshInstance3D] = []

var _holding := false
var _box := AABB()
var _time: float = 0.0
var _seed: float = 0.0
var _tether_mat: ShaderMaterial
var _shell_mat: ShaderMaterial
static var _strip: ArrayMesh


func _init() -> void:
	top_level = true
	_seed = randf() * 10.0


func _ready() -> void:
	if _strip == null:
		_strip = _make_strip()
	_tether_mat = ShaderMaterial.new()
	_tether_mat.shader = preload("res://modules/yard/assets/tools_fx/field_tether.gdshader")
	_tether_mat.set_shader_parameter("bands", 5.0)
	_tether_mat.set_shader_parameter("flow", 2.2)
	_tether_mat.set_shader_parameter("colour", Vector3(colour.r, colour.g, colour.b))
	_shell_mat = ShaderMaterial.new()
	_shell_mat.shader = preload("res://modules/yard/assets/tools_fx/field_grip.gdshader")
	_shell_mat.set_shader_parameter("colour", Vector3(colour.r, colour.g, colour.b))
	shell = MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = BoxMesh.new()
	shell.material_override = _shell_mat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.visible = false
	add_child(shell)
	for k in tethers:
		var line := MeshInstance3D.new()
		line.name = "Tether%d" % k
		line.mesh = _strip
		line.material_override = _tether_mat
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.visible = false
		add_child(line)
		lines.append(line)


## Holds `piece` this frame, the lines from `from` (world) to `at` on it (world),
## `near_limit` 0..1 how near the hold is to giving.
func hold(piece: Node3D, from: Array[Vector3], at: Vector3, near_limit: float = 0.0) -> void:
	if piece != body:
		body = piece
		_box = _box_of(piece)
	_holding = piece != null and is_instance_valid(piece)
	from_points = from
	strain = clampf(near_limit, 0.0, 1.0)
	to_point = at


func release() -> void:
	_holding = false


func holding() -> bool:
	return _holding


func showing() -> bool:
	return strength > 0.001


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_time += delta
	if body != null and not is_instance_valid(body):
		body = null
		_holding = false
	strength = move_toward(strength, 1.0 if _holding else 0.0, delta / maxf(ease_seconds, 0.01))
	var on := strength > 0.001 and body != null and not from_points.is_empty()
	shell.visible = on
	for line in lines:
		line.visible = on
	if not on:
		if strength <= 0.001:
			body = null
		return
	var size := _box.size + Vector3.ONE * shell_grow * 2.0
	shell.global_transform = body.global_transform * Transform3D(Basis().scaled(size), _box.get_center())
	var mid := Vector3.ZERO
	for p in from_points:
		mid += p
	mid /= float(from_points.size())
	var toward := mid - to_point
	shell.set_instance_shader_parameter("strength", strength)
	shell.set_instance_shader_parameter("strain", strain)
	shell.set_instance_shader_parameter("toward", toward if toward.length_squared() > 1e-6 else Vector3.UP)
	var reach := minf(minf(_box.size.x, _box.size.y), _box.size.z) * 0.35
	var length := toward.length()
	var dir := toward / length if length > 1e-4 else Vector3.UP
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	for k in lines.size():
		var ang := TAU * float(k) / float(maxi(lines.size(), 1)) + _seed
		var spread := side * cos(ang) + up * sin(ang)
		var a := to_point + spread * reach + dir * reach * 0.5
		var b: Vector3 = from_points[k % from_points.size()]
		var w := sin(_time * TAU * writhe_hz + float(k) * 2.1 + _seed) * 0.5 + 0.5 * sin(_time * TAU * writhe_hz * 1.7 + float(k))
		var bow := (spread * (0.6 + 0.4 * w) + up.rotated(dir, _time * writhe_hz + float(k)) * 0.35 * w) \
				* a.distance_to(b) * tether_bow
		var c := (a + b) * 0.5 + bow
		var line := lines[k]
		line.set_instance_shader_parameter("from_piece", a)
		line.set_instance_shader_parameter("bend", c)
		line.set_instance_shader_parameter("to_intake", b)
		line.set_instance_shader_parameter("width", tether_width)
		line.set_instance_shader_parameter("seed", float(k) * 0.37 + _seed)
		line.custom_aabb = AABB(a, Vector3.ZERO).expand(b).expand(c).grow(tether_width + 0.05)
	_tether_mat.set_shader_parameter("strength", strength)
	_tether_mat.set_shader_parameter("strain", strain)


## A piece's box (its own space): its drawn shapes', else a 0.6 m cube.
static func _box_of(piece: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in piece.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var b := piece.global_transform.affine_inverse() * mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return AABB(Vector3.ONE * -0.3, Vector3.ONE * 0.6) if first else box


## The tether strip: a unit strip of quads along UV2.x (0..1), UV.y across.
static func _make_strip() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var index := PackedInt32Array()
	for s in STRIP_SEGMENTS + 1:
		var t := float(s) / STRIP_SEGMENTS
		for across: float in [0.0, 1.0]:
			verts.append(Vector3(0.0, t, 0.0))
			uvs.append(Vector2(t, across))
			uv2s.append(Vector2(t, 0.0))
		if s > 0:
			var a := (s - 1) * 2
			index.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
