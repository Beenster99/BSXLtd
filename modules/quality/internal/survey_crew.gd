extends Node3D
## Puts the surveyors in the shipyard while a visit is on: Quality adds one to the yard when
## Ship and Bay hands it over (shipyard_ready). On survey_started it sends the crew in from
## the bay's open south side, sharing the joints out between them in a nearest-first walk;
## on survey_finished they walk back out. Every player sees them; the host's clock decides
## when they leave.

const Surveyor := preload("res://modules/quality/internal/surveyor.gd")

## How far from under a joint a surveyor stands, out from the ship, m.
const STAND_OFF := 1.2

var bus: QualityBus


func _init(p_bus: QualityBus) -> void:
	bus = p_bus


func _ready() -> void:
	bus.survey_started.connect(_on_started)
	bus.survey_finished.connect(_on_finished)
	if bus.survey_running():
		# The yard opened (or this player joined) part way through a visit.
		var s := bus.current_survey()
		_on_started(StringName(s.get("kind", "")), str(s.get("job_id", "")), s.get("joints", []))


func surveyors() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in get_children():
		if c is Node3D and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _on_started(_kind: StringName, _job_id: String, joint_ids: Array) -> void:
	var n := maxi(1, int(bus.current_survey().get("crew", 1)))
	var targets := _targets(joint_ids)
	var entry := _entry()
	for i in n:
		var mine: Array[Vector3] = []
		for j in range(i, targets.size(), n):
			mine.append(targets[j])
		var stops := _route(mine, entry)
		var s := Surveyor.new(stops, entry + Vector3(0.9 * (i - (n - 1) * 0.5), 0, 0),
				bus.survey_rules.walk_speed, bus.survey_rules.scan_s)
		add_child(s)


func _on_finished(_rep: SurveyReport) -> void:
	for s in surveyors():
		s.call("leave")


## Joint positions in this node's space (the yard's), for joints with a site in the yard.
func _targets(joint_ids: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var trades := Modules.bus("trades") as TradesBus
	if trades == null:
		return out
	for id in joint_ids:
		var site := trades.site(StringName(id))
		if site and site.is_inside_tree():
			out.append(to_local(site.global_position))
	return out


## Nearest-first walk from the entry; each stop stands on the floor a little out from under
## the joint (away from the ship's middle) and looks at it.
func _route(points: Array[Vector3], from: Vector3) -> Array[Dictionary]:
	var yard_bus := Modules.bus("ship_bay") as ShipBayBus
	var centre := yard_bus.ship_transform(get_parent() as Node3D).origin if yard_bus else Vector3.ZERO
	var left := points.duplicate()
	var here := from
	var out: Array[Dictionary] = []
	while not left.is_empty():
		var best := 0
		for k in left.size():
			if _flat(left[k]).distance_to(_flat(here)) < _flat(left[best]).distance_to(_flat(here)):
				best = k
		var at: Vector3 = left[best]
		left.remove_at(best)
		var out_dir := _flat(at - centre)
		out_dir = out_dir.normalized() if out_dir.length() > 0.01 else Vector3.BACK
		var stand := _clear_spot(_flat(at) + out_dir * STAND_OFF, out_dir)
		out.append({"stand": stand, "at": at})
		here = stand
	return out


## Steps `p` out along `dir` until nothing is overhead below head height (the hull, a
## wing), so a surveyor never stands inside the ship. Needs the yard's colliders.
func _clear_spot(p: Vector3, dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var spot := _clamp_to_bay(p)
	if space == null:
		return spot
	for i in 24:
		var from := to_global(spot + Vector3(0, 2.2, 0))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to_global(spot + Vector3(0, 0.15, 0))))
		var sides := space.intersect_ray(PhysicsRayQueryParameters3D.create(to_global(spot + Vector3(0, 1.0, 0)),
				to_global(spot + Vector3(0, 1.0, 0) + dir * 0.4)))
		if hit.is_empty() and sides.is_empty():
			return spot
		spot = _clamp_to_bay(spot + dir * 0.5)
	return spot


## Where the crew walks in and out: the middle of the bay's south (+Z) side.
func _entry() -> Vector3:
	var box := _bay_box()
	return Vector3(box.get_center().x, 0.0, box.end.z - 1.5)


func _clamp_to_bay(p: Vector3) -> Vector3:
	var box := _bay_box().grow(-0.8)
	return Vector3(clampf(p.x, box.position.x, box.end.x), 0.0, clampf(p.z, box.position.z, box.end.z))


func _bay_box() -> AABB:
	var yard_bus := Modules.bus("ship_bay") as ShipBayBus
	var rooms: Dictionary = yard_bus.shipyard_rooms() if yard_bus else {}
	return rooms.get("bay", {}).get("box", AABB(Vector3(-28, 0, -24), Vector3(56, 30, 48)))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Release screenshots: two surveyors at the ship, one scanning, and a camera on them.
func stage_shot() -> Camera3D:
	var yard_bus := Modules.bus("ship_bay") as ShipBayBus
	var centre := yard_bus.ship_transform(get_parent() as Node3D).origin if yard_bus else Vector3.ZERO
	centre.y = 0.0
	var stops := _route([centre + Vector3(-1.5, 1.6, 2.0)], centre + Vector3(-2.0, 0, 9.0))
	var stand: Vector3 = stops[0].stand
	var a := Surveyor.new(stops, stand, 1.4, 9999.0)
	add_child(a)
	var b := Surveyor.new([], stand + Vector3(-1.3, 0, 1.0))
	add_child(b)
	b.look_at(to_global(stand + Vector3(-4.0, 0.0, 1.5)), Vector3.UP, true)
	var cam := Camera3D.new()
	cam.name = "QualityShotCamera"
	add_child(cam)
	cam.global_position = to_global(stand + Vector3(-5.0, 1.75, 2.6))
	cam.look_at(to_global(stand + Vector3(0.3, 1.3, -0.6)))
	cam.fov = 50
	cam.current = true
	return cam
