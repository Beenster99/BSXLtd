extends RefCounted
## What each part the stores keep looks like: Void Salvage's own parts (VsParts: its builders,
## mostly the components modelled in Blender, on its salvage surface), the same parts a Void
## Salvage crew strips from a wreck and the yard fits, so the racks hold beams, plates,
## cabinets and engines, never crates. Each comes laid as it
## rests on a rack: its long side along z, a plate flat, its bottom on y = 0, its middle over
## the origin. Built once, cached.

## part id -> {mesh, glow (or null), glow_colour, layers ([{mesh, material}]: body, glass,
## lit details), rest (Transform3D), size (as it rests, m)}.
static var _looks: Dictionary = {}
static var _mats: Dictionary = {}


static func look(part: String) -> Dictionary:
	if not _looks.has(part):
		_looks[part] = _make(part)
	return _looks[part]


static func shape_of(part: String) -> PartShapes.PartShape:
	var shape := VsParts.shape(part)
	return shape if shape != null else PartShapes.box(Vector3.ONE * 0.5)


## The part's body material: Void Salvage's salvage surface (its paint, finish zones and
## detail maps, VsParts.surface); a plain one for a part it doesn't know.
static func material(part := "") -> Material:
	if VsParts.has(part):
		return VsParts.surface(part)
	if not _mats.has("body"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.45
		m.roughness = 0.5
		_mats["body"] = m
	return _mats["body"]


static func glow_material(c: Color) -> StandardMaterial3D:
	return VsParts.glow_material(c)


## Every mesh the part draws with its material, as Void Salvage draws it: the body on its
## surface, its glass, its lit details (screens, lamps, a thruster's glow) each in its colour.
static func layers(part: String) -> Array:
	return look(part).layers


static func _make(part: String) -> Dictionary:
	var shape := shape_of(part)
	var box := shape.mesh.get_aabb()
	var kind := YardRackStore.kind_of(part)
	var s := box.size
	var basis := Basis()
	# Lay it as it rests: long stock and plates with their longest side along z, a plate's
	# thinnest side up; anything else stands as built, its longer side along z.
	if kind == YardRackStore.LONG or kind == YardRackStore.PLATE:
		var axes := [0, 1, 2]
		axes.sort_custom(func(a: int, b: int) -> bool: return s[a] < s[b])
		var up: int = axes[0] if kind == YardRackStore.PLATE else axes[1]
		var along: int = axes[2]
		var across: int = 3 - up - along
		basis = Basis(_axis(across), _axis(up), _axis(along)).transposed()
		if basis.determinant() < 0.0:   # a turn, never a mirror (it would draw inside out)
			basis = Basis(-_axis(across), _axis(up), _axis(along)).transposed()
	elif s.x > s.z * 1.05:
		basis = Basis(Vector3.UP, PI * 0.5)
	var laid := Transform3D(basis, Vector3.ZERO) * box
	var rest := Transform3D(basis, Vector3(-laid.get_center().x, -laid.position.y, -laid.get_center().z))
	var drawn: Array = [{"mesh": shape.mesh, "material": material(part)}]
	if shape.glass != null:
		drawn.append({"mesh": shape.glass, "material": Glazing.material(shape.glass_kind)})
	if not shape.emissives.is_empty():
		for e: Dictionary in shape.emissives:
			drawn.append({"mesh": e["mesh"], "material": glow_material(e.get("color", shape.glow_color)), "lit": true})
	elif shape.glow != null:
		drawn.append({"mesh": shape.glow, "material": glow_material(shape.glow_color), "lit": true})
	return {
		"layers": drawn,
		"mesh": shape.mesh,
		"glow": shape.glow,
		"glow_colour": shape.glow_color,
		"rest": rest,
		"size": laid.size,
	}


static func _axis(i: int) -> Vector3:
	return [Vector3.RIGHT, Vector3.UP, Vector3.BACK][i]
