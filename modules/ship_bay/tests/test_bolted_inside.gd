extends ModuleTest
## Inside walls and floors are bolted down (beenster, 0.3.31: "the internal walls and floors
## should be bolted but there didn't seem to be as many"): on a wreck made from a Void Salvage
## file, a welded partition or deck plate is held by a row of bolts along each seam, and a
## wall panel Void Salvage holds by a bolt or two gets its edge bolts repeated along the edge.
##   tools/run_tests.sh ship_bay

const LayoutLoader := preload("res://modules/ship_bay/internal/layout_loader.gd")


func run_tests() -> void:
	for design: String in ["vsw:patience", "vsw:sentinel", "vsw:long_hauler"]:
		_check_design(design)


func _check_design(design: String) -> void:
	var f := VsWreckLibrary.file_of(design)
	check(not f.is_empty(), "%s: the file" % design)
	if f.is_empty():
		return
	var recs := {}
	for p: Dictionary in f["parts"]:
		recs[str(p["path"])] = p
	var def := LayoutLoader.from_file(f, "probe", LayoutLoader.WRECK_RULES)
	var inside_welds := 0
	var inside_bolts := 0
	var copies := 0
	var stray := 0
	var file_paths := {}
	for j: Dictionary in f["joints"]:
		file_paths[str(j["path"])] = j
		for end: String in ["a", "b"]:
			if LayoutLoader.is_inside_panel(recs.get(str(j[end]), {})):
				if str(j["kind"]) in ["weld", "spot"]:
					inside_welds += 1
				break
	for s: MountSlot in def.slots:
		for fp: FastenerPoint in s.fasteners:
			var j: Dictionary = file_paths.get(fp.path, {})
			var panel := {}
			for end: String in ["b", "a"]:
				if LayoutLoader.is_inside_panel(recs.get(str(j.get(end, "")), {})):
					panel = recs[str(j[end])]
					break
			if panel.is_empty():
				continue
			if fp.kind == "weld":
				inside_bolts -= 1000   # a weld left on an inside panel
			elif fp.kind == "bolt":
				inside_bolts += 1
			if fp.has_meta("copy"):
				copies += 1
				# Every extra bolt sits on its panel (within a few cm of its box).
				var box := LayoutLoader._box(panel.get("box", {})).grow(LayoutLoader.PANEL_SLACK + 0.001)
				if not box.has_point(fp.position):
					stray += 1
	check(inside_bolts > 0 and inside_bolts >= inside_welds, "%s: inside walls and floors have no welds left, %d bolts (%d welds in the file)" % [design, inside_bolts, inside_welds])
	var was := Flags.is_on("ship_bay.bolted_inside")
	Flags.set_flag("ship_bay.bolted_inside", false)
	var plain := 0
	for s: MountSlot in LayoutLoader.from_file(f, "probe", LayoutLoader.WRECK_RULES).slots:
		plain += s.fasteners.filter(func(fp: FastenerPoint) -> bool: return fp.kind == "bolt").size()
	Flags.set_flag("ship_bay.bolted_inside", was)
	var now := 0
	for s: MountSlot in def.slots:
		now += s.fasteners.filter(func(fp: FastenerPoint) -> bool: return fp.kind == "bolt").size()
	print("  %s: %d bolts on the ship, %d before" % [design, now, plain])
	check(copies > 0, "%s: inside panels got more bolts than the file's (%d extra)" % [design, copies])
	check(stray == 0, "%s: every extra bolt sits on its panel (%d off)" % [design, stray])
	var ids := {}
	var twice := 0
	for s: MountSlot in def.slots:
		for fp: FastenerPoint in s.fasteners:
			if ids.has(fp.joint_id):
				twice += 1
			ids[fp.joint_id] = true
	check(twice == 0, "%s: every fastener has its own id (%d repeated)" % [design, twice])
