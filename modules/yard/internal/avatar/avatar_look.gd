class_name YardSuitLook
extends RefCounted
## How a player's suit looks (docs/AVATAR_PLAN.md section 9, AV4a): a variant per slot
## (helmet, visor, torso, pack, shoulders, gauntlets, boots), the exo frame shown or not,
## three colours from palettes, wear and the name plate. Kept in the profile (`Profile.look`,
## [suit]) and carried as one short code (`encode`/`decode`): the session's player list
## takes it at join and on every Apply (`NetSession.request_look`), and every machine
## builds that player's figure from it (`YardAvatar.apply_look`). Static, pure data.
##
## A look is a Dictionary:
##   {helmet, visor, torso, pack, shoulders, gauntlets, boots: variant id (SLOTS),
##    exo: bool (shown; owning it is Profile.exo), primary, secondary, accent: palette index,
##    wear: 0 clean / 1 worn / 2 battered, plate: up to PLATE_MAX characters ("" = the
##    player's name)}

## Selectable parts: six designs a shell slot (tools/blender/player_suits), six visor coatings.
## New variants are added at the end of a slot's list, so every code keeps its meaning.
const DESIGN_IDS: Array[String] = ["kestrel", "foundry", "lantern", "manta", "belter", "bulwark"]
const SLOTS: Dictionary = {
	"helmet": DESIGN_IDS,
	"visor": ["dark", "gold", "mirror", "ice", "ember", "jade"],
	"torso": DESIGN_IDS,
	"pack": DESIGN_IDS,
	"shoulders": DESIGN_IDS,
	"gauntlets": DESIGN_IDS,
	"boots": DESIGN_IDS,
}
## Keep the existing new-design codes d/e/f; retired a/b/c shell codes use Kestrel.
const SHELL_CODE_OFFSET := 3
## The slots in the code's (and the wardrobe's) order.
const SLOT_ORDER: Array[String] = ["helmet", "visor", "torso", "pack", "shoulders", "gauntlets", "boots"]
## What the wardrobe calls each variant.
const VARIANT_NAMES: Dictionary = {
	"kestrel": "KESTREL", "foundry": "FOUNDRY", "lantern": "LANTERN",
	"manta": "MANTA", "belter": "BELTER", "bulwark": "BULWARK",
	"dark": "SMOKED", "gold": "GOLD", "mirror": "MIRROR",
	"ice": "ICE", "ember": "EMBER", "jade": "JADE",
}
## The visor coatings (shaders/player_visor.gdshader): the glass's own colour, what it
## reflects, how mirrored (0..1) and how sharp (roughness 0..1).
const VISORS: Dictionary = {
	"dark": {"tint": Color(0.012, 0.016, 0.022), "sheen": Color(0.55, 0.68, 0.85), "mirror": 0.85, "roughness": 0.05},
	"gold": {"tint": Color(0.75, 0.47, 0.10), "sheen": Color(1.0, 0.78, 0.36), "mirror": 1.0, "roughness": 0.10},
	"mirror": {"tint": Color(0.72, 0.76, 0.80), "sheen": Color(0.85, 0.92, 1.0), "mirror": 1.0, "roughness": 0.03},
	"ice": {"tint": Color(0.10, 0.36, 0.58), "sheen": Color(0.55, 0.9, 1.0), "mirror": 0.9, "roughness": 0.06},
	"ember": {"tint": Color(0.52, 0.07, 0.02), "sheen": Color(1.0, 0.45, 0.2), "mirror": 0.95, "roughness": 0.08},
	"jade": {"tint": Color(0.03, 0.30, 0.17), "sheen": Color(0.5, 1.0, 0.72), "mirror": 0.9, "roughness": 0.06},
}

## The hard plates' colour: the company's shell white, light grey, slate, olive, Belter tan,
## charcoal.
const PRIMARY: Array[Color] = [
	ShipParts.SHELL, Color(0.7, 0.72, 0.74), Color(0.36, 0.42, 0.48),
	Color(0.4, 0.43, 0.27), Color(0.66, 0.55, 0.4), Color(0.21, 0.22, 0.24),
]
const PRIMARY_NAMES: Array[String] = ["SHELL WHITE", "LIGHT GREY", "SLATE", "OLIVE", "BELTER TAN", "CHARCOAL"]
## The trim: the company teal, orange, rust, dark grey, bone, black.
const SECONDARY: Array[Color] = [
	ShipParts.TRIM, Color(0.85, 0.42, 0.12), Color(0.5, 0.22, 0.13),
	Color(0.27, 0.29, 0.31), Color(0.84, 0.8, 0.68), Color(0.07, 0.07, 0.08),
]
const SECONDARY_NAMES: Array[String] = ["COMPANY TEAL", "ORANGE", "RUST", "DARK GREY", "BONE", "BLACK"]
## The accent (shoulders, visor rim, pack flash, sole lights, chest strip): how crewmates
## tell each other apart, so the host keeps a crew's distinct. The first four are the crew
## colours the host has always handed out (NetSession.COLORS), then eight more.
const ACCENT: Array[Color] = [
	Color(0.95, 0.55, 0.15),   # orange
	Color(0.25, 0.8, 0.95),    # cyan
	Color(0.55, 0.9, 0.3),     # lime
	Color(0.9, 0.35, 0.75),    # magenta
	Color(0.93, 0.94, 0.96),   # white
	Color(0.96, 0.88, 0.2),    # yellow
	Color(0.92, 0.2, 0.16),    # red
	Color(0.56, 0.36, 0.96),   # violet
	Color(0.3, 0.5, 1.0),      # sky blue
	Color(0.45, 0.98, 0.75),   # mint
	Color(0.78, 0.66, 0.32),   # gold
	Color(1.0, 0.62, 0.78),    # pink
]
const ACCENT_NAMES: Array[String] = ["ORANGE", "CYAN", "LIME", "MAGENTA", "WHITE", "YELLOW", "RED",
		"VIOLET", "SKY BLUE", "MINT", "GOLD", "PINK"]
## Wear's strength on the salvage surface shader (its `condition` wear, 0..1): clean, worn,
## battered.
const WEAR_LEVELS: Array[float] = [0.0, 0.35, 0.7]
const WEAR_NAMES: Array[String] = ["CLEAN", "WORN", "BATTERED"]
## The name plate's longest text (characters) and what it may hold.
const PLATE_MAX: int = 12
const PLATE_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -'"

const DEFAULT: Dictionary = {
	"helmet": "kestrel", "visor": "dark", "torso": "kestrel", "pack": "kestrel",
	"shoulders": "kestrel", "gauntlets": "kestrel", "boots": "kestrel", "exo": false,
	"primary": 0, "secondary": 0, "accent": 0, "wear": 1, "plate": "",
}

## The code's variant letters: index 0 is "a".
const LETTERS := "abcdefghijklmnopqrstuvwxyz"


## A fresh copy of the default look.
static func default_look() -> Dictionary:
	return DEFAULT.duplicate()


## A design changes the six interchangeable shells; colours and personal details stay yours.
static func design_look(id: String, base: Dictionary = {}) -> Dictionary:
	var out := valid(base)
	if id not in DESIGN_IDS:
		return out
	for slot: String in SLOT_ORDER:
		if slot != "visor":
			out[slot] = id
	return out


## `look` with every field present and in range (missing or unknown ones take the default).
static func valid(look: Dictionary) -> Dictionary:
	var out := default_look()
	for slot: String in SLOT_ORDER:
		var v := String(look.get(slot, ""))
		if (SLOTS[slot] as Array).has(v):
			out[slot] = v
	out["exo"] = bool(look.get("exo", false))
	out["primary"] = _index(look.get("primary", 0), PRIMARY.size())
	out["secondary"] = _index(look.get("secondary", 0), SECONDARY.size())
	out["accent"] = _index(look.get("accent", 0), ACCENT.size())
	out["wear"] = _index(look.get("wear", DEFAULT["wear"]), WEAR_LEVELS.size(), int(DEFAULT["wear"]))
	out["plate"] = clean_plate(String(look.get("plate", "")))
	return out


## The plate's text as it can be shown: capitals, the allowed characters, PLATE_MAX long.
static func clean_plate(text: String) -> String:
	var out := ""
	for ch in text.to_upper():
		if PLATE_CHARS.contains(ch):
			out += ch
	return out.strip_edges().left(PLATE_MAX)


## The look as a short code: a letter per slot (shells start at d; visors at a), exo ("0"/"1"),
## then the primary, secondary, accent and wear indexes and the plate, dot-separated:
## "daddddd0.0.0.0.1.OLA".
static func encode(look: Dictionary) -> String:
	var l := valid(look)
	var head := ""
	for slot: String in SLOT_ORDER:
		var offset := 0 if slot == "visor" else SHELL_CODE_OFFSET
		head += LETTERS[(SLOTS[slot] as Array).find(l[slot]) + offset]
	head += "1" if l["exo"] else "0"
	return "%s.%d.%d.%d.%d.%s" % [head, l["primary"], l["secondary"], l["accent"], l["wear"], l["plate"]]


## A code back to a look. Anything it doesn't know (a newer build's variant, garbage) falls
## back to the default, field by field, so no code is ever an error.
static func decode(code: String) -> Dictionary:
	var look := default_look()
	var bits := code.split(".", true, 5)
	if bits.is_empty():
		return look
	var head := bits[0]
	var shape := RegEx.create_from_string("^[a-z]{1,%d}[01]?$" % SLOT_ORDER.size())
	if shape.search(head) == null:
		head = ""   # not a code at all: every slot keeps its default
	for i in SLOT_ORDER.size():
		if i >= head.length():
			break
		var at := LETTERS.find(head[i]) - (0 if SLOT_ORDER[i] == "visor" else SHELL_CODE_OFFSET)
		var variants: Array = SLOTS[SLOT_ORDER[i]]
		if at >= 0 and at < variants.size():
			look[SLOT_ORDER[i]] = variants[at]
	if head.length() > SLOT_ORDER.size():
		look["exo"] = head[SLOT_ORDER.size()] == "1"
	var fields := ["primary", "secondary", "accent", "wear"]
	for i in fields.size():
		if bits.size() > i + 1 and bits[i + 1].is_valid_int():
			look[fields[i]] = int(bits[i + 1])
	if bits.size() > 5:
		look["plate"] = bits[5]
	return valid(look)


## `look` with the exo frame shown (or not).
static func with_exo(look: Dictionary, on: bool) -> Dictionary:
	var out := valid(look)
	out["exo"] = on
	return out


## The look's accent colour (what it asks for; the host may hand out another).
static func accent_color(look: Dictionary) -> Color:
	return ACCENT[_index(look.get("accent", 0), ACCENT.size())]


## The accent's name for a colour ("" if it isn't one of ACCENT).
static func accent_name(color: Color) -> String:
	for i in ACCENT.size():
		if ACCENT[i].is_equal_approx(color):
			return ACCENT_NAMES[i]
	return ""


## The colour a player gets: the accent they ask for, unless someone else wears it, then
## the first in ACCENT nobody wears.
static func resolve_accent(wanted: Color, taken: Array) -> Color:
	if not taken.any(func(c: Color) -> bool: return c.is_equal_approx(wanted)):
		return wanted
	for c in ACCENT:
		if not taken.any(func(t: Color) -> bool: return t.is_equal_approx(c)):
			return c
	return wanted


## The variant after (`step` 1) or before (-1) the look's in `slot`, wrapping round.
static func stepped(look: Dictionary, slot: String, step: int) -> String:
	var variants: Array = SLOTS[slot]
	var at := variants.find(look.get(slot, variants[0]))
	return variants[posmod(at + step, variants.size())]


static func _index(v: Variant, count: int, fallback: int = 0) -> int:
	var i := int(v) if (v is int or v is float) else fallback
	return i if i >= 0 and i < count else fallback
