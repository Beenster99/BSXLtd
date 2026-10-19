extends ModuleTest
## Progression: XP and levels from joints, perks and upgrades as effects, certs from test
## jobs and lapsing, buying upgrades through Business, save round trip.
##   tools/run_tests.sh progression


class TradesStub:
	extends Node
	signal joint_completed(joint_id, quality, trade, player_id)
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
	signal test_passed(job_id, player_ids)


class ContractsStub:
	extends Node
	signal job_closed(job_id)


var events: Array = []


func run_tests() -> void:
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

	check(bus.skills().size() == 5, "five trade skills load from data")
	check(bus.certs().size() >= 1 and bus.upgrades().size() >= 1, "certs and upgrades load")

	# XP: 10 per perfect joint, scaled by quality; level 1 at 100 XP.
	for i in 9:
		trades.joint_completed.emit("j%d" % i, 1.0, &"welding", &"ana")
	check(bus.skill_xp(&"ana", &"welding") == 90, "nine perfect welds give 90 XP")
	check(bus.skill_level(&"ana", &"welding") == 0, "still level 0 below 100 XP")
	trades.joint_completed.emit("j9", 0.5, &"welding", &"ana")
	check(bus.skill_xp(&"ana", &"welding") == 95, "a half quality joint gives half XP")
	trades.joint_completed.emit("j10", 1.0, &"welding", &"ana")
	check(bus.skill_level(&"ana", &"welding") == 1, "level 1 at 100 XP")
	check(events.has(["level_up", &"ana", &"welding", 1]), "level_up emitted")
	check(is_equal_approx(bus.effect(&"ana", &"weld_bead_stability"), 0.05), "level 1 perk applies")
	check(trades.modifiers.get(&"ana", {}).has(&"weld_bead_stability"), "effects pushed to Trades")
	check(bus.effect(&"ben", &"weld_bead_stability") == 0.0, "other players unaffected")
	trades.joint_completed.emit("j11", 1.0, &"no_such_trade", &"ana")
	trades.joint_completed.emit("j12", 1.0, &"welding", &"")
	check(bus.skill_xp(&"ana", &"welding") == 105, "unknown trades and anonymous joints ignored")

	# Certs: pressure welding needs welding level 2 and its test job.
	quality.test_passed.emit(&"cert_test_pressure_weld", [&"ana"])
	check(not bus.has_cert(&"ana", &"pressure_welding"), "no cert below the skill level")
	for i in 20:
		trades.joint_completed.emit("k%d" % i, 1.0, &"welding", &"ana")
	check(bus.skill_level(&"ana", &"welding") == 2, "level 2 at 300 XP")
	quality.test_passed.emit(&"cert_test_pressure_weld", [&"ana", &"ben"])
	check(bus.has_cert(&"ana", &"pressure_welding"), "cert earned on a passed test")
	check(not bus.has_cert(&"ben", &"pressure_welding"), "unskilled player gets no cert")
	for i in 19:
		contracts.job_closed.emit("job%d" % i)
	check(bus.has_cert(&"ana", &"pressure_welding"), "cert still valid after 19 jobs")
	contracts.job_closed.emit("job19")
	check(not bus.has_cert(&"ana", &"pressure_welding"), "cert lapses after 20 jobs")
	check(events.has(["lapsed", &"ana", &"pressure_welding"]), "cert_lapsed emitted")

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
	check(is_equal_approx(bus.effect(&"ben", &"lift_speed"), 0.2), "company upgrade applies to everyone")
	check(bus.can_unlock(&"inspection_scanner").ok, "scanner unlockable once the crane is owned")
	check(bus.can_unlock(&"second_crane").missing == [&"owned"], "owned upgrades can't be bought twice")

	# Save round trip through Saves.
	var slot := "_test_progression_%d" % Time.get_ticks_usec()
	Saves.register_section("progression_test", bus)
	check(Saves.save(slot) == OK, "save writes")
	var fresh := ProgressionBus.new()
	add_child(fresh)
	fresh.attach(trades, null, null, null)
	Saves.register_section("progression_test", fresh)
	check(Saves.load_slot(slot) == OK, "load reads")
	check(fresh.skill_xp(&"ana", &"welding") == bus.skill_xp(&"ana", &"welding"), "XP survives a save")
	check(fresh.has_upgrade(&"second_crane"), "upgrades survive a save")
	check(is_equal_approx(fresh.effect(&"ana", &"weld_bead_stability"), 0.05), "effects rebuilt after load")
	Saves.unregister_section("progression_test")
	DirAccess.remove_absolute(Saves.path_for(slot))

	# Loader: Progression only loads with its chain on.
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "trades": true,
			"quality": true, "business": true, "progression": true})
	Modules.load_all()
	check(Modules.bus("progression") is ProgressionBus, "progression loads with its chain on")
	Flags.use(saved)
	Modules.load_all()
	check(not Modules.is_loaded("progression"), "progression off by default")
