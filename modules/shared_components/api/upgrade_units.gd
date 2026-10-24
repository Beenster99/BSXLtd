class_name UpgradeUnits
extends RefCounted
## The units BSX builds for Component Upgrades (stage U1) and the add-ons that go inside
## them, as parts and joints on a ShipKit with a model (the bay's rigs, the bench, the
## ship). The attractor coil comes at three tiers (UpgradeRules: Mk I to III, each bigger,
## all inside Void Salvage's 1.4 x 0.3 x 0.4 m slot box, horns and all): a tray housing with
## the copper windings along it round an open bore, a bolted and tack-welded cover over it,
## and three internal mount points the cover hides: the coil bay (a quantum core slides into
## the bore), the emitter flange on the front face (a field emitter array's horns weld on)
## and the cable harness in the bay at the right-hand end (the control board wires in).
## Everything is Void Salvage shapes and
## paints; nothing here is synced (every machine builds the same from the same ids).
##
## Unit space: x along the unit (the coil's axis; the harness bay at +x), y up (the cover on
## top), -z the front (the emitter end).
## `attractor_coil` returns {name, unit, family, tier, display_name, part, cover, bolts,
## tacks, xform, box (unit space), mounts: [{id, display_name, trade, accepts, at, normal}]};
## `fit_addon` puts an add-on on one of those mounts and joins it by the mount's trade.

## Part names (Void Salvage's PartCatalog sorts unknown names by word rules).
const UNIT_PART := "AttractorCoil"
const COVER_PART := "AttractorCoilCover"
const ADDON_PARTS := {"quantum_core": "QuantumCore", "field_emitter": "FieldEmitter", "control_board": "ControlBoard"}
## Sheet thickness of the housing's tray and cover, metres.
const SHEET := 0.02
const COVER := 0.03
## The gap kept between parts' collision, metres.
const GAP := 0.005
## The open bore the windings leave down the middle, radius in metres (every tier).
const BORE := 0.05
## Windings per tier.
const TURNS: PackedInt32Array = [0, 8, 12, 16]
## A quantum core's radius and length per tier, metres (Q1 to Q3: wider and longer each tier).
const CORE_RADIUS: PackedFloat32Array = [0.0, 0.024, 0.034, 0.044]
const CORE_LENGTH: PackedFloat32Array = [0.0, 0.5, 0.7, 0.9]
## The harness bay at the unit's +x end, metres along x.
const BAY := 0.16
## Emitter horns per tier.
const HORNS: PackedInt32Array = [0, 2, 3, 4]
## The control board, metres.
const BOARD_SIZE := Vector3(0.12, 0.016, 0.08)

## Why the last `fit_addon` refused ("" after one that fitted): the rig's screen shows it.
static var last_refusal := ""


static func housing_paint() -> Material:
	return ShipKit.paint(Color(0.28, 0.3, 0.33), 0.6, 0.5)


static func cover_paint() -> Material:
	return ShipKit.paint(Color(0.16, 0.34, 0.5), 0.5, 0.45)


static func copper_paint() -> Material:
	return ShipKit.paint(Color(0.74, 0.46, 0.22), 0.9, 0.35)


static func steel_paint() -> Material:
	return ShipKit.paint(Color(0.6, 0.62, 0.64), 0.8, 0.4)


static func board_paint() -> Material:
	return ShipKit.paint(Color(0.1, 0.35, 0.22), 0.1, 0.7)


## Builds a tier's attractor coil on `kit` at `xform` (ship or rig space) and returns its
## record (see the top). `path` prefixes the parts' and joints' paths ("slot:attractor_coil").
static func attractor_coil(kit: ShipKit, tier: int, xform: Transform3D, path: String = "") -> Dictionary:
	var family := "attractor_coil"
	var size := UpgradeRules.unit_size(family, tier)
	var unit := UpgradeRules.unit_id(family, tier)
	if size == Vector3.ZERO or unit == "":
		push_error("UpgradeUnits: no attractor coil tier %d" % tier)
		return {}
	var h := size * 0.5
	var inner_h := size.y - COVER - GAP   # the tray's height under the cover
	var tray_y := -h.y + inner_h * 0.5
	var housing := housing_paint()
	var p := "%s/%s" % [path, unit] if path != "" else unit
	# The housing: a tray (base, two sides, two ends) as one part.
	kit.begin_part(UNIT_PART, PartData.Kind.COMPONENT)
	kit.add(PartShapes.box(Vector3(size.x, SHEET, size.z)), xform * Transform3D(Basis.IDENTITY, Vector3(0, -h.y + SHEET * 0.5, 0)), housing)
	for sx in [-1.0, 1.0]:
		kit.add(PartShapes.box(Vector3(SHEET, inner_h, size.z)), xform * Transform3D(Basis.IDENTITY, Vector3(sx * (h.x - SHEET * 0.5), tray_y, 0)), housing)
	for sz in [-1.0, 1.0]:
		kit.add(PartShapes.box(Vector3(size.x - 2 * SHEET, inner_h, SHEET)), xform * Transform3D(Basis.IDENTITY, Vector3(0, tray_y, sz * (h.z - SHEET * 0.5))), housing)
	# The windings: copper rings round the bore along x, on two steel bobbin cheeks (looks),
	# leaving the harness bay free at the +x end.
	var coil_r := minf(inner_h * 0.5 - 0.015, h.z - SHEET - 0.015)
	var coil_y := -h.y + SHEET + coil_r + 0.01
	var coil_x := -BAY * 0.5
	var turns := TURNS[clampi(tier, 1, 3)]
	var span := size.x - 2 * SHEET - 0.08 - BAY
	var pitch := span / float(turns)
	var lay := Basis(Vector3.FORWARD, PI * 0.5)   # a ring's axis (y) along x
	for i in turns:
		var x := coil_x - span * 0.5 + pitch * (float(i) + 0.5)
		kit.add(PartShapes.ring(BORE, coil_r, pitch * 0.8, 24), xform * Transform3D(lay, Vector3(x, coil_y, 0)), copper_paint(), "", null, false)
	for sx in [-1.0, 1.0]:
		kit.add(PartShapes.ring(BORE, coil_r + 0.01, 0.012, 24), xform * Transform3D(lay, Vector3(coil_x + sx * (span * 0.5 + 0.01), coil_y, 0)), steel_paint(), "", null, false)
	# The harness bay: a cable tray along the back wall of the bay, inside (a look).
	var bay_x := h.x - SHEET - BAY * 0.5
	kit.add(PartShapes.box(Vector3(BAY - 0.02, 0.01, 0.04)), xform * Transform3D(Basis.IDENTITY, Vector3(bay_x, -h.y + SHEET + 0.005, h.z - SHEET - 0.03)), steel_paint(), "", null, false)
	var part := kit.end_part()
	part.path = p
	# The cover: a plate over the tray, bolted at the corners and tacked at each end.
	var cover_y := h.y - COVER * 0.5
	kit.begin_part(COVER_PART, PartData.Kind.COMPONENT)
	kit.add(PartShapes.box(Vector3(size.x, COVER, size.z)), xform * Transform3D(Basis.IDENTITY, Vector3(0, cover_y, 0)), cover_paint())
	kit.add(PartShapes.box(Vector3(size.x * 0.5, 0.004, 0.03)), xform * Transform3D(Basis.IDENTITY, Vector3(0, h.y + 0.002, -h.z + 0.06)), ShipKit.glow(Color(0.45, 0.8, 1.0), 1.5), "", null, false)
	var cover := kit.end_part()
	cover.path = p + "/cover"
	var bolts: Array[ConnectionData] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var at := xform * Vector3(sx * (h.x - 0.03), h.y, sz * (h.z - 0.03))
			var c := kit.join(cover, part, ConnectionData.Kind.BOLT, at, xform.basis * Vector3.UP, Vector3.ZERO, Vector2.ZERO,
					"%s/cover/bolt/%d" % [p, bolts.size()])
			if c:
				bolts.append(c)
	var tacks := kit.tack(cover, part, [xform * Vector3(0, cover_y, -h.z), xform * Vector3(0, cover_y, h.z)], xform.basis * Vector3.UP, p + "/cover")
	# The internal mount points, unit space.
	var mounts: Array[Dictionary] = []
	var places := {
		"core_bay": [Vector3(coil_x, coil_y, 0), Vector3.RIGHT],
		"emitter_flange": [Vector3(coil_x, tray_y, -h.z), Vector3.FORWARD],
		"harness": [Vector3(bay_x - 0.03, -h.y + SHEET, 0), Vector3.UP],
	}
	for m: Dictionary in UpgradeRules.mounts(family):
		var id := str(m.get("id", ""))
		if not places.has(id):
			continue
		mounts.append({"id": id, "display_name": m.get("display_name", id), "trade": m.get("trade", "bolt"),
				"accepts": m.get("accepts", []), "at": places[id][0], "normal": places[id][1]})
	return {"name": UNIT_PART, "unit": unit, "family": family, "tier": tier, "display_name": UpgradeRules.tiers(family)[tier - 1].get("display_name", unit),
			"part": part, "cover": cover, "bolts": bolts, "tacks": tacks, "xform": xform, "path": p,
			"box": AABB(-h, size), "mounts": mounts}


## The mount record of `unit` (from `attractor_coil`) with this id, or {}.
static func mount_of(unit: Dictionary, mount_id: String) -> Dictionary:
	for m: Dictionary in unit.get("mounts", []):
		if m["id"] == mount_id:
			return m
	return {}


## Fits add-on `addon_id` ("quantum_core_2", "field_emitter_1", "control_board") into `unit`
## on its mount point, joined by the mount's trade (bolt, weld or wire), and returns
## {addon, kind, tier, mount, part, joints}; {} when the rules refuse it (`last_refusal`
## says why; `fitted` is what the unit already holds, add-on ids).
static func fit_addon(kit: ShipKit, unit: Dictionary, addon_id: String, fitted: PackedStringArray = []) -> Dictionary:
	last_refusal = UpgradeRules.refusal(unit.get("unit", ""), addon_id, fitted)
	if last_refusal != "":
		return {}
	var parsed := UpgradeRules.parse_addon(addon_id)
	var m := mount_of(unit, UpgradeRules.mount_for(addon_id))
	if m.is_empty():
		last_refusal = "the unit has no %s" % UpgradeRules.mount_for(addon_id)
		return {}
	var xform: Transform3D = unit["xform"]
	var at: Vector3 = m["at"]
	var normal: Vector3 = m["normal"]
	var tier := int(parsed["tier"])
	var part: PartData
	match parsed["kind"]:
		"quantum_core":
			part = quantum_core(kit, tier, xform * Transform3D(Basis.IDENTITY, at))
		"field_emitter":
			part = field_emitter(kit, tier, xform * Transform3D(Basis.IDENTITY, at))
		"control_board":
			part = control_board(kit, xform * Transform3D(Basis.IDENTITY, at + Vector3(0, BOARD_SIZE.y * 0.5 + GAP, 0)))
	if part == null:
		return {}
	part.path = "%s/%s" % [unit.get("path", unit.get("unit", "")), addon_id]
	var kind: ConnectionData.Kind = UpgradeRules.TRADE_JOINTS.get(m["trade"], ConnectionData.Kind.BOLT)
	var joints: Array[ConnectionData] = []
	var unit_part: PartData = unit["part"]
	match parsed["kind"]:
		"quantum_core":
			# Two clamp bolts, one each end of the core, down onto the bobbin cheeks.
			var half := CORE_LENGTH[tier] * 0.5 - 0.03
			for sx in [-1.0, 1.0]:
				joints.append(kit.join(part, unit_part, kind, xform * (at + Vector3(sx * half, CORE_RADIUS[tier], 0)), xform.basis * Vector3.UP,
						Vector3.ZERO, Vector2.ZERO, "%s/clamp/%d" % [part.path, joints.size()]))
		"field_emitter":
			# A weld seam round the flange plate's foot, on the housing's front face.
			joints.append(kit.join(part, unit_part, kind, xform * at, xform.basis * normal, xform.basis * Vector3.UP, Vector2(0.2, 0.12),
					"%s/seam" % part.path))
		"control_board":
			# Wired into the harness: one connector plug off the board's outboard end.
			joints.append(kit.join(part, unit_part, kind, xform * (at + Vector3(BOARD_SIZE.x * 0.5, BOARD_SIZE.y * 0.5 + GAP, 0)), xform.basis * Vector3.RIGHT,
					Vector3.ZERO, Vector2.ZERO, "%s/plug" % part.path))
	return {"addon": addon_id, "kind": parsed["kind"], "tier": tier, "mount": m["id"], "part": part, "joints": joints}


## A quantum core at `tier`: a sealed cylinder lying along x (wider and longer each tier)
## with a lit band round its middle and a cap each end.
static func quantum_core(kit: ShipKit, tier: int, xform: Transform3D) -> PartData:
	tier = clampi(tier, 1, 3)
	var r := CORE_RADIUS[tier]
	var l := CORE_LENGTH[tier]
	var lay := Basis(Vector3.FORWARD, PI * 0.5)
	kit.begin_part(ADDON_PARTS["quantum_core"], PartData.Kind.COMPONENT)
	kit.add(PartShapes.prism(20, r, l - 0.04), xform * Transform3D(lay, Vector3.ZERO), steel_paint())
	for sx in [-1.0, 1.0]:
		kit.add(PartShapes.prism(20, r * 0.8, 0.02), xform * Transform3D(lay, Vector3(sx * (l * 0.5 - 0.01), 0, 0)), housing_paint())
	kit.add(PartShapes.ring(r + 0.001, r + 0.006, 0.03 + 0.01 * tier, 24), xform * Transform3D(lay, Vector3.ZERO),
			ShipKit.glow(Color(0.5, 0.3, 1.0), 2.0 + tier), "", null, false)
	return kit.end_part()


## A field emitter array at `tier`: a flange plate standing on the housing's front face
## (its back at the origin, facing -z) with `HORNS[tier]` horns pointing forward.
static func field_emitter(kit: ShipKit, tier: int, xform: Transform3D) -> PartData:
	tier = clampi(tier, 1, 3)
	var horns := HORNS[tier]
	var width := 0.08 + 0.06 * horns
	var plate := Vector3(width, 0.12, SHEET)
	var face := Basis(Vector3.RIGHT, -PI * 0.5)   # a frustum's +y out of the front (-z)
	kit.begin_part(ADDON_PARTS["field_emitter"], PartData.Kind.COMPONENT)
	kit.add(PartShapes.box(plate), xform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -plate.z * 0.5 - GAP)), steel_paint())
	for i in horns:
		var x := -width * 0.5 + width * (float(i) + 0.5) / float(horns)
		var z := -plate.z - GAP - 0.03
		kit.add(PartShapes.frustum(0.016, 0.03, 0.06, 12), xform * Transform3D(face, Vector3(x, 0, z)), housing_paint())
		kit.add(PartShapes.ring(0.0, 0.014, 0.004, 12), xform * Transform3D(face, Vector3(x, 0, z - 0.032)),
				ShipKit.glow(Color(0.4, 0.9, 1.0), 2.0), "", null, false)
	return kit.end_part()


## The control board: a small green board lying flat (its underside at the origin) with a
## row of lit indicators and a plug block.
static func control_board(kit: ShipKit, xform: Transform3D) -> PartData:
	kit.begin_part(ADDON_PARTS["control_board"], PartData.Kind.COMPONENT)
	kit.add(PartShapes.box(BOARD_SIZE), xform, board_paint())
	kit.add(PartShapes.box(Vector3(0.02, 0.012, 0.03)), xform * Transform3D(Basis.IDENTITY, Vector3(0.045, BOARD_SIZE.y * 0.5 + 0.006, 0)), housing_paint(), "", null, false)
	for i in 3:
		kit.add(PartShapes.box(Vector3(0.006, 0.004, 0.006)), xform * Transform3D(Basis.IDENTITY, Vector3(-0.045, BOARD_SIZE.y * 0.5 + 0.002, -0.015 + 0.015 * i)),
				ShipKit.glow(Color(0.3, 1.0, 0.45), 2.0), "", null, false)
	return kit.end_part()


## The part name an add-on kind builds ("quantum_core" -> "QuantumCore").
static func addon_part_name(kind: String) -> String:
	return ADDON_PARTS.get(kind, "")
