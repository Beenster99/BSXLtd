extends Node3D
## Goods moving between a trolley and where they sit (the floor, a shelf, another trolley's
## deck) are beamed across: a copy of the goods rises off one, floats over in an arc and
## settles on the other, held in a pale tractor beam from the trolley doing the work. The
## fleet starts a flight when the stores' state moves a crate; until it lands the real
## goods are not drawn at the far end (TrolleyFleet and the shipyard ask `landing()`).
##
## Presentation only: every peer flies its own copy from the same state changes.

const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")

## How long a flight takes: this many seconds plus `per_metre` for each metre it crosses.
@export var base_time := 0.9
@export var per_metre := 0.22
## The longest a flight may take, seconds.
@export var max_time := 2.8
## How high the goods rise over the straight line between the ends, metres (at least).
@export var arc_height := 1.8
## The beam's colour (alpha is its strength).
@export var beam_colour := Color(0.45, 0.9, 1.0, 0.3)

## Flights in the air: {key, ghost, beam, from, to, emitter, t, time, done}.
var flights: Array = []
var _beam_mat: StandardMaterial3D


## Starts a flight of `lots` ([{item, count, look}, ...]) from `from` to `to` (each a
## Vector3 in yard space or a Node3D, its origin; a trolley's deck node lands it on top).
## `emitter` is the trolley the beam comes from; `ends` the trolleys giving or taking the goods
## (busy() holds them till it lands). `done` is called when it lands.
func fly(key: String, lots: Array, from: Variant, to: Variant, emitter: Node3D, ends: Array = [], done := Callable()) -> void:
	land(key)
	var ghost := Node3D.new()
	ghost.name = "Beamed_" + key.replace("/", "_").replace(":", "_")
	add_child(ghost)
	var wide := 0.5
	for placed: Array in ItemLook.stack_lots(lots, Vector2(2.4, 2.4), 2.4):
		var n := ItemLook.make(str(placed[0]), placed[1])
		n.transform = placed[2]
		ghost.add_child(n)
		var s := ItemLook.size_of(str(placed[0]))
		wide = maxf(wide, maxf(s.x, s.z) * 0.5 + absf((placed[2] as Transform3D).origin.x))
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var tube := CylinderMesh.new()
	tube.top_radius = clampf(wide, 0.5, 2.6)   # round the goods
	tube.bottom_radius = 0.08  # at the trolley
	tube.height = 1.0
	tube.radial_segments = 12
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	beam.mesh = tube
	beam.material_override = _beam()
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var a := _at(from)
	var b := _at(to)
	var time := clampf(base_time + per_metre * a.distance_to(b), base_time, max_time)
	ghost.global_position = a
	flights.append({"key": key, "ghost": ghost, "beam": beam, "from": from, "to": to, "emitter": emitter, "ends": ends,
			"t": 0.0, "time": time, "done": done})
	_place(flights[-1])


## True while goods under `key` are in the air.
func landing(key: String) -> bool:
	for f: Dictionary in flights:
		if f["key"] == key:
			return true
	return false


## True while a flight is beaming goods off or onto `trolley` (it holds still till they land).
func busy(trolley: Node3D) -> bool:
	for f: Dictionary in flights:
		if f["emitter"] == trolley or (f["ends"] as Array).has(trolley):
			return true
	return false


## The flight under `key`, or {}.
func flight(key: String) -> Dictionary:
	for f: Dictionary in flights:
		if f["key"] == key:
			return f
	return {}


## Ends a flight now (it lands where it was going).
func land(key: String) -> void:
	for i in range(flights.size() - 1, -1, -1):
		if flights[i]["key"] == key:
			_finish(i)


func _process(delta: float) -> void:
	for i in range(flights.size() - 1, -1, -1):
		var f: Dictionary = flights[i]
		f["t"] = float(f["t"]) + delta
		if not is_instance_valid(f["emitter"]) or float(f["t"]) >= float(f["time"]):
			_finish(i)
			continue
		_place(f)


func _place(f: Dictionary) -> void:
	var s := smoothstep(0.0, 1.0, clampf(float(f["t"]) / float(f["time"]), 0.0, 1.0))
	var a := _at(f["from"])
	var b := _at(f["to"])
	var rise := maxf(arc_height, a.distance_to(b) * 0.2)
	var p := a.lerp(b, s) + Vector3.UP * rise * sin(PI * s)
	var ghost: Node3D = f["ghost"]
	ghost.global_position = p
	# The beam: from the trolley's deck up (or down) to the goods.
	var beam: MeshInstance3D = f["beam"]
	var emitter: Node3D = f["emitter"]
	var root := emitter.global_position
	var deck: Variant = emitter.get("deck")
	if deck is Node3D:
		root = (deck as Node3D).global_position + Vector3.UP * 0.1
	var tip := p
	var span := tip - root
	var length := span.length()
	beam.visible = length > 0.3
	if not beam.visible:
		return
	var up := span / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up * length, side.cross(up))
	beam.global_transform = Transform3D(basis, root + span * 0.5)


func _finish(i: int) -> void:
	var f: Dictionary = flights[i]
	flights.remove_at(i)
	(f["ghost"] as Node3D).queue_free()
	(f["beam"] as Node3D).queue_free()
	var done: Callable = f["done"]
	if done.is_valid():
		done.call()


static func _at(where: Variant) -> Vector3:
	if where is Node3D and is_instance_valid(where):
		return (where as Node3D).global_position
	return where if where is Vector3 else Vector3.ZERO


func _beam() -> StandardMaterial3D:
	if _beam_mat == null:
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_beam_mat.albedo_color = beam_colour
		_beam_mat.emission_enabled = true
		_beam_mat.emission = Color(beam_colour.r, beam_colour.g, beam_colour.b)
		_beam_mat.emission_energy_multiplier = 0.6
	return _beam_mat
