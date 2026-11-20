extends ModuleTest
## Refurbishing bots (beenster, 19 Nov; 0.4.4 playtest): second-hand parts come in at Reclaimed
## grade at goods in, the works' cart brings them into the annex, a BSX RF-2 takes a small
## one through inspect, strip, clean, rebuild and test on its cradle, and a big one goes under the
## crane onto the heavy stand where a team works it. A part that passes leaves certified at
## Standard, the same size, for a cost; a cracked one is scrapped (a big one cut up first). Idle
## bots go home to the charger rack. The works runs on the yard's shared clock: the same log
## replayed to the same tick is the same works.
##   tools/run_tests.sh refurb

const TYPE := "reactor_small:3R"


func run_tests() -> void:
	var cat := DesignCatalog.load_default()
	var works := RefurbWorks.new(null, cat)
	check(works.bots.size() == works.tuning.cradles + works.tuning.heavy_crew and works.cradles.size() == works.tuning.cradles + 1,
			"one refurbisher per light cradle, a heavy crew for the heavy stand")
	var slots := {}
	for b in works.bots:
		slots[works.dock_point(int(b.id))] = true
		check((b.pos as Vector3).distance_to(works.dock_point(int(b.id))) < 0.01, "%s starts on its charger" % b.serial)
	check(slots.size() == works.bots.size(), "each bot has its own charger slot")
	var paces := {}
	for b in works.bots:
		paces[snappedf(float(b.pace), 0.001)] = true
	check(paces.size() == works.bots.size(), "each bot works at its own pace")

	# What it would take, for the market.
	var good := works.estimate(TYPE, 0.8)
	var bad := works.estimate(TYPE, 0.3)
	var certified_as := cat.part(String(good.get("result", "")))
	check(certified_as != null and certified_as.grade == "S" and certified_as.size_class == 3, "a 3R reactor is certified as a 3S (Standard): %s" % good.get("result", ""))
	check(float(bad.seconds) > float(good.seconds) and float(bad.cost) > float(good.cost), "a worn part takes longer and costs more")
	check(float(bad.scrap) > float(good.scrap), "a worn part is likelier to be scrapped")
	check(float(good.cost) < float(good.new_price) * 0.5, "refurbishing costs well under a new part (%.0f of %.0f)" % [good.cost, good.new_price])
	check(works.estimate("no_such_part", 0.5).is_empty(), "an unknown type has no estimate")
	check(not bool(good.heavy), "a 3R reactor is a light-line part")

	# The stand-in dealer's types: graded machinery with a Void Salvage model, Reclaimed, up to
	# the heavy stand's biggest.
	var types := RefurbWorks.dealer_types(cat, works.tuning.dealer_max_size)
	check(types.size() >= 8, "the dealer has a range of parts (%d)" % types.size())
	var all_r := true
	var big := 0
	for t in types:
		all_r = all_r and t.ends_with("R")
		big += int(RefurbWorks.longest(cat.part(t)) > works.tuning.light_max)
	check(all_r, "the dealer sells Reclaimed parts")
	check(big >= 8, "some of them are big parts for the heavy stand (%d)" % big)

	# A part through the works, no dealer: goods in, the cart, the rollers, a cradle.
	works.standin_dealer = false
	var id := works.receive(TYPE, 0.9)
	check(id > 0 and String(works.lots[id].where) == RefurbWorks.AT_BACKLOG, "a delivered part waits at goods in")
	var seen_stages := {}
	var seen_where := {}
	var t := 0.0
	while t < 600.0 and String(works.lots[id].where) not in [RefurbWorks.AT_OUT, RefurbWorks.AT_SCRAP]:
		works.step(1.0 / 60.0)
		t += 1.0 / 60.0
		seen_where[String(works.lots[id].where)] = true
		var st := int(works.lots[id].stage)
		if st >= 0:
			seen_stages[st] = true
		if st == RefurbWorks.Stage.CLEAN and float(works.lots[id].progress) > 0.5 and not seen_stages.has(99):
			check(float(works.lots[id].grime) < float(works.lots[id].wear), "cleaning takes the grime off")
			seen_stages[99] = true
	var lot: Dictionary = works.lots[id]
	if String(lot.where) == RefurbWorks.AT_SCRAP:
		check(works.scrapped == 1 and works.stock.is_empty(), "a scrapped part is not in stock")
	else:
		check(String(lot.where) == RefurbWorks.AT_OUT, "the part is done within ten minutes (%.0f s)" % t)
		check(seen_where.has(RefurbWorks.AT_CART) and seen_where.has(RefurbWorks.AT_INTAKE) and seen_where.has(RefurbWorks.AT_CARRIED),
				"it came in on the cart, onto the rollers, and a bot carried it (%s)" % [seen_where.keys()])
		check(seen_stages.size() >= 6, "it went through all five stages (%s)" % [seen_stages.keys()])
		check(float(lot.condition) >= works.tuning.pass_at, "it leaves in good condition (%.2f)" % lot.condition)
		check(int(works.stock.get(String(good.result), 0)) == 1 and works.certified == 1, "it is in stock as a Standard part")
		check(works.spent > 0.0 and is_equal_approx(works.spent, float(lot.cost)), "refurbishing it was paid for (%.0f)" % works.spent)
		check(works.take(String(good.result)) and works.stock.is_empty(), "taking it out of stock")
		check(not works.take(String(good.result)), "nothing left to take")
	check(String(works.bots[0].state) in [RefurbWorks.BOT_RETURN, RefurbWorks.BOT_DOCK], "the bot goes back to its charger")
	for i in 60 * 30:
		works.step(1.0 / 60.0)
	check((works.bots[0].pos as Vector3).distance_to(works.dock_point(0)) < 0.05, "with nothing to do it hangs on its charger rack")
	check(String(works.cart.phase) == "park", "the cart is back at goods in")

	# A big part: the cart brings it, the crane lifts it onto the heavy stand, a team works it,
	# the crane takes it to the heavy out bay (or, cut up, to the skip).
	var wh := RefurbWorks.new(null, cat)
	wh.standin_dealer = false
	var big_type := ""
	for bt in types:
		if RefurbWorks.longest(cat.part(bt)) > 7.0:
			big_type = bt
			break
	var hid := wh.receive(big_type, 0.85)
	check(hid > 0 and bool(wh.lots[hid].heavy), "a %s (%.1f m) is a heavy-stand part" % [big_type, RefurbWorks.longest(cat.part(big_type))])
	var hw := {}
	var team_max := 0
	var heavy_light_help := false
	var th := 0.0
	while th < 1500.0 and String(wh.lots[hid].where) not in [RefurbWorks.AT_OUT, RefurbWorks.AT_SCRAP]:
		wh.step(1.0 / 60.0)
		th += 1.0 / 60.0
		hw[String(wh.lots[hid].where)] = true
		var team := wh.heavy_team(hid)
		team_max = maxi(team_max, team.size())
		for b in team:
			heavy_light_help = heavy_light_help or String(b.role) == "light"
	var hl: Dictionary = wh.lots[hid]
	check(hw.has(RefurbWorks.AT_CART) and hw.has(RefurbWorks.AT_CRANE) and hw.has(RefurbWorks.AT_CRADLE), "it came on the cart and went under the crane (%s)" % [hw.keys()])
	check(String(hl.where) in [RefurbWorks.AT_OUT, RefurbWorks.AT_SCRAP], "the big part is done within 25 minutes (%.0f s, %s)" % [th, hl.where])
	check(team_max >= 3 and heavy_light_help, "a team works it, idle light-line bots joining in (most %d)" % team_max)
	if String(hl.where) == RefurbWorks.AT_OUT:
		check(wh.heavy_out == hid and (hl.pos as Vector3).distance_to(RefurbWorks.HEAVY_OUT_AT) < 0.05, "the crane set it in the heavy out bay")
		check(int(wh.stock.get(String(hl.result), 0)) == 1, "it is in stock")
	for i in 60 * 60:
		wh.step(1.0 / 60.0)
	check(not wh.crane_busy() and wh.cradles[wh.heavy_index()] < 0, "the crane is parked and the stand free")
	var home := 0
	for b in wh.bots:
		home += int((b.pos as Vector3).distance_to(wh.dock_point(int(b.id))) < 0.05)
	check(home == wh.bots.size(), "every bot is home on the charger rack (%d of %d)" % [home, wh.bots.size()])
	check(wh.receive("box_beam:6R", 0.5) < 0 or RefurbWorks.longest(cat.part("box_beam:6R")) <= wh.tuning.heavy_max, "a part too big for the annex is turned away")

	# Worn parts: some scrapped at inspection, some sent back once from the bench test.
	var w2 := RefurbWorks.new(null, cat)
	w2.standin_dealer = false
	for i in 24:
		w2.receive(TYPE, 0.1)
	for i in 60 * 60 * 30:
		w2.step(1.0 / 60.0)
	var retests := 0
	for l: Dictionary in w2.lots.values():
		retests += int(bool(l.retest))
	check(w2.scrapped > 0 and w2.certified > 0, "worn parts: %d certified, %d scrapped" % [w2.certified, w2.scrapped])
	check(retests > 0, "some failed the bench test first time (%d)" % retests)
	check(w2.lots_at(RefurbWorks.AT_STORES).size() > 0, "a full refurbished rack moves the oldest on to the stores")
	var docked := 0
	for b in w2.bots:
		docked += int(String(b.state) == RefurbWorks.BOT_DOCK)
	check(docked == w2.bots.size(), "with nothing left, every bot is back on its charger")

	# Determinism: the dealer on, ten minutes run twice from scratch, the same shop.
	var a := RefurbWorks.new(null, cat)
	var b2 := RefurbWorks.new(null, cat)
	for i in 60 * 600:
		a.step(1.0 / 60.0)
	for i in 60 * 600:
		b2.step(1.0 / 60.0)
	check(a.lots.size() >= 6, "the stand-in dealer brought lots in ten minutes (%d)" % a.lots.size())
	var heavies := 0
	for l: Dictionary in a.lots.values():
		heavies += int(bool(l.heavy))
	check(heavies >= 1, "some of them big (%d)" % heavies)
	check(a.fingerprint() == b2.fingerprint(), "the same ticks make the same shop")
	b2.reset()
	for i in 60 * 600:
		b2.step(1.0 / 60.0)
	check(a.fingerprint() == b2.fingerprint(), "reset and replayed: the same shop again")
	var t0 := Time.get_ticks_usec()
	for i in 3600:
		a.step(1.0 / 60.0)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 3600.0
	check(ms < 0.2, "a tick is cheap enough to replay for a late joiner (%.4f ms)" % ms)

	await _shop()
	await _shop_moves()


## The works drawn on a local clock: the requests go through its log, its bots draw, the board
## reads the state.
func _shop() -> void:
	var bus := Modules.bus("refurb") as RefurbBus
	check(bus != null, "the refurb module loads")
	var annex: AABB = YardLayout.ROOMS["refurb"].box
	var hall: AABB = YardLayout.ROOMS["racking"].box
	check(annex.has_point(RefurbBus.shop_at() + Vector3(0, 0.1, 0)) and YardLayout.room_at(RefurbBus.shop_at() + Vector3(0, 1, 0)) == "refurb", "the works sits in its annex")
	check(is_equal_approx(annex.position.z, hall.end.z) and annex.position.x >= hall.position.x and annex.end.x <= hall.end.x, "the annex is behind the stores hall")
	check(YardLayout.has_gravity(RefurbBus.shop_at() + Vector3(0, 1, 0)), "the annex has the station's gravity")
	var holder := Node3D.new()
	add_child(holder)
	var shop: Node3D = RefurbBus.Shop.new()
	holder.add_child(shop)
	var works := RefurbWorks.new()
	works.standin_dealer = false
	shop.call("setup", null, null, works)
	shop.call("request", {"kind": "refurb.in", "type": TYPE, "condition": 0.97})
	shop.call("run_ticks", 2)
	check(works.lots.size() == 1, "a request is applied at its tick")
	shop.call("run_ticks", 60 * 60)
	shop.call("draw", 0.016)
	await frames(2)
	check(works.lots_at(RefurbWorks.AT_CRADLE).size() == 1, "the part is on a cradle (%s)" % works.fingerprint())
	check(String(shop.call("board_text")).contains("REACTOR") or String(shop.call("board_text")).to_upper().contains("REACTOR"), "the board names it")
	check((shop.get("bots") as Array).size() == works.bots.size(), "every refurbisher is drawn")
	# The wall screen (the design room's layout) shows the part on its stand.
	var board := shop.find_child("RefurbBoard", true, false)
	check(board != null, "the works has its wall screen")
	if board:
		var said := ""
		for l in board.find_children("*", "Label", true, false):
			said += (l as Label).text + "\n"
		check(said.to_upper().contains("REACTOR") and said.contains("R1") and said.contains("HEAVY"), "the wall screen lists each stand and the part on it")
	# No signs or floor labels in the annex (0.4.5 playtest): only the drones' own stencils.
	var signs := 0
	for l in shop.find_children("*", "Label3D", true, false):
		var on_bot := false
		for b: Node in shop.get("bots"):
			if b.is_ancestor_of(l):
				on_bot = true
		if not on_bot:
			signs += 1
	check(signs == 0, "no labels in the annex (%d)" % signs)
	# BSX's drones, not TartanCo's.
	var named := ""
	for l in shop.find_children("*", "Label3D", true, false):
		named += (l as Label3D).text
	check(named.contains("BSX") and not named.to_upper().contains("TARTAN"), "the drones carry BSX's name")
	# The pressure washer runs while a drone cleans.
	var sprays := shop.find_children("Spray*", "", true, false)
	check(sprays.size() == works.bots.size(), "each drone has its pressure washer")
	var gfx := Modules.bus("graphics")
	if gfx and gfx.has_method("zfight_scan"):
		var found: Array = gfx.call("zfight_scan", shop)
		check(found.is_empty(), "no flickering faces in the shop (%d):\n%s" % [found.size(), gfx.call("describe_zfights", found, 40)])
	holder.queue_free()
	await frames(2)


## How the drones work a part (0.4.7 playtest): inspecting, a drone hovers off the part and
## scans across it with beams from its eye, a line of light moving over the part; the pressure
## washer only runs with the lance at the part, never from across the annex.
func _shop_moves() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var shop: Node3D = RefurbBus.Shop.new()
	holder.add_child(shop)
	var works := RefurbWorks.new()
	works.standin_dealer = false
	shop.call("setup", null, null, works)
	shop.call("request", {"kind": "refurb.in", "type": TYPE, "condition": 0.6})
	var lot: Dictionary = {}
	var bot: Dictionary = {}
	for k in 60 * 240:
		shop.call("run_ticks", 1)
		var on := works.lots_at(RefurbWorks.AT_CRADLE)
		if on.size() == 1 and int(on[0].stage) == RefurbWorks.Stage.INSPECT and int(on[0].bot) >= 0:
			var b: Dictionary = works.bots[int(on[0].bot)]
			if String(b.state) == RefurbWorks.BOT_WORK and (b.pos as Vector3).distance_to(b.target) < 0.05:
				lot = on[0]
				bot = b
				break
	check(not lot.is_empty(), "a drone gets to inspecting a part (%s)" % works.fingerprint())
	if lot.is_empty():
		holder.queue_free()
		return
	var i := int(bot.id)
	var top := (lot.pos as Vector3).y + float(lot.h)
	check((bot.pos as Vector3).y > top, "inspecting, it hovers above the part (%.2f over %.2f)" % [(bot.pos as Vector3).y, top])
	for f in 3:
		shop.call("draw", 0.016)
	var scan: Node3D = shop.find_child("Scan%d" % i, true, false)
	var beams: MeshInstance3D = scan.find_child("Beams", false, false) if scan else null
	check(beams != null and (beams.mesh as ImmediateMesh).get_surface_count() == 2, "it scans the part with a fan of beams")
	var n: Node3D = shop.get("_lot_nodes").get(int(lot.id))
	var mat: ShaderMaterial = n.get_meta("mat") if n else null
	check(mat != null and mat.next_pass is ShaderMaterial, "a line of light moves over the part it scans")
	var other := shop.find_child("Scan%d" % ((i + 1) % works.bots.size()), true, false)
	check(other != null and (other.find_child("Beams", false, false).mesh as ImmediateMesh).get_surface_count() == 0, "an idle drone draws no beams")
	# Cleaning: the washer runs at the part, not while the drone is still flying in.
	lot.stage = RefurbWorks.Stage.CLEAN
	bot.tool = "blaster"
	var spray: Node3D = shop.find_child("Spray%d" % i, true, false)
	var at: Vector3 = bot.pos
	bot.pos = at + Vector3(0, 0, 8.0)
	for f in 3:
		shop.call("draw", 0.016)
	check(not bool(spray.get("on")), "no spray from a drone still flying in")
	check((beams.mesh as ImmediateMesh).get_surface_count() == 0, "no beams once it stops scanning")
	bot.pos = at
	for f in 3:
		shop.call("draw", 0.016)
	check(bool(spray.get("on")), "the washer runs with the lance at the part")
	var look: Node3D = shop.get("bots")[i]
	var tip: Vector3 = look.get("tip")
	var to_part := (n.global_position - tip) if n else Vector3.ZERO
	check(tip.distance_to(n.global_position) < 3.0, "the lance is at the part (%.2f m)" % tip.distance_to(n.global_position))
	check((look.get("tip_dir") as Vector3).dot(to_part.normalized()) > 0.3, "the lance points at the part")
	holder.queue_free()
	await frames(2)
