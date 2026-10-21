extends ModuleTest
## You on foot in the yard (beenster's 0.3.6 list): Space jumps, a ladder climbs, and when a
## yard screen hands the yard's own walker back on closing, Tools takes the view back so you
## aren't left at the start point with the worker's hands floating where you stood. The HUD's
## text goes to UI's right-hand panel; a screen holding the mouse, or a trolley driven on
## remote, keeps the worker's hands and feet still.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""


func run_tests() -> void:
	var saved := {}
	for flag: String in ["trades.shipyard", "trades.jump"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	(Modules.bus("ship_bay") as ShipBayBus).load_ship("vs_kestrel")
	var yard := _fake_yard()
	add_child(yard)
	(Modules.bus("trades") as TradesBus)._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	var worker := rig.worker
	var walker := yard.get("walker") as CharacterBody3D

	# A yard screen closes and hands the walker back: Tools takes the yard again.
	check(not bool(yard.get("walker_active")), "in the yard the worker is you; the yard's walker is stood down")
	yard.call("set_walker_active", true)
	walker.get_node("Camera3D").set("current", true)
	await frames(2)
	check(not bool(yard.get("walker_active")) and worker.camera.current,
			"a screen handing the walker back doesn't move you: the worker keeps the view")

	# Stand on the floor away from everything, then jump.
	worker.global_position = Vector3(20, 0.05, 20)
	await physics(20)
	check(worker.is_on_floor(), "standing on the floor")
	var ground := worker.global_position.y
	Input.action_press(Keys.JUMP)
	var top := ground
	for i in 20:
		await physics(1)
		top = maxf(top, worker.global_position.y)
	Input.action_release(Keys.JUMP)
	check(top - ground > 0.35, "Space jumps (up %.2f m)" % (top - ground))
	await physics(60)
	check(worker.is_on_floor() and absf(worker.global_position.y - ground) < 0.05, "and you land again")

	# Without the flag's say-so, no jumping.
	worker.agile = false
	Input.action_press(Keys.JUMP)
	await physics(10)
	Input.action_release(Keys.JUMP)
	check(absf(worker.global_position.y - ground) < 0.02, "with trades.jump off, Space does nothing")
	worker.agile = true

	# On a ladder: forward climbs, back climbs down, stepping off the top puts you on the deck.
	worker.set_ladder(1)
	check(worker.on_ladder(), "in a ladder's climbing space")
	Input.action_press(Keys.FORWARD)
	await physics(60)
	Input.action_release(Keys.FORWARD)
	var climbed := worker.global_position.y - ground
	check(climbed > 1.2 and Vector2(worker.global_position.x - 20, worker.global_position.z - 20).length() < 0.05,
			"forward climbs straight up the ladder (%.2f m)" % climbed)
	await physics(20)
	check(absf(worker.global_position.y - ground - climbed) < 0.05, "let go and you hold on where you are")
	Input.action_press(Keys.BACK)
	await physics(20)
	Input.action_release(Keys.BACK)
	check(worker.global_position.y - ground < climbed - 0.3, "back climbs down")
	var deck := Vector3(21, 2.5, 20)
	worker.set_ladder(-1, deck)
	check(not worker.on_ladder() and worker.global_position.is_equal_approx(deck), "out of the top: onto the deck")

	# The tool, what you're on and the keys are cards in the right-hand panel.
	await frames(2)
	var ids := HudSlots.infos().map(func(c: Dictionary) -> String: return c.id)
	check(ids.has(TradesBay.INFO_TOOL) and ids.has(TradesBay.INFO_KEYS), "the tool and keys are cards in the right-hand panel")
	var keys_card: Dictionary = HudSlots.infos().filter(func(c: Dictionary) -> bool: return c.id == TradesBay.INFO_KEYS)[0]
	check(Keys.key_name(Keys.JUMP) in keys_card.text, "the keys card names the jump key")

	# A screen with the mouse: clicks don't use a tool.
	rig.set_tool(&"tractor")
	HudSlots.claim_pointer("test")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	rig._handle_input(click)
	check(rig.get("_pressed") == null, "while a screen has the mouse, a click doesn't use the tool")
	HudSlots.release_pointer("test")
	rig._handle_input(click)
	check(rig.get("_pressed") != null, "and once it lets go, it does")
	click.pressed = false
	rig._handle_input(click)

	# Driving a trolley on remote: W A S D are the trolley's.
	var ship_bus := Modules.bus("ship_bay")
	worker.global_position = Vector3(20, 0.05, 20)
	await physics(10)
	var stood := worker.global_position
	ship_bus.set("remote_driving", true)
	await frames(1)
	Input.action_press(Keys.FORWARD)
	await physics(20)
	Input.action_release(Keys.FORWARD)
	ship_bus.set("remote_driving", false)
	check(Vector2(worker.global_position.x - stood.x, worker.global_position.z - stood.z).length() < 0.02,
			"driving a trolley on remote, the worker stands still")
	await frames(1)

	yard.queue_free()
	await frames(1)
	check(not HudSlots.infos().any(func(c: Dictionary) -> bool: return String(c.id).begins_with("trades.")),
			"leaving the yard takes Tools' cards away")
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _fake_yard() -> Node3D:
	var script := GDScript.new()
	script.source_code = FAKE_YARD
	script.reload()
	var yard := Node3D.new()
	yard.set_script(script)
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 12)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	walker.add_child(cam)
	yard.set("walker", walker)
	yard.add_child(walker)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.2, 80)
	floor_shape.shape = box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	yard.add_child(floor_body)
	return yard
