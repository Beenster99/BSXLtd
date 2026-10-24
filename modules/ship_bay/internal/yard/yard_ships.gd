extends Node3D
## Ships stood on the apron for a look (Settings > Debug > Ship): each built by Shared
## Components' VsShipImport from BSX's copy of its Void Salvage file, frozen and solid to walk
## in, on Dock 2. Follows ShipBayBus.yard_ships on every player.

## Where each design stands: Dock 2's middle (apron.gd DOCKS), nose to the north (-Z).
const PLACES := {"manta": Vector3(-90.0, 0.0, 92.0)}

## Design -> its body.
var ships: Dictionary = {}
var _bus: ShipBayBus


func _ready() -> void:
	name = "YardShips"
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if _bus:
		_bus.yard_ships_changed.connect(sync)
		sync(_bus.yard_ships)


func _exit_tree() -> void:
	if _bus and _bus.yard_ships_changed.is_connected(sync):
		_bus.yard_ships_changed.disconnect(sync)


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
