extends RefCounted
## What a stores item looks like: its own shape from Void Salvage's parts library (a
## battery rack is a battery rack, a fuel tank a tank), never a crate. Trolleys, the
## goods-in floor, the stores and the refurbishment line draw goods with it, so a part
## keeps its form from the ship to the shelf (until the crusher grinds it to dust).
##
## Each catalogue item (StorageLayout.items()) has a builder and a size here; anything not
## listed takes its category's stand-in sized by its mass. Shapes are built once.
##
## Item space: origin at the bottom centre of the item's box, +Y up.

const StorageLayout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")

## Rough density for sizing stand-ins, kg per cubic metre.
const DENSITY := 700.0
## Biggest and smallest edge of a stand-in, metres.
const MAX_EDGE := 5.0
const MIN_EDGE := 0.2
## Lays a part built along Y (tanks, thrusters, engines) down along Z.
const LAY := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))

## The look of goods by how far the refurbishment line has brought them.
enum Look { NEW, WORN, RUST, BARE }

static var _shapes: Dictionary = {}
static var _paints: Dictionary = {}


## The item's size (its box, metres).
static func size_of(item: String, mass := -1.0) -> Vector3:
	return (_entry(item, mass)["aabb"] as AABB).size


## A node drawing one of `item` (origin at its bottom centre), in `look`.
static func make(item: String, look := Look.NEW, mass := -1.0) -> Node3D:
	var e := _entry(item, mass)
	var root := Node3D.new()
	root.name = "Item_" + item.validate_node_name()
	root.set_meta("item", item)
	root.set_meta("size", (e["aabb"] as AABB).size)
	var box: AABB = e["aabb"]
	var xf := Transform3D(e["basis"], -Vector3(box.get_center().x, box.position.y, box.get_center().z))
	var shape: PartShapes.PartShape = e["shape"]
	_mesh(root, shape.mesh, xf, _body_paint(look))
	if shape.glass:
		_mesh(root, shape.glass, xf, Glazing.material(shape.glass_kind))
	if shape.glow and look != Look.RUST:
		_mesh(root, shape.glow, xf, _glow(shape.glow_color))
	return root


## The meshes and transforms (item space) that draw `item`, for MultiMesh batching:
## [[mesh, material, transform]].
static func pieces(item: String, look := Look.NEW, mass := -1.0) -> Array:
	var e := _entry(item, mass)
	var box: AABB = e["aabb"]
	var xf := Transform3D(e["basis"], -Vector3(box.get_center().x, box.position.y, box.get_center().z))
	var shape: PartShapes.PartShape = e["shape"]
	var out: Array = [[shape.mesh, _body_paint(look), xf]]
	if shape.glass:
		out.append([shape.glass, Glazing.material(shape.glass_kind), xf])
	if shape.glow and look != Look.RUST:
		out.append([shape.glow, _glow(shape.glow_color), xf])
	return out


static func _mesh(root: Node3D, mesh: Mesh, xf: Transform3D, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	root.add_child(mi)


static func _entry(item: String, mass: float) -> Dictionary:
	var info: Dictionary = StorageLayout.items().get(item, {})
	var kg := mass if mass >= 0.0 else float(info.get("mass", 50.0))
	var key := item if not info.is_empty() or mass < 0.0 else "%s@%d" % [item, roundi(kg)]
	if _shapes.has(key):
		return _shapes[key]
	var made: Array = _build(item)
	if made.is_empty():
		made = _stand_in(str(info.get("category", "")), kg)
	var shape: PartShapes.PartShape = made[0]
	var basis: Basis = made[1] if made.size() > 1 else Basis()
	var box: AABB = Transform3D(basis, Vector3.ZERO) * shape.mesh.get_aabb()
	var e := {"shape": shape, "basis": basis, "aabb": box}
	_shapes[key] = e
	return e


## The parts library's own builder for a catalogue item: [shape, basis] or [] for none.
static func _build(item: String) -> Array:
	match item:
		# Electronics
		"Antenna": return [WreckParts.antenna(1.4, 0.7)]
		"Armchair": return [WreckParts.armchair()]
		"BatteryRack": return [WreckParts.battery_rack(1.2, 1.4, 0.5)]
		"BreakerPanel": return [WreckParts.switch_cabinet(Vector3(0.9, 1.6, 0.4))]
		"BridgeJunction", "CockpitJunction", "HangarJunction", "HoldJunction", "EngineJunction":
			return [WreckParts.junction_box(Vector3(0.5, 0.4, 0.25))]
		"ButtonPanel": return [WreckParts.button_panel(1.4, 0.5)]
		"CapacitorBank": return [WreckParts.capacitor_bank(1.6, 1.9, 0.7)]
		"EngineControl": return [WreckParts.console(2.4, 1.4, 1.1)]
		"GasGenerator": return [WreckParts.generator(Vector3(1.8, 1.6, 1.4))]
		"Generator": return [WreckParts.generator(Vector3(3.0, 2.4, 2.0))]
		"GravityGenerator": return [WreckParts.gravity_generator(1.4, 1.8)]
		"Gyroscope": return [WreckParts.gyroscope(1.2)]
		"HangarConsole", "PilotConsole": return [WreckParts.console(1.8, 1.2, 0.8)]
		"HelmConsole": return [WreckParts.console(1.8, 1.2, 0.9)]
		"Headlamp": return [WreckParts.headlamp_bar(1.2, 4)]
		"HeatSink": return [WreckParts.heat_sink(6, 1.0)]
		"HydrogenGenerator": return [WreckParts.generator(Vector3(2.4, 2.0, 1.6))]
		"MedStation": return [WreckParts.med_station()]
		"MediaWall": return [WreckParts.media_wall(3.0, 1.8, 0.4)]
		"OreDetector": return [WreckParts.ore_detector(1.0, 0.8)]
		"OverheadPanel": return [WreckParts.button_panel(1.0, 0.4, 4, 2)]
		"OxygenGenerator": return [WreckParts.machine_unit(Vector3(2.6, 2.2, 1.6))]
		"Radiator": return [WreckParts.radiator_grille(2.4, 1.2)]
		"Reactor": return [WreckParts.reactor(1.1, 2.4)]
		"RefillStation": return [WreckParts.refill_station()]
		"Searchlight": return [WreckParts.searchlight(0.45, 0.8)]
		"SideConsole": return [WreckParts.console(1.2, 1.0, 0.6)]
		"SolarPanel": return [WreckParts.solar_panel(1.6, 2.4)]
		"SurvivalKit": return [WreckParts.survival_kit()]
		"Workbench": return [WreckParts.workbench()]
		# Machinery
		"Assembler", "Gearforge": return [WreckParts.machine_unit(Vector3(3.2, 2.6, 2.4))]
		"CutterDrum": return [WreckParts.cutter_drum(1.45, 4.2)]
		"Drill": return [WreckParts.bore_drill(0.9, 2.4)]
		"DrillMotor": return [WreckParts.machine_unit(Vector3(1.4, 1.2, 1.2))]
		"DrillShaft": return [WreckParts.pipe(0.18, 2.4), LAY]
		"Forge", "Smelter", "Refinery": return [WreckParts.machine_unit(Vector3(3.0, 2.8, 2.4))]
		"LandingGear": return [WreckParts.landing_leg(1.4)]
		"LiftCar": return [WreckParts.lift_car(1.8, 1.6, 2.3)]
		"RockWheel": return [WreckParts.rock_wheel(0.95, 1.1)]
		"Welder": return [WreckParts.ship_welder(1.4, 3.0)]
		# Fittings
		"Basin": return [WreckParts.basin()]
		"BedAlcove": return [WreckParts.bed_alcove()]
		"Bench": return [WreckParts.bench()]
		"BowLights", "RoofLights": return [WreckParts.stud_lights(4)]
		"Bunk": return [WreckParts.bunk()]
		"CrewSeat", "PilotSeat", "Seat": return [WreckParts.seat()]
		"Desk", "PlotTable", "LoungeTable": return [WreckParts.table(1.6, 0.8, 0.75)]
		"DeskChair", "MessSeat", "Stool": return [WreckParts.stool()]
		"DoorJamb": return [WreckParts.portal_jamb()]
		"DoorLintel": return [WreckParts.portal_lintel()]
		"Galley": return [WreckParts.galley_counter(2.4)]
		"GalleyCounter": return [WreckParts.galley_counter(2.0)]
		"Ladder": return [WreckParts.ladder(2.4)]
		"Locker", "ToolLocker": return [WreckParts.locker()]
		"MedBed": return [WreckParts.med_bed()]
		"MessTable": return [WreckParts.mess_table()]
		"NameBoard": return [WreckParts.name_board("BSX", 3.0, 0.8)]
		"Railing": return [WreckParts.railing(2.0)]
		"RoofHatch": return [WreckParts.roof_hatch()]
		"RoofVent", "SideVent", "SternVent": return [WreckParts.louvre_panel(1.2, 0.6)]
		"ShelfRack": return [WreckParts.shelf_rack()]
		"Shower": return [WreckParts.shower()]
		"Stair": return [WreckParts.stair(1.0, 1.8, 2.4)]
		"SternGrille": return [WreckParts.radiator_grille(1.6, 0.8)]
		"SuitLocker", "SurvivalLocker": return [WreckParts.survival_locker()]
		"Toilet": return [WreckParts.toilet()]
		# Glass
		"WindscreenPane": return [WreckParts.mesh_panel(2.0, 1.2, 0.06), Basis(Vector3.RIGHT, -PI * 0.5)]
		# Hull
		"Grating": return [WreckParts.grating(1.2, 2.4)]
		"ThrusterBlock": return [WreckParts.thruster_pod(1.6, 1.4, 1.8)]
		# Cargo
		"CargoContainer", "OreContainer": return [WreckParts.container(Vector3(2.4, 2.4, 4.8))]
		"CargoCrate": return [WreckParts.cargo_crate()]
		"CargoModule", "TechContainer": return [WreckParts.container(Vector3(2.2, 2.2, 3.6))]
		"Container": return [WreckParts.container(Vector3(2.0, 2.0, 2.6))]
		"ContainerHatch": return [WreckParts.container_hatch()]
		"OreBin": return [WreckParts.ore_bin()]
		# Wiring and piping
		"ConveyorJunction": return [WreckParts.conveyor_junction()]
		"ConveyorTube": return [WreckParts.conveyor_tube(2.0)]
		"CoolantElbow", "FuelElbow", "FuelLineElbow", "PipeElbow": return [WreckParts.pipe_elbow(0.08)]
		"CoolantLineTee", "FuelLineTee": return [WreckParts.pipe_tee(0.08)]
		"CoolantLine", "CoolantPipe", "FuelLine", "FuelPipe", "PipeDrop": return [WreckParts.pipe(0.08, 1.6), LAY]
		# Fluids
		"CoolantPump", "FuelPump": return [WreckParts.machine_unit(Vector3(1.6, 1.4, 1.2))]
		"CoolantTank": return [WreckParts.tank(0.45, 1.6), LAY]
		"FuelTank": return [WreckParts.banded_tank(0.8, 2.6), LAY]
		"SideTank": return [WreckParts.octo_tank(0.7, 2.6), LAY]
		# Frame
		"GunMount", "GunCradle": return [WreckParts.piston_gear(1.6, 1.4)]
		"LandingLeg": return [WreckParts.landing_leg(1.6)]
		"RailBarrel": return [WreckParts.rail_barrel(4.0)]
		"RailBreech": return [WreckParts.machine_unit(Vector3(2.6, 2.4, 5.0))]
		# Engines
		"DriveEngine", "IonThruster", "LiftThruster", "SideThruster", "SideThrusters":
			return [WreckParts.ion_thruster(0.6, 1.0), LAY]
		"EnginePod": return [WreckParts.thruster_pod(2.4, 2.0, 4.0)]
		"HydrogenEngine": return [WreckParts.hydrogen_engine(1.0, 1.8), LAY]
		"HydrogenThruster", "MainThruster", "SternThruster": return [WreckParts.cup_thruster(0.6, 1.0), LAY]
		"JumpDrive": return [WreckParts.gravity_generator(1.6, 2.0)]
		"MainEngine": return [WreckParts.engine_bell(0.9, 2.0), LAY]
		"TurbineEngine": return [WreckParts.turbine_engine(0.9, 1.5), LAY]
		# Weapons
		"GunnerConsole": return [WreckParts.console(1.6, 1.2, 0.8)]
		"GunnerSeat": return [WreckParts.crash_seat()]
		"LargeTurret": return [WreckParts.twin_turret(1.2, 2.4)]
		"MissileLauncher": return [WreckParts.missile_launcher(1.4, 1.6, 3.6)]
		"MissileRack": return [WreckParts.missile_launcher(1.0, 1.0, 2.0, 2, 2)]
		"NavalTurret": return [WreckParts.naval_turret(2.4, 3.6)]
		"RailMuzzle": return [WreckParts.rail_muzzle(1.4, 1.2)]
		"Turret": return [WreckParts.dome_turret()]
	return []


## A category's stand-in for a part with no builder of its own, sized from its mass.
static func _stand_in(category: String, kg: float) -> Array:
	var v := maxf(kg, 1.0) / DENSITY
	match category:
		"fluids":
			var r := clampf(pow(v / 6.0, 1.0 / 3.0), MIN_EDGE, 1.2)
			return [WreckParts.tank(r, clampf(r * 3.5, 0.6, MAX_EDGE)), LAY]
		"engines":
			var r := clampf(pow(v / 4.0, 1.0 / 3.0), 0.25, 1.4)
			return [WreckParts.engine_bell(r, clampf(r * 2.4, 0.6, MAX_EDGE)), LAY]
		"piping", "wiring":
			return [WreckParts.pipe(0.08, clampf(v * 60.0, 0.6, 3.0)), LAY]
		"hull", "glass":
			var side := clampf(sqrt(v / 0.04), 0.6, 3.0)
			return [PartShapes.chamfer_box(Vector3(side, 0.04 + v / (side * side), side * 1.3), 0.01)]
		"frame":
			var l := clampf(v * 30.0, 1.0, MAX_EDGE)
			return [PartShapes.girder(l, 0.2, 0.2), Basis(Vector3.UP, PI * 0.5)]
		"weapons":
			return [WreckParts.dome_turret(clampf(pow(v, 1.0 / 3.0) * 0.6, 0.3, 1.4))]
		"cargo":
			var e := clampf(pow(v, 1.0 / 3.0), 0.6, 2.6)
			return [WreckParts.cargo_crate(Vector3(e, e, e))]
		"fittings":
			var e := clampf(pow(v, 1.0 / 3.0), MIN_EDGE, 2.0)
			return [WreckParts.locker(e, clampf(e * 1.6, 0.4, 2.2), e * 0.6)]
		"fasteners":
			return [WreckParts.lockbox()]
	# Electronics, machinery, ship modules: a machine.
	var e := clampf(pow(v, 1.0 / 3.0), 0.4, 3.2)
	return [WreckParts.machine_unit(Vector3(e * 1.2, e, e))]


static func _body_paint(look: int) -> Material:
	if _paints.has(look):
		return _paints[look]
	var m: Material
	match look:
		Look.RUST:
			m = ShipSurface.of(ShipKit.paint(Color(0.44, 0.25, 0.13), 0.3, 0.9, "cast_iron"))
		Look.WORN:
			m = ShipSurface.of(ShipKit.paint(Color(0.62, 0.56, 0.48), 0.35, 0.75, "bare_steel"))
		Look.BARE:
			m = ShipSurface.of(ShipKit.paint(Color(0.85, 0.86, 0.88), 0.85, 0.3, "bare_steel"))
		_:
			# The part's own zoned colours and finishes.
			m = ShipSurface.of(ShipKit.paint(Color.WHITE, 0.4, 0.55))
	_paints[look] = m
	return m


static func _glow(colour: Color) -> Material:
	var key := "glow/" + colour.to_html()
	if not _paints.has(key):
		_paints[key] = ShipKit.glow(colour, 1.2)
	return _paints[key]


## Where `count` copies of goods `size` big stand on a deck `area` (x across, y along)
## stacked neatly: rows across, rows along, then layer on layer up to `max_height` (m).
## Long goods turn to lie along the deck. Returns the transforms (deck space, origin at the
## deck's centre on its top) of those that fit, at most `count`.
static func stack(size: Vector3, count: int, area: Vector2, max_height := 2.4, gap := 0.04) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var basis := Basis()
	var s := size
	# Turn it so its longer side runs along the deck's longer side.
	if (s.x > s.z) != (area.x > area.y):
		basis = Basis(Vector3.UP, PI * 0.5)
		s = Vector3(s.z, s.y, s.x)
	var across := maxi(1, floori((area.x + gap) / (s.x + gap)))
	var along := maxi(1, floori((area.y + gap) / (s.z + gap)))
	var layers := maxi(1, floori((max_height + 0.001) / (s.y + gap)))
	var x0 := -(across * (s.x + gap) - gap) * 0.5 + s.x * 0.5
	var z0 := -(along * (s.z + gap) - gap) * 0.5 + s.z * 0.5
	for layer in layers:
		for j in along:
			for i in across:
				if out.size() >= count:
					return out
				out.append(Transform3D(basis, Vector3(x0 + i * (s.x + gap), layer * (s.y + gap), z0 + j * (s.z + gap))))
	return out


## Several lots on one deck (a trolley's load): each lot `{item, count, look}` gets a band
## across the deck, front to back in load order, its goods in rows across it and layered up
## to `max_height`; a lot with too little deck left stacks higher. Returns
## [[item, look, transform], ...] (deck space, like stack()).
static func stack_lots(lots: Array, area: Vector2, max_height := 2.4, gap := 0.06) -> Array:
	var out: Array = []
	var z := -area.y * 0.5
	for lot: Dictionary in lots:
		var item := str(lot.get("item", ""))
		var count := maxi(1, int(lot.get("count", 1)))
		var s := size_of(item)
		var basis := Basis()
		# Long goods lie across the deck so a lot's band stays short.
		if s.z > s.x and s.z <= area.x:
			basis = Basis(Vector3.UP, PI * 0.5)
			s = Vector3(s.z, s.y, s.x)
		var across := maxi(1, floori((area.x + 0.04) / (s.x + 0.04)))
		var layers := maxi(1, floori((max_height + 0.001) / (s.y + 0.02)))
		var left := area.y * 0.5 - z
		var rows := ceili(float(count) / (across * layers))
		var room := maxi(1, floori((left + gap) / (s.z + gap)))
		if rows > room:
			rows = room
			layers = ceili(float(count) / (across * rows))
		var x0 := -(across * (s.x + 0.04) - 0.04) * 0.5 + s.x * 0.5
		var placed := 0
		for layer in layers:
			for j in rows:
				for i in across:
					if placed >= count:
						break
					out.append([item, lot.get("look", Look.NEW), Transform3D(basis,
							Vector3(x0 + i * (s.x + 0.04), layer * (s.y + 0.02), z + s.z * 0.5 + j * (s.z + gap)))])
					placed += 1
		z = minf(z + rows * (s.z + gap), area.y * 0.5 - 0.2)
	return out


## The look for goods in this condition (0..1) at this point on the line ("" when not on it).
static func look_for(condition: float, stage := "") -> int:
	match stage:
		"coater":
			return Look.NEW
		"bath":
			return Look.BARE
	if condition >= 0.9:
		return Look.NEW
	return Look.RUST if condition < 0.6 else Look.WORN
