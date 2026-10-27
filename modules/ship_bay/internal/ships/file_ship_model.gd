extends RigidBody3D
## A ship the bay builds straight from its Void Salvage file, with no folder of its own: the
## random wrecks (Settings > Debug > Ship) and any generated ship. Built by Shared Components'
## VsShipImport like the Kestrel, so every part and joint has the path its file gives it and
## the bay's fastener markers line up with them. What the Kestrel's folder says by hand (where
## the stairs meet the side door, where the shore power socket is) this works out from the
## file. A wreck's damage is in the file: gone parts aren't built, broken joints aren't made.
##
## Frozen: it stands on the bay's cradle. Ship space: -Z forward, +Y up, the deck floor at
## y = 0.

## The landing legs' part paths start with this; on a cradle they stand down between its beams.
const LEG := "component:leg/"
## How far apart lowest_in reads the surface, metres.
const STEP := 0.25

var importer: VsShipImport
var file: Dictionary = {}
## The side door's sill and the power socket, ship space (access_points).
var side_door := Vector3.ZERO
var power_socket := Vector3.ZERO


func _init(f: Dictionary = {}, node_name := "Wreck") -> void:
	name = node_name
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	file = f
	importer = VsShipImport.new()
	if not importer.build(f, self):
		push_error("ShipBay: %s didn't build: %s" % [node_name, "; ".join(importer.errors)])
		return
	_find_access()
	_build_power_socket()


## Where the bay's stairs and power cable meet the ship (ship space).
func access_points() -> Dictionary:
	return {"side_door": side_door, "power_socket": power_socket}


## The side door: the file's port side door opening if it has one, else the port side of the
## hull at the floor, a third of the way aft. The socket: low on the starboard flank, aft.
func _find_access() -> void:
	var hull := AABB()
	var first := true
	var door := AABB()
	var has_door := false
	for p: Dictionary in file.get("parts", []):
		var path := str(p.get("path", ""))
		if not path.begins_with("hull/"):
			continue
		var b := _box(p.get("box", {}))
		hull = b if first else hull.merge(b)
		first = false
		if path.begins_with("hull/opening:side_door/"):
			door = b if not has_door else door.merge(b)
			has_door = true
	if first:
		var bounds: Dictionary = file.get("derived", {}).get("bounds", {})
		hull = _box(bounds)
	if has_door and door.get_center().x < 0.0:
		side_door = Vector3(door.position.x, 0.0, door.get_center().z)
	else:
		side_door = Vector3(hull.position.x, 0.0, hull.position.z + hull.size.z * 0.4)
	power_socket = Vector3(hull.end.x, 0.72, hull.position.z + hull.size.z * 0.78)


## Slot id -> the model's meshes that are the slot's part (the visuals of the file's parts it
## holds), as KestrelModel.slot_pieces, plus loose look pieces inside a fitting's or unit's
## box.
func slot_pieces(def: ShipDefinition) -> Dictionary:
	var out := {}
	var taken := {}
	var owner := {}
	var units: Array[MountSlot] = []
	for s in def.slots:
		out[s.slot_id] = []
		for p: String in s.parts:
			owner[p] = s.slot_id
			if p.begins_with("fitting:") or p.begins_with("component:"):
				units.append(s)
	for path: String in importer.parts_by_path:
		var look := importer.kit.model.part_visual((importer.parts_by_path[path] as PartData).id)
		if look == null:
			continue
		var meshes: Array = [look] if look is MeshInstance3D else []
		meshes.append_array(look.find_children("*", "MeshInstance3D", true, false))
		for mi: Node in meshes:
			taken[mi] = true
		meshes = meshes.filter(func(mi: Node) -> bool: return (mi as Node3D).visible)
		var id: String = owner.get(path, "")
		if out.has(id):
			(out[id] as Array).append_array(meshes)
	if units.is_empty():
		return out
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if taken.has(mi) or mi.mesh == null or not mi.visible:
			continue
		var centre := _local_xform(mi) * mi.mesh.get_aabb().get_center()
		for s in units:
			if s.box.has_point(centre):
				(out[s.slot_id] as Array).append(mi)
				break
	return out


## The lowest point of the ship's surface over each of `points` (ship x, z), one each, INF
## where nothing is over one: where its belly meets the cradle's saddles. `skip_legs` leaves
## out the landing legs (they stand down between the cradle's beams).
func belly_under(points: Array[Vector2], skip_legs := false) -> PackedFloat64Array:
	var low := PackedFloat64Array()
	low.resize(points.size())
	low.fill(INF)
	if points.is_empty():
		return low
	var reach := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		reach = reach.expand(p)
	var legs := _leg_meshes() if skip_legs else {}
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible or legs.has(mi):
			continue
		var xf := _local_xform(mi)
		var box := xf * mi.mesh.get_aabb()
		if not Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(0.01).intersects(reach, true):
			continue
		var near: Array[int] = []
		for k in points.size():
			var p := points[k]
			if p.x >= box.position.x - 0.01 and p.x <= box.end.x + 0.01 and p.y >= box.position.z - 0.01 \
					and p.y <= box.end.z + 0.01 and box.position.y < low[k]:
				near.append(k)
		if near.is_empty():
			continue
		var faces := mi.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var a := xf * faces[i]
			var b := xf * faces[i + 1]
			var c := xf * faces[i + 2]
			for k: int in near:
				var y := _y_at(a, b, c, points[k])
				if y < low[k]:
					low[k] = y
	return low


## The lowest point of the ship's surface over `area` (ship x, z), INF when none is: read off
## the meshes at points STEP metres apart over it (part boxes are loose round slanted plates),
## the landing legs left out.
func lowest_in(area: Rect2) -> float:
	var points: Array[Vector2] = []
	var nx := maxi(int(ceilf(area.size.x / STEP)), 1)
	var nz := maxi(int(ceilf(area.size.y / STEP)), 1)
	for i in nx + 1:
		for j in nz + 1:
			points.append(area.position + Vector2(area.size.x * i / nx, area.size.y * j / nz))
	var low := INF
	for y: float in belly_under(points, true):
		low = minf(low, y)
	return low


## The landing legs' meshes (set of MeshInstance3D).
func _leg_meshes() -> Dictionary:
	var out := {}
	for path: String in importer.parts_by_path:
		if not path.begins_with(LEG):
			continue
		var look := importer.kit.model.part_visual((importer.parts_by_path[path] as PartData).id)
		if look == null:
			continue
		if look is MeshInstance3D:
			out[look] = true
		for mi: Node in look.find_children("*", "MeshInstance3D", true, false):
			out[mi] = true
	return out


## The height of triangle abc over the point (x, z), INF when the point isn't under it.
static func _y_at(a: Vector3, b: Vector3, c: Vector3, p: Vector2) -> float:
	var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(d) < 1e-9:
		return INF
	var u := ((b.z - c.z) * (p.x - c.x) + (c.x - b.x) * (p.y - c.z)) / d
	var v := ((c.z - a.z) * (p.x - c.x) + (a.x - c.x) * (p.y - c.z)) / d
	var w := 1.0 - u - v
	if u < -1e-4 or v < -1e-4 or w < -1e-4:
		return INF
	return u * a.y + v * b.y + w * c.y


func _local_xform(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## The shore power socket the bay's ground power unit plugs into: a recessed box with a
## round plug face and a lamp, on the starboard flank.
func _build_power_socket() -> void:
	var at := power_socket
	var dark := ShipSurface.of(ShipParts.mat("dark"))
	var hazard := ShipSurface.of(ShipKit.paint(Color(0.95, 0.55, 0.1), 0.2, 0.55))
	_look(PartShapes.chamfer_box(Vector3(0.08, 0.32, 0.3), 0.015), Transform3D(Basis(), at), dark)
	_look(PartShapes.prism(12, 0.07, 0.05), Transform3D(Basis(Vector3.BACK, -PI * 0.5), at + Vector3(0.05, -0.02, 0)), hazard)
	var lamp := _look(PartShapes.box(Vector3(0.01, 0.03, 0.12)), Transform3D(Basis(), at + Vector3(0.045, 0.12, 0)), null)
	lamp.material_override = ShipKit.glow(Color(0.35, 1.0, 0.5), 2.0)


func _look(shape: PartShapes.PartShape, xform: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "ShorePower"
	mi.mesh = shape.mesh
	mi.transform = xform
	mi.material_override = mat
	add_child(mi)
	return mi


static func _box(d: Dictionary) -> AABB:
	var p: Array = d.get("pos", [0, 0, 0])
	var s: Array = d.get("size", [0, 0, 0])
	return AABB(Vector3(p[0], p[1], p[2]), Vector3(s[0], s[1], s[2]))
