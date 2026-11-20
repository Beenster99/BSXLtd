extends ModuleTest
## The build plan (master plan 5.1): the sample skiff as ordered jobs, every joint made once.

const Samples := DesignBus.Samples
const Blueprint := preload("res://modules/build/internal/blueprint.gd")


func run_tests() -> void:
	var cat := DesignCatalog.load_default()
	var rec := DesignRecord.new()
	Samples.skiff(rec, cat)
	var bp := Blueprint.new()
	bp.build(rec, cat)
	var plan := BuildPlan.make(bp.model, func(p: PartData) -> Dictionary: return bp.groups[p.id])
	check(plan.jobs.size() >= 30 and plan.jobs.size() <= 90, "a small ship is some fifty jobs (%d)" % plan.jobs.size())
	check(plan.stages() == PackedStringArray(BuildPlan.STAGE_ORDER), "every stage has jobs: %s" % str(plan.stages()))
	var last := -1
	for j in plan.jobs:
		var s := BuildPlan.STAGE_ORDER.find(str(j.stage))
		check(s >= last, "stages run in order (%s)" % j.name)
		last = s
	check(str(plan.jobs[0].name) == "Frame ring 0", "the first job is frame ring 0 (%s)" % plan.jobs[0].name)
	check(str(plan.jobs[2].name).begins_with("Stringers"), "the stringers follow the second ring (%s)" % plan.jobs[2].name)
	# Every joint is made by exactly one job: a key fastening, an assembly's own or a tack.
	var seen := {}
	var dup := 0
	for j in plan.jobs:
		for k in ["key", "inner", "tack"]:
			for i: int in j[k]:
				if seen.has(i):
					dup += 1
				seen[i] = true
	check(dup == 0, "no joint is made twice (%d)" % dup)
	check(seen.size() == bp.model.connections.size(), "every joint is made (%d of %d)" % [seen.size(), bp.model.connections.size()])
	var parts := 0
	for j in plan.jobs:
		parts += (j.parts as Array).size()
		check((j.key as Array).size() >= 1 or (j.inner as Array).is_empty() and (j.tack as Array).is_empty(), "%s has hand work" % j.name)
		check((j.key as Array).size() <= int(BuildPlan.STAGES[str(j.stage)].key), "%s asks few by hand" % j.name)
	check(parts == bp.model.parts.size(), "every part is in a job")
	check(plan.key_count() < 300, "the hand work is a few hundred fastenings at most (%d)" % plan.key_count())
	var fit := plan.stage_jobs("fittings")
	check(fit.size() == rec.components.size(), "a job per fitting (%d)" % fit.size())
	var bolts := 0
	for j in fit:
		for i: int in j.key:
			if bp.model.connections[i].kind == ConnectionData.Kind.BOLT:
				bolts += 1
	check(bolts >= fit.size() * 2, "fittings are bolted down by hand (%d bolts)" % bolts)
	print("jobs %d, key %d, parts %d, joints %d" % [plan.jobs.size(), plan.key_count(), parts, bp.model.connections.size()])
	for j in plan.jobs:
		print("  %s | %s | parts %d key %d inner %d tack %d" % [j.stage, j.name, (j.parts as Array).size(), (j.key as Array).size(), (j.inner as Array).size(), (j.tack as Array).size()])
