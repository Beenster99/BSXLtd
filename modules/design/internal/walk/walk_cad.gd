extends RefCounted
## Walk-inside drawn as a 3D CAD model (beenster, 19 Nov co-op test: "make it look like a 3D
## CAD model with object types in specific colours per class"): every built piece takes the
## flat colour of its class, with dark edges round the boxes. V in walk-inside swaps back to the
## near-real look (WalkInside.cad).
##
## Classes, by what WalkBuild named a piece or which of the frame's materials it wears; a part
## takes its catalogue colour (one per category), wires and pipes keep their own colours.

const CLASSES: Dictionary = {
	"frame": {"name": "Frame and beams", "colour": Color(0.25, 0.45, 0.78)},
	"hull": {"name": "Hull plating", "colour": Color(0.42, 0.50, 0.58)},
	"glass": {"name": "Glass", "colour": Color(0.45, 0.85, 1.0, 0.35)},
	"wall": {"name": "Walls and linings", "colour": Color(0.74, 0.74, 0.70)},
	"deck": {"name": "Decks", "colour": Color(0.40, 0.44, 0.48)},
	"ceiling": {"name": "Ceilings", "colour": Color(0.62, 0.64, 0.66)},
	"door": {"name": "Doors", "colour": Color(0.96, 0.52, 0.12)},
	"access": {"name": "Stairs, lifts and hatches", "colour": Color(0.96, 0.80, 0.18)},
	"component": {"name": "Components (by kind)", "colour": Color(0.40, 0.80, 0.45)},
	"service": {"name": "Wires and pipes", "colour": Color(0.85, 0.35, 0.75)},
}
## The order the legend lists them in.
const ORDER: PackedStringArray = ["frame", "hull", "glass", "wall", "deck", "ceiling", "door", "access",
		"component"]
## Weld, rivet and bolt heads.
const FASTENER := Color(0.22, 0.24, 0.27)
## Edges drawn round the boxes.
const EDGE := Color(0.05, 0.07, 0.10)

## Name prefixes WalkBuild gives its pieces -> class ("" leaves them as built).
const BY_NAME: Array = [
	["Floor_", "deck"], ["DeckPlates_", "deck"], ["OpenDeck", "deck"], ["Ceiling_", "ceiling"],
	["Roof_", "hull"], ["OpenDeckRoof_", "hull"], ["Door_", "door"], ["Sill_", "door"], ["Lift", "access"],
	["Ramp_", "access"], ["Steps_", "access"], ["Rail", "access"], ["Ladder", "access"], ["Hatch", "access"], ["Girder", "frame"],
	["Beam", "frame"], ["CableInWall", ""], ["CableTray", ""], ["Pipe", ""], ["Riser", ""], ["ServiceXray", ""],
	["Lamp_", ""], ["HoloOutline", "edge"], ["Part_", "component"], ["Mount_", "component"],
]

var _mats: Dictionary = {}


## Recolours everything under `root` (WalkBuild's output) by class. `frame_mats` are the
## materials WalkBuild gave the frame ({shell, frame, lining, deck}).
func apply(root: Node3D, rec: DesignRecord, catalog: DesignCatalog, frame_mats: Dictionary) -> void:
	var by_mat := {}
	for k: String in frame_mats:
		by_mat[frame_mats[k]] = {"shell": "hull", "frame": "frame", "lining": "wall", "deck": "deck"}.get(k, "frame")
	for child in root.get_children():
		var cls := class_of(child)
		if cls == "":
			continue
		if cls == "edge":
			(child as MeshInstance3D).material_override = _edge_mat()
			continue
		var col: Color = CLASSES.get(cls, CLASSES.frame).colour
		if cls == "component":
			col = _part_colour(child, rec, catalog)
		var geo: Array[Node] = child.find_children("*", "GeometryInstance3D", true, false)
		if child is GeometryInstance3D:
			geo.append(child)
		for g in geo:
			var gi := g as GeometryInstance3D
			if gi is MeshInstance3D and gi.name == "HoloOutline":
				continue
			var own := cls
			var c := col
			if child.name == "Frame":
				var m: Material = gi.material_override
				# Anything else on the frame is a weld, rivet or bolt head: small and dark.
				own = str(by_mat.get(m, "glass" if _see_through(m) else "fastener"))
				c = CLASSES[own].colour if CLASSES.has(own) else FASTENER
			elif cls != "component" and _see_through(gi.material_override):
				c = CLASSES.glass.colour
			# Ceilings face away from the lamps under them: lit more from within to read.
			gi.material_override = mat(c, 0.5 if own == "ceiling" else 0.12)


## The class of a piece WalkBuild built (a top-level child of its root): "" to leave it as built.
func class_of(n: Node) -> String:
	if n.name == "Frame":
		return "frame"
	var info: Variant = n.get_meta("walk") if n.has_meta("walk") else null
	if info is Dictionary and str(info.get("kind", "")) == "wall":
		return "wall"
	for pair: Array in BY_NAME:
		if str(n.name).begins_with(str(pair[0])):
			return str(pair[1])
	if info is Dictionary:
		match str(info.get("kind", "")):
			"floor": return "deck"
			"door": return "door"
			"component", "mount": return "component"
	return "wall" if n is StaticBody3D else ""


## A flat CAD colour: lit, matt, a little self-lit so the far side of a room still reads.
func mat(c: Color, glow := 0.12) -> StandardMaterial3D:
	var key := "%s/%s" % [c.to_html(), glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		m.metallic = 0.0
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b) * glow
		if c.a < 0.99:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


func _edge_mat() -> StandardMaterial3D:
	if not _mats.has("edge"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = EDGE
		_mats["edge"] = m
	return _mats["edge"]


static func _see_through(m: Material) -> bool:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		return sm.shader != null and "glass" in sm.shader.resource_path.to_lower()
	return false


static func _part_colour(n: Node, rec: DesignRecord, catalog: DesignCatalog) -> Color:
	var id := str(n.name).trim_prefix("Part_").trim_prefix("Mount_")
	var c: Variant = rec.components.get(id, rec.mounts.get(id)) if rec else null
	if c is Dictionary:
		var pt := catalog.part(str(c.type))
		if pt:
			return Color(pt.colour.r, pt.colour.g, pt.colour.b)
	return CLASSES.component.colour
