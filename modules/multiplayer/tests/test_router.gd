extends ModuleTest
## Hosting over the internet: addresses the internet can't reach are spotted, the router is
## left alone while solo or with open_router off, and the crew tab says how to be reached.
##   tools/run_tests.sh multiplayer

const ROUTER := preload("res://modules/multiplayer/internal/net_router.gd")
const PORT := 24596


func run_tests() -> void:
	for ip in ["10.1.2.3", "192.168.0.4", "172.20.0.1", "100.70.1.1", "127.0.0.1"]:
		check(ROUTER.shared_address(ip), "%s can't be reached from the internet" % ip)
	for ip in ["81.2.69.160", "172.32.0.1", "100.128.0.1"]:
		check(not ROUTER.shared_address(ip), "%s is a real internet address" % ip)

	var net := Modules.bus("multiplayer") as MultiplayerBus
	check(net.router_info().state == "off", "router left alone in solo play")

	var saved := Flags.all()
	var was: Variant = Settings.get_value("multiplayer", "open_router")
	var port_was: Variant = Settings.get_value("multiplayer", "port")
	Settings.set_value("multiplayer", "port", PORT)
	Flags.set_flag(MultiplayerBus.ONLINE_FLAG, true)
	Settings.set_value("multiplayer", "open_router", false)
	var bus := MultiplayerBus.new()
	bus.name = "RouterBus"
	add_child(bus)
	bus.register_module()
	check(bus.host(PORT) == OK, "hosts")
	await frames(2)
	check(bus.router_info().state == "off", "open_router off: the router is not asked")
	var screen: Control = bus._crew_screen(true)
	add_child(screen)
	await frames(2)
	var note := str(screen.find_child("OnlineNote", true, false).text)
	check(note.contains("Same network") and note.contains(str(PORT)), "host told how crew reach them: %s" % note)
	check(screen.find_child("CrewCopyAddress", true, false) != null, "COPY button for the address")
	screen.queue_free()
	bus.leave()
	await frames(2)

	# With the router asked: on a machine with no UPnP router this ends "failed" with a reason.
	Settings.set_value("multiplayer", "open_router", true)
	check(bus.host(PORT) == OK, "hosts again")
	await frames(1)
	check(bus.router_info().state == "opening", "asks the router when hosting starts")
	var end := Time.get_ticks_msec() + 10000
	while bus.router_info().state == "opening" and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	var info := bus.router_info()
	check(info.state in ["open", "failed"], "router answer comes back: %s" % str(info))
	check(info.state == "open" or str(info.reason) != "", "a failure says why")
	bus.queue_free()
	Settings.set_value("multiplayer", "open_router", was)
	Settings.set_value("multiplayer", "port", port_was)
	Flags.use(saved)
