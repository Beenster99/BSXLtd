class_name RefurbBus
extends Node
## The refurbishing bots' module bus (Modules.bus("refurb")), beenster 19 Nov: "refurbishing
## bots, as some of our goods suppliers will provide second hand parts". The refurb works, an
## annex of the stores hall (0.4.4 playtest: "move refurbishing unit to an annex of the main
## hall"; YardLayout.ROOMS.refurb), where TartanCo RF-2 refurbishers take a second-hand part
## through inspect, strip, clean, rebuild and test, and certify it at Standard grade, the same
## size. Big parts (up to RefurbTuning.heavy_max) go under the annex's crane onto the heavy
## stand, worked by a team. Its state is a RefurbWorks stepped on the yard's shared clock.
##
## For the parts market (a vendor selling second-hand parts):
##   var refurb := Modules.bus("refurb") as RefurbBus
##   refurb.estimate("reactor_small:3R", 0.55)   # {result, seconds, cost, scrap, new_price}
##   refurb.receive_used("reactor_small:3R", 0.55, "Orbis Surplus")   # bought: it comes in
##   refurb.use_market()     # call in your register_module: the stand-in dealer stays away
##   refurb.stock()          # certified parts ready: {type id: count}
##   refurb.take("reactor_small:3")   # one fitted to a ship
##   refurb.part_certified.connect(func(type_id, lot): ...)
## A part comes in at any grade (a Reclaimed "R" variant, normally) and condition 0..1, at goods
## in; the works' cart brings it through. Until the market sells second-hand parts, a used-parts
## dealer (Kettlemoor Salvage Exchange) sends a lot or two every minute or so.
##
## Features (Flags): "refurb" (the module), "refurb.shop" (the works in its annex).

## A second-hand part came in (lot: RefurbWorks' lot dictionary).
signal lot_arrived(lot: Dictionary)
## A refurbisher started a stage on a part.
signal stage_started(lot: Dictionary)
## A part passed its bench test: `type_id` is the certified type, now in stock.
signal part_certified(type_id: String, lot: Dictionary)
## Inspection found a cracked casing: scrapped.
signal lot_scrapped(lot: Dictionary)

const FLAG := "refurb"
const SHOP_FLAG := "refurb.shop"
## The annex's room in YardLayout.ROOMS, and its box if the yard has none (station space, m).
const ROOM := "refurb"
const ROOM_FALLBACK := AABB(Vector3(48, 0, -4), Vector3(36, 16, 30))
const Shop := preload("res://modules/refurb/internal/refurb_shop.gd")

## The shop's state while the yard is open (or the last one, after it closed).
var works: RefurbWorks
## False once the parts market supplies the second-hand parts (use_market).
var standin_dealer := true

var _yard: Node
var _shop: Node3D


func register_module() -> void:
	if Modules.ready_done:
		_hook_yard()
	else:
		Modules.modules_ready.connect(_hook_yard, CONNECT_ONE_SHOT)


func _hook_yard() -> void:
	_yard = Modules.bus("yard")
	if _yard == null or not Flags.is_on(SHOP_FLAG):
		return
	if not _yard.is_connected("station_ready", open_shop):
		_yard.connect("station_ready", open_shop)
	for view: String in ["refurb_shop", "refurb_cradle", "refurb_racks", "refurb_heavy", "refurb_door"]:
		Shots.register(view, "yard.station", func(scene: Node) -> void: _show(scene, view), 90)
	var s: Node3D = _yard.call("station")
	if s:
		open_shop(s)


## Builds the works in its annex (the yard's station_ready).
func open_shop(station: Node3D) -> void:
	if station == null or station.has_node("RefurbShop"):
		return
	works = RefurbWorks.new()
	works.standin_dealer = standin_dealer
	_shop = Shop.new()
	station.add_child(_shop)
	_shop.position = shop_at()
	_shop.call("setup", self, _yard, works)


## Where the works goes in station space: the annex's floor middle (annex space's origin).
static func shop_at() -> Vector3:
	var box: AABB = (YardLayout.ROOMS[ROOM].box as AABB) if YardLayout.ROOMS.has(ROOM) else ROOM_FALLBACK
	return Vector3(box.get_center().x, box.position.y, box.get_center().z)


## The works' node while the station is open, else null.
func shop() -> Node3D:
	return _shop if is_instance_valid(_shop) else null


## A second-hand part bought: it arrives at goods in and the works' cart brings it through (on
## every player's yard, at the same tick). `condition` 0..1.
func receive_used(type_id: String, condition: float, source := "") -> void:
	var e := {"kind": "refurb.in", "type": type_id, "condition": clampf(condition, 0.0, 1.0), "source": source}
	if shop():
		_shop.call("request", e)
	elif _yard:
		_yard.call("sim_request", e)


## One certified part leaves stock (fitted to a ship).
func take(type_id: String) -> void:
	var e := {"kind": "refurb.take", "type": type_id}
	if shop():
		_shop.call("request", e)
	elif _yard:
		_yard.call("sim_request", e)


## Certified parts ready: {type id: count}.
func stock() -> Dictionary:
	return works.stock.duplicate() if works else {}


## What refurbishing a part would take: {result, seconds, cost, scrap (0..1), new_price, heavy};
## empty for a part too big for the annex (over RefurbTuning.heavy_max).
func estimate(type_id: String, condition: float) -> Dictionary:
	if works == null:
		works = RefurbWorks.new()
	return works.estimate(type_id, condition)


## The parts market supplies second-hand parts from now on: the stand-in dealer stops coming.
## Call it from your register_module, so every player's shop agrees from tick 0.
func use_market() -> void:
	standin_dealer = false
	if works:
		works.standin_dealer = false


func _show(scene: Node, view: String) -> void:
	var s := shop()
	var cam: Camera3D = scene.get("view_camera") if scene else null
	if s == null or cam == null:
		return
	# A busy works for the picture: a few minutes of work run straight away.
	if s.get("works").time < 300.0:
		s.call("fast_forward", 300.0)
	var v: Array = s.call("view_points")[view]
	cam.global_position = v[0]
	cam.look_at(v[1])
	cam.current = true


## Each thing that happens in the works (its sim calls this on every machine, at the same tick).
func _shop_event(kind: String, lot: Dictionary) -> void:
	match kind:
		"arrived":
			lot_arrived.emit(lot)
		"stage":
			stage_started.emit(lot)
		"certified":
			part_certified.emit(String(lot.result), lot)
		"scrapped":
			lot_scrapped.emit(lot)
