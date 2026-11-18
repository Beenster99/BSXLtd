extends ModuleTest
## Void Salvage's components as BSX stocks and fits them (VsParts): every entry builds from Void
## Salvage's own code, weighs something, draws on the salvage surface with its zones, and makes
## a node to drop into a scene.
##   tools/run_tests.sh shared_components


func run_tests() -> void:
	check(VsParts.ids().size() >= 30, "a full stock of Void Salvage parts (%d)" % VsParts.ids().size())
	check(VsParts.ids("engines").has("HydrogenEngine"), "the engines include the hydrogen engine")
	check(not VsParts.has("Crate") and VsParts.shape("Crate") == null and VsParts.instance("Crate") == null,
			"an unknown id has no part")
	for id: String in VsParts.ids():
		var s := VsParts.shape(id)
		check(s != null and s.mesh != null and s.mesh.get_surface_count() > 0, "%s: Void Salvage builds it" % id)
		if s == null or s.mesh == null:
			continue
		check(s.collision != null, "%s: has collision for a hook or a rack" % id)
		var size := VsParts.size(id)
		check(size.x > 0.0 and size.y > 0.0 and size.z > 0.0 and size.length() < 12.0, "%s: a sensible size %s" % [id, size])
		check(VsParts.mass(id) >= 1.0, "%s: weighs something (%.0f kg)" % [id, VsParts.mass(id)])
		check(Materials.TABLE.has(VsParts.material_id(id)), "%s: made of a shared material" % id)
		check(VsParts.display_name(id) != "" and VsParts.category(id) != "", "%s: has a name and a category" % id)
		var mat := VsParts.surface(id)
		check(mat.shader == SurfaceFinish.surface_shader(false), "%s: drawn on Void Salvage's salvage surface" % id)
		var node := VsParts.instance(id)
		check(node != null and node.get_node_or_null("Body") is MeshInstance3D, "%s: makes a node with its body" % id)
		node.free()
	# The modelled components come through: a battery rack's look has finish zones in it.
	var zones := SurfaceZones.finishes_in(VsParts.shape("BatteryRack").mesh)
	check(zones.size() > 1, "the battery rack carries finish zones: %s" % [zones.keys()])
	check(VsParts.shape("Reactor") == VsParts.shape("Reactor"), "shapes are built once")
	check(VsParts.mass("Reactor") > VsParts.mass("JunctionBox"), "a reactor outweighs a junction box")
