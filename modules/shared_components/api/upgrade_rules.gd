class_name UpgradeRules
extends RefCounted
## BSX's upgrade rules (Component Upgrades, stage U1), read from
## data/upgrades/upgrade_rules.json: the unit families BSX builds at tiers (the attractor
## coil at Mk I to III), what each tier does for the ship's figures, the add-ons that go
## inside a unit (quantum core, field emitter array, control board), which mount point each
## takes, and how many a unit holds. Static: read once, never synced (both peers carry the
## same file). Void Salvage is not changed by any of this: a unit leaves BSX as the module id
## the ship's save already names (`unit_id`) with its figures in `unit_stats`.

const RULES_PATH := "res://modules/shared_components/data/upgrades/upgrade_rules.json"
## The figures a family may change, in Void Salvage's BaseShip export names.
const FIGURES: PackedStringArray = ["attract_max_mass", "attract_reach", "attract_speed", "attract_accel"]
## What a mount point's trade means for the joint that fits its add-on.
const TRADE_JOINTS := {"bolt": ConnectionData.Kind.BOLT, "weld": ConnectionData.Kind.WELD,
		"rivet": ConnectionData.Kind.RIVET, "wire": ConnectionData.Kind.CONNECTOR}

static var _table: Dictionary = {}


## The whole file (cached).
static func rules() -> Dictionary:
	if _table.is_empty():
		var text := FileAccess.get_file_as_string(RULES_PATH)
		var parsed: Variant = JSON.parse_string(text)
		_table = parsed if parsed is Dictionary else {"families": {}, "addons": {}}
	return _table


## Reads the file again (tests and tools). (Not `reload`: that is Script's own.)
static func reread() -> Dictionary:
	_table = {}
	return rules()


## The tiers an add-on kind comes in, as ints (JSON numbers read as floats).
static func addon_tiers(kind: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for t: Variant in addon(kind).get("tiers", []):
		out.append(int(t))
	return out


static func family_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in rules().get("families", {}):
		out.append(id)
	out.sort()
	return out


static func family(id: String) -> Dictionary:
	return rules().get("families", {}).get(id, {})


## The tiers a family is built at, lowest first: [{tier, unit, display_name, size, ...}].
static func tiers(family_id: String) -> Array:
	return family(family_id).get("tiers", [])


static func tier_count(family_id: String) -> int:
	return tiers(family_id).size()


## The module id a family's tier leaves BSX as ("attractor_coil_2"), or "".
static func unit_id(family_id: String, tier: int) -> String:
	for t: Dictionary in tiers(family_id):
		if int(t.get("tier", 0)) == tier:
			return str(t.get("unit", ""))
	return ""


## The family a unit id belongs to ("attractor_coil_2" -> "attractor_coil"), or "".
static func family_of_unit(unit: String) -> String:
	for id: String in rules().get("families", {}):
		if tier_of_unit(id, unit) > 0:
			return id
	return ""


## A unit id's tier in its family, or 0.
static func tier_of_unit(family_id: String, unit: String) -> int:
	for t: Dictionary in tiers(family_id):
		if str(t.get("unit", "")) == unit:
			return int(t.get("tier", 0))
	return 0


## A tier's housing size, metres (x across the slot, y up, z fore to aft).
static func unit_size(family_id: String, tier: int) -> Vector3:
	for t: Dictionary in tiers(family_id):
		if int(t.get("tier", 0)) == tier:
			return _vec3(t.get("size", [1, 1, 1]))
	return Vector3.ZERO


## The slot box a family's units must fit, metres (Void Salvage's slot size).
static func slot_box(family_id: String) -> Vector3:
	return _vec3(family(family_id).get("slot_box", [0, 0, 0]))


## How many add-ons one of the family's units holds.
static func max_addons(family_id: String) -> int:
	return int(family(family_id).get("max_addons", 0))


## A family's internal mount points: [{id, display_name, trade, accepts}].
static func mounts(family_id: String) -> Array:
	return family(family_id).get("mounts", [])


static func mount(family_id: String, mount_id: String) -> Dictionary:
	for m: Dictionary in mounts(family_id):
		if str(m.get("id", "")) == mount_id:
			return m
	return {}


static func addon_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in rules().get("addons", {}):
		out.append(id)
	out.sort()
	return out


## An add-on kind ("quantum_core"): {display_name, blurb, fits, mount, tiers, raises}.
static func addon(kind: String) -> Dictionary:
	return rules().get("addons", {}).get(kind, {})


## An add-on part id is its kind and tier: "quantum_core_2" -> {kind: "quantum_core", tier: 2}
## ("control_board" alone is tier 1). {} for an id the rules don't know.
static func parse_addon(addon_id: String) -> Dictionary:
	var kind := addon_id
	var tier := 1
	var n := addon_id.rfind("_")
	if n > 0 and addon_id.substr(n + 1).is_valid_int() and not addon(addon_id).has("mount"):
		kind = addon_id.substr(0, n)
		tier = int(addon_id.substr(n + 1))
	if addon(kind).is_empty() or not addon_tiers(kind).has(tier):
		return {}
	return {"kind": kind, "tier": tier}


## "quantum_core" at tier 2 -> "quantum_core_2"; a one-tier add-on keeps its bare kind.
static func addon_id(kind: String, tier: int) -> String:
	if addon(kind).is_empty() or not addon_tiers(kind).has(tier):
		return ""
	return kind if addon_tiers(kind).size() == 1 else "%s_%d" % [kind, tier]


## Every add-on part id a family takes, by kind then tier.
static func addons_for(family_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for kind in addon_ids():
		var a := addon(kind)
		if not (a.get("fits", []) as Array).has(family_id):
			continue
		for t in addon_tiers(kind):
			out.append(addon_id(kind, t))
	return out


## Why `addon_id` can't go into `unit` with `fitted` (add-on ids) already in it: "" when it
## can. The rules: a known add-on of a kind the family takes; the unit's tier at least the
## add-on's; a mount point free for it; room under `max_addons`.
static func refusal(unit: String, addon_part: String, fitted: PackedStringArray = PackedStringArray()) -> String:
	var fam := family_of_unit(unit)
	if fam == "":
		return "no such unit"
	var parsed := parse_addon(addon_part)
	if parsed.is_empty():
		return "no such add-on"
	var a := addon(parsed["kind"])
	if not (a.get("fits", []) as Array).has(fam):
		return "%s does not fit a %s" % [a.get("display_name", parsed["kind"]), str(family(fam).get("display_name", fam)).to_lower()]
	if int(parsed["tier"]) > tier_of_unit(fam, unit):
		return "needs a Mk %s unit or better" % _roman(int(parsed["tier"]))
	if fitted.size() >= max_addons(fam):
		return "the unit is full (%d add-ons)" % max_addons(fam)
	for f in fitted:
		var other := parse_addon(f)
		if other.is_empty():
			continue
		if str(addon(other["kind"]).get("mount", "")) == str(a.get("mount", "")):
			return "the %s already holds %s" % [str(mount(fam, a.get("mount", "")).get("display_name", a.get("mount", ""))).to_lower(), str(addon(other["kind"]).get("display_name", f)).to_lower()]
	return ""


static func can_fit(unit: String, addon_part: String, fitted: PackedStringArray = PackedStringArray()) -> bool:
	return refusal(unit, addon_part, fitted) == ""


## The mount point id an add-on part goes on in its family ("core_bay"), or "".
static func mount_for(addon_part: String) -> String:
	var parsed := parse_addon(addon_part)
	return "" if parsed.is_empty() else str(addon(parsed["kind"]).get("mount", ""))


## The figures a unit gives a ship (its tier's over the base, plus each fitted add-on's
## amounts at its tier), in Void Salvage's names: Void Salvage's `unit_stats` for the module.
static func stats(unit: String, fitted: PackedStringArray = PackedStringArray()) -> Dictionary:
	var fam := family_of_unit(unit)
	if fam == "":
		return {}
	var out: Dictionary = {}
	var f := family(fam)
	for k: String in f.get("base", {}):
		out[k] = float(f["base"][k])
	for t: Dictionary in tiers(fam):
		if str(t.get("unit", "")) == unit:
			for k: String in FIGURES:
				if t.has(k):
					out[k] = float(t[k])
	for part in fitted:
		var parsed := parse_addon(part)
		if parsed.is_empty():
			continue
		var raises: Dictionary = addon(parsed["kind"]).get("raises", {})
		for k: String in raises:
			var amounts: Array = raises[k]
			var i := clampi(int(parsed["tier"]) - 1, 0, amounts.size() - 1)
			out[k] = float(out.get(k, 0.0)) + float(amounts[i])
	return out


## The base figures (a stock ship), for the test rig's "before" column.
static func base_stats(family_id: String) -> Dictionary:
	var out: Dictionary = {}
	for k: String in family(family_id).get("base", {}):
		out[k] = float(family(family_id)["base"][k])
	return out


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


static func _vec3(v: Variant) -> Vector3:
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO
