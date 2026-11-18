extends Node3D
## The stores hall's racks and what is on them (0.4.0 playtest: racking "5x larger", holding
## "significant part sizes" seen "as their actual parts and not crates and boxes"). Draws a
## YardRackStore: cantilever racks for long stock, deep pallet racking for plates, pallet
## racking for components and floor cradles under a gantry for engines and tanks, every part
## drawn as Void Salvage's own part (YardStockLook), one MultiMesh per part.
##
## No counters: bots (and you) take parts from the racks themselves. The racks run along z
## with their aisles open at the yard side (the hall's open face, -Z) and at goods in (east).

const Look := preload("res://modules/yard/internal/yard_stock_look.gd")

const RACK_BLUE := Color(0.2, 0.32, 0.55)
const BEAM_ORANGE := Color(1.0, 0.5, 0.12)

var store: YardRackStore
## part id -> {body: MultiMeshInstance3D, glow: MultiMeshInstance3D or null}.
var part_meshes: Dictionary = {}
## Per slot: its label on the rack's aisle face.
var labels: Array[Label3D] = []
## Per rack: its solid (you walk round a rack, not through it).
var rack_solids: Array[CollisionShape3D] = []
var _kit
var _dirty := false
var _uprights: Array[Transform3D] = []
var _beams: Array[Transform3D] = []
var _decks: Array[Transform3D] = []
var _feet: Array[Transform3D] = []


func build(kit, rack_store: YardRackStore) -> void:
	_kit = kit
	store = rack_store
	for r in YardRackStore.RACKS.size():
		_build_rack(r)
	_multi(_uprights, kit.paint(RACK_BLUE, 0.3, 0.4, "enamel"), "Uprights")
	_multi(_beams, kit.paint(BEAM_ORANGE, 0.2, 0.45, "enamel"), "Beams")
	_multi(_decks, kit.paint(Color(0.5, 0.52, 0.55), 0.7, 0.45, "galvanised"), "Decks")
	_multi(_feet, kit.paint(Color(0.16, 0.17, 0.19), 0.6, 0.5, "gunmetal"), "Feet")
	_build_gantry()
	_build_labels()
	redraw()
	store.changed.connect(func(_i: int) -> void: _dirty = true)


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		redraw()


## Draws every part on every rack again, and the racks' labels.
func redraw() -> void:
	var by_part: Dictionary = {}
	for i in store.slots.size():
		var part: String = store.slots[i].part
		if part == "":
			continue
		if not by_part.has(part):
			by_part[part] = []
		(by_part[part] as Array).append_array(item_transforms(i))
	for part: String in YardRackStore.PARTS:
		var xforms: Array = by_part.get(part, [])
		if xforms.is_empty() and not part_meshes.has(part):
			continue
		var m := _part_mesh(part)
		for key: String in ["body", "glow"]:
			var mmi: MultiMeshInstance3D = m[key]
			if mmi == null:
				continue
			mmi.multimesh.instance_count = xforms.size()
			for j in xforms.size():
				mmi.multimesh.set_instance_transform(j, xforms[j])
			mmi.visible = not xforms.is_empty()
	for i in labels.size():
		var s := store.slots[i]
		labels[i].text = "%s  x%d" % [YardRackStore.PARTS[s.part].name, int(s.qty)] if s.part != "" else "-"


## How many parts are drawn (for tests): every instance of every part.
func drawn_count() -> int:
	var n := 0
	for part: String in part_meshes:
		n += (part_meshes[part].body as MultiMeshInstance3D).multimesh.instance_count
	return n


## Where each part in a place is drawn (station space): laid side by side on long stock's
## arms, stacked on a plate deck, set out on a component deck, one or two to a cradle.
func item_transforms(i: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var s := store.slots[i]
	if s.part == "":
		return out
	var rack: Dictionary = YardRackStore.RACKS[int(s.rack)]
	var look := Look.look(s.part)
	var ls: Vector3 = look.size
	var rest: Transform3D = look.rest
	var p := store.slot_position(i)
	var room := store.slot_size(i)
	var side := float(s.side)
	var inner := float(rack.x) + side * _inner_gap(int(rack.kind))
	var width := float(rack.depth) - _inner_gap(int(rack.kind)) - (0.12 if int(rack.kind) == YardRackStore.LONG else 0.05)
	var qty := int(s.qty)
	match int(rack.kind):
		YardRackStore.LONG:
			var pitch := ls.x + 0.04
			var per_row := maxi(1, int(width / pitch))
			for k in qty:
				var row := k % per_row
				var layer := k / per_row
				var at := Vector3(inner + side * (ls.x * 0.5 + row * pitch), p.y + layer * (ls.y + 0.005), p.z)
				out.append(Transform3D(Basis(), at) * rest)
		YardRackStore.PLATE:
			var layers := maxi(1, int((room.y - 0.1) / (ls.y + 0.004)))
			for k in mini(qty, layers):
				var at := Vector3(inner + side * width * 0.5, p.y + k * (ls.y + 0.004), p.z)
				out.append(Transform3D(Basis(), at) * rest)
		YardRackStore.COMPONENT:
			var nx := maxi(1, int(width / (ls.x + 0.08)))
			var nz := maxi(1, int((room.z - 0.2) / (ls.z + 0.12)))
			var layers := maxi(1, int((room.y - 0.05) / (ls.y + 0.01)))
			var per_layer := nx * nz
			for k in mini(qty, per_layer * layers):
				var layer := k / per_layer
				var ix := (k % per_layer) % nx
				var iz := (k % per_layer) / nx
				var x := inner + side * width * (float(ix) + 0.5) / float(nx)
				var z := p.z + room.z * ((float(iz) + 0.5) / float(nz) - 0.5) * 0.92
				out.append(Transform3D(Basis(), Vector3(x, p.y + layer * (ls.y + 0.01), z)) * rest)
		YardRackStore.HEAVY:
			for k in qty:
				var z := p.z if qty == 1 else p.z + (float(k) - 0.5) * (ls.z + 0.3)
				out.append(Transform3D(Basis(), Vector3(inner + side * width * 0.5, p.y, z)) * rest)
	return out


## Where a place may hold its parts (station space), for checks: from the rack's spine out to
## its front, its floor to its clear height, its length along the rack.
func slot_box(i: int) -> AABB:
	var s := store.slots[i]
	var rack: Dictionary = YardRackStore.RACKS[int(s.rack)]
	var p := store.slot_position(i)
	var room := store.slot_size(i)
	var x0 := float(rack.x)
	var x1 := float(rack.x) + float(s.side) * float(rack.depth)
	return AABB(Vector3(minf(x0, x1), p.y, p.z - room.z * 0.5), Vector3(absf(x1 - x0), room.y, room.z))


func _inner_gap(kind: int) -> float:
	return 0.3 if kind == YardRackStore.LONG else 0.12


func _part_mesh(part: String) -> Dictionary:
	if part_meshes.has(part):
		return part_meshes[part]
	var look := Look.look(part)
	var m := {"body": _part_multi(look.mesh, Look.material(), "Stock_%s" % part), "glow": null}
	if look.glow != null:
		m.glow = _part_multi(look.glow, Look.glow_material(look.glow_colour), "Stock_%s_glow" % part)
	part_meshes[part] = m
	return m


func _part_multi(mesh: Mesh, mat: Material, node_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi


# --- Racks ---------------------------------------------------------------------------------

func _build_rack(r: int) -> void:
	var rack: Dictionary = YardRackStore.RACKS[r]
	var kind := int(rack.kind)
	var x := float(rack.x)
	var depth := float(rack.depth)
	var bay := float(rack.bay)
	var bays := YardRackStore.bays_of(r)
	var z0 := float(rack.z0)
	var length := bay * bays
	var z_mid := z0 + length * 0.5
	var levels := int(rack.levels)
	var top := float(rack.first) + float(rack.pitch) * levels + 0.2
	match kind:
		YardRackStore.LONG:
			top = float(rack.first) + float(rack.pitch) * (levels - 1) + 1.0
			for b in bays:
				var zc := z0 + bay * (b + 0.5)
				for dz: float in [-2.4, 2.4]:
					var z := zc + dz
					_uprights.append(_xf(Vector3(0.3, top, 0.36), Vector3(x, top * 0.5, z)))
					for side: float in rack.sides:
						# The foot along the floor, the arms out from the column (sloping up a
						# touch at their stop), one per level.
						_feet.append(_xf(Vector3(depth + 0.2, 0.25, 0.3), Vector3(x + side * (depth + 0.2) * 0.5, 0.125, z)))
						for level in levels:
							var y := float(rack.first) + float(rack.pitch) * level
							_beams.append(_xf(Vector3(depth - 0.15, 0.12, 0.16), Vector3(x + side * (0.15 + (depth - 0.15) * 0.5), y - 0.06, z)))
							_beams.append(_xf(Vector3(0.06, 0.1, 0.16), Vector3(x + side * (depth - 0.03), y + 0.05, z)))
			# Ties along the rack, between the columns.
			for y: float in [top * 0.45, top - 0.2]:
				_uprights.append(_xf(Vector3(0.12, 0.16, length - 0.4), Vector3(x, y, z_mid)))
		YardRackStore.PLATE, YardRackStore.COMPONENT:
			for side: float in rack.sides:
				var x_in := x + side * 0.08
				var x_out := x + side * depth
				for b in bays + 1:
					var z := z0 + bay * b
					for xp: float in [x_in, x_out]:
						_uprights.append(_xf(Vector3(0.09, top, 0.09), Vector3(xp, top * 0.5, z)))
					var y := 0.6
					while y < top - 0.3:
						_uprights.append(_xf(Vector3(depth - 0.17, 0.05, 0.05), Vector3((x_in + x_out) * 0.5, y, z)))
						y += 1.6
				for level in levels + 1:
					var y := float(rack.first) + float(rack.pitch) * level
					for xp: float in [x_in, x_out]:
						_beams.append(_xf(Vector3(0.05, 0.12, length - 0.1), Vector3(xp, y - 0.06, z_mid)))
					if level < levels:
						for b in bays:
							_decks.append(_xf(Vector3(depth - 0.08 - 0.1, 0.03, bay - 0.14), Vector3((x_in + x_out) * 0.5, y - 0.015, z0 + bay * (b + 0.5))))
		YardRackStore.HEAVY:
			top = 3.6
			for side: float in rack.sides:
				for b in bays:
					var zc := z0 + bay * (b + 0.5)
					var xc := x + side * (0.12 + (depth - 0.17) * 0.5)
					# A cradle: two rails along the bay on cross members, its top at `first`.
					for dx: float in [-0.75, 0.75]:
						_feet.append(_xf(Vector3(0.22, float(rack.first) - 0.12, bay - 0.8), Vector3(xc + dx, (float(rack.first) - 0.12) * 0.5, zc)))
						_beams.append(_xf(Vector3(0.22, 0.12, bay - 0.8), Vector3(xc + dx, float(rack.first) - 0.06, zc)))
					for dz: float in [-(bay - 1.2) * 0.5, (bay - 1.2) * 0.5]:
						_feet.append(_xf(Vector3(1.28, 0.14, 0.2), Vector3(xc, 0.07, zc + dz)))
	# You walk round a rack: one solid over its footprint.
	var lo := Vector3(x - depth - (0.25 if kind == YardRackStore.LONG else 0.05), 0.0, z0 - 0.05)
	var hi := Vector3(x + depth + (0.25 if kind == YardRackStore.LONG else 0.05), top, z0 + length + 0.05)
	var cs := CollisionShape3D.new()
	cs.name = "Rack_%s" % rack.id
	var shape := BoxShape3D.new()
	shape.size = hi - lo
	cs.shape = shape
	cs.position = (lo + hi) * 0.5
	_kit.body.add_child(cs)
	rack_solids.append(cs)
	# Its name at the yard end, up high.
	var title := "%s  %s" % [rack.id, ["LONG STOCK", "PLATE", "COMPONENTS", "HEAVY"][kind]]
	_kit.sign(title, Vector3(x, minf(top, 7.0) + 0.6, z0 - 0.4), Vector3.FORWARD, 0.01, BEAM_ORANGE, 64)


## The gantry crane over the heavy cradles: rails on columns either side, a bridge and hoist.
func _build_gantry() -> void:
	var k = _kit
	for r in YardRackStore.RACKS.size():
		var rack: Dictionary = YardRackStore.RACKS[r]
		if int(rack.kind) != YardRackStore.HEAVY:
			continue
		var yellow: Material = k.paint(Color(1.0, 0.78, 0.1), 0.2, 0.5, "enamel")
		var dark: Material = k.paint(Color(0.16, 0.17, 0.19), 0.6, 0.5, "gunmetal")
		var x := float(rack.x)
		var reach := float(rack.depth) + 0.9
		var z0 := float(rack.z0)
		var length := float(rack.bay) * YardRackStore.bays_of(r)
		var rail_y := 9.0
		for side: float in [-1.0, 1.0]:
			var xr := x + side * reach
			k.box(Vector3(0.5, 0.6, length + 1.0), Vector3(xr, rail_y + 0.3, z0 + length * 0.5), yellow, false)
			var z := z0 - 0.3
			while z <= z0 + length + 0.5:
				k.box(Vector3(0.42, rail_y, 0.42), Vector3(xr, rail_y * 0.5, z), yellow)
				z += float(rack.bay) * 2.0
		var bz := z0 + float(rack.bay) * 4.0   # between two cradles' bots
		k.box(Vector3(reach * 2.0 + 0.8, 0.7, 0.9), Vector3(x, rail_y + 0.95, bz), yellow, false)
		k.box(Vector3(1.0, 0.8, 1.2), Vector3(x + 0.8, rail_y + 0.2, bz), dark, false)
		k.box(Vector3(0.04, 3.4, 0.04), Vector3(x + 0.8, rail_y - 1.9, bz), dark, false)
		k.box(Vector3(0.5, 0.3, 0.3), Vector3(x + 0.8, rail_y - 3.75, bz), yellow, false)


func _build_labels() -> void:
	for i in store.slots.size():
		var s := store.slots[i]
		var rack: Dictionary = YardRackStore.RACKS[int(s.rack)]
		var side := float(s.side)
		var p := store.slot_position(i)
		var l := Label3D.new()
		l.pixel_size = 0.0025
		l.font_size = 28
		l.outline_size = 6
		l.modulate = Color(1, 1, 1, 0.95)
		var y := p.y - 0.07 if int(rack.kind) != YardRackStore.LONG else p.y - 0.2
		if int(rack.kind) == YardRackStore.HEAVY:
			y = float(rack.first) + 0.02
		l.position = Vector3(float(rack.x) + side * (float(rack.depth) + 0.04), maxf(y, 0.06), p.z)
		l.rotation.y = PI * 0.5 * side
		add_child(l)
		labels.append(l)


func _xf(size: Vector3, centre: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), centre)


func _multi(xforms: Array[Transform3D], mat: Material, node_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	mm.mesh = cube
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi
