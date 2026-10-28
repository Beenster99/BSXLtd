extends ModuleTest
## Loose parts land like the real thing (beenster, 26 Oct: "When objects hit the floor that I
## have removed they should clang like in real life. Objects removed from a salvage seem to
## hover slightly above ground. These same objects should stack on top of each other ...
## Objects should stack on these trolleys."):
## - trades.part_landing: a part's collision is the hull of its look, so a tilted plate lies
##   flat on the floor instead of on its slot box's face in the air; landings clang, louder
##   for harder hits.
## - trades.parts_on_decks: beamed onto a trolley, the part stays itself on the deck, stacks
##   on the parts already there, rides with the deck, and goes when Ship and Bay releases it.
## Ship and Bay's trolley calls are played by a stand-in with a deck body of our own.

const FAKE_API := """extends RefCounted
var deck: Node3D
var noted := {}
func beam_to_trolley(slot_id: String, component: String, condition: float, from: Vector3) -> String:
	return "m"
func cancel_beam(slot_id: String) -> void:
	pass
func trolley_deck_position(id: String) -> Variant:
	return deck.global_position if deck else null
func fitted_condition(slot_id: String) -> float:
	return 1.0
func note_loose(slot_id: String, component: String, condition: float, body: Node3D) -> void:
	noted[slot_id] = body
func forget_loose(slot_id: String) -> void:
	noted.erase(slot_id)
var lifted: Array = []
func lift_off_trolley(crate_id: String) -> bool:
	lifted.append(crate_id)
	return true
"""
## A plate whose slot box is a fat AABB round the tilted plate (it used to land 0.5 m up).
const PLATE := "plate_cockpit_wall_e1"
const ENGINES := ["eng_port", "eng_stbd"]


func run_tests() -> void:
	var saved := {}
	for flag: String in ["trades.shipyard", "trades.tractor", "ship_bay.clean_up", "trades.part_landing", "trades.parts_on_decks"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var trades := Modules.bus("trades") as TradesBus
	ship_bus.reset_data()
	var yard := (load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)) as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var rig: TradesBay = yard.get_node_or_null(TradesBus.YARD_RIG)
	check(rig != null and ship_bus.get_slot(PLATE) != null, "the yard is up with the ship's plate")
	if rig == null or ship_bus.get_slot(PLATE) == null:
		yard.queue_free()
		return
	var beam := rig.ship_station().tractor
	var api: Object = _make(FAKE_API, RefCounted.new())
	beam.trolley_api = api

	# Off the ship, the plate falls and lies flat on the floor: no gap under it.
	for f in ship_bus.get_fasteners(PLATE):
		ship_bus.note_joint_removed(f.joint_id)
	await frames(2)
	var plate: TradesLoosePart = beam.loose.get(PLATE)
	check(plate != null and plate.get_child(0) is CollisionShape3D, "the plate is loose")
	if plate == null:
		yard.queue_free()
		return
	var shape := (plate.get_child(0) as CollisionShape3D).shape
	check(shape is ConvexPolygonShape3D, "its collision is the hull of its look, not its slot's box")
	# Dropped from 1.5 m onto open yard floor beside the ship, turned as it came off.
	await _rest(plate, 6.0)
	plate.global_position = Vector3(plate.global_position.x + 9.0, 1.5 + plate.depth_below(), plate.global_position.z)
	plate.drop()
	await _rest(plate, 6.0)
	var gap := _gap_under(plate)
	check(absf(gap) < 0.03, "it lies on the floor, not above it (gap %.3f m)" % gap)
	check(plate.clangs > 0, "it clanged when it hit (%d)" % plate.clangs)

	# Harder hits are louder; a gentle touch is silent.
	var before := plate.clangs
	plate._clang_s = 1.0
	plate.clang(0.3)
	check(plate.clangs == before, "a gentle touch makes no sound")
	plate.clang(1.2)
	var soft := float(plate.last_clang[1])
	plate._clang_s = 1.0
	plate.clang(5.0)
	var loud := float(plate.last_clang[1])
	check(loud > soft + 6.0, "a hard hit is louder (%.0f dB vs %.0f dB)" % [loud, soft])
	plate.clang(5.0)
	check(plate.clangs == before + 2, "contacts chattering as it settles don't clang again at once")
	var p3 := plate.find_children("*", "AudioStreamPlayer3D", false, false)
	check(not p3.is_empty() and (p3[0] as AudioStreamPlayer3D).bus == Sfx.bus(), "the clang plays in 3D on the Effects bus")

	# A trolley deck of our own: an open plate, out in the yard.
	var deck := AnimatableBody3D.new()
	deck.name = "Deck"
	deck.sync_to_physics = false
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 0.12, 3.0)
	col.shape = box
	col.position.y = -0.06
	deck.add_child(col)
	yard.add_child(deck)
	deck.global_position = plate.global_position + Vector3(6, 0.8, 0)
	api.set("deck", deck)

	# Both engines come off; each is beamed onto the deck as its own crate.
	var engines: Array[TradesLoosePart] = []
	var landed := []
	trades.part_on_deck.connect(func(id: String, body: Node3D, on: Node3D) -> void: landed.append([id, body, on]))
	for i in ENGINES.size():
		for f in ship_bus.get_fasteners(ENGINES[i]):
			ship_bus.note_joint_removed(f.joint_id)
		await frames(2)
		var e: TradesLoosePart = beam.loose.get(ENGINES[i])
		engines.append(e)
		beam.to_trolley[ENGINES[i]] = "m"
		beam._on_part_beamed("crate_%d" % i, "m", e.component, ENGINES[i])
		check(not beam.loose.has(ENGINES[i]) and beam.on_deck.get("crate_%d" % i) == e and trades.deck_part("crate_%d" % i) == e,
				"%s stays as itself for its crate, no longer loose" % ENGINES[i])
		await _ride(e, 6.0)
	var a := engines[0]
	var b := engines[1]
	check(a.riding == deck, "the first engine rests on the deck and rides it")
	check(b.riding == deck, "the second rests on it too (through the first)")
	var a_box := a.global_transform * a.outline
	check(b.global_position.y > a.global_position.y + a_box.size.y * 0.5,
			"the second stacks on top of the first (%.2f over %.2f)" % [b.global_position.y, a.global_position.y])
	check(landed.size() == 2 and landed[0][2] == deck, "Ship and Bay hears each landed on the deck (%d)" % landed.size())

	# The trolley drives off: the stack goes with it.
	var a_from := a.global_position
	var b_from := b.global_position
	deck.global_position += Vector3(2.5, 0, -1.0)
	await frames(3)
	check(a.global_position.distance_to(a_from + Vector3(2.5, 0, -1.0)) < 0.01 and
			b.global_position.distance_to(b_from + Vector3(2.5, 0, -1.0)) < 0.01, "the stack rides with the deck")
	check(beam.aimed_part() != a and not beam.loose.values().has(a), "the beam can't take them off the deck")

	# Part info (trades.part_info, beenster 0.3.19: "When I look at a part (anywhere in the
	# game) I must be able to see its information on the right hand panel"): no key to hold.
	var had_info := Flags.is_on("trades.part_info")
	Flags.set_flag("trades.part_info", true)
	rig.set_tool(&"tractor")
	_look_at(rig, plate.centre())
	var card := rig.look_hint()
	check(str(card.get("text", "")).contains("CONDITION") and str(card.get("text", "")).contains(plate.component),
			"looking at the loose plate, the card gives its details: %s" % str(card.get("text", "")).replace("\n", " | "))
	_look_at(rig, b.centre())
	card = rig.look_hint()
	check(str(card.get("text", "")).contains("on a trolley"), "and a part on a trolley says so: %s" % str(card.get("text", "")).replace("\n", " | "))
	# Anything in the game carrying meta "component": a crate on a shelf, say.
	var comp := ""
	var shared: Node = Modules.bus("shared_components")
	if shared and shared.has_method("part_names") and not (shared.call("part_names") as PackedStringArray).is_empty():
		comp = (shared.call("part_names") as PackedStringArray)[0]
	var crate := StaticBody3D.new()
	crate.set_meta("component", comp)
	crate.set_meta("condition", 0.4)
	var crate_col := CollisionShape3D.new()
	crate.add_child(crate_col)
	yard.add_child(crate)
	rig.worker.face(rig.worker.global_position + Vector3(0.3, 20.0, 0.3))  # at the sky: no ship part under the aim
	await frames(1)
	card = rig.look_hint({"collider": crate_col})
	var spec: Object = shared.call("build_spec", comp) if shared else null
	var name := str(spec.get("display_name")) if spec and str(spec.get("display_name")) != "" else comp
	check(comp != "" and str(card.get("title", "")) == name.to_upper().capitalize() and str(card.get("text", "")).contains("40%"),
			"a crate with a component shows that part's details: %s / %s" % [str(card.get("title", "")), str(card.get("text", "")).replace("\n", " | ")])
	check(rig.look_hint({"collider": null}).is_empty(), "looking at nothing shows no card")
	crate.queue_free()
	Flags.set_flag("trades.part_info", had_info)

	# The beam takes the top one off the trolley (beenster, 0.3.19: "I need to be able to
	# tractor a part from a trolley (any trolley)"): Ship and Bay lifts its crate off.
	_look_at(rig, b.centre())
	check(beam.can_lift_decks() and str(beam.actions()[0][1]).contains("trolley"), "aimed at a part on a trolley, the beam offers to lift it off")
	rig.ship_station().press(&"tractor")
	check(beam.held == b and (api.get("lifted") as Array) == ["crate_1"], "it takes it and Ship and Bay lifts its crate off the trolley")
	check(not beam.on_deck.has("crate_1") and beam.loose.get(ENGINES[1]) == b and b.riding == null and trades.deck_part("crate_1") == null,
			"it's a loose part in your beam again, no longer on the deck")
	beam._on_deck_part_left("crate_1", "m")
	await frames(1)
	check(is_instance_valid(b), "Ship and Bay saying its crate left doesn't take it from your beam")
	rig.ship_station().release()

	# The crates leave the trolley (Ship and Bay's deck_part_left, or a release): the parts go.
	beam._on_deck_part_left("crate_0", "m")
	await frames(2)
	check(not is_instance_valid(a) and beam.on_deck.is_empty(), "a crate leaving the trolley takes its part")
	check(trades.deck_part("crate_0") == null, "and nothing is listed on the deck")
	# Beamed back onto the trolley as a new crate, then released.
	beam.to_trolley[ENGINES[1]] = "m"
	beam._on_part_beamed("crate_2", "m", b.component, ENGINES[1])
	check(beam.on_deck.get("crate_2") == b and not beam.loose.has(ENGINES[1]), "it can go back on a trolley as a new crate")
	trades.release_deck_part("crate_2")
	await frames(1)
	check(not is_instance_valid(b) and beam.on_deck.is_empty(), "release_deck_part frees a part on a deck too")

	await _goods_off(rig, beam, api, deck)
	await _goods_in(rig, beam, api, deck)

	yard.queue_free()
	await frames(1)
	ship_bus.reset_data()
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


## Stock Ship and Bay draws on a trolley (trades.goods_off): the beam takes it off as a loose
## part, looking as it was drawn, and Ship and Bay lifts its crate off; a stack waits until
## Ship and Bay can take one off it.
func _goods_off(rig: TradesBay, beam: TradesTractor, api: Object, deck: Node3D) -> void:
	var had := Flags.is_on("trades.goods_off")
	Flags.set_flag("trades.goods_off", true)
	var comp := str((Modules.bus("ship_bay") as ShipBayBus).storage_items().keys()[0])
	var cargo := Node3D.new()
	cargo.name = "Cargo"
	cargo.position = Vector3(0, 0.06, 0)
	deck.add_child(cargo)
	var size := Vector3(0.6, 0.4, 0.5)
	var one := _item(cargo, comp, size, Vector3(-0.6, 0, 0))
	_look_box(cargo, AABB(one.position - Vector3(size.x * 0.5, 0, size.z * 0.5), size),
			{"component": comp, "condition": 0.7, "crate_id": "goods_1"})
	var low := _item(cargo, comp, size, Vector3(0.6, 0, 0))
	_item(cargo, comp, size, Vector3(0.6, size.y, 0))
	_look_box(cargo, AABB(low.position - Vector3(size.x * 0.5, 0, size.z * 0.5), size * Vector3(1, 2, 1)),
			{"component": comp, "condition": 1.0, "crate_id": "goods_2"})
	await frames(2)

	_look_at(rig, one.global_position + Vector3.UP * 0.2)
	await frames(1)
	# A trolley's own areas round its deck (its reach, the HERE marker) don't hide the goods.
	if Flags.is_on("trades.goods_aim_through"):
		var reach := Area3D.new()
		reach.monitoring = false
		var rs := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		rb.size = Vector3(4, 3, 4)
		rs.shape = rb
		reach.add_child(rs)
		deck.add_child(reach)
		await frames(2)
		check(beam.aimed_goods() != null, "goods inside a trolley's bigger area are still aimed at")
		reach.queue_free()
		await frames(2)
	check(beam.aimed_goods() != null and str(beam.actions()[0][1]).contains("trolley") and beam.aim_title().contains("on a trolley"),
			"aimed at goods on a trolley, the beam offers to lift them off (%s)" % beam.aim_title())
	rig.ship_station().press(&"tractor")
	var got := beam.held
	check(got != null and TradesTractor.is_goods(got) and got.component == comp and (api.get("lifted") as Array).has("goods_1"),
			"it takes them, and Ship and Bay lifts their crate off the trolley")
	if got == null:
		Flags.set_flag("trades.goods_off", had)
		return
	check(got.global_position.distance_to(one.global_position) < 0.05 and not got.find_children("*", "MeshInstance3D", true, false).is_empty(),
			"they come off where they sat, looking as they were drawn")
	check(is_equal_approx(got.condition, 0.7) and str(got.get_meta("component")) == comp, "in the condition they were in, with their details")
	rig.ship_station().press(&"tractor")
	check((api.get("lifted") as Array).count("goods_1") == 1, "the same crate isn't lifted twice")
	rig.ship_station().release()
	check((api.get("noted") as Dictionary).get(got.slot_id) == got, "let go, they lie loose for the clean-up to put away")
	beam.clear()
	check(is_instance_valid(got) and beam.loose.get(got.slot_id) == got, "the ship leaving doesn't take stock with it")

	# A stack of two: Ship and Bay can't take one off it yet.
	beam.held = null
	_look_at(rig, low.global_position + Vector3.UP * 0.6)
	await frames(1)
	rig.ship_station().press(&"tractor")
	check(beam.held == null and not (api.get("lifted") as Array).has("goods_2"), "a stack waits until one can come off it")
	check(beam._validate_lift(2, {"kind": "goods", "crate_id": "nope"}) is String, "the host turns down goods it can't find")
	# Ship and Bay takes one item off a stack (lift_off_trolley(crate_id, qty)): one at a time.
	var two: Object = _make(FAKE_API.replace("func lift_off_trolley(crate_id: String) -> bool:\n\tlifted.append(crate_id)",
			"func lift_off_trolley(crate_id: String, qty := 0) -> bool:\n\tlifted.append([crate_id, qty])"), RefCounted.new())
	two.set("deck", deck)
	beam.trolley_api = two
	rig.ship_station().press(&"tractor")
	var first := beam.held
	check(first != null and (two.get("lifted") as Array) == [["goods_2", 1]], "one comes off the stack (%s)" % [two.get("lifted")])
	rig.ship_station().release()
	if first:
		first.global_position += Vector3(0, 0, -6)
	await frames(2)
	rig.ship_station().press(&"tractor")
	var second := beam.held
	check(second != null and second != first and first.slot_id != second.slot_id and (two.get("lifted") as Array).size() == 2,
			"and another, each its own part (%s, %s)" % [first.slot_id if first else "", second.slot_id if second else ""])
	if second:
		rig.ship_station().release()
	beam.trolley_api = api
	cargo.queue_free()
	Flags.set_flag("trades.goods_off", had)


## A delivered crate on the goods-in floor (trades.goods_in): a look box under the shipyard's
## "Stores" with a crate_id comes off as one loose part and Ship and Bay collects the crate;
## a stocked rack place (meta "location", no crate_id) stays put.
func _goods_in(rig: TradesBay, beam: TradesTractor, api: Object, deck: Node3D) -> void:
	var saved := {"trades.goods_off": Flags.is_on("trades.goods_off"), "trades.goods_in": Flags.is_on("trades.goods_in")}
	Flags.set_flag("trades.goods_off", true)
	Flags.set_flag("trades.goods_in", true)
	var comp := str((Modules.bus("ship_bay") as ShipBayBus).storage_items().keys()[0])
	var stand_in: Object = _make(FAKE_API + "var collected: Array = []\nfunc collect_crate(crate_id: String) -> void:\n\tcollected.append(crate_id)\n", RefCounted.new())
	stand_in.set("deck", deck)
	beam.trolley_api = stand_in
	var yard_side := Node3D.new()
	rig.get_parent().add_child(yard_side)
	var stores := Node3D.new()
	stores.name = "Stores"
	yard_side.add_child(stores)
	# Clear of the deck and the goods already lifted off it.
	stores.global_position = rig.worker.global_position + rig.worker.global_basis * Vector3(1.2, 0.3, -2.5)
	var size := Vector3(0.6, 0.4, 0.5)
	_look_box(stores, AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), size), {"component": comp, "condition": 0.8, "crate_id": "in_1"})
	await frames(2)
	_look_at(rig, stores.global_position + Vector3.UP * 0.2)
	await frames(1)
	check(beam.aimed_goods() != null and beam.aim_title().contains("goods in") and str(beam.actions()[0][1]).contains("floor"),
			"aimed at a delivered crate in goods in, the beam offers to lift it off the floor (%s)" % beam.aim_title())
	rig.ship_station().press(&"tractor")
	var got := beam.held
	check(got != null and TradesTractor.is_goods(got) and got.component == comp and (stand_in.get("collected") as Array) == ["in_1"],
			"it takes it, and Ship and Bay collects the crate (%s)" % [stand_in.get("collected")])
	check(got != null and got.global_position.distance_to(stores.global_position) < 0.05 and is_equal_approx(got.condition, 0.8),
			"it comes off where it sat, in its condition")
	if got:
		rig.ship_station().release()
	# A rack place's look box carries "location", not a crate: the beam leaves it.
	var rack := Node3D.new()
	stores.add_child(rack)
	_look_box(rack, AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), size), {"component": comp, "condition": 1.0, "location": "R1-A"})
	for a: Node in stores.find_children("*", "Area3D", true, false):
		if a.has_meta("crate_id"):
			a.queue_free()
	if got:
		got.global_position += Vector3(0, 0, -6)
	await frames(2)
	_look_at(rig, stores.global_position + Vector3.UP * 0.2)
	await frames(1)
	check(beam.aimed_goods() == null, "a stocked rack place isn't taken by the beam")
	yard_side.queue_free()
	beam.trolley_api = api
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _item(parent: Node3D, comp: String, size: Vector3, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Item_" + comp
	root.set_meta("item", comp)
	root.set_meta("size", size)
	root.position = at
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position.y = size.y * 0.5
	root.add_child(mi)
	parent.add_child(root)
	return root


func _look_box(parent: Node3D, box: AABB, metas: Dictionary) -> void:
	var area := Area3D.new()
	area.name = "Look"
	area.monitoring = false
	area.set_meta("look_only", true)
	for k: String in metas:
		area.set_meta(k, metas[k])
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = box.size
	shape.shape = b
	shape.position = box.get_center()
	area.add_child(shape)
	parent.add_child(area)


func _look_at(rig: TradesBay, at: Vector3) -> void:
	var stand := at + Vector3(0, 0, 2.2)
	stand.y = at.y - 1.6 if at.y > 1.6 else 0.0
	rig.worker.global_position = stand
	rig.worker.face(at)


## Waits until the part is still (or `limit` seconds).
func _rest(part: TradesLoosePart, limit: float) -> void:
	var t := 0.0
	var still := 0.0
	while t < limit and still < 0.4:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		still = still + get_physics_process_delta_time() if part.linear_velocity.length() < 0.03 else 0.0


func _ride(part: TradesLoosePart, limit: float) -> void:
	var t := 0.0
	while t < limit and part.riding == null:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


## The gap between the part's lowest point and the ground under its middle (m; a hair
## under 0 is resting contact).
func _gap_under(part: TradesLoosePart) -> float:
	var space := part.get_world_3d().direct_space_state
	var bottom := part.global_position.y - part.depth_below()
	var at := part.centre()
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, Vector3(at.x, bottom - 2.0, at.z))
	q.exclude = [part.get_rid()]
	var hit := space.intersect_ray(q)
	return bottom - float((hit.position as Vector3).y) if not hit.is_empty() else 9.0


func _make(source: String, obj: Object) -> Object:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	obj.set_script(script)
	return obj
