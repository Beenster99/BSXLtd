extends ModuleTest
## Ship and Bay: fastener rings show only near the point a player aims at
## (ShipBayBus.set_marker_focus), so a ship full of bolts and rivets isn't a field of green and
## amber; the heads always show. INF shows every ring again.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.set_marker_focus(Vector3.ZERO, INF)
	var view := (load("res://modules/ship_bay/internal/bay/bay.tscn") as PackedScene).instantiate() as Node3D
	add_child(view)
	await frames(2)
	var markers: Dictionary = view.get("markers")
	check(markers.size() > 100, "the bay marks every fastener: %d" % markers.size())
	var shown := func() -> int:
		return markers.values().filter(func(m: MeshInstance3D) -> bool: return m.mesh != null).size()
	check(shown.call() == markers.size(), "with no focus every ring shows")
	# Aim at the port engine's first fastener.
	var f: FastenerPoint = bus.get_fasteners("eng_port")[0]
	var root: Node3D = view.get("ship_root")
	var at := root.global_transform * f.position
	bus.set_marker_focus(at, 2.0)
	var near: MeshInstance3D = markers[f.joint_id]
	check(near.mesh != null, "the aimed-at fastener's ring shows")
	var far_hidden := 0
	var far_count := 0
	var heads_kept := true
	for id: String in markers:
		var m: MeshInstance3D = markers[id]
		if m.position.distance_to(f.position) > 2.0:
			far_count += 1
			far_hidden += 1 if m.mesh == null else 0
			if m.visible:   # (an empty slot's fasteners hide whole)
				heads_kept = heads_kept and (m.get_child(0) as MeshInstance3D).mesh != null
	check(far_count > 0 and far_hidden == far_count, "rings further than 2 m hide: %d of %d" % [far_hidden, far_count])
	check(heads_kept, "but their heads still show")
	check(shown.call() < markers.size() / 2, "most of the ship's rings are off: %d shown" % shown.call())
	# A small move does nothing; a bigger one moves the focus.
	bus.set_marker_focus(at + Vector3(0.05, 0, 0), 2.0)
	check(bus.marker_focus_at == at, "a nudge under the step keeps the rings as they are")
	bus.set_marker_focus(Vector3.ZERO, INF)
	check(shown.call() == markers.size(), "INF shows them all again")
	view.queue_free()
	await frames(1)
