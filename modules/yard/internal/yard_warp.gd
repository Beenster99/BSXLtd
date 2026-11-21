extends Node3D
## A delivery ship leaving the yard by warp (beenster, 21 Nov: "when the delivery ships leave
## they should have a sort of warp effect and sound"; flag yard.warp_out). The ship spools up
## inside a growing blue bubble with a light that brightens and a shudder. Then it jumps: a
## white flash, a shock ring and streaks, and the ship stretches out along its heading to a
## thread and is gone. The sound is YardSoundBank's "warp_jump", made in code. Presentation
## only: the traffic has already let the ship go, and this frees it.

const Bank := preload("res://modules/yard/internal/yard_sound_bank.gd")

## The spool before the jump (s), the stretch (s) and the flash's fade after it (s).
@export var spool := 1.4
@export var stretch := 0.3
@export var fade := 1.2
## How long the ship stretches along its heading at the jump (x its length).
@export var stretch_to := 60.0
## How loud the jump is (dB) and how far it carries (m).
@export var volume_db := 2.0
@export var sound_range := 400.0

const TINT := Color(0.55, 0.8, 1.0)
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform float energy = 1.0;
uniform float rim = 2.0;
uniform bool core = false;
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float glow = core ? pow(facing, rim) : pow(1.0 - facing, rim) * 0.8 + 0.08;
	ALBEDO = tint.rgb * glow * energy;
}
"""
static var _shader: Shader

var ship: Node3D
var heading := Vector3.RIGHT
var t := 0.0
## Where the ship is in the jump: "spool", "jump", "after", "done".
var phase := "spool"
var _size := 10.0
var _pivot: Node3D
var _bubble: MeshInstance3D
var _flash: MeshInstance3D
var _ring: MeshInstance3D
var _streaks: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _shake_from := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


## Takes `ship` (inside the tree) away from where it is now, warping out along `dir`, and
## returns the effect (a child of `parent`). The effect frees the ship and itself when done.
static func jump(parent: Node3D, of_ship: Node3D, dir := Vector3.RIGHT, with_sound := true) -> Node3D:
	var w: Node3D = load("res://modules/yard/internal/yard_warp.gd").new()
	w.name = "Warp_" + String(of_ship.name)
	parent.add_child(w)
	w.call("_start", of_ship, dir, with_sound)
	return w


func _start(of_ship: Node3D, dir: Vector3, with_sound: bool) -> void:
	ship = of_ship
	heading = dir.normalized()
	_rng.seed = hash(name)
	var box := _bounds(ship)
	_size = maxf(box.size.length(), 6.0)
	global_position = box.get_center()
	# The ship hangs in a pivot at its middle, so the jump stretches it from there.
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	var at := ship.global_transform
	ship.get_parent().remove_child(ship)
	_pivot.add_child(ship)
	ship.global_transform = at
	_shake_from = ship.position
	var glow := _additive(TINT, 1.5, 2.5)
	_bubble = _sphere(_size * 0.6, glow)
	_bubble.scale = Vector3.ONE * 0.2
	_flash = _sphere(_size * 0.3, _additive(Color(0.9, 0.95, 1.0), 3.0, 3.0, true))
	_flash.visible = false
	var torus := TorusMesh.new()
	torus.inner_radius = _size * 0.48
	torus.outer_radius = _size * 0.5
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _additive(TINT, 3.0, 0.5)
	_ring.basis = _ring_basis()
	_ring.visible = false
	add_child(_ring)
	var streak_mat := _additive(Color(0.75, 0.9, 1.0), 2.5, 0.0)
	for i in 10:
		var s := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(1.0, 0.08, 0.08)
		s.mesh = m
		s.material_override = streak_mat
		s.visible = false
		s.set_meta("off", Vector3(0, _rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35)) * _size)
		s.set_meta("speed", _rng.randf_range(0.7, 1.3))
		add_child(s)
		_streaks.append(s)
	_light = OmniLight3D.new()
	_light.light_color = TINT
	_light.light_energy = 0.0
	_light.omni_range = _size * 4.0
	add_child(_light)
	if with_sound:
		var p := AudioStreamPlayer3D.new()
		p.name = "Sound"
		p.stream = Bank.stream("warp_jump")
		p.bus = Sfx.bus()
		p.volume_db = volume_db
		p.unit_size = 30.0
		p.max_distance = sound_range
		add_child(p)
		p.play()


func _process(delta: float) -> void:
	advance(delta)


## Moves the effect on by `delta` seconds (tests call it to play it through).
func advance(delta: float) -> void:
	if phase == "done":
		return
	t += delta
	if t < spool:
		phase = "spool"
		var u := t / spool
		_bubble.scale = Vector3.ONE * lerpf(0.2, 1.0, u * u)
		_set_glow(_bubble, 0.3 + 1.7 * u)
		_light.light_energy = 6.0 * u * u
		var shake := 0.004 * _size * u
		if is_instance_valid(ship):
			ship.position = _shake_from + heading * u * u * _size * 0.15 + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * shake
		return
	var j := t - spool
	if j < stretch:
		phase = "jump"
		var u := j / stretch
		_stretch(lerpf(1.0, stretch_to, u * u), u * u * stretch_to * _size * 0.5)
		_bubble.visible = false
		_flash.visible = true
		_flash.scale = Vector3.ONE * lerpf(0.4, 1.4, u)
		_light.light_energy = 16.0
		_show_streaks(u)
		return
	var a := j - stretch
	if is_instance_valid(ship):
		ship.queue_free()
		ship = null
	if a < fade:
		phase = "after"
		var u := a / fade
		_flash.scale = Vector3.ONE * lerpf(1.4, 1.8, u)
		_set_glow(_flash, 3.0 * (1.0 - u) * (1.0 - u))
		_ring.visible = true
		_ring.scale = Vector3.ONE * lerpf(1.0, 2.5, sqrt(u))
		_set_glow(_ring, 3.0 * (1.0 - u))
		_light.light_energy = 16.0 * (1.0 - u) * (1.0 - u)
		_show_streaks(1.0 + u * 2.0)
		return
	phase = "done"
	var sound := get_node_or_null("Sound") as AudioStreamPlayer3D
	if sound != null and sound.playing:
		# Let the boom's tail finish before going.
		for c in get_children():
			if c != sound:
				c.queue_free()
		sound.finished.connect(queue_free)
	else:
		queue_free()


## Stretches the ship `factor` times along its heading, its middle `ahead` m on.
func _stretch(factor: float, ahead: float) -> void:
	var d := heading
	var b := Basis.IDENTITY
	for i in 3:
		var e := Vector3.ZERO
		e[i] = 1.0
		b[i] = e + d * d.dot(e) * (factor - 1.0)
	# Thinner as it stretches, so it goes to a thread.
	var thin := 1.0 / sqrt(factor)
	var side := Basis.IDENTITY
	for i in 3:
		var e := Vector3.ZERO
		e[i] = 1.0
		side[i] = e * thin + d * d.dot(e) * (1.0 - thin)
	_pivot.basis = b * side
	_pivot.position = d * ahead


func _show_streaks(u: float) -> void:
	for s in _streaks:
		s.visible = true
		var length := _size * (1.0 + u * 8.0) * float(s.get_meta("speed"))
		s.scale = Vector3(length, 1.0, 1.0)
		s.basis = _along(heading) * Basis.from_scale(Vector3(length, 1.0, 1.0))
		s.position = (s.get_meta("off") as Vector3) + heading * (length * 0.5 + u * _size * 2.0)


## A basis that turns +x onto `d`.
func _along(d: Vector3) -> Basis:
	var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var z := d.cross(up).normalized()
	var y := z.cross(d).normalized()
	return Basis(d, y, z)


## The ring stands square to the heading (a TorusMesh lies in xz, its axis y).
func _ring_basis() -> Basis:
	var a := _along(heading)
	return Basis(a.z, a.x, a.y)


func _sphere(radius: float, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 24
	m.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A glow that is bright at its edge and clear in the middle (a bubble, not a disc), added
## to what is behind it.
func _additive(c: Color, energy: float, rim := 2.0, core := false) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GLOW_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("rim", rim)
	m.set_shader_parameter("core", core)
	return m


func _set_glow(mi: MeshInstance3D, energy: float) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter("energy", energy)


## Everything drawn under `node`, in station space.
static func _bounds(node: Node3D) -> AABB:
	var box := AABB(node.global_position, Vector3.ZERO)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh != null:
			box = box.merge(m.global_transform * m.get_aabb())
	return box
