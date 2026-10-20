class_name Footsteps
extends Node3D
## Footstep sounds for anyone who walks: add one to the walker (a CharacterBody3D, or any
## Node3D moved by the network) and it plays a step every stride while on the ground, a
## thud on landing, by the surface underfoot:
##   walker.add_child(Footsteps.new())
## The surface is the collider's meta "surface" ("metal", "grating" or "concrete"), or
## "metal" for colliders in the group "metal_floor"; anything else is concrete.

## Metres between steps at walking pace; longer strides when running.
@export var stride := 0.72
@export var run_stride := 1.25
## Speed (m/s) at and above which strides are run strides.
@export var run_speed := 6.0
## Loudness of a step, dB.
@export var volume_db := -10.0
## Falling speed (m/s) at landing that makes a thud rather than a step.
@export var land_speed := 3.0

var surface := "concrete"
var steps := 0
var _walked := 0.0
var _was_on_floor := true
var _last := Vector3.ZERO
var _fall := 0.0
var _left := false


func _ready() -> void:
	name = "Footsteps"
	_last = _body().global_position if _body() else Vector3.ZERO


func _physics_process(delta: float) -> void:
	var body := _body()
	if body == null or delta <= 0.0:
		return
	var moved := body.global_position - _last
	_last = body.global_position
	var on_floor := true
	var vel := moved / delta
	if body is CharacterBody3D:
		var cb := body as CharacterBody3D
		on_floor = cb.is_on_floor()
		vel = cb.get_real_velocity()
	if not on_floor:
		_fall = maxf(_fall, -vel.y)
		_was_on_floor = false
		return
	if not _was_on_floor:
		_was_on_floor = true
		surface = surface_under(body)
		if _fall > land_speed:
			Sfx.play("land", self, volume_db + 2.0, randf_range(0.9, 1.05))
		else:
			step()
		_fall = 0.0
		_walked = 0.0
		return
	var flat := Vector2(vel.x, vel.z).length()
	if flat < 0.3:
		_walked = stride * 0.6  # the first step comes soon after setting off
		return
	_walked += Vector2(moved.x, moved.z).length()
	var length := lerpf(stride, run_stride, clampf((flat - 3.0) / (run_speed - 3.0), 0.0, 1.0))
	if _walked >= length:
		_walked -= length
		surface = surface_under(body)
		step()


## Plays one step on the current surface, left and right feet a little apart in pitch.
func step() -> void:
	steps += 1
	_left = not _left
	var pitch := randf_range(0.92, 1.08) * (1.03 if _left else 0.97)
	Sfx.play("step_" + surface, self, volume_db, pitch)


## What the walker stands on: "metal", "grating" or "concrete".
func surface_under(body: Node3D) -> String:
	if not body.is_inside_tree():
		return "concrete"
	var space := body.get_world_3d().direct_space_state
	var from := body.global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.8)
	if body is CollisionObject3D:
		query.exclude = [(body as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return "concrete"
	var collider := hit.collider as Node
	if collider == null:
		return "concrete"
	var s := str(collider.get_meta("surface", ""))
	if s in ["metal", "grating", "concrete"]:
		return s
	return "metal" if collider.is_in_group("metal_floor") else "concrete"


func _body() -> Node3D:
	return get_parent() as Node3D
