extends Node3D
## The recycler in Pre-assembly: a shredder that breaks stored goods in really bad condition
## (under ShipBayBus.RECYCLE_BELOW) down into raw materials. A dark plinth under a machine
## housing with a hopper on top, a chute down the front into an output bin of ingots, and a
## touch screen on the front: PREV / NEXT pick a poor lot from the stores (worst first), the
## screen shows what it breaks down into, and RECYCLE puts it through. The lot leaves the
## stores and the bus says scrap_recycled with the materials; Business adds them to stock.
## The machine runs for `run_time` with its lamps lit and a motor sound.
##
## Its +Z faces the hall (the front, where you stand); the origin is on the floor.

const Touch := preload("res://modules/ship_bay/internal/kit/touch_screen.gd")
const T := preload("res://modules/ui/api/terminal_kit.gd")

## The machine's footprint (x across, z deep) and housing height, metres.
const SIZE := Vector3(2.2, 2.0, 2.4)
const PLINTH := 0.25

## How long a lot takes to go through, seconds.
@export var run_time := 2.5

var screen: Node3D
## The poor lots in the stores now, and which one the screen shows.
var lots: Array[Dictionary] = []
var pick := 0
## Seconds left on the lot going through (0 when idle).
var running := 0.0
## Lots put through since the yard loaded (the output bin's pile grows with them).
var recycled := 0

var _bus: ShipBayBus
var _lamp: MeshInstance3D
var _lamp_on: Material
var _lamp_off: Material
var _ingots: Array[MeshInstance3D] = []
var _motor: AudioStreamPlayer3D
var _mats := {}


func _ready() -> void:
	name = "Recycler"
	add_to_group("gfx_interactable")
	set_meta("gfx_id", "yard:recycler")
	_mats = {
		"body": ShipSurface.of(ShipKit.paint(Color(0.24, 0.42, 0.58), 0.35, 0.45, "satin_paint")),
		"dark": ShipSurface.of(ShipKit.paint(Color(0.12, 0.13, 0.15), 0.5, 0.5, "gunmetal")),
		"steel": ShipSurface.of(ShipKit.paint(Color(0.6, 0.62, 0.64), 0.75, 0.4, "galvanised")),
		"yellow": ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint")),
		"ingot": ShipSurface.of(ShipKit.paint(Color(0.72, 0.62, 0.5), 0.8, 0.35, "brushed_alloy")),
	}
	_lamp_on = ShipKit.glow(Color(1.0, 0.55, 0.15), 4.0)
	_lamp_off = ShipKit.glow(Color(0.25, 0.9, 0.45), 1.5)
	_build()
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if _bus:
		_bus.stock_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if _bus and _bus.stock_changed.is_connected(refresh):
		_bus.stock_changed.disconnect(refresh)


## Re-reads the poor lots from the stores and redraws the screen.
func refresh() -> void:
	var was := str(lots[pick].location) if pick < lots.size() else ""
	lots = _bus.scrap_stock() if _bus else []
	pick = 0
	for i in lots.size():
		if str(lots[i].location) == was:
			pick = i
	_show()


func next(way := 1) -> void:
	if lots.is_empty():
		return
	pick = posmod(pick + way, lots.size())
	Sfx.play("tick", self, -10.0)
	_show()


## RECYCLE: the lot on the screen goes through.
func recycle() -> void:
	if running > 0.0 or pick >= lots.size() or _bus == null:
		Sfx.play("error", self)
		return
	var lot: Dictionary = lots[pick]
	_bus.recycle_stock(str(lot.location))
	running = run_time
	recycled += 1
	_lamp.material_override = _lamp_on
	if _motor:
		_motor.play()
	Sfx.play("clunk", self)
	_pile()
	_show()


func _process(delta: float) -> void:
	if running <= 0.0:
		return
	running = maxf(running - delta, 0.0)
	# A shudder while it shreds.
	$Housing.position.x = sin(running * 60.0) * 0.004
	if running == 0.0:
		$Housing.position.x = 0.0
		_lamp.material_override = _lamp_off
		if _motor:
			_motor.stop()
		Sfx.play("chime", self, -8.0)
		_show()


func _show() -> void:
	if screen == null:
		return
	if running > 0.0:
		screen.call("set_status", "RUNNING", T.AMBER)
	else:
		screen.call("set_status", "%d POOR LOTS" % lots.size() if not lots.is_empty() else "NOTHING POOR", T.GOOD if not lots.is_empty() else T.DIM)
	if lots.is_empty():
		screen.call("set_body", "Nothing in the stores is poor enough.\nGoods under %d%% condition go here." % roundi(ShipBayBus.RECYCLE_BELOW * 100.0), T.DIM)
	else:
		var lot: Dictionary = lots[pick]
		var mats := ShipBayBus.scrap_materials(str(lot.item), int(lot.qty))
		var parts := PackedStringArray()
		for m: String in mats:
			parts.append("%s %s KG" % [m.to_upper(), _kg(float(mats[m]))])
		screen.call("set_body", "%d / %d  %s x%d  %d%%\n-> %s" % [pick + 1, lots.size(), str(lot.name).to_upper().left(18),
				int(lot.qty), roundi(float(lot.condition) * 100.0), "  ".join(parts)])
	screen.call("set_button", "go", "RECYCLE", not lots.is_empty() and running <= 0.0)


static func _kg(kg: float) -> String:
	return "%d" % roundi(kg) if kg >= 10.0 else "%.1f" % kg


## The output bin's pile: an ingot more per lot, up to its rim.
func _pile() -> void:
	for i in _ingots.size():
		_ingots[i].visible = i < recycled * 2


func _build() -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.set_meta("surface", "metal")
	add_child(body)
	var housing := Node3D.new()
	housing.name = "Housing"
	add_child(housing)
	_part(PartShapes.chamfer_box(Vector3(SIZE.x + 0.2, PLINTH, SIZE.z + 0.2), 0.03).mesh, Vector3(0, PLINTH * 0.5, 0), _mats["dark"])
	_part(PartShapes.chamfer_box(Vector3(SIZE.x, SIZE.y, SIZE.z), 0.06).mesh, Vector3(0, PLINTH + SIZE.y * 0.5, 0), _mats["body"], housing)
	_collide(body, Vector3(SIZE.x + 0.2, PLINTH + SIZE.y, SIZE.z + 0.2), Vector3(0, (PLINTH + SIZE.y) * 0.5, 0))
	# The hopper: four steel walls round an opening in the top, a dark throat inside.
	var top := PLINTH + SIZE.y
	var hw := 0.8
	for k: float in [-1.0, 1.0]:
		_part(PartShapes.box(Vector3(hw * 2.0, 0.6, 0.05)).mesh, Vector3(0, top + 0.3, k * hw), _mats["steel"], housing)
		_part(PartShapes.box(Vector3(0.05, 0.6, hw * 2.0)).mesh, Vector3(k * hw, top + 0.3, 0), _mats["steel"], housing)
	_part(PartShapes.box(Vector3(hw * 2.0 - 0.1, 0.02, hw * 2.0 - 0.1)).mesh, Vector3(0, top + 0.02, 0), _mats["dark"], housing)
	_collide(body, Vector3(hw * 2.0 + 0.05, 0.6, hw * 2.0 + 0.05), Vector3(0, top + 0.3, 0))
	# Shredder rollers seen down the throat.
	for x: float in [-0.25, 0.25]:
		_part(PartShapes.prism(10, 0.18, hw * 1.7).mesh, Vector3(x, top - 0.12, 0), _mats["steel"], housing, Basis(Vector3.RIGHT, PI * 0.5))
	# The motor on the back, a vent and hazard stripes on the front.
	_part(WreckParts.generator(Vector3(1.2, 0.8, 0.6)).mesh, Vector3(0, PLINTH + 0.6, -SIZE.z * 0.5 - 0.32), _mats["dark"])
	_part(PartShapes.louvre(0.8, 0.4, 0.04, 5).mesh, Vector3(-0.55, PLINTH + 0.45, SIZE.z * 0.5 + 0.01), _mats["dark"], housing, Basis(Vector3.RIGHT, PI * 0.5))
	var n := 11
	for i in n:
		if i % 2 == 1:
			_part(PartShapes.box(Vector3(SIZE.x / n, 0.12, 0.012)).mesh, Vector3(-SIZE.x * 0.5 + (i + 0.5) * SIZE.x / n, PLINTH + SIZE.y - 0.12, SIZE.z * 0.5 + 0.007), _mats["dark"], housing)
	# The chute out of the front's right side into the output bin.
	var bin := Vector3(0.55, 0, SIZE.z * 0.5 + 0.55)
	_part(PartShapes.box(Vector3(0.6, 0.06, 0.7)).mesh, Vector3(0.55, PLINTH + 0.95, SIZE.z * 0.5 + 0.3), _mats["steel"], null, Basis(Vector3.RIGHT, 0.45))
	_part(PartShapes.box(Vector3(0.9, 0.04, 0.8)).mesh, bin + Vector3(0, 0.02, 0), _mats["yellow"])
	for k: float in [-1.0, 1.0]:
		_part(PartShapes.box(Vector3(0.9, 0.5, 0.03)).mesh, bin + Vector3(0, 0.25, k * 0.39), _mats["yellow"])
		_part(PartShapes.box(Vector3(0.03, 0.5, 0.8)).mesh, bin + Vector3(k * 0.44, 0.25, 0), _mats["yellow"])
	_collide(body, Vector3(0.9, 0.5, 0.8), bin + Vector3(0, 0.25, 0))
	var ingot := PartShapes.chamfer_box(Vector3(0.24, 0.07, 0.1), 0.01).mesh
	for i in 24:
		var row := i % 3
		var col := (i / 3) % 4
		var layer := i / 12
		var mi := _part(ingot, bin + Vector3(-0.27 + row * 0.27, 0.08 + layer * 0.075, -0.24 + col * 0.16), _mats["ingot"], null, Basis(Vector3.UP, 0.08 * float(i % 5 - 2)))
		mi.visible = false
		_ingots.append(mi)
	# A lamp on the housing: green idle, amber while it runs.
	_lamp = _part(PartShapes.prism(12, 0.06, 0.1).mesh, Vector3(SIZE.x * 0.5 - 0.2, top + 0.05, SIZE.z * 0.5 - 0.2), _lamp_off, housing)
	var plate := Label3D.new()
	plate.text = "RECYCLER  RX-2"
	plate.font = ShipKit.mono_font()
	plate.font_size = 40
	plate.pixel_size = 0.0025
	plate.modulate = Color(0.95, 0.95, 0.92)
	plate.outline_size = 0
	plate.position = Vector3(0, PLINTH + SIZE.y - 0.32, SIZE.z * 0.5 + 0.012)
	housing.add_child(plate)
	# The touch screen on the front, tilted up to whoever stands there.
	_part(PartShapes.chamfer_box(Vector3(0.62, 0.44, 0.06), 0.015).mesh, Vector3(-0.35, PLINTH + 1.25, SIZE.z * 0.5 + 0.02), _mats["dark"], housing, Basis(Vector3.RIGHT, -0.2))
	screen = Touch.new()
	screen.name = "Screen"
	screen.transform = Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(-0.35, PLINTH + 1.25, SIZE.z * 0.5 + 0.06))
	housing.add_child(screen)
	screen.call("setup", Vector2(0.58, 0.4), "RECYCLER", 3)
	screen.call("add_button", "prev", "PREV", next.bind(-1))
	screen.call("add_button", "next", "NEXT", next.bind(1))
	screen.call("add_button", "go", "RECYCLE", recycle, true)
	_motor = Sfx.loop("servo", self, -16.0)
	if _motor:
		_motor.stop()


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
