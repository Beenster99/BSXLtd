class_name SurfaceFinish
extends RefCounted
## The finish library (docs/ECONOMY_PLAN.md section 7, A1 revised): every surface a part can
## show, as a PBR recipe the salvage surface shader draws. A finish is what a surface is
## *made of and how it was treated*: gloss paint, brushed steel, anodised alloy, cast iron,
## chrome, matte plastic, ribbed rubber, glazed ceramic, canvas, leather, oak... Parts carry
## them as zones (SurfaceZones: a colour's alpha names a finish), the game's materials
## (Materials.TABLE) point at one for the part's own body, and ship paint (ShipSurface)
## picks one from its StandardMaterial3D. Look only: a part's mass, value and hardness are
## its Materials id, never its finishes.
##
## Each entry (FINISHES, by id):
##   name       what it is, for the detail pane and the contact sheet
##   group      metal, paint, plastic, rubber, ceramic, fabric, leather, wood, special
##   metallic, roughness, specular (0.5 = dielectric default), clearcoat (a lacquer layer)
##   pattern    what the detail layer draws (Pattern): SMOOTH (paint orange peel), BRUSHED
##              (lines along the part), CAST (rough lumpy metal), CELLS (chalk and pores),
##              WEAVE (two-way threads), PEBBLE (leather and crinkle finishes), TILES (a
##              grid of plates with grout lines), SPANGLE (galvanised crystals), RIBS
##              (moulded ridges), GRAIN (wood)
##   scale      metres one tile of the pattern covers (bigger = coarser features)
##   bump       how much the pattern tilts the normal (0 flat .. 1). Smooth metals and paints
##              sit near 0: they read by their sheen, not by lumps (a 0.1 bump on an 0.8 m
##              tile is 8 cm orange peel under a sun)
##   relief     how much it shades the colour (0 .. 1)
##   wear       how it ages (Wear): PAINT chips to primer and bare metal, METAL scratches
##              and dulls, PLASTIC scuffs pale, RUBBER greys with dust, FABRIC stains and
##              fades, CERAMIC chips to a pale core, WOOD scuffs pale, NONE only grime
##   rust       bare steel under it rusts (0 .. 1)
##   tint       the part's material tint still colours it (polished trim on a titanium part
##              reads as titanium): 0 or 1
##   flake      metal flakes that glint (metallic paints, spangle), temper (heat colours),
##              iridescence (an oil film), each 0 .. 1
##   swatch     the colour the contact sheet paints its block
## Metals sit at 0.6 .. 0.85 metallic, never 1: a fully metallic surface has no colour of its
## own, and in space there is mostly black to reflect.
## Codes: CODES lists the ids in order; a finish's code is its index + 1 (0 = "as built":
## the part's own paint from the shader's albedo, metallic and roughness uniforms). Add a
## finish at the END of CODES: the codes are baked into every part's vertex colours.

enum Pattern { SMOOTH, BRUSHED, CAST, CELLS, WEAVE, PEBBLE, TILES, SPANGLE, RIBS, GRAIN }
enum Wear { PAINT, METAL, PLASTIC, RUBBER, FABRIC, CERAMIC, WOOD, NONE }

## Every finish id in code order (code = index + 1). Never reorder; only append.
const CODES: Array[String] = [
	# 1..12: the first zones (A1b), kept at their codes.
	"polished_steel", "copper", "ceramic", "blued_steel", "heat_shield", "enamel", "plastic",
	"rubber", "fabric", "wood", "gold", "bare_steel",
	# 13..: the A1 revision.
	"brushed_steel", "stainless", "chrome", "brushed_alloy", "anodised", "cast_iron",
	"galvanised", "brass", "titanium", "dense_cast", "gunmetal", "gloss_paint", "satin_paint",
	"metallic_paint", "hazard_paint", "plastic_gloss", "plastic_textured", "nylon",
	"rubber_tread", "foam", "ceramic_glazed", "ceramic_tile", "canvas", "upholstery", "leather",
	"carbon", "silicon", "braid", "veil",
]

## Fewer than this many codes fit an 8-bit alpha at STEP apart: 42.
const MAX_CODES: int = 42

const FINISHES: Dictionary = {
	# --- Metals -------------------------------------------------------------------------
	"polished_steel": {"name": "Polished steel", "group": "metal", "metallic": 0.78, "roughness": 0.22,
			"pattern": Pattern.BRUSHED, "scale": 0.6, "bump": 0.02, "relief": 0.04, "wear": Wear.METAL,
			"rust": 0.3, "tint": 1, "swatch": Color(0.82, 0.84, 0.86)},
	"bare_steel": {"name": "Bare steel", "group": "metal", "metallic": 0.7, "roughness": 0.42,
			"pattern": Pattern.BRUSHED, "scale": 0.5, "bump": 0.04, "relief": 0.08, "wear": Wear.METAL,
			"rust": 1.0, "tint": 1, "swatch": Color(0.55, 0.56, 0.58)},
	"brushed_steel": {"name": "Brushed steel", "group": "metal", "metallic": 0.75, "roughness": 0.36,
			"pattern": Pattern.BRUSHED, "scale": 0.5, "bump": 0.06, "relief": 0.1, "wear": Wear.METAL,
			"rust": 0.6, "tint": 1, "swatch": Color(0.6, 0.62, 0.64)},
	"stainless": {"name": "Stainless steel", "group": "metal", "metallic": 0.8, "roughness": 0.3,
			"pattern": Pattern.BRUSHED, "scale": 0.5, "bump": 0.03, "relief": 0.06, "wear": Wear.METAL,
			"rust": 0.0, "tint": 0, "swatch": Color(0.72, 0.73, 0.74)},
	"chrome": {"name": "Chrome", "group": "metal", "metallic": 0.85, "roughness": 0.08,
			"pattern": Pattern.SMOOTH, "scale": 1.0, "bump": 0.0, "relief": 0.02, "wear": Wear.METAL,
			"rust": 0.0, "tint": 0, "swatch": Color(0.9, 0.9, 0.92)},
	"brushed_alloy": {"name": "Brushed alloy", "group": "metal", "metallic": 0.72, "roughness": 0.4,
			"pattern": Pattern.BRUSHED, "scale": 0.5, "bump": 0.05, "relief": 0.08, "wear": Wear.METAL,
			"rust": 0.0, "tint": 1, "swatch": Color(0.74, 0.75, 0.77)},
	"anodised": {"name": "Anodised alloy", "group": "metal", "metallic": 0.6, "roughness": 0.55,
			"pattern": Pattern.SMOOTH, "scale": 0.3, "bump": 0.03, "relief": 0.05, "wear": Wear.METAL,
			"rust": 0.0, "tint": 0, "swatch": Color(0.5, 0.52, 0.55)},
	"cast_iron": {"name": "Cast iron", "group": "metal", "metallic": 0.6, "roughness": 0.8,
			"pattern": Pattern.CAST, "scale": 0.25, "bump": 0.35, "relief": 0.3, "wear": Wear.METAL,
			"rust": 1.0, "tint": 0, "swatch": Color(0.3, 0.3, 0.31)},
	"galvanised": {"name": "Galvanised steel", "group": "metal", "metallic": 0.72, "roughness": 0.5,
			"pattern": Pattern.SPANGLE, "scale": 0.4, "bump": 0.02, "relief": 0.25, "wear": Wear.METAL,
			"rust": 0.2, "tint": 0, "flake": 0.5, "swatch": Color(0.66, 0.68, 0.7)},
	"brass": {"name": "Brass", "group": "metal", "metallic": 0.8, "roughness": 0.32,
			"pattern": Pattern.SMOOTH, "scale": 0.5, "bump": 0.02, "relief": 0.04, "wear": Wear.METAL,
			"rust": 0.0, "tint": 0, "swatch": Color(0.78, 0.62, 0.3)},
	"copper": {"name": "Copper", "group": "metal", "metallic": 0.8, "roughness": 0.38,
			"pattern": Pattern.SMOOTH, "scale": 0.4, "bump": 0.02, "relief": 0.05, "wear": Wear.METAL,
			"rust": 0.0, "tint": 0, "swatch": Color(0.85, 0.6, 0.25)},
	"gold": {"name": "Gold", "group": "metal", "metallic": 0.82, "roughness": 0.25,
			"pattern": Pattern.SMOOTH, "scale": 0.5, "bump": 0.0, "relief": 0.03, "wear": Wear.NONE,
			"rust": 0.0, "tint": 0, "swatch": Color(0.85, 0.62, 0.16)},
	"titanium": {"name": "Titanium", "group": "metal", "metallic": 0.75, "roughness": 0.45,
			"pattern": Pattern.BRUSHED, "scale": 0.5, "bump": 0.05, "relief": 0.08, "wear": Wear.METAL,
			"rust": 0.0, "tint": 1, "temper": 0.6, "swatch": Color(0.6, 0.63, 0.7)},
	"blued_steel": {"name": "Heat-blued steel", "group": "metal", "metallic": 0.7, "roughness": 0.4,
			"pattern": Pattern.BRUSHED, "scale": 0.5, "bump": 0.04, "relief": 0.08, "wear": Wear.METAL,
			"rust": 0.3, "tint": 0, "temper": 0.9, "swatch": Color(0.3, 0.31, 0.33)},
	"heat_shield": {"name": "Heat-tinted shield", "group": "metal", "metallic": 0.55, "roughness": 0.6,
			"pattern": Pattern.CAST, "scale": 0.3, "bump": 0.12, "relief": 0.2, "wear": Wear.METAL,
			"rust": 0.0, "tint": 0, "temper": 0.6, "swatch": Color(0.5, 0.44, 0.38)},
	"dense_cast": {"name": "Dense cast alloy", "group": "metal", "metallic": 0.6, "roughness": 0.75,
			"pattern": Pattern.CAST, "scale": 0.35, "bump": 0.25, "relief": 0.3, "wear": Wear.METAL,
			"rust": 0.0, "tint": 1, "swatch": Color(0.3, 0.3, 0.33)},
	"gunmetal": {"name": "Gunmetal", "group": "metal", "metallic": 0.72, "roughness": 0.5,
			"pattern": Pattern.SMOOTH, "scale": 0.5, "bump": 0.02, "relief": 0.05, "wear": Wear.METAL,
			"rust": 0.2, "tint": 0, "swatch": Color(0.28, 0.29, 0.32)},
	# --- Paints -------------------------------------------------------------------------
	"gloss_paint": {"name": "Gloss paint", "group": "paint", "metallic": 0.0, "roughness": 0.25,
			"clearcoat": 0.6, "pattern": Pattern.SMOOTH, "scale": 0.8, "bump": 0.0, "relief": 0.02,
			"wear": Wear.PAINT, "rust": 1.0, "tint": 0, "swatch": Color(0.72, 0.1, 0.08)},
	"satin_paint": {"name": "Satin paint", "group": "paint", "metallic": 0.05, "roughness": 0.5,
			"pattern": Pattern.SMOOTH, "scale": 0.8, "bump": 0.02, "relief": 0.03, "wear": Wear.PAINT,
			"rust": 1.0, "tint": 0, "swatch": Color(0.3, 0.32, 0.38)},
	"metallic_paint": {"name": "Metallic paint", "group": "paint", "metallic": 0.35, "roughness": 0.3,
			"clearcoat": 0.8, "pattern": Pattern.SMOOTH, "scale": 0.8, "bump": 0.0, "relief": 0.02,
			"wear": Wear.PAINT, "rust": 1.0, "tint": 0, "flake": 0.8, "swatch": Color(0.2, 0.23, 0.3)},
	"enamel": {"name": "Enamel", "group": "paint", "metallic": 0.05, "roughness": 0.2,
			"clearcoat": 0.3, "pattern": Pattern.SMOOTH, "scale": 0.6, "bump": 0.0, "relief": 0.02,
			"wear": Wear.PAINT, "rust": 1.0, "tint": 0, "swatch": Color(0.8, 0.78, 0.7)},
	"hazard_paint": {"name": "Hazard paint", "group": "paint", "metallic": 0.0, "roughness": 0.55,
			"pattern": Pattern.SMOOTH, "scale": 0.6, "bump": 0.02, "relief": 0.04, "wear": Wear.PAINT,
			"rust": 1.0, "tint": 0, "swatch": Color(0.92, 0.72, 0.12)},
	# --- Plastics and rubber ------------------------------------------------------------
	"plastic": {"name": "Matte plastic", "group": "plastic", "metallic": 0.0, "roughness": 0.6,
			"pattern": Pattern.SMOOTH, "scale": 0.5, "bump": 0.02, "relief": 0.04, "wear": Wear.PLASTIC,
			"rust": 0.0, "tint": 0, "swatch": Color(0.25, 0.27, 0.3)},
	"plastic_gloss": {"name": "Gloss plastic", "group": "plastic", "metallic": 0.0, "roughness": 0.2,
			"clearcoat": 0.3, "pattern": Pattern.SMOOTH, "scale": 0.5, "bump": 0.0, "relief": 0.02,
			"wear": Wear.PLASTIC, "rust": 0.0, "tint": 0, "swatch": Color(0.8, 0.1, 0.08)},
	"plastic_textured": {"name": "Textured plastic", "group": "plastic", "metallic": 0.0, "roughness": 0.75,
			"pattern": Pattern.PEBBLE, "scale": 0.12, "bump": 0.25, "relief": 0.12, "wear": Wear.PLASTIC,
			"rust": 0.0, "tint": 0, "swatch": Color(0.13, 0.13, 0.14)},
	"nylon": {"name": "Nylon webbing", "group": "fabric", "metallic": 0.0, "roughness": 0.7,
			"pattern": Pattern.WEAVE, "scale": 0.08, "bump": 0.3, "relief": 0.3, "wear": Wear.FABRIC,
			"rust": 0.0, "tint": 0, "swatch": Color(0.85, 0.55, 0.15)},
	"rubber": {"name": "Rubber", "group": "rubber", "metallic": 0.0, "roughness": 0.88,
			"pattern": Pattern.SMOOTH, "scale": 0.4, "bump": 0.03, "relief": 0.06, "wear": Wear.RUBBER,
			"rust": 0.0, "tint": 0, "swatch": Color(0.12, 0.12, 0.13)},
	"rubber_tread": {"name": "Ribbed rubber", "group": "rubber", "metallic": 0.0, "roughness": 0.9,
			"pattern": Pattern.RIBS, "scale": 0.1, "bump": 0.5, "relief": 0.35, "wear": Wear.RUBBER,
			"rust": 0.0, "tint": 0, "swatch": Color(0.14, 0.14, 0.15)},
	"foam": {"name": "Closed-cell foam", "group": "rubber", "metallic": 0.0, "roughness": 0.95,
			"pattern": Pattern.CELLS, "scale": 0.15, "bump": 0.15, "relief": 0.15, "wear": Wear.RUBBER,
			"rust": 0.0, "tint": 0, "swatch": Color(0.3, 0.3, 0.32)},
	# --- Ceramics -----------------------------------------------------------------------
	"ceramic": {"name": "Ceramic", "group": "ceramic", "metallic": 0.0, "roughness": 0.9,
			"pattern": Pattern.CELLS, "scale": 0.4, "bump": 0.15, "relief": 0.25, "wear": Wear.CERAMIC,
			"rust": 0.0, "tint": 0, "swatch": Color(0.86, 0.79, 0.64)},
	"ceramic_glazed": {"name": "Glazed ceramic", "group": "ceramic", "metallic": 0.0, "roughness": 0.15,
			"clearcoat": 0.7, "pattern": Pattern.SMOOTH, "scale": 0.5, "bump": 0.0, "relief": 0.03,
			"wear": Wear.CERAMIC, "rust": 0.0, "tint": 0, "swatch": Color(0.9, 0.9, 0.88)},
	"ceramic_tile": {"name": "Ceramic armour tile", "group": "ceramic", "metallic": 0.0, "roughness": 0.85,
			"pattern": Pattern.TILES, "scale": 0.5, "bump": 0.25, "relief": 0.3, "wear": Wear.CERAMIC,
			"rust": 0.0, "tint": 1, "swatch": Color(0.72, 0.7, 0.66)},
	# --- Fabrics, leather, wood ---------------------------------------------------------
	"fabric": {"name": "Woven fabric", "group": "fabric", "metallic": 0.0, "roughness": 0.95,
			"pattern": Pattern.WEAVE, "scale": 0.06, "bump": 0.2, "relief": 0.25, "wear": Wear.FABRIC,
			"rust": 0.0, "tint": 0, "swatch": Color(0.32, 0.4, 0.5)},
	"canvas": {"name": "Canvas", "group": "fabric", "metallic": 0.0, "roughness": 0.92,
			"pattern": Pattern.WEAVE, "scale": 0.1, "bump": 0.3, "relief": 0.3, "wear": Wear.FABRIC,
			"rust": 0.0, "tint": 0, "swatch": Color(0.42, 0.4, 0.33)},
	"upholstery": {"name": "Upholstery", "group": "fabric", "metallic": 0.0, "roughness": 0.85,
			"pattern": Pattern.WEAVE, "scale": 0.05, "bump": 0.12, "relief": 0.18, "wear": Wear.FABRIC,
			"rust": 0.0, "tint": 0, "swatch": Color(0.34, 0.35, 0.37)},
	"leather": {"name": "Leather", "group": "leather", "metallic": 0.0, "roughness": 0.5,
			"pattern": Pattern.PEBBLE, "scale": 0.2, "bump": 0.25, "relief": 0.22, "wear": Wear.PLASTIC,
			"rust": 0.0, "tint": 0, "swatch": Color(0.36, 0.22, 0.14)},
	"wood": {"name": "Wood", "group": "wood", "metallic": 0.0, "roughness": 0.45,
			"clearcoat": 0.3, "pattern": Pattern.GRAIN, "scale": 0.6, "bump": 0.06, "relief": 0.3,
			"wear": Wear.WOOD, "rust": 0.0, "tint": 0, "swatch": Color(0.78, 0.47, 0.27)},
	"carbon": {"name": "Carbon fibre", "group": "special", "metallic": 0.1, "roughness": 0.22,
			"clearcoat": 0.9, "pattern": Pattern.WEAVE, "scale": 0.04, "bump": 0.08, "relief": 0.6,
			"wear": Wear.PLASTIC, "rust": 0.0, "tint": 0, "swatch": Color(0.18, 0.18, 0.2)},
	# --- Specials -----------------------------------------------------------------------
	"silicon": {"name": "Solar silicon", "group": "special", "metallic": 0.3, "roughness": 0.12,
			"clearcoat": 0.8, "pattern": Pattern.TILES, "scale": 0.16, "bump": 0.05, "relief": 0.35,
			"wear": Wear.NONE, "rust": 0.0, "tint": 0, "iridescence": 0.1, "swatch": Color(0.1, 0.16, 0.42)},
	"braid": {"name": "Superconductor braid", "group": "special", "metallic": 0.75, "roughness": 0.35,
			"pattern": Pattern.WEAVE, "scale": 0.03, "bump": 0.3, "relief": 0.3, "wear": Wear.NONE,
			"rust": 0.0, "tint": 1, "swatch": Color(0.85, 0.95, 1.2)},
	"veil": {"name": "Veil alloy", "group": "special", "metallic": 0.75, "roughness": 0.3,
			"pattern": Pattern.SMOOTH, "scale": 0.6, "bump": 0.0, "relief": 0.04, "wear": Wear.NONE,
			"rust": 0.0, "tint": 1, "iridescence": 0.7, "swatch": Color(0.8, 0.86, 1.0)},
}

## The defaults a finish leaves out.
const DEFAULTS: Dictionary = {
	"metallic": 0.0, "roughness": 0.5, "specular": 0.5, "clearcoat": 0.0, "pattern": Pattern.SMOOTH,
	"scale": 0.5, "bump": 0.1, "relief": 0.1, "wear": Wear.NONE, "rust": 0.0, "tint": 0, "flake": 0.0,
	"temper": 0.0, "iridescence": 0.0, "swatch": Color(0.5, 0.5, 0.5), "name": "As built", "group": "paint",
}

## The lookup texture: one row per code (row 0 = as built), TEXELS pixels across.
const TEXELS: int = 5
const ROWS: int = 64

static var _table: ImageTexture
static var _codes: Dictionary = {}


## The code of finish `id` (1..), or 0 for an unknown id or "" (as built).
static func code(id: String) -> int:
	if _codes.is_empty():
		for i in CODES.size():
			_codes[CODES[i]] = i + 1
	return int(_codes.get(id, 0))


## The id at `code_`, or "" for 0 or out of range.
static func id_of(code_: int) -> String:
	return CODES[code_ - 1] if code_ >= 1 and code_ <= CODES.size() else ""


static func info(id: String) -> Dictionary:
	var out := DEFAULTS.duplicate()
	out.merge(FINISHES.get(id, {}), true)
	return out


static func display_name(id: String) -> String:
	return String(FINISHES.get(id, {}).get("name", "As built"))


## A value of finish `id`, with the defaults filled in.
static func value(id: String, key: String) -> Variant:
	return FINISHES.get(id, {}).get(key, DEFAULTS[key])


## The lookup texture, baked once: row = code, texels
##   0 (metallic, roughness, specular, clearcoat)
##   1 (pattern, scale m, bump, relief)
##   2 (wear, rust, tint, flake)
##   3 (temper, iridescence, 0, 0)
##   4 (swatch rgb, 0): the finish's own colour, for a material showing through its paint
## Row 0 is a sentinel the shader reads as "the part's own paint" (SMOOTH, PAINT wear, rusts).
static func table() -> ImageTexture:
	if _table == null:
		var img := Image.create(TEXELS, ROWS, false, Image.FORMAT_RGBAF)
		img.set_pixel(0, 0, Color(0.0, 0.5, 0.5, 0.0))
		img.set_pixel(1, 0, Color(float(Pattern.SMOOTH), 0.8, 0.02, 0.03))
		img.set_pixel(2, 0, Color(float(Wear.PAINT), 1.0, 1.0, 0.0))
		img.set_pixel(3, 0, Color(0.0, 0.0, 0.0, 0.0))
		img.set_pixel(4, 0, Color(0.5, 0.5, 0.5, 0.0))
		for i in CODES.size():
			var f := info(CODES[i])
			var row := i + 1
			img.set_pixel(0, row, Color(float(f["metallic"]), float(f["roughness"]), float(f["specular"]), float(f["clearcoat"])))
			img.set_pixel(1, row, Color(float(int(f["pattern"])), float(f["scale"]), float(f["bump"]), float(f["relief"])))
			img.set_pixel(2, row, Color(float(int(f["wear"])), float(f["rust"]), float(f["tint"]), float(f["flake"])))
			img.set_pixel(3, row, Color(float(f["temper"]), float(f["iridescence"]), 0.0, 0.0))
			var sw: Color = f["swatch"]
			img.set_pixel(4, row, Color(sw.r, sw.g, sw.b, 0.0))
		_table = ImageTexture.create_from_image(img)
	return _table


## Puts the finish table on a salvage surface material.
static func apply(m: ShaderMaterial) -> void:
	m.set_shader_parameter("finish_table", table())
	m.set_shader_parameter("finish_count", CODES.size())


## Every id in a group ("metal", "paint"...), in code order.
static func in_group(group: String) -> Array[String]:
	var out: Array[String] = []
	for id in CODES:
		if String(FINISHES[id]["group"]) == group:
			out.append(id)
	return out


## A copy of a salvage surface with its paint (colour, metal, roughness...), made fresh:
## in Godot 4.7 duplicate() on these loses the colour (on the copy and on the shared
## original), so weathered parts came out the shader's default grey.
static func copy_surface(mat: ShaderMaterial) -> ShaderMaterial:
	var copy := ShaderMaterial.new()
	copy.shader = mat.shader
	copy.render_priority = mat.render_priority
	for u: Dictionary in mat.shader.get_shader_uniform_list():
		var key: String = u["name"]
		var value: Variant = mat.get_shader_parameter(key)
		if value != null:
			copy.set_shader_parameter(key, value)
	return copy


static var _two_sided: Shader


## The surface shader, or a copy that draws both sides of faces (thin parts like looms).
static func surface_shader(two_sided: bool) -> Shader:
	var base := preload("res://shared/void_salvage/shaders/salvage_surface.gdshader")
	if not two_sided:
		return base
	if _two_sided == null:
		_two_sided = Shader.new()
		_two_sided.code = base.code.replace("render_mode cull_back;", "render_mode cull_disabled;")
	return _two_sided
