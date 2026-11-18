extends RefCounted
## What each part the stores keep looks like: Void Salvage's own part shapes (WreckParts,
## FrameParts, PartShapes in shared/void_salvage), the same parts the ships are built from, so
## the racks hold beams, plates, cabinets and engines, never crates. Each comes laid as it
## rests on a rack: its long side along z, a plate flat, its bottom on y = 0, its middle over
## the origin. Built once, cached.

## part id -> {mesh, glow (or null), glow_colour, rest (Transform3D), size (as it rests, m)}.
static var _looks: Dictionary = {}
static var _mats: Dictionary = {}


static func look(part: String) -> Dictionary:
	if not _looks.has(part):
		_looks[part] = _make(part)
	return _looks[part]


static func shape_of(part: String) -> PartShapes.PartShape:
	match part:
		"box_beam_6": return PartShapes.girder(6.0, 0.2, 0.24)
		"girder_4": return PartShapes.i_beam(4.0, 0.16, 0.2)
		"pipe_4": return WreckParts.pipe(0.08, 4.0)
		"pipe_big_5": return WreckParts.pipe(0.16, 5.0)
		"hull_plate": return FrameParts.rect(1.5, 2.5)
		"deck_plate": return PartShapes.inset_panel(1.2, 2.4, 0.04, 0.1)
		"armour_slab": return WreckParts.armour_slab(2.0, 2.8)
		"radiator": return WreckParts.radiator_grille(2.8, 1.2)
		"junction_box": return WreckParts.junction_box()
		"valve": return WreckParts.valve_body()
		"switch_cabinet": return WreckParts.switch_cabinet()
		"battery_rack": return WreckParts.battery_rack()
		"heat_sink": return WreckParts.heat_sink()
		"gyroscope": return WreckParts.gyroscope()
		"capacitor_bank": return WreckParts.capacitor_bank(1.6, 1.4, 0.7)
		"generator": return WreckParts.generator(Vector3(1.4, 1.2, 0.9))
		"engine_bell": return WreckParts.engine_bell(0.9, 1.8)
		"hydrogen_engine": return WreckParts.hydrogen_engine(1.2, 2.0)
		"turbine_engine": return WreckParts.turbine_engine(1.0, 1.6)
		"thruster_pod": return WreckParts.thruster_pod(1.2, 1.0, 1.6)
		"tank_large": return WreckParts.tank(0.6, 2.8)
		"reactor": return WreckParts.reactor(1.0, 2.0)
	return PartShapes.box(Vector3.ONE * 0.5)


## The part's body material (its vertex colours, a little metal) and its lit faces'.
static func material() -> StandardMaterial3D:
	if not _mats.has("body"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.45
		m.roughness = 0.5
		_mats["body"] = m
	return _mats["body"]


static func glow_material(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	return _mats[key]


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
	return {
		"mesh": shape.mesh,
		"glow": shape.glow,
		"glow_colour": shape.glow_color,
		"rest": rest,
		"size": laid.size,
	}


static func _axis(i: int) -> Vector3:
	return [Vector3.RIGHT, Vector3.UP, Vector3.BACK][i]
