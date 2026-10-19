extends RefCounted
## Builds a ShipDefinition from a ship's folder:
##   <name>_layout.json     Void Salvage's view of the ship (rooms, module slots), ship space
##   <name>_fasteners.json  BSX's joints per slot
##   <name>.glb             the model
## The layout is shaped like the file Void Salvage will export, so swapping the hand-written
## one for an exported one needs no code change.

const LAYOUT_VERSION := 1


static func load_ship(dir: String) -> ShipDefinition:
	var name := dir.get_file()
	var layout := _read_json(dir.path_join(name + "_layout.json"))
	if layout.is_empty():
		return null
	if int(layout.get("version", 0)) > LAYOUT_VERSION:
		push_error("ShipBay: %s layout version %s is newer than %d" % [name, layout.get("version"), LAYOUT_VERSION])
		return null
	var joints: Dictionary = _read_json(dir.path_join(name + "_fasteners.json")).get("slots", {})
	var def := ShipDefinition.new()
	def.version = int(layout.get("version", 1))
	def.ship_id = layout.get("ship_id", "")
	def.display_name = layout.get("display_name", def.ship_id)
	def.source = layout.get("source", "")
	def.bounds = _aabb(layout.get("bounds", {}))
	for room: Dictionary in layout.get("rooms", []):
		var z: Array = room.get("z", [0.0, 0.0])
		def.rooms[room.get("name", "")] = Vector2(z[0], z[1])
	for entry: Dictionary in layout.get("module_slots", []):
		var s := _slot(entry)
		for j: Dictionary in joints.get(s.slot_id, []):
			s.fasteners.append(_fastener(s.slot_id, j))
		def.slots.append(s)
	var model_path := dir.path_join(name + ".glb")
	if ResourceLoader.exists(model_path):
		def.model = load(model_path)
	return def


static func _slot(e: Dictionary) -> MountSlot:
	var s := MountSlot.new()
	s.slot_id = e.get("slot_id", "")
	s.display_name = e.get("display_name", s.slot_id)
	s.accepts = PackedStringArray(e.get("accepts", []))
	s.fitted = e.get("fitted", "")
	s.access = e.get("access", "inboard")
	s.box = _aabb(e.get("box", {}))
	var facing := _vec(e.get("facing", [0, 0, 1])).normalized()
	var up := Vector3.UP if absf(facing.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	var x := up.cross(facing).normalized()
	s.mount = Transform3D(Basis(x, facing.cross(x), facing), _vec(e.get("origin", [0, 0, 0])))
	return s


static func _fastener(slot_id: String, j: Dictionary) -> FastenerPoint:
	var f := FastenerPoint.new()
	f.joint_id = "%s/%s" % [slot_id, j.get("id", "")]
	f.kind = j.get("kind", "bolt")
	f.spec = j.get("spec", "")
	f.position = _vec(j.get("at", [0, 0, 0]))
	f.normal = _vec(j.get("normal", [0, 1, 0])).normalized()
	return f


static func _read_json(path: String) -> Dictionary:
	var res := load(path) as JSON if ResourceLoader.exists(path) else null
	if res == null or not res.data is Dictionary:
		push_error("ShipBay: can't read %s" % path)
		return {}
	return res.data


static func _vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


static func _aabb(d: Dictionary) -> AABB:
	var lo := _vec(d.get("min", [0, 0, 0]))
	return AABB(lo, _vec(d.get("max", [0, 0, 0])) - lo)
