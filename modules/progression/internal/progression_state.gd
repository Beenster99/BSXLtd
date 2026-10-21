extends RefCounted
## Everything Progression remembers, with the rules that change it. No nodes and no other
## modules here: the bus feeds it events and turns what it returns into signals.
##
## Skills and certs belong to a player; upgrades belong to the company.

const SAVE_VERSION := 1

var catalog: RefCounted
## String(player_id) -> {"skills": {skill_id: xp}, "certs": {cert_id: jobs_since_earned}}
var players: Dictionary = {}
var owned: PackedStringArray = []
## String(joint_id) -> XP already given for it, so a regraded joint only adds the difference.
var joint_xp: Dictionary = {}


func _init(cat: RefCounted) -> void:
	catalog = cat


func xp(player_id: StringName, skill_id: StringName) -> int:
	return int(_player(player_id).skills.get(String(skill_id), 0))


func level(player_id: StringName, skill_id: StringName) -> int:
	var s: ProgressionSkill = catalog.skills.get(skill_id)
	return s.level_for(xp(player_id, skill_id)) if s else 0


func has_cert(player_id: StringName, cert_id: StringName) -> bool:
	return _player(player_id).certs.has(String(cert_id))


func has_upgrade(upgrade_id: StringName) -> bool:
	return String(upgrade_id) in owned


## Perks from the player's skill levels plus every owned upgrade with this key.
func effect(player_id: StringName, key: StringName, perks := true, upgrades := true) -> float:
	return float(effects(player_id, perks, upgrades).get(key, 0.0))


## Every effect key that applies to the player, summed: {effect_key: value}. Perks or
## upgrades can be left out while their feature is switched off.
func effects(player_id: StringName, perks := true, upgrades := true) -> Dictionary:
	var out := {}
	if perks:
		_add_perks(player_id, out)
	if upgrades:
		_add_upgrades(out)
	return out


func _add_perks(player_id: StringName, out: Dictionary) -> void:
	for s: ProgressionSkill in catalog.skills.values():
		var lvl := level(player_id, s.id)
		for p in s.perks:
			if p.level <= lvl:
				out[p.effect_key] = float(out.get(p.effect_key, 0.0)) + p.value


func _add_upgrades(out: Dictionary) -> void:
	for id in owned:
		var u: ProgressionUpgrade = catalog.upgrades.get(StringName(id))
		if u and u.effect_key != &"":
			out[u.effect_key] = float(out.get(u.effect_key, 0.0)) + u.value


## {ok, missing}: missing lists upgrade ids still needed, "owned" or "unknown".
func can_unlock(upgrade_id: StringName) -> Dictionary:
	var u: ProgressionUpgrade = catalog.upgrades.get(upgrade_id)
	if u == null:
		return {"ok": false, "missing": [&"unknown"]}
	if has_upgrade(upgrade_id):
		return {"ok": false, "missing": [&"owned"]}
	var missing: Array[StringName] = []
	for req in u.requires:
		if not req in owned:
			missing.append(StringName(req))
	return {"ok": missing.is_empty(), "missing": missing}


## A graded joint (quality 0..1). A regraded joint adds only what beats its earlier grade.
## Returns {skill, amount, xp, level_before, level_after}, or {} when it adds nothing.
func add_joint(player_id: StringName, joint_id: StringName, trade: StringName, quality: float) -> Dictionary:
	var s: ProgressionSkill = catalog.skill_for_trade(trade)
	if s == null or player_id == &"":
		return {}
	var earned := roundi(s.xp_per_joint * clampf(quality, 0.0, 1.0))
	var given := int(joint_xp.get(String(joint_id), 0))
	var amount := earned - given
	if amount <= 0:
		return {}
	joint_xp[String(joint_id)] = earned
	var before := xp(player_id, s.id)
	_player(player_id, true).skills[String(s.id)] = before + amount
	return {"skill": s.id, "amount": amount, "xp": before + amount,
			"level_before": s.level_for(before), "level_after": s.level_for(before + amount)}


## A passed test job. Returns [[player_id, cert_id], ...] for each cert newly earned.
func pass_test(job_id: StringName, player_ids: Array) -> Array:
	var earned := []
	for c: ProgressionCert in catalog.certs.values():
		if c.test_job_id != job_id:
			continue
		for pid in player_ids:
			if level(pid, c.skill) >= c.min_level and not has_cert(pid, c.id):
				award(pid, c.id)
				earned.append([StringName(pid), c.id])
	return earned


func award(player_id: StringName, cert_id: StringName) -> void:
	_player(player_id, true).certs[String(cert_id)] = 0


## A closed job ages every cert. Returns [[player_id, cert_id], ...] for each that lapsed.
func close_job() -> Array:
	var lapsed := []
	for pid in players:
		var certs: Dictionary = players[pid].certs
		for cid in certs.keys():
			certs[cid] = int(certs[cid]) + 1
			var c: ProgressionCert = catalog.certs.get(StringName(cid))
			if c and c.valid_for_jobs > 0 and certs[cid] >= c.valid_for_jobs:
				certs.erase(cid)
				lapsed.append([StringName(pid), StringName(cid)])
	return lapsed


## The joint was taken apart, so a rebuilt joint with the same id earns afresh.
func forget_joint(joint_id: StringName) -> void:
	joint_xp.erase(String(joint_id))


func own(upgrade_id: StringName) -> void:
	if not has_upgrade(upgrade_id):
		owned.append(String(upgrade_id))


func to_dict() -> Dictionary:
	return {"players": players.duplicate(true), "owned": Array(owned), "joint_xp": joint_xp.duplicate()}


func from_dict(data: Dictionary, from_version: int) -> void:
	# Version 1 is the first schema; migrations for later versions go here.
	if from_version > SAVE_VERSION:
		push_warning("Progression: save version %d is newer than %d" % [from_version, SAVE_VERSION])
	players = {}
	var saved_players: Dictionary = data.get("players", {})
	for pid in saved_players:
		var p: Dictionary = saved_players[pid]
		players[String(pid)] = {"skills": p.get("skills", {}).duplicate(),
				"certs": p.get("certs", {}).duplicate()}
	owned = PackedStringArray(data.get("owned", []))
	joint_xp = data.get("joint_xp", {}).duplicate()


func _player(player_id: StringName, create := false) -> Dictionary:
	var key := String(player_id)
	if players.has(key):
		return players[key]
	var p := {"skills": {}, "certs": {}}
	if create:
		players[key] = p
	return p
