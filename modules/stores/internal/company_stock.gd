extends RefCounted
## The stores hall's racks kept to the company's stock (beenster, 20 Nov: "make the warehouse
## actually reflect the company stockholding"). The business books (BusinessBus.get_stock) are
## the company's stock; the racks (YardRackStore) are where it lies. The host keeps the two
## together, both ways:
##   - the books gain parts (bought, delivered): the yard orders them, haulers bring them in to
##     goods in and the bots put them away (YardBus.order_parts, on the shared clock);
##   - the books lose parts (sold, fitted elsewhere): bots take them off the racks and out to
##     the yard side (YardBus.send_to_yard);
##   - the yard itself takes parts off the racks (a kit for a player or a worker bot) or puts
##     parts on them that the books didn't send for: the books follow (use_stock, add_stock).
## Every player's racks change through the yard's shared clock (its log), so they agree; only
## the host's books change. A fresh clock starts the racks from the books themselves
## (YardBus.stock_source -> starting stock), laid out by YardRackStore.set_stock.
##
## Pure logic over duck-typed `business` and `yard` objects, so tests can drive it with stubs.

## What the yard holds or has on its way in, by our reckoning: {part: qty}.
var sent := {}
## Loads we asked for that have not reached the racks yet, and loads we asked to go out that
## have not left them: {part: qty}.
var expect_in := {}
var expect_out := {}
## Rack changes before this sim tick are a replay of the log (the host opening a yard the crew
## already had open): they are what the books already know, so they are not reported.
var quiet_until_tick := -1

var business: Object
var yard: Object
var store: YardRackStore
var _cache: Array = []


## The stock a new company starts with: the demo stock the racks used to be filled with
## (YardRackStore.fill_demo's), as {part: qty}.
static func opening_stock() -> Dictionary:
	var s := YardRackStore.new()
	s.fill_demo()
	return s.counts()


## The books' stock of the parts the racks keep: {part: qty}.
func books() -> Dictionary:
	var out := {}
	if business == null or not business.has_method("get_stock"):
		return out
	var all: Dictionary = business.call("get_stock")
	for part: Variant in all:
		var id := str(part)
		if YardRackStore.PARTS.has(id) and int(all[part]) > 0:
			out[id] = int(all[part])
	return out


## The racks start from `parts` (a fresh clock): nothing in flight.
func start(parts: Dictionary) -> void:
	sent = parts.duplicate()
	expect_in.clear()
	expect_out.clear()


## Watches `s` (the open yard's racks).
func bind(s: YardRackStore, quiet_until := -1) -> void:
	if store == s:
		quiet_until_tick = maxi(quiet_until_tick, quiet_until)
		return
	unbind()
	store = s
	quiet_until_tick = quiet_until
	if store:
		store.changed.connect(on_changed)
		_recache()


func unbind() -> void:
	if store and store.changed.is_connected(on_changed):
		store.changed.disconnect(on_changed)
	store = null
	_cache.clear()


## A place on the racks changed (-1: all of them, laid out afresh). `tick` is the yard's sim
## tick it changed at (-1 unknown).
func on_changed(i: int, tick := -1) -> void:
	if store == null:
		return
	if i < 0 or i >= _cache.size():
		_recache()
		return
	var was: Array = _cache[i]
	var now: Dictionary = store.slots[i]
	_cache[i] = [str(now.part), int(now.qty)]
	if tick < 0 and yard and yard.has_method("station"):
		tick = _sim_tick()
	if tick >= 0 and tick < quiet_until_tick:
		return
	var deltas := {}
	if str(was[0]) != "":
		deltas[str(was[0])] = -int(was[1])
	if str(now.part) != "":
		deltas[str(now.part)] = int(deltas.get(str(now.part), 0)) + int(now.qty)
	for part: String in deltas:
		var d: int = deltas[part]
		if d > 0:
			_arrived(part, d)
		elif d < 0:
			_left(part, -d)


## Brings the yard's orders in line with the books: what they gained is ordered in, what they
## lost is sent out (only what is on the racks now; the rest on a later call).
func sync() -> void:
	if store == null or yard == null:
		return
	var want := books()
	var parts := {}
	for p: String in want:
		parts[p] = true
	for p: String in sent:
		parts[p] = true
	var ids := parts.keys()
	ids.sort()
	var order: Array = []
	var out: Array = []
	for part: String in ids:
		var d := int(want.get(part, 0)) - int(sent.get(part, 0))
		if d > 0:
			order.append({"part": part, "qty": d})
			sent[part] = int(sent.get(part, 0)) + d
			expect_in[part] = int(expect_in.get(part, 0)) + d
		elif d < 0:
			var n := mini(-d, store.count(part) - int(expect_out.get(part, 0)))
			if n > 0:
				out.append({"part": part, "qty": n})
				sent[part] = int(sent.get(part, 0)) - n
				expect_out[part] = int(expect_out.get(part, 0)) + n
	if not order.is_empty():
		yard.call("order_parts", order)
	if not out.is_empty():
		yard.call("send_to_yard", out)


## Parts went onto the racks: ours, or ones the books didn't send for (the yard bought them).
func _arrived(part: String, n: int) -> void:
	var ours := mini(n, int(expect_in.get(part, 0)))
	_less(expect_in, part, ours)
	var rest := n - ours
	if rest <= 0:
		return
	sent[part] = int(sent.get(part, 0)) + rest
	if business and business.has_method("add_stock"):
		business.call("add_stock", part, rest, "new", "yard")


## Parts came off the racks: ours going out, or the yard using them (a kit).
func _left(part: String, n: int) -> void:
	var ours := mini(n, int(expect_out.get(part, 0)))
	_less(expect_out, part, ours)
	var rest := n - ours
	if rest <= 0:
		return
	sent[part] = maxi(0, int(sent.get(part, 0)) - rest)
	if business and business.has_method("use_stock"):
		business.call("use_stock", part, rest)


static func _less(d: Dictionary, part: String, n: int) -> void:
	var left := int(d.get(part, 0)) - n
	if left > 0:
		d[part] = left
	else:
		d.erase(part)


func _recache() -> void:
	_cache.clear()
	if store == null:
		return
	for s in store.slots:
		_cache.append([str(s.part), int(s.qty)])


func _sim_tick() -> int:
	var station: Variant = yard.call("station")
	if not station is Node:
		return -1
	var sim: Variant = (station as Node).get("sim")
	return int((sim as Node).get("tick")) if sim is Node else -1
