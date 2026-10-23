extends RigidBody3D
## The Kestrel as Void Salvage exported it (kestrel.vsship.json, vsship 2.0), built by Shared
## Components' VsShipImport: every part and joint with the path the file gives it, so a work
## order's paths find them. BSX adds one thing a flying ship doesn't have: the shore power
## socket the bay's ground power unit plugs into.
##
## Frozen: it stands on the bay's cradles. The screens and panels are dressing here (no
## ship systems in the yard). Built in _init, so a bare instantiate() has every piece.
##
## Ship space: -Z forward, +Y up, the deck floor at y = 0.

const FILE := "res://modules/ship_bay/internal/ships/kestrel/kestrel.vsship.json"
const LayoutLoader := preload("res://modules/ship_bay/internal/layout_loader.gd")
## Where the bay's stairs meet the port side door (its sill, on the hull's side), and the
## shore power socket low on the starboard flank, aft of the fuel port. Ship space, metres.
const SIDE_DOOR_SILL := Vector3(-2.7, 0.0, 2.25)
const POWER_SOCKET := Vector3(2.76, 0.72, 6.05)

## Seconds the power-up sweep takes from bow to stern.
@export var power_up_time := 1.4

var importer: VsShipImport
var powered := true
var _lit: Array[MeshInstance3D] = []
var _lamps: Array[Light3D] = []
var _texts: Array[Label3D] = []
var _dark_mats: Dictionary = {}
var _power_tween: Tween
var _hum: AudioStreamPlayer3D


func _init() -> void:
	name = "Kestrel"
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	importer = VsShipImport.new()
	if not importer.build(LayoutLoader.read_file(FILE), self):
		push_error("Kestrel: the ship file didn't build: %s" % "; ".join(importer.errors))
	_drop_doubled_looks()
	_open_doors()
	_build_power_socket()
	for n: Node in find_children("*", "", true, false):
		if n is Light3D:
			_lamps.append(n)
		elif n is Label3D:
			_texts.append(n)
		elif n is MeshInstance3D:
			var m := (n as MeshInstance3D).material_override as StandardMaterial3D
			if m and m.emission_enabled:
				_lit.append(n)
	set_powered(false)


## A unit's part (an engine, a door leaf) also arrives as loose look pieces drawing the same
## faces in the same place, which flicker against each other: the part's plain visual hides
## wherever a loose piece covers the same box (its collision and joints stay). Then the loose
## pieces are inset as Void Salvage draws them.
func _drop_doubled_looks() -> void:
	var model := importer.kit.model
	var looks: Array[AABB] = []
	var parts := {}
	for path: String in importer.parts_by_path:
		var look := model.part_visual((importer.parts_by_path[path] as PartData).id)
		if look:
			parts[look] = true
	for c: Node in get_children():
		if c is MeshInstance3D and not parts.has(c) and (c as MeshInstance3D).mesh:
			looks.append((c as MeshInstance3D).transform * (c as MeshInstance3D).mesh.get_aabb())
	# Loose pieces get the small visual inset Void Salvage's ShipKit.add gives every piece, so
	# touching pieces never share a face.
	for c: Node in get_children():
		var piece := c as MeshInstance3D
		if piece and not parts.has(piece) and piece.mesh:
			piece.transform = piece.transform * importer.kit._inset(piece.mesh.get_aabb(), piece.transform)
	for look: Node in parts:
		var mi := look as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		var box := mi.transform * mi.mesh.get_aabb()
		for b: AABB in looks:
			if b.get_center().distance_to(box.get_center()) < 0.01 and (b.size - box.size).length() < 0.02:
				mi.visible = false
				break


## The sliding doors stand open (the file's `layout.doors` moves: the side door, the
## bulkhead's pocket door), so crews walk in from the lift and through to the cabin. The
## hinged stern door and belly hatch stay shut.
func _open_doors() -> void:
	var model := importer.kit.model
	for door: Dictionary in importer.file.get("layout", {}).get("doors", {}).values():
		var moves: Dictionary = door.get("moves", {})
		for tag: String in moves:
			var by := VsShipImport.vec3(moves[tag])
			for piece: Dictionary in importer.kit.tagged.get(tag, []):
				if piece.has("part"):
					var part: PartData = model.parts.get(int(piece["part"]))
					if part:
						model.move_part(part.id, Transform3D(part.local_transform.basis, part.local_transform.origin + by))
				elif piece.get("mesh") is Node3D:
					(piece["mesh"] as Node3D).position += by


## Where the bay's stairs and power cable meet the ship (ship space).
func access_points() -> Dictionary:
	return {"side_door": SIDE_DOOR_SILL, "power_socket": POWER_SOCKET}


## Slot id -> the model's meshes that are the slot's part: the visuals of the file's parts
## under "slot:<id>/", and the loose looks (a fitting with no part, a unit's trim) whose
## centre is in the slot's box. Other parts never count, however close.
func slot_pieces(def: ShipDefinition) -> Dictionary:
	var out := {}
	var taken := {}
	var owner := {}
	for s in def.slots:
		out[s.slot_id] = []
		for p: String in s.parts:
			owner[p] = s.slot_id
	for path: String in importer.parts_by_path:
		var look := importer.kit.model.part_visual((importer.parts_by_path[path] as PartData).id)
		if look == null:
			continue
		var meshes: Array = [look] if look is MeshInstance3D else []
		meshes.append_array(look.find_children("*", "MeshInstance3D", true, false))
		for mi: Node in meshes:
			taken[mi] = true
		var id: String = owner.get(path, path.trim_prefix("slot:").get_slice("/", 0) if path.begins_with("slot:") else "")
		if out.has(id):
			(out[id] as Array).append_array(meshes)
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if taken.has(mi) or mi.mesh == null:
			continue
		var centre := _local_xform(mi) * mi.mesh.get_aabb().get_center()
		for s in def.slots:
			if s.box.has_point(centre):
				(out[s.slot_id] as Array).append(mi)
				break
	return out


func _local_xform(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## Lamps, screens, lit edges and text on or off. Off they read as dark glass and paint. On,
## the ship powers up: everything lit comes on bow to stern over `power_up_time` seconds with
## a flicker, and a quiet hum starts (`instant` skips the show: loading, screenshots).
func set_powered(on: bool, instant := false) -> void:
	powered = on
	if _power_tween:
		_power_tween.kill()
		_power_tween = null
	_power_hum(on)
	if not on or instant or not is_inside_tree():
		for n: Node3D in _lamps + _texts + _lit:
			_light(n, on)
		return
	# Off first, then on in a sweep along the ship.
	var all: Array[Node3D] = []
	for n: Node3D in _lamps + _texts + _lit:
		_light(n, false)
		all.append(n)
	if all.is_empty():
		return
	var zs := all.map(func(n: Node3D) -> float: return to_local(n.global_position).z)
	var z0: float = zs.min()
	var span: float = maxf(float(zs.max()) - z0, 0.01)
	var order := range(all.size())
	order.sort_custom(func(a: int, b: int) -> bool: return zs[a] < zs[b])
	_power_tween = create_tween()
	var t := 0.0
	for i: int in order:
		var at := 0.12 + power_up_time * (float(zs[i]) - z0) / span
		if at > t:
			_power_tween.tween_interval(at - t)
			t = at
		var n := all[i]
		_power_tween.tween_callback(_light.bind(n, true))
	# A flicker of the whole ship as the bus settles, then on for good.
	_power_tween.tween_interval(0.12)
	_power_tween.tween_callback(func() -> void:
		for n: Node3D in all:
			_light(n, false))
	_power_tween.tween_interval(0.07)
	_power_tween.tween_callback(func() -> void:
		for n: Node3D in all:
			_light(n, true))


func _light(n: Node3D, on: bool) -> void:
	if n is Light3D or n is Label3D:
		n.visible = on
		return
	var mi := n as MeshInstance3D
	if on:
		mi.material_override = mi.get_meta("lit_mat", mi.material_override)
		return
	var lit := mi.material_override as StandardMaterial3D
	if not mi.has_meta("lit_mat"):
		mi.set_meta("lit_mat", lit)
	lit = mi.get_meta("lit_mat")
	if not _dark_mats.has(lit):
		var d := ShipKit.paint(lit.emission.darkened(0.82), 0.3, 0.35)
		_dark_mats[lit] = ShipSurface.of(d)
	mi.material_override = _dark_mats[lit]


## The quiet hum of a powered ship, from amidships.
func _power_hum(on: bool) -> void:
	if on and _hum == null and is_inside_tree():
		_hum = Sfx.loop("hover_drive", self, -27.0)
		_hum.name = "PowerHum"
		_hum.pitch_scale = 0.42
		_hum.position = Vector3(0, 1.2, 1.0)
		_hum.unit_size = 4.0
		_hum.max_distance = 25.0
	elif not on and _hum:
		_hum.queue_free()
		_hum = null


## The shore power socket: a recessed box with a round plug face, four bolts and a lamp that
## shows when the ship has power.
func _build_power_socket() -> void:
	var at := POWER_SOCKET
	var dark := ShipParts.mat("dark")
	var hazard := ShipKit.paint(Color(0.95, 0.55, 0.1), 0.2, 0.55)
	var steel := ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.35)
	_look(PartShapes.chamfer_box(Vector3(0.08, 0.32, 0.3), 0.015), Transform3D(Basis(), at), dark)
	_look(PartShapes.prism(12, 0.07, 0.05), Transform3D(Basis(Vector3.BACK, -PI * 0.5), at + Vector3(0.05, -0.02, 0)), hazard)
	var lamp := _look(PartShapes.box(Vector3(0.01, 0.03, 0.12)), Transform3D(Basis(), at + Vector3(0.045, 0.12, 0)), null)
	lamp.material_override = ShipKit.glow(Color(0.35, 1.0, 0.5), 2.0)
	var label := Label3D.new()
	label.text = "SHORE PWR"
	label.font = ShipKit.mono_font()
	label.font_size = 14
	label.pixel_size = 0.0015
	label.modulate = Color(1.0, 0.8, 0.4)
	label.outline_size = 0
	label.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), at + Vector3(0.046, -0.13, 0))
	add_child(label)
	var hex := PartShapes.prism(6, 0.017, 0.014)
	for c: Vector2 in [Vector2(-0.12, -0.13), Vector2(0.12, -0.13), Vector2(-0.12, 0.13), Vector2(0.12, 0.13)]:
		_look(hex, Transform3D(Basis(Vector3.BACK, -PI * 0.5), at + Vector3(0.047, c.y, c.x)), steel)


func _look(shape: PartShapes.PartShape, xform: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.transform = xform
	if mat:
		mi.material_override = ShipSurface.of(mat)
	add_child(mi)
	return mi
