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
## the section's body, on its stand beside the dock}.
var sections: Dictionary = {}

const HullSections := preload("res://modules/ship_bay/internal/hull_sections.gd")
## A free section's stand: its trestles' tops over the ground, and how far beside the hull
## (past its full width) the sections are set down, metres. How long a section takes to
## swing from the hull to its stand, seconds.
const TRESTLE_TOP := 1.0
const STAND_GAP := 1.5
const SWING_TIME := 4.0
var _bus: ShipBayBus


func _ready() -> void:
	name = "YardShips"
	_bus = Modules.bus("ship_bay") as ShipBayBus
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
				(sections[job][i] as Node).queue_free()
				(sections[job] as Dictionary).erase(i)
		if (sections[job] as Dictionary).is_empty():
			sections.erase(job)
	for job: String in _bus.hulls:
		if hulls.has(job):
			continue
		var body := _build_hull(job, _bus.hulls[job])
		if body:
			hulls[job] = body
			_build_sections(job, _bus.hulls[job], body)


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
## with where it was cut from, set out past the hull's width on the dock's outer side, its
## belly on two trestles. One freed while the yard is open swings across from the hull.
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
	var side := -1.0 if from.origin.x < 0.0 else 1.0   # Dock 2 is west of the pad, Dock 3 east
	var to := from
	to.origin += Vector3(side * (width + STAND_GAP), TRESTLE_TOP - (from * belly).y, 0)
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
		add_child(body)
		body.global_transform = to
		_trestles(body, float(sec["z0"]), float(sec["z1"]), width, belly)
		built[i] = body
		if _live and int(free.back()) == i:
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


## A pair of steel trestles under a section at its ends, in the section's own space.
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
