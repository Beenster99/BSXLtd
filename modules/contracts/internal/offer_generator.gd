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
## Whether BSX's own clients send whole ships and wrecks (contracts.wrecks, stage S3).
var wrecks := false

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
const WANTED_FITTINGS: PackedStringArray = ["galley", "bunks", "console", "map_screen", "monitor", "control_panel",
		"breaker_panel", "reactor_cabinet", "bowsers", "hose_rack", "locker", "seat", "suit_stand"]
## Fittings whose presence on the subject is a hazard for the crew.
const HAZARD_FITTINGS: Dictionary = {"reactor_cabinet": "power", "breaker_panel": "power", "bowsers": "fuel"}


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
	# BSX's own clients at tier two and up send whole ships and wrecks BSX makes itself.
	if wrecks and String(client.get("game", "")) == "bsx_generated" and tier >= 2 and rng.randf() < 0.6:
		return _whole_ship(client_id, client, cycle, slot, tier, kind, rng)
	var part_id := String(parts[rng.randi_range(0, parts.size() - 1)])
	var part: Dictionary = ContractClients.PARTS.get(part_id, {})
	if kind == WorkOrder.BREAK and (part.get("yields", []) as Array).is_empty():
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
			var yields: Array = (part.get("yields", []) as Array).duplicate()
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
	var price := price_for(kind, "small", t)
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
		"commercial": {"price": price, "currency": "cr", "deposit_pct": 30, "due_day": cycle + DUE_IN[clampi(tier, 1, 3)]},
	}


## A whole-ship offer: a generated ship (refurbish) or wreck (break, scrap, dispose) from
## Shared Components' WreckMaker, seeded so every machine builds the same one. The wants
## come from what is really left on it.
func _whole_ship(client_id: String, client: Dictionary, cycle: int, slot: int, tier: int, kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var designs := VsShipImport.designs()
	if designs.is_empty():
		return {}
	var design := designs[rng.randi_range(0, designs.size() - 1)]
	var options: Array = WRECK_EVENTS.get(kind, WRECK_EVENTS["scrap"])
	var events := String(options[rng.randi_range(0, options.size() - 1)])
	var seed_value := int(hash("%s/%d/%d/ship" % [client_id, cycle, slot])) & 0x7FFFFFFF
	var wreck := WreckMaker.for_design(design, seed_value, events)
	if wreck.is_empty():
		return {}
	var facts := ship_facts(wreck)
	var is_wreck := kind != WorkOrder.REFURBISH
	var condition := snappedf(float(facts.get("condition", 1.0)), 0.01)
	var mass := float(facts.get("mass_kg", 0.0))
	var holds: Array = facts.get("holds", [])
	var subject := {"type": "wreck" if is_wreck else "ship", "design": design, "seed": seed_value, "events": events,
			"condition": condition, "mass_kg": mass, "holds": holds,
			"parts_left": int(facts.get("parts_left", 0)), "parts_gone": int(facts.get("parts_gone", 0))}
	var wants: Array = []
	match kind:
		WorkOrder.BREAK:
			var pool: Array = []
			for name: String in holds:
				if name in WANTED_FITTINGS and not name in pool:
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
		"commercial": {"price": price_for(kind, size, t), "currency": "cr", "deposit_pct": 30, "due_day": cycle + DUE_IN[clampi(tier, 1, 3)] + (6 if size == "medium" else 14)},
	}


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
