extends Node3D
## The crusher bay outside Pre-assembly's south door: where goods too far gone to refurbish
## end up. Trolleys set them down on the feed pad (the survey's GRIND calls off both lines,
## and a clean-up's scrap); a loader rides each lot up the ramp into a huge twin-shaft
## crusher (the hall's old grinder, three times the size), which breaks it down to dust. A
## screw lifts the dust into the smelter, which casts it into ingots, and the ingots ride
## the cooling conveyor out to the ingot yard: a painted zone for each material, the
## ingots stacked on pallets in it. Cast ingots join Business's raw materials for sale
## (ShipBayBus.scrap_recycled).
##
## The plant runs by itself on the host: whenever the crusher is empty and a lot waits on
## the pad it takes it, runs it for crush_time and says finish. Its state is the bus's
## (line_state().crusher); this node draws it and times the run on every peer.
##
## Built in yard space on the apron south of the east wing; north is -Z.

const Touch := preload("res://modules/ship_bay/internal/kit/touch_screen.gd")
const T := preload("res://modules/ui/api/terminal_kit.gd")
const LineParts := preload("res://modules/ship_bay/internal/yard/line_parts.gd")
const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")

## The bay on the apron (x, z, width, depth), metres.
const BAY := Rect2(44.0, 28.0, 24.0, 23.0)
## Where trolleys set down lots for the crusher (floor points, yard space).
const FEED_SPOTS: Array[Vector3] = [Vector3(47.2, 0, 31.6), Vector3(47.2, 0, 35.0), Vector3(47.2, 0, 38.4)]
## The crusher's centre on the floor; lots travel +X into it.
const CRUSHER := Vector3(60.2, 0, 35.0)
## The crusher is the hall grinder's design drawn this many times bigger.
const K := 3.0
## The grinder's own measures (its frame, before K): bed height, width, mouth offset.
const BED := 0.9
const WIDTH := 1.6
## The ramp from the feed pad up to the crusher's mouth (yard space, on the rollers).
const RAMP_FOOT := Vector3(49.6, 0.9, 35.0)
const RAMP_TOP := Vector3(56.6, BED * K, 35.0)
## The smelter's centre on the floor, and the ingot yard's cooling conveyor (z) along the
## zones' north edge.
const SMELTER := Vector3(65.4, 0, 35.0)
const CONVEYOR_Z := 41.6
## The ingot yard: one zone per material, west to east, each this big (x, z).
const ZONE_SIZE := Vector2(3.0, 6.6)
const ZONE_Z := 43.6
const MATERIALS: PackedStringArray = ["steel", "alloy", "titanium", "copper", "tungsten", "glass", "crystal"]
const METAL_LOOK := {"steel": Color(0.46, 0.47, 0.49), "alloy": Color(0.74, 0.76, 0.8), "titanium": Color(0.55, 0.58, 0.66),
		"copper": Color(0.78, 0.45, 0.25), "tungsten": Color(0.32, 0.33, 0.35), "glass": Color(0.62, 0.8, 0.76),
		"crystal": Color(0.6, 0.78, 0.98)}
## Ingots drawn on a pallet (5 a layer, 3 layers), and pallets a zone shows (2 x 5).
const PER_PALLET := 15
const PALLETS := 10

## Seconds the crusher takes over a lot, and a lot takes from the pad to the nip.
@export var crush_time := 8.0
@export var feed_time := 3.0

var screen: Node3D
var running := 0.0
var _bus: ShipBayBus
var _state: Dictionary = {}
var _mats: Dictionary = {}
var _housing: Node3D
var _rotors: Array[Node3D] = []
var _sparks: CPUParticles3D
var _spark_glow: OmniLight3D
var _furnace_glow: OmniLight3D
var _mouth: MeshInstance3D
var _motor: AudioStreamPlayer3D
var _grind: AudioStreamPlayer3D
var _lot: Node3D
var _mover: Node3D
var _finishing := false
var _crates_root: Node3D
var _crate_nodes: Dictionary = {}
var _zones_root: Node3D
var _zone_key := ""
var _zone_labels: Dictionary = {}
var _clock := 0.0


func _ready() -> void:
	name = "CrusherPlant"
	_mats = {
		"dark": _paint(Color(0.12, 0.13, 0.15), 0.5, 0.5, "gunmetal"),
		"steel": _paint(Color(0.6, 0.62, 0.64), 0.75, 0.4, "galvanised"),
		"roller": _paint(Color(0.7, 0.72, 0.74), 0.85, 0.3, "brushed_steel"),
		"yellow": _paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"),
		"cast": _paint(Color(0.3, 0.32, 0.34), 0.55, 0.5, "cast_iron"),
		"furnace": _paint(Color(0.42, 0.2, 0.12), 0.35, 0.6, "cast_iron"),
		"wood": _paint(Color(0.55, 0.42, 0.28), 0.0, 0.8, "wood"),
		"white": _paint(Color(0.9, 0.9, 0.88), 0.0, 0.8, "satin_paint"),
		"red": _paint(Color(0.75, 0.16, 0.12), 0.1, 0.6, "satin_paint"),
	}
	for m: String in MATERIALS:
		_mats["ingot_" + m] = _paint(METAL_LOOK[m], 0.2 if ["glass", "crystal"].has(m) else 0.8, 0.35, "bare_steel")
	_build_pad()
	_build_ramp()
	_build_crusher()
	_build_smelter()
	_build_ingot_yard()
	_build_screen()
	_crates_root = Node3D.new()
	_crates_root.name = "Crates"
	add_child(_crates_root)
	_zones_root = Node3D.new()
	_zones_root.name = "Ingots"
	add_child(_zones_root)
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if _bus:
		_bus.line_changed.connect(_on_line_changed)
		_bus.stock_changed.connect(_draw_crates)
	_state = _crusher_state()
	_draw_crates()
	_show()


func _exit_tree() -> void:
	if _bus:
		if _bus.line_changed.is_connected(_on_line_changed):
			_bus.line_changed.disconnect(_on_line_changed)
		if _bus.stock_changed.is_connected(_draw_crates):
			_bus.stock_changed.disconnect(_draw_crates)


func _crusher_state() -> Dictionary:
	return (_bus.line_state().get("crusher", {}) as Dictionary) if _bus else {}


func _on_line_changed() -> void:
	var was := _state
	_state = _crusher_state()
	var now := str(_state.get("state", ""))
	var then := str(was.get("state", ""))
	if now == "running" and then != "running":
		running = crush_time
		_start(true)
		# The lot left its pallet: it rides up the ramp into the mouth.
		_feed_in(_state.get("lot", {}), _state.get("from", []))
	elif now != "running" and then == "running":
		running = 0.0
		_start(false)
		Sfx.play("chime", self, -8.0)
		if int(_state.get("cast", 0)) > 0:
			LineParts.play("hiss", _furnace_glow, -4.0)
	_draw_crates()
	_show()


func _process(delta: float) -> void:
	if running > 0.0:
		running = maxf(running - delta, 0.0)
		_animate(1.0 - running / maxf(crush_time, 0.01))
		if running <= 0.0 and _bus and _bus.line_runs_here() and not _finishing:
			_finishing = true
			_bus.line_request("finish", {"line": "crusher"})
	elif _finishing:
		_finishing = false
	if _furnace_glow:
		_furnace_glow.light_energy = 1.6 + 0.3 * sin(Time.get_ticks_msec() * 0.007) + (1.2 if running > 0.0 else 0.0)
	# On the host the plant feeds itself: an empty crusher takes the next lot on the pad.
	if _bus and _bus.line_runs_here() and str(_state.get("state", "")) == "":
		_clock -= delta
		if _clock <= 0.0:
			_clock = 0.5
			var next := _next_crate()
			if next != "":
				_bus.line_request("crush", {"crate": next})


## The lot waiting longest on the feed pad, or "".
func _next_crate() -> String:
	var best := ""
	var best_n := 1 << 30
	for id: String in _bus.line_crates():
		if str(_bus.line_crates()[id].line) == "crush" and int(id.get_slice("/", 1)) < best_n:
			best_n = int(id.get_slice("/", 1))
			best = id
	return best


# --- Drawing the state ---------------------------------------------------------------------

func _show() -> void:
	if screen == null:
		return
	var state := str(_state.get("state", ""))
	var lot: Dictionary = _state.get("lot", {})
	var waiting := 0
	if _bus:
		for c: Dictionary in _bus.line_crates().values():
			if str(c.line) == "crush":
				waiting += 1
	if state == "running":
		screen.call("set_status", "CRUSHING", T.AMBER)
	else:
		screen.call("set_status", "%d ON THE PAD" % waiting if waiting > 0 else "IDLE", T.CYAN if waiting > 0 else T.DIM)
	var lines := PackedStringArray()
	if state == "running":
		lines.append("%s x%d  %d%%" % [str(lot.get("name", "")).to_upper().left(20), int(lot.get("qty", 1)), roundi(float(lot.get("condition", 0.0)) * 100.0)])
	else:
		lines.append("Lots too worn to refurbish come\nhere to be crushed and smelted.")
	var dust: Dictionary = _state.get("dust", {})
	var parts := PackedStringArray()
	for m: String in MATERIALS:
		if float(dust.get(m, 0.0)) >= 0.1:
			parts.append("%s %s" % [m.to_upper(), _kg(float(dust[m]))])
	lines.append("IN THE SMELTER: " + ("  ".join(parts) + " KG" if not parts.is_empty() else "NOTHING"))
	var ingots: Dictionary = _state.get("ingots", {})
	var total := 0
	for m: String in ingots:
		total += int(ingots[m])
	lines.append("INGOT YARD: %d INGOTS (%s KG EACH)" % [total, _kg(ShipBayBus.INGOT_KG)])
	screen.call("set_body", "\n".join(lines))
	_draw_lot()
	_draw_ingots()


## The lot in the crusher's nip while it runs (the copy riding the ramp draws it first).
func _draw_lot() -> void:
	var lot: Dictionary = _state.get("lot", {})
	if str(_state.get("state", "")) != "running" or lot.is_empty() or is_instance_valid(_mover):
		if _lot:
			_lot.visible = false
		return
	if _lot == null:
		_lot = Node3D.new()
		_lot.name = "Lot"
		add_child(_lot)
	_dress(_lot, lot)
	_lot.visible = true


func _dress(node: Node3D, lot: Dictionary) -> void:
	var key := "%s|%.2f" % [str(lot.get("item", "")), float(lot.get("mass", 0.0))]
	if node.get_meta("key", "") == key:
		return
	node.set_meta("key", key)
	for c in node.get_children():
		c.free()
	node.add_child(ItemLook.make(str(lot.get("item", "")), ItemLook.Look.RUST, float(lot.get("mass", 0.0))))


## Where a lot drops into the crusher's nip (yard space).
func _nip() -> Vector3:
	return CRUSHER + Vector3(0, BED * K - 0.2, 0)


## A copy of the lot riding from its pallet up the ramp into the mouth.
func _feed_in(lot: Dictionary, from: Array) -> void:
	if lot.is_empty():
		return
	var start := Vector3(from[0], 0.15, from[2]) if from.size() == 3 else FEED_SPOTS[0] + Vector3(0, 0.15, 0)
	if is_instance_valid(_mover):
		_mover.queue_free()
	_mover = Node3D.new()
	_mover.name = "Feeding"
	add_child(_mover)
	_dress(_mover, lot)
	_mover.position = start
	var tw := create_tween()
	tw.tween_property(_mover, "position", RAMP_FOOT, feed_time * 0.25)
	tw.tween_property(_mover, "position", RAMP_TOP, feed_time * 0.55)
	tw.tween_property(_mover, "position", _nip(), feed_time * 0.2)
	tw.tween_callback(func() -> void:
		_mover.queue_free()
		_show())


## The lots waiting on the feed pad, each as itself with a tag.
func _draw_crates() -> void:
	if _bus == null or _crates_root == null:
		return
	var crates := _bus.line_crates()
	for id: String in _crate_nodes.keys():
		if not crates.has(id) or str(crates[id].line) != "crush":
			(_crate_nodes[id] as Node3D).queue_free()
			_crate_nodes.erase(id)
	for id: String in crates:
		var c: Dictionary = crates[id]
		if str(c.line) != "crush" or _crate_nodes.has(id):
			continue
		var node := Node3D.new()
		node.name = "Crate_" + id.replace("/", "_")
		node.position = _bus.crate_position(id) + Vector3(0, 0.15, 0)
		_crates_root.add_child(node)
		_dress(node, {"item": c.item, "mass": c.mass})
		var tag := Label3D.new()
		tag.text = "%s  x%d\nTO CRUSH  %d%%" % [c.name, int(c.qty), roundi(float(c.condition) * 100.0)]
		tag.font = ShipKit.mono_font()
		tag.font_size = 40
		tag.pixel_size = 0.0025
		tag.outline_size = 6
		tag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		tag.position = Vector3(0, ItemLook.size_of(str(c.item), float(c.mass)).y + 0.4, 0)
		node.add_child(tag)
		_crate_nodes[id] = node


## The ingot yard: a stack of pallets in each material's zone for the ingots cast so far.
func _draw_ingots() -> void:
	var ingots: Dictionary = _state.get("ingots", {})
	var key := str(ingots)
	if key == _zone_key or _zones_root == null:
		return
	_zone_key = key
	for c in _zones_root.get_children():
		c.free()
	var ingot := PartShapes.chamfer_box(Vector3(0.5, 0.12, 0.16), 0.03).mesh
	var pallet := PartShapes.box(Vector3(1.2, 0.14, 1.0)).mesh
	for i in MATERIALS.size():
		var m := MATERIALS[i]
		var n := int(ingots.get(m, 0))
		(_zone_labels[m] as Label3D).text = "%s\n%d INGOTS" % [m.to_upper(), n]
		var shown := mini(n, PER_PALLET * PALLETS)
		var c := _zone_centre(i)
		var full := ceili(shown / float(PER_PALLET))
		for p in full:
			var at := c + Vector3(-0.7 + (p % 2) * 1.4, 0, -2.5 + (p / 2) * 1.25)
			_part(pallet, at + Vector3(0, 0.07, 0), _mats["wood"], _zones_root)
			var on := mini(PER_PALLET, shown - p * PER_PALLET)
			for k in on:
				var layer := k / 5
				var flip := layer % 2 == 1
				var off := Vector3((k % 5 - 2) * 0.22, 0.2 + layer * 0.121, 0.0) if not flip else Vector3(0.0, 0.2 + layer * 0.121, (k % 5 - 2) * 0.19)
				_part(ingot, at + off, _mats["ingot_" + m], _zones_root, Basis(Vector3.UP, PI * 0.5) if not flip else Basis())


static func _zone_centre(i: int) -> Vector3:
	return Vector3(BAY.position.x + 0.6 + ZONE_SIZE.x * 0.5 + i * (ZONE_SIZE.x + 0.3), 0, ZONE_Z + ZONE_SIZE.y * 0.5)


# --- Running ---------------------------------------------------------------------------------

## The crusher at `k` (0..1) through its run: the rotors turn into each other, the housing
## shudders, sparks fly from the nip while there is something in it, the lot sinks in.
func _animate(k: float) -> void:
	var spin := k * crush_time * 4.0
	_rotors[0].rotation.x = spin
	_rotors[1].rotation.x = -spin
	_housing.position.z = sin(k * 300.0) * 0.012
	var biting := k > 0.15 and k < 0.9 and not is_instance_valid(_mover)
	_sparks.emitting = biting
	_spark_glow.light_energy = randf_range(1.5, 4.0) if biting else 0.0
	if _lot and _lot.visible:
		var drop := 1.2 * clampf(k * 1.6 - 0.3, 0.0, 1.0)
		_lot.position = _nip() + Vector3(0, -drop, 0) + Vector3(sin(k * 420.0), 0, cos(k * 370.0)) * 0.02
		_lot.scale = Vector3.ONE * maxf(1.0 - k, 0.05)


func _start(on: bool) -> void:
	if on:
		Sfx.play("clunk", self, -2.0)
		if _motor:
			_motor.play()
		if _grind:
			_grind.play()
		return
	if _motor:
		_motor.stop()
	if _grind:
		_grind.stop()
	_housing.position = Vector3.ZERO
	_sparks.emitting = false
	_spark_glow.light_energy = 0.0
	if _lot:
		_lot.visible = false


# --- Building --------------------------------------------------------------------------------

## The feed pad: three marked pallets on the bay's west side, and the bay's outline.
func _build_pad() -> void:
	var root := Node3D.new()
	root.name = "FeedPad"
	add_child(root)
	# The bay's outline in hazard yellow and its name on the ground.
	for z: float in [BAY.position.y, BAY.end.y]:
		_part(PartShapes.box(Vector3(BAY.size.x, 0.01, 0.2)).mesh, Vector3(BAY.get_center().x, 0.006, z), _mats["yellow"], root)
	for x: float in [BAY.position.x, BAY.end.x]:
		_part(PartShapes.box(Vector3(0.2, 0.01, BAY.size.y)).mesh, Vector3(x, 0.006, BAY.get_center().y), _mats["yellow"], root)
	for p: Vector3 in FEED_SPOTS:
		_part(PartShapes.box(Vector3(1.6, 0.14, 1.8)).mesh, p + Vector3(0, 0.07, 0), _mats["wood"], root)
		for k: float in [-1.0, 1.0]:
			_part(PartShapes.box(Vector3(2.0, 0.01, 0.1)).mesh, p + Vector3(0, 0.006, k * 1.05), _mats["red"], root)
	var words := _plate("CRUSHER FEED", Color(0.95, 0.75, 0.1))
	words.font_size = 96
	words.position = Vector3(FEED_SPOTS[0].x - 1.9, 0.02, 35.0)
	words.rotation = Vector3(-PI * 0.5, PI * 0.5, 0)
	root.add_child(words)
	var sign_board := _plate("CRUSHER BAY", Color(0.95, 0.95, 0.92))
	sign_board.font_size = 160
	sign_board.outline_size = 12
	sign_board.position = CRUSHER + Vector3(0, BED * K + 2.0 + 1.6, -WIDTH * K * 0.5 - 0.3)
	sign_board.rotation.y = PI
	root.add_child(sign_board)


## The loading ramp: a roller bed from the pad's edge up to the crusher's mouth on legs.
func _build_ramp() -> void:
	var root := Node3D.new()
	root.name = "Ramp"
	add_child(root)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.set_meta("surface", "metal")
	root.add_child(body)
	var along := RAMP_TOP - RAMP_FOOT
	var length := along.length()
	var pitch := atan2(along.y, Vector2(along.x, along.z).length())
	var basis := Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -pitch)
	var mid := (RAMP_FOOT + RAMP_TOP) * 0.5
	var width := 2.4
	for x: float in [-width * 0.5, width * 0.5]:
		_part(PartShapes.box(Vector3(0.12, 0.24, length)).mesh, mid + basis * Vector3(x, -0.12, 0), _mats["steel"], root, basis)
	var n := floori(length / 0.35)
	for i in n:
		var z := -length * 0.5 + (i + 0.5) * length / n
		_part(PartShapes.prism(10, 0.07, width - 0.1).mesh, mid + basis * Vector3(0, -0.07, z), _mats["roller"], root, basis * Basis(Vector3.FORWARD, PI * 0.5))
	for i in 4:
		var p := RAMP_FOOT.lerp(RAMP_TOP, (i + 0.5) / 4.0)
		for side: float in [-1.0, 1.0]:
			var leg_h := p.y - 0.25
			_part(PartShapes.box(Vector3(0.14, leg_h, 0.14)).mesh, Vector3(p.x, leg_h * 0.5, p.z + side * width * 0.5), _mats["dark"], root)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.4, length)
	col.shape = box
	col.transform = Transform3D(basis, mid + basis * Vector3(0, -0.2, 0))
	body.add_child(col)
	# Under the high end the ramp is a wall to walk round, not a roof to stand under.
	_collide(body, Vector3(length * 0.5, RAMP_TOP.y, width), Vector3(RAMP_TOP.x - length * 0.25, RAMP_TOP.y * 0.5, RAMP_TOP.z))


## The crusher: the line grinder's twin-shaft shredder K times over, on a plinth, its
## barred window to the north, motor and gears to the south.
func _build_crusher() -> void:
	var root := Node3D.new()
	root.name = "Crusher"
	root.add_to_group("gfx_interactable")
	root.set_meta("gfx_id", "line:crusher")
	root.set_meta("look_hint", {"title": "Crusher", "text": "Breaks worn-out lots down to dust for the smelter. It takes the next lot off the feed pad by itself.",
			"keys": []})
	root.position = CRUSHER
	add_child(root)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.set_meta("surface", "metal")
	root.add_child(body)
	# The grinder's frame: +Z its travel (yard +X), +X its front (yard -Z).
	var frame := Node3D.new()
	frame.name = "Frame"
	frame.transform = Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * K), Vector3.ZERO)
	root.add_child(frame)
	var side := 1.0
	var cast: Material = _mats["cast"]
	var top := BED + 0.75
	var cz := 0.25
	_part(PartShapes.chamfer_box(Vector3(WIDTH + 0.4, 0.12, 2.4), 0.02).mesh, Vector3(0, 0.06, 0.1), _mats["dark"], frame)
	_housing = Node3D.new()
	_housing.name = "Housing"
	frame.add_child(_housing)
	_part(PartShapes.chamfer_box(Vector3(WIDTH, BED - 0.42, 1.5), 0.03).mesh, Vector3(0, 0.12 + (BED - 0.42) * 0.5, cz), cast, _housing)
	_part(PartShapes.chamfer_box(Vector3(0.12, top - BED + 0.32, 1.5), 0.02).mesh, Vector3(-side * 0.74, (top + BED - 0.32) * 0.5, cz), cast, _housing)
	var win_y0 := BED - 0.22
	_part(PartShapes.box(Vector3(0.12, 0.1, 1.5)).mesh, Vector3(side * 0.74, win_y0 - 0.05, cz), cast, _housing)
	_part(PartShapes.box(Vector3(0.12, 0.12, 1.5)).mesh, Vector3(side * 0.74, top - 0.06, cz), cast, _housing)
	for z: float in [cz - 0.69, cz + 0.69]:
		_part(PartShapes.box(Vector3(0.12, top - win_y0 - 0.12, 0.118)).mesh, Vector3(side * 0.74, (top - 0.12 + win_y0) * 0.5, z), cast, _housing)
	for z: float in [cz - 0.32, cz, cz + 0.32]:
		_part(PartShapes.prism(8, 0.018, top - win_y0 - 0.12).mesh, Vector3(side * 0.77, (top - 0.12 + win_y0) * 0.5, z), _mats["yellow"], _housing)
	_part(PartShapes.box(Vector3(1.36, top - BED - 0.3, 0.1)).mesh, Vector3(0, (top + BED + 0.3) * 0.5, cz - 0.7), cast, _housing)
	_part(PartShapes.box(Vector3(1.36, top - BED + 0.3, 0.1)).mesh, Vector3(0, (top + BED - 0.3) * 0.5, cz + 0.7), cast, _housing)
	_part(PartShapes.box(Vector3(1.6, 0.16, 0.05)).mesh, Vector3(0, top - 0.12, cz - 0.77), _mats["yellow"], _housing)
	for z: float in [cz - 0.45, cz, cz + 0.45]:
		_part(PartShapes.box(Vector3(0.06, top - BED + 0.2, 0.06)).mesh, Vector3(-side * 0.83, (top + BED - 0.2) * 0.5, z), cast, _housing)
	for i in 2:
		var r := Node3D.new()
		r.name = "Rotor%d" % i
		r.position = Vector3(0, BED + 0.02, cz - 0.22 + 0.44 * i)
		_housing.add_child(r)
		_part(LineParts.rotor(1.3, 0.3, 7, 3, (0.0 if i == 0 else 1.3 / 7.0 * 0.5) - 1.3 / 7.0 * 0.25), Vector3.ZERO, _mats["roller"], r)
		_part(LineParts.gear(0.215, 0.07, 18), Vector3(-side * 0.93, 0, 0), _mats["steel"], r, Basis(Vector3.RIGHT, PI / 18.0 * i))
		for x: float in [-0.85, 0.85]:
			_part(PartShapes.chamfer_box(Vector3(0.08, 0.18, 0.18), 0.02).mesh, r.position + Vector3(x, 0, 0), _mats["dark"], _housing)
		_rotors.append(r)
	for y: float in [BED - 0.25, BED + 0.29]:
		_part(PartShapes.box(Vector3(0.04, 0.04, 1.0)).mesh, Vector3(-side * 1.02, y, cz), _mats["yellow"], _housing)
	for z: float in [cz - 0.48, cz + 0.48]:
		_part(PartShapes.box(Vector3(0.04, 0.5, 0.04)).mesh, Vector3(-side * 1.02, BED + 0.02, z), _mats["yellow"], _housing)
	for x: float in [-0.74, 0.74]:
		for z: float in [cz - 0.7, cz + 0.7]:
			_part(PartShapes.box(Vector3(0.05, 0.32, 0.05)).mesh, Vector3(x, top + 0.16, z), _mats["yellow"], _housing)
		_part(PartShapes.box(Vector3(0.04, 0.04, 1.44)).mesh, Vector3(x, top + 0.3, cz), _mats["yellow"], _housing)
	for z: float in [cz - 0.7, cz + 0.7]:
		_part(PartShapes.box(Vector3(1.44, 0.038, 0.038)).mesh, Vector3(0, top + 0.3, z), _mats["yellow"], _housing)
	# The hopper over the mouth that the ramp tips into.
	_part(PartShapes.frustum(0.62, 0.42, 0.5, 4).mesh, Vector3(0, top + 0.25, -0.62), _mats["yellow"], frame, Basis(Vector3.UP, PI * 0.25))
	# The motor behind, and the mouth's bed.
	_part(WreckParts.generator(Vector3(1.0, 0.8, 0.9)).mesh, Vector3(-side * 1.55, 0.55, 0.3), _mats["dark"], frame)
	_mouth = _part(PartShapes.box(Vector3(1.0, 0.06, 0.6)).mesh, Vector3(0, BED - 0.03, -0.8), _mats["roller"], frame)
	_sparks = LineParts.sparks(Vector3(0.55, 0.02, 0.06) * K)
	_sparks.position = Vector3(0, (BED + 0.28) * K, 0)
	root.add_child(_sparks)
	_spark_glow = OmniLight3D.new()
	_spark_glow.name = "SparkGlow"
	_spark_glow.light_color = Color(1.0, 0.6, 0.25)
	_spark_glow.omni_range = 9.0
	_spark_glow.light_energy = 0.0
	_spark_glow.shadow_enabled = false
	_spark_glow.set_meta("gfx_no_shadow", true)
	_spark_glow.position = Vector3(0, (BED + 0.5) * K, 0)
	root.add_child(_spark_glow)
	# Collision in yard terms (the frame is scaled): the housing and the motor.
	_collide(body, Vector3(1.5 * K, (top + 0.3) * K, (WIDTH + 0.2) * K), Vector3(cz * K, (top + 0.3) * K * 0.5, 0))
	_collide(body, Vector3(0.9 * K, 0.9 * K, 1.0 * K), Vector3(0.3 * K, 0.45 * K, 1.55 * K))
	_motor = Sfx.loop("servo", root, -6.0)
	if _motor:
		_motor.stop()
		_motor.pitch_scale = 0.4
	_grind = LineParts.loop("grind", root, -2.0)
	if _grind:
		_grind.stop()
		_grind.pitch_scale = 0.6


## The smelter: a squat furnace with a glowing door and flue, fed by a screw from under the
## crusher; ingots come out of its spout onto the cooling conveyor down to the ingot yard.
func _build_smelter() -> void:
	var root := Node3D.new()
	root.name = "Smelter"
	root.add_to_group("gfx_interactable")
	root.set_meta("gfx_id", "line:smelter")
	root.set_meta("look_hint", {"title": "Smelter", "text": "Melts the crusher's dust and casts it into ingots for the ingot yard.", "keys": []})
	root.position = SMELTER
	add_child(root)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.set_meta("surface", "metal")
	root.add_child(body)
	_part(PartShapes.chamfer_box(Vector3(3.4, 0.3, 3.4), 0.04).mesh, Vector3(0, 0.15, 0), _mats["dark"], root)
	_part(PartShapes.prism(20, 1.35, 2.8).mesh, Vector3(0, 1.7, 0), _mats["furnace"], root)
	_part(PartShapes.frustum(1.35, 0.5, 0.8, 20).mesh, Vector3(0, 3.5, 0), _mats["furnace"], root)
	_part(PartShapes.prism(12, 0.32, 3.2).mesh, Vector3(0, 5.5, 0), _mats["dark"], root)
	for y: float in [0.6, 1.7, 2.8]:
		_part(PartShapes.ring(1.35, 1.42, 0.12).mesh, Vector3(0, y, 0), _mats["steel"], root, Basis(Vector3.RIGHT, PI * 0.5))
	_collide(body, Vector3(2.8, 3.9, 2.8), Vector3(0, 1.95, 0))
	# The door on the south face, glowing round its edges, and the pour spout.
	var hot := ShipKit.glow(Color(1.0, 0.45, 0.1), 6.0)
	_part(PartShapes.box(Vector3(1.1, 1.0, 0.1)).mesh, Vector3(0, 1.6, 1.38), _mats["dark"], root)
	_part(PartShapes.box(Vector3(1.2, 0.06, 0.08)).mesh, Vector3(0, 2.12, 1.4), hot, root)
	_part(PartShapes.box(Vector3(1.2, 0.06, 0.08)).mesh, Vector3(0, 1.08, 1.4), hot, root)
	_part(PartShapes.box(Vector3(0.5, 0.18, 1.2)).mesh, Vector3(0, 0.9, 2.0), _mats["steel"], root, Basis(Vector3.RIGHT, 0.2))
	_part(PartShapes.box(Vector3(0.3, 0.04, 1.0)).mesh, Vector3(0, 0.98, 2.0), hot, root, Basis(Vector3.RIGHT, 0.2))
	_furnace_glow = OmniLight3D.new()
	_furnace_glow.name = "FurnaceGlow"
	_furnace_glow.light_color = Color(1.0, 0.5, 0.2)
	_furnace_glow.omni_range = 7.0
	_furnace_glow.light_energy = 1.6
	_furnace_glow.shadow_enabled = false
	_furnace_glow.set_meta("gfx_no_shadow", true)
	_furnace_glow.position = Vector3(0, 1.6, 2.2)
	root.add_child(_furnace_glow)
	# The screw from under the crusher's discharge up into the furnace's top.
	var from := Vector3(CRUSHER.x + 1.6 * K * 0.5 + 0.6, 0.8, CRUSHER.z + 0.8) - SMELTER
	var to := Vector3(-0.4, 4.0, 0.8)
	var along := to - from
	var len := along.length()
	var tube := Basis.looking_at(along.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	_part(PartShapes.prism(14, 0.3, len).mesh, (from + to) * 0.5, _mats["steel"], root, tube)
	_part(WreckParts.junction_box(Vector3(0.6, 0.6, 0.6), Color(1.0, 0.6, 0.15)).mesh, from + Vector3(0, -0.2, 0), _mats["dark"], root)
	# The cooling conveyor from the spout south then west along the ingot zones.
	var belt: Material = _mats["dark"]
	var spout := Vector3(0, 0, 2.9)
	var down := CONVEYOR_Z - SMELTER.z - spout.z
	_conveyor(root, spout + Vector3(0, 0, down * 0.5), down, 0.0, belt)
	var west := SMELTER.x - (BAY.position.x + 1.0)
	_conveyor(root, Vector3(-west * 0.5, 0, CONVEYOR_Z - SMELTER.z), west, PI * 0.5, belt)


## A low belt conveyor `length` long centred on `at` (in `parent`'s frame), turned `yaw`.
func _conveyor(parent: Node3D, at: Vector3, length: float, yaw: float, belt: Material) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_part(PartShapes.box(Vector3(0.9, 0.08, length)).mesh, at + Vector3(0, 0.6, 0), belt, parent, basis)
	for x: float in [-0.48, 0.48]:
		_part(PartShapes.box(Vector3(0.06, 0.16, length)).mesh, at + basis * Vector3(x, 0.62, 0), _mats["steel"], parent, basis)
	var n := maxi(2, floori(length / 2.0))
	for i in n + 1:
		var z := -length * 0.5 + i * length / n
		for x: float in [-0.42, 0.42]:
			_part(PartShapes.box(Vector3(0.06, 0.56, 0.06)).mesh, at + basis * Vector3(x, 0.28, z), _mats["dark"], parent, basis)


## The ingot yard: a painted zone for each material with its name on a board and the ground.
func _build_ingot_yard() -> void:
	var root := Node3D.new()
	root.name = "IngotYard"
	add_child(root)
	for i in MATERIALS.size():
		var m := MATERIALS[i]
		var c := _zone_centre(i)
		var paint: Material = _mats["white"]
		for z: float in [-ZONE_SIZE.y * 0.5, ZONE_SIZE.y * 0.5]:
			_part(PartShapes.box(Vector3(ZONE_SIZE.x, 0.01, 0.12)).mesh, c + Vector3(0, 0.006, z), paint, root)
		for x: float in [-ZONE_SIZE.x * 0.5, ZONE_SIZE.x * 0.5]:
			_part(PartShapes.box(Vector3(0.12, 0.01, ZONE_SIZE.y)).mesh, c + Vector3(x, 0.006, 0), paint, root)
		# A band of the metal's colour across the zone's head.
		_part(PartShapes.box(Vector3(ZONE_SIZE.x - 0.3, 0.01, 0.5)).mesh, c + Vector3(0, 0.007, -ZONE_SIZE.y * 0.5 + 0.45), _mats["ingot_" + m], root)
		# Its board on a post at the back of the zone.
		var post := c + Vector3(0, 0, ZONE_SIZE.y * 0.5 - 0.2)
		_part(PartShapes.box(Vector3(0.1, 2.2, 0.1)).mesh, post + Vector3(0, 1.1, 0), _mats["dark"], root)
		_part(PartShapes.box(Vector3(1.6, 0.6, 0.06)).mesh, post + Vector3(0, 2.4, 0), _mats["dark"], root)
		var label := _plate("%s\n0 INGOTS" % m.to_upper(), Color(0.95, 0.95, 0.92))
		label.font_size = 48
		label.position = post + Vector3(0, 2.4, -0.04)
		label.rotation.y = PI
		root.add_child(label)
		_zone_labels[m] = label
	var sign_board := _plate("INGOT YARD", Color(0.95, 0.75, 0.1))
	sign_board.font_size = 96
	sign_board.position = Vector3(BAY.get_center().x, 0.02, ZONE_Z - 0.9)
	sign_board.rotation = Vector3(-PI * 0.5, PI, 0)
	root.add_child(sign_board)


## The plant's screen on a post by the feed pad, facing the hall's door.
func _build_screen() -> void:
	var post := Vector3(BAY.position.x + 1.2, 0, BAY.position.y + 1.2)
	_part(PartShapes.box(Vector3(0.12, 1.1, 0.12)).mesh, post + Vector3(0, 0.55, 0), _mats["dark"])
	var face := Basis(Vector3.UP, PI * 0.75) * Basis(Vector3.RIGHT, -0.35)
	_part(PartShapes.chamfer_box(Vector3(0.66, 0.46, 0.06), 0.015).mesh, post + Vector3(0, 1.25, 0), _mats["dark"], null, face)
	var holder := Node3D.new()
	holder.name = "Control"
	holder.add_to_group("gfx_interactable")
	holder.set_meta("gfx_id", "line:crusher_screen")
	add_child(holder)
	screen = Touch.new()
	screen.name = "Screen"
	screen.transform = Transform3D(face, post + Vector3(0, 1.25, 0) + face * Vector3(0, 0, 0.04))
	holder.add_child(screen)
	screen.call("setup", Vector2(0.62, 0.42), "CRUSHER  CR-1", 1)


func _plate(text: String, colour: Color) -> Label3D:
	var plate := Label3D.new()
	plate.text = text
	plate.font = ShipKit.mono_font()
	plate.font_size = 36
	plate.pixel_size = 0.0025
	plate.modulate = colour
	plate.outline_size = 0
	return plate


static func _kg(kg: float) -> String:
	return "%d" % roundi(kg) if kg >= 10.0 else "%.1f" % kg


static func _paint(colour: Color, metallic: float, roughness: float, finish: String) -> Material:
	return ShipSurface.of(ShipKit.paint(colour, metallic, roughness, finish))


func _part(mesh: Mesh, at: Vector3, mat: Material, parent: Node3D = null, basis := Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, at)
	(parent if parent else self).add_child(mi)
	return mi


func _collide(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = at
	body.add_child(col)
