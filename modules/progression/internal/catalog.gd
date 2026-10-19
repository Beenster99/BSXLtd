extends RefCounted
## Loads the skill, cert and upgrade definitions from internal/data/, keyed by id.

const DATA := "res://modules/progression/internal/data"

var skills: Dictionary = {}    # id -> ProgressionSkill
var certs: Dictionary = {}     # id -> ProgressionCert
var upgrades: Dictionary = {}  # id -> ProgressionUpgrade


static func from_data() -> RefCounted:
	var c: RefCounted = new()
	c.skills = _load_dir(DATA + "/skills")
	c.certs = _load_dir(DATA + "/certs")
	c.upgrades = _load_dir(DATA + "/upgrades")
	return c


## The skill trained by joints of `trade`, or null.
func skill_for_trade(trade: StringName) -> ProgressionSkill:
	for s: ProgressionSkill in skills.values():
		if s.trade == trade:
			return s
	return null


static func _load_dir(dir: String) -> Dictionary:
	var out := {}
	for entry in ResourceLoader.list_directory(dir):
		if not entry.ends_with(".tres"):
			continue
		var res: Resource = load("%s/%s" % [dir, entry])
		var id: StringName = res.get("id") if res else &""
		if id == &"":
			push_error("Progression: %s/%s has no id" % [dir, entry])
			continue
		out[id] = res
	return out
