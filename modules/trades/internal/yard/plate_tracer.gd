class_name TradesPlateTracer
extends Node3D
## Making cutting configs off the ship's plates with the template scribe (beenster, 0.3.23,
## and 0.3.24's playtest: "The scribe tool should highlight the plate you are pointed to and
## provide information in the right panel, the player should be able to save the plate as a
## config for the flatbed plasma cutter"). Behind trades.cutting_bed.
##
## With the scribe in hand, the plate of the ship (or a wreck) under your aim lights up: its
## edge drawn in glowing chalk and a pale wash over it, and the right-hand panel shows its name,
## its size, its area and whether it is saved yet. Left click saves it: it is measured into a
## cutting config (named for the plate, numbered T-001, T-002...) that the cutting bed's screen
## offers for everyone, kept in the save, and a chalk line is left round the plate.
##
## trades.scribe_beams (beenster, 0.3.29: "scribe tool should pick beams now too"): a member of
## her frame (a ring, a stringer, a post) or a beam of the hologram under the aim lights up
## the same way, the panel gives its length and section, and left click puts its length on the
## cutting bed's cut list.

const EVENT := "trades.template"
const SECTION := "trades_templates"
## The thinnest a plate's box is to count as a plate (m), and the least of its other sides.
const PLATE_MAX_T := 0.07
const PLATE_MIN_SIDE := 0.15
## How far off a plate's plane the aim still counts as on it (m).
const PLANE_M := 0.25
## How far the scribe reaches (m from the eye).
const REACH_M := 6.0
## How far a hit face may lean off a plate's mount facing and still be that plate (degrees).
const FACE_DEG := 40.0
## The right-hand panel's card.
const INFO := "trades.plate"
const GLOW := Color(0.45, 1.0, 0.85)

var bay: Node  # TradesBay
## The plate under the scribe's aim now: plate_at's dictionary, or {} for none.
var aimed: Dictionary = {}
## The aimed plate's name, for the scribe's screen ("" for none).
var plate_name := ""
## The last config saved here (for the hint and tests), {} before any.
var last: Dictionary = {}

var _net: Node
var _highlight: MeshInstance3D
var _chalk: MeshInstance3D
var _said_at := -10000
var _shown := ""
## The beam under the scribe's aim (trades.scribe_beams): {name, a, b (ship space), size
## (Vector2 across its section, m), source (the frame part's path, or "holo:<id>")}, {} for none.
var beam: Dictionary = {}
## How near the aim a hologram beam's line counts as on it (m).
const HOLO_PICK_M := 0.15


static func beams_on() -> bool:
	return Flags.is_on("trades.scribe_beams")


static func enabled() -> bool:
	return Flags.is_on("trades.cutting_bed")


func build(net: Node = null) -> void:
	_highlight = MeshInstance3D.new()
	_highlight.name = "Highlight"
	_highlight.mesh = ImmediateMesh.new()
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.vertex_color_use_as_albedo = true
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Drawn over the plate whatever is in the way, so the plate you point at always shows.
	hm.no_depth_test = true
	hm.render_priority = 1
	_highlight.material_override = hm
	_highlight.top_level = true
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)
	_chalk = MeshInstance3D.new()
	_chalk.name = "Chalk"
	_chalk.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 0.9)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_chalk.material_override = m
	_chalk.top_level = true
	_chalk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_chalk)
	_net = net
	if _net:
		_net.call("register_event", EVENT, _apply, _validate)
		if _net.has_method("register_snapshot_provider"):
			_net.call("register_snapshot_provider", SECTION, self)


func _exit_tree() -> void:
	HudSlots.clear_info(INFO)
	if _net:
		_net.call("unregister_event", EVENT)
		if _net.has_method("unregister_snapshot_provider"):
			_net.call("unregister_snapshot_provider", SECTION)


## The scribe's left click: pressed saves the plate under the aim (or takes the beam's length).
func set_tracing(on: bool) -> void:
	if on:
		if not beam.is_empty():
			take_beam()
		else:
			save_aimed()


## A ray (world space) that goes on through parts taken off the ship: their shapes stay on
## her body a while, but there's nothing there to pick.
static func through_gone(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var ship := Modules.bus("ship_bay") as ShipBayBus
	var at := from
	var end := from + dir * REACH_M
	for i in 8:
		var q := PhysicsRayQueryParameters3D.create(at, end)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty() or ship == null \
				or str(ship.inspect_at(hit.collider, int(hit.get("shape", 0)), hit.position).get("slot_state", "")) != "empty":
			return hit
		at = (hit.position as Vector3) + dir * 0.01
	return {}


## The beam under a world-space aim from `from` along `dir`, the ray's `hit` given: a hologram
## beam the line passes within HOLO_PICK_M of (nearer than the hit), else the frame member the
## hit is on; {} for none (see `beam`).
func beam_at(from: Vector3, dir: Vector3, hit: Dictionary) -> Dictionary:
	var xf := ship_xform()
	var xi := xf.affine_inverse()
	var o := xi * from
	var d := (xi.basis * dir).normalized()
	var hit_t := INF if hit.is_empty() else from.distance_to(hit.position as Vector3)
	var best := {}
	var best_t := hit_t
	var ship := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	if ship and ship.ship and bus:
		for r: Dictionary in bus.beam_design(ship.ship.ship_id):
			var a := VsShipImport.vec3(r.a)
			var b := VsShipImport.vec3(r.b)
			var c := Geometry3D.get_closest_points_between_segments(o, o + d * REACH_M, a, b)
			var t := o.distance_to(c[0])
			if c[0].distance_to(c[1]) < HOLO_PICK_M and t < best_t:
				var sec := TradesBeamSections.normal(str(r.section))
				best_t = t
				best = {"name": "Hologram beam, %s" % TradesBeamSections.name_of(sec), "a": a, "b": b,
						"size": Vector2(float(TradesBeamSections.info(sec).get("w", 0.1)), float(TradesBeamSections.info(sec).get("h", 0.1))), "source": "holo:%d" % int(r.id)}
	if not best.is_empty() or hit.is_empty() or ship == null or ship.ship == null:
		return best
	var info := ship.inspect_at(hit.collider, int(hit.get("shape", 0)), hit.position)
	if str(info.get("kind", "")) != "frame" or str(info.get("slot_state", "")) == "empty":
		return {}
	var path := str(info.get("path", ""))
	for part: Variant in TradesBeamDesigner._ship_file(ship.ship).get("parts", []):
		if not part is Dictionary or str((part as Dictionary).get("path", "")) != path:
			continue
		var shape: Dictionary = (part as Dictionary).get("shape", {})
		var args: Array = shape.get("args", [])
		if str(shape.get("shape", "")) != "girder" or args.size() < 3:
			return {}
		var pxf := VsShipImport.xform((part as Dictionary).get("xform", {}))
		var half := pxf.basis.x.normalized() * float(args[0]) * 0.5
		var shown := str(info.get("display_name", "")) if str(info.get("display_name", "")) != "" else str(info.get("name", "Frame member")).capitalize()
		return {"name": shown, "a": pxf.origin - half, "b": pxf.origin + half,
				"size": Vector2(float(args[1]), float(args[2])), "source": path}
	return {}


func _aim_beam(found: Dictionary) -> void:
	var key := "" if found.is_empty() else str(found.source)
	var was := "" if beam.is_empty() else str(beam.source)
	beam = found
	if found.is_empty():
		if was != "":
			(_highlight.mesh as ImmediateMesh).clear_surfaces()
			HudSlots.clear_info(INFO)
		return
	plate_name = str(found.name)
	_draw_beam()
	if key != was:
		_shown = ""
		HudSlots.set_info(INFO, "Beam", "\n".join(beam_lines()), 9)


## A beam's length (mm).
static func beam_mm(b: Dictionary) -> int:
	return roundi((b.a as Vector3).distance_to(b.b) * 1000.0)


## What the right-hand panel says about the aimed beam.
func beam_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if beam.is_empty():
		return out
	var size: Vector2 = beam.size
	out.append(str(beam.name))
	out.append("Length  %d mm" % beam_mm(beam))
	out.append("Section  %d x %d mm" % [roundi(size.x * 1000.0), roundi(size.y * 1000.0)])
	out.append("Left click: add it to the cutting bed's cut list")
	return out


## Puts the aimed beam's length on the cutting bed's cut list. Returns why not, or "".
func take_beam() -> String:
	if beam.is_empty():
		return "no beam"
	var bed := bay.get("cutting_bed") as TradesCuttingBed if bay else null
	if bed == null:
		_say("There's no cutting bed to send it to.")
		return "no bed"
	var mm := clampi(beam_mm(beam), 50, 12000)
	var why := bed.add_length(mm)
	if why != "":
		_say("%d mm: %s." % [mm, why])
		return why
	if bay and bay.has_method("play"):
		bay.call("play", &"tick")
	if bay and bay.has_method("hint"):
		bay.call("hint", "%d mm added to the cutting bed's cut list (%d on it)." % [mm, bed.lengths.size()])
	return ""


## The aimed beam lit: its line glowing, breathing.
func _draw_beam() -> void:
	var im := _highlight.mesh as ImmediateMesh
	im.clear_surfaces()
	var xf := ship_xform()
	var a := xf * (beam.a as Vector3)
	var b := xf * (beam.b as Vector3)
	var size: Vector2 = beam.size
	var r := maxf(size.x, size.y) * 0.5 + 0.03
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP if absf(along.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(along).normalized()
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	var edge := Color(GLOW.r, GLOW.g, GLOW.b, 0.5 + 0.3 * pulse)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var c0 := (side * cos(k * PI / 2.0) + up * sin(k * PI / 2.0)) * r
		var c1 := (side * cos((k + 1) * PI / 2.0) + up * sin((k + 1) * PI / 2.0)) * r
		for q: Vector3 in [a + c0, b + c0, b + c1, a + c0, b + c1, a + c1]:
			im.surface_set_color(Color(edge, 0.15 + 0.08 * pulse))
			im.surface_add_vertex(q)
	im.surface_end()


## The plate slot under a ship-space point: {slot, box, centre, u, v, n (ship-space plane axes:
## two across the plate, one out of it), size (m across u and v)} or {} for none. A plate is a
## slot named for one (a hull or wall plate), or one whose box is plate-thin; a slanted plate's
## plane is its mount's facing (its box is fat round it), so the Kestrel's 8 cm and slanted
## plates count too (playtest 0.3.24: the scribe found almost none).
## `keep`: the plate being traced keeps the chalk where it meets a neighbour along an edge.
## `face`: the ship-space normal of the surface the aim hit (trades.scribe_faces, beenster
## 0.3.27: "scribe doesnt seem to be able to pick up the angled sections"): a wreck's tapering
## plates face their ring's way, not the way their mount says, so the hit face sets the plane.
static func plate_at(p: Vector3, keep := "", face := Vector3.ZERO) -> Dictionary:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	if bus == null:
		return {}
	var best := {}
	var best_d := INF
	for s: MountSlot in bus.get_slots():
		if not s.box.grow(0.06).has_point(p):
			continue
		var plate := plate_of(s, face)
		if plate.is_empty():
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
## `face` (ship space, or zero): a plate within FACE_DEG of facing it is taken as facing it.
static func plate_of(s: MountSlot, face := Vector3.ZERO) -> Dictionary:
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
	if face != Vector3.ZERO and Flags.is_on("trades.scribe_faces"):
		var f := face.normalized() * signf(face.dot(n)) if face.dot(n) != 0.0 else Vector3.ZERO
		if f != Vector3.ZERO and f.dot(n) >= cos(deg_to_rad(FACE_DEG)):
			n = f
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




## Each step with the scribe in hand: the plate under the aim, lit up and on the panel.
func _physics_process(_delta: float) -> void:
	var w := bay.get("worker") as Node3D if bay else null
	var holding: bool = bay != null and bay.get("tool") == &"template" and w != null and w.is_inside_tree()
	if not holding:
		_aim({})
		return
	var from: Vector3 = w.call("aim_origin")
	var dir: Vector3 = w.call("aim_dir")
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * REACH_M)
	q.exclude = [(w as CollisionObject3D).get_rid()]
	var hit := w.get_world_3d().direct_space_state.intersect_ray(q)
	if beams_on():
		var found := beam_at(from, dir, through_gone(w.get_world_3d().direct_space_state, from, dir, q.exclude))
		if not found.is_empty():
			_aim({})
			_aim_beam(found)
			return
		_aim_beam({})
	aim_at(hit.position if not hit.is_empty() else Vector3.INF, hit.get("normal", Vector3.ZERO))


## Aims the scribe at a world point (INF: at nothing): the plate there becomes `aimed`.
## `normal`: the world normal of the face hit there, if known.
func aim_at(world: Vector3, normal := Vector3.ZERO) -> void:
	if not world.is_finite():
		_aim({})
		return
	var xf := ship_xform()
	var p := xf.affine_inverse() * world
	var face := (xf.basis.inverse() * normal).normalized() if normal != Vector3.ZERO else Vector3.ZERO
	_aim(plate_at(p, str((aimed.slot as MountSlot).slot_id) if not aimed.is_empty() else "", face))


func ship_xform() -> Transform3D:
	return bay.call("ship_transform") if bay and bay.has_method("ship_transform") else Transform3D.IDENTITY


func _aim(found: Dictionary) -> void:
	aimed = found
	var s: MountSlot = found.get("slot") as MountSlot
	plate_name = "" if s == null else (s.display_name if s.display_name != "" else s.slot_id.capitalize())
	var key := "" if s == null else s.slot_id + str(saved_as(s.slot_id))
	if key == _shown:
		if s:
			_draw_highlight()
		return
	_shown = key
	(_highlight.mesh as ImmediateMesh).clear_surfaces()
	if s == null:
		HudSlots.clear_info(INFO)
		return
	_draw_highlight()
	HudSlots.set_info(INFO, "Plate", "\n".join(info_lines()), 9)


## What the right-hand panel says about the aimed plate.
func info_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if aimed.is_empty():
		return out
	var s: MountSlot = aimed.slot
	var size: Vector2 = aimed.size
	var big := Vector2(maxf(size.x, size.y), minf(size.x, size.y))
	out.append(plate_name)
	out.append("Size  %d x %d mm" % [roundi(big.x * 1000.0), roundi(big.y * 1000.0)])
	out.append("Area  %.2f m²,  edge %.1f m" % [size.x * size.y, 2.0 * (size.x + size.y)])
	if s.fitted != "":
		out.append("Part  %s" % s.fitted)
	var saved := saved_as(s.slot_id)
	if saved != "":
		out.append("Saved as cutting config %s" % saved)
	else:
		out.append("Left click: save it as a cutting config")
	return out


## The config already saved from a plate (its slot id), or "".
func saved_as(slot_id: String) -> String:
	var bus := Modules.bus("trades") as TradesBus
	if bus:
		for t: Dictionary in bus.templates():
			if str(t.get("source", "")) == slot_id and str(t.get("kind", "")) == "traced":
				return str(t.id)
	return ""


## Saves the aimed plate as a cutting config (host-checked, for everyone). Returns why not, or "".
func save_aimed() -> String:
	if aimed.is_empty():
		_say("Point the scribe at a plate of the ship to save it as a cutting config.")
		return "no plate"
	var s: MountSlot = aimed.slot
	var already := saved_as(s.slot_id)
	if already != "":
		_say("%s is already saved as cutting config %s." % [plate_name, already])
		return "saved"
	var half: Vector2 = (aimed.size as Vector2) * 0.5
	if half.x < half.y:
		half = Vector2(half.y, half.x)
	var outline := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	_draw_chalk(aimed)
	_ask({"name": plate_name, "outline": outline, "source": s.slot_id})
	if bay and bay.has_method("play"):
		bay.call("play", &"tick")
	return ""


## A hint, at most every half second.
func _say(text: String) -> void:
	var now := Time.get_ticks_msec()
	if bay == null or not bay.has_method("hint") or now - _said_at < 500:
		return
	_said_at = now
	bay.call("hint", text)


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
	if saved_as(str(p.get("source", ""))) != "":
		return "already saved"
	var bus := Modules.bus("trades") as TradesBus
	return {"id": bus.next_template_id() if bus else "T-000", "name": str(p.get("name", "Plate")),
			"outline": outline, "source": str(p.get("source", ""))}


func _apply(p: Dictionary) -> void:
	var bus := Modules.bus("trades") as TradesBus
	if bus == null:
		return
	last = bus.add_template(TradesPlateShapes.finish({"id": str(p.id), "name": str(p.name), "outline": p.outline,
			"holes": [], "kind": "traced", "source": str(p.source)}))
	_shown = ""
	if bay and bay.has_method("hint"):
		var s: Vector2 = last.size
		bay.call("hint", "Saved %s as cutting config %s, %d x %d mm. Pick it on the cutting bed's screen."
				% [last.name, last.id, roundi(s.x * 1000.0), roundi(s.y * 1000.0)])


## The plate's four corners in the world, a hair off its face (towards `out`).
func _corners(found: Dictionary, lift: float) -> PackedVector3Array:
	var ship := ship_xform()
	var c: Vector3 = found.centre
	var u: Vector3 = found.u
	var v: Vector3 = found.v
	var n: Vector3 = found.n
	# Off the face the worker is on.
	var w := bay.get("worker") as Node3D if bay else null
	if w and w.is_inside_tree() and (ship.basis * n).dot(w.global_position - ship * c) < 0.0:
		n = -n
	var h: Vector2 = (found.size as Vector2) * 0.5
	var out := PackedVector3Array()
	for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		out.append(ship * (c + u * h.x * k.x + v * h.y * k.y + n * lift))
	return out


## The aimed plate lit: a pale wash and a glowing edge that breathes.
func _draw_highlight() -> void:
	var im := _highlight.mesh as ImmediateMesh
	im.clear_surfaces()
	var p := _corners(aimed, 0.05)
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var wash := Color(GLOW.r, GLOW.g, GLOW.b, 0.12 + 0.06 * pulse)
	for i: int in [0, 1, 2, 0, 2, 3]:
		im.surface_set_color(wash)
		im.surface_add_vertex(p[i])
	var edge := Color(GLOW.r, GLOW.g, GLOW.b, 0.7 + 0.3 * pulse)
	var n := (p[1] - p[0]).cross(p[3] - p[0]).normalized()
	for i in 4:
		var a := p[i]
		var b := p[(i + 1) % 4]
		var side := (b - a).normalized().cross(n).normalized() * 0.02
		for q: Vector3 in [a - side, b - side, b + side, a - side, b + side, a + side]:
			im.surface_set_color(edge)
			im.surface_add_vertex(q)
	im.surface_end()


## A chalk line left round a saved plate.
func _draw_chalk(found: Dictionary) -> void:
	var im := _chalk.mesh as ImmediateMesh
	im.clear_surfaces()
	var p := _corners(found, 0.012)
	var n := (p[1] - p[0]).cross(p[3] - p[0]).normalized()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a := p[i]
		var b := p[(i + 1) % 4]
		var side := (b - a).normalized().cross(n).normalized() * 0.008
		for q: Vector3 in [a - side, b - side, b + side, a - side, b + side, a + side]:
			im.surface_add_vertex(q)
	im.surface_end()


# --- Snapshot: late joiners get the saved configs ------------------------------------------

func get_net_snapshot() -> Dictionary:
	var bus := Modules.bus("trades") as TradesBus
	return {"traced": bus.save_data().get("templates", []) if bus else []}


func apply_net_snapshot(data: Dictionary) -> void:
	var bus := Modules.bus("trades") as TradesBus
	if bus:
		bus.load_data({"templates": data.get("traced", [])}, bus.save_version())
