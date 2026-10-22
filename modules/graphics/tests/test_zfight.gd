extends ModuleTest
## G5, the Z-fighting checker: it finds two faces in one plane that overlap, not ones lifted
## 0.6 mm apart, back to back, side by side, buried in a box or marked "gfx_coplanar_ok";
## and every scene with screenshot points stays within its budget of flickering pairs.
##   tools/run_tests.sh graphics

## Flickering pairs each scene has today. Lower a budget when its owner fixes some (the test
## says so); a scene over budget fails with the new pairs listed.
const BUDGET := {
	"ship_bay.shipyard": 1,
}


func run_tests() -> void:
	var bus := Modules.bus("graphics") as GfxBus
	var root := Node3D.new()
	add_child(root)
	var floor_box := _box(root, Vector3(10, 0.2, 10), Vector3(0, -0.1, 0))
	var mat := _box(root, Vector3(2, 0.0, 2), Vector3(1, 0.0, 1))           # flush on the floor
	var lifted := _box(root, Vector3(2, 0.0, 2), Vector3(-3, 0.0006, -3))   # lifted 0.6 mm
	var beside := _box(root, Vector3(2, 0.0, 2), Vector3(7, 0.0, 7))        # off the floor's edge
	var hits := bus.zfight_scan(root)
	check(hits.size() == 1, "one flickering pair: %s" % bus.describe_zfights(hits))
	if hits.size() == 1:
		var h: Dictionary = hits[0]
		check([h.a, h.b].has(floor_box.get_path()) and [h.a, h.b].has(mat.get_path()), "the mat lying flush on the floor")
		check(is_equal_approx(float(h.area), 4.0), "its whole 4 m² overlap")
		check((h.normal as Vector3).is_equal_approx(Vector3.UP), "on the floor's top")
	check(not _names(hits).has(lifted.get_path()), "a layer lifted 0.6 mm is fine")
	check(not _names(hits).has(beside.get_path()), "faces that don't overlap are fine")
	mat.set_meta("gfx_coplanar_ok", true)
	check(bus.zfight_scan(root).is_empty(), "gfx_coplanar_ok lets a decal lie flush")
	# Two boxes back to back share a plane but face away from each other: no flicker.
	var a := _box(root, Vector3(1, 1, 1), Vector3(20, 0.5, 0))
	_box(root, Vector3(1, 1, 1), Vector3(21, 0.5, 0))
	var faces := bus.zfight_scan(a)
	check(faces.is_empty(), "back to back is fine")
	# Two overlapping faces inside a third, solid box are hidden.
	var hidden := Node3D.new()
	hidden.position = Vector3(40, 0, 0)
	root.add_child(hidden)
	_box(hidden, Vector3(1, 0.0, 1), Vector3(0, 1, 0))
	_box(hidden, Vector3(1, 0.0, 1), Vector3(0.2, 1, 0))
	check(bus.zfight_scan(hidden).size() == 1, "two flush plates flicker in the open")
	_box(hidden, Vector3(3, 3, 3), Vector3(0, 1, 0))
	check(bus.zfight_scan(hidden).is_empty(), "but not buried inside a solid box")
	root.queue_free()

	# Every scene with screenshot points, as it loads.
	var done := {}
	for shot in Shots.all():
		var id: String = shot.scene
		if done.has(id) or not Router.has_scene(id):
			continue
		done[id] = true
		var packed := load(Router.scene_path(id)) as PackedScene
		if packed == null:
			continue
		var scene := packed.instantiate()
		if not scene is Node3D:
			scene.free()
			continue
		add_child(scene)
		await frames(5)
		var found := bus.zfight_scan(scene)
		var budget := int(BUDGET.get(id, 0))
		check(found.size() <= budget, "%s: %d flickering pairs, budget %d. Lift one face 0.6 mm or mark a decal gfx_coplanar_ok:\n%s"
				% [id, found.size(), budget, bus.describe_zfights(found, 12)])
		if found.size() < budget:
			print("%s: %d flickering pairs, under its budget of %d: lower BUDGET in test_zfight.gd" % [id, found.size(), budget])
		scene.queue_free()
		await frames(2)


func _box(parent: Node3D, size: Vector3, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = at
	parent.add_child(m)
	return m


func _names(hits: Array[Dictionary]) -> Array:
	var out := []
	for h in hits:
		out.append(h.a)
		out.append(h.b)
	return out
