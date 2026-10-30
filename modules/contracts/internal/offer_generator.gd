extends RefCounted
## Writes the offers the clients post (plan stage S4): a work order Dictionary per client,
## cycle and slot, seeded so every machine and every load writes the same one. The bus
## imports what this returns through its reader, so a generated offer is checked like a
## file. Until stage S3 lands wrecks, every subject is a part on a trolley (size "small").

## Labour bands by size when no pricer is wired in (Business's own, mirrored; Business
## sets ContractsBus.set_pricer so its rules win). Credits.
const DEFAULT_BANDS: Dictionary = {"small": Vector2i(2000, 12000), "medium": Vector2i(10000, 60000), "large": Vector2i(80000, 400000)}
const KIND_FACTOR: Dictionary = {"fit": 1.0, "break": 1.0, "scrap": 0.8, "refurbish": 1.25, "dispose": 0.9}
## An offer stays on the board this many cycles.
const OFFER_LIFE := 5
## Cycles until the job is due, by tier.
const DUE_IN: PackedInt32Array = [0, 8, 12, 16]

## Callable(kind: String, size: String, t: float) -> int, or unset for DEFAULT_BANDS.
var pricer: Callable
## Callable(material: String, kg: float) -> int: what a client pays BSX for cutting and
## baling kilograms of a material (scrap jobs pay by the tonne, plan stage S5); unset,
## SCRAP_PER_TONNE scaled by the material's price applies. Business tunes it.
var scrap_pricer: Callable
## Callable(id) -> bool: is this a real part (on the yard's parts list)? Unset, the tables
## above are trusted; set, no offer ever asks for a part the callable refuses.
var part_exists: Callable
## The processing fee for a tonne of mild steel, CR (dearer materials scale by their price).
## Below the broker's own price for the metal, so a client who keeps the metal pays BSX less
## than BSX would make keeping it.
const SCRAP_PER_TONNE := 400.0
## Whether BSX's own clients send whole ships and wrecks (contracts.wrecks, stage S3).
var wrecks := false
## Whether the Reserve and the insurer post large jobs worked in stages (contracts.stages, S6).
var stages := false

## Large jobs (S6): who posts them, at Preferred standing, and the hulk they send (the
## Sentinel first; beenster, 30 Oct 2026).
const LARGE_CLIENTS: PackedStringArray = ["tallow_reserve", "carrow_underwriters"]
const LARGE_DESIGNS: PackedStringArray = ["vsw:sentinel"]
## Damage a large hulk arrives with: enough to be a wreck, not enough to strip its weapons.
const LARGE_EVENTS: PackedStringArray = ["weathered:2", "collision:2", "breach:2"]
## The decommissioning plan, in the order the Reserve's rules set: weapons made safe
## first, the reactor out before anything else comes off, then the engines, then the hull.
## Each stage names the fittings it takes and the share of the price it pays.
const WEAPON_PARTS: PackedStringArray = ["AssaultCannon", "PDC", "RailMuzzle", "Turret", "NavalTurret", "MissileLauncher", "RailBarrel", "Cannon", "MissileRack"]
const REACTOR_PARTS: PackedStringArray = ["Reactor"]
const ENGINE_PARTS: PackedStringArray = ["MainEngine", "Thruster", "IonThruster", "TurbineEngine", "HydrogenEngine", "Engine"]
const STAGE_PLAN: Array = [
	{"id": "weapons", "name": "Weapons made safe", "parts": WEAPON_PARTS, "disposition": "destroyed", "min_condition": 0.0, "share": 0.15,
		"rule": "Every weapon destroyed and certified before any other work starts.", "checks": []},
	{"id": "reactor", "name": "Reactor out", "parts": REACTOR_PARTS, "disposition": "returned", "min_condition": 0.3, "share": 0.25,
		"rule": "The reactor comes out whole and goes back before the hull is opened.", "checks": ["weapons_destroyed"]},
	{"id": "engines", "name": "Engines off", "parts": ENGINE_PARTS, "disposition": "returned", "min_condition": 0.4, "share": 0.25, "rule": "",
		"checks": ["weapons_destroyed", "reactor_out"]},
	{"id": "hull", "name": "Hull cut to frames", "material_share": 0.35, "share": 0.2, "rule": "Sections onto the dolly, frames to the cutting bay.",
		"checks": ["weapons_destroyed", "reactor_out"]},
	{"id": "bales", "name": "Bales out", "material_share": 0.55, "share": 0.15, "rule": "Pressed and weighed; the client's truck collects.",
		"checks": ["weapons_destroyed", "reactor_out"]},
]

## A whole ship or wreck is a medium job up to this mass, large above it (kg).
const MEDIUM_MAX_KG := 400_000.0
## What the events did to a ship, by job kind: a refurbish takes a tired ship, the rest a wreck.
const WRECK_EVENTS: Dictionary = {
	"refurbish": ["weathered:2", "weathered:3", "collision:2"],
	"break": ["collision:3,stripped:1", "fire:2,stripped:1", "breach:2"],
	"scrap": ["fire:4,collision:3", "breach:4,stripped:2", "collision:5"],
	"dispose": ["fire:5,breach:3", "fire:4,stripped:3"],
}
## Fittings a break job asks back from a wreck, by part name in the ship file.
## Imported Void Salvage hulls carry the snake_case ones; BSX's generated ships also carry
## the CamelCase machinery and trade gear Shared Components fits them with.
## Fittings a break job may ask for out of a wreck: every one is on Business's parts list
## (the market catalogue), so the yard can always stock, value and sell what it strips.
const WANTED_FITTINGS: PackedStringArray = ["IonThruster", "TurbineEngine", "HydrogenEngine", "Generator",
		"BatteryRack", "LandingClamp", "Searchlight", "Antenna", "SolarPanel", "Container", "Turret"]
## Fittings whose presence on the subject is a hazard for the crew.
const HAZARD_FITTINGS: Dictionary = {"reactor_cabinet": "power", "breaker_panel": "power", "bowsers": "fuel",
		"Generator": "power", "jump_tank": "fuel", "RoofTank": "fuel", "Turret": "weapons"}


## One offer for a client at a tier (1 to 3), or {} if the client posts nothing. slot
## tells offers from the same client and cycle apart.
func make(client_id: String, cycle: int, slot: int, tier: int) -> Dictionary:
	var client: Dictionary = ContractClients.TABLE.get(client_id, {})
	if client.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d/%d" % [client_id, cycle, slot])
	var kinds: Array = client.get("kinds", [])
	var parts: Array = client.get("parts", [])
	if kinds.is_empty() or parts.is_empty():
		return {}
	var kind := String(kinds[rng.randi_range(0, kinds.size() - 1)])
	# The Reserve and the insurer, at Preferred standing, post large hulks worked in stages.
	if stages and wrecks and client_id in LARGE_CLIENTS and tier >= 3 and rng.randf() < 0.5:
		var large := _large_job(client_id, client, cycle, slot, tier, rng)
		if not large.is_empty():
			return large
	# BSX's own clients at tier two and up send whole ships and wrecks BSX makes itself.
	if wrecks and String(client.get("game", "")) == "bsx_generated" and tier >= 2 and rng.randf() < 0.6:
		return _whole_ship(client_id, client, cycle, slot, tier, kind, rng)
	var real: Array = parts.filter(func(id: String) -> bool: return listed(id))
	if real.is_empty():
		return {}
	var part_id := String(real[rng.randi_range(0, real.size() - 1)])
	var part: Dictionary = ContractClients.PARTS.get(part_id, {})
	var yields: Array = (part.get("yields", []) as Array).filter(func(id: String) -> bool: return listed(id))
	if kind == WorkOrder.BREAK and yields.is_empty():
		kind = WorkOrder.SCRAP
	var mass_range: Array = part.get("mass", [1000, 3000])
	# Higher tiers send the bigger, better pieces and pay further up the band.
	var t := clampf((float(tier) - 1.0) / 2.0 + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
	var mass := lerpf(float(mass_range[0]), float(mass_range[1]), t)
	mass = roundf(mass / 100.0) * 100.0
	var condition := snappedf(rng.randf_range(0.15, 0.45) if kind in [WorkOrder.SCRAP, WorkOrder.DISPOSE] else rng.randf_range(0.35, 0.7), 0.05)
	var material := String(part.get("material", "steel"))
	var subject := {"type": "part", "component": {"id": part_id, "material": material}, "condition": condition, "mass_kg": mass}

	var wants: Array = []
	match kind:
		WorkOrder.BREAK:
			var n := mini(yields.size(), 1 + rng.randi_range(0, tier))
			for i in n:
				var y := String(yields[rng.randi_range(0, yields.size() - 1)])
				yields.erase(y)
				wants.append({"what": "part", "component": {"id": y}, "qty": 1 + rng.randi_range(0, 1),
						"min_condition": snappedf(rng.randf_range(0.4, 0.6) + 0.1 * (tier - 1), 0.05)})
		WorkOrder.SCRAP:
			var share := rng.randf_range(0.55, 0.75)
			wants.append({"what": "material", "material": material, "kg": roundf(mass * share / 100.0) * 100.0})
		WorkOrder.REFURBISH:
			wants.append({"what": "condition", "min_condition": snappedf(rng.randf_range(0.8, 0.9) + 0.03 * (tier - 1), 0.01)})
		WorkOrder.DISPOSE:
			wants.append({"what": "gone"})

	var voice: Array = (client.get("voice", {}) as Dictionary).get(kind, ["%s", ""])
	var name := part_id.to_snake_case().replace("_", " ")
	var id := "%s.g%d_%d" % [client_id, cycle, slot]
	return {
		"schema": WorkOrder.SCHEMA, "schema_version": WorkOrder.SCHEMA_VERSION,
		"contract_id": id, "issued_at": "cycle %d" % cycle, "kind": kind,
		"client": {"company": client_id, "display_name": String(client.get("display_name", client_id)), "game": String(client.get("game", "bsx_generated"))},
		"subject": subject, "wants": wants, "keeps": String(client.get("keeps", "bsx")),
		"hazards": (part.get("hazards", []) as Array).duplicate(),
		"manifest": [], "spec_sheet": {"library": true, "overrides": []},
		"notes": [{"text": String(voice[1])}],
		"title": String(voice[0]) % name,
		"offer": {"posted": cycle, "expires": cycle + OFFER_LIFE, "tier": tier},
		"commercial": commercial(kind, "small", t, wants, cycle + DUE_IN[clampi(tier, 1, 3)]),
	}


## True when id is a real part: on the parts list when one is wired, else in our own tables.
func listed(id: String) -> bool:
	return not part_exists.is_valid() or bool(part_exists.call(id))


## An offer's terms: labour by kind and size, plus, for a scrap job, the processing fee by
## the tonne for every kilogram the client wants out (per_tonne, tonnes and the whole fee
## say so on the order). 30% deposit, due on due_day.
func commercial(kind: String, size: String, t: float, wants: Array, due_day: int) -> Dictionary:
	var out := {"price": price_for(kind, size, t), "currency": "cr", "deposit_pct": 30, "due_day": due_day}
	if kind == WorkOrder.SCRAP:
		var tonnes := 0.0
		var fee := 0
		for w: Variant in wants:
			if w is Dictionary and String(w.get("what", "")) == "material":
				var kg := float(w.get("kg", 0.0))
				tonnes += kg / 1000.0
				fee += scrap_fee(String(w.get("material", "steel")), kg)
		if tonnes > 0.0:
			out["tonnes"] = snappedf(tonnes, 0.1)
			out["per_tonne"] = int(roundf(float(fee) / tonnes))
			out["fee"] = fee
			out["price"] = int(out["price"]) + fee
	return out


## What a client pays BSX to cut and bale kg of a material, CR (the scrap_pricer's word, or
## SCRAP_PER_TONNE by the material's price, rounded to the ten).
func scrap_fee(material: String, kg: float) -> int:
	if kg <= 0.0:
		return 0
	if scrap_pricer.is_valid():
		return int(scrap_pricer.call(material, kg))
	var factor := float((Materials.TABLE.get(material, {}) as Dictionary).get("price", 1.0))
	return int(roundf(kg / 1000.0 * SCRAP_PER_TONNE * factor / 10.0) * 10.0)


## A whole-ship offer: a generated ship (refurbish) or wreck (break, scrap, dispose) from
## Shared Components' WreckMaker, seeded so every machine builds the same one. The wants
## come from what is really left on it.
func _whole_ship(client_id: String, client: Dictionary, cycle: int, slot: int, tier: int, kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var seed_value := int(hash("%s/%d/%d/ship" % [client_id, cycle, slot])) & 0x7FFFFFFF
	# The hull is one of Void Salvage's own wreck designs, built by its wreck pipeline (beenster,
	# 27 Oct): the tier picks the size (small or medium at tier two, medium or large above), the
	# seed the design and the damage. While none is packed, one of BSX's generated ships (S3b),
	# the client's trade picking the family.
	var hull_size := String((["S", "M"] if tier <= 2 else ["M", "L"])[rng.randi_range(0, 1)])
	var design := VsWreckLibrary.pick(rng, hull_size)
	if design == "":
		design = ShipGenerator.design_id(seed_value, hull_size, ShipGenerator.family_for(String(client.get("trade", ""))))
	var options: Array = WRECK_EVENTS.get(kind, WRECK_EVENTS["scrap"])
	var events := String(options[rng.randi_range(0, options.size() - 1)])
	var file := design_source(design)
	if file.is_empty():
		return {}
	var wreck := WreckMaker.make(file, seed_value, events)
	if wreck.is_empty():
		return {}
	var facts := ship_facts(wreck)
	var is_wreck := kind != WorkOrder.REFURBISH
	var condition := snappedf(float(facts.get("condition", 1.0)), 0.01)
	var mass := float(facts.get("mass_kg", 0.0))
	var holds: Array = facts.get("holds", [])
	var subject := {"type": "wreck" if is_wreck else "ship", "design": design, "seed": seed_value, "events": events,
			"name": String(wreck.get("ship", {}).get("name", "")), "condition": condition, "mass_kg": mass, "holds": holds,
			"parts_left": int(facts.get("parts_left", 0)), "parts_gone": int(facts.get("parts_gone", 0))}
	var wants: Array = []
	match kind:
		WorkOrder.BREAK:
			var pool: Array = []
			for name: String in holds:
				if name in WANTED_FITTINGS and listed(name) and not name in pool:
					pool.append(name)
			var n := mini(pool.size(), 1 + rng.randi_range(0, tier))
			for i in n:
				var name := String(pool[rng.randi_range(0, pool.size() - 1)])
				pool.erase(name)
				var have := holds.count(name)
				wants.append({"what": "part", "component": {"id": name}, "qty": 1 + rng.randi_range(0, mini(have, 2) - 1),
						"min_condition": snappedf(rng.randf_range(0.4, 0.6), 0.05)})
			if wants.is_empty():
				kind = WorkOrder.SCRAP
		WorkOrder.REFURBISH:
			wants.append({"what": "condition", "min_condition": snappedf(rng.randf_range(0.85, 0.92), 0.01)})
		WorkOrder.DISPOSE:
			wants.append({"what": "gone"})
	if kind == WorkOrder.SCRAP:
		var share := rng.randf_range(0.45, 0.6)
		wants.append({"what": "material", "material": String(facts.get("material", "steel")), "kg": roundf(mass * share / 1000.0) * 1000.0})
	var hazards: Array = []
	for name: String in holds:
		var h := String(HAZARD_FITTINGS.get(name, ""))
		if h != "" and not h in hazards:
			hazards.append(h)
	var size := "medium" if mass <= MEDIUM_MAX_KG else "large"
	var t := clampf((float(tier) - 2.0) / 1.0 * 0.5 + rng.randf_range(0.0, 0.3), 0.0, 1.0)
	var voice: Array = (client.get("voice", {}) as Dictionary).get(kind, ["%s", ""])
	var name := String(wreck.get("ship", {}).get("name", design)).to_lower() + (" wreck" if is_wreck else "")
	var id := "%s.g%d_%d" % [client_id, cycle, slot]
	return {
		"schema": WorkOrder.SCHEMA, "schema_version": WorkOrder.SCHEMA_VERSION,
		"contract_id": id, "issued_at": "cycle %d" % cycle, "kind": kind,
		"client": {"company": client_id, "display_name": String(client.get("display_name", client_id)), "game": String(client.get("game", "bsx_generated"))},
		"subject": subject, "wants": wants, "keeps": String(client.get("keeps", "bsx")), "hazards": hazards,
		"manifest": [], "spec_sheet": {"library": true, "overrides": []},
		"notes": [{"text": String(voice[1])}],
		"title": String(voice[0]) % name,
		"offer": {"posted": cycle, "expires": cycle + OFFER_LIFE, "tier": tier, "size": size},
		"commercial": commercial(kind, size, t, wants, cycle + DUE_IN[clampi(tier, 1, 3)] + (6 if size == "medium" else 14)),
	}


## A large job (S6): one of LARGE_DESIGNS, broken in the stages STAGE_PLAN sets, each stage
## with its own wants and pay. The order's wants are every stage's together, so the handover
## check and the pay follow the same lines. {} when the hulk cannot be built.
func _large_job(client_id: String, client: Dictionary, cycle: int, slot: int, tier: int, rng: RandomNumberGenerator) -> Dictionary:
	var seed_value := int(hash("%s/%d/%d/large" % [client_id, cycle, slot])) & 0x7FFFFFFF
	var design := String(LARGE_DESIGNS[rng.randi_range(0, LARGE_DESIGNS.size() - 1)])
	var events := String(LARGE_EVENTS[rng.randi_range(0, LARGE_EVENTS.size() - 1)])
	var file := design_source(design)
	if file.is_empty():
		return {}
	var wreck := WreckMaker.make(file, seed_value, events)
	if wreck.is_empty():
		return {}
	var facts := ship_facts(wreck)
	var mass := float(facts.get("mass_kg", 0.0))
	var holds: Array = facts.get("holds", [])
	var material := String(facts.get("material", "steel"))
	var t := clampf(0.5 + rng.randf_range(0.0, 0.4), 0.0, 1.0)
	var price := price_for(WorkOrder.BREAK, "large", t)
	var plan: Array = []
	var share_total := 0.0
	for spec: Dictionary in STAGE_PLAN:
		var wants: Array = []
		if spec.has("parts"):
			for name: String in spec["parts"]:
				var have := holds.count(name)
				if have > 0 and listed(name):
					wants.append({"what": "part", "component": {"id": name}, "qty": have, "min_condition": float(spec["min_condition"]),
							"disposition": String(spec["disposition"])})
		else:
			wants.append({"what": "material", "material": material, "kg": roundf(mass * float(spec["material_share"]) / 1000.0) * 1000.0})
		if wants.is_empty():
			continue
		plan.append({"id": String(spec["id"]), "name": String(spec["name"]), "wants": wants, "share": float(spec["share"]), "rule": String(spec["rule"]),
				"checks": Array(spec.get("checks", []))})
		share_total += float(spec["share"])
	if plan.size() < 2:
		return {}
	var all_wants: Array = []
	var paid := 0
	for i in plan.size():
		var st: Dictionary = plan[i]
		var pay := int(roundf(float(price) * float(st["share"]) / share_total / 100.0) * 100.0) if i < plan.size() - 1 else price - paid
		paid += pay
		st["pay"] = pay
		st.erase("share")
		all_wants.append_array(st["wants"])
	var hazards: Array = ["weapons", "power"]
	for name: String in holds:
		var h := String(HAZARD_FITTINGS.get(name, ""))
		if h != "" and not h in hazards:
			hazards.append(h)
	var subject := {"type": "wreck", "design": design, "seed": seed_value, "events": events,
			"name": String(wreck.get("ship", {}).get("name", "")), "condition": snappedf(float(facts.get("condition", 1.0)), 0.01),
			"mass_kg": mass, "holds": holds, "parts_left": int(facts.get("parts_left", 0)), "parts_gone": int(facts.get("parts_gone", 0))}
	var voice: Array = (client.get("voice", {}) as Dictionary).get("large", ["Decommission: %s", ""])
	var name := String(wreck.get("ship", {}).get("name", design)).to_lower() + " wreck"
	var id := "%s.g%d_%d" % [client_id, cycle, slot]
	return {
		"schema": WorkOrder.SCHEMA, "schema_version": WorkOrder.SCHEMA_VERSION,
		"contract_id": id, "issued_at": "cycle %d" % cycle, "kind": WorkOrder.BREAK,
		"client": {"company": client_id, "display_name": String(client.get("display_name", client_id)), "game": String(client.get("game", "bsx_generated"))},
		"subject": subject, "wants": all_wants, "stages": plan, "keeps": String(client.get("keeps", "bsx")), "hazards": hazards,
		"manifest": [], "spec_sheet": {"library": true, "overrides": []},
		"notes": [{"text": String(voice[1])}],
		"title": String(voice[0]) % name,
		"offer": {"posted": cycle, "expires": cycle + OFFER_LIFE, "tier": tier, "size": "large", "stages": plan.size()},
		"commercial": {"price": price, "currency": "cr", "deposit_pct": 30, "due_day": cycle + DUE_IN[clampi(tier, 1, 3)] + 21, "stage_payments": true},
	}


## Generating a ship takes up to a second or so, and a cycle's offers reuse the same design,
## so the clean files are kept by design id (the same id always gives the same ship).
static var _files: Dictionary = {}


static func design_source(design: String) -> Dictionary:
	if not _files.has(design):
		_files[design] = VsShipImport.design_source(design)
	return _files[design]


## What a generated ship or wreck file says about itself: the mass left on it, how many parts
## are left and gone, the fittings still attached (holds, by part name), its main material and
## a condition from the damage (1 for a clean ship).
static func ship_facts(file: Dictionary) -> Dictionary:
	var damage: Dictionary = file.get("damage", {})
	var dparts: Dictionary = damage.get("parts", {})
	var mass := 0.0
	var ship_mass := 0.0
	var left := 0
	var gone := 0
	var holds: Array = []
	var by_material := {}
	var wear := 0.0
	var worn := 0
	for p: Dictionary in file.get("parts", []):
		var m := float(p.get("mass", p.get("mass_kg", 0.0)))
		ship_mass += m
		var d: Dictionary = dparts.get(String(p.get("path", "")), {})
		var state := String(d.get("state", "attached"))
		if state != "attached":
			gone += 1
			continue
		left += 1
		mass += m
		var mat := String(p.get("material", "steel"))
		by_material[mat] = float(by_material.get(mat, 0.0)) + m
		if String(p.get("kind", "")) == "component":
			holds.append(String(p.get("name", "")))
		var c: Dictionary = d.get("condition", {})
		if not c.is_empty():
			wear += maxf(float(c.get("wear", 0.0)), float(c.get("scorch", 0.0)))
			worn += 1
	var main := "steel"
	for mat: String in by_material:
		if by_material[mat] > float(by_material.get(main, 0.0)):
			main = mat
	var kept := mass / ship_mass if ship_mass > 0.0 else 1.0
	var mean_wear := wear / worn if worn > 0 else 0.0
	var condition := clampf(kept * (1.0 - 0.6 * mean_wear), 0.05, 1.0)
	return {"mass_kg": roundf(mass), "ship_mass_kg": roundf(ship_mass), "parts_left": left, "parts_gone": gone,
			"holds": holds, "material": main, "condition": condition}


func price_for(kind: String, size: String, t: float) -> int:
	if pricer.is_valid():
		return int(pricer.call(kind, size, t))
	var band: Vector2i = DEFAULT_BANDS.get(size, DEFAULT_BANDS["small"])
	var base := lerpf(float(band.x), float(band.y), clampf(t, 0.0, 1.0)) * float(KIND_FACTOR.get(kind, 1.0))
	return int(roundf(base / 100.0) * 100.0)


## Whether a client posts this cycle (seeded).
static func posts(client_id: String, cycle: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d/post" % [client_id, cycle])
	return rng.randf() < float(ContractClients.TABLE.get(client_id, {}).get("post_chance", 0.0))
