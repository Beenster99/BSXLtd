class_name UpgradePlate
extends Resource
## The upgrade plate: what a unit's rig test proved. Quality writes one for every field
## sweep (QualityBus.run_field_sweep); a passing plate carries a serial and is the unit's
## certificate (serial, tier, grade, tested numbers), a failing one carries the snag list
## that sends the unit back to fitting. Other modules read these: Ship and Bay shows the
## plate on the unit (QualityBus.make_plate_node), Business prices from tested vs rated,
## and the export (U3) writes `tested` as the slot's unit_stats.

const VERSION := 1

@export var version := VERSION
## "BSX-U-0001" on a pass; "" when the unit failed its test.
@export var serial := ""
## The unit that went on the rig ("attractor_coil_1") and its family ("attractor_coil").
@export var unit_id := ""
@export var family := ""
## The tier the add-ons aimed for, 1 to 3.
@export var tier := 1
## The rig's test: "field_sweep" for the emitter frame (U1).
@export var test := "field_sweep"
## Figures before, what the tier is rated for, and what the test measured, e.g.
## {"attract_reach": 18.0, "attract_max_mass": 6000.0}. tested is what the crew gets.
@export var base: Dictionary = {}
@export var rated: Dictionary = {}
@export var tested: Dictionary = {}
## The add-ons fitted: [{"part": "quantum_core", "tier": 2, "mount": "coil_bay"}].
@export var addons: Array[Dictionary] = []
## The unit's joints as graded: [{"joint_id", "trade", "score", "grade", "faults"}].
@export var joints: Array[Dictionary] = []
## Mean joint score 0..100, as 0..1 for Void Salvage's quality scale, and the letter.
@export var average := 0.0
@export var quality := 0.0
@export var grade := ""
## Share of the tier's rated gain the unit reached (1.0 = exactly rated; above beats it).
@export var efficiency := 0.0
@export var passed := false
## What stopped a pass: [{"code": "trip" | "overheat" | "short" | "nothing_fitted", "text"}].
@export var snags: Array[Dictionary] = []
@export var job_id := ""
## The rig it was tested on ("" when the test didn't come from a rig).
@export var rig_id := ""
@export var time := 0


## True when the test beat the tier's rated figures (Business pays a bonus).
func beats_rating() -> bool:
	return passed and efficiency > 1.0


func to_dict() -> Dictionary:
	return {
		"version": version, "serial": serial, "unit_id": unit_id, "family": family, "tier": tier,
		"test": test, "base": base, "rated": rated, "tested": tested, "addons": addons,
		"joints": joints, "average": average, "quality": quality, "grade": grade,
		"efficiency": efficiency, "passed": passed, "snags": snags, "job_id": job_id, "rig_id": rig_id, "time": time,
	}


static func from_dict(d: Dictionary) -> UpgradePlate:
	var p := UpgradePlate.new()
	p.serial = str(d.get("serial", ""))
	p.unit_id = str(d.get("unit_id", ""))
	p.family = str(d.get("family", ""))
	p.tier = int(d.get("tier", 1))
	p.test = str(d.get("test", "field_sweep"))
	p.base = d.get("base", {})
	p.rated = d.get("rated", {})
	p.tested = d.get("tested", {})
	p.addons.assign(d.get("addons", []))
	p.joints.assign(d.get("joints", []))
	p.average = float(d.get("average", 0.0))
	p.quality = float(d.get("quality", 0.0))
	p.grade = str(d.get("grade", ""))
	p.efficiency = float(d.get("efficiency", 0.0))
	p.passed = bool(d.get("passed", false))
	p.snags.assign(d.get("snags", []))
	p.job_id = str(d.get("job_id", ""))
	p.rig_id = str(d.get("rig_id", ""))
	p.time = int(d.get("time", 0))
	return p
