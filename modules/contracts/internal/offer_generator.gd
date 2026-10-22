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
