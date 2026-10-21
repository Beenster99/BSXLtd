extends RefCounted
## G5, ground surfaces (flag "graphics.surfaces"): a material its owner marks with meta
## "gfx_surface" (KINDS: "concrete", "ground", "epoxy", "asphalt") is drawn with Graphics's
## ground shader in that kind's look, in the owner's colour and roughness: patches, a tint per
## slab, aggregate, dirt and damp, oil stains, scuffs and relief, all laid out in world space.
## The owner's material stays as it is (shared paints are fine); each node that draws it gets
## the Graphics copy as its material_override, and the flag off puts the owner's back.

const GroundShader := preload("res://modules/graphics/internal/ground_surface.gdshader")
## Meta on an owner's material: which kind of surface it is.
const META := "gfx_surface"
## Meta on a node Graphics restyled: the owner's material, to put back.
const SAVED := "gfx_surface_saved"

## Each kind's shader settings (see ground_surface.gdshader). "roughness" is added to the
## owner's roughness.
const KINDS := {
	"concrete": {"mottle": 0.14, "mottle_scale": 0.3, "slab": 6.0, "slab_tint": 0.08, "grain": 0.1,
			"grain_scale": 25.0, "stains": 0.5, "stain_scale": 0.07, "oil": 0.18, "oil_size": 0.8,
			"bump": 0.1, "bump_scale": 4.0, "roughness": -0.05},
	"ground": {"mottle": 0.22, "mottle_scale": 0.05, "dust": 0.45, "dust_colour": Color(0.56, 0.38, 0.27),
			"grain": 0.18, "grain_scale": 12.0, "stains": 0.15, "stain_scale": 0.02, "bump": 0.5,
			"bump_scale": 2.0, "roughness": 0.0},
	"epoxy": {"mottle": 0.04, "mottle_scale": 0.2, "slab": 6.0, "slab_tint": 0.02, "grain": 0.02,
			"grain_scale": 30.0, "stains": 0.12, "stain_scale": 0.12, "oil": 0.1, "oil_size": 0.5,
			"scuffs": 0.6, "bump": 0.04, "bump_scale": 3.0, "roughness": -0.1},
	"asphalt": {"mottle": 0.08, "mottle_scale": 0.15, "grain": 0.3, "grain_scale": 40.0,
			"stains": 0.25, "stain_scale": 0.05, "oil": 0.15, "oil_size": 0.6, "bump": 0.12,
			"bump_scale": 10.0, "roughness": -0.05},
}

## Owner's material -> Graphics's copy (one per material, shared by every node drawing it).
static var _made: Dictionary = {}


## The kind an owner's material is marked as, or "" (unmarked, or a kind Graphics lacks).
static func kind_of(m: Material) -> String:
	if m == null or not m.has_meta(META):
		return ""
	var kind := String(m.get_meta(META))
	return kind if KINDS.has(kind) else ""


## Graphics's copy of an owner's marked material.
static func material_for(src: Material) -> ShaderMaterial:
	if _made.has(src) and is_instance_valid(_made[src]):
		return _made[src]
	var kind := kind_of(src)
	var look: Dictionary = KINDS[kind]
	var colour := Vector3(0.4, 0.4, 0.4)
	var rough := 0.9
	if src is StandardMaterial3D:
		var c := (src as StandardMaterial3D).albedo_color.srgb_to_linear()
		colour = Vector3(c.r, c.g, c.b)
		rough = (src as StandardMaterial3D).roughness
	elif src is ShaderMaterial:
		# Void Salvage's ship surface (ShipSurface.of) keeps a linear albedo and roughness.
		var a: Variant = (src as ShaderMaterial).get_shader_parameter("albedo")
		if a is Vector3:
			colour = a
		elif a is Color:
			var c := (a as Color).srgb_to_linear()
			colour = Vector3(c.r, c.g, c.b)
		var r: Variant = (src as ShaderMaterial).get_shader_parameter("roughness")
		if r is float:
			rough = r
	var m := ShaderMaterial.new()
	m.shader = GroundShader
	m.set_shader_parameter("albedo", colour)
	m.set_shader_parameter("roughness", clampf(rough + float(look.get("roughness", 0.0)), 0.05, 1.0))
	for key: String in look:
		if key == "roughness":
			continue
		var v: Variant = look[key]
		if v is Color:
			var c := (v as Color).srgb_to_linear()
			v = Vector3(c.r, c.g, c.b)
		m.set_shader_parameter(key, v)
	# Still says what it is, for anyone reading the scene (Graphics's own copies are never
	# restyled again: see apply).
	m.set_meta(META, kind)
	_made[src] = m
	return m


## Restyles one node if its material is marked; true when it did.
static func apply(g: GeometryInstance3D) -> bool:
	if g.has_meta(SAVED):
		return false
	var src := g.material_override
	if kind_of(src) == "" or (src as ShaderMaterial and (src as ShaderMaterial).shader == GroundShader):
		return false
	g.set_meta(SAVED, src)
	g.material_override = material_for(src)
	return true


## Puts the owner's material back.
static func remove(g: GeometryInstance3D) -> void:
	if not g.has_meta(SAVED):
		return
	g.material_override = g.get_meta(SAVED)
	g.remove_meta(SAVED)
