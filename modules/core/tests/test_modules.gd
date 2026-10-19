extends ModuleTest
## Modules: manifests found, dependency order, flags and missing dependencies respected.
##   tools/run_tests.sh core


func run_tests() -> void:

	var manifests: Dictionary = Modules.read_manifests("res://modules")
	check(manifests.has("ui") and manifests.has("trades"), "manifests found: %s" % str(manifests.keys()))
	check(not manifests.has("core"), "core is built in, not loaded from a manifest")
	for id in manifests:
		var m: ModuleManifest = manifests[id]
		for dep in m.depends_on:
			check(manifests.has(dep), "%s depends on known module %s" % [id, dep])

	var order: PackedStringArray = Modules.load_order(manifests)
	check(order.size() == manifests.size(), "every module ordered (no cycles)")
	for id in manifests:
		for dep in manifests[id].depends_on:
			check(order.find(dep) < order.find(id), "%s loads before %s" % [dep, id])

	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "trades": true,
			"quality": false, "business": false})
	Modules.load_all()
	check(Modules.is_loaded("trades"), "trades loads with its chain on")
	check(Modules.bus("trades") is TradesBus, "trades bus reachable")
	check(not Modules.is_loaded("quality"), "quality off by flag")
	check(Modules.skipped_reason("quality") == "flag off", "skip reason for a flag")

	Flags.use({"core": true, "ui": true, "contracts": false, "ship_bay": true, "trades": true})
	Modules.load_all()
	check(not Modules.is_loaded("ship_bay"), "ship_bay skipped without contracts")
	check(Modules.skipped_reason("ship_bay") == "needs contracts", "skip reason for a dependency")
	check(not Modules.is_loaded("trades"), "trades skipped down the chain")

	Flags.use(saved)
	Modules.load_all()
