extends ModuleTest
## Refurbishing bots (beenster, 19 Nov): second-hand parts come in at Reclaimed grade, a TartanCo
## RF-2 takes each through inspect, strip, clean, rebuild and test, and a part that passes leaves
## certified at Standard, the same size, for a cost; a cracked one is scrapped. The shop runs on
## the yard's shared clock: the same log replayed to the same tick is the same shop.
##   tools/run_tests.sh refurb

const TYPE := "reactor_small:3R"


func run_tests() -> void:
	var cat := DesignCatalog.load_default()
	var works := RefurbWorks.new(null, cat)
	check(works.bots.size() == works.tuning.cradles and works.cradles.size() == works.tuning.cradles, "one refurbisher per cradle")
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

	# The stand-in dealer's types: graded machinery with a Void Salvage model, Reclaimed, small.
	var types := RefurbWorks.dealer_types(cat, works.tuning.dealer_max_size)
	check(types.size() >= 8, "the dealer has a range of parts (%d)" % types.size())
	var all_r := true
	for t in types:
		all_r = all_r and t.ends_with("R")
	check(all_r, "the dealer sells Reclaimed parts")

	# A part through the shop, no dealer.
	works.standin_dealer = false
	var id := works.receive(TYPE, 0.9)
	check(id > 0 and String(works.lots[id].where) == RefurbWorks.AT_INTAKE, "a delivered part goes on the intake rack")
	var seen_stages := {}
	var t := 0.0
	while t < 600.0 and String(works.lots[id].where) not in [RefurbWorks.AT_OUT, RefurbWorks.AT_SCRAP]:
		works.step(1.0 / 60.0)
		t += 1.0 / 60.0
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
		check(seen_stages.size() >= 6, "it went through all five stages (%s)" % [seen_stages.keys()])
		check(float(lot.condition) >= works.tuning.pass_at, "it leaves in good condition (%.2f)" % lot.condition)
		check(int(works.stock.get(String(good.result), 0)) == 1 and works.certified == 1, "it is in stock as a Standard part")
		check(works.spent > 0.0 and is_equal_approx(works.spent, float(lot.cost)), "refurbishing it was paid for (%.0f)" % works.spent)
		check(works.take(String(good.result)) and works.stock.is_empty(), "taking it out of stock")
		check(not works.take(String(good.result)), "nothing left to take")
	check(String(works.bots[0].state) in [RefurbWorks.BOT_RETURN, RefurbWorks.BOT_DOCK], "the bot goes back to its dock")

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
	check(docked == w2.bots.size(), "with nothing left, every bot is back on its dock")

	# Determinism: the dealer on, ten minutes run twice from scratch, the same shop.
	var a := RefurbWorks.new(null, cat)
	var b2 := RefurbWorks.new(null, cat)
	for i in 60 * 600:
		a.step(1.0 / 60.0)
	for i in 60 * 600:
		b2.step(1.0 / 60.0)
	check(a.lots.size() >= 6, "the stand-in dealer brought lots in ten minutes (%d)" % a.lots.size())
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


## The shop drawn on a local clock: the requests go through its log, its bots draw, the board
## reads the state.
func _shop() -> void:
	var bus := Modules.bus("refurb") as RefurbBus
	check(bus != null, "the refurb module loads")
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
	shop.call("run_ticks", 60 * 45)
	shop.call("draw", 0.016)
	await frames(2)
	check(works.lots_at(RefurbWorks.AT_CRADLE).size() == 1, "the part is on a cradle (%s)" % works.fingerprint())
	check(String(shop.call("board_text")).contains("REACTOR") or String(shop.call("board_text")).to_upper().contains("REACTOR"), "the board names it")
	check((shop.get("bots") as Array).size() == works.bots.size(), "every refurbisher is drawn")
	holder.queue_free()
	await frames(2)
