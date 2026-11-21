extends Node
## The help chapters' pictures (run under a display, a few minutes):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       res://modules/help/internal/tools/help_shots.tscn -- --out=/abs/dir [--dump] [--install]
## Stages a yard part-way through a ship contract (cash, the sample design open, a signed
## order, a build in the berth with parts on order, a few bots), puts each wrist screen up on a
## terminal as the wrist shows it, rings the buttons and figures its chapter talks about
## (numbered as the chapter's callouts are) and saves <shot>.png. --install also writes them
## where the game reads them (HelpShots.DIR, as .webp). --dump writes <shot>.txt: every text on
## the screen with its place, to find what to ring.

const Shots := preload("res://modules/help/internal/help_shots_data.gd")
const Ring := preload("res://modules/help/internal/tools/help_ring.gd")

const SIZE := Vector2i(1600, 1000)

var out := "user://help_shots"
## Over everything (the design room's console has a layer of its own).
var overlay: CanvasLayer
var dump := false
var install := false


func _ready() -> void:
	# The run lives on the root: the design room replaces the scene this starts in.
	if get_parent() != get_tree().root or name != "HelpShotsRunner":
		var runner := Node.new()
		runner.name = "HelpShotsRunner"
		runner.set_script(get_script())
		get_tree().root.add_child.call_deferred(runner)
		return
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		dump = dump or arg == "--dump"
		install = install or arg == "--install"
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(SIZE)
	get_tree().root.size = SIZE
	overlay = CanvasLayer.new()
	overlay.layer = 120
	add_child(overlay)
	if not Modules.ready_done:
		await Modules.modules_ready
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	await _console_shots(only)
	await _stage()
	var back := ColorRect.new()
	back.color = Color(0.03, 0.04, 0.06)
	back.size = Vector2(SIZE)
	overlay.add_child(back)
	for shot: Dictionary in Shots.SHOTS:
		if only != "" and not str(shot.id).begins_with(only):
			continue
		if not shot.has("channel"):
			continue
		if HudSlots.holo_channel(str(shot.channel)).is_empty():
			print("HelpShots: no channel ", shot.channel)
			continue
		var term := HoloTerminal.new(false, "WRIST TERMINAL")
		term.size = Vector2(SIZE) - Vector2(40, 40)
		term.position = Vector2(20, 20)
		back.add_child(term)
		term.show_channel(str(shot.channel))
		await _frames(6)
		var screen := term.content.get_child(0) as Control
		for step: Array in shot.get("do", []):
			_do(screen, step)
			await _frames(4)
		await _frames(6)
		var ring := Ring.new()
		ring.size = Vector2(SIZE)
		overlay.add_child(ring)
		await _ring_and_save(shot, term, ring)
		term.queue_free()
		await _frames(2)
	get_tree().quit()


func _ring_and_save(shot: Dictionary, root: Control, ring: Control) -> void:
	var missing: Array = ring.call("mark", root, shot.get("ring", []))
	for m in missing:
		print("HelpShots: %s: no '%s' on screen" % [shot.id, m])
	await _frames(2)
	await _save(str(shot.id), shot.get("crop", []))
	if dump:
		_dump(root, str(shot.id))
	ring.queue_free()


func _shot(id: String) -> Dictionary:
	for s: Dictionary in Shots.SHOTS:
		if str(s.id) == id:
			return s
	return {"id": id}


## The design console at the holotable: the sample open, the client orders, an order picked with
## its quote, the contract's payments, then signed.
func _console_shots(only: String) -> void:
	var design := Modules.bus("design")
	if design:
		design.call("open_sample")
	Router.goto("design.room")
	await _frames(30)
	var room: Node = get_tree().current_scene
	var console: Control = room.get("console")
	var contracts := Modules.bus("contracts")
	if console == null or contracts == null:
		print("HelpShots: no design console")
		return
	# The layout as a new player sees it (the last run saved its folds).
	if console.has_method("reset_layout"):
		console.call("reset_layout")
	var steps := [["console", func() -> void: pass],
		["console_orders", func() -> void:
			# The CONTRACT panel (folded at first, bottom right) opened up, the views folded.
			var panels: Dictionary = console.get("panels")
			if panels.has("contract"):
				panels.contract.call("set_collapsed", false)
			for id: String in ["views", "holo", "data"]:
				if panels.has(id):
					panels[id].call("set_collapsed", true)
			console.set("_orders_open", true)
			console.call("_fill_palette")],
		["console_quote", func() -> void:
			for o: Dictionary in contracts.call("ship_orders"):
				if str(contracts.call("ship_sign_problem", o)) == "":
					console.set("_orders_open", false)
					console.call("set_order", o)
					break],
		["console_terms", func() -> void: console.call("toggle_contract_terms")],
		["console_signed", func() -> void:
			console.call("toggle_contract_terms")
			var send := console.find_child("SendQuote", true, false) as Button
			if send:
				send.pressed.emit()
			# The frame done: the keel's gate ready to sign.
			for c: Dictionary in contracts.call("ship_contracts"):
				contracts.call("request_ship_stage", str(c.id), "keel")
			console.call("_fill_palette")],
	]
	for st: Array in steps:
		(st[1] as Callable).call()
		await _frames(25)
		if only != "" and not str(st[0]).begins_with(only):
			continue
		var ring := Ring.new()
		ring.size = Vector2(SIZE)
		overlay.add_child(ring)
		await _ring_and_save(_shot(str(st[0])), console, ring)


## The yard part-way through its first big contract.
func _stage() -> void:
	var biz := Modules.bus("business")
	var design := Modules.bus("design")
	var build := Modules.bus("build")
	var orders := Modules.bus("orders")
	var contracts := Modules.bus("contracts")
	var supply := Modules.bus("supply")
	Flags.set_flag("company.growth", false)
	if biz:
		biz.call("credit", 4_000_000, "capture", "Opening balance")
	if design:
		design.call("open_sample")
	if supply:
		supply.call("set_standing", "tarrow", 58)
		supply.call("set_standing", "orbis", 44)
	# A ship order signed for the open design (the console shots sign one).
	var signed := contracts != null and not (contracts.get("_ships") as Dictionary).is_empty()
	if contracts and design and not signed:
		var rec: Object = design.get("library").get("current")
		for o: Dictionary in contracts.call("ship_orders"):
			if str(contracts.call("ship_sign_problem", o)) == "":
				rec.set("order", o)
				contracts.call("request_sign_ship", o, str(rec.get("id")), str(rec.get("name")), int(float(o.budget) * 0.55), "You")
				break
	await _frames(3)
	# A freighter waiting in a holding berth; the signed ship in the build berth with her frame
	# and plates ordered and the frame in.
	if build and orders:
		var rec := DesignRecord.new()
		rec.name = "Hesper freighter"
		DesignBus.Samples.freighter(rec, orders.call("catalog"))
		build.call("start", "help_freighter", rec.to_dict(), rec.name, "bots")
		await _frames(2)
		var cid := str(build.get("current"))
		for l: Dictionary in orders.call("lines", cid):
			if str(l.stage) in ["frame", "plates"]:
				var qs: Array = orders.call("quotes", cid, l)
				if not qs.is_empty():
					orders.call("set_split", cid, str(l.key), str(qs[0].vendor), float(l.need))
		orders.call("place", cid)
		for o: Dictionary in orders.get("orders"):
			if int(o.id) == 1:
				o.due = int(orders.call("now_minute"))
				o.late = 0
		orders.call("deliver_due")
		# Two lines chosen, not yet ordered.
		var n := 0
		for l: Dictionary in orders.call("lines", cid):
			if str(l.kind) == "component" and n < 2:
				var qs: Array = orders.call("quotes", cid, l)
				orders.call("set_split", cid, str(l.key), str(qs[0].vendor), float(l.need))
				n += 1
	await _frames(3)


## A step before the shot: ["call", method, args...] on the screen, or ["press", text].
func _do(screen: Control, step: Array) -> void:
	match str(step[0]):
		"call":
			if screen.has_method(str(step[1])):
				screen.callv(str(step[1]), step.slice(2))
		"press":
			var b := Ring.find_text(screen, str(step[1])) as BaseButton
			if b:
				b.pressed.emit()
		"scroll":
			var sc := screen.find_children("*", "ScrollContainer", true, false)
			if not sc.is_empty():
				(sc[0] as ScrollContainer).scroll_vertical = int(step[1])
		"set":
			screen.set(str(step[1]), step[2])
			if screen.has_method("refresh"):
				screen.call("refresh")


func _dump(root: Control, id: String) -> void:
	var lines: PackedStringArray = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and (n as Control).is_visible_in_tree():
			var t := ""
			if n is Button:
				t = "[B] " + (n as Button).text
			elif n is Label:
				t = (n as Label).text
			elif n is LineEdit:
				t = "[E] " + (n as LineEdit).placeholder_text
			if t.strip_edges() != "":
				var r := (n as Control).get_global_rect()
				var tip := (n as Control).tooltip_text
				lines.append("%4d,%4d %4dx%3d  %s%s" % [r.position.x, r.position.y, r.size.x, r.size.y, t.replace("\n", " / "),
						("   {tip: %s}" % tip.replace("\n", " ")) if tip != "" else ""])
		var kids := n.get_children()
		kids.reverse()
		stack.append_array(kids)
	var f := FileAccess.open(out.path_join(id + ".txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## `crop`: [x, y, w, h] px of the window to keep (a corner of a big screen), drawn larger.
func _save(id: String, crop: Array = []) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if crop.size() == 4:
		img = img.get_region(Rect2i(int(crop[0]), int(crop[1]), int(crop[2]), int(crop[3])))
	img.save_png(out.path_join(id + ".png"))
	if install:
		var small := img.duplicate() as Image
		var w := 1200 if crop.is_empty() else mini(1100, img.get_width() * 2)
		small.resize(w, roundi(float(w) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Shots.DIR))
		small.save_webp(ProjectSettings.globalize_path(Shots.DIR.path_join(id + ".webp")), true, 0.82)
	print("HelpShots: ", out.path_join(id + ".png"))
