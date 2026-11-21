extends ModuleTest
## The bots' charger racks (0.4.4 playtest: "drones should home on charger racks"): every
## stores and yard bot has its own pad, sits on it when idle with its fans still and its strip
## lit, and goes back to it after work.
##   tools/run_tests.sh yard

const Racks := preload("res://modules/yard/internal/charger_racks.gd")


func run_tests() -> void:
	var saved := Flags.all()
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING, YardBus.CHARGER_RACKS]:
		Flags.set_flag(f, true)
	var s := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(s)
	(s.get("sim") as Node).set_process(false)
	var traffic: Node = s.get("traffic")
	var racks: Node3D = traffic.get("racks")
	check(racks != null, "the racks are built")
	var bots: Array = traffic.get("bots")
	var homes := {}
	for b: Dictionary in bots:
		homes[str(b.home)] = true
	check(homes.size() == bots.size(), "a pad each (%d homes, %d bots)" % [homes.size(), bots.size()])
	var apart := true
	for i in bots.size():
		for j in range(i + 1, bots.size()):
			var a: Vector3 = bots[i].home
			var b: Vector3 = bots[j].home
			if absf(a.x - b.x) < 2.2 and absf(a.y - b.y) < 0.8 and absf(a.z - b.z) < 2.2:
				apart = false
	check(apart, "no two bots on top of each other")
	check(Racks.home(0, false).z > -10.0 and Racks.home(0, false).x > YardRackStore.UPPER_EDGE_X,
			"the stores' rack is on the back wall of the well")
	# Slim steel (0.5.1 playtest: "these racks are excessively large"): no flat sheet, nothing but
	# the pads over 0.5 m across in two directions.
	var big := []
	for m: Node in racks.find_children("*", "MeshInstance3D", true, false):
		var bm := (m as MeshInstance3D).mesh as BoxMesh
		if bm == null or String(m.name).contains("Pad") or (m as MeshInstance3D).global_position.y < 5.0:
			continue
		var sz := bm.size
		var dims := [sz.x, sz.y, sz.z]
		dims.sort()
		if dims[0] < 0.01 or dims[1] > 0.5:
			big.append("%s %s" % [m.name, sz])
	check(big.is_empty(), "the wall rack is slim steel %s" % [big.slice(0, 4)])
	traffic.call("step", 0.02)
	var lit := 0
	for b: Dictionary in bots:
		if Racks.docked(b):
			lit += 1
	check(lit == bots.size(), "all on their pads at the start (%d)" % lit)
	var rotor := (bots[0].node as Node3D).get_node_or_null("Rotor0") as Node3D
	var turn := rotor.rotation.y if rotor else 0.0
	traffic.call("step", 0.5)
	check(rotor != null and is_equal_approx(rotor.rotation.y, turn), "fans still on the charger")
	# An order: bots go to work and come home again.
	traffic.call("order", [{"part": "HullPlate", "qty": 2}])
	var left := false
	for i in 9000:
		traffic.call("step", 1.0 / 30.0)
		if not left:
			for b: Dictionary in bots:
				if not b.has("hauler") and not Racks.docked(b):
					left = true
		elif not bool(traffic.call("busy")):
			break
	check(left, "bots leave their pads for work")
	for i in 1800:
		traffic.call("step", 1.0 / 30.0)
	var home_again := 0
	var stores := 0
	for b: Dictionary in bots:
		if b.has("hauler"):
			continue
		stores += 1
		if Racks.docked(b):
			home_again += 1
	check(home_again == stores, "and all go home to charge after (%d of %d)" % [home_again, stores])
	s.queue_free()
	await frames(2)
	Flags.use(saved)
