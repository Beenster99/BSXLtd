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
		if h.is_empty() or not is_instance_valid(body) or body.get_parent() == null or str(body.get_parent().name) != str(h.get("cradle", "")):
			if is_instance_valid(body):
				var cradle := body.get_parent()
				if cradle and cradle.get("load_node") == body:
					cradle.set("load_node", null)
					cradle.set("load_t", 0.0)
				body.queue_free()
			hulls.erase(job)
	for job: String in _bus.hulls:
		if hulls.has(job):
			continue
		var body := _build_hull(job, _bus.hulls[job])
		if body:
			hulls[job] = body


func _build_hull(job: String, h: Dictionary) -> Node3D:
	var yard := get_parent()
	var cradle: Node3D = yard.find_child(str(h.get("cradle", "")), true, false) as Node3D if yard else null
	if cradle == null or not cradle.has_method("carry"):
		return null
	var file := WreckMaker.for_design(str(h.get("design", "")), int(h.get("seed", 0)), h.get("events", []))
	if file.is_empty():
		file = VsShipImport.design_source(str(h.get("design", "")))
	if file.is_empty():
		return null
	var body := RigidBody3D.new()
	body.name = "Hull_" + job.validate_node_name()
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var importer := VsShipImport.new()
	if not importer.build(file, body):
		push_error("ShipBay: contract hull %s didn't build: %s" % [job, "; ".join(importer.errors)])
		body.free()
		return null
	body.set_meta("importer", importer)
	body.set_meta("job_id", job)
	body.set_meta("look_hint", {"title": str(h.get("name", "")).capitalize() if str(h.get("name", "")) != "" else "Contract hull",
			"text": "In for a job, on a transport cradle: a transporter can move it about.", "keys": []})
	# Its belly on the saddles, its middle over the cradle's.
	var b: Dictionary = importer.file.get("derived", {}).get("bounds", {})
	var pos: Array = b.get("pos", [0, 0, 0])
	var size: Array = b.get("size", [0, 0, 0])
	var centre := Vector3(float(pos[0]) + float(size[0]) * 0.5, float(pos[1]), float(pos[2]) + float(size[2]) * 0.5)
	cradle.call("carry", body, Vector3(-centre.x, float(cradle.get("saddle_top")) - centre.y + 0.02, -centre.z))
	cradle.set("load_t", float(h.get("mass_kg", 0.0)) / 1000.0)
	return body
