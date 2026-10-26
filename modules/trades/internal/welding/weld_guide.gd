class_name TradesWeldGuide
extends Node3D
## What you see of a seam with the welder in hand (trades.weld_guide, beenster 0.3.17: "it's
## impossible to see where the welder tip is and where the weld line is"): a soapstone line
## chalked along the stretches still to run, a tick at each end you can strike the arc from,
## and a bright point where the torch's tip meets the work, drawn over the nozzle so the
## torch never hides it. Pale enough to read through the shield without flaring.
## Presentation only.

## The chalk line's width and how far it stands off the plate (m).
const LINE_W := 0.005
const LIFT_M := 0.004
## The start ticks: across the seam, and along it (m).
const TICK_W := 0.032
const TICK_L := 0.006
## The tip point's radius, and the ring round it (m).
const TIP_R := 0.005
const HALO_R := Vector2(0.012, 0.015)

var _lines: MeshInstance3D
var _mesh: ImmediateMesh
var _tip: MeshInstance3D
var _tip_on: StandardMaterial3D
var _tip_off: StandardMaterial3D
var _halo: MeshInstance3D
## Vertices in the line as last drawn (tests).
var vertex_count := 0


func _init() -> void:
	name = "WeldGuide"
	top_level = true
	_mesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _mesh
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var chalk := StandardMaterial3D.new()
	chalk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Over 1 so it stays white past the tonemap and reads as bright through the shield glass.
	chalk.albedo_color = Color(1.5, 1.55, 1.6)
	chalk.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Over the torch and the plate's own marker, and bright enough to read through the shield.
	chalk.no_depth_test = true
	chalk.render_priority = 1
	_lines.material_override = chalk
	add_child(_lines)
	var dot := SphereMesh.new()
	dot.radius = TIP_R
	dot.height = TIP_R * 2.0
	dot.radial_segments = 10
	dot.rings = 5
	_tip = MeshInstance3D.new()
	_tip.mesh = dot
	_tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tip_on = _dot_mat(Color(1.0, 1.0, 1.0))
	_tip_off = _dot_mat(Color(0.55, 0.62, 0.66))
	_tip.material_override = _tip_off
	add_child(_tip)
	var ring := TorusMesh.new()
	ring.inner_radius = HALO_R.x
	ring.outer_radius = HALO_R.y
	ring.rings = 20
	ring.ring_segments = 4
	_halo = MeshInstance3D.new()
	_halo.mesh = ring
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tip.add_child(_halo)
	hide_all()


## The seam's line (world): its middle, its direction along the plate, the plate's normal and
## its length (m). `bins` marks the stretches already run this pass (1), drawn as gaps;
## `starts` are where an arc may be struck (m from the middle), drawn as ticks where there's
## line left beside them.
func show_seam(centre: Vector3, along: Vector3, n: Vector3, length: float, bins: PackedByteArray,
		starts: PackedFloat32Array) -> void:
	_mesh.clear_surfaces()
	vertex_count = 0
	var half := length * 0.5
	var side := n.cross(along).normalized()
	var lift := n * LIFT_M
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(1, bins.size())
	var step := length / count
	var k := 0
	while k < count:
		if not bins.is_empty() and bins[k] == 1:
			k += 1
			continue
		var from := k
		while k < count and (bins.is_empty() or bins[k] == 0):
			k += 1
		_quad(centre + lift + along * (from * step - half), along, side, (k - from) * step, LINE_W)
	for s in starts:
		# Only where there's line left to run from it.
		var right := roundi((s + half) / step)
		if not (_open(bins, right - 1, count) or _open(bins, right, count)):
			continue
		_quad(centre + lift * 1.5 + along * (s - TICK_L * 0.5), along, side, TICK_L, TICK_W)
	_mesh.surface_end()
	_lines.visible = true


## The point where the torch's tip meets the work (on the plate with normal `n`), ringed;
## `on_seam` lights it up once it's on the line, in `tone` (the welding pace, trades.weld_skill).
func show_tip(at: Vector3, n: Vector3, on_seam: bool, tone := Color.WHITE) -> void:
	_tip_on.albedo_color = tone
	var x := n.cross(Vector3.UP) if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	x = x.normalized()
	_tip.global_transform = Transform3D(Basis(x, n, x.cross(n)), at + n * LIFT_M)
	_tip.material_override = _tip_on if on_seam else _tip_off
	_halo.material_override = _tip.material_override
	_tip.visible = true


func hide_tip() -> void:
	_tip.visible = false


func hide_all() -> void:
	_lines.visible = false
	_tip.visible = false


func tip_showing() -> bool:
	return _tip.visible


func line_showing() -> bool:
	return _lines.visible


static func _open(bins: PackedByteArray, k: int, count: int) -> bool:
	return k >= 0 and k < count and (bins.is_empty() or bins[k] == 0)


## A flat strip from `start` along `along` for `length`, `width` across.
func _quad(start: Vector3, along: Vector3, side: Vector3, length: float, width: float) -> void:
	var a := start - side * width * 0.5
	var b := start + side * width * 0.5
	var c := b + along * length
	var d := a + along * length
	for p: Vector3 in [a, b, c, a, c, d]:
		_mesh.surface_add_vertex(p)
	vertex_count += 6


static func _dot_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.no_depth_test = true
	m.render_priority = 2
	return m
