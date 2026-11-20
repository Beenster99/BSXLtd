extends ModuleTest
## DesignMatrix: the size x class capability matrix, what each power unit can run, and small
## makes that beat bigger ones.

var cat := DesignCatalog.load_default()


func run_tests() -> void:
	var counts := []
	for g: Dictionary in DesignMatrix.GROUPS:
		var rows := DesignMatrix.rows(cat, str(g.id))
		var n := 0
		for r in rows:
			for s in r.cells:
				n += (r.cells[s] as Dictionary).size()
		counts.append("%s %d types %d cells" % [g.id, rows.size(), n])
		check(rows.size() >= 3, "%s has several makes in the matrix" % g.id)
	print("matrix: " + ", ".join(counts))
	var reactor := DesignMatrix.rows(cat, "power").filter(func(r): return r.base_id == "reactor_small")
	check(reactor.size() == 1, "the fusion reactor is a power row")
	var r: Dictionary = reactor[0]
	check(r.sizes[0] == 2 and r.sizes[-1] == 8, "it comes in sizes 2 to 8")
	var c2p: Dictionary = r.cells[2]["P"]
	var c2s: Dictionary = r.cells[2]["S"]
	var c5s: Dictionary = r.cells[5]["S"]
	check(c2p.label == "2P" and float(c2p.figure) > float(c2s.figure), "class P at size 2 out-powers class S")
	check(float(c5s.figure) > float(c2s.figure) and float(c5s.volume) > float(c2s.volume), "size 5 is bigger and makes more")
	check(cat.part("shield_generator") != null and DesignMatrix.group_of(cat.part("shield_generator")) == "defence", "shield generators are in")
	check(DesignMatrix.group_of(cat.part("radiator")) == "", "a radiator makes nothing, so it isn't a power row")
	# What one reactor can run.
	var runs := DesignMatrix.supports(cat, c2s.id)
	check(not runs.is_empty(), "a size 2 reactor runs some things: %d" % runs.size())
	for id in runs:
		check(DesignMatrix.draw_kw(cat.part(id)) <= float(c2s.make_kw), "%s draws no more than it makes" % id)
		break
	var big_runs := DesignMatrix.supports(cat, str(r.cells[8]["P"].id))
	check(big_runs.size() > runs.size(), "a size 8 Precision reactor runs more: %d" % big_runs.size())
	var eng := DesignMatrix.supports(cat, c2s.id, "propulsion")
	check(eng.all(func(id): return DesignMatrix.group_of(cat.part(id)) == "propulsion"), "supports() can keep to one group")
	var by := DesignMatrix.supported_by(cat, "shield_generator")
	check(not by.is_empty() and by.has(str(c5s.id)), "what can run a shield generator includes a size 5 reactor")
	check(DesignMatrix.supports(cat, "shield_generator").is_empty(), "a consumer supports nothing")
	# Bigger is not always better.
	var pd := cat.part("plasma_drive")
	var ion := cat.part("ion_thruster:4S")
	check(pd != null and ion != null, "plasma drive and a big ion thruster exist")
	check(pd.thrust > ion.thrust and pd.size.x * pd.size.y * pd.size.z < ion.size.x * ion.size.y * ion.size.z,
			"a small plasma drive out-pushes a big ion thruster: %.0f kN vs %.0f kN" % [pd.thrust, ion.thrust])
	var cell := cat.part("compact_fusion_cell")
	check(cell.power > cat.part("generator").power and cell.size.x < cat.part("generator").size.x, "a compact fusion cell out-powers a bigger generator")
	for g in ["power", "propulsion", "defence"]:
		var sb := DesignMatrix.small_beats_big(cat, g)
		print("  ", g, ": ", "%s %s (%.1f m3) beats %s %s (%.1f m3)" % [sb[0].small.name, sb[0].small.label, sb[0].small.volume, sb[0].big.name, sb[0].big.label, sb[0].big.volume]) if not sb.is_empty() else null
		check(not sb.is_empty(), "%s: smaller beats bigger somewhere (%s)" % [g,
				"%s %s beats %s %s" % [sb[0].small.name, sb[0].small.label, sb[0].big.name, sb[0].big.label] if not sb.is_empty() else "none"])
