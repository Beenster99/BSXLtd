class_name MotionTable
extends RefCounted
## How each moving part of a design moves (beenster, 19 Nov: "How can we test things like
## cargo doors, under carriage, feet, other major moving parts?"). One spec per catalogue part
## id, in the part's own space: origin on the floor in the middle of its footprint, y up, its
## front -Z (a hull mount's plate against the hull at +Z, its front facing out).
##
## A spec: {kind, range, seconds, kw, load_kg, open (Vector2 w x h, m, ZERO for none), note}
##   kind "hinge_out": a slab hinged at its foot falls outward (-Z): ramps, clamshells, airstairs.
##     range: degrees from upright.
##   kind "hinge_up": a lid hinged at its back top edge lifts: hatches, fold-out arrays.
##   kind "slide_side" / "slide_out" / "slide_up": a leaf slides aside (+X), a collar out (-Z), a
##     platform or forks up (+Y). range: metres (0 = its own width, depth or height).
##   kind "spin": an arm turns about the vertical: cranes, turrets, radars. range: degrees of
##     travel either side of its front (180 = all the way round); reach: arm length, m (0 = its
##     depth); a hull mount turns only through the half facing out.
##   kind "leg": landing gear, legs, jacks, hung under the hull (DesignPartType.under_hull): a
##     strut folded along the hull swings down and its oleo runs out to the part's own foot.
##     stroke: how far the oleo runs (it takes up uneven ground), m (0 = a fifth of its height);
##     load_kg is per foot.
##   kind "belt": a conveyor's belt runs; nothing sweeps. range: belt speed, m/s.
## The catalogue's own figures (DesignPartType open_size, move_s, move_kw, load_kg, clearance,
## and move_kind / move_range when they exist) win over the numbers here.

const SPECS: Dictionary = {
	"cargo_ramp": {"kind": "hinge_out", "range": 100.0, "seconds": 8.0, "kw": 4.0, "load_kg": 6000.0, "note": "Hinged at the sill, it lowers out to the ground"},
	"tail_ramp": {"kind": "hinge_out", "range": 105.0, "seconds": 10.0, "kw": 6.0, "load_kg": 12000.0, "note": "Hinged at the sill, it lowers out to the ground"},
	"clamshell_doors": {"kind": "hinge_out", "range": 95.0, "seconds": 9.0, "kw": 6.0, "load_kg": 0.0, "note": "Two shells swing out from the hull"},
	"airstair": {"kind": "hinge_out", "range": 115.0, "seconds": 6.0, "kw": 1.5, "load_kg": 400.0, "note": "A stair folds down to the ground"},
	"side_hold_door": {"kind": "hinge_up", "range": 100.0, "seconds": 7.0, "kw": 3.0, "load_kg": 0.0, "note": "Hinged at the top, it lifts clear of the opening"},
	"roof_hatch": {"kind": "hinge_up", "range": 110.0, "seconds": 4.0, "kw": 1.0, "load_kg": 0.0, "note": "The lid lifts on its back hinge"},
	"belly_hatch": {"kind": "hinge_up", "range": 100.0, "seconds": 4.0, "kw": 1.0, "load_kg": 0.0, "note": "The lid swings clear on its hinge"},
	"undercarriage_doors": {"kind": "hinge_up", "range": 90.0, "seconds": 2.0, "kw": 1.0, "load_kg": 0.0, "note": "The gear doors swing open ahead of the legs"},
	"solar_panel": {"kind": "hinge_up", "range": 90.0, "seconds": 12.0, "kw": 0.5, "load_kg": 0.0, "note": "The array folds out flat"},
	"folding_solar_array": {"kind": "hinge_up", "range": 90.0, "seconds": 15.0, "kw": 0.5, "load_kg": 0.0, "note": "The array folds out flat"},
	"folding_radiator": {"kind": "hinge_up", "range": 90.0, "seconds": 12.0, "kw": 0.5, "load_kg": 0.0, "note": "The radiator folds out flat"},
	"airlock_door": {"kind": "slide_side", "range": 0.0, "seconds": 3.0, "kw": 1.0, "load_kg": 0.0, "note": "The leaf slides aside"},
	"blast_door": {"kind": "slide_side", "range": 0.0, "seconds": 5.0, "kw": 3.0, "load_kg": 0.0, "note": "The armoured leaf slides aside"},
	"docking_port": {"kind": "slide_out", "range": 0.6, "seconds": 6.0, "kw": 2.0, "load_kg": 0.0, "note": "The collar runs out to meet the other ship"},
	"docking_clamp": {"kind": "slide_out", "range": 0.5, "seconds": 4.0, "kw": 3.0, "load_kg": 30000.0, "note": "The clamps run out and close"},
	"gangway_tube": {"kind": "slide_out", "range": 2.5, "seconds": 12.0, "kw": 2.0, "load_kg": 600.0, "note": "The tube telescopes out"},
	"hydraulic_ram": {"kind": "slide_out", "range": 0.8, "seconds": 3.0, "kw": 4.0, "load_kg": 20000.0, "note": "The ram pushes out"},
	"lift_platform": {"kind": "slide_up", "range": 0.0, "seconds": 6.0, "kw": 5.0, "load_kg": 1500.0, "note": "The platform rises"},
	"pallet_lifter": {"kind": "slide_up", "range": 0.0, "seconds": 4.0, "kw": 2.0, "load_kg": 1000.0, "note": "The forks rise"},
	"tow_winch": {"kind": "slide_out", "range": 0.4, "seconds": 5.0, "kw": 8.0, "load_kg": 20000.0, "note": "The drum pays out and hauls in"},
	"crane_hoist": {"kind": "spin", "range": 180.0, "reach": 0.0, "seconds": 10.0, "kw": 6.0, "load_kg": 2000.0, "note": "The boom slews round"},
	"crane_boom": {"kind": "spin", "range": 180.0, "reach": 0.0, "seconds": 12.0, "kw": 8.0, "load_kg": 5000.0, "note": "The boom slews round"},
	"turret": {"kind": "spin", "range": 180.0, "reach": 0.0, "seconds": 4.0, "kw": 2.0, "load_kg": 0.0, "note": "The turret traverses"},
	"twin_turret": {"kind": "spin", "range": 180.0, "reach": 0.0, "seconds": 5.0, "kw": 3.0, "load_kg": 0.0, "note": "The turret traverses"},
	"naval_turret": {"kind": "spin", "range": 180.0, "reach": 0.0, "seconds": 8.0, "kw": 6.0, "load_kg": 0.0, "note": "The turret traverses"},
	"gatling_gun": {"kind": "spin", "range": 180.0, "reach": 0.0, "seconds": 2.0, "kw": 1.0, "load_kg": 0.0, "note": "The gun traverses"},
	"point_defence": {"kind": "spin", "range": 180.0, "reach": 0.0, "seconds": 1.5, "kw": 1.0, "load_kg": 0.0, "note": "The mount traverses"},
	"railgun": {"kind": "spin", "range": 180.0, "reach": 0.0, "seconds": 6.0, "kw": 4.0, "load_kg": 0.0, "note": "The rail traverses"},
	"antenna": {"kind": "spin", "range": 180.0, "reach": 0.0, "seconds": 8.0, "kw": 0.3, "load_kg": 0.0, "note": "The dish turns"},
	"antenna_mast": {"kind": "slide_up", "range": 3.0, "seconds": 10.0, "kw": 0.5, "load_kg": 0.0, "note": "The mast telescopes up"},
	"radar_array": {"kind": "spin", "range": 180.0, "reach": 0.0, "seconds": 4.0, "kw": 0.5, "load_kg": 0.0, "note": "The array turns"},
	"landing_gear": {"kind": "leg", "range": 0.0, "seconds": 8.0, "kw": 2.0, "load_kg": 60000.0, "note": "The leg swings down and its oleo runs out"},
	"undercarriage_leg": {"kind": "leg", "range": 0.0, "seconds": 8.0, "kw": 2.0, "load_kg": 80000.0, "note": "The leg swings down and its oleo runs out"},
	"landing_skid": {"kind": "leg", "range": 0.0, "seconds": 5.0, "kw": 1.0, "load_kg": 50000.0, "note": "The skid drops"},
	"landing_foot_pad": {"kind": "leg", "range": 0.0, "seconds": 6.0, "kw": 1.5, "load_kg": 40000.0, "note": "The foot drops"},
	"stabiliser_jack": {"kind": "leg", "range": 0.0, "seconds": 5.0, "kw": 1.5, "load_kg": 25000.0, "note": "The jack runs down"},
	"conveyor": {"kind": "belt", "range": 0.5, "seconds": 0.0, "kw": 1.5, "load_kg": 500.0, "note": "The belt runs"},
}

## How each kind of door in the record moves (DesignCatalog.DOOR_KINDS styles).
const DOOR_SECONDS := {"split": 2.0, "slide": 2.5, "swing": 2.0, "roll": 5.0}
const DOOR_KW := {"split": 0.5, "slide": 0.5, "swing": 0.0, "roll": 1.5}
## How each door style is described.
const DOOR_NOTES := {"split": "Two leaves slide apart into the wall", "slide": "The leaf slides aside into the wall",
		"swing": "The leaf swings open on its hinges", "roll": "The shutter rolls up into its drum"}

const KIND_NAMES := {"hinge_out": "Hinge out", "hinge_up": "Hinge up", "slide_side": "Slide aside",
		"slide_out": "Slide out", "slide_up": "Slide up", "spin": "Turn", "leg": "Leg", "belt": "Belt"}


## The spec of a catalogue part (a variant's base id is used), with the catalogue's own
## figures over this table's and loads and power scaled with its size; {} if it doesn't move.
static func spec(pt: DesignPartType) -> Dictionary:
	if pt == null:
		return {}
	var base_id := pt.base_id if pt.base_id != "" else pt.id
	var s: Dictionary = SPECS.get(base_id, {}).duplicate()
	# The landing gear's sizes (small, large, XL) move as it does.
	if s.is_empty() and base_id.begins_with("landing_gear"):
		s = SPECS["landing_gear"].duplicate()
	# A part this table doesn't know moves as the catalogue says (its move_kind and move_range;
	# a "slide" is read from its name, and a turn's range is its whole travel).
	var kind_v: Variant = pt.get("move_kind")
	if s.is_empty() and kind_v is String and str(kind_v) != "":
		var kind := str(kind_v)
		var r: Variant = pt.get("move_range")
		var rng := float(r) if r != null else 0.0
		if kind == "slide":
			kind = "slide_side" if base_id.contains("door") else ("slide_up" if base_id.contains("lift") or base_id.contains("mast") else "slide_out")
		elif kind == "spin":
			rng *= 0.5
		s = {"kind": kind, "range": rng, "seconds": 0.0, "kw": 0.0, "load_kg": 0.0, "note": ""}
	if s.is_empty() or str(s.get("kind", "")) == "":
		return {}
	var k := maxf(pt.model_scale, 0.01)
	s["load_kg"] = float(s.get("load_kg", 0.0)) * k * k
	s["kw"] = float(s.get("kw", 0.0)) * k * k
	s["seconds"] = float(s.get("seconds", 0.0)) * sqrt(k)
	s["open"] = _default_open(str(s.kind), pt.size)
	# The catalogue's figures when it has them.
	var v: Variant = pt.get("move_s")
	if v != null and float(v) > 0.0:
		s["seconds"] = float(v)
	v = pt.get("move_kw")
	if v != null and float(v) > 0.0:
		s["kw"] = float(v)
	v = pt.get("load_kg")
	if v != null and float(v) > 0.0:
		s["load_kg"] = float(v)
	v = pt.get("open_size")
	if v is Vector2 and (v as Vector2).length() > 0.0:
		s["open"] = v
	v = pt.get("clearance")
	if v != null and float(v) > 0.0:
		s["clearance"] = float(v)
	return s


## A door's spec from its kind (DesignCatalog.DOOR_KINDS), {} for an open doorway.
static func door_spec(door: Dictionary) -> Dictionary:
	var k := DesignCatalog.door_kind(door)
	if not bool(k.get("leaves", true)):
		return {}
	var style := str(k.get("style", "split"))
	var w := DesignCatalog.door_w(door)
	var secs := float(k.get("move_s", DOOR_SECONDS.get(style, 2.0)))
	var kw := float(k.get("move_kw", DOOR_KW.get(style, 0.5)))
	return {"kind": "door_" + style, "style": style, "range": w, "seconds": secs * sqrt(w / float(k.w)),
			"kw": kw * w / float(k.w), "load_kg": 0.0, "open": Vector2(w - 0.16, DesignCatalog.door_h(door) - 0.1),
			"note": str(DOOR_NOTES.get(style, "")), "airtight": bool(k.get("airtight", false))}


static func _default_open(kind: String, size: Vector3) -> Vector2:
	match kind:
		"hinge_out":
			return Vector2(size.x, size.y)
		"hinge_up":
			return Vector2(size.x, size.z)
		"slide_side":
			return Vector2(size.x * 0.85, size.y * 0.9)
	return Vector2.ZERO


## True when the part moves at all.
static func moves(pt: DesignPartType) -> bool:
	return not spec(pt).is_empty()
