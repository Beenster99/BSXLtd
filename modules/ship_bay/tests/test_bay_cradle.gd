extends ModuleTest
## Ship and Bay: the courtyard's ship stands on a small transport cradle ("BayCradle") the
## dolly can lift and drive away, the ship riding along.
##   tools/run_tests.sh ship_bay

const Dolly := preload("res://modules/ship_bay/internal/yard/dolly.gd")
const Cradle := preload("res://modules/ship_bay/internal/yard/transport_cradle.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var flags := ["ship_bay.apron", "ship_bay.dolly", "ship_bay.bay_cradle"]
	var was := flags.map(func(f: String) -> bool: return Flags.is_on(f))
	for f: String in flags:
		Flags.set_flag(f, true)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var tr: Node3D = yard.get("transporters")
	var bay: Node3D = yard.find_child("Bay", true, false) as Node3D
	if bay == null:
		for n in yard.find_children("*", "Node3D", true, false):
			if n.get("cradle") is Cradle:
				bay = n
				break
	check(tr != null and bay != null, "the yard has its transporters and bay")
	if tr == null or bay == null:
		yard.queue_free()
		return
	yard.call("set_walker_active", false)
	(yard.get("walker") as Node3D).global_position = Vector3(0, 0, 10)
	var c: Cradle = bay.get("cradle")
	check(c != null and c.size == "s" and c.load_node == bay.get("ship_root"), "the ship stands on a small cradle")
	check(tr.call("cradle", "BayCradle") == c, "the transporters know the bay's cradle")
	var d: Dolly = tr.get("transporters")["dolly"]
	d.accel = 4.0
	d.lift_speed = 1.0
	tr.call("toggle_remote", "dolly")
	var home := c.global_transform
	var before := bus.ship_transform(yard)
	d.global_transform = Transform3D(Basis(), Vector3(home.origin.x, 0, home.origin.z - 0.8))
	await frames(2)
	check(bool(tr.call("aligned", d, c)), "the dolly lines up under its pins")
	await _hold("ship_bay.dolly_up", 60)
	for i in 4:
		tr.call("throw_pin", str(c.name), i)
	await _hold("ship_bay.dolly_up", 60)
	check(d.load_cradle == c, "the dolly lifts the bay cradle: %s" % d.stopped)
	var lifted := bus.ship_transform(yard)
	var access: Node3D = bay.get("access")
	var plug: Node3D = access.get("plug") if access else null
	var plug_was := plug.global_position if plug else Vector3.ZERO
	check(lifted.origin.y > before.origin.y + 0.3, "the ship rises with it: %.2f -> %.2f" % [before.origin.y, lifted.origin.y])
	await _hold("ship_bay.dolly_ahead", 60)
	var moved := bus.ship_transform(yard)
	check(moved.origin.z < lifted.origin.z - 0.5, "and rides along when it drives: %s, %s" % [moved.origin - lifted.origin, d.stopped])
	if plug and str(access.get("plug_state")) == "hull":
		check(plug.global_position.distance_to(plug_was) > 0.4, "the power plug on the hull rides along with it")
	var saved: Dictionary = bus.snapshot().get("transport", {})
	check((saved.get("cradles", {}) as Dictionary).has("BayCradle"), "where the bay cradle is goes in the save")
	d.halt()
	yard.queue_free()
	await frames(2)
	for i in flags.size():
		Flags.set_flag(flags[i], was[i])
	bus.reset_data()


func _hold(action: String, n: int) -> void:
	Input.action_press(action)
	for i in n:
		await get_tree().physics_frame
	Input.action_release(action)
