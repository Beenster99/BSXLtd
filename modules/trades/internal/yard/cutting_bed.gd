class_name TradesCuttingBed
extends Node3D
## The plate hall's CNC cutting bed (beenster, 0.3.23: "in the middle of this new hall is a
## plasma cutting bed to make bespoke shapes from them ... The plasma cutter can store its own
## template sizes which are shown on an interface the player uses on the side of the machine.
## The plasma cutting machine is very much like a real one in its animation"). Behind
## trades.cutting_bed; stands on Ship and Bay's ShipBayBus.cutting_bed_spot() (floor level,
## -Z the operator's side).
##
## Like a real table: a water tray under a bed of steel slats that takes a 12 x 6 m sheet (made
## much bigger after 0.3.24's playtest, for the very large plates off a ship), two
## rails down its long sides, a gantry riding them on end trucks, a carriage across the gantry
## with the torch on a height lifter, a drag chain for the leads, an amber beacon, and the
## operator's console on a pedestal at the front corner. Plasma for metal; for glass and
## crystal the carriage swaps to its water-jet head.
##
## A stock plate (Shared Components' StockPlates) let go of by the tractor beam over the bed
## settles flat on the slats. On the console pick a template (the bed's own stored sizes, or
## one traced off a ship with the template scribe), turn it if you like, and press CUT: the
## gantry runs the head to the pierce point, the torch comes down, pierces with a flare and a
## shower of sparks into the water, follows the outline (holes first) at the feed rate for the
## metal and its thickness, lifts, and parks. The kerf glows and cools behind it. Then the cut
## piece ("<plate>:cut:<template>") and the skeleton left of the sheet ("<plate>:offcut") lie
## on the bed as loose parts for the beam.
## Every player sees the same run: the host checks a cut and everyone plays it from the same
## program (event trades.cut); the plate on the bed reaches late joiners in a snapshot.

const CUT_EVENT := "trades.cut"
const LOAD_EVENT := "trades.bed_load"
const SECTION := "trades_cutting_bed"
## The bed: half its working area (m, x along the rails, z across) and the slats' top.
const HALF := Vector2(6.0, 3.0)
const SLAT_Y := 0.86
## The gantry's rails (z either side) and their top.
const RAIL_Z := HALF.y + 0.28
const RAIL_Y := 1.0
## Where the head parks (bed space x, z) between jobs.
const PARK := Vector2(-HALF.x - 0.25, -HALF.y - 0.05)
## Where the nozzle's tip sits from the gantry's middle (x) and the lifter's origin (y), m.
const NOZZLE := Vector2(-0.28, -0.018)
## How high the torch rides over the plate between cuts, and the gap while cutting (m).
const LIFT_M := 0.09
const STANDOFF_M := 0.004
## Densities (kg/m³) for cut pieces' masses, by the shared Materials names.
const DENSITY := {"steel": 7850.0, "alloy": 2700.0, "titanium": 4500.0, "glass": 2500.0, "crystal": 2650.0}

## Head speeds (m/s): rapid moves, and the cutting feed for 1 mm of steel (thicker plates go
## slower; the water jet slower still), scaled by `feed_scale` for play.
@export var rapid_speed := 3.0
@export var plasma_feed := 0.2
@export var jet_feed := 0.06
@export var feed_scale := 1.0
## Seconds the arc takes to pierce (or the jet to drill through).
@export var pierce_s := 0.8
## The lifter's speed (m/s).
@export var lift_speed := 0.3
## Seconds the kerf takes to cool from white-hot to dark.
@export var kerf_cool_s := 6.0

var bay: Node  # TradesBay
## The plate on the bed: {id, size (Vector2 m, x along the bed, y across), thickness (m),
## material, family, condition} or {} for none.
var plate: Dictionary = {}
## The run going now: {template (id), turn, offset (Vector2), loops, step, ...} or {}.
var job: Dictionary = {}
## What the last finished run made: [piece id, offcut id].
var made: PackedStringArray = PackedStringArray()
## The head now (bed space): x, z along the bed, and the torch's height over the slats.
var head := Vector2(PARK.x, PARK.y)
var torch_h := LIFT_M
## Which template the console has picked, and its turn (radians, quarter turns).
var picked := ""
var turn := 0.0
var panel: Control  # TradesCutterPanel

var _net: Node
var _gantry: Node3D
var _carriage: Node3D
var _lifter: Node3D
var _plasma_head: Node3D
var _jet_head: Node3D
var _plate_node: MeshInstance3D
var _arc: OmniLight3D
var _beacon: OmniLight3D
var _beacon_mesh: MeshInstance3D
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _mist: GPUParticles3D
var _spatter: GPUParticles3D
var _flare: MeshInstance3D
var _kerf: MeshInstance3D
var _kerf_points: Array = []  # [Vector3 (bed space), time made]
var _hiss: AudioStreamPlayer3D
var _motor: AudioStreamPlayer3D
var _screen: TouchScreen
var _clock := 0.0


static func enabled() -> bool:
	return Flags.is_on("trades.cutting_bed")


static func spot() -> Variant:
	var bus := Modules.bus("ship_bay")
	if bus and bus.has_method("cutting_bed_spot"):
		return bus.call("cutting_bed_spot")
	return null


func build(net: Node = null) -> void:
	_build_table()
	_build_gantry()
	_build_console()
	_build_effects()
	_net = net
	if _net:
		_net.call("register_event", CUT_EVENT, _apply_cut, _validate_cut)
		_net.call("register_event", LOAD_EVENT, _apply_load, _validate_load)
		if _net.has_method("register_snapshot_provider"):
			_net.call("register_snapshot_provider", SECTION, self)
	var bus := _trades()
	if bus and bus.has_signal("templates_changed"):
		bus.templates_changed.connect(_refresh_panel)
	_place_head()
	_refresh_panel()


func _exit_tree() -> void:
	if _net:
		_net.call("unregister_event", CUT_EVENT)
		_net.call("unregister_event", LOAD_EVENT)
		if _net.has_method("unregister_snapshot_provider"):
			_net.call("unregister_snapshot_provider", SECTION)


func _trades() -> TradesBus:
	return Modules.bus("trades") as TradesBus


# --- Plates ----------------------------------------------------------------------------

## Shared Components' stock plates, or null before they exist.
static func stock_plates() -> Script:
	var path := "res://modules/shared_components/api/stock_plates.gd"
	return load(path) as Script if ResourceLoader.exists(path) else null


## The plate data for a stock plate id: {id, size, thickness, material, family} or {}.
static func plate_info(id: String) -> Dictionary:
	var sp := stock_plates()
	if sp == null or not bool(sp.call("is_plate", id)):
		return {}
	var it: Dictionary = sp.call("item", id)
	var size: Vector3 = it.get("size", Vector3(1, 0.005, 1))
	return {"id": id, "size": Vector2(size.x, size.z), "thickness": size.y,
			"material": str(it.get("material", "steel")), "family": str(it.get("family", "metal"))}


## The bed set on its spot with its rails along the room's longer side (`room`: Ship and Bay's
## CUTTING_BED_ROOM, x across and z along the spot; a bed's rails run along its own x).
static func lay_along(spot: Transform3D, room: Variant) -> Transform3D:
	if room is Vector3 and (room as Vector3).z > (room as Vector3).x:
		return spot * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	return spot


## A plate fits the bed (12 m by 6 m).
static func fits_bed(size: Vector2) -> bool:
	return (size.x <= HALF.x * 2.0 + 0.001 and size.y <= HALF.y * 2.0 + 0.001)


## Puts a plate on the bed (the host's load event, a snapshot, or tests).
func set_plate(info: Dictionary) -> void:
	plate = info.duplicate()
	made = PackedStringArray()
	if is_instance_valid(_plate_node):
		_plate_node.queue_free()
		_plate_node = null
	if not plate.is_empty():
		var t: float = plate.thickness
		var s: Vector2 = plate.size
		_plate_node = MeshInstance3D.new()
		_plate_node.name = "Plate"
		_plate_node.mesh = TradesPlateShapes.extrude(_rect_centred(s), [], t)
		_plate_node.material_override = _plate_mat(plate)
		_plate_node.position = Vector3(0, SLAT_Y + t * 0.5, 0)
		add_child(_plate_node)
	_refresh_panel()


func is_glass() -> bool:
	return str(plate.get("family", "metal")) == "glass"


## A loose plate let go of over the bed (the host looks each step): it settles on the slats.
func _physics_process(_delta: float) -> void:
	if not _is_host() or not plate.is_empty() or not job.is_empty():
		return
	var beam := _tractor()
	if beam == null:
		return
	for id: String in beam.loose.keys():
		var part: TradesLoosePart = beam.loose[id]
		if not is_instance_valid(part) or part.held:
			continue
		var info := plate_info(part.component)
		if info.is_empty() or not fits_bed(info.size):
			continue
		var local := global_transform.affine_inverse() * part.global_position
		if absf(local.x) < HALF.x + 0.3 and absf(local.z) < HALF.y + 0.3 and local.y < SLAT_Y + 0.8 and local.y > SLAT_Y - 0.3 \
				and part.linear_velocity.length() < 0.6:
			info["condition"] = part.condition
			_ask(LOAD_EVENT, {"part": id, "plate": info})
			return


func _validate_load(_sender: int, p: Dictionary) -> Variant:
	if not plate.is_empty() or not job.is_empty():
		return "the bed has a plate"
	if not p.get("plate") is Dictionary:
		return "no plate"
	return p


func _apply_load(p: Dictionary) -> void:
	var beam := _tractor()
	var id := str(p.get("part", ""))
	if beam and beam.has_method("take_away"):
		beam.call("take_away", id)
	set_plate(p.plate)


# --- Cutting ---------------------------------------------------------------------------

## The template by id (the bed's own or a traced one), or {}.
func template(id: String) -> Dictionary:
	var bus := _trades()
	if bus:
		for t: Dictionary in bus.templates():
			if str(t.id) == id:
				return t
	return {}


## Why a cut can't start now, or "" when it can.
func refusal(template_id: String, quarter := turn) -> String:
	if not job.is_empty():
		return "Cutting"
	if plate.is_empty():
		return "No plate on the bed"
	var t := template(template_id)
	if t.is_empty():
		return "Pick a config"
	var turned := TradesPlateShapes.make_turned(t, quarter)
	if TradesPlateShapes.fit_turn(turned, plate.size) < 0.0:
		return "Too big for this plate"
	return ""


## The console's CUT: asks the host to run the picked template on the plate.
func cut(template_id := picked) -> String:
	var why := refusal(template_id)
	if why != "":
		return why
	_ask(CUT_EVENT, {"template": template_id, "turn": turn})
	return ""


func _validate_cut(sender: int, p: Dictionary) -> Variant:
	var why := refusal(str(p.get("template", "")), float(p.get("turn", 0.0)))
	if why != "":
		return why
	return {"template": str(p.template), "turn": float(p.get("turn", 0.0)), "peer": sender,
			"plate": plate.duplicate(), "serial": _serial()}


func _apply_cut(p: Dictionary) -> void:
	var t := template(str(p.template))
	if t.is_empty():
		return
	var turned := TradesPlateShapes.make_turned(t, float(p.turn))
	var extra := TradesPlateShapes.fit_turn(turned, plate.size)
	var shape := TradesPlateShapes.make_turned(turned, extra)
	job = {"template": str(p.template), "shape": shape, "serial": str(p.serial),
			"program": _program(shape), "step": 0, "t": 0.0, "from": head, "from_h": torch_h}
	_kerf_points.clear()
	_refresh_panel()


## The head's moves for a shape centred on the plate: for each loop (holes first) a rapid to
## its start, down, pierce, along the loop at the feed, up; then back to park.
func _program(shape: Dictionary) -> Array:
	var steps: Array = []
	var feed := _feed()
	var cut_h := float(plate.thickness) + STANDOFF_M
	for loop: PackedVector2Array in TradesPlateShapes.cut_path(shape, 0.0):
		if loop.is_empty():
			continue
		steps.append({"kind": "rapid", "to": loop[0], "speed": rapid_speed})
		steps.append({"kind": "lift", "to": cut_h})
		steps.append({"kind": "pierce", "s": pierce_s * (1.5 if is_glass() else 1.0) * (0.5 + float(plate.thickness) * 100.0)})
		for i in range(1, loop.size()):
			steps.append({"kind": "cut", "to": loop[i], "speed": feed})
		steps.append({"kind": "lift", "to": LIFT_M})
	steps.append({"kind": "rapid", "to": PARK, "speed": rapid_speed})
	return steps


## The cutting feed (m/s) for this plate.
func _feed() -> float:
	var mm := float(plate.get("thickness", 0.005)) * 1000.0
	var base := jet_feed if is_glass() else plasma_feed
	return clampf(base * 4.0 / (3.0 + mm), base * 0.25, base) * feed_scale


func _process(delta: float) -> void:
	_clock += delta
	var cutting := false
	var piercing := false
	var moving := false
	if not job.is_empty():
		var steps: Array = job.program
		var budget := delta
		while budget > 0.0 and int(job.step) < steps.size():
			var s: Dictionary = steps[job.step]
			match str(s.kind):
				"rapid", "cut":
					var to: Vector2 = s.to
					var d := head.distance_to(to)
					var go := float(s.speed) * budget
					if go >= d:
						budget -= d / float(s.speed)
						head = to
						job.step = int(job.step) + 1
					else:
						head = head.move_toward(to, go)
						budget = 0.0
					moving = true
					if s.kind == "cut":
						cutting = true
						_kerf_points.append([Vector3(head.x, SLAT_Y + float(plate.thickness) + 0.0015, head.y), _clock])
				"lift":
					var hd := float(s.to)
					var go := lift_speed * budget
					if absf(torch_h - hd) <= go:
						budget -= absf(torch_h - hd) / lift_speed
						torch_h = hd
						job.step = int(job.step) + 1
					else:
						torch_h = move_toward(torch_h, hd, go)
						budget = 0.0
				"pierce":
					job.t = float(job.t) + budget
					piercing = true
					if float(job.t) >= float(s.s):
						budget = float(job.t) - float(s.s)
						job.t = 0.0
						job.step = int(job.step) + 1
					else:
						budget = 0.0
		if int(job.step) >= steps.size():
			_finish()
	_place_head()
	_show_effects(cutting, piercing, moving, delta)


func _finish() -> void:
	var shape: Dictionary = job.shape
	var serial := str(job.serial)
	var info := plate.duplicate()
	job = {}
	_drop_plate_node()
	plate = {}
	made = PackedStringArray()
	var piece_id := "%s:cut:%s#%s" % [info.id, shape.id, serial]
	var off_id := "%s:offcut#%s" % [info.id, serial]
	var t: float = info.thickness
	var hole := (shape.outline as PackedVector2Array).duplicate()
	hole.reverse()
	_lay_piece(piece_id, "%s:cut:%s" % [info.id, shape.id], shape.outline, shape.get("holes", []), t, info)
	_lay_piece(off_id, "%s:offcut" % info.id, _rect_centred(info.size), [hole], t, info)
	made = PackedStringArray([piece_id, off_id])
	_refresh_panel()


## A cut piece as a loose part on the slats, for the tractor beam (on every machine, same id).
func _lay_piece(id: String, component: String, outline: PackedVector2Array, holes: Array, t: float, info: Dictionary) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = TradesPlateShapes.extrude(outline, holes, t)
	visual.material_override = _plate_mat(info)
	var r := TradesPlateShapes.bounds(outline)
	var centre := r.get_center()
	visual.position = Vector3(-centre.x, 0, -centre.y)
	var holder := Node3D.new()
	holder.add_child(visual)
	var box := AABB(Vector3(-r.size.x * 0.5, -t * 0.5, -r.size.y * 0.5), Vector3(r.size.x, t, r.size.y))
	var xform := global_transform * Transform3D(Basis(), Vector3(centre.x, SLAT_Y + t * 0.5 + 0.002, centre.y))
	var area := TradesPlateShapes.area_of({"outline": outline, "holes": holes})
	var kg := area * t * float(DENSITY.get(str(info.material), 7850.0))
	var beam := _tractor()
	if beam and beam.has_method("adopt_piece"):
		beam.call("adopt_piece", id, component, box, holder, xform, kg, float(info.get("condition", 1.0)))
	else:
		holder.name = "Piece_" + id.validate_node_name()
		holder.set_meta("component", component)
		holder.top_level = true
		add_child(holder)
		holder.global_transform = xform


func _drop_plate_node() -> void:
	if is_instance_valid(_plate_node):
		_plate_node.queue_free()
	_plate_node = null


func _serial() -> String:
	return "%d%03d" % [Time.get_unix_time_from_system(), randi() % 1000]


func _ask(event: String, p: Dictionary) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", event, p)
		return
	var v: Variant = (_validate_cut if event == CUT_EVENT else _validate_load).call(1, p)
	if v is Dictionary:
		(_apply_cut if event == CUT_EVENT else _apply_load).call(v)


func _is_host() -> bool:
	return _net == null or not bool(_net.call("is_online")) or bool(_net.call("is_host"))


func _tractor() -> Node:
	if bay == null or not bay.has_method("ship_station"):
		return null
	var s: Variant = bay.call("ship_station")
	return (s as Node).get("tractor") as Node if s else null


# --- Snapshot ---------------------------------------------------------------------------

func get_net_snapshot() -> Dictionary:
	return {"plate": plate}


func apply_net_snapshot(data: Dictionary) -> void:
	var p: Variant = data.get("plate", {})
	if p is Dictionary and job.is_empty():
		set_plate(p)


# --- The console ------------------------------------------------------------------------

func pick(id: String) -> void:
	picked = id
	_refresh_panel()


func rotate_quarter() -> void:
	turn = fmod(turn + PI * 0.5, TAU)
	_refresh_panel()


func _refresh_panel() -> void:
	if panel and panel.has_method("refresh"):
		panel.call("refresh")


# --- The machine -------------------------------------------------------------------------

func _place_head() -> void:
	if _gantry == null:
		return
	# The nozzle hangs NOZZLE under and behind the carriage's middle.
	_gantry.position.x = head.x - NOZZLE.x
	_carriage.position.z = head.y
	_lifter.position.y = SLAT_Y + torch_h - (_gantry.position.y + _carriage.position.y) - NOZZLE.y
	_plasma_head.visible = not is_glass()
	_jet_head.visible = is_glass()


func _nozzle() -> Vector3:
	return Vector3(head.x, SLAT_Y + torch_h, head.y)


func _show_effects(cutting: bool, piercing: bool, moving: bool, delta: float) -> void:
	var live := cutting or piercing
	var glass := is_glass()
	var at := _nozzle()
	_arc.visible = live and not glass
	if _arc.visible:
		_arc.position = at + Vector3(0, 0.02, 0)
		_arc.light_energy = (2.2 if piercing else 1.3) * (0.8 + 0.4 * randf())
	_sparks.emitting = live and not glass
	_sparks.position = Vector3(at.x, SLAT_Y - 0.01, at.z)
	_sparks.amount_ratio = 1.0 if piercing else 0.6
	_spatter.emitting = live and not glass
	_spatter.position = Vector3(at.x, SLAT_Y + float(plate.get("thickness", 0.0)) + 0.002, at.z)
	_flare.visible = live
	_flare.position = at + Vector3(0, -0.004, 0)
	_flare.scale = Vector3.ONE * ((1.6 if piercing else 1.0) * (0.85 + 0.3 * randf()) * (0.6 if glass else 1.0))
	_smoke.emitting = live and not glass
	_smoke.position = at
	_mist.emitting = live and glass
	_mist.position = Vector3(at.x, SLAT_Y - 0.01, at.z)
	var running := not job.is_empty()
	_beacon.visible = running and fmod(_clock, 0.8) < 0.4
	(_beacon_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 4.0 if _beacon.visible else 0.2
	_loop(_hiss, live)
	_hiss.pitch_scale = 0.7 if glass else 1.0
	_hiss.global_position = global_transform * at
	_loop(_motor, moving and running)
	_draw_kerf()


func _loop(p: AudioStreamPlayer3D, on: bool) -> void:
	if on == p.playing or DisplayServer.get_name() == "headless":
		return
	if on:
		p.play()
	else:
		p.stop()


## The kerf behind the torch: a strip over the cut line, white-hot where it was just cut,
## cooling through orange and red to dark (water-jet cuts stay wet grey).
func _draw_kerf() -> void:
	var im := _kerf.mesh as ImmediateMesh
	im.clear_surfaces()
	if _kerf_points.size() < 2:
		return
	var glass := is_glass()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, _kerf_points.size()):
		var a: Vector3 = _kerf_points[i - 1][0]
		var b: Vector3 = _kerf_points[i][0]
		if a.distance_to(b) < 0.0001:
			continue
		var age := _clock - float(_kerf_points[i][1])
		var heat := clampf(1.0 - age / kerf_cool_s, 0.0, 1.0)
		var c := Color(0.25, 0.27, 0.3) if glass else _heat_colour(heat)
		var side := (b - a).normalized().cross(Vector3.UP) * 0.003
		for v: Vector3 in [a - side, b - side, b + side, a - side, b + side, a + side]:
			im.surface_set_color(c)
			im.surface_add_vertex(v)
	im.surface_end()


static func _heat_colour(heat: float) -> Color:
	if heat <= 0.0:
		return Color(0.06, 0.05, 0.05)
	if heat > 0.7:
		return Color(1.0, 0.95, 0.75).lerp(Color(1.0, 0.6, 0.15), (1.0 - heat) / 0.3) * 4.0
	return Color(0.06, 0.05, 0.05).lerp(Color(1.0, 0.35, 0.05) * 3.0, heat / 0.7)


# --- Building it -------------------------------------------------------------------------

func _build_table() -> void:
	var frame := _mat(Color(0.18, 0.19, 0.2), 0.6, 0.5)
	var steel := _mat(Color(0.42, 0.42, 0.43), 0.8, 0.45)
	var rust := _mat(Color(0.32, 0.22, 0.16), 0.5, 0.8)
	var water := _mat(Color(0.05, 0.09, 0.1), 0.2, 0.05)
	var yellow := _mat(Color(0.95, 0.72, 0.08), 0.3, 0.45)
	# The water tray on its legs, its rim, and the water a little under the slats.
	var tray := HALF * 2.0 + Vector2(0.4, 0.4)
	_box(Vector3(tray.x, 0.5, tray.y), Vector3(0, 0.55, 0), frame, true)
	var lx := -tray.x * 0.5 + 0.1
	while lx <= tray.x * 0.5 - 0.09:
		for z: float in [-tray.y * 0.5 + 0.1, tray.y * 0.5 - 0.1]:
			_box(Vector3(0.12, 0.3, 0.12), Vector3(lx, 0.15, z), frame, false)
		lx += (tray.x - 0.2) / ceilf((tray.x - 0.2) / 2.0)
	_box(Vector3(tray.x - 0.2, 0.01, tray.y - 0.2), Vector3(0, 0.79, 0), water, false)
	for z: float in [-tray.y * 0.5 + 0.03, tray.y * 0.5 - 0.03]:
		_box(Vector3(tray.x, 0.06, 0.06), Vector3(0, 0.83, z), frame, false)
	for x: float in [-tray.x * 0.5 + 0.03, tray.x * 0.5 - 0.03]:
		_box(Vector3(0.06, 0.06, tray.y), Vector3(x, 0.83, 0), frame, false)
	# The slats: upright strips across the bed, burnt along their tops.
	var x := -HALF.x
	while x <= HALF.x + 0.001:
		_box(Vector3(0.006, 0.07, HALF.y * 2.0 + 0.1), Vector3(x, SLAT_Y - 0.035, 0), rust, false)
		x += 0.16
	# The slats' tops are what a plate rests on.
	var top := StaticBody3D.new()
	top.name = "BedTop"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(HALF.x * 2.0, 0.02, HALF.y * 2.0)
	cs.shape = bs
	cs.position = Vector3(0, SLAT_Y - 0.01, 0)
	top.add_child(cs)
	add_child(top)
	# The rails on their beams down both long sides, with end stops and legs every 2 m or so.
	var rail := HALF.x * 2.0 + 1.0
	for z: float in [-RAIL_Z, RAIL_Z]:
		_box(Vector3(rail, 0.16, 0.14), Vector3(0.0, RAIL_Y - 0.12, z), frame, true)
		_box(Vector3(rail, 0.03, 0.04), Vector3(0.0, RAIL_Y - 0.025, z), steel, false)
		for ex: float in [-rail * 0.5 + 0.05, rail * 0.5 - 0.05]:
			_box(Vector3(0.05, 0.12, 0.12), Vector3(ex, RAIL_Y + 0.02, z), yellow, false)
		var n := int(ceilf((rail - 0.4) / 2.0))
		for k in n + 1:
			var x2 := -rail * 0.5 + 0.2 + (rail - 0.4) * k / n
			_box(Vector3(0.12, RAIL_Y - 0.2, 0.12), Vector3(x2, (RAIL_Y - 0.2) * 0.5, z), frame, false)


func _build_gantry() -> void:
	var yellow := _mat(Color(0.95, 0.72, 0.08), 0.3, 0.45)
	var dark := _mat(Color(0.12, 0.12, 0.13), 0.5, 0.5)
	var steel := _mat(Color(0.6, 0.61, 0.62), 0.85, 0.3)
	var copper := _mat(Color(0.85, 0.5, 0.25), 0.9, 0.3)
	var blue := _mat(Color(0.1, 0.35, 0.8), 0.3, 0.4)
	_gantry = Node3D.new()
	_gantry.name = "Gantry"
	_gantry.position = Vector3(PARK.x, 0, 0)
	add_child(_gantry)
	# End trucks on the rails, the bridge across, a motor on each truck.
	for z: float in [-RAIL_Z, RAIL_Z]:
		_box(Vector3(0.36, 0.22, 0.18), Vector3(0, RAIL_Y + 0.11, z), yellow, false, _gantry)
		_box(Vector3(0.14, 0.14, 0.14), Vector3(-0.1, RAIL_Y + 0.29, z + signf(z) * 0.06), dark, false, _gantry)
		_box(Vector3(0.18, 0.4, 0.1), Vector3(0, RAIL_Y + 0.42, z), yellow, false, _gantry)
	_box(Vector3(0.3, 0.34, RAIL_Z * 2.0 + 0.2), Vector3(0, RAIL_Y + 0.52, 0), yellow, false, _gantry)
	_box(Vector3(0.03, 0.03, RAIL_Z * 2.0), Vector3(-0.115, RAIL_Y + 0.46, 0), steel, false, _gantry)
	# The drag chain along the bridge's top.
	for k in int(RAIL_Z * 20.0):
		_box(Vector3(0.08, 0.05, 0.09), Vector3(0.02, RAIL_Y + 0.72, -RAIL_Z + 0.1 * k), dark, false, _gantry)
	# The beacon on the far truck.
	_beacon_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = 0.1
	_beacon_mesh.mesh = cyl
	var amber := _mat(Color(1.0, 0.55, 0.05), 0.0, 0.3)
	amber.emission_enabled = true
	amber.emission = Color(1.0, 0.5, 0.05)
	_beacon_mesh.material_override = amber
	_beacon_mesh.position = Vector3(0, RAIL_Y + 0.68, RAIL_Z)
	_gantry.add_child(_beacon_mesh)
	_beacon = OmniLight3D.new()
	_beacon.light_color = Color(1.0, 0.55, 0.1)
	_beacon.omni_range = 4.0
	_beacon.light_energy = 1.5
	_beacon.position = _beacon_mesh.position + Vector3(0, 0.1, 0)
	_beacon.visible = false
	_gantry.add_child(_beacon)
	# The carriage on the bridge's front face, and the lifter in it.
	_carriage = Node3D.new()
	_carriage.name = "Carriage"
	_carriage.position = Vector3(-0.2, RAIL_Y + 0.5, PARK.y)
	_gantry.add_child(_carriage)
	_box(Vector3(0.12, 0.3, 0.28), Vector3(0, 0, 0), dark, false, _carriage)
	_box(Vector3(0.1, 0.1, 0.1), Vector3(0.02, 0.2, 0), blue, false, _carriage)
	_lifter = Node3D.new()
	_lifter.name = "Lifter"
	_carriage.add_child(_lifter)
	_box(Vector3(0.06, 0.4, 0.08), Vector3(-0.08, 0.2, 0), steel, false, _lifter)
	# The plasma torch: a body, a shield cup and its copper nozzle; the lead up to the chain.
	_plasma_head = Node3D.new()
	_plasma_head.name = "PlasmaTorch"
	_lifter.add_child(_plasma_head)
	_cyl(0.028, 0.24, Vector3(-0.08, 0.14, 0), dark, _plasma_head)
	_cyl(0.022, 0.03, Vector3(-0.08, 0.005, 0), steel, _plasma_head)
	_cone(0.008, 0.016, 0.02, Vector3(-0.08, -0.008, 0), copper, _plasma_head)
	_cyl(0.012, 0.3, Vector3(-0.08, 0.4, 0.05), dark, _plasma_head)
	# The water-jet head: the cutting head with its abrasive hopper and a pressure line.
	_jet_head = Node3D.new()
	_jet_head.name = "WaterJet"
	_lifter.add_child(_jet_head)
	_cyl(0.03, 0.18, Vector3(-0.08, 0.12, 0), steel, _jet_head)
	_cone(0.004, 0.012, 0.05, Vector3(-0.08, 0.005, 0), steel, _jet_head)
	_box(Vector3(0.08, 0.1, 0.08), Vector3(-0.08, 0.28, 0.06), blue, false, _jet_head)
	_cyl(0.008, 0.35, Vector3(-0.08, 0.4, -0.03), steel, _jet_head)
	_jet_head.visible = false


func _build_console() -> void:
	var dark := _mat(Color(0.14, 0.15, 0.16), 0.5, 0.5)
	var red := _mat(Color(0.8, 0.05, 0.03), 0.2, 0.4)
	var stand := Node3D.new()
	stand.name = "Console"
	# At the front corner, turned to face the operator (who stands on the -Z side).
	stand.position = Vector3(HALF.x - 0.2, 0, -RAIL_Z - 0.57)
	stand.rotation.y = PI
	add_child(stand)
	_box(Vector3(0.25, 1.05, 0.25), Vector3(0, 0.525, 0), dark, true, stand)
	_box(Vector3(0.7, 0.5, 0.12), Vector3(0, 1.3, 0.02), dark, false, stand)
	# The emergency stop beside the screen.
	_cyl(0.035, 0.03, Vector3(0.43, 1.12, 0.06), red, stand).rotation.x = PI * 0.5
	panel = TradesCutterPanel.new()
	panel.bed = self
	_screen = TouchScreen.new(panel, Vector2i(1100, 760), Vector2(0.62, 0.43))
	_screen.name = "Screen"
	_screen.position = Vector3(0, 1.3, 0.09)
	_screen.rotation.x = deg_to_rad(-12.0)
	stand.add_child(_screen)


func _build_effects() -> void:
	_arc = OmniLight3D.new()
	_arc.name = "Arc"
	_arc.light_color = Color(0.7, 0.8, 1.0)
	_arc.omni_range = 3.5
	_arc.visible = false
	add_child(_arc)
	_sparks = _particles("Sparks", 260, 0.7, Color(1.0, 0.6, 0.15), Vector3(0, -1, 0), 25.0, 2.0, 4.5, Vector3(0, -9.0, 0), 0.03, true)
	_smoke = _particles("Smoke", 60, 2.5, Color(0.5, 0.5, 0.52, 0.35), Vector3(0, 1, 0), 30.0, 0.2, 0.6, Vector3(0, 0.3, 0), 0.25, false)
	# Spatter thrown up off the top of the plate round the arc, and the arc's white-blue flare.
	_spatter = _particles("Spatter", 90, 0.4, Color(1.0, 0.75, 0.35), Vector3(0, 1, 0), 75.0, 0.8, 2.2, Vector3(0, -9.0, 0), 0.025, true)
	_flare = MeshInstance3D.new()
	_flare.name = "Flare"
	var fq := QuadMesh.new()
	fq.size = Vector2(0.16, 0.16)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = _puff()
	fm.albedo_color = Color(0.75, 0.85, 1.0) * 3.0
	fq.material = fm
	_flare.mesh = fq
	_flare.visible = false
	add_child(_flare)
	_mist = _particles("Mist", 120, 0.9, Color(0.85, 0.9, 0.95, 0.5), Vector3(0, -1, 0), 60.0, 0.5, 1.5, Vector3(0, -2.0, 0), 0.12, false)
	_kerf = MeshInstance3D.new()
	_kerf.name = "Kerf"
	_kerf.mesh = ImmediateMesh.new()
	var km := StandardMaterial3D.new()
	km.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	km.vertex_color_use_as_albedo = true
	_kerf.material_override = km
	add_child(_kerf)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.name = "Hiss"
	_hiss.stream = TradesSounds.hum(0.5, 0.5, 150.0, 8000.0)
	_hiss.volume_db = -4.0
	_hiss.max_distance = 40.0
	add_child(_hiss)
	_motor = AudioStreamPlayer3D.new()
	_motor.name = "Motor"
	_motor.stream = TradesSounds.hum(0.5, 0.2, 220.0, 1200.0)
	_motor.volume_db = -14.0
	add_child(_motor)


func _particles(n: String, amount: int, life: float, colour: Color, dir: Vector3, spread: float,
		v_min: float, v_max: float, gravity: Vector3, size: float, streak: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.direction = dir
	m.spread = spread
	m.initial_velocity_min = v_min
	m.initial_velocity_max = v_max
	m.gravity = gravity
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour.r, colour.g, colour.b, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	m.color_ramp = ft
	if not streak:
		var grow := Curve.new()
		grow.add_point(Vector2(0, 0.3))
		grow.add_point(Vector2(1, 1.0))
		var gt := CurveTexture.new()
		gt.curve = grow
		m.scale_curve = gt
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(size * 0.15, size) if streak else Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if streak:
		mat.albedo_color = Color(2.5, 1.5, 0.6)
	else:
		mat.albedo_texture = _puff()
	q.material = mat
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-5, -3, -5), Vector3(10, 8, 10))
	add_child(p)
	return p


func _plate_mat(info: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	match str(info.get("material", "steel")):
		"glass", "crystal":
			m.albedo_color = Color(0.7, 0.85, 0.9, 0.45)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic = 0.1
		"alloy":
			m.albedo_color = Color(0.78, 0.79, 0.8)
			m.metallic = 0.85
			m.roughness = 0.35
		"titanium":
			m.albedo_color = Color(0.55, 0.56, 0.6)
			m.metallic = 0.8
			m.roughness = 0.4
		_:
			m.albedo_color = Color(0.4, 0.41, 0.42)
			m.metallic = 0.45
			m.roughness = 0.55
	return m


static func _rect_centred(s: Vector2) -> PackedVector2Array:
	var h := s * 0.5
	return PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])


func _box(size: Vector3, at: Vector3, mat: Material, solid: bool, parent: Node = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	if solid:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		m.add_child(body)
	return m


func _cyl(r: float, h: float, at: Vector3, mat: Material, parent: Node) -> MeshInstance3D:
	return _cone(r, r, h, at, mat, parent)


func _cone(top: float, bottom: float, h: float, at: Vector3, mat: Material, parent: Node) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = bottom
	c.bottom_radius = top
	c.height = h
	c.radial_segments = 16
	m.mesh = c
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


## A soft round puff for the smoke and mist.
static func _puff() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m
