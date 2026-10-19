class_name SurfaceZones
extends RefCounted
## Finish zones inside one part (docs/ECONOMY_PLAN.md section 7, A1b and the A1 revision).
## A component is one part with one material (mass, value, hardness), but its mesh is
## painted in named colours (WreckParts' TRIM, COPPER, LINER, RIM, the fabrics...): each of
## those colours carries a finish code (SurfaceFinish) in its alpha, and the salvage surface
## draws that zone as that finish (chrome, anodised alloy, ribbed rubber, leather, glazed
## ceramic, solar silicon...) instead of the part's own paint. Look only.
##
## The code: alpha = 1 - code * STEP, STEP = 6/255, so every code lands exactly on an 8-bit
## alpha (vertex colours are stored 8-bit) with room for 42 finishes. Alpha 1 = no zone (the
## part's own paint). Nothing else reads a vertex colour's alpha on these opaque surfaces;
## never scale a zoned colour (`c * 0.9` scales its code too): tag a new colour instead.

## The alpha step between codes.
const STEP: float = 6.0 / 255.0

## The alphas to put on a zone's colour constant (Color(r, g, b, SurfaceZones.COPPER_A)), one
## per finish, named after SurfaceFinish.CODES in upper case. The first twelve keep the A1b
## names (POLISHED is polished steel, BARE bare steel, CERAMIC plain ceramic...).
const POLISHED_A: float = 1.0 - 1.0 * STEP
const COPPER_A: float = 1.0 - 2.0 * STEP
const CERAMIC_A: float = 1.0 - 3.0 * STEP
const BLUED_A: float = 1.0 - 4.0 * STEP
const HEAT_A: float = 1.0 - 5.0 * STEP
const ENAMEL_A: float = 1.0 - 6.0 * STEP
const PLASTIC_A: float = 1.0 - 7.0 * STEP
const RUBBER_A: float = 1.0 - 8.0 * STEP
const FABRIC_A: float = 1.0 - 9.0 * STEP
const WOOD_A: float = 1.0 - 10.0 * STEP
const GOLD_A: float = 1.0 - 11.0 * STEP
const BARE_A: float = 1.0 - 12.0 * STEP
const BRUSHED_STEEL_A: float = 1.0 - 13.0 * STEP
const STAINLESS_A: float = 1.0 - 14.0 * STEP
const CHROME_A: float = 1.0 - 15.0 * STEP
const BRUSHED_ALLOY_A: float = 1.0 - 16.0 * STEP
const ANODISED_A: float = 1.0 - 17.0 * STEP
const CAST_IRON_A: float = 1.0 - 18.0 * STEP
const GALVANISED_A: float = 1.0 - 19.0 * STEP
const BRASS_A: float = 1.0 - 20.0 * STEP
const TITANIUM_A: float = 1.0 - 21.0 * STEP
const DENSE_CAST_A: float = 1.0 - 22.0 * STEP
const GUNMETAL_A: float = 1.0 - 23.0 * STEP
const GLOSS_PAINT_A: float = 1.0 - 24.0 * STEP
const SATIN_PAINT_A: float = 1.0 - 25.0 * STEP
const METALLIC_PAINT_A: float = 1.0 - 26.0 * STEP
const HAZARD_PAINT_A: float = 1.0 - 27.0 * STEP
const PLASTIC_GLOSS_A: float = 1.0 - 28.0 * STEP
const PLASTIC_TEXTURED_A: float = 1.0 - 29.0 * STEP
const NYLON_A: float = 1.0 - 30.0 * STEP
const RUBBER_TREAD_A: float = 1.0 - 31.0 * STEP
const FOAM_A: float = 1.0 - 32.0 * STEP
const CERAMIC_GLAZED_A: float = 1.0 - 33.0 * STEP
const CERAMIC_TILE_A: float = 1.0 - 34.0 * STEP
const CANVAS_A: float = 1.0 - 35.0 * STEP
const UPHOLSTERY_A: float = 1.0 - 36.0 * STEP
const LEATHER_A: float = 1.0 - 37.0 * STEP
const CARBON_A: float = 1.0 - 38.0 * STEP
const SILICON_A: float = 1.0 - 39.0 * STEP
const BRAID_A: float = 1.0 - 40.0 * STEP
const VEIL_A: float = 1.0 - 41.0 * STEP

## The first zones' codes by their A1b names (Zone.COPPER == SurfaceFinish.code("copper")).
enum Zone { NONE, POLISHED, COPPER, CERAMIC, BLUED, HEAT, ENAMEL, PLASTIC, RUBBER, FABRIC, WOOD, GOLD, BARE }


## `c` tagged with finish `id` (its alpha set to the finish's code). An unknown id leaves
## the colour untagged.
static func tag(c: Color, id: String) -> Color:
	return tagged(c, SurfaceFinish.code(id))


## `c` carrying `code_` (0 = no zone).
static func tagged(c: Color, code_: int) -> Color:
	return Color(c.r, c.g, c.b, 1.0 - float(code_) * STEP)


## The finish code a vertex colour carries (0 for an untagged colour).
static func zone_of(c: Color) -> int:
	var z := (1.0 - c.a) / STEP
	var n := roundi(z)
	if n <= 0 or n > SurfaceFinish.CODES.size() or absf(z - float(n)) > 0.34:
		return 0
	return n


## The finish id a vertex colour carries ("" for none).
static func finish_of(c: Color) -> String:
	return SurfaceFinish.id_of(zone_of(c))


## Puts the finish table on a salvage surface (the shader reads zones from it).
static func apply(m: ShaderMaterial) -> void:
	SurfaceFinish.apply(m)


## The finishes a mesh's colours carry, id -> how many vertices (a part's bill of surfaces;
## "" counts the untagged vertices, the part's own paint).
static func finishes_in(mesh: Mesh) -> Dictionary:
	var out: Dictionary = {}
	if mesh == null or mesh.get_surface_count() == 0:
		return out
	var cols: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	for c: Color in cols:
		var id := finish_of(c)
		out[id] = int(out.get(id, 0)) + 1
	return out
