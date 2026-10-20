extends RigidBody3D
## The Kestrel in full: Void Salvage's starter salvager (its KestrelShip, VS commit 065f363)
## built the same way, frame first with the shared HullBuilder and fitted out from the
## shared ShipParts, so every frame, plate, door and fitting is where Void Salvage has it.
## Then the detail an export leaves out: rivets along every skin plate's seams, bolt heads
## on the linings, the deck plates and the fittings' feet, and a bolted mounting flange
## behind each engine (the bay's fastener heads sit on it).
##
## Frozen: it stands on the bay's cradles. The screens and panels are dressing here (no
## ship systems in the yard). Built in _init, so a bare instantiate() has every piece.
##
## Ship space: -Z forward, +Y up, the deck floor at y = 0. Rooms:
##   cockpit   z -5.5 .. -2.5   cabin z -2.5 .. 1.35   bulkhead 1.35 .. 1.65
##   hold      z  1.65 .. 6.42  engines 6.5 .. 8.0

# The hull's outline (outer surface), metres (as KestrelShip).
const W: float = 2.6
const ROOF: float = 3.2
const SHOULDER: float = 2.6
const CHINE: float = -0.15
const BELLY: float = -0.5
const BOTTOM_X: float = 2.15
const ROOF_X: float = 2.0
const Z_NOSE: float = -5.5
const Z_COCKPIT: float = -2.5
const Z_BULK: float = 1.5
const BULK_T: float = 0.3
const Z_STERN: float = 6.5
const STATIONS: Array[float] = [-2.5, -0.5, 1.5, 4.0, 6.5]
const NOSE_STATIONS: Array[float] = [-5.5, -4.0, -2.5]
const IN: float = 2.24
const CEIL: float = 2.5
const DECK_UP: float = 0.3
const FRAME_IN: float = 0.27
const OPENING := Rect2(-0.8, 0.3, 1.6, 2.0)
const DOOR := Rect2(-0.55, 0.0, 1.1, 2.1)
const STERN_DOOR := Rect2(-1.6, 0.05, 3.2, 2.4)
const HATCH := Rect2(-1.0, 3.5, 1.9, 2.6)
const LOCK_DOOR := Vector2(1.85, 2.65)
const LOCK_DOOR_TOP: float = 2.05
const FUEL_PORT_Z: float = 4.9
const WINDOW_Z: float = -1.35
const SEAT_Z: float = -4.05
## The engines' mounting flanges on the stern face (x, y), one each side.
const FLANGE := Vector2(1.0, 1.18)
const FLANGE_T: float = 0.04
## Rivet and bolt spacing along a seam, metres.
const RIVET_PITCH: float = 0.16
const BOLT_PITCH: float = 0.5

var kit: ShipKit
var shell := ShipParts.mat("shell")
var trim_paint := ShipParts.mat("trim")
var dark := ShipParts.mat("dark")
var edge_glow := ShipParts.mat("edge")
var frame_steel := ShipKit.paint(Color(0.34, 0.36, 0.38), 0.75, 0.4)
var lining := ShipKit.paint(Color(0.74, 0.74, 0.72), 0.1, 0.65)
var floor_mat := ShipKit.paint(Color(0.22, 0.23, 0.24), 0.6, 0.6)
var hull_dark := ShipKit.paint(Color(0.26, 0.28, 0.3), 0.6, 0.45)
var hazard := ShipKit.paint(Color(0.95, 0.55, 0.1), 0.2, 0.55)
var white := ShipKit.paint(Color(0.9, 0.9, 0.88), 0.1, 0.35)
var red := ShipKit.glow(Color(1.0, 0.08, 0.04), 3.0)
var glass := ShipKit.glass()
var bolt_steel := ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.35)
## Every fitting from ShipParts: {name, box (ship space)}.
var fittings: Array[Dictionary] = []
## Rivet and bolt heads, by material: Material -> Array[Transform3D] (one MultiMesh each).
var rivets: Dictionary = {}
var bolts: Dictionary = {}


func _init() -> void:
	name = "Kestrel"
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	kit = ShipKit.new(self)
	_build_hull()
	_build_canopy()
	_build_inner_walls()
	_build_cockpit()
	_build_cabin()
	_build_hold()
	_build_side_door()
	_build_stern()
	_build_exterior()
	_rivet_hull()
	_bolt_inside()
	_build_heads()


## The main hull's cross-section, round from the roof's left edge (x, y).
static func profile() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-ROOF_X, ROOF), Vector2(ROOF_X, ROOF), Vector2(W, SHOULDER), Vector2(W, CHINE),
			Vector2(BOTTOM_X, BELLY), Vector2(-BOTTOM_X, BELLY), Vector2(-W, CHINE), Vector2(-W, SHOULDER)])


## The canopy section's cross-section at nose station `i` (0 = the nose, 2 = the hull).
static func nose_profile(i: int) -> PackedVector2Array:
	var s: Array = [[1.75, 2.5, 0.7, 1.05, 0.12, 1.25, -0.15], [2.45, 3.45, 0.75, 1.15, -0.05, 1.95, -0.42],
			[W, ROOF, ROOF - SHOULDER, 1.2, CHINE, BOTTOM_X, BELLY]][i]
	var w: float = s[0]
	var top: float = s[1]
	var c: float = s[2]
	return PackedVector2Array([Vector2(-(w - c), top), Vector2(w - c, top), Vector2(w, top - c), Vector2(w, s[3]),
			Vector2(w, s[4]), Vector2(s[5], s[6]), Vector2(-s[5], s[6]), Vector2(-w, s[4]), Vector2(-w, s[3]),
			Vector2(-w, top - c)])


# --- Hull: frame first, then skin ------------------------------------------------------------

func _build_hull() -> void:
	var outline := profile()
	var hull_b := HullBuilder.new(kit, shell, frame_steel)
	for z in STATIONS:
		hull_b.add_station(z, outline)
	hull_b.frame_skip = func(station: int, edge: int) -> bool:
		var z: float = STATIONS[station]
		return edge == 4 and z > HATCH.position.y - 0.3 and z < HATCH.end.y + 0.3
	# Edges: 0 roof, 1 right shoulder, 2 right side, 3 right lower chamfer, 4 bottom, 5 left
	# lower chamfer, 6 left side, 7 left shoulder. Sides and bottom are walls with holes.
	hull_b.build(func(_seg: int, edge: int) -> Dictionary:
		match edge:
			2, 4, 6:
				return {"skip": true}
			1, 7:
				return {"mat": trim_paint}
		return {"mat": shell})
	for side: float in [-1.0, 1.0]:
		var holes: Array = [_side_window(side, W - 0.04, WINDOW_Z, 1.45, 0.9, 0.6, "chamfer")]
		if side < 0.0:
			holes.append(Rect2(LOCK_DOOR.x, 0.0, LOCK_DOOR.y - LOCK_DOOR.x, LOCK_DOOR_TOP))
		kit.wall("x", side * (W - 0.04), Z_COCKPIT, Z_STERN, CHINE, SHOULDER, 0.08, holes, shell)
	kit.wall("y", BELLY * 0.5, -BOTTOM_X, BOTTOM_X, Z_COCKPIT, Z_STERN - 0.08, -BELLY, [Rect2(HATCH.position, HATCH.size)], floor_mat)
	for side: float in [-1.0, 1.0]:
		kit.block(Vector3(side * BOTTOM_X, -0.12, Z_COCKPIT), Vector3(side * (IN + 0.08), 0.0, Z_STERN - 0.08), floor_mat)
	hull_b.cap(Z_STERN, _stern_pieces(), 1.0, dark)


## The stern cap's outlines round the stern door.
static func _stern_pieces() -> Array:
	var out: Array = []
	for r: Rect2 in [Rect2(-4.0, -2.0, 4.0 + STERN_DOOR.position.x, 6.0), Rect2(STERN_DOOR.end.x, -2.0, 4.0, 6.0),
			Rect2(STERN_DOOR.position.x, STERN_DOOR.end.y, STERN_DOOR.size.x, 2.0),
			Rect2(STERN_DOOR.position.x, -2.0, STERN_DOOR.size.x, 2.0 + STERN_DOOR.position.y)]:
		var piece := _clip(profile(), r)
		if piece.size() >= 3:
			out.append(piece)
	return out


func _build_canopy() -> void:
	var nose := HullBuilder.new(kit, shell, frame_steel)
	nose.frame_width = 0.1
	nose.frame_height = 0.12
	nose.node_size = 0.16
	for i in NOSE_STATIONS.size():
		nose.add_station(NOSE_STATIONS[i], nose_profile(i))
	nose.frame_skip = func(_station: int, edge: int) -> bool:
		return edge == 5
	nose.build(func(seg: int, edge: int) -> Dictionary:
		if _canopy_glazed(seg, edge):
			return {"mat": glass}
		return {"mat": shell})
	var front := nose_profile(0)
	var sill := front[3].y
	var low := PackedVector2Array()
	var high := PackedVector2Array()
	for p in front:
		if p.y <= sill + 0.001:
			low.append(p)
		if p.y >= sill - 0.001:
			high.append(p)
	nose.cap(Z_NOSE, [low], -1.0, shell)
	nose.cap(Z_NOSE, [high], -1.0, glass)
	for x: float in [-0.55, 0.55]:
		kit.add(PartShapes.box(Vector3(0.07, 2.5 - sill - 0.08, 0.07)), Transform3D(Basis(), Vector3(x, (sill + 2.5 - 0.08) * 0.5, Z_NOSE - 0.02)),
				frame_steel, "", null, false)
	kit.add(PartShapes.box(Vector3(front[3].x * 2.0 + 0.04, 0.06, 0.04)), Transform3D(Basis(), Vector3(0, sill, Z_NOSE - 0.03)),
			trim_paint, "", null, false)


static func _canopy_glazed(seg: int, edge: int) -> bool:
	return edge in [1, 2, 8, 9] or (edge == 0 and seg == 0)


func _build_inner_walls() -> void:
	var cabin_z1 := Z_BULK - BULK_T * 0.5
	var hold_z0 := Z_BULK + BULK_T * 0.5
	_cross_wall(Z_COCKPIT, 0.12, [OPENING], lining)
	_cross_wall(Z_BULK, BULK_T, [DOOR], lining)
	for side: float in [-1.0, 1.0]:
		var hole := Rect2(WINDOW_Z - 0.45, 1.15, 0.9, 0.6)
		kit.wall("x", side * (IN + 0.04), Z_COCKPIT + 0.06, cabin_z1, 0.0, CEIL, 0.08, [hole], lining)
		_window_reveal(side, hole)
		var holes: Array = []
		if side < 0.0:
			holes.append(Rect2(LOCK_DOOR.x, 0.0, LOCK_DOOR.y - LOCK_DOOR.x, LOCK_DOOR_TOP))
		kit.wall("x", side * (IN + 0.04), hold_z0, Z_STERN - 0.08, 0.0, CEIL, 0.08, holes, lining)
	kit.wall("y", CEIL + 0.03, -IN - 0.08, IN + 0.08, Z_COCKPIT + 0.06, cabin_z1, 0.06, [], lining)
	for side: float in [-1.0, 1.0]:
		kit.add(PartShapes.box(Vector3(0.012, 0.1, cabin_z1 - Z_COCKPIT - 0.1)), Transform3D(Basis(),
				Vector3(side * (IN - 0.006), 0.05, (Z_COCKPIT + cabin_z1) * 0.5)), dark, "", null, false)
		kit.add(PartShapes.box(Vector3(0.012, 0.04, Z_STERN - hold_z0 - 0.1)), Transform3D(Basis(),
				Vector3(side * (IN - 0.006), CEIL - 0.02, (hold_z0 + Z_STERN) * 0.5)), trim_paint, "", null, false)


func _cross_wall(z: float, thickness: float, holes: Array, mat: Material) -> void:
	var inner := FrameParts.inset(profile(), FRAME_IN)
	var cuts: Array[float] = [-4.0, 4.0]
	for h: Rect2 in holes:
		cuts.append(h.position.x)
		cuts.append(h.end.x)
	cuts.sort()
	var pieces: Array = []
	for i in cuts.size() - 1:
		var a := cuts[i]
		var b := cuts[i + 1]
		if b - a < 0.005:
			continue
		var spans: Array = [[-2.0, 5.0]]
		for h: Rect2 in holes:
			if (a + b) * 0.5 > h.position.x and (a + b) * 0.5 < h.end.x:
				var next: Array = []
				for s: Array in spans:
					if h.end.y <= s[0] or h.position.y >= s[1]:
						next.append(s)
						continue
					if h.position.y > s[0]:
						next.append([s[0], h.position.y])
					if h.end.y < s[1]:
						next.append([h.end.y, s[1]])
				spans = next
		for s: Array in spans:
			var piece := _clip(inner, Rect2(a, s[0], b - a, (s[1] as float) - (s[0] as float)))
			if piece.size() >= 3:
				pieces.append(piece)
	var walls := HullBuilder.new(kit, mat, mat)
	walls.skin = thickness
	walls.cap(z - thickness * 0.5, pieces, -1.0, mat)


static func _clip(outline: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var got := Geometry2D.intersect_polygons(outline, box)
	if got.is_empty():
		return PackedVector2Array()
	return got[0]


func _window_reveal(side: float, hole: Rect2) -> void:
	var x := side * (IN + 0.18)
	var depth := 0.2
	for y: float in [hole.position.y - 0.02, hole.end.y + 0.02]:
		kit.add(PartShapes.box(Vector3(depth, 0.04, hole.size.x + 0.08)), Transform3D(Basis(), Vector3(x, y, hole.get_center().x)), lining)
	for z: float in [hole.position.x - 0.02, hole.end.x + 0.02]:
		kit.add(PartShapes.box(Vector3(depth, hole.size.y, 0.04)), Transform3D(Basis(), Vector3(x, hole.get_center().y, z)), lining)
	kit.add(PartShapes.box(Vector3(0.01, 0.012, hole.size.x)), Transform3D(Basis(), Vector3(side * (IN - 0.005), hole.position.y - 0.03,
			hole.get_center().x)), edge_glow, "", null, false)


func _side_window(side: float, wall_x: float, z: float, y: float, length: float, height: float,
		inner: String, opening: float = 0.78) -> Rect2:
	var shape := PartShapes.window_panel(height, length, inner, 0.16, opening)
	kit.add(shape, Transform3D(Basis(Vector3.BACK, -side * PI * 0.5), Vector3(side * wall_x, y, z)), hull_dark, "", glass)
	return Rect2(z - length * 0.5, y - height * 0.5, length, height)


# --- Cockpit -------------------------------------------------------------------------------

func _build_cockpit() -> void:
	kit.block(Vector3(-1.5, DECK_UP - 0.1, Z_NOSE + 0.25), Vector3(1.5, DECK_UP, -4.0), floor_mat)
	kit.block(Vector3(-2.05, DECK_UP - 0.1, -4.0), Vector3(2.05, DECK_UP, Z_COCKPIT - 0.06), floor_mat)
	var step := Vector3(OPENING.size.x, DECK_UP, 0.45)
	var col := CollisionShape3D.new()
	col.shape = PartShapes.wedge(step).collision
	col.transform = Transform3D(Basis(), Vector3(0, DECK_UP * 0.5, Z_COCKPIT + 0.06 + step.z * 0.5))
	add_child(col)
	for k in 2:
		var top := DECK_UP * (1.0 - float(k) * 0.5)
		var front := Z_COCKPIT + 0.06 + step.z * (0.5 + float(k) * 0.5)
		kit.add(PartShapes.box(Vector3(step.x, top, front - Z_COCKPIT - 0.06)), Transform3D(Basis(),
				Vector3(0, top * 0.5, (Z_COCKPIT + 0.06 + front) * 0.5)), floor_mat, "", null, false)
		kit.add(PartShapes.box(Vector3(step.x, 0.012, 0.02)), Transform3D(Basis(), Vector3(0, top - 0.006, front - 0.01)),
				edge_glow, "", null, false)
	fittings.append(ShipParts.console(kit, Transform3D(Basis(), Vector3(0, DECK_UP, -4.78)), 2.7, 0.5))
	_tilted_screen(Vector3(-0.85, DECK_UP + 0.92, -5.06), 30.0, Vector2(0.7, 0.42),
			"FLIGHT\nVEL   0.0 m/s\nDAMP  ON\nBAY   CRADLED", ShipParts.SCREEN)
	_tilted_screen(Vector3(0, DECK_UP + 0.94, -5.06), 30.0, Vector2(0.62, 0.38), "NAV\n\n  BSX LTD YARD\n  BAY 1", Color(0.4, 1.0, 0.55))
	_tilted_screen(Vector3(0.85, DECK_UP + 0.92, -5.06), 30.0, Vector2(0.7, 0.46), "HOLD\n0 kg\nSTERN  SHUT\nHATCH  SHUT", ShipParts.SCREEN)
	var map_at := Vector3(1.62, DECK_UP + 1.05, -4.55)
	var nav_eye := Vector3(0.72, DECK_UP + 1.55, SEAT_Z + 0.1)
	var map_frame := Transform3D(Basis.looking_at(map_at - nav_eye, Vector3.UP), map_at)
	kit.add(PartShapes.box(Vector3(0.68, 0.5, 0.03)), map_frame, hull_dark, "", null, false)
	kit.add(PartShapes.box(Vector3(0.62, 0.44, 0.004)), map_frame * Transform3D(Basis(), Vector3(0, 0, 0.017)),
			ShipParts.mat("screen"), "", null, false)
	_label("SYSTEM MAP", map_frame * Transform3D(Basis(), Vector3(-0.28, 0.19, 0.02)), 22, ShipParts.SCREEN, true)
	kit.add(PartShapes.box(Vector3(0.08, map_at.y - 0.3 - DECK_UP, 0.08)), Transform3D(Basis(),
			Vector3(map_at.x, (DECK_UP + map_at.y - 0.3) * 0.5, map_at.z + 0.05)), dark)
	kit.add(PartShapes.box(Vector3(0.3, 0.03, 0.3)), Transform3D(Basis(), Vector3(map_at.x, DECK_UP + 0.015, map_at.z + 0.05)),
			dark, "", null, false)
	fittings.append(ShipParts.seat(kit, Vector3(-0.72, DECK_UP, SEAT_Z), "seat_0"))
	fittings.append(ShipParts.seat(kit, Vector3(0.72, DECK_UP, SEAT_Z), "seat_1"))
	kit.light(Vector3(0, 2.75, -3.3), Color(0.8, 0.88, 1.0), 0.6, 5.0)
	for side: float in [-1.0, 1.0]:
		kit.add(PartShapes.box(Vector3(0.012, 0.012, Z_COCKPIT + 4.0 - 0.1)), Transform3D(Basis(),
				Vector3(side * 1.99, DECK_UP + 0.006, (-4.0 + Z_COCKPIT) * 0.5)), edge_glow, "", null, false)


# --- Cabin ---------------------------------------------------------------------------------

func _build_cabin() -> void:
	var front := Z_COCKPIT + 0.06
	var back := Z_BULK - BULK_T * 0.5
	var to_aft := Basis(Vector3.UP, -PI * 0.5)
	var to_fore := Basis(Vector3.UP, PI * 0.5)
	var from_right := Basis(Vector3.UP, PI)
	var names: Array[String] = ["CREW 1", "CREW 2", "CREW 3", "CREW 4"]
	var k := 0
	for x: float in [-2.02, -1.6, 1.6, 2.02]:
		var l := ShipParts.locker(kit, Transform3D(to_aft, Vector3(x, 0, front)))
		(l["label"] as Label3D).text = names[k]
		k += 1
		fittings.append(l)
	fittings.append(ShipParts.breaker_panel(kit, Transform3D(to_aft, Vector3(-1.1, 0, front))))
	fittings.append(ShipParts.trophy_shelf(kit, Transform3D(to_aft, Vector3(1.1, 0, front)), 1.55, 0.5))
	var t := ShipParts.table(kit, Transform3D(Basis(), Vector3(-IN, 0, WINDOW_Z)), Vector2(0.8, 1.1))
	(t["label"] as Label3D).text = "WORK ORDER\n\nIN BAY AT BSX LTD\nFOR REFIT"
	fittings.append(t)
	fittings.append(ShipParts.galley(kit, Transform3D(from_right, Vector3(IN, 0, WINDOW_Z)), 1.1, 0.6, false))
	var bunk_z := back - 0.05 - 0.975
	fittings.append(ShipParts.bunks(kit, Transform3D(Basis(), Vector3(-IN, 0, bunk_z))))
	fittings.append(ShipParts.bunks(kit, Transform3D(from_right, Vector3(IN, 0, bunk_z))))
	_door_panel(Transform3D(to_fore, Vector3(0.8, 1.3, back)))
	fittings.append(ShipParts.name_board(kit, Transform3D(to_fore, Vector3(0, 2.33, back)), "KESTREL", 1.1, 0.2))
	ShipParts.lamp(kit, Vector3(0, CEIL - 0.04, -1.3), 1.0, Vector3.BACK, "warm", 0.9, 4.5)
	ShipParts.lamp(kit, Vector3(0, CEIL - 0.04, 0.45), 1.0, Vector3.BACK, "warm", 0.7, 4.0)


# --- Hold ----------------------------------------------------------------------------------

func _build_hold() -> void:
	var face := Z_BULK + BULK_T * 0.5
	var to_aft := Basis(Vector3.UP, -PI * 0.5)
	var from_right := Basis(Vector3.UP, PI)
	_build_bulkhead_door()
	_door_panel(Transform3D(to_aft, Vector3(0.85, 1.3, face)))
	_monitor(Transform3D(to_aft, Vector3(-1.43, 1.7, face)), Vector2(1.52, 0.855))
	fittings.append(ShipParts.suit_stand(kit, Transform3D(Basis(), Vector3(-IN, 0, 4.05))))
	fittings.append(ShipParts.wall_rack(kit, Transform3D(Basis(), Vector3(-IN, 0, 5.2)), 1.5, 1.05))
	_control_panel(Transform3D(Basis(), Vector3(-IN, 1.62, 5.2)), "CARGO CONTROL",
			[["STERN DOOR", Color(0.3, 0.7, 1.0)], ["ATTRACT", Color(0.35, 1.0, 0.6)],
			["EJECT", Color(1.0, 0.25, 0.15)], ["LIGHTS", Color(1.0, 0.95, 0.75)]])
	_bowsers(Transform3D(from_right, Vector3(IN, 0.0, FUEL_PORT_Z)))
	_hose_rack(Transform3D(from_right, Vector3(IN, 1.65, 5.62)))
	fittings.append(ShipParts.reactor_cabinet(kit, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.97, 0, Z_STERN - 0.08)), 0.52, 0.3))
	for side: float in [-1.0, 1.0]:
		var half := HATCH.size.x * 0.5
		var cx := HATCH.get_center().x + side * (half * 0.5 - 0.003)
		kit.add(PartShapes.box(Vector3(half + 0.006, 0.1, HATCH.size.y - 0.04)),
				Transform3D(Basis(), Vector3(cx, -0.06, HATCH.get_center().y)), dark)
		for k in 3:
			var z := lerpf(HATCH.position.y + 0.5, HATCH.end.y - 0.5, float(k) / 2.0)
			kit.add(PartShapes.box(Vector3(half - 0.2, 0.012, 0.22)), Transform3D(Basis(), Vector3(cx, 0.0, z)), hazard, "", null, false)
			kit.add(PartShapes.box(Vector3(half - 0.1, 0.1, 0.06)), Transform3D(Basis(), Vector3(cx, -0.16, z)), frame_steel, "", null, false)
	var rim := 0.14
	kit.block(Vector3(HATCH.position.x - rim, 0.0, HATCH.position.y - rim), Vector3(HATCH.end.x + rim, 0.02, HATCH.position.y), hazard)
	kit.block(Vector3(HATCH.position.x - rim, 0.0, HATCH.end.y), Vector3(HATCH.end.x + rim, 0.02, HATCH.end.y + rim), hazard)
	for side: float in [-1.0, 1.0]:
		var x0 := HATCH.end.x if side > 0.0 else HATCH.position.x - rim
		kit.block(Vector3(x0, 0.0, HATCH.position.y), Vector3(x0 + rim, 0.02, HATCH.end.y), hazard)
	# The hatch coaming is bolted down, the leaves hinged on bolted straps.
	for x: float in [HATCH.position.x - rim * 0.5, HATCH.end.x + rim * 0.5]:
		_bolt_line(Vector3(x, 0.02, HATCH.position.y - rim * 0.5), Vector3(x, 0.02, HATCH.end.y + rim * 0.5), Vector3.UP, bolt_steel, 0.3)
	for z: float in [HATCH.position.y - rim * 0.5, HATCH.end.y + rim * 0.5]:
		_bolt_line(Vector3(HATCH.position.x, 0.02, z), Vector3(HATCH.end.x, 0.02, z), Vector3.UP, bolt_steel, 0.3)
	fittings.append(ShipParts.hold_net(kit, 2.72, Rect2(-1.9, 1.95, 3.8, 4.2)))
	for z: float in [2.7, 5.0]:
		ShipParts.lamp(kit, Vector3(0, 2.86, z), 1.6, Vector3.RIGHT, "cold", 1.5, 7.0)


func _build_bulkhead_door() -> void:
	var h := DOOR.size.y - 0.02
	var w := DOOR.size.x + 0.02
	var win := Rect2(-0.25, 1.2, 0.5, 0.55)
	kit.wall("z", Z_BULK, -w * 0.5, w * 0.5, 0.0, h, 0.06, [win], shell)
	kit.add(PartShapes.box(Vector3(win.size.x, win.size.y, 0.02)), Transform3D(Basis(), Vector3(0, win.get_center().y, Z_BULK)),
			glass, "", null, false)
	for s: float in [-1.0, 1.0]:
		kit.add(PartShapes.box(Vector3(w - 0.1, 0.12, 0.01)), Transform3D(Basis(), Vector3(0, 0.6, Z_BULK + s * 0.035)),
				trim_paint, "", null, false)
		kit.add(PartShapes.box(Vector3(0.012, h - 0.3, 0.012)), Transform3D(Basis(), Vector3(w * 0.5 - 0.05, h * 0.5, Z_BULK + s * 0.036)),
				edge_glow, "", null, false)
	for s: float in [-1.0, 1.0]:
		var z := Z_BULK + s * (BULK_T * 0.5 + 0.01)
		kit.add(PartShapes.box(Vector3(DOOR.size.x + 0.16, 0.08, 0.02)), Transform3D(Basis(), Vector3(0, DOOR.end.y + 0.04, z)), dark, "", null, false)
		for x: float in [DOOR.position.x - 0.04, DOOR.end.x + 0.04]:
			kit.add(PartShapes.box(Vector3(0.08, DOOR.size.y, 0.02)), Transform3D(Basis(), Vector3(x, DOOR.size.y * 0.5, z)), dark, "", null, false)
			# The portal frame is bolted through the bulkhead.
			_bolt_line(Vector3(x, 0.15, z + s * 0.01), Vector3(x, DOOR.size.y - 0.1, z + s * 0.01), Vector3(0, 0, s), bolt_steel, 0.4)
		kit.add(PartShapes.box(Vector3(DOOR.size.x, 0.012, 0.012)), Transform3D(Basis(), Vector3(0, DOOR.end.y + 0.005, z + s * 0.012)),
				edge_glow, "", null, false)


# --- Side door -----------------------------------------------------------------------------

func _build_side_door() -> void:
	var door_w := LOCK_DOOR.y - LOCK_DOOR.x
	var door_z := (LOCK_DOOR.x + LOCK_DOOR.y) * 0.5
	var gap_x := -(IN + 0.18)
	kit.add(PartShapes.box(Vector3(0.05, LOCK_DOOR_TOP - 0.02, door_w + 0.02)), Transform3D(Basis(),
			Vector3(gap_x, (LOCK_DOOR_TOP - 0.02) * 0.5, door_z)), dark)
	kit.add(PartShapes.box(Vector3(0.01, 0.1, door_w - 0.1)), Transform3D(Basis(), Vector3(gap_x - 0.03, 1.5, door_z)),
			hazard, "", null, false)
	kit.add(PartShapes.box(Vector3(0.2, 0.04, door_w)), Transform3D(Basis(), Vector3(gap_x, LOCK_DOOR_TOP + 0.02, door_z)), lining)
	kit.add(PartShapes.box(Vector3(0.2, 0.02, door_w)), Transform3D(Basis(), Vector3(gap_x, 0.0 - 0.01, door_z)), floor_mat)
	kit.add(PartShapes.box(Vector3(0.2, LOCK_DOOR_TOP, 0.04)), Transform3D(Basis(), Vector3(gap_x, LOCK_DOOR_TOP * 0.5, LOCK_DOOR.x - 0.02)), lining)
	kit.add(PartShapes.box(Vector3(0.02, 0.06, door_w + 0.16)), Transform3D(Basis(), Vector3(-IN + 0.01, LOCK_DOOR_TOP + 0.08, door_z)),
			hazard, "", null, false)
	var pocket_z := LOCK_DOOR.y + door_w * 0.5 + 0.05
	_door_panel(Transform3D(Basis(), Vector3(-IN, 1.3, pocket_z)))
	_door_panel(Transform3D(Basis(Vector3.UP, PI), Vector3(-W, 1.3, pocket_z)))
	kit.add(PartShapes.box(Vector3(0.04, 0.06, door_w)), Transform3D(Basis(), Vector3(-W - 0.02, LOCK_DOOR_TOP + 0.12, door_z)),
			red, "", null, false)


# --- Stern and outside ---------------------------------------------------------------------

func _build_stern() -> void:
	var d := STERN_DOOR
	var split := d.position.y + d.size.y * 0.5
	var z := Z_STERN + 0.11
	for leaf: Array in [["stern_upper", split, d.end.y + 0.06], ["stern_lower", d.position.y - 0.05, split]]:
		var tag: String = leaf[0]
		var y0: float = leaf[1]
		var y1: float = leaf[2]
		var mid := (y0 + y1) * 0.5
		kit.add(PartShapes.chamfer_box(Vector3(d.size.x + 0.04, y1 - y0, 0.12), 0.03), Transform3D(Basis(), Vector3(0, mid, z)), dark)
		kit.add(PartShapes.inset_panel(d.size.x - 0.3, y1 - y0 - 0.25, 0.05, 0.08), Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
				Vector3(0, mid, z + 0.075)), shell, "", null, false)
		for x: float in [-d.size.x * 0.5 + 0.1, d.size.x * 0.5 - 0.1]:
			kit.add(PartShapes.box(Vector3(0.14, y1 - y0 - 0.1, 0.01)), Transform3D(Basis(), Vector3(x, mid, z + 0.065)), hazard, "", null, false)
		var seam := split + (0.02 if tag == "stern_upper" else -0.02)
		kit.add(PartShapes.box(Vector3(d.size.x - 0.2, 0.02, 0.012)), Transform3D(Basis(), Vector3(0, seam, z + 0.066)),
				edge_glow, "", null, false)
		# The leaf's hinge straps, bolted on.
		var hinge_y := y1 - 0.12 if tag == "stern_upper" else y0 + 0.12
		for x: float in [-1.0, 1.0]:
			kit.add(PartShapes.box(Vector3(0.16, 0.18, 0.02)), Transform3D(Basis(), Vector3(x, hinge_y, z + 0.07)), frame_steel, "", null, false)
			for bx: float in [-0.05, 0.05]:
				_bolt(Vector3(x + bx, hinge_y, z + 0.08), Vector3.BACK, bolt_steel)
	var fx := d.size.x * 0.5
	kit.block(Vector3(-fx - 0.1, d.end.y + 0.06, Z_STERN), Vector3(fx + 0.1, d.end.y + 0.2, Z_STERN + 0.06), trim_paint)
	var emit := ShipKit.glow(Color(0.25, 0.6, 1.0), 2.5)
	kit.add(PartShapes.box(Vector3(d.size.x, 0.06, 0.05)), Transform3D(Basis(), Vector3(0, d.end.y - 0.05, Z_STERN - 0.12)),
			emit, "", null, false)
	for side: float in [-1.0, 1.0]:
		kit.add(PartShapes.box(Vector3(0.05, d.size.y - 0.15, 0.05)), Transform3D(Basis(),
				Vector3(side * (fx - 0.04), d.get_center().y, Z_STERN - 0.12)), emit, "", null, false)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 2.1, 1.25, 0)
		var aft := Basis(Vector3.RIGHT, PI * 0.5)
		# The mounting flange the engine bolts to (the ship's half of the joint: it stays
		# when the engine comes off). The engine's own bolts are the bay's fastener heads.
		kit.add(PartShapes.chamfer_box(Vector3(FLANGE.x, FLANGE.y, FLANGE_T), 0.015),
				Transform3D(Basis(), at + Vector3(0, 0, Z_STERN + FLANGE_T * 0.5)), frame_steel, "", null, false)
		kit.add(PartShapes.chamfer_box(Vector3(0.86, 0.95, 0.8), 0.12), Transform3D(Basis(), at + Vector3(0, 0, Z_STERN + 0.4)), shell)
		kit.add(PartShapes.box(Vector3(0.88, 0.08, 0.6)), Transform3D(Basis(), at + Vector3(0, 0.3, Z_STERN + 0.42)), trim_paint, "", null, false)
		kit.add(PartShapes.ring(0.32, 0.4, 0.12), Transform3D(aft, at + Vector3(0, 0, Z_STERN + 0.86)), frame_steel)
		kit.add(PartShapes.nozzle(0.26, 0.4, 0.7, 0.05), Transform3D(aft, at + Vector3(0, 0, Z_STERN + 1.2)), frame_steel)
		kit.add(PartShapes.box(Vector3(0.04, 0.04, 0.04)), Transform3D(Basis(), at + Vector3(0, 0, Z_STERN + 1.0)),
				ShipKit.glow(Color(1.0, 0.5, 0.15), 1.0), "", null, false)


func _build_exterior() -> void:
	_fuel_port(Transform3D(Basis(), Vector3(W, 1.3, FUEL_PORT_Z)))
	fittings.append(ShipParts.name_board(kit, Transform3D(Basis(), Vector3(W, 1.85, 2.75)), "KESTREL", 1.5, 0.3))
	fittings.append(ShipParts.name_board(kit, Transform3D(Basis(Vector3.UP, PI), Vector3(-W, 1.85, 5.0)), "KESTREL", 1.5, 0.3))
	for side: float in [-1.0, 1.0]:
		kit.add(PartShapes.box(Vector3(0.02, 0.03, Z_STERN - Z_COCKPIT - 0.3)), Transform3D(Basis(),
				Vector3(side * (W + 0.01), SHOULDER - 0.06, (Z_STERN + Z_COCKPIT) * 0.5)), edge_glow, "", null, false)
		for sp: Array in _skirt_spans(side):
			var length: float = sp[1] - sp[0]
			var mid: float = (sp[0] + sp[1]) * 0.5
			kit.add(PartShapes.box(Vector3(0.02, 0.55, length)), Transform3D(Basis(), Vector3(side * (W + 0.01), CHINE + 0.275, mid)), dark)
			kit.add(PartShapes.box(Vector3(0.02, 0.08, length)), Transform3D(Basis(), Vector3(side * (W + 0.012), CHINE + 0.6, mid)),
					trim_paint, "", null, false)
		for z: float in [-0.5, 1.5, 4.0]:
			kit.add(PartShapes.box(Vector3(0.01, SHOULDER - CHINE - 0.75, 0.02)), Transform3D(Basis(),
					Vector3(side * (W + 0.005), (CHINE + 0.66 + SHOULDER - 0.08) * 0.5, z)), dark, "", null, false)
		kit.add(PartShapes.inset_panel(0.55, 0.7, 0.04, 0.06), Transform3D(Basis(Vector3.BACK, -side * PI * 0.5),
				Vector3(side * (W + 0.02), 1.15, 0.5)), dark)
		kit.add(PartShapes.box(Vector3(0.012, 0.05, 0.6)), Transform3D(Basis(), Vector3(side * (W + 0.045), 1.47, 0.5)), hazard, "", null, false)
		# The service hatch's quick-release bolts.
		for c: Vector2 in [Vector2(-0.22, -0.3), Vector2(0.22, -0.3), Vector2(-0.22, 0.3), Vector2(0.22, 0.3)]:
			_bolt(Vector3(side * (W + 0.04), 1.15 + c.y, 0.5 + c.x), Vector3(side, 0, 0), bolt_steel)
		for z: float in [-1.6, 5.2]:
			var at := Vector3(side * 1.55, BELLY - 0.16, z)
			kit.add(PartShapes.chamfer_box(Vector3(0.7, 0.3, 0.9), 0.07), Transform3D(Basis(), at), dark)
			kit.add(PartShapes.box(Vector3(0.6, 0.06, 0.02)), Transform3D(Basis(), at + Vector3(0, -0.05, -0.46)), red, "", null, false)
			# Each skid's mounting plate, bolted to the belly.
			kit.add(PartShapes.box(Vector3(0.82, 0.02, 1.02)), Transform3D(Basis(), Vector3(at.x, BELLY - 0.01, z)), frame_steel, "", null, false)
			for c: Vector2 in [Vector2(-0.36, -0.46), Vector2(0.36, -0.46), Vector2(-0.36, 0.46), Vector2(0.36, 0.46), Vector2(-0.36, 0), Vector2(0.36, 0)]:
				_bolt(Vector3(at.x + c.x, BELLY - 0.02, z + c.y), Vector3.DOWN, bolt_steel)
		for z: float in [-0.4, 3.0]:
			kit.add(PartShapes.nozzle(0.08, 0.14, 0.22), Transform3D(Basis(Vector3.RIGHT, PI), Vector3(side * 1.9, BELLY - 0.12, z)),
					frame_steel, "", null, false)
		for z: float in [-1.8, 5.9]:
			var q := Vector3(side * (W + 0.1), 2.25, z)
			kit.add(PartShapes.chamfer_box(Vector3(0.2, 0.36, 0.36), 0.04), Transform3D(Basis(), q), dark)
			kit.add(PartShapes.nozzle(0.05, 0.09, 0.14), Transform3D(Basis(Vector3.BACK, -side * PI * 0.5), q + Vector3(side * 0.14, 0, 0)),
					frame_steel, "", null, false)
			for c: Vector2 in [Vector2(-0.14, -0.14), Vector2(0.14, -0.14), Vector2(-0.14, 0.14), Vector2(0.14, 0.14)]:
				_bolt(Vector3(q.x + side * 0.1, q.y + c.y, z + c.x), Vector3(side, 0, 0), bolt_steel)
	kit.add(PartShapes.inset_panel(1.6, 2.4, 0.06, 0.1), Transform3D(Basis(), Vector3(0, ROOF + 0.03, 3.6)), dark)
	for x: float in [-0.75, 0.75]:
		_bolt_line(Vector3(x, ROOF + 0.06, 2.45), Vector3(x, ROOF + 0.06, 4.75), Vector3.UP, bolt_steel, 0.38)
	kit.add(PartShapes.louvre(1.0, 0.8, 0.08, 5), Transform3D(Basis(), Vector3(-0.9, ROOF + 0.04, 0.4)), dark)
	kit.add(PartShapes.prism(6, 0.03, 1.1), Transform3D(Basis(), Vector3(1.3, ROOF + 0.55, 5.6)), dark, "", null, false)
	kit.add(PartShapes.frustum(0.1, 0.05, 0.1, 8), Transform3D(Basis(), Vector3(1.3, ROOF + 0.05, 5.6)), dark, "", null, false)
	for n: Array in [[Vector3(-W - 0.03, SHOULDER + 0.05, -2.2), Color(1, 0.1, 0.05)],
			[Vector3(W + 0.03, SHOULDER + 0.05, -2.2), Color(0.1, 1, 0.2)], [Vector3(0, ROOF + 0.03, Z_STERN - 0.2), Color(1, 1, 1)]]:
		kit.add(PartShapes.dome(0.06, 0.06, 10, 3), Transform3D(Basis(), n[0]), ShipKit.glow(n[1], 4.0), "", null, false)


static func _skirt_spans(side: float) -> Array:
	if side < 0.0:
		return [[Z_COCKPIT + 0.02, LOCK_DOOR.x - 0.08], [LOCK_DOOR.y + 0.08, Z_STERN - 0.02]]
	return [[Z_COCKPIT + 0.02, Z_STERN - 0.02]]


# --- Screens and panels (dressing: the ship's systems aren't running in the yard) ----------

func _label(text: String, xform: Transform3D, size: int, color: Color, top_left := false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = ShipKit.mono_font()
	label.font_size = size
	label.pixel_size = 0.0015
	label.modulate = color
	label.outline_size = 0
	if top_left:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.transform = xform
	add_child(label)
	return label


## Text on a panel face: `at` in the frame's space, facing along its X.
func _panel_label(text: String, frame: Transform3D, at: Vector3, size: int, color: Color) -> Label3D:
	var l := _label(text, frame * Transform3D(Basis(Vector3.UP, PI * 0.5), at), size, color)
	l.pixel_size = 0.0016
	return l


func _panel_box(frame: Transform3D, at: Vector3, size: Vector3, mat: Material, solid: bool) -> void:
	kit.add(PartShapes.box(size), frame * Transform3D(Basis(), at), mat, "", null, solid)


## A console screen at `at` tilted back `tilt_deg`, with its text.
func _tilted_screen(at: Vector3, tilt_deg: float, size: Vector2, text: String, color: Color) -> void:
	var b := Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg))
	kit.add(PartShapes.box(Vector3(size.x + 0.04, size.y + 0.04, 0.03)), Transform3D(b, at), hull_dark, "", null, false)
	kit.add(PartShapes.box(Vector3(size.x, size.y, 0.004)), Transform3D(b, at + b * Vector3(0, 0, 0.016)),
			ShipParts.mat("screen"), "", null, false)
	var l := _label(text, Transform3D(b, at + b * Vector3(-size.x * 0.46, size.y * 0.45, 0.02)), 22, color, true)
	l.line_spacing = -3.0
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_bolt(at + b * Vector3(c.x * (size.x * 0.5 + 0.005), c.y * (size.y * 0.5 + 0.005), 0.015), b.z, bolt_steel)


## A door's panel: OPEN and CLOSE buttons under a status lamp.
func _door_panel(frame: Transform3D) -> void:
	_panel_box(frame, Vector3(0.02, 0, 0), Vector3(0.04, 0.5, 0.26), hull_dark, true)
	_panel_box(frame, Vector3(0.027, 0.27, 0), Vector3(0.02, 0.04, 0.26), hazard, false)
	_panel_box(frame, Vector3(0.042, 0.2, 0), Vector3(0.008, 0.03, 0.12), ShipKit.glow(Color(0.3, 1.0, 0.45), 0.8), false)
	for b: Array in [["OPEN", Color(0.3, 1.0, 0.45), 0.08], ["CLOSE", Color(1.0, 0.3, 0.2), -0.12]]:
		_panel_box(frame, Vector3(0.05, b[2], 0), Vector3(0.025, 0.1, 0.1), ShipKit.glow(b[1], 1.2), false)
		_panel_label(b[0], frame, Vector3(0.042, b[2] - 0.075, 0), 18, Color(0.85, 0.92, 1.0))
	for c: Vector2 in [Vector2(-0.1, -0.21), Vector2(0.1, -0.21), Vector2(-0.1, 0.21), Vector2(0.1, 0.21)]:
		_bolt(frame * Vector3(0.04, c.y, c.x), frame.basis.x, bolt_steel)


## A screen with a bezel on a surface; returns its text, top left aligned.
func _screen(frame: Transform3D, at: Vector3, size: Vector2, font_size: int, text: String) -> void:
	var bezel := ShipKit.paint(Color(0.32, 0.34, 0.36), 0.7, 0.35)
	_panel_box(frame, at + Vector3(0.015, 0.0, 0.0), Vector3(0.03, size.y + 0.05, size.x + 0.05), bezel, false)
	_panel_box(frame, at + Vector3(0.032, 0.0, 0.0), Vector3(0.004, size.y, size.x), ShipKit.glow(Color(0.02, 0.07, 0.1), 1.0), false)
	var label := _panel_label(text, frame, at + Vector3(0.036, size.y * 0.5 - 0.015, size.x * 0.5 - 0.02), font_size,
			Color(0.45, 0.95, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP


## The hold monitor: bezel, screen and six soft keys.
func _monitor(frame: Transform3D, screen: Vector2) -> void:
	var keys_y := -screen.y * 0.5 - 0.1
	_panel_box(frame, Vector3(0.04, -0.075, 0.0), Vector3(0.08, screen.y + 0.3, screen.x + 0.08), hull_dark, true)
	_panel_box(frame, Vector3(0.085, 0.0, 0.0), Vector3(0.01, screen.y, screen.x), ShipKit.glow(Color(0.01, 0.04, 0.06), 0.4), false)
	_panel_box(frame, Vector3(0.082, screen.y * 0.5 + 0.012, 0.0), Vector3(0.006, 0.006, screen.x), ShipKit.glow(ShipParts.EDGE, 1.2), false)
	var text := _panel_label("HOLD MONITOR\n\nHOLD      0 kg\nSTERN     SHUT\nHATCH     SHUT\nBAY       BSX LTD", frame,
			Vector3(0.091, screen.y * 0.5 - 0.06, screen.x * 0.5 - 0.06), 30, ShipParts.SCREEN)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var keys: Array[String] = ["<", ">", "^", "v", "MARK", "F"]
	var spacing := minf(0.2, screen.x / 7.0)
	for i in keys.size():
		var z := screen.x * 0.5 - 0.12 - float(i) * spacing
		if i == keys.size() - 1:
			z = -screen.x * 0.5 + 0.12
		_panel_box(frame, Vector3(0.095, keys_y, z), Vector3(0.03, 0.07, 0.13), ShipKit.glow(Color(0.08, 0.32, 0.4), 0.6), false)
		_panel_label(keys[i], frame, Vector3(0.112, keys_y, z), 22 if keys[i].length() < 3 else 16, ShipParts.SCREEN)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_bolt(frame * Vector3(0.08, -0.075 + c.y * (screen.y * 0.5 + 0.12), c.x * (screen.x * 0.5 + 0.01)), frame.basis.x, bolt_steel)


func _control_panel(frame: Transform3D, title: String, buttons: Array) -> void:
	var count := buttons.size()
	var length := 0.36 * float(count) + 0.15
	_panel_box(frame, Vector3(0.03, 0, 0), Vector3(0.06, 0.78, length), hull_dark, true)
	_panel_box(frame, Vector3(0.04, 0.44, 0), Vector3(0.02, 0.1, length), hazard, false)
	_panel_label(title, frame, Vector3(0.063, 0.295, 0), 30, Color(0.95, 0.75, 0.3))
	for i in count:
		var b: Array = buttons[i]
		var bz := (float(count - 1) * 0.5 - float(i)) * 0.36
		_panel_box(frame, Vector3(0.0675, 0.03, bz), Vector3(0.015, 0.22, 0.22), ShipKit.paint(Color(0.1, 0.1, 0.11), 0.6, 0.4), false)
		_panel_box(frame, Vector3(0.08, 0.03, bz), Vector3(0.04, 0.16, 0.16), ShipKit.glow(b[1], 1.2), false)
		_panel_label(b[0], frame, Vector3(0.063, -0.14, bz), 24, Color(0.85, 0.92, 1.0))
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_bolt(frame * Vector3(0.06, c.y * 0.34, c.x * (length * 0.5 - 0.04)), frame.basis.x, bolt_steel)


## The fuel and coolant bowsers with their manifold (`frame` on the wall, X into the room).
func _bowsers(frame: Transform3D) -> void:
	var steel := ShipKit.paint(Color(0.55, 0.57, 0.6), 0.7, 0.4)
	var tank_dark := ShipKit.paint(Color(0.18, 0.19, 0.21), 0.5, 0.6)
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)
	var out_x := Basis(Vector3.BACK, -PI * 0.5)
	kit.add(PartShapes.chamfer_box(Vector3(0.24, 0.42, 0.42), 0.03), frame * Transform3D(Basis(), Vector3(0.14, 0.42, 0.0)), steel)
	kit.add(PartShapes.prism(10, 0.06, 0.12), frame * Transform3D(along_z, Vector3(0.1, 0.32, -0.26)), tank_dark, "", null, false)
	_panel_box(frame, Vector3(0.27, 0.48, 0.075), Vector3(0.04, 0.11, 0.11), ShipKit.glow(Color(0.35, 1.0, 0.6), 0.6), true)
	_panel_label("PUMP", frame, Vector3(0.262, 0.58, 0.075), 18, Color(0.85, 0.92, 1.0))
	_panel_box(frame, Vector3(0.27, 0.48, -0.075), Vector3(0.04, 0.11, 0.11), ShipKit.glow(Color(1.0, 0.65, 0.15), 0.6), true)
	_panel_label("TANK", frame, Vector3(0.262, 0.58, -0.075), 18, Color(1.0, 0.8, 0.45))
	_panel_label("MANIFOLD", frame, Vector3(0.262, 0.27, 0.0), 16, Color(0.85, 0.92, 1.0))
	_screen(frame, Vector3(0.0, 1.05, 0.0), Vector2(0.5, 0.24), 16, "PUMP OFF\nHOSE ON RACK")
	var tanks: Array = [["fuel", 1.05, hazard, Color(1.0, 0.65, 0.15), 0.25, 0.35],
			["coolant", 2.25, ShipKit.paint(Color(0.22, 0.52, 0.66), 0.35, 0.5), Color(0.35, 0.85, 1.0), 0.55, 0.6]]
	for t: Array in tanks:
		var z: float = t[1]
		var pipe_y: float = t[4]
		var at := Vector3(0.72, 0.0, z)
		kit.add(PartShapes.prism(20, 0.56, 0.14), frame * Transform3D(Basis(), at + Vector3(0, 0.07, 0)), tank_dark)
		kit.add(PartShapes.prism(20, 0.5, 2.2), frame * Transform3D(Basis(), at + Vector3(0, 1.24, 0)), t[2])
		kit.add(PartShapes.dome(0.5, 0.22, 20, 4), frame * Transform3D(Basis(), at + Vector3(0, 2.34, 0)), t[2], "", null, false)
		kit.add(PartShapes.ring(0.5, 0.52, 0.08), frame * Transform3D(Basis(), at + Vector3(0, 2.05, 0)), tank_dark, "", null, false)
		# The footing's hold-down bolts round the drum.
		for k in 8:
			var a := TAU * (float(k) + 0.5) / 8.0
			_bolt(frame * (at + Vector3(cos(a) * 0.53, 0.14, sin(a) * 0.53)), frame.basis.y, bolt_steel)
		var run := z - 0.2
		kit.add(PartShapes.prism(10, 0.045, run), frame * Transform3D(along_z, Vector3(0.07, pipe_y, 0.2 + run * 0.5)), steel, "", null, false)
		kit.add(PartShapes.prism(10, 0.045, 0.18), frame * Transform3D(out_x, Vector3(0.14, pipe_y, z)), steel, "", null, false)
		kit.add(PartShapes.prism(10, 0.05, 0.06), frame * Transform3D(along_z, Vector3(0.07, pipe_y, 0.32)),
				ShipKit.glow(t[3], 0.8), "", null, false)
		var face := 0.72 + 0.5
		var low := 0.45
		var high := 2.0
		_panel_box(frame, Vector3(face, (low + high) * 0.5, z), Vector3(0.04, high - low + 0.12, 0.17), tank_dark, false)
		_panel_box(frame, Vector3(face + 0.021, (low + high) * 0.5, z), Vector3(0.004, high - low, 0.08),
				ShipKit.glow(Color(0.02, 0.03, 0.04), 1.0), false)
		for k in 5:
			var y := lerpf(low, high, float(k) / 4.0)
			_panel_box(frame, Vector3(face + 0.023, y, z + 0.065), Vector3(0.003, 0.008, 0.035 if k % 2 == 0 else 0.022), white, false)
		var level: float = t[5]
		_panel_box(frame, Vector3(face + 0.025, low + (high - low) * level * 0.5, z), Vector3(0.006, (high - low) * level, 0.06),
				ShipKit.glow(t[3], 0.8), false)
		_panel_label((t[0] as String).to_upper(), frame, Vector3(face + 0.022, high + 0.17, z), 40, t[3])


func _hose_rack(frame: Transform3D) -> void:
	var rack_dark := ShipKit.paint(Color(0.2, 0.21, 0.23), 0.6, 0.5)
	var hose := ShipKit.paint(Color(0.1, 0.1, 0.11), 0.0, 0.85)
	_panel_box(frame, Vector3(0.015, 0.0, 0.0), Vector3(0.03, 0.9, 0.9), hull_dark, true)
	for z: float in [-0.22, 0.22]:
		_panel_box(frame, Vector3(0.17, 0.34, z), Vector3(0.3, 0.05, 0.05), rack_dark, true)
		_panel_box(frame, Vector3(0.3, 0.38, z), Vector3(0.04, 0.1, 0.05), rack_dark, false)
	# The coil hanging on its hooks.
	kit.add(PartShapes.ring(0.22, 0.34, 0.12, 24), frame * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.2, 0.05, 0.0)), hose, "", null, false)
	_panel_box(frame, Vector3(0.035, -0.3, 0.0), Vector3(0.012, 0.08, 0.9), hazard, false)
	_panel_label("FUEL HOSE", frame, Vector3(0.033, -0.38, 0.0), 20, Color(1.0, 0.75, 0.3))
	for c: Vector2 in [Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
		_bolt(frame * Vector3(0.03, c.y, c.x), frame.basis.x, bolt_steel)


func _fuel_port(frame: Transform3D) -> void:
	var port_dark := ShipKit.paint(Color(0.12, 0.13, 0.14), 0.6, 0.5)
	var brass := ShipKit.paint(Color(0.75, 0.55, 0.28), 0.9, 0.3)
	var face := Basis(Vector3.BACK, -PI * 0.5)
	_panel_box(frame, Vector3(0.03, 0.0, 0.3), Vector3(0.06, 0.95, 1.25), port_dark, true)
	_panel_box(frame, Vector3(0.065, 0.45, 0.3), Vector3(0.01, 0.04, 1.25), hazard, false)
	kit.add(PartShapes.ring(0.065, 0.1, 0.12), frame * Transform3D(face, Vector3(0.1, 0.0, 0.0)), brass)
	kit.add(PartShapes.prism(16, 0.065, 0.02), frame * Transform3D(face, Vector3(0.06, 0.0, 0.0)), port_dark, "", null, false)
	kit.add(PartShapes.ring(0.105, 0.118, 0.02), frame * Transform3D(face, Vector3(0.065, 0.0, 0.0)),
			ShipKit.glow(Color(1.0, 0.7, 0.25), 2.0), "", null, false)
	_panel_label("FUEL", frame, Vector3(0.063, 0.16, 0.0), 24, Color(1.0, 0.75, 0.3))
	_screen(frame, Vector3(0.06, 0.17, 0.6), Vector2(0.5, 0.24), 16, "PUMP OFF")
	_panel_box(frame, Vector3(0.08, -0.2, 0.74), Vector3(0.04, 0.12, 0.12), ShipKit.glow(Color(0.35, 1.0, 0.6), 0.6), true)
	_panel_label("PUMP", frame, Vector3(0.063, -0.31, 0.74), 18, Color(0.85, 0.92, 1.0))
	_panel_box(frame, Vector3(0.068, -0.2, 0.47), Vector3(0.016, 0.16, 0.09), hull_dark, true)
	var pivot := Vector3(0.075, -0.2, 0.47)
	var up := Basis(Vector3.BACK, 0.6)
	kit.add(PartShapes.box(Vector3(0.11, 0.022, 0.022)), frame * Transform3D(up, pivot) * Transform3D(Basis(), Vector3(0.055, 0, 0)),
			ShipKit.paint(Color(0.7, 0.72, 0.74), 0.8, 0.3), "", null, false)
	kit.add(PartShapes.box(Vector3(0.035, 0.035, 0.035)), frame * Transform3D(up, pivot) * Transform3D(Basis(), Vector3(0.115, 0, 0)),
			hazard, "", null, false)
	_panel_label("IN", frame, Vector3(0.063, -0.065, 0.47), 18, Color(0.85, 0.92, 1.0))
	_panel_label("OUT", frame, Vector3(0.063, -0.335, 0.47), 18, Color(0.85, 0.92, 1.0))
	for c: Vector2 in [Vector2(-0.3, -0.44), Vector2(0.9, -0.44), Vector2(-0.3, 0.44), Vector2(0.9, 0.44), Vector2(0.3, -0.44)]:
		_bolt(frame * Vector3(0.06, c.y, c.x), frame.basis.x, bolt_steel)


# --- Rivets and bolts ----------------------------------------------------------------------

func _rivet(at: Vector3, normal: Vector3, mat: Material) -> void:
	(rivets.get_or_add(mat, []) as Array).append(_head_xform(at, normal))


func _bolt(at: Vector3, normal: Vector3, mat: Material) -> void:
	(bolts.get_or_add(mat, []) as Array).append(_head_xform(at, normal))


## A head's frame: Y out of the surface at `at`, turned a little at random (seeded by place).
static func _head_xform(at: Vector3, normal: Vector3) -> Transform3D:
	var n := normal.normalized()
	var side := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := side.cross(n).normalized()
	var b := Basis(x, n, x.cross(n))
	var spin := fmod(absf(at.x * 13.1 + at.y * 7.3 + at.z * 3.7), TAU)
	return Transform3D(b * Basis(Vector3.UP, spin), at)


## Rivets from `a` to `b` at about `pitch` apart, ends included; `keep(p)` drops some.
func _rivet_line(a: Vector3, b: Vector3, normal: Vector3, mat: Material, keep := Callable(), pitch := RIVET_PITCH) -> void:
	var n := maxi(1, roundi(a.distance_to(b) / pitch))
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		if not keep.is_valid() or keep.call(p):
			_rivet(p, normal, mat)


func _bolt_line(a: Vector3, b: Vector3, normal: Vector3, mat: Material, pitch := BOLT_PITCH) -> void:
	var n := maxi(1, roundi(a.distance_to(b) / pitch))
	for i in n + 1:
		_bolt(a.lerp(b, float(i) / float(n)), normal, mat)


## Rivets round a flat plate's outline (outer face corners in order), `inset` in from its edges.
func _plate_rivets(corners: Array[Vector3], outward: Vector3, mat: Material, inset := 0.05, keep := Callable()) -> void:
	var c := Vector3.ZERO
	for p in corners:
		c += p
	c /= float(corners.size())
	var n := (corners[1] - corners[0]).cross(corners[2] - corners[0]).normalized()
	if n.dot(outward) < 0.0:
		n = -n
	var pts: Array[Vector3] = []
	for p in corners:
		var d := c - p
		pts.append(p + d.normalized() * minf(inset * 1.41, d.length() * 0.5))
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		if a.distance_to(b) < 0.08:
			continue
		var count := maxi(1, roundi(a.distance_to(b) / RIVET_PITCH))
		for k in count:
			var p := a.lerp(b, float(k) / float(count))
			if not keep.is_valid() or keep.call(p):
				_rivet(p, n, mat)


func _rivet_hull() -> void:
	# The skin plates HullBuilder laid: roof, shoulders and lower chamfers.
	var outline := profile()
	for seg in STATIONS.size() - 1:
		for e: int in [0, 1, 3, 5, 7]:
			var mat := trim_paint if e in [1, 7] else shell
			_plate_rivets(_quad(outline, outline, STATIONS[seg], STATIONS[seg + 1], e), _out(outline, e), mat)
	# The canopy's painted plates (the glass is held by its frames).
	for seg in NOSE_STATIONS.size() - 1:
		var pa := nose_profile(seg)
		var pb := nose_profile(seg + 1)
		for e in pa.size():
			if not _canopy_glazed(seg, e):
				_plate_rivets(_quad(pa, pb, NOSE_STATIONS[seg], NOSE_STATIONS[seg + 1], e), _out(pa, e), shell)
	# The flanks: double rows down each frame, along the top and over the skirt, clear of the
	# windows, the side door and what's fitted outside.
	for side: float in [-1.0, 1.0]:
		var x := side * W
		var n := Vector3(side, 0, 0)
		var clear := _flank_keep(side)
		for z: float in [Z_COCKPIT + 0.05, -0.55, -0.45, 1.45, 1.55, 3.95, 4.05, Z_STERN - 0.05]:
			_rivet_line(Vector3(x, CHINE + 0.72, z), Vector3(x, SHOULDER - 0.05, z), n, shell, clear)
		_rivet_line(Vector3(x, SHOULDER - 0.12, Z_COCKPIT + 0.05), Vector3(x, SHOULDER - 0.12, Z_STERN - 0.05), n, shell, clear)
		_rivet_line(Vector3(x, CHINE + 0.72, Z_COCKPIT + 0.05), Vector3(x, CHINE + 0.72, Z_STERN - 0.05), n, shell, clear)
		for sp: Array in _skirt_spans(side):
			for y: float in [CHINE + 0.06, CHINE + 0.49]:
				_rivet_line(Vector3(side * (W + 0.02), y, sp[0] + 0.05), Vector3(side * (W + 0.02), y, sp[1] - 0.05), n, dark, Callable(), 0.25)
	# The belly: along its edges and across at the frames, clear of the hatch, skids and jets.
	var belly_keep := func(p: Vector3) -> bool:
		if Rect2(HATCH.position - Vector2(0.2, 0.2), HATCH.size + Vector2(0.4, 0.4)).has_point(Vector2(p.x, p.z)):
			return false
		for z: float in [-1.6, 5.2]:
			if absf(absf(p.x) - 1.55) < 0.45 and absf(p.z - z) < 0.55:
				return false
		for z: float in [-0.4, 3.0]:
			if absf(absf(p.x) - 1.9) < 0.2 and absf(p.z - z) < 0.2:
				return false
		return true
	var down := Vector3.DOWN
	for x: float in [-BOTTOM_X + 0.06, BOTTOM_X - 0.06]:
		_rivet_line(Vector3(x, BELLY, Z_COCKPIT + 0.05), Vector3(x, BELLY, Z_STERN - 0.1), down, floor_mat, belly_keep)
	for z: float in [Z_COCKPIT + 0.05, -0.55, -0.45, 1.45, 1.55, 3.95, 4.05, Z_STERN - 0.12]:
		_rivet_line(Vector3(-BOTTOM_X + 0.06, BELLY, z), Vector3(BOTTOM_X - 0.06, BELLY, z), down, floor_mat, belly_keep)
	# The stern cap round the door, clear of the engine flanges.
	var stern_keep := func(p: Vector3) -> bool:
		return absf(absf(p.x) - 2.1) > FLANGE.x * 0.5 + 0.04 or absf(p.y - 1.25) > FLANGE.y * 0.5 + 0.04
	for piece: PackedVector2Array in _stern_pieces():
		var corners: Array[Vector3] = []
		for p in piece:
			corners.append(Vector3(p.x, p.y, Z_STERN))
		_plate_rivets(corners, Vector3.BACK, dark, 0.06, stern_keep)
	# The engine flanges are riveted to the stern face round their edges.
	for side: float in [-1.0, 1.0]:
		var cx := side * 2.1
		var hx := FLANGE.x * 0.5 - 0.04
		var hy := FLANGE.y * 0.5 - 0.04
		var zf := Z_STERN + FLANGE_T
		var corners: Array[Vector3] = [Vector3(cx - hx, 1.25 - hy, zf), Vector3(cx + hx, 1.25 - hy, zf),
				Vector3(cx + hx, 1.25 + hy, zf), Vector3(cx - hx, 1.25 + hy, zf)]
		# Only up its sides: the engine's own bolts (the bay's fastener heads) take the top
		# and bottom edges.
		var sides_only := func(p: Vector3) -> bool:
			return absf(absf(p.x) - 2.1) > 0.44
		_plate_rivets(corners, Vector3.BACK, frame_steel, 0.0, sides_only)


## Where a flank rivet may go (outside the holes and what's fitted on that flank).
func _flank_keep(side: float) -> Callable:
	var keep_out: Array[Rect2] = [Rect2(WINDOW_Z - 0.6, 1.0, 1.2, 0.9), Rect2(0.15, 0.7, 0.7, 0.9),
			Rect2(-2.05, 1.95, 0.5, 0.6), Rect2(5.65, 1.95, 0.5, 0.6)]   # window, hatch, thrusters (z, y)
	if side < 0.0:
		keep_out.append(Rect2(LOCK_DOOR.x - 0.12, -1.0, LOCK_DOOR.y - LOCK_DOOR.x + 0.24, LOCK_DOOR_TOP + 1.2))
		keep_out.append(Rect2(4.15, 1.6, 1.7, 0.5))     # name board
		keep_out.append(Rect2(2.75, 1.0, 0.5, 0.6))     # door panel outside
	else:
		keep_out.append(Rect2(1.95, 1.6, 1.6, 0.5))     # name board
		keep_out.append(Rect2(4.5, 0.75, 1.4, 1.1))     # fuel port
	return func(p: Vector3) -> bool:
		for r in keep_out:
			if r.has_point(Vector2(p.z, p.y)):
				return false
		return true


## Bolt heads inside: the linings' panel seams, the deck plates and the fittings' feet.
func _bolt_inside() -> void:
	var cabin_z1 := Z_BULK - BULK_T * 0.5
	var hold_z0 := Z_BULK + BULK_T * 0.5
	for side: float in [-1.0, 1.0]:
		var x := side * IN
		var n := Vector3(-side, 0, 0)
		for span: Array in [[Z_COCKPIT + 0.1, cabin_z1 - 0.05], [hold_z0 + 0.05, Z_STERN - 0.12]]:
			for y: float in [0.16, CEIL - 0.08]:
				var z: float = span[0]
				while z <= span[1]:
					if not (side < 0.0 and z > LOCK_DOOR.x - 0.1 and z < LOCK_DOOR.y + 0.1):
						_bolt(Vector3(x, y, z), n, bolt_steel)
					z += BOLT_PITCH
	# Deck plates: seams across the floor at the frames and down each side.
	var floor_keep := func(p: Vector3) -> bool:
		return not Rect2(HATCH.position - Vector2(0.2, 0.2), HATCH.size + Vector2(0.4, 0.4)).has_point(Vector2(p.x, p.z))
	for z: float in [-0.5, 3.0, 4.0, 6.3]:
		var y := 0.0
		var a := Vector3(-IN + 0.15, y, z)
		var b := Vector3(IN - 0.15, y, z)
		var count := roundi(a.distance_to(b) / 0.3)
		for i in count + 1:
			var p := a.lerp(b, float(i) / float(count))
			if floor_keep.call(p):
				_bolt(p, Vector3.UP, bolt_steel)
	for x: float in [-1.15, 1.15]:
		var z := Z_COCKPIT + 0.7
		while z < Z_STERN - 0.2:
			if floor_keep.call(Vector3(x, 0, z)) and absf(z - Z_BULK) > 0.3:
				_bolt(Vector3(x, 0.0, z), Vector3.UP, bolt_steel)
			z += 0.6
	# Floor-standing fittings bolt down at their corners.
	for f in fittings:
		var box: AABB = f["box"]
		var foot := box.position.y
		if absf(foot) > 0.02 and absf(foot - DECK_UP) > 0.02:
			continue
		if box.size.x < 0.2 or box.size.z < 0.2:
			continue
		for c: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var p := Vector3(box.position.x - 0.03 + c.x * (box.size.x + 0.06), foot, box.position.z - 0.03 + c.y * (box.size.z + 0.06))
			if absf(p.x) < IN - 0.03 and _clear_of_cross_walls(p.z):
				_bolt(p, Vector3.UP, bolt_steel)


static func _clear_of_cross_walls(z: float) -> bool:
	return z > Z_COCKPIT + 0.1 and absf(z - Z_BULK) > BULK_T * 0.5 + 0.04 and z < Z_STERN - 0.12 \
			or z < Z_COCKPIT - 0.1 and z > Z_NOSE + 0.3


## A HullBuilder face's outer corners: profile edge `e` from station za to zb.
static func _quad(pa: PackedVector2Array, pb: PackedVector2Array, za: float, zb: float, e: int) -> Array[Vector3]:
	var n := pa.size()
	var out: Array[Vector3] = [Vector3(pa[e].x, pa[e].y, za), Vector3(pa[(e + 1) % n].x, pa[(e + 1) % n].y, za),
			Vector3(pb[(e + 1) % n].x, pb[(e + 1) % n].y, zb), Vector3(pb[e].x, pb[e].y, zb)]
	# A triangle (two corners meet): drop the repeat.
	for i in range(out.size() - 1, 0, -1):
		if out[i].distance_to(out[i - 1]) < 0.001:
			out.remove_at(i)
	return out


static func _out(profile_pts: PackedVector2Array, e: int) -> Vector3:
	var n := profile_pts.size()
	var c := Vector2.ZERO
	for p in profile_pts:
		c += p
	c /= float(n)
	var a := profile_pts[e]
	var b := profile_pts[(e + 1) % n]
	var d := b - a
	var nrm := Vector2(d.y, -d.x).normalized()
	if nrm.dot((a + b) * 0.5 - c) < 0.0:
		nrm = -nrm
	return Vector3(nrm.x, nrm.y, 0.0)


## One MultiMesh per head shape and material: domed rivets, hex bolts with a washer.
func _build_heads() -> void:
	var rivet_shape := PartShapes.dome(0.014, 0.009, 8, 2)
	for mat: Material in rivets:
		_multimesh("Rivets", rivet_shape.mesh, mat, rivets[mat], Vector3(0, 0.0045, 0))
	var hex := PartShapes.prism(6, 0.017, 0.014)
	var washer := PartShapes.prism(12, 0.024, 0.004)
	for mat: Material in bolts:
		_multimesh("BoltWashers", washer.mesh, mat, bolts[mat], Vector3(0, 0.002, 0))
		_multimesh("BoltHeads", hex.mesh, mat, bolts[mat], Vector3(0, 0.011, 0))


func _multimesh(node_name: String, mesh: Mesh, mat: Material, xforms: Array, lift: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		var t: Transform3D = xforms[i]
		mm.set_instance_transform(i, t * Transform3D(Basis(), lift))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = ShipSurface.of(mat)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi, true)
