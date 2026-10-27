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
## How far off a plate's plane the chalk still counts as on it (m).
const PLANE_M := 0.25
## How far the scribe reaches (m from the eye), how close to the edge a chalk point must be to
## count (m), how much of the edge (0..1) makes a template, and the chalk's step (m).
const REACH_M := 3.0
const SNAP_M := 0.09
const COVERED := 0.85
const STEP_M := 0.02

var bay: Node  # TradesBay
## Tracing now (the mouse held with the scribe).
var tracing := false
## The plate being traced: its slot id, ship-space box and plate (plate_at: its plane); and the
## chalk so far (plate-plane points, m from the plate's middle).
var slot_id := ""
var plate_box := AABB()
var plate: Dictionary = {}
var points := PackedVector2Array()
## The traced plate's name, for the scribe's screen ("" before one).
var plate_name := ""
## The last template made here (for the hint and tests), {} before any.
var last: Dictionary = {}

var _net: Node
var _said_at := -10000
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


## The plate slot under a ship-space point: {slot, box, centre, u, v, n (ship-space plane axes:
## two across the plate, one out of it), size (m across u and v)} or {} for none. A plate is a
## slot named for one (a hull or wall plate), or one whose box is plate-thin; a slanted plate's
## plane is its mount's facing (its box is fat round it), so the Kestrel's 8 cm and slanted
## plates count too (playtest 0.3.24: the scribe found almost none).
## `keep`: the plate being traced keeps the chalk where it meets a neighbour along an edge.
static func plate_at(p: Vector3, keep := "") -> Dictionary:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	if bus == null:
		return {}
	var best := {}
	var best_d := INF
	for s: MountSlot in bus.get_slots():
		var plate := plate_of(s)
		if plate.is_empty() or not s.box.grow(0.06).has_point(p):
			continue
		var off := p - (plate.centre as Vector3)
		var d := absf(off.dot(plate.n))
		if d > PLANE_M or absf(off.dot(plate.u)) > (plate.size as Vector2).x * 0.5 + 0.06 \
				or absf(off.dot(plate.v)) > (plate.size as Vector2).y * 0.5 + 0.06:
			continue
		# The nearest plane wins, then the smaller plate.
		var score := d + (plate.size as Vector2).x * (plate.size as Vector2).y * 0.001
		if s.slot_id == keep:
			score -= 1.0
		if score < best_d:
			best_d = score
			best = plate
	return best


## A slot as a plate (plate_at's dictionary without the point), or {} when it isn't one.
static func plate_of(s: MountSlot) -> Dictionary:
	var b := s.box
	var dims := [b.size.x, b.size.y, b.size.z]
	var thin := 0
	for k in 3:
		if dims[k] < dims[thin]:
			thin = k
	var named := "plate" in s.slot_id.to_lower() or "plate" in ",".join(s.parts).to_lower()
	var n := Vector3.ZERO
	if named and s.mount.basis.z.length() > 0.5:
		n = s.mount.basis.z.normalized()
	elif float(dims[thin]) <= PLATE_MAX_T:
		n[thin] = 1.0
	else:
		return {}
	# Across the plate: v as near up as the plate allows (along the ship where it lies flat).
	var v := Vector3.UP - n * n.y
	if v.length() < 0.3:
		v = Vector3.FORWARD - n * n.z
	v = v.normalized()
	var u := v.cross(n).normalized()
	var c := b.get_center()
	var lo := Vector2(INF, INF)
	var hi := -lo
	for i in 8:
		var q := b.get_endpoint(i) - c
		var f := Vector2(q.dot(u), q.dot(v))
		lo = lo.min(f)
		hi = hi.max(f)
	# A slanted plate's box corners lie off its plane: those across it are the plate's ends.
	var size := hi - lo
	if size.x < PLATE_MIN_SIDE or size.y < PLATE_MIN_SIDE:
		return {}
	return {"slot": s, "box": b, "centre": c + u * (lo.x + hi.x) * 0.5 + v * (lo.y + hi.y) * 0.5,
			"u": u, "v": v, "n": n, "size": size}


## Where the plate's edge is: its outline in its own plane (m, centred).
func edges() -> PackedVector2Array:
	var s := (plate.get("size", Vector2.ZERO) as Vector2) * 0.5
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
		_say("Nothing in reach. Hold the chalk on a plate of the ship and run it round its edge.")
		return
	chalk_at(hit.position, hit.normal)


## A chalk point at a world point on a surface: on a plate, the line grows and is measured.
func chalk_at(world: Vector3, normal: Vector3) -> void:
	var ship: Transform3D = bay.call("ship_transform") if bay and bay.has_method("ship_transform") else Transform3D.IDENTITY
	var p := ship.affine_inverse() * world
	var found := plate_at(p, slot_id)
	if found.is_empty():
		_say("That isn't a plate. Run the chalk round the edge of a hull or wall plate.")
		return
	var s: MountSlot = found.slot
	if s.slot_id != slot_id:
		_restart(s.slot_id, found)
		plate_name = s.display_name if s.display_name != "" else s.slot_id.capitalize()
	var off := p - (plate.centre as Vector3)
	var flat := Vector2(off.dot(plate.u), off.dot(plate.v))
	_say("Tracing %s: %d%% of its edge. Keep the chalk on the edge all the way round."
			% [plate_name, roundi(progress() / COVERED * 100.0)])
	if not points.is_empty() and flat.distance_to(points[points.size() - 1]) < STEP_M:
		return
	points.append(flat)
	_chalk_world.append(world + normal * 0.003)
	_draw_chalk(normal)
	if progress() >= COVERED:
		_measure(s)


func _restart(id: String, found: Dictionary) -> void:
	slot_id = id
	plate_box = found.box
	plate = found
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
	plate = {}
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


## A hint while tracing, at most every half second.
func _say(text: String) -> void:
	var now := Time.get_ticks_msec()
	if bay == null or not bay.has_method("hint") or now - _said_at < 500:
		return
	_said_at = now
	bay.call("hint", text)


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
