extends ModuleTest
## The racks hold the company's stock (beenster, 20 Nov: "make the warehouse actually reflect
## the company stockholding"): a stock laid out on the racks is the same on every machine and
## all of it; the books gaining parts orders them in, losing parts sends them out; the yard
## using parts (a kit) or taking parts in takes them out of or puts them into the books; a new
## company gets its opening stock once, and a fresh yard starts its racks from the books.
##   tools/run_tests.sh stores

const CompanyStock := preload("res://modules/stores/internal/company_stock.gd")


## Stand-in books: get_stock, add_stock, use_stock as BusinessBus has them.
class Books:
	extends RefCounted
	var stock := {}
	var added := 0
	var used := 0

	func get_stock() -> Dictionary:
		return stock.duplicate()

	func add_stock(part: String, qty: int, _condition := "new", _source := "") -> int:
		stock[part] = int(stock.get(part, 0)) + qty
		added += qty
		return int(stock[part])

	func use_stock(part: String, qty := 1, _condition := "") -> bool:
		if int(stock.get(part, 0)) < qty:
			return false
		stock[part] = int(stock[part]) - qty
		used += qty
		return true


## Stand-in yard: notes what is ordered in and sent out.
class Yard:
	extends RefCounted
	var orders: Array = []
	var sends: Array = []

	func order_parts(items: Array) -> void:
		orders.append_array(items)

	func send_to_yard(items: Array) -> void:
		sends.append_array(items)

	func station() -> Node3D:
		return null


func run_tests() -> void:
	_layout()
	_mirror()
	await _with_business()


## set_stock: all of it, the same slots whatever order the stock comes in.
func _layout() -> void:
	var opening := CompanyStock.opening_stock()
	check(not opening.is_empty(), "a new company has an opening stock: %d lines" % opening.size())
	var a := YardRackStore.new()
	a.set_stock(opening)
	check(a.counts() == opening, "the racks hold the stock, all of it")
	var keys := opening.keys()
	keys.reverse()
	var backwards := {}
	for k: String in keys:
		backwards[k] = opening[k]
	var b := YardRackStore.new()
	b.set_stock(backwards)
	var same := true
	for i in a.slots.size():
		if a.slots[i].part != b.slots[i].part or int(a.slots[i].qty) != int(b.slots[i].qty):
			same = false
	check(same, "the same stock gives the same places on every machine")
	var heavy := 0
	for s in a.slots:
		if s.part != "" and YardRackStore.kind_of(str(s.part)) == YardRackStore.HEAVY:
			heavy += 1
	check(heavy == a.filled_count(YardRackStore.HEAVY), "each part lies on a rack of its kind")
	var few := YardRackStore.new()
	few.set_stock({"Reactor": 2, "NotAPart": 5})
	check(few.counts() == {"Reactor": 2}, "parts the racks don't keep are left out")
	var places: Array[int] = []
	for i in few.slots.size():
		if few.slots[i].part != "":
			places.append(i)
	check(places.size() == 2 and few.slot_position(places[0]).distance_to(few.slot_position(places[1])) > 10.0,
			"a little stock is spread over the racks, not bunched at one end")
	var fired := [0]
	few.changed.connect(func(i: int) -> void: fired[0] = i - 100)
	few.set_stock({})
	check(fired[0] == -101 and few.counts().is_empty(), "laying out afresh says so once (slot -1)")


## The mirror against stand-in books and yard.
func _mirror() -> void:
	var books := Books.new()
	var yard := Yard.new()
	books.stock = {"Reactor": 1, "FuelTank": 2, "SteelBar": 40}
	var store := YardRackStore.new()
	var m := CompanyStock.new()
	m.business = books
	m.yard = yard
	check(m.books() == {"Reactor": 1, "FuelTank": 2}, "the books' rack parts (not their other stock)")
	m.start(m.books())
	store.set_stock(m.books())
	m.bind(store)
	m.sync()
	check(yard.orders.is_empty() and yard.sends.is_empty(), "racks and books agree: nothing to do")
	# Bought: two more fuel tanks in the books. The yard orders them; they arrive.
	books.stock.FuelTank = 4
	m.sync()
	check(yard.orders == [{"part": "FuelTank", "qty": 2}], "the books gained two: the yard orders them in")
	m.sync()
	check(yard.orders.size() == 1, "and only once")
	for k in 2:
		var slot := store.reserve("FuelTank", 1)
		store.put(slot, "FuelTank", 1)
	check(books.added == 0 and store.count("FuelTank") == 4, "they reach the racks without counting twice")
	# Sold: the reactor leaves the books. A bot takes it out.
	books.stock.Reactor = 0
	m.sync()
	check(yard.sends == [{"part": "Reactor", "qty": 1}], "the books lost one: it goes out to the yard side")
	store.take(store.find("Reactor"), 1)
	check(books.used == 0 and store.count("Reactor") == 0, "it comes off the racks without counting twice")
	# Used in the yard: a kit takes a fuel tank. The books follow.
	store.take(store.find("FuelTank"), 1)
	check(books.used == 1 and int(books.stock.FuelTank) == 3, "a kit took one: the books use it")
	m.sync()
	check(yard.orders.size() == 1 and yard.sends.size() == 1, "and nothing is ordered to replace it")
	# Taken in by the yard (a demo contract's delivery): the books gain it.
	store.store("Gyroscope", 1)
	check(int(books.stock.get("Gyroscope", 0)) == 1, "parts the yard took in go into the books")
	# Sold before it reached the racks: only what is on them goes out, the rest later.
	books.stock.Seat = 2
	m.sync()
	books.stock.Seat = 0
	m.sync()
	check(not yard.sends.any(func(s: Dictionary) -> bool: return s.part == "Seat"), "nothing is sent out before it arrives")
	var slot := store.reserve("Seat", 2)
	store.put(slot, "Seat", 2)
	m.sync()
	check(yard.sends.any(func(s: Dictionary) -> bool: return s.part == "Seat" and int(s.qty) == 2), "once in, it goes out")
	# A replayed log (the host opening a yard the crew had open) is old news.
	m.quiet_until_tick = 100
	store.changed.disconnect(m.on_changed)
	var before := books.used
	var at := store.find("FuelTank")
	store.take(at, 1)
	m.on_changed(at, 50)
	check(books.used == before, "a change replayed from the log is not reported again")
	at = store.find("FuelTank")
	store.take(at, 1)
	m.on_changed(at, 150)
	check(books.used == before + 1, "a change after the replay is reported")


## With the real business books: the opening stock goes in once and a fresh yard starts from it.
func _with_business() -> void:
	var bus := Modules.bus("stores") as StoresBus
	var business := Modules.bus("business")
	if bus == null or business == null or bus.company == null:
		check(true, "no business module here: books checks skipped")
		return
	business.call("reset")
	bus.reset_data()
	check(bus.is_preview() and bus.store().counts() == CompanyStock.opening_stock(), "before a yard opens it previews the opening stock")
	var start := bus._starting_stock()
	check(start == CompanyStock.opening_stock() and bus.opening_given, "a new company's books get the opening stock")
	var held: Dictionary = business.call("get_stock")
	check(int(held.get("Reactor", 0)) == int(start.get("Reactor", 0)), "the books hold it: %d reactors" % int(held.get("Reactor", 0)))
	var again := bus._starting_stock()
	check(again == start, "only once")
	check(bus.save_data().opening_given == true, "saved")
	bus.load_data({}, 1)
	check(not bus.opening_given, "a game from before has not had it")
	var yard := Modules.bus("yard") as YardBus
	if yard:
		bus.load_data({"opening_given": true}, 1)
		check(yard.starting_stock().get("parts", {}) == bus.company.books(), "a fresh yard clock starts the racks from the books")
	await frames(1)
