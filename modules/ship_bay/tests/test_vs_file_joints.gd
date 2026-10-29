extends ModuleTest
## Shared Components, for Ship and Bay: every weld, spot weld, bolt and rivet in Void Salvage's
## ship files (the Kestrel and the Manta, from its 0.137 exports) is a fastener the trades can
## work, on the ship as it is and on wrecks made from it (beenster, 27 Oct: "all welds, bolts
## and rivets must interact with our appropriate tools"). A joint is workable while both of its
## parts are still on the ship; a broken one starts undone.
##   tools/run_tests.sh ship_bay

const LayoutLoader := preload("res://modules/ship_bay/internal/layout_loader.gd")
const WORKED := ["weld", "bolt", "rivet", "connector"]


func run_tests() -> void:
	for design: String in ["kestrel", "manta"]:
		var file := VsShipImport.design_source(design)
		check(not file.is_empty() and str(file.get("generator", {}).get("version", "")) >= "0.137.0",
				"%s: the 0.137 file (%s)" % [design, file.get("generator", {}).get("version", "")])
		_covered(design + " as built", file)
		for events: Variant in ["weathered:2", "collision:3,fire:2", "breach:3,stripped:2"]:
			_covered("%s, %s" % [design, events], WreckMaker.for_design(design, 84, events))
	var kestrel := LayoutLoader.load_ship(ShipBayBus.SHIPS["vs_kestrel"])
	var kinds := {}
	for s: MountSlot in kestrel.slots:
		for f: FastenerPoint in s.fasteners:
			kinds[f.kind] = true
	check(kestrel != null and kinds.has("weld") and kinds.has("bolt") and kinds.has("rivet"),
			"the bay's Kestrel loads from the new file with welds, bolts and rivets: %s" % [kinds.keys()])


## Every joint whose two parts are still on the ship is a fastener of a kind the tools take,
## exactly once, at the joint's own place.
func _covered(label: String, f: Dictionary) -> void:
	var def := LayoutLoader.from_file(f, "probe", LayoutLoader.WRECK_RULES)
	check(def != null, "%s: loads" % label)
	if def == null:
		return
	var dparts: Dictionary = WreckMaker.damage_of(f).get("parts", {})
	var on := {}
	for p: Dictionary in f.get("parts", []):
		var st := str((dparts.get(p["path"], {}) as Dictionary).get("state", WreckMaker.STATE_ATTACHED))
		if st == WreckMaker.STATE_ATTACHED:
			on[p["path"]] = true
	var seen := {}
	var boxes := {}
	var twice := 0
	var bad_kind: Array = []
	var off := 0
	for s: MountSlot in def.slots:
		for fp: FastenerPoint in s.fasteners:
			if fp.has_meta("copy"):
				continue   # an inside panel's extra bolts share their file joint (0.3.32)
			if seen.has(fp.path):
				twice += 1
			seen[fp.path] = fp
			boxes[fp.path] = s.box
			if not fp.kind in WORKED:
				bad_kind.append(fp.kind)
	var missing: Array = []
	var unhid: Array = []
	var counts := {}
	for j: Dictionary in f.get("joints", []):
		if not (on.has(j["a"]) and on.has(j["b"])):
			continue
		counts[j["kind"]] = int(counts.get(j["kind"], 0)) + 1
		if not seen.has(j["path"]):
			missing.append(j["path"])
		elif (seen[j["path"]] as FastenerPoint).position.distance_to(Vector3(j["at"][0], j["at"][1], j["at"][2])) > _slack(seen[j["path"]], j):
			# Bolts hidden under a fitting's foot are moved out where you can see them (0.3.27).
			var was := FastenerPoint.new()
			was.position = Vector3(j["at"][0], j["at"][1], j["at"][2])
			was.normal = (seen[j["path"]] as FastenerPoint).normal
			if LayoutLoader.is_under(was, boxes[j["path"]]) and LayoutLoader.unhides(str(j["a"])):
				unhid.append(str(j["a"]).get_slice("/", 1))
			else:
				off += 1
	check(missing.is_empty(), "%s: every joint still on her is workable (%s; %d missing %s)" % [label, counts, missing.size(), missing.slice(0, 5)])
	check(twice == 0 and bad_kind.is_empty() and off == 0, "%s: once each, a tool's kind, in place (%d twice, kinds %s, %d moved; %d out from under fittings, %s)" % [label, twice, bad_kind, off, unhid.size(), unhid.slice(0, 6)])


## How far a fastener may sit from its joint's place: an inside wall's or floor's weld made a
## row of bolts has its first bolt along the seam (LayoutLoader._bolted_inside).
func _slack(fp: FastenerPoint, j: Dictionary) -> float:
	if not fp.has_meta("inside"):
		return 0.001
	var size: Variant = j.get("seam_size")
	return (float(size[0]) * 0.5 if size is Array else 0.0) + 0.001
