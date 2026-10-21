extends ModuleTest
## Progression: XP and levels from joints, perks and upgrades as effects, certs from test
## jobs and lapsing, buying upgrades through Business, save round trip.
##   tools/run_tests.sh progression


class TradesStub:
	extends Node
	var modifiers := {}

	func set_player_modifiers(player_id: StringName, effects: Dictionary) -> void:
		modifiers[player_id] = effects


class BusinessStub:
	extends Node
	signal purchase_completed(order_id)
	signal purchase_failed(order_id, reason)
	var cash := 0
	var charged: Array = []

	func request_purchase(price_ref: StringName, order_id: String) -> void:
		if cash <= 0:
			purchase_failed.emit(order_id, "no_funds")
			return
		charged.append(price_ref)
		purchase_completed.emit(order_id)


class QualityStub:
	extends Node
	signal joint_graded(record)
	signal record_dropped(joint_id)
	signal test_passed(job_id, player_ids)
	var modifiers := {}

	func set_player_modifiers(player_id: StringName, effects: Dictionary) -> void:
		modifiers[player_id] = effects

	func grade(joint_id: String, trade: StringName, peer_id: int, score: int) -> void:
		var r := Record.new()
		r.joint_id = StringName(joint_id)
		r.trade = trade
		r.peer_id = peer_id
		r.score = score
		joint_graded.emit(r)


## The JointRecord fields Progression reads.
class Record:
	extends RefCounted
	var joint_id: StringName
	var trade: StringName
	var peer_id := 1
	var score := -1


class ContractsStub:
	extends Node
	signal job_closed(job_id)


var events: Array = []


func run_tests() -> void:
	var start_flags := Flags.all()
	var on := start_flags.duplicate()
	for f in [ProgressionBus.PERKS, ProgressionBus.CERTS, ProgressionBus.UPGRADES]:
		on[f] = true
	on["progression"] = true
	Flags.use(on)
	var trades := TradesStub.new()
	var business := BusinessStub.new()
	var quality := QualityStub.new()
	var contracts := ContractsStub.new()
	for n in [trades, business, quality, contracts]:
		add_child(n)
	var bus := ProgressionBus.new()
	add_child(bus)
	bus.attach(trades, business, quality, contracts)
	bus.level_up.connect(func(p, s, l): events.append(["level_up", p, s, l]))
	bus.cert_awarded.connect(func(p, c): events.append(["cert", p, c]))
	bus.cert_lapsed.connect(func(p, c): events.append(["lapsed", p, c]))
	bus.upgrade_unlocked.connect(func(u): events.append(["unlocked", u]))
	bus.upgrade_failed.connect(func(u, why): events.append(["failed", u, why]))

	check(bus.skills().size() == 4, "one skill per joint-making tool loads from data")
	check(bus.certs().size() >= 1 and bus.upgrades().size() >= 1, "certs and upgrades load")

	# XP: 10 per joint scoring 100, scaled by score; level 1 at 100 XP. Peer 2 is "ana".
	for i in 9:
		quality.grade("j%d" % i, &"WELD", 2, 100)
	check(bus.skill_xp(&"ana", &"welding") == 0, "players are keyed by peer id for now")
	check(bus.skill_xp(&"2", &"welding") == 90, "nine perfect welds give 90 XP")
	check(bus.skill_level(&"2", &"welding") == 0, "still level 0 below 100 XP")
	quality.grade("j9", &"WELD", 2, 30)
	check(bus.skill_xp(&"2", &"welding") == 93, "a score of 30 gives 30% XP")
	quality.grade("j9", &"WELD", 2, 50)
	check(bus.skill_xp(&"2", &"welding") == 95, "a regraded joint adds only the difference")
	quality.grade("j9", &"WELD", 2, 20)
	check(bus.skill_xp(&"2", &"welding") == 95, "a worse regrade takes nothing away")
	quality.record_dropped.emit(&"j9")
	quality.grade("j9", &"WELD", 2, -1)
	check(bus.skill_xp(&"2", &"welding") == 100, "a rebuilt ungraded joint earns half afresh")
	check(bus.skill_level(&"2", &"welding") == 1, "level 1 at 100 XP")
	check(events.has(["level_up", &"2", &"welding", 1]), "level_up emitted")
	check(is_equal_approx(bus.effect(&"2", &"weld_bead_stability"), 0.05), "level 1 perk applies")
	check(trades.modifiers.get(&"2", {}).has(&"weld_bead_stability"), "effects pushed to Trades")
	check(quality.modifiers.get(&"2", {}).has(&"weld_bead_stability"), "effects pushed to Quality")
	check(bus.effect(&"3", &"weld_bead_stability") == 0.0, "other players unaffected")
	quality.grade("j11", &"NO_SUCH_TRADE", 2, 100)
	check(bus.skill_xp(&"2", &"welding") == 100, "unknown trades ignored")

	# Certs: pressure welding needs welding level 2 and its test job.
	quality.test_passed.emit(&"cert_test_pressure_weld", [&"2"])
	check(not bus.has_cert(&"2", &"pressure_welding"), "no cert below the skill level")
	for i in 20:
		quality.grade("k%d" % i, &"WELD", 2, 100)
	check(bus.skill_level(&"2", &"welding") == 2, "level 2 at 300 XP")
	quality.test_passed.emit(&"cert_test_pressure_weld", [&"2", &"3"])
	check(bus.has_cert(&"2", &"pressure_welding"), "cert earned on a passed test")
	check(not bus.has_cert(&"3", &"pressure_welding"), "unskilled player gets no cert")
	for i in 19:
		contracts.job_closed.emit("job%d" % i)
	check(bus.has_cert(&"2", &"pressure_welding"), "cert still valid after 19 jobs")
	contracts.job_closed.emit("job19")
	check(not bus.has_cert(&"2", &"pressure_welding"), "cert lapses after 20 jobs")
	check(events.has(["lapsed", &"2", &"pressure_welding"]), "cert_lapsed emitted")

	# Upgrades: prerequisites, Business refusing, Business charging.
	bus.request_upgrade(&"inspection_scanner")
	check(not bus.has_upgrade(&"inspection_scanner"), "prerequisite enforced")
	check(not bus.can_unlock(&"inspection_scanner").ok, "can_unlock reports the missing crane")
	bus.request_upgrade(&"second_crane")
	check(events.has(["failed", &"second_crane", "no_funds"]), "Business refusal reported")
	business.cash = 1000
	bus.request_upgrade(&"second_crane")
	check(bus.has_upgrade(&"second_crane"), "upgrade owned after purchase")
	check(business.charged == [&"upgrade.second_crane"], "charged through the upgrade's price_ref")
	check(is_equal_approx(bus.effect(&"3", &"lift_speed"), 0.2), "company upgrade applies to everyone")
	check(bus.can_unlock(&"inspection_scanner").ok, "scanner unlockable once the crane is owned")
	check(bus.can_unlock(&"second_crane").missing == [&"owned"], "owned upgrades can't be bought twice")

	# Save round trip through Saves.
	var slot := "_test_progression_%d" % Time.get_ticks_usec()
	Saves.register_section("progression_test", bus)
	check(Saves.save(slot) == OK, "save writes")
	var fresh := ProgressionBus.new()
	add_child(fresh)
	var quality2 := QualityStub.new()
	add_child(quality2)
	fresh.attach(trades, null, quality2, null)
	Saves.register_section("progression_test", fresh)
	check(Saves.load_slot(slot) == OK, "load reads")
	check(fresh.skill_xp(&"2", &"welding") == bus.skill_xp(&"2", &"welding"), "XP survives a save")
	quality2.grade("j0", &"WELD", 2, 100)
	check(fresh.skill_xp(&"2", &"welding") == bus.skill_xp(&"2", &"welding"), "regrade after a load gives no XP twice")
	check(fresh.has_upgrade(&"second_crane"), "upgrades survive a save")
	check(is_equal_approx(fresh.effect(&"2", &"weld_bead_stability"), 0.05), "effects rebuilt after load")
	Saves.unregister_section("progression_test")
	DirAccess.remove_absolute(Saves.path_for(slot))

	# With the features switched off: no perks, no certs, no buying.
	Flags.use(start_flags)
	Flags.set_flag("progression", true)
	check(bus.effect(&"2", &"weld_bead_stability") == 0.0, "no perks with progression.perks off")
	check(bus.effect(&"3", &"lift_speed") == 0.0, "no upgrade effects with progression.upgrades off")
	bus.request_upgrade(&"inspection_scanner")
	check(events.has(["failed", &"inspection_scanner", "upgrades_off"]), "no buying with progression.upgrades off")
	quality.test_passed.emit(&"cert_test_pressure_weld", [&"2"])
	check(not bus.has_cert(&"2", &"pressure_welding"), "no certs with progression.certs off")
	check(bus.skill_level(&"2", &"welding") == 2, "levels still count")
	Flags.use(on)

	# Loader: Progression only loads with its chain on.
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "trades": true,
			"quality": true, "business": true, "multiplayer": true, "progression": true})
	Modules.load_all()
	check(Modules.bus("progression") is ProgressionBus, "progression loads with its chain on")
	Flags.use(start_flags)
	Modules.load_all()
	check(Modules.is_loaded("progression"), "progression on in the project flags")
	for f in [ProgressionBus.PERKS, ProgressionBus.CERTS, ProgressionBus.UPGRADES]:
		check(not Flags.is_on(f), "%s off in the project flags" % f)
