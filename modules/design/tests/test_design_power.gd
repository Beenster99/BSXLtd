extends ModuleTest
## Design Room: solar, batteries, fuel and endurance (DesignPower): solar delivers by the sun
## where she works, is quiet, needs batteries for shadow; generators burn the tanks.
##   tools/run_tests.sh design

var cat := DesignCatalog.load_default()


func ship(parts: Array, region := "") -> DesignRecord:
	var d := DesignRecord.new("p", "Power test")
	d.apply({"op": "add_room", "room": {"id": "r1", "type": "engineering", "x": 0, "z": 0, "w": 8, "d": 8}})
	var i := 0
	for p: String in parts:
		i += 1
		d.apply({"op": "add_component", "component": {"id": "c%d" % i, "type": p, "room": "r1",
				"x": 1 + i % 6, "z": 1 + i / 6, "rot": 0}})
	if region != "":
		d.order = {"id": "o", "region": region}
	return d


func run_tests() -> void:
	var solar := cat.part("solar_panel")
	var bat := cat.part("battery_bank")
	check(solar != null and bat != null, "solar and battery parts exist")
	# Solar alone: delivers its rating in full sun, less further out.
	var t := DesignTotals.compute(ship(["solar_panel", "solar_panel"]), cat)
	check(is_equal_approx(t.solar_rated, 2.0 * solar.power) and is_equal_approx(t.solar_kw, t.solar_rated),
			"full sun with no order: delivered = rated (%s / %s)" % [t.solar_kw, t.solar_rated])
	var outer := DesignTotals.compute(ship(["solar_panel", "solar_panel"], "outer"), cat)
	check(outer.region == "outer" and outer.solar_kw < t.solar_kw * 0.5 and is_equal_approx(outer.solar_rated, t.solar_rated),
			"the outer system delivers far less: %s kW" % outer.solar_kw)
	var deep := DesignTotals.compute(ship(["solar_panel"], "deep"), cat)
	check(deep.solar_kw < 0.1 * deep.solar_rated, "deep space: near nothing")
	# Batteries store, they do not generate.
	var tb := DesignTotals.compute(ship(["battery_bank"]), cat)
	check(tb.power_made == 0.0 and tb.store_kwh > 0.0, "a battery adds storage (%s kWh), not power" % tb.store_kwh)
	# Quiet: solar adds far less signature a kW than a generator.
	var tg := DesignTotals.compute(ship(["generator"]), cat)
	var ts := DesignTotals.compute(ship(["solar_panel"]), cat)
	var base := DesignTotals.compute(ship([]), cat)
	var per_kw_gen := (tg.signature() - base.signature()) / tg.power_made
	var per_kw_sol := (ts.signature() - base.signature()) / maxf(ts.power_made, 0.001)
	check(per_kw_sol < per_kw_gen * 0.2, "solar is quiet: %.3f vs %.3f a kW" % [per_kw_sol, per_kw_gen])
	# Shadow: a solar-only ship with a load and no battery is warned; enough batteries clear it.
	var loaded := ["solar_panel", "solar_panel", "solar_panel", "solar_panel", "solar_panel", "solar_panel",
			"solar_panel", "solar_panel"]
	var d1 := ship(loaded)
	var t1 := DesignTotals.compute(d1, cat)
	check(t1.power_used > 0.0 and t1.power_balance() >= 0.0, "eight arrays carry an engineering room (%s / %s kW)" % [
			t1.power_made, t1.power_used])
	check(not t1.solar_rides_shadow(), "with no battery she cannot ride out shadow")
	var probs := DesignRules.check(d1, cat, t1)
	check(probs.any(func(p: Dictionary) -> bool: return p.code == "solar_shadow"), "WILL IT WORK warns about shadow")
	var t2 := DesignTotals.compute(ship(loaded + ["battery_bank"]), cat)
	check(t2.solar_rides_shadow(), "a battery rack carries her through shadow (%s kWh)" % t2.store_kwh)
	check(t2.endurance_days() >= DesignPower.ENDURANCE_CAP, "solar with stores: endurance at the cap")
	check(t1.endurance_days() == 0.0, "solar without stores: no endurance")
	# Fuel: a generator's endurance comes from the tanks; more tanks, longer.
	var tf := DesignTotals.compute(ship(["generator", "fuel_tank"]), cat)
	var tf2 := DesignTotals.compute(ship(["generator", "fuel_tank", "fuel_tank"]), cat)
	check(tf.endurance_days() > 0.0 and tf2.endurance_days() > tf.endurance_days(),
			"generator endurance grows with fuel: %.1f -> %.1f days" % [tf.endurance_days(), tf2.endurance_days()])
	var none := DesignTotals.compute(ship(["generator"]), cat)
	check(none.endurance_days() == 0.0 or none.power_used <= 0.0, "a generator with no fuel: no endurance")
	# Fit keys: endurance_days and reactors (0 = no reactor aboard).
	var tr := DesignTotals.compute(ship(["reactor_small"]), cat)
	var rows := tr.fit({"reactors": 0, "endurance_days": 10})
	check(rows.size() == 2 and not rows[0].ok and rows[0].label == "No reactor aboard",
			"a no-reactor clause fails with a reactor aboard")
	check(t2.fit({"reactors": 0})[0].ok, "and passes on a solar ship")
	check(t2.fit({"endurance_days": 30})[0].ok, "a solar ship with stores meets 30 days without refuelling")
