class_name SurfaceScans
extends RefCounted
## Scanned surface layers (trial: docs/review/SCAN_MATERIALS.md). The look lab's photo-scanned PBR
## sets (assets/materials/, ambientCG, CC0) drawn under the salvage surface's own looks: each
## finish names a BASE scan (its micro detail on the finish's own colour), the BARE metal its chips
## and scratches show and the RUST its age brings (MAP). The game's wear still decides where paint
## gives way and rust creeps (shaders/salvage_surface.gdshader); the scans only give those places
## real metal, rust and paint to show. Laid on hexagons in the part's own space by metres
## (shaders/scan_layers.gdshaderinc), so nothing repeats. Look only.
##
## Per wreck (Dan, 12 Nov: "I wanted to pick materials per wreck, for variety"): only a design listed
## in DESIGNS draws scans, with its own picks over the house's (MAP); every other wreck, the crew's
## ships and the stations draw as before. `dress` gives a wreck's surfaces their scans at the end of
## her build (WreckShip), on every machine alike (the look only, nothing sent). The three maps of
## every set in SETS go into three texture arrays once the first such wreck is built (about 10.7 MB
## of video memory a set).

## False: no wreck draws scans (a capture's `--no-scans`, for the before shots).
static var enabled: bool = true

## The designs that draw scans, each with its own picks: finish id -> an entry as in MAP (a
## finish it leaves out takes the house's). The armoured transport: charcoal paint over steel with
## heavy rust, her armour and frame in dark worn steel with patchy rust, tread decks, worn
## galvanised gratings (docs/review/SCAN_MATERIALS.md).
const DESIGNS: Dictionary = {
	"armoured_transport": {
		"satin_paint": ["metal038", 0.55, 0.35, 0.5, "metal062c", "metal025", 0.0, 0.9, 1.0, 0.0],
		"gunmetal": ["metal063", 1.0, 0.8, 1.0, "metal038", "metal026", 0.5, 0.9, 1.0, 0.0],
		"tread_diamond_steel": ["diamondplate005d", 1.0, 1.0, 1.0, "metal038", "metal053c", 0.4, 0.8, 1.0, 1.0],
		"galvanised": ["metal039", 1.0, 0.7, 0.8, "metal039", "metal053c", 0.7, 0.8, 1.0, 0.0],
	},
}

## The sets in the arrays, in layer order: [folder in assets/materials, m one repeat covers, how it
## may turn on its hexagons (0 shifted only: brushed lines keep their way; 1 quarter turns; 2 any
## angle), the blur mip its colour is held against (bigger keeps broader detail)].
const SETS: Array = [
	["metal038", 1.2, 2, 6.0],          # 0 worn grey steel: painted steel's micro detail, bare steel
	["metal025", 1.6, 2, 7.0],          # 1 heavy rust
	["metal053c", 1.4, 2, 7.0],         # 2 rust over bare steel
	["metal063", 1.2, 2, 6.0],          # 3 dark worn steel: gunmetal, armour
	["metal039", 1.0, 2, 6.0],          # 4 worn galvanised steel
	["metal062c", 1.0, 2, 6.5],         # 5 pitted steel: bare and cast metal, heat-worked steel
	["diamondplate005d", 1.1, 1, 5.0],  # 6 diamond tread plate, bare
	["metal010", 0.8, 0, 6.0],          # 7 brushed steel
	["metal057c", 1.0, 2, 6.0],         # 8 copper
	["plastic012b", 0.6, 2, 6.0],       # 9 textured plastic
	["rubber004", 0.6, 2, 6.0],         # 10 rubber
	["metal033", 1.0, 2, 6.0],          # 11 blue-grey steel: titanium, anodised alloy
	["metal026", 1.6, 2, 7.0],          # 12 rusted steel, patchy
]

## The house's picks: finish id -> [base set, colour strength, normal strength, roughness strength, bare set, rust set,
## hue kept (0 lightness only .. 1 its colour), rust's normal strength, tile scale, raised]. A set
## is a folder from SETS ("" none). "" (the key) is "as built": a part's own paint.
const PAINT := ["metal038", 0.55, 0.35, 0.5, "metal062c", "metal025", 0.0, 0.9, 1.0, 0.0]
const MAP: Dictionary = {
	"": PAINT, "gloss_paint": ["metal038", 0.35, 0.2, 0.3, "metal062c", "metal025", 0.0, 0.9, 1.0, 0.0],
	"satin_paint": PAINT, "enamel": ["metal038", 0.35, 0.2, 0.3, "metal062c", "metal025", 0.0, 0.9, 1.0, 0.0],
	"metallic_paint": PAINT, "hazard_paint": PAINT, "hazard_stripes": PAINT,
	"bare_steel": ["metal062c", 0.9, 0.8, 0.8, "metal062c", "metal053c", 0.5, 0.9, 1.0, 0.0],
	"brushed_steel": ["metal010", 0.8, 0.6, 0.6, "metal010", "metal053c", 0.4, 0.8, 1.0, 0.0],
	"polished_steel": ["metal010", 0.5, 0.3, 0.3, "metal010", "metal053c", 0.4, 0.8, 1.0, 0.0],
	"stainless": ["metal010", 0.6, 0.4, 0.4, "metal010", "", 0.4, 0.0, 1.0, 0.0],
	"gunmetal": ["metal063", 1.0, 0.8, 1.0, "metal038", "metal026", 0.5, 0.9, 1.0, 0.0],
	"galvanised": ["metal039", 1.0, 0.7, 0.8, "metal039", "metal053c", 0.7, 0.8, 1.0, 0.0],
	"cast_iron": ["metal062c", 1.0, 1.0, 0.8, "metal062c", "metal025", 0.3, 1.0, 0.6, 0.0],
	"dense_cast": ["metal062c", 0.9, 1.0, 0.8, "metal062c", "", 0.3, 0.0, 0.6, 0.0],
	"heat_shield": ["metal062c", 0.8, 0.7, 0.6, "metal062c", "", 0.3, 0.0, 0.8, 0.0],
	"blued_steel": ["metal062c", 0.7, 0.6, 0.6, "metal062c", "metal053c", 0.3, 0.8, 1.0, 0.0],
	"titanium": ["metal033", 0.7, 0.5, 0.6, "metal033", "", 0.3, 0.0, 1.0, 0.0],
	"anodised": ["metal033", 0.5, 0.3, 0.5, "metal010", "", 0.0, 0.0, 1.0, 0.0],
	"brushed_alloy": ["metal010", 0.6, 0.5, 0.5, "metal010", "", 0.3, 0.0, 1.0, 0.0],
	"copper": ["metal057c", 1.0, 0.5, 0.8, "metal057c", "", 1.0, 0.0, 1.0, 0.0],
	"plastic": ["plastic012b", 0.5, 0.5, 0.6, "", "", 0.0, 0.0, 1.0, 0.0],
	"plastic_gloss": ["plastic012b", 0.3, 0.25, 0.3, "", "", 0.0, 0.0, 1.0, 0.0],
	"plastic_textured": ["plastic012b", 0.8, 0.9, 0.8, "", "", 0.0, 0.0, 0.5, 0.0],
	"rubber": ["rubber004", 0.6, 0.6, 0.6, "", "", 0.0, 0.0, 1.0, 0.0],
	"foam": ["rubber004", 0.6, 0.8, 0.6, "", "", 0.0, 0.0, 1.0, 0.0],
	"tread_diamond": ["diamondplate005d", 1.0, 1.0, 1.0, "metal038", "metal025", 0.0, 0.8, 1.0, 1.0],
	"tread_diamond_steel": ["diamondplate005d", 1.0, 1.0, 1.0, "metal038", "metal053c", 0.4, 0.8, 1.0, 1.0],
	"tread_diamond_paint": ["diamondplate005d", 0.8, 1.0, 0.8, "metal038", "metal025", 0.0, 0.8, 1.0, 1.0],
	"hazard_tread": ["diamondplate005d", 0.8, 1.0, 0.8, "metal038", "metal025", 0.0, 0.8, 1.0, 1.0],
}

## Rows and texels of `table_for()`: row = finish code (SurfaceFinish), three texels.
const ROWS: int = 64
const TEXELS: int = 3

static var _albedo: Texture2DArray
static var _normal: Texture2DArray
static var _orm: Texture2DArray
static var _tables: Dictionary = {}   # design id -> its lookup texture


## The layer of set `folder` (-1 for none or unknown).
static func layer_of(folder: String) -> int:
	for i in SETS.size():
		if SETS[i][0] == folder:
			return i
	return -1


## Design `design_id`'s picks: the house's (MAP) with its own (DESIGNS) over them.
static func picks(design_id: String) -> Dictionary:
	var out: Dictionary = MAP.duplicate()
	out.merge(DESIGNS.get(design_id, {}), true)
	return out


## Whether design `design_id` draws scans.
static func scanned(design_id: String) -> bool:
	return enabled and DESIGNS.has(design_id)


## Design `design_id`'s lookup texture: row = finish code; texels 0 (base layer + 1, colour,
## normal, roughness), 1 (bare layer + 1, rust layer + 1, hue, rust normal), 2 (tile scale,
## raised, 0, 0).
static func table_for(design_id: String) -> ImageTexture:
	if not _tables.has(design_id):
		var img := Image.create(TEXELS, ROWS, false, Image.FORMAT_RGBAF)
		var map := picks(design_id)
		for id: String in map:
			var row := SurfaceFinish.code(id) if id != "" else 0
			if id != "" and row == 0:
				continue
			var e: Array = map[id]
			img.set_pixel(0, row, Color(float(layer_of(e[0]) + 1), e[1], e[2], e[3]))
			img.set_pixel(1, row, Color(float(layer_of(e[4]) + 1), float(layer_of(e[5]) + 1), e[6], e[7]))
			img.set_pixel(2, row, Color(e[8], e[9], 0.0, 0.0))
		_tables[design_id] = ImageTexture.create_from_image(img)
	return _tables[design_id]


static func _array(kind: String) -> Texture2DArray:
	var images: Array[Image] = []
	for s: Array in SETS:
		var tex: Texture2D = load("res://assets/materials/%s/%s_2048_%s.jpg" % [s[0], s[0], kind])
		images.append(tex.get_image())
	var arr := Texture2DArray.new()
	var err := arr.create_from_images(images)
	if err != OK:
		push_error("SurfaceScans: could not make the %s array (%d)" % [kind, err])
	return arr


## Gives every salvage surface under `body` (a wreck of design `design_id`, at the end of her build)
## its scans: each material she draws with is swapped for a copy carrying them (one copy per
## material, so another wreck sharing it is untouched); copies made later (a part's condition, a
## scheme's finish, a merged look) keep them. Nothing for a design not in DESIGNS. Returns how many
## materials were given scans.
static func dress(body: Node, design_id: String) -> int:
	if not scanned(design_id):
		return 0
	var made: Dictionary = {}   # material instance id -> its copy with scans
	for n: Node in body.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.material_override is ShaderMaterial:
			var c := _dressed(g.material_override as ShaderMaterial, design_id, made)
			if c != null:
				g.material_override = c
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i)
			if m == null:
				m = mi.mesh.surface_get_material(i)
			if m is ShaderMaterial:
				var c := _dressed(m as ShaderMaterial, design_id, made)
				if c != null:
					mi.set_surface_override_material(i, c)
	body.set_meta("scans", design_id)
	return made.size()


## A salvage surface's copy with design `design_id`'s scans (cached in `made`), or null for a
## material that isn't one.
static func _dressed(m: ShaderMaterial, design_id: String, made: Dictionary) -> ShaderMaterial:
	if m.shader != SurfaceFinish.surface_shader(false) and m.shader != SurfaceFinish.surface_shader(true):
		return null
	if m.get_shader_parameter("scan_on") == true:
		return null   # a copy made by this dress already
	var key := m.get_instance_id()
	if not made.has(key):
		var c := SurfaceFinish.copy_surface(m)
		c.next_pass = m.next_pass
		apply(c, design_id)
		made[key] = c
	return made[key]


## Puts design `design_id`'s scans on a salvage surface material.
static func apply(m: ShaderMaterial, design_id: String) -> void:
	if _albedo == null:
		_albedo = _array("color")
		_normal = _array("normal")
		_orm = _array("orm")
	m.set_shader_parameter("scan_on", true)
	m.set_shader_parameter("scan_albedo", _albedo)
	m.set_shader_parameter("scan_normal", _normal)
	m.set_shader_parameter("scan_orm", _orm)
	m.set_shader_parameter("scan_table", table_for(design_id))
	var layers: Array[Vector4] = []
	for i in 16:
		if i < SETS.size():
			layers.append(Vector4(SETS[i][1], SETS[i][2], SETS[i][3], 0.0))
		else:
			layers.append(Vector4(1.0, 0.0, 6.0, 0.0))
	m.set_shader_parameter("scan_layer", layers)
