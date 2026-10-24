extends Node3D
## The upgrade plate as a thing on the unit: a brushed steel plate riveted to the housing,
## engraved with the serial, tier, grade and tested figures. A unit that failed its test gets
## a red reject tag with its first snag instead. Origin at the plate's back centre, facing +Z.

const STEEL := Color("b9bec4")
const TAG := Color("c8321e")
const INK := Color("1d2024")

var plate: UpgradePlate


func _init(p_plate: UpgradePlate) -> void:
	plate = p_plate
	name = "UpgradePlate"
	if plate.passed:
		_build_plate()
	else:
		_build_tag()


## The engraving, line by line (tests and the look hint read it).
func lines() -> PackedStringArray:
	if not plate.passed:
		return PackedStringArray(["REJECTED", _unit_words().to_upper(),
				str(plate.snags[0].get("text", "")) if not plate.snags.is_empty() else ""])
	var figures := PackedStringArray()
	for stat in plate.tested:
		if float(plate.tested[stat]) != float(plate.base.get(stat, 0.0)):
			figures.append(FieldSweep.stat_text(stat, float(plate.tested[stat])).to_upper())
	return PackedStringArray(["BSX LTD  ·  UPGRADE CERTIFIED", "%s  ·  TIER %d" % [_unit_words().to_upper(), plate.tier],
			"SERIAL %s   GRADE %s" % [plate.serial, plate.grade], "   ".join(figures)])


func look_hint() -> Dictionary:
	return {"title": "Upgrade plate" if plate.passed else "Reject tag", "text": "\n".join(lines())}


func _unit_words() -> String:
	return FieldSweep.part_words(plate.family if plate.family != "" else plate.unit_id)


func _build_plate() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.26, 0.15, 0.004)
	body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STEEL
	mat.metallic = 0.9
	mat.roughness = 0.35
	body.material_override = mat
	body.position.z = 0.002
	add_child(body)
	for x in [-0.118, 0.118]:
		for y in [-0.063, 0.063]:
			var rivet := MeshInstance3D.new()
			var dome := SphereMesh.new()
			dome.radius = 0.005
			dome.height = 0.005
			rivet.mesh = dome
			rivet.material_override = mat
			rivet.position = Vector3(x, y, 0.004)
			add_child(rivet)
	_engrave(lines(), INK, 0.15)


func _build_tag() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.12, 0.002)
	body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TAG
	mat.roughness = 0.8
	body.material_override = mat
	body.position.z = 0.001
	add_child(body)
	_engrave(lines(), Color.WHITE, 0.11)


func _engrave(text_lines: PackedStringArray, ink: Color, width: float) -> void:
	var l := Label3D.new()
	l.name = "Engraving"
	l.text = "\n".join(text_lines)
	l.font_size = 22
	l.pixel_size = 0.0004
	l.width = width / l.pixel_size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = ink
	l.outline_size = 0
	l.line_spacing = 2
	l.position.z = 0.0045
	add_child(l)
