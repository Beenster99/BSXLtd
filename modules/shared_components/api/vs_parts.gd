class_name VsParts
extends RefCounted
## Void Salvage's components as BSX stocks, lifts and fits them: the same parts a Void Salvage
## crew strips from a wreck, built by Void Salvage's own code in res://shared/void_salvage/
## (WreckParts: most of them are the components modelled in Blender, `PartAsset`), drawn on
## Void Salvage's own salvage surface (PBR paint, the detail maps and the finish zones inside a
## part: chrome trim, rubber, copper, glazed ceramic), so a battery rack on a stores rack, on
## the crane hook and fitted into a design is the one in Void Salvage, never a box.
##
## Ids are Void Salvage `part_name`s ("Reactor", "BatteryRack"), the part's id in both games.
## Read-only, the same on every machine; looks are built once and cached. Presentation and data
## only: nothing here touches the network.

## id -> {name, category (a Void Salvage PartCatalog category), material (a Materials id)}.
## The names and categories are Void Salvage's PartCatalog's.
const ENTRIES: Dictionary = {
	# Power
	"Reactor": {"name": "Reactor", "category": "electronics", "material": "steel"},
	"ReactorCore": {"name": "Reactor core", "category": "electronics", "material": "steel"},
	"Generator": {"name": "Generator", "category": "electronics", "material": "steel"},
	"BatteryRack": {"name": "Battery rack", "category": "electronics", "material": "steel"},
	"CapacitorBank": {"name": "Capacitor bank", "category": "electronics", "material": "copper"},
	"SolarPanel": {"name": "Solar panel", "category": "electronics", "material": "alloy"},
	"Radiator": {"name": "Radiator", "category": "electronics", "material": "alloy"},
	"HeatSink": {"name": "Heat sink", "category": "electronics", "material": "copper"},
	"SwitchCabinet": {"name": "Switch cabinet", "category": "electronics", "material": "steel"},
	"JunctionBox": {"name": "Junction box", "category": "wiring", "material": "steel"},
	# Control
	"Gyroscope": {"name": "Gyroscope", "category": "electronics", "material": "steel"},
	"PilotConsole": {"name": "Pilot console", "category": "electronics", "material": "alloy"},
	"SideConsole": {"name": "Side console", "category": "electronics", "material": "alloy"},
	"Antenna": {"name": "Antenna", "category": "electronics", "material": "alloy"},
	# Engines
	"MainThruster": {"name": "Main thruster", "category": "engines", "material": "steel"},
	"HydrogenEngine": {"name": "Hydrogen engine", "category": "engines", "material": "steel"},
	"TurbineEngine": {"name": "Turbine engine", "category": "engines", "material": "alloy"},
	"IonThruster": {"name": "Ion thruster", "category": "engines", "material": "alloy"},
	"SideThruster": {"name": "Side thruster", "category": "engines", "material": "alloy"},
	"LiftThruster": {"name": "Lift thruster", "category": "engines", "material": "alloy"},
	# Machinery and fluids
	"Assembler": {"name": "Assembler", "category": "machinery", "material": "steel"},
	"FuelTank": {"name": "Fuel tank", "category": "fluids", "material": "steel"},
	"SideTank": {"name": "Side tank", "category": "fluids", "material": "steel"},
	"FuelValve": {"name": "Valve", "category": "piping", "material": "steel"},
	"Pipe": {"name": "Pipe", "category": "piping", "material": "steel"},
	"BigPipe": {"name": "Big pipe", "category": "piping", "material": "steel"},
	"CargoContainer": {"name": "Cargo container", "category": "cargo", "material": "steel"},
	# Life and crew
	"MedStation": {"name": "Med station", "category": "electronics", "material": "alloy"},
	"CrashSeat": {"name": "Crash seat", "category": "fittings", "material": "alloy"},
	"Seat": {"name": "Seat", "category": "fittings", "material": "alloy"},
	"Bunk": {"name": "Bunk", "category": "fittings", "material": "steel"},
	"Locker": {"name": "Locker", "category": "fittings", "material": "steel"},
	"Workbench": {"name": "Workbench", "category": "fittings", "material": "steel"},
	"GalleyCounter": {"name": "Galley counter", "category": "fittings", "material": "steel"},
	# Structure
	"BoxBeam": {"name": "Box beam", "category": "frame", "material": "steel"},
	"Girder": {"name": "Girder", "category": "frame", "material": "steel"},
	"HullPlate": {"name": "Hull plate", "category": "hull", "material": "steel"},
	"DeckPlate": {"name": "Deck plate", "category": "hull", "material": "steel"},
	"ArmourSlab": {"name": "Armour slab", "category": "hull", "material": "tungsten"},
}

## The paint a part's body wears, by category (its builder's vertex colours carry the trim,
## the zones and the lit parts; the body itself is drawn white for its paint to show), sRGB.
const PAINT: Dictionary = {
	"electronics": Color(0.62, 0.65, 0.68), "engines": Color(0.36, 0.38, 0.41),
	"machinery": Color(0.72, 0.6, 0.3), "fluids": Color(0.55, 0.58, 0.56),
	"piping": Color(0.5, 0.52, 0.54), "cargo": Color(0.6, 0.38, 0.2),
	"fittings": Color(0.66, 0.67, 0.68), "wiring": Color(0.58, 0.6, 0.62),
	"frame": Color(0.48, 0.5, 0.52), "hull": Color(0.56, 0.58, 0.6),
}

static var _shapes: Dictionary = {}
static var _surfaces: Dictionary = {}
static var _glows: Dictionary = {}


## Every id, optionally only one category's, sorted.
static func ids(category := "") -> Array[String]:
	var out: Array[String] = []
	for id: String in ENTRIES:
		if category == "" or String(ENTRIES[id]["category"]) == category:
			out.append(id)
	out.sort()
	return out


static func has(id: String) -> bool:
	return ENTRIES.has(id)


## Shown to players ("Battery rack").
static func display_name(id: String) -> String:
	return String(ENTRIES.get(id, {}).get("name", id))


static func category(id: String) -> String:
	return String(ENTRIES.get(id, {}).get("category", ""))


## The Materials id it is made of ("steel").
static func material_id(id: String) -> String:
	return String(ENTRIES.get(id, {}).get("material", "steel"))


## The part's shape (mesh, collision, glow, glass) from Void Salvage's builders at the size a
## ship carries it, cached; null for an unknown id.
static func shape(id: String) -> PartShapes.PartShape:
	if not ENTRIES.has(id):
		return null
	if not _shapes.has(id):
		_shapes[id] = _build(id)
	return _shapes[id]


## Its size as built (m): x across, y up, z along.
static func size(id: String) -> Vector3:
	var s := shape(id)
	return s.mesh.get_aabb().size if s != null else Vector3.ZERO


## Kilograms: its solid volume times its material's density.
static func mass(id: String) -> float:
	var s := shape(id)
	if s == null:
		return 0.0
	var vol := s.volume if s.volume > 0.0 else _box_volume(s.mesh.get_aabb().size) * 0.35
	return maxf(vol * float(Materials.info(material_id(id))["density"]), 1.0)


## Void Salvage's salvage surface for this part's body: its category's paint, its vertex
## colours (trim, the finish zones inside it: chrome, rubber, copper), the detail maps, and
## its material's look (a tungsten slab reads as tungsten). Shared per paint and material;
## never weathered.
static func surface(id: String) -> ShaderMaterial:
	var paint: Color = PAINT.get(category(id), Color(0.6, 0.62, 0.64))
	var key := paint.to_html()
	if not _surfaces.has(key):
		var m := ShaderMaterial.new()
		m.shader = SurfaceFinish.surface_shader(false)
		var lin := paint.srgb_to_linear()   # the shader's albedo is linear
		m.set_shader_parameter("albedo", Vector3(lin.r, lin.g, lin.b))
		m.set_shader_parameter("use_vertex_color", true)
		m.set_shader_parameter("metallic", 0.45)
		m.set_shader_parameter("roughness", 0.55)
		m.set_shader_parameter("survey_skip", true)
		SurfaceDetail.apply(m)
		_surfaces[key] = m
	return Materials.surface(_surfaces[key], material_id(id))


## A lit detail's material (a screen, a status lamp, a thruster's glow) in `c`.
static func glow_material(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _glows.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glows[key] = m
	return _glows[key]


## The part as nodes to drop into a scene: its body on the salvage surface, its glass and its
## lit details, as built (origin where Void Salvage builds it; `size` gives its box). No
## collision: add `shape(id).collision` where it needs one. Null for an unknown id.
static func instance(id: String) -> Node3D:
	var s := shape(id)
	if s == null:
		return null
	var root := Node3D.new()
	root.name = id
	root.set_meta("vs_part", id)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = s.mesh
	body.material_override = surface(id)
	root.add_child(body)
	if s.glass != null:
		var glass := MeshInstance3D.new()
		glass.name = "Glass"
		glass.mesh = s.glass
		glass.material_override = Glazing.material(s.glass_kind)
		root.add_child(glass)
	if not s.emissives.is_empty():
		for e: Dictionary in s.emissives:
			var lit := MeshInstance3D.new()
			lit.name = "Glow"
			lit.mesh = e["mesh"]
			lit.material_override = glow_material(e.get("color", s.glow_color))
			lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(lit)
	elif s.glow != null:
		var lit := MeshInstance3D.new()
		lit.name = "Glow"
		lit.mesh = s.glow
		lit.material_override = glow_material(s.glow_color)
		lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lit)
	return root


static func _build(id: String) -> PartShapes.PartShape:
	match id:
		"Reactor": return WreckParts.reactor(1.0, 2.0)
		"ReactorCore": return WreckParts.reactor_core()
		"Generator": return WreckParts.generator(Vector3(1.4, 1.2, 0.9))
		"BatteryRack": return WreckParts.battery_rack()
		"CapacitorBank": return WreckParts.capacitor_bank(1.6, 1.4, 0.7)
		"SolarPanel": return WreckParts.solar_panel(1.6, 3.0)
		"Radiator": return WreckParts.radiator_grille(2.8, 1.2)
		"HeatSink": return WreckParts.heat_sink()
		"SwitchCabinet": return WreckParts.switch_cabinet()
		"JunctionBox": return WreckParts.junction_box()
		"Gyroscope": return WreckParts.gyroscope()
		"PilotConsole": return WreckParts.console(1.8, 1.0, 0.7)
		"SideConsole": return WreckParts.console(1.0, 1.0, 0.6)
		"Antenna": return WreckParts.antenna(1.6, 0.6)
		"MainThruster": return WreckParts.engine_bell(0.9, 1.8)
		"HydrogenEngine": return WreckParts.hydrogen_engine(1.2, 2.0)
		"TurbineEngine": return WreckParts.turbine_engine(1.0, 1.6)
		"IonThruster": return WreckParts.ion_thruster(0.8, 1.2)
		"SideThruster": return WreckParts.thruster_pod(0.6, 0.5, 0.8)
		"LiftThruster": return WreckParts.ducted_fan(0.6, 0.6)
		"Assembler": return WreckParts.machine_unit(Vector3(1.6, 1.8, 1.2))
		"FuelTank": return WreckParts.tank(0.6, 2.8)
		"SideTank": return WreckParts.banded_tank(0.6, 2.4)
		"FuelValve": return WreckParts.valve_body()
		"Pipe": return WreckParts.pipe(0.08, 4.0)
		"BigPipe": return WreckParts.pipe(0.16, 5.0)
		"CargoContainer": return WreckParts.container(Vector3(2.4, 2.4, 4.8))
		"MedStation": return WreckParts.med_station()
		"CrashSeat": return WreckParts.crash_seat()
		"Seat": return WreckParts.seat()
		"Bunk": return WreckParts.bunk()
		"Locker": return WreckParts.locker()
		"Workbench": return WreckParts.workbench()
		"GalleyCounter": return WreckParts.galley_counter()
		"BoxBeam": return PartShapes.girder(6.0, 0.2, 0.24)
		"Girder": return PartShapes.i_beam(4.0, 0.16, 0.2)
		"HullPlate": return FrameParts.rect(1.5, 2.5)
		"DeckPlate": return PartShapes.inset_panel(1.2, 2.4, 0.04, 0.1)
		"ArmourSlab": return WreckParts.armour_slab(2.0, 2.8)
	return null


static func _box_volume(s: Vector3) -> float:
	return s.x * s.y * s.z
