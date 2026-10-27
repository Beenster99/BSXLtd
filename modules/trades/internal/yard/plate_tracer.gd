class_name TradesPlateTracer
extends Node3D
## Tracing a template off a plate at the ship (beenster, 0.3.23: "The shape is destined by a
## template which is created at the wreck or vessel in the courtyard - a player makes a
## template by tracing the line of the plate, this is then measured by the system and a
## template created which can be fed into the plasma cutter"). Behind trades.cutting_bed.
##
## With the template scribe in hand (a soapstone chalk on a tape reel), hold the left mouse
## button on a plate of the ship and run the chalk round its edge: a white chalk line follows
## the tip. Once the line has gone round the plate's whole edge (most of it: `covered`) the
## scribe measures it, and the template (named for the plate, numbered T-001, T-002...) goes
## to the cutting bed's console for everyone. Let go part way and the line stays, so you can
## carry on; start on another plate and it starts again.

const EVENT := "trades.template"
const SECTION := "trades_templates"
## The thinnest a plate's box is to count as a plate (m), and the least of its other sides.
const PLATE_MAX_T := 0.07
const PLATE_MIN_SIDE := 0.15
## How far the scribe reaches (m from the eye), how close to the edge a chalk point must be to
## count (m), how much of the edge (0..1) makes a template, and the chalk's step (m).
const REACH_M := 3.0
const SNAP_M := 0.09
const COVERED := 0.85
const STEP_M := 0.02

var bay: Node  # TradesBay
## Tracing now (the mouse held with the scribe).
var tracing := false
## The plate being traced: its slot id, ship-space box, the two in-plane axes and the thin
## one; and the chalk so far (plate-plane points, m from the box's middle).
var slot_id := ""
var plate_box := AABB()
var axes := Vector3i(0, 2, 1)
var points := PackedVector2Array()
## The traced plate's name, for the scribe's screen ("" before one).
var plate_name := ""
## The last template made here (for the hint and tests), {} before any.
var last: Dictionary = {}

var _net: Node
var _chalk: MeshInstance3D
var _chalk_world: PackedVector3Array = PackedVector3Array()


static func enabled() -> bool:
	return Flags.is_on("trades.cutting_bed")


func build(net: Node = null) -> void:
	_chalk = MeshInstance3D.new()
	_chalk.name = "Chalk"
	_chalk.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 0.9)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_chalk.material_override = m
	_chalk.top_level = true
	add_child(_chalk)
	_net = net
	if _net:
		_net.call("register_event", EVENT, _apply, _validate)
		if _net.has_method("register_snapshot_provider"):
			_net.call("register_snapshot_provider", SECTION, self)


func _exit_tree() -> void:
	if _net:
		_net.call("unregister_event", EVENT)
		if _net.has_method("unregister_snapshot_provider"):
			_net.call("unregister_snapshot_provider", SECTION)


func set_tracing(on: bool) -> void:
	tracing = on


## The plate slot under a ship-space point: {slot, box, axes} or {} for none.
static func plate_at(p: Vector3) -> Dictionary:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	if bus == null:
		return {}
	var best := {}
	var best_v := INF
	for s: MountSlot in bus.get_slots():
		var b := s.box
		var dims := [b.size.x, b.size.y, b.size.z]
		var thin := 0
		for k in 3:
			if dims[k] < dims[thin]:
				thin = k
		var others := [0, 1, 2].filter(func(k: int) -> bool: return k != thin)
		if float(dims[thin]) > PLATE_MAX_T or float(dims[others[0]]) < PLATE_MIN_SIDE or float(dims[others[1]]) < PLATE_MIN_SIDE:
			continue
		if not b.grow(0.04).has_point(p):
			continue
		var v := b.size.x * b.size.y * b.size.z
		if v < best_v:
			best_v = v
			best = {"slot": s, "box": b, "axes": Vector3i(others[0], others[1], thin)}
	return best


## Where the plate's edge is: its outline in its own plane (m, centred).
func edges() -> PackedVector2Array:
	var s := Vector2(plate_box.size[axes.x], plate_box.size[axes.y]) * 0.5
	return PackedVector2Array([Vector2(-s.x, -s.y), Vector2(s.x, -s.y), Vector2(s.x, s.y), Vector2(-s.x, s.y)])


## How much of the plate's edge the chalk has gone round (0..1).
func progress() -> float:
	return TradesPlateShapes.coverage(points, edges(), SNAP_M) if slot_id != "" else 0.0


func _physics_process(_delta: float) -> void:
	if not tracing:
		return
	var w := bay.get("worker") as Node3D if bay else null
	if w == null or not w.is_inside_tree():
		return
	var from: Vector3 = w.call("aim_origin")
	var dir: Vector3 = w.call("aim_dir")
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * REACH_M)
	q.exclude = [(w as CollisionObject3D).get_rid()]
	var hit := w.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	chalk_at(hit.position, hit.normal)


## A chalk point at a world point on a surface: on a plate, the line grows and is measured.
func chalk_at(world: Vector3, normal: Vector3) -> void:
	var ship: Transform3D = bay.call("ship_transform") if bay and bay.has_method("ship_transform") else Transform3D.IDENTITY
	var p := ship.affine_inverse() * world
	var found := plate_at(p)
	if found.is_empty():
		return
	var s: MountSlot = found.slot
	if s.slot_id != slot_id:
		_restart(s.slot_id, found.box, found.axes)
		plate_name = s.display_name if s.display_name != "" else s.slot_id.capitalize()
	var c := plate_box.get_center()
	var flat := Vector2(p[axes.x] - c[axes.x], p[axes.y] - c[axes.y])
	if not points.is_empty() and flat.distance_to(points[points.size() - 1]) < STEP_M:
		return
	points.append(flat)
	_chalk_world.append(world + normal * 0.003)
	_draw_chalk(normal)
	if progress() >= COVERED:
		_measure(s)


func _restart(id: String, box: AABB, ax: Vector3i) -> void:
	slot_id = id
	plate_box = box
	axes = ax
	points = PackedVector2Array()
	_chalk_world = PackedVector3Array()
	(_chalk.mesh as ImmediateMesh).clear_surfaces()


func _measure(s: MountSlot) -> void:
	var t := TradesPlateShapes.measure(points, edges(), SNAP_M, 24, COVERED)
	if t.is_empty():
		return
	_ask({"name": plate_name, "outline": t.outline, "source": s.slot_id})
	tracing = false
	slot_id = ""
	plate_name = ""
	points = PackedVector2Array()
	if bay and bay.has_method("play"):
		bay.call("play", &"tick")


func _ask(p: Dictionary) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", EVENT, p)
		return
	var v: Variant = _validate(1, p)
	if v is Dictionary:
		_apply(v)


func _validate(_sender: int, p: Dictionary) -> Variant:
	var outline: Variant = p.get("outline")
	if not outline is PackedVector2Array or (outline as PackedVector2Array).size() < 3:
		return "no outline"
	var bus := Modules.bus("trades") as TradesBus
	return {"id": bus.next_template_id() if bus else "T-000", "name": str(p.get("name", "Plate")),
			"outline": outline, "source": str(p.get("source", ""))}


func _apply(p: Dictionary) -> void:
	var bus := Modules.bus("trades") as TradesBus
	if bus == null:
		return
	last = bus.add_template(TradesPlateShapes.finish({"id": str(p.id), "name": str(p.name), "outline": p.outline,
			"holes": [], "kind": "traced", "source": str(p.source)}))
	if bay and bay.has_method("hint"):
		var s: Vector2 = last.size
		bay.call("hint", "Template %s measured: %s, %d x %d mm. It's on the cutting bed's console."
				% [last.id, last.name, roundi(s.x * 1000.0), roundi(s.y * 1000.0)])


## A chalk ribbon along the line (2 cm wide, on the plate).
func _draw_chalk(normal: Vector3) -> void:
	var im := _chalk.mesh as ImmediateMesh
	im.clear_surfaces()
	if _chalk_world.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, _chalk_world.size()):
		var a := _chalk_world[i - 1]
		var b := _chalk_world[i]
		if a.distance_to(b) > 0.5:
			continue
		var side := (b - a).normalized().cross(normal).normalized() * 0.008
		for v: Vector3 in [a - side, b - side, b + side, a - side, b + side, a + side]:
			im.surface_add_vertex(v)
	im.surface_end()


# --- Snapshot: late joiners get the traced templates ---------------------------------------

func get_net_snapshot() -> Dictionary:
	var bus := Modules.bus("trades") as TradesBus
	return {"traced": bus.save_data().get("templates", []) if bus else []}


func apply_net_snapshot(data: Dictionary) -> void:
	var bus := Modules.bus("trades") as TradesBus
	if bus:
		bus.load_data({"templates": data.get("traced", [])}, bus.save_version())
