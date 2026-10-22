extends ModuleTest
## Play Together on the title screen: the menu entry and scene are there while online play is
## on, and the screen has the name, Host, address and Join, keeps the name and refuses an
## empty address.
##   tools/run_tests.sh multiplayer


func run_tests() -> void:
	var online := Flags.is_on(MultiplayerBus.ONLINE_FLAG)
	var listed := Menu.entries().any(func(e: Dictionary) -> bool: return e.id == MultiplayerBus.PLAY_SCENE)
	check(listed == online, "Play Together on the title screen follows the online flag")
	check(Router.has_scene(MultiplayerBus.PLAY_SCENE) == online, "Play Together scene registered")
	if not online:
		return

	var name_was: Variant = Settings.get_value("multiplayer", "player_name")
	var screen: Control = load(Router.scene_path(MultiplayerBus.PLAY_SCENE)).instantiate()
	add_child(screen)
	await frames(2)
	for n in ["PlayerName", "Host", "Address", "Join", "Back"]:
		check(screen.find_child(n, true, false) != null, "screen has %s" % n)
	var host := screen.find_child("Host", true, false) as Button
	check(host.text.begins_with("Host  -  "), "Host says which game it hosts: %s" % host.text)
	(screen.find_child("PlayerName", true, false) as LineEdit).text = "Riveter Rae"
	(screen.find_child("Address", true, false) as LineEdit).text = "  "
	(screen.find_child("Join", true, false) as Button).pressed.emit()
	await frames(1)
	check(str(screen.find_child("Note", true, false).text).contains("address"), "an empty address is refused")
	var net := Modules.bus("multiplayer") as MultiplayerBus
	check(not net.is_online(), "nothing joined without an address")
	screen.queue_free()
	Settings.set_value("multiplayer", "player_name", name_was)
