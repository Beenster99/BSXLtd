extends Node
## Runs the ACCOUNTS screenshots (see accounts_capture.gd) from a node of the root.

const SIZE := Vector2i(1110, 780)
const WRIST := Vector2i(860, 420)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://accounts_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	if not Modules.ready_done:
		await Modules.modules_ready
	var bus := Modules.bus("business") as BusinessBus
	sample_books(bus)
	DisplayServer.window_set_size(SIZE)
	get_tree().root.size = SIZE
	var screen := bus.make_accounts_wall(150.0)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	await _frames(20)
	await _save(out, "accounts_week")
	screen.call("set_period", "30 D")
	await _frames(10)
	var scroll := screen.get_child(0) as ScrollContainer
	await _save(out, "accounts_month")
	scroll.scroll_vertical = 2000
	await _frames(10)
	await _save(out, "accounts_detail")
	screen.queue_free()
	DisplayServer.window_set_size(WRIST)
	get_tree().root.size = WRIST
	var wrist := (HudSlots.holo_channel(BusinessBus.WRIST_ACCOUNTS).factory as Callable).call(true) as Control
	wrist.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wrist)
	await _frames(20)
	await _save(out, "accounts_wrist")
	wrist.queue_free()
	var design := Modules.bus("design")
	if "--room" in OS.get_cmdline_user_args() and design and design.has_method("register_wall_view"):
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		get_tree().root.size = Vector2i(1920, 1080)
		design.call("open_sample")
		Router.goto("design.room")
		await _frames(30)
		var room: Node = get_tree().current_scene
		room.call("set_room_view", true)
		var wall: Node = (room.get("walls") as Dictionary)["wall_left"]
		var board: Node = wall.get("content")
		# Step the left wall's first panel round to ACCOUNTS.
		for i in 16:
			if str(board.get("panels")[0].view) == BusinessBus.ACCOUNTS_WALL_VIEW:
				break
			board.call("step", 0, 1)
		var cam := room.get("camera") as Camera3D
		cam.position = Vector3(4.0, 2.6, 3.0)
		cam.rotation = Vector3(-0.05, 1.25, 0)
		await _frames(40)
		await _save(out, "room")
		var img: Image = wall.get("viewport").get_texture().get_image()
		img.save_png(out.path_join("wall_left.png"))
	get_tree().quit()


## A fortnight of sample business: three contracts (one handed over, one staged), parts
## bought and delivered, a loan, a crew of three paid each day, stock sold on.
static func sample_books(bus: BusinessBus) -> void:
	bus.reset()
	bus.test_crew = {1: "Ann", 2: "Bob", 3: "Cass"}
	bus.test_levels = {"Ann": 9, "Bob": 4, "Cass": 1}
	var books: RefCounted = bus.get("_books")
	books.set("instant_deliveries", true)
	var listings := bus.get_listings().filter(func(l: MarketListing) -> bool: return l.unit_price > 200 and l.unit_price < 6000)
	var buy := func(n: int, contract: String) -> void:
		var basket: Array = []
		for i in n:
			var l: MarketListing = listings[(i * 37 + bus.get_day() * 11) % listings.size()]
			basket.append({"listing_id": l.id, "qty": 1 + i % 3})
		bus.place_market_order(basket, contract)
	books.call("accept_contract", "SO-1042 Kestrel refit", 48000, 5, 14000)
	buy.call(5, "SO-1042 Kestrel refit")
	books.call("advance_day")
	books.get("company").take_loan(25000, 24, bus.get_day())
	books.call("advance_day")
	books.call("accept_contract", "SO-1047 Manta cargo hall", 126000, 14, 38000)
	books.call("plan_stages", "SO-1047 Manta cargo hall", [{"id": "frame", "name": "Frame", "value": 42000},
			{"id": "skin", "name": "Skin", "value": 46000}, {"id": "fit", "name": "Fit out", "value": 38000}])
	buy.call(8, "SO-1047 Manta cargo hall")
	for d in 3:
		books.call("advance_day")
	books.call("hand_over", "SO-1042 Kestrel refit", 0.82, 0)
	books.call("sign_off_stage", "SO-1047 Manta cargo hall", "frame")
	books.call("advance_day")
	buy.call(4, "")
	bus.add_stock(listings[3].part, 4, "used", "recovered")
	bus.add_stock(listings[9].part, 2, "refurbished", "recovered")
	books.call("advance_day")
	var offers := bus.get_offers(listings[3].part, "used")
	if not offers.is_empty():
		bus.sell_stock(str(offers[0].supplier_id), listings[3].part, "used", 2)
	books.call("accept_contract", "SO-1051 Gannet thrusters", 31000, 16, 9000)
	buy.call(3, "SO-1051 Gannet thrusters")
	for d in 4:
		books.call("advance_day")
	books.call("sign_off_stage", "SO-1047 Manta cargo hall", "skin")
	books.get("company").award_bonus("Ann", 600, "Kestrel handover", "Ann", bus.get_day())
	books.call("advance_day")
	books.call("advance_minutes", 14 * 60 + 20)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(out: String, shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot + ".png"))
	print("AccountsCapture: ", out.path_join(shot + ".png"))
