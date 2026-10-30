extends Node3D
## Ships stood on the apron for a look (Settings > Debug > Ship): each built by Shared
## Components' VsShipImport from BSX's copy of its Void Salvage file, frozen and solid to walk
## in, on Dock 2. Follows ShipBayBus.yard_ships on every player.

## Where each design stands: Dock 2's middle (apron.gd DOCKS), nose to the north (-Z).
const PLACES := {"manta": Vector3(-90.0, 0.0, 92.0)}

## Design -> its body.
var ships: Dictionary = {}
## Contract hulls (ShipBayBus.hulls): job id -> the hull's body, carried by its cradle.
var hulls: Dictionary = {}
## A large hull's sections cut free of it (ship_bay.sections): job id -> {section index ->
## the section's body, on its stand beside the dock or lifted into a transport cradle}.
var sections: Dictionary = {}
## Their stands (a pair of trestles each, staying when the crane lifts the section away):
## job id -> {section index -> the stand}.
var stands: Dictionary = {}
## The mobile cranes by Docks 2 and 3 (ship_bay.sections): dock id -> MobileCrane.
var cranes: Dictionary = {}

const HullSections := preload("res://modules/ship_bay/internal/hull_sections.gd")
const MobileCrane := preload("res://modules/ship_bay/internal/yard/mobile_crane.gd")
## Where each dock's mobile crane parks, at the south end of the dock's side towards the pad
## (the side its sections stand on), facing north. How far it works out past a section's
## edge (its carrier's middle), metres.
const CRANE_HOMES := {"2": Vector3(-52.0, 0.0, 136.0), "3": Vector3(52.0, 0.0, 136.0)}
const CRANE_GAP := 6.0
## A free section's stand: its trestles' tops over the ground, and how far beside the hull
## (past its full width) the sections are set down, metres. How long a section takes to
## swing from the hull to its stand, seconds.
const TRESTLE_TOP := 1.0
const STAND_GAP := 1.5
const SWING_TIME := 4.0
## A part a section stands on is at least this wide both ways, metres.
const STAND_ON := 1.0
var _bus: ShipBayBus


func _ready() -> void:
	name = "YardShips"
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if Flags.is_on("ship_bay.sections"):
		for id: String in CRANE_HOMES:
			var crane := MobileCrane.new()
			crane.name = "Crane" + id
			add_child(crane)
			crane.setup(CRANE_HOMES[id])
			crane.on_use = crane_use.bind(id)
			cranes[id] = crane
	if _bus:
		_bus.yard_ships_changed.connect(sync)
		sync(_bus.yard_ships)
		_bus.hulls_changed.connect(sync_hulls)
		sync_hulls()


func _exit_tree() -> void:
	if _bus and _bus.yard_ships_changed.is_connected(sync):
		_bus.yard_ships_changed.disconnect(sync)
	if _bus and _bus.hulls_changed.is_connected(sync_hulls):
		_bus.hulls_changed.disconnect(sync_hulls)


## Builds the designs in `designs` that aren't standing yet and takes away the rest.
func sync(designs: PackedStringArray) -> void:
	for d: String in ships.keys():
		if not designs.has(d):
			(ships[d] as Node).queue_free()
			ships.erase(d)
	for d: String in designs:
		if not ships.has(d) and PLACES.has(d):
			var body := _build(d)
			if body:
				ships[d] = body


func _build(design: String) -> Node3D:
	var file := VsShipImport.design_source(design)
	if file.is_empty():
		return null
	var body := RigidBody3D.new()
	body.name = design.capitalize()
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var importer := VsShipImport.new()
	if not importer.build(file, body):
		push_error("ShipBay: the %s didn't build: %s" % [design, "; ".join(importer.errors)])
		body.free()
		return null
	body.set_meta("importer", importer)
	# Its lowest point on the dock's concrete.
	var bounds: Dictionary = importer.file.get("derived", {}).get("bounds", {})
	var low := float((bounds.get("pos", [0, 0, 0]) as Array)[1])
	add_child(body)
	body.position = PLACES[design] + Vector3(0, -low + 0.02, 0)
	return body


## Builds each contract hull on its transport cradle (the cradle carries it from then on, so
## a transporter can move it about) and takes away hulls whose job is over.
func sync_hulls() -> void:
	if _bus == null:
		return
	for job: String in hulls.keys():
		var h: Dictionary = _bus.hulls.get(job, {})
		var body: Node3D = hulls[job]
		if h.is_empty() or not is_instance_valid(body) or body.get_parent() == null or str(body.get_parent().name) != str(h.get("cradle", "")) \
				or body.get_meta("free", []) != h.get("free", []):
			if is_instance_valid(body):
				var cradle := body.get_parent()
				if cradle and cradle.get("load_node") == body:
					cradle.set("load_node", null)
					cradle.set("load_t", 0.0)
				body.queue_free()
			hulls.erase(job)
	for job: String in sections.keys():
		var free: Array = (_bus.hulls.get(job, {}) as Dictionary).get("free", [])
		for i: int in (sections[job] as Dictionary).keys():
			if not free.has(i):
				var sec: Node3D = sections[job][i]
				var holder := sec.get_parent()
				if holder and holder.get("load_node") == sec:
					holder.set("load_node", null)
					holder.set("load_t", 0.0)
				sec.queue_free()
				(sections[job] as Dictionary).erase(i)
				var stand: Node = (stands.get(job, {}) as Dictionary).get(i)
				if stand:
					stand.queue_free()
					(stands[job] as Dictionary).erase(i)
		if (sections[job] as Dictionary).is_empty():
			sections.erase(job)
			stands.erase(job)
	for job: String in _bus.hulls:
		if hulls.has(job):
			continue
		var body := _build_hull(job, _bus.hulls[job])
		if body:
			hulls[job] = body
			_build_sections(job, _bus.hulls[job], body)
	for job: String in sections:
		_follow_lifts(job)


func _build_hull(job: String, h: Dictionary) -> Node3D:
	var yard := get_parent()
	var cradle: Node3D = yard.find_child(str(h.get("cradle", "")), true, false) as Node3D if yard else null
	if cradle == null or not cradle.has_method("carry"):
		return null
	var free: Array = h.get("free", [])
	var body: RigidBody3D
	if free.is_empty():
		body = hull_body("Hull_" + job.validate_node_name(), str(h.get("design", "")), int(h.get("seed", 0)), h.get("events", []))
	else:
		# What is left of it: every section not cut free.
		var plan := _bus.section_plan(job)
		var keep := {}
		var ranges: Array = []
		for sec: Dictionary in plan:
			if free.has(int(sec["index"])):
				continue
			for path: String in sec["parts"]:
				keep[path] = true
			ranges.append(_range_of(sec, plan.size()))
		body = file_body("Hull_" + job.validate_node_name(), HullSections.sub_file(ShipBayBus.hull_file(h), keep, ranges))
	if body == null:
		return null
	body.set_meta("free", free.duplicate())
	body.set_meta("job_id", job)
	body.set_meta("look_hint", {"title": str(h.get("name", "")).capitalize() if str(h.get("name", "")) != "" else "Contract hull",
			"text": "In for a job, on a transport cradle: a transporter can move it about.", "keys": []})
	var centre: Vector3 = body.get_meta("belly")
	cradle.call("carry", body, Vector3(-centre.x, float(cradle.get("saddle_top")) - centre.y + 0.02, -centre.z))
	cradle.set("load_t", float(h.get("mass_kg", 0.0)) / 1000.0)
	return body


## A wreck (or ship) of `design` rolled from `seed` with `events`, built as a frozen body
## named `node_name`; null if it has no file or doesn't build. Its meta "belly" is the middle
## of its belly in its own space (set that on a cradle's saddles), "importer" the importer.
static func hull_body(node_name: String, design: String, seed_value: int, events: Variant) -> RigidBody3D:
	return file_body(node_name, ShipBayBus.hull_file({"design": design, "seed": seed_value, "events": events}))


## The same from a hull file `file` (whole, or a section's: HullSections.sub_file).
static func file_body(node_name: String, file: Dictionary) -> RigidBody3D:
	if file.is_empty():
		return null
	var body := RigidBody3D.new()
	body.name = node_name
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var importer := VsShipImport.new()
	if not importer.build(file, body):
		push_error("ShipBay: %s didn't build: %s" % [node_name, "; ".join(importer.errors)])
		body.free()
		return null
	body.set_meta("importer", importer)
	var b: Dictionary = importer.file.get("derived", {}).get("bounds", {})
	var pos: Array = b.get("pos", [0, 0, 0])
	var size: Array = b.get("size", [0, 0, 0])
	body.set_meta("belly", Vector3(float(pos[0]) + float(size[0]) * 0.5, float(pos[1]), float(pos[2]) + float(size[2]) * 0.5))
	body.set_meta("mass_kg", float(importer.file.get("stats", {}).get("mass_kg", 0.0)))
	return body


# --- Sections cut free (S6) ------------------------------------------------------------------

## The z range a section's loose pieces and lights are kept for: its cuts, open at the
## hull's two ends (trim can stand past the bounds).
static func _range_of(sec: Dictionary, count: int) -> Array:
	return [-INF if int(sec["index"]) == 0 else float(sec["z0"]), INF if int(sec["index"]) == count - 1 else float(sec["z1"])]


## Builds each of a hull's free sections not built yet on its stand beside the dock: level
## with where it was cut from, set out past the hull's width on the side towards the pad
## (where its crane works), its belly on two trestles. One freed while the yard is open
## swings across from the hull; one already lifted goes straight into its cradle.
func _build_sections(job: String, h: Dictionary, hull: Node3D) -> void:
	var free: Array = h.get("free", [])
	if free.is_empty():
		return
	var plan := _bus.section_plan(job)
	var built: Dictionary = sections.get_or_add(job, {})
	var file := ShipBayBus.hull_file(h)
	var bounds: Dictionary = file.get("derived", {}).get("bounds", {})
	var width := float((bounds.get("size", [0, 0, 0]) as Array)[0])
	var belly: Vector3 = hull.get_meta("belly", Vector3.ZERO)
	var from := hull.global_transform
	var side := 1.0 if from.origin.x < 0.0 else -1.0   # Dock 2 is west of the pad, Dock 3 east
	for i: int in free:
		if built.has(i) or i >= plan.size():
			continue
		var sec: Dictionary = plan[i]
		var keep := {}
		for path: String in sec["parts"]:
			keep[path] = true
		var body := file_body("Section_%s_%d" % [job.validate_node_name(), i], HullSections.sub_file(file, keep, [_range_of(sec, plan.size())]))
		if body == null:
			continue
		body.set_meta("job_id", job)
		body.set_meta("section", i)
		body.set_meta("look_hint", {"title": "Section %d of %d (%s)" % [i + 1, plan.size(), str(h.get("name", "hull")).capitalize()],
				"text": "Cut free of the hull, %.0f t, on its stand: ready for the crane." % (float(sec["mass_kg"]) / 1000.0), "keys": []})
		body.set_meta("mass_kg", float(sec["mass_kg"]))
		add_child(body)
		# On its stand by its own lowest broad part (a section of a hull's middle can sit
		# metres over the keel it was cut from; a ladder or aerial hanging under it doesn't
		# count). Both boxes in its own space, for the crane.
		body.global_transform = Transform3D.IDENTITY
		var low := _mesh_box(body, STAND_ON)
		body.set_meta("broad_box", low)
		body.set_meta("whole_box", _mesh_box(body))
		var to := from
		to.origin += Vector3(side * (width + STAND_GAP), 0, 0)
		to.origin.y = TRESTLE_TOP - low.position.y
		body.global_transform = to
		body.set_meta("stand", to)
		var stand := Node3D.new()
		stand.name = "Stand_%s_%d" % [job.validate_node_name(), i]
		add_child(stand)
		stand.global_transform = to
		_trestles(stand, float(sec["z0"]), float(sec["z1"]), width, Vector3(belly.x, low.position.y, belly.z))
		(stands.get_or_add(job, {}) as Dictionary)[i] = stand
		built[i] = body
		var into := str(_bus.lifted_sections(job).get(str(i), ""))
		if into != "":
			body.set_meta("cradle", into)
			_seat(body, into)
		elif _live and int(free.back()) == i:
			_swing(body, from, to)


## True once the yard has built what it found on loading, so later frees swing across.
var _live := false


func _process(_delta: float) -> void:
	_live = true
	set_process(false)


## Moves a freed section from the hull to its stand: up clear, across, down.
func _swing(body: Node3D, from: Transform3D, to: Transform3D) -> void:
	var up := Vector3(0, 3.0, 0)
	body.global_transform = from
	var tw := create_tween()
	tw.tween_property(body, "global_position", from.origin + up, SWING_TIME * 0.3)
	tw.tween_property(body, "global_position", Vector3(to.origin.x, from.origin.y + up.y, to.origin.z), SWING_TIME * 0.4)
	tw.tween_property(body, "global_position", to.origin, SWING_TIME * 0.3)


## The box round a body's visible meshes at least `broad` metres across both ways
## (flat), world space.
static func _mesh_box(body: Node3D, broad := 0.0) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		var b := mi.global_transform * mi.mesh.get_aabb()
		if b.size.x < broad or b.size.z < broad:
			continue
		out = b if first else out.merge(b)
		first = false
	return out


## A pair of steel trestles under a section at its ends, in its stand's space (the section's
## own space where it stands).
func _trestles(body: Node3D, z0: float, z1: float, width: float, belly: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.75, 0.1)
	mat.roughness = 0.7
	var span := maxf(width * 0.6, 2.0)
	for z: float in [z0 + 1.0, z1 - 1.0]:
		var beam := MeshInstance3D.new()
		beam.mesh = PartShapes.box(Vector3(span, 0.3, 0.4)).mesh
		beam.material_override = mat
		beam.position = Vector3(belly.x, belly.y - 0.15, z)
		body.add_child(beam)
		for x: float in [-span * 0.45, span * 0.45]:
			var leg := MeshInstance3D.new()
			leg.mesh = PartShapes.box(Vector3(0.25, TRESTLE_TOP - 0.3, 0.25)).mesh
			leg.material_override = mat
			leg.position = Vector3(belly.x + x, belly.y - 0.3 - (TRESTLE_TOP - 0.3) * 0.5, z)
			body.add_child(leg)


# --- The mobile cranes (S6) ------------------------------------------------------------------

## Sections the host has said were lifted into a cradle that still stand on their stands:
## the dock's crane lifts each across (all at once on loading, or with the crane busy).
func _follow_lifts(job: String) -> void:
	var lifted := _bus.lifted_sections(job)
	for i: int in (sections.get(job, {}) as Dictionary):
		var body: Node3D = sections[job][i]
		var into := str(lifted.get(str(i), ""))
		if into == "" or str(body.get_meta("cradle", "")) == into:
			continue
		body.set_meta("cradle", into)
		var cradle := _cradle(into)
		if cradle == null:
			continue
		var crane: Node3D = cranes.get(_dock_of(body))
		var plan := _crane_plan(body, cradle)
		if _live and crane and not bool(crane.get("busy")) and not plan.is_empty():
			var whole: AABB = body.get_meta("whole_box")
			var broad: AABB = body.get_meta("broad_box")
			var c := broad.get_center()
			crane.call("lift", body, plan["to"], plan["spot"], Vector3(c.x, broad.position.y, c.z), whole.end.y,
					Vector2(broad.size.x, broad.size.z) * 0.5, _seat.bind(body, into))
		else:
			_seat(body, into)


## The dock a section stands by: "2" west of the pad, "3" east.
static func _dock_of(body: Node3D) -> String:
	var at: Transform3D = body.get_meta("stand", body.global_transform)
	return "2" if at.origin.x < 0.0 else "3"


func _cradle(cradle_name: String) -> Node3D:
	var yard := get_parent()
	var c := yard.find_child(cradle_name, true, false) as Node3D if yard else null
	return c if c and c.has_method("carry") else null


## A section's place in `cradle`'s saddles (world), its ends along the cradle's whichever way
## round turns it least.
static func _in_cradle(body: Node3D, cradle: Node3D) -> Transform3D:
	var broad: AABB = body.get_meta("broad_box")
	var c := broad.get_center()
	var rel := wrapf(body.global_transform.basis.get_euler().y - cradle.global_transform.basis.get_euler().y, -PI, PI)
	var turn := Basis(Vector3.UP, 0.0 if absf(rel) < PI * 0.5 else PI)
	var origin := Vector3(0, float(cradle.get("saddle_top")) + 0.02, 0) - turn * Vector3(c.x, broad.position.y, c.z)
	return cradle.global_transform * Transform3D(turn, origin)


## Where the crane works from to lift `body` off its stand into `cradle`: {spot, to}, or {}
## when no spot beside the section reaches both.
func _crane_plan(body: Node3D, cradle: Node3D) -> Dictionary:
	var stand: Transform3D = body.get_meta("stand", body.global_transform)
	var broad: AABB = body.get_meta("broad_box")
	var whole: AABB = body.get_meta("whole_box")
	var to := _in_cradle(body, cradle)
	var pick := stand * broad.get_center()
	var drop := to * broad.get_center()
	var side := 1.0 if stand.origin.x < 0.0 else -1.0
	var edge := maxf((stand * whole.position).x, (stand * whole.end).x) if side > 0.0 else minf((stand * whole.position).x, (stand * whole.end).x)
	var x := edge + side * CRANE_GAP
	for z: float in [(pick.z + drop.z) * 0.5, pick.z, drop.z]:
		var spot := Vector3(x, 0, z - MobileCrane.PIVOT.z)
		if MobileCrane.reaches(spot, pick) and MobileCrane.reaches(spot, drop):
			return {"spot": spot, "to": to}
	return {}


## Sets a lifted section in its cradle's saddles; the cradle carries it from then on.
func _seat(body: Node3D, cradle_name: String) -> void:
	var cradle := _cradle(cradle_name)
	if cradle == null or not is_instance_valid(body):
		return
	var at := _in_cradle(body, cradle)
	if body.get_parent():
		body.get_parent().remove_child(body)
	cradle.call("carry", body, Vector3.ZERO)
	body.global_transform = at
	cradle.set("load_t", float(body.get_meta("mass_kg", 0.0)) / 1000.0)
	var hint: Dictionary = (body.get_meta("look_hint", {}) as Dictionary).duplicate()
	hint["text"] = "Cut free of the hull, %.0f t, in a transport cradle: a transporter can move it about." % (float(body.get_meta("mass_kg", 0.0)) / 1000.0)
	body.set_meta("look_hint", hint)


## F on dock `dock`'s crane: it lifts the first section on a stand by that dock into the
## nearest empty cradle it reaches that is big enough. Says why not on its screen.
func crane_use(dock: String) -> void:
	var crane: Node3D = cranes.get(dock)
	if crane == null or _bus == null or bool(crane.get("busy")):
		return
	var tr := get_parent().find_child("Transporters", true, false) if get_parent() else null
	var all: Array = tr.get("cradles") if tr else []
	var taken := _bus.cradles_in_use()
	var waiting := false
	for job: String in sections:
		var plan := _bus.section_plan(job)
		var lifted := _bus.lifted_sections(job)
		var order: Array = (sections[job] as Dictionary).keys()
		order.sort()
		for i: int in order:
			var body: Node3D = sections[job][i]
			if lifted.has(str(i)) or _dock_of(body) != dock or i >= plan.size():
				continue
			waiting = true
			var sec: Dictionary = plan[i]
			var need := ShipBayBus.cradle_size_for(float(sec["mass_kg"]), float(sec["z1"]) - float(sec["z0"]))
			var best := ""
			var best_d := INF
			for c: Node3D in all:
				if taken.has(str(c.name)) or c.get("load_node") != null or not _fits(str(c.get("size")), need):
					continue
				if _crane_plan(body, c).is_empty():
					continue
				var d := c.global_position.distance_to(body.global_position)
				if d < best_d:
					best_d = d
					best = str(c.name)
			if best != "":
				_bus.lift_section(job, i, best)
				return
	crane.set("status", "NO EMPTY CRADLE IN REACH" if waiting else "NO SECTION ON A STAND")
	crane.call("_apply")


static func _fits(size: String, need: String) -> bool:
	var rank := {"s": 0, "m": 1, "l": 2}
	return int(rank.get(size, -1)) >= int(rank.get(need, 3))
