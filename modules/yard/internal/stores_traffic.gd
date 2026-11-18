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

signal delivered(part: String, qty: int)
signal sent(part: String, qty: int)

## Bots' speed (m/s) and how long a tractor draw takes (s).
@export var bot_speed := 9.0
@export var draw_seconds := 1.2
## Haulers' cruise in and out (m/s), and how far off they come from (m, east of the berths).
@export var hauler_speed := 28.0
@export var hauler_approach := 260.0
@export var store_bots := 10
@export var yard_bots := 4
## Loads one hauler carries at most.
@export var hauler_loads := 6

## Bots cruise over the racks at this height (m), each a little apart.
const CRUISE_Y := 13.0
const YARD_CRUISE_Y := 7.0
## Where yard bots set loads down at the build berth (station space): a grid from here.
const BERTH_STAGING := Vector3(6.0, -1.5, -73.5)
const BOT_HANG := 0.9

var store: YardRackStore
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


func build(rack_store: YardRackStore) -> void:
	store = rack_store
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


## True while anything is on its way: a hauler, a load, a bot at work or a part still asked for.
func busy() -> bool:
	if not backlog.is_empty() or not haulers.is_empty() or not yard_asks.is_empty():
		return true
	for l in loads:
		if l.where != "berth":
			return true
	for b in bots:
		if not (b.job as Array).is_empty():
			return true
	return false


func _process(delta: float) -> void:
	step(delta)


## Moves everything on by `delta` seconds (tests call it directly).
func step(delta: float) -> void:
	_step_haulers(delta)
	for b in bots:
		if (b.job as Array).is_empty():
			_next_job(b)
		_step_bot(b, delta)


# --- Haulers -------------------------------------------------------------------------------

func _call_haulers() -> void:
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
		var node := _make_hauler(i)
		node.position = berth + Vector3(hauler_approach + 30.0 * i, 6.0, 0)
		add_child(node)
		var h := {"node": node, "berth": i, "state": "in", "loads": [], "t": 0.0}
		for k in cargo.size():
			var l := _new_load(cargo[k].part, int(cargo[k].qty))
			l.where = "hauler"
			l.hold = k
			node.add_child(l.node)
			l.node.position = _hold_spot(k)
			(h.loads as Array).append(l)
		haulers.append(h)


func _step_haulers(delta: float) -> void:
	for h in haulers.duplicate():
		var node: Node3D = h.node
		var berth: Vector3 = YardRackStore.HAULER_BERTHS[int(h.berth)]
		match h.state:
			"in":
				var d := node.position.distance_to(berth)
				var speed := clampf(d * 0.6, 3.0, hauler_speed)
				node.position = node.position.move_toward(berth, speed * delta)
				if node.position.distance_to(berth) < 0.02:
					h.state = "open"
			"open":
				var ramp: Node3D = node.get_node("Ramp")
				ramp.rotation.z = move_toward(ramp.rotation.z, 1.45, delta * 0.8)
				var left := (h.loads as Array).filter(func(l: Dictionary) -> bool: return l.where == "hauler")
				if left.is_empty() and ramp.rotation.z >= 1.44:
					h.t += delta
					if h.t > 1.5:
						h.state = "out"
			"out":
				var ramp: Node3D = node.get_node("Ramp")
				ramp.rotation.z = move_toward(ramp.rotation.z, 0.0, delta * 1.2)
				if ramp.rotation.z < 0.01:
					node.position.x += minf(hauler_speed, 4.0 + (node.position.x - berth.x) * 0.5) * delta
				if node.position.x > berth.x + hauler_approach:
					node.queue_free()
					haulers.remove_at(haulers.find_custom(func(x: Dictionary) -> bool: return x.node == node))
					_hauler_free[int(h.berth)] = true
					_call_haulers()


## Where a load stands in a hauler's hold (the hauler's own space): two rows down the hold.
func _hold_spot(k: int) -> Vector3:
	return Vector3(-5.0 + float(k / 2) * 3.4, -2.6, -1.6 if k % 2 == 0 else 1.6)


# --- Jobs ----------------------------------------------------------------------------------

func _next_job(b: Dictionary) -> void:
	if b.yard:
		# A load waiting at the yard side goes out to the build berth.
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
			add_child(l.node)
			l.where = "rack"
			l.claimed = true
			l.node.position = store.slot_position(slot)
			(_dispatch_spots[int(spot.bay)] as Array)[int(spot.i)] = l.id
			b.job = _fetch_steps(l, store.pick_point(slot)) + _carry_steps(l, spot.at, func() -> void: _to_dispatch(l), false)
			return
		# A load in a hauler's hold comes out to goods in.
		for h in haulers:
			if h.state != "open":
				continue
			for l: Dictionary in h.loads:
				if l.where == "hauler" and not l.claimed:
					var spot := _free_spot([_bay_spots[int(h.berth)]], [YardRackStore.GOODS_IN_BAYS[int(h.berth)]])
					if spot.is_empty():
						return
					l.claimed = true
					(_bay_spots[int(h.berth)] as Array)[int(spot.i)] = l.id
					var mouth := (h.node as Node3D).position + Vector3(-11.0, 1.0, (l.node as Node3D).position.z)
					b.job = _fetch_steps(l, mouth) + _carry_steps(l, spot.at, func() -> void: _to_bay(l), false)
					return
	# Nothing to do: home.
	if (b.node as Node3D).position.distance_to(b.home) > 0.1:
		b.job = _fly_steps(b.node.position, b.home, b)


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
	elif s.has("set"):
		var l: Dictionary = s.set
		var ln: Node3D = l.node
		if not s.has("t"):
			s.t = 0.0
			s.from = ln.global_position
			l.where = "setting"
		s.t += delta / draw_seconds
		ln.global_position = (s.from as Vector3).lerp(s.at, _ease(minf(s.t, 1.0)))
		if s.t >= 1.0:
			b.carrying = {}
			l.claimed = false
			(s.done as Callable).call()
			job.pop_front()


## Up to the bot's cruise height, across, and down: over the racks, never through them.
func _route(from: Vector3, to: Vector3, index: int) -> Array:
	var cruise := CRUISE_Y + float(index % 5) * 0.4
	if index >= store_bots:   # yard bots fly under the open face's lintel, never over racks
		cruise = YARD_CRUISE_Y + float(index % 4) * 0.6
	if Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z)) < 0.5:
		return [to]
	return [Vector3(from.x, maxf(cruise, from.y), from.z), Vector3(to.x, maxf(cruise, to.y), to.z), to]


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
	var look: Dictionary = Look.look(part)
	for t: Transform3D in load_layout(part, qty):
		var mi := MeshInstance3D.new()
		mi.mesh = look.mesh
		mi.material_override = Look.material()
		mi.transform = t
		node.add_child(mi)
		if look.glow != null:
			var g := MeshInstance3D.new()
			g.mesh = look.glow
			g.material_override = Look.glow_material(look.glow_colour)
			g.transform = t
			node.add_child(g)
	_next_id += 1
	var l := {"id": _next_id, "part": part, "qty": qty, "node": node, "where": "", "claimed": false, "slot": -1}
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
	if yard:
		return Vector3(20.0 + i % 4 * 7.0, 4.0, -70.0)
	return Vector3(65.0 + float(i % 2) * 2.5, 2.4, -50.0 + float(i / 2) * 9.0)


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


## A stores bot: a white body on four ducted fans, an orange band (teal for the yard's), the
## tractor's emitter underneath and a beacon on top.
func _make_bot(i: int, yard: bool) -> Node3D:
	var n := Node3D.new()
	n.name = ("YardBot%d" if yard else "StoreBot%d") % i
	var white := _mat("bot_white", Color(0.9, 0.91, 0.92))
	var band := _mat("bot_teal" if yard else "bot_orange", Color(0.2, 0.75, 0.7) if yard else Color(1.0, 0.5, 0.12))
	var dark := _mat("bot_dark", Color(0.15, 0.16, 0.18))
	_part(n, _box(Vector3(1.0, 0.32, 1.0)), Vector3.ZERO, white)
	_part(n, _box(Vector3(1.04, 0.08, 1.04)), Vector3(0, -0.08, 0), band)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.26
	ring.outer_radius = 0.34
	var fan := CylinderMesh.new()
	fan.top_radius = 0.26
	fan.bottom_radius = 0.26
	fan.height = 0.02
	for dx: float in [-0.68, 0.68]:
		for dz: float in [-0.68, 0.68]:
			_part(n, ring, Vector3(dx, 0.0, dz), white)
			_part(n, fan, Vector3(dx, -0.02, dz), _mat("bot_fan", Color(0.35, 0.65, 1.0), 1.5)).name = "Fan"
			_part(n, _box(Vector3(absf(dx) - 0.3, 0.06, 0.08)), Vector3(dx * 0.5, 0.0, dz), dark, Vector3(0, 0, 0)).rotation.y = 0.0
	var emitter := SphereMesh.new()
	emitter.radius = 0.16
	emitter.height = 0.2
	_part(n, emitter, Vector3(0, -0.2, 0), _mat("bot_emitter", Color(0.45, 0.85, 1.0), 2.5))
	var beacon := SphereMesh.new()
	beacon.radius = 0.06
	beacon.height = 0.12
	_part(n, beacon, Vector3(0, 0.2, 0), _mat("bot_beacon", Color(1.0, 0.6, 0.1), 4.0)).name = "Beacon"
	return n


func _spin(node: Node3D, _delta: float, working: bool) -> void:
	var beacon := node.get_node_or_null("Beacon") as Node3D
	if beacon:
		beacon.visible = working and int(Time.get_ticks_msec() / 400) % 2 == 0


## A hauler: a long boxy freighter, its cab to the east, engines behind, its hold open to the
## west with a ramp that lowers towards goods in.
func _make_hauler(i: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Hauler%d" % i
	var hull := _mat("hauler_hull", Color(0.78, 0.76, 0.7))
	var stripe := _mat("hauler_stripe", Color(0.85, 0.3, 0.15))
	var dark := _mat("hauler_dark", Color(0.2, 0.21, 0.23))
	var lamp := _mat("hauler_lamp", Color(1.0, 0.92, 0.75), 3.0)
	# The hold: floor, roof and sides, open at the west end (-X), 16 m long.
	_part(n, _box(Vector3(16.0, 0.4, 7.6)), Vector3(0, -3.0, 0), dark)
	_part(n, _box(Vector3(16.0, 0.5, 8.2)), Vector3(0, 3.25, 0), hull)
	for side: float in [-1.0, 1.0]:
		_part(n, _box(Vector3(16.0, 6.6, 0.3)), Vector3(0, 0.0, side * 3.95), hull)
		_part(n, _box(Vector3(16.04, 0.6, 0.32)), Vector3(0, 1.6, side * 3.96), stripe)
		_part(n, _box(Vector3(10.0, 0.1, 0.1)), Vector3(-2.0, 2.9, side * 3.6), lamp)
	# Cab and engines.
	_part(n, _box(Vector3(5.0, 5.0, 6.0)), Vector3(10.5, 0.5, 0), hull)
	_part(n, _box(Vector3(1.0, 1.4, 4.4)), Vector3(13.05, 1.6, 0), _mat("hauler_glass", Color(0.3, 0.55, 0.75), 0.6))
	_part(n, _box(Vector3(0.3, 7.0, 8.6)), Vector3(8.05, 0.2, 0), dark)
	var bell: Dictionary = Look.look("engine_bell")
	for dz: float in [-2.2, 2.2]:
		var e := _part(n, bell.mesh, Vector3(14.6, -1.0, dz), Look.material(), Vector3(0, 0, -PI * 0.5))
		if bell.glow != null:
			var g := _part(n, bell.glow, Vector3(14.6, -1.0, dz), Look.glow_material(bell.glow_colour), Vector3(0, 0, -PI * 0.5))
			g.name = "EngineGlow"
		e.name = "Engine"
	# The ramp, hinged on the hold floor's west edge.
	var ramp := Node3D.new()
	ramp.name = "Ramp"
	ramp.position = Vector3(-8.0, -3.0, 0)
	n.add_child(ramp)
	_part(ramp, _box(Vector3(0.25, 6.0, 7.4)), Vector3(0, 3.0, 0), hull)
	_part(ramp, _box(Vector3(0.27, 0.4, 7.42)), Vector3(0, 5.6, 0), stripe)
	var light := OmniLight3D.new()
	light.position = Vector3(-2.0, 2.0, 0)
	light.omni_range = 12.0
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.92, 0.8)
	n.add_child(light)
	var tag := Label3D.new()
	tag.text = "HAULER %d" % (i + 1)
	tag.font_size = 96
	tag.pixel_size = 0.012
	tag.modulate = Color(0.85, 0.3, 0.15)
	tag.position = Vector3(0, 0.0, -4.12)
	tag.rotation.y = PI
	n.add_child(tag)
	return n
