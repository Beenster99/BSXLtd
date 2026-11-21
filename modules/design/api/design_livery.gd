class_name DesignLivery
extends RefCounted
## Her paint and markings (plan 3.10, the outside designer, stage 4): a base colour and a trim
## colour laid over the skin's panels in a pattern, a stripe down both sides, her name and hull
## number painted on, a client's livery in one go, and any single panel painted by hand
## ("panel:<z>:<edge>" -> {paint: "#rrggbb"} in the frame edits). DesignFrame builds the skin
## in these colours; walk-inside adds the stripe and the lettering.
##   rec.livery = {base, trim, stripe ("" none), stripe_at ("low", "mid", "high"), pattern,
##                 number, show_name, client}

## The yard's bare alloy: the colour a design has before it is painted.
const BARE := Color(0.5, 0.52, 0.55)
const PATTERNS := ["plain", "bands", "checker", "chamfers", "top"]
const PATTERN_NAMES := {"plain": "Plain", "bands": "Bands", "checker": "Checker", "chamfers": "Chamfers",
		"top": "Two tone"}
const STRIPES := ["low", "mid", "high"]
## The stripe's height, as a share of the side, and its width, m.
const STRIPE_AT := {"low": 0.22, "mid": 0.5, "high": 0.78}
const STRIPE_W := 0.35
## Paint and lettering per m2 of skin: what it costs, weighs and takes the painters.
const PAINT := {"name": "Paint and markings", "cost": 14.0, "mass": 0.35, "hours": 0.05}
## The paint shop's chart: a few colours to pick from, ship-yard plain.
const SWATCHES := ["#8a8f94", "#d9dcd8", "#2c3136", "#4a5a3c", "#7a2a22", "#c8a032", "#1f4e79", "#d46a1e",
		"#e8e2d0", "#3d6b6b"]
## A client's sector picks its livery's look: [base, trim, stripe, pattern] (then varied by the
## client, so two clients in a sector differ).
const SECTOR_LOOKS := {
	"military": ["#4a5a3c", "#2c3136", "#c8a032", "chamfers"],
	"mining": ["#c8a032", "#2c3136", "#d46a1e", "bands"],
	"trade": ["#1f4e79", "#d9dcd8", "#d46a1e", "top"],
	"salvage": ["#d46a1e", "#2c3136", "#e8e2d0", "bands"],
	"courier": ["#2c3136", "#7a2a22", "#d9dcd8", "plain"],
	"yacht": ["#e8e2d0", "#c8a032", "#1f4e79", "top"],
	"transport": ["#d9dcd8", "#1f4e79", "#7a2a22", "top"],
	"research": ["#e8e2d0", "#3d6b6b", "#d46a1e", "chamfers"],
}


## Whether a design is painted at all (else the skin keeps the yard's bare alloy).
static func painted(d: DesignRecord) -> bool:
	return not d.livery.is_empty()


static func base(l: Dictionary) -> Color:
	return Color.from_string(str(l.get("base", "")), BARE)


static func trim(l: Dictionary) -> Color:
	return Color.from_string(str(l.get("trim", "")), base(l).darkened(0.35))


## The colour of skin panel `e` in bay `k` (the plan's livery and hand-painted panels); null
## when the design is not painted and the panel was not painted by hand.
static func colour(p: Dictionary, k: int, e: int) -> Variant:
	var hand: Dictionary = p.get("paint", {})
	var key := "%d:%d" % [k, e]
	if hand.has(key):
		return Color.from_string(str(hand[key]), BARE)
	var l: Dictionary = p.get("livery", {})
	if l.is_empty():
		return null
	var b := base(l)
	var t := trim(l)
	match str(l.get("pattern", "plain")):
		"bands":
			return b if k % 2 == 0 else t
		"checker":
			return b if (k + e) % 2 == 0 else t
		"chamfers":
			return t if e % 2 == 1 else b
		"top":
			return t if e in [7, 0, 1] else b
	return b


## The colour of an end plate (front 0, back 1).
static func cap_colour(p: Dictionary) -> Variant:
	var l: Dictionary = p.get("livery", {})
	return null if l.is_empty() else base(l)


## A client's livery, from its sector's look varied by the client (always the same for one
## client): the fields to merge into rec.livery.
static func for_client(client_id: String, sector: String) -> Dictionary:
	var look: Array = SECTOR_LOOKS.get(sector, SECTOR_LOOKS["trade"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(client_id)
	var b := Color.from_string(look[0], BARE)
	b = b.lightened(rng.randf_range(-0.08, 0.12)) if rng.randf() < 0.5 else b.darkened(rng.randf_range(0.0, 0.12))
	return {"base": "#" + b.to_html(false), "trim": look[1], "stripe": look[2], "pattern": look[3],
			"stripe_at": STRIPES[rng.randi_range(0, 2)], "client": client_id}


## Her stripe and lettering on the skin of `plan`, under `parent` (ship space): a band down both
## sides at the stripe's height, her name and hull number aft of the nose on both sides. Each
## node is named Stripe_* or Marking_*. Nothing for an unpainted design.
static func decorate(plan: Dictionary, d: DesignRecord, parent: Node3D, layers: int = 1) -> void:
	var l := d.livery
	var st: Array = plan.get("stations", [])
	if l.is_empty() or st.size() < 2:
		return
	if str(l.get("stripe", "")) != "":
		var col := Color.from_string(str(l.stripe), Color.WHITE)
		var mat := ShipKit.paint(col, 0.3, 0.5)
		var at := float(STRIPE_AT.get(str(l.get("stripe_at", "mid")), 0.5))
		for e in [DesignFrame.STARBOARD, DesignFrame.PORT]:
			var tris := PackedVector3Array()
			for i in range(1, st.size()):
				var a := _band(st[i - 1], e, at)
				var b := _band(st[i], e, at)
				# Clockwise seen from outside (Godot's front faces), on each side.
				if e == DesignFrame.STARBOARD:
					tris.append_array([a[0], b[1], a[1], a[0], b[0], b[1]])
				else:
					tris.append_array([a[0], a[1], b[1], a[0], b[1], b[0]])
			var stool := SurfaceTool.new()
			stool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for v in tris:
				stool.add_vertex(v)
			stool.generate_normals()
			var mi := MeshInstance3D.new()
			mi.name = "Stripe_%d" % e
			mi.mesh = stool.commit()
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.layers = layers
			parent.add_child(mi)
	var words: Array[String] = []
	if bool(l.get("show_name", false)) and d.name.strip_edges() != "":
		words.append(d.name.to_upper())
	if str(l.get("number", "")).strip_edges() != "":
		words.append(str(l.number).to_upper())
	if words.is_empty():
		return
	var ink := Color.from_string(str(l.get("stripe", "")), Color.WHITE) if str(l.get("stripe", "")) != "" else trim(l).inverted()
	# In the fore half of her full-height body, clear of a tapering nose: the first frame whose
	# side is near her deepest, the words in the bay aft of it.
	var tall := 0.0
	for s: Dictionary in st:
		tall = maxf(tall, _side_height(s))
	var i := 0
	while i < st.size() - 2 and _side_height(st[i]) < tall * 0.85:
		i += 1
	var z := lerpf(float(st[i].z), float(st[mini(i + 1, st.size() - 1)].z), 0.5)
	var high := str(l.get("stripe_at", "mid")) != "high"
	for e in [DesignFrame.STARBOARD, DesignFrame.PORT]:
		var lbl := Label3D.new()
		lbl.name = "Marking_%d" % e
		lbl.text = "  ".join(words)
		lbl.pixel_size = 0.004
		lbl.font_size = 96
		lbl.modulate = ink
		lbl.outline_size = 0
		lbl.double_sided = false
		lbl.layers = layers
		# On the skin itself (the side plate at that frame), just proud of it, above the stripe
		# or below a high one.
		var band := _band(st[i], e, 0.75 if high else 0.3)
		var at := ((band[0] as Vector3) + (band[1] as Vector3)) * 0.5
		at.x += 0.02 if e == DesignFrame.STARBOARD else -0.02
		lbl.position = Vector3(at.x, at.y, z)
		# Reads from outside: starboard faces +X, port faces -X, the words running fore to aft
		# on the port side and aft to fore on starboard, as painted names do.
		lbl.rotation.y = PI * 0.5 if e == DesignFrame.STARBOARD else -PI * 0.5
		parent.add_child(lbl)


## The stripe's lower and upper points on side edge `e` of a station (x y z), just proud of
## the skin.
static func _band(station: Dictionary, e: int, at: float) -> Array:
	var pr: PackedVector2Array = station.profile
	var a := pr[e]
	var b := pr[(e + 1) % pr.size()]
	var lo := a if a.y < b.y else b
	var hi := b if a.y < b.y else a
	var mid := lo.lerp(hi, at)
	var dir := (hi - lo).normalized()
	var out := Vector2(1.0 if e == DesignFrame.STARBOARD else -1.0, 0.0) * 0.012
	var z := float(station.z)
	var p0 := mid - dir * STRIPE_W * 0.5 + out
	var p1 := mid + dir * STRIPE_W * 0.5 + out
	return [Vector3(p0.x, p0.y, z), Vector3(p1.x, p1.y, z)]


## How tall a station's starboard side plate stands, m.
static func _side_height(station: Dictionary) -> float:
	var pr: PackedVector2Array = station.profile
	var e := DesignFrame.STARBOARD
	return absf(pr[e].y - pr[(e + 1) % pr.size()].y)
