class_name Materials
extends RefCounted
## What salvage parts are made of (docs/ECONOMY_PLAN.md 3.2): each material has a
## hardness tier (tools below it are slow or useless), a density (mass comes from volume x
## density, so an alloy plate is lighter than a steel one), a price factor and a look (a
## SurfaceFinish and a tint, drawn by the salvage shader). `PartData.material` is an id
## into TABLE. Wrecks get theirs from `WreckDesign.material_for`, rolled from the wreck's
## seed in part-id order on every machine, never sent (`WreckDesign.assign_materials`).

## id -> {name, tier, density kg/m3, price (value factor), look}. Builders make every
## part as steel (7,800 kg/m3) and looms as copper; assigning another material scales the
## part's mass by the density ratio and its value by mass and price. The look is a finish
## (SurfaceFinish, the surface the part's body shows: "" keeps the paint it was built with)
## with a tint over the part's paint and `blend`, how much the finish's own colour shows
## through that paint (0 = the paint's colour in the finish's surface, 1 = the finish's
## swatch colour); zones inside the part (SurfaceZones) keep their own finishes.
const TABLE: Dictionary = {
	"steel": {"name": "Mild steel", "tier": 1, "density": 7800.0, "price": 1.0,
			"look": {}},
	"alloy": {"name": "Hull alloy", "tier": 1, "density": 2700.0, "price": 1.6,
			"look": {"finish": "anodised", "tint": Color(1.08, 1.08, 1.1), "blend": 0.25}},
	"copper": {"name": "Copper", "tier": 1, "density": 8900.0, "price": 1.0,
			"look": {}},
	"glass": {"name": "Glass", "tier": 1, "density": 2500.0, "price": 1.0,
			"look": {}},
	"titanium": {"name": "Titanium", "tier": 2, "density": 4500.0, "price": 4.0,
			"look": {"finish": "titanium", "tint": Color(0.9, 0.92, 1.0), "blend": 0.6}},
	"crystal": {"name": "Crystal glass", "tier": 2, "density": 2500.0, "price": 3.0,
			"look": {}},
	"superconductor": {"name": "Superconductor", "tier": 2, "density": 6000.0, "price": 8.0,
			"look": {"finish": "braid", "tint": Color(0.9, 0.97, 1.1), "blend": 0.7}},
	"ceramic": {"name": "Ceramic armour", "tier": 3, "density": 3900.0, "price": 2.5,
			"look": {"finish": "ceramic_tile", "tint": Color(1.1, 1.08, 1.02), "blend": 0.6}},
	"tungsten": {"name": "Dense alloy", "tier": 3, "density": 17000.0, "price": 6.0,
			"look": {"finish": "dense_cast", "tint": Color(0.7, 0.7, 0.75), "blend": 0.6}},
	"veil": {"name": "Veil alloy", "tier": 4, "density": 5200.0, "price": 20.0,
			"look": {"finish": "veil", "tint": Color(0.9, 0.94, 1.0), "blend": 0.6}},
}
## What a part is made of as built (before a design picks): steel, or copper for looms.
const BUILT := "steel"


static func info(id: String) -> Dictionary:
	return TABLE.get(id, TABLE[BUILT])


static func tier(id: String) -> int:
	return int(info(id)["tier"])


static func display_name(id: String) -> String:
	return String(info(id)["name"])


## "I", "II", "III", "IV" for a tool mark or tier.
static func roman(n: int) -> String:
	return ["0", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


## How fast a tool of `hardness` works something of `tier`: full speed at or under its
## hardness, `under_tier_rate` one tier above, nothing beyond (it only sparks).
static func tool_factor(hardness: int, tier_: int, under_tier_rate: float) -> float:
	if tier_ <= hardness:
		return 1.0
	if tier_ == hardness + 1:
		return under_tier_rate
	return 0.0


## The readout for a tool working something too hard for it, or "" when it's fine:
## "TOO HARD: CERAMIC ARMOUR (NEED MK II)" or "SLOW: TITANIUM (MK II FOR FULL SPEED)".
static func hardness_text(hardness: int, id: String) -> String:
	var t := tier(id)
	if t <= hardness:
		return ""
	if t == hardness + 1:
		return "SLOW: %s (MK %s FOR FULL SPEED)" % [display_name(id).to_upper(), roman(t)]
	return "TOO HARD: %s (NEED MK %s)" % [display_name(id).to_upper(), roman(t - 1)]


## The material a part has as built (no mass change): copper for wiring looms, else steel.
static func built_for(part_name: String, kind: int) -> String:
	return "copper" if kind == PartData.Kind.CONDUIT and (part_name.contains("Loom") or part_name.contains("Plug")) else BUILT


## Makes `part` of material `id`: mass scales by the density ratio, value by the mass and
## the price ratio. Data only; the structure's set_part_material also changes the look.
static func assign(part: PartData, id: String) -> void:
	if not TABLE.has(id) or id == part.material:
		return
	var old := info(part.material)
	var new := info(id)
	var ratio := float(new["density"]) / float(old["density"])
	part.mass = maxf(part.mass * ratio, 0.5)
	part.value *= ratio * float(new["price"]) / float(old["price"])
	part.material = id


static var _looks: Dictionary = {}


## The salvage surface `base` made to look like material `id` (one shared copy per pair);
## `base` itself for materials with no look of their own.
static func surface(base: ShaderMaterial, id: String) -> ShaderMaterial:
	var look: Dictionary = info(id)["look"]
	if look.is_empty():
		return base
	var key := "%d:%s" % [base.get_instance_id(), id]
	if not _looks.has(key):
		var m := SurfaceFinish.copy_surface(base)
		apply_look(m, id)
		_looks[key] = m
	return _looks[key]


## Sets material `id`'s look on a salvage surface: its finish code and tint.
static func apply_look(m: ShaderMaterial, id: String) -> void:
	var look: Dictionary = info(id)["look"]
	var tint: Color = look.get("tint", Color.WHITE)
	m.set_shader_parameter("material_tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("material_finish", SurfaceFinish.code(String(look.get("finish", ""))))
	m.set_shader_parameter("material_blend", float(look.get("blend", 0.0)))


## The finish id material `id` shows on a part's body ("" = the paint it was built with).
static func finish_of(id: String) -> String:
	return String((info(id)["look"] as Dictionary).get("finish", ""))
