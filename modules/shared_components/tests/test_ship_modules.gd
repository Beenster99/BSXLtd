extends ModuleTest
## The ship upgrades BSX names: every module file is complete and consistent, and the ids
## contracts already use are there.
##   tools/run_tests.sh shared_components

const CATEGORIES: PackedStringArray = ["handling", "sensors", "towing", "fuel", "processing"]
const MOUNTS: PackedStringArray = ["hold", "roof", "hull", "engineering"]
const STATS: PackedStringArray = ["attractor_cap", "hold_capacity", "contact_range", "survey_time",
		"tow_mass", "bowser_capacity"]


func run_tests() -> void:
	var lib := Modules.bus("shared_components") as SharedComponentsBus
	check(lib != null, "shared_components bus is loaded")
	if lib == null:
		return
	var ids := lib.ship_module_ids()
	check(ids.size() == 10, "ten ship modules: %s" % [ids])
	for id in ["attractor_coil_1", "hold_net"]:
		check(lib.is_ship_module(id), "contracts' module id '%s' exists" % id)
	check(lib.ship_module("no_such_module") == null, "unknown module is null")
	check(lib.ship_module_ids("S").has("attractor_coil_1") and not lib.ship_module_ids("S").has("smelter"),
			"the Kestrel takes a coil but not a smelter")
	check(lib.ship_module_ids("XL").size() == ids.size(), "the yard ship takes every module")
	check(lib.ship_module("attractor_coil_2").factor > lib.ship_module("attractor_coil_1").factor,
			"Mk II lifts more than Mk I")
	for id in ids:
		_check_module(lib, lib.ship_module(id))


func _check_module(lib: SharedComponentsBus, m: ShipModuleSpec) -> void:
	var id := m.id
	check(m.version >= 1, "%s: schema version" % id)
	check(id == id.to_lower() and not id.contains(" "), "%s: id is snake_case" % id)
	check(m.display_name != "" and m.blurb != "", "%s: has a name and a blurb" % id)
	check(CATEGORIES.has(m.category), "%s: category '%s' is known" % [id, m.category])
	check(MOUNTS.has(m.mount), "%s: mount '%s' is known" % [id, m.mount])
	check(not m.fits.is_empty(), "%s: fits at least one ship class" % id)
	for c in m.fits:
		check(SharedComponentsBus.SHIP_CLASSES.has(c), "%s: ship class '%s' is known" % [id, c])
	if m.stat == "":
		check(is_equal_approx(m.factor, 1.0), "%s: a verb module has factor 1" % id)
	else:
		check(STATS.has(m.stat), "%s: stat '%s' is known" % [id, m.stat])
		check(m.factor > 0.0 and not is_equal_approx(m.factor, 1.0), "%s: factor changes the stat" % id)
	if m.requires != "":
		var r := lib.ship_module(m.requires)
		check(r != null, "%s: requires an existing module" % id)
		if r:
			for c in m.fits:
				check(r.fits.has(c), "%s: what it requires fits class %s too" % [id, c])
	check(m.hours > 0.0, "%s: takes some hours to fit" % id)
