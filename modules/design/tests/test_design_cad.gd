extends ModuleTest
## Walk-inside as a CAD model (WalkCad: a flat colour per class of object, V for the real look)
## and windows: glass in the hull opens the room's wall or ceiling behind it (WalkBuild).
##   tools/run_tests.sh design

const WalkBuild := preload("res://modules/design/internal/walk/walk_build.gd")
const WalkCad := preload("res://modules/design/internal/walk/walk_cad.gd")
const Samples := preload("res://modules/design/internal/sample_designs.gd")


func run_tests() -> void:
	var cat := DesignCatalog.load_default()
	var rec := DesignRecord.new("s", "Skiff")
	Samples.skiff(rec, cat)
	var b := WalkBuild.new(cat)
	var root := Node3D.new()
	add_child(root)
	b.build(rec, root)
	var cad := WalkCad.new()
	cad.apply(root, rec, cat, b.frame_mats)
	var ceil := root.get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with("Ceiling_"))
	check(not ceil.is_empty() and _colour(ceil[0]) == _rgb(WalkCad.CLASSES.ceiling.colour), "ceilings take the ceiling colour")
	var door := root.get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with("Door_"))
	var dm := (door[0] as Node).find_children("*", "GeometryInstance3D", true, false) if not door.is_empty() else []
	check(not dm.is_empty() and _colour(dm[0]) == _rgb(WalkCad.CLASSES.door.colour), "doors are orange")
	var part := root.get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with("Part_"))
	var pm := (part[0] as Node).find_children("*", "GeometryInstance3D", true, false) if not part.is_empty() else []
	var pid := str(part[0].name).trim_prefix("Part_") if not part.is_empty() else ""
	var want := cat.part(str(rec.components[pid].type)).colour if pid != "" else Color.BLACK
	check(not pm.is_empty() and _colour(pm[0]) == _rgb(want), "a part takes its kind's colour")
	var frame := root.get_node_or_null("Frame")
	var seen := {}
	for g in frame.find_children("*", "GeometryInstance3D", true, false):
		var m := (g as GeometryInstance3D).material_override
		if m is StandardMaterial3D:
			seen[(m as StandardMaterial3D).albedo_color.to_html()] = true
	for k in ["frame", "hull", "glass"]:
		check(seen.has((WalkCad.CLASSES[k].colour as Color).to_html()), "the frame has %s in its colour" % k)
	# The bridge's glazed roof: no ceiling or roof plate hides it.
	check(root.get_node_or_null("Ceiling_r1") == null and root.get_node_or_null("Roof_r1") == null,
			"under the bridge's glass roof there is no ceiling")
	check(root.get_node_or_null("Ceiling_r5") != null, "engineering, under metal, keeps its ceiling")
	check(b.windows == 0, "no side glass, no wall windows")
	# Glass in the side of the hull by engineering: its outer wall opens there.
	var plan := DesignFrame.propose(rec)
	var prof: PackedVector2Array = plan.stations[0].profile
	var side := -1
	var best := -INF
	for e in prof.size():
		var x := minf(prof[e].x, prof[(e + 1) % prof.size()].x)
		if absf(prof[e].x - prof[(e + 1) % prof.size()].x) < 0.01 and x > best:
			best = x
			side = e
	rec.apply({"op": "set_frame", "key": DesignFrame.panel_key(1.0, side), "value": {"glass": true}})
	b.build(rec, root)
	check(b.windows > 0, "glass in the side opens the wall beside it: %d windows" % b.windows)
	root.queue_free()


static func _rgb(c: Color) -> String:
	return Color(c.r, c.g, c.b, c.a).to_html()


static func _colour(n: Node) -> String:
	var m: Variant = (n as GeometryInstance3D).material_override if n is GeometryInstance3D else null
	return (m as StandardMaterial3D).albedo_color.to_html() if m is StandardMaterial3D else "none"
