extends Node3D
## Goods in and the stores' bots (0.4.0 playtest): "a goods in area which is a place for large
## hauler ships to offload their deliveries to. When we start a new contract and start to buy
## the parts this should be a busy area with multiple deliveries coming in and being directed
## to their racks before bots are ordering in from the yard side."
##
## Buying parts (`order`) sends haulers to the berths outside goods in; store bots draw each
## load out of a hauler's hold with their tractor field (Void Salvage's grip, YardFieldGrip),
## set it down in that hauler's goods-in bay, then carry it to the rack place the stores give
## it and slide it in. Sending parts to the yard (`send_to_yard`) has store bots take them off
## the racks to the yard-side bays along the open face, where yard bots fly them out to the
## build berth. All presentation over a YardRackStore: the stores change as a load lands.

const Look := preload("res://modules/yard/internal/yard_stock_look.gd")
const StoresShellRef := preload("res://modules/yard/internal/stores_shell.gd")
const BotLook := preload("res://modules/yard/internal/yard_bot_look.gd")
const HaulerLook := preload("res://modules/yard/internal/yard_hauler_look.gd")
const FreighterLook := preload("res://modules/yard/internal/yard_freighter_look.gd")
## The freight lines' own courier, hauler and freighter (19 Nov, flag yard.delivery_ships).
const Ships := preload("res://modules/yard/internal/yard_delivery_ships.gd")
## The bots' charger racks (0.4.4 playtest, flag yard.charger_racks): their homes.
const Racks := preload("res://modules/yard/internal/charger_racks.gd")
const Warp := preload("res://modules/yard/internal/yard_warp.gd")

signal delivered(part: String, qty: int)
signal sent(part: String, qty: int)
## A kit (YardKits) has all arrived where it was asked for: its order's id and its loads.
signal kit_delivered(order_id: int, kit: String)

## Bots' speed (m/s) and how long a tractor draw takes (s).
@export var bot_speed := 9.0
@export var draw_seconds := 1.2
## Haulers' cruise in and out (m/s), and how far off they come from (m, east of the berths).
@export var hauler_speed := 28.0
@export var hauler_approach := 260.0
## With yard.warp_out, how far past its berth (m) a delivery jumps to warp (21 Nov).
@export var warp_after := 45.0
## Deliveries gone by warp so far (tests read it).
var warps := 0
@export var store_bots := 10
@export var yard_bots := 6
## How long a kit's loads stay where a mover bot set them down for you before they go back (s).
@export var kit_keep_seconds := 150.0
## Loads one hauler carries at most.
@export var hauler_loads := 6
## Each hauler's own bots, in its freight line's livery, that help unload it (0.4.1).
@export var hauler_crew := 2
## The bulk freighter (0.4.1): a big order (this many loads waiting or more) brings her
## instead of the haulers; she carries up to `ship_loads`, with her own crew of bots.
@export var ship_threshold := 30
@export var ship_loads := 36
@export var ship_crew := 6
@export var ship_speed := 18.0   # m/s
## Where she berths, alongside goods in (station space: the middle of her hold floor).
const SHIP_BERTH := Vector3(84.0 + 12.0 + 15.0, 0.0, -34.0)

## Bots cruise over the racks at this height (m), each a little apart.
const CRUISE_Y := 13.0
const YARD_CRUISE_Y := 7.0
## Where yard bots set loads down at the build berth (station space): a grid from here.
const BERTH_STAGING := Vector3(6.0, -1.5, -73.5)
const BOT_HANG := 0.9

var store: YardRackStore
## The charger racks (null with yard.charger_racks off: the bots hover at their old spots).
var racks: Racks
## {node, berth (index), state ("in", "open", "out"), loads: Array[load], t}.
var haulers: Array[Dictionary] = []
## Loads waiting for a hauler (more bought than the berths take at once).
var backlog: Array[Dictionary] = []
## A load: {part, qty, node (Node3D drawn), at (where it rests), where ("hauler", "bay",
## "rack", "dispatch", "berth", "carried"), claimed (bool), slot, spot}.
var loads: Array[Dictionary] = []
## {node, grip, yard (bool), job (Array of steps), carrying (load or {}), home}.
var bots: Array[Dictionary] = []
## Parts asked for at the yard side, not yet taken off a rack: {part, qty}.
var yard_asks: Array[Dictionary] = []

var _bay_spots: Array = []        # per goods-in bay: spot -> load or null
var _dispatch_spots: Array = []   # per dispatch bay
var _berth_used := 0
var _hauler_free: Array[bool] = []
var _mats: Dictionary = {}
var _next_id := 0
var _next_brand := 0
var _ship: Dictionary = {}
## The lines' own ships (YardDeliveryShips) in place of the 0.4.1 hauler and freighter.
var _lines_ships := false
## Kits on their way (deliver_kit): {id, kit, to (Node3D), asked (parts), arrived (parts),
## loads (the loads set down so far), done}.
var kit_orders: Array[Dictionary] = []
var _next_kit := 0
var _clock := 0.0

## The yard bots are mover bots too: out of the stores by its corridor door, along the
## corridor and in at a room's door (station space, m; y is the bots' corridor height).
const STORES_DOOR := Vector3(30.0, 2.4, -4.0)
const MOVER_AISLE_X := 33.5
const CORRIDOR_Z := -2.0
const CORRIDOR_Y := 2.4
## room id -> its corridor door's x and a point just inside it (z).
const ROOM_DOORS := {
	"design": Vector2(6.25, -6.5), "contracts": Vector2(-6.0, 2.5), "crew": Vector2(10.0, 2.5),
	"quarters": Vector2(32.0, 2.5), "airlock": Vector2(-36.0, -2.0), "design_lock": Vector2(6.25, -6.5),
}


func build(rack_store: YardRackStore) -> void:
	store = rack_store
	_lines_ships = Flags.is_on(YardBus.DELIVERY_SHIPS)
	if Flags.is_on(YardBus.CHARGER_RACKS):
		racks = Racks.new()
		add_child(racks)
		racks.build(store_bots, yard_bots, BotLook.BSX_STORES.accent, BotLook.BSX_YARD.accent)
	for b in YardRackStore.GOODS_IN_BAYS.size():
		_bay_spots.append([null, null, null, null, null, null, null, null, null, null, null, null])
	for b in YardRackStore.DISPATCH_BAYS.size():
		_dispatch_spots.append([null, null, null, null, null, null])
	for i in YardRackStore.HAULER_BERTHS.size():
		_hauler_free.append(true)
	for i in store_bots + yard_bots:
		var yard := i >= store_bots
		var home := _home(i, yard)
		var bot := _make_bot(i, yard)
		bot.position = home
		add_child(bot)
		var grip := YardFieldGrip.new()
		grip.tethers = 3
		grip.tether_width = 0.05
		add_child(grip)
		bots.append({"node": bot, "grip": grip, "yard": yard, "job": [], "carrying": {}, "home": home, "index": i})


## Buys parts: [{part, qty}...]. Haulers bring them in loads (a rack place's worth each).
func order(items: Array) -> void:
	for it: Dictionary in items:
		var part: String = it.part
		if not YardRackStore.PARTS.has(part):
			continue
		var left := int(it.qty)
		var stack := int(YardRackStore.PARTS[part].stack)
		while left > 0:
			var n := mini(left, stack)
			backlog.append({"part": part, "qty": n})
			left -= n
	_call_haulers()


## Asks for parts at the yard side: [{part, qty}...]. Bots take them off the racks.
func send_to_yard(items: Array) -> void:
	for it: Dictionary in items:
		if YardRackStore.PARTS.has(it.part):
			yard_asks.append({"part": it.part, "qty": int(it.qty)})


## Sends a kit (YardKits id) to `to` wherever it is (a player's rig, a worker bot): mover bots
## take its parts off the racks and bring them, following it, and set them down by it. Returns
## the order's id (kit_delivered fires with it), -1 for an unknown kit. Parts out of stock are
## left out. With `wait` the movers don't set their loads down: they hover by `to` holding them
## until every part has been taken (`take_piece`), then go home (the worker bots' supplies).
func deliver_kit(kit: String, to: Node3D, wait := false) -> int:
	if not YardKits.KITS.has(kit) or to == null:
		return -1
	_next_kit += 1
	var o := {"id": _next_kit, "kit": kit, "to": to, "asked": 0, "arrived": 0, "loads": [], "done": false, "wait": wait}
	kit_orders.append(o)
	var parts := YardKits.parts(kit)
	parts.reverse()
	for it: Dictionary in parts:
		if not YardRackStore.PARTS.has(it.part):
			continue
		var have := mini(int(it.qty), store.count(it.part))
		if have <= 0:
			continue
		o.asked = int(o.asked) + have
		yard_asks.push_front({"part": it.part, "qty": have, "kit": o.id})   # ahead of the yard's own asks
	if int(o.asked) == 0:
		o.done = true
		kit_delivered.emit(o.id, kit)
	return o.id


func kit_order(id: int) -> Dictionary:
	for o in kit_orders:
		if int(o.id) == id:
			return o
	return {}


## Takes a delivered load away (a worker bot fitted it, or nobody wanted it).
func consume(l: Dictionary) -> void:
	for i in loads.size():
		if int(loads[i].id) == int(l.id):
			loads.remove_at(i)
			break
	if is_instance_valid(l.node):
		(l.node as Node).queue_free()


## Loads movers are holding by `to`, waiting for their parts to be taken (deliver_kit's wait).
func waiting_loads(to: Node3D) -> Array:
	var out := []
	for o in kit_orders:
		if o.to == to:
			for l: Dictionary in o.loads:
				if l.where == "waiting" and int(l.qty) > 0:
					out.append(l)
	return out


## Takes one part off a waiting load: a node at the part's place (its meshes in part space), now
## the caller's to place. The mover goes home once its load is all taken. Null if none is left.
func take_piece(l: Dictionary) -> Node3D:
	var qty := int(l.qty)
	if qty <= 0 or not is_instance_valid(l.node):
		return null
	var ln: Node3D = l.node
	var layers: Array = Look.layers(l.part)
	var at: Transform3D = load_layout(l.part, int(l.get("full", qty)))[qty - 1]
	var piece := Node3D.new()
	piece.name = "Piece_%s" % l.part
	add_child(piece)
	piece.global_transform = ln.global_transform * at
	var kids := ln.get_children()
	for k in layers.size():
		var i := (qty - 1) * layers.size() + k
		if i < kids.size():
			var mi := kids[i] as MeshInstance3D
			ln.remove_child(mi)
			mi.transform = Transform3D.IDENTITY
			piece.add_child(mi)
	l.qty = qty - 1
	return piece


## True while anything is on its way: a hauler, a load, a bot at work or a part still asked for.
func busy() -> bool:
	if not backlog.is_empty() or not haulers.is_empty() or not yard_asks.is_empty():
		return true
	for l in loads:
		if l.where != "berth" and l.where != "delivered" and l.where != "waiting":
			return true
	for b in bots:
		if not (b.job as Array).is_empty() and not (b.job[0] as Dictionary).has("wait"):
			return true
	return false


func _process(delta: float) -> void:
	step(delta)


## Moves everything on by `delta` seconds (tests call it directly).
func step(delta: float) -> void:
	_clock += delta
	_step_haulers(delta)
	for l in loads.duplicate():
		if l.where == "delivered" and not l.get("kept", false) and _clock - float(l.get("landed_at", 0.0)) > kit_keep_seconds:
			consume(l)
	for b in bots.duplicate():
		if b.has("hauler") and bool(b.aboard) and b.hauler.state != "open":
			BotLook.animate(b.node, delta, false)
			continue
		if (b.job as Array).is_empty():
			_next_job(b)
		_step_bot(b, delta)
	if racks:
		racks.show_charging(bots)


# --- Haulers -------------------------------------------------------------------------------

func _call_haulers() -> void:
	if not _ship.is_empty():
		return   # she has the berths
	if backlog.size() >= ship_threshold and not _hauler_free.has(false):
		_call_ship()
		return
	for i in _hauler_free.size():
		if backlog.is_empty():
			return
		if not _hauler_free[i]:
			continue
		_hauler_free[i] = false
		var cargo: Array[Dictionary] = []
		while not backlog.is_empty() and cargo.size() < hauler_loads:
			cargo.append(backlog.pop_front())
		var berth: Vector3 = YardRackStore.HAULER_BERTHS[i]
		var brand: Dictionary = BotLook.BRANDS[_next_brand % BotLook.BRANDS.size()]
		_next_brand += 1
		# A courier for one or two loads, else a hauler (the lines' own ships, under the flag).
		var size := Ships.size_for(cargo.size()) if _lines_ships else ""
		var node: Node3D
		if _lines_ships:
			node = Ships.make(brand, size)
			node.name = "Hauler%d" % i
		else:
			node = _make_hauler(i, brand)
		node.position = berth + Vector3(hauler_approach + 30.0 * i, 6.0, 0)
		add_child(node)
		var h := {"node": node, "berth": i, "kind": "hauler", "state": "in", "loads": [], "t": 0.0, "brand": brand, "crew": [], "size": size}
		for k in (1 if size == Ships.SMALL else hauler_crew):
			_add_crew(h, brand, Ships.crew_park(size, k) if _lines_ships else Vector3(3.0 + k * 2.6, 1.2, -1.9 + k * 3.8), k)
		for k in cargo.size():
			var l := _new_load(cargo[k].part, int(cargo[k].qty))
			l.where = "hauler"
			l.hold = k
			node.add_child(l.node)
			l.node.position = Ships.hold_spot(size, k) if _lines_ships else _hold_spot(k)
			(h.loads as Array).append(l)
		haulers.append(h)


## The bulk freighter comes in with the next `ship_loads` loads, her crew aboard.
func _call_ship() -> void:
	var brand: Dictionary = BotLook.BRANDS[_next_brand % BotLook.BRANDS.size()]
	_next_brand += 1
	var node: Node3D
	if _lines_ships:
		node = Ships.make(brand, Ships.LARGE)
		node.name = "Freighter"
	else:
		node = _make_freighter(brand)
	node.position = SHIP_BERTH + Vector3(hauler_approach + 120.0, 0.0, 0.0)
	add_child(node)
	var h := {"node": node, "berth": -1, "kind": "ship", "state": "in", "loads": [], "t": 0.0, "brand": brand, "crew": [], "size": "large"}
	var k := 0
	while not backlog.is_empty() and k < ship_loads:
		var it: Dictionary = backlog.pop_front()
		var l := _new_load(it.part, int(it.qty))
		l.where = "hauler"
		l.hold = k
		node.add_child(l.node)
		l.node.position = _ship_spot(k)
		(h.loads as Array).append(l)
		k += 1
	for c in ship_crew:
		var park := Vector3(-6.0 + float(c % 2) * 8.0, 11.0, -20.0 + float(c / 2) * 20.0)
		_add_crew(h, brand, park, c)
	haulers.append(h)
	_ship = h


## Where a load stands in her hold (her space): three rows across, twelve along.
func _ship_spot(k: int) -> Vector3:
	return Vector3(-9.0 + float(k % 3) * 6.0, 0.0, -26.0 + float(k / 3) * 4.7)


## One of a delivery's own bots, parked aboard at `park` (its ship's space).
func _add_crew(h: Dictionary, brand: Dictionary, park: Vector3, k: int) -> void:
	var node: Node3D = h.node
	var crew := BotLook.make(brand, "%s %d" % [String(brand.name).get_slice(" ", 0).left(3), k + 1])
	crew.name = "CrewBot%d" % k
	crew.position = park
	node.add_child(crew)
	var grip := YardFieldGrip.new()
	grip.tethers = 3
	grip.tether_width = 0.05
	add_child(grip)
	var b := {"node": crew, "grip": grip, "yard": false, "job": [], "carrying": {}, "home": park,
			"index": (maxi(int(h.berth), 0) * 2 + k) % maxi(store_bots, 1), "hauler": h, "park": park, "aboard": true}
	(h.crew as Array).append(b)
	bots.append(b)


func _step_haulers(delta: float) -> void:
	for h in haulers.duplicate():
		var node: Node3D = h.node
		var ship: bool = h.kind == "ship"
		var berth: Vector3 = SHIP_BERTH if ship else YardRackStore.HAULER_BERTHS[int(h.berth)]
		var top_speed := ship_speed if ship else hauler_speed
		match h.state:
			"in":
				var d := node.position.distance_to(berth)
				var speed := clampf(d * (0.35 if ship else 0.6), 2.0, top_speed)
				node.position = node.position.move_toward(berth, speed * delta)
				if node.position.distance_to(berth) < 0.02:
					h.state = "open"
			"open":
				var open := _open_by(h, delta, true)
				var left := (h.loads as Array).filter(func(l: Dictionary) -> bool: return l.where == "hauler")
				var away := (h.crew as Array).filter(func(b: Dictionary) -> bool: return not bool(b.aboard))
				if left.is_empty() and away.is_empty() and open >= 0.99:
					h.t += delta
					if h.t > 1.5:
						h.state = "out"
			"out":
				if _open_by(h, delta, false) <= 0.01:
					node.position.x += minf(top_speed, 4.0 + (node.position.x - berth.x) * 0.5) * delta
				var warp := Flags.is_on(YardBus.WARP_OUT)
				if node.position.x > berth.x + (warp_after if warp else hauler_approach):
					for b: Dictionary in h.crew:
						(b.grip as Node).queue_free()
						bots.erase(b)
					haulers.remove_at(haulers.find_custom(func(x: Dictionary) -> bool: return x.node == node))
					if warp:
						warps += 1
						Warp.jump(self, node, Vector3.RIGHT, YardSounds.enabled())
					else:
						node.queue_free()
					if ship:
						_ship = {}
					else:
						_hauler_free[int(h.berth)] = true
					_call_haulers()


## Opens (or closes) a delivery: a hauler's ramp lowers, the freighter's door slides up into
## her hull. How far open it is now, 0..1.
func _open_by(h: Dictionary, delta: float, opening: bool) -> float:
	var node: Node3D = h.node
	if h.kind == "ship":
		var top: Node3D = node.get_node("DoorTop")
		var bottom: Node3D = node.get_node("DoorBottom")
		var travel := FreighterLook.DOOR.y * 0.5 + 0.6
		top.position.y = move_toward(top.position.y, travel if opening else 0.0, delta * (1.2 if opening else 1.6))
		bottom.position.y = -top.position.y
		return top.position.y / travel
	if _lines_ships:   # the frames' lids stand up
		var t := move_toward(Ships.open_of(node), 1.0 if opening else 0.0, delta * (0.55 if opening else 0.8))
		Ships.set_open(node, t)
		return t
	var ramp: Node3D = node.get_node("Ramp")
	ramp.rotation.z = move_toward(ramp.rotation.z, 1.45 if opening else 0.0, delta * (0.8 if opening else 1.2))
	return ramp.rotation.z / 1.45


## The bulk freighter in a freight line's livery (YardFreighterLook): her door's leaves
## "DoorTop" and "DoorBottom", her
## hold lit, her line's name along her side over the door and on her bow.
func _make_freighter(brand: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Freighter"
	var livery := BotLook.livery(brand)
	var fm := FreighterLook.meshes()
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = fm.hull
	hull.material_override = livery
	n.add_child(hull)
	for leaf: String in ["door_top", "door_bottom"]:
		var door := Node3D.new()
		door.name = "DoorTop" if leaf == "door_top" else "DoorBottom"
		n.add_child(door)
		var dm := MeshInstance3D.new()
		dm.mesh = fm[leaf]
		dm.material_override = livery
		door.add_child(dm)
	for lz: float in [-20.0, 0.0, 20.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(-2.0, 11.0, lz)
		light.omni_range = 22.0
		light.light_energy = 1.4
		light.light_color = Color(1.0, 0.94, 0.84)
		light.set_meta("gfx_no_shadow", true)   # a hold lamp: its shadows drew the hall again
		n.add_child(light)
	var tag := Label3D.new()
	tag.text = String(brand.name)
	tag.font_size = 128
	tag.pixel_size = 0.06
	tag.modulate = brand.trim
	tag.outline_size = 0
	tag.position = Vector3(FreighterLook.DOOR_X - 0.6, 21.0, 0)
	tag.rotation.y = -PI * 0.5
	n.add_child(tag)
	var bow := tag.duplicate() as Label3D
	bow.pixel_size = 0.03
	bow.position = Vector3(0, 13.0, -FreighterLook.HALF.z - 6.6)
	bow.rotation.y = PI
	bow.modulate = brand.trim
	n.add_child(bow)
	n.set_meta("brand", brand.id)
	return n


## Where a load stands in a hauler's hold (the hauler's own space): two rows down the hold.
func _hold_spot(k: int) -> Vector3:
	return Vector3(-5.0 + float(k / 2) * 3.4, -2.6, -1.6 if k % 2 == 0 else 1.6)


# --- Jobs ----------------------------------------------------------------------------------

func _next_job(b: Dictionary) -> void:
	if b.has("hauler"):
		_crew_job(b)
		return
	if b.yard:
		# A load waiting at the yard side goes out to the build berth.
		for l in loads:
			if l.where == "dispatch" and not l.claimed and l.has("kit"):
				var o := kit_order(int(l.kit))
				if not o.is_empty() and is_instance_valid(o.to):
					l.claimed = true
					b.job = _wait_steps(l, o) if bool(o.get("wait", false)) else _kit_steps(l, o)
					return
				l.erase("kit")
		for l in loads:
			if l.where == "dispatch" and not l.claimed:
				l.claimed = true
				var spot := _berth_spot()
				b.job = _carry_steps(l, spot, func() -> void: _to_berth(l), false)
				return
	else:
		# A load set down at goods in goes to its rack place.
		for l in loads:
			if l.where == "bay" and not l.claimed:
				var slot := store.reserve(l.part, int(l.qty))
				if slot < 0:
					continue
				l.claimed = true
				l.slot = slot
				b.job = _carry_steps(l, store.slot_position(slot), func() -> void: _to_rack(l), true, store.pick_point(slot))
				return
		# A part asked for at the yard side comes off its rack.
		while not yard_asks.is_empty():
			var ask: Dictionary = yard_asks[0]
			var slot := store.find(ask.part)
			if slot < 0 and ask.has("kit"):   # gone since it was asked for: the kit comes without it
				yard_asks.pop_front()
				_kit_short(int(ask.kit), int(ask.qty))
				continue
			if slot < 0:
				break
			var spot := _free_spot(_dispatch_spots, YardRackStore.DISPATCH_BAYS)
			if spot.is_empty():
				break
			var n := store.take(slot, int(ask.qty))
			ask.qty = int(ask.qty) - n
			if int(ask.qty) <= 0:
				yard_asks.pop_front()
			var l := _new_load(ask.part, n)
			if ask.has("kit"):
				l.kit = int(ask.kit)
			add_child(l.node)
			l.where = "rack"
			l.claimed = true
			l.node.position = store.slot_position(slot)
			(_dispatch_spots[int(spot.bay)] as Array)[int(spot.i)] = l.id
			b.job = _fetch_steps(l, store.pick_point(slot)) + _carry_steps(l, spot.at, func() -> void: _to_dispatch(l), false)
			return
		# A load in a delivery's hold comes out to goods in.
		for h in haulers:
			if h.state == "open" and _unload_job(b, h):
				return
	# Nothing to do: home.
	if (b.node as Node3D).position.distance_to(b.home) > 0.1:
		b.job = _fly_steps(b.node.position, b.home, b)


## A hauler's own bot: out of the hold to carry its loads to goods in, then back aboard.
func _crew_job(b: Dictionary) -> void:
	var h: Dictionary = b.hauler
	var hn: Node3D = h.node
	var waiting := (h.loads as Array).filter(func(l: Dictionary) -> bool: return l.where == "hauler" and not l.claimed)
	if bool(b.aboard):
		if waiting.is_empty():
			return
		var node: Node3D = b.node
		node.reparent(self)
		b.aboard = false
	if _unload_job(b, h):
		return
	if (h.loads as Array).any(func(l: Dictionary) -> bool: return l.where == "hauler"):
		if _lines_ships and h.kind != "ship":   # wait over the frames
			b.job = [{"fly": hn.position + Ships.wait_spot(String(h.size), int(b.index))}]
		else:
			b.job = [{"fly": hn.position + Vector3(-10.0, 3.0 + float(b.index % 2) * 1.5, (b.park as Vector3).z)}]   # wait at the ramp
		return
	b.job = [{"fly": hn.position + (b.park as Vector3)}, {"board": h}]


## Gives bot `b` the next load waiting in delivery `h`'s hold, out to a free spot at goods in
## (a hauler's own bay; the freighter fills all four): true if it took one.
func _unload_job(b: Dictionary, h: Dictionary) -> bool:
	for l: Dictionary in h.loads:
		if l.where != "hauler" or l.claimed:
			continue
		var bay := int(h.berth)
		var spot: Dictionary
		if h.kind == "ship":
			spot = _free_spot(_bay_spots, YardRackStore.GOODS_IN_BAYS)
			if not spot.is_empty():
				bay = int(spot.bay)
		else:
			spot = _free_spot([_bay_spots[bay]], [YardRackStore.GOODS_IN_BAYS[bay]])
		if spot.is_empty():
			return false
		l.claimed = true
		(_bay_spots[bay] as Array)[int(spot.i)] = l.id
		var ln: Node3D = l.node
		# A hauler's loads are drawn out over its ramp; in her hold a bot goes in over each.
		var mouth := ln.global_position if h.kind == "ship" else (h.node as Node3D).position + Vector3(-11.0, 1.0, ln.position.z)
		if _lines_ships and h.kind != "ship":
			# Drawn straight up out of its frame, high enough to clear the command module.
			mouth = Vector3(ln.global_position.x, (h.node as Node3D).position.y + Ships.clear_y(String(h.size)), ln.global_position.z)
		b.job = _fetch_steps(l, mouth) + _carry_steps(l, spot.at, func() -> void: _to_bay(l), false)
		return true
	return false


## Steps that fly to `above` (a point the bot hovers at) and draw load `l` up under the bot.
func _fetch_steps(l: Dictionary, above: Vector3) -> Array:
	return [{"fly": above + Vector3(0, _load_height(l) + BOT_HANG + 0.6, 0)}, {"draw": l}]


## Steps that carry the load the bot holds to `at` (where it will rest) and let it go there:
## from over it (`from_aisle` slides it in sideways from `aisle`, for a rack place).
func _carry_steps(l: Dictionary, at: Vector3, landed: Callable, from_aisle: bool, aisle := Vector3.ZERO) -> Array:
	var steps: Array = []
	if l.where != "carried" and l.where != "rack" and l.where != "hauler":
		steps.append({"fly": at_or(l) + Vector3(0, _load_height(l) + BOT_HANG + 0.6, 0)})
		steps.append({"draw": l})
	var hover := (aisle if from_aisle else at) + Vector3(0, _load_height(l) + BOT_HANG + 0.6, 0)
	steps.append({"fly": hover})
	steps.append({"set": l, "at": at, "done": landed})
	return steps


func at_or(l: Dictionary) -> Vector3:
	return (l.node as Node3D).global_position


func _fly_steps(_from: Vector3, to: Vector3, _b: Dictionary) -> Array:
	return [{"fly": to}]


func _step_bot(b: Dictionary, delta: float) -> void:
	var node: Node3D = b.node
	var grip: YardFieldGrip = b.grip
	var job: Array = b.job
	var carrying: Dictionary = b.carrying
	if not carrying.is_empty() and carrying.where == "carried":
		(carrying.node as Node3D).global_position = node.global_position - Vector3(0, BOT_HANG + _load_height(carrying), 0)
	if not carrying.is_empty():
		var from: Array[Vector3] = [node.global_position - Vector3(0, 0.3, 0)]
		grip.hold(carrying.node, from, (carrying.node as Node3D).global_position + Vector3(0, _load_height(carrying) * 0.5, 0))
	else:
		grip.release()
	if not (racks and Racks.docked(b)):   # on its charger the fans stand still
		_spin(node, delta, not job.is_empty())
	if job.is_empty():
		return
	var s: Dictionary = job[0]
	if s.has("fly"):
		var target: Vector3 = s.fly
		if not s.has("route"):
			s.route = _route(node.position, target, int(b.index))
		var route: Array = s.route
		var to: Vector3 = route[0]
		node.position = node.position.move_toward(to, bot_speed * delta)
		var flat := Vector3(to.x - node.position.x, 0, to.z - node.position.z)
		if flat.length() > 0.3:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-flat.x, -flat.z), minf(1.0, delta * 4.0))
		if node.position.distance_to(to) < 0.01:
			route.pop_front()
			if route.is_empty():
				job.pop_front()
	elif s.has("draw"):
		var l: Dictionary = s.draw
		var ln: Node3D = l.node
		if not s.has("t"):
			s.t = 0.0
			s.from = ln.global_position
			if ln.get_parent() != self:
				ln.reparent(self)
			b.carrying = l
			if l.where == "bay":
				_free_bay_spot(l)
			elif l.where == "dispatch":
				_free_spot_of(_dispatch_spots, l)
			l.where = "drawing"
		s.t += delta / draw_seconds
		var under := node.global_position - Vector3(0, BOT_HANG + _load_height(l), 0)
		ln.global_position = (s.from as Vector3).lerp(under, _ease(minf(s.t, 1.0)))
		if s.t >= 1.0:
			l.where = "carried"
			job.pop_front()
	elif s.has("path") or s.has("path_home"):
		if not s.has("points"):
			if s.has("path_home"):   # back the way it came, then home
				var back := _mover_way(b.home, node.position)
				back.reverse()
				back.append(b.home)
				s.points = back
			else:
				s.points = _mover_way(node.position, (s.path as Node3D).global_position)
		var points: Array = s.points
		if points.is_empty():
			job.pop_front()
		else:
			var to: Vector3 = points[0]
			node.position = node.position.move_toward(to, bot_speed * delta)
			_face(node, to - node.position, delta)
			if node.position.distance_to(to) < 0.01:
				points.pop_front()
	elif s.has("follow"):
		var o: Dictionary = s.follow
		if not is_instance_valid(o.to):
			job.pop_front()
			return
		var to := _beside(node.position, o.to as Node3D, s.l)
		node.position = node.position.move_toward(to, bot_speed * 0.8 * delta)
		_face(node, (o.to as Node3D).global_position - node.position, delta)
		if node.position.distance_to(to) < 0.2:
			job.pop_front()
	elif s.has("board"):
		node.reparent((s.board as Dictionary).node)
		node.position = b.park
		node.rotation = Vector3.ZERO
		b.aboard = true
		job.pop_front()
	elif s.has("wait"):
		var l: Dictionary = s.wait
		var o: Dictionary = s.o
		if not s.has("slot"):
			s.slot = (o.loads as Array).size()
			(o.loads as Array).append(l)
			l.where = "waiting"
			o.arrived = int(o.arrived) + int(l.qty)
			_kit_check(o)
		if int(l.qty) <= 0 or not is_instance_valid(o.to):
			b.carrying = {}
			consume(l)
			job.pop_front()
			return
		# Side by side along the supply point, each load level with it, the bot over it.
		var spot := (o.to as Node3D).global_position + Vector3(0, 0, 2.6 * float(int(s.slot) % 4)) + Vector3(0, BOT_HANG + _load_height(l), 0)
		node.global_position = node.global_position.move_toward(spot, bot_speed * 0.6 * delta)
		_face(node, Vector3(1, 0, 0), delta)
		(l.node as Node3D).global_position = node.global_position - Vector3(0, BOT_HANG + _load_height(l), 0)
	elif s.has("set"):
		var l: Dictionary = s.set
		var ln: Node3D = l.node
		if not s.has("t"):
			s.t = 0.0
			s.from = ln.global_position
			if s.has("at_fn"):
				s.at = (s.at_fn as Callable).call(b)
			l.where = "setting"
		s.t += delta / draw_seconds
		ln.global_position = (s.from as Vector3).lerp(s.at, _ease(minf(s.t, 1.0)))
		if s.t >= 1.0:
			b.carrying = {}
			l.claimed = false
			(s.done as Callable).call()
			job.pop_front()


# --- Mover bots ------------------------------------------------------------------------------

## A supply load for the worker bots: out to them like a kit, then held there till it's used.
func _wait_steps(l: Dictionary, o: Dictionary) -> Array:
	var steps := _fetch_steps(l, at_or(l))
	steps.append({"path": o.to})
	steps.append({"wait": l, "o": o})
	steps.append({"path_home": true})
	return steps


## A kit load from the yard side to its order's target: drawn up, out by the way to the
## target's room, after it as it moves, and set down beside it.
func _kit_steps(l: Dictionary, o: Dictionary) -> Array:
	var steps := _fetch_steps(l, at_or(l))
	steps.append({"path": o.to})
	steps.append({"follow": o, "l": l})
	steps.append({"set": l, "at_fn": func(bot: Dictionary) -> Vector3: return _drop_at(bot, o.to as Node3D, l),
			"done": func() -> void: _kit_landed(l, o)})
	steps.append({"path_home": true})
	return steps


## The way from the stores' yard side to `to`: up the aisle and out of the stores by its
## corridor door, along the corridor, in at the room's door; out of the open face to the dock;
## by the well to the upper storey. The last leg (following it) is the follow step's.
func _mover_way(from: Vector3, to: Vector3) -> Array:
	var room := YardLayout.room_at(to + Vector3(0, 0.3, 0))
	var low := YARD_CRUISE_Y
	var pts: Array = [Vector3(from.x, maxf(low, from.y), from.z)]
	if room == "":   # outside: out of the open face
		pts.append(Vector3(from.x, low, StoresShellRef.Z_YARD - 6.0))
	elif room == "racking":
		if _storey(to) == 1:
			pts.append(Vector3(YardRackStore.WELL_X, low, clampf(to.z, -60.0, -8.0)))
			pts.append(Vector3(YardRackStore.WELL_X, YardRackStore.UPPER_FLOOR_Y + 4.0, clampf(to.z, -60.0, -8.0)))
	else:
		pts.append(Vector3(MOVER_AISLE_X, low, from.z))
		pts.append(Vector3(MOVER_AISLE_X, low, STORES_DOOR.z - 2.5))
		pts.append(Vector3(STORES_DOOR.x, CORRIDOR_Y, STORES_DOOR.z - 2.0))
		pts.append(Vector3(STORES_DOOR.x, CORRIDOR_Y, CORRIDOR_Z))
		if ROOM_DOORS.has(room):
			var d: Vector2 = ROOM_DOORS[room]
			pts.append(Vector3(d.x, CORRIDOR_Y, CORRIDOR_Z))
			pts.append(Vector3(d.x, CORRIDOR_Y, d.y))
	return pts


## Where a mover hovers to set a load down by `to`: 1.8 m short of it on the way in, its load
## just clear of the floor (in a room) or level with it (in zero g).
func _beside(from: Vector3, to: Node3D, l: Dictionary) -> Vector3:
	var p := to.global_position
	var flat := Vector3(from.x - p.x, 0, from.z - p.z)
	if flat.length() < 0.1:
		flat = Vector3.BACK
	var at := p + flat.normalized() * 1.8
	if YardLayout.has_gravity(p):
		at.y = _floor_under(p) + _load_height(l) + BOT_HANG + 0.5
	return at


func _drop_at(b: Dictionary, to: Node3D, l: Dictionary) -> Vector3:
	var at: Vector3 = (b.node as Node3D).global_position
	if YardLayout.has_gravity(to.global_position):
		return Vector3(at.x, _floor_under(to.global_position), at.z)
	return at - Vector3(0, BOT_HANG + _load_height(l) + 0.2, 0)


func _floor_under(p: Vector3) -> float:
	if YardLayout.room_at(p + Vector3(0, 0.3, 0)) == "racking":
		return YardRackStore.floor_y(_storey(p))
	return 0.0


func _kit_landed(l: Dictionary, o: Dictionary) -> void:
	l.where = "delivered"
	l.landed_at = _clock
	(o.loads as Array).append(l)
	o.arrived = int(o.arrived) + int(l.qty)
	_kit_check(o)


func _kit_short(id: int, qty: int) -> void:
	var o := kit_order(id)
	if o.is_empty():
		return
	o.asked = int(o.asked) - qty
	_kit_check(o)


func _kit_check(o: Dictionary) -> void:
	if not bool(o.done) and int(o.arrived) >= int(o.asked):
		o.done = true
		kit_delivered.emit(int(o.id), String(o.kit))


func _face(node: Node3D, way: Vector3, delta: float) -> void:
	var flat := Vector3(way.x, 0, way.z)
	if flat.length() > 0.3:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(-flat.x, -flat.z), minf(1.0, delta * 4.0))


## Up to the bot's cruise height, across, and down: over the racks, never through them. Between
## storeys (0.4.1) it goes by the well over goods in: across at its own storey's cruise to the
## well, up or down it to the other storey's, across and down.
func _route(from: Vector3, to: Vector3, index: int) -> Array:
	var lane := float(index % 5) * 0.4
	if index >= store_bots:   # yard bots fly under the open face's lintel, never over racks
		var low := YARD_CRUISE_Y + float(index % 4) * 0.6
		if Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z)) < 0.5:
			return [to]
		return [Vector3(from.x, maxf(low, from.y), from.z), Vector3(to.x, maxf(low, to.y), to.z), to]
	# Out to a hauler's hold, or in from it: through goods in's opening, under its head.
	var door_x := StoresShellRef.X1
	var door_y := StoresShellRef.GOODS_IN_H - 3.0
	if to.x > door_x + 0.5 and from.x <= door_x + 0.5:
		var z := clampf(to.z, StoresShellRef.GOODS_IN_Z.x + 2.0, StoresShellRef.GOODS_IN_Z.y - 2.0)
		var inner := Vector3(door_x - 3.0, door_y - lane, z)
		return _route(from, inner, index) + [Vector3(door_x + 3.0, door_y - lane, z), to]
	if from.x > door_x + 0.5 and to.x <= door_x + 0.5:
		var z := clampf(from.z, StoresShellRef.GOODS_IN_Z.x + 2.0, StoresShellRef.GOODS_IN_Z.y - 2.0)
		var outer := Vector3(door_x + 3.0, door_y - lane, z)
		var inner := Vector3(door_x - 3.0, door_y - lane, z)
		return [outer, inner] + _route(inner, to, index)
	var s_from := _storey(from)
	var s_to := _storey(to)
	# One end in the well (open floor to roof): fly at the other end's storey all the way.
	if from.x >= YardRackStore.UPPER_EDGE_X:
		s_from = s_to
	elif to.x >= YardRackStore.UPPER_EDGE_X:
		s_to = s_from
	var c_from := YardRackStore.floor_y(s_from) + CRUISE_Y + lane
	var c_to := YardRackStore.floor_y(s_to) + CRUISE_Y + lane
	if s_from == s_to:
		if Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z)) < 0.5:
			return [to]
		return [Vector3(from.x, maxf(c_from, from.y), from.z), Vector3(to.x, maxf(c_to, to.y), to.z), to]
	var wz := clampf(to.z if s_to == 1 else from.z, -60.0, -8.0)
	var wx := YardRackStore.WELL_X + float(index % 3) * 2.5 - 2.5
	return [Vector3(from.x, c_from, from.z), Vector3(wx, c_from, wz), Vector3(wx, c_to, wz),
			Vector3(to.x, c_to, to.z), to]


## Which storey a point is on for flying: over the upper deck's floor (west of the well) and
## above it, the upper; anywhere else the ground floor (the well and goods in, outside).
func _storey(p: Vector3) -> int:
	if p.x < YardRackStore.UPPER_EDGE_X and p.y >= YardRackStore.UPPER_FLOOR_Y - 0.3:
		return 1
	return 0


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# --- Where loads land ----------------------------------------------------------------------

func _to_bay(l: Dictionary) -> void:
	l.where = "bay"


func _to_rack(l: Dictionary) -> void:
	store.put(int(l.slot), l.part, int(l.qty))
	delivered.emit(l.part, int(l.qty))
	for i in loads.size():
		if int(loads[i].id) == int(l.id):
			loads.remove_at(i)
			break
	(l.node as Node).queue_free()


func _to_dispatch(l: Dictionary) -> void:
	l.where = "dispatch"


func _to_berth(l: Dictionary) -> void:
	l.where = "berth"
	sent.emit(l.part, int(l.qty))


func _free_spot(spots_per_bay: Array, bays: Array) -> Dictionary:
	for bi in spots_per_bay.size():
		var spots: Array = spots_per_bay[bi]
		var bay: AABB = bays[bi]
		var cols := 4 if spots.size() == 12 else 3
		var rows := spots.size() / cols
		for i in spots.size():
			if spots[i] == null:
				var cx := bay.position.x + bay.size.x * (float(i % cols) + 0.5) / cols
				var cz := bay.position.z + bay.size.z * (float(i / cols) + 0.5) / rows
				var real_bay := bi if bays.size() > 1 else -1
				return {"bay": real_bay, "i": i, "at": Vector3(cx, 0.0, cz)}
	return {}


func _free_bay_spot(l: Dictionary) -> void:
	_free_spot_of(_bay_spots, l)


func _free_spot_of(spots_per_bay: Array, l: Dictionary) -> void:
	for spots: Array in spots_per_bay:
		for i in spots.size():
			if spots[i] != null and int(spots[i]) == int(l.id):
				spots[i] = null


func _berth_spot() -> Vector3:
	var i := _berth_used
	_berth_used += 1
	return BERTH_STAGING + Vector3(-float(i % 8) * 3.2, 0, -float((i / 8) % 4) * 3.4)


# --- Looks ---------------------------------------------------------------------------------

func _new_load(part: String, qty: int) -> Dictionary:
	var node := Node3D.new()
	node.name = "Load_%s" % part
	var layers: Array = Look.layers(part)
	for t: Transform3D in load_layout(part, qty):
		for l: Dictionary in layers:
			var mi := MeshInstance3D.new()
			mi.mesh = l.mesh
			mi.material_override = l.material
			mi.transform = t
			node.add_child(mi)
	_next_id += 1
	var l := {"id": _next_id, "part": part, "qty": qty, "full": qty, "node": node, "where": "", "claimed": false, "slot": -1}
	loads.append(l)
	return l


## How a load of `qty` parts sits (its own space, bottom middle at the origin): long stock
## side by side, plates in a stack, components in a block, heavy parts in a row.
static func load_layout(part: String, qty: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var look: Dictionary = Look.look(part)
	var ls: Vector3 = look.size
	var rest: Transform3D = look.rest
	match YardRackStore.kind_of(part):
		YardRackStore.LONG:
			var per := mini(qty, 6)
			for k in qty:
				var row := k % per
				var layer := k / per
				out.append(Transform3D(Basis(), Vector3((float(row) - (per - 1) * 0.5) * (ls.x + 0.04), layer * (ls.y + 0.005), 0)) * rest)
		YardRackStore.PLATE:
			for k in qty:
				out.append(Transform3D(Basis(), Vector3(0, k * (ls.y + 0.004), 0)) * rest)
		YardRackStore.COMPONENT:
			var n := ceili(sqrt(float(qty)))
			for k in qty:
				var ix := k % n
				var iz := k / n
				out.append(Transform3D(Basis(), Vector3((float(ix) - (n - 1) * 0.5) * (ls.x + 0.08), 0, (float(iz) - (n - 1) * 0.5) * (ls.z + 0.1))) * rest)
		_:
			for k in qty:
				out.append(Transform3D(Basis(), Vector3(0, 0, (float(k) - (qty - 1) * 0.5) * (ls.z + 0.3))) * rest)
	return out


func _load_height(l: Dictionary) -> float:
	if not l.has("height"):
		var h := 0.0
		for c in (l.node as Node3D).get_children():
			var mi := c as MeshInstance3D
			if mi:
				h = maxf(h, (mi.transform * mi.mesh.get_aabb()).end.y)
		l.height = h
	return float(l.height)


func _home(i: int, yard: bool) -> Vector3:
	if racks:
		return Racks.home(i, yard)
	if yard:
		return Vector3(18.0 + float(i % 6) * 6.0, 4.0, -70.0)
	return Vector3(71.0 + float(i % 2) * 6.0, 9.0, -52.0 + float(i / 2) * 9.0)


func _mat(key: String, c: Color, glow := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.4
		m.roughness = 0.45
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


func _part(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## A stores bot in BSX's livery (orange for the stores, teal for the yard's), the detailed
## hover bot of YardBotLook.
func _make_bot(i: int, yard: bool) -> Node3D:
	var n := BotLook.make(BotLook.BSX_YARD if yard else BotLook.BSX_STORES, ("Y%02d" if yard else "S%02d") % (i + 1))
	n.name = ("YardBot%d" if yard else "StoreBot%d") % i
	return n


func _spin(node: Node3D, delta: float, working: bool) -> void:
	BotLook.animate(node, delta, working)


## A hauler in its freight line's livery (YardHaulerLook): the hold open to the west with a
## ramp that lowers towards goods in, its cab and engines to the east, its name on both sides.
func _make_hauler(i: int, brand: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Hauler%d" % i
	var livery := BotLook.livery(brand)
	var hm := HaulerLook.meshes()
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = hm.hull
	hull.material_override = livery
	n.add_child(hull)
	var bell: Array = Look.layers("MainThruster")
	for dz: float in [-2.2, 2.2]:
		for j in bell.size():
			var e := _part(n, bell[j].mesh, Vector3(14.6, -1.0, dz), bell[j].material, Vector3(0, 0, -PI * 0.5))
			e.name = "Engine" if j == 0 else "EngineGlow"
	var ramp := Node3D.new()
	ramp.name = "Ramp"
	ramp.position = Vector3(-8.0, -3.0, 0)
	n.add_child(ramp)
	var rm := MeshInstance3D.new()
	rm.mesh = hm.ramp
	rm.material_override = livery
	ramp.add_child(rm)
	var light := OmniLight3D.new()
	light.position = Vector3(-2.0, 2.0, 0)
	light.omni_range = 12.0
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.92, 0.8)
	light.set_meta("gfx_no_shadow", true)
	n.add_child(light)
	for side: float in [-1.0, 1.0]:
		var tag := Label3D.new()
		tag.text = String(brand.name)
		tag.font_size = 96
		tag.pixel_size = 0.011
		tag.modulate = brand.accent
		tag.outline_size = 0
		tag.position = Vector3(-1.0, -0.4, side * 4.27)
		tag.rotation.y = 0.0 if side > 0.0 else PI
		n.add_child(tag)
	n.set_meta("brand", brand.id)
	return n
